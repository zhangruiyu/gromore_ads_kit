import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ohos_platform_view.dart';

/// Banner广告Widget
class AdBannerWidget extends StatefulWidget {
  /// 广告位ID
  final String posId;

  /// 宽度
  final double width;

  /// 高度
  final double height;

  /// 是否可见
  final bool isVisible;

  // ========== 高级参数 ==========

  /// 是否静音播放（聚合功能）
  final bool? mutedIfCan;

  /// 音量大小 0.0-1.0（仅Android）
  final double? volume;

  /// 是否开启竞价结果回传（聚合功能）
  final bool? bidNotify;

  /// 场景ID（聚合功能）
  final String? scenarioId;

  /// 是否使用SurfaceView（仅Android）
  final bool? useSurfaceView;

  /// 启用Banner混出信息流（聚合功能）
  final bool? enableMixedMode;

  /// HarmonyOS 直连穿山甲时使用原生自渲染 Banner。
  ///
  /// GroMore 鸿蒙聚合 Banner 官方暂不支持自渲染，聚合广告位不要开启。
  final bool? harmonyNativeRender;

  /// 扩展参数
  final Map<String, dynamic>? extraParams;

  // ========== 事件回调 ==========

  /// 加载回调
  final VoidCallback? onAdLoaded;

  /// 错误回调
  final Function(String error)? onAdError;

  /// 点击回调
  final VoidCallback? onAdClicked;

  /// 关闭回调
  final VoidCallback? onAdClosed;

  /// 渲染成功回调
  final Function(double width, double height)? onRenderSuccess;

  /// 渲染失败回调
  final Function(String error)? onRenderFail;

  /// ECPM信息回调
  final Function(Map<String, dynamic> ecpmData)? onEcpmInfo;

  /// 混出信息流布局回调
  final VoidCallback? onMixedLayout;

  const AdBannerWidget({
    super.key,
    required this.posId,
    this.width = 375,
    this.height = 60,
    this.isVisible = true,
    // 高级参数
    this.mutedIfCan,
    this.volume,
    this.bidNotify,
    this.scenarioId,
    this.useSurfaceView,
    this.enableMixedMode,
    this.harmonyNativeRender,
    this.extraParams,
    // 事件回调
    this.onAdLoaded,
    this.onAdError,
    this.onAdClicked,
    this.onAdClosed,
    this.onRenderSuccess,
    this.onRenderFail,
    this.onEcpmInfo,
    this.onMixedLayout,
  });

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  static const MethodChannel _pluginChannel = MethodChannel('gromore_ads_kit');

  Future<bool>? _harmonyBannerReady;

  @override
  void didUpdateWidget(covariant AdBannerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.posId != widget.posId ||
        oldWidget.width != widget.width ||
        oldWidget.height != widget.height ||
        oldWidget.mutedIfCan != widget.mutedIfCan ||
        oldWidget.bidNotify != widget.bidNotify ||
        oldWidget.scenarioId != widget.scenarioId ||
        oldWidget.enableMixedMode != widget.enableMixedMode ||
        oldWidget.harmonyNativeRender != widget.harmonyNativeRender ||
        oldWidget.extraParams != widget.extraParams) {
      _harmonyBannerReady = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) {
      return const SizedBox.shrink();
    }

    // 根据平台选择对应的原生视图
    const String viewType = 'gromore_ads_kit_banner';

    // 创建参数Map
    final Map<String, dynamic> creationParams = <String, dynamic>{
      'posId': widget.posId,
      'width': widget.width.toInt(),
      'height': widget.height.toInt(),
    };

