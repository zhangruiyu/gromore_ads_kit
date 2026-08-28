package com.zhecent.gromore_ads_kit.utils

import android.util.Log
import com.bytedance.sdk.openadsdk.mediation.manager.MediationBaseManager
import com.bytedance.sdk.openadsdk.mediation.manager.MediationAdEcpmInfo
import com.zhecent.gromore_ads_kit.common.AdConstants

/**
 * 广告日志工具类
 * 负责统一的广告日志记录和错误处理
 */
class AdLogger {

    /**
     * 记录广告请求日志
     */
    fun logAdRequest(adType: String, posId: String, params: Map<String, Any> = emptyMap()) {
        val paramsStr = if (params.isNotEmpty()) {
            params.entries.joinToString(", ") { "${it.key}=${it.value}" }
        } else {
            "无额外参数"
        }
        Log.d(AdConstants.TAG, "[$adType] 请求广告 - 广告位:$posId, 参数:[$paramsStr]")
    }

    /**
     * 记录广告成功日志
     */
    fun logAdSuccess(adType: String, action: String, posId: String, extra: String? = null) {
        val extraStr = if (extra != null) " - $extra" else ""
        Log.d(AdConstants.TAG, "[$adType] $action 成功 - 广告位:$posId$extraStr")
    }

    /**
     * 记录广告错误日志
     */
    fun logAdError(adType: String, action: String, posId: String, errorCode: Int, errorMsg: String) {
        val chineseMsg = getChineseErrorMessage(errorCode, errorMsg)
        Log.e(AdConstants.TAG, "[$adType] $action 失败 - 广告位:$posId, 错误码:$errorCode, 错误信息:$chineseMsg")
    }

    /**
     * 记录广告详细信息
     */
    fun logAdDetailInfo(mediationManager: MediationBaseManager?) {
        if (mediationManager == null) return

        try {
            val showEcpm = mediationManager.showEcpm
            if (showEcpm != null) {
                logEcpmInfo(showEcpm)
            }

            // 广告加载信息暂时注释掉，可能API不同
            // val loadInfo = mediationManager.adLoadInfo
            // if (loadInfo != null && loadInfo.isNotEmpty()) {
            //     Log.d(AdConstants.TAG, "广告加载信息: 共${loadInfo.size}个ADN参与")
            // }
        } catch (e: Exception) {
            Log.w(AdConstants.TAG, "获取广告详细信息失败", e)
        }
    }

    /**
     * 记录ECPM信息
     */
    private fun logEcpmInfo(ecpmInfo: MediationAdEcpmInfo) {
        Log.d(AdConstants.TAG, "广告ECPM信息: \n" +
                "SDK名称: ${ecpmInfo.getSdkName()}\n" +
                "自定义SDK名称: ${ecpmInfo.getCustomSdkName()}\n" +
                "代码位ID: ${ecpmInfo.getSlotId()}\n" +
                "ECPM价格: ${ecpmInfo.getEcpm()}分\n" +
                "竞价类型: ${ecpmInfo.getReqBiddingType()}\n" +
                "请求ID: ${ecpmInfo.getRequestId()}\n" +
                "代码位类型: ${ecpmInfo.getRitType()}\n" +
                "AB测试ID: ${ecpmInfo.getAbTestId()}\n" +
                "场景ID: ${ecpmInfo.getScenarioId()}\n" +
                "流量分组ID: ${ecpmInfo.getSegmentId()}\n" +
                "渠道: ${ecpmInfo.getChannel()}\n" +
                "子渠道: ${ecpmInfo.getSubChannel()}")
    }

    /**
     * 记录广告对象复用警告
     */
    fun logAdObjectReuse(adType: String) {
        Log.w(AdConstants.TAG, "[$adType] 检测到广告对象可能被重复使用，建议每次展示后销毁广告实例")
    }

    /**
     * 获取中文错误信息
     */
    private fun getChineseErrorMessage(errorCode: Int, originalMessage: String): String {
        return when (errorCode) {
            // 通用错误码
            -1 -> "网络错误"
            -2 -> "参数错误"
            -3 -> "广告位不存在或已关闭"
            -4 -> "广告素材下载失败"
            -5 -> "广告频次限制"
            -6 -> "包名与广告位不匹配"
            -7 -> "广告位类型不匹配"
            -8 -> "广告位已过期"
            -9 -> "用户网络环境异常"
            -10 -> "广告填充率低，暂无广告返回"

            // SDK初始化相关
            4001 -> "SDK初始化失败"
            4002 -> "SDK未初始化"
            4003 -> "AppID无效"
            4004 -> "配置文件错误"

            // 广告加载相关
            20001 -> "广告请求参数错误"
            20002 -> "网络请求失败"
            20003 -> "广告解析失败"
            20004 -> "广告素材加载超时"
            20005 -> "广告已过期"
            20006 -> "重复请求"
            20007 -> "请求过于频繁"

            // 广告展示相关
            30001 -> "广告未加载完成"
            30002 -> "广告已展示过"
            30003 -> "Activity异常"
            30004 -> "广告渲染失败"
            30005 -> "广告展示超时"

            // 开屏广告特有
            40001 -> "开屏广告尺寸不匹配"
            40002 -> "开屏广告logo路径无效"

            // 插屏/激励视频特有
            50001 -> "视频素材下载失败"
            50002 -> "视频播放异常"
            50003 -> "奖励验证失败"

            // 信息流广告特有
            60001 -> "信息流广告渲染失败"
            60002 -> "信息流广告尺寸异常"

            else -> originalMessage.ifBlank { "未知错误" }
        }
    }

    /**
     * 记录广告生命周期
     */
    fun logAdLifecycle(adType: String, posId: String, action: String) {
        Log.i(AdConstants.TAG, "[$adType] 生命周期 - 广告位:$posId, 动作:$action")
    }

    /**
     * 记录性能指标
     */
    fun logPerformanceMetric(adType: String, posId: String, metric: String, value: Long) {
        Log.d(AdConstants.TAG, "[$adType] 性能指标 - 广告位:$posId, 指标:$metric, 值:${value}ms")
    }

    companion object {
        @Volatile
        private var INSTANCE: AdLogger? = null

        /**
         * 获取单例实例
         */
        fun getInstance(): AdLogger {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: AdLogger().also { INSTANCE = it }
            }
        }
    }
}
