import 'ad_event.dart';

String? _asString(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  return value.toString();
}

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

/// 广告错误事件
class AdErrorEvent extends AdEvent {
  /// 错误码
  final int? code;

  /// 错误消息
  final String message;

  const AdErrorEvent({
    required super.action,
    required super.posId,
    required super.timestamp,
    required this.message,
    this.code,
    super.extra,
  });

  /// 从Map创建错误事件对象
  factory AdErrorEvent.fromMap(Map<String, dynamic> map) {
    final base = AdEvent.fromMap(map);
    final Map<String, dynamic> extra = base.extra ?? const <String, dynamic>{};

    final message =
        _asString(map['message']) ??
        _asString(map['error']) ??
        _asString(extra['message']) ??
        _asString(extra['error']) ??
        _asString(extra['errorMessage']) ??
        'Unknown error';

    final code =
        _asInt(map['code']) ??
        _asInt(map['errorCode']) ??
        _asInt(extra['code']) ??
        _asInt(extra['errorCode']);

    return AdErrorEvent(
      action: base.action,
      posId: base.posId,
      timestamp: base.timestamp,
      message: message,
      code: code,
      extra: base.extra,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map.addAll({'message': message, if (code != null) 'code': code});
    return map;
  }

  @override
  String toString() {
    return 'AdErrorEvent(action: $action, posId: $posId, message: $message, code: $code, timestamp: $timestamp)';
  }
}