    // 添加高级参数（只添加非null的参数）
    if (widget.mutedIfCan != null) {
      creationParams['mutedIfCan'] = widget.mutedIfCan;
    }
    if (widget.volume != null) {
      creationParams['volume'] = widget.volume;
    }
    if (widget.bidNotify != null) {
      creationParams['bidNotify'] = widget.bidNotify;
    }
    if (widget.scenarioId != null) {
      creationParams['scenarioId'] = widget.scenarioId;
    }
    if (widget.useSurfaceView != null) {
      creationParams['useSurfaceView'] = widget.useSurfaceView;
    }
    if (widget.enableMixedMode != null) {
      creationParams['enableMixedMode'] = widget.enableMixedMode;
    }
    if (widget.harmonyNativeRender != null) {
      creationParams['harmonyNativeRender'] = widget.harmonyNativeRender;
    }
    if (widget.extraParams != null) {
      creationParams['extraParams'] = widget.extraParams;
    }

    if (isGromoreOhosPlatform) {
      _harmonyBannerReady ??= _loadHarmonyBanner(creationParams);
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: FutureBuilder<bool>(
          future: _harmonyBannerReady,
          builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
            if (snapshot.data != true) {
              return const SizedBox.shrink();
            }
            return buildGromoreOhosPlatformView(
              viewType: viewType,
              creationParams: creationParams,
              onPlatformViewCreated: _onPlatformViewCreated,
              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                Factory<OneSequenceGestureRecognizer>(
                  () => EagerGestureRecognizer(),
                ),
              },
            );
          },
        ),
      );
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: defaultTargetPlatform == TargetPlatform.android
          ? AndroidView(
              viewType: viewType,
              layoutDirection: TextDirection.ltr,
              creationParams: creationParams,
              creationParamsCodec: const StandardMessageCodec(),
              onPlatformViewCreated: _onPlatformViewCreated,
              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                Factory<OneSequenceGestureRecognizer>(
                  () => EagerGestureRecognizer(),
                ),
              },
            )
          : UiKitView(
              viewType: viewType,
              layoutDirection: TextDirection.ltr,
              creationParams: creationParams,
              creationParamsCodec: const StandardMessageCodec(),
              onPlatformViewCreated: _onPlatformViewCreated,
              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                Factory<OneSequenceGestureRecognizer>(
                  () => EagerGestureRecognizer(),
                ),
              },
            ),
    );
  }

  Future<bool> _loadHarmonyBanner(Map<String, dynamic> params) async {
    try {
      return await _pluginChannel.invokeMethod<bool>('loadBannerAd', params) ??
          false;
    } on PlatformException catch (error) {
      widget.onAdError?.call(error.message ?? error.code);
      return false;
    }
  }

  void _onPlatformViewCreated(int id) {
    // 创建与原生端通信的MethodChannel
    final MethodChannel channel = MethodChannel('gromore_ads_kit_banner_$id');

    // 设置方法调用处理器
    channel.setMethodCallHandler((MethodCall call) async {
      switch (call.method) {
        case 'onAdLoaded':
          widget.onAdLoaded?.call();
          break;
        case 'onAdError':
          final String error = call.arguments as String;
          widget.onAdError?.call(error);
          break;
        case 'onAdClicked':
          widget.onAdClicked?.call();
          break;
        case 'onAdClosed':
          widget.onAdClosed?.call();
          break;
        case 'onRenderSuccess':
          if (call.arguments is Map) {
            final args = call.arguments as Map;
            final double width = (args['width'] as num?)?.toDouble() ?? 0.0;
            final double height = (args['height'] as num?)?.toDouble() ?? 0.0;
            widget.onRenderSuccess?.call(width, height);
          }
          break;
        case 'onRenderFail':
          final String error = call.arguments as String;
          widget.onRenderFail?.call(error);
          break;
        case 'onEcpmInfo':
          if (call.arguments is Map) {
            final Map<String, dynamic> ecpmData = Map<String, dynamic>.from(
              call.arguments as Map,
            );
            widget.onEcpmInfo?.call(ecpmData);
          }
          break;
        case 'onMixedLayout':
          widget.onMixedLayout?.call();
          break;
      }
    });
  }
}
