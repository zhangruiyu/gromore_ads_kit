package com.zhecent.gromore_ads_kit.views

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.graphics.Color
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import com.bumptech.glide.Glide
import com.bytedance.sdk.openadsdk.TTNativeAd
import com.bytedance.sdk.openadsdk.TTAdDislike
import com.bytedance.sdk.openadsdk.mediation.ad.IMediationViewBinder
import com.bytedance.sdk.openadsdk.mediation.ad.IMediationNativeAdInfo
import com.bytedance.sdk.openadsdk.mediation.ad.IMediationDislikeCallback
import com.bytedance.sdk.openadsdk.mediation.ad.MediationViewBinder
import com.zhecent.gromore_ads_kit.R
import com.zhecent.gromore_ads_kit.utils.UIUtils

internal data class NativeAdLayout(
    val root: LinearLayout,
    val clickViews: List<View>,
    val creativeViews: List<View>,
    val dislikeButton: Button,
    val binder: IMediationViewBinder
)

internal fun Context.findActivity(): Activity? {
    var current: Context? = this
    while (current is ContextWrapper) {
        if (current is Activity) return current
        current = current.baseContext
    }
    return current as? Activity
}

internal fun buildMixedBannerView(
    activity: Activity,
    info: IMediationNativeAdInfo,
    widthPx: Int,
    heightPx: Int,
    onDislike: (String) -> Unit
): View {
    val root = LayoutInflater.from(activity)
        .inflate(R.layout.gromore_mixed_banner_ad, null, false) as LinearLayout
    val imageView = root.findViewById<ImageView>(R.id.gromore_banner_image)
    val titleView = root.findViewById<TextView>(R.id.gromore_banner_title)
    val actionButton = root.findViewById<Button>(R.id.gromore_banner_action)
    val dislikeButton = root.findViewById<Button>(R.id.gromore_banner_dislike)
    titleView.text = info.title.orEmpty()
    actionButton.text = info.actionText?.takeIf(String::isNotBlank) ?: "查看"

    val imageUrl = info.imageUrl?.takeIf(String::isNotBlank)
        ?: info.iconUrl?.takeIf(String::isNotBlank)
    imageUrl?.let { Glide.with(activity).load(it).into(imageView) }

    val binder = MediationViewBinder.Builder(R.layout.gromore_mixed_banner_ad)
        .titleId(R.id.gromore_banner_title)
        .mainImageId(R.id.gromore_banner_image)
        .callToActionId(R.id.gromore_banner_action)
        .build()
    info.registerView(
        activity,
        root,
        listOf(root, titleView),
        listOf(actionButton, imageView),
        emptyList(),
        binder
    )

    if (info.hasDislike()) {
        val dialog = info.getDislikeDialog(activity)
        dialog.setDislikeCallback(object : IMediationDislikeCallback {
            override fun onShow() {}
            override fun onSelected(position: Int, value: String?) {
                onDislike(value ?: "dislike")
            }
            override fun onCancel() {}
        })
        dislikeButton.setOnClickListener { dialog.showDislikeDialog() }
    } else {
        dislikeButton.visibility = View.GONE
    }

    root.layoutParams = ViewGroup.LayoutParams(
        if (widthPx > 0) widthPx else ViewGroup.LayoutParams.MATCH_PARENT,
        if (heightPx > 0) heightPx else UIUtils.dp2px(activity, 60)
    )
    return root
}

internal fun buildNativeAdLayout(
    context: Context,
    ad: TTNativeAd,
    widthPx: Int,
    heightPx: Int
): NativeAdLayout {
    val root = LayoutInflater.from(context)
        .inflate(R.layout.gromore_native_ad, null, false) as LinearLayout
    root.layoutParams = ViewGroup.LayoutParams(
        if (widthPx > 0) widthPx else ViewGroup.LayoutParams.MATCH_PARENT,
        if (heightPx > 0) heightPx else ViewGroup.LayoutParams.WRAP_CONTENT
    )
    val iconView = root.findViewById<ImageView>(R.id.gromore_native_icon)
    val titleView = root.findViewById<TextView>(R.id.gromore_native_title)
    val dislikeButton = root.findViewById<Button>(R.id.gromore_native_dislike)
    val descriptionView = root.findViewById<TextView>(R.id.gromore_native_description)
    val mediaContainer = root.findViewById<FrameLayout>(R.id.gromore_native_media)
    val mainImage = root.findViewById<ImageView>(R.id.gromore_native_main_image)
    val actionButton = root.findViewById<Button>(R.id.gromore_native_action)

    titleView.text = ad.title.orEmpty()
    descriptionView.text = ad.description.orEmpty()
    actionButton.text = ad.buttonText?.takeIf(String::isNotBlank) ?: "查看详情"

    val sdkMediaView = ad.adView
    if (sdkMediaView != null) {
        (sdkMediaView.parent as? ViewGroup)?.removeView(sdkMediaView)
        mainImage.visibility = View.GONE
        mediaContainer.addView(sdkMediaView, FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        ))
    } else {
        ad.imageList?.firstOrNull()?.imageUrl?.takeIf(String::isNotBlank)?.let { url ->
            Glide.with(context).load(url).into(mainImage)
        }
    }

    ad.icon?.imageUrl?.takeIf(String::isNotBlank)?.let { url ->
        Glide.with(context).load(url).into(iconView)
    }

    val binder = MediationViewBinder.Builder(R.layout.gromore_native_ad)
        .titleId(R.id.gromore_native_title)
        .descriptionTextId(R.id.gromore_native_description)
        .callToActionId(R.id.gromore_native_action)
        .iconImageId(R.id.gromore_native_icon)
        .mainImageId(R.id.gromore_native_main_image)
        .mediaViewIdId(R.id.gromore_native_media)
        .build()

    return NativeAdLayout(
        root = root,
        clickViews = listOf(root, titleView, descriptionView),
        creativeViews = listOf(actionButton, mediaContainer),
        dislikeButton = dislikeButton,
        binder = binder
    )
}
