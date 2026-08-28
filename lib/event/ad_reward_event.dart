import 'ad_event.dart';

String? _rewardAsString(dynamic value) =>
    value is String ? value : value?.toString();

int? _rewardAsInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

bool _rewardAsBool(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final str = value.toString().toLowerCase();
  return str == 'true' || str == '1';
}

/// 激励视频奖励事件
class AdRewardEvent extends AdEvent {
  /// 奖励类型
  final String? rewardType;

  /// 奖励数量
  final int? rewardAmount;

  /// 是否验证通过
  final bool verified;

  const AdRewardEvent({
    required super.action,
    required super.posId,
    required super.timestamp,
    this.rewardType,
    this.rewardAmount,
    this.verified = false,
    super.extra,
  });

  /// 从Map创建奖励事件对象
  factory AdRewardEvent.fromMap(Map<String, dynamic> map) {
    final base = AdEvent.fromMap(map);
    final Map<String, dynamic> extra = base.extra ?? const <String, dynamic>{};

    final rewardType =
        _rewardAsString(map['rewardType']) ??
        _rewardAsString(extra['rewardType']);

    final rewardAmount =
        _rewardAsInt(map['rewardAmount']) ??
        _rewardAsInt(extra['rewardAmount']);

    final verified =
        _rewardAsBool(map['verified']) || _rewardAsBool(extra['verified']);

    return AdRewardEvent(
      action: base.action,
      posId: base.posId,
      timestamp: base.timestamp,
      rewardType: rewardType,
      rewardAmount: rewardAmount,
      verified: verified,
      extra: base.extra,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map.addAll({
      'verified': verified,
      if (rewardType != null) 'rewardType': rewardType,
      if (rewardAmount != null) 'rewardAmount': rewardAmount,
    });
    return map;
  }

  @override
  String toString() {
    return 'AdRewardEvent(action: $action, posId: $posId, rewardType: $rewardType, rewardAmount: $rewardAmount, verified: $verified, timestamp: $timestamp)';
  }
}
