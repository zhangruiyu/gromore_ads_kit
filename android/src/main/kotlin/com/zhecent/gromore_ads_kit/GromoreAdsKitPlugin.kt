package com.zhecent.gromore_ads_kit

import android.app.Activity
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import com.zhecent.gromore_ads_kit.common.AdConstants
import com.zhecent.gromore_ads_kit.managers.*
import com.zhecent.gromore_ads_kit.utils.AdEventHelper
import com.zhecent.gromore_ads_kit.utils.AdValidationHelper
import com.zhecent.gromore_ads_kit.utils.AdLogger
import com.zhecent.gromore_ads_kit.views.GromoreAdsKitBannerViewFactory
import com.zhecent.gromore_ads_kit.views.GromoreAdsKitDrawFeedViewFactory
import com.zhecent.gromore_ads_kit.views.GromoreAdsKitFeedViewFactory

/**
 * GroMore广告插件主类（重构后极简版）
 * 职责：
 * 1. Flutter插件生命周期管理
 * 2. 方法调用纯路由分发
 * 3. Activity依赖注入管理
 * 4. 事件通道管理
 *
 * 注意：所有具体的SDK操作都已移到专门的管理器中
 */
class GromoreAdsKitPlugin :
    FlutterPlugin,
    ActivityAware,
    MethodCallHandler,
    EventChannel.StreamHandler {

    companion object {
        private const val TAG = AdConstants.TAG
    }

    // Flutter通信通道
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel

    // Flutter插件绑定引用（用于访问Assets）
    private lateinit var flutterPluginBinding: FlutterPlugin.FlutterPluginBinding

    // 当前Activity引用
    private var currentActivity: Activity? = null

    // 工具类实例
    private lateinit var eventHelper: AdEventHelper
    private val validationHelper = AdValidationHelper.getInstance()
    private val logger = AdLogger.getInstance()

    // SDK管理器
    private lateinit var sdkManager: SdkManager

    // 广告管理器实例
    private lateinit var splashAdManager: SplashAdManager
    private lateinit var interstitialAdManager: InterstitialAdManager
    private lateinit var rewardVideoAdManager: RewardVideoAdManager
    private lateinit var feedAdManager: FeedAdManager
    private lateinit var drawFeedAdManager: DrawFeedAdManager
    private lateinit var bannerAdManager: BannerAdManager

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        // 保存FlutterPluginBinding引用
        this.flutterPluginBinding = flutterPluginBinding

        // 初始化通信通道
        methodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "gromore_ads_kit")
        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "gromore_ads_kit_event")

        // 设置处理器
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)

        // 初始化工具类
        eventHelper = AdEventHelper.getInstance()

        // 初始化所有管理器
        initAllManagers()

        // 注册原生视图工厂
        flutterPluginBinding.platformViewRegistry.registerViewFactory(
            "gromore_ads_kit_banner",
            GromoreAdsKitBannerViewFactory()
        )
        flutterPluginBinding.platformViewRegistry.registerViewFactory(
            "gromore_ads_kit_feed",
            GromoreAdsKitFeedViewFactory(
                flutterPluginBinding.binaryMessenger,
                feedAdManager,
                eventHelper,
                logger
            )
        )
        flutterPluginBinding.platformViewRegistry.registerViewFactory(
            "gromore_ads_kit_draw_feed",
            GromoreAdsKitDrawFeedViewFactory(
                flutterPluginBinding.binaryMessenger,
                drawFeedAdManager,
                eventHelper,
                logger
            )
        )

        Log.d(TAG, "GroMore广告插件已初始化，Banner PlatformView已注册")
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        currentActivity = binding.activity
        updateManagersActivity(binding.activity)
        Log.d(TAG, "Activity已绑定到GroMore广告插件")
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        currentActivity = binding.activity
        updateManagersActivity(binding.activity)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        // 保持activity引用
    }

    override fun onDetachedFromActivity() {
        currentActivity = null
        updateManagersActivity(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            // 基础方法
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }

            // SDK管理相关（路由到SdkManager）
            "initAd" -> {
                sdkManager.initAd(call, result)
            }
            "requestPermissionIfNecessary" -> {
                sdkManager.requestPermissionIfNecessary(call, result)
            }
            "preload" -> {
                sdkManager.preload(call, result)
            }
            "launchTestTools" -> {
                sdkManager.launchTestTools(call, result)
            }
            "isReady" -> {
                handleIsReady(call, result)
            }
            "getAdLoadInfo" -> {
                handleGetAdLoadInfo(call, result)
            }

            // 开屏广告（路由到SplashAdManager）
            "showSplashAd" -> {
                splashAdManager.show(call, result)
            }

            // 插屏广告（路由到InterstitialAdManager）
            "loadInterstitialAd" -> {
                interstitialAdManager.load(call, result)
            }
            "showInterstitialAd" -> {
                interstitialAdManager.show(call, result)
            }

            // 激励视频广告（路由到RewardVideoAdManager）
            "loadRewardVideoAd" -> {
                rewardVideoAdManager.load(call, result)
            }
            "showRewardVideoAd" -> {
                rewardVideoAdManager.show(call, result)
            }

            // 信息流广告（路由到FeedAdManager）
            "loadFeedAd" -> {
                feedAdManager.loadBatch(call, result)
            }
            "clearFeedAd" -> {
                feedAdManager.clearBatch(call, result)
            }

            // Draw信息流广告（路由到DrawFeedAdManager）
            "loadDrawFeedAd" -> {
                drawFeedAdManager.loadBatch(call, result)
            }
            "clearDrawFeedAd" -> {
                drawFeedAdManager.clearBatch(call, result)
            }

            // Banner广告（路由到BannerAdManager）
            "loadBannerAd" -> {
                bannerAdManager.load(call, result)
            }
            "showBannerAd" -> {
                bannerAdManager.show(call, result)
            }
            "destroyBannerAd" -> {
                bannerAdManager.destroy()
                result.success(true)
            }

            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)

        // 销毁所有管理器资源
        destroyAllManagers()

        Log.d(TAG, "GroMore广告插件已卸载")
    }

    // EventChannel.StreamHandler 实现
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventHelper.updateEventSink(events)
        Log.d(TAG, "事件通道已连接")
    }

    override fun onCancel(arguments: Any?) {
        eventHelper.updateEventSink(null)
        Log.d(TAG, "事件通道已断开")
    }

    /**
     * 初始化所有管理器（SDK管理器 + 广告管理器）
     */
    private fun initAllManagers() {
        // SDK管理器
        sdkManager = SdkManager(
            eventHelper,
            validationHelper,
            logger,
            flutterPluginBinding.applicationContext,
            flutterPluginBinding.flutterAssets
        )

        // 广告管理器（传递FlutterPluginBinding以支持Assets访问）
        splashAdManager = SplashAdManager(eventHelper, validationHelper, logger, flutterPluginBinding)
        interstitialAdManager = InterstitialAdManager(eventHelper, validationHelper, logger)
        rewardVideoAdManager = RewardVideoAdManager(eventHelper, validationHelper, logger)
        feedAdManager = FeedAdManager(eventHelper, validationHelper, logger)
        drawFeedAdManager = DrawFeedAdManager(eventHelper, validationHelper, logger)
        bannerAdManager = BannerAdManager(eventHelper, validationHelper, logger)
    }

    /**
     * 更新所有管理器的Activity引用
     */
    private fun updateManagersActivity(activity: Activity?) {
        // SDK管理器
        sdkManager.setActivity(activity)

        // 广告管理器
        splashAdManager.setActivity(activity)
        interstitialAdManager.setActivity(activity)
        rewardVideoAdManager.setActivity(activity)
        feedAdManager.setActivity(activity)
        drawFeedAdManager.setActivity(activity)
        bannerAdManager.setActivity(activity)
    }

    /**
     * 销毁所有管理器
     */
    private fun destroyAllManagers() {
        try {
            // 销毁广告管理器
            splashAdManager.destroy()
            interstitialAdManager.destroy()
            rewardVideoAdManager.destroy()
            feedAdManager.destroyAll()
            drawFeedAdManager.destroyAll()
            bannerAdManager.destroy()

            Log.d(TAG, "所有管理器已销毁")
        } catch (e: Exception) {
            Log.e(TAG, "销毁管理器时发生异常", e)
        }
    }

    private fun handleIsReady(call: MethodCall, result: Result) {
        val adType = call.argument<String>("adType")
        val adId = call.argument<Int>("adId")
        val ready = when (adType) {
            "splash" -> splashAdManager.isReady()
            "interstitial" -> interstitialAdManager.isReady()
            "rewardVideo" -> rewardVideoAdManager.isReady()
            "feed" -> adId?.let(feedAdManager::isReady) ?: false
            "drawFeed" -> adId?.let(drawFeedAdManager::isReady) ?: false
            "banner" -> bannerAdManager.isReady()
            else -> {
                result.error(AdConstants.ErrorCodes.INVALID_PARAMS, "不支持的广告类型: $adType", null)
                return
            }
        }
        result.success(ready)
    }

    private fun handleGetAdLoadInfo(call: MethodCall, result: Result) {
        val adType = call.argument<String>("adType")
        val adId = call.argument<Int>("adId")
        val info = when (adType) {
            "splash" -> splashAdManager.getAdLoadInfo()
            "interstitial" -> interstitialAdManager.getAdLoadInfo()
            "rewardVideo" -> rewardVideoAdManager.getAdLoadInfo()
            "feed" -> adId?.let(feedAdManager::getAdLoadInfo) ?: emptyList()
            "drawFeed" -> adId?.let(drawFeedAdManager::getAdLoadInfo) ?: emptyList()
            "banner" -> bannerAdManager.getAdLoadInfo()
            else -> {
                result.error(AdConstants.ErrorCodes.INVALID_PARAMS, "不支持的广告类型: $adType", null)
                return
            }
        }
        result.success(info)
    }

    // 注意：initAd、preload、launchTestTools等方法已移动到SdkManager中
    // 主插件现在只负责路由分发，不包含具体的SDK操作逻辑
}
