package com.zhecent.gromore_ads_kit.managers

import android.app.Activity
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import com.bytedance.sdk.openadsdk.*
import com.bytedance.sdk.openadsdk.mediation.ad.MediationAdSlot
import com.bytedance.sdk.openadsdk.mediation.manager.MediationAdEcpmInfo
import com.bytedance.sdk.openadsdk.mediation.manager.MediationNativeManager
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
import com.zhecent.gromore_ads_kit.utils.UIUtils
import com.zhecent.gromore_ads_kit.views.buildMixedBannerView

/**
 * Banner广告管理器
 * 负责Banner广告的加载、展示和生命周期管理
 * 基于官方GroMore SDK文档实现
 */
class BannerAdManager(
    eventHelper: AdEventHelper,
    validationHelper: AdValidationHelper = AdValidationHelper.getInstance(),
    logger: AdLogger = AdLogger.getInstance()
) : BaseAdManager(eventHelper, validationHelper, logger), AdManagerInterface {

    companion object {
        private const val TAG = AdConstants.TAG
        private const val CONTAINER_TAG = "gromore_banner_api_container"
    }

    // Banner广告实例
    private var bannerAd: TTNativeExpressAd? = null
    private var currentPosId: String = ""
    private var isLoading = AtomicBoolean(false)
    private var isLoaded = AtomicBoolean(false)

    // 广告监听器
    private var adListener: TTAdNative.NativeExpressAdListener? = null
    private var interactionListener: TTNativeExpressAd.ExpressAdInteractionListener? = null
    private var dislikeCallback: TTAdDislike.DislikeInteractionCallback? = null
    private var bannerContainer: FrameLayout? = null

    override fun load(call: MethodCall, result: Result) {
        val posId = call.argument<String>("posId")?.trim()
        val rawWidth = call.argument<Int>("width") ?: 375
        val rawHeight = call.argument<Int>("height") ?: 60
        val activity = getCurrentActivity()

        // 参数验证
        if (posId.isNullOrBlank()) {
            result.error(AdConstants.ErrorCodes.INVALID_POS_ID, "广告位ID不能为空", null)
            return
        }

        if (activity == null) {
            result.error(AdConstants.ErrorCodes.NO_ACTIVITY, "Activity不可用", null)
            return
        }

        // 执行基础检查
        val errorMsg = validationHelper.performBasicChecks(AdConstants.AD_TYPE_BANNER, posId, activity)
        if (errorMsg != null) {
            logger.logAdError(AdConstants.AD_TYPE_BANNER, "加载", posId, -1, errorMsg)
            result.error(AdConstants.ErrorCodes.LOAD_ERROR, errorMsg, null)
            return
        }

        val nonNullActivity = activity

        // 防止重复加载
        if (!isLoading.compareAndSet(false, true)) {
            val message = "Banner广告正在加载中，请勿重复调用"
            logger.logAdError(AdConstants.AD_TYPE_BANNER, "加载", posId, -1, message)
            result.error(AdConstants.ErrorCodes.ALREADY_LOADING, message, null)
            return
        }

        // 更新状态
        currentPosId = posId
        isLoaded.set(false)
        validationHelper.updateRequestTime(posId)

        val (widthDp, heightDp) = validationHelper.validateAdSize(rawWidth, rawHeight)
        val widthPx = UIUtils.dp2px(nonNullActivity, widthDp)
        val heightPx = UIUtils.dp2px(nonNullActivity, heightDp)

        // 记录请求日志
        val requestLog = mutableMapOf<String, Any>(
            "widthDp" to widthDp,
            "heightDp" to heightDp,
            "widthPx" to widthPx,
            "heightPx" to heightPx
        )

        // 发送开始加载事件
        eventHelper.sendBannerEvent(AdConstants.Events.BANNER_LOAD_START, posId, mapOf(
            "width" to widthPx,
            "height" to heightPx
        ))

        try {
            logger.logAdLifecycle(AdConstants.AD_TYPE_BANNER, posId, "开始加载")

            // 清理之前的广告
            cleanupBannerAd()

            // 创建AdSlot对象（按照官方文档，只配置明确传递的参数）
            val adSlotBuilder = AdSlot.Builder()
                .setCodeId(posId)
                .setImageAcceptedSize(widthPx, heightPx) // 单位px

            // 创建MediationAdSlot构建器
            val mediationBuilder = MediationAdSlot.Builder()

            // 只有明确传递的参数才配置
            if (call.hasArgument("mutedIfCan")) {
                val mutedIfCan = call.argument<Boolean>("mutedIfCan") ?: false
                mediationBuilder.setMuted(mutedIfCan)
                requestLog["mutedIfCan"] = mutedIfCan
            }

            if (call.hasArgument("volume")) {
                val volume = call.argument<Number>("volume")?.toFloat()
                val validatedVolume = validationHelper.validateVolume(volume ?: 1.0f)
                mediationBuilder.setVolume(validatedVolume)
                requestLog["volume"] = validatedVolume
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

            // Banner混出信息流功能（聚合维度功能）
            if (call.hasArgument("enableMixedMode") && call.argument<Boolean>("enableMixedMode") == true) {
                // 设置MediationNativeToBannerListener，将信息流素材渲染成Banner
                val mixedModeListener = object : com.bytedance.sdk.openadsdk.mediation.ad.MediationNativeToBannerListener() {
                    override fun getMediationBannerViewFromNativeAd(nativeAdInfo: com.bytedance.sdk.openadsdk.mediation.ad.IMediationNativeAdInfo?): android.view.View? {
                        val info = nativeAdInfo ?: return null
                        Log.d(TAG, "Banner混出信息流：使用插件默认布局渲染")
                        return buildMixedBannerView(nonNullActivity, info, widthPx, heightPx) { reason ->
                            eventHelper.sendCloseEvent(
                                AdConstants.AD_TYPE_BANNER,
                                posId,
                                mapOf("reason" to reason, "mixedMode" to true)
                            )
                        }
                    }
                }
                mediationBuilder.setMediationNativeToBannerListener(mixedModeListener)
                Log.d(TAG, "Banner混出信息流模式已启用")
                requestLog["enableMixedMode"] = true
            }

            if (call.hasArgument("extraParams")) {
                val extraParams = call.argument<Map<String, Any?>>("extraParams")
                extraParams?.forEach { (key, value) ->
                    if (value != null) {
                        mediationBuilder.setExtraObject(key, value)
                    }
                }
                if (!extraParams.isNullOrEmpty()) {
                    requestLog["extraParams"] = extraParams
                }
            }

            if (call.hasArgument("extraData")) {
                val extraData = call.argument<Map<String, Any?>>("extraData")
                extraData?.forEach { (key, value) ->
                    if (value != null) {
                        mediationBuilder.setExtraObject(key, value)
                    }
                }
                if (!extraData.isNullOrEmpty()) {
                    requestLog["extraData"] = extraData
                }
            }

            logger.logAdRequest(AdConstants.AD_TYPE_BANNER, posId, requestLog)

            // 设置MediationAdSlot
            adSlotBuilder.setMediationAdSlot(mediationBuilder.build())
            val adSlot = adSlotBuilder.build()

            // 创建TTAdNative对象
            val adNativeLoader = TTAdSdk.getAdManager().createAdNative(nonNullActivity)

            val resultSent = AtomicBoolean(false)

            // 创建加载监听器
            adListener = object : TTAdNative.NativeExpressAdListener {
                override fun onNativeExpressAdLoad(ads: MutableList<TTNativeExpressAd>?) {
                    isLoading.set(false)

                    if (!ads.isNullOrEmpty()) {
                        isLoaded.set(true)
                        bannerAd = ads[0]

                        logger.logAdSuccess(AdConstants.AD_TYPE_BANNER, "加载", posId, "Banner广告加载成功")
                        eventHelper.sendLoadSuccessEvent(AdConstants.AD_TYPE_BANNER, posId)

                        // 设置交互监听器
                        setupInteractionListener(bannerAd!!, posId)

                        if (!resultSent.getAndSet(true)) {
                            result.success(true)
                        }
                    } else {
                        val errorMsg = "Banner广告加载成功，但列表为空"
                        logger.logAdError(AdConstants.AD_TYPE_BANNER, "加载", posId, -1, errorMsg)
                        eventHelper.sendLoadFailEvent(AdConstants.AD_TYPE_BANNER, posId, -1, errorMsg)
                        if (!resultSent.getAndSet(true)) {
                            result.error(AdConstants.ErrorCodes.LOAD_ERROR, errorMsg, null)
                        }
                    }
                }

                override fun onError(code: Int, message: String?) {
                    isLoading.set(false)
                    isLoaded.set(false)

                    val errorMsg = message ?: "未知错误"
                    logger.logAdError(AdConstants.AD_TYPE_BANNER, "加载", posId, code, errorMsg)
                    eventHelper.sendLoadFailEvent(AdConstants.AD_TYPE_BANNER, posId, code, errorMsg)

                    // 清理资源
                    cleanupBannerAd()

                    if (!resultSent.getAndSet(true)) {
                        result.error(AdConstants.ErrorCodes.LOAD_ERROR, "Banner广告加载失败: $errorMsg", code)
                    }
                }
            }

            // 开始加载广告
            adNativeLoader.loadBannerExpressAd(adSlot, adListener)

        } catch (e: Exception) {
            isLoading.set(false)
            val errorMsg = e.message ?: "未知异常"
            logger.logAdError(AdConstants.AD_TYPE_BANNER, "加载异常", posId, -1, errorMsg)
            isLoading.set(false)
            result.error(AdConstants.ErrorCodes.LOAD_ERROR, "Banner广告加载异常: $errorMsg", null)
        }
    }

    override fun show(call: MethodCall, result: Result) {
        val ad = bannerAd
        if (!isReady() || ad == null) {
            result.error(AdConstants.ErrorCodes.LOAD_ERROR, "Banner广告尚未加载完成或已销毁", null)
            return
        }

        val activity = getCurrentActivity()
        if (activity == null) {
            result.error(AdConstants.ErrorCodes.NO_ACTIVITY, "Activity不可用", null)
            return
        }

        val adView = ad.expressAdView
        if (adView == null) {
            result.error(AdConstants.ErrorCodes.LOAD_ERROR, "Banner广告视图不可用", null)
            return
        }

        activity.runOnUiThread {
            try {
                val container = ensureBannerContainer(activity)
                if (container == null) {
                    logger.logAdError(AdConstants.AD_TYPE_BANNER, "显示", currentPosId, -1, "未找到可用于承载Banner的根视图")
                    result.error(AdConstants.ErrorCodes.SHOW_ERROR, "未找到可用于展示Banner的容器", null)
                    return@runOnUiThread
                }

                container.removeAllViews()
                (adView.parent as? ViewGroup)?.removeView(adView)

                val layoutParams = createBannerLayoutParams()
                container.addView(adView, layoutParams)

                logger.logAdSuccess(AdConstants.AD_TYPE_BANNER, "显示", currentPosId, "Banner广告手动展示")
                eventHelper.sendShowEvent(AdConstants.AD_TYPE_BANNER, currentPosId)
                result.success(true)
            } catch (e: Exception) {
                val message = e.message ?: "未知异常"
                logger.logAdError(AdConstants.AD_TYPE_BANNER, "显示", currentPosId, -1, message)
                result.error(AdConstants.ErrorCodes.SHOW_ERROR, "Banner广告展示异常: $message", null)
            }
        }
    }

    override fun destroy() {
        logger.logAdLifecycle(AdConstants.AD_TYPE_BANNER, currentPosId, "开始销毁")
        cleanupBannerAd()
        removeBannerContainer()
        eventHelper.sendBannerEvent(AdConstants.Events.BANNER_DESTROYED, currentPosId)
        logger.logAdLifecycle(AdConstants.AD_TYPE_BANNER, currentPosId, "销毁完成")
        isLoading.set(false)
        isLoaded.set(false)
        currentPosId = ""
    }

    override fun isReady(): Boolean {
        return isLoaded.get() && bannerAd != null
    }

    fun getAdLoadInfo(): List<Map<String, Any>> {
        return AdDiagnosticsHelper.getAdLoadInfo(bannerAd?.mediationManager)
    }

    /**
     * 设置交互监听器
     */
    private fun setupInteractionListener(ad: TTNativeExpressAd, posId: String) {
        try {
            // 设置交互监听器
            interactionListener = object : TTNativeExpressAd.ExpressAdInteractionListener {
                override fun onAdClicked(view: View?, type: Int) {
                    logger.logAdSuccess(AdConstants.AD_TYPE_BANNER, "点击", posId, "Banner广告被点击")
                    eventHelper.sendClickEvent(AdConstants.AD_TYPE_BANNER, posId)
                }

                override fun onAdShow(view: View?, type: Int) {
                    logger.logAdSuccess(AdConstants.AD_TYPE_BANNER, "展示", posId, "Banner广告展示成功")
                    eventHelper.sendShowEvent(AdConstants.AD_TYPE_BANNER, posId)

                    // 获取ECPM信息
                    getEcpmInfo(ad, posId)
                }

                override fun onRenderFail(view: View?, msg: String?, code: Int) {
                    val errorMsg = msg ?: "渲染失败"
                    logger.logAdError(AdConstants.AD_TYPE_BANNER, "渲染", posId, code, errorMsg)
                    eventHelper.sendBannerErrorEvent(AdConstants.Events.BANNER_RENDER_FAIL, posId, code, errorMsg)
                }

                override fun onRenderSuccess(view: View?, width: Float, height: Float) {
                    logger.logAdSuccess(AdConstants.AD_TYPE_BANNER, "渲染", posId, "Banner广告渲染成功")
                    eventHelper.sendBannerEvent(AdConstants.Events.BANNER_RENDER_SUCCESS, posId, mapOf(
                        "width" to width,
                        "height" to height
                    ))
                }
            }

            ad.setExpressInteractionListener(interactionListener)

            // 设置dislike回调
            dislikeCallback = object : TTAdDislike.DislikeInteractionCallback {
                override fun onShow() {
                    Log.d(TAG, "Banner dislike dialog show")
                }

                override fun onSelected(position: Int, value: String?, enforce: Boolean) {
                    logger.logAdSuccess(AdConstants.AD_TYPE_BANNER, "关闭", posId, "Banner广告Dislike选中")
                    eventHelper.sendCloseEvent(AdConstants.AD_TYPE_BANNER, posId, mapOf(
                        "position" to position,
                        "value" to (value ?: ""),
                        "enforce" to enforce
                    ))
                }

                override fun onCancel() {
                    Log.d(TAG, "Banner dislike dialog cancel")
                }
            }

            getCurrentActivity()?.let { activity ->
                ad.setDislikeCallback(activity, dislikeCallback)
            }

        } catch (e: Exception) {
            Log.w(TAG, "设置Banner交互监听器异常: ${e.message}")
        }
    }

    /**
     * 获取ECPM信息（按照官方文档）
     */
    private fun getEcpmInfo(ad: TTNativeExpressAd, posId: String) {
        try {
            val mediationManager: MediationNativeManager? = ad.mediationManager
            mediationManager?.let { manager ->
                val showEcpm: MediationAdEcpmInfo? = manager.showEcpm
                showEcpm?.let { ecpmInfo ->
                    val ecpmData = mapOf(
                        "ecpm" to (ecpmInfo.ecpm ?: "0"),
                        "platform" to (ecpmInfo.sdkName ?: ""),
                        "ritID" to (ecpmInfo.slotId ?: ""),
                        "requestID" to (ecpmInfo.requestId ?: ""),
                        "customSdkName" to (ecpmInfo.customSdkName ?: ""),
                        "reqBiddingType" to (ecpmInfo.reqBiddingType ?: 0),
                        "ritType" to (ecpmInfo.ritType ?: 0),
                        "abTestId" to (ecpmInfo.abTestId ?: ""),
                        "scenarioId" to (ecpmInfo.scenarioId ?: ""),
                        "segmentId" to (ecpmInfo.segmentId ?: 0),
                        "channel" to (ecpmInfo.channel ?: ""),
                        "subChannel" to (ecpmInfo.subChannel ?: "")
                    )

                    eventHelper.sendBannerEcpmEvent(posId, ecpmData)
                    Log.d(TAG, "Banner ECPM信息：$ecpmData")
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "获取Banner ECPM信息异常: ${e.message}")
        }
    }

    /**
     * 清理Banner广告资源
     */
    private fun cleanupBannerAd() {
        try {
            bannerAd?.let { ad ->
                // 移除监听器
                ad.setExpressInteractionListener(null)

                // 从父视图中移除
                val adView = ad.expressAdView
                adView?.let { view ->
                    (view.parent as? ViewGroup)?.removeView(view)
                }

                // 销毁广告
                ad.destroy()
            }

            bannerAd = null
            adListener = null
            interactionListener = null
            dislikeCallback = null
            isLoaded.set(false)
            bannerContainer?.removeAllViews()

        } catch (e: Exception) {
            Log.w(TAG, "清理Banner广告资源异常: ${e.message}")
        }
    }

    private fun ensureBannerContainer(activity: Activity): FrameLayout? {
        val root = activity.findViewById<ViewGroup>(android.R.id.content) ?: return null
        val existing = bannerContainer
        if (existing != null) {
            if (existing.parent != root) {
                (existing.parent as? ViewGroup)?.removeView(existing)
                root.addView(existing, createContainerLayoutParams(root))
            }
            return existing
        }

        val container = FrameLayout(activity).apply {
            tag = CONTAINER_TAG
        }
        root.addView(container, createContainerLayoutParams(root))
        bannerContainer = container
        return container
    }

    private fun createContainerLayoutParams(root: ViewGroup): ViewGroup.LayoutParams {
        return if (root is FrameLayout) {
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply {
                gravity = Gravity.BOTTOM
            }
        } else {
            ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        }
    }

    private fun createBannerLayoutParams(): FrameLayout.LayoutParams {
        return FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            gravity = Gravity.CENTER_HORIZONTAL
        }
    }

    private fun removeBannerContainer() {
        bannerContainer?.let { container ->
            container.removeAllViews()
            (container.parent as? ViewGroup)?.removeView(container)
        }
        bannerContainer = null
    }
}
