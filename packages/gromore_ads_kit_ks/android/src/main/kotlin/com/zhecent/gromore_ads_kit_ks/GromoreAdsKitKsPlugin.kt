package com.zhecent.gromore_ads_kit_ks

import io.flutter.embedding.engine.plugins.FlutterPlugin

/** 只负责让快手广告 SDK 和 GroMore Adapter 随宿主一起打包。 */
class GromoreAdsKitKsPlugin : FlutterPlugin {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) = Unit

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) = Unit
}
