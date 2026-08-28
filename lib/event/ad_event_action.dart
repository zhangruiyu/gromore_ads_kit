/// 广告事件动作枚举
class AdEventAction {
  // 开屏广告事件
  static const String splashLoaded = 'splash_loaded';
  static const String splashShowed = 'splash_showed';
  static const String splashClicked = 'splash_clicked';
  static const String splashSkipped = 'splash_skipped';
  static const String splashClosed = 'splash_closed';
  static const String splashTimeOver = 'splash_time_over';
  static const String splashLoadError = 'splash_load_fail';
  static const String splashRenderFail = 'splash_render_fail';
  static const String splashRenderSuccess = 'splash_render_success';
  static const String splashEcpm = 'splash_ecpm';
  static const String splashCardReady = 'splash_card_ready';
  static const String splashCardClicked = 'splash_card_clicked';
  static const String splashCardClosed = 'splash_card_closed';
  static const String splashZoomOutReady = 'splash_zoom_out_ready';
  static const String splashZoomOutClicked = 'splash_zoom_out_clicked';
  static const String splashZoomOutClosed = 'splash_zoom_out_closed';
  static const String splashResume = 'splash_resume';
  static const String splashViewControllerClosed =
      'splash_view_controller_closed';
  static const String splashVideoFinished = 'splash_video_finished';

  // 插屏广告事件
  static const String interstitialLoaded = 'interstitial_loaded';
  static const String interstitialCached = 'interstitial_cached';
  static const String interstitialShowed = 'interstitial_showed';
  static const String interstitialClicked = 'interstitial_clicked';
  static const String interstitialClosed = 'interstitial_closed';
  static const String interstitialCompleted = 'interstitial_completed';
  static const String interstitialSkipped = 'interstitial_skipped';
  static const String interstitialLoadError = 'interstitial_load_fail';
  static const String interstitialRenderSuccess = 'interstitial_render_success';
  static const String interstitialRenderFail = 'interstitial_render_fail';
  static const String interstitialVideoDownloaded =
      'interstitial_video_downloaded';
  static const String interstitialWillClose = 'interstitial_will_close';
  static const String interstitialWillPresentModal =
      'interstitial_will_present_modal';
  static const String interstitialRewardSucceed = 'interstitial_reward_succeed';
  static const String interstitialRewardFail = 'interstitial_reward_fail';
  static const String interstitialEcpmInfo = 'interstitial_ecpm_info';

  // 激励视频事件
  static const String rewardVideoLoaded = 'reward_video_loaded';
  static const String rewardVideoCached = 'reward_video_cached';
  static const String rewardVideoShowed = 'reward_video_showed';
  static const String rewardVideoClicked = 'reward_video_clicked';
  static const String rewardVideoClosed = 'reward_video_closed';
  static const String rewardVideoCompleted = 'reward_video_completed';
  static const String rewardVideoSkipped = 'reward_video_skipped';
  static const String rewardVideoRewarded = 'reward_video_rewarded';
  static const String rewardVideoLoadError = 'reward_video_load_fail';
  static const String rewardVideoRenderSuccess = 'reward_video_render_success';
  static const String rewardVideoDownloadSuccess =
      'reward_video_download_success';
  static const String rewardVideoWillShow = 'reward_video_will_show';
  static const String rewardVideoEcpmInfo = 'reward_video_ecpm_info';
  static const String rewardVideoError = 'reward_video_error';
  static const String rewardVideoRewardFail = 'reward_video_reward_fail';
  static const String rewardVideoPlayAgainShowed =
      'reward_video_play_again_showed';
  static const String rewardVideoPlayAgainClicked =
      'reward_video_play_again_clicked';
  static const String rewardVideoPlayAgainClosed =
      'reward_video_play_again_closed';
  static const String rewardVideoPlayAgainCompleted =
      'reward_video_play_again_completed';
  static const String rewardVideoPlayAgainError =
      'reward_video_play_again_error';
  static const String rewardVideoPlayAgainRewarded =
      'reward_video_play_again_rewarded';
  static const String rewardVideoPlayAgainSkipped =
      'reward_video_play_again_skipped';

  // 激励奖励通用事件
  static const String rewardVerify = 'reward_verify';
  static const String rewardComplete = 'reward_complete';

  // Banner广告事件
  static const String bannerLoaded = 'banner_loaded';
  static const String bannerShowed = 'banner_showed';
  static const String bannerClicked = 'banner_clicked';
  static const String bannerClosed = 'banner_closed';
  static const String bannerDestroyed = 'banner_destroyed';
  static const String bannerLoadError = 'banner_load_fail';
  static const String bannerRenderSuccess = 'banner_render_success';
  static const String bannerRenderFail = 'banner_render_fail';
  static const String bannerLoadStart = 'banner_load_start';
  static const String bannerEcpm = 'banner_ecpm';
  static const String bannerWillShow = 'banner_will_show';
  static const String bannerDislike = 'banner_dislike';
  static const String bannerResume = 'banner_resume';
  static const String bannerMixedLayout = 'banner_mixed_layout';

  // 信息流广告事件
  static const String feedLoaded = 'feed_loaded';
  static const String feedShowed = 'feed_showed';
  static const String feedClicked = 'feed_clicked';
  static const String feedClosed = 'feed_closed';
  static const String feedDestroyed = 'feed_destroyed';
  static const String feedLoadError = 'feed_load_fail';

  // Draw信息流广告事件
  static const String drawFeedLoaded = 'draw_feed_loaded';
  static const String drawFeedShowed = 'draw_feed_showed';
  static const String drawFeedClicked = 'draw_feed_clicked';
  static const String drawFeedClosed = 'draw_feed_closed';
  static const String drawFeedDestroyed = 'draw_feed_destroyed';
  static const String drawFeedLoadError = 'draw_feed_load_fail';
}
