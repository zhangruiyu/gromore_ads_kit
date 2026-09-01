import common from '@ohos.app.ability.common';
import { NodeController, UIContext } from '@kit.ArkUI';
import {
  CSJArrayList,
  CSJConstant,
  CSJNativeAd,
} from '@csj/openadsdk';
import {
  Any,
  BinaryMessenger,
  MethodChannel,
  PlatformView,
  PlatformViewFactory,
  StandardMessageCodec,
} from '@ohos/flutter_ohos';
import { Params } from '@ohos/flutter_ohos/src/main/ets/plugin/platform/PlatformView';
import GromoreAdStore, { NativeAdEntry, ViewAdEntry } from './GromoreAdStore';

type AdViewKind = 'feed' | 'drawFeed' | 'banner';

@Component
struct GromoreAdComponent {
  @Prop params: Params;
  private adView: GromoreAdPlatformView = this.params.platformView as GromoreAdPlatformView;

  build() {
    if (this.adView.isNativeRender()) {
      this.buildNativeAd()
    } else if (this.adView.getNodeController() !== undefined) {
      NodeContainer(this.adView.getNodeController()!)
        .width('100%')
        .height('100%')
    } else {
      Stack()
        .width('100%')
        .height('100%')
    }
  }

  @Builder
  private buildNativeAd() {
    if (this.adView.isDrawFeed()) {
      Stack({ alignContent: Alignment.BottomStart }) {
        this.buildMedia()
        Column({ space: 6 }) {
          Row({ space: 8 }) {
            if (this.adView.getIconUrl().length > 0) {
              Image(this.adView.getIconUrl())
                .width(36)
                .height(36)
                .borderRadius(6)
                .id(this.adView.getIconId())
            }
            Text(this.adView.getDescription())
              .fontSize(13)
              .fontColor('#FFFFFFFF')
              .maxLines(2)
              .layoutWeight(1)
              .id(this.adView.getDescriptionId())
            Button(this.adView.getButtonText())
              .fontSize(13)
              .height(34)
              .backgroundColor('#E93C3C')
              .id(this.adView.getCreativeId())
          }
          Row() {
            Text(this.adView.getTitle())
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#FFFFFFFF')
              .maxLines(1)
              .layoutWeight(1)
              .id(this.adView.getTitleId())
            this.buildAdLogo()
            Button('×')
              .fontSize(16)
              .fontColor('#FFFFFFFF')
              .width(30)
              .height(30)
              .backgroundColor('#66000000')
              .onClick(() => this.adView.showDislike(this))
          }
        }
        .width('100%')
        .padding(10)
        .linearGradient({
          angle: 180,
          colors: [['#00000000', 0.0], ['#99000000', 1.0]],
        })
      }
      .width('100%')
      .height('100%')
      .id(this.adView.getRootId())
      .onAppear(() => this.adView.registerNativeInteraction(this.getUIContext()))
    } else {
      Column({ space: 8 }) {
        Row({ space: 8 }) {
          if (this.adView.getIconUrl().length > 0) {
            Image(this.adView.getIconUrl())
              .width(36)
              .height(36)
              .borderRadius(6)
              .id(this.adView.getIconId())
          }
          Column({ space: 2 }) {
            Text(this.adView.getTitle())
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#FF1F2329')
              .maxLines(1)
              .id(this.adView.getTitleId())
            Text(this.adView.getDescription())
              .fontSize(12)
              .fontColor('#FF646A73')
              .maxLines(2)
              .id(this.adView.getDescriptionId())
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          Button('×')
            .fontSize(16)
            .fontColor('#FF8F959E')
            .width(30)
            .height(30)
            .backgroundColor('#00000000')
            .onClick(() => this.adView.showDislike(this))
        }
        this.buildMedia()
        Row({ space: 8 }) {
          Text(`广告 · ${this.adView.getSource()}`)
            .fontSize(11)
            .fontColor('#FF8F959E')
            .layoutWeight(1)
          this.buildAdLogo()
          Button(this.adView.getButtonText())
            .fontSize(13)
            .height(34)
            .backgroundColor('#E93C3C')
            .id(this.adView.getCreativeId())
        }
      }
      .width('100%')
      .height('100%')
      .padding(10)
      .backgroundColor('#FFFFFFFF')
      .id(this.adView.getRootId())
      .onAppear(() => this.adView.registerNativeInteraction(this.getUIContext()))
    }
  }

  @Builder
  private buildMedia() {
    if (this.adView.isVideoAd() && this.adView.getNodeController() !== undefined) {
      NodeContainer(this.adView.getNodeController()!)
        .width('100%')
        .layoutWeight(1)
        .hitTestBehavior(HitTestMode.None)
    } else if (this.adView.getImageUrls().length > 1) {
      Row({ space: 6 }) {
        ForEach(this.adView.getImageUrls(), (url: string, index: number) => {
          Image(url)
            .width(`${100 / this.adView.getImageUrls().length - 2}%`)
            .height('100%')
            .objectFit(ImageFit.Cover)
            .id(this.adView.getImageId(index))
        })
      }
      .width('100%')
      .layoutWeight(1)
    } else if (this.adView.getImageUrls().length === 1) {
      Image(this.adView.getImageUrls()[0])
        .width('100%')
        .layoutWeight(1)
        .objectFit(ImageFit.Cover)
        .id(this.adView.getImageId(0))
    } else {
      Stack()
        .width('100%')
        .layoutWeight(1)
        .backgroundColor('#FFF2F3F5')
    }
  }

  @Builder
  private buildAdLogo() {
    if (this.adView.hasTextLogo()) {
      Text(this.adView.getTextLogo())
        .fontSize(10)
        .fontColor('#FF8F959E')
        .onClick((event: ClickEvent) => this.adView.onLogoClick(event))
    } else if (this.adView.getImageLogo() !== undefined) {
      Image(this.adView.getImageLogo()!)
        .width(28)
        .height(14)
        .objectFit(ImageFit.Contain)
        .onClick((event: ClickEvent) => this.adView.onLogoClick(event))
    }
  }
}

@Builder
function GromoreAdBuilder(params: Params) {
  GromoreAdComponent({ params: params })
}

export class GromoreAdPlatformView extends PlatformView {
  private readonly kind: AdViewKind;
  private readonly entry: ViewAdEntry | undefined;
  private readonly rootId: string;
  private readonly iconId: string;
  private readonly descriptionId: string;
  private readonly titleId: string;
  private readonly creativeId: string;
  private imageIds: Array<string> = new Array<string>();
  private interactionRegistered: boolean = false;

