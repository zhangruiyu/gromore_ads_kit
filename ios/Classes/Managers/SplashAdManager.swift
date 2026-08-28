import Foundation
import Flutter
import UIKit
import BUAdSDK

private enum SplashLogoSource: String {
    case asset, file, resource, bundle
}

private struct SplashLogoConfig: Equatable {
    let source: SplashLogoSource
    let value: String
    let height: Double?
    let heightRatio: Double?
    let backgroundColorHex: String?
}

private struct SplashFallbackConfig: Equatable {
    let adnName: String
    let slotId: String
    let appId: String
    let appKey: String?
}

private struct SplashIOSOptions: Equatable {
    let supportCardView: Bool?
    let supportZoomOutView: Bool?
    let hideSkipButton: Bool?
    let mediaExt: [String: Any]?
    let extraParams: [String: Any]?
    let buttonType: Int?
    let fallback: SplashFallbackConfig?

    static func == (lhs: SplashIOSOptions, rhs: SplashIOSOptions) -> Bool {
        return lhs.supportCardView == rhs.supportCardView &&
            lhs.supportZoomOutView == rhs.supportZoomOutView &&
            lhs.hideSkipButton == rhs.hideSkipButton &&
            NSDictionary(dictionary: lhs.mediaExt ?? [:]).isEqual(to: rhs.mediaExt ?? [:]) &&
            NSDictionary(dictionary: lhs.extraParams ?? [:]).isEqual(to: rhs.extraParams ?? [:]) &&
            lhs.buttonType == rhs.buttonType &&
            lhs.fallback == rhs.fallback
    }
}

/// 开屏广告管理器
class SplashAdManager: NSObject, SimpleAdManagerProtocol {

    private let eventHelper = AdEventHelper.shared
    private let validationHelper = AdValidationHelper.shared
    private let logger = AdLogger.shared
    private weak var flutterRegistrar: FlutterPluginRegistrar?

    private var currentSplashAd: BUSplashAd?
    private var currentPosId: String = ""
    private var currentLogoConfig: SplashLogoConfig?
    private var currentOptions: SplashIOSOptions?

    private var preloadedSplashAd: BUSplashAd?
    private var preloadedPosId: String?
    private var preloadedLogoConfig: SplashLogoConfig?
    private var preloadedOptions: SplashIOSOptions?

    private var isLoading = false
    private var isPreloadMode = false

    private var currentResult: FlutterResult?
    private var currentLoadingLogo: SplashLogoConfig?
    private var currentLoadingOptions: SplashIOSOptions?

    init(registrar: FlutterPluginRegistrar? = nil) {
        self.flutterRegistrar = registrar
        super.init()
    }

    func show(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let posId: String = getRequiredArgument(call, key: "posId"), !posId.isEmpty else {
            result(createFlutterError(code: AdConstants.ErrorCodes.invalidPosId, message: "广告位ID不能为空"))
            return
        }

        if let errorMsg = validationHelper.performBasicChecks(adType: AdConstants.AdType.splash, posId: posId) {
            result(createFlutterError(code: AdConstants.ErrorCodes.loadError, message: errorMsg))
            return
        }

        if isLoading {
            logger.logWarning("开屏广告正在加载中，无法重复请求")
            result(createFlutterError(code: AdConstants.ErrorCodes.frequentRequest, message: "广告正在加载中"))
            return
        }

        let timeout = getOptionalArgumentValue(call, key: "timeout") as? Double
        let preload = getOptionalArgumentValue(call, key: "preload") as? Bool ?? false
        let logoConfig = parseLogoConfig(from: getOptionalArgumentValue(call, key: "logo"))
        let iosOptions = parseIOSOptions(from: getOptionalArgumentValue(call, key: "ios"))

        currentPosId = posId
        currentLogoConfig = logoConfig
        currentOptions = iosOptions

        var logParams: [String: Any] = [:]
        if let timeout = timeout { logParams["timeout"] = timeout }
        if preload { logParams["preload"] = true }
        if let logo = logoConfig {
            logParams["logo"] = [
                "source": logo.source.rawValue,
                "value": logo.value,
                "height": logo.height as Any,
                "heightRatio": logo.heightRatio as Any,
                "background": logo.backgroundColorHex as Any
            ].compactMapValues { $0 }
        }
        logger.logAdRequest(AdConstants.AdType.splash, posId: posId, params: logParams)

        if !preload, let cachedAd = preloadedSplashAd, preloadedPosId == posId,
           preloadedLogoConfig == logoConfig, preloadedOptions == iosOptions {
            showPreloadedSplashAd(result: result)
            return
        }

        loadSplashAd(
            posId: posId,
            timeout: timeout,
            preload: preload,
            logoConfig: logoConfig,
            iosOptions: iosOptions,
            result: result
        )
    }

