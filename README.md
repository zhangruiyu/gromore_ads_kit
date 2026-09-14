# gromore_ads_kit

GroMore 广告聚合 Flutter 插件，支持 Android、iOS 和 HarmonyOS/OpenHarmony。

核心包支持开屏、插屏、Banner、激励视频、信息流和 Draw 信息流、广告预加载、
完整隐私控制、waterfall 诊断以及事件/错误/奖励/eCPM 回调。优量汇、百度、
Sigmob、快手和 GroMore 官方测试工具均拆成独立扩展包，业务 App 只安装真正使用的
平台，避免无关 SDK 增大包体、权限和隐私合规范围。

本项目基于
[`Xlxinxi/flutter_gromore_ads`](https://github.com/Xlxinxi/flutter_gromore_ads)
的 MIT 许可源码适配而来，来源版本见
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)。

## 当前版本

- 核心插件 `2.0.2`
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

## 快速接入

### 1. 在 GroMore 后台准备配置

先为 Android、iOS、HarmonyOS 分别创建应用并取得各自的 GroMore App ID。然后创建
聚合广告位，在广告位的瀑布流中添加准备使用的 ADN 代码位。

注意区分两个 ID：

- `GromoreAdsKit.initAd()` 传应用的 **App ID**。
- 加载开屏、激励视频等广告时传聚合广告位的 **代码位 ID**。

代码位 ID 是否以 `1` 开头不能用来判断它是不是 GroMore 广告位，应以后台显示的
广告位类型和“是否用于 GroMore”配置为准。

### 2. 选择依赖方式

| 包名 | Android | iOS | HarmonyOS | 用途 |
| --- | --- | --- | --- | --- |
| `gromore_ads_kit` | 支持 | 支持 | 支持 | 核心包，只包含 GroMore/穿山甲 |
| `gromore_ads_kit_gdt` | 支持 | 支持 | 支持 | 加入优量汇 SDK 和 Adapter |
| `gromore_ads_kit_baidu` | 支持 | 支持 | 暂不支持 | 加入百度 SDK 和 Adapter |
| `gromore_ads_kit_sigmob` | 支持 | 支持 | 暂不支持 | 加入 Sigmob SDK 和 Adapter |
| `gromore_ads_kit_ks` | 支持 | 支持 | 支持 | 加入快手 SDK 和 Adapter |
| `gromore_ads_kit_all` | 支持 | 支持 | 支持 | 一次安装上述核心包和四个 ADN 扩展 |
| `gromore_ads_kit_debug_tools` | Debug | Debug | 不支持 | GroMore 官方预览测试工具 |

只使用 GroMore/穿山甲时添加核心包：

```yaml
dependencies:
  gromore_ads_kit: ^2.0.2
```

按实际需要添加 ADN 扩展。下面的示例会接入优量汇和 Sigmob，不会把百度和快手
打进 App：

```yaml
dependencies:
  gromore_ads_kit: ^2.0.2
  gromore_ads_kit_gdt: ^1.0.0     # 优量汇
  gromore_ads_kit_sigmob: ^1.0.0  # Sigmob
```

其他 ADN 按需添加：

```yaml
dependencies:
  gromore_ads_kit: ^2.0.2
  gromore_ads_kit_baidu: ^1.0.0   # 百度
  gromore_ads_kit_ks: ^1.0.0      # 快手
```

确实需要优量汇、百度、Sigmob 和快手四家平台时，可以只使用全家桶：

```yaml
dependencies:
  gromore_ads_kit_all: ^2.0.0
```

全家桶已经依赖核心包，不要再重复添加 `gromore_ads_kit`。它也不会携带官方测试
工具。

扩展包只负责把对应平台的原生 SDK、GroMore Adapter、清单和资源带入宿主，业务层
不需要单独初始化每一家 ADN，也不需要 import 每个扩展包。按需依赖时统一使用：

```dart
import 'package:gromore_ads_kit/gromore_ads_kit.dart';
```

只依赖全家桶时使用它导出的统一入口：

```dart
import 'package:gromore_ads_kit_all/gromore_ads_kit_all.dart';
```

修改依赖后执行：

```shell
flutter pub get
```

iOS 若没有在后续 Flutter 构建中自动安装 Pod，可在 `ios` 目录手动执行
`pod install`。各扩展包已发布到 pub.dev，可使用上述版本号；在本仓库联调时可临时
改成对应 `packages/` 下的 path 依赖。

