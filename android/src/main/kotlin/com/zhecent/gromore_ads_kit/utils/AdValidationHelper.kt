package com.zhecent.gromore_ads_kit.utils

import android.app.Activity
import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import com.bytedance.sdk.openadsdk.TTAdSdk
import com.zhecent.gromore_ads_kit.common.AdConstants

/**
 * 广告验证工具类
 * 负责广告请求前的各种验证工作
 */
class AdValidationHelper {

    // 存储上次请求时间，用于防止频繁请求
    private val lastRequestTimeMap = mutableMapOf<String, Long>()

    /**
     * 执行基础检查
     * @param adType 广告类型
     * @param posId 广告位ID
     * @param activity 当前Activity
     * @return 错误信息，null表示检查通过
     */
    fun performBasicChecks(adType: String, posId: String, activity: Activity?): String? {
        // 检查广告位ID
        if (posId.isBlank()) {
            return "广告位ID不能为空"
        }

        // 检查Activity
        if (activity == null) {
            return "Activity不可用"
        }

        // 检查SDK初始化状态
        if (!checkSDKInitStatus()) {
            return "SDK未初始化或初始化失败"
        }

        // 检查网络连接
        if (!isNetworkAvailable(activity)) {
            return "网络连接不可用"
        }

        // 检查请求频率
        if (!canMakeRequest(posId)) {
            return "请求过于频繁，请等待${AdConstants.MIN_REQUEST_INTERVAL / 1000}秒"
        }

        return null
    }

    /**
     * 检查SDK初始化状态
     */
    private fun checkSDKInitStatus(): Boolean {
        return try {
            TTAdSdk.getAdManager() != null && TTAdSdk.isSdkReady()
        } catch (e: Exception) {
            false
        }
    }

    /**
     * 检查网络连接状态
     */
    private fun isNetworkAvailable(activity: Activity): Boolean {
        return try {
            val connectivityManager = activity.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val network = connectivityManager.activeNetwork ?: return false
            val networkCapabilities = connectivityManager.getNetworkCapabilities(network) ?: return false

            networkCapabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ||
                    networkCapabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) ||
                    networkCapabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET)
        } catch (e: Exception) {
            true // 如果无法检查，默认认为网络可用
        }
    }

    /**
     * 检查是否可以发起请求（防止频繁请求）
     */
    private fun canMakeRequest(posId: String): Boolean {
        val currentTime = System.currentTimeMillis()
        val lastTime = lastRequestTimeMap[posId] ?: 0
        return (currentTime - lastTime) >= AdConstants.MIN_REQUEST_INTERVAL
    }

    /**
     * 更新请求时间
     */
    fun updateRequestTime(posId: String) {
        lastRequestTimeMap[posId] = System.currentTimeMillis()
    }

    /**
     * 验证方向参数
     */
    fun validateOrientation(orientation: Int): Int {
        return if (orientation == AdConstants.ORIENTATION_HORIZONTAL) {
            AdConstants.ORIENTATION_HORIZONTAL
        } else {
            AdConstants.ORIENTATION_VERTICAL
        }
    }

    /**
     * 验证广告数量
     */
    fun validateAdCount(count: Int): Int {
        return when {
            count < 1 -> 1
            count > 3 -> 3
            else -> count
        }
    }

    /**
     * 验证广告尺寸
     */
    fun validateAdSize(width: Int, height: Int): Pair<Int, Int> {
        val validWidth = if (width <= 0) 300 else width
        val validHeight = if (height <= 0) 125 else height
        return Pair(validWidth, validHeight)
    }

    /**
     * 验证音量参数
     */
    fun validateVolume(volume: Float): Float {
        return when {
            volume < 0f -> 0f
            volume > 1f -> 1f
            else -> volume
        }
    }

    /**
     * 验证超时时间
     */
    fun validateTimeout(timeout: Double): Double {
        return when {
            timeout <= 0 -> 3.5
            timeout > 10.0 -> 10.0
            else -> timeout
        }
    }

    companion object {
        @Volatile
        private var INSTANCE: AdValidationHelper? = null

        /**
         * 获取单例实例
         */
        fun getInstance(): AdValidationHelper {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: AdValidationHelper().also { INSTANCE = it }
            }
        }
    }
}