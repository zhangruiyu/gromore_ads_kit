# 自定义 ADN 接入边界

自定义 ADN 不是只靠 Flutter 层就能通用实现的功能。它至少依赖以下宿主信息：

- GroMore 后台为当前应用和广告位生成的自定义 ADN 配置；
- 自定义 ADN 自己的 Android/iOS SDK；
- 与当前 GroMore 版本匹配的 Adapter；
- SDK 初始化、广告加载、展示、竞价、销毁和隐私字段的真实接口。

因此基础插件不会内置一个假的“万能 Adapter”，也不会擅自加入所有三方网络。

## 正确接法

1. 在 GroMore 后台为目标应用配置自定义 ADN，并下载当前 SDK 生成包。
2. Android 把匹配的 SDK/Adapter 依赖放到宿主 `app`；iOS 把匹配的 Pod 或
   framework 放到宿主 target。
3. 按官方自定义 Adapter 协议实现独立 Android/iOS Adapter 包。
4. 保持 Adapter 包与本插件解耦，只让宿主选择需要的网络和版本。
5. 使用 GroMore Debug 测试工具逐广告位验证加载、展示、点击、竞价和隐私行为。

当你提供具体 ADN 名称、SDK、Adapter 文档和 GroMore 后台生成包后，可以在这个
边界内继续实现一个可编译、可验证的独立 Adapter，而不污染基础插件。

官方入口：[Android 自定义 ADN](https://www.csjplatform.com/supportcenter/28682)。
