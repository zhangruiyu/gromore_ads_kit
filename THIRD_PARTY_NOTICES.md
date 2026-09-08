# 三方组件说明

`gromore_ads_kit` 的源码使用仓库根目录 `LICENSE` 中的 MIT 许可证。插件同时包含
广告平台提供的二进制 SDK；这些二进制不因插件源码许可证而改变其原有授权条件。

本项目基于
[`Xlxinxi/flutter_gromore_ads`](https://github.com/Xlxinxi/flutter_gromore_ads)
提交 `832a78c0a664fa694bb292064ec539d46fd853a2` 改造。上游项目使用 MIT 许可证，
其版权声明和许可证文本保留在本项目的 `LICENSE` 中。

## 快手 Android 广告 SDK

- 原生 SDK：`kssdk-ad 5.3.20.1`
- 原生 SDK 文件：`android/maven/com/kuaishou/local/kssdk-ad/5.3.20.1/kssdk-ad-5.3.20.1.aar`
- 原生 SDK SHA-256：`807bcb5b221258826e6f02ff5557616117767f45b8aa7ee4c31fdfec3586c9a1`
- GroMore Adapter：`mediation-ks-adapter 5.3.20.1.1`
- Adapter 来源：字节跳动正式 Maven `com.pangle.cn:mediation-ks-adapter:5.3.20.1.1`
- 获取来源：穿山甲后台生成的 GroMore Android `7.7.1.6` 官方完整包

上述二进制继续受各自平台的许可条款约束。

## 优量汇 HarmonyOS SDK

- 包名：`@gdt/gdt-union-sdk`
- 版本：`1.2.0`
- 文件：`ohos/libs/GDTUnionSDK-default-release.har`
- SHA-256：`9d0f5af8fe54acea7a8872759b5d60478309af551cfbdd99dc8e298a5ec45a9e`
- 获取来源：公开 HarmonyOS 广告聚合示例仓库
  [`bayescom/Harmony_AdvanceSDK`](https://github.com/bayescom/Harmony_AdvanceSDK)
- HAR 包内 `oh-package.json5` 声明：`license: Apache-2.0`

升级三方 SDK 时，应重新核对 GroMore 官方版本配对、包内许可证声明，并更新本文件的
版本号和 SHA-256。
