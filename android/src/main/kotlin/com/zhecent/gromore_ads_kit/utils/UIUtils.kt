package com.zhecent.gromore_ads_kit.utils

import android.content.Context

/**
 * UI工具类，用于屏幕密度转换等功能
 */
object UIUtils {

    /**
     * 将dp值转换为px值
     * @param context 上下文
     * @param dpValue dp值
     * @return px值
     */
    @JvmStatic
    fun dp2px(context: Context, dpValue: Int): Int {
        val density = context.resources.displayMetrics.density
        return (dpValue * density + 0.5f).toInt()
    }

    /**
     * 将dp值转换为px值（浮点数版本）
     * @param context 上下文
     * @param dpValue dp值
     * @return px值
     */
    @JvmStatic
    fun dp2px(context: Context, dpValue: Float): Int {
        val density = context.resources.displayMetrics.density
        return (dpValue * density + 0.5f).toInt()
    }
}