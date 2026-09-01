# gromore_ads_kit

GroMore 广告聚合 Flutter 插件，支持 Android、iOS 和 HarmonyOS/OpenHarmony。

支持开屏、插屏、Banner、激励视频、信息流和 Draw 信息流、
广告预加载、完整隐私控制、waterfall 诊断、事件/错误/奖励/eCPM 回调，以及
GroMore 官方预览测试工具。

本项目基于
[`Xlxinxi/flutter_gromore_ads`](https://github.com/Xlxinxi/flutter_gromore_ads)
的 MIT 许可源码适配而来，来源版本见
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)。

## 当前版本

- 插件 `1.0.0`
- Flutter `>=3.41.6`；Android/iOS 使用 FVM Flutter `3.41.6` 验证，
  HarmonyOS 使用 FVM Flutter `3.41.10-ohos-0.0.2-beta` 验证
- Dart `^3.11.4`
- Android：`minSdk 24`、`compileSdk 36`、Java 17
- Android GroMore：`com.pangle.cn:mediation-sdk:7.7.1.6`
- iOS：`13.0+`、Xcode `15.2+`
- iOS GroMore：`Ads-CN 7.7.0.8`
- HarmonyOS：Flutter OHOS `3.41.10-ohos-0.0.2-beta`、DevEco Studio
  `5.0.3.403+`、OpenHarmony API 12+、`@csj/openadsdk 7.5.3`

版本依据为 2026-09-01 查询到的字节跳动官方 Maven/OHPM 仓库、CocoaPods Trunk
和 GroMore 官方接入文档。三方 ADN 的 SDK 与 Adapter 必须以你在 GroMore 后台
实际选择并生成的版本为准，插件不会擅自全量引入。

## 添加依赖

本地开发时，在业务 App 的 `pubspec.yaml` 中添加：

```yaml
dependencies:
  gromore_ads_kit:
    path: ../gromore_ads_kit
```

然后执行 `flutter pub get`。

## Android 配置

### Maven 仓库

GroMore 不在 Google Maven 或 Maven Central 中。在宿主工程
`android/settings.gradle.kts` 的 `dependencyResolutionManagement` 中加入：

```kotlin
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_PROJECT)
    repositories {
        google()
        mavenCentral()
        maven(url = "https://artifact.bytedance.com/repository/pangle")
    }
}
```

旧式 Groovy 工程可以在项目级 `build.gradle` 中加入：

```groovy
allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url "https://artifact.bytedance.com/repository/pangle" }
    }
}
```

插件已经引入官方要求的 `okhttp:3.12.1`，宿主不需要重复添加。

### Android 要求

- `minSdk` 必须至少为 `24`。
- 官方 SDK 默认只带 `arm64-v8a`。宿主若配置了 ABI 过滤，至少保留该架构。
- 插件只声明联网、网络状态和 Wi-Fi 状态权限。定位、设备信息、存储、安装包、
  `QUERY_ALL_PACKAGES` 等敏感权限应由宿主按真实业务、隐私政策和所选 ADN 决定。
- `supportMultiProcess`：单进程传 `false`；只有确实使用多进程时才传 `true`，并在
  所有使用广告的进程完成 `TTAdSdk.init` 和 `TTAdSdk.start`。
- 7.3 及以上不再需要旧版 `TTMultiProvider` 手工配置。

若 GroMore 合并清单后覆盖 App 名称，可在宿主 `AndroidManifest.xml` 中保留自己的名称：

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">
    <application
        android:label="你的应用名称"
        tools:replace="android:label" />
</manifest>
```

## iOS 配置

`0.2.0` 起最低支持 iOS 13。插件通过 CocoaPods 引入
`Ads-CN/CSJMediation 7.7.0.8`。测试工具不进入插件的常规 Pod 依赖。

### ATT

只有业务确实要申请 IDFA 时，才在宿主 `Info.plist` 添加真实用途文案：

```xml
<key>NSUserTrackingUsageDescription</key>
<string>用于获得更相关的广告内容，并统计广告效果。</string>
```

用户同意隐私政策后，再调用 `GromoreAdsKit.requestIDFA`。用户拒绝 ATT 不应阻止
SDK 以非 IDFA 方式工作。

### SKAdNetwork

穿山甲当前公开的两个标识符如下；接入其他 ADN 时还要按对应 ADN 最新文档补齐：

```xml
<key>SKAdNetworkItems</key>
<array>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>238da6jt44.skadnetwork</string>
    </dict>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>x2jnk7ly8j.skadnetwork</string>
    </dict>
