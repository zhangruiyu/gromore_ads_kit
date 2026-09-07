#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint gromore_ads_kit.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'gromore_ads_kit'
  s.version          = '1.0.1'
  s.summary          = 'Flutter GroMore 广告插件的 iOS 实现'
  s.description      = <<-DESC
  基于穿山甲 GroMore SDK 的 Flutter 广告插件，支持开屏、插屏、
  Banner、激励视频、信息流和 Draw 信息流等广告形式。
                       DESC
  s.homepage         = 'https://github.com/zhangruiyu/gromore_ads_kit'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'zhangruiyu' => '157418979@qq.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'

  # GroMore 聚合 SDK（包含 BUAdSDK）
  s.dependency 'Ads-CN-Beta/CSJMediation', '7.8.0.2'

  # 原生 SDK 和 Adapter 必须成对存在，否则 GroMore 初始化时只会识别到一半。
  s.dependency 'GDTMobSDK', '4.15.90'
  s.dependency 'BaiduMobAdSDK', '10.050'
  s.dependency 'SigmobAd-iOS', '5.1.2'
  s.dependency 'KSAdSDK', '5.5.10.1'

  # 新版 Adapter 尚未发布到 CocoaPods Trunk，按官方手动集成方式随插件分发。
  # iOS 官方预览工具也由插件统一携带，宿主不需要再修改 Podfile。
  s.vendored_frameworks = [
    'Vendor/CSJMGdtAdapter/CSJMGdtAdapter.xcframework',
    'Vendor/CSJMBaiduAdapter/CSJMBaiduAdapter.xcframework',
    'Vendor/CSJMSigmobAdapter/CSJMSigmobAdapter.xcframework',
    'Vendor/CSJMKsAdapter/CSJMKsAdapter.xcframework',
    'GroMoreDebugTools/Vendor/BUAdTestMeasurement.xcframework'
  ]
  s.resources = ['GroMoreDebugTools/Vendor/BUAdTestMeasurement.bundle']

  s.platform = :ios, '13.0'
  s.static_framework = true

  # 插件直接使用的系统框架。Ads-CN自身依赖由其Podspec管理。
  s.frameworks = ['UIKit', 'AdSupport', 'AppTrackingTransparency']

  # GroMore官方要求的系统库。
  s.libraries = ['c++', 'c++abi', 'sqlite3', 'z']

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'OTHER_LDFLAGS' => '-ObjC'
  }
  s.swift_version = '5.0'

  # Privacy manifest for App Store compliance
  s.resource_bundles = {'gromore_ads_kit_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
