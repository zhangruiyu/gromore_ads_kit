import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gromore_ads_kit/gromore_ads_kit.dart';
import 'package:gromore_ads_kit/gromore_ads_kit_platform_interface.dart';
import 'package:gromore_ads_kit/gromore_ads_kit_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockGromoreAdsKitPlatform
    with MockPlatformInterfaceMixin
    implements GromoreAdsKitPlatform {
  MockGromoreAdsKitPlatform();

  final StreamController<Map<String, dynamic>> _controller =
      StreamController<Map<String, dynamic>>.broadcast();

  @override
  Stream<Map<String, dynamic>> get adEventStream => _controller.stream;

  @override
  Future<bool> requestIdfa() => Future.value(true);

  @override
  Future<bool> requestPermissionIfNecessary() => Future.value(true);

  @override
  Future<bool> initAd(Map<String, dynamic> params) => Future.value(true);

  @override
  Future<bool> isReady(Map<String, dynamic> params) => Future.value(true);

  @override
  Future<List<Map<dynamic, dynamic>>> getAdLoadInfo(
    Map<String, dynamic> params,
  ) => Future.value(const <Map<dynamic, dynamic>>[
    <String, dynamic>{
      'mediationRit': 'rit_1',
      'adnName': 'CSJ',
      'adType': 'rewardVideo',
      'errorCode': 0,
      'errorMessage': '',
    },
  ]);

  @override
  Future<bool> preload(Map<String, dynamic> params) => Future.value(true);

  @override
  Future<bool> showSplashAd(Map<String, dynamic> params) => Future.value(true);

  @override
  Future<bool> loadInterstitialAd(Map<String, dynamic> params) =>
      Future.value(true);

  @override
  Future<bool> showInterstitialAd(String posId) => Future.value(true);

  @override
  Future<bool> loadRewardVideoAd(Map<String, dynamic> params) =>
      Future.value(true);

  @override
  Future<bool> showRewardVideoAd(String posId) => Future.value(true);

  @override
  Future<List<int>> loadFeedAd(Map<String, dynamic> params) =>
      Future.value(const <int>[]);

  @override
  Future<bool> clearFeedAd(List<int> ids) => Future.value(true);

  @override
  Future<List<int>> loadDrawFeedAd(Map<String, dynamic> params) =>
      Future.value(const <int>[]);

  @override
  Future<bool> clearDrawFeedAd(List<int> ids) => Future.value(true);

  @override
  Future<bool> loadBannerAd(Map<String, dynamic> params) => Future.value(true);

  @override
  Future<bool> showBannerAd() => Future.value(true);

  @override
  Future<bool> destroyBannerAd() => Future.value(true);

  @override
  Future<bool> launchTestTools() => Future.value(true);

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final GromoreAdsKitPlatform initialPlatform = GromoreAdsKitPlatform.instance;

  test('$MethodChannelGromoreAdsKit is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelGromoreAdsKit>());
  });

  test('getPlatformVersion', () async {
    MockGromoreAdsKitPlatform fakePlatform = MockGromoreAdsKitPlatform();
    GromoreAdsKitPlatform.instance = fakePlatform;

    expect(await GromoreAdsKit.getPlatformVersion, '42');
  });

  test('ECPM parser accepts current Android and iOS native keys', () {
    final event = AdEcpmEvent.fromMap({
      'action': 'reward_video_ecpm_info',
      'posId': 'reward_pos',
      'timestamp': 1,
      'extra': {
        'ecpm': '12.5',
        'platform': 'CSJ',
        'slotID': 'slot_1',
        'requestID': 'request_1',
      },
    });

    expect(event.ecpm, 12.5);
    expect(event.networkName, 'CSJ');
    expect(event.adnId, 'slot_1');
    expect(event.requestId, 'request_1');
  });

  test('preload rejects ad types not supported by GroMore', () {
    expect(
      () => GromoreAdsKit.preload(
        configs: const [
          PreloadConfig.banner(['banner_pos']),
        ],
      ),
      throwsArgumentError,
    );
  });

  test('privacy config only serializes explicitly supplied values', () {
    const privacy = AdPrivacyConfig(
      canUseLocation: false,
      canUseOaid: true,
      customIdfa: 'idfa_from_host',
    );

    expect(privacy.toMap(), {
      'canUseLocation': false,
      'canUseOaid': true,
      'customIdfa': 'idfa_from_host',
    });
  });

  test('diagnostics parses native load info', () async {
    GromoreAdsKitPlatform.instance = MockGromoreAdsKitPlatform();

    expect(await GromoreAdsKit.isReady(AdType.rewardVideo), isTrue);
    final info = await GromoreAdsKit.getAdLoadInfo(AdType.rewardVideo);
    expect(info, hasLength(1));
    expect(info.single.adnName, 'CSJ');
    expect(info.single.errorCode, 0);
  });

  test('feed diagnostics requires adId', () {
    expect(() => GromoreAdsKit.getAdLoadInfo(AdType.feed), throwsArgumentError);
  });
}
