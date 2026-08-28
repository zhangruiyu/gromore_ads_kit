import 'ad_event.dart';

double? _ecpmAsDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

/// 广告ECPM事件（千次展示收入）
class AdEcpmEvent extends AdEvent {
  /// ECPM值
  final double ecpm;

  /// 广告网络名称
  final String? networkName;

  /// 广告源ID
  final String? adnId;

  /// 渠道/子渠道
  final String? channel;
  final String? subChannel;

  /// 请求信息
  final String? requestId;
  final String? ritType;
  final String? scenarioId;
  final String? levelTag;
  final int? biddingType;
  final Map<String, dynamic>? customData;

  const AdEcpmEvent({
    required super.action,
    required super.posId,
    required super.timestamp,
    required this.ecpm,
    this.networkName,
    this.adnId,
    this.channel,
    this.subChannel,
    this.requestId,
    this.ritType,
    this.scenarioId,
    this.levelTag,
    this.biddingType,
    this.customData,
    super.extra,
  });

  /// 从Map创建ECPM事件对象
  factory AdEcpmEvent.fromMap(Map<String, dynamic> map) {
    final base = AdEvent.fromMap(map);
    final Map<String, dynamic> extra = base.extra ?? const <String, dynamic>{};

    final ecpmValue =
        _ecpmAsDouble(map['ecpm']) ?? _ecpmAsDouble(extra['ecpm']) ?? 0.0;

    final network =
        (map['networkName'] ??
                map['platform'] ??
                extra['networkName'] ??
                extra['sdkName'] ??
                extra['platform'])
            ?.toString();

    final adn =
        (map['adnId'] ??
                map['ritID'] ??
                map['slotID'] ??
                extra['adnId'] ??
                extra['ritID'] ??
                extra['slotID'] ??
                extra['slotId'])
            ?.toString();

    final channel = (map['channel'] ?? extra['channel'])?.toString();
    final subChannel = (map['subChannel'] ?? extra['subChannel'])?.toString();
    final requestId =
        (map['requestId'] ??
                map['requestID'] ??
                extra['requestId'] ??
                extra['requestID'])
            ?.toString();
    final ritType = (map['ritType'] ?? extra['ritType'])?.toString();
    final scenarioId = (map['scenarioId'] ?? extra['scenarioId'])?.toString();
    final levelTag = (map['levelTag'] ?? extra['levelTag'])?.toString();
    final biddingType = _asInt(
      map['reqBiddingType'] ?? extra['reqBiddingType'] ?? extra['biddingType'],
    );
    final customRaw = extra['customData'] ?? map['customData'];
    final customData = customRaw is Map
        ? customRaw.map((key, value) => MapEntry('$key', value))
        : null;

    return AdEcpmEvent(
      action: base.action,
      posId: base.posId,
      timestamp: base.timestamp,
      ecpm: ecpmValue,
      networkName: network,
      adnId: adn,
      channel: channel,
      subChannel: subChannel,
      requestId: requestId,
      ritType: ritType,
      scenarioId: scenarioId,
      levelTag: levelTag,
      biddingType: biddingType,
      customData: customData,
      extra: base.extra,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map.addAll({
      'ecpm': ecpm,
      if (networkName != null) 'networkName': networkName,
      if (adnId != null) 'adnId': adnId,
      if (channel != null) 'channel': channel,
      if (subChannel != null) 'subChannel': subChannel,
      if (requestId != null) 'requestId': requestId,
      if (ritType != null) 'ritType': ritType,
      if (scenarioId != null) 'scenarioId': scenarioId,
      if (levelTag != null) 'levelTag': levelTag,
      if (biddingType != null) 'reqBiddingType': biddingType,
      if (customData != null) 'customData': customData,
    });
    return map;
  }

  @override
  String toString() {
    return 'AdEcpmEvent(action: $action, posId: $posId, ecpm: $ecpm, networkName: $networkName, adnId: $adnId, timestamp: $timestamp)';
  }
}
