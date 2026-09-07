# HarmonyOS 接入

本页对应 `gromore_ads_kit 1.0.1`，核对日期为 2026-09-04。插件使用
Flutter OHOS `3.41.10-ohos-0.0.2-beta` 和 GroMore HarmonyOS
`@csj/openadsdk 7.5.3` 验证。

## 环境要求

- Flutter OHOS `3.41.10-ohos-0.0.2-beta`；
- DevEco Studio `5.0.3.403` 或更高版本；
- OpenHarmony SDK API 12 或更高版本；
- HarmonyOS NEXT.0.0.26 或更高版本。

普通 Flutter SDK 没有 `OhosView`。Android/iOS 工程继续导入
`gromore_ads_kit.dart`；HarmonyOS 工程导入 `gromore_ads_kit_ohos.dart`。

## OHPM 仓库

在宿主 HarmonyOS 工程根目录 `.ohpmrc` 中配置：

```properties
registry=https://ohpm.openharmony.cn/ohpm/,https://artifact.bytedance.com/repository/byted-ohpm/
```

插件 HAR 已声明穿山甲核心包、快手 SDK、优量汇 SDK 和对应 GroMore Adapter：

```json5
"dependencies": {
  "@csj/openadsdk": "7.5.3",
  "@csj/adapter_ks": "3.0.6-6",
  "ksadsdk": "3.0.6",
  "@csj/adapter_gdt": "1.2.0-2",
  "@gdt/gdt-union-sdk": "file:libs/GDTUnionSDK-default-release.har"
}
```

宿主 product 的 `build-profile.json5` 需要开启标准化 OHM URL：

```json5
"buildOption": {
  "strictMode": {
    "useNormalizedOHMUrl": true
  }
}
```

## 广告网络依赖

插件默认引入穿山甲、快手和优量汇。穿山甲与快手的核心 SDK、Adapter 通过官方
OHPM 仓库解析；优量汇的核心 SDK 当前不在穿山甲或 OpenHarmony 公共 OHPM 仓库，
因此插件按 GroMore 官方依赖方式内置 `GDTUnionSDK-default-release.har`，宿主不需要
另外下载或声明。当前配对版本为：

```json5
"dependencies": {
  "@csj/openadsdk": "7.5.3",
  "@csj/adapter_gdt": "1.2.0-2",
  "@gdt/gdt-union-sdk": "file:libs/GDTUnionSDK-default-release.har"
}
```

插件的 `build-profile.json5` 已同时加入：

```json5
"buildOption": {
  "arkOptions": {
    "runtimeOnly": {
      "packages": [
        "@csj/adapter_gdt",
        "@gdt/gdt-union-sdk"
      ]
    }
  }
}
```

不要在宿主中重复加入不同版本的优量汇 Adapter 或 SDK，以免动态模块命中错误版本。

## 权限与隐私

插件声明：

- `ohos.permission.INTERNET`：必需；
- `ohos.permission.GET_NETWORK_INFO`：官方列为可选，插件已声明。

以下权限由宿主按实际业务决定，插件不会代替宿主扩大权限范围：

- `ohos.permission.GET_WIFI_INFO`；
- `ohos.permission.APPROXIMATELY_LOCATION`；
- `ohos.permission.LOCATION`；
- `ohos.permission.APP_TRACKING_CONSENT`。

在隐私协议同意前不要调用 `CSJAdSdk.start` 对应的 `initAd`。授权结果通过
`AdPrivacyConfig` 传入；拒绝系统 OAID 权限时可以由宿主提供 `devOaid`，也可以留空。

```dart
await GromoreAdsKit.initAd(
  '你的鸿蒙 App ID',
  useMediation: true,
  debugMode: kDebugMode,
  appName: '你的应用名称',
  allowShowNotify: true,
  privacy: const AdPrivacyConfig(
    canUseAppTrackingConsent: false,
    canUseLocation: false,
    canUseWifiState: false,
  ),
);
```

如果宿主需要由 SDK 发起已声明的动态权限申请，可以在合适时机调用
`GromoreAdsKit.requestPermissionIfNecessary`。最终权限说明、申请时机和拒绝后的行为
仍由宿主负责。

