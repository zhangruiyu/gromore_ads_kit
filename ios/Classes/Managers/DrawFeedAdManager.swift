import Foundation
import Flutter
import UIKit
import BUAdSDK

/**
 * Draw信息流广告管理器（iOS）
 * 使用 BUNativeExpressAdManager 加载模板 Draw 广告
 */
class DrawFeedAdManager: BaseAdManager, FeedAdManagerProtocol {
    typealias ListAdRequest = BaseAdManager.ListAdRequest
    struct DrawFeedAdPayload {
        let posId: String
        let view: BUNativeExpressAdView
    }

    private struct DrawFeedEntry {
        let payload: DrawFeedAdPayload
        let createdAt: Date = Date()
    }

    private var drawAdsCache: [Int: DrawFeedEntry] = [:]
    private var adIdCounter: Int = 1

    private var currentPosId: String = ""
    private var isLoading: Bool = false
    private var expectedCount: Int = 0

    private var currentLoadResult: FlutterResult?
    private var expressAdManager: BUNativeExpressAdManager?

    func loadBatch(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if isLoading {
            logger.logWarning("Draw信息流广告正在加载中，无法重复请求")
            result(createFlutterError(code: AdConstants.ErrorCodes.frequentRequest, message: "广告正在加载中"))
            return
        }

        guard let request = prepareListAdRequest(
            call,
            adType: AdConstants.AdType.drawFeed,
            defaultWidth: 300.0,
            defaultHeight: 340.0,
            result: result
        ) else {
            return
        }

        loadDrawAds(request: request, flutterResult: result)
    }

    func clearBatch(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let adIds: [Int] = getArgumentValue(call, key: "list", defaultValue: []) else {
            result(createFlutterError(code: AdConstants.ErrorCodes.invalidParams, message: "广告ID列表格式错误"))
            return
        }

        var removedCount = 0
        for adId in adIds {
            if let entry = drawAdsCache.removeValue(forKey: adId) {
                removedCount += 1
                DispatchQueue.main.async {
                    entry.payload.view.removeFromSuperview()
                }
                logger.logAdSuccess(AdConstants.AdType.drawFeed, action: "销毁", posId: entry.payload.posId, message: "adId=\(adId)")
                eventHelper.sendAdEvent(
                    AdConstants.Events.drawFeedDestroyed,
                    posId: entry.payload.posId,
                    extra: ["adId": adId, "reason": "clear"]
                )
            }
        }

        logger.logInfo("清除了 \(removedCount) 个Draw信息流广告，剩余 \(drawAdsCache.count) 个")
        result(true)
    }

    func destroyAll() {
        logger.logInfo("销毁所有Draw信息流广告，当前数量: \(drawAdsCache.count)")
        for (adId, entry) in drawAdsCache {
            DispatchQueue.main.async {
                entry.payload.view.removeFromSuperview()
            }
            logger.logAdSuccess(AdConstants.AdType.drawFeed, action: "销毁", posId: entry.payload.posId, message: "adId=\(adId)")
            eventHelper.sendAdEvent(
                AdConstants.Events.drawFeedDestroyed,
                posId: entry.payload.posId,
                extra: ["adId": adId, "reason": "destroy_all"]
            )
        }
        drawAdsCache.removeAll()
        adIdCounter = 1
        currentPosId = ""
        isLoading = false
        currentLoadResult = nil
        expressAdManager = nil
    }

    func takeDrawFeedAd(adId: Int) -> DrawFeedAdPayload? {
        guard let entry = drawAdsCache.removeValue(forKey: adId) else {
            logger.logAdError(AdConstants.AdType.drawFeed, action: "取用", posId: currentPosId, errorCode: -1, errorMessage: "广告未找到 adId=\(adId)")
            return nil
        }
        return entry.payload
    }

    func isReady(adId: Int) -> Bool {
        return drawAdsCache[adId]?.payload.view.isReady ?? false
    }

    func getAdLoadInfo(adId: Int) -> [[String: Any]] {
        guard drawAdsCache[adId] != nil else { return [] }
        return AdDiagnosticsHelper.map(
            expressAdManager?.mediation?.getAdLoadInfoList(),
            adType: "drawFeed"
        )
    }

