package com.zhecent.gromore_ads_kit.common

/**
 * 广告相关常量定义
 */
object AdConstants {

    // 日志标签
    const val TAG = "GromoreAdsKitPlugin"

    // 广告类型
    const val AD_TYPE_SPLASH = "splash"
    const val AD_TYPE_INTERSTITIAL = "interstitial"
    const val AD_TYPE_REWARD_VIDEO = "reward_video"
    const val AD_TYPE_FEED = "feed"
    const val AD_TYPE_DRAW_FEED = "draw_feed"
    const val AD_TYPE_BANNER = "banner"

    // 事件类型
    object Events {
        // 开屏广告事件
        const val SPLASH_LOADED = "splash_loaded"
        const val SPLASH_SHOWED = "splash_showed"
        const val SPLASH_CLICKED = "splash_clicked"
        const val SPLASH_CLOSED = "splash_closed"
        const val SPLASH_LOAD_FAIL = "splash_load_fail"
        const val SPLASH_RENDER_FAIL = "splash_render_fail"
        const val SPLASH_RENDER_SUCCESS = "splash_render_success"
        const val SPLASH_ECPM = "splash_ecpm"
        const val SPLASH_CARD_READY = "splash_card_ready"
        const val SPLASH_CARD_CLICKED = "splash_card_clicked"
        const val SPLASH_CARD_CLOSED = "splash_card_closed"
        const val SPLASH_ZOOM_OUT_READY = "splash_zoom_out_ready"
        const val SPLASH_ZOOM_OUT_CLICKED = "splash_zoom_out_clicked"
        const val SPLASH_ZOOM_OUT_CLOSED = "splash_zoom_out_closed"
        const val SPLASH_RESUME = "splash_resume"
        const val SPLASH_VIEW_CONTROLLER_CLOSED = "splash_view_controller_closed"
        const val SPLASH_VIDEO_FINISHED = "splash_video_finished"

        // 插屏广告事件
        const val INTERSTITIAL_LOADED = "interstitial_loaded"
        const val INTERSTITIAL_CACHED = "interstitial_cached"
        const val INTERSTITIAL_SHOWED = "interstitial_showed"
        const val INTERSTITIAL_CLICKED = "interstitial_clicked"
        const val INTERSTITIAL_CLOSED = "interstitial_closed"
        const val INTERSTITIAL_COMPLETED = "interstitial_completed"
        const val INTERSTITIAL_SKIPPED = "interstitial_skipped"
        const val INTERSTITIAL_LOAD_FAIL = "interstitial_load_fail"
        const val INTERSTITIAL_RENDER_SUCCESS = "interstitial_render_success"
        const val INTERSTITIAL_RENDER_FAIL = "interstitial_render_fail"
        const val INTERSTITIAL_VIDEO_DOWNLOADED = "interstitial_video_downloaded"
        const val INTERSTITIAL_WILL_CLOSE = "interstitial_will_close"
        const val INTERSTITIAL_WILL_PRESENT_MODAL = "interstitial_will_present_modal"
        const val INTERSTITIAL_REWARD_SUCCEED = "interstitial_reward_succeed"
        const val INTERSTITIAL_REWARD_FAIL = "interstitial_reward_fail"
        const val INTERSTITIAL_ECPM_INFO = "interstitial_ecpm_info"