### 3. 保持后台与客户端一致

GroMore 后台开启某家 ADN，不代表它的原生 SDK 已经自动进入 App。客户端必须安装
对应扩展包：

- 后台只启用穿山甲：只安装核心包。
- 后台启用穿山甲和优量汇：安装核心包与 `gromore_ads_kit_gdt`。
- 后台启用多家 ADN：逐个安装对应扩展，或者使用全家桶。
- 后台已经停用某家 ADN：可以移除对应扩展包，再重新构建以缩小包体和合规范围。

如果后台启用了某家 ADN，但客户端没有安装对应扩展，GroMore 初始化日志会报告该
SDK 或 Adapter 未接入，而且该 ADN 无法参与本次瀑布流。反过来，安装了扩展包但
后台没有配置它，不会自动请求该平台广告。

## Android 配置

### Maven 依赖

核心插件通过字节跳动官方 Maven 仓库引入 GroMore `7.7.1.6`，并自动把仓库注册给
宿主 Android 工程。使用者不需要在
`settings.gradle` 或项目级 `build.gradle` 重复添加字节跳动 Maven 仓库，也不需要
重复引入 `okhttp:3.12.1`。

每个 ADN 扩展包自行声明匹配的 SDK 和 Adapter。升级时应同时更新同一扩展包里的
二者；百度、Sigmob、快手当前指定版本没有经过验证的公开原生 SDK Maven 坐标，
所以只在它们各自的扩展包中保留对应 AAR/POM。

### 第三方 ADN

GroMore 后台勾选某个广告网络，只会把该网络写进聚合配置，不会自动把它的原生
SDK 和 Adapter 装进 APK。二者版本不匹配时，初始化日志会提示“未按要求接入”。

安装 `gromore_ads_kit_gdt` 后自动加入：

```groovy
implementation 'com.qq.e.union:union:4.680.1550'
implementation 'com.pangle.cn:mediation-gdt-adapter:4.680.1550.1'
```

融合 SDK `mediation-sdk` 已经包含穿山甲能力，穿山甲没有单独的 Adapter 依赖。
初始化日志里笼统列出 `pangle`，不等于还需要再引入一份穿山甲 SDK。

核心包声明穿山甲 `TTFileProvider`；`gromore_ads_kit_gdt` 声明优量汇
`GDTFileProvider` 及其路径资源，宿主无需重复配置。

百度 Adapter 不会自动传递百度原生 SDK。安装 `gromore_ads_kit_baidu` 后，会配套
加入 GroMore `7.7.1.6` 官方包指定的百度 SDK `9.4503` 和 Adapter `9.4503.1`。

Sigmob 不能只加 Adapter。`gromore_ads_kit_sigmob` 配套加入 WindAd SDK、common
SDK 和 Sigmob Adapter；若需要更换版本，应以 GroMore 后台为当前应用生成的
Android SDK 包为准，同时替换这三项依赖。详细步骤见
[`doc/ANDROID_ADN.md`](doc/ANDROID_ADN.md)。

快手同样需要原生 SDK 和 Adapter 成对接入。安装 `gromore_ads_kit_ks` 后会加入
GroMore `7.7.1.6` 官方生成包指定的快手 SDK `5.3.20.1` 和 Adapter
`5.3.20.1.1`。

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
        android:allowBackup="false"
        tools:replace="android:allowBackup,android:label" />
