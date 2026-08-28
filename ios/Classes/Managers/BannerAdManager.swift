import Foundation
import Flutter
import UIKit
import BUAdSDK

/**
 * Banner广告管理器
 * 负责Banner广告的加载、展示和生命周期管理
 */
class BannerAdManager: NSObject, AdManagerProtocol {

    // 工具类实例
    private let eventHelper: AdEventHelper
    private let validationHelper: AdValidationHelper
    private let logger: AdLogger

    // 当前Banner广告实例
    private var currentBannerAd: BUNativeExpressBannerView?
    private var currentPosId: String = ""
    private var isLoading = false
    private var isLoaded = false
    private var pendingLoadResult: FlutterResult?

    // Banner容器视图
    private var bannerContainerView: UIView?

    override init() {
        self.eventHelper = AdEventHelper.shared
        self.validationHelper = AdValidationHelper.shared
        self.logger = AdLogger.shared
        super.init()
    }

    /**
     * 从MethodCall中提取参数
     */
    private func getArgumentValue<T>(_ call: FlutterMethodCall, key: String, defaultValue: T) -> T {
        if let args = call.arguments as? [String: Any],
           let value = args[key] as? T {
            return value
        }
        return defaultValue
    }

    /**
     * 从MethodCall中提取必需参数
     */
    private func getRequiredArgument<T>(_ call: FlutterMethodCall, key: String) -> T? {
        if let args = call.arguments as? [String: Any] {
            return args[key] as? T
        }
        return nil
    }

    /**
     * 创建Flutter错误
     */
    private func createFlutterError(code: String, message: String, details: Any? = nil) -> FlutterError {
        return FlutterError(code: code, message: message, details: details)
    }

