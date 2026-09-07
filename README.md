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

- 插件 `1.0.1`
- Flutter `>=3.41.6`；Android/iOS 使用 FVM Flutter `3.41.6` 验证，
  HarmonyOS 使用 FVM Flutter `3.41.10-ohos-0.0.2-beta` 验证
- Dart `^3.11.4`
- Android：`minSdk 24`、`compileSdk 36`、Java 17
- Android GroMore：`com.pangle.cn:mediation-sdk:7.7.1.6`
- iOS：`13.0+`、Xcode `15.2+`
- iOS GroMore：`Ads-CN-Beta 7.8.0.2`
- HarmonyOS：Flutter OHOS `3.41.10-ohos-0.0.2-beta`、DevEco Studio
  `5.0.3.403+`、OpenHarmony API 12+、`@csj/openadsdk 7.5.3`

版本依据为 2026-09-02 查询到的字节跳动官方 Maven/OHPM 仓库、CocoaPods Trunk
和 GroMore 官方接入文档。Android、iOS 和 HarmonyOS 的官方 SDK 版本并不一致，
不能把某个平台的 Adapter 版本照搬到另一个平台。

## 添加依赖

本地开发时，在业务 App 的 `pubspec.yaml` 中添加：

```yaml
dependencies:
  gromore_ads_kit:
    path: ../gromore_ads_kit
```

然后执行 `flutter pub get`。

## Android 配置

### Maven 依赖

插件已经把 GroMore `7.7.1.6`、官方测试工具和当前配套 ADN Adapter 放进自身的
本地 Maven 目录，并自动注册给宿主 Android 工程。使用者不需要在
`settings.gradle` 或项目级 `build.gradle` 添加字节跳动 Maven 仓库，也不需要
重复引入 `okhttp:3.12.1`。

如果以后更换 GroMore 或 Adapter 版本，需要同时替换插件 `android/maven` 里的
AAR/POM 和 `android/build.gradle` 中的坐标，避免编译坐标与实际二进制不一致。

### 第三方 ADN

GroMore 后台勾选某个广告网络，只会把该网络写进聚合配置，不会自动把它的原生
SDK 和 Adapter 装进 APK。二者版本不匹配时，初始化日志会提示“未按要求接入”。

本插件 `1.0.1` 已内置以下优量汇依赖，宿主不用重复添加：

```groovy
implementation 'com.qq.e.union:union:4.680.1550'
implementation 'com.pangle.cn:mediation-gdt-adapter:4.680.1550.1'
```

融合 SDK `mediation-sdk` 已经包含穿山甲能力，穿山甲没有单独的 Adapter 依赖。
初始化日志里笼统列出 `pangle`，不等于还需要再引入一份穿山甲 SDK。

插件同时按照 GroMore 官方 Android 工程自动声明穿山甲 `TTFileProvider`、优量汇
`GDTFileProvider` 及其路径资源，宿主无需再复制这两段 Manifest 配置。

百度 Adapter 不会自动传递百度原生 SDK。插件已经内置 GroMore `7.7.1.6` 官方
Android 包指定的百度 SDK `9.4503` 和 Adapter `9.4503.1`；宿主不需要重复添加。

Sigmob 不能只加 Adapter。本插件已经配套内置 WindAd SDK、common SDK 和 Sigmob
Adapter；若需要更换版本，应以 GroMore 后台为当前应用生成的 Android SDK 包为准，
同时替换这三项依赖，不能只升级其中一项。详细步骤见
[`doc/ANDROID_ADN.md`](doc/ANDROID_ADN.md)。

快手同样需要原生 SDK 和 Adapter 成对接入。插件已内置 GroMore `7.7.1.6` 官方
生成包指定的快手 SDK `5.3.20.1` 和 Adapter `5.3.20.1.1`，宿主无需重复添加。

插件不再依赖 `mediation-auto-adapter`：它不能替宿主下载三方 ADN SDK，而且在
Flutter 插件 module 中没有应用到宿主 App，不能解决运行时 Adapter 缺失。

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
`Ads-CN-Beta/CSJMediation 7.8.0.2`。官方预览工具和所需资源由插件统一携带。

### 第三方 ADN

插件已经把 GroMore iOS 文档列出的四家通用 ADN 的原生 SDK 和 Adapter 配对，
宿主不用再手工下载：

| ADN | 原生 SDK | GroMore Adapter |
| --- | --- | --- |
| 优量汇/GDT | `GDTMobSDK 4.15.90` | `CSJMGdtAdapter 4.15.90.1` |
| 百度 | `BaiduMobAdSDK 10.050` | `CSJMBaiduAdapter 10.050.3` |
| Sigmob | `SigmobAd-iOS 5.1.2` | `CSJMSigmobAdapter 5.1.2.1` |
| 快手 | `KSAdSDK 5.5.10.1` | `CSJMKsAdapter 5.5.10.1.1` |

