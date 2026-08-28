import Foundation
import Flutter
import UIKit
import BUAdSDK

/**
 * 信息流广告管理器（iOS）
 * 采用 BUNativeExpressAdManager 直接加载模板信息流广告
 */
class FeedAdManager: BaseAdManager, FeedAdManagerProtocol {
    typealias ListAdRequest = BaseAdManager.ListAdRequest
    struct FeedAdPayload {
        let posId: String
        let view: BUNativeExpressAdView
    }

    private struct FeedAdEntry {
        let payload: FeedAdPayload
        let createdAt: Date = Date()
    }

    // 工具类实例由 BaseAdManager 提供

    // 缓存信息流广告视图
    private var feedAdsCache: [Int: FeedAdEntry] = [:]
    private var adIdCounter: Int = 0

    // 当前状态
    private var currentPosId: String = ""
    private var isLoading: Bool = false
    private var expectedCount: Int = 0

    // 加载回调
    private var currentLoadResult: FlutterResult?

    // 持有当前的广告管理器
    private var expressAdManager: BUNativeExpressAdManager?

    /**
     * 批量加载信息流广告
     */
    func loadBatch(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if isLoading {
            logger.logWarning("信息流广告正在加载中，无法重复请求")
            result(createFlutterError(code: AdConstants.ErrorCodes.frequentRequest, message: "广告正在加载中"))
            return
        }

        guard let request = prepareListAdRequest(
            call,
            adType: AdConstants.AdType.feed,
            defaultWidth: 300.0,
            defaultHeight: 150.0,
            result: result
        ) else {
            return
        }

        loadFeedAds(request: request, flutterResult: result)
    }

    /**
     * 批量清除信息流广告
     */
    func clearBatch(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let adIds: [Int] = getArgumentValue(call, key: "list", defaultValue: []) else {
            result(createFlutterError(code: AdConstants.ErrorCodes.invalidParams, message: "广告ID列表格式错误"))
            return
        }

        var removedCount = 0
        for adId in adIds {
            if let entry = feedAdsCache.removeValue(forKey: adId) {
                removedCount += 1
                DispatchQueue.main.async {
                    entry.payload.view.removeFromSuperview()
                }
                logger.logAdSuccess(AdConstants.AdType.feed, action: "销毁", posId: entry.payload.posId, message: "adId=\(adId)")
                eventHelper.sendAdEvent(
                    AdConstants.Events.feedDestroyed,
                    posId: entry.payload.posId,
                    extra: ["adId": adId, "reason": "clear"]
                )
            }
        }

        logger.logInfo("清除了 \(removedCount) 个信息流广告，剩余 \(feedAdsCache.count) 个")
        result(true)
    }

    /**
     * 销毁所有广告
     */
    func destroyAll() {
        logger.logInfo("销毁所有信息流广告，当前数量: \(feedAdsCache.count)")
        for (adId, entry) in feedAdsCache {
            DispatchQueue.main.async {
                entry.payload.view.removeFromSuperview()
            }
            logger.logAdSuccess(AdConstants.AdType.feed, action: "销毁", posId: entry.payload.posId, message: "adId=\(adId)")
            eventHelper.sendAdEvent(
                AdConstants.Events.feedDestroyed,
                posId: entry.payload.posId,
                extra: ["adId": adId, "reason": "destroy_all"]
            )
        }
        feedAdsCache.removeAll()
        adIdCounter = 0
        currentPosId = ""
        isLoading = false
        currentLoadResult = nil
        expressAdManager = nil
    }

    /**
     * 获取并移除信息流广告视图，避免重复使用
     */
    func takeFeedAd(adId: Int) -> FeedAdPayload? {
        guard let entry = feedAdsCache.removeValue(forKey: adId) else {
            logger.logAdError(AdConstants.AdType.feed, action: "取用", posId: currentPosId, errorCode: -1, errorMessage: "广告未找到 adId=\(adId)")
            return nil
        }
        return entry.payload
    }

    func isReady(adId: Int) -> Bool {
        return feedAdsCache[adId]?.payload.view.isReady ?? false
    }

    func getAdLoadInfo(adId: Int) -> [[String: Any]] {
        guard feedAdsCache[adId] != nil else { return [] }
        return AdDiagnosticsHelper.map(
            expressAdManager?.mediation?.getAdLoadInfoList(),
            adType: "feed"
        )
    }

    // MARK: - 私有方法

