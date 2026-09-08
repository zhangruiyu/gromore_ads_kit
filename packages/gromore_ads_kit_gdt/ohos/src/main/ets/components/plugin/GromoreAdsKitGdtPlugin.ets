import { FlutterPlugin, FlutterPluginBinding } from '@ohos/flutter_ohos';

/** 只负责让优量汇 SDK 和 GroMore Adapter 随宿主一起打包。 */
export default class GromoreAdsKitGdtPlugin implements FlutterPlugin {
  getUniqueClassName(): string {
    return 'GromoreAdsKitGdtPlugin';
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {}

  onDetachedFromEngine(binding: FlutterPluginBinding): void {}
}
