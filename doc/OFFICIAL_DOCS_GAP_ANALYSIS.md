# GroMore 官网能力核对

核对日期：2026-08-27。基线为 Android GroMore `7.7.1.6`、iOS Ads-CN
`7.7.0.7`。

## 通用插件能力已经完成

| 能力 | Android | iOS | 说明 |
| --- | --- | --- | --- |
| SDK 初始化 | 已支持 | 已支持 | 用户同意隐私政策后初始化；成功后才允许请求广告 |
| 完整隐私控制 | 已支持 | 已支持 | Android 接入 `TTCustomController`/`MediationPrivacyConfig`；iOS 接入 `BUAdSDKPrivacyProvider` 和当前头文件公开的 Mediation 开关 |
| 开屏 | 已支持 | 已支持 | 包含专用预加载、底部 Logo、兜底配置和 eCPM |
| 插屏/全屏视频 | 已支持 | 已支持 | 先加载后展示，展示前检查 `isReady`，展示后回传 eCPM |
| 激励视频 | 已支持 | 已支持 | 奖励参数、服务端验证回调、展示前 `isReady`、展示后 eCPM |
| Banner 模板 | 已支持 | 已支持 | 支持加载、展示、事件、dislike 和 eCPM |
| Banner 混合信息流 | 已支持 | 已支持 | 提供默认自渲染布局，并注册点击/关闭区域 |
| 信息流模板/自渲染 | 已支持 | 已支持 | 批量加载后通过 Flutter PlatformView 展示 |
| Draw 模板/自渲染 | 已支持 | 已支持 | 批量加载后通过 Flutter PlatformView 展示 |
| Waterfall 诊断 | 已支持 | 已支持 | Dart 可获取每个 ADN 的代码位、名称、错误码和错误信息 |
| 公开 `isReady` | 已支持 | 已支持 | 覆盖六种广告类型；Feed/Draw 通过 `adId` 查询 |
| 通用预加载 | 已限制到官方范围 | 已限制到官方范围 | 激励、插屏/全屏视频、信息流；拒绝 Banner 和 Draw |
| 官方预览测试工具 | 可选接入 | 可选接入 | 仅 Debug；AAR/framework 由宿主从当前生成包加入 |

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

   官网隐私页提到 CAID 开关，但 Ads-CN `7.7.0.7` 当前公开头文件只提供
   `forbiddenIDFA`，没有可编译的 `forbiddenCAID` 属性。插件不会通过未公开 selector
   猜测调用；后续 SDK 公开该字段后再按头文件补入。

4. **产品级自渲染视觉定制**

   插件提供可直接工作的默认布局。若业务需要品牌化排版、视频播放器或特定尺寸，
   仍要在 Android `NativeAdLayoutBuilder.kt` 和 iOS
   `NativeAdViewConfigurator.swift` 上按产品要求定制，同时保留 GroMore 点击区域、
   展示和 dislike 注册。

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
- [GroMore 隐私合规指南](https://www.csjplatform.com/supportcenter/5879)
- [预加载/缓存支持范围](https://www.csjplatform.com/supportcenter/26232)
- [官方预览测试工具](https://www.csjplatform.com/en/supportcenter/28563)