</array>
```

### ATS 与隐私清单

GroMore 官方说明广告主素材可能仍包含 HTTP 地址。只有你的实际广告素材需要时，
才在宿主评估风险后设置 `NSAllowsArbitraryLoads = true`；这个开关会放宽整个 App 的
传输安全策略，插件不会自动替宿主开启。

`Ads-CN` 自带 `CSJAdSDK.bundle/PrivacyInfo.xcprivacy`。如果宿主已经有自己的
`PrivacyInfo.xcprivacy`，发布前请按官方说明合并 GroMore 和所有三方 ADN 的条目，
相同 API 原因不要重复添加。

## HarmonyOS 配置

HarmonyOS 必须使用 Flutter OHOS 分支。Android/iOS 仍可使用普通 Flutter；插件把
`OhosView` 放在独立入口中，避免鸿蒙专属类型影响普通 Flutter 编译。

宿主工程根目录 `.ohpmrc` 加入官方仓库：

```properties
registry=https://ohpm.openharmony.cn/ohpm/,https://artifact.bytedance.com/repository/byted-ohpm/
```

插件已引入 `@csj/openadsdk 7.5.3`。宿主 `build-profile.json5` 对应 product 需要：

```json5
"buildOption": {
  "strictMode": {
    "useNormalizedOHMUrl": true
  }
}
```

插件只声明必需的 `ohos.permission.INTERNET` 和可选的
`ohos.permission.GET_NETWORK_INFO`。`GET_WIFI_INFO`、
`APPROXIMATELY_LOCATION`、`LOCATION`、`APP_TRACKING_CONSENT` 等敏感权限，
必须由宿主按真实用途、隐私政策和用户授权自行声明。

HarmonyOS App 使用鸿蒙入口，并在 `runApp` 前注册平台视图：

```dart
import 'package:gromore_ads_kit/gromore_ads_kit_ohos.dart';

void main() {
  registerGromoreAdsKitOhosPlatformViews();
  runApp(const MyApp());
}
```

默认只带穿山甲/GroMore 核心包。若要聚合快手或广点通，宿主还要加入与当前版本
匹配的 Adapter 和本地 HAR，并按官方要求配置 `runtimeOnly.packages`。完整步骤和
当前官方依赖示例见 [`doc/HARMONYOS.md`](doc/HARMONYOS.md)。

## 初始化

必须先展示并取得用户对宿主隐私政策的选择，再初始化 SDK。`useMediation` 只能在
第一次初始化时设置；只有初始化返回 `true` 后才能请求广告。

```dart
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:gromore_ads_kit/gromore_ads_kit.dart';

AdEventSubscription? adSubscription;

Future<bool> initAdsAfterPrivacyConsent() async {
  // 这里应先等待你自己的隐私协议弹窗结果。
  const allowIdfa = false;
  if (Platform.isIOS && allowIdfa) {
    await GromoreAdsKit.requestIDFA;
  }

  adSubscription = GromoreAdsKit.onEvent(
    onEvent: (event) {
      debugPrint('广告事件: ${event.action}, posId=${event.posId}');
    },
    onError: (event) {
      debugPrint('广告错误: ${event.code}, ${event.message}');
    },
    onReward: (event) {
      debugPrint('奖励结果: verified=${event.verified}');
    },
  );

  return GromoreAdsKit.initAd(
    '你的7位App ID',
    useMediation: true,
    debugMode: kDebugMode,
    appName: '你的应用名称',
    allowShowNotify: true,
    supportMultiProcess: Platform.isAndroid ? false : null,
    privacy: AdPrivacyConfig(
      canUseLocation: false,
      canUseAppTrackingConsent: false,
      canUsePhoneState: false,
      canUseWifiState: true,
      canUseOaid: true,
      canUseAndroidId: false,
      canUseRecordAudio: false,
      canUseMessage: false,
      canUseAppList: false,
      canUseWifiBssid: false,
      forbidIdfa: !allowIdfa,
      allowUploadDeviceInfo: false,
    ),
  );
}

