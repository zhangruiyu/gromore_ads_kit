Pod::Spec.new do |s|
  s.name = 'gromore_ads_kit_debug_tools'
  s.version = '1.0.0'
  s.summary = 'GroMore 官方广告测试工具调试扩展'
  s.description = '为 gromore_ads_kit 提供 GroMore 官方广告测试工具，仅供本地调试。'
  s.homepage = 'https://github.com/zhangruiyu/gromore_ads_kit'
  s.license = { :file => '../LICENSE' }
  s.author = { 'zhangruiyu' => '157418979@qq.com' }
  s.source = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.dependency 'Ads-CN-Beta/CSJMediation', '7.8.0.2'
  s.vendored_frameworks = 'Vendor/BUAdTestMeasurement.xcframework'
  s.resources = ['Vendor/BUAdTestMeasurement.bundle']
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
