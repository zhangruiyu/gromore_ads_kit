# 从 0.3.0 升级到 1.0.0

`1.0.0` 新增 HarmonyOS/OpenHarmony 原生实现。Android 和 iOS 的现有 Dart API
保持兼容；原有 Android/iOS 工程仍导入 `gromore_ads_kit.dart`。

## HarmonyOS 工程

1. 使用 Flutter OHOS `3.41.10-ohos-0.0.2-beta` 或兼容版本。
2. 按 [`HARMONYOS.md`](HARMONYOS.md) 配置 `.ohpmrc`、
   `useNormalizedOHMUrl`、权限和可选 ADN。
3. 将导入改为 `gromore_ads_kit_ohos.dart`。
4. 在 `runApp` 前调用 `registerGromoreAdsKitOhosPlatformViews()`。
5. 用户完成隐私选择后，再调用 `GromoreAdsKit.initAd`。

```dart
import 'package:gromore_ads_kit/gromore_ads_kit_ohos.dart';

void main() {
  registerGromoreAdsKitOhosPlatformViews();
  runApp(const MyApp());
}
```

## 新参数

`initAd` 新增可选 `appName` 和 `allowShowNotify`；HarmonyOS 初始化会传给官方
`SDKConfigBuilder`，Android/iOS 保持原行为。

`AdPrivacyConfig` 新增：

- `canUseAppTrackingConsent`；
- `devOaid`。

开屏请求新增 `SplashAdHarmonyOptions`，当前用于传入 `CSJSplashUserData` 兜底参数。

## 已知平台差异

- HarmonyOS Feed/Draw 同时支持模板和原生自渲染，聚合混出无需业务区分；
- HarmonyOS 聚合 Banner 使用模板；直连穿山甲可传
  `harmonyNativeRender: true` 启用原生自渲染；
- HarmonyOS `getAdLoadInfo` 返回空列表；
- HarmonyOS `launchTestTools` 返回 `false`；
- HarmonyOS Banner Widget 会先自动加载广告，再创建原生视图；
- HarmonyOS 独立 `showBannerAd` API 返回 `false`，请使用 `AdBannerWidget`；
- 无调试签名时，HAP 的 ArkTS 编译可以成功，但最终签名步骤会失败。

这些差异不会改变 Android/iOS 0.3.0 已有行为。
