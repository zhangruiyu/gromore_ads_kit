import Flutter
import UIKit
import BUAdSDK

/// Banner广告原生视图工厂
class GromoreAdsKitBannerViewFactory: NSObject, FlutterPlatformViewFactory {
    private var messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return GromoreAdsKitBannerView(
            frame: frame,
            viewId: viewId,
            arguments: args,
            binaryMessenger: messenger)
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

/// Banner广告原生视图
class GromoreAdsKitBannerView: NSObject, FlutterPlatformView {
    private var _view: UIView
    private var methodChannel: FlutterMethodChannel
    private var bannerAd: BUNativeExpressBannerView?

    private let posId: String
    private let width: CGFloat
    private let height: CGFloat
    private let enableMixedMode: Bool
    private let options: [String: Any]

    init(
        frame: CGRect,
        viewId: Int64,
        arguments args: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger?
    ) {
        _view = UIView()
        methodChannel = FlutterMethodChannel(name: "gromore_ads_kit_banner_\(viewId)", binaryMessenger: messenger!)

        // 解析参数
        let params = args as? [String: Any] ?? [:]
        options = params
        posId = params["posId"] as? String ?? ""
        width = CGFloat(params["width"] as? Int ?? 375)
        height = CGFloat(params["height"] as? Int ?? 60)
        enableMixedMode = params["enableMixedMode"] as? Bool ?? false

        super.init()

        // 设置视图大小
        _view.frame = CGRect(x: 0, y: 0, width: width, height: height)
        _view.backgroundColor = UIColor.lightGray

        // 设置方法处理器
        methodChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            self?.handle(call, result: result)
        }

        NSLog("GromoreAdsKitBanner 创建Banner视图: posId=\(posId), size=\(width)x\(height)")
        createBannerAd()
    }

    func view() -> UIView {
        return _view
    }

    private func createBannerAd() {
        guard !posId.isEmpty else {
            NSLog("GromoreAdsKitBanner Banner广告位ID为空")
            sendCallback(method: "onAdError", arguments: "广告位ID为空")
            return
        }

        // 获取当前视图控制器
        guard let rootVC = getCurrentViewController() else {
            NSLog("GromoreAdsKitBanner 无法获取根视图控制器")
            sendCallback(method: "onAdError", arguments: "无法获取根视图控制器")
            return
        }

        // 创建Banner广告视图
        bannerAd = BUNativeExpressBannerView(
            slotID: posId,
            rootViewController: rootVC,
            adSize: CGSize(width: width, height: height)
        )
        bannerAd?.delegate = self
        if let mediation = bannerAd?.mediation {
            if let muted = options["mutedIfCan"] as? Bool {
                mediation.addParam(NSNumber(value: muted), withKey: "mutedIfCan")
            }
            if let bidNotify = options["bidNotify"] as? Bool {
                mediation.addParam(NSNumber(value: bidNotify), withKey: "bidNotify")
            }
            if let scenarioId = options["scenarioId"] as? String, !scenarioId.isEmpty {
                mediation.addParam(scenarioId, withKey: "scenarioId")
            }
            if enableMixedMode {
                mediation.addParam(NSNumber(value: true), withKey: "enableMixedMode")
            }
            if let extraParams = options["extraParams"] as? [String: Any] {
                for (key, value) in extraParams {
                    mediation.addParam(value, withKey: key)
                }
            }
        }

        // 开始加载广告数据（不立即添加到视图）
        bannerAd?.loadAdData()
        NSLog("GromoreAdsKitBanner 开始加载Banner广告: posId=\(posId), size=\(width)x\(height)")
    }

    private func sendCallback(method: String, arguments: Any?) {
        DispatchQueue.main.async { [weak self] in
            self?.methodChannel.invokeMethod(method, arguments: arguments)
        }
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "refresh":
            NSLog("GromoreAdsKitBanner 刷新Banner广告")
            refreshAd()
            result(true)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func refreshAd() {
        bannerAd?.removeFromSuperview()
        bannerAd = nil
        createBannerAd()
    }

    /**
     * 获取当前顶级视图控制器
     */
    private func getCurrentViewController() -> UIViewController? {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) {
            return keyWindow.rootViewController
        }
        return nil
    }

    deinit {
        NSLog("GromoreAdsKitBanner Banner视图销毁")
        bannerAd?.removeFromSuperview()
        bannerAd = nil
        methodChannel.setMethodCallHandler(nil)
    }
}

