package com.zhecent.gromore_ads_kit.managers

import android.os.Bundle
import android.util.Log
import com.bytedance.sdk.openadsdk.AdSlot
import com.bytedance.sdk.openadsdk.TTAdConstant
import com.bytedance.sdk.openadsdk.TTAdNative
import com.bytedance.sdk.openadsdk.TTAdSdk
import com.bytedance.sdk.openadsdk.TTRewardVideoAd
import com.bytedance.sdk.openadsdk.mediation.MediationConstant
import com.bytedance.sdk.openadsdk.mediation.ad.MediationAdSlot
import com.zhecent.gromore_ads_kit.common.AdConstants
import com.zhecent.gromore_ads_kit.common.AdManagerInterface
import com.zhecent.gromore_ads_kit.common.BaseAdManager
import com.zhecent.gromore_ads_kit.utils.AdEventHelper
import com.zhecent.gromore_ads_kit.utils.AdLogger
import com.zhecent.gromore_ads_kit.utils.AdDiagnosticsHelper
import com.zhecent.gromore_ads_kit.utils.AdValidationHelper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import java.util.concurrent.atomic.AtomicBoolean

/**
 * 激励视频广告管理器
 * 负责激励视频广告的加载、展示和生命周期管理
 */
class RewardVideoAdManager(
    eventHelper: AdEventHelper,
    validationHelper: AdValidationHelper = AdValidationHelper.getInstance(),
    logger: AdLogger = AdLogger.getInstance()
) : BaseAdManager(eventHelper, validationHelper, logger), AdManagerInterface {

    private data class RewardRequest(
        val posId: String,
        val orientation: Int,
        val orientationProvided: Boolean,
        val userId: String?,
        val customData: String?,
        val rewardName: String?,
        val rewardAmount: Int?,
        val mutedIfCan: Boolean?,
        val volume: Float?,
        val bidNotify: Boolean?,
        val scenarioId: String?,
        val useSurfaceView: Boolean?,
        val showAdnLoadErrorDetail: Boolean
    )

    private var currentRequest: RewardRequest? = null
    private var rewardVideoAd: TTRewardVideoAd? = null
    private var currentPosId: String? = null
    private var isLoading = false
    private var hasLoaded = false

    override fun load(call: MethodCall, result: Result) {
        val posId = call.argument<String>("posId")?.takeIf { it.isNotBlank() }
        if (posId == null) {
            result.error(AdConstants.ErrorCodes.INVALID_POS_ID, "广告位ID不能为空", null)
            return
        }

        val activity = getCurrentActivity()
        val errorMsg = validationHelper.performBasicChecks(AdConstants.AD_TYPE_REWARD_VIDEO, posId, activity)
        if (errorMsg != null) {
            result.error(AdConstants.ErrorCodes.LOAD_ERROR, errorMsg, null)
            return
        }

        if (isLoading) {
            result.error(AdConstants.ErrorCodes.ALREADY_LOADING, "激励视频广告正在加载，请稍后再试", null)
            return
        }

        val request = buildRewardRequest(posId, call)
        isLoading = true
        hasLoaded = false
        currentRequest = request
        currentPosId = posId
        validationHelper.updateRequestTime(posId)
        logRewardRequest(request)

        try {
            logger.logAdLifecycle(AdConstants.AD_TYPE_REWARD_VIDEO, posId, "开始加载")
            val adSlot = buildAdSlot(request)
            val resultSent = AtomicBoolean(false)
            val adNativeLoader: TTAdNative = TTAdSdk.getAdManager().createAdNative(activity)

            val rewardVideoAdListener = object : TTAdNative.RewardVideoAdListener {
                override fun onRewardVideoAdLoad(ttRewardVideoAd: TTRewardVideoAd?) {
                    rewardVideoAd = ttRewardVideoAd
                    isLoading = false
                    hasLoaded = true
                    logger.logAdSuccess(AdConstants.AD_TYPE_REWARD_VIDEO, "加载", posId)
                    eventHelper.sendLoadSuccessEvent(AdConstants.AD_TYPE_REWARD_VIDEO, posId)
                    if (!resultSent.getAndSet(true)) {
                        result.success(true)
                    }
                }

                override fun onRewardVideoCached() {
                    val targetPosId = currentPosId ?: posId
                    logger.logAdSuccess(AdConstants.AD_TYPE_REWARD_VIDEO, "缓存", targetPosId)
                    eventHelper.sendAdEvent(AdConstants.Events.REWARD_VIDEO_CACHED, targetPosId)
                }

                override fun onRewardVideoCached(ttRewardVideoAd: TTRewardVideoAd?) {
                    rewardVideoAd = ttRewardVideoAd
                    val targetPosId = currentPosId ?: posId
                    logger.logAdSuccess(AdConstants.AD_TYPE_REWARD_VIDEO, "缓存", targetPosId)
                    hasLoaded = true
                    eventHelper.sendAdEvent(AdConstants.Events.REWARD_VIDEO_CACHED, targetPosId)
                }

                override fun onError(code: Int, message: String?) {
                    val errorMessage = message ?: "未知错误"
                    logger.logAdError(AdConstants.AD_TYPE_REWARD_VIDEO, "加载", posId, code, errorMessage)
                    eventHelper.sendLoadFailEvent(AdConstants.AD_TYPE_REWARD_VIDEO, posId, code, errorMessage)
                    resetState(clearRequest = true)
                    rewardVideoAd = null
                    if (!resultSent.getAndSet(true)) {
                        result.error(AdConstants.ErrorCodes.LOAD_ERROR, "激励视频广告加载失败: $errorMessage", code)
                    }
                }
            }

            adNativeLoader.loadRewardVideoAd(adSlot, rewardVideoAdListener)
        } catch (e: Exception) {
            Log.e(AdConstants.TAG, "激励视频广告加载异常", e)
            logger.logAdError(AdConstants.AD_TYPE_REWARD_VIDEO, "加载异常", posId, -1, e.message ?: "未知异常")
            resetState(clearRequest = true)
            rewardVideoAd = null
            result.error(AdConstants.ErrorCodes.LOAD_ERROR, "激励视频广告加载异常: ${e.message}", null)
        }
    }

    override fun show(call: MethodCall, result: Result) {
        val requestedPosId = call.argument<String>("posId")?.takeIf { it.isNotBlank() }
        val loadedPosId = currentPosId
        if (loadedPosId.isNullOrBlank()) {
            result.error(AdConstants.ErrorCodes.AD_NOT_LOADED, "激励视频广告未加载，请先调用loadRewardVideoAd", null)
            return
        }
        if (requestedPosId != null && requestedPosId != loadedPosId) {
            result.error(
                AdConstants.ErrorCodes.INVALID_OPERATION,
                "激励视频广告与传入的广告位不一致，请重新加载",
                null
            )
            return
        }

        val activity = getCurrentActivity()
        if (activity == null) {
            result.error(AdConstants.ErrorCodes.NO_ACTIVITY, "Activity不可用", null)
            return
        }

        val adInstance = rewardVideoAd
        if (adInstance == null || !hasLoaded) {
            result.error(
                AdConstants.ErrorCodes.AD_NOT_LOADED,
                "激励视频广告未准备就绪，请确认已成功加载",
                null
            )
            return
        }

        val mediationManager = adInstance.mediationManager
        if (mediationManager?.isReady != true) {
            logger.logAdError(
                AdConstants.AD_TYPE_REWARD_VIDEO,
                "展示",
                loadedPosId,
                -1,
                "广告未准备就绪"
            )
            result.error(AdConstants.ErrorCodes.SDK_NOT_READY, "激励视频广告未准备就绪，请稍后再试", null)
            return
        }

        val posId = loadedPosId
        logger.logAdLifecycle(AdConstants.AD_TYPE_REWARD_VIDEO, posId, "开始展示")
        adInstance.setRewardAdInteractionListener(createInteractionListener(posId))

        hasLoaded = false
        activity.runOnUiThread {
            try {
                adInstance.showRewardVideoAd(activity)
                result.success(true)
            } catch (e: Exception) {
                logger.logAdError(AdConstants.AD_TYPE_REWARD_VIDEO, "展示", posId, -1, e.message ?: "未知异常")
                result.error(AdConstants.ErrorCodes.SHOW_ERROR, "激励视频广告展示异常: ${e.message}", null)
            }
        }
    }

    override fun destroy() {
        try {
            rewardVideoAd?.mediationManager?.destroy()
        } catch (e: Exception) {
            Log.w(AdConstants.TAG, "销毁激励视频广告异常", e)
        } finally {
            rewardVideoAd = null
            logger.logAdLifecycle(AdConstants.AD_TYPE_REWARD_VIDEO, currentPosId ?: "", "广告实例已销毁")
            resetState(clearRequest = true)
        }
    }

    override fun isReady(): Boolean {
        return rewardVideoAd?.mediationManager?.isReady == true
    }

    fun getAdLoadInfo(): List<Map<String, Any>> {
        return AdDiagnosticsHelper.getAdLoadInfo(rewardVideoAd?.mediationManager)
    }

    private fun buildRewardRequest(posId: String, call: MethodCall): RewardRequest {
        val orientationProvided = call.hasArgument("orientation")
        val rawOrientation = if (orientationProvided) {
            call.argument<Int>("orientation") ?: AdConstants.ORIENTATION_VERTICAL
        } else {
            AdConstants.ORIENTATION_VERTICAL
        }
        val resolvedOrientation = validationHelper.validateOrientation(rawOrientation)

        val userId = call.argument<String>("userId")?.takeIf { it.isNotBlank() }
        val customData = call.argument<String>("customData")?.takeIf { it.isNotBlank() }
        val rewardName = call.argument<String>("rewardName")?.takeIf { it.isNotBlank() }
        val rewardAmount = call.argument<Int>("rewardAmount")?.takeIf { it > 0 }
        val mutedIfCan = call.argument<Boolean>("mutedIfCan")
        val volume = call.argument<Double>("volume")?.toFloat()?.let { validationHelper.validateVolume(it) }
        val bidNotify = call.argument<Boolean>("bidNotify")
        val scenarioId = call.argument<String>("scenarioId")?.takeIf { it.isNotBlank() }
        val useSurfaceView = call.argument<Boolean>("useSurfaceView")
        val showAdnLoadErrorDetail = call.argument<Boolean>("showAdnLoadErrorDetail") == true

        return RewardRequest(
            posId = posId,
            orientation = resolvedOrientation,
            orientationProvided = orientationProvided,
            userId = userId,
            customData = customData,
            rewardName = rewardName,
            rewardAmount = rewardAmount,
            mutedIfCan = mutedIfCan,
            volume = volume,
            bidNotify = bidNotify,
            scenarioId = scenarioId,
            useSurfaceView = useSurfaceView,
            showAdnLoadErrorDetail = showAdnLoadErrorDetail
        )
    }

    private fun logRewardRequest(request: RewardRequest) {
        val params = mutableMapOf<String, Any>()
        if (request.orientationProvided) {
            params["orientation"] = request.orientation
        }
        request.userId?.let { params["userId"] = it }
        request.customData?.let { params["customData"] = it }
        request.rewardName?.let { params["rewardName"] = it }
        request.rewardAmount?.let { params["rewardAmount"] = it }
        request.mutedIfCan?.let { params["mutedIfCan"] = it }
        request.volume?.let { params["volume"] = it }
        request.bidNotify?.let { params["bidNotify"] = it }
        request.scenarioId?.let { params["scenarioId"] = it }
        request.useSurfaceView?.let { params["useSurfaceView"] = it }
        params["showAdnLoadErrorDetail"] = request.showAdnLoadErrorDetail
        logger.logAdRequest(AdConstants.AD_TYPE_REWARD_VIDEO, request.posId, params)
    }

    private fun buildAdSlot(request: RewardRequest): AdSlot {
        val adSlotBuilder = AdSlot.Builder()
            .setCodeId(request.posId)
            .setOrientation(
                if (request.orientation == AdConstants.ORIENTATION_HORIZONTAL) {
                    TTAdConstant.HORIZONTAL
                } else {
                    TTAdConstant.VERTICAL
                }
            )

        request.userId?.let { adSlotBuilder.setUserID(it) }

        val mediationSlotBuilder = MediationAdSlot.Builder()
        request.mutedIfCan?.let { mediationSlotBuilder.setMuted(it) }
        request.volume?.let { mediationSlotBuilder.setVolume(it) }
        request.bidNotify?.let { mediationSlotBuilder.setBidNotify(it) }
        request.useSurfaceView?.let { mediationSlotBuilder.setUseSurfaceView(it) }
        request.rewardName?.let { mediationSlotBuilder.setRewardName(it) }
        request.rewardAmount?.let { mediationSlotBuilder.setRewardAmount(it) }
        request.scenarioId?.let { mediationSlotBuilder.setScenarioId(it) }
        request.customData?.let {
            mediationSlotBuilder.setExtraObject(MediationConstant.CUSTOM_DATA_KEY_GROMORE_EXTRA, it)
        }
        if (request.showAdnLoadErrorDetail) {
            mediationSlotBuilder.setExtraObject("show_adn_load_error_detail", true)
        }

        return adSlotBuilder
            .setMediationAdSlot(mediationSlotBuilder.build())
            .build()
    }

    private fun createInteractionListener(posId: String): TTRewardVideoAd.RewardAdInteractionListener {
        return object : TTRewardVideoAd.RewardAdInteractionListener {
            override fun onAdShow() {
                logger.logAdSuccess(AdConstants.AD_TYPE_REWARD_VIDEO, "显示", posId)
                eventHelper.sendShowEvent(AdConstants.AD_TYPE_REWARD_VIDEO, posId)
                sendEcpmInfo(posId)
            }

            override fun onAdVideoBarClick() {
                logger.logAdSuccess(AdConstants.AD_TYPE_REWARD_VIDEO, "点击", posId)
                eventHelper.sendClickEvent(AdConstants.AD_TYPE_REWARD_VIDEO, posId)
            }

            override fun onAdClose() {
                logger.logAdSuccess(AdConstants.AD_TYPE_REWARD_VIDEO, "关闭", posId)
                eventHelper.sendCloseEvent(AdConstants.AD_TYPE_REWARD_VIDEO, posId)
                logger.logAdDetailInfo(rewardVideoAd?.mediationManager)
                destroy()
            }

            override fun onVideoComplete() {
                logger.logAdSuccess(AdConstants.AD_TYPE_REWARD_VIDEO, "播放完成", posId)
                eventHelper.sendAdEvent(AdConstants.Events.REWARD_VIDEO_COMPLETED, posId)
            }

            override fun onVideoError() {
                logger.logAdError(AdConstants.AD_TYPE_REWARD_VIDEO, "播放", posId, -1, "视频播放异常")
                eventHelper.sendAdEvent(AdConstants.Events.REWARD_VIDEO_ERROR, posId)
            }

            override fun onRewardVerify(
                rewardVerify: Boolean,
                rewardAmount: Int,
                rewardName: String?,
                errorCode: Int,
                errorMsg: String?
            ) {
                Log.d(AdConstants.TAG, "激励视频奖励验证(已废弃): verify=$rewardVerify, amount=$rewardAmount, name=$rewardName")
            }

            override fun onRewardArrived(rewardVerify: Boolean, rewardType: Int, rewardBundle: Bundle?) {
                val rewardName = rewardBundle?.getString("reward_name") ?: currentRequest?.rewardName ?: ""
                val rewardAmount = rewardBundle?.getInt("reward_amount") ?: currentRequest?.rewardAmount ?: 0
                val extra = mutableMapOf<String, Any>(
                    "verified" to rewardVerify,
                    "rewardType" to rewardType,
                    "rewardName" to rewardName,
                    "rewardAmount" to rewardAmount
                )
                currentRequest?.userId?.let { extra["userId"] = it }
                currentRequest?.customData?.let { extra["customData"] = it }
                logger.logAdSuccess(
                    AdConstants.AD_TYPE_REWARD_VIDEO,
                    "奖励验证",
                    posId,
                    "verify=$rewardVerify, name=$rewardName, amount=$rewardAmount"
                )
                eventHelper.sendAdEvent(AdConstants.Events.REWARD_VIDEO_REWARDED, posId, extra)
            }

            override fun onSkippedVideo() {
                logger.logAdSuccess(AdConstants.AD_TYPE_REWARD_VIDEO, "跳过", posId)
                eventHelper.sendAdEvent(AdConstants.Events.REWARD_VIDEO_SKIPPED, posId)
            }
        }
    }

    private fun sendEcpmInfo(posId: String) {
        try {
            val ecpmInfo = rewardVideoAd?.mediationManager?.showEcpm ?: return
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
            eventHelper.sendAdEvent(AdConstants.Events.REWARD_VIDEO_ECPM_INFO, posId, ecpmData)
        } catch (e: Exception) {
            Log.w(AdConstants.TAG, "获取激励视频ECPM信息异常: ${e.message}")
        }
    }

    private fun resetState(clearRequest: Boolean) {
        isLoading = false
        hasLoaded = false
        if (clearRequest) {
            currentRequest = null
            currentPosId = null
        }
    }
}
