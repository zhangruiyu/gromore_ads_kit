# 1.x 升级到 2.0.0

`2.0.0` 把第三方 ADN 和官方测试工具从核心插件拆出。广告 API 没有变化，业务代码
仍使用 `GromoreAdsKit`；只需要按实际后台配置调整 `pubspec.yaml`。

只接 GroMore/穿山甲：

```yaml
dependencies:
  gromore_ads_kit: ^2.0.0
```

按需增加扩展：

```yaml
dependencies:
  gromore_ads_kit: ^2.0.0
  gromore_ads_kit_gdt: ^1.0.0
  gromore_ads_kit_baidu: ^1.0.0
  gromore_ads_kit_sigmob: ^1.0.0
  gromore_ads_kit_ks: ^1.0.0
```

需要全部四家时可以改用：

```yaml
dependencies:
  gromore_ads_kit_all: ^2.0.0
```

扩展包会被 Flutter 自动注册，不需要在 Dart 代码中初始化它们。

官方测试工具只在本地调试时临时加入：

```yaml
dependencies:
  gromore_ads_kit_debug_tools: ^1.0.0
```

Android 测试 AAR 仅进入 Debug 变体。iOS 的 CocoaPods 依赖没有等价的 Debug-only
Flutter 插件机制，因此上架前必须移除 `gromore_ads_kit_debug_tools`，再执行：

```shell
flutter pub get
cd ios && pod install
```

从核心包移除某个 ADN 后，还应在 GroMore 后台关闭对应广告网络，或者安装匹配扩展；
否则 SDK 初始化日志会提示对应 Adapter 未接入。
