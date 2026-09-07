# gromore_ads_kit 示例

这个示例用于验证插件能在 Android、iOS 和 HarmonyOS 工程中正确注册、解析原生
SDK 并完成构建。

真正请求广告前，请先按根目录 [`README.md`](../README.md) 配置：

- GroMore 后台为 Android、iOS、HarmonyOS 分别创建的 App ID 和广告位 ID；
- 用户隐私协议同意流程；
- Android 所选 ADN 在 GroMore 后台的代码位配置；SDK 和 Adapter 已由插件内置；
- iOS ATT、SKAdNetwork、隐私清单和所选 ADN；
- HarmonyOS OHPM 仓库、隐私权限、可选 ADN 和 Flutter OHOS 入口注册；
- Android 和 iOS 都由插件内置、业务入口建议只在 Debug 中开放的官方预览测试工具。

HarmonyOS 详细配置见 [`doc/HARMONYOS.md`](../doc/HARMONYOS.md)。占位 App ID
不会产生真实广告，请替换成 GroMore 后台为各端创建的独立 App ID。
