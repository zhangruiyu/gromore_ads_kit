import Foundation
import Flutter
import UIKit
import BUAdSDK

/**
 * 插屏广告管理器
 * 负责插屏广告的加载、展示和生命周期管理
 */
class InterstitialAdManager: NSObject, AdManagerProtocol {

    // 工具类实例
    private let eventHelper: AdEventHelper
    private let validationHelper: AdValidationHelper
    private let logger: AdLogger

    // 当前插屏广告实例
    private var currentInterstitialAd: BUNativeExpressFullscreenVideoAd?
    private var currentPosId: String = ""
    private var isLoading = false
    private var isLoaded = false

    override init() {
        self.eventHelper = AdEventHelper.shared
        self.validationHelper = AdValidationHelper.shared
        self.logger = AdLogger.shared
        super.init()
    }

    /**
     * 加载插屏广告
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
        if let errorMsg = validationHelper.performBasicChecks(adType: AdConstants.AdType.interstitial, posId: posId) {
            result(createFlutterError(code: AdConstants.ErrorCodes.loadError, message: errorMsg))
            return
        }

        // 检查是否正在加载
        if isLoading {
            logger.logWarning("插屏广告正在加载中，无法重复请求")
            result(createFlutterError(code: AdConstants.ErrorCodes.frequentRequest, message: "广告正在加载中"))
            return
        }

        // 更新请求时间
        validationHelper.updateRequestTime(posId: posId)

        // 记录请求日志 - 只记录实际传递的参数
        var requestParams: [String: Any] = [:]
        if let orientation = (call.arguments as? [String: Any])?["orientation"] as? Int {
            requestParams["orientation"] = orientation
        }
        if let mutedIfCan = (call.arguments as? [String: Any])?["mutedIfCan"] as? Bool {
            requestParams["mutedIfCan"] = mutedIfCan
        }
        if let bidNotify = (call.arguments as? [String: Any])?["bidNotify"] as? Bool {
            requestParams["bidNotify"] = bidNotify
        }
        if let scenarioId = (call.arguments as? [String: Any])?["scenarioId"] as? String {
            requestParams["scenarioId"] = scenarioId
        }
        if let showDirection = (call.arguments as? [String: Any])?["showDirection"] as? Int {
            requestParams["showDirection"] = showDirection
        }
        if let customData = (call.arguments as? [String: Any])?["customData"] {
            requestParams["customData"] = customData
        }
        if let extraParams = (call.arguments as? [String: Any])?["extraParams"] as? [String: Any], !extraParams.isEmpty {
            requestParams["extraParams"] = extraParams
        }
        logger.logAdRequest(AdConstants.AdType.interstitial, posId: posId, params: requestParams)

        // 开始加载插屏广告
        isLoading = true
        isLoaded = false
        currentPosId = posId
        currentLoadResult = result
        loadInterstitialAd(posId: posId, call: call)
    }

    /**
     * 展示插屏广告
     */
    func show(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let rawPosId: String = getRequiredArgument(call, key: "posId") else {
            result(createFlutterError(code: AdConstants.ErrorCodes.invalidPosId, message: "广告位ID不能为空"))
            return
        }

        let posId = rawPosId.trimmingCharacters(in: .whitespacesAndNewlines)
        let loadedPosId = currentPosId

        if loadedPosId.isEmpty {
            logger.logAdError(AdConstants.AdType.interstitial, action: "展示", posId: posId, errorCode: -1, errorMessage: "广告未加载")
            result(createFlutterError(code: AdConstants.ErrorCodes.adNotLoaded, message: "插屏广告未加载，请先调用loadInterstitialAd"))
            return
        }

        if !posId.isEmpty && posId != loadedPosId {
            logger.logAdError(AdConstants.AdType.interstitial, action: "展示", posId: loadedPosId, errorCode: -1, errorMessage: "广告位不匹配")
            result(createFlutterError(code: AdConstants.ErrorCodes.invalidOperation, message: "插屏广告与传入的广告位不一致，请重新加载"))
            return
        }

        // 检查广告是否已加载
        if !isLoaded || currentInterstitialAd == nil {
            logger.logAdError(AdConstants.AdType.interstitial, action: "展示", posId: posId, errorCode: -1, errorMessage: "广告未加载")
            result(createFlutterError(code: AdConstants.ErrorCodes.adNotLoaded, message: "插屏广告未加载，请先调用loadInterstitialAd"))
            return
        }

        // 检查广告是否准备就绪（聚合维度功能）
        if let mediation = currentInterstitialAd?.mediation, !mediation.isReady {
            logger.logAdError(AdConstants.AdType.interstitial, action: "展示", posId: loadedPosId, errorCode: -1, errorMessage: "广告未准备就绪")
            result(createFlutterError(code: AdConstants.ErrorCodes.adNotReady, message: "插屏广告未准备就绪，请稍后再试"))
            return
        }

        // 获取当前视图控制器
        guard let rootViewController = getCurrentViewController() else {
            logger.logAdError(AdConstants.AdType.interstitial, action: "展示", posId: loadedPosId, errorCode: -1, errorMessage: "无法获取根视图控制器")
            result(createFlutterError(code: AdConstants.ErrorCodes.showError, message: "无法获取根视图控制器"))
            return
        }

        logger.logAdRequest(AdConstants.AdType.interstitial, posId: loadedPosId, params: ["action": "show"])

        // 展示插屏广告
        let success = currentInterstitialAd?.show(fromRootViewController: rootViewController) ?? false
        if !success {
            logger.logAdError(AdConstants.AdType.interstitial, action: "展示", posId: loadedPosId, errorCode: -1, errorMessage: "广告展示调用失败")
            result(createFlutterError(code: AdConstants.ErrorCodes.showError, message: "插屏广告展示失败"))
            return
        }

        isLoaded = false
        result(true)
    }

    /**
     * 加载插屏广告
     */
    private func loadInterstitialAd(posId: String, call: FlutterMethodCall) {
        // 创建广告位配置
        let slot = BUAdSlot()
        slot.id = posId

        // ⚠️ 重要：只有Flutter API明确传递的参数才调用原生配置方法
        // 不传递的参数让SDK使用原生默认值，避免"自以为是"的默认值设置

        // 静音设置（只有明确传递了参数才设置）
        if hasArgument(call, key: "mutedIfCan") {
            let mutedIfCan = getArgumentValue(call, key: "mutedIfCan", defaultValue: false)
            slot.mediation.mutedIfCan = mutedIfCan
        }

        // 创建插屏广告实例
        let interstitialAd = BUNativeExpressFullscreenVideoAd(slot: slot)
        interstitialAd.delegate = self

        // 设置聚合参数（只有明确传递了参数才设置）
        if let mediation = interstitialAd.mediation {
            // 显示方向设置（支持两种参数名：showDirection优先，其次orientation）
            var directionValue: Int? = nil
            if hasArgument(call, key: "showDirection") {
                directionValue = getArgumentValue(call, key: "showDirection", defaultValue: 0)
            } else if hasArgument(call, key: "orientation") {
                // 将Flutter的orientation值转换为iOS的显示方向值
                let orientation = getArgumentValue(call, key: "orientation", defaultValue: 1)
                // vertical(1) -> 0, horizontal(2) -> 1
                directionValue = orientation == 2 ? 1 : 0
            }

            if let direction = directionValue {
                mediation.addParam(NSNumber(value: direction), withKey: "show_direction")
            }

            // 奖励验证设置（只有明确传递了参数才设置）
            if hasArgument(call, key: "rewardName") && hasArgument(call, key: "rewardAmount") {
                let rewardName = getArgumentValue(call, key: "rewardName", defaultValue: "")
                let rewardAmount = getArgumentValue(call, key: "rewardAmount", defaultValue: 0)

                if !rewardName.isEmpty && rewardAmount > 0 {
                    let rewardModel = BURewardedVideoModel()
                    rewardModel.rewardName = rewardName
                    rewardModel.rewardAmount = rewardAmount

                    // 添加自定义数据（如果有的话）
                    if hasArgument(call, key: "customData") {
                        let customData = getArgumentValue(call, key: "customData", defaultValue: "")
                        if !customData.isEmpty {
                            rewardModel.extra = customData
                        }
                    }

                    mediation.rewardModel = rewardModel
                }
            }

            // 其他额外参数（如果有的话）
            if hasArgument(call, key: "extraParams") {
                if let extraParams = call.arguments as? [String: Any],
                   let params = extraParams["extraParams"] as? [String: Any] {
                    for (key, value) in params {
                        mediation.addParam(value, withKey: key)
                    }
                }
            }
        }

        currentInterstitialAd = interstitialAd

        logger.logManagerState(AdConstants.AdType.interstitial, posId: posId, state: "开始加载")

        // 加载广告数据
        interstitialAd.loadData()
    }

