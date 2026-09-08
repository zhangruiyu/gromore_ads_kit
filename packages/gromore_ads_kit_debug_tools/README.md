# gromore_ads_kit_debug_tools

`gromore_ads_kit` 的官方广告测试工具扩展。

> 官方文档要求测试工具不要带到线上版本。请只在本地调试期间添加，验收完成后从宿主依赖中移除。

```yaml
dependencies:
  gromore_ads_kit: ^2.0.0
  gromore_ads_kit_debug_tools: ^1.0.0
```

SDK 初始化完成后调用：

```dart
await GromoreAdsKit.launchTestTools();
```

Android 的测试 AAR 只使用 `debugImplementation`；iOS 受 CocoaPods 限制，添加本包后所有构建配置都会链接测试 Framework，所以发布前必须移除本包并重新执行 `pod install`。
