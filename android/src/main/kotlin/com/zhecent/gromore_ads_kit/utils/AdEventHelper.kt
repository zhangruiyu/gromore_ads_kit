package com.zhecent.gromore_ads_kit.utils

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import com.zhecent.gromore_ads_kit.common.AdConstants

/**
 * 广告事件处理工具类
 * 负责统一处理广告事件的发送和管理
 */
class AdEventHelper(private var eventSink: EventChannel.EventSink?) {

    private val mainHandler = Handler(Looper.getMainLooper())

    /**
     * 发送广告事件
     * @param action 事件动作
     * @param posId 广告位ID
     * @param extra 额外参数
     */
    fun sendAdEvent(action: String, posId: String, extra: Map<String, Any>? = null) {
        val event = mutableMapOf<String, Any>(
            "action" to action,
            "posId" to posId,
            "timestamp" to System.currentTimeMillis()
        )
        extra?.let {
            if (it.isNotEmpty()) {
                event["extra"] = it
            }
        }

        mainHandler.post {
            eventSink?.success(event)
        }
    }

    /**
     * 发送广告加载成功事件
     */
    fun sendLoadSuccessEvent(adType: String, posId: String, extra: Map<String, Any>? = null) {
        val action = when (adType) {
            AdConstants.AD_TYPE_SPLASH -> AdConstants.Events.SPLASH_LOADED
            AdConstants.AD_TYPE_INTERSTITIAL -> AdConstants.Events.INTERSTITIAL_LOADED
            AdConstants.AD_TYPE_REWARD_VIDEO -> AdConstants.Events.REWARD_VIDEO_LOADED
            AdConstants.AD_TYPE_FEED -> AdConstants.Events.FEED_LOADED
            AdConstants.AD_TYPE_DRAW_FEED -> AdConstants.Events.DRAW_FEED_LOADED
            AdConstants.AD_TYPE_BANNER -> AdConstants.Events.BANNER_LOADED
            else -> "${adType}_loaded"
        }
        sendAdEvent(action, posId, extra)
    }

    /**
     * 发送广告展示事件
     */
    fun sendShowEvent(adType: String, posId: String, extra: Map<String, Any>? = null) {
        val action = when (adType) {
            AdConstants.AD_TYPE_SPLASH -> AdConstants.Events.SPLASH_SHOWED
            AdConstants.AD_TYPE_INTERSTITIAL -> AdConstants.Events.INTERSTITIAL_SHOWED
            AdConstants.AD_TYPE_REWARD_VIDEO -> AdConstants.Events.REWARD_VIDEO_SHOWED
            AdConstants.AD_TYPE_FEED -> AdConstants.Events.FEED_SHOWED
            AdConstants.AD_TYPE_DRAW_FEED -> AdConstants.Events.DRAW_FEED_SHOWED
            AdConstants.AD_TYPE_BANNER -> AdConstants.Events.BANNER_SHOWED
            else -> "${adType}_showed"
        }
        sendAdEvent(action, posId, extra)
    }

    /**
     * 发送广告点击事件
     */
    fun sendClickEvent(adType: String, posId: String, extra: Map<String, Any>? = null) {
        val action = when (adType) {
            AdConstants.AD_TYPE_SPLASH -> AdConstants.Events.SPLASH_CLICKED
            AdConstants.AD_TYPE_INTERSTITIAL -> AdConstants.Events.INTERSTITIAL_CLICKED
            AdConstants.AD_TYPE_REWARD_VIDEO -> AdConstants.Events.REWARD_VIDEO_CLICKED
            AdConstants.AD_TYPE_FEED -> AdConstants.Events.FEED_CLICKED
            AdConstants.AD_TYPE_DRAW_FEED -> AdConstants.Events.DRAW_FEED_CLICKED
            AdConstants.AD_TYPE_BANNER -> AdConstants.Events.BANNER_CLICKED
            else -> "${adType}_clicked"
        }
        sendAdEvent(action, posId, extra)
    }

    /**
     * 发送广告关闭事件
     */
    fun sendCloseEvent(adType: String, posId: String, extra: Map<String, Any>? = null) {
        val action = when (adType) {
            AdConstants.AD_TYPE_SPLASH -> AdConstants.Events.SPLASH_CLOSED
            AdConstants.AD_TYPE_INTERSTITIAL -> AdConstants.Events.INTERSTITIAL_CLOSED
            AdConstants.AD_TYPE_REWARD_VIDEO -> AdConstants.Events.REWARD_VIDEO_CLOSED
            AdConstants.AD_TYPE_FEED -> AdConstants.Events.FEED_CLOSED
            AdConstants.AD_TYPE_DRAW_FEED -> AdConstants.Events.DRAW_FEED_CLOSED
            AdConstants.AD_TYPE_BANNER -> AdConstants.Events.BANNER_CLOSED
            else -> "${adType}_closed"
        }
        sendAdEvent(action, posId, extra)
    }

    /**
     * 发送广告加载失败事件
     */
    fun sendLoadFailEvent(adType: String, posId: String, errorCode: Int, errorMsg: String) {
        val action = when (adType) {
            AdConstants.AD_TYPE_SPLASH -> AdConstants.Events.SPLASH_LOAD_FAIL
            AdConstants.AD_TYPE_INTERSTITIAL -> AdConstants.Events.INTERSTITIAL_LOAD_FAIL
            AdConstants.AD_TYPE_REWARD_VIDEO -> AdConstants.Events.REWARD_VIDEO_LOAD_FAIL
            AdConstants.AD_TYPE_FEED -> AdConstants.Events.FEED_LOAD_FAIL
            AdConstants.AD_TYPE_DRAW_FEED -> AdConstants.Events.DRAW_FEED_LOAD_FAIL
            AdConstants.AD_TYPE_BANNER -> AdConstants.Events.BANNER_LOAD_FAIL
            else -> "${adType}_load_fail"
        }
        sendAdEvent(action, posId, mapOf(
            "message" to errorMsg,
            "code" to errorCode
        ))
    }

    /**
     * 发送Banner专用事件
     */
    fun sendBannerEvent(action: String, posId: String, extra: Map<String, Any>? = null) {
        sendAdEvent(action, posId, extra)
    }

    /**
     * 发送Banner错误事件
     */
    fun sendBannerErrorEvent(action: String, posId: String, errorCode: Int, errorMsg: String) {
        sendAdEvent(action, posId, mapOf(
            "message" to errorMsg,
            "code" to errorCode,
            "adType" to AdConstants.AD_TYPE_BANNER
        ))
    }

    /**
     * 发送Banner ECPM事件
     */
    fun sendBannerEcpmEvent(posId: String, ecpmData: Map<String, Any>) {
        sendAdEvent(AdConstants.Events.BANNER_ECPM, posId, ecpmData)
    }

    /**
     * 更新事件通道
     */
    fun updateEventSink(eventSink: EventChannel.EventSink?) {
        this.eventSink = eventSink
    }

    companion object {
        @Volatile
        private var INSTANCE: AdEventHelper? = null

        /**
         * 获取单例实例
         */
        fun getInstance(eventSink: EventChannel.EventSink? = null): AdEventHelper {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: AdEventHelper(eventSink).also { INSTANCE = it }
            }
        }
    }
}
