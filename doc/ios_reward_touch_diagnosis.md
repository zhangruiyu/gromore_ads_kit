# iOS 激励广告触摸残留调查

## 已确认的异常路径

2026-09-10，在 iOS 26.6 真机的快手聚合广告中捕获到以下事件链：

1. 广告由 `KSAdNavigationController` 展示，底层 `FlutterViewController` 已隐藏。
2. 用户在广告的 `TK_VIEW_TKLabel` 上按下。系统时间戳为 `12321.181312` 秒。
3. 同一个广告触点进入隐藏的 `FlutterViewController.touchesBegan`，Dart 收到 `PointerDownEvent`，位置为 `(0, 0)`。
4. 系统在 `12321.213837` 秒分发了抬手事件，但 Flutter 原生入口没有收到对应的 `touchesEnded` 或 `touchesCancelled`。
5. 广告退出后，Flutter 原生 `ongoingTouches` 中仍保留该触点。Dart 侧也遗留了触点，最终由插件原有补偿清理。

这说明至少在这条广告路径中，触摸进入了不应接收它的底层 Flutter 页面，并缺失了结束事件。此次证据不能归因为“取消事件的 stationary 状态被错误转换”；捕获到的其他取消事件均为正常的 cancelled 状态。尚未确定 SDK 内部哪个方法导致了响应传递中断。

## 原生修复

插件使用独立的 `RewardAdHostViewController` 承载激励广告，并在该控制器终止未被广告消费的触摸事件。广告显示和关闭仍由 SDK 处理；插件在退出时移除自己的承载页，再通知调用方。展示失败和销毁路径也会清理承载页。

调用方不需要改变接口用法。原生隔离在关闭 Dart 补偿的情况下通过真机验证后，已移除 Dart 触点清理、追踪代码及仅验证该补偿的测试，`showRewardVideoAd` 恢复为直接调用平台接口。最终修复只保留在插件 iOS 原生层。

### 关闭时短暂黑屏的后续处理

用户随后确认不再卡住，但关闭广告时会短暂黑屏。最初的承载页使用 `.fullScreen` 和黑色背景，SDK 广告先退出、承载页后移除，期间会露出黑底。

承载页改用 `.overFullScreen`、透明背景和非不透明视图，保留下层业务页面；仍保持触摸交互开启，并由承载控制器截住未消费的事件，不通过透明度或禁用交互让触摸穿透。广告关闭和资源释放顺序保持不变。

Apple 对这两种展示方式的区别见 [overFullScreen 文档](https://developer.apple.com/documentation/uikit/uimodalpresentationstyle/overfullscreen)。此项修改已通过 iOS Debug 构建（Xcode 构建耗时 25.9 秒），并重新安装到 iOS 26.6 真机。用户完成“跳过广告 → 滑动关闭”操作后确认：黑屏消失，上下滑动和右滑返回均正常。Dart 触点补偿仍未启用。

## 真机对照结果

| 样本 | Dart 补偿 | 结果 |
| --- | --- | --- |
| 穿山甲按钮关闭 | 开启 | 触点完整，残留为 0；作为正常对照 |
| 快手异常关闭路径 | 开启 | 广告触点进入隐藏的 Flutter 页面，残留 1 个，由补偿清理 |
| 快手另一轮关闭 | 关闭 | 此轮触点完整，残留为 0；不能据此排除间歇性问题 |
| 快手，启用原生承载页 | 关闭 | 广告触点进入 Flutter 的数量为 0，残留为 0；用户确认滑动、返回正常 |

原生隔离已在上述快手真机样本验证，不代表所有聚合广告网络、素材、横屏和错误退场路径都已完成设备验收。

## 验证与临时追踪

原生修改已通过 iOS Debug 构建。移除 Dart 补偿后，插件 45 项测试、独响路由和广告事件相关 4 项测试全部通过；恢复后的 Dart 入口静态分析通过。

独响整库测试为 169 项通过、2 项失败：默认计数器示例仍期待界面存在 `0`，Android 转场测试仍期待旧版 Zoom。这两项测试及其页面实现没有被本次修改；相关路由和广告事件测试通过。

调查使用的 `UIApplication.sendEvent`、Flutter 原生触摸入口日志仅用于 Debug 对照，已从业务工程源代码撤除；临时停用 Dart 补偿的开关也已撤除。正式实现没有运行时替换 Flutter 方法。

本地精简证据保存于 `/tmp/duxiang-ios26-orphan-touch-evidence.log`，对照日志为 `/tmp/duxiang-ios26-isolated-native-touch.log`。
