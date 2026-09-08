package com.zhecent.gromore_ads_kit_baidu

import io.flutter.embedding.engine.plugins.FlutterPlugin

/** 只负责让百度广告 SDK 和 GroMore Adapter 随宿主一起打包。 */
class GromoreAdsKitBaiduPlugin : FlutterPlugin {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) = Unit

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) = Unit
}