void disposeAds() {
  adSubscription?.cancel();
}
```

## 常用广告

通用预加载只支持激励视频、插屏/全屏视频和信息流。GroMore 官方不支持 Banner、
Draw 信息流通用预加载；开屏请使用 `SplashAdRequest(preload: true)` 的专用流程。
插屏和激励视频会在原生确认 `isReady` 后才展示。业务也可以主动查询：

```dart
final ready = await GromoreAdsKit.isReady(AdType.rewardVideo);
```

`AdType.banner` 查询的是 `loadBannerAd` 加载的 API 模式 Banner。Android/iOS 的
`AdBannerWidget` 是独立 PlatformView；HarmonyOS 的 Widget 会先自动调用
`loadBannerAd`，成功后再挂载原生视图。

### 开屏

```dart
await GromoreAdsKit.showSplashAd(
  const SplashAdRequest(
    posId: 'splash_pos_id',
    timeout: Duration(seconds: 4),
  ),
);
```

### 插屏

```dart
await GromoreAdsKit.loadInterstitialAd('interstitial_pos_id');
await GromoreAdsKit.showInterstitialAd('interstitial_pos_id');
```

### 激励视频

```dart
final subscription = GromoreAdsKit.onRewardVideoEvents(
  'reward_pos_id',
  onRewarded: (event) {
    if (event.verified) {
      // 在这里发放奖励。
    }
  },
);

await GromoreAdsKit.loadRewardVideoAd('reward_pos_id');
await GromoreAdsKit.showRewardVideoAd('reward_pos_id');
subscription.cancel();
```

### Banner

```dart
const AdBannerWidget(
  posId: 'banner_pos_id',
  width: 375,
  height: 60,
  enableMixedMode: true,
)
```

`enableMixedMode` 打开后，GroMore 返回混合信息流素材时，Android 和 iOS 都会使用
插件内置 Banner 布局，并完成点击、关闭区域注册。GroMore 官方明确说明
鸿蒙聚合维度暂不支持自渲染 Banner，因此 `enableMixedMode` 在鸿蒙端会被忽略。

如果鸿蒙工程使用 `useMediation: false` 直连穿山甲，可以显式开启官方原生
自渲染 Banner：

```dart
AdBannerWidget(
  posId: 'csj_banner_pos_id',
  width: 375,
  height: 100,
  harmonyNativeRender: true,
)
```

鸿蒙独立 `showBannerAd()` 返回 `false`，请使用 `AdBannerWidget` 展示。

### 信息流

Flutter 视图同时支持模板和自渲染广告。自渲染会使用插件内置默认布局，并按官网
要求先注册展示、点击和 dislike 交互再展示。

HarmonyOS `1.0.0` 使用官方 `loadFeedAd` 聚合混出链路。模板素材挂载 SDK
`NodeController`，原生素材使用插件内置 ArkUI 布局，并注册展示、普通点击、
创意点击和 dislike 计费事件。

```dart
final adIds = await GromoreAdsKit.loadFeedAd(
  'feed_pos_id',
  width: 375,
  height: 300,
  count: 3,
);

if (adIds.isNotEmpty) {
  AdFeedWidget(
    posId: 'feed_pos_id',
    adId: adIds.first,
    width: 375,
    height: 300,
  );
}
```

### Draw 信息流

Flutter 视图同时支持模板和自渲染 Draw 广告，默认布局和交互注册由插件完成。

HarmonyOS `1.0.0` 使用官方 `loadDrawAd` 聚合混出链路，同时支持模板和原生
自渲染 Draw，并接入视频播放、暂停、续播和完成监听。

```dart
final adIds = await GromoreAdsKit.loadDrawFeedAd(
  'draw_pos_id',
  width: 375,
  height: 300,
  count: 3,
);

