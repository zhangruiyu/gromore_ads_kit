package com.zhecent.gromore_ads_kit.managers

import android.app.Activity
import android.content.Context
import android.content.pm.ApplicationInfo
import android.net.Uri
import android.util.Log
import android.widget.ImageView
import io.flutter.embedding.engine.plugins.FlutterPlugin
import com.bytedance.sdk.openadsdk.*
import com.bytedance.sdk.openadsdk.mediation.IMediationManager
import com.bytedance.sdk.openadsdk.mediation.IMediationPreloadRequestInfo
import com.bytedance.sdk.openadsdk.mediation.MediationConstant
import com.bytedance.sdk.openadsdk.mediation.MediationPreloadRequestInfo
import com.bytedance.sdk.openadsdk.mediation.ad.MediationAdSlot
import com.bytedance.sdk.openadsdk.mediation.init.MediationConfig
import com.bytedance.sdk.openadsdk.mediation.init.MediationPrivacyConfig
import com.bumptech.glide.Glide
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import com.zhecent.gromore_ads_kit.common.AdConstants
import com.zhecent.gromore_ads_kit.common.BaseSdkManager
import com.zhecent.gromore_ads_kit.utils.AdEventHelper
import com.zhecent.gromore_ads_kit.utils.AdValidationHelper
import com.zhecent.gromore_ads_kit.utils.AdLogger
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject
import java.io.File
import java.io.FileInputStream
import java.io.InputStreamReader
import java.nio.charset.StandardCharsets
import java.lang.reflect.Proxy
import java.util.Locale

/**
 * SDK管理器
 * 负责GroMore SDK的初始化、配置、预加载和测试工具管理
 * 从主插件中分离出来，实现职责分离
 */