  constructor(kind: AdViewKind, viewId: number, args: Any, messenger: BinaryMessenger) {
    super();
    this.kind = kind;
    this.entry = this.findEntry(kind, args);
    const idPrefix = `gromore_${kind}_${viewId}_${this.entry?.id ?? 0}`;
    this.rootId = `${idPrefix}_root`;
    this.iconId = `${idPrefix}_icon`;
    this.descriptionId = `${idPrefix}_description`;
    this.titleId = `${idPrefix}_title`;
    this.creativeId = `${idPrefix}_creative`;

    if (this.entry !== undefined) {
      const channelName = this.getChannelName(kind, viewId);
      this.entry.channel = new MethodChannel(messenger, channelName);
      setTimeout(() => {
        this.entry?.channel?.invokeMethod('onAdLoaded', null);
        this.entry?.channel?.invokeMethod('onAdRenderSuccess', null);
        if (kind === 'banner') {
          this.entry?.channel?.invokeMethod('onRenderSuccess', {
            'width': this.readNumber(args, 'width', 0),
            'height': this.readNumber(args, 'height', 0),
          });
        }
      }, 0);
    }
  }

  getView(): WrappedBuilder<[Params]> {
    return new WrappedBuilder(GromoreAdBuilder);
  }

  getNodeController(): NodeController | undefined {
    return this.entry?.getAdComponent();
  }

  isNativeRender(): boolean {
    return this.entry instanceof NativeAdEntry && !this.entry.isExpress;
  }

  isDrawFeed(): boolean {
    return this.kind === 'drawFeed';
  }

  getRootId(): string {
    return this.rootId;
  }

  getIconId(): string {
    return this.iconId;
  }

  getDescriptionId(): string {
    return this.descriptionId;
  }

  getTitleId(): string {
    return this.titleId;
  }

  getCreativeId(): string {
    return this.creativeId;
  }

  getImageId(index: number): string {
    while (this.imageIds.length <= index) {
      this.imageIds.push(`${this.rootId}_image_${this.imageIds.length}`);
    }
    return this.imageIds[index];
  }

  getTitle(): string {
    return this.nativeAd()?.getTitle() ?? '广告';
  }

  getDescription(): string {
    return this.nativeAd()?.getDescription() ?? '';
  }

  getButtonText(): string {
    return this.nativeAd()?.getButtonText() ?? '查看详情';
  }

  getSource(): string {
    return this.nativeAd()?.getSource() ?? '';
  }

