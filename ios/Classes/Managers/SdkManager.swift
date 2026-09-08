import Foundation
import Flutter
import UIKit
import BUAdSDK
import AppTrackingTransparency
import AdSupport

/**
 * SDK管理器协议
 * 定义SDK相关的所有操作接口，与Android版本保持一致
 */
protocol SdkManagerProtocol {
    /**
     * 初始化广告SDK
     */
    func initAd(_ call: FlutterMethodCall, result: @escaping FlutterResult)

    /**
     * 请求IDFA权限（iOS特有）
     */
    func requestIDFA(result: @escaping FlutterResult)

    /**
     * 预加载广告
     */
    func preload(_ call: FlutterMethodCall, result: @escaping FlutterResult)

    /**
     * 销毁SDK管理器
     */
    func destroy()
}

/**
 * SDK管理器实现类
 * 负责GroMore SDK的初始化、配置和预加载
 * 从主插件中分离出来，实现职责分离，与Android版本架构保持一致
 */
class SdkManager: BaseAdManager, SdkManagerProtocol {

    // SDK初始化状态与配置缓存
    private weak var registrar: FlutterPluginRegistrar?
    private var isSdkInitialized = false
    private var lastInitOptions: InitOptions?
    private var temporaryConfigFiles: [URL] = []
    private var privacyProvider: GromorePrivacyProvider?
    private let fileManager = FileManager.default

    init(registrar: FlutterPluginRegistrar?,
         eventHelper: AdEventHelper = AdEventHelper.shared,
         validationHelper: AdValidationHelper = AdValidationHelper.shared,
         logger: AdLogger = AdLogger.shared) {
        self.registrar = registrar
        super.init(eventHelper: eventHelper, validationHelper: validationHelper, logger: logger)
        logger.logInfo("SdkManager初始化完成")
    }

    // MARK: - SDK初始化

    /**
     * 初始化广告SDK
     * 从GromoreAdsKitPlugin迁移而来，保持完整功能
     */
    func initAd(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            logger.logAdError("SDK", action: "初始化", posId: "", errorCode: -1, errorMessage: "参数格式无效")
            result(createFlutterError(code: AdConstants.ErrorCodes.invalidArguments, message: "arguments must be a dictionary"))
            return
        }

        let rawAppId = (args["appId"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let useMediation = args["useMediation"] as? Bool
        let debugMode = args["debugMode"] as? Bool

        guard let appId = rawAppId, !appId.isEmpty, let useMediation = useMediation, let debugMode = debugMode else {
            logger.logAdError("SDK", action: "初始化", posId: "", errorCode: -1, errorMessage: "appId/useMediation/debugMode缺失")
            result(createFlutterError(code: AdConstants.ErrorCodes.invalidArguments,
                                      message: "appId, useMediation, and debugMode are required"))
            return
        }

        let limitPersonalAds = (args["limitPersonalAds"] as? NSNumber)?.intValue ?? args["limitPersonalAds"] as? Int
        let limitProgrammaticAds = (args["limitProgrammaticAds"] as? NSNumber)?.intValue ?? args["limitProgrammaticAds"] as? Int
        let themeStatus = (args["themeStatus"] as? NSNumber)?.intValue ?? args["themeStatus"] as? Int
        let ageGroup = (args["ageGroup"] as? NSNumber)?.intValue ?? args["ageGroup"] as? Int
        let privacy = args["privacy"] as? [String: Any]
        let configParam = args["config"]

        let advancedConfig = resolveAdvancedConfig(configParam)
        let privacySignature = privacy.flatMap { value -> String? in
            guard JSONSerialization.isValidJSONObject(value),
                  let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]) else {
                return nil
            }
            return data.base64EncodedString()
        }

