import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'view/ohos_platform_view.dart';

export 'gromore_ads_kit.dart';

/// 注册 HarmonyOS/OpenHarmony 原生广告视图。
///
/// 这个入口依赖 Flutter OHOS 分支提供的 [OhosView]。请在 `runApp` 前调用一次。
void registerGromoreAdsKitOhosPlatformViews() {
  registerGromoreOhosPlatformViewBuilder(({
    required String viewType,
    required Map<String, dynamic> creationParams,
    required PlatformViewCreatedCallback onPlatformViewCreated,
    required Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers,
  }) {
    return OhosView(
      viewType: viewType,
      layoutDirection: TextDirection.ltr,
      creationParams: creationParams,
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: onPlatformViewCreated,
      gestureRecognizers: gestureRecognizers,
    );
  });
}
