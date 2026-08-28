import Foundation
import Flutter
import UIKit
import BUAdSDK

/**
 * 激励视频广告管理器
 * 负责激励视频广告的加载、展示和生命周期管理
 */
class RewardVideoAdManager: NSObject, AdManagerProtocol {

    // 工具类实例
    private let eventHelper: AdEventHelper
    private let validationHelper: AdValidationHelper
    private let logger: AdLogger

    // 当前激励视频广告实例
    private var currentRewardVideoAd: BUNativeExpressRewardedVideoAd?
    private var currentPosId: String = ""
    private var isLoading = false
    private var isLoaded = false

    // 激励视频参数 - 移除所有默认值，只保存明确传递的参数
    private var currentUserId: String? = nil
    private var currentCustomData: String? = nil
    private var currentOrientation: Int? = nil

    // 奖励信息参数
    private var currentRewardName: String? = nil
    private var currentRewardAmount: Int? = nil

    // 聚合维度参数
    private var currentMutedIfCan: Bool? = nil
    private var currentScenarioID: String? = nil
    private var currentBidNotify: Bool? = nil

    override init() {
        self.eventHelper = AdEventHelper.shared
        self.validationHelper = AdValidationHelper.shared
        self.logger = AdLogger.shared
        super.init()
    }

    /**
     * 加载激励视频广告
     */
    func load(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let posId: String = getRequiredArgument(call, key: "posId") else {
            result(createFlutterError(code: AdConstants.ErrorCodes.invalidPosId, message: "广告位ID不能为空"))
            return
        }

        // 获取参数（只获取存在的参数，不设置默认值，让SDK使用原生默认配置）
        let args = call.arguments as? [String: Any] ?? [:]
        let userId: String? = args["userId"] as? String
        let customData: String? = normalizeCustomData(args["customData"])
        let orientation: Int? = args["orientation"] as? Int
        let rewardName: String? = args["rewardName"] as? String
        let rewardAmount: Int? = parseInt(args["rewardAmount"])

        // 聚合维度参数（只获取存在的参数）
        let mutedIfCan: Bool? = args["mutedIfCan"] as? Bool
        let scenarioId: String? = args["scenarioId"] as? String
        let bidNotify: Bool? = args["bidNotify"] as? Bool

        // 执行基础检查
        if let errorMsg = validationHelper.performBasicChecks(adType: AdConstants.AdType.rewardVideo, posId: posId) {
            result(createFlutterError(code: AdConstants.ErrorCodes.loadError, message: errorMsg))
            return
        }

        // 检查是否正在加载
        if isLoading {
            logger.logWarning("激励视频广告正在加载中，无法重复请求")
            result(createFlutterError(code: AdConstants.ErrorCodes.frequentRequest, message: "广告正在加载中"))
            return
        }

        // 更新请求时间
        validationHelper.updateRequestTime(posId: posId)

        // 记录请求日志（只记录存在的参数）
        var logParams: [String: Any] = [:]
        if let userId = userId { logParams["userId"] = userId }
        if let customData = customData { logParams["customData"] = customData }
        if let orientation = orientation { logParams["orientation"] = orientation }
        if let rewardName = rewardName { logParams["rewardName"] = rewardName }
        if let rewardAmount = rewardAmount { logParams["rewardAmount"] = rewardAmount }
        if let mutedIfCan = mutedIfCan { logParams["mutedIfCan"] = mutedIfCan }
        if let scenarioId = scenarioId { logParams["scenarioId"] = scenarioId }
        if let bidNotify = bidNotify { logParams["bidNotify"] = bidNotify }

        logger.logAdRequest(AdConstants.AdType.rewardVideo, posId: posId, params: logParams)

        // 保存参数（只保存明确传递的参数，不设置默认值）
        currentUserId = userId
        currentCustomData = customData
        currentOrientation = orientation
        currentRewardName = rewardName
        currentRewardAmount = rewardAmount
        currentMutedIfCan = mutedIfCan
        currentScenarioID = scenarioId
        currentBidNotify = bidNotify

        // 开始加载激励视频广告
        loadRewardVideoAd(posId: posId, call: call, result: result)
    }

