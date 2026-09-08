package com.zhecent.gromore_ads_kit_sigmob

import io.flutter.embedding.engine.plugins.FlutterPlugin

/** 只负责让 Sigmob SDK 和 GroMore Adapter 随宿主一起打包。 */
class GromoreAdsKitSigmobPlugin : FlutterPlugin {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) = Unit

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) = Unit
}
