import Foundation
import UIKit

/**
 * 广告验证助手类
 * 负责广告请求的各种验证逻辑
 */
class AdValidationHelper {

    // 单例实例
    static let shared = AdValidationHelper()

    // 记录上次请求时间
    private var lastRequestTimes: [String: Int64] = [:]
    private var sdkInitialized = false

    private init() {}

    /**
     * 执行基础检查
     */
    func performBasicChecks(adType: String, posId: String) -> String? {
        if !sdkInitialized {
            AdLogger.shared.logAdError(adType, action: "验证", posId: posId, errorCode: -1, errorMessage: "SDK未初始化")
            return "SDK未初始化或初始化失败"
        }

        // 检查广告位ID是否为空
        if posId.isEmpty {
            AdLogger.shared.logAdError(adType, action: "验证", posId: posId, errorCode: -1, errorMessage: "广告位ID不能为空")
            return "广告位ID不能为空"
        }

        // 检查是否频繁请求
        if isFrequentRequest(posId: posId) {
            AdLogger.shared.logWarning("广告位 \(posId) 请求过于频繁，请稍后再试")
            return "请求过于频繁，请稍后再试"
        }

        // 检查当前是否在主线程
        if !Thread.isMainThread {
            AdLogger.shared.logWarning("广告请求必须在主线程中执行")
        }

        return nil
    }

    func updateSdkInitialized(_ initialized: Bool) {
        sdkInitialized = initialized
    }

    /**
     * 检查是否频繁请求
     */
    func isFrequentRequest(posId: String) -> Bool {
        let currentTime = Int64(Date().timeIntervalSince1970 * 1000)

        if let lastTime = lastRequestTimes[posId] {
            let timeDiff = currentTime - lastTime
            if timeDiff < AdConstants.minRequestInterval {
                AdLogger.shared.logDebug("广告位 \(posId) 距离上次请求仅 \(timeDiff)ms，小于最小间隔 \(AdConstants.minRequestInterval)ms")
                return true
            }
        }

        return false
    }

    /**
     * 更新请求时间
     */
    func updateRequestTime(posId: String) {
        let currentTime = Int64(Date().timeIntervalSince1970 * 1000)
        lastRequestTimes[posId] = currentTime
        AdLogger.shared.logDebug("更新广告位 \(posId) 请求时间: \(currentTime)")
    }

    /**
     * 验证必需参数
     */
    func validateRequiredParams(_ params: [String: Any], requiredKeys: [String]) -> String? {
        for key in requiredKeys {
            if params[key] == nil {
                let errorMessage = "缺少必需参数: \(key)"
                AdLogger.shared.logAdError("参数验证", action: "验证", posId: "", errorCode: -1, errorMessage: errorMessage)
                return errorMessage
            }
        }
        return nil
    }

    /**
     * 验证广告位ID格式
     */
    func validatePosIdFormat(_ posId: String) -> Bool {
        // 基本格式验证：不为空，长度合理
        if posId.isEmpty || posId.count > 50 {
            return false
        }

        // 可以添加更多格式验证规则
        return true
    }

    /**
     * 验证应用状态
     */
    func validateAppState() -> String? {
        // 检查应用是否在前台
        let appState = UIApplication.shared.applicationState
        if appState != .active {
            let stateDesc = getAppStateDescription(appState)
            AdLogger.shared.logWarning("应用当前状态: \(stateDesc)，建议在应用激活状态下请求广告")
            // 不阻止请求，只是记录警告
        }

        return nil
    }

    /**
     * 获取应用状态描述
     */
    private func getAppStateDescription(_ state: UIApplication.State) -> String {
        switch state {
        case .active:
            return "激活"
        case .inactive:
            return "未激活"
        case .background:
            return "后台"
        @unknown default:
            return "未知"
        }
    }

    /**
     * 清理过期的请求时间记录
     */
    func cleanupOldRequestTimes() {
        let currentTime = Int64(Date().timeIntervalSince1970 * 1000)
        let expireTime = AdConstants.adCacheTimeout * 10 // 10倍缓存时间后清理

        let keysToRemove = lastRequestTimes.compactMap { key, time in
            (currentTime - time > expireTime) ? key : nil
        }

        for key in keysToRemove {
            lastRequestTimes.removeValue(forKey: key)
        }

        if !keysToRemove.isEmpty {
            AdLogger.shared.logDebug("清理了 \(keysToRemove.count) 个过期的请求时间记录")
        }
    }
}