        // 激励视频广告事件
        const val REWARD_VIDEO_LOADED = "reward_video_loaded"
        const val REWARD_VIDEO_CACHED = "reward_video_cached"
        const val REWARD_VIDEO_SHOWED = "reward_video_showed"
        const val REWARD_VIDEO_CLICKED = "reward_video_clicked"
        const val REWARD_VIDEO_CLOSED = "reward_video_closed"
        const val REWARD_VIDEO_COMPLETED = "reward_video_completed"
        const val REWARD_VIDEO_SKIPPED = "reward_video_skipped"
        const val REWARD_VIDEO_REWARDED = "reward_video_rewarded"
        const val REWARD_VIDEO_LOAD_FAIL = "reward_video_load_fail"
        const val REWARD_VIDEO_RENDER_SUCCESS = "reward_video_render_success"
        const val REWARD_VIDEO_DOWNLOAD_SUCCESS = "reward_video_download_success"
        const val REWARD_VIDEO_WILL_SHOW = "reward_video_will_show"
        const val REWARD_VIDEO_ECPM_INFO = "reward_video_ecpm_info"
        const val REWARD_VIDEO_ERROR = "reward_video_error"
        const val REWARD_VIDEO_REWARD_FAIL = "reward_video_reward_fail"
        const val REWARD_VIDEO_PLAY_AGAIN_SHOWED = "reward_video_play_again_showed"
        const val REWARD_VIDEO_PLAY_AGAIN_CLICKED = "reward_video_play_again_clicked"
        const val REWARD_VIDEO_PLAY_AGAIN_CLOSED = "reward_video_play_again_closed"
        const val REWARD_VIDEO_PLAY_AGAIN_COMPLETED = "reward_video_play_again_completed"
        const val REWARD_VIDEO_PLAY_AGAIN_ERROR = "reward_video_play_again_error"
        const val REWARD_VIDEO_PLAY_AGAIN_REWARDED = "reward_video_play_again_rewarded"
        const val REWARD_VIDEO_PLAY_AGAIN_SKIPPED = "reward_video_play_again_skipped"

        // 信息流广告事件
        const val FEED_LOADED = "feed_loaded"
        const val FEED_SHOWED = "feed_showed"
        const val FEED_CLICKED = "feed_clicked"
        const val FEED_CLOSED = "feed_closed"
        const val FEED_DESTROYED = "feed_destroyed"
        const val FEED_LOAD_FAIL = "feed_load_fail"

        // Draw信息流广告事件
        const val DRAW_FEED_LOADED = "draw_feed_loaded"
        const val DRAW_FEED_SHOWED = "draw_feed_showed"
        const val DRAW_FEED_CLICKED = "draw_feed_clicked"
        const val DRAW_FEED_CLOSED = "draw_feed_closed"
        const val DRAW_FEED_DESTROYED = "draw_feed_destroyed"
        const val DRAW_FEED_LOAD_FAIL = "draw_feed_load_fail"

        // Banner广告事件
        const val BANNER_LOADED = "banner_loaded"
        const val BANNER_SHOWED = "banner_showed"
        const val BANNER_CLICKED = "banner_clicked"
        const val BANNER_CLOSED = "banner_closed"
        const val BANNER_DESTROYED = "banner_destroyed"
        const val BANNER_LOAD_FAIL = "banner_load_fail"
        const val BANNER_RENDER_SUCCESS = "banner_render_success"
        const val BANNER_RENDER_FAIL = "banner_render_fail"
        const val BANNER_LOAD_START = "banner_load_start"
        const val BANNER_ECPM = "banner_ecpm"
        const val BANNER_WILL_SHOW = "banner_will_show"
        const val BANNER_DISLIKE = "banner_dislike"
        const val BANNER_RESUME = "banner_resume"
        const val BANNER_MIXED_LAYOUT = "banner_mixed_layout"
    }

    // 错误码
    object ErrorCodes {
        const val INVALID_POS_ID = "INVALID_POS_ID"
        const val NO_ACTIVITY = "NO_ACTIVITY"
        const val ACTIVITY_ERROR = "ACTIVITY_ERROR"
        const val INVALID_PARAMS = "INVALID_PARAMS"
        const val AD_NOT_LOADED = "AD_NOT_LOADED"
        const val LOAD_ERROR = "LOAD_ERROR"
        const val SHOW_ERROR = "SHOW_ERROR"
        const val NETWORK_ERROR = "NETWORK_ERROR"
        const val SDK_NOT_READY = "SDK_NOT_READY"
        const val FREQUENT_REQUEST = "FREQUENT_REQUEST"
        const val ALREADY_LOADING = "ALREADY_LOADING"
        const val INVALID_OPERATION = "INVALID_OPERATION"
        const val ALREADY_INITIALIZED = "ALREADY_INITIALIZED"
    }

    // 请求间隔时间（毫秒）
    const val MIN_REQUEST_INTERVAL = 3000L

    // 广告缓存时间
    const val AD_CACHE_TIMEOUT = 30000L

    // 方向常量
    const val ORIENTATION_VERTICAL = 1
    const val ORIENTATION_HORIZONTAL = 2
}