原生 SDK 由 CocoaPods 官方索引下载；GroMore Adapter 来自穿山甲官方静态包，
随插件保存在 `ios/Vendor`，并保留原始 MIT LICENSE。这里只完成客户端能力接入，
实际请求哪家广告仍由 GroMore 后台的广告网络、代码位和瀑布流配置决定。

这些版本来自 GroMore `7.8.0.2` 官方聚合包及其示例 Podfile，原生 SDK 与 Adapter
必须保持成对升级。

### ATT

只有业务确实要申请 IDFA 时，才在宿主 `Info.plist` 添加真实用途文案：

```xml
<key>NSUserTrackingUsageDescription</key>
<string>用于获得更相关的广告内容，并统计广告效果。</string>
```

用户同意隐私政策后，再调用 `GromoreAdsKit.requestIDFA`。用户拒绝 ATT 不应阻止
SDK 以非 IDFA 方式工作。

### SKAdNetwork

插件不能替宿主改 `Info.plist`。使用上述 ADN 时，按各平台最新文档补齐标识符。
GroMore 当前公开表中穿山甲、Sigmob 和 GDT 的标识符如下：

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
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>8922nb4gd.skadnetwork</string>
    </dict>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>f7s53z58qe.skadnetwork</string>
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

插件已引入 `@csj/openadsdk 7.5.3`、快手 `ksadsdk 3.0.6`、优量汇
`@gdt/gdt-union-sdk 1.2.0`，以及匹配的 `@csj/adapter_ks 3.0.6-6` 和
`@csj/adapter_gdt 1.2.0-2`。优量汇核心 SDK 随插件以本地 HAR 提供，其余依赖从
官方 OHPM 仓库解析。宿主
`build-profile.json5` 对应 product 需要：

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

默认带穿山甲、快手和优量汇。优量汇 Adapter、腾讯底层 SDK 及
`runtimeOnly.packages` 已全部放在插件内，宿主不需要再复制 HAR 或重复声明依赖。
完整版本说明见 [`doc/HARMONYOS.md`](doc/HARMONYOS.md)。

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

测试工具要求 Android/iOS GroMore `7.2.0.0+`，并且必须在 SDK 初始化成功后调用。
还需要在 GroMore 后台开启全局广告预览模式和测试权限。
HarmonyOS `1.0.0` 的 `launchTestTools()` 返回 `false`，不伪造未公开的工具入口。

### Android

插件已经通过 `implementation` 直接携带与融合 SDK 配套的
`com.pangle.cn:mediation-test-tools:7.7.1.6`，宿主不需要重复声明依赖。
Android 原生层不限制构建类型，是否开放入口由宿主应用决定。

这意味着 Android Release 产物也会包含测试工具。GroMore 当前官方文档仍将它标为
测试阶段工具并注明不可带到线上，请在发布前自行评估包体和平台审核风险。

### iOS

插件已直接携带与当前 GroMore 版本匹配的 `BUAdTestMeasurement.xcframework` 和
`BUAdTestMeasurement.bundle`，宿主不需要下载文件或修改 `Podfile`。Swift 入口仍由
`#if DEBUG` 限制，Release 中调用会返回明确错误。

这意味着 iOS Release 产物也会包含测试工具二进制和资源。该取舍用于保证插件使用者
拿到依赖后即可调试；宿主仍应只在开发者页面开放入口，并自行评估包体和平台审核风险。

业务侧仍要限制调用：

```dart
if (kDebugMode) {
  await GromoreAdsKit.launchTestTools();
}
```

推荐只在 `kDebugMode` 下调用，避免向普通用户暴露入口。

## 版本升级

- 0.3.0 → 1.0.0：[`doc/MIGRATION_1_0_0.md`](doc/MIGRATION_1_0_0.md)
- 0.2.0 → 0.3.0：[`doc/MIGRATION_0_3_0.md`](doc/MIGRATION_0_3_0.md)
- 0.1.0 → 0.2.0：[`doc/MIGRATION_0_2_0.md`](doc/MIGRATION_0_2_0.md)

自定义 ADN 的职责边界见 [`doc/CUSTOM_ADN.md`](doc/CUSTOM_ADN.md)。
Android 官方 ADN 的依赖说明见 [`doc/ANDROID_ADN.md`](doc/ANDROID_ADN.md)。

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

插件代码使用 MIT，详见 [`LICENSE`](LICENSE)。随包提供的三方二进制及其包内声明见
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)。
