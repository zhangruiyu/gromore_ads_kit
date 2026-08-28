import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 信息流广告Widget
class AdFeedWidget extends StatefulWidget {
  /// 广告位ID
  final String posId;

  /// 广告数据ID（从loadFeedAd返回的ID）
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

  const AdFeedWidget({
    super.key,
    required this.posId,
    required this.adId,
    this.width = 375,
    this.height = 125,
    this.isVisible = true,
    this.onAdLoaded,
    this.onAdError,
    this.onAdClicked,
    this.onAdClosed,
    this.onAdRenderSuccess,
    this.onAdRenderFail,
  });

  @override
  State<AdFeedWidget> createState() => _AdFeedWidgetState();
}

class _AdFeedWidgetState extends State<AdFeedWidget> {
  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) {
      return const SizedBox.shrink();
    }

    // 根据平台选择对应的原生视图
    const String viewType = 'gromore_ads_kit_feed';

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
    final MethodChannel channel = MethodChannel('gromore_ads_kit_feed_$id');

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
      }
    });
  }
}