    func destroy() {
        logger.logInfo("销毁开屏广告管理器")
        currentSplashAd = nil
        currentPosId = ""
        currentLogoConfig = nil
        currentOptions = nil
        clearPreloaded()
        isLoading = false
        isPreloadMode = false
        currentResult = nil
        currentLoadingLogo = nil
        currentLoadingOptions = nil
    }

    func isReady() -> Bool {
        let ad = preloadedSplashAd ?? currentSplashAd
        return ad?.mediation?.isReady == true
    }

    func getAdLoadInfo() -> [[String: Any]] {
        let ad = preloadedSplashAd ?? currentSplashAd
        return AdDiagnosticsHelper.map(
            ad?.mediation?.getAdLoadInfoList(),
            adType: "splash"
        )
    }

    private func loadSplashAd(
        posId: String,
        timeout: Double?,
        preload: Bool,
        logoConfig: SplashLogoConfig?,
        iosOptions: SplashIOSOptions?,
        result: @escaping FlutterResult
    ) {
        isLoading = true
        isPreloadMode = preload
        currentResult = result
        currentLoadingLogo = logoConfig
        currentLoadingOptions = iosOptions

        let splashAd = buildSplashAd(
            posId: posId,
            timeout: timeout,
            logoConfig: logoConfig,
            iosOptions: iosOptions
        )
        splashAd.delegate = self
        splashAd.cardDelegate = self

        currentSplashAd = splashAd
        logger.logManagerState(AdConstants.AdType.splash, posId: posId, state: "开始加载")
        splashAd.loadData()
    }

    private func buildSplashAd(
        posId: String,
        timeout: Double?,
        logoConfig: SplashLogoConfig?,
        iosOptions: SplashIOSOptions?
    ) -> BUSplashAd {
        let slot = BUAdSlot()
        slot.id = posId
        slot.adType = .splash

        if let mediaExt = iosOptions?.mediaExt {
            slot.ext = mediaExt
        }

        if let fallback = iosOptions?.fallback {
            let fallbackData = BUMSplashUserData()
            fallbackData.adnName = fallback.adnName
            fallbackData.rit = fallback.slotId
            fallbackData.appID = fallback.appId
            fallbackData.appKey = fallback.appKey
            slot.mediation.splashUserData = fallbackData
        }

        let splashAd: BUSplashAd
        if let bottomView = buildBottomView(config: logoConfig) {
            splashAd = BUSplashAd(slot: slot, adSize: .zero)
            splashAd.mediation?.customBottomView = bottomView
        } else {
            splashAd = BUSplashAd(slot: slot, adSize: .zero)
        }

        if let timeout = timeout {
            splashAd.tolerateTimeout = timeout
        }

        if let hideSkip = iosOptions?.hideSkipButton {
            splashAd.hideSkipButton = hideSkip
        }

        if let supportCard = iosOptions?.supportCardView {
            splashAd.supportCardView = supportCard
        }

        if iosOptions?.supportZoomOutView != nil {
            logger.logWarning("Ads-CN 7.7 已移除开屏 ZoomOut 接口，supportZoomOutView 已忽略")
        }

        if let buttonType = iosOptions?.buttonType,
           let splashButtonType = BUMSplashButtonType(rawValue: buttonType) {
            splashAd.mediation?.splashButtonType = splashButtonType
        }

        if let extraParams = iosOptions?.extraParams {
            for (key, value) in extraParams {
                splashAd.mediation?.addParam(value, withKey: key)
            }
        }

        return splashAd
    }

