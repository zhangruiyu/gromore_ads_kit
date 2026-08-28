package com.zhecent.gromore_ads_kit.views

import android.content.Context
import android.util.Log
import android.view.View
import android.widget.FrameLayout
import com.bytedance.sdk.openadsdk.*
import com.bytedance.sdk.openadsdk.mediation.ad.MediationAdSlot
import com.bytedance.sdk.openadsdk.mediation.manager.MediationAdEcpmInfo
import com.bytedance.sdk.openadsdk.mediation.manager.MediationNativeManager
import io.flutter.plugin.platform.PlatformView
import com.zhecent.gromore_ads_kit.common.AdConstants
import com.zhecent.gromore_ads_kit.utils.AdEventHelper
import com.zhecent.gromore_ads_kit.utils.AdLogger
import com.zhecent.gromore_ads_kit.utils.UIUtils

/**
 * Banner广告原生视图
 * 实现Flutter PlatformView接口，用于在Flutter中显示Banner广告
 */
class GromoreAdsKitBannerView(
    private val context: Context,
    private val viewId: Int,
    creationParams: Map<String, Any>
) : PlatformView {

    companion object {
        private const val TAG = AdConstants.TAG
    }

    // 根容器
    private val containerView: FrameLayout = FrameLayout(context)

    // 广告参数
    private val posId: String = creationParams["posId"] as? String ?: ""
    private val width: Int = creationParams["width"] as? Int ?: 375
    private val height: Int = creationParams["height"] as? Int ?: 60
    private val enableMixedMode: Boolean = creationParams["enableMixedMode"] as? Boolean ?: false
    private val options: Map<String, Any> = creationParams

    // 广告实例
    private var bannerAd: TTNativeExpressAd? = null
    private var isLoading = false
    private var isLoaded = false

    // 工具类
    private val eventHelper = AdEventHelper.getInstance()
    private val logger = AdLogger.getInstance()

    init {
        setupContainer()
        loadBannerAd()
    }

    /**
     * 设置容器视图
     */
    private fun setupContainer() {
        containerView.layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        )

        Log.d(TAG, "Banner PlatformView 容器已创建: viewId=$viewId, posId=$posId, size=${width}x${height}")
    }

    /**
     * 加载Banner广告
     */
    private fun loadBannerAd() {
        if (posId.isEmpty()) {
            Log.e(TAG, "Banner PlatformView posId为空")
            return
        }

        if (isLoading) {
            Log.w(TAG, "Banner PlatformView 正在加载中: posId=$posId")
            return
        }

        isLoading = true
        isLoaded = false

        Log.d(TAG, "Banner PlatformView 开始加载: posId=$posId, size=${width}x${height}")

        try {
            // 使用UIUtils将dp转换为px
            val widthPx = UIUtils.dp2px(context, width)
            val heightPx = UIUtils.dp2px(context, height)

            Log.d(TAG, "Banner PlatformView 尺寸转换: ${width}x${height}dp -> ${widthPx}x${heightPx}px")

            // 创建AdSlot对象（按照官方文档，使用SDK默认配置）
            val mediationBuilder = MediationAdSlot.Builder()
            (options["mutedIfCan"] as? Boolean)?.let(mediationBuilder::setMuted)
            (options["volume"] as? Number)?.toFloat()?.coerceIn(0f, 1f)?.let(mediationBuilder::setVolume)
            (options["bidNotify"] as? Boolean)?.let(mediationBuilder::setBidNotify)
            (options["scenarioId"] as? String)?.takeIf(String::isNotBlank)?.let(mediationBuilder::setScenarioId)
            (options["useSurfaceView"] as? Boolean)?.let(mediationBuilder::setUseSurfaceView)
            (options["extraParams"] as? Map<*, *>)?.forEach { (key, value) ->
                if (key is String && value != null) {
                    mediationBuilder.setExtraObject(key, value)
                }
            }
            if (enableMixedMode) {
                mediationBuilder.setMediationNativeToBannerListener(
                    object : com.bytedance.sdk.openadsdk.mediation.ad.MediationNativeToBannerListener() {
                        override fun getMediationBannerViewFromNativeAd(
                            nativeAdInfo: com.bytedance.sdk.openadsdk.mediation.ad.IMediationNativeAdInfo?
                        ): View? {
                            val info = nativeAdInfo ?: return null
                            val activity = context.findActivity() ?: return null
                            return buildMixedBannerView(activity, info, widthPx, heightPx) { reason ->
                                eventHelper.sendCloseEvent(
                                    AdConstants.AD_TYPE_BANNER,
                                    posId,
                                    mapOf("reason" to reason, "mixedMode" to true)
                                )
                            }
                        }
                    }
                )
            }

            val adSlot = AdSlot.Builder()
                .setCodeId(posId)
                .setImageAcceptedSize(widthPx, heightPx) // 单位px
                .setMediationAdSlot(mediationBuilder.build())
                .build()

            // 创建TTAdNative对象
            val adNativeLoader = TTAdSdk.getAdManager().createAdNative(context)

            // 创建加载监听器
            val adListener = object : TTAdNative.NativeExpressAdListener {
                override fun onNativeExpressAdLoad(ads: MutableList<TTNativeExpressAd>?) {
                    isLoading = false

                    if (!ads.isNullOrEmpty()) {
                        isLoaded = true
                        bannerAd = ads[0]

                        Log.d(TAG, "Banner PlatformView 加载成功: posId=$posId")

                        // 设置交互监听器
                        setupInteractionListener(bannerAd!!)

                        // 渲染广告（显示将在onRenderSuccess回调中处理）
                        bannerAd!!.render()

                        // 发送加载成功事件
                        eventHelper.sendLoadSuccessEvent(AdConstants.AD_TYPE_BANNER, posId)
                    } else {
                        val errorMsg = "Banner PlatformView 加载成功，但列表为空"
                        Log.e(TAG, errorMsg)
                        eventHelper.sendLoadFailEvent(AdConstants.AD_TYPE_BANNER, posId, -1, errorMsg)
                    }
                }

                override fun onError(code: Int, message: String?) {
                    isLoading = false
                    isLoaded = false

                    val errorMsg = message ?: "未知错误"
                    Log.e(TAG, "Banner PlatformView 加载失败: posId=$posId, code=$code, msg=$errorMsg")
                    eventHelper.sendLoadFailEvent(AdConstants.AD_TYPE_BANNER, posId, code, errorMsg)
                }
            }

            // 开始加载广告
            adNativeLoader.loadBannerExpressAd(adSlot, adListener)

        } catch (e: Exception) {
            isLoading = false
            val errorMsg = e.message ?: "未知异常"
            Log.e(TAG, "Banner PlatformView 加载异常: posId=$posId, error=$errorMsg", e)
            eventHelper.sendLoadFailEvent(AdConstants.AD_TYPE_BANNER, posId, -1, errorMsg)
        }
    }

    /**
     * 显示Banner广告
     */
    private fun displayBannerAd(ad: TTNativeExpressAd) {
        try {
            val adView = ad.expressAdView
            if (adView != null) {
                // 清除之前的广告视图
                containerView.removeAllViews()

                // 移除广告视图的旧父容器（如果有）
                (adView.parent as? android.view.ViewGroup)?.removeView(adView)

                // 测量广告视图的实际尺寸
                adView.measure(
                    View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
                    View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
                )
                val measuredWidth = adView.measuredWidth
                val measuredHeight = adView.measuredHeight

                Log.d(TAG, "Banner PlatformView 测量尺寸: ${measuredWidth}x${measuredHeight}px")

                // 设置广告视图的布局参数，使用测量尺寸
                val layoutParams = FrameLayout.LayoutParams(
                    if (measuredWidth > 0) measuredWidth else FrameLayout.LayoutParams.WRAP_CONTENT,
                    if (measuredHeight > 0) measuredHeight else FrameLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    gravity = android.view.Gravity.CENTER
                }

                // 添加到容器中
                containerView.addView(adView, layoutParams)

                Log.d(TAG, "Banner PlatformView 显示成功: posId=$posId, 实际显示尺寸: ${layoutParams.width}x${layoutParams.height}px")
            } else {
                Log.e(TAG, "Banner PlatformView expressAdView为null: posId=$posId")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Banner PlatformView 显示异常: posId=$posId, error=${e.message}", e)
        }
    }

    /**
     * 设置交互监听器
     */
    private fun setupInteractionListener(ad: TTNativeExpressAd) {
        try {
            // 设置交互监听器
            val interactionListener = object : TTNativeExpressAd.ExpressAdInteractionListener {
                override fun onAdClicked(view: View?, type: Int) {
                    Log.d(TAG, "Banner PlatformView 被点击: posId=$posId")
                    eventHelper.sendClickEvent(AdConstants.AD_TYPE_BANNER, posId)
                }

                override fun onAdShow(view: View?, type: Int) {
                    Log.d(TAG, "Banner PlatformView 展示成功: posId=$posId")
                    eventHelper.sendShowEvent(AdConstants.AD_TYPE_BANNER, posId)

                    // 获取ECPM信息
                    getEcpmInfo(ad)
                }

                override fun onRenderFail(view: View?, msg: String?, code: Int) {
                    val errorMsg = msg ?: "渲染失败"
                    Log.e(TAG, "Banner PlatformView 渲染失败: posId=$posId, code=$code, msg=$errorMsg")
                    eventHelper.sendBannerErrorEvent(AdConstants.Events.BANNER_RENDER_FAIL, posId, code, errorMsg)
                }

                override fun onRenderSuccess(view: View?, width: Float, height: Float) {
                    Log.d(TAG, "Banner PlatformView 渲染成功: posId=$posId, size=${width}x${height}")

                    // 渲染成功后显示广告（参照成功的参考插件实现）
                    val adView = bannerAd?.expressAdView
                    if (bannerAd != null && adView != null) {
                        containerView.removeAllViews()

                        // 移除广告视图的旧父容器（如果有）
                        (adView.parent as? android.view.ViewGroup)?.removeView(adView)

                        // 关键：使用参考插件的布局参数 MATCH_PARENT, WRAP_CONTENT
                        val adParams = FrameLayout.LayoutParams(
                            FrameLayout.LayoutParams.MATCH_PARENT,
                            FrameLayout.LayoutParams.WRAP_CONTENT
                        ).apply {
                            gravity = android.view.Gravity.CENTER
                        }

                        containerView.addView(adView, adParams)
                        Log.d(TAG, "Banner PlatformView 添加到容器成功")
                    } else {
                        Log.e(TAG, "Banner PlatformView adView为null，无法显示")
                    }

                    eventHelper.sendBannerEvent(AdConstants.Events.BANNER_RENDER_SUCCESS, posId, mapOf(
                        "width" to width,
                        "height" to height
                    ))
                }
            }

            ad.setExpressInteractionListener(interactionListener)

            // 设置dislike回调
            val dislikeCallback = object : TTAdDislike.DislikeInteractionCallback {
                override fun onShow() {
                    Log.d(TAG, "Banner PlatformView dislike dialog show: posId=$posId")
                }

                override fun onSelected(position: Int, value: String?, enforce: Boolean) {
                    Log.d(TAG, "Banner PlatformView dislike选中: posId=$posId")
                    eventHelper.sendCloseEvent(AdConstants.AD_TYPE_BANNER, posId, mapOf(
                        "position" to position,
                        "value" to (value ?: ""),
                        "enforce" to enforce
                    ))
                }

                override fun onCancel() {
                    Log.d(TAG, "Banner PlatformView dislike dialog cancel: posId=$posId")
                }
            }

            context.findActivity()?.let { activity ->
                ad.setDislikeCallback(activity, dislikeCallback)
            }

        } catch (e: Exception) {
            Log.w(TAG, "Banner PlatformView 设置交互监听器异常: posId=$posId, error=${e.message}", e)
        }
    }

    /**
     * 获取ECPM信息
     */
    private fun getEcpmInfo(ad: TTNativeExpressAd) {
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
                    Log.d(TAG, "Banner PlatformView ECPM信息: $ecpmData")
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Banner PlatformView 获取ECPM信息异常: posId=$posId, error=${e.message}", e)
        }
    }

    /**
     * 清理资源
     */
    private fun cleanup() {
        try {
            bannerAd?.let { ad ->
                // 移除监听器
                ad.setExpressInteractionListener(null)

                // 从容器中移除
                val adView = ad.expressAdView
                containerView.removeAllViews()

                // 销毁广告
                ad.destroy()
            }

            bannerAd = null
            isLoading = false
            isLoaded = false

            Log.d(TAG, "Banner PlatformView 资源已清理: posId=$posId")

        } catch (e: Exception) {
            Log.w(TAG, "Banner PlatformView 清理资源异常: posId=$posId, error=${e.message}", e)
        }
    }

    // PlatformView 接口实现
    override fun getView(): View {
        return containerView
    }

    override fun dispose() {
        Log.d(TAG, "Banner PlatformView dispose: viewId=$viewId, posId=$posId")
        cleanup()
        eventHelper.sendBannerEvent(AdConstants.Events.BANNER_DESTROYED, posId)
    }
}