</manifest>
```

## iOS 配置

最低支持 iOS 13。核心插件通过 CocoaPods 引入
`Ads-CN-Beta/CSJMediation 7.8.0.2`，不再默认携带第三方 ADN 和测试工具。

### 第三方 ADN

安装对应扩展包后，会加入 GroMore iOS 文档指定的原生 SDK 与 Adapter：

| 扩展包 | 原生 SDK | GroMore Adapter |
| --- | --- | --- |
| `gromore_ads_kit_gdt` | `GDTMobSDK 4.15.90` | `CSJMGdtAdapter 4.15.90.1` |
| `gromore_ads_kit_baidu` | `BaiduMobAdSDK 10.050` | `CSJMBaiduAdapter 10.050.3` |
| `gromore_ads_kit_sigmob` | `SigmobAd-iOS 5.1.2` | `CSJMSigmobAdapter 5.1.2.1` |
| `gromore_ads_kit_ks` | `KSAdSDK 5.5.10.1` | `CSJMKsAdapter 5.5.10.1.1` |

原生 SDK 由 CocoaPods 官方索引下载；GroMore Adapter 来自穿山甲官方静态包，
随各自扩展包保存在 `ios/Vendor`，并保留原始 LICENSE。这里只完成客户端能力接入，
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

HarmonyOS 构建仍须使用 Flutter OHOS 分支。平台判断使用
`flutter_platform_utils` 的 `PlatformUtils.isOhos`，核心包没有直接引用
`TargetPlatform.ohos`；Android/iOS 可继续使用标准 Flutter。插件把 `OhosView`
放在独立入口中，避免鸿蒙专属类型影响标准 Flutter 编译。

宿主工程根目录 `.ohpmrc` 加入官方仓库：

```properties
registry=https://ohpm.openharmony.cn/ohpm/,https://artifact.bytedance.com/repository/byted-ohpm/
```

核心包只引入 `@csj/openadsdk 7.5.3`。安装 `gromore_ads_kit_gdt` 后加入优量汇
`@gdt/gdt-union-sdk 1.2.0` 与 `@csj/adapter_gdt 1.2.0-2`；安装
`gromore_ads_kit_ks` 后加入快手 `ksadsdk 3.0.6` 与
`@csj/adapter_ks 3.0.6-6`。百度和 Sigmob 当前没有本插件可验证的鸿蒙依赖，
对应扩展包不声明 OHOS 平台。宿主
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

HarmonyOS 使用 Banner、信息流或 Draw 等 PlatformView 广告时，需要使用鸿蒙入口，
并在 `runApp` 前注册平台视图：

```dart
import 'package:gromore_ads_kit/gromore_ads_kit_ohos.dart';

void main() {
  registerGromoreAdsKitOhosPlatformViews();
  runApp(const MyApp());
}
```

如果同一个仓库还要使用标准 Flutter 构建 Android/iOS，请只在鸿蒙专用入口（例如
`main_ohos.dart`）中导入 `gromore_ads_kit_ohos.dart`。标准 Flutter 入口继续导入
`gromore_ads_kit.dart`，不会解析鸿蒙分支独有的 `OhosView`。

核心默认只带穿山甲。优量汇和快手的 SDK、Adapter 及 `runtimeOnly.packages`
均放在各自扩展包内，宿主安装扩展后不需要再复制 HAR 或重复声明依赖。
完整版本说明见 [`doc/HARMONYOS.md`](doc/HARMONYOS.md)。

## 初始化

必须先展示并取得用户对宿主隐私政策的选择，再初始化 SDK。`useMediation` 只能在
第一次初始化时设置；只有初始化返回 `true` 后才能请求广告。

三端通常使用不同的 App ID。下面使用 `flutter_platform_utils` 判断鸿蒙，不直接
引用标准 Flutter 中不存在的 `TargetPlatform.ohos`。如果宿主代码也要直接导入
`flutter_platform_utils`，请在宿主 `pubspec.yaml` 显式添加
`flutter_platform_utils: ^1.0.0`，避免依赖传递关系触发分析警告。

```dart
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_platform_utils/flutter_platform_utils.dart';
import 'package:gromore_ads_kit/gromore_ads_kit.dart';

AdEventSubscription? adSubscription;

String get gromoreAppId {
  if (PlatformUtils.isOhos) {
    return '你的鸿蒙 App ID';
  }
  if (Platform.isIOS) {
    return '你的 iOS App ID';
  }
  return '你的 Android App ID';
}

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
    gromoreAppId,
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

### Android：Sigmob 提示缺少设备 ID / OAID

`canUseOaid: true` 只是允许 SDK 自行读取，不代表设备一定能提供 OAID。
如果日志出现 `MdidSdkHelper` / `OAID 读取类创建失败`，需要检查 OAID 获取依赖，
或者复用宿主已有的 OAID 获取库，将真实 OAID 在 **GroMore 初始化前**传入：

```dart
// 必须先取得相应用户授权，并等待宿主已有 OAID 库返回真实值。
// oaidFromHost 表示上述获取结果；不可用时为 null，不是写死的设备 ID。
final String? oaid = oaidFromHost;
final privacy = AdPrivacyConfig(
  oaid: oaid,
  canUseOaid: oaid == null,
  canUsePhoneState: false,
  canUseAndroidId: false,
);
// 在现有 GromoreAdsKit.initAd(...) 中使用 privacy，其他隐私选项继续按宿主授权设置。
```

