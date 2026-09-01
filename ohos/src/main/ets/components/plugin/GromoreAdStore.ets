import { MethodChannel } from '@ohos/flutter_ohos';
import { NodeController } from '@kit.ArkUI';
import {
  CSJFullAd,
  CSJNativeAd,
  CSJNativeExpressAd,
  CSJRewardAd,
  CSJSplashAd,
} from '@csj/openadsdk';

export interface ViewAdEntry {
  readonly id: number;
  readonly posId: string;
  channel: MethodChannel | undefined;

  getAdComponent(): NodeController | undefined;

  destroy(): void;
}

export class ExpressAdEntry implements ViewAdEntry {
  readonly id: number;
  readonly posId: string;
  readonly ad: CSJNativeExpressAd;
  channel: MethodChannel | undefined = undefined;

  constructor(id: number, posId: string, ad: CSJNativeExpressAd) {
    this.id = id;
    this.posId = posId;
    this.ad = ad;
  }

  getAdComponent(): NodeController | undefined {
    return this.ad.getAdComponent();
  }

  destroy(): void {
    this.ad.destroy();
  }
}

export class NativeAdEntry implements ViewAdEntry {
  readonly id: number;
  readonly posId: string;
  readonly ad: CSJNativeAd;
  isExpress: boolean;
  channel: MethodChannel | undefined = undefined;

  constructor(id: number, posId: string, ad: CSJNativeAd, isExpress: boolean) {
    this.id = id;
    this.posId = posId;
    this.ad = ad;
    this.isExpress = isExpress;
  }

  getAdComponent(): NodeController | undefined {
    return this.ad.getAdComponent();
  }

  destroy(): void {
    this.ad.destroy();
  }
}

export class RewardAdEntry {
  readonly posId: string;
  readonly ad: CSJRewardAd;
  readonly rewardName: string;
  readonly rewardAmount: number;

  constructor(posId: string, ad: CSJRewardAd, rewardName: string, rewardAmount: number) {
    this.posId = posId;
    this.ad = ad;
    this.rewardName = rewardName;
    this.rewardAmount = rewardAmount;
  }
}

export default class GromoreAdStore {
  static nextAdId: number = 1;
  static splashAds: Map<string, CSJSplashAd> = new Map<string, CSJSplashAd>();
  static interstitialAds: Map<string, CSJFullAd> = new Map<string, CSJFullAd>();
  static rewardAds: Map<string, RewardAdEntry> = new Map<string, RewardAdEntry>();
  static feedAds: Map<number, ViewAdEntry> = new Map<number, ViewAdEntry>();
  static drawFeedAds: Map<number, ViewAdEntry> = new Map<number, ViewAdEntry>();
  static bannerAd: ViewAdEntry | undefined = undefined;

  static allocateId(): number {
    const id = GromoreAdStore.nextAdId;
    GromoreAdStore.nextAdId += 1;
    return id;
  }

  static clearViewAds(entries: Map<number, ViewAdEntry>, ids: number[]): void {
    ids.forEach((id: number) => {
      const entry = entries.get(id);
      entry?.destroy();
      entries.delete(id);
    });
  }

  static destroyAll(): void {
    GromoreAdStore.feedAds.forEach((entry: ViewAdEntry) => entry.destroy());
    GromoreAdStore.drawFeedAds.forEach((entry: ViewAdEntry) => entry.destroy());
    GromoreAdStore.bannerAd?.destroy();
    GromoreAdStore.splashAds.clear();
    GromoreAdStore.interstitialAds.clear();
    GromoreAdStore.rewardAds.clear();
    GromoreAdStore.feedAds.clear();
    GromoreAdStore.drawFeedAds.clear();
    GromoreAdStore.bannerAd = undefined;
  }
}