// MARK: - BUNativeExpressBannerViewDelegate
extension GromoreAdsKitBannerView: BUMNativeExpressBannerViewDelegate {

    func nativeExpressBannerAdNeedLayoutUI(
        _ bannerAd: BUNativeExpressBannerView,
        canvasView: BUMCanvasView
    ) {
        NativeAdViewConfigurator.configure(canvasView)
        sendCallback(method: "onMixedLayout", arguments: nil)
    }

    func nativeExpressBannerAdViewDidLoad(_ bannerAdView: BUNativeExpressBannerView) {
        NSLog("GromoreAdsKitBanner Banner广告加载成功")

        // 设置Banner的frame并添加到父视图（官方文档推荐在此回调中添加）
        bannerAdView.frame = CGRect(x: 0, y: 0, width: width, height: height)
        _view.addSubview(bannerAdView)

        // 发送加载成功回调
        sendCallback(method: "onAdLoaded", arguments: nil)
        NSLog("GromoreAdsKitBanner Banner广告已添加到视图: frame=\(bannerAdView.frame)")
    }

    func nativeExpressBannerAdView(_ bannerAdView: BUNativeExpressBannerView, didLoadFailWithError error: Error?) {
        NSLog("GromoreAdsKitBanner Banner广告加载失败: \(error?.localizedDescription ?? "Unknown error")")
        sendCallback(method: "onAdError", arguments: "Banner广告加载失败: \(error?.localizedDescription ?? "Unknown error")")
    }

    func nativeExpressBannerAdViewRenderSuccess(_ bannerAdView: BUNativeExpressBannerView) {
        NSLog("GromoreAdsKitBanner Banner广告渲染成功")
        sendCallback(method: "onAdRenderSuccess", arguments: nil)
    }

    func nativeExpressBannerAdViewRenderFail(_ bannerAdView: BUNativeExpressBannerView, error: Error?) {
        NSLog("GromoreAdsKitBanner Banner广告渲染失败: \(error?.localizedDescription ?? "Unknown error")")
        sendCallback(method: "onAdRenderFail", arguments: "Banner广告渲染失败: \(error?.localizedDescription ?? "Unknown error")")
    }

    func nativeExpressBannerAdViewWillBecomVisible(_ bannerAdView: BUNativeExpressBannerView) {
        NSLog("GromoreAdsKitBanner Banner广告即将展示")
        sendCallback(method: "onAdWillShow", arguments: nil)
    }

    func nativeExpressBannerAdViewDidBecomeVisible(_ bannerAdView: BUNativeExpressBannerView) {
        NSLog("GromoreAdsKitBanner Banner广告显示")
        sendCallback(method: "onAdShowed", arguments: nil)

        // 获取ECPM信息（官方文档要求在展示后调用）
        if let ecpmInfo = bannerAdView.mediation?.getShowEcpmInfo() {
            let ecpmData: [String: Any] = [
                "ecpm": ecpmInfo.ecpm ?? 0,
                "platform": ecpmInfo.adnName ?? "",
                "ritID": ecpmInfo.slotID ?? "",
                "requestID": ecpmInfo.requestID ?? ""
            ]
            NSLog("GromoreAdsKitBanner Banner ECPM信息：\\(ecpmData)")
            sendCallback(method: "onEcpm", arguments: ecpmData)
        }
    }

    func nativeExpressBannerAdViewDidClick(_ bannerAdView: BUNativeExpressBannerView) {
        NSLog("GromoreAdsKitBanner Banner广告被点击")
        sendCallback(method: "onAdClicked", arguments: nil)
    }

    func nativeExpressBannerAdView(_ bannerAdView: BUNativeExpressBannerView, dislikeWithReason filterwords: [BUDislikeWords]?) {
        NSLog("GromoreAdsKitBanner Banner广告被关闭")
        sendCallback(method: "onAdClosed", arguments: nil)
        bannerAdView.removeFromSuperview()
    }

    func nativeExpressBannerAdViewDidCloseOtherController(_ bannerAdView: BUNativeExpressBannerView, interactionType: BUInteractionType) {
        NSLog("GromoreAdsKitBanner Banner广告关闭其他控制器")
        sendCallback(method: "onAdResume", arguments: nil)
    }

    func nativeExpressBannerAdViewDidRemoved(_ bannerAdView: BUNativeExpressBannerView) {
        NSLog("GromoreAdsKitBanner Banner广告被移除")
        sendCallback(method: "onAdClosed", arguments: nil)
    }
}