    // MARK: - Private helpers

    private func loadDrawAds(request: ListAdRequest, flutterResult: @escaping FlutterResult) {
        isLoading = true
        currentPosId = request.posId
        expectedCount = request.count
        currentLoadResult = flutterResult

        let slot = BUAdSlot()
        slot.id = request.posId
        slot.adType = BUAdSlotAdType.drawVideo
        slot.position = BUAdSlotPosition.feed
        setSlotMutedIfSupported(slot)

        let mediation = slot.mediation
        if let mutedIfCan = request.options["mutedIfCan"] as? Bool {
            mediation.mutedIfCan = mutedIfCan
        }
        if let volume = request.options["volume"] as? Double {
            logger.logWarning("当前 iOS Draw 信息流不支持 volume 参数，已忽略: \(volume)")
        }
        if let bidNotify = request.options["bidNotify"] as? Bool {
            mediation.bidNotify = bidNotify
        }
        if let scenarioId = request.options["scenarioId"] as? String, !scenarioId.isEmpty {
            mediation.scenarioID = scenarioId
        }
        if let extraParams = request.options["extra"] as? [String: Any], !extraParams.isEmpty {
            logger.logWarning("当前 iOS Draw 信息流暂不支持 extra 透传，已忽略: \(extraParams)")
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

        logger.logManagerState(AdConstants.AdType.drawFeed, posId: request.posId, state: "开始加载 \(request.count) 个Draw广告")
        manager.loadAdData(withCount: request.count)
    }

}

// MARK: - BUNativeExpressAdViewDelegate

extension DrawFeedAdManager: BUNativeExpressAdViewDelegate, BUCustomEventProtocol {
    func nativeExpressAdSuccess(toLoad nativeExpressAd: BUNativeExpressAdManager, views: [BUNativeExpressAdView]) {
        isLoading = false

        guard !views.isEmpty else {
            logger.logAdError(AdConstants.AdType.drawFeed, action: "加载", posId: currentPosId, errorCode: -1, errorMessage: "返回的广告视图为空")
            if let result = currentLoadResult {
                result(createFlutterError(code: AdConstants.ErrorCodes.loadError, message: "Draw信息流广告加载失败：返回的广告视图为空"))
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
            let payload = DrawFeedAdPayload(posId: currentPosId, view: view)
            drawAdsCache[adId] = DrawFeedEntry(payload: payload)
            adIds.append(adId)

            eventHelper.sendAdEvent(
                AdConstants.Events.drawFeedLoaded,
                posId: currentPosId,
                extra: ["adId": adId]
            )
        }

        logger.logAdSuccess(AdConstants.AdType.drawFeed, action: "加载", posId: currentPosId, message: "成功加载 \(views.count) 个Draw广告")
        eventHelper.sendAdEvent(AdConstants.Events.drawFeedLoaded, posId: currentPosId, extra: ["count": views.count])

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

        logger.logAdError(AdConstants.AdType.drawFeed, action: "加载", posId: currentPosId, errorCode: errorCode, errorMessage: errorMessage)
        eventHelper.sendErrorEvent(adType: AdConstants.AdType.drawFeed, posId: currentPosId, errorCode: errorCode, errorMessage: errorMessage)

        if let result = currentLoadResult {
            result(createFlutterError(code: AdConstants.ErrorCodes.loadError, message: "Draw信息流广告加载失败: \(errorMessage)", details: errorCode))
            currentLoadResult = nil
        }
    }

    func nativeExpressAdView(_ nativeExpressAdView: BUNativeExpressAdView, dislikeWithReason filterWords: [BUDislikeWords]?) {
        let removedAdIds = drawAdsCache.filter { $0.value.payload.view == nativeExpressAdView }.map { $0.key }
        for adId in removedAdIds {
            if let entry = drawAdsCache.removeValue(forKey: adId) {
                logger.logAdSuccess(AdConstants.AdType.drawFeed, action: "销毁", posId: entry.payload.posId, message: "adId=\(adId)")
                eventHelper.sendAdEvent(AdConstants.Events.drawFeedDestroyed, posId: entry.payload.posId, extra: ["adId": adId, "reason": "dislike"])
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
