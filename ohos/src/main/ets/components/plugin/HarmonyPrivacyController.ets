import { Any } from '@ohos/flutter_ohos';
import { CSJCustomPrivacyController } from '@csj/openadsdk';

export default class HarmonyPrivacyController extends CSJCustomPrivacyController {
  private canUseTrackingConsent: boolean = false;
  private oaid: string | undefined = undefined;
  private canUseLocationValue: boolean = false;
  private latitude: number | undefined = undefined;
  private longitude: number | undefined = undefined;
  private canUseWifiValue: boolean = false;
  private macAddressValue: string | undefined = undefined;

  constructor(privacy: Map<string, Any> | undefined) {
    super();
    if (privacy === undefined) {
      return;
    }

    this.canUseTrackingConsent = this.readBoolean(
      privacy,
      'canUseAppTrackingConsent',
      this.readBoolean(privacy, 'canUseOaid', false),
    );
    this.oaid = this.readString(privacy, 'devOaid') ?? this.readString(privacy, 'oaid');
    this.canUseLocationValue = this.readBoolean(privacy, 'canUseLocation', false);
    this.latitude = this.readNumber(privacy, 'latitude');
    this.longitude = this.readNumber(privacy, 'longitude');
    this.canUseWifiValue = this.readBoolean(privacy, 'canUseWifiState', false);
    this.macAddressValue = this.readString(privacy, 'macAddress');
  }

  isCanUseAppTrackingConsent(): boolean {
    return this.canUseTrackingConsent;
  }

  getDevOaid(): string | undefined {
    return this.oaid;
  }

  isCanUseLocation(): boolean {
    return this.canUseLocationValue;
  }

  getTTLocation(): number[] | undefined {
    if (this.latitude === undefined || this.longitude === undefined) {
      return undefined;
    }
    return [this.latitude, this.longitude];
  }

  isCanUseWifiState(): boolean {
    return this.canUseWifiValue;
  }

  getMacAddress(): string | undefined {
    return this.macAddressValue;
  }

  private readBoolean(values: Map<string, Any>, key: string, fallback: boolean): boolean {
    const value: Any = values.get(key);
    return typeof value === 'boolean' ? value : fallback;
  }

  private readString(values: Map<string, Any>, key: string): string | undefined {
    const value: Any = values.get(key);
    return typeof value === 'string' ? value : undefined;
  }

  private readNumber(values: Map<string, Any>, key: string): number | undefined {
    const value: Any = values.get(key);
    return typeof value === 'number' ? value : undefined;
  }
}
