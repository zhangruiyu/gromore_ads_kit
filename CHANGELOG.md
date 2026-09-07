## Unreleased

* HarmonyOS 内置优量汇 `@gdt/gdt-union-sdk 1.2.0` HAR 和匹配的 GroMore Adapter
  `@csj/adapter_gdt 1.2.0-2`，宿主无需再复制 HAR 或配置 `runtimeOnly`。
* HarmonyOS 内置快手 `ksadsdk 3.0.6` 和匹配的 GroMore Adapter
  `@csj/adapter_ks 3.0.6-6`，全部通过官方 OHPM 仓库远程依赖。
* Android 将 `mediation-test-tools:7.7.1.6` 改为插件内置依赖，宿主不再重复配置。
* Android 将 GroMore、测试工具和四家 ADN Adapter 一并放进插件本地 Maven，宿主
  不再需要配置字节跳动 Maven 仓库。
* Android GroMore SDK、测试工具和 ADN Adapter 统一使用 `com.pangle.cn` 正式 Maven
  坐标，与 GroMore 官方 Android 下载包保持一致。
* Android 内置 GroMore `7.7.1.6` 官方包配套的百度 SDK `9.4503`，修复只有
  Adapter、缺少百度原生 SDK 导致的初始化失败。
* Android 内置 GroMore `7.7.1.6` 官方包配套的快手 SDK `5.3.20.1` 和 Adapter
  `5.3.20.1.1`，修复快手广告创建 ADN loader 失败。
* Android 按 GroMore 官方工程补齐穿山甲 `TTFileProvider` 和优量汇
  `GDTFileProvider`，修复官方测试工具中两家 Manifest 检测失败。
* 移除 Android 原生层的 Release 构建拦截，测试工具入口是否开放由宿主决定。
* iOS 内置官方 `BUAdTestMeasurement` 预览工具和资源，宿主不再需要修改 Podfile。
* 清理宿主应用专属说明，插件文档和构建配置保持通用。
* iOS 成对内置 GDT、百度、Sigmob、快手四家 ADN 的原生 SDK 与 GroMore Adapter。
* iOS GroMore 升级到 `Ads-CN-Beta 7.8.0.2`，并对齐官方包要求的 GDT、百度、Sigmob、快手 SDK 与 Adapter 版本。

## 1.0.1

* Android 内置优量汇 SDK `4.680.1550` 和匹配的 GroMore Adapter
  `4.680.1550.1`，与 GroMore 后台导出的 beta Maven 接入配置保持一致。
* 移除未实际应用、也不能自动引入三方 ADN SDK 的
  `mediation-auto-adapter` 构建脚本依赖。
* 补充 Android 第三方 ADN 的接入边界和 Sigmob 本地 AAR 接入说明。

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
