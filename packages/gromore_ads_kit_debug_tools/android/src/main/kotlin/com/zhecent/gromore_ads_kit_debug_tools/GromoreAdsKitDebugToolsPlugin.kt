package com.zhecent.gromore_ads_kit_debug_tools

import android.app.Activity
import android.content.Context
import android.widget.ImageView
import com.bumptech.glide.Glide
import com.bytedance.sdk.openadsdk.TTAdSdk
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.lang.reflect.Proxy

/** GroMore 官方广告测试工具，只在宿主的 Debug 构建中带入测试 AAR。 */
class GromoreAdsKitDebugToolsPlugin :
    FlutterPlugin,
    ActivityAware,
    MethodChannel.MethodCallHandler {

    private var channel: MethodChannel? = null
    private var activity: Activity? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "gromore_ads_kit_debug_tools").also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "launchTestTools") {
            result.notImplemented()
            return
        }
        launchTestTools(result)
    }

    private fun launchTestTools(result: MethodChannel.Result) {
        if (!TTAdSdk.isSdkReady()) {
            result.error("SDK_NOT_READY", "GroMore SDK尚未初始化，请先调用 initAd", null)
            return
        }

        val currentActivity = activity
        if (currentActivity == null) {
            result.error("ACTIVITY_ERROR", "无法获取当前 Activity", null)
            return
        }

        try {
            val toolClass = Class.forName("com.bytedance.mtesttools.api.TTMediationTestTool")
            val callbackClass = Class.forName(
                "com.bytedance.mtesttools.api.TTMediationTestTool\$ImageCallBack"
            )
            val imageCallback = Proxy.newProxyInstance(
                callbackClass.classLoader,
                arrayOf(callbackClass)
            ) { _, method, args ->
                if (method.name == "loadImage") {
                    val imageView = args?.getOrNull(0) as? ImageView
                    val url = args?.getOrNull(1) as? String
                    if (imageView != null && !url.isNullOrEmpty()) {
                        Glide.with(currentActivity).load(url).into(imageView)
                    }
                }
                null
            }
            toolClass
                .getMethod("launchTestTools", Context::class.java, callbackClass)
                .invoke(null, currentActivity, imageCallback)
            result.success(true)
        } catch (error: Throwable) {
            val reason = if (error is ClassNotFoundException || error is NoClassDefFoundError) {
                "当前构建未包含 GroMore 官方测试工具，请使用 Debug 构建"
            } else {
                error.message ?: "未知异常"
            }
            result.error("SHOW_ERROR", "启动 GroMore 测试工具失败：$reason", null)
        }
    }
}
