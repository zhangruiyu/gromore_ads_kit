package com.zhecent.gromore_ads_kit.views

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import com.bytedance.sdk.openadsdk.TTDrawFeedAd
import com.bytedance.sdk.openadsdk.TTFeedAd
import com.bytedance.sdk.openadsdk.TTNativeAd
import com.bytedance.sdk.openadsdk.mediation.ad.MediationExpressRenderListener
import com.zhecent.gromore_ads_kit.common.AdConstants
import com.zhecent.gromore_ads_kit.managers.DrawFeedAdManager
import com.zhecent.gromore_ads_kit.utils.AdEventHelper
import com.zhecent.gromore_ads_kit.utils.AdLogger
import com.zhecent.gromore_ads_kit.utils.UIUtils
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView

/**
 * Draw信息流广告PlatformView
 */
class GromoreAdsKitDrawFeedView(
    private val context: Context,
    messenger: BinaryMessenger,
    viewId: Int,
    creationParams: Map<String, Any>,
    private val drawFeedAdManager: DrawFeedAdManager,
    private val eventHelper: AdEventHelper,
    private val logger: AdLogger
) : PlatformView, MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = AdConstants.TAG
    }

    private val containerView: FrameLayout = FrameLayout(context)
    private val methodChannel = MethodChannel(messenger, "gromore_ads_kit_draw_feed_$viewId")
    private val mainHandler = Handler(Looper.getMainLooper())

    private val requestedPosId: String = creationParams["posId"] as? String ?: ""
    private val adId: Int = (creationParams["adId"] as? Number)?.toInt() ?: -1
    private val widthDp: Int = (creationParams["width"] as? Number)?.toInt() ?: 0
    private val heightDp: Int = (creationParams["height"] as? Number)?.toInt() ?: 0

    private val widthPx: Int = UIUtils.dp2px(context, widthDp)
    private val heightPx: Int = UIUtils.dp2px(context, heightDp)

    private var drawFeedAd: TTDrawFeedAd? = null
    private var actualPosId: String = requestedPosId
    private var expressAd: Boolean = true

    init {
        methodChannel.setMethodCallHandler(this)
        containerView.layoutParams = FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        )
        bindAd()
    }

    override fun getView(): View = containerView

    override fun dispose() {
        methodChannel.setMethodCallHandler(null)
        releaseAd()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "refresh" -> {
                drawFeedAd?.let {
                    try {
                        it.render()
                        result.success(true)
                    } catch (e: Exception) {
                        Log.w(TAG, "Draw信息流广告刷新失败", e)
                        result.error("REFRESH_FAILED", e.message, null)
                    }
                } ?: result.error("NO_AD", "Draw feed ad not available", null)
            }
            else -> result.notImplemented()
        }
    }

    private fun bindAd() {
        if (requestedPosId.isEmpty() || adId == -1) {
            notifyFlutter("onAdError", "广告参数无效")
            logger.logAdError(
                AdConstants.AD_TYPE_DRAW_FEED,
                "Bind",
                requestedPosId,
                -1,
                "参数无效 posId=$requestedPosId, adId=$adId"
            )
            return
        }

        val payload = drawFeedAdManager.takeDrawFeedAd(adId)
        if (payload == null) {
            notifyFlutter("onAdError", "Draw信息流广告不存在或已被使用")
            logger.logAdError(
                AdConstants.AD_TYPE_DRAW_FEED,
                "Bind",
                requestedPosId,
                -1,
                "广告不存在或已被移除 adId=$adId"
            )
            return
        }

        drawFeedAd = payload.ad
        actualPosId = payload.posId
        expressAd = payload.isExpress

        notifyFlutter("onAdLoaded", null)
        logger.logAdSuccess(AdConstants.AD_TYPE_DRAW_FEED, "Bind", actualPosId, "adId=$adId")

        setupListeners(payload)
        try {
            if (payload.isExpress) {
                payload.ad.render()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Draw信息流广告渲染异常", e)
            val message = e.message ?: "render error"
            notifyFlutter("onAdRenderFail", message)
            eventHelper.sendLoadFailEvent(AdConstants.AD_TYPE_DRAW_FEED, actualPosId, -1, message)
        }
    }

    private fun setupListeners(payload: DrawFeedAdManager.DrawFeedAdPayload) {
        val ad = payload.ad
        val mediationManager = ad.mediationManager
        if (payload.isExpress && mediationManager?.isExpress == true) {
            ad.setExpressRenderListener(object : MediationExpressRenderListener {
                override fun onRenderSuccess(view: View?, width: Float, height: Float, isExpress: Boolean) {
                    logger.logAdSuccess(AdConstants.AD_TYPE_DRAW_FEED, "渲染成功", actualPosId, "adId=$adId")
                    attachAdView(view)
                    notifyFlutter("onAdRenderSuccess", null)
                }

                override fun onAdClick() {
                    logger.logAdSuccess(AdConstants.AD_TYPE_DRAW_FEED, "点击", actualPosId, "adId=$adId")
                    notifyFlutter("onAdClicked", null)
                    eventHelper.sendClickEvent(AdConstants.AD_TYPE_DRAW_FEED, actualPosId, mapOf("adId" to adId))
                }

                override fun onAdShow() {
                    logger.logAdSuccess(AdConstants.AD_TYPE_DRAW_FEED, "展示", actualPosId, "adId=$adId")
                    eventHelper.sendShowEvent(AdConstants.AD_TYPE_DRAW_FEED, actualPosId, mapOf("adId" to adId))
                }

                override fun onRenderFail(view: View?, msg: String?, code: Int) {
                    val errorMsg = msg ?: "render fail"
                    logger.logAdError(AdConstants.AD_TYPE_DRAW_FEED, "渲染失败", actualPosId, code, errorMsg)
                    notifyFlutter("onAdRenderFail", errorMsg)
                    eventHelper.sendLoadFailEvent(AdConstants.AD_TYPE_DRAW_FEED, actualPosId, code, errorMsg)
                }
            })
        } else {
            setupNativeAd(ad)
        }

        try {
            ad.setVideoAdListener(object : TTFeedAd.VideoAdListener {
                override fun onVideoLoad(feedAd: TTFeedAd) {}

                override fun onVideoError(errorCode: Int, extraCode: Int) {
                    logger.logAdError(AdConstants.AD_TYPE_DRAW_FEED, "视频播放失败", actualPosId, errorCode, "extra=$extraCode")
                }

                override fun onVideoAdStartPlay(feedAd: TTFeedAd) {}

                override fun onVideoAdPaused(feedAd: TTFeedAd) {}

                override fun onVideoAdContinuePlay(feedAd: TTFeedAd) {}

                override fun onProgressUpdate(current: Long, duration: Long) {}

                override fun onVideoAdComplete(feedAd: TTFeedAd) {}
            })

            ad.setDrawVideoListener(object : TTDrawFeedAd.DrawVideoListener {
                override fun onClickRetry() {
                    logger.logAdError(AdConstants.AD_TYPE_DRAW_FEED, "点击重试", actualPosId, -1, "adId=$adId")
                }

                override fun onClick() {
                    logger.logAdSuccess(AdConstants.AD_TYPE_DRAW_FEED, "视频点击", actualPosId, "adId=$adId")
                }
            })
        } catch (e: Exception) {
            Log.w(TAG, "设置Draw视频监听失败", e)
        }
    }

    private fun setupNativeAd(ad: TTDrawFeedAd) {
        val activity = context.findActivity()
        if (activity == null) {
            val message = "自渲染Draw信息流需要Activity"
            notifyFlutter("onAdError", message)
            eventHelper.sendLoadFailEvent(AdConstants.AD_TYPE_DRAW_FEED, actualPosId, -1, message)
            return
        }

        try {
            val layout = buildNativeAdLayout(context, ad, widthPx, heightPx)
            ad.registerViewForInteraction(
                activity,
                layout.root,
                layout.clickViews,
                layout.creativeViews,
                emptyList(),
                object : TTNativeAd.AdInteractionListener {
                    override fun onAdClicked(view: View, nativeAd: TTNativeAd) {
                        notifyFlutter("onAdClicked", null)
                        eventHelper.sendClickEvent(AdConstants.AD_TYPE_DRAW_FEED, actualPosId, mapOf("adId" to adId))
                    }

                    override fun onAdCreativeClick(view: View, nativeAd: TTNativeAd) {
                        notifyFlutter("onAdClicked", null)
                        eventHelper.sendClickEvent(AdConstants.AD_TYPE_DRAW_FEED, actualPosId, mapOf("adId" to adId))
                    }

                    override fun onAdShow(nativeAd: TTNativeAd) {
                        eventHelper.sendShowEvent(AdConstants.AD_TYPE_DRAW_FEED, actualPosId, mapOf("adId" to adId))
                    }
                },
                layout.binder
            )
            setupNativeDislike(ad, activity, layout.dislikeButton)
            attachAdView(layout.root)
            notifyFlutter("onAdRenderSuccess", null)
        } catch (e: Exception) {
            val message = e.message ?: "native render error"
            logger.logAdError(AdConstants.AD_TYPE_DRAW_FEED, "自渲染", actualPosId, -1, message)
            notifyFlutter("onAdRenderFail", message)
        }
    }

    private fun setupNativeDislike(ad: TTDrawFeedAd, activity: android.app.Activity, dislikeButton: android.widget.Button) {
        val dialog = ad.getDislikeDialog(activity)
        dialog.setDislikeInteractionCallback(object : com.bytedance.sdk.openadsdk.TTAdDislike.DislikeInteractionCallback {
            override fun onShow() {}
            override fun onSelected(position: Int, value: String?, enforce: Boolean) {
                notifyFlutter("onAdClosed", null)
                eventHelper.sendCloseEvent(AdConstants.AD_TYPE_DRAW_FEED, actualPosId, mapOf("adId" to adId, "reason" to (value ?: "dislike")))
            }
            override fun onCancel() {}
        })
        dislikeButton.setOnClickListener { dialog.showDislikeDialog() }
    }

    private fun attachAdView(view: View?) {
        val adView = view ?: drawFeedAd?.adView
        if (adView == null) {
            Log.w(TAG, "Draw信息流广告View为空")
            return
        }
        containerView.removeAllViews()
        (adView.parent as? ViewGroup)?.removeView(adView)

        val layoutParams = FrameLayout.LayoutParams(
            if (widthPx > 0) widthPx else FrameLayout.LayoutParams.WRAP_CONTENT,
            if (heightPx > 0) heightPx else FrameLayout.LayoutParams.WRAP_CONTENT
        )
        containerView.addView(adView, layoutParams)
    }

    private fun releaseAd() {
        drawFeedAd?.let {
            try {
                it.destroy()
                logger.logAdLifecycle(AdConstants.AD_TYPE_DRAW_FEED, actualPosId, "广告销毁 adId=$adId")
                notifyFlutter("onAdClosed", null)
                eventHelper.sendCloseEvent(
                    AdConstants.AD_TYPE_DRAW_FEED,
                    actualPosId,
                    mapOf("adId" to adId, "reason" to "dispose")
                )
            } catch (e: Exception) {
                Log.w(TAG, "销毁Draw信息流广告失败", e)
            }
        }
        drawFeedAd = null
    }

    private fun notifyFlutter(method: String, argument: Any?) {
        mainHandler.post {
            methodChannel.invokeMethod(method, argument)
        }
    }
}
