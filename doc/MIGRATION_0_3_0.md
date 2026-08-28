# 从 0.2.0 升级到 0.3.0

`0.3.0` 是兼容性功能升级，原有初始化和广告加载调用不用修改。

## 推荐调整

1. 在用户完成隐私选择后，把真实授权结果通过 `AdPrivacyConfig` 传给 `initAd`。
2. 需要在加载完成后决定 UI 状态时，使用 `GromoreAdsKit.isReady`。
3. 排查某个 ADN 为什么没有填充时，在加载回调结束后调用
   `GromoreAdsKit.getAdLoadInfo`。
4. Feed/Draw 返回的 `adId` 在绑定到 Widget 时只消费一次；要在绑定前查询该条
   广告的状态或 waterfall。

## 隐私配置示例

```dart
await GromoreAdsKit.initAd(
  '你的 App ID',
  useMediation: true,
  debugMode: kDebugMode,
  privacy: const AdPrivacyConfig(
    canUseLocation: false,
    canUsePhoneState: false,
    canUseWifiState: true,
    canUseOaid: true,
    canUseAndroidId: false,
    canUseRecordAudio: false,
    canUseMessage: false,
    canUseAppList: false,
    canUseWifiBssid: false,
    forbidIdfa: true,
    allowUploadDeviceInfo: false,
  ),
);
```

不要直接复制示例作为法律结论；字段必须与你的隐私政策、用户授权结果和所接 ADN
保持一致。

## 自渲染变化

Feed 和 Draw 信息流现在同时接受模板与自渲染广告。插件会为自渲染物料提供一套
可直接展示的默认布局，并按 GroMore 要求注册点击区域和 dislike。若产品需要完全
自定义 UI，可以在插件原生布局文件上继续定制，但不要删除 SDK 交互注册。
