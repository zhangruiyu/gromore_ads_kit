import Foundation
import BUAdSDK

enum AdDiagnosticsHelper {
    static func map(_ list: [BUMAdLoadInfo]?, adType: String) -> [[String: Any]] {
        return list?.map { info in
            var item: [String: Any] = [
                "mediationRit": info.mediationRit,
                "adnName": info.adnName,
                "adType": adType,
                "errorCode": info.errCode,
                "errorMessage": info.errMsg
            ]
            if let customAdnName = info.customAdnName {
                item["customAdnName"] = customAdnName
            }
            if let errorUserInfo = info.errUserInfo {
                item["errorUserInfo"] = errorUserInfo
            }
            return item
        } ?? []
    }
}