class SdkManager(
    eventHelper: AdEventHelper,
    validationHelper: AdValidationHelper = AdValidationHelper.getInstance(),
    logger: AdLogger = AdLogger.getInstance(),
    private val applicationContext: Context,
    private val flutterAssets: FlutterPlugin.FlutterAssets
) : BaseSdkManager(eventHelper, validationHelper, logger) {

    companion object {
        private const val TAG = AdConstants.TAG
    }

    // SDK初始化状态
    private var isSdkInitialized = false
    private var lastInitOptions: InitOptions? = null

    fun isReady(): Boolean = isSdkInitialized && TTAdSdk.isSdkReady()

    /**
     * 初始化广告SDK
     * 负责处理本地配置、隐私参数以及重复初始化的容错
     */
    fun initAd(call: MethodCall, result: Result) {
        val appId = call.argument<String>("appId")?.trim()
        val useMediation = call.argument<Boolean>("useMediation")
        val debugMode = call.argument<Boolean>("debugMode")
        val limitPersonalAds = call.argument<Int>("limitPersonalAds")
        val limitProgrammaticAds = call.argument<Int>("limitProgrammaticAds")
        val themeStatus = call.argument<Int>("themeStatus")
        val ageGroup = call.argument<Int>("ageGroup")
        // Android特有参数：多进程支持
        // 不设置默认值，让SDK使用原生默认行为
        // 对应iOS：无此参数，iOS采用单进程架构
        val supportMultiProcess = call.argument<Boolean>("supportMultiProcess")
        val privacy = PrivacyOptions.from(call.argument<Map<String, Any?>>("privacy"))
        val configParam: Any? = call.argument("config")

        if (appId.isNullOrEmpty()) {
            result.error(AdConstants.ErrorCodes.INVALID_POS_ID, "AppId不能为空", null)
            return
        }

        if (useMediation == null) {
            result.error(AdConstants.ErrorCodes.INVALID_PARAMS, "useMediation参数是必需的", null)
            return
        }

        if (debugMode == null) {
            result.error(AdConstants.ErrorCodes.INVALID_PARAMS, "debugMode参数是必需的", null)
            return
        }

        val configResult = resolveAdvancedConfig(configParam)

        val logParams = mutableMapOf<String, Any>(
            "useMediation" to useMediation,
            "debugMode" to debugMode
        )
        supportMultiProcess?.let { logParams["supportMultiProcess"] = it }
        configResult.source?.let { logParams["configSource"] = it }
        limitPersonalAds?.let { logParams["limitPersonalAds"] = it }
        limitProgrammaticAds?.let { logParams["limitProgrammaticAds"] = it }
        themeStatus?.let { logParams["themeStatus"] = it }
        ageGroup?.let { logParams["ageGroup"] = it }

        logger.logAdRequest("SDK", appId, logParams)

        val customController = createTTCustomController(
            ageGroup,
            limitPersonalAds,
            limitProgrammaticAds,
            privacy
        )
        val initOptions = InitOptions(
            appId = appId,
            useMediation = useMediation,
            debugMode = debugMode,
            supportMultiProcess = supportMultiProcess,
            limitPersonalAds = limitPersonalAds,
            limitProgrammaticAds = limitProgrammaticAds,
            themeStatus = themeStatus,
            ageGroup = ageGroup,
            configSignature = configResult.json?.toString()?.hashCode()?.toString()
        )

        if (isSdkInitialized && TTAdSdk.isSdkReady()) {
            val compatible = lastInitOptions?.isCompatibleWith(initOptions) ?: false
            if (compatible) {
                lastInitOptions = initOptions
                applyPostInitSettings(themeStatus, customController)
                logger.logAdSuccess("SDK", "重复初始化", appId, "复用现有实例")
                eventHelper.sendAdEvent(
                    "sdk_init_reused",
                    appId,
                    mapOf(
                        "sdkReady" to TTAdSdk.isSdkReady(),
                        "limitPersonalAds" to (limitPersonalAds ?: -1),
                        "limitProgrammaticAds" to (limitProgrammaticAds ?: -1),
                        "themeStatus" to (themeStatus ?: -1)
                    )
                )
                result.success(true)
                return
            } else {
                val message = "GroMore SDK 已使用 appId=$appId 完成初始化，新的配置与现有配置不兼容"
                logger.logAdError("SDK", "重复初始化", appId, -1, message)
                result.error(AdConstants.ErrorCodes.ALREADY_INITIALIZED, message, null)
                return
            }
        }

        try {
            val builder = TTAdConfig.Builder()
                .appId(appId)
                .useMediation(useMediation)
                .customController(customController)

            // 只在参数存在时才设置，让SDK使用原生默认值
            supportMultiProcess?.let { builder.supportMultiProcess(it) }

            if (debugMode) {
                builder.debug(true)
            }

            ageGroup?.let {
                val sdkAgeGroup = when (it) {
                    2 -> TTAdConstant.MINOR
                    1 -> TTAdConstant.TEENAGER
                    else -> TTAdConstant.ADULT
                }
                builder.setAgeGroup(sdkAgeGroup)
            }

            val mediationConfig = buildMediationConfig(configResult.json)
            mediationConfig?.let { builder.setMediationConfig(it) }

            val ttAdConfig = builder.build()

            logger.logAdLifecycle("SDK", appId, "init_start")
            val initEventMap = mutableMapOf<String, Any>(
                "useMediation" to useMediation,
                "debugMode" to debugMode,
                "hasLocalConfig" to (mediationConfig != null)
            )
            supportMultiProcess?.let { initEventMap["supportMultiProcess"] = it }
            eventHelper.sendAdEvent("sdk_init_start", appId, initEventMap)

            TTAdSdk.init(applicationContext, ttAdConfig)
            val logMessage = "GroMore SDK init 已调用 - appId=$appId, useMediation=$useMediation, debugMode=$debugMode" +
                (supportMultiProcess?.let { ", supportMultiProcess=$it" } ?: "")
            Log.d(TAG, logMessage)

            TTAdSdk.start(object : TTAdSdk.Callback {
                override fun success() {
                    isSdkInitialized = true
                    lastInitOptions = initOptions
                    applyPostInitSettings(themeStatus, customController)

                    val ready = TTAdSdk.isSdkReady()
                    logger.logAdSuccess("SDK", "启动", appId, "SDK准备状态: $ready")
                    eventHelper.sendAdEvent(
                        "sdk_init_success",
                        appId,
                        mapOf(
                            "sdkReady" to ready,
                            "limitPersonalAds" to (limitPersonalAds ?: -1),
                            "limitProgrammaticAds" to (limitProgrammaticAds ?: -1),
                            "themeStatus" to (themeStatus ?: -1)
                        )
                    )
                    result.success(true)
                }

                override fun fail(code: Int, msg: String?) {
                    isSdkInitialized = false
                    val message = msg ?: "未知错误"
                    logger.logAdError("SDK", "启动", appId, code, message)
                    eventHelper.sendAdEvent(
                        "sdk_init_fail",
                        appId,
                        mapOf(
                            "code" to code,
                            "message" to message
                        )
                    )
                    result.error(AdConstants.ErrorCodes.LOAD_ERROR, "GroMore SDK启动失败: $message", code)
                }
            })
        } catch (e: Exception) {
            isSdkInitialized = false
            val message = e.message ?: "未知异常"
            logger.logAdError("SDK", "初始化异常", appId, -1, message)
            eventHelper.sendAdEvent(
                "sdk_init_fail",
                appId,
                mapOf(
                    "code" to -1,
                    "message" to message
                )
            )
            result.error(AdConstants.ErrorCodes.LOAD_ERROR, "GroMore SDK初始化异常: $message", null)
        }
    }

    private data class InitOptions(
        val appId: String,
        val useMediation: Boolean,
        val debugMode: Boolean,
        val supportMultiProcess: Boolean?,  // 可空类型
        val limitPersonalAds: Int?,
        val limitProgrammaticAds: Int?,
        val themeStatus: Int?,
        val ageGroup: Int?,
        val configSignature: String?
    ) {
        fun isCompatibleWith(other: InitOptions): Boolean {
            return appId == other.appId &&
                useMediation == other.useMediation &&
                debugMode == other.debugMode &&
                (supportMultiProcess ?: false) == (other.supportMultiProcess ?: false) &&
                (configSignature ?: "") == (other.configSignature ?: "")
        }
    }

    private data class AdvancedConfigResult(
        val json: JSONObject?,
        val source: String?
    )

    private data class PrivacyOptions(
        val canUseLocation: Boolean?,
        val latitude: Double?,
        val longitude: Double?,
        val canUsePhoneState: Boolean?,
        val imei: String?,
        val canUseWifiState: Boolean?,
        val macAddress: String?,
        val canUseWriteExternal: Boolean?,
        val canUseOaid: Boolean?,
        val oaid: String?,
        val canUseAndroidId: Boolean?,
        val androidId: String?,
        val canUseRecordAudio: Boolean?,
        val canUseMessage: Boolean?,
        val canUseAppList: Boolean?,
        val customAppList: List<String>?,
        val customDeviceImeis: List<String>?,
        val userPrivacyConfig: Map<String, Any>?
    ) {
        companion object {
            fun from(raw: Map<String, Any?>?): PrivacyOptions {
                fun stringList(key: String): List<String>? {
                    return (raw?.get(key) as? List<*>)
                        ?.mapNotNull { it?.toString()?.trim()?.takeIf(String::isNotEmpty) }
                        ?.takeIf(List<String>::isNotEmpty)
                }

                val rawPrivacyMap = raw?.get("userPrivacyConfig") as? Map<*, *>
                val privacyMap = rawPrivacyMap
                    ?.entries
                    ?.associate { it.key.toString() to (it.value ?: "") }
                    ?.takeIf(Map<String, Any>::isNotEmpty)

                return PrivacyOptions(
                    canUseLocation = raw?.get("canUseLocation") as? Boolean,
                    latitude = (raw?.get("latitude") as? Number)?.toDouble(),
                    longitude = (raw?.get("longitude") as? Number)?.toDouble(),
                    canUsePhoneState = raw?.get("canUsePhoneState") as? Boolean,
                    imei = raw?.get("imei") as? String,
                    canUseWifiState = raw?.get("canUseWifiState") as? Boolean,
                    macAddress = raw?.get("macAddress") as? String,
                    canUseWriteExternal = raw?.get("canUseWriteExternal") as? Boolean,
                    canUseOaid = raw?.get("canUseOaid") as? Boolean,
                    oaid = raw?.get("oaid") as? String,
                    canUseAndroidId = raw?.get("canUseAndroidId") as? Boolean,
                    androidId = raw?.get("androidId") as? String,
                    canUseRecordAudio = raw?.get("canUseRecordAudio") as? Boolean,
                    canUseMessage = raw?.get("canUseMessage") as? Boolean,
                    canUseAppList = raw?.get("canUseAppList") as? Boolean,
                    customAppList = stringList("customAppList"),
                    customDeviceImeis = stringList("customDeviceImeis"),
                    userPrivacyConfig = privacyMap
                )
            }
        }
    }

    private fun buildMediationConfig(localConfig: JSONObject?): MediationConfig? {
        if (localConfig == null) return null
        return try {
            MediationConfig.Builder()
                .setCustomLocalConfig(localConfig)
                .build()
        } catch (e: Exception) {
            Log.w(TAG, "构建MediationConfig失败: ${e.message}")
            null
        }
    }

    private fun applyPostInitSettings(themeStatus: Int?, controller: TTCustomController) {
        try {
            val mediationManager = TTAdSdk.getMediationManager()
            mediationManager?.updatePrivacyConfig(controller)
            themeStatus?.let { mediationManager?.setThemeStatus(it) }
        } catch (e: Exception) {
            Log.w(TAG, "应用GroMore后置配置失败: ${e.message}")
        }
    }

    private fun resolveAdvancedConfig(config: Any?): AdvancedConfigResult {
        if (config == null) {
            return AdvancedConfigResult(null, null)
        }
        return when (config) {
            is JSONObject -> AdvancedConfigResult(config, "json-object")
            is Map<*, *> -> AdvancedConfigResult(mapToJSONObject(config), "map")
            is String -> resolveAdvancedConfigFromString(config)
            else -> {
                Log.w(TAG, "config参数类型暂不支持: ${config::class.java.simpleName}")
                AdvancedConfigResult(null, null)
            }
        }
    }

    private fun resolveAdvancedConfigFromString(raw: String): AdvancedConfigResult {
        val trimmed = raw.trim()
        if (trimmed.isEmpty()) {
            return AdvancedConfigResult(null, null)
        }
        return when {
            trimmed.startsWith("{") -> {
                try {
                    AdvancedConfigResult(JSONObject(trimmed), "inline-json")
                } catch (e: JSONException) {
                    Log.w(TAG, "解析内联JSON失败: ${e.message}")
                    AdvancedConfigResult(null, null)
                }
            }

            trimmed.startsWith("file://") -> {
                val uri = Uri.parse(trimmed)
                val json = readJsonFromFile(uri.path)
                AdvancedConfigResult(json, uri.path?.let { "file-uri:$it" })
            }

            trimmed.startsWith("/") -> {
                val json = readJsonFromFile(trimmed)
                AdvancedConfigResult(json, "file-path:$trimmed")
            }

            else -> {
                val assetPath = try {
                    flutterAssets.getAssetFilePathByName(trimmed)
                } catch (e: Exception) {
                    Log.w(TAG, "获取Asset路径失败: ${e.message}")
                    null
                }
                val json = readJsonFromAsset(assetPath)
                if (json != null) {
                    AdvancedConfigResult(json, assetPath?.let { "asset:$it" })
                } else {
                    Log.w(TAG, "未能识别的config参数: $trimmed")
                    AdvancedConfigResult(null, null)
                }
            }
        }
    }

    private fun mapToJSONObject(map: Map<*, *>): JSONObject {
        val json = JSONObject()
        for ((key, value) in map) {
            key ?: continue
            json.put(key.toString(), toJsonValue(value))
        }
        return json
    }

    private fun listToJSONArray(list: List<*>): JSONArray {
        val jsonArray = JSONArray()
        list.forEach { jsonArray.put(toJsonValue(it)) }
        return jsonArray
    }

    private fun toJsonValue(value: Any?): Any? {
        return when (value) {
            null -> JSONObject.NULL
            is Number, is Boolean, is String -> value
            is Map<*, *> -> mapToJSONObject(value)
            is List<*> -> listToJSONArray(value)
            is Array<*> -> listToJSONArray(value.toList())
            is JSONObject -> value
            is JSONArray -> value
            else -> value.toString()
        }
    }

    private fun readJsonFromAsset(assetPath: String?): JSONObject? {
        if (assetPath.isNullOrEmpty()) {
            return null
        }
        return try {
            applicationContext.assets.open(assetPath).use { input ->
                InputStreamReader(input, StandardCharsets.UTF_8).use { reader ->
                    JSONObject(reader.readText())
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "读取Asset配置失败($assetPath): ${e.message}")
            null
        }
    }

    private fun readJsonFromFile(path: String?): JSONObject? {
        if (path.isNullOrEmpty()) {
            return null
        }
        return try {
            val file = File(path)
            if (!file.exists() || !file.isFile) {
                Log.w(TAG, "本地配置文件不存在: $path")
                return null
            }
            FileInputStream(file).use { input ->
                InputStreamReader(input, StandardCharsets.UTF_8).use { reader ->
                    JSONObject(reader.readText())
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "读取本地配置文件失败($path): ${e.message}")
            null
        }
    }

    /**
     * 预加载广告
     * 配合 GroMore 首次预缓存能力，根据 configs 构建各类型请求
     */
    fun preload(call: MethodCall, result: Result) {
        try {
            // 检查Activity可用性
            val errorMsg = checkActivityAvailable()
            if (errorMsg != null) {
                result.error(AdConstants.ErrorCodes.ACTIVITY_ERROR, errorMsg, null)
                return
            }

            // 检查SDK初始化状态
            if (!isSdkInitialized) {
                result.error(AdConstants.ErrorCodes.SDK_NOT_READY, "SDK未初始化或初始化失败", null)
                return
            }

            val preloadConfigs = call.argument<List<Map<String, Any>>>("preloadConfigs")
            if (preloadConfigs.isNullOrEmpty()) {
                logger.logAdError("预加载", "参数校验", "", -1, "preloadConfigs 不能为空")
                result.error(
                    AdConstants.ErrorCodes.INVALID_PARAMS,
                    "preloadConfigs 不能为空",
                    null
                )
                return
            }

            val unsupportedTypes = preloadConfigs.mapNotNull { it["adType"] as? String }
                .map { it.trim() }
                .filter { it == "banner" || it == "draw_feed" }
                .distinct()
            if (unsupportedTypes.isNotEmpty()) {
                result.error(
                    AdConstants.ErrorCodes.INVALID_PARAMS,
                    "GroMore 官方不支持这些广告类型的预加载: ${unsupportedTypes.joinToString()}",
                    null
                )
                return
            }

            handlePreload(call, result, preloadConfigs)
        } catch (e: Exception) {
            Log.e(TAG, "预加载异常", e)
            logger.logAdError("预加载", "异常", "", -1, e.message ?: "未知异常")
            result.error(AdConstants.ErrorCodes.LOAD_ERROR, "预加载异常: ${e.message}", null)
        }
    }

    private fun handlePreload(
        call: MethodCall,
        result: Result,
        preloadConfigs: List<Map<String, Any>>
    ) {
        val rawParallel = call.argument<Int>("parallelNum") ?: 2
        val rawInterval = call.argument<Int>("requestIntervalS") ?: 2

        val parallelNum = sanitizeParallel(rawParallel)
        val requestIntervalS = sanitizeInterval(rawInterval)

        logger.logAdRequest(
            "预加载",
            "",
            mapOf(
                "configCount" to preloadConfigs.size,
                "parallelNum" to parallelNum,
                "requestIntervalS" to requestIntervalS
            )
        )

        val requestInfoList = mutableListOf<IMediationPreloadRequestInfo>()

        preloadConfigs.forEachIndexed { index, config ->
            val adType = (config["adType"] as? String)?.trim()
            val adIds = extractStringList(config["adIds"])
            val options = extractOptions(config["options"])

            if (adType.isNullOrEmpty()) {
                logger.logAdError("预加载", "配置解析", "", -1, "第${index + 1}项缺少 adType 字段")
                return@forEachIndexed
            }
            if (adIds.isEmpty()) {
                logger.logAdError("预加载", "配置解析", "", -1, "第${index + 1}项($adType) 未提供有效的 adIds")
                return@forEachIndexed
            }

            val preloadInfo = when (adType) {
                "reward_video" -> buildRewardPreloadInfo(adIds, options)
                "interstitial" -> buildInterstitialPreloadInfo(adIds, options)
                "feed" -> buildFeedPreloadInfo(adIds, options)
                "draw_feed" -> buildDrawFeedPreloadInfo(adIds, options)
                "banner" -> buildBannerPreloadInfo(adIds, options)
                else -> {
                    logger.logAdError("预加载", "类型不支持", "", -1, "未知的adType=$adType")
                    null
                }
            }

            if (preloadInfo != null) {
                requestInfoList.add(preloadInfo)
                Log.d(TAG, "预加载配置[$index]: type=$adType, ids=${adIds.joinToString()}, options=${options ?: emptyMap<String, Any?>()} ")
            }
        }

        executePreload(requestInfoList, parallelNum, requestIntervalS, result)
    }

    private fun sanitizeParallel(value: Int): Int = value.coerceIn(1, 20)

    private fun sanitizeInterval(value: Int): Int = value.coerceIn(1, 10)

    private fun extractStringList(raw: Any?): List<String> {
        if (raw !is List<*>) return emptyList()
        return raw.mapNotNull { item ->
            when (item) {
                is String -> item.trim().takeIf { it.isNotEmpty() }
                is Number -> item.toString()
                else -> item?.toString()?.takeIf { it.isNotBlank() }
            }
        }
    }

    private fun extractOptions(raw: Any?): Map<String, Any?>? {
        if (raw !is Map<*, *>) return null
        val result = mutableMapOf<String, Any?>()
        raw.forEach { (key, value) ->
            when (key) {
                is String -> result[key] = value
                null -> Unit
                else -> result[key.toString()] = value
            }
        }
        return if (result.isEmpty()) null else result
    }

    private fun parseString(options: Map<String, Any?>?, key: String): String? {
        val value = options?.get(key) ?: return null
        return value.toString().trim().takeIf { it.isNotEmpty() }
    }

    private fun parseInt(options: Map<String, Any?>?, key: String): Int? {
        val value = options?.get(key) ?: return null
        return when (value) {
            is Int -> value
            is Number -> value.toInt()
            is String -> value.trim().toIntOrNull()
            else -> null
        }
    }

    private fun parseFloat(options: Map<String, Any?>?, key: String): Float? {
        val value = options?.get(key) ?: return null
        return when (value) {
            is Float -> value
            is Number -> value.toFloat()
            is String -> value.trim().toFloatOrNull()
            else -> null
        }
    }

    private fun parseBoolean(options: Map<String, Any?>?, key: String): Boolean? {
        val value = options?.get(key) ?: return null
        return when (value) {
            is Boolean -> value
            is Number -> value.toInt() != 0
            is String -> when (value.trim().lowercase(Locale.ROOT)) {
                "1", "true", "yes", "on" -> true
                "0", "false", "no", "off" -> false
                else -> null
            }
            else -> null
        }
    }

    private fun parseMap(options: Map<String, Any?>?, key: String): Map<String, Any?>? {
        return extractOptions(options?.get(key))
    }

    private fun parseCustomData(options: Map<String, Any?>?, key: String, defaultValue: String? = null): String? {
        val value = options?.get(key) ?: return defaultValue
        return when (value) {
            is String -> value.trim().takeIf { it.isNotEmpty() } ?: defaultValue
            is Map<*, *> -> {
                val mapValue = extractOptions(value)
                if (mapValue.isNullOrEmpty()) {
                    defaultValue
                } else {
                    try {
                        JSONObject(mapValue).toString()
                    } catch (e: JSONException) {
                        Log.w(TAG, "预加载自定义参数序列化失败", e)
                        defaultValue
                    }
                }
            }
            else -> defaultValue
        }
    }

    private fun buildRewardPreloadInfo(
        adIds: List<String>,
        options: Map<String, Any?>?
    ): IMediationPreloadRequestInfo {
        val orientation = validationHelper.validateOrientation(
            parseInt(options, "orientation") ?: AdConstants.ORIENTATION_VERTICAL
        )
        val userId = parseString(options, "userId") ?: "preload_user"
        val customData = parseCustomData(options, "customData", "GroMoreAds")
        val rewardName = parseString(options, "rewardName")
        val rewardAmount = parseInt(options, "rewardAmount")
        val mutedIfCan = parseBoolean(options, "mutedIfCan")
        val volume = parseFloat(options, "volume")?.let { validationHelper.validateVolume(it) }
        val bidNotify = parseBoolean(options, "bidNotify")
        val scenarioId = parseString(options, "scenarioId")
        val useSurfaceView = parseBoolean(options, "useSurfaceView")
        val extraParams = parseMap(options, "extraParams")
        val extraData = parseMap(options, "extraData")

        val mediationBuilder = MediationAdSlot.Builder()
        customData?.let { mediationBuilder.setExtraObject(MediationConstant.CUSTOM_DATA_KEY_GROMORE_EXTRA, it) }
        mutedIfCan?.let { mediationBuilder.setMuted(it) }
        volume?.let { mediationBuilder.setVolume(it) }
        bidNotify?.let { mediationBuilder.setBidNotify(it) }
        scenarioId?.let { mediationBuilder.setScenarioId(it) }
        useSurfaceView?.let { mediationBuilder.setUseSurfaceView(it) }
        rewardName?.let { mediationBuilder.setRewardName(it) }
        rewardAmount?.let { mediationBuilder.setRewardAmount(it) }
        extraParams?.forEach { (key, value) -> if (value != null) mediationBuilder.setExtraObject(key, value) }
        extraData?.forEach { (key, value) -> if (value != null) mediationBuilder.setExtraObject(key, value) }

        val adSlot = AdSlot.Builder()
            .setUserID(userId)
            .setOrientation(if (orientation == AdConstants.ORIENTATION_HORIZONTAL) TTAdConstant.HORIZONTAL else TTAdConstant.VERTICAL)
            .setMediationAdSlot(mediationBuilder.build())
            .build()

        return MediationPreloadRequestInfo(AdSlot.TYPE_REWARD_VIDEO, adSlot, adIds)
    }

    private fun buildInterstitialPreloadInfo(
        adIds: List<String>,
        options: Map<String, Any?>?
    ): IMediationPreloadRequestInfo {
        val orientation = validationHelper.validateOrientation(
            parseInt(options, "orientation") ?: AdConstants.ORIENTATION_VERTICAL
        )
        val customData = parseCustomData(options, "customData")
        val rewardName = parseString(options, "rewardName")
        val rewardAmount = parseInt(options, "rewardAmount")
        val mutedIfCan = parseBoolean(options, "mutedIfCan")
        val volume = parseFloat(options, "volume")?.let { validationHelper.validateVolume(it) }
        val bidNotify = parseBoolean(options, "bidNotify")
        val scenarioId = parseString(options, "scenarioId")
        val useSurfaceView = parseBoolean(options, "useSurfaceView")
        val extraParams = parseMap(options, "extraParams")
        val extraData = parseMap(options, "extraData")

        val mediationBuilder = MediationAdSlot.Builder()
        mutedIfCan?.let { mediationBuilder.setMuted(it) }
        volume?.let { mediationBuilder.setVolume(it) }
        bidNotify?.let { mediationBuilder.setBidNotify(it) }
        scenarioId?.let { mediationBuilder.setScenarioId(it) }
        useSurfaceView?.let { mediationBuilder.setUseSurfaceView(it) }
        rewardName?.let { mediationBuilder.setRewardName(it) }
        rewardAmount?.let { mediationBuilder.setRewardAmount(it) }
        customData?.let { mediationBuilder.setExtraObject(MediationConstant.CUSTOM_DATA_KEY_GROMORE_EXTRA, it) }
        extraParams?.forEach { (key, value) -> if (value != null) mediationBuilder.setExtraObject(key, value) }
        extraData?.forEach { (key, value) -> if (value != null) mediationBuilder.setExtraObject(key, value) }

        val adSlot = AdSlot.Builder()
            .setOrientation(if (orientation == AdConstants.ORIENTATION_HORIZONTAL) TTAdConstant.HORIZONTAL else TTAdConstant.VERTICAL)
            .setMediationAdSlot(mediationBuilder.build())
            .build()

        return MediationPreloadRequestInfo(AdSlot.TYPE_FULL_SCREEN_VIDEO, adSlot, adIds)
    }

    private fun buildFeedPreloadInfo(
        adIds: List<String>,
        options: Map<String, Any?>?,
        adSlotType: Int = AdSlot.TYPE_FEED
    ): IMediationPreloadRequestInfo {
        val requestedWidth = parseInt(options, "width") ?: 300
        val requestedHeight = parseInt(options, "height") ?: 125
        val (widthPx, heightPx) = validationHelper.validateAdSize(requestedWidth, requestedHeight)
        val requestedCount = parseInt(options, "count")
        val adCount = requestedCount?.let { validationHelper.validateAdCount(it) } ?: 1

        val mediationBuilder = MediationAdSlot.Builder()
        parseBoolean(options, "mutedIfCan")?.let { mediationBuilder.setMuted(it) }
        parseFloat(options, "volume")?.let { mediationBuilder.setVolume(validationHelper.validateVolume(it)) }
        parseBoolean(options, "bidNotify")?.let { mediationBuilder.setBidNotify(it) }
        parseString(options, "scenarioId")?.let { mediationBuilder.setScenarioId(it) }
        parseBoolean(options, "useSurfaceView")?.let { mediationBuilder.setUseSurfaceView(it) }
        parseMap(options, "extra")?.forEach { (key, value) -> if (value != null) mediationBuilder.setExtraObject(key, value) }
        parseMap(options, "extraData")?.forEach { (key, value) -> if (value != null) mediationBuilder.setExtraObject(key, value) }

        val adSlot = AdSlot.Builder()
            .setImageAcceptedSize(widthPx, heightPx)
            .setAdCount(adCount)
            .setMediationAdSlot(mediationBuilder.build())
            .build()

        return MediationPreloadRequestInfo(adSlotType, adSlot, adIds)
    }

    private fun buildDrawFeedPreloadInfo(
        adIds: List<String>,
        options: Map<String, Any?>?
    ): IMediationPreloadRequestInfo {
        // GroMore SDK 暂未提供单独的 Draw Feed 预加载类型，沿用 Feed 类型入参即可命中缓存
        return buildFeedPreloadInfo(adIds, options, AdSlot.TYPE_FEED)
    }

    private fun buildBannerPreloadInfo(
        adIds: List<String>,
        options: Map<String, Any?>?
    ): IMediationPreloadRequestInfo {
        val requestedWidth = parseInt(options, "width") ?: 375
        val requestedHeight = parseInt(options, "height") ?: 60
        val (widthPx, heightPx) = validationHelper.validateAdSize(requestedWidth, requestedHeight)

        val mediationBuilder = MediationAdSlot.Builder()
        parseBoolean(options, "mutedIfCan")?.let { mediationBuilder.setMuted(it) }
        parseFloat(options, "volume")?.let { mediationBuilder.setVolume(validationHelper.validateVolume(it)) }
        parseBoolean(options, "bidNotify")?.let { mediationBuilder.setBidNotify(it) }
        parseString(options, "scenarioId")?.let { mediationBuilder.setScenarioId(it) }
        parseBoolean(options, "useSurfaceView")?.let { mediationBuilder.setUseSurfaceView(it) }
        parseMap(options, "extraParams")?.forEach { (key, value) -> if (value != null) mediationBuilder.setExtraObject(key, value) }
        parseMap(options, "extraData")?.forEach { (key, value) -> if (value != null) mediationBuilder.setExtraObject(key, value) }

        val adSlot = AdSlot.Builder()
            .setImageAcceptedSize(widthPx, heightPx)
            .setMediationAdSlot(mediationBuilder.build())
            .build()

        return MediationPreloadRequestInfo(AdSlot.TYPE_BANNER, adSlot, adIds)
    }

    /**
     * 执行预加载
     */
    private fun executePreload(requestInfoList: List<IMediationPreloadRequestInfo>, concurrent: Int, interval: Int, result: Result) {
        if (requestInfoList.isEmpty()) {
            logger.logAdError("预加载", "配置为空", "", -1, "没有有效的预加载配置")
            result.error(AdConstants.ErrorCodes.INVALID_PARAMS, "预加载配置为空或无效", null)
            return
        }

        try {
            val mediationManager: IMediationManager? = TTAdSdk.getMediationManager()
            if (mediationManager != null) {
                Log.d(TAG, "开始执行预加载: ${requestInfoList.size}个配置, concurrent=$concurrent, interval=${interval}s")
                mediationManager.preload(getCurrentActivity(), requestInfoList, concurrent, interval)

                logger.logAdSuccess("预加载", "执行", "", "配置数量: ${requestInfoList.size}")
                eventHelper.sendAdEvent("preload_success", "", mapOf(
                    "configCount" to requestInfoList.size,
                    "concurrent" to concurrent,
                    "interval" to interval
                ))

                result.success(true)
            } else {
                logger.logAdError("预加载", "MediationManager为空", "", -1, "获取MediationManager失败")
                result.error(AdConstants.ErrorCodes.SDK_NOT_READY, "MediationManager不可用", null)
            }
        } catch (e: Exception) {
            logger.logAdError("预加载", "执行异常", "", -1, e.message ?: "未知异常")
            result.error(AdConstants.ErrorCodes.LOAD_ERROR, "预加载执行异常: ${e.message}", null)
        }
    }

    /**
     * 启动测试工具
     * 从GromoreAdsKitPlugin迁移而来
     */
    fun launchTestTools(call: MethodCall, result: Result) {
        try {
            val isDebuggable = applicationContext.applicationInfo.flags and
                ApplicationInfo.FLAG_DEBUGGABLE != 0
            if (!isDebuggable) {
                val message = "GroMore测试工具仅允许在Debug构建中使用"
                logger.logAdError("测试工具", "启动失败", "", -1, message)
                result.error(AdConstants.ErrorCodes.SHOW_ERROR, message, null)
                return
            }

            if (!isSdkInitialized || !TTAdSdk.isSdkReady()) {
                val message = "GroMore SDK未初始化或尚未完成启动，请先调用 initAd"
                logger.logAdError("测试工具", "启动失败", "", -1, message)
                result.error(AdConstants.ErrorCodes.SDK_NOT_READY, message, null)
                return
            }

            val errorMsg = checkActivityAvailable()
            if (errorMsg != null) {
                result.error(AdConstants.ErrorCodes.ACTIVITY_ERROR, errorMsg, null)
                return
            }

            logger.logAdRequest("测试工具", "", emptyMap())
            Log.d(TAG, "启动GroMore测试工具")
            val activity = getCurrentActivity()
            if (activity == null) {
                val message = "无法获取当前Activity，测试工具无法启动"
                logger.logAdError("测试工具", "启动失败", "", -1, message)
                result.error(AdConstants.ErrorCodes.ACTIVITY_ERROR, message, null)
                return
            }

            // tools-release.aar 由 GroMore 后台按当前 SDK 配置生成，插件不内置固定旧版本。
            val toolClass = Class.forName("com.bytedance.mtesttools.api.TTMediationTestTool")
            val callbackClass = Class.forName("com.bytedance.mtesttools.api.TTMediationTestTool\$ImageCallBack")
            val imageCallback = Proxy.newProxyInstance(
                callbackClass.classLoader,
                arrayOf(callbackClass)
            ) { _, method, args ->
                if (method.name == "loadImage") {
                    val imageView = args?.getOrNull(0) as? ImageView
                    val url = args?.getOrNull(1) as? String
                    loadTestToolImage(imageView, url)
                }
                null
            }
            toolClass
                .getMethod("launchTestTools", Context::class.java, callbackClass)
                .invoke(null, activity, imageCallback)

            Log.d(TAG, "GroMore测试工具已启动")
            eventHelper.sendAdEvent("test_tools_launched", "", emptyMap())
            result.success(true)

        } catch (e: Throwable) {
            Log.e(TAG, "启动测试工具失败", e)
            val reason = when (e) {
                is ClassNotFoundException, is NoClassDefFoundError ->
                    "未找到GroMore测试工具依赖，请确认已引入 tools-release.aar"
                else -> e.message ?: "未知异常"
            }
            logger.logAdError("测试工具", "启动失败", "", -1, reason)
            eventHelper.sendAdEvent(
                "test_tools_failed",
                "",
                mapOf("reason" to reason)
            )
            result.error(AdConstants.ErrorCodes.SHOW_ERROR, "启动测试工具失败: $reason", null)
        }
    }

    /**
     * 权限申请（Android特有）
     */
    fun requestPermissionIfNecessary(call: MethodCall, result: Result) {
        try {
            // 在Android上，GroMore SDK会自动处理权限
            // 这里可以添加额外的权限检查逻辑
            Log.d(TAG, "权限申请处理完成")
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "权限申请异常", e)
            result.error(AdConstants.ErrorCodes.LOAD_ERROR, "权限申请异常: ${e.message}", null)
        }
    }

    /**
     * 创建TTCustomController
     * 根据年龄组设置隐私控制
     */
    private fun createTTCustomController(
        ageGroup: Int?,
        limitPersonalAds: Int?,
        limitProgrammaticAds: Int?,
        privacy: PrivacyOptions
    ): TTCustomController {
        val resolvedAgeGroup = when (ageGroup) {
            2 -> TTAdConstant.MINOR
            1 -> TTAdConstant.TEENAGER
            else -> TTAdConstant.ADULT
        }
        val limitPersonal = limitPersonalAds == 1
        val limitProgrammatic = limitProgrammaticAds == 1

        return object : TTCustomController() {
            override fun isCanUseLocation(): Boolean = privacy.canUseLocation ?: false

            override fun getTTLocation(): LocationProvider? {
                val latitude = privacy.latitude ?: return null
                val longitude = privacy.longitude ?: return null
                return TTLocation(latitude, longitude)
            }

            override fun alist(): Boolean = privacy.canUseAppList ?: false
            override fun isCanUsePhoneState(): Boolean = privacy.canUsePhoneState ?: false
            override fun getDevImei(): String? = privacy.imei
            override fun isCanUseWifiState(): Boolean = privacy.canUseWifiState ?: true
            override fun getMacAddress(): String? = privacy.macAddress
            override fun isCanUseWriteExternal(): Boolean = privacy.canUseWriteExternal ?: false
            override fun getDevOaid(): String? = privacy.oaid

            override fun isCanUseAndroidId(): Boolean {
                return privacy.canUseAndroidId ?: (resolvedAgeGroup != TTAdConstant.MINOR)
            }

            override fun getAndroidId(): String? = privacy.androidId

            override fun isCanUsePermissionRecordAudio(): Boolean {
                return privacy.canUseRecordAudio ?: (resolvedAgeGroup != TTAdConstant.MINOR)
            }

            override fun isCanUseMessage(): Boolean = privacy.canUseMessage ?: false

            override fun userPrivacyConfig(): MutableMap<String, Any>? {
                return privacy.userPrivacyConfig?.toMutableMap()
            }

            override fun getMediationPrivacyConfig(): MediationPrivacyConfig {
                return object : MediationPrivacyConfig() {
                    override fun getCustomAppList(): MutableList<String>? {
                        return privacy.customAppList?.toMutableList()
                    }

                    override fun getCustomDevImeis(): MutableList<String>? {
                        return privacy.customDeviceImeis?.toMutableList()
                    }

                    override fun isCanUseOaid(): Boolean = privacy.canUseOaid ?: true
                    override fun isLimitPersonalAds(): Boolean = limitPersonal
                    override fun isProgrammaticRecommend(): Boolean = !limitProgrammatic
                }
            }
        }
    }

    private fun loadTestToolImage(imageView: ImageView?, url: String?) {
        Log.d(TAG, "测试工具请求加载图片: $url")
        try {
            val activity = getCurrentActivity()
            if (imageView != null && !url.isNullOrEmpty() && activity != null) {
                Glide.with(activity)
                    .load(url)
                    .into(imageView)
                Log.d(TAG, "图片加载成功: $url")
            }
        } catch (e: Exception) {
            Log.w(TAG, "测试工具图片加载异常: ${e.message}")
        }
    }

    /**
     * 销毁SDK管理器
     * 实现BaseAdManager的抽象方法
     */
    override fun destroy() {
        // SDK管理器通常不需要特别的销毁逻辑
        // SDK生命周期由系统管理
        logger.logAdLifecycle("SDK_MANAGER", "", "SDK管理器销毁完成")
    }
}
