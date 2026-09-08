import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_platform_utils/flutter_platform_utils.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

typedef GromoreOhosPlatformViewBuilder =
    Widget Function({
      required String viewType,
      required Map<String, dynamic> creationParams,
      required PlatformViewCreatedCallback onPlatformViewCreated,
      required Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers,
    });

GromoreOhosPlatformViewBuilder? _ohosPlatformViewBuilder;

/// 当前 Flutter 是否运行在 HarmonyOS/OpenHarmony。
bool get isGromoreOhosPlatform => PlatformUtils.isOhos;

/// 注册 Flutter OHOS 分支提供的 OhosView 构建器。
void registerGromoreOhosPlatformViewBuilder(
  GromoreOhosPlatformViewBuilder builder,
) {
  _ohosPlatformViewBuilder = builder;
}

/// 创建鸿蒙原生广告视图。
Widget buildGromoreOhosPlatformView({
  required String viewType,
  required Map<String, dynamic> creationParams,
  required PlatformViewCreatedCallback onPlatformViewCreated,
  required Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers,
}) {
  final GromoreOhosPlatformViewBuilder? builder = _ohosPlatformViewBuilder;
  if (builder == null) {
    return ErrorWidget(
      'HarmonyOS 平台请改为导入 gromore_ads_kit_ohos.dart，'
      '并在 runApp 前调用 registerGromoreAdsKitOhosPlatformViews()。',
    );
  }

  return builder(
    viewType: viewType,
    creationParams: creationParams,
    onPlatformViewCreated: onPlatformViewCreated,
    gestureRecognizers: gestureRecognizers,
  );
}
