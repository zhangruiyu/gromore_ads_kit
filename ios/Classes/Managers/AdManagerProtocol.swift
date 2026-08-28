import Foundation
import Flutter
import UIKit

/**
 * 广告管理器基础协议
 */
protocol AdManagerProtocol {
    /**
     * 加载广告
     */
    func load(_ call: FlutterMethodCall, result: @escaping FlutterResult)

    /**
     * 展示广告
     */
    func show(_ call: FlutterMethodCall, result: @escaping FlutterResult)

    /**
     * 销毁广告
     */
    func destroy()
}

/**
 * 简单广告管理器协议（只有展示方法）
 */
protocol SimpleAdManagerProtocol {
    /**
     * 展示广告
     */
    func show(_ call: FlutterMethodCall, result: @escaping FlutterResult)

    /**
     * 销毁广告
     */
    func destroy()
}

/**
 * 信息流广告管理器协议
 */
protocol FeedAdManagerProtocol {
    /**
     * 批量加载信息流广告
     */
    func loadBatch(_ call: FlutterMethodCall, result: @escaping FlutterResult)

    /**
     * 批量清除信息流广告
     */
    func clearBatch(_ call: FlutterMethodCall, result: @escaping FlutterResult)

    /**
     * 销毁所有广告
     */
    func destroyAll()
}

/**
 * 基础广告管理器类
 */
class BaseAdManager: NSObject {

    // 工具类实例
    internal let eventHelper: AdEventHelper
    internal let validationHelper: AdValidationHelper
    internal let logger: AdLogger

    init(eventHelper: AdEventHelper = AdEventHelper.shared,
         validationHelper: AdValidationHelper = AdValidationHelper.shared,
         logger: AdLogger = AdLogger.shared) {
        self.eventHelper = eventHelper
        self.validationHelper = validationHelper
        self.logger = logger
        super.init()
    }

    /**
     * 从MethodCall中提取参数
     */
    func getArgumentValue<T>(_ call: FlutterMethodCall, key: String, defaultValue: T) -> T {
        if let args = call.arguments as? [String: Any],
           let value = args[key] as? T {
            return value
        }
        return defaultValue
    }

    /**
     * 从MethodCall中提取必需参数
     */
    func getRequiredArgument<T>(_ call: FlutterMethodCall, key: String) -> T? {
        if let args = call.arguments as? [String: Any] {
            return args[key] as? T
        }
        return nil
    }

    /**
     * 创建Flutter错误
     */
    func createFlutterError(code: String, message: String, details: Any? = nil) -> FlutterError {
        return FlutterError(code: code, message: message, details: details)
    }

    /**
     * 获取当前顶级视图控制器
     */
    func getCurrentViewController() -> UIViewController? {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) {
            return keyWindow.rootViewController
        }
        return nil
    }
}

// MARK: - 通用列表广告请求

extension BaseAdManager {
    struct ListAdRequest {
        let posId: String
        let width: Double
        let height: Double
        let count: Int
        let options: [String: Any]
        let requestLog: [String: Any]
    }

    func prepareListAdRequest(
        _ call: FlutterMethodCall,
        adType: String,
        defaultWidth: Double,
        defaultHeight: Double,
        result: @escaping FlutterResult
    ) -> ListAdRequest? {
        guard let posId: String = getRequiredArgument(call, key: "posId") else {
            result(createFlutterError(code: AdConstants.ErrorCodes.invalidPosId, message: "广告位ID不能为空"))
            return nil
        }

        let args = call.arguments as? [String: Any] ?? [:]

        // 修复：不使用强制默认值，要求用户传递width/height
        guard let width = args["width"] as? Double else {
            result(createFlutterError(code: AdConstants.ErrorCodes.invalidParams, message: "width参数必须传递"))
            return nil
        }
        guard let height = args["height"] as? Double else {
            result(createFlutterError(code: AdConstants.ErrorCodes.invalidParams, message: "height参数必须传递"))
            return nil
        }

        // 修复：不限制count范围，让SDK决定
        let count = args["count"] as? Int ?? 1

        if let errorMsg = validationHelper.performBasicChecks(adType: adType, posId: posId) {
            result(createFlutterError(code: AdConstants.ErrorCodes.loadError, message: errorMsg))
            return nil
        }

        validationHelper.updateRequestTime(posId: posId)

        var options: [String: Any] = [:]
        var requestLog: [String: Any] = [
            "width": width,
            "height": height,
            "count": count
        ]

        if let mutedIfCan = args["mutedIfCan"] as? Bool {
            options["mutedIfCan"] = mutedIfCan
            requestLog["mutedIfCan"] = mutedIfCan
        }
        if let bidNotify = args["bidNotify"] as? Bool {
            options["bidNotify"] = bidNotify
            requestLog["bidNotify"] = bidNotify
        }
        if let scenarioId = args["scenarioId"] as? String, !scenarioId.isEmpty {
            options["scenarioId"] = scenarioId
            requestLog["scenarioId"] = scenarioId
        }
        if let extra = args["extra"] {
            options["extra"] = extra
            requestLog["extra"] = extra
        }

        logger.logAdRequest(adType, posId: posId, params: requestLog)

        return ListAdRequest(
            posId: posId,
            width: width,
            height: height,
            count: count,
            options: options,
            requestLog: requestLog
        )
    }
}