    /**
     * 加载Banner广告
     */
    func load(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let rawPosId: String = getRequiredArgument(call, key: "posId") else {
            result(createFlutterError(code: AdConstants.ErrorCodes.invalidPosId, message: "广告位ID不能为空"))
            return
        }

        let posId = rawPosId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !posId.isEmpty else {
            result(createFlutterError(code: AdConstants.ErrorCodes.invalidPosId, message: "广告位ID不能为空"))
            return
        }

        // 执行基础检查
        if let errorMsg = validationHelper.performBasicChecks(adType: AdConstants.AdType.banner, posId: posId) {
            logger.logAdError(AdConstants.AdType.banner, action: "加载", posId: posId, errorCode: -1, errorMessage: errorMsg)
            result(createFlutterError(code: AdConstants.ErrorCodes.preCheckFailed, message: errorMsg))
            return
        }

        // 防止重复加载
        if isLoading {
            let message = "Banner广告正在加载中，请勿重复调用"
            logger.logAdError(AdConstants.AdType.banner, action: "加载", posId: posId, errorCode: -1, errorMessage: message)
            result(createFlutterError(code: AdConstants.ErrorCodes.alreadyLoading, message: message))
            return
        }

        // 获取广告参数（正确的参数传递策略）
        let args = call.arguments as? [String: Any] ?? [:]

        // ✅ 正确：只在Flutter传递时才使用，否则使用SDK默认值
        // width和height有合理的默认值，因为创建广告视图时必须提供尺寸
        let width = args["width"] as? Int ?? 375
        let height = args["height"] as? Int ?? 60

        // ✅ 正确：可选参数，只在存在时才处理
        let mutedIfCan = args["mutedIfCan"] as? Bool
        let bidNotify = args["bidNotify"] as? Bool
        let scenarioId = args["scenarioId"] as? String
        let enableMixedMode = args["enableMixedMode"] as? Bool
        let extraParams = args["extraParams"] as? [String: Any]

        // 记录参数
        let adSize = CGSize(width: width, height: height)
        currentPosId = posId
        isLoading = true
        isLoaded = false
        pendingLoadResult = nil
        validationHelper.updateRequestTime(posId: posId)

        // 记录请求日志（只记录实际传递的参数）
        var logParams: [String: Any] = [:]

        // 记录尺寸参数（这两个总是有值）
        logParams["width"] = width
        logParams["height"] = height

        // 只记录实际传递的可选参数
        if mutedIfCan != nil { logParams["mutedIfCan"] = mutedIfCan! }
        if bidNotify != nil { logParams["bidNotify"] = bidNotify! }
        if scenarioId != nil { logParams["scenarioId"] = scenarioId! }
        if enableMixedMode != nil { logParams["enableMixedMode"] = enableMixedMode! }
        if extraParams != nil { logParams["extraParams"] = extraParams! }

        logger.logAdRequest(AdConstants.AdType.banner, posId: posId, params: logParams)

        // 发送开始加载事件
        eventHelper.sendBannerEvent(AdConstants.Events.bannerLoadStart, posId: posId, extra: [
            "width": width,
            "height": height
        ])

        // 获取根视图控制器
        guard let rootViewController = getCurrentViewController() else {
            let message = "无法获取根视图控制器"
            logger.logAdError(AdConstants.AdType.banner, action: "加载", posId: posId, errorCode: -1, errorMessage: message)
            isLoading = false
            pendingLoadResult = nil
            result(createFlutterError(code: AdConstants.ErrorCodes.noRootController, message: message))
            return
        }

        // 清理之前的Banner广告
        cleanupBannerAd()

        pendingLoadResult = result

        // 创建Banner广告
        currentBannerAd = BUNativeExpressBannerView(
            slotID: posId,
            rootViewController: rootViewController,
            adSize: adSize
        )

        currentBannerAd?.delegate = self

        // 配置聚合功能参数（使用mediation的addParam方法）
        if let mediation = currentBannerAd?.mediation {

            // ✅ 配置竞价通知（bidNotify）
            if let bidNotifyValue = bidNotify {
                mediation.addParam(bidNotifyValue, withKey: "bidNotify")
                logger.logInfo("Banner配置竞价通知: \(bidNotifyValue)")
            }

            // ✅ 配置场景ID（scenarioId）
            if let scenarioIdValue = scenarioId, !scenarioIdValue.isEmpty {
                mediation.addParam(scenarioIdValue, withKey: "scenarioId")
                logger.logInfo("Banner配置场景ID: \(scenarioIdValue)")
            }

            // ✅ 配置静音（mutedIfCan）
            if let mutedValue = mutedIfCan {
                mediation.addParam(mutedValue, withKey: "mutedIfCan")
                logger.logInfo("Banner配置静音: \(mutedValue)")
            }

            // ✅ 配置混出信息流模式（enableMixedMode）
            if let mixedModeValue = enableMixedMode, mixedModeValue {
                mediation.addParam(mixedModeValue, withKey: "enableMixedMode")
                logger.logInfo("Banner混出信息流模式已启用")
                // iOS端混出功能将通过delegate回调 nativeExpressBannerAdNeedLayoutUI 实现
            }

            // ✅ 配置扩展参数（extraParams）
            if let extraParamsValue = extraParams {
                for (key, value) in extraParamsValue {
                    mediation.addParam(value, withKey: key)
                    logger.logInfo("Banner配置扩展参数: \(key)=\(value)")
                }
            }
        }

       // 开始加载广告
       currentBannerAd?.loadAdData()

       logger.logInfo("Banner广告开始加载：posId=\\(posId), size=\\(adSize)")
    }

    /**
     * 展示Banner广告（支持手动控制显示）
     */
    func show(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard isLoaded, let bannerAd = currentBannerAd else {
            result(createFlutterError(code: AdConstants.ErrorCodes.adNotReady, message: "Banner广告尚未加载完成或已销毁"))
            return
        }

        // 获取根视图控制器
        guard let rootViewController = getCurrentViewController() else {
            result(createFlutterError(code: AdConstants.ErrorCodes.noRootController, message: "无法获取根视图控制器"))
            return
        }

        // 手动添加Banner到界面（用于API方式调用）
        if bannerAd.superview == nil {
            addBannerToApp(bannerAd)
            logger.logAdSuccess(AdConstants.AdType.banner, action: "显示", posId: currentPosId, message: "Banner广告手动显示成功")
        }

        result(true)
    }

    /**
     * 销毁Banner广告
     */
    func destroy(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        logger.logInfo("开始销毁Banner广告：posId=\\(currentPosId)")

        cleanupBannerAd()

        // 发送销毁事件
        eventHelper.sendBannerEvent(AdConstants.Events.bannerDestroyed, posId: currentPosId, extra: nil)
        isLoading = false
        currentPosId = ""
        logger.logInfo("Banner广告已销毁")
        result(true)
    }

    /**
     * 销毁Banner广告（无参数版本，用于协议兼容）
     */
    func destroy() {
        logger.logInfo("开始销毁Banner广告：posId=\(currentPosId)")
        cleanupBannerAd()
        eventHelper.sendBannerEvent(AdConstants.Events.bannerDestroyed, posId: currentPosId, extra: nil)
        isLoading = false
        currentPosId = ""
        logger.logInfo("Banner广告已销毁")
    }

