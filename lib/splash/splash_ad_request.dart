import 'dart:convert';

/// logo资源类型
enum SplashLogoSource { asset, file, resource, bundle }

/// 开屏广告底部LOGO配置
class SplashAdLogo {
  const SplashAdLogo._(
    this.source,
    this.value, {
    this.height,
    this.heightRatio,
    this.backgroundColor,
  }) : assert(height == null || height > 0, 'height 必须大于 0'),
       assert(
         heightRatio == null || (heightRatio > 0 && heightRatio <= 0.25),
         'heightRatio 必须在 (0, 0.25] 之间',
       );

  /// 使用 Flutter assets 资源（推荐）
  const SplashAdLogo.asset(
    String assetPath, {
    double? height,
    double? heightRatio,
    String? backgroundColor,
  }) : this._(
         SplashLogoSource.asset,
         assetPath,
         height: height,
         heightRatio: heightRatio,
         backgroundColor: backgroundColor,
       );

  /// 使用本地文件路径
  const SplashAdLogo.file(
    String filePath, {
    double? height,
    double? heightRatio,
    String? backgroundColor,
  }) : this._(
         SplashLogoSource.file,
         filePath,
         height: height,
         heightRatio: heightRatio,
         backgroundColor: backgroundColor,
       );

  /// 使用 Android 资源名称（mipmap/drawable）或 iOS 的 UIImage(named:)
  const SplashAdLogo.resource(
    String name, {
    double? height,
    double? heightRatio,
    String? backgroundColor,
  }) : this._(
         SplashLogoSource.resource,
         name,
         height: height,
         heightRatio: heightRatio,
         backgroundColor: backgroundColor,
       );

  /// 使用 iOS Bundle 资源路径
  const SplashAdLogo.bundle(
    String bundlePath, {
    double? height,
    double? heightRatio,
    String? backgroundColor,
  }) : this._(
         SplashLogoSource.bundle,
         bundlePath,
         height: height,
         heightRatio: heightRatio,
         backgroundColor: backgroundColor,
       );

  /// 资源类型
  final SplashLogoSource source;

  /// 资源具体值
  final String value;

  /// 固定高度（dp/pt）
  final double? height;

  /// 按屏幕高度百分比定义的高度，范围 (0, 0.25]
  final double? heightRatio;

  /// 底部区域背景颜色，#RRGGBB 或 #AARRGGBB
  final String? backgroundColor;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'source': source.name,
    'value': value,
    if (height != null) 'height': height,
    if (heightRatio != null) 'heightRatio': heightRatio,
    if (backgroundColor != null) 'backgroundColor': backgroundColor,
  };

  @override
  String toString() => jsonEncode(toJson());
}

/// 穿山甲兜底配置
class SplashAdFallback {
  const SplashAdFallback({
    required this.adnName,
    required this.slotId,
    required this.appId,
    this.appKey,
  });

  /// ADN 名称（pangle / baidu / gdt / ks / mtg / sigmob 等）
  final String adnName;

  /// ADN 代码位 ID
  final String slotId;

  /// ADN 应用 ID
  final String appId;

  /// ADN AppKey，可选
  final String? appKey;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'adnName': adnName,
    'slotId': slotId,
    'appId': appId,
    if (appKey != null) 'appKey': appKey,
  };
}

/// Android 平台开屏广告可选配置
///
/// **平台差异说明**：
/// - `muted`、`volume`：音量控制仅Android支持，iOS会自动忽略这些参数
/// - `useSurfaceView`：Android视频渲染选项，iOS使用不同的渲染机制
/// - `shakeButton`：摇一摇按钮功能，iOS不支持
/// - `enablePreload`：聚合预加载开关，iOS使用不同的预加载策略
///
/// **参数传递策略**：
/// 未传递的参数（null）不会调用原生SDK的setter，保留SDK默认行为
class SplashAdAndroidOptions {
  const SplashAdAndroidOptions({
    this.muted,
    this.volume,
    this.useSurfaceView,
    this.bidNotify,
    this.shakeButton,
    this.enablePreload,
    this.scenarioId,
    this.extras,
    this.customData,
    this.fallback,
  }) : assert(
         volume == null || (volume >= 0 && volume <= 1),
         'volume 需在 [0,1] 范围内',
       );

  /// 是否静音 (@android 仅Android支持)
  final bool? muted;

  /// 播放音量 (0 ~ 1) (@android 仅Android支持)
  final double? volume;

  /// 是否使用 SurfaceView (@android 仅Android支持)
  final bool? useSurfaceView;

  /// 竞价回调开关
  final bool? bidNotify;

  /// 摇一摇按钮开关 (@android 仅Android支持)
  final bool? shakeButton;

  /// 聚合预加载开关 (@android Android专属配置)
  final bool? enablePreload;

  /// 场景 ID
  final String? scenarioId;

  /// 额外参数 (key -> value) 将调用 `setExtraObject`
  final Map<String, dynamic>? extras;

  /// 自定义扩展数据，将写入 `CUSTOM_DATA_KEY_GROMORE_EXTRA`
  final Map<String, dynamic>? customData;