    /**
     * 销毁广告
     */
    func destroy() {
        logger.logInfo("销毁插屏广告管理器")
        currentInterstitialAd?.delegate = nil
        currentInterstitialAd = nil
        currentPosId = ""
        isLoading = false
        isLoaded = false
        currentLoadResult = nil
    }

    func isReady() -> Bool {
        return isLoaded && currentInterstitialAd?.mediation?.isReady == true
    }

    func getAdLoadInfo() -> [[String: Any]] {
        return AdDiagnosticsHelper.map(
            currentInterstitialAd?.mediation?.getAdLoadInfoList(),
            adType: "interstitial"
        )
    }

    // MARK: - 私有属性

    // 用于存储加载结果回调
    private var currentLoadResult: FlutterResult?

    // MARK: - 辅助方法

    private func hasArgument(_ call: FlutterMethodCall, key: String) -> Bool {
        guard let args = call.arguments as? [String: Any] else { return false }
        return args[key] != nil
    }

    private func getArgumentValue<T>(_ call: FlutterMethodCall, key: String, defaultValue: T) -> T {
        if let args = call.arguments as? [String: Any],
           let value = args[key] as? T {
            return value
        }
        return defaultValue
    }

    private func getRequiredArgument<T>(_ call: FlutterMethodCall, key: String) -> T? {
        if let args = call.arguments as? [String: Any] {
            return args[key] as? T
        }
        return nil
    }

    private func createFlutterError(code: String, message: String, details: Any? = nil) -> FlutterError {
        return FlutterError(code: code, message: message, details: details)
    }

    private func getCurrentViewController() -> UIViewController? {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) {
            return keyWindow.rootViewController
        }
        return nil
    }
}

// MARK: - BUNativeExpressFullscreenVideoAdDelegate

extension InterstitialAdManager: BUNativeExpressFullscreenVideoAdDelegate {

    /**
     * 插屏广告加载成功
     */
    func nativeExpressFullscreenVideoAdDidLoad(_ fullscreenVideoAd: BUNativeExpressFullscreenVideoAd) {
        isLoading = false
        isLoaded = true

        logger.logAdSuccess(AdConstants.AdType.interstitial, action: "加载", posId: currentPosId, message: "插屏广告加载成功")
        eventHelper.sendInterstitialEvent(AdConstants.Events.interstitialLoaded, posId: currentPosId)

        // 通知Flutter加载成功
        if let result = currentLoadResult {
            result(true)
            currentLoadResult = nil
        }
    }

    /**
     * 插屏广告加载失败
     */
    func nativeExpressFullscreenVideoAd(_ fullscreenVideoAd: BUNativeExpressFullscreenVideoAd, didFailWithError error: Error?) {
        isLoading = false
        isLoaded = false

        let errorMessage = error?.localizedDescription ?? "未知错误"
        let errorCode = (error as NSError?)?.code ?? -1

        logger.logAdError(AdConstants.AdType.interstitial, action: "加载", posId: currentPosId, errorCode: errorCode, errorMessage: errorMessage)
        eventHelper.sendErrorEvent(adType: AdConstants.AdType.interstitial, posId: currentPosId, errorCode: errorCode, errorMessage: errorMessage)
        currentInterstitialAd = nil

        // 通知Flutter加载失败
        if let result = currentLoadResult {
            result(createFlutterError(code: AdConstants.ErrorCodes.loadError, message: "插屏广告加载失败: \(errorMessage)", details: errorCode))
            currentLoadResult = nil
        }
    }

    /**
     * 插屏广告渲染成功
     */
    func nativeExpressFullscreenVideoAdViewRenderSuccess(_ fullscreenVideoAd: BUNativeExpressFullscreenVideoAd) {
        logger.logAdEvent(AdConstants.Events.interstitialRenderSuccess, posId: currentPosId)
        eventHelper.sendInterstitialEvent(AdConstants.Events.interstitialRenderSuccess, posId: currentPosId)
    }

    /**
     * 插屏广告渲染失败
     */
    func nativeExpressFullscreenVideoAdViewRenderFail(_ fullscreenVideoAd: BUNativeExpressFullscreenVideoAd, error: Error?) {
        let errorMessage = error?.localizedDescription ?? "未知错误"
        let errorCode = (error as NSError?)?.code ?? -1

        logger.logAdError(AdConstants.AdType.interstitial, action: "渲染", posId: currentPosId, errorCode: errorCode, errorMessage: errorMessage)
        eventHelper.sendErrorEvent(adType: AdConstants.AdType.interstitial, posId: currentPosId, errorCode: errorCode, errorMessage: "渲染失败: \(errorMessage)")
    }

    /**
     * 插屏广告展示
     */
    func nativeExpressFullscreenVideoAdWillVisible(_ fullscreenVideoAd: BUNativeExpressFullscreenVideoAd) {
        logger.logAdEvent(AdConstants.Events.interstitialShowed, posId: currentPosId)
        eventHelper.sendInterstitialEvent(AdConstants.Events.interstitialShowed, posId: currentPosId)
    }

    /**
     * 插屏广告点击
     */
    func nativeExpressFullscreenVideoAdDidClick(_ fullscreenVideoAd: BUNativeExpressFullscreenVideoAd) {
        logger.logAdEvent(AdConstants.Events.interstitialClicked, posId: currentPosId)
        eventHelper.sendInterstitialEvent(AdConstants.Events.interstitialClicked, posId: currentPosId)
    }

    /**
     * 插屏广告关闭
     */
    func nativeExpressFullscreenVideoAdDidClose(_ fullscreenVideoAd: BUNativeExpressFullscreenVideoAd) {
        logger.logAdEvent(AdConstants.Events.interstitialClosed, posId: currentPosId)
        eventHelper.sendInterstitialEvent(AdConstants.Events.interstitialClosed, posId: currentPosId)

        // 重置加载状态，需要重新加载
        destroy()
    }

    /**
     * 插屏广告播放完成
     */
    func nativeExpressFullscreenVideoAdDidPlayFinish(_ fullscreenVideoAd: BUNativeExpressFullscreenVideoAd, didFailWithError error: Error?) {
        if let error = error {
            let errorMessage = error.localizedDescription
            logger.logAdError(AdConstants.AdType.interstitial, action: "播放", posId: currentPosId, errorCode: (error as NSError).code, errorMessage: errorMessage)
        } else {
            logger.logAdEvent(AdConstants.Events.interstitialCompleted, posId: currentPosId)
            eventHelper.sendInterstitialEvent(AdConstants.Events.interstitialCompleted, posId: currentPosId)
        }
    }

    /**
     * 插屏广告视频下载成功（主要针对纯CSJ广告）
     */
    func nativeExpressFullscreenVideoAdDidDownLoadVideo(_ fullscreenVideoAd: BUNativeExpressFullscreenVideoAd) {
        logger.logAdEvent(AdConstants.Events.interstitialVideoDownloaded, posId: currentPosId)
        eventHelper.sendInterstitialEvent(AdConstants.Events.interstitialVideoDownloaded, posId: currentPosId)

        // 根据官方文档建议：仅接入CSJ广告时建议在收到此回调后进行广告展示
        // 聚合模式则在 nativeExpressFullscreenVideoAdDidLoad 回调中展示
    }

    /**
     * 插屏广告跳过
     */
    func nativeExpressFullscreenVideoAdDidClickSkip(_ fullscreenVideoAd: BUNativeExpressFullscreenVideoAd) {
        logger.logAdEvent(AdConstants.Events.interstitialSkipped, posId: currentPosId)
        eventHelper.sendInterstitialEvent(AdConstants.Events.interstitialSkipped, posId: currentPosId)
    }

    /**
     * 插屏广告即将关闭
     */
    func nativeExpressFullscreenVideoAdWillClose(_ fullscreenVideoAd: BUNativeExpressFullscreenVideoAd) {
        logger.logAdEvent(AdConstants.Events.interstitialWillClose, posId: currentPosId)
        eventHelper.sendInterstitialEvent(AdConstants.Events.interstitialWillClose, posId: currentPosId)
    }

