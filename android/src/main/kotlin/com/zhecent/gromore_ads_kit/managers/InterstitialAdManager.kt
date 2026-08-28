package com.zhecent.gromore_ads_kit.managers

import android.util.Log
import com.bytedance.sdk.openadsdk.*
import com.bytedance.sdk.openadsdk.mediation.ad.MediationAdSlot
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import java.util.concurrent.atomic.AtomicBoolean
import com.zhecent.gromore_ads_kit.common.AdConstants
import com.zhecent.gromore_ads_kit.common.AdManagerInterface
import com.zhecent.gromore_ads_kit.common.BaseAdManager
import com.zhecent.gromore_ads_kit.utils.AdEventHelper
import com.zhecent.gromore_ads_kit.utils.AdValidationHelper
import com.zhecent.gromore_ads_kit.utils.AdLogger
import com.zhecent.gromore_ads_kit.utils.AdDiagnosticsHelper

/**
 * 插屏广告管理器
 * 负责插屏广告的加载、展示和生命周期管理
 */
class InterstitialAdManager(
    eventHelper: AdEventHelper,
    validationHelper: AdValidationHelper = AdValidationHelper.getInstance(),
    logger: AdLogger = AdLogger.getInstance()
) : BaseAdManager(eventHelper, validationHelper, logger), AdManagerInterface {

    // 插屏广告对象
    private var interstitialAd: TTFullScreenVideoAd? = null
    private var currentPosId: String? = null
    private val isLoading = AtomicBoolean(false)
    private val hasLoaded = AtomicBoolean(false)

    override fun load(call: MethodCall, result: Result) {
        val posId = call.argument<String>("posId")?.trim()
        if (posId.isNullOrEmpty()) {
            result.error(AdConstants.ErrorCodes.INVALID_POS_ID, "广告位ID不能为空", null)
            return
        }

        val activity = getCurrentActivity()
        if (activity == null) {
            result.error(AdConstants.ErrorCodes.NO_ACTIVITY, "Activity不可用", null)
            return
        }

        // 执行基础检查
        val errorMsg = validationHelper.performBasicChecks(AdConstants.AD_TYPE_INTERSTITIAL, posId, activity)
        if (errorMsg != null) {
            result.error(AdConstants.ErrorCodes.LOAD_ERROR, errorMsg, null)
            return
        }

        if (!isLoading.compareAndSet(false, true)) {
            result.error(AdConstants.ErrorCodes.ALREADY_LOADING, "插屏广告正在加载中，请勿重复调用", null)
            return
        }

        // 获取方向参数（现在也是可选的）
        val requestedOrientation = call.argument<Int>("orientation")
        val validatedOrientation = validationHelper.validateOrientation(requestedOrientation ?: AdConstants.ORIENTATION_VERTICAL)

        currentPosId = posId
        hasLoaded.set(false)

        // 更新请求时间
        validationHelper.updateRequestTime(posId)

        val mutedIfCan = if (call.hasArgument("mutedIfCan")) call.argument<Boolean>("mutedIfCan") ?: false else null
        val volume = if (call.hasArgument("volume")) {
            val rawVolume = call.argument<Number>("volume")?.toFloat() ?: 1.0f
            validationHelper.validateVolume(rawVolume)
        } else null
        val bidNotify = if (call.hasArgument("bidNotify")) call.argument<Boolean>("bidNotify") ?: false else null
        val scenarioId = call.argument<String>("scenarioId")?.trim()?.takeIf { it.isNotEmpty() }
        val useSurfaceView = if (call.hasArgument("useSurfaceView")) call.argument<Boolean>("useSurfaceView") ?: false else null
        val extraData = call.argument<Map<String, Any?>>("extraData")
        val extraParams = call.argument<Map<String, Any?>>("extraParams")

        val requestParams = mutableMapOf<String, Any>("orientation" to validatedOrientation)
        mutedIfCan?.let { requestParams["mutedIfCan"] = it }
        volume?.let { requestParams["volume"] = it }
        bidNotify?.let { requestParams["bidNotify"] = it }
        scenarioId?.let { requestParams["scenarioId"] = it }
        useSurfaceView?.let { requestParams["useSurfaceView"] = it }
        if (!extraData.isNullOrEmpty()) {
            requestParams["extraData"] = extraData
        }
        if (!extraParams.isNullOrEmpty()) {
            requestParams["extraParams"] = extraParams
        }

        logger.logAdRequest(AdConstants.AD_TYPE_INTERSTITIAL, posId, requestParams)

        try {
            logger.logAdLifecycle(AdConstants.AD_TYPE_INTERSTITIAL, posId, "开始加载")

            // 创建结果状态管理，防止重复提交
            val resultSent = AtomicBoolean(false)

            // 创建AdSlot对象
            val adSlot = AdSlot.Builder()
                .setCodeId(posId)
                .setOrientation(if (validatedOrientation == AdConstants.ORIENTATION_HORIZONTAL) TTAdConstant.HORIZONTAL else TTAdConstant.VERTICAL)
                .setMediationAdSlot(
                    MediationAdSlot.Builder()
                        .apply {
                            mutedIfCan?.let { setMuted(it) }
                            volume?.let { setVolume(it) }
                            bidNotify?.let { setBidNotify(it) }
                            scenarioId?.let { setScenarioId(it) }
                            useSurfaceView?.let { setUseSurfaceView(it) }

                            extraData?.forEach { (key, value) ->
                                if (value != null) {
                                    setExtraObject(key, value)
                                }
                            }

                            extraParams?.forEach { (key, value) ->
                                if (value != null) {
                                    setExtraObject(key, value)
                                }
                            }
                        }
                        .build()
                )
                .build()

            // 创建TTAdNative对象
            val adNativeLoader = TTAdSdk.getAdManager().createAdNative(activity)

            // 创建加载监听器
            val fullScreenVideoListener = object : TTAdNative.FullScreenVideoAdListener {
                override fun onFullScreenVideoAdLoad(ad: TTFullScreenVideoAd?) {
                    logger.logAdSuccess(AdConstants.AD_TYPE_INTERSTITIAL, "加载", posId)
                    interstitialAd = ad
                    hasLoaded.set(true)
                    isLoading.set(false)
                    eventHelper.sendLoadSuccessEvent(AdConstants.AD_TYPE_INTERSTITIAL, posId)

                    // 在加载成功时返回，不等待缓存
                    if (!resultSent.getAndSet(true)) {
                        result.success(true)
                    }
                }

                override fun onFullScreenVideoCached() {
                    Log.d(AdConstants.TAG, "插屏广告缓存成功（旧回调）")
                    currentPosId?.let { eventHelper.sendAdEvent(AdConstants.Events.INTERSTITIAL_CACHED, it) }
                }

                override fun onFullScreenVideoCached(ad: TTFullScreenVideoAd?) {
                    logger.logAdSuccess(AdConstants.AD_TYPE_INTERSTITIAL, "缓存", posId)
                    interstitialAd = ad
                    currentPosId?.let { eventHelper.sendAdEvent(AdConstants.Events.INTERSTITIAL_CACHED, it) }
                }

                override fun onError(code: Int, message: String?) {
                    val errorMessage = message ?: "未知错误"
                    logger.logAdError(AdConstants.AD_TYPE_INTERSTITIAL, "加载", posId, code, errorMessage)
                    eventHelper.sendLoadFailEvent(AdConstants.AD_TYPE_INTERSTITIAL, posId, code, errorMessage)
                    interstitialAd = null
                    hasLoaded.set(false)
                    isLoading.set(false)

                    if (!resultSent.getAndSet(true)) {
                        result.error(AdConstants.ErrorCodes.LOAD_ERROR, "插屏广告加载失败: $errorMessage", code)
                    }
                }
            }

            // 加载广告
            adNativeLoader.loadFullScreenVideoAd(adSlot, fullScreenVideoListener)

        } catch (e: Exception) {
            logger.logAdError(AdConstants.AD_TYPE_INTERSTITIAL, "加载异常", posId, -1, e.message ?: "未知异常")
            interstitialAd = null
            hasLoaded.set(false)
            isLoading.set(false)
            result.error(AdConstants.ErrorCodes.LOAD_ERROR, "插屏广告加载异常: ${e.message}", null)
        }
    }

    override fun show(call: MethodCall, result: Result) {
        val requestedPosId = call.argument<String>("posId")?.trim()
        val loadedPosId = currentPosId
        if (loadedPosId.isNullOrEmpty()) {
            result.error(AdConstants.ErrorCodes.AD_NOT_LOADED, "插屏广告未加载，请先调用loadInterstitialAd", null)
            return
        }

        if (!requestedPosId.isNullOrEmpty() && requestedPosId != loadedPosId) {
            result.error(
                AdConstants.ErrorCodes.INVALID_OPERATION,
                "插屏广告与传入的广告位不一致，请重新加载",
                null
            )
            return
        }

        val activity = getCurrentActivity()
        if (activity == null) {
            result.error(AdConstants.ErrorCodes.NO_ACTIVITY, "Activity不可用", null)
            return
        }

        val adInstance = interstitialAd
        if (adInstance == null || !hasLoaded.get()) {
            result.error(AdConstants.ErrorCodes.AD_NOT_LOADED, "插屏广告未准备就绪，请先加载", null)
            return
        }

        try {
            logger.logAdLifecycle(AdConstants.AD_TYPE_INTERSTITIAL, loadedPosId, "开始展示")

            val mediationManager = adInstance.mediationManager
            if (mediationManager?.isReady != true) {
                logger.logAdError(
                    AdConstants.AD_TYPE_INTERSTITIAL,
                    "展示",
                    loadedPosId,
                    -1,
                    "广告未准备就绪"
                )
                result.error(AdConstants.ErrorCodes.SDK_NOT_READY, "插屏广告未准备就绪，请稍后再试", null)
                return
            }

            val interactionListener = object : TTFullScreenVideoAd.FullScreenVideoAdInteractionListener {
                override fun onAdShow() {
                    logger.logAdSuccess(AdConstants.AD_TYPE_INTERSTITIAL, "显示", loadedPosId)
                    eventHelper.sendShowEvent(AdConstants.AD_TYPE_INTERSTITIAL, loadedPosId)
                    sendEcpmInfo(loadedPosId)
                }

                override fun onAdVideoBarClick() {
                    logger.logAdSuccess(AdConstants.AD_TYPE_INTERSTITIAL, "点击", loadedPosId)
                    eventHelper.sendClickEvent(AdConstants.AD_TYPE_INTERSTITIAL, loadedPosId)
                }

                override fun onAdClose() {
                    logger.logAdSuccess(AdConstants.AD_TYPE_INTERSTITIAL, "关闭", loadedPosId)
                    eventHelper.sendCloseEvent(AdConstants.AD_TYPE_INTERSTITIAL, loadedPosId)
                    logger.logAdDetailInfo(mediationManager)
                    destroy()
                }

                override fun onVideoComplete() {
                    logger.logAdSuccess(AdConstants.AD_TYPE_INTERSTITIAL, "播放完成", loadedPosId)
                    eventHelper.sendAdEvent(AdConstants.Events.INTERSTITIAL_COMPLETED, loadedPosId)
                }

                override fun onSkippedVideo() {
                    logger.logAdSuccess(AdConstants.AD_TYPE_INTERSTITIAL, "跳过", loadedPosId)
                    eventHelper.sendAdEvent(AdConstants.Events.INTERSTITIAL_SKIPPED, loadedPosId)
                }
            }

            adInstance.setFullScreenVideoAdInteractionListener(interactionListener)
            adInstance.showFullScreenVideoAd(activity)
            hasLoaded.set(false)
            result.success(true)

        } catch (e: Exception) {
            logger.logAdError(AdConstants.AD_TYPE_INTERSTITIAL, "展示异常", loadedPosId, -1, e.message ?: "未知异常")
            result.error(AdConstants.ErrorCodes.SHOW_ERROR, "插屏广告展示异常: ${e.message}", null)
        }
    }

    override fun destroy() {
        try {
            interstitialAd?.mediationManager?.destroy()
            interstitialAd = null
        } catch (e: Exception) {
            Log.e(AdConstants.TAG, "销毁插屏广告失败", e)
        } finally {
            hasLoaded.set(false)
            isLoading.set(false)
            val posId = currentPosId ?: ""
            currentPosId = null
            logger.logAdLifecycle(AdConstants.AD_TYPE_INTERSTITIAL, posId, "广告实例已销毁")
        }
    }

    override fun isReady(): Boolean {
        return hasLoaded.get() && interstitialAd?.mediationManager?.isReady == true
    }

    fun getAdLoadInfo(): List<Map<String, Any>> {
        return AdDiagnosticsHelper.getAdLoadInfo(interstitialAd?.mediationManager)
    }

    private fun sendEcpmInfo(posId: String) {
        try {
            val ecpmInfo = interstitialAd?.mediationManager?.showEcpm ?: return
            val ecpmData = mapOf(
                "ecpm" to (ecpmInfo.ecpm ?: "0"),
                "platform" to (ecpmInfo.sdkName ?: ""),
                "ritID" to (ecpmInfo.slotId ?: ""),
                "requestID" to (ecpmInfo.requestId ?: ""),
                "customSdkName" to (ecpmInfo.customSdkName ?: ""),
                "reqBiddingType" to (ecpmInfo.reqBiddingType ?: 0),
                "ritType" to (ecpmInfo.ritType ?: 0),
                "scenarioId" to (ecpmInfo.scenarioId ?: ""),
                "channel" to (ecpmInfo.channel ?: ""),
                "subChannel" to (ecpmInfo.subChannel ?: "")
            )
            eventHelper.sendAdEvent(AdConstants.Events.INTERSTITIAL_ECPM_INFO, posId, ecpmData)
        } catch (e: Exception) {
            Log.w(AdConstants.TAG, "获取插屏广告ECPM信息异常: ${e.message}")
        }
    }
}
