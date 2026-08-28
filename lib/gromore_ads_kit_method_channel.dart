import 'dart:async';

import 'package:flutter/services.dart';

import 'gromore_ads_kit_platform_interface.dart';

/// Default MethodChannel implementation used by Flutter.
class MethodChannelGromoreAdsKit extends GromoreAdsKitPlatform {
  MethodChannelGromoreAdsKit()
    : _methodChannel = const MethodChannel(_methodChannelName),
      _eventChannel = const EventChannel(_eventChannelName);

  static const String _methodChannelName = 'gromore_ads_kit';
  static const String _eventChannelName = 'gromore_ads_kit_event';

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  Stream<Map<String, dynamic>>? _eventStream;

  @override
  Stream<Map<String, dynamic>> get adEventStream {
    return _eventStream ??= _eventChannel
        .receiveBroadcastStream()
        .map<Map<String, dynamic>>(_coerceEventPayload)
        .asBroadcastStream();
  }

  @override
  Future<bool> requestIdfa() {
    return _invokeBool('requestIDFA');
  }

  @override
  Future<bool> requestPermissionIfNecessary() {
    return _invokeBool('requestPermissionIfNecessary');
  }

  @override
  Future<bool> initAd(Map<String, dynamic> params) {
    return _invokeBool('initAd', params);
  }

  @override
  Future<bool> isReady(Map<String, dynamic> params) {
    return _invokeBool('isReady', params);
  }

  @override
  Future<List<Map<dynamic, dynamic>>> getAdLoadInfo(
    Map<String, dynamic> params,
  ) async {
    final List<dynamic>? raw = await _methodChannel.invokeMethod<List<dynamic>>(
      'getAdLoadInfo',
      params,
    );
    if (raw == null) return const <Map<dynamic, dynamic>>[];
    return raw.whereType<Map>().toList(growable: false);
  }

  @override
  Future<bool> preload(Map<String, dynamic> params) {
    return _invokeBool('preload', params);
  }

  @override
  Future<bool> showSplashAd(Map<String, dynamic> params) {
    return _invokeBool('showSplashAd', params);
  }

  @override
  Future<bool> loadInterstitialAd(Map<String, dynamic> params) {
    return _invokeBool('loadInterstitialAd', params);
  }

  @override
  Future<bool> showInterstitialAd(String posId) {
    return _invokeBool('showInterstitialAd', {'posId': posId});
  }

  @override
  Future<bool> loadRewardVideoAd(Map<String, dynamic> params) {
    return _invokeBool('loadRewardVideoAd', params);
  }

  @override
  Future<bool> showRewardVideoAd(String posId) {
    return _invokeBool('showRewardVideoAd', {'posId': posId});
  }

  @override
  Future<List<int>> loadFeedAd(Map<String, dynamic> params) {
    return _invokeIntList('loadFeedAd', params);
  }

  @override
  Future<bool> clearFeedAd(List<int> ids) {
    return _invokeBool('clearFeedAd', {'list': ids});
  }

  @override
  Future<List<int>> loadDrawFeedAd(Map<String, dynamic> params) {
    return _invokeIntList('loadDrawFeedAd', params);
  }

  @override
  Future<bool> clearDrawFeedAd(List<int> ids) {
    return _invokeBool('clearDrawFeedAd', {'list': ids});
  }

  @override
  Future<bool> loadBannerAd(Map<String, dynamic> params) {
    return _invokeBool('loadBannerAd', params);
  }

  @override
  Future<bool> showBannerAd() {
    return _invokeBool('showBannerAd');
  }

  @override
  Future<bool> destroyBannerAd() {
    return _invokeBool('destroyBannerAd');
  }

  @override
  Future<bool> launchTestTools() {
    return _invokeBool('launchTestTools');
  }

  @override
  Future<String?> getPlatformVersion() {
    return _methodChannel.invokeMethod<String>('getPlatformVersion');
  }

  Future<bool> _invokeBool(
    String method, [
    Map<String, dynamic>? params,
  ]) async {
    final bool? value = await _methodChannel.invokeMethod<bool>(method, params);
    return value ?? false;
  }

  Future<List<int>> _invokeIntList(
    String method,
    Map<String, dynamic> params,
  ) async {
    final List<dynamic>? raw = await _methodChannel.invokeMethod<List<dynamic>>(
      method,
      params,
    );
    if (raw == null) {
      return const <int>[];
    }
    return raw
        .map<int?>(
          (dynamic value) => value is int
              ? value
              : value is num
              ? value.toInt()
              : int.tryParse(value.toString()),
        )
        .whereType<int>()
        .toList(growable: false);
  }

  Map<String, dynamic> _coerceEventPayload(dynamic raw) {
    if (raw is Map) {
      return raw.map<String, dynamic>(
        (dynamic key, dynamic value) => MapEntry(key.toString(), value),
      );
    }
    throw ArgumentError(
      'Expected event payload to be a Map but found ${raw.runtimeType}',
    );
  }
}
