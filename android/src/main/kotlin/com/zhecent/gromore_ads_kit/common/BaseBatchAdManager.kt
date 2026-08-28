package com.zhecent.gromore_ads_kit.common

import android.app.Activity
import com.bytedance.sdk.openadsdk.AdSlot
import com.bytedance.sdk.openadsdk.mediation.ad.MediationAdSlot
import com.zhecent.gromore_ads_kit.utils.AdEventHelper
import com.zhecent.gromore_ads_kit.utils.AdLogger
import com.zhecent.gromore_ads_kit.utils.AdValidationHelper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result

/**
 * 通用批量广告管理器，封装信息流/Draw广告公共参数解析与校验。
 */
abstract class BaseBatchAdManager(
    private val adType: String,
    eventHelper: AdEventHelper,
    validationHelper: AdValidationHelper = AdValidationHelper.getInstance(),
    logger: AdLogger = AdLogger.getInstance()
) : BaseAdManager(eventHelper, validationHelper, logger), BatchAdManagerInterface {

    protected data class BatchRequest(
        val posId: String,
        val activity: Activity,
        val width: Int,
        val height: Int,
        val count: Int,
        val mediationSlot: MediationAdSlot,
        val requestLog: MutableMap<String, Any>
    )

    protected fun prepareRequest(call: MethodCall, result: Result): BatchRequest? {
        val posId = call.argument<String>("posId")?.trim()
        if (posId.isNullOrEmpty()) {
            result.error(AdConstants.ErrorCodes.INVALID_POS_ID, "广告位ID不能为空", null)
            return null
        }

        val activity = getCurrentActivity()
        val errorMessage = validationHelper.performBasicChecks(adType, posId, activity)
        if (errorMessage != null) {
            result.error(AdConstants.ErrorCodes.LOAD_ERROR, errorMessage, null)
            return null
        }
        val nonNullActivity = activity ?: return null

        // 修复：要求用户必须传递width/height/count，不使用默认值
        val requestedWidth = call.argument<Int>("width")
        if (requestedWidth == null || requestedWidth == 0) {
            result.error(AdConstants.ErrorCodes.INVALID_PARAMS, "width参数必须传递且大于0", null)
            return null
        }

        val requestedHeight = call.argument<Int>("height")
        if (requestedHeight == null || requestedHeight == 0) {
            result.error(AdConstants.ErrorCodes.INVALID_PARAMS, "height参数必须传递且大于0", null)
            return null
        }

        val requestedCount = call.argument<Int>("count")
        if (requestedCount == null || requestedCount == 0) {
            result.error(AdConstants.ErrorCodes.INVALID_PARAMS, "count参数必须传递且大于0", null)
            return null
        }

        val (widthPx, heightPx) = validationHelper.validateAdSize(requestedWidth, requestedHeight)
        val adCount = validationHelper.validateAdCount(requestedCount)

        validationHelper.updateRequestTime(posId)

        val requestLog = mutableMapOf<String, Any>(
            "width" to widthPx,
            "height" to heightPx,
            "count" to adCount
        )

        val mediationBuilder = MediationAdSlot.Builder()

        if (call.hasArgument("mutedIfCan")) {
            val muted = call.argument<Boolean>("mutedIfCan") ?: false
            mediationBuilder.setMuted(muted)
            requestLog["mutedIfCan"] = muted
        }

        if (call.hasArgument("volume")) {
            val rawVolume = call.argument<Number>("volume")?.toFloat() ?: 1f
            val volume = validationHelper.validateVolume(rawVolume)
            mediationBuilder.setVolume(volume)
            requestLog["volume"] = volume
        }

        if (call.hasArgument("bidNotify")) {
            val bidNotify = call.argument<Boolean>("bidNotify") ?: false
            mediationBuilder.setBidNotify(bidNotify)
            requestLog["bidNotify"] = bidNotify
        }

        if (call.hasArgument("scenarioId")) {
            val scenarioId = call.argument<String>("scenarioId")?.trim()
            if (!scenarioId.isNullOrEmpty()) {
                mediationBuilder.setScenarioId(scenarioId)
                requestLog["scenarioId"] = scenarioId
            }
        }

        if (call.hasArgument("useSurfaceView")) {
            val useSurfaceView = call.argument<Boolean>("useSurfaceView") ?: false
            mediationBuilder.setUseSurfaceView(useSurfaceView)
            requestLog["useSurfaceView"] = useSurfaceView
        }

        if (call.hasArgument("extra")) {
            val extraParams = call.argument<Map<String, Any?>>("extra")
            extraParams?.forEach { (key, value) ->
                if (value != null) {
                    mediationBuilder.setExtraObject(key, value)
                }
            }
            if (!extraParams.isNullOrEmpty()) {
                requestLog["extra"] = extraParams
            }
        }

        return BatchRequest(
            posId = posId,
            activity = nonNullActivity,
            width = widthPx,
            height = heightPx,
            count = adCount,
            mediationSlot = mediationBuilder.build(),
            requestLog = requestLog
        )
    }

    protected fun buildAdSlot(request: BatchRequest): AdSlot {
        return AdSlot.Builder()
            .setCodeId(request.posId)
            .setImageAcceptedSize(request.width, request.height)
            .setAdCount(request.count)
            .setMediationAdSlot(request.mediationSlot)
            .build()
    }

    protected fun logRequest(posId: String, params: Map<String, Any>) {
        logger.logAdRequest(adType, posId, params)
    }

    protected fun logLifecycle(posId: String, action: String) {
        logger.logAdLifecycle(adType, posId, action)
    }

    protected fun sendLoadSuccess(posId: String, extra: Map<String, Any>? = null) {
        eventHelper.sendLoadSuccessEvent(adType, posId, extra)
    }

    protected fun sendLoadFail(posId: String, errorCode: Int, errorMessage: String) {
        eventHelper.sendLoadFailEvent(adType, posId, errorCode, errorMessage)
    }
}
