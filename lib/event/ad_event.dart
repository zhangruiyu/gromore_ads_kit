/// 提取事件额外数据。
Map<String, dynamic>? extractEventExtra(Map<String, dynamic> map) {
  final dynamic rawExtra = map['extra'];
  if (rawExtra is Map) {
    return rawExtra.map((key, value) => MapEntry('$key', value));
  }

  final fallback = <String, dynamic>{};
  map.forEach((key, value) {
    if (key == 'action' ||
        key == 'posId' ||
        key == 'timestamp' ||
        key == 'extra') {
      return;
    }
    fallback[key] = value;
  });
  return fallback.isEmpty ? null : fallback;
}

int _parseTimestamp(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  throw ArgumentError('Invalid timestamp value: $value');
}

/// 广告事件基类
class AdEvent {
  /// 事件动作
  final String action;

  /// 广告位ID
  final String posId;

  /// 时间戳
  final int timestamp;

  /// 额外数据
  final Map<String, dynamic>? extra;

  const AdEvent({
    required this.action,
    required this.posId,
    required this.timestamp,
    this.extra,
  });

  /// 从Map创建事件对象
  factory AdEvent.fromMap(Map<String, dynamic> map) {
    final action = map['action'] as String?;
    final posId = map['posId'] as String?;
    if (action == null || posId == null) {
      throw ArgumentError('Invalid ad event payload: $map');
    }

    return AdEvent(
      action: action,
      posId: posId,
      timestamp: _parseTimestamp(map['timestamp']),
      extra: extractEventExtra(map),
    );
  }

  /// 转换为Map
  Map<String, dynamic> toMap() {
    return {
      'action': action,
      'posId': posId,
      'timestamp': timestamp,
      if (extra != null && extra!.isNotEmpty) 'extra': extra,
    };
  }

  @override
  String toString() {
    return 'AdEvent(action: $action, posId: $posId, timestamp: $timestamp, extra: $extra)';
  }
}
