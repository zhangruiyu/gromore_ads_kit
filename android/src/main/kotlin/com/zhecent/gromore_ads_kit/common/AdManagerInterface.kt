package com.zhecent.gromore_ads_kit.common

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result

/**
 * 广告管理器接口
 * 定义所有广告类型管理器的通用方法
 */
interface AdManagerInterface {

    /**
     * 加载广告
     * @param call 方法调用参数
     * @param result 结果回调
     */
    fun load(call: MethodCall, result: Result)

    /**
     * 展示广告
     * @param call 方法调用参数
     * @param result 结果回调
     */
    fun show(call: MethodCall, result: Result)

    /**
     * 销毁广告实例
     */
    fun destroy()

    /**
     * 检查广告是否准备就绪
     * @return 是否可以展示广告
     */
    fun isReady(): Boolean
}

/**
 * 简化的广告管理器接口
 * 适用于只需要展示的广告类型（如开屏广告）
 */
interface SimpleAdManagerInterface {

    /**
     * 展示广告（包含加载和展示）
     * @param call 方法调用参数
     * @param result 结果回调
     */
    fun show(call: MethodCall, result: Result)

    /**
     * 销毁广告实例
     */
    fun destroy()
}

/**
 * 批量管理广告接口
 * 适用于信息流广告等需要管理多个实例的类型
 */
interface BatchAdManagerInterface {

    /**
     * 加载广告列表
     * @param call 方法调用参数
     * @param result 结果回调，返回广告ID列表
     */
    fun loadBatch(call: MethodCall, result: Result)

    /**
     * 清除广告列表
     * @param call 方法调用参数
     * @param result 结果回调
     */
    fun clearBatch(call: MethodCall, result: Result)

    /**
     * 销毁所有广告实例
     */
    fun destroyAll()
}