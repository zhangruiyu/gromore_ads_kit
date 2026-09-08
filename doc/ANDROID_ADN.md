# Android 第三方 ADN 接入

GroMore 的聚合配置和 Android 依赖是两件事。后台启用一个 ADN 后，最终 APK
还必须同时包含该 ADN 的原生 SDK 和与它匹配的 GroMore Adapter。

当前 GroMore SDK、官方测试工具和下列 Adapter 都由插件通过字节跳动官方 Maven
仓库引入，宿主不需要再写这些依赖。插件只为没有可靠远程坐标的百度、Sigmob、
快手指定版本原生 SDK 保留本地 Maven 文件。

## 优量汇

插件 `1.0.1` 已内置以下依赖，宿主不要重复添加：

```groovy
implementation 'com.qq.e.union:union:4.680.1550'
implementation 'com.pangle.cn:mediation-gdt-adapter:4.680.1550.1'
```

如果其他应用从 GroMore 后台下载的生成包指定了不同版本，应同时替换 SDK 和
Adapter，不能只改其中一个。

插件已自动声明官方工程要求的 `com.qq.e.comm.GDTFileProvider` 和固定下载缓存
路径。宿主无需重复声明；最终合并 Manifest 中缺少该 Provider 时，GroMore 官方
测试工具会把优量汇的 Manifest 状态标红。

## 穿山甲

插件已经引入 `com.pangle.cn:mediation-sdk:7.7.1.6`。这个融合 SDK 包含穿山甲
能力，穿山甲没有需要单独添加的 Adapter。

插件已自动声明官方工程要求的 `com.bytedance.sdk.openadsdk.TTFileProvider` 和
文件路径资源。宿主无需重复声明；GroMore 融合 SDK 自带的其他 Provider 不能替代
测试工具检查的这一项。

## 百度

插件 `1.0.1` 已内置 GroMore `7.7.1.6` 官方 Android 下载包中的百度 SDK
`9.4503`，并配套以下 Adapter：

```groovy
implementation 'com.baidu.local:mobads:9.4503'
implementation 'com.pangle.cn:mediation-baidu-adapter:9.4503.1'
```

`com.baidu.local` 是插件内部 Maven 目录里的本地坐标。GroMore Adapter 不会自动
传递百度原生 SDK；只添加 Adapter 会在初始化时出现 `AdSettings` 类找不到。

## Sigmob

插件 `1.0.1` 已内置以下相互匹配的依赖：

```groovy
implementation 'com.sigmob.local:windad:4.25.14'
implementation 'com.sigmob.local:windad-common:2.0.1'
implementation 'com.pangle.cn:mediation-sigmob-adapter:4.25.14.1'
```

`com.sigmob.local` 是插件内部 Maven 目录里的本地坐标，不会从公网下载。WindAd AAR
已自带 `sigmob_provider_paths.xml`、Manifest 组件和混淆规则，宿主不要重复复制。其他
应用若使用不同的 GroMore 生成包，必须同时替换 WindAd、common 和 Adapter，不能只
升级其中一个。

SDK 接好后，还需要在 GroMore 后台把 Sigmob 代码位加入对应的聚合广告位。测试工具
能识别出 SDK、Adapter 版本和 Manifest，只说明组件已经进入 APK。测试工具还会按它
自己的“建议版本范围”标红；如果后台当前生成包明确给出的版本与明细中识别到的版本
一致，应再结合初始化日志判断，不能只看红绿颜色。最终必须单独加载并展示该 Sigmob
代码位，才算完成真机验证。

Sigmob 会尝试读取 OAID。若日志出现 `MdidSdkHelper` 找不到，说明 App 没有直接接入
MSA OAID SDK。OAID 组件需要从 MSA 官方取得，并为应用包名和签名配置证书，不能随便
塞一个来历不明的 AAR；接入前还要同步核对隐私政策和用户授权时机。

## 快手

插件已内置 GroMore `7.7.1.6` 官方 Android 生成包中的快手原生 SDK 和匹配的
Adapter：

```groovy
implementation 'com.kuaishou.local:kssdk-ad:5.3.20.1'
implementation 'com.pangle.cn:mediation-ks-adapter:5.3.20.1.1'
```

`com.kuaishou.local` 是插件内部 Maven 目录里的本地坐标。快手 Adapter 不会自动
传递快手原生 SDK；只接 Adapter 时，GroMore 会提示 `ks创建失败，请检查adapter是否接入`
或 `create adn loader fail`。其他应用无需在宿主工程重复声明这两个依赖。

这两个版本必须一起升级，并以 GroMore 后台生成包为准。SDK 进入 APK 只代表接入
完成；是否能填充、参与竞价并最终展示，还取决于后台代码位、请求环境和瀑布流竞价结果。

## 为什么不用自动 Adapter 插件

`mediation-auto-adapter` 只尝试根据已经存在的 ADN SDK 版本选择 Adapter，本身不会
下载优量汇或 Sigmob SDK。Flutter 插件的 `buildscript classpath` 也不会自动把这个
Gradle 插件应用到宿主 App，因此基础插件不再保留这项无效依赖。

## Maven 坐标和版本检测

Android 的 GroMore SDK、测试工具和各 ADN Adapter 必须来自同一个版本通道。
本插件直接使用 `com.pangle.cn` 正式 Maven 通道。不要把其中一项改成
`com.pangle_beta.cn`。GroMore `7.7.1.6` 的正式 Maven 二进制与后台生成包经文件
校验内容相同，因此改为远程依赖不会改变运行时代码。

2026-09-03 从 GroMore 后台实时生成的 Android `7.7.1.6` 官方包仍指定 GDT
`4.680.1550` / Adapter `4.680.1550.1`、Sigmob `4.25.14` / Adapter
`4.25.14.1`。同一官方生成包还指定快手 `5.3.20.1` / Adapter `5.3.20.1.1`。
如果测试工具在线规则要求 GDT `4.690.1560.x` 或 Sigmob
`4.25.80.x`，而后台生成包和官方 Maven 尚未提供对应 Adapter，说明下载包与在线
检测规则尚未同步。此时不能伪造版本号，也不能只升级原生 SDK；应等待官方发布成对
版本后一起更新。

官方资料：

- [GroMore Android SDK 集成与工程配置](https://www.csjplatform.com/supportcenter/28659)
- [Sigmob Android SDK 接入说明](https://doc.sigmob.com/en/sigmob/1110/)
