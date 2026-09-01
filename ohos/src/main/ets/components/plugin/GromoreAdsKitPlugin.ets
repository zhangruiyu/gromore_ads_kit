import {
  AbilityAware,
  AbilityPluginBinding,
  Any,
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
} from '@ohos/flutter_ohos';
import { UIAbility } from '@kit.AbilityKit';
import { ArrayList, List } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { display, UIContext, window } from '@kit.ArkUI';
import {
  AdLoadType,
  AdSlot,
  AdSlotBuilder,
  AdSlotType,
  CSJAdSdk,
  CSJDrawAd,
  CSJDrawAdListener,
  CSJFeedAd,
  CSJFeedAdListener,
  CSJFullAd,
  CSJNativeAd,
  CSJNativeAdListener,
  CSJNativeExpressAd,
  CSJRewardAd,
  CSJSplashAd,
  CSJSplashAdCloseType,
  CSJSplashAdLoadParam,
  CSJSplashUserData,
  FullAdLoadListener,
  MediationConfigBuilder,
  NativeExpressAdListener,
  REWARD_AWARD_TYPE,
  RewardAdLoadListener,
  SDKConfigBuilder,
} from '@csj/openadsdk';
import GromoreAdEvents from './GromoreAdEvents';
import GromoreAdPlatformViewFactory from './GromoreAdPlatformView';
import GromoreAdStore, {
  ExpressAdEntry,
  NativeAdEntry,
  RewardAdEntry,
} from './GromoreAdStore';
import HarmonyPrivacyController from './HarmonyPrivacyController';

type ExpressAdKind = 'feed' | 'drawFeed' | 'banner';

export default class GromoreAdsKitPlugin implements FlutterPlugin, MethodCallHandler, AbilityAware {
  private methodChannel: MethodChannel | null = null;
  private uiAbility: UIAbility | null = null;
  private readonly events: GromoreAdEvents = new GromoreAdEvents();

  getUniqueClassName(): string {
    return 'GromoreAdsKitPlugin';
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.methodChannel = new MethodChannel(binding.getBinaryMessenger(), 'gromore_ads_kit');
    this.methodChannel.setMethodCallHandler(this);
    this.events.attach(binding);

    binding.getPlatformViewRegistry().registerViewFactory(
      'gromore_ads_kit_feed',
      new GromoreAdPlatformViewFactory('feed', binding.getBinaryMessenger()),
    );
    binding.getPlatformViewRegistry().registerViewFactory(
      'gromore_ads_kit_draw_feed',
      new GromoreAdPlatformViewFactory('drawFeed', binding.getBinaryMessenger()),
    );
    binding.getPlatformViewRegistry().registerViewFactory(
      'gromore_ads_kit_banner',
      new GromoreAdPlatformViewFactory('banner', binding.getBinaryMessenger()),
    );
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.methodChannel?.setMethodCallHandler(null);
    this.methodChannel = null;
    this.events.detach();
    GromoreAdStore.destroyAll();
  }

  onAttachedToAbility(binding: AbilityPluginBinding): void {
    this.uiAbility = binding.getAbility();
  }

