import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gromore_ads_kit/gromore_ads_kit_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelGromoreAdsKit platform = MethodChannelGromoreAdsKit();
  const MethodChannel channel = MethodChannel('gromore_ads_kit');
  const MethodChannel debugToolsChannel = MethodChannel(
    'gromore_ads_kit_debug_tools',
  );

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          return '42';
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(debugToolsChannel, (MethodCall methodCall) async {
          return methodCall.method == 'launchTestTools';
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(debugToolsChannel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });

  test('launchTestTools uses the optional debug tools channel', () async {
    expect(await platform.launchTestTools(), isTrue);
  });
}