    private func buildBottomView(config: SplashLogoConfig?) -> UIView? {
        guard let config = config else { return nil }

        let screenBounds = UIScreen.main.bounds
        let maxHeight = screenBounds.height * 0.25
        let defaultHeight = screenBounds.height * 0.15
        var resolvedHeight: CGFloat = defaultHeight

        if let explicitHeight = config.height {
            resolvedHeight = CGFloat(explicitHeight)
        }
        if let ratio = config.heightRatio {
            resolvedHeight = CGFloat(ratio) * screenBounds.height
        }
        resolvedHeight = CGFloat(min(max(resolvedHeight, 0), maxHeight))
        if resolvedHeight < 1 {
            return nil
        }

        guard let image = loadLogoImage(config: config) else {
            return nil
        }

        let container = UIView(frame: CGRect(x: 0, y: 0, width: screenBounds.width, height: resolvedHeight))
        if let hex = config.backgroundColorHex, let color = color(from: hex) {
            container.backgroundColor = color
        } else {
            container.backgroundColor = UIColor.clear
        }

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            imageView.widthAnchor.constraint(lessThanOrEqualToConstant: screenBounds.width * 0.6),
            imageView.heightAnchor.constraint(lessThanOrEqualToConstant: resolvedHeight - 12)
        ])

        return container
    }

    private func loadLogoImage(config: SplashLogoConfig) -> UIImage? {
        switch config.source {
        case .asset:
            guard let registrar = flutterRegistrar else { return nil }
            let assetKey = registrar.lookupKey(forAsset: config.value)
            return UIImage(named: assetKey) ?? UIImage(contentsOfFile: Bundle.main.path(forResource: assetKey, ofType: nil) ?? "")
        case .file:
            return UIImage(contentsOfFile: config.value)
        case .resource:
            return UIImage(named: config.value)
        case .bundle:
            return UIImage(contentsOfFile: config.value)
        }
    }

    private func showPreloadedSplashAd(result: @escaping FlutterResult) {
        guard let splashAd = preloadedSplashAd else {
            result(createFlutterError(code: AdConstants.ErrorCodes.showError, message: "没有可用的预加载广告"))
            clearPreloaded()
            return
        }

        guard let rootViewController = getCurrentViewController() else {
            result(createFlutterError(code: AdConstants.ErrorCodes.showError, message: "无法获取根视图控制器"))
            clearPreloaded()
            return
        }

        currentSplashAd = splashAd
        currentPosId = preloadedPosId ?? currentPosId
        currentLogoConfig = preloadedLogoConfig
        currentOptions = preloadedOptions

        splashAd.delegate = self
        splashAd.cardDelegate = self
        splashAd.showSplashView(inRootViewController: rootViewController)
        clearPreloaded()
        result(true)
    }

    private func clearPreloaded() {
        preloadedSplashAd = nil
        preloadedPosId = nil
        preloadedLogoConfig = nil
        preloadedOptions = nil
    }

    private func getOptionalArgumentValue(_ call: FlutterMethodCall, key: String) -> Any? {
        guard let args = call.arguments as? [String: Any] else { return nil }
        return args[key]
    }

    private func getRequiredArgument<T>(_ call: FlutterMethodCall, key: String) -> T? {
        guard let args = call.arguments as? [String: Any], let value = args[key] as? T else {
            return nil
        }
        return value
    }

    private func createFlutterError(code: String, message: String, details: Any? = nil) -> FlutterError {
        return FlutterError(code: code, message: message, details: details)
    }

    private func getCurrentViewController() -> UIViewController? {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) {
            return keyWindow.rootViewController
        }
        return UIApplication.shared.keyWindow?.rootViewController
    }

    private func parseLogoConfig(from value: Any?) -> SplashLogoConfig? {
        guard let dict = value as? [String: Any] else { return nil }
        guard let sourceRaw = (dict["source"] as? String)?.lowercased(),
              let source = SplashLogoSource(rawValue: sourceRaw),
              let path = dict["value"] as? String, !path.isEmpty else {
            return nil
        }
        let height = dict["height"] as? Double
        let ratio = dict["heightRatio"] as? Double
        let background = dict["backgroundColor"] as? String
        return SplashLogoConfig(
            source: source,
            value: path,
            height: height,
            heightRatio: ratio,
            backgroundColorHex: background
        )
    }

    private func parseFallback(from value: Any?) -> SplashFallbackConfig? {
        guard let dict = value as? [String: Any] else { return nil }
        guard let adnName = dict["adnName"] as? String,
              let slotId = dict["slotId"] as? String,
              let appId = dict["appId"] as? String else {
            return nil
        }
        let appKey = dict["appKey"] as? String
        return SplashFallbackConfig(adnName: adnName, slotId: slotId, appId: appId, appKey: appKey)
    }

    private func parseIOSOptions(from value: Any?) -> SplashIOSOptions? {
        guard let dict = value as? [String: Any], !dict.isEmpty else { return nil }
        let supportCardView = dict["supportCardView"] as? Bool
        let supportZoomOutView = dict["supportZoomOutView"] as? Bool
        let hideSkip = dict["hideSkipButton"] as? Bool
        let mediaExt = dict["mediaExt"] as? [String: Any]
        let extraParams = dict["extraParams"] as? [String: Any]
        let buttonType = dict["buttonType"] as? Int
        let fallback = parseFallback(from: dict["fallback"])
        return SplashIOSOptions(
            supportCardView: supportCardView,
            supportZoomOutView: supportZoomOutView,
            hideSkipButton: hideSkip,
            mediaExt: mediaExt,
            extraParams: extraParams,
            buttonType: buttonType,
            fallback: fallback
        )
    }

    private func color(from hex: String) -> UIColor? {
        var formatted = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if formatted.hasPrefix("#") {
            formatted.removeFirst()
        }
        guard formatted.count == 6 || formatted.count == 8 else { return nil }
        if formatted.count == 6 {
            formatted = "FF" + formatted
        }
        var value: UInt64 = 0
        Scanner(string: formatted).scanHexInt64(&value)
        let a = CGFloat((value & 0xFF000000) >> 24) / 255.0
        let r = CGFloat((value & 0x00FF0000) >> 16) / 255.0
        let g = CGFloat((value & 0x0000FF00) >> 8) / 255.0
        let b = CGFloat(value & 0x000000FF) / 255.0
        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
}