    /**
     * 插屏广告已经展示（聚合维度使用）
     */
    func nativeExpressFullscreenVideoAdDidVisible(_ fullscreenVideoAd: BUNativeExpressFullscreenVideoAd) {
        logger.logAdEvent(AdConstants.Events.interstitialShowed, posId: currentPosId)
        eventHelper.sendInterstitialEvent(AdConstants.Events.interstitialShowed, posId: currentPosId)

        // 展示后可获取聚合信息
        if let mediationInfo = fullscreenVideoAd.mediation?.getShowEcpmInfo() {
            let ecpmInfo: [String: Any] = [
                "ecpm": mediationInfo.ecpm ?? 0,
                "platform": mediationInfo.adnName ?? "",
                "slotID": mediationInfo.slotID ?? "",
                "requestID": mediationInfo.requestID ?? ""
            ]
            logger.logAdEvent(AdConstants.Events.interstitialEcpmInfo, posId: currentPosId, extra: ecpmInfo)
            eventHelper.sendInterstitialEvent(AdConstants.Events.interstitialEcpmInfo, posId: currentPosId, extra: ecpmInfo)
        }
    }
}

// MARK: - BUMNativeExpressFullscreenVideoAdDelegate (聚合功能代理)

extension InterstitialAdManager: BUMNativeExpressFullscreenVideoAdDelegate {

    /**
     * 插屏广告展示失败（聚合维度功能）
     */
    func nativeExpressFullscreenVideoAdDidShowFailed(_ fullscreenVideoAd: BUNativeExpressFullscreenVideoAd, error: Error) {
        let errorMessage = error.localizedDescription
        let errorCode = (error as NSError).code

        logger.logAdError(AdConstants.AdType.interstitial, action: "展示失败", posId: currentPosId, errorCode: errorCode, errorMessage: errorMessage)
        eventHelper.sendErrorEvent(adType: AdConstants.AdType.interstitial, posId: currentPosId, errorCode: errorCode, errorMessage: "展示失败: \(errorMessage)")

        // 重置状态，允许重新加载
        destroy()
    }

    /**
     * 即将弹出广告详情页回调
     */
    func nativeExpressFullscreenVideoAdWillPresentFullScreenModal(_ fullscreenVideoAd: BUNativeExpressFullscreenVideoAd) {
        logger.logAdEvent(AdConstants.Events.interstitialWillPresentModal, posId: currentPosId)
        eventHelper.sendInterstitialEvent(AdConstants.Events.interstitialWillPresentModal, posId: currentPosId)
    }

    /**
     * 奖励验证回调成功（目前支持GDT）
     */
    func nativeExpressFullscreenVideoAdServerRewardDidSucceed(_ fullscreenVideoAd: BUNativeExpressFullscreenVideoAd, verify: Bool) {
        let rewardInfo = ["verify": verify]
        logger.logAdEvent(AdConstants.Events.interstitialRewardSucceed, posId: currentPosId, extra: rewardInfo)
        eventHelper.sendInterstitialEvent(AdConstants.Events.interstitialRewardSucceed, posId: currentPosId, extra: rewardInfo)
    }

    /**
     * 奖励验证回调失败（目前支持GDT）
     */
    func nativeExpressFullscreenVideoAdServerRewardDidFail(_ fullscreenVideoAd: BUNativeExpressFullscreenVideoAd, error: Error) {
        let errorMessage = error.localizedDescription
        let errorCode = (error as NSError).code

        logger.logAdError(AdConstants.AdType.interstitial, action: "奖励验证失败", posId: currentPosId, errorCode: errorCode, errorMessage: errorMessage)
        eventHelper.sendErrorEvent(adType: AdConstants.AdType.interstitial, posId: currentPosId, errorCode: errorCode, errorMessage: "奖励验证失败: \(errorMessage)")
        eventHelper.sendInterstitialEvent(
            AdConstants.Events.interstitialRewardFail,
            posId: currentPosId,
            extra: [
                "code": errorCode,
                "message": errorMessage
            ]
        )
    }
}