        var logParams: [String: Any] = [
            "useMediation": useMediation,
            "debugMode": debugMode
        ]
        if let source = advancedConfig.source { logParams["configSource"] = source }
        if let limitPersonalAds = limitPersonalAds { logParams["limitPersonalAds"] = limitPersonalAds }
        if let limitProgrammaticAds = limitProgrammaticAds { logParams["limitProgrammaticAds"] = limitProgrammaticAds }
        if let themeStatus = themeStatus { logParams["themeStatus"] = themeStatus }
        if let ageGroup = ageGroup { logParams["ageGroup"] = ageGroup }

        logger.logAdRequest("SDK", posId: appId, params: logParams)

        let initOptions = InitOptions(appId: appId,
                                      useMediation: useMediation,
                                      debugMode: debugMode,
                                      configSignature: advancedConfig.signature,
                                      privacySignature: privacySignature)

        if isSdkInitialized {
            if let last = lastInitOptions, last.isCompatible(with: initOptions) {
                lastInitOptions = initOptions
                logger.logAdSuccess("SDK", action: "重复初始化", posId: appId, message: "复用现有实例")
                eventHelper.sendAdEvent("sdk_init_reused", posId: appId, extra: [
                    "limitPersonalAds": limitPersonalAds ?? -1,
                    "limitProgrammaticAds": limitProgrammaticAds ?? -1,
                    "themeStatus": themeStatus ?? -1
                ])
                result(true)
                return
            } else {
                let message = "GroMore SDK 已使用 appId=\(lastInitOptions?.appId ?? appId) 完成初始化，新的配置与现有配置不兼容"
                logger.logAdError("SDK", action: "重复初始化", posId: appId, errorCode: -1, errorMessage: message)
                result(createFlutterError(code: AdConstants.ErrorCodes.alreadyInitialized, message: message))
                return
            }
        }

        let configuration = BUAdSDKConfiguration()
        configuration.appID = appId
        configuration.useMediation = useMediation
        configuration.debugLog = NSNumber(value: debugMode ? 1 : 0)
        configuration.sdkdebug = debugMode

        if let customIdfa = privacy?["customIdfa"] as? String, !customIdfa.isEmpty {
            configuration.customIdfa = customIdfa
        }

        if let forbidIdfa = privacy?["forbidIdfa"] as? Bool {
            configuration.mediation.forbiddenIDFA = NSNumber(value: forbidIdfa)
        }

        if let allowUploadDeviceInfo = privacy?["allowUploadDeviceInfo"] as? Bool {
            configuration.mediation.allowUploadDeviceInfo = allowUploadDeviceInfo
        }

        if let privacy = privacy, !privacy.isEmpty {
            let provider = GromorePrivacyProvider(values: privacy)
            privacyProvider = provider
            configuration.privacyProvider = provider
        }

        if let themeStatus = themeStatus {
            configuration.themeStatus = NSNumber(value: themeStatus)
        }

        if let ageGroup = ageGroup {
            switch ageGroup {
            case 2:
                configuration.ageGroup = .minor
            case 1:
                configuration.ageGroup = .teenager
            default:
                configuration.ageGroup = .adult
            }
        }

        if let limitPersonalAds = limitPersonalAds {
            configuration.mediation.limitPersonalAds = NSNumber(value: limitPersonalAds)
        }

        if let limitProgrammaticAds = limitProgrammaticAds {
            configuration.mediation.limitProgrammaticAds = NSNumber(value: limitProgrammaticAds)
        }

        if let path = advancedConfig.path {
            configuration.mediation.advanceSDKConfigPath = path
        }

        logger.logInfo("GroMore SDK开始初始化 - AppId=\(appId), useMediation=\(useMediation), debugMode=\(debugMode)")
        eventHelper.sendAdEvent("sdk_init_start", posId: appId, extra: [
            "useMediation": useMediation,
            "debugMode": debugMode,
            "hasLocalConfig": advancedConfig.path != nil
        ])

