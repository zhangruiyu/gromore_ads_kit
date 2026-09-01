/// GroMore SDK 隐私控制。
///
/// 所有字段都可选。未设置的字段继续使用插件原有默认值，方便旧项目平滑升级。
/// 建议宿主在用户同意隐私政策后，根据实际授权结果显式填写。
class AdPrivacyConfig {
  const AdPrivacyConfig({
    this.canUseLocation,
    this.latitude,
    this.longitude,
    this.canUseAppTrackingConsent,
    this.devOaid,
    this.canUsePhoneState,
    this.imei,
    this.canUseWifiState,
    this.macAddress,
    this.canUseWriteExternal,
    this.canUseOaid,
    this.oaid,
    this.canUseAndroidId,
    this.androidId,
    this.canUseRecordAudio,
    this.canUseMessage,
    this.canUseAppList,
    this.customAppList,
    this.customDeviceImeis,
    this.userPrivacyConfig,
    this.canUseWifiBssid,
    this.customIdfa,
    this.forbidIdfa,
    this.allowUploadDeviceInfo,
    this.iosPrivacyConfig,
  }) : assert(
         (latitude == null) == (longitude == null),
         'latitude 和 longitude 必须同时设置',
       ),
       assert(
         latitude == null || (latitude >= -90 && latitude <= 90),
         'latitude 必须在 -90 到 90 之间',
       ),
       assert(
         longitude == null || (longitude >= -180 && longitude <= 180),
         'longitude 必须在 -180 到 180 之间',
       );

  /// 是否允许读取定位。Android、iOS、HarmonyOS 均支持。
  final bool? canUseLocation;

  /// 自定义纬度；必须与 [longitude] 一起传入。
  final double? latitude;

  /// 自定义经度；必须与 [latitude] 一起传入。
  final double? longitude;

  /// 是否允许 HarmonyOS SDK 使用应用跟踪授权状态。
  ///
  /// 默认 `false`。宿主申请 `ohos.permission.APP_TRACKING_CONSENT` 后，
  /// 应按真实授权结果传入。
  final bool? canUseAppTrackingConsent;

  /// 宿主主动提供给 HarmonyOS SDK 的 OAID。
  final String? devOaid;

  /// 是否允许读取手机状态。仅 Android。
  final bool? canUsePhoneState;

  /// 自定义 IMEI。仅 Android。
  final String? imei;

  /// 是否允许读取 Wi-Fi 状态。Android、HarmonyOS 支持。
  final bool? canUseWifiState;

  /// 自定义 MAC 地址。Android、HarmonyOS 支持。
  final String? macAddress;

  /// 是否允许写外部存储。仅 Android。
  final bool? canUseWriteExternal;

  /// 是否允许 GroMore 获取 OAID。仅 Android。
  final bool? canUseOaid;

  /// 自定义 OAID。仅 Android。
  final String? oaid;

  /// 是否允许读取 Android ID。仅 Android。
  final bool? canUseAndroidId;

  /// 自定义 Android ID。仅 Android。
  final String? androidId;

  /// 是否允许使用录音权限。仅 Android。
  final bool? canUseRecordAudio;

  /// 是否允许读取短信相关信息。仅 Android。
  final bool? canUseMessage;

  /// 是否允许读取应用列表。仅 Android。
  final bool? canUseAppList;

  /// 宿主主动提供的应用包名列表。仅 Android。
  final List<String>? customAppList;

  /// 宿主主动提供的设备 IMEI 列表。仅 Android。
  final List<String>? customDeviceImeis;

  /// Android GroMore `userPrivacyConfig` 透传字段。
  final Map<String, String>? userPrivacyConfig;

  /// 是否允许读取 Wi-Fi BSSID。仅 iOS。
  final bool? canUseWifiBssid;

  /// 宿主主动提供的 IDFA。仅 iOS。
  final String? customIdfa;

  /// 是否禁止 SDK 获取 IDFA。仅 iOS。
  final bool? forbidIdfa;

  /// 是否允许 GroMore 上传设备信息。仅 iOS。
  final bool? allowUploadDeviceInfo;

  /// iOS `BUAdSDKPrivacyProvider.privacyConfig` 透传字段。
  final Map<String, Object?>? iosPrivacyConfig;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      if (canUseLocation != null) 'canUseLocation': canUseLocation,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (canUseAppTrackingConsent != null)
        'canUseAppTrackingConsent': canUseAppTrackingConsent,
      if (devOaid != null) 'devOaid': devOaid,
      if (canUsePhoneState != null) 'canUsePhoneState': canUsePhoneState,
      if (imei != null) 'imei': imei,
      if (canUseWifiState != null) 'canUseWifiState': canUseWifiState,
      if (macAddress != null) 'macAddress': macAddress,
      if (canUseWriteExternal != null)
        'canUseWriteExternal': canUseWriteExternal,
      if (canUseOaid != null) 'canUseOaid': canUseOaid,
      if (oaid != null) 'oaid': oaid,
      if (canUseAndroidId != null) 'canUseAndroidId': canUseAndroidId,
      if (androidId != null) 'androidId': androidId,
      if (canUseRecordAudio != null) 'canUseRecordAudio': canUseRecordAudio,
      if (canUseMessage != null) 'canUseMessage': canUseMessage,
      if (canUseAppList != null) 'canUseAppList': canUseAppList,
      if (customAppList != null) 'customAppList': customAppList,
      if (customDeviceImeis != null) 'customDeviceImeis': customDeviceImeis,
      if (userPrivacyConfig != null) 'userPrivacyConfig': userPrivacyConfig,
      if (canUseWifiBssid != null) 'canUseWifiBssid': canUseWifiBssid,
      if (customIdfa != null) 'customIdfa': customIdfa,
      if (forbidIdfa != null) 'forbidIdfa': forbidIdfa,
      if (allowUploadDeviceInfo != null)
        'allowUploadDeviceInfo': allowUploadDeviceInfo,
      if (iosPrivacyConfig != null) 'iosPrivacyConfig': iosPrivacyConfig,
    };
  }
}