if (adIds.isNotEmpty) {
  AdDrawFeedWidget(
    posId: 'draw_pos_id',
    adId: adIds.first,
    width: 375,
    height: 300,
  );
}
```

## Waterfall 诊断

加载回调结束后，可以查看每个 ADN 在本次 waterfall 中的结果：

```dart
final info = await GromoreAdsKit.getAdLoadInfo(AdType.rewardVideo);
for (final item in info) {
  debugPrint(
    '${item.adnName}: code=${item.errorCode}, ${item.errorMessage}',
  );
}
```

Feed/Draw 需要在广告 ID 绑定 Widget 之前传入 `adId`：

```dart
final info = await GromoreAdsKit.getAdLoadInfo(
  AdType.feed,
  adId: adIds.first,
);
```

HarmonyOS SDK 当前公开接口没有提供与 Android/iOS 同等的逐 ADN 加载结果查询，
因此 `1.0.0` 在鸿蒙端返回空列表；请使用 SDK Debug 日志和后台测试能力排查填充。

## 官方预览测试工具

测试工具要求 Android/iOS GroMore `7.2.0.0+`，只允许放在 Debug 包中，并且必须
在 SDK 初始化成功后调用。还需要在 GroMore 后台开启全局广告预览模式和测试权限。
HarmonyOS `1.0.0` 的 `launchTestTools()` 返回 `false`，不伪造未公开的工具入口。

### Android

插件不内置可能过期的 `tools-release.aar`。请从 GroMore 后台按当前 SDK/ADN 配置
生成并下载 SDK 包，把其中的 `tools-release.aar` 放到宿主
`android/app/libs/`，再添加：

```kotlin
dependencies {
    debugImplementation(files("libs/tools-release.aar"))
}
```

### iOS

从 GroMore 后台当前 SDK 生成包中取出 `BUAdTestMeasurement.xcframework` 和
`BUAdTestMeasurement.bundle`，在 Xcode 中只加入宿主 Debug 配置。插件使用
`#if DEBUG && canImport(BUAdTestMeasurement)` 检测；未引入时会返回明确错误。

不要直接把 `Ads-CN/BUAdTestMeasurement` subspec 添加为插件依赖：它和
`CSJMediation` 会合并进同一个 CocoaPods target，可能连同测试资源一起进入 Release。

业务侧仍要限制调用：

```dart
if (kDebugMode) {
  await GromoreAdsKit.launchTestTools();
}
```

上线前删除调用，并检查 Release 归档不含 Android `tools-release.aar` 或 iOS
`BUAdTestMeasurement`。

## 版本升级

- 0.3.0 → 1.0.0：[`doc/MIGRATION_1_0_0.md`](doc/MIGRATION_1_0_0.md)
- 0.2.0 → 0.3.0：[`doc/MIGRATION_0_3_0.md`](doc/MIGRATION_0_3_0.md)
- 0.1.0 → 0.2.0：[`doc/MIGRATION_0_2_0.md`](doc/MIGRATION_0_2_0.md)

自定义 ADN 的职责边界见 [`doc/CUSTOM_ADN.md`](doc/CUSTOM_ADN.md)。

官网能力逐项核对结果见
[`doc/OFFICIAL_DOCS_GAP_ANALYSIS.md`](doc/OFFICIAL_DOCS_GAP_ANALYSIS.md)。

## 官方资料

- [GroMore Android SDK 接入与初始化](https://www.csjplatform.com/supportcenter/28659)
- [GroMore iOS SDK 接入配置](https://www.csjplatform.com/supportcenter/28696)
- [GroMore iOS 初始化与隐私合规](https://www.csjplatform.com/supportcenter/28697)
- [GroMore HarmonyOS SDK 与工程配置](https://www.csjplatform.com/supportcenter/28670)
- [GroMore HarmonyOS 初始化与隐私合规](https://www.csjplatform.com/supportcenter/28671)
- [GroMore HarmonyOS 开屏](https://www.csjplatform.com/supportcenter/28672)
- [GroMore HarmonyOS 激励视频](https://www.csjplatform.com/supportcenter/28673)
- [GroMore HarmonyOS 插全屏](https://www.csjplatform.com/supportcenter/28674)
- [GroMore HarmonyOS 信息流](https://www.csjplatform.com/supportcenter/28675)
- [GroMore HarmonyOS Banner](https://www.csjplatform.com/supportcenter/28676)
- [GroMore HarmonyOS Draw](https://www.csjplatform.com/supportcenter/28677)
- [GroMore 预览测试工具](https://www.csjplatform.com/en/supportcenter/28563)
- [Android Maven 元数据](https://artifact.bytedance.com/repository/pangle/com/pangle/cn/mediation-sdk/maven-metadata.xml)
- [Ads-CN CocoaPods Trunk 信息](https://trunk.cocoapods.org/api/v1/pods/Ads-CN)

## 许可证

MIT，详见 [`LICENSE`](LICENSE)。
