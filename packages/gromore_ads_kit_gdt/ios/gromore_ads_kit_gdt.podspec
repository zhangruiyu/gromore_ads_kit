Pod::Spec.new do |s|
  s.name = 'gromore_ads_kit_gdt'
  s.version = '1.0.0'
  s.summary = 'GroMore 优量汇可选适配包'
  s.description = '为 gromore_ads_kit 提供优量汇原生 SDK 和 GroMore Adapter。'
  s.homepage = 'https://github.com/zhangruiyu/gromore_ads_kit'
  s.license = { :file => '../LICENSE' }
  s.author = { 'zhangruiyu' => '157418979@qq.com' }
  s.source = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.dependency 'Ads-CN-Beta/CSJMediation', '7.8.0.2'
  s.dependency 'GDTMobSDK', '4.15.90'
  s.vendored_frameworks = 'Vendor/CSJMGdtAdapter/CSJMGdtAdapter.xcframework'
  s.platform = :ios, '13.0'
  s.static_framework = true
  s.frameworks = ['UIKit', 'AdSupport', 'AppTrackingTransparency']
  s.libraries = ['c++', 'c++abi', 'sqlite3', 'z']
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'OTHER_LDFLAGS' => '-ObjC'
  }
  s.swift_version = '5.0'
end
