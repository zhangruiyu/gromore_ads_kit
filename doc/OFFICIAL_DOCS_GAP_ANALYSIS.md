# GroMore 官网能力核对

核对日期：2026-09-01。基线为 Android GroMore `7.7.1.6`、iOS Ads-CN
`7.8.0.2`、HarmonyOS `@csj/openadsdk 7.5.3`。

## 通用插件能力已经完成

| 能力 | Android | iOS | HarmonyOS | 说明 |
| --- | --- | --- | --- | --- |
| SDK 初始化 | 已支持 | 已支持 | 已支持 | 用户同意隐私政策后初始化；成功后才允许请求广告 |
| 隐私控制 | 已支持 | 已支持 | 已支持 | 鸿蒙映射 OAID、定位、Wi-Fi 和宿主 MAC 控制器 |
| 开屏 | 已支持 | 已支持 | 基础能力已支持 | 鸿蒙支持加载、专用预加载、展示、兜底和 eCPM，底部 Logo/自定义关闭按钮未接入 |
| 插屏/全屏视频 | 已支持 | 已支持 | 已支持 | 先加载后展示，展示后回传 eCPM |
| 激励视频 | 已支持 | 已支持 | 已支持 | 奖励回调、展示状态和 eCPM |
| Banner 模板 | 已支持 | 已支持 | 已支持 | 鸿蒙通过 ArkUI `NodeController` 嵌入 Flutter PlatformView |
| Banner 混合信息流 | 已支持 | 已支持 | 官方不支持 | 鸿蒙 GroMore 聚合暂不支持自渲染 Banner；直连 CSJ 可显式启用内置自渲染 |
| 信息流模板 | 已支持 | 已支持 | 已支持 | 批量加载后通过 Flutter PlatformView 展示 |
| 信息流自渲染 | 已支持 | 已支持 | 已支持 | 鸿蒙使用官方 `loadFeedAd` 混出并注册 ArkUI 计费交互 |
| Draw 模板 | 已支持 | 已支持 | 已支持 | 批量加载后通过 Flutter PlatformView 展示 |
| Draw 自渲染 | 已支持 | 已支持 | 已支持 | 鸿蒙使用官方 `loadDrawAd` 混出，并接入原生视频监听 |
| Waterfall 诊断 | 已支持 | 已支持 | 暂不可用 | 鸿蒙 `getAdLoadInfo` 当前返回空列表 |
| 公开 `isReady` | 已支持 | 已支持 | 已支持 | 覆盖六种广告类型；Feed/Draw 通过 `adId` 查询 |
| 通用预加载 | 已限制到官方范围 | 已限制到官方范围 | 已限制到官方范围 | 激励、插屏/全屏视频、信息流；拒绝 Banner 和 Draw |
| 官方预览测试工具 | 可选接入 | 可选接入 | 暂不可用 | 鸿蒙 `launchTestTools()` 返回 `false` |

GroMore 7.2 起已经下线激励视频“再看一次”。插件不调用被删除的原生接口；旧 Dart
参数和事件名只为源码兼容保留，不会产生“再看一次”回调。Ads-CN 7.7 也已经移除
旧的 iOS 开屏 ZoomOut 接口。

## 仍需要宿主或真实业务资料的部分

1. **自定义 ADN Adapter**

   自定义 ADN 的 SDK、Adapter 版本和后台配置与具体应用绑定，无法在基础 Flutter
   插件中通用生成。宿主提供目标 ADN、官方 SDK、Adapter 文档和 GroMore 当前生成包
   后，应作为独立 Adapter 接入。见 [`CUSTOM_ADN.md`](CUSTOM_ADN.md)。

2. **真实广告位验收**

   本仓库能验证编译、通道、参数和生命周期，但没有业务 App ID、代码位、GroMore
   后台配置和测试设备权限，无法替代真机上的填充、展示、点击、奖励和收益验收。
   发布前必须使用官方 Debug 工具逐个 ADN、逐个广告位验证。

