import Foundation

/**
 * 广告相关常量定义 - iOS版本
 * 与Android版本保持一致
 */
struct AdConstants {

    // 日志标签
    static let TAG = "GromoreAdsKitPlugin"

    // 广告类型
    struct AdType {
        static let splash = "splash"
        static let interstitial = "interstitial"
        static let rewardVideo = "reward_video"
        static let feed = "feed"
        static let drawFeed = "draw_feed"
        static let banner = "banner"
    }

    // 事件类型
    struct Events {
        // 开屏广告事件
        static let splashLoaded = "splash_loaded"
        static let splashShowed = "splash_showed"
        static let splashClicked = "splash_clicked"
        static let splashClosed = "splash_closed"
        static let splashLoadFail = "splash_load_fail"
        static let splashRenderFail = "splash_render_fail"
        static let splashRenderSuccess = "splash_render_success"
        static let splashEcpm = "splash_ecpm"
        static let splashCardReady = "splash_card_ready"
        static let splashCardClicked = "splash_card_clicked"
        static let splashCardClosed = "splash_card_closed"
        static let splashZoomOutReady = "splash_zoom_out_ready"
        static let splashZoomOutClicked = "splash_zoom_out_clicked"
        static let splashZoomOutClosed = "splash_zoom_out_closed"
        static let splashResume = "splash_resume"
        static let splashViewControllerClosed = "splash_view_controller_closed"
        static let splashVideoFinished = "splash_video_finished"

        // 插屏广告事件
        static let interstitialLoaded = "interstitial_loaded"
        static let interstitialCached = "interstitial_cached"
        static let interstitialShowed = "interstitial_showed"
        static let interstitialClicked = "interstitial_clicked"
        static let interstitialClosed = "interstitial_closed"
        static let interstitialCompleted = "interstitial_completed"
        static let interstitialSkipped = "interstitial_skipped"
        static let interstitialLoadFail = "interstitial_load_fail"
        static let interstitialRenderSuccess = "interstitial_render_success"
        static let interstitialRenderFail = "interstitial_render_fail"
        static let interstitialVideoDownloaded = "interstitial_video_downloaded"
        static let interstitialWillClose = "interstitial_will_close"
        static let interstitialWillPresentModal = "interstitial_will_present_modal"
        static let interstitialRewardSucceed = "interstitial_reward_succeed"
        static let interstitialRewardFail = "interstitial_reward_fail"
        static let interstitialEcpmInfo = "interstitial_ecpm_info"

        // 激励视频广告事件
        static let rewardVideoLoaded = "reward_video_loaded"
        static let rewardVideoCached = "reward_video_cached"
        static let rewardVideoShowed = "reward_video_showed"
        static let rewardVideoClicked = "reward_video_clicked"
        static let rewardVideoClosed = "reward_video_closed"
        static let rewardVideoCompleted = "reward_video_completed"
        static let rewardVideoSkipped = "reward_video_skipped"
        static let rewardVideoRewarded = "reward_video_rewarded"
        static let rewardVideoLoadFail = "reward_video_load_fail"
        static let rewardVideoRenderSuccess = "reward_video_render_success"
        static let rewardVideoDownloadSuccess = "reward_video_download_success"
        static let rewardVideoWillShow = "reward_video_will_show"
        static let rewardVideoEcpmInfo = "reward_video_ecpm_info"
        static let rewardVideoError = "reward_video_error"
        static let rewardVideoRewardFail = "reward_video_reward_fail"

        // 信息流广告事件
        static let feedLoaded = "feed_loaded"
        static let feedShowed = "feed_showed"
        static let feedClicked = "feed_clicked"
        static let feedClosed = "feed_closed"
        static let feedDestroyed = "feed_destroyed"
        static let feedLoadFail = "feed_load_fail"

        // Draw信息流广告事件
        static let drawFeedLoaded = "draw_feed_loaded"
        static let drawFeedShowed = "draw_feed_showed"
        static let drawFeedClicked = "draw_feed_clicked"
        static let drawFeedClosed = "draw_feed_closed"
        static let drawFeedDestroyed = "draw_feed_destroyed"
        static let drawFeedLoadFail = "draw_feed_load_fail"

        // Banner广告事件
        static let bannerLoadStart = "banner_load_start"
        static let bannerLoaded = "banner_loaded"
        static let bannerRenderSuccess = "banner_render_success"
        static let bannerRenderFail = "banner_render_fail"
        static let bannerShowed = "banner_showed"
        static let bannerClicked = "banner_clicked"
        static let bannerClosed = "banner_closed"
        static let bannerDestroyed = "banner_destroyed"
        static let bannerLoadFail = "banner_load_fail"
        static let bannerEcpm = "banner_ecpm"
        static let bannerDislike = "banner_dislike"
        static let bannerResume = "banner_resume"
        static let bannerMixedLayout = "banner_mixed_layout"
        static let bannerWillShow = "banner_will_show"
    }

    // 错误码
    struct ErrorCodes {
        static let invalidPosId = "INVALID_POS_ID"
        static let noActivity = "NO_ACTIVITY"
        static let activityError = "ACTIVITY_ERROR"
        static let invalidParams = "INVALID_PARAMS"
        static let invalidArguments = "INVALID_ARGUMENTS"
        static let adNotLoaded = "AD_NOT_LOADED"
        static let adNotReady = "AD_NOT_READY"
        static let loadError = "LOAD_ERROR"
        static let showError = "SHOW_ERROR"
        static let networkError = "NETWORK_ERROR"
        static let sdkNotReady = "SDK_NOT_READY"
        static let frequentRequest = "FREQUENT_REQUEST"
        static let preCheckFailed = "PRE_CHECK_FAILED"
        static let alreadyLoading = "ALREADY_LOADING"
        static let noRootController = "NO_ROOT_CONTROLLER"
        static let invalidOperation = "INVALID_OPERATION"
        static let sdkNotInitialized = "SDK_NOT_INITIALIZED"
        static let initFailed = "INIT_FAILED"
        static let versionNotSupported = "VERSION_NOT_SUPPORTED"
        static let debugOnly = "DEBUG_ONLY"
        static let alreadyInitialized = "ALREADY_INITIALIZED"
    }

    // 请求间隔时间（毫秒）
    static let minRequestInterval: Int64 = 3000

    // 广告缓存时间
    static let adCacheTimeout: Int64 = 30000

    // 方向常量
    struct Orientation {
        static let vertical = 1
        static let horizontal = 2
    }
}