    func isReady() -> Bool {
        return isLoaded && currentBannerAd?.mediation?.isReady == true
    }

    func getAdLoadInfo() -> [[String: Any]] {
        return AdDiagnosticsHelper.map(
            currentBannerAd?.mediation?.getAdLoadInfoList(),
            adType: "banner"
        )
    }

    /**
     * 清理Banner广告资源
     */
    private func cleanupBannerAd() {
        if let bannerAd = currentBannerAd {
            bannerAd.delegate = nil
            bannerAd.removeFromSuperview()
        }

        bannerContainerView?.removeFromSuperview()
        bannerContainerView = nil
        currentBannerAd = nil
        isLoaded = false
        pendingLoadResult = nil
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

    /**
     * 将Banner广告添加到应用界面
     */
    private func addBannerToApp(_ bannerAdView: BUNativeExpressBannerView) {
        guard let rootViewController = getCurrentViewController() else {
            logger.logAdError(AdConstants.AdType.banner, action: "展示", posId: currentPosId, errorCode: -1, errorMessage: "无法获取根视图控制器")
            return
        }

        // 创建容器视图
        bannerContainerView = UIView()
        bannerContainerView?.backgroundColor = UIColor.clear

        // 设置容器视图约束 - 固定在屏幕底部
        bannerContainerView?.translatesAutoresizingMaskIntoConstraints = false
        rootViewController.view.addSubview(bannerContainerView!)

        NSLayoutConstraint.activate([
            bannerContainerView!.leadingAnchor.constraint(equalTo: rootViewController.view.leadingAnchor),
            bannerContainerView!.trailingAnchor.constraint(equalTo: rootViewController.view.trailingAnchor),
            bannerContainerView!.bottomAnchor.constraint(equalTo: rootViewController.view.safeAreaLayoutGuide.bottomAnchor),
            bannerContainerView!.heightAnchor.constraint(equalToConstant: bannerAdView.frame.height)
        ])

        // 将Banner添加到容器中
        bannerContainerView?.addSubview(bannerAdView)
        bannerAdView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            bannerAdView.centerXAnchor.constraint(equalTo: bannerContainerView!.centerXAnchor),
            bannerAdView.centerYAnchor.constraint(equalTo: bannerContainerView!.centerYAnchor),
            bannerAdView.widthAnchor.constraint(equalToConstant: bannerAdView.frame.width),
            bannerAdView.heightAnchor.constraint(equalToConstant: bannerAdView.frame.height)
        ])

        logger.logInfo("Banner广告已添加到应用界面")
    }
}

// MARK: - BUMNativeExpressBannerViewDelegate
extension BannerAdManager: BUMNativeExpressBannerViewDelegate {

    func nativeExpressBannerAdNeedLayoutUI(
        _ bannerAd: BUNativeExpressBannerView,
        canvasView: BUMCanvasView
    ) {
        NativeAdViewConfigurator.configure(canvasView)
        eventHelper.sendBannerEvent(
            AdConstants.Events.bannerMixedLayout,
            posId: currentPosId,
            extra: ["mixedMode": true]
        )
    }

    func nativeExpressBannerAdViewDidLoad(_ bannerAdView: BUNativeExpressBannerView) {
        isLoading = false
        isLoaded = true

        logger.logAdSuccess(AdConstants.AdType.banner, action: "加载", posId: currentPosId, message: "Banner广告加载成功")

        pendingLoadResult?(true)
        pendingLoadResult = nil

        // 发送加载成功事件
        eventHelper.sendBannerEvent(AdConstants.Events.bannerLoaded, posId: currentPosId, extra: nil)

        logger.logInfo("Banner广告加载完成，等待PlatformView处理显示")
    }

    func nativeExpressBannerAdView(_ bannerAdView: BUNativeExpressBannerView, didLoadFailWithError error: Error?) {
        isLoading = false
        isLoaded = false

        let errorMessage = error?.localizedDescription ?? "未知错误"
        let errorCode = (error as NSError?)?.code ?? -1

        logger.logAdError(AdConstants.AdType.banner, action: "加载", posId: currentPosId, errorCode: errorCode, errorMessage: errorMessage)

        // 发送加载失败事件
        eventHelper.sendBannerErrorEvent(AdConstants.Events.bannerLoadFail, message: errorMessage, posId: currentPosId, code: errorCode)

        if let pending = pendingLoadResult {
            pending(createFlutterError(code: AdConstants.ErrorCodes.loadError, message: "Banner广告加载失败: \(errorMessage)", details: errorCode))
            pendingLoadResult = nil
        }

        // 清理资源
        cleanupBannerAd()
    }