        BUAdSDKManager.start(asyncCompletionHandler: { [weak self] (success: Bool, error: Error?) in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if success {
                    self.isSdkInitialized = true
                    self.validationHelper.updateSdkInitialized(true)
                    self.lastInitOptions = initOptions
                    self.logger.logAdSuccess("SDK", action: "初始化", posId: appId, message: "GroMore SDK初始化成功")
                    self.eventHelper.sendAdEvent("sdk_init_success", posId: appId, extra: [
                        "limitPersonalAds": limitPersonalAds ?? -1,
                        "limitProgrammaticAds": limitProgrammaticAds ?? -1,
                        "themeStatus": themeStatus ?? -1
                    ])
                    result(true)
                } else {
                    self.isSdkInitialized = false
                    self.validationHelper.updateSdkInitialized(false)
                    let errorMessage = error?.localizedDescription ?? "Unknown error"
                    let errorCode = (error as NSError?)?.code ?? -1
                    self.logger.logAdError("SDK", action: "初始化", posId: appId, errorCode: errorCode, errorMessage: errorMessage)
                    self.eventHelper.sendAdEvent("sdk_init_fail", posId: appId, extra: [
                        "errorCode": errorCode,
                        "errorMessage": errorMessage
                    ])
                    result(self.createFlutterError(code: AdConstants.ErrorCodes.initFailed,
                                                   message: "SDK初始化失败: \(errorMessage)",
                                                   details: error?.localizedDescription))
                }
            }
        })
    }

    private struct InitOptions {
        let appId: String
        let useMediation: Bool
        let debugMode: Bool
        let configSignature: String?
        let privacySignature: String?

        func isCompatible(with other: InitOptions) -> Bool {
            return appId == other.appId &&
                useMediation == other.useMediation &&
                debugMode == other.debugMode &&
                (configSignature ?? "") == (other.configSignature ?? "") &&
                (privacySignature ?? "") == (other.privacySignature ?? "")
        }
    }

    private struct AdvancedConfigResolution {
        let path: String?
        let signature: String?
        let source: String?
    }

    private func resolveAdvancedConfig(_ config: Any?) -> AdvancedConfigResolution {
        guard let config = config else {
            return AdvancedConfigResolution(path: nil, signature: nil, source: nil)
        }

        if let map = config as? [String: Any] {
            guard JSONSerialization.isValidJSONObject(map),
                  let data = try? JSONSerialization.data(withJSONObject: map, options: [.sortedKeys]),
                  let jsonString = String(data: data, encoding: .utf8) else {
                logger.logWarning("无法序列化 config map")
                return AdvancedConfigResolution(path: nil, signature: nil, source: "map-invalid")
            }
            return writeTemporaryConfig(jsonString: jsonString, reason: "map")
        }

        if let array = config as? [Any] {
            if let data = try? JSONSerialization.data(withJSONObject: array, options: [.sortedKeys]),
               let jsonString = String(data: data, encoding: .utf8) {
                return writeTemporaryConfig(jsonString: jsonString, reason: "list")
            }
            logger.logWarning("config 列表序列化失败")
            return AdvancedConfigResolution(path: nil, signature: nil, source: "list-invalid")
        }

        if let jsonString = config as? String {
            let trimmed = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return AdvancedConfigResolution(path: nil, signature: nil, source: "empty-string")
            }

            if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") {
                return writeTemporaryConfig(jsonString: trimmed, reason: "inline-json")
            }

            if trimmed.hasPrefix("file://"), let url = URL(string: trimmed) {
                let path = url.path
                if fileManager.fileExists(atPath: path) {
                    return AdvancedConfigResolution(path: path, signature: path, source: "file-uri")
                } else {
                    logger.logWarning("本地配置文件不存在: \(path)")
                    return AdvancedConfigResolution(path: nil, signature: nil, source: "file-uri-missing")
                }
            }

            if trimmed.hasPrefix("/") {
                if fileManager.fileExists(atPath: trimmed) {
                    return AdvancedConfigResolution(path: trimmed, signature: trimmed, source: "file-path")
                } else {
                    logger.logWarning("本地配置文件不存在: \(trimmed)")
                    return AdvancedConfigResolution(path: nil, signature: nil, source: "file-path-missing")
                }
            }

            if let registrar = registrar {
                let assetKey = registrar.lookupKey(forAsset: trimmed)
                if let assetURL = Bundle.main.resourceURL?.appendingPathComponent(assetKey),
                   fileManager.fileExists(atPath: assetURL.path) {
                    return AdvancedConfigResolution(path: assetURL.path, signature: assetURL.path, source: "asset:\(assetKey)")
                }
            }

            if let path = Bundle.main.path(forResource: trimmed, ofType: nil), fileManager.fileExists(atPath: path) {
                return AdvancedConfigResolution(path: path, signature: path, source: "bundle:\(trimmed)")
            }

            if let path = Bundle.main.path(forResource: trimmed, ofType: "json"), fileManager.fileExists(atPath: path) {
                return AdvancedConfigResolution(path: path, signature: path, source: "bundle:\(trimmed).json")
            }

            logger.logWarning("未找到指定的本地配置: \(trimmed)")
            return AdvancedConfigResolution(path: nil, signature: nil, source: "asset-missing")
        }

        logger.logWarning("config 参数类型暂不支持: \(type(of: config))")
        return AdvancedConfigResolution(path: nil, signature: nil, source: "unsupported-type")
    }

    private func writeTemporaryConfig(jsonString: String, reason: String) -> AdvancedConfigResolution {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("gromore_config_\(UUID().uuidString).json")
        do {
            try jsonString.write(to: url, atomically: true, encoding: .utf8)
            temporaryConfigFiles.append(url)
            return AdvancedConfigResolution(path: url.path, signature: jsonString, source: reason)
        } catch {
            logger.logWarning("写入临时配置失败: \(error.localizedDescription)")
            return AdvancedConfigResolution(path: nil, signature: nil, source: "\(reason)-write-failed")
        }
    }

    // MARK: - IDFA权限管理

    /**
     * 请求IDFA权限
     * iOS特有功能，用于广告追踪
     */
    func requestIDFA(result: @escaping FlutterResult) {
        logger.logAdRequest("IDFA", posId: "", params: [:])

        if #available(iOS 14, *) {
            ATTrackingManager.requestTrackingAuthorization { [weak self] status in
                DispatchQueue.main.async {
                    let requestResult = status == ATTrackingManager.AuthorizationStatus.authorized
                    self?.logger.logAdSuccess("IDFA", action: "权限申请", posId: "",
                                             message: "IDFA权限申请完成: \(requestResult ? "已授权" : "未授权")")
                    self?.eventHelper.sendAdEvent("idfa_request_completed", posId: "", extra: [
                        "authorized": requestResult,
                        "status": status.rawValue
                    ])
                    result(requestResult)
                }
            }
        } else {
            logger.logAdSuccess("IDFA", action: "权限申请", posId: "", message: "iOS版本低于14.0，自动授权")
            eventHelper.sendAdEvent("idfa_request_completed", posId: "", extra: [
                "authorized": true,
                "status": "auto_granted_ios_below_14"
            ])
            result(true)
        }
    }

    // MARK: - 预加载功能

    /**
     * 预加载广告
     * 基础实现，后续可以根据需要扩展
     */
    func preload(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            logger.logAdError("预加载", action: "参数验证", posId: "", errorCode: -1, errorMessage: "参数格式无效")
            result(createFlutterError(code: AdConstants.ErrorCodes.invalidArguments, message: "Invalid arguments"))
            return
        }

        guard isSdkInitialized else {
            logger.logAdError("预加载", action: "状态检查", posId: "", errorCode: -1, errorMessage: "SDK未初始化")
            result(createFlutterError(code: AdConstants.ErrorCodes.sdkNotReady, message: "SDK未初始化或初始化失败"))
            return
        }

        guard let configs = args["preloadConfigs"] as? [[String: Any]], !configs.isEmpty else {
            logger.logAdError("预加载", action: "参数校验", posId: "", errorCode: -1, errorMessage: "preloadConfigs 不能为空")
            result(createFlutterError(code: AdConstants.ErrorCodes.invalidParams, message: "preloadConfigs 不能为空"))
            return
        }

        let unsupportedTypes = Set(configs.compactMap { config -> String? in
            guard let adType = config["adType"] as? String else { return nil }
            let value = adType.trimmingCharacters(in: .whitespacesAndNewlines)
            return value == "banner" || value == "draw_feed" ? value : nil
        })
        if !unsupportedTypes.isEmpty {
            let names = unsupportedTypes.sorted().joined(separator: ", ")
            result(createFlutterError(
                code: AdConstants.ErrorCodes.invalidParams,
                message: "GroMore 官方不支持这些广告类型的预加载: \(names)"
            ))
            return
        }

        handlePreload(configs: configs, args: args, result: result)
    }

    private func handlePreload(configs: [[String: Any]], args: [String: Any], result: @escaping FlutterResult) {
        let parallel = sanitizeParallel(args["parallelNum"] as? Int ?? 2)
        let interval = sanitizeInterval(args["requestIntervalS"] as? Int ?? 2)

        logger.logAdRequest("预加载", posId: "", params: [
            "configCount": configs.count,
            "parallelNum": parallel,
            "requestIntervalS": interval
        ])

        var adInfos: [Any] = []

        for (index, config) in configs.enumerated() {
            guard let adTypeRaw = config["adType"] as? String else {
                logger.logAdError("预加载", action: "配置解析", posId: "", errorCode: -1, errorMessage: "第\(index + 1)项缺少 adType")
                continue
            }
            let adType = adTypeRaw.trimmingCharacters(in: .whitespacesAndNewlines)
            let adIds = extractStringArray(config["adIds"]).filter { !$0.isEmpty }
            let options = extractOptions(config["options"])

            guard !adType.isEmpty else {
                logger.logAdError("预加载", action: "配置解析", posId: "", errorCode: -1, errorMessage: "第\(index + 1)项 adType 为空")
                continue
            }
            guard !adIds.isEmpty else {
                logger.logAdError("预加载", action: "配置解析", posId: "", errorCode: -1, errorMessage: "第\(index + 1)项(\(adType)) 未提供有效的 adIds")
                continue
            }

            switch adType {
            case "reward_video":
                let infos = buildRewardPreloadInfos(adIds: adIds, options: options)
                adInfos.append(contentsOf: infos)
                logger.logDebug("预加载配置[\(index)] reward_video - ids: \(adIds), options: \(options ?? [:])")
            case "interstitial":
                let infos = buildInterstitialPreloadInfos(adIds: adIds, options: options)
                adInfos.append(contentsOf: infos)
                logger.logDebug("预加载配置[\(index)] interstitial - ids: \(adIds), options: \(options ?? [:])")
            case "feed":
                let infos = buildFeedPreloadInfos(adIds: adIds, options: options)
                adInfos.append(contentsOf: infos)
                logger.logDebug("预加载配置[\(index)] feed - ids: \(adIds), options: \(options ?? [:])")
            case "draw_feed":
                let infos = buildDrawFeedPreloadInfos(adIds: adIds, options: options)
                adInfos.append(contentsOf: infos)
                logger.logDebug("预加载配置[\(index)] draw_feed - ids: \(adIds), options: \(options ?? [:])")
            case "banner":
                let infos = buildBannerPreloadInfos(adIds: adIds, options: options)
                adInfos.append(contentsOf: infos)
                logger.logDebug("预加载配置[\(index)] banner - ids: \(adIds), options: \(options ?? [:])")
            default:
                logger.logAdError("预加载", action: "类型不支持", posId: "", errorCode: -1, errorMessage: "未知的 adType=\(adType)")
            }
        }

        guard !adInfos.isEmpty else {
            logger.logAdError("预加载", action: "配置验证", posId: "", errorCode: -1, errorMessage: "未生成任何可预加载的广告对象")
            result(createFlutterError(code: AdConstants.ErrorCodes.invalidParams, message: "预加载配置为空或不受支持"))
            return
        }

        performPreload(adInfos: adInfos, parallel: parallel, interval: interval, result: result)
    }

    private func performPreload(adInfos: [Any], parallel: Int, interval: Int, result: @escaping FlutterResult) {
        let task = {
            BUAdSDKManager.mediation.preloadAds(withInfos: adInfos, andInterval: interval, andConcurrent: parallel)
            self.logger.logAdSuccess("预加载", action: "执行", posId: "", message: "广告对象数量: \(adInfos.count)")
            self.eventHelper.sendAdEvent("preload_success", posId: "", extra: [
                "configCount": adInfos.count,
                "concurrent": parallel,
                "interval": interval
            ])
            result(true)
        }

        if Thread.isMainThread {
            task()
        } else {
            DispatchQueue.main.async(execute: task)
        }
    }

    private func sanitizeParallel(_ value: Int) -> Int {
        return max(1, min(value, 20))
    }

    private func sanitizeInterval(_ value: Int) -> Int {
        return max(1, min(value, 10))
    }

    private func extractStringArray(_ raw: Any?) -> [String] {
        guard let array = raw as? [Any] else { return [] }
        return array.compactMap { element in
            if let str = element as? String {
                return str.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if let number = element as? NSNumber {
                return number.stringValue
            }
            return (element as? CustomStringConvertible)?.description
        }
    }

    private func extractOptions(_ raw: Any?) -> [String: Any]? {
        guard let dict = raw as? [String: Any] else { return nil }
        var result: [String: Any] = [:]
        for (key, value) in dict {
            result[key] = value
        }
        return result.isEmpty ? nil : result
    }

    private func extractString(_ options: [String: Any]?, key: String) -> String? {
        guard let value = options?[key] else { return nil }
        if let str = value as? String {
            let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        return (value as? CustomStringConvertible)?.description
    }

    private func extractInt(_ options: [String: Any]?, key: String) -> Int? {
        guard let value = options?[key] else { return nil }
        if let number = value as? NSNumber {
            return number.intValue
        }
        if let str = value as? String {
            return Int(str)
        }
        return nil
    }

    private func extractBool(_ options: [String: Any]?, key: String) -> Bool? {
        guard let value = options?[key] else { return nil }
        if let boolValue = value as? Bool {
            return boolValue
        }
        if let number = value as? NSNumber {
            return number.boolValue
        }
        if let str = value as? String {
            let lowered = str.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if ["1", "true", "yes", "on"].contains(lowered) {
                return true
            }
            if ["0", "false", "no", "off"].contains(lowered) {
                return false
            }
        }
        return nil
    }

    private func extractMap(_ options: [String: Any]?, key: String) -> [String: Any]? {
        guard let raw = options?[key] else { return nil }
        if let dict = raw as? [String: Any] {
            return dict.isEmpty ? nil : dict
        }
        return nil
    }

    private func extractCustomData(_ options: [String: Any]?, key: String) -> String? {
        guard let value = options?[key] else { return nil }
        if let str = value as? String {
            let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let dict = value as? [String: Any], JSONSerialization.isValidJSONObject(dict),
           let data = try? JSONSerialization.data(withJSONObject: dict, options: []),
           let jsonStr = String(data: data, encoding: .utf8) {
            return jsonStr
        }
        return nil
    }

    private func buildRewardPreloadInfos(adIds: [String], options: [String: Any]?) -> [BUNativeExpressRewardedVideoAd] {
        var result: [BUNativeExpressRewardedVideoAd] = []
        for adId in adIds {
            let slot = BUAdSlot()
            slot.id = adId
            slot.adType = .rewardVideo
            slot.position = .fullscreen
            if let muted = extractBool(options, key: "mutedIfCan") {
                slot.mediation.mutedIfCan = muted
            }
            if let bidNotify = extractBool(options, key: "bidNotify") {
                slot.mediation.bidNotify = bidNotify
            }
            if let scenarioId = extractString(options, key: "scenarioId") {
                slot.mediation.scenarioID = scenarioId
            }

            let model = BURewardedVideoModel()
            if let userId = extractString(options, key: "userId") {
                model.userId = userId
            }
            if let customData = extractCustomData(options, key: "customData") {
                model.extra = customData
            }
            if let rewardName = extractString(options, key: "rewardName") {
                model.rewardName = rewardName
            }
            if let rewardAmount = extractInt(options, key: "rewardAmount") {
                model.rewardAmount = rewardAmount
            }
            let ad = BUNativeExpressRewardedVideoAd(slot: slot, rewardedVideoModel: model)

            if let extraParams = extractMap(options, key: "extraParams") {
                for (key, value) in extraParams {
                    ad.mediation?.addParam(value, withKey: key)
                }
            }
            if let extraData = extractMap(options, key: "extraData") {
                for (key, value) in extraData {
                    ad.mediation?.addParam(value, withKey: key)
                }
            }

            result.append(ad)
        }
        return result
    }

    private func buildInterstitialPreloadInfos(adIds: [String], options: [String: Any]?) -> [BUNativeExpressFullscreenVideoAd] {
        var result: [BUNativeExpressFullscreenVideoAd] = []
        for adId in adIds {
            let slot = BUAdSlot()
            slot.id = adId
            slot.adType = .fullscreenVideo
            slot.position = .fullscreen
            if let muted = extractBool(options, key: "mutedIfCan") {
                slot.mediation.mutedIfCan = muted
            }
            if let bidNotify = extractBool(options, key: "bidNotify") {
                slot.mediation.bidNotify = bidNotify
            }
            if let scenarioId = extractString(options, key: "scenarioId") {
                slot.mediation.scenarioID = scenarioId
            }

            let ad = BUNativeExpressFullscreenVideoAd(slot: slot)

            if let rewardName = extractString(options, key: "rewardName"),
               let rewardAmount = extractInt(options, key: "rewardAmount") {
                let rewardModel = BURewardedVideoModel()
                rewardModel.rewardName = rewardName
                rewardModel.rewardAmount = rewardAmount
                if let customData = extractCustomData(options, key: "customData") {
                    rewardModel.extra = customData
                }
                ad.mediation?.rewardModel = rewardModel
            } else if let customData = extractCustomData(options, key: "customData") {
                ad.mediation?.addParam(customData, withKey: "customData")
            }

            if let extraParams = extractMap(options, key: "extraParams") {
                for (key, value) in extraParams {
                    ad.mediation?.addParam(value, withKey: key)
                }
            }
            if let extraData = extractMap(options, key: "extraData") {
                for (key, value) in extraData {
                    ad.mediation?.addParam(value, withKey: key)
                }
            }

            result.append(ad)
        }
        return result
    }

    private func buildFeedPreloadInfos(adIds: [String], options: [String: Any]?) -> [BUNativeExpressAdManager] {
        var result: [BUNativeExpressAdManager] = []
        for adId in adIds {
            let slot = BUAdSlot()
            slot.id = adId
            slot.adType = .feed

            // 解析尺寸参数
            let width = extractInt(options, key: "width") ?? 300
            let height = extractInt(options, key: "height") ?? 125
            let adSize = CGSize(width: CGFloat(width), height: CGFloat(height))

            // 配置mediation参数
            if let muted = extractBool(options, key: "mutedIfCan") {
                slot.mediation.mutedIfCan = muted
            }
            if let bidNotify = extractBool(options, key: "bidNotify") {
                slot.mediation.bidNotify = bidNotify
            }
            if let scenarioId = extractString(options, key: "scenarioId") {
                slot.mediation.scenarioID = scenarioId
            }

            let manager = BUNativeExpressAdManager(slot: slot, adSize: adSize)
            result.append(manager)
        }
        return result
    }

    private func buildDrawFeedPreloadInfos(adIds: [String], options: [String: Any]?) -> [BUNativeExpressAdManager] {
        // DrawFeed使用相同的BUNativeExpressAdManager，复用Feed预加载逻辑
        return buildFeedPreloadInfos(adIds: adIds, options: options)
    }

    private func buildBannerPreloadInfos(adIds: [String], options: [String: Any]?) -> [BUNativeExpressBannerView] {
        var result: [BUNativeExpressBannerView] = []
        for adId in adIds {
            let width = extractInt(options, key: "width") ?? 375
            let height = extractInt(options, key: "height") ?? 60
            let adSize = CGSize(width: CGFloat(width), height: CGFloat(height))

            let slot = BUAdSlot()
            slot.id = adId
            slot.adType = .banner

            if let muted = extractBool(options, key: "mutedIfCan") {
                slot.mediation.mutedIfCan = muted
            }
            if let bidNotify = extractBool(options, key: "bidNotify") {
                slot.mediation.bidNotify = bidNotify
            }
            if let scenarioId = extractString(options, key: "scenarioId") {
                slot.mediation.scenarioID = scenarioId
            }

            // 使用正确的初始化方法：initWithSlot:rootViewController:adSize:
            // 预加载场景使用slot方式，需要提供rootViewController
            // 如果无法获取rootViewController，使用window的rootViewController作为备用
            guard let rootVC = getCurrentViewController() ?? UIApplication.shared.keyWindow?.rootViewController else {
                logger.logWarning("Banner预加载失败：无法获取rootViewController，adId=\(adId)")
                continue
            }

            let bannerView = BUNativeExpressBannerView(
                slot: slot,
                rootViewController: rootVC,
                adSize: adSize
            )
            result.append(bannerView)
        }
        return result
    }

    // MARK: - 生命周期管理

    /**
     * 销毁SDK管理器
     * 实现协议要求
     */
    func destroy() {
        logger.logInfo("SdkManager开始销毁")

        // SDK管理器通常不需要特别的销毁逻辑
        // SDK生命周期由系统管理
        isSdkInitialized = false
        validationHelper.updateSdkInitialized(false)
        lastInitOptions = nil
        temporaryConfigFiles.forEach { try? fileManager.removeItem(at: $0) }
        temporaryConfigFiles.removeAll()

        eventHelper.sendAdEvent("sdk_manager_destroyed", posId: "", extra: nil)
        logger.logInfo("SdkManager销毁完成")
    }

    // MARK: - 辅助方法

    /**
     * 检查SDK初始化状态
     */
    func isSdkReady() -> Bool {
        return isSdkInitialized
    }
}

private final class GromorePrivacyProvider: NSObject, BUAdSDKPrivacyProvider {
    private let values: [String: Any]

    init(values: [String: Any]) {
        self.values = values
        super.init()
    }

    func canUseLocation() -> Bool {
        return values["canUseLocation"] as? Bool ?? false
    }

    func latitude() -> CLLocationDegrees {
        return (values["latitude"] as? NSNumber)?.doubleValue ?? 0
    }

    func longitude() -> CLLocationDegrees {
        return (values["longitude"] as? NSNumber)?.doubleValue ?? 0
    }

    func canUseWiFiBSSID() -> Bool {
        return values["canUseWifiBssid"] as? Bool ?? true
    }

    func privacyConfig() -> [AnyHashable: Any]? {
        return values["iosPrivacyConfig"] as? [AnyHashable: Any]
    }
}
