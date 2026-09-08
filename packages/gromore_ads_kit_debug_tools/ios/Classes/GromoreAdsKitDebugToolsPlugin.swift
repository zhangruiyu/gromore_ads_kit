import Flutter
import UIKit
#if DEBUG
import BUAdTestMeasurement
#endif

/// GroMore 官方广告测试工具，只允许从 Debug 构建进入。
public class GromoreAdsKitDebugToolsPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "gromore_ads_kit_debug_tools",
            binaryMessenger: registrar.messenger()
        )
        let instance = GromoreAdsKitDebugToolsPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard call.method == "launchTestTools" else {
            result(FlutterMethodNotImplemented)
            return
        }

        #if DEBUG
        DispatchQueue.main.async {
            guard let rootViewController = Self.currentViewController() else {
                result(FlutterError(
                    code: "ACTIVITY_ERROR",
                    message: "无法获取当前 ViewController",
                    details: nil
                ))
                return
            }
            let configuration = BUAdTestMeasurementConfiguration()
            configuration.debugMode = true
            BUAdTestMeasurementManager.showTestMeasurement(with: rootViewController)
            result(true)
        }
        #else
        result(FlutterError(
            code: "DEBUG_ONLY",
            message: "GroMore 官方测试工具仅支持 Debug 构建",
            details: nil
        ))
        #endif
    }

    private static func currentViewController() -> UIViewController? {
        let rootViewController = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController

        var current = rootViewController
        while let presented = current?.presentedViewController {
            current = presented
        }
        return current
    }
}