// MARK: - BUSplashAdDelegate
extension SplashAdManager: BUSplashAdDelegate {
    func splashAdLoadSuccess(_ splashAd: BUSplashAd) {
        isLoading = false
        logger.logAdSuccess(AdConstants.AdType.splash, action: "加载", posId: currentPosId, message: "开屏广告加载成功")
        eventHelper.sendSplashEvent(AdConstants.Events.splashLoaded, posId: currentPosId)

        if isPreloadMode {
            preloadedSplashAd = splashAd
            preloadedPosId = currentPosId
            preloadedLogoConfig = currentLoadingLogo ?? currentLogoConfig
            preloadedOptions = currentLoadingOptions ?? currentOptions
            currentResult?(true)
            currentResult = nil
            currentLoadingLogo = nil
            currentLoadingOptions = nil
            isPreloadMode = false
            return
        }

        guard let rootViewController = getCurrentViewController() else {
            currentResult?(createFlutterError(code: AdConstants.ErrorCodes.showError, message: "无法获取根视图控制器"))
            currentResult = nil
            return
        }

        splashAd.showSplashView(inRootViewController: rootViewController)
        currentResult?(true)
        currentResult = nil
        currentLoadingLogo = nil
        currentLoadingOptions = nil
    }

    func splashAdLoadFail(_ splashAd: BUSplashAd, error: BUAdError?) {
        isLoading = false
        let message = error?.localizedDescription ?? "未知错误"
        let code = error?.code ?? -1
        logger.logAdError(AdConstants.AdType.splash, action: "加载", posId: currentPosId, errorCode: code, errorMessage: message)
        eventHelper.sendErrorEvent(adType: AdConstants.AdType.splash, posId: currentPosId, errorCode: code, errorMessage: message)
        currentResult?(createFlutterError(code: AdConstants.ErrorCodes.loadError, message: "开屏广告加载失败: \(message)", details: code))
        currentResult = nil
        currentLoadingLogo = nil
        currentLoadingOptions = nil
    }

    func splashAdWillShow(_ splashAd: BUSplashAd) {
        logger.logAdEvent(AdConstants.Events.splashShowed, posId: currentPosId)
        eventHelper.sendSplashEvent(AdConstants.Events.splashShowed, posId: currentPosId)
        sendEcpmInfo(from: splashAd.mediation)
    }

    func splashAdDidShow(_ splashAd: BUSplashAd) {
        logger.logAdEvent(AdConstants.Events.splashShowed, posId: currentPosId)
        eventHelper.sendSplashEvent(AdConstants.Events.splashShowed, posId: currentPosId)
    }

    func splashAdDidClick(_ splashAd: BUSplashAd) {
        logger.logAdEvent(AdConstants.Events.splashClicked, posId: currentPosId)
        eventHelper.sendSplashEvent(AdConstants.Events.splashClicked, posId: currentPosId)
    }

    func splashAdDidClose(_ splashAd: BUSplashAd, closeType: BUSplashAdCloseType) {
        logger.logAdEvent(AdConstants.Events.splashClosed, posId: currentPosId)
        eventHelper.sendSplashEvent(
            AdConstants.Events.splashClosed,
            posId: currentPosId,
            extra: ["closeType": closeType.rawValue]
        )
        destroy()
    }