  onDetachedFromAbility(): void {
    this.uiAbility = null;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case 'getPlatformVersion':
        result.success('HarmonyOS');
        break;
      case 'requestIDFA':
        result.success(true);
        break;
      case 'requestPermissionIfNecessary':
        this.requestPermissionIfNecessary(result);
        break;
      case 'initAd':
        this.initAd(call, result);
        break;
      case 'isReady':
        this.isReady(call, result);
        break;
      case 'getAdLoadInfo':
        result.success([]);
        break;
      case 'preload':
        this.preload(call, result);
        break;
      case 'showSplashAd':
        this.showSplashAd(call, result);
        break;
      case 'loadInterstitialAd':
        this.loadInterstitialAd(call, result);
        break;
      case 'showInterstitialAd':
        this.showInterstitialAd(call, result);
        break;
      case 'loadRewardVideoAd':
        this.loadRewardVideoAd(call, result);
        break;
      case 'showRewardVideoAd':
        this.showRewardVideoAd(call, result);
        break;
      case 'loadFeedAd':
        this.loadNativeAds(call, result, 'feed');
        break;
      case 'clearFeedAd':
        this.clearExpressAds(call, result, 'feed');
        break;
      case 'loadDrawFeedAd':
        this.loadNativeAds(call, result, 'drawFeed');
        break;
      case 'clearDrawFeedAd':
        this.clearExpressAds(call, result, 'drawFeed');
        break;
      case 'loadBannerAd':
        this.loadBannerAd(call, result);
        break;
      case 'showBannerAd':
        result.success(false);
        break;
      case 'destroyBannerAd':
        this.destroyBannerAd(result);
        break;
      case 'launchTestTools':
        result.success(false);
        break;
      default:
        result.notImplemented();
    }
  }

  private initAd(call: MethodCall, result: MethodResult): void {
    if (this.uiAbility === null) {
      result.error('ABILITY_UNAVAILABLE', 'HarmonyOS UIAbility is unavailable.', null);
      return;
    }

    const args: Map<string, Any> = this.args(call);
    const appId = this.stringValue(args, 'appId');
    if (appId === undefined || appId.length === 0) {
      result.error('INVALID_ARGUMENT', 'appId cannot be empty.', null);
      return;
    }

    const useMediation = this.booleanValue(args, 'useMediation', true);
    const mediationBuilder = new MediationConfigBuilder().useMediation(useMediation);
    const localConfig = this.stringValue(args, 'config');
    if (localConfig !== undefined && !localConfig.trim().startsWith('{')) {
      mediationBuilder.setCustomLocalConfig(localConfig);
    }

    const privacy: Map<string, Any> | undefined = this.mapValue(args, 'privacy');
    const sdkBuilder = new SDKConfigBuilder()
      .appId(appId)
      .appName(this.stringValue(args, 'appName') ?? 'Flutter')
      .allowShowNotify(this.booleanValue(args, 'allowShowNotify', true))
      .debug(this.booleanValue(args, 'debugMode', false))
      .customController(new HarmonyPrivacyController(privacy))
      .setMediationConfig(mediationBuilder.build());

    const themeStatus = this.numberValue(args, 'themeStatus');
    if (themeStatus !== undefined) {
      sdkBuilder.setThemeStatus(themeStatus);
    }
    const ageGroup = this.numberValue(args, 'ageGroup');
    if (ageGroup !== undefined) {
      sdkBuilder.setAgeGroup(ageGroup);
    }

    // GroMore 官方要求使用 UIAbilityContext；ApplicationContext 可能导致广告展示异常。
    // https://www.csjplatform.com/supportcenter/28671
    CSJAdSdk.init(this.uiAbility.context, sdkBuilder.build());
    CSJAdSdk.start()
      .then((startResult) => {
        if (CSJAdSdk.isSdkReady()) {
          result.success(true);
        } else {
          result.error('SDK_START_FAILED', startResult.msg, startResult.code);
        }
      })
      .catch((error: BusinessError) => {
        result.error('SDK_START_FAILED', error.message, error.code);
      });
  }

  private requestPermissionIfNecessary(result: MethodResult): void {
    if (this.uiAbility === null) {
      result.success(false);
      return;
    }
    CSJAdSdk.requestPermissionIfNeed(this.uiAbility.context);
    result.success(true);
  }

  private isReady(call: MethodCall, result: MethodResult): void {
    const args: Map<string, Any> = this.args(call);
    const adType = this.stringValue(args, 'adType') ?? '';
    const adId = this.numberValue(args, 'adId');
    let ready = false;
    if (adType === 'splash') {
      ready = GromoreAdStore.splashAds.size > 0;
    } else if (adType === 'interstitial') {
      ready = GromoreAdStore.interstitialAds.size > 0;
    } else if (adType === 'rewardVideo') {
      ready = GromoreAdStore.rewardAds.size > 0;
    } else if (adType === 'feed' && adId !== undefined) {
      ready = GromoreAdStore.feedAds.has(adId);
    } else if (adType === 'drawFeed' && adId !== undefined) {
      ready = GromoreAdStore.drawFeedAds.has(adId);
    } else if (adType === 'banner') {
      ready = GromoreAdStore.bannerAd !== undefined;
    }
    result.success(ready);
  }

  private preload(call: MethodCall, result: MethodResult): void {
    if (!CSJAdSdk.isSdkReady()) {
      result.error('SDK_NOT_READY', 'Call initAd after privacy consent before preload.', null);
      return;
    }

    const args: Map<string, Any> = this.args(call);
    const rawConfigs: Array<Map<string, Any>> = args.get('preloadConfigs') as Array<Map<string, Any>>;
    if (rawConfigs === undefined || rawConfigs.length === 0) {
      result.error('INVALID_ARGUMENT', 'preloadConfigs cannot be empty.', null);
      return;
    }

    const slots = new List<AdSlot>();
    rawConfigs.forEach((config: Map<string, Any>) => {
      const adType = this.stringValue(config, 'adType') ?? '';
      const adIds = config.get('adIds') as Array<string>;
      if (adIds === undefined) {
        return;
      }
      adIds.forEach((posId: string) => {
        const builder = new AdSlotBuilder()
          .setCodeId(posId)
          .setAdType(this.preloadAdType(adType))
          .setAdLoadType(AdLoadType.PRELOAD);
        slots.add(builder.build());
      });
    });

    if (slots.length === 0) {
      result.error('INVALID_ARGUMENT', 'No supported preload ad slots were provided.', null);
      return;
    }

    const parallelNum = this.numberValue(args, 'parallelNum') ?? 2;
    const requestIntervalS = this.numberValue(args, 'requestIntervalS') ?? 1;
    CSJAdSdk.getMediationManager().preload(slots, parallelNum, requestIntervalS);
    result.success(true);
  }

  private preloadAdType(adType: string): number {
    if (adType === 'reward_video') {
      return AdSlotType.TYPE_REWARD_VIDEO;
    }
    if (adType === 'feed') {
      return AdSlotType.TYPE_FEED;
    }
    return AdSlotType.TYPE_FULL_SCREEN_VIDEO;
  }

  private showSplashAd(call: MethodCall, result: MethodResult): void {
    const windowStage = this.windowStage(result);
    if (windowStage === undefined) {
      return;
    }
    const uiContext = this.uiContext(result);
    if (uiContext === undefined) {
      return;
    }

    const args: Map<string, Any> = this.args(call);
    const posId = this.requiredPosId(args, result);
    if (posId === undefined) {
      return;
    }

    const onlyPreload = this.booleanValue(args, 'preload', false);
    const cachedAd = GromoreAdStore.splashAds.get(posId);
    if (!onlyPreload && cachedAd !== undefined) {
      GromoreAdStore.splashAds.delete(posId);
      this.attachSplashListeners(cachedAd, posId);
      cachedAd.showSplashAd(windowStage);
      result.success(true);
      return;
    }

    let width: number;
    let height: number;
    try {
      const screen = display.getDefaultDisplaySync();
      width = screen.width / screen.densityPixels;
      height = screen.height / screen.densityPixels;
    } catch (error) {
      const businessError = error as BusinessError;
      result.error('DISPLAY_UNAVAILABLE', businessError.message, businessError.code);
      return;
    }
    const adSlot = new AdSlotBuilder().setCodeId(posId).setAcceptSize(width, height).build();
    const timeoutSeconds = this.numberValue(args, 'timeout') ?? 3.5;
    let replied = false;
    const loadParam = new CSJSplashAdLoadParam(adSlot, {
      onAdLoaded: (ad: CSJSplashAd) => {
        this.attachSplashListeners(ad, posId);
        this.events.emit('splash_loaded', posId);
        if (onlyPreload) {
          GromoreAdStore.splashAds.set(posId, ad);
        } else {
          ad.showSplashAd(windowStage);
        }
        if (!replied) {
          replied = true;
          result.success(true);
        }
      },
      onError: (code: number, message: string) => {
        this.events.emitError('splash_load_fail', posId, code, message);
        if (!replied) {
          replied = true;
          result.error('SPLASH_LOAD_FAILED', message, code);
        }
      },
      onRenderSuccess: (ad: CSJSplashAd) => {
        this.events.emit('splash_render_success', posId);
      },
      onRenderFail: (code: number, message: string) => {
        this.events.emitError('splash_render_fail', posId, code, message);
      },
    }, uiContext, Math.round(timeoutSeconds * 1000));

    const harmony: Map<string, Any> | undefined = this.mapValue(args, 'harmony');
    const fallback: Map<string, Any> | undefined =
      harmony === undefined ? undefined : this.mapValue(harmony, 'fallback');
    if (fallback !== undefined) {
      const adnName = this.stringValue(fallback, 'adnName') ?? '';
      const slotId = this.stringValue(fallback, 'slotId') ?? '';
      const appId = this.stringValue(fallback, 'appId') ?? '';
      const appKey = this.stringValue(fallback, 'appKey');
      loadParam.setSplashUserData(new CSJSplashUserData(adnName, slotId, appId, appKey));
    }
    CSJAdSdk.getAdCreator().loadSplashAd(loadParam);
  }

  private attachSplashListeners(ad: CSJSplashAd, posId: string): void {
    ad.setInteractionListener({
      onDidShow: () => {
        this.events.emit('splash_showed', posId);
        this.events.emitEcpm('splash_ecpm', posId, ad.getMediationAdInfo());
      },
      onDidClick: () => this.events.emit('splash_clicked', posId),
      onDidClose: (closeType: CSJSplashAdCloseType) => {
        if (closeType === CSJSplashAdCloseType.CLICK_SKIP) {
          this.events.emit('splash_skipped', posId);
        }
        this.events.emit('splash_closed', posId, { 'closeType': closeType.value });
      },
      onVideoDidPlayFinish: () => this.events.emit('splash_video_finished', posId),
      onVideoDidPlayFail: (code: number, message: string) => {
        this.events.emitError('splash_render_fail', posId, code, message);
      },
    });
  }

  private loadInterstitialAd(call: MethodCall, result: MethodResult): void {
    const args: Map<string, Any> = this.args(call);
    const posId = this.requiredPosId(args, result);
    if (posId === undefined) {
      return;
    }

    let builder = new AdSlotBuilder().setCodeId(posId);
    const customData = this.stringValue(args, 'customData');
    if (customData !== undefined) {
      builder = builder.setMediaExtra(customData);
    }
    let replied = false;
    const listener: FullAdLoadListener = {
      onAdLoaded: (ad: CSJFullAd) => {
        GromoreAdStore.interstitialAds.set(posId, ad);
        this.attachInterstitialListeners(ad, posId);
        this.events.emit('interstitial_loaded', posId);
        if (!replied) {
          replied = true;
          result.success(true);
        }
      },
      onAdCached: (ad: CSJFullAd) => {
        GromoreAdStore.interstitialAds.set(posId, ad);
        this.events.emit('interstitial_cached', posId);
      },
      onError: (code: number, message: string) => {
        this.events.emitError('interstitial_load_fail', posId, code, message);
        if (!replied) {
          replied = true;
          result.error('INTERSTITIAL_LOAD_FAILED', message, code);
        }
      },
    };
    CSJAdSdk.getAdCreator().loadFullAd(builder.build(), listener);
  }

  private attachInterstitialListeners(ad: CSJFullAd, posId: string): void {
    ad.setInteractionListener({
      onShow: () => {
        this.events.emit('interstitial_showed', posId);
        this.events.emitEcpm('interstitial_ecpm_info', posId, ad.getMediationAdInfo());
      },
      onSkip: () => this.events.emit('interstitial_skipped', posId),
      onClick: () => this.events.emit('interstitial_clicked', posId),
      onClose: () => {
        this.events.emit('interstitial_closed', posId);
        GromoreAdStore.interstitialAds.delete(posId);
      },
      onComplete: () => this.events.emit('interstitial_completed', posId),
    });
  }

  private showInterstitialAd(call: MethodCall, result: MethodResult): void {
    const stage = this.windowStage(result);
    if (stage === undefined) {
      return;
    }
    const posId = this.requiredPosId(this.args(call), result);
    if (posId === undefined) {
      return;
    }
    const ad = GromoreAdStore.interstitialAds.get(posId);
    if (ad === undefined) {
      result.error('AD_NOT_READY', 'Interstitial ad is not ready.', posId);
      return;
    }
    ad.showFullAd(stage);
    result.success(true);
  }

  private loadRewardVideoAd(call: MethodCall, result: MethodResult): void {
    const args: Map<string, Any> = this.args(call);
    const posId = this.requiredPosId(args, result);
    if (posId === undefined) {
      return;
    }

    const rewardName = this.stringValue(args, 'rewardName') ?? '';
    const rewardAmount = this.numberValue(args, 'rewardAmount') ?? 0;
    let builder = new AdSlotBuilder().setCodeId(posId).setRewardName(rewardName).setRewardAmount(rewardAmount);
    const customData = this.stringValue(args, 'customData');
    if (customData !== undefined) {
      builder = builder.setMediaExtra(customData);
    }

    let replied = false;
    const listener: RewardAdLoadListener = {
      onAdLoaded: (ad: CSJRewardAd) => {
        const entry = new RewardAdEntry(posId, ad, rewardName, rewardAmount);
        GromoreAdStore.rewardAds.set(posId, entry);
        this.attachRewardListeners(entry);
        this.events.emit('reward_video_loaded', posId);
        if (!replied) {
          replied = true;
          result.success(true);
        }
      },
      onAdCached: (ad: CSJRewardAd) => {
        this.events.emit('reward_video_cached', posId);
      },
      onError: (code: number, message: string) => {
        this.events.emitError('reward_video_load_fail', posId, code, message);
        if (!replied) {
          replied = true;
          result.error('REWARD_LOAD_FAILED', message, code);
        }
      },
    };
    CSJAdSdk.getAdCreator().loadRewardAd(builder.build(), listener);
  }

  private attachRewardListeners(entry: RewardAdEntry): void {
    const ad = entry.ad;
    const posId = entry.posId;
    ad.setInteractionListener({
      onShow: () => {
        this.events.emit('reward_video_showed', posId);
        this.events.emitEcpm('reward_video_ecpm_info', posId, ad.getMediationAdInfo());
      },
      onSkip: () => this.events.emit('reward_video_skipped', posId),
      onClick: () => this.events.emit('reward_video_clicked', posId),
      onClose: () => {
        this.events.emit('reward_video_closed', posId);
        GromoreAdStore.rewardAds.delete(posId);
      },
      onComplete: () => this.events.emit('reward_video_completed', posId),
      onRewardArrived: (isVerify: boolean, rewardType: REWARD_AWARD_TYPE, extraInfo?: object) => {
        this.events.emit('reward_video_rewarded', posId, {
          'verified': isVerify,
          'rewardType': entry.rewardName,
          'rewardAmount': entry.rewardAmount,
        });
      },
    });
  }

  private showRewardVideoAd(call: MethodCall, result: MethodResult): void {
    const stage = this.windowStage(result);
    if (stage === undefined) {
      return;
    }
    const posId = this.requiredPosId(this.args(call), result);
    if (posId === undefined) {
      return;
    }
    const entry = GromoreAdStore.rewardAds.get(posId);
    if (entry === undefined) {
      result.error('AD_NOT_READY', 'Reward video ad is not ready.', posId);
      return;
    }
    entry.ad.showRewardAd(stage);
    result.success(true);
  }

  private loadNativeAds(call: MethodCall, result: MethodResult, kind: ExpressAdKind): void {
    const uiContext = this.uiContext(result);
    if (uiContext === undefined) {
      return;
    }
    const args: Map<string, Any> = this.args(call);
    const posId = this.requiredPosId(args, result);
    if (posId === undefined) {
      return;
    }

    const width = this.numberValue(args, 'width') ?? 375;
    const height = this.numberValue(args, 'height') ?? (kind === 'drawFeed' ? 667 : 300);
    const count = Math.max(1, Math.min(3, this.numberValue(args, 'count') ?? 1));
    const adSlot = new AdSlotBuilder()
      .setCodeId(posId)
      .setAcceptSize(width, height)
      .setAdCount(count)
      .setSupportRenderControl(true)
      .build();

    // GroMore 鸿蒙聚合要求 Feed/Draw 统一走原生加载接口，由 isExpressAd 区分混出结果。
    // https://www.csjplatform.com/supportcenter/28675
    // https://www.csjplatform.com/supportcenter/28677
    if (kind === 'drawFeed') {
      const listener: CSJDrawAdListener = {
        onError: (code: number, message: string) => {
          this.events.emitError('draw_feed_load_fail', posId, code, message);
          result.error('DRAW_AD_LOAD_FAILED', message, code);
        },
        onDrawAdLoad: (ads: ArrayList<CSJDrawAd>) => {
          this.renderNativeAds(ads, posId, kind, uiContext, result);
        },
      };
      CSJAdSdk.getAdCreator().loadDrawAd(adSlot, listener);
    } else {
      const listener: CSJFeedAdListener = {
        onError: (code: number, message: string) => {
          this.events.emitError('feed_load_fail', posId, code, message);
          result.error('FEED_AD_LOAD_FAILED', message, code);
        },
        onFeedAdLoad: (ads: ArrayList<CSJFeedAd>) => {
          this.renderNativeAds(ads, posId, kind, uiContext, result);
        },
      };
      CSJAdSdk.getAdCreator().loadFeedAd(adSlot, listener);
    }
  }

  private renderNativeAds(
    ads: ArrayList<CSJNativeAd>,
    posId: string,
    kind: ExpressAdKind,
    uiContext: UIContext,
    result: MethodResult,
  ): void {
    if (ads.length === 0) {
      result.error('NATIVE_AD_LOAD_FAILED', 'GroMore returned an empty ad list.', null);
      return;
    }

    const ids = new Array<number>();
    let renderedCount = 0;
    for (let index = 0; index < ads.length; index += 1) {
      const ad = ads[index];
      const id = GromoreAdStore.allocateId();
      const entry = new NativeAdEntry(id, posId, ad, false);
      ids.push(id);
      this.attachNativeListeners(entry, kind);
      let renderCompleted = false;
      ad.setExpressRenderListener({
        onRenderSuccess: (width: number, height: number, isExpress: boolean) => {
          if (renderCompleted) {
            return;
          }
          renderCompleted = true;
          entry.isExpress = isExpress;
          if (kind === 'drawFeed') {
            GromoreAdStore.drawFeedAds.set(id, entry);
          } else {
            GromoreAdStore.feedAds.set(id, entry);
          }
          this.events.emit(kind === 'drawFeed' ? 'draw_feed_render_success' : 'feed_render_success', posId, {
            'adId': id,
            'width': width,
            'height': height,
            'isExpress': isExpress,
          });

          renderedCount += 1;
          if (renderedCount === ads.length) {
            this.events.emit(kind === 'drawFeed' ? 'draw_feed_loaded' : 'feed_loaded', posId, {
              'adIds': ids,
            });
            result.success(ids);
          }
        },
      });
      ad.render(uiContext);
    }
  }

  private attachNativeListeners(entry: NativeAdEntry, kind: ExpressAdKind): void {
    const ad = entry.ad;
    const prefix = kind === 'drawFeed' ? 'draw_feed' : kind;
    ad.setAdInteractionListener({
      onAdClicked: (nativeAd: CSJNativeAd) => {
        this.events.emit(`${prefix}_clicked`, entry.posId, { 'adId': entry.id });
        entry.channel?.invokeMethod('onAdClicked', null);
      },
      onAdCreativeClick: (nativeAd: CSJNativeAd) => {
        this.events.emit(`${prefix}_clicked`, entry.posId, {
          'adId': entry.id,
          'creative': true,
        });
        entry.channel?.invokeMethod('onAdClicked', null);
      },
      onAdShow: (nativeAd: CSJNativeAd) => {
        this.events.emit(`${prefix}_showed`, entry.posId, { 'adId': entry.id });
        entry.channel?.invokeMethod('onAdLoaded', null);
        if (kind === 'drawFeed') {
          this.events.emitEcpm(`${prefix}_ecpm`, entry.posId, (ad as CSJDrawAd).getMediationAdInfo());
        } else if (kind === 'feed') {
          this.events.emitEcpm(`${prefix}_ecpm`, entry.posId, (ad as CSJFeedAd).getMediationAdInfo());
        }
      },
    });

    ad.setDislikeCallback({
      onShow: () => {},
      onSelected: (position: number, value: string, enforce: boolean) => {
        this.events.emit(`${prefix}_closed`, entry.posId, {
          'adId': entry.id,
          'reason': value,
          'enforce': enforce,
        });
        entry.channel?.invokeMethod('onAdClosed', null);
      },
      onCancel: () => {},
    });

    if (kind === 'drawFeed') {
      const drawAd = ad as CSJDrawAd;
      drawAd.setCanInterruptVideoPlay(true);
      drawAd.setDrawVideoListener({
        onVideoLoad: () => {},
        onVideoError: (code: number, message: string) => {
          this.events.emitError(`${prefix}_video_error`, entry.posId, code, message);
        },
        onVideoAdStartPlay: () => entry.channel?.invokeMethod('onVideoPlay', null),
        onVideoAdPaused: () => entry.channel?.invokeMethod('onVideoPause', null),
        onVideoAdContinuePlay: () => entry.channel?.invokeMethod('onVideoPlay', null),
        onProgressUpdate: (current: number, duration: number) => {},
        onVideoAdComplete: () => entry.channel?.invokeMethod('onVideoComplete', null),
        onClickReplay: () => {},
      });
    } else if (kind === 'feed') {
      (ad as CSJFeedAd).setVideoAdListener({
        onVideoLoad: () => {},
        onVideoError: (code: number, message: string) => {
          this.events.emitError(`${prefix}_video_error`, entry.posId, code, message);
        },
        onVideoAdStartPlay: () => entry.channel?.invokeMethod('onVideoPlay', null),
        onVideoAdPaused: () => entry.channel?.invokeMethod('onVideoPause', null),
        onVideoAdContinuePlay: () => entry.channel?.invokeMethod('onVideoPlay', null),
        onProgressUpdate: (current: number, duration: number) => {},
        onVideoAdComplete: () => entry.channel?.invokeMethod('onVideoComplete', null),
      });
    }
  }

  private attachExpressListeners(entry: ExpressAdEntry, kind: ExpressAdKind): void {
    const ad = entry.ad;
    const prefix = kind === 'drawFeed' ? 'draw_feed' : kind;
    ad.setExpressInteractionListener({
      onAdClicked: (type: number) => {
        this.events.emit(`${prefix}_clicked`, entry.posId, { 'interactionType': type });
        entry.channel?.invokeMethod('onAdClicked', null);
      },
      onAdShow: (type: number) => {
        this.events.emit(`${prefix}_showed`, entry.posId, { 'interactionType': type });
        entry.channel?.invokeMethod('onAdLoaded', null);
        const ecpmAction = kind === 'banner' ? 'banner_ecpm' : `${prefix}_ecpm`;
        this.events.emitEcpm(ecpmAction, entry.posId, ad.getMediationAdInfo());
      },
      onRenderFail: (code: number, message: string) => {
        this.events.emitError(`${prefix}_render_fail`, entry.posId, code, message);
        const callback = kind === 'banner' ? 'onRenderFail' : 'onAdRenderFail';
        entry.channel?.invokeMethod(callback, message);
      },
      onRenderSuccess: (width: number, height: number) => {
        this.events.emit(`${prefix}_render_success`, entry.posId, {
          'width': width,
          'height': height,
        });
        if (kind === 'banner') {
          entry.channel?.invokeMethod('onRenderSuccess', { 'width': width, 'height': height });
        } else {
          entry.channel?.invokeMethod('onAdRenderSuccess', null);
        }
      },
    });

    ad.setVideoAdListener({
      onVideoLoad: () => {},
      onVideoError: (code: number, message: string) => {
        this.events.emitError(`${prefix}_video_error`, entry.posId, code, message);
      },
      onVideoAdStartPlay: () => entry.channel?.invokeMethod('onVideoPlay', null),
      onVideoAdPaused: () => entry.channel?.invokeMethod('onVideoPause', null),
      onVideoAdContinuePlay: () => entry.channel?.invokeMethod('onVideoPlay', null),
      onProgressUpdate: (current: number, duration: number) => {},
      onVideoAdComplete: () => entry.channel?.invokeMethod('onVideoComplete', null),
      onClickReplay: () => {},
    });
  }

  private clearExpressAds(call: MethodCall, result: MethodResult, kind: ExpressAdKind): void {
    const rawIds = this.args(call).get('list') as Array<number>;
    const ids = rawIds ?? new Array<number>();
    if (kind === 'drawFeed') {
      GromoreAdStore.clearViewAds(GromoreAdStore.drawFeedAds, ids);
    } else {
      GromoreAdStore.clearViewAds(GromoreAdStore.feedAds, ids);
    }
    result.success(true);
  }

  private loadBannerAd(call: MethodCall, result: MethodResult): void {
    const uiContext = this.uiContext(result);
    if (uiContext === undefined) {
      return;
    }
    const args: Map<string, Any> = this.args(call);
    const posId = this.requiredPosId(args, result);
    if (posId === undefined) {
      return;
    }
    const width = this.numberValue(args, 'width') ?? 375;
    const height = this.numberValue(args, 'height') ?? 60;
    const adSlot = new AdSlotBuilder().setCodeId(posId).setAcceptSize(width, height).build();
    if (this.booleanValue(args, 'harmonyNativeRender', false)) {
      // 官方仅支持直连穿山甲的鸿蒙自渲染 Banner，GroMore 聚合维度暂不支持。
      // https://www.csjplatform.com/supportcenter/28676
      const nativeListener: CSJNativeAdListener = {
        onError: (code: number, message: string) => {
          this.events.emitError('banner_load_fail', posId, code, message);
          result.error('BANNER_NATIVE_LOAD_FAILED', message, code);
        },
        onNativeAdLoad: (ads: ArrayList<CSJNativeAd>) => {
          if (ads.length === 0) {
            result.error('BANNER_NATIVE_LOAD_FAILED', 'GroMore returned an empty native banner list.', null);
            return;
          }
          GromoreAdStore.bannerAd?.destroy();
          const entry = new NativeAdEntry(GromoreAdStore.allocateId(), posId, ads[0], false);
          GromoreAdStore.bannerAd = entry;
          this.attachNativeListeners(entry, 'banner');
          this.events.emit('banner_loaded', posId, { 'native': true });
          result.success(true);
        },
      };
      CSJAdSdk.getAdCreator().loadNativeAd(adSlot, nativeListener);
      return;
    }

    const listener: NativeExpressAdListener = {
      onError: (code: number, message: string) => {
        this.events.emitError('banner_load_fail', posId, code, message);
        result.error('BANNER_LOAD_FAILED', message, code);
      },
      onNativeExpressAdLoad: (ads: ArrayList<CSJNativeExpressAd>) => {
        if (ads.length === 0) {
          result.error('BANNER_LOAD_FAILED', 'GroMore returned an empty banner list.', null);
          return;
        }
        GromoreAdStore.bannerAd?.destroy();
        const entry = new ExpressAdEntry(GromoreAdStore.allocateId(), posId, ads[0]);
        GromoreAdStore.bannerAd = entry;
        this.attachExpressListeners(entry, 'banner');
        entry.ad.render(uiContext);
        this.events.emit('banner_loaded', posId);
        result.success(true);
      },
    };
    CSJAdSdk.getAdCreator().loadBannerAd(adSlot, listener);
  }

  private destroyBannerAd(result: MethodResult): void {
    const entry = GromoreAdStore.bannerAd;
    entry?.destroy();
    GromoreAdStore.bannerAd = undefined;
    if (entry !== undefined) {
      this.events.emit('banner_destroyed', entry.posId);
    }
    result.success(true);
  }

  private args(call: MethodCall): Map<string, Any> {
    return call.args as Map<string, Any>;
  }

  private requiredPosId(args: Map<string, Any>, result: MethodResult): string | undefined {
    const posId = this.stringValue(args, 'posId');
    if (posId === undefined || posId.length === 0) {
      result.error('INVALID_ARGUMENT', 'posId cannot be empty.', null);
      return undefined;
    }
    return posId;
  }

  private stringValue(args: Map<string, Any>, key: string): string | undefined {
    const value: Any = args.get(key);
    return typeof value === 'string' ? value : undefined;
  }

  private numberValue(args: Map<string, Any>, key: string): number | undefined {
    const value: Any = args.get(key);
    return typeof value === 'number' ? value : undefined;
  }

  private booleanValue(args: Map<string, Any>, key: string, fallback: boolean): boolean {
    const value: Any = args.get(key);
    return typeof value === 'boolean' ? value : fallback;
  }

  private mapValue(args: Map<string, Any>, key: string): Map<string, Any> | undefined {
    const value: Any = args.get(key);
    return value instanceof Map ? value as Map<string, Any> : undefined;
  }

  private windowStage(result: MethodResult): window.WindowStage | undefined {
    if (this.uiAbility === null) {
      result.error('ABILITY_UNAVAILABLE', 'HarmonyOS UIAbility is unavailable.', null);
      return undefined;
    }
    return this.uiAbility.context.windowStage;
  }

  private uiContext(result: MethodResult): UIContext | undefined {
    const stage = this.windowStage(result);
    if (stage === undefined) {
      return undefined;
    }
    try {
      return stage.getMainWindowSync().getUIContext();
    } catch (error) {
      const businessError = error as BusinessError;
      result.error('WINDOW_UNAVAILABLE', businessError.message, businessError.code);
      return undefined;
    }
  }
}
