import Flutter
import UIKit
import BUAdSDK

/// Feed广告原生视图工厂
class GromoreAdsKitFeedViewFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger
    private let feedAdManager: FeedAdManager
    private let eventHelper: AdEventHelper
    private let logger: AdLogger

    init(messenger: FlutterBinaryMessenger,
         feedAdManager: FeedAdManager,
         eventHelper: AdEventHelper,
         logger: AdLogger) {
        self.messenger = messenger
        self.feedAdManager = feedAdManager
        self.eventHelper = eventHelper
        self.logger = logger
        super.init()
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        return GromoreAdsKitFeedView(
            frame: frame,
            viewId: viewId,
            arguments: args,
            messenger: messenger,
            feedAdManager: feedAdManager,
            eventHelper: eventHelper,
            logger: logger
        )
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }
}

/// Feed广告原生视图
class GromoreAdsKitFeedView: NSObject, FlutterPlatformView, BUNativeExpressAdViewDelegate {
    private let containerView: UIView
    private let methodChannel: FlutterMethodChannel
    private let feedAdManager: FeedAdManager
    private let eventHelper: AdEventHelper
    private let logger: AdLogger

    private let requestedPosId: String
    private let adId: Int

    private var expressAdView: BUNativeExpressAdView?
    private var actualPosId: String

    init(frame: CGRect,
         viewId: Int64,
         arguments args: Any?,
         messenger: FlutterBinaryMessenger,
         feedAdManager: FeedAdManager,
         eventHelper: AdEventHelper,
         logger: AdLogger) {
        self.containerView = UIView(frame: frame)
        self.methodChannel = FlutterMethodChannel(name: "gromore_ads_kit_feed_\(viewId)", binaryMessenger: messenger)
        self.feedAdManager = feedAdManager
        self.eventHelper = eventHelper
        self.logger = logger

        let params = args as? [String: Any] ?? [:]
        self.requestedPosId = params["posId"] as? String ?? ""
        self.adId = params["adId"] as? Int ?? -1
        self.actualPosId = self.requestedPosId

        super.init()

        containerView.backgroundColor = .clear
        methodChannel.setMethodCallHandler(handleMethodCall)
        bindAd()
    }

    func view() -> UIView {
        return containerView
    }

    deinit {
        methodChannel.setMethodCallHandler(nil)
        updateAdViewDelegate(expressAdView, delegate: nil)
        if expressAdView != nil {
            eventHelper.sendCloseEvent(AdConstants.AdType.feed, posId: actualPosId, extra: ["adId": adId, "reason": "dispose"])
        }
    }

    private func handleMethodCall(_ call: FlutterMethodCall, result: FlutterResult) {
        switch call.method {
        case "refresh":
            if let view = expressAdView {
                _ = NativeAdViewConfigurator.configure(view)
                view.render()
                result(true)
            } else {
                result(FlutterError(code: "NO_AD", message: "Feed ad not available", details: nil))
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func bindAd() {
        guard !requestedPosId.isEmpty, adId >= 0 else {
            methodChannel.invokeMethod("onAdError", arguments: "广告参数无效")
            logger.logAdError(AdConstants.AdType.feed, action: "Bind", posId: requestedPosId, errorCode: -1, errorMessage: "参数无效 posId=\(requestedPosId) adId=\(adId)")
            return
        }

        guard let payload = feedAdManager.takeFeedAd(adId: adId) else {
            methodChannel.invokeMethod("onAdError", arguments: "信息流广告不存在或已被使用")
            logger.logAdError(AdConstants.AdType.feed, action: "Bind", posId: requestedPosId, errorCode: -1, errorMessage: "广告不存在或已被移除 adId=\(adId)")
            return
        }

        expressAdView = payload.view
        actualPosId = payload.posId
        updateAdViewDelegate(payload.view, delegate: self)
        payload.view.rootViewController = topViewController()

        methodChannel.invokeMethod("onAdLoaded", arguments: nil)
        logger.logAdSuccess(AdConstants.AdType.feed, action: "Bind", posId: actualPosId, message: "adId=\(adId)")

        attachAdView(payload.view)
        _ = NativeAdViewConfigurator.configure(payload.view)
        payload.view.render()
    }

    private func attachAdView(_ adView: BUNativeExpressAdView) {
        adView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(adView)
        NSLayoutConstraint.activate([
            adView.topAnchor.constraint(equalTo: containerView.topAnchor),
            adView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            adView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            adView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        containerView.layoutIfNeeded()
    }

    private func topViewController() -> UIViewController? {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }),
           let rootVC = keyWindow.rootViewController {
            var current = rootVC
            while let presented = current.presentedViewController {
                current = presented
            }
            return current
        }
        return nil
    }

    // MARK: - BUNativeExpressAdViewDelegate

    func nativeExpressAdViewRenderSuccess(_ nativeExpressAdView: BUNativeExpressAdView) {
        methodChannel.invokeMethod("onAdRenderSuccess", arguments: nil)
    }

    func nativeExpressAdViewRenderFail(_ nativeExpressAdView: BUNativeExpressAdView, error: Error?) {
        let message = error?.localizedDescription ?? "render fail"
        methodChannel.invokeMethod("onAdRenderFail", arguments: message)
        eventHelper.sendErrorEvent(adType: AdConstants.AdType.feed, posId: actualPosId, errorCode: (error as NSError?)?.code ?? -1, errorMessage: message)
    }

    func nativeExpressAdViewDidClick(_ nativeExpressAdView: BUNativeExpressAdView) {
        methodChannel.invokeMethod("onAdClicked", arguments: nil)
        eventHelper.sendClickEvent(AdConstants.AdType.feed, posId: actualPosId, extra: ["adId": adId])
    }

    func nativeExpressAdViewWillShow(_ nativeExpressAdView: BUNativeExpressAdView) {
        eventHelper.sendShowEvent(AdConstants.AdType.feed, posId: actualPosId, extra: ["adId": adId])
    }

    func nativeExpressAdViewDidClosed(_ nativeExpressAdView: BUNativeExpressAdView) {
        methodChannel.invokeMethod("onAdClosed", arguments: nil)
        eventHelper.sendCloseEvent(AdConstants.AdType.feed, posId: actualPosId, extra: ["adId": adId, "reason": "closed"])
    }

    func nativeExpressAdView(_ nativeExpressAdView: BUNativeExpressAdView, dislikeWithReason filterWords: [BUDislikeWords]?) {
        methodChannel.invokeMethod("onAdClosed", arguments: nil)
        eventHelper.sendCloseEvent(AdConstants.AdType.feed, posId: actualPosId, extra: ["adId": adId, "reason": "dislike"])
    }

    func dispose() {
        methodChannel.setMethodCallHandler(nil)
        updateAdViewDelegate(expressAdView, delegate: nil)
        expressAdView?.removeFromSuperview()
        expressAdView = nil
    }

    private func updateAdViewDelegate(_ adView: BUNativeExpressAdView?, delegate: BUNativeExpressAdViewDelegate?) {
        guard let adView else { return }
        let selector = NSSelectorFromString("setDelegate:")
        if adView.responds(to: selector) {
            adView.perform(selector, with: delegate)
        } else if delegate != nil {
            logger.logWarning("BUNativeExpressAdView 不支持设置 delegate，posId=\(actualPosId), adId=\(adId)，事件回调将通过管理器处理")
        }
    }
}