    /**
     * 展示激励视频广告
     */
    func show(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let posId: String = getRequiredArgument(call, key: "posId") else {
            result(createFlutterError(code: AdConstants.ErrorCodes.invalidPosId, message: "广告位ID不能为空"))
            return
        }

        // 检查广告是否已加载
        if !isLoaded || currentRewardVideoAd == nil {
            logger.logAdError(AdConstants.AdType.rewardVideo, action: "展示", posId: posId, errorCode: -1, errorMessage: "广告未加载")
            result(createFlutterError(code: AdConstants.ErrorCodes.adNotLoaded, message: "激励视频广告未加载，请先调用loadRewardVideoAd"))
            return
        }

        // 聚合维度：检查广告是否准备就绪
        if let mediation = currentRewardVideoAd?.mediation, !mediation.isReady {
            logger.logAdError(AdConstants.AdType.rewardVideo, action: "展示", posId: posId, errorCode: -1, errorMessage: "广告未准备就绪")
            result(createFlutterError(code: AdConstants.ErrorCodes.adNotReady, message: "激励视频广告未准备就绪，请稍后再试"))
            return
        }

        // 获取当前视图控制器
        guard let rootViewController = getCurrentViewController() else {
            logger.logAdError(AdConstants.AdType.rewardVideo, action: "展示", posId: posId, errorCode: -1, errorMessage: "无法获取根视图控制器")
            result(createFlutterError(code: AdConstants.ErrorCodes.showError, message: "无法获取根视图控制器"))
            return
        }

        logger.logManagerState(AdConstants.AdType.rewardVideo, posId: posId, state: "开始展示")

        let showBlock = { [weak self] in
            guard let self = self else { return }
            let showResult = self.currentRewardVideoAd?.show(fromRootViewController: rootViewController) ?? false
            if showResult {
                self.isLoaded = false
                result(true)
            } else {
                self.logger.logAdError(AdConstants.AdType.rewardVideo, action: "展示", posId: posId, errorCode: -1, errorMessage: "展示失败")
                self.resetState(clearRequest: false)
                result(self.createFlutterError(code: AdConstants.ErrorCodes.showError, message: "激励视频广告展示失败"))
            }
        }

        if Thread.isMainThread {
            showBlock()
        } else {
            DispatchQueue.main.async(execute: showBlock)
        }
    }

    /**
     * 加载激励视频广告
     */
    private func loadRewardVideoAd(posId: String, call: FlutterMethodCall, result: @escaping FlutterResult) {
        isLoading = true
        isLoaded = false
        currentPosId = posId

        // 创建广告位配置（使用BUAdSlot方式，支持聚合功能）
        let adSlot = BUAdSlot()
        adSlot.id = posId

        // 聚合维度相关设置（只设置存在的参数）
        let mediation = adSlot.mediation
        let args = call.arguments as? [String: Any] ?? [:]

        // 检查调用参数是否存在，只有存在才设置（符合开发流程文档要求）
        if args.keys.contains("mutedIfCan"), let mutedIfCan = args["mutedIfCan"] as? Bool {
            mediation.mutedIfCan = mutedIfCan
        }
        if args.keys.contains("bidNotify"), let bidNotify = args["bidNotify"] as? Bool {
            mediation.bidNotify = bidNotify
        }
        if args.keys.contains("scenarioId"), let scenarioId = args["scenarioId"] as? String, !scenarioId.isEmpty {
            mediation.scenarioID = scenarioId
        }

        // 显示方向要设置到广告实例的 mediation 上，BUAdSlotMediation 没有 addParam。
        let showDirection: Int?
        if args.keys.contains("orientation"), let orientation = args["orientation"] as? Int {
            // vertical(1) -> 0, horizontal(2) -> 1
            showDirection = orientation == 2 ? 1 : 0
        } else {
            showDirection = nil
        }

        // volume参数iOS不支持，记录警告
        if args.keys.contains("volume"), let volume = args["volume"] as? Double {
            logger.logWarning("当前 iOS 激励视频广告不支持 volume 参数，已忽略: \(volume)")
        }

        // 创建奖励视频模型（只设置存在的参数，符合开发流程文档要求）
        let model = BURewardedVideoModel()

        // 只有Flutter明确传递的参数才设置，避免覆盖SDK默认配置
        if args.keys.contains("rewardName"), let rewardName = args["rewardName"] as? String {
            model.rewardName = rewardName
        }
        if args.keys.contains("rewardAmount"), let rewardAmount = parseInt(args["rewardAmount"]) {
            model.rewardAmount = rewardAmount
        }
        // 设置用户ID和自定义数据（只有存在时才设置）
        if args.keys.contains("userId"), let userId = args["userId"] as? String, !userId.isEmpty {
            model.userId = userId
        }
        if args.keys.contains("customData"), let customData = normalizeCustomData(args["customData"]) {
            model.extra = customData
        }

        // 创建激励视频广告实例（使用BUAdSlot方式）
        let rewardVideoAd = BUNativeExpressRewardedVideoAd(slot: adSlot, rewardedVideoModel: model)
        if let showDirection = showDirection {
            rewardVideoAd.mediation?.addParam(NSNumber(value: showDirection), withKey: "show_direction")
        }
        rewardVideoAd.delegate = self

        currentRewardVideoAd = rewardVideoAd

        // 存储result回调
        self.currentLoadResult = result

        logger.logManagerState(AdConstants.AdType.rewardVideo, posId: posId, state: "开始加载")

        // 加载广告数据
        rewardVideoAd.loadData()
    }

