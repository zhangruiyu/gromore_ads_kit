import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ohos_platform_view.dart';

/// Draw信息流广告Widget
/// 用于展示Draw类型的信息流广告，区别于传统信息流广告
/// Draw广告支持特殊的视频控制、自定义渲染等功能
class AdDrawFeedWidget extends StatefulWidget {
  /// 广告位ID
  final String posId;

  /// 广告数据ID（从loadDrawFeedAd返回的ID）
  final int adId;

  /// 宽度
  final double width;

  /// 高度
  final double height;

  /// 是否可见
  final bool isVisible;

  /// 加载回调
  final VoidCallback? onAdLoaded;

  /// 错误回调
  final Function(String error)? onAdError;

  /// 点击回调
  final VoidCallback? onAdClicked;

  /// 关闭回调
  final VoidCallback? onAdClosed;

  /// 渲染成功回调
  final VoidCallback? onAdRenderSuccess;

  /// 渲染失败回调
  final Function(String error)? onAdRenderFail;

  /// Draw广告特有：视频播放回调
  final VoidCallback? onVideoPlay;

  /// Draw广告特有：视频暂停回调
  final VoidCallback? onVideoPause;

  /// Draw广告特有：视频播放完成回调
  final VoidCallback? onVideoComplete;

  const AdDrawFeedWidget({
    super.key,
    required this.posId,
    required this.adId,
    this.width = 375,
    this.height = 300,
    this.isVisible = true,
    this.onAdLoaded,
    this.onAdError,
    this.onAdClicked,
    this.onAdClosed,
    this.onAdRenderSuccess,
    this.onAdRenderFail,
    this.onVideoPlay,
    this.onVideoPause,
    this.onVideoComplete,
  });

  @override
  State<AdDrawFeedWidget> createState() => _AdDrawFeedWidgetState();
}

class _AdDrawFeedWidgetState extends State<AdDrawFeedWidget> {
  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) {
      return const SizedBox.shrink();
    }

    // 使用专门的draw_feed视图类型
    const String viewType = 'gromore_ads_kit_draw_feed';

    // 创建参数Map
    final Map<String, dynamic> creationParams = <String, dynamic>{
      'posId': widget.posId,
      'adId': widget.adId,
      'width': widget.width.toInt(),
      'height': widget.height.toInt(),
    };

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
          : isGromoreOhosPlatform
          ? buildGromoreOhosPlatformView(
              viewType: viewType,
              creationParams: creationParams,
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

  void _onPlatformViewCreated(int id) {
    // 创建与原生端通信的MethodChannel
    final MethodChannel channel = MethodChannel(
      'gromore_ads_kit_draw_feed_$id',
    );

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
        case 'onAdRenderSuccess':
          widget.onAdRenderSuccess?.call();
          break;
        case 'onAdRenderFail':
          final String error = call.arguments as String;
          widget.onAdRenderFail?.call(error);
          break;
        // Draw广告特有的视频回调
        case 'onVideoPlay':
          widget.onVideoPlay?.call();
          break;
        case 'onVideoPause':
          widget.onVideoPause?.call();
          break;
        case 'onVideoComplete':
          widget.onVideoComplete?.call();
          break;
      }
    });
  }
}
