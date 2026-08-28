import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'gromore_ads_kit_method_channel.dart';

/// Base contract for communicating with the underlying GroMore implementations.
abstract class GromoreAdsKitPlatform extends PlatformInterface {
  GromoreAdsKitPlatform() : super(token: _token);

  static final Object _token = Object();

  static GromoreAdsKitPlatform _instance = MethodChannelGromoreAdsKit();

  /// The active platform implementation.
  static GromoreAdsKitPlatform get instance => _instance;

  static set instance(GromoreAdsKitPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Broadcast stream with raw events from the native side.
  Stream<Map<String, dynamic>> get adEventStream {
    throw UnimplementedError('adEventStream has not been implemented.');
  }

  Future<bool> requestIdfa() {
    throw UnimplementedError('requestIdfa() has not been implemented.');
  }

  Future<bool> requestPermissionIfNecessary() {
    throw UnimplementedError(
      'requestPermissionIfNecessary() has not been implemented.',
    );
  }

  Future<bool> initAd(Map<String, dynamic> params) {
    throw UnimplementedError('initAd() has not been implemented.');
  }

  Future<bool> isReady(Map<String, dynamic> params) {
    throw UnimplementedError('isReady() has not been implemented.');
  }

  Future<List<Map<dynamic, dynamic>>> getAdLoadInfo(
    Map<String, dynamic> params,
  ) {
    throw UnimplementedError('getAdLoadInfo() has not been implemented.');
  }

  Future<bool> preload(Map<String, dynamic> params) {
    throw UnimplementedError('preload() has not been implemented.');
  }

  Future<bool> showSplashAd(Map<String, dynamic> params) {
    throw UnimplementedError('showSplashAd() has not been implemented.');
  }

  Future<bool> loadInterstitialAd(Map<String, dynamic> params) {
    throw UnimplementedError('loadInterstitialAd() has not been implemented.');
  }

  Future<bool> showInterstitialAd(String posId) {
    throw UnimplementedError('showInterstitialAd() has not been implemented.');
  }

  Future<bool> loadRewardVideoAd(Map<String, dynamic> params) {
    throw UnimplementedError('loadRewardVideoAd() has not been implemented.');
  }

  Future<bool> showRewardVideoAd(String posId) {
    throw UnimplementedError('showRewardVideoAd() has not been implemented.');
  }

  Future<List<int>> loadFeedAd(Map<String, dynamic> params) {
    throw UnimplementedError('loadFeedAd() has not been implemented.');
  }

  Future<bool> clearFeedAd(List<int> ids) {
    throw UnimplementedError('clearFeedAd() has not been implemented.');
  }

  Future<List<int>> loadDrawFeedAd(Map<String, dynamic> params) {
    throw UnimplementedError('loadDrawFeedAd() has not been implemented.');
  }

  Future<bool> clearDrawFeedAd(List<int> ids) {
    throw UnimplementedError('clearDrawFeedAd() has not been implemented.');
  }

  Future<bool> loadBannerAd(Map<String, dynamic> params) {
    throw UnimplementedError('loadBannerAd() has not been implemented.');
  }

  Future<bool> showBannerAd() {
    throw UnimplementedError('showBannerAd() has not been implemented.');
  }

  Future<bool> destroyBannerAd() {
    throw UnimplementedError('destroyBannerAd() has not been implemented.');
  }

  Future<bool> launchTestTools() {
    throw UnimplementedError('launchTestTools() has not been implemented.');
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('getPlatformVersion() has not been implemented.');
  }
}
