/// 插件支持查询状态和瀑布流信息的广告类型。
abstract final class AdType {
  static const String splash = 'splash';
  static const String interstitial = 'interstitial';
  static const String rewardVideo = 'rewardVideo';
  static const String feed = 'feed';
  static const String drawFeed = 'drawFeed';
  static const String banner = 'banner';

  static const Set<String> values = <String>{
    splash,
    interstitial,
    rewardVideo,
    feed,
    drawFeed,
    banner,
  };
}

/// GroMore 单个 ADN 在本次瀑布流请求中的加载结果。
class AdLoadInfo {
  const AdLoadInfo({
    required this.mediationRit,
    required this.adnName,
    required this.adType,
    required this.errorCode,
    required this.errorMessage,
    this.customAdnName,
    this.errorUserInfo,
  });

  factory AdLoadInfo.fromMap(Map<dynamic, dynamic> map) {
    return AdLoadInfo(
      mediationRit: map['mediationRit']?.toString() ?? '',
      adnName: map['adnName']?.toString() ?? '',
      adType: map['adType']?.toString() ?? '',
      errorCode: _toInt(map['errorCode']),
      errorMessage: map['errorMessage']?.toString() ?? '',
      customAdnName: map['customAdnName']?.toString(),
      errorUserInfo: _toStringMap(map['errorUserInfo']),
    );
  }

  final String mediationRit;
  final String adnName;
  final String adType;
  final int errorCode;
  final String errorMessage;

  /// iOS 自定义 ADN 名称；Android 通常为空。
  final String? customAdnName;

  /// iOS SDK 返回的补充错误信息。
  final Map<String, String>? errorUserInfo;

  static int _toInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static Map<String, String>? _toStringMap(Object? value) {
    if (value is! Map) return null;
    return value.map<String, String>(
      (dynamic key, dynamic item) => MapEntry(key.toString(), item.toString()),
    );
  }
}
