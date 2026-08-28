# 从 0.1.0 升级到 0.2.0

`0.2.0` 将 Android GroMore 升级到 `7.7.1.6`，iOS Ads-CN 升级到
`7.7.0.7`。Flutter API 没有改名，但原生最低版本和测试工具接入方式有变化。

## 必做

1. Android `minSdk` 调整为 `24`，确保宿主能访问字节跳动 Maven 仓库。
2. iOS Deployment Target 调整为 `13.0`，使用 Xcode `15.2+`。
3. 重新执行 `flutter pub get` 和 `pod install --repo-update`，让 CocoaPods 更新锁文件。
4. 确认用户同意宿主隐私政策后再调用 `initAd`。
5. 等 `initAd` 返回 `true` 后再加载广告。
6. iOS 补齐 ATT 用途文案、穿山甲 SKAdNetwork ID，并合并最新隐私清单。
7. 删除 `enablePlayAgain: true` 的业务逻辑。GroMore 7.2 起已下线“再看一次”，
   插件只为源码兼容保留这个 Dart 参数并忽略它。
8. 不要再给通用 `preload` 传 Banner 或 Draw 信息流；官方只支持激励视频、
   插屏/全屏视频和信息流。开屏继续使用插件自己的开屏预加载参数。

## 行为变化

- 插屏和激励视频在原生 `isReady == false` 时不再冒险调用展示，而是返回错误。
- iOS 13+ 广告请求会检查 SDK 是否已经初始化成功。
- Ads-CN 7.7 已移除 iOS 开屏 ZoomOut 接口，旧 `supportZoomOutView` 参数被忽略。
- 信息流和 Draw 信息流仍只支持模板渲染，自渲染广告暂不支持 Flutter PlatformView。

## Android 测试工具

插件已删除旧的内置 `tools-release.aar`。需要测试时，从 GroMore 后台当前生成包中
取出它，放到宿主 `android/app/libs/`，只在 Debug 配置添加：

```kotlin
dependencies {
    debugImplementation(files("libs/tools-release.aar"))
}
```

Release 包不要添加这个 AAR，也不要调用 `launchTestTools()`。

## iOS 测试工具

删除旧版独立 Pod `BUAdTestMeasurement 6.8.1.3`。从 GroMore 后台当前 SDK 生成包
取得 `BUAdTestMeasurement.xcframework` 和资源 Bundle，只加入宿主 Debug 配置。

不要把 `Ads-CN/BUAdTestMeasurement` subspec 固定到插件 Podspec：它与
`CSJMediation` 合并为同一个 CocoaPods target 后，测试框架可能进入 Release。

## 清理旧缓存

如果 CocoaPods 仍解析到 6.x，可先备份并删除宿主 `ios/Podfile.lock`，再执行：

```shell
flutter clean
flutter pub get
cd ios
pod install --repo-update
```

团队项目应把新的 `Podfile.lock` 一起评审。
