import Foundation
import Flutter

/**
 * 广告事件助手类
 * 负责事件的统一发送和管理
 */
class AdEventHelper {

    // 单例实例
    static let shared = AdEventHelper()

    // 事件通道回调
    private var eventSink: FlutterEventSink?

    private init() {}

    /**
     * 更新事件回调
     */
    func updateEventSink(_ sink: FlutterEventSink?) {
        eventSink = sink
        NSLog("\(AdConstants.TAG) 事件通道已更新: \(sink != nil ? "已连接" : "已断开")")
    }

    /**
     * 发送广告事件
     */
    func sendAdEvent(_ eventType: String, posId: String, extra: [String: Any]? = nil) {
        guard let eventSink = eventSink else {
            NSLog("\(AdConstants.TAG) 事件通道未连接，无法发送事件: \(eventType)")
            return
        }

        var eventData: [String: Any] = [
            "action": eventType,
            "posId": posId,
            "timestamp": Date().timeIntervalSince1970 * 1000
        ]

        // 合并额外数据
        if let extra = extra {
            if !extra.isEmpty {
                eventData["extra"] = extra
            }
        }

        // 在主线程发送事件
        DispatchQueue.main.async {
            eventSink(eventData)
            NSLog("\(AdConstants.TAG) 发送事件: \(eventType), posId: \(posId)")
        }
    }

    /**
     * 发送开屏广告事件
     */
    func sendSplashEvent(_ eventType: String, posId: String, extra: [String: Any]? = nil) {
        sendAdEvent(eventType, posId: posId, extra: extra)
    }

    /**
     * 发送插屏广告事件
     */
    func sendInterstitialEvent(_ eventType: String, posId: String, extra: [String: Any]? = nil) {
        sendAdEvent(eventType, posId: posId, extra: extra)
    }

    /**
     * 发送激励视频事件
     */
    func sendRewardVideoEvent(_ eventType: String, posId: String, extra: [String: Any]? = nil) {
        sendAdEvent(eventType, posId: posId, extra: extra)
    }

    /**
     * 发送信息流广告事件
     */
    func sendFeedEvent(_ eventType: String, posId: String, extra: [String: Any]? = nil) {
        sendAdEvent(eventType, posId: posId, extra: extra)
    }

    /**
     * 发送展示事件
     */
    func sendShowEvent(_ adType: String, posId: String, extra: [String: Any]? = nil) {
        let action = "\(adType)_showed"
        sendAdEvent(action, posId: posId, extra: extra)
    }

    /**
     * 发送点击事件
     */
    func sendClickEvent(_ adType: String, posId: String, extra: [String: Any]? = nil) {
        let action = "\(adType)_clicked"
        sendAdEvent(action, posId: posId, extra: extra)
    }

    /**
     * 发送关闭事件
     */
    func sendCloseEvent(_ adType: String, posId: String, extra: [String: Any]? = nil) {
        let action = "\(adType)_closed"
        sendAdEvent(action, posId: posId, extra: extra)
    }

    /**
     * 发送Banner广告事件
     */
    func sendBannerEvent(_ eventType: String, posId: String, extra: [String: Any]? = nil) {
        sendAdEvent(eventType, posId: posId, extra: extra)
    }

    /**
     * 发送错误事件
     */
    func sendErrorEvent(adType: String, posId: String, errorCode: Int, errorMessage: String) {
        let eventType = "\(adType)_load_fail"
        let extra: [String: Any] = [
            "code": errorCode,
            "message": errorMessage,
            "adType": adType
        ]
        sendAdEvent(eventType, posId: posId, extra: extra)
    }

    /**
     * 发送Banner错误事件
     */
    func sendBannerErrorEvent(_ eventType: String, message: String, posId: String, code: Int? = nil) {
        var extra: [String: Any] = [
            "message": message,
            "adType": "banner"
        ]

        if let errorCode = code {
            extra["code"] = errorCode
        }

        sendAdEvent(eventType, posId: posId, extra: extra)
    }
}