  getIconUrl(): string {
    return this.nativeAd()?.getIcon()?.getImageUrl() ?? '';
  }

  getImageUrls(): Array<string> {
    const images = this.nativeAd()?.getImageList();
    if (images === undefined) {
      return new Array<string>();
    }
    const urls = new Array<string>();
    for (let index = 0; index < images.length; index += 1) {
      urls.push(images[index].getImageUrl());
    }
    return urls;
  }

  isVideoAd(): boolean {
    const imageMode = this.nativeAd()?.getImageMode();
    return imageMode === CSJConstant.IMAGE_MODE_VIDEO ||
      imageMode === CSJConstant.IMAGE_MODE_VIDEO_VERTICAL ||
      imageMode === CSJConstant.IMAGE_MODE_SQUARE_VIDEO;
  }

  hasTextLogo(): boolean {
    return typeof this.nativeAd()?.getAdLogo() === 'string';
  }

  getTextLogo(): string {
    const logo = this.nativeAd()?.getAdLogo();
    return typeof logo === 'string' ? logo : '';
  }

  getImageLogo(): Resource | undefined {
    const logo = this.nativeAd()?.getAdLogo();
    return typeof logo === 'string' ? undefined : logo;
  }

  onLogoClick(event: ClickEvent): void {
    this.nativeAd()?.onAdClick(CSJConstant.TYPE_CLICK_LOGO, event);
  }

  showDislike(context: object): void {
    this.nativeAd()?.getDislikeDialog()?.showDislikeDialog(context);
  }

  registerNativeInteraction(uiContext: UIContext): void {
    const ad = this.nativeAd();
    if (ad === undefined || this.interactionRegistered) {
      return;
    }

    // 官方要求自渲染组件 ID 全局唯一，并在布局出现后注册计费区域。
    // https://www.csjplatform.com/supportcenter/28675
    // https://www.csjplatform.com/supportcenter/28677
    this.interactionRegistered = true;
    const clickViewIds = new CSJArrayList<string>();
    clickViewIds.addAdId(this.iconId);
    clickViewIds.addAdId(this.descriptionId);
    const creativeViewIds = new CSJArrayList<string>();
    creativeViewIds.addAdId(this.titleId);
    creativeViewIds.addAdId(this.creativeId);
    this.imageIds.forEach((id: string) => creativeViewIds.addAdId(id));
    ad.registerViewForInteraction(this.rootId, uiContext, clickViewIds, creativeViewIds);
  }

  dispose(): void {
    if (this.entry === undefined) {
      return;
    }

    this.entry.channel = undefined;
    if (this.kind === 'feed') {
      this.entry.destroy();
      GromoreAdStore.feedAds.delete(this.entry.id);
    } else if (this.kind === 'drawFeed') {
      this.entry.destroy();
      GromoreAdStore.drawFeedAds.delete(this.entry.id);
    } else if (GromoreAdStore.bannerAd?.id === this.entry.id) {
      this.entry.destroy();
      GromoreAdStore.bannerAd = undefined;
    }
  }

  private findEntry(kind: AdViewKind, args: Any): ViewAdEntry | undefined {
    if (kind === 'banner') {
      return GromoreAdStore.bannerAd;
    }

    const adId = this.readNumber(args, 'adId', -1);
    return kind === 'feed' ? GromoreAdStore.feedAds.get(adId) : GromoreAdStore.drawFeedAds.get(adId);
  }

  private nativeAd(): CSJNativeAd | undefined {
    return this.entry instanceof NativeAdEntry ? this.entry.ad : undefined;
  }

  private getChannelName(kind: AdViewKind, viewId: number): string {
    if (kind === 'drawFeed') {
      return `gromore_ads_kit_draw_feed_${viewId}`;
    }
    return `gromore_ads_kit_${kind}_${viewId}`;
  }

  private readNumber(args: Any, key: string, fallback: number): number {
    const values: Map<string, Any> = args as Map<string, Any>;
    const value: Any = values.get(key);
    return typeof value === 'number' ? value : fallback;
  }
}

export default class GromoreAdPlatformViewFactory extends PlatformViewFactory {
  private readonly kind: AdViewKind;
  private readonly messenger: BinaryMessenger;

  constructor(kind: AdViewKind, messenger: BinaryMessenger) {
    super(new StandardMessageCodec());
    this.kind = kind;
    this.messenger = messenger;
  }

  create(context: common.Context, viewId: number, args: Any): PlatformView {
    return new GromoreAdPlatformView(this.kind, viewId, args, this.messenger);
  }
}
