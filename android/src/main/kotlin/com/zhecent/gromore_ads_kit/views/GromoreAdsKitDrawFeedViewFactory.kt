package com.zhecent.gromore_ads_kit.views

import android.content.Context
import com.zhecent.gromore_ads_kit.managers.DrawFeedAdManager
import com.zhecent.gromore_ads_kit.utils.AdEventHelper
import com.zhecent.gromore_ads_kit.utils.AdLogger
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * Draw信息流广告原生视图工厂
 */
class GromoreAdsKitDrawFeedViewFactory(
    private val messenger: BinaryMessenger,
    private val drawFeedAdManager: DrawFeedAdManager,
    private val eventHelper: AdEventHelper,
    private val logger: AdLogger
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val creationParams = args as? Map<String, Any> ?: emptyMap()
        return GromoreAdsKitDrawFeedView(
            context,
            messenger,
            viewId,
            creationParams,
            drawFeedAdManager,
            eventHelper,
            logger
        )
    }
}
