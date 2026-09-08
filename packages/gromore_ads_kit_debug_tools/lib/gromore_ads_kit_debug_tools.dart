import 'package:flutter/services.dart';

/// GroMore 官方广告测试工具入口。
class GromoreAdsKitDebugTools {
  GromoreAdsKitDebugTools._();

  static const MethodChannel _channel = MethodChannel(
    'gromore_ads_kit_debug_tools',
  );

  /// 打开官方广告测试工具。
  static Future<bool> launch() async {
    final bool? launched = await _channel.invokeMethod<bool>('launchTestTools');
    return launched ?? false;
  }
}
