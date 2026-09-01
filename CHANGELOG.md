## 1.0.0

* 新增 HarmonyOS/OpenHarmony 插件平台，实现 GroMore SDK 初始化、隐私控制、
  开屏、插全屏、激励视频、Banner、信息流和 Draw。
* HarmonyOS Feed/Draw 改用官方聚合混出链路，同时支持模板与原生自渲染；
  内置 ArkUI 布局完成物料展示、唯一组件 ID、计费点击区、dislike 和视频回调。
* HarmonyOS 直连穿山甲新增原生自渲染 Banner，通过
  `harmonyNativeRender: true` 显式开启；GroMore 聚合 Banner 仍按官方限制使用模板。
* HarmonyOS 核心 SDK 使用官方 OHPM `@csj/openadsdk 7.5.3`，补齐仓库、权限、
  可选快手/广点通 Adapter 和 `runtimeOnly` 接入文档。
* 新增独立 `gromore_ads_kit_ohos.dart` 入口，在保留普通 Flutter Android/iOS
  编译兼容性的同时注册 `OhosView`。
* `initAd` 新增 HarmonyOS `appName`、`allowShowNotify`，`AdPrivacyConfig` 新增
  OAID 授权与宿主 OAID 字段。
* 开屏新增 `SplashAdHarmonyOptions` 和 `CSJSplashUserData` 兜底映射。
* 明确记录 HarmonyOS 1.0.0 的 waterfall 明细、预览工具和真机验收边界。
* 修正 Flutter/Dart 最低版本约束，兼容标准 Flutter `3.41.6` 自带的
  Dart `3.11.4`；HarmonyOS 初始化按官方要求使用 `UIAbilityContext`。
* iOS GroMore 更新到 CocoaPods 官方当前最新版 `Ads-CN 7.7.0.8`。

## 0.3.0

* 新增跨平台 `AdPrivacyConfig`，完整接入 Android `TTCustomController`、
  `MediationPrivacyConfig` 与 iOS `BUAdSDKPrivacyProvider`、IDFA 和设备信息开关。
* 新增公开的 `GromoreAdsKit.isReady`，支持开屏、插屏、激励视频、Banner、
  信息流和 Draw 信息流。
* 新增 `GromoreAdsKit.getAdLoadInfo`，结构化返回 Android/iOS 每个 ADN 的
  waterfall 加载结果。
* Android Feed/Draw PlatformView 支持模板和自渲染广告，自动注册展示、点击和
  dislike 交互。
* iOS Feed/Draw PlatformView 支持模板和自渲染物料，补齐物料布局与点击区域注册。
* Android/iOS Banner 补齐混合信息流默认布局；Android PlatformView 接入 dislike。
* 新增自定义 ADN 接入边界说明和 0.2.0 到 0.3.0 迁移说明。

## 0.2.0

* Android GroMore SDK 升级到 7.7.1.6，并按官方要求加入 OkHttp 3.12.1。
* Android 编译环境对齐 Flutter 3.41：compileSdk 36、Java 17、AGP 8.11.1、Kotlin 2.2.20。
* iOS Ads-CN 升级到 7.7.0.7，最低系统版本提高到 iOS 13.0。
* iOS 测试工具改为通过 `canImport` 检测宿主 Debug framework，避免测试包进入 Release。
* 移除过时的 Android 内置 tools-release.aar，改为运行时检测宿主 Debug 依赖。
* 更新隐私、ATT、SKAdNetwork、多进程、ABI 和测试工具接入文档。
* 适配 GroMore 7.2+ 已移除的激励视频“再看一次”和 iOS 开屏 ZoomOut 接口。
* 插屏、激励视频在展示前严格检查 `isReady`，并补齐 Android 展示后 eCPM 事件。
* 修正 Dart eCPM 对 Android/iOS 当前原生字段名的解析。
* 按官方能力限制 Banner、Draw 信息流通用预加载。
* iOS 广告请求增加 SDK 初始化状态检查。
* 新增 0.1.0 到 0.2.0 迁移说明。

## 0.1.0

* 使用 Flutter 3.41.10 和 Dart 3.11.5 创建插件骨架。
* 支持 Android 和 iOS。
* 支持开屏、插屏、Banner、激励视频、信息流和 Draw 信息流广告。
* 支持广告事件、错误、奖励和 eCPM 回调。
* 保留上游 MIT 许可证并记录来源版本。
