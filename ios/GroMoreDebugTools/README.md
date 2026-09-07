# GroMore iOS 官方预览工具

这里保存穿山甲官方下载包中的：

- `BUAdTestMeasurement.xcframework`
- `BUAdTestMeasurement.bundle`

这些文件由 `gromore_ads_kit.podspec` 统一携带，插件使用者不需要再修改宿主 `Podfile`。
测试工具的调用入口仍由 `#if DEBUG` 限制；Release 包会携带二进制和资源，但不会开放入口。

当前二进制来自穿山甲控制台生成的 `union_platform_iOS_7.8.0.2` 官方包，并与插件的
`Ads-CN-Beta/CSJMediation 7.8.0.2` 配套使用。
