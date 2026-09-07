Pod::Spec.new do |s|
  s.name = 'GroMoreDebugTools'
  s.version = '1.0.0'
  s.summary = 'GroMore iOS 官方预览工具的 Debug 包装'
  s.description = 'GroMore iOS 官方预览工具的通用二进制包装。'
  s.homepage = 'https://www.csjplatform.com/supportcenter/28563'
  s.license = { :type => 'Commercial', :text => '以穿山甲官方 SDK 下载包内许可为准' }
  s.author = { 'Pangle' => 'union_service@bytedance.com' }
  s.source = { :path => '.' }

  s.platform = :ios, '13.0'
  s.vendored_frameworks = 'Vendor/BUAdTestMeasurement.xcframework'
  s.resources = 'Vendor/BUAdTestMeasurement.bundle'
  s.frameworks = ['UIKit']
end