    func nativeExpressBannerAdViewRenderSuccess(_ bannerAdView: BUNativeExpressBannerView) {
        logger.logAdSuccess(AdConstants.AdType.banner, action: "渲染", posId: currentPosId, message: "Banner广告渲染成功")

        // 发送渲染成功事件
        eventHelper.sendBannerEvent(AdConstants.Events.bannerRenderSuccess, posId: currentPosId, extra: nil)
    }

    func nativeExpressBannerAdViewRenderFail(_ bannerAdView: BUNativeExpressBannerView, error: Error?) {
        let errorMessage = error?.localizedDescription ?? "渲染失败"
        let errorCode = (error as NSError?)?.code ?? -1

        logger.logAdError(AdConstants.AdType.banner, action: "渲染", posId: currentPosId, errorCode: errorCode, errorMessage: errorMessage)

        // 发送渲染失败事件
        eventHelper.sendBannerErrorEvent(AdConstants.Events.bannerRenderFail, message: errorMessage, posId: currentPosId, code: errorCode)
    }

    func nativeExpressBannerAdViewWillBecomVisible(_ bannerAdView: BUNativeExpressBannerView) {
        logger.logInfo("Banner广告即将展示：posId=\\(currentPosId)")

        // 发送即将展示事件
        eventHelper.sendBannerEvent(AdConstants.Events.bannerWillShow, posId: currentPosId, extra: nil)
    }

    func nativeExpressBannerAdViewDidBecomeVisible(_ bannerAdView: BUNativeExpressBannerView) {
        logger.logAdSuccess(AdConstants.AdType.banner, action: "展示", posId: currentPosId, message: "Banner广告展示成功")

        // 发送展示成功事件
        eventHelper.sendBannerEvent(AdConstants.Events.bannerShowed, posId: currentPosId, extra: nil)

        // 获取ECPM信息
        if let ecpmInfo = bannerAdView.mediation?.getShowEcpmInfo() {
            let ecpmData: [String: Any] = [
                "ecpm": ecpmInfo.ecpm ?? 0,
                "platform": ecpmInfo.adnName ?? "",
                "ritID": ecpmInfo.slotID ?? "",
                "requestID": ecpmInfo.requestID ?? ""
            ]

            eventHelper.sendBannerEvent(AdConstants.Events.bannerEcpm, posId: currentPosId, extra: ecpmData)
            logger.logInfo("Banner ECPM信息：\\(ecpmData)")
        }
    }

    func nativeExpressBannerAdViewDidClick(_ bannerAdView: BUNativeExpressBannerView) {
        logger.logAdSuccess(AdConstants.AdType.banner, action: "点击", posId: currentPosId, message: "Banner广告被点击")

        // 发送点击事件
        eventHelper.sendBannerEvent(AdConstants.Events.bannerClicked, posId: currentPosId, extra: nil)
    }

    func nativeExpressBannerAdView(_ bannerAdView: BUNativeExpressBannerView, dislikeWithReason filterwords: [BUDislikeWords]?) {
        logger.logInfo("Banner广告Dislike：posId=\\(currentPosId)")

        // 发送Dislike事件
        eventHelper.sendBannerEvent(AdConstants.Events.bannerDislike, posId: currentPosId, extra: nil)
    }

    func nativeExpressBannerAdViewDidCloseOtherController(_ bannerAdView: BUNativeExpressBannerView, interactionType: BUInteractionType) {
        logger.logInfo("Banner广告关闭其他控制器：posId=\\(currentPosId)")

        // 发送恢复事件
        eventHelper.sendBannerEvent(AdConstants.Events.bannerResume, posId: currentPosId, extra: nil)
    }

    func nativeExpressBannerAdViewDidRemoved(_ nativeExpressAdView: BUNativeExpressBannerView) {
        logger.logInfo("Banner广告被移除：posId=\\(currentPosId)")

        // 发送关闭事件
        eventHelper.sendBannerEvent(AdConstants.Events.bannerClosed, posId: currentPosId, extra: nil)

        // 清理资源
        cleanupBannerAd()
    }

}