    private func loadFeedAds(request: ListAdRequest, flutterResult: @escaping FlutterResult) {
        isLoading = true
        currentPosId = request.posId
        expectedCount = request.count
        currentLoadResult = flutterResult

        let slot = BUAdSlot()
        slot.id = request.posId
        slot.adType = BUAdSlotAdType.feed
        slot.position = BUAdSlotPosition.feed
        setSlotMutedIfSupported(slot)

        let mediation = slot.mediation
        if let mutedIfCan = request.options["mutedIfCan"] as? Bool {
            mediation.mutedIfCan = mutedIfCan
        }
        if let bidNotify = request.options["bidNotify"] as? Bool {
            mediation.bidNotify = bidNotify
        }
        if let scenarioId = request.options["scenarioId"] as? String, !scenarioId.isEmpty {
            mediation.scenarioID = scenarioId
        }
        if let extraParams = request.options["extra"] as? [String: Any], !extraParams.isEmpty {
            logger.logWarning("当前 iOS Feed 广告暂不支持 extra 透传，已忽略: \(extraParams)")
        }

        let imageSize = BUSize()
        imageSize.width = Int(request.width)
        imageSize.height = Int(request.height)
        slot.imgSize = imageSize
        slot.adSize = CGSize(width: request.width, height: request.height)

        let adSize = CGSize(width: request.width, height: request.height)
        let manager = BUNativeExpressAdManager(slot: slot, adSize: adSize)
        manager.delegate = self
        expressAdManager = manager

        logger.logManagerState(AdConstants.AdType.feed, posId: request.posId, state: "开始加载 \(request.count) 个广告")
        manager.loadAdData(withCount: request.count)
    }

}

// MARK: - BUNativeExpressAdViewDelegate

extension FeedAdManager: BUNativeExpressAdViewDelegate, BUCustomEventProtocol {
    func nativeExpressAdSuccess(toLoad nativeExpressAd: BUNativeExpressAdManager, views: [BUNativeExpressAdView]) {
        isLoading = false

        guard !views.isEmpty else {
            logger.logAdError(AdConstants.AdType.feed, action: "加载", posId: currentPosId, errorCode: -1, errorMessage: "返回的广告视图为空")
            if let result = currentLoadResult {
                result(createFlutterError(code: AdConstants.ErrorCodes.loadError, message: "信息流广告加载失败：返回的广告视图为空"))
                currentLoadResult = nil
            }
            return
        }

        var adIds: [Int] = []

        for view in views {
            let adId = adIdCounter
            adIdCounter += 1

            view.removeFromSuperview()
            view.backgroundColor = .clear
            let payload = FeedAdPayload(posId: currentPosId, view: view)
            feedAdsCache[adId] = FeedAdEntry(payload: payload)
            adIds.append(adId)

            eventHelper.sendAdEvent(
                AdConstants.Events.feedLoaded,
                posId: currentPosId,
                extra: ["adId": adId]
            )
        }

        logger.logAdSuccess(AdConstants.AdType.feed, action: "加载", posId: currentPosId, message: "成功加载 \(views.count) 个信息流广告")
        eventHelper.sendFeedEvent(AdConstants.Events.feedLoaded, posId: currentPosId, extra: ["count": views.count])

        if let result = currentLoadResult {
            result(adIds)
            currentLoadResult = nil
        }
    }

    func nativeExpressAdFail(_ nativeExpressAd: BUNativeExpressAdManager, error: Error?) {
        nativeExpressAdFail(toLoad: nativeExpressAd, error: error)
    }

    func nativeExpressAdFail(toLoad nativeExpressAd: BUNativeExpressAdManager, error: Error?) {
        isLoading = false

        let errorMessage = error?.localizedDescription ?? "未知错误"
        let errorCode = (error as NSError?)?.code ?? -1

        logger.logAdError(AdConstants.AdType.feed, action: "加载", posId: currentPosId, errorCode: errorCode, errorMessage: errorMessage)
        eventHelper.sendErrorEvent(adType: AdConstants.AdType.feed, posId: currentPosId, errorCode: errorCode, errorMessage: errorMessage)

        if let result = currentLoadResult {
            result(createFlutterError(code: AdConstants.ErrorCodes.loadError, message: "信息流广告加载失败: \(errorMessage)", details: errorCode))
            currentLoadResult = nil
        }
    }

    func nativeExpressAdView(_ nativeExpressAdView: BUNativeExpressAdView, dislikeWithReason filterWords: [BUDislikeWords]?) {
        let removedAdIds = feedAdsCache.filter { $0.value.payload.view == nativeExpressAdView }.map { $0.key }
        for adId in removedAdIds {
            if let entry = feedAdsCache.removeValue(forKey: adId) {
                logger.logAdSuccess(AdConstants.AdType.feed, action: "销毁", posId: entry.payload.posId, message: "adId=\(adId)")
                eventHelper.sendAdEvent(AdConstants.Events.feedDestroyed, posId: entry.payload.posId, extra: ["adId": adId, "reason": "dislike"])
            }
        }
    }

    private func setSlotMutedIfSupported(_ slot: BUAdSlot) {
        let selector = NSSelectorFromString("setMutedIfCan:")
        if slot.responds(to: selector) {
            slot.perform(selector, with: NSNumber(value: true))
            return
        }

        let legacySelector = NSSelectorFromString("setIsMutedIfCan:")
        if slot.responds(to: legacySelector) {
            slot.perform(legacySelector, with: NSNumber(value: true))
            return
        }

        logger.logWarning("BUAdSlot 未提供静音配置接口，posId=\(currentPosId)")
    }
}
