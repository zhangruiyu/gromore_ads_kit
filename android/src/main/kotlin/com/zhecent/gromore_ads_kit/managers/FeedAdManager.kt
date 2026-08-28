package com.zhecent.gromore_ads_kit.managers

import com.bytedance.sdk.openadsdk.TTAdNative
import com.bytedance.sdk.openadsdk.TTAdSdk
import com.bytedance.sdk.openadsdk.TTFeedAd
import com.zhecent.gromore_ads_kit.common.AdConstants
import com.zhecent.gromore_ads_kit.common.BaseBatchAdManager
import com.zhecent.gromore_ads_kit.utils.AdEventHelper
import com.zhecent.gromore_ads_kit.utils.AdDiagnosticsHelper
import com.zhecent.gromore_ads_kit.utils.AdLogger
import com.zhecent.gromore_ads_kit.utils.AdValidationHelper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger

/**
 * 信息流广告管理器
 * 负责信息流广告的加载、清理和生命周期管理
 */
class FeedAdManager(
    eventHelper: AdEventHelper,
    validationHelper: AdValidationHelper = AdValidationHelper.getInstance(),
    logger: AdLogger = AdLogger.getInstance()
) : BaseBatchAdManager(AdConstants.AD_TYPE_FEED, eventHelper, validationHelper, logger) {

    data class FeedAdPayload(
        val posId: String,
        val ad: TTFeedAd,
        val isExpress: Boolean
    )

    private data class FeedAdEntry(
        val payload: FeedAdPayload,
        val createdAt: Long = System.currentTimeMillis()
    )

    private val adIdGenerator = AtomicInteger(1)
    private val feedAds = mutableMapOf<Int, FeedAdEntry>()

    override fun loadBatch(call: MethodCall, result: Result) {
        val request = prepareRequest(call, result) ?: return

        logRequest(request.posId, request.requestLog)

        try {
            logLifecycle(request.posId, "开始加载")
            val adSlot = buildAdSlot(request)

            val resultSent = AtomicBoolean(false)
            val adNativeLoader: TTAdNative = TTAdSdk.getAdManager().createAdNative(request.activity)

            val feedAdListener = object : TTAdNative.FeedAdListener {
                override fun onFeedAdLoad(feedAdList: List<TTFeedAd>?) {
                    val ads = feedAdList ?: emptyList()
                    if (ads.isEmpty()) {
                        logLifecycle(request.posId, "加载成功但无可用广告")
                        sendLoadSuccess(request.posId, mapOf("count" to 0))
                        if (!resultSent.getAndSet(true)) {
                            result.success(emptyList<Int>())
                        }
                        return
                    }

                    val adIds = mutableListOf<Int>()
                    ads.forEach { feedAd ->
                        val adId = adIdGenerator.getAndIncrement()
                        val isExpress = feedAd.mediationManager?.isExpress == true
                        val entry = FeedAdEntry(
                            FeedAdPayload(request.posId, feedAd, isExpress)
                        )
                        feedAds[adId] = entry
                        adIds.add(adId)
                        eventHelper.sendAdEvent(
                            AdConstants.Events.FEED_LOADED,
                            request.posId,
                            mapOf("adId" to adId, "express" to isExpress)
                        )
                    }

                    logger.logAdSuccess(
                        AdConstants.AD_TYPE_FEED,
                        "加载",
                        request.posId,
                        "成功获取${adIds.size}个信息流广告"
                    )
                    sendLoadSuccess(request.posId, mapOf("count" to adIds.size))
                    if (!resultSent.getAndSet(true)) {
                        result.success(adIds)
                    }
                }

                override fun onError(errorCode: Int, message: String?) {
                    val errorMessage = message ?: "未知错误"
                    logger.logAdError(AdConstants.AD_TYPE_FEED, "加载", request.posId, errorCode, errorMessage)
                    sendLoadFail(request.posId, errorCode, errorMessage)
                    if (!resultSent.getAndSet(true)) {
                        result.error(
                            AdConstants.ErrorCodes.LOAD_ERROR,
                            "信息流广告加载失败: $errorMessage",
                            errorCode
                        )
                    }
                }
            }

            adNativeLoader.loadFeedAd(adSlot, feedAdListener)
        } catch (e: Exception) {
            logger.logAdError(
                AdConstants.AD_TYPE_FEED,
                "加载异常",
                request.posId,
                -1,
                e.message ?: "未知异常"
            )
            result.error(
                AdConstants.ErrorCodes.LOAD_ERROR,
                "信息流广告加载异常: ${e.message}",
                null
            )
        }
    }

    override fun clearBatch(call: MethodCall, result: Result) {
        val adIds = call.argument<List<Int>>("list") ?: emptyList()
        if (adIds.isEmpty()) {
            result.success(true)
            return
        }

        var clearedCount = 0
        adIds.forEach { adId ->
            val entry = feedAds.remove(adId)
            if (entry != null) {
                try {
                    entry.payload.ad.destroy()
                } catch (destroyError: Exception) {
                    logger.logAdError(
                        AdConstants.AD_TYPE_FEED,
                        "销毁",
                        entry.payload.posId,
                        -1,
                        destroyError.message ?: "销毁异常"
                    )
                }
                clearedCount++
                logger.logAdSuccess(AdConstants.AD_TYPE_FEED, "销毁", entry.payload.posId, "adId=$adId")
                eventHelper.sendAdEvent(
                    AdConstants.Events.FEED_DESTROYED,
                    entry.payload.posId,
                    mapOf("adId" to adId, "reason" to "clear")
                )
            }
        }

        logger.logAdLifecycle(
            AdConstants.AD_TYPE_FEED,
            "",
            "批量清除信息流广告，成功$clearedCount/${adIds.size}"
        )
        result.success(true)
    }

    override fun destroyAll() {
        if (feedAds.isEmpty()) {
            return
        }
        feedAds.forEach { (adId, entry) ->
            try {
                entry.payload.ad.destroy()
                logger.logAdLifecycle(
                    AdConstants.AD_TYPE_FEED,
                    entry.payload.posId,
                    "销毁缓存广告 adId=$adId"
                )
            } catch (e: Exception) {
                logger.logAdError(
                    AdConstants.AD_TYPE_FEED,
                    "销毁",
                    entry.payload.posId,
                    -1,
                    e.message ?: "销毁异常"
                )
            }
        }
        feedAds.clear()
        adIdGenerator.set(1)
    }

    fun takeFeedAd(adId: Int): FeedAdPayload? {
        val entry = feedAds.remove(adId)
        if (entry == null) {
            logger.logAdError(
                AdConstants.AD_TYPE_FEED,
                "取用",
                "",
                -1,
                "尝试取用不存在的广告 adId=$adId"
            )
        }
        return entry?.payload
    }

    fun isReady(adId: Int): Boolean {
        return feedAds[adId]?.payload?.ad?.mediationManager?.isReady == true
    }

    fun getAdLoadInfo(adId: Int): List<Map<String, Any>> {
        return AdDiagnosticsHelper.getAdLoadInfo(feedAds[adId]?.payload?.ad?.mediationManager)
    }

    override fun destroy() {
        destroyAll()
    }
}
