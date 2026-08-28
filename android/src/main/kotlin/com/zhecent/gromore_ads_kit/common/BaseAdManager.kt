package com.zhecent.gromore_ads_kit.common

import android.app.Activity
import com.zhecent.gromore_ads_kit.utils.AdEventHelper
import com.zhecent.gromore_ads_kit.utils.AdValidationHelper
import com.zhecent.gromore_ads_kit.utils.AdLogger

/**
 * 基础广告管理器抽象类
 * 统一Activity依赖注入机制和通用功能
 */
abstract class BaseAdManager(
    protected val eventHelper: AdEventHelper,
    protected val validationHelper: AdValidationHelper,
    protected val logger: AdLogger
) {

    // 当前Activity引用（统一管理）
    private var currentActivity: Activity? = null

    /**
     * 设置Activity引用（依赖注入）
     */
    fun setActivity(activity: Activity?) {
        this.currentActivity = activity
    }

    /**
     * 获取当前Activity
     * 统一的Activity获取方法，所有子类都应该使用这个方法
     */
    protected fun getCurrentActivity(): Activity? {
        return currentActivity
    }

    /**
     * 检查Activity可用性
     * @return 错误信息，如果为null表示检查通过
     */
    protected fun checkActivityAvailable(): String? {
        return if (currentActivity == null) {
            "Activity不可用"
        } else {
            null
        }
    }

    /**
     * 抽象方法：销毁资源
     * 每个管理器必须实现自己的销毁逻辑
     */
    abstract fun destroy()
}

/**
 * SDK管理器基类
 * 专门用于SDK相关管理（初始化、配置、测试工具等）
 */
abstract class BaseSdkManager(
    eventHelper: AdEventHelper,
    validationHelper: AdValidationHelper,
    logger: AdLogger
) : BaseAdManager(eventHelper, validationHelper, logger)