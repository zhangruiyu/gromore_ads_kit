package com.zhecent.gromore_ads_kit.managers

import android.app.Activity
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import com.bytedance.sdk.openadsdk.AdSlot
import com.bytedance.sdk.openadsdk.CSJAdError
import com.bytedance.sdk.openadsdk.CSJSplashAd
import com.bytedance.sdk.openadsdk.TTAdNative
import com.bytedance.sdk.openadsdk.TTAdSdk
import com.bytedance.sdk.openadsdk.mediation.MediationConstant
import com.bytedance.sdk.openadsdk.mediation.ad.MediationAdSlot
import com.bytedance.sdk.openadsdk.mediation.ad.MediationSplashRequestInfo
import com.bytedance.sdk.openadsdk.mediation.manager.MediationAdEcpmInfo
import com.zhecent.gromore_ads_kit.common.AdConstants
import com.zhecent.gromore_ads_kit.common.BaseAdManager
import com.zhecent.gromore_ads_kit.common.SimpleAdManagerInterface
import com.zhecent.gromore_ads_kit.utils.AdEventHelper
import com.zhecent.gromore_ads_kit.utils.AdDiagnosticsHelper
import com.zhecent.gromore_ads_kit.utils.AdLogger
import com.zhecent.gromore_ads_kit.utils.AdValidationHelper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import java.io.InputStream
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.max
import kotlin.math.min
import org.json.JSONObject

/**
 * 开屏广告管理器 - 负责开屏广告的加载、展示、事件派发
 */
class SplashAdManager(
    eventHelper: AdEventHelper,
    validationHelper: AdValidationHelper = AdValidationHelper.getInstance(),
    logger: AdLogger = AdLogger.getInstance(),
    private val flutterPluginBinding: FlutterPlugin.FlutterPluginBinding? = null
) : BaseAdManager(eventHelper, validationHelper, logger), SimpleAdManagerInterface {

    private enum class LogoSource { ASSET, FILE, RESOURCE, BUNDLE }

    private data class LogoConfig(
        val source: LogoSource,
        val value: String,
        val heightDp: Double?,
        val heightRatio: Double?,
        val backgroundColor: Int?
    )

    private data class FallbackConfig(
        val adnName: String,
        val slotId: String,
        val appId: String,
        val appKey: String?
    )

    private data class AndroidOptions(
        val muted: Boolean?,
        val volume: Float?,
        val useSurfaceView: Boolean?,
        val bidNotify: Boolean?,
        val shakeButton: Boolean?,
        val enablePreload: Boolean?,
        val scenarioId: String?,
        val extras: Map<String, Any>?,
        val customData: Map<String, Any>?,
        val fallback: FallbackConfig?
    )

    private var currentSplashAd: CSJSplashAd? = null
    private var currentPosId: String = ""
    private var currentLogoConfig: LogoConfig? = null
    private var currentAndroidOptions: AndroidOptions? = null

    private var preloadedSplashAd: CSJSplashAd? = null
    private var preloadedPosId: String? = null
    private var preloadedLogoConfig: LogoConfig? = null
    private var preloadedAndroidOptions: AndroidOptions? = null

    private var splashContainer: FrameLayout? = null
    private var splashContentHeightPx: Int = 0
    private var splashLogoHeightPx: Int = 0

    override fun show(call: MethodCall, result: Result) {
        val posId = call.argument<String>("posId")?.takeIf { it.isNotBlank() }
        val activity = getCurrentActivity()

        if (posId == null) {
            result.error(AdConstants.ErrorCodes.INVALID_POS_ID, "广告位ID不能为空", null)
            return
        }

        val errorMsg = validationHelper.performBasicChecks(AdConstants.AD_TYPE_SPLASH, posId, activity)
        if (errorMsg != null) {
            result.error(AdConstants.ErrorCodes.LOAD_ERROR, errorMsg, null)
            return
        }

        currentPosId = posId

        val timeout = call.argument<Double>("timeout")
        val preloadRequested = call.argument<Boolean>("preload") ?: false
        val logoConfig = parseLogoConfig(call.argument("logo"))
        val androidOptions = parseAndroidOptions(call.argument("android"))

        currentLogoConfig = logoConfig
        currentAndroidOptions = androidOptions

        val logParams = mutableMapOf<String, Any>()
        timeout?.let { logParams["timeout"] = it }
        if (preloadRequested) logParams["preload"] = true
        logoConfig?.let { logParams["logo"] = mapOf(
            "source" to it.source.name.lowercase(),
            "value" to it.value,
            "heightDp" to it.heightDp,
            "heightRatio" to it.heightRatio,
            "background" to it.backgroundColor
        ) }
        logger.logAdRequest(AdConstants.AD_TYPE_SPLASH, posId, logParams)

        // 如果存在可用的预加载广告且参数一致，优先直接展示
        if (!preloadRequested && preloadedSplashAd != null) {
            val preloadLogoMatch = preloadedLogoConfig == logoConfig
            val preloadOptionMatch = preloadedAndroidOptions == androidOptions
            val preloadPosMatch = preloadedPosId == posId
            if (preloadLogoMatch && preloadOptionMatch && preloadPosMatch) {
                showPreloadedSplashAd(result)
                return
            } else {
                logger.logAdLifecycle(AdConstants.AD_TYPE_SPLASH, posId, "预加载参数不一致，重新加载")
                clearPreloaded()
            }
        }

        val timeoutSeconds = validationHelper.validateTimeout(timeout ?: 3.5)
        val (adSlot, resolvedLogoHeight) = buildAdSlot(posId, activity, logoConfig, androidOptions)
        splashLogoHeightPx = resolvedLogoHeight

        val adLoader: TTAdNative = TTAdSdk.getAdManager().createAdNative(activity?.applicationContext)
        val resultSent = AtomicBoolean(false)

        val listener = object : TTAdNative.CSJSplashAdListener {
            override fun onSplashLoadSuccess(csjSplashAd: CSJSplashAd?) {
                Log.d(AdConstants.TAG, "开屏广告物料加载成功")
            }

            override fun onSplashRenderSuccess(csjSplashAd: CSJSplashAd?) {
                logger.logAdSuccess(AdConstants.AD_TYPE_SPLASH, "渲染", posId)
                eventHelper.sendLoadSuccessEvent(AdConstants.AD_TYPE_SPLASH, posId)
                eventHelper.sendAdEvent(AdConstants.Events.SPLASH_RENDER_SUCCESS, posId)

                if (preloadRequested) {
                    preloadedSplashAd = csjSplashAd
                    preloadedPosId = posId
                    preloadedLogoConfig = logoConfig
                    preloadedAndroidOptions = androidOptions
                    if (!resultSent.getAndSet(true)) {
                        result.success(true)
                    }
                } else {
                    setupAndShowSplashAd(csjSplashAd, posId, resultSent, result)
                }
            }

            override fun onSplashLoadFail(csjAdError: CSJAdError?) {
                val errorCode = csjAdError?.code ?: -1
                val errorMessage = csjAdError?.msg ?: "未知错误"
                logger.logAdError(AdConstants.AD_TYPE_SPLASH, "加载", posId, errorCode, errorMessage)
                eventHelper.sendLoadFailEvent(AdConstants.AD_TYPE_SPLASH, posId, errorCode, errorMessage)
                if (!resultSent.getAndSet(true)) {
                    result.error(AdConstants.ErrorCodes.LOAD_ERROR, "开屏广告加载失败: $errorMessage", errorCode)
                }
            }

            override fun onSplashRenderFail(csjSplashAd: CSJSplashAd?, csjAdError: CSJAdError?) {
                val errorCode = csjAdError?.code ?: -1
                val errorMessage = csjAdError?.msg ?: "未知错误"
                logger.logAdError(AdConstants.AD_TYPE_SPLASH, "渲染", posId, errorCode, errorMessage)
                eventHelper.sendAdEvent(
                    AdConstants.Events.SPLASH_RENDER_FAIL,
                    posId,
                    mapOf("code" to errorCode, "message" to errorMessage)
                )
                if (!resultSent.getAndSet(true)) {
                    result.error(AdConstants.ErrorCodes.SHOW_ERROR, "开屏广告渲染失败: $errorMessage", errorCode)
                }
            }
        }

        try {
            adLoader.loadSplashAd(adSlot, listener, (timeoutSeconds * 1000).toInt())
        } catch (e: Exception) {
            logger.logAdError(AdConstants.AD_TYPE_SPLASH, "异常", posId, -1, e.message ?: "未知异常")
            if (!resultSent.getAndSet(true)) {
                result.error(AdConstants.ErrorCodes.SHOW_ERROR, "开屏广告异常: ${e.message}", null)
            }
        }
    }

    override fun destroy() {
        currentSplashAd = null
        currentPosId = ""
        currentLogoConfig = null
        currentAndroidOptions = null
        clearPreloaded()
        removeSplashContainer()
        logger.logAdLifecycle(AdConstants.AD_TYPE_SPLASH, "", "开屏广告管理器销毁完成")
    }

    private fun clearPreloaded() {
        preloadedSplashAd = null
        preloadedPosId = null
        preloadedLogoConfig = null
        preloadedAndroidOptions = null
    }

    private fun setupAndShowSplashAd(
        csjSplashAd: CSJSplashAd?,
        posId: String,
        resultSent: AtomicBoolean,
        result: Result
    ) {
        val activity = getCurrentActivity()
        if (activity == null || csjSplashAd == null) {
            if (!resultSent.getAndSet(true)) {
                result.error(AdConstants.ErrorCodes.SHOW_ERROR, "Activity或广告实例为空", null)
            }
            return
        }

        currentSplashAd = csjSplashAd
        currentPosId = posId
        registerSplashListeners(csjSplashAd, posId)
        showSplashAdView(csjSplashAd, activity, posId)

        if (!resultSent.getAndSet(true)) {
            result.success(true)
        }
    }

    private fun registerSplashListeners(ad: CSJSplashAd, posId: String) {
        ad.setSplashAdListener(object : CSJSplashAd.SplashAdListener {
            override fun onSplashAdShow(p0: CSJSplashAd?) {
                logger.logAdSuccess(AdConstants.AD_TYPE_SPLASH, "展示", posId)
                eventHelper.sendShowEvent(AdConstants.AD_TYPE_SPLASH, posId)
                sendEcpmEventIfAvailable()
            }

            override fun onSplashAdClick(p0: CSJSplashAd?) {
                logger.logAdSuccess(AdConstants.AD_TYPE_SPLASH, "点击", posId)
                eventHelper.sendClickEvent(AdConstants.AD_TYPE_SPLASH, posId)
            }

            override fun onSplashAdClose(p0: CSJSplashAd?, closeType: Int) {
                logger.logAdSuccess(AdConstants.AD_TYPE_SPLASH, "关闭", posId, "closeType=$closeType")
                eventHelper.sendCloseEvent(
                    AdConstants.AD_TYPE_SPLASH,
                    posId,
                    mapOf("closeType" to closeType)
                )
                destroy()
            }
        })

        ad.setSplashCardListener(object : CSJSplashAd.SplashCardListener {
            override fun onSplashCardReadyToShow(cardAd: CSJSplashAd?) {
                eventHelper.sendAdEvent(AdConstants.Events.SPLASH_CARD_READY, posId)
            }

            override fun onSplashCardClick() {
                eventHelper.sendAdEvent(AdConstants.Events.SPLASH_CARD_CLICKED, posId)
            }

            override fun onSplashCardClose() {
                eventHelper.sendAdEvent(AdConstants.Events.SPLASH_CARD_CLOSED, posId)
            }
        })
    }

    private fun showSplashAdView(csjSplashAd: CSJSplashAd, activity: Activity, posId: String) {
        val splashView = csjSplashAd.splashView
        if (splashView == null) {
            logger.logAdError(AdConstants.AD_TYPE_SPLASH, "展示", posId, -1, "无法获取开屏广告视图")
            return
        }

        val container = getOrCreateSplashContainer(activity)
        container.removeAllViews()

        val logoHeight = splashLogoHeightPx
        val logoConfig = currentLogoConfig

        if (logoHeight > 0 && logoConfig != null) {
            val root = LinearLayout(activity).apply {
                orientation = LinearLayout.VERTICAL
                layoutParams = FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.MATCH_PARENT
                )
            }

            val splashLayoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                splashContentHeightPx
            )
            val splashWrapper = FrameLayout(activity)
            splashWrapper.addView(splashView, FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            ))
            root.addView(splashWrapper, splashLayoutParams)

            val bottomLayoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                logoHeight
            )
            val bottomContainer = FrameLayout(activity)
            logoConfig.backgroundColor?.let { bottomContainer.setBackgroundColor(it) }

            val logoView = createLogoView(activity, logoConfig)
            if (logoView != null) {
                bottomContainer.addView(
                    logoView,
                    FrameLayout.LayoutParams(
                        FrameLayout.LayoutParams.WRAP_CONTENT,
                        FrameLayout.LayoutParams.WRAP_CONTENT,
                        Gravity.CENTER
                    )
                )
            }
            root.addView(bottomContainer, bottomLayoutParams)

            container.addView(root)
        } else {
            container.addView(
                splashView,
                FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.MATCH_PARENT
                )
            )
        }
    }

    private fun getOrCreateSplashContainer(activity: Activity): FrameLayout {
        splashContainer?.let { return it }
        val container = FrameLayout(activity).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
            setBackgroundColor(Color.BLACK)
        }
        val root = activity.window?.decorView as? ViewGroup
        root?.addView(container)
        splashContainer = container
        return container
    }

    private fun removeSplashContainer() {
        splashContainer?.let { container ->
            (container.parent as? ViewGroup)?.removeView(container)
        }
        splashContainer = null
    }

    private fun createLogoView(activity: Activity, config: LogoConfig?): View? {
        if (config == null) return null
        val bitmap = when (config.source) {
            LogoSource.ASSET -> loadBitmapFromAsset(activity, config.value)
            LogoSource.FILE -> BitmapFactory.decodeFile(config.value)
            LogoSource.RESOURCE -> loadBitmapFromResource(activity, config.value)
            LogoSource.BUNDLE -> loadBitmapFromBundle(activity, config.value)
        }
        if (bitmap == null) {
            logger.logAdError(AdConstants.AD_TYPE_SPLASH, "logo", "", -1, "无法加载logo: ${config.value}")
            return null
        }
        return ImageView(activity).apply {
            setImageBitmap(bitmap)
            scaleType = ImageView.ScaleType.FIT_CENTER
            adjustViewBounds = true
        }
    }

    private fun loadBitmapFromAsset(activity: Activity, assetPath: String): Bitmap? {
        val binding = flutterPluginBinding ?: return null
        return try {
            val lookup = binding.flutterAssets.getAssetFilePathByName(assetPath)
            val inputStream: InputStream = activity.assets.open(lookup)
            BitmapFactory.decodeStream(inputStream).also { inputStream.close() }
        } catch (e: Exception) {
            logger.logAdError(AdConstants.AD_TYPE_SPLASH, "logo", "", -1, "加载Flutter资源失败: ${e.message}")
            null
        }
    }

    private fun loadBitmapFromResource(activity: Activity, resourceName: String): Bitmap? {
        val resources = activity.resources
        val pkg = activity.packageName
        val mipmapId = resources.getIdentifier(resourceName, "mipmap", pkg)
        val drawableId = if (mipmapId != 0) mipmapId else resources.getIdentifier(resourceName, "drawable", pkg)
        if (drawableId == 0) {
            return null
        }
        return BitmapFactory.decodeResource(resources, drawableId)
    }

    private fun loadBitmapFromBundle(activity: Activity, bundlePath: String): Bitmap? {
        return try {
            BitmapFactory.decodeStream(activity.assets.open(bundlePath))
        } catch (_: Exception) {
            null
        }
    }

    private fun showPreloadedSplashAd(result: Result) {
        val activity = getCurrentActivity()
        val ad = preloadedSplashAd
        if (activity == null || ad == null) {
            result.error(AdConstants.ErrorCodes.SHOW_ERROR, "没有可用的预加载开屏广告", null)
            clearPreloaded()
            return
        }

        currentSplashAd = ad
        currentLogoConfig = preloadedLogoConfig
        currentAndroidOptions = preloadedAndroidOptions
        currentPosId = preloadedPosId ?: currentPosId

        registerSplashListeners(ad, currentPosId)
        showSplashAdView(ad, activity, currentPosId)
        clearPreloaded()
        result.success(true)
    }

    private fun sendEcpmEventIfAvailable() {
        val manager = currentSplashAd?.mediationManager ?: return
        val info: MediationAdEcpmInfo = manager.showEcpm ?: return
        val payload = mutableMapOf<String, Any>()
        info.ecpm?.let { payload["ecpm"] = it }
        info.sdkName?.let { payload["sdkName"] = it }
        info.customSdkName?.let { payload["customSdkName"] = it }
        info.slotId?.let { payload["slotId"] = it }
        info.levelTag?.let { payload["levelTag"] = it }
        payload["reqBiddingType"] = info.reqBiddingType
        info.errorMsg?.let { payload["errorMsg"] = it }
        info.requestId?.let { payload["requestId"] = it }
        info.ritType?.let { payload["ritType"] = it }
        info.segmentId?.let { payload["segmentId"] = it }
        info.channel?.let { payload["channel"] = it }
        info.subChannel?.let { payload["subChannel"] = it }
        info.abTestId?.let { payload["abTestId"] = it }
        info.scenarioId?.let { payload["scenarioId"] = it }
        info.customData?.let { payload["customData"] = it }
        if (payload.isNotEmpty()) {
            eventHelper.sendAdEvent(AdConstants.Events.SPLASH_ECPM, currentPosId, payload)
        }
    }

    fun isReady(): Boolean {
        val ad = preloadedSplashAd ?: currentSplashAd
        return ad?.mediationManager?.isReady == true
    }

    fun getAdLoadInfo(): List<Map<String, Any>> {
        val ad = preloadedSplashAd ?: currentSplashAd
        return AdDiagnosticsHelper.getAdLoadInfo(ad?.mediationManager)
    }

    private fun parseLogoConfig(raw: Map<String, Any?>?): LogoConfig? {
        if (raw == null || raw.isEmpty()) return null
        val sourceValue = (raw["source"] as? String)?.trim()?.lowercase() ?: return null
        val value = (raw["value"] as? String)?.trim()?.takeIf { it.isNotEmpty() } ?: return null
        val source = when (sourceValue) {
            "asset" -> LogoSource.ASSET
            "file" -> LogoSource.FILE
            "resource" -> LogoSource.RESOURCE
            "bundle" -> LogoSource.BUNDLE
            else -> LogoSource.ASSET
        }
        val heightDp = (raw["height"] as? Number)?.toDouble()
        val heightRatio = (raw["heightRatio"] as? Number)?.toDouble()
        val colorHex = (raw["backgroundColor"] as? String)?.trim()
        val color = parseColorOrNull(colorHex)
        return LogoConfig(source, value, heightDp, heightRatio, color)
    }

    private fun parseAndroidOptions(raw: Map<String, Any?>?): AndroidOptions? {
        if (raw == null || raw.isEmpty()) return null
        val muted = raw["muted"] as? Boolean
        val volume = (raw["volume"] as? Number)?.toFloat()
        val useSurfaceView = raw["useSurfaceView"] as? Boolean
        val bidNotify = raw["bidNotify"] as? Boolean
        val shakeButton = raw["shakeButton"] as? Boolean
        val enablePreload = raw["enablePreload"] as? Boolean
        val scenarioId = raw["scenarioId"] as? String
        val extras = (raw["extras"] as? Map<*, *>)?.mapNotNull {
            val key = it.key as? String ?: return@mapNotNull null
            key to it.value as Any
        }?.toMap()
        val customData = (raw["customData"] as? Map<*, *>)?.mapNotNull {
            val key = it.key as? String ?: return@mapNotNull null
            key to it.value as Any
        }?.toMap()
        val fallback = parseFallbackConfig(raw["fallback"] as? Map<*, *>)
        return AndroidOptions(muted, volume, useSurfaceView, bidNotify, shakeButton, enablePreload, scenarioId, extras, customData, fallback)
    }

    private fun parseFallbackConfig(raw: Map<*, *>?): FallbackConfig? {
        if (raw == null || raw.isEmpty()) return null
        val adnName = (raw["adnName"] as? String)?.trim()?.takeIf { it.isNotEmpty() } ?: return null
        val slotId = (raw["slotId"] as? String)?.trim()?.takeIf { it.isNotEmpty() } ?: return null
        val appId = (raw["appId"] as? String)?.trim()?.takeIf { it.isNotEmpty() } ?: return null
        val appKey = (raw["appKey"] as? String)?.trim()?.takeIf { it.isNotEmpty() }
        return FallbackConfig(adnName, slotId, appId, appKey)
    }

    private fun buildAdSlot(
        posId: String,
        activity: Activity?,
        logoConfig: LogoConfig?,
        androidOptions: AndroidOptions?
    ): Pair<AdSlot, Int> {
        val metrics = activity?.resources?.displayMetrics
        val screenWidth = metrics?.widthPixels ?: 1080
        val screenHeight = metrics?.heightPixels ?: 1920
        val density = metrics?.density ?: 3f

        val (contentHeight, logoHeight) = resolveHeights(screenHeight, density, logoConfig)
        splashContentHeightPx = contentHeight

        val slotBuilder = AdSlot.Builder()
            .setCodeId(posId)
            .setImageAcceptedSize(screenWidth, contentHeight)

        if (androidOptions != null) {
            val mediationBuilder = MediationAdSlot.Builder()
            androidOptions.muted?.let { mediationBuilder.setMuted(it) }
            androidOptions.volume?.let { mediationBuilder.setVolume(it) }
            androidOptions.useSurfaceView?.let { mediationBuilder.setUseSurfaceView(it) }
            androidOptions.bidNotify?.let { mediationBuilder.setBidNotify(it) }
            androidOptions.shakeButton?.let { mediationBuilder.setSplashShakeButton(it) }
            androidOptions.enablePreload?.let { mediationBuilder.setSplashPreLoad(it) }
            androidOptions.scenarioId?.let { mediationBuilder.setScenarioId(it) }
            androidOptions.extras?.forEach { (key, value) -> mediationBuilder.setExtraObject(key, value) }
            androidOptions.customData?.takeIf { it.isNotEmpty() }?.let { custom ->
                mediationBuilder.setExtraObject(
                    MediationConstant.CUSTOM_DATA_KEY_GROMORE_EXTRA,
                    JSONObject(custom as Map<*, *>).toString()
                )
            }
            androidOptions.fallback?.let {
                mediationBuilder.setMediationSplashRequestInfo(
                    object : MediationSplashRequestInfo(
                        it.adnName,
                        it.slotId,
                        it.appId,
                        it.appKey ?: ""
                    ) {}
                )
            }
            slotBuilder.setMediationAdSlot(mediationBuilder.build())
        }

        return slotBuilder.build() to logoHeight
    }

    private fun resolveHeights(
        screenHeight: Int,
        density: Float,
        logoConfig: LogoConfig?
    ): Pair<Int, Int> {
        if (logoConfig == null) {
            return screenHeight to 0
        }
        val maxLogoHeight = (screenHeight * 0.25f).toInt()
        val defaultLogoHeight = (screenHeight * 0.15f).toInt()
        var logoHeight = when {
            logoConfig.heightDp != null -> (logoConfig.heightDp * density).toInt()
            logoConfig.heightRatio != null -> (screenHeight * logoConfig.heightRatio).toInt()
            else -> defaultLogoHeight
        }
        logoHeight = logoHeight.coerceIn(0, maxLogoHeight)
        val minContentHeight = (screenHeight * 0.5f).toInt()
        val contentHeight = max(screenHeight - logoHeight, minContentHeight)
        return contentHeight to logoHeight
    }

    private fun parseColorOrNull(color: String?): Int? {
        if (color.isNullOrBlank()) return null
        return try {
            Color.parseColor(color)
        } catch (_: IllegalArgumentException) {
            null
        }
    }
}
