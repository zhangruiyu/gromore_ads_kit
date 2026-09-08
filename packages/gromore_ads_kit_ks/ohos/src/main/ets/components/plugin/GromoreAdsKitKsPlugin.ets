import { FlutterPlugin, FlutterPluginBinding } from '@ohos/flutter_ohos';

/** 只负责让快手广告 SDK 和 GroMore Adapter 随宿主一起打包。 */
export default class GromoreAdsKitKsPlugin implements FlutterPlugin {
  getUniqueClassName(): string {
    return 'GromoreAdsKitKsPlugin';
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {}

  onDetachedFromEngine(binding: FlutterPluginBinding): void {}
}