- Sigmob 官方规定：`canUseOaid: false` 时才使用宿主传入的 OAID；这里是禁止
  **SDK 自行采集**，不是禁止使用已获授权的传入值。
- 示例中获取失败时保留 SDK 自行读取；如果用户不允许 OAID，应同时设置
  `canUseOaid: false` 和 `oaid: null`，不要因加载失败而绕过用户选择。
- 某些 OAID 库首次调用只启动异步获取，需要等待回调或短暂、有限次数重读；
  不要无限等待，也不要在初始化后反复初始化 SDK 来补值。
- 不要传空字符串、全零值，也不要用 IMEI、Android ID 或随机 UUID 代替 OAID。
  日志只记录获取成功与否，不输出完整 OAID。
- 本插件负责透传，不捆绑额外 OAID 库或宿主专属证书。接入方自行选择获取方案，
  不需要为了传入 OAID 额外开放定位、电话、应用列表等权限。

此配置也用于同一 SDK 初始化后打开的官方测试工具。补齐 OAID 不保证一定填充，
还需要重新检查 Sigmob 请求结果。[Sigmob 官方隐私设置说明](https://doc.sigmob.com/sigmob/11140/)。

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

HarmonyOS 实现使用官方 `loadFeedAd` 聚合混出链路。模板素材挂载 SDK
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

HarmonyOS 实现使用官方 `loadDrawAd` 聚合混出链路，同时支持模板和原生
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

Android 激励视频加载返回 `20005` 时，表示聚合位下所有代码位都请求失败，
不是某一家 ADN 的具体错误。插件在 Debug 包中会自动为激励视频请求打开
`show_adn_load_error_detail`，`onError` 的 `message` 会尽量包含每家 ADN 的
代码位、错误码和原因；Release 包默认关闭。如需显式控制，可在调用
`loadRewardVideoAd` 时传 `showAdnLoadErrorDetail: true/false`。该参数只影响
**App 通过插件发起的 Android 请求**，不会改变 GroMore 官方测试工具的请求或
后台填充结果。诊断日志可能含代码位 ID，正式包如需打开请自行控制日志上报范围。

Feed/Draw 需要在广告 ID 绑定 Widget 之前传入 `adId`：

```dart
final info = await GromoreAdsKit.getAdLoadInfo(
  AdType.feed,
  adId: adIds.first,
);
```

HarmonyOS SDK 当前公开接口没有提供与 Android/iOS 同等的逐 ADN 加载结果查询，
因此当前版本在鸿蒙端返回空列表；请使用 SDK Debug 日志和后台测试能力排查填充。

## 官方预览测试工具

测试工具已拆到 `gromore_ads_kit_debug_tools`。它要求 Android/iOS GroMore
`7.2.0.0+`，并且必须在 SDK 初始化成功后调用。
还需要在 GroMore 后台开启全局广告预览模式和测试权限。
HarmonyOS 的 `launchTestTools()` 返回 `false`，不伪造未公开的工具入口。

### Android

扩展包使用 `debugImplementation` 引入
`com.pangle.cn:mediation-test-tools:7.7.1.6`，因此 Android Release 变体不会打入
测试工具 AAR。

### iOS

iOS 扩展包携带匹配的 `BUAdTestMeasurement.xcframework` 和资源 Bundle，Swift
入口由 `#if DEBUG` 限制。CocoaPods 没有与 Android `debugImplementation` 等价的
Flutter 插件依赖方式，因此发布 iOS 前必须从 `pubspec.yaml` 移除整个
`gromore_ads_kit_debug_tools` 包并重新执行 `flutter pub get` 和 `pod install`。

业务侧仍要限制调用：

```dart
if (kDebugMode) {
  await GromoreAdsKit.launchTestTools();
}
```

推荐只在 `kDebugMode` 下调用。未安装扩展包时，`launchTestTools()` 会返回明确的
`MissingPluginException`，不会让核心广告功能依赖测试工具。

## 版本升级

- 1.x → 2.0.0：[`doc/MIGRATION_2_0_0.md`](doc/MIGRATION_2_0_0.md)
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