3. **iOS 文档与当前二进制头文件不一致的字段**

   官网隐私页提到 CAID 开关，但 Ads-CN `7.8.0.2` 当前公开头文件只提供
   `forbiddenIDFA`，没有可编译的 `forbiddenCAID` 属性。插件不会通过未公开 selector
   猜测调用；后续 SDK 公开该字段后再按头文件补入。

4. **产品级自渲染视觉定制**

   插件提供可直接工作的默认布局。若业务需要品牌化排版、视频播放器或特定尺寸，
   仍要在 Android `NativeAdLayoutBuilder.kt` 和 iOS
   `NativeAdViewConfigurator.swift` 上按产品要求定制，同时保留 GroMore 点击区域、
   展示和 dislike 注册。

5. **HarmonyOS 高级展示能力**

   当前 HarmonyOS 实现已打通 Feed/Draw 模板与自渲染混出，但开屏底部 Logo、
   自定义关闭按钮尚未接入。鸿蒙 GroMore 聚合维度暂不支持自渲染 Banner；
   插件只在直连穿山甲时通过 `harmonyNativeRender` 显式开启。`AdSlotBuilder` 没有
   Android/iOS 的全部高级 setter，因此音量、场景 ID、竞价回传等参数不伪造支持。

6. **HarmonyOS Waterfall 与预览工具**

   当前 HarmonyOS SDK 公开 API 没有与 Android/iOS 插件现有实现等价的逐 ADN 加载
   明细查询和预览工具启动入口。插件分别返回空列表和 `false`，等待官方公开稳定接口。

7. **HarmonyOS 可选 ADN 与真机验收**

   基础插件只带 `@csj/openadsdk`。快手和广点通通过独立扩展包加入匹配的 SDK、
   Adapter 和 `runtimeOnly` 配置，仍需配置真实后台瀑布流并在签名真机上逐个验证。详见
   [`HARMONYOS.md`](HARMONYOS.md)。

## 官方依据

- [Android SDK 接入与初始化](https://www.csjplatform.com/supportcenter/28659)
- [Android 信息流](https://www.csjplatform.com/supportcenter/28662)
- [Android Banner](https://www.csjplatform.com/supportcenter/28664)
- [Android 自定义 ADN](https://www.csjplatform.com/supportcenter/28682)
- [iOS SDK 接入配置](https://www.csjplatform.com/supportcenter/28696)
- [iOS 初始化与隐私合规](https://www.csjplatform.com/supportcenter/28697)
- [iOS 开屏](https://www.csjplatform.com/supportcenter/28698)
- [iOS 激励视频](https://www.csjplatform.com/supportcenter/28699)
- [iOS 插屏](https://www.csjplatform.com/supportcenter/28700)
- [iOS 信息流](https://www.csjplatform.com/supportcenter/28702)
- [iOS Draw 信息流](https://www.csjplatform.com/supportcenter/28703)
- [HarmonyOS SDK 与工程配置](https://www.csjplatform.com/supportcenter/28670)
- [HarmonyOS 初始化与隐私合规](https://www.csjplatform.com/supportcenter/28671)
- [HarmonyOS 开屏](https://www.csjplatform.com/supportcenter/28672)
- [HarmonyOS 激励视频](https://www.csjplatform.com/supportcenter/28673)
- [HarmonyOS 插全屏](https://www.csjplatform.com/supportcenter/28674)
- [HarmonyOS 信息流](https://www.csjplatform.com/supportcenter/28675)
- [HarmonyOS Banner](https://www.csjplatform.com/supportcenter/28676)
- [HarmonyOS Draw](https://www.csjplatform.com/supportcenter/28677)
- [GroMore 隐私合规指南](https://www.csjplatform.com/supportcenter/5879)
- [预加载/缓存支持范围](https://www.csjplatform.com/supportcenter/26232)
- [官方预览测试工具](https://www.csjplatform.com/en/supportcenter/28563)