    /**
     * 销毁广告
     */
    func destroy() {
        logger.logInfo("销毁激励视频广告管理器")
        resetState(clearRequest: true)
    }

    func isReady() -> Bool {
        return isLoaded && currentRewardVideoAd?.mediation?.isReady == true
    }

    func getAdLoadInfo() -> [[String: Any]] {
        return AdDiagnosticsHelper.map(
            currentRewardVideoAd?.mediation?.getAdLoadInfoList(),
            adType: "rewardVideo"
        )
    }

    // MARK: - 私有属性

    // 用于存储加载结果回调
    private var currentLoadResult: FlutterResult?

    // MARK: - 辅助方法

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

    private func resetState(clearRequest: Bool) {
        currentRewardVideoAd = nil
        currentLoadResult = nil
        isLoading = false
        isLoaded = false
        if clearRequest {
            currentPosId = ""
            currentUserId = nil
            currentCustomData = nil
            currentOrientation = nil
            currentRewardName = nil
            currentRewardAmount = nil
            currentMutedIfCan = nil
            currentScenarioID = nil
            currentBidNotify = nil
        }
    }

    private func normalizeCustomData(_ value: Any?) -> String? {
        if let string = value as? String, !string.isEmpty {
            return string
        }
        if let map = value as? [String: Any], JSONSerialization.isValidJSONObject(map),
           let data = try? JSONSerialization.data(withJSONObject: map, options: []),
           let json = String(data: data, encoding: .utf8), !json.isEmpty {
            return json
        }
        return nil
    }

    private func parseInt(_ value: Any?) -> Int? {
        if let number = value as? Int {
            return number
        }
        if let number = value as? NSNumber {
            return number.intValue
        }
        if let string = value as? String {
            return Int(string)
        }
        return nil
    }
}

// MARK: - BUNativeExpressRewardedVideoAdDelegate

extension RewardVideoAdManager: BUNativeExpressRewardedVideoAdDelegate {

    /**
     * 激励视频广告加载成功
     */
    func nativeExpressRewardedVideoAdDidLoad(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd) {
        isLoading = false
        isLoaded = true

        logger.logAdSuccess(AdConstants.AdType.rewardVideo, action: "加载", posId: currentPosId, message: "激励视频广告加载成功")
        eventHelper.sendRewardVideoEvent(AdConstants.Events.rewardVideoLoaded, posId: currentPosId)

        // 通知Flutter加载成功
        if let result = currentLoadResult {
            result(true)
            currentLoadResult = nil
        }
    }