    func splashAdDidShowFailed(_ splashAd: BUSplashAd, error: Error) {
        let nsError = error as NSError
        logger.logAdError(AdConstants.AdType.splash, action: "展示", posId: currentPosId, errorCode: nsError.code, errorMessage: nsError.localizedDescription)
        eventHelper.sendErrorEvent(adType: AdConstants.AdType.splash, posId: currentPosId, errorCode: nsError.code, errorMessage: nsError.localizedDescription)
        destroy()
    }

    func splashAdRenderSuccess(_ splashAd: BUSplashAd) {
        eventHelper.sendSplashEvent(AdConstants.Events.splashRenderSuccess, posId: currentPosId)
    }

    func splashAdRenderFail(_ splashAd: BUSplashAd, error: BUAdError?) {
        let message = error?.localizedDescription ?? "渲染失败"
        let code = error?.code ?? -1
        eventHelper.sendErrorEvent(adType: AdConstants.AdType.splash, posId: currentPosId, errorCode: code, errorMessage: message)
        destroy()
    }

    func splashAdViewControllerDidClose(_ splashAd: BUSplashAd) {
        eventHelper.sendSplashEvent(AdConstants.Events.splashViewControllerClosed, posId: currentPosId)
    }

    func splashDidCloseOtherController(_ splashAd: BUSplashAd, interactionType: BUInteractionType) {
        eventHelper.sendSplashEvent(AdConstants.Events.splashResume, posId: currentPosId)
    }

    func splashVideoAdDidPlayFinish(_ splashAd: BUSplashAd, didFailWithError error: Error?) {
        if let error = error as NSError? {
            logger.logAdError(AdConstants.AdType.splash, action: "视频播放", posId: currentPosId, errorCode: error.code, errorMessage: error.localizedDescription)
        } else {
            eventHelper.sendSplashEvent(AdConstants.Events.splashVideoFinished, posId: currentPosId)
        }
    }

}

// MARK: - BUSplashCardDelegate
extension SplashAdManager: BUSplashCardDelegate {
    func splashCardReady(toShow splashAd: BUSplashAd) {
        eventHelper.sendSplashEvent(AdConstants.Events.splashCardReady, posId: currentPosId)
    }

    func splashCardViewDidClick(_ splashAd: BUSplashAd) {
        eventHelper.sendSplashEvent(AdConstants.Events.splashCardClicked, posId: currentPosId)
    }

    func splashCardViewDidClose(_ splashAd: BUSplashAd) {
        eventHelper.sendSplashEvent(AdConstants.Events.splashCardClosed, posId: currentPosId)
        destroy()
    }
}

private extension SplashAdManager {
    func sendEcpmInfo(from mediation: (any BUSplashAdMediationProtocol)?) {
        guard let info = mediation?.getShowEcpmInfo() else { return }
        var extra: [String: Any] = [:]
        if let ecpm = info.ecpm { extra["ecpm"] = ecpm }
        extra["biddingType"] = info.biddingType.rawValue
        let adnName = info.adnName as String?
        if let adn = adnName, !adn.isEmpty { extra["sdkName"] = adn }
        let customAdn = info.customAdnName as String?
        if let custom = customAdn, !custom.isEmpty { extra["customSdkName"] = custom }
        let slotId = info.slotID as String?
        if let slot = slotId, !slot.isEmpty { extra["slotId"] = slot }
        let levelTag = info.levelTag as String?
        if let level = levelTag, !level.isEmpty { extra["levelTag"] = level }
        let errorMsg = info.errorMsg as String?
        if let msg = errorMsg, !msg.isEmpty { extra["errorMsg"] = msg }
        let requestId = info.requestID as String?
        if let req = requestId, !req.isEmpty { extra["requestId"] = req }
        let creativeId = info.creativeID as String?
        if let creative = creativeId, !creative.isEmpty { extra["creativeId"] = creative }
        let ritType = info.adRitType as String?
        if let rit = ritType, !rit.isEmpty { extra["ritType"] = rit }
        if let segment = info.segmentId { extra["segmentId"] = segment }
        if let abTest = info.abtestId { extra["abTestId"] = abTest }
        let channel = info.channel as String?
        if let ch = channel, !ch.isEmpty { extra["channel"] = ch }
        let subChannel = info.sub_channel as String?
        if let sub = subChannel, !sub.isEmpty { extra["subChannel"] = sub }
        let scenario = info.scenarioId as String?
        if let s = scenario, !s.isEmpty { extra["scenarioId"] = s }
        let subType = info.subRitType as String?
        if let t = subType, !t.isEmpty { extra["subRitType"] = t }
        if !extra.isEmpty {
            eventHelper.sendSplashEvent(AdConstants.Events.splashEcpm, posId: currentPosId, extra: extra)
        }
    }
}
