package com.zhecent.gromore_ads_kit.utils

import com.bytedance.sdk.openadsdk.mediation.manager.MediationBaseManager

object AdDiagnosticsHelper {
    fun getAdLoadInfo(manager: MediationBaseManager?): List<Map<String, Any>> {
        return manager?.adLoadInfo?.map { info ->
            mapOf(
                "mediationRit" to (info.mediationRit ?: ""),
                "adnName" to (info.adnName ?: ""),
                "adType" to (info.adType ?: ""),
                "errorCode" to info.errCode,
                "errorMessage" to (info.errMsg ?: "")
            )
        } ?: emptyList()
    }
}