## Flutter 入口

在 `runApp` 前注册一次鸿蒙 PlatformView：

```dart
import 'package:flutter/material.dart';
import 'package:gromore_ads_kit/gromore_ads_kit_ohos.dart';

void main() {
  registerGromoreAdsKitOhosPlatformViews();
  runApp(const MyApp());
}
```

开屏兜底可以通过 `SplashAdHarmonyOptions` 传入：

```dart
await GromoreAdsKit.showSplashAd(
  const SplashAdRequest(
    posId: '开屏代码位',
    harmony: SplashAdHarmonyOptions(
      fallback: SplashAdFallback(
        adnName: 'pangle',
        slotId: '穿山甲代码位',
        appId: '穿山甲 App ID',
      ),
    ),
  ),
);
```

## 1.0.0 能力边界

| 能力 | HarmonyOS 1.0.0 | 说明 |
| --- | --- | --- |
| 初始化/聚合/隐私 | 支持 | `init` 后执行 `start`，映射官方隐私控制器 |
| 开屏 | 支持 | 加载、专用预加载、展示、兜底、事件、eCPM |
| 插全屏 | 支持 | 官方 `CSJFullAd`，先加载再展示 |
| 激励视频 | 支持 | 奖励回调、事件、eCPM |
| Banner | 支持 | GroMore 聚合使用模板；直连穿山甲可启用内置自渲染；独立 `showBannerAd` 返回 `false` |
| 信息流 | 模板 + 自渲染 | 官方 `loadFeedAd` 聚合混出，返回 `adId` 后绑定 Widget |
| Draw | 模板 + 自渲染 | 官方 `loadDrawAd` 聚合混出，返回 `adId` 后绑定 Widget |
| 自渲染交互 | 支持 | ArkUI 内置物料布局、唯一组件 ID、普通/创意点击区、dislike 和视频监听 |
| Waterfall 明细 | 暂不可用 | 当前返回空列表 |
| 官方预览工具 | 暂不可用 | `launchTestTools()` 返回 `false` |

HarmonyOS 当前公开 `AdSlotBuilder` 没有 Android/iOS 端全部高级 setter，因此
`mutedIfCan`、`bidNotify`、`scenarioId`、`useSurfaceView` 等参数在鸿蒙端不会
伪造支持。开屏底部 Logo 和自定义关闭按钮也尚未接入。

GroMore 官方说明鸿蒙聚合维度暂不支持自渲染 Banner。聚合广告位使用默认
模板即可；仅当 `initAd(useMediation: false)` 直连穿山甲时，才在
`AdBannerWidget` 传入 `harmonyNativeRender: true`。

初始化的本地配置在 HarmonyOS 只接受 SDK 可读取的字符串路径；Dart `Map` 或直接
JSON 字符串不会传给 `setCustomLocalConfig`。

## 构建与真机验收

命令行构建前，需要先在 DevEco Studio 打开 `example/ohos`，通过
`File -> Project Structure -> Signing Configs` 配置调试签名。无签名时 Hvigor 可以
完成 ArkTS 编译，但 `flutter build hap` 最后会因无法签名而返回非零状态。

本仓库没有真实 App ID、代码位、后台瀑布流配置和测试设备权限。发布业务 App 前，
必须在真机上逐个验证填充、展示、点击、关闭、奖励回调和 eCPM，并分别验证所接的
穿山甲、快手、广点通 Adapter。

## 官方文档

- [SDK 与工程配置](https://www.csjplatform.com/supportcenter/28670)
- [初始化与隐私合规](https://www.csjplatform.com/supportcenter/28671)
- [开屏广告](https://www.csjplatform.com/supportcenter/28672)
- [激励视频](https://www.csjplatform.com/supportcenter/28673)
- [插全屏广告](https://www.csjplatform.com/supportcenter/28674)
- [信息流广告](https://www.csjplatform.com/supportcenter/28675)
- [Banner 广告](https://www.csjplatform.com/supportcenter/28676)
- [Draw 广告](https://www.csjplatform.com/supportcenter/28677)
