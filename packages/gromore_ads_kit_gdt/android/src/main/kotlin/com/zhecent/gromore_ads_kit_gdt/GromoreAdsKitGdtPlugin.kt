package com.zhecent.gromore_ads_kit_gdt

import io.flutter.embedding.engine.plugins.FlutterPlugin

/** 只负责让优量汇 SDK 和 GroMore Adapter 随宿主一起打包。 */
class GromoreAdsKitGdtPlugin : FlutterPlugin {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) = Unit

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) = Unit
}