    /**
     * 激励视频广告加载失败
     */
    func nativeExpressRewardedVideoAd(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd, didFailWithError error: Error?) {
        let resultCallback = currentLoadResult
        resetState(clearRequest: false)

        let errorMessage = error?.localizedDescription ?? "未知错误"
        let errorCode = (error as NSError?)?.code ?? -1

        logger.logAdError(AdConstants.AdType.rewardVideo, action: "加载", posId: currentPosId, errorCode: errorCode, errorMessage: errorMessage)
        eventHelper.sendErrorEvent(adType: AdConstants.AdType.rewardVideo, posId: currentPosId, errorCode: errorCode, errorMessage: errorMessage)

        // 通知Flutter加载失败
        if let result = resultCallback {
            result(createFlutterError(code: AdConstants.ErrorCodes.loadError, message: "激励视频广告加载失败: \(errorMessage)", details: errorCode))
        }
    }

    /**
     * 激励视频广告渲染成功
     */
    func nativeExpressRewardedVideoAdViewRenderSuccess(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd) {
        logger.logAdEvent(AdConstants.Events.rewardVideoRenderSuccess, posId: currentPosId)
        eventHelper.sendRewardVideoEvent(AdConstants.Events.rewardVideoRenderSuccess, posId: currentPosId)
    }

    /**
     * 激励视频广告渲染失败
     */
    func nativeExpressRewardedVideoAdViewRenderFail(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd, error: Error?) {
        let errorMessage = error?.localizedDescription ?? "未知错误"
        let errorCode = (error as NSError?)?.code ?? -1

        logger.logAdError(AdConstants.AdType.rewardVideo, action: "渲染", posId: currentPosId, errorCode: errorCode, errorMessage: errorMessage)
        eventHelper.sendErrorEvent(adType: AdConstants.AdType.rewardVideo, posId: currentPosId, errorCode: errorCode, errorMessage: "渲染失败: \(errorMessage)")
    }

    /**
     * 激励视频素材加载完成 - 关键回调
     * CSJ广告建议在此回调时展示广告，聚合维度在didLoad后检查isReady再展示
     */
    func nativeExpressRewardedVideoAdDidDownLoadVideo(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd) {
        logger.logAdEvent(AdConstants.Events.rewardVideoDownloadSuccess, posId: currentPosId)
        eventHelper.sendRewardVideoEvent(AdConstants.Events.rewardVideoDownloadSuccess, posId: currentPosId)
    }

    /**
     * 激励视频展示失败 - 关键回调
     */
    func nativeExpressRewardedVideoAdDidShowFailed(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd, error: Error) {
        let errorMessage = error.localizedDescription
        let errorCode = (error as NSError).code

        logger.logAdError(AdConstants.AdType.rewardVideo, action: "展示失败", posId: currentPosId, errorCode: errorCode, errorMessage: errorMessage)
        eventHelper.sendErrorEvent(adType: AdConstants.AdType.rewardVideo, posId: currentPosId, errorCode: errorCode, errorMessage: "展示失败: \(errorMessage)")
        eventHelper.sendRewardVideoEvent(
            AdConstants.Events.rewardVideoError,
            posId: currentPosId,
            extra: [
                "code": errorCode,
                "message": errorMessage
            ]
        )

        // 重置状态
        resetState(clearRequest: false)
    }

    /**
     * 激励视频展示成功 - 关键回调（ECPM获取时机）
     */
    func nativeExpressRewardedVideoAdDidVisible(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd) {
        logger.logAdEvent(AdConstants.Events.rewardVideoShowed, posId: currentPosId)
        eventHelper.sendRewardVideoEvent(AdConstants.Events.rewardVideoShowed, posId: currentPosId)

        // 聚合维度：获取ECPM信息
        if let mediation = rewardedVideoAd.mediation {
            if let ecpmInfo = mediation.getShowEcpmInfo() {
                let ecpmData: [String: Any] = [
                    "ecpm": ecpmInfo.ecpm ?? "",
                    "platform": ecpmInfo.adnName ?? "",
                    "ritID": ecpmInfo.slotID ?? "",
                    "requestID": ecpmInfo.requestID ?? ""
                ]
                logger.logAdEvent(AdConstants.Events.rewardVideoEcpmInfo, posId: currentPosId, extra: ecpmData)
                eventHelper.sendRewardVideoEvent(AdConstants.Events.rewardVideoEcpmInfo, posId: currentPosId, extra: ecpmData)
            }
        }
    }