  /// 自定义兜底配置
  final SplashAdFallback? fallback;

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (muted != null) 'muted': muted,
    if (volume != null) 'volume': volume,
    if (useSurfaceView != null) 'useSurfaceView': useSurfaceView,
    if (bidNotify != null) 'bidNotify': bidNotify,
    if (shakeButton != null) 'shakeButton': shakeButton,
    if (enablePreload != null) 'enablePreload': enablePreload,
    if (scenarioId != null) 'scenarioId': scenarioId,
    if (extras != null) 'extras': extras,
    if (customData != null) 'customData': customData,
    if (fallback != null) 'fallback': fallback!.toJson(),
  };
}

/// iOS 平台开屏广告可选配置
///
/// **平台差异说明**：
/// - `supportCardView`：卡片样式，仅iOS支持，Android不支持此UI形式
/// - `supportZoomOutView`：Ads-CN 7.7 已移除对应 iOS 接口，当前会被忽略
/// - `hideSkipButton`：控制跳过按钮显示，iOS特有配置
/// - `buttonType`：点击区域类型，仅iOS的BUMSplashButtonType支持
///
/// **参数传递策略**：
/// 当字段为 `null` 时，插件不会调用原生SDK的setter，保留SDK默认行为
class SplashAdIOSOptions {
  const SplashAdIOSOptions({
    this.supportCardView,
    this.supportZoomOutView,
    this.hideSkipButton,
    this.mediaExt,
    this.extraParams,
    this.buttonType,
    this.fallback,
  });

  /// 是否支持卡片样式 (@ios 仅iOS支持)
  final bool? supportCardView;

  /// 兼容旧代码保留。Ads-CN 7.7 已移除对应 iOS 接口，当前会被忽略。
  final bool? supportZoomOutView;

  /// 是否隐藏跳过按钮 (@ios 仅iOS支持)
  final bool? hideSkipButton;

  /// 透传给 SDK 的 mediaExt (@ios iOS专属)
  final Map<String, dynamic>? mediaExt;

  /// 通过 mediation.addParam 传递的参数 (@ios iOS专属)
  final Map<String, dynamic>? extraParams;

  /// 点击区域类型（BUMSplashButtonType） (@ios 仅iOS支持)
  /// 1=全屏可点，2=下载条可点
  final int? buttonType;

  /// 自定义兜底配置
  final SplashAdFallback? fallback;

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (supportCardView != null) 'supportCardView': supportCardView,
    if (supportZoomOutView != null) 'supportZoomOutView': supportZoomOutView,
    if (hideSkipButton != null) 'hideSkipButton': hideSkipButton,
    if (mediaExt != null) 'mediaExt': mediaExt,
    if (extraParams != null) 'extraParams': extraParams,
    if (buttonType != null) 'buttonType': buttonType,
    if (fallback != null) 'fallback': fallback!.toJson(),
  };
}

/// HarmonyOS 平台开屏广告可选配置。
class SplashAdHarmonyOptions {
  const SplashAdHarmonyOptions({this.fallback});

  /// 穿山甲直客兜底配置，对应 HarmonyOS `CSJSplashUserData`。
  final SplashAdFallback? fallback;

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (fallback != null) 'fallback': fallback!.toJson(),
  };
}

/// 开屏广告请求参数
class SplashAdRequest {
  const SplashAdRequest({
    required this.posId,
    this.timeout = const Duration(milliseconds: 3500),
    this.preload = false,
    this.logo,
    this.android,
    this.ios,
    this.harmony,
  });

  /// 广告位 ID
  final String posId;

  /// 加载超时时间，默认 3.5 秒
  final Duration timeout;

  /// 是否仅预加载
  final bool preload;

  /// 底部 LOGO 配置
  final SplashAdLogo? logo;

  /// Android 端配置
  final SplashAdAndroidOptions? android;

  /// iOS 端配置
  final SplashAdIOSOptions? ios;

  /// HarmonyOS 端配置
  final SplashAdHarmonyOptions? harmony;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'posId': posId,
    if (timeout != const Duration(milliseconds: 3500))
      'timeout': timeout.inMilliseconds / 1000.0,
    if (preload) 'preload': true,
    if (logo != null) 'logo': logo!.toJson(),
    if (android != null) 'android': android!.toJson(),
    if (ios != null) 'ios': ios!.toJson(),
    if (harmony != null) 'harmony': harmony!.toJson(),
  };

  SplashAdRequest copyWith({
    String? posId,
    Duration? timeout,
    bool? preload,
    SplashAdLogo? logo,
    SplashAdAndroidOptions? android,
    SplashAdIOSOptions? ios,
    SplashAdHarmonyOptions? harmony,
  }) {
    return SplashAdRequest(
      posId: posId ?? this.posId,
      timeout: timeout ?? this.timeout,
      preload: preload ?? this.preload,
      logo: logo ?? this.logo,
      android: android ?? this.android,
      ios: ios ?? this.ios,
      harmony: harmony ?? this.harmony,
    );
  }
}
