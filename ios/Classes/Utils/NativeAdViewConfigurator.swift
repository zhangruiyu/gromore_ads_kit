import UIKit
import BUAdSDK

enum NativeAdViewConfigurator {
    /// 返回 true 表示当前广告是自渲染广告，并且已经完成物料和点击区域配置。
    static func configure(_ adView: BUNativeExpressAdView) -> Bool {
        guard let canvas = adView.mediation,
              !canvas.isExpressAd,
              let data = canvas.data else {
            return false
        }
        configureCanvas(canvas, data: data, container: adView)
        return true
    }

    static func configure(_ canvasView: BUMCanvasView) {
        guard let data = canvasView.data else { return }
        configureCanvas(canvasView, data: data, container: canvasView)
    }

    private static func configureCanvas(
        _ canvas: BUMCanvasViewProtocol,
        data: BUMaterialMeta,
        container: UIView
    ) {
        let bounds = container.bounds.isEmpty
            ? CGRect(x: 0, y: 0, width: 375, height: 150)
            : container.bounds
        let padding: CGFloat = 10
        let closeWidth: CGFloat = 34
        let topHeight: CGFloat = min(48, bounds.height * 0.32)
        let buttonHeight: CGFloat = min(40, max(30, bounds.height * 0.25))

        canvas.titleLabel.text = data.adTitle ?? "广告"
        canvas.titleLabel.font = .boldSystemFont(ofSize: 15)
        canvas.titleLabel.textColor = .label
        canvas.titleLabel.numberOfLines = 2
        addIfNeeded(canvas.titleLabel, to: container)
        canvas.titleLabel.frame = CGRect(
            x: padding,
            y: padding,
            width: max(0, bounds.width - padding * 2 - closeWidth),
            height: topHeight
        )

        canvas.descLabel.text = data.adDescription ?? ""
        canvas.descLabel.font = .systemFont(ofSize: 13)
        canvas.descLabel.textColor = .secondaryLabel
        canvas.descLabel.numberOfLines = 2
        addIfNeeded(canvas.descLabel, to: container)

        let contentTop = padding + topHeight
        let contentBottom = bounds.height - buttonHeight - padding
        canvas.descLabel.frame = CGRect(
            x: padding,
            y: contentTop,
            width: max(0, bounds.width * 0.42 - padding),
            height: max(0, contentBottom - contentTop)
        )

        canvas.imageView.contentMode = .scaleAspectFill
        canvas.imageView.clipsToBounds = true
        addIfNeeded(canvas.imageView, to: container)
        canvas.imageView.frame = CGRect(
            x: bounds.width * 0.44,
            y: contentTop,
            width: max(0, bounds.width * 0.56 - padding),
            height: max(0, contentBottom - contentTop)
        )
        loadImage(data.imageAry?.first?.imageURL, into: canvas.imageView)

        if let mediaView = canvas.mediaView {
            addIfNeeded(mediaView, to: container)
            mediaView.frame = canvas.imageView.frame
        }

        if let icon = data.icon {
            let iconView = canvas.iconImageView ?? UIImageView()
            iconView.contentMode = .scaleAspectFill
            iconView.clipsToBounds = true
            canvas.iconImageView = iconView
            addIfNeeded(iconView, to: container)
            iconView.frame = CGRect(x: padding, y: contentTop, width: 36, height: 36)
            loadImage(icon.imageURL, into: iconView)
        }

        canvas.callToActionBtn.setTitle(data.buttonText ?? "查看详情", for: .normal)
        canvas.callToActionBtn.setTitleColor(.white, for: .normal)
        canvas.callToActionBtn.backgroundColor = UIColor(red: 0.93, green: 0.18, blue: 0.18, alpha: 1)
        canvas.callToActionBtn.layer.cornerRadius = 6
        addIfNeeded(canvas.callToActionBtn, to: container)
        canvas.callToActionBtn.frame = CGRect(
            x: padding,
            y: bounds.height - buttonHeight,
            width: max(0, bounds.width - padding * 2),
            height: buttonHeight - padding
        )

        let dislikeButton = canvas.dislikeBtn ?? UIButton(type: .system)
        dislikeButton.setTitle("×", for: .normal)
        dislikeButton.setTitleColor(.secondaryLabel, for: .normal)
        canvas.dislikeBtn = dislikeButton
        addIfNeeded(dislikeButton, to: container)
        dislikeButton.frame = CGRect(
            x: bounds.width - closeWidth,
            y: 0,
            width: closeWidth,
            height: closeWidth
        )

        var clickableViews: [UIView] = [
            canvas.titleLabel,
            canvas.descLabel,
            canvas.imageView,
            canvas.callToActionBtn
        ]
        if let mediaView = canvas.mediaView { clickableViews.append(mediaView) }
        if let iconImageView = canvas.iconImageView { clickableViews.append(iconImageView) }
        canvas.registerClickableViews(clickableViews)
    }

    private static func addIfNeeded(_ view: UIView, to container: UIView) {
        if view.superview == nil {
            container.addSubview(view)
        }
    }

    private static func loadImage(_ urlString: String?, into imageView: UIImageView) {
        guard let urlString, let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                imageView.image = image
            }
        }.resume()
    }
}