    /**
     * 激励视频广告即将展示
     */
    func nativeExpressRewardedVideoAdWillVisible(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd) {
        logger.logAdEvent(AdConstants.Events.rewardVideoWillShow, posId: currentPosId)
        eventHelper.sendRewardVideoEvent(AdConstants.Events.rewardVideoWillShow, posId: currentPosId)
    }

    /**
     * 激励视频广告点击
     */
    func nativeExpressRewardedVideoAdDidClick(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd) {
        logger.logAdEvent(AdConstants.Events.rewardVideoClicked, posId: currentPosId)
        eventHelper.sendRewardVideoEvent(AdConstants.Events.rewardVideoClicked, posId: currentPosId)
    }

    func nativeExpressRewardedVideoAdDidClickSkip(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd) {
        logger.logAdEvent(AdConstants.Events.rewardVideoSkipped, posId: currentPosId)
        eventHelper.sendRewardVideoEvent(AdConstants.Events.rewardVideoSkipped, posId: currentPosId)
    }

    /**
     * 激励视频广告关闭
     */
    func nativeExpressRewardedVideoAdDidClose(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd) {
        logger.logAdEvent(AdConstants.Events.rewardVideoClosed, posId: currentPosId)
        eventHelper.sendRewardVideoEvent(AdConstants.Events.rewardVideoClosed, posId: currentPosId)

        // 重置加载状态，需要重新加载
        resetState(clearRequest: true)
    }

    /**
     * 激励视频广告播放完成
     */
    func nativeExpressRewardedVideoAdDidPlayFinish(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd, didFailWithError error: Error?) {
        if let error = error {
            let errorMessage = error.localizedDescription
            logger.logAdError(AdConstants.AdType.rewardVideo, action: "播放", posId: currentPosId, errorCode: (error as NSError).code, errorMessage: errorMessage)
        } else {
            logger.logAdEvent(AdConstants.Events.rewardVideoCompleted, posId: currentPosId)
            eventHelper.sendRewardVideoEvent(AdConstants.Events.rewardVideoCompleted, posId: currentPosId)
        }
    }

    /**
     * 激励视频广告奖励发放成功
     */
    func nativeExpressRewardedVideoAdServerRewardDidSucceed(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd, verify: Bool) {
        // 只包含实际设置的参数，避免包含空字符串或0值
        var rewardInfo: [String: Any] = ["verify": verify]

        if let rewardName = currentRewardName {
            rewardInfo["rewardName"] = rewardName
        }
        if let rewardAmount = currentRewardAmount {
            rewardInfo["rewardAmount"] = rewardAmount
        }
        if let userId = currentUserId {
            rewardInfo["userId"] = userId
        }
        if let customData = currentCustomData {
            rewardInfo["customData"] = customData
        }

        logger.logAdEvent(AdConstants.Events.rewardVideoRewarded, posId: currentPosId, extra: rewardInfo)
        eventHelper.sendRewardVideoEvent(AdConstants.Events.rewardVideoRewarded, posId: currentPosId, extra: rewardInfo)
    }

    /**
     * 激励视频广告奖励发放失败
     */
    func nativeExpressRewardedVideoAdServerRewardDidFail(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd, error: Error?) {
        let errorMessage = error?.localizedDescription ?? "奖励发放失败"
        let errorCode = (error as NSError?)?.code ?? -1

        logger.logAdError(AdConstants.AdType.rewardVideo, action: "奖励发放", posId: currentPosId, errorCode: errorCode, errorMessage: errorMessage)

        // 只包含实际设置的参数
        var failInfo: [String: Any] = [
            "errorCode": errorCode,
            "errorMessage": errorMessage
        ]

        if let userId = currentUserId {
            failInfo["userId"] = userId
        }
        if let customData = currentCustomData {
            failInfo["customData"] = customData
        }

        eventHelper.sendRewardVideoEvent(AdConstants.Events.rewardVideoRewardFail, posId: currentPosId, extra: failInfo)
    }
}
