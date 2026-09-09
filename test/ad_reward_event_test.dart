import 'package:flutter_test/flutter_test.dart';
import 'package:gromore_ads_kit/gromore_ads_kit.dart';

void main() {
  group('原生广告奖励验证结果', () {
    for (final key in ['verify', 'verified']) {
      for (final nested in [false, true]) {
        for (final value in [true, 1, 'true', '1', false, 0, 'false', '0']) {
          test('$key=$value，extra=$nested', () {
            final payload = <String, dynamic>{key: value};
            final event = AdRewardEvent.fromMap({
              'action': AdEventAction.rewardVideoRewarded,
              'posId': 'reward-test',
              'timestamp': 1,
              if (nested) 'extra': payload else ...payload,
            });

            expect(event.verified, [true, 1, 'true', '1'].contains(value));
          });
        }
      }
    }

    test('没有验证结果时不发奖励', () {
      final event = AdRewardEvent.fromMap({
        'action': AdEventAction.rewardVideoRewarded,
        'posId': 'reward-test',
        'timestamp': 1,
        'extra': {'rewardAmount': 3},
      });
      expect(event.verified, isFalse);
    });
  });
}
