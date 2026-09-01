import {
  Any,
  EventChannel,
  EventSink,
  FlutterPluginBinding,
  StreamHandler,
} from '@ohos/flutter_ohos';
import { MediationAdInfo } from '@csj/openadsdk';

export default class GromoreAdEvents implements StreamHandler {
  private eventChannel: EventChannel | null = null;
  private eventSink: EventSink | null = null;

  attach(binding: FlutterPluginBinding): void {
    this.eventChannel = new EventChannel(binding.getBinaryMessenger(), 'gromore_ads_kit_event');
    this.eventChannel.setStreamHandler(this);
  }

  detach(): void {
    this.eventChannel = null;
    this.eventSink = null;
  }

  onListen(args: Any, events: EventSink): void {
    this.eventSink = events;
  }

  onCancel(args: Any): void {
    this.eventSink = null;
  }

  emit(action: string, posId: string, extra?: Record<string, Any>): void {
    const payload: Record<string, Any> = {
      'action': action,
      'posId': posId,
      'timestamp': Date.now(),
    };
    if (extra !== undefined) {
      payload['extra'] = extra;
    }
    this.eventSink?.success(payload);
  }

  emitError(action: string, posId: string, code: number, message: string): void {
    this.emit(action, posId, {
      'code': code,
      'errorCode': code,
      'message': message,
      'errorMessage': message,
    });
  }

  emitEcpm(action: string, posId: string, rawInfo: object | undefined): void {
    if (!(rawInfo instanceof MediationAdInfo)) {
      return;
    }

    const ecpmInfo = rawInfo.getShowEcpm();
    if (ecpmInfo === undefined) {
      return;
    }

    this.emit(action, posId, {
      'ecpm': ecpmInfo.getEcpm(),
      'networkName': ecpmInfo.getAdnName(),
      'adnId': ecpmInfo.getAdnRitId(),
      'ritType': ecpmInfo.getRitType(),
      'requestId': ecpmInfo.getRequestId(),
      'channel': ecpmInfo.getChannel(),
      'subChannel': ecpmInfo.getSubChannel(),
      'scenarioId': ecpmInfo.getScenarioId(),
      'reqBiddingType': ecpmInfo.getBiddingType(),
    });
  }
}
