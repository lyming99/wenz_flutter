#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint window_border.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'window_border'
  s.version          = '0.0.1'
  s.summary          = 'Native frameless window borders for Flutter desktop.'
  s.description      = <<-DESC
Native frameless window borders for Flutter desktop.
                       DESC
  s.homepage         = 'https://github.com/lyming99/wenz_flutter'
  s.license          = { :type => 'Proprietary', :file => '../LICENSE' }
  s.author           = 'WenzFlow'

  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'

  # If your plugin requires a privacy manifest, for example if it collects user
  # data, update the PrivacyInfo.xcprivacy file to describe your plugin's
  # privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'window_border_privacy' => ['Resources/PrivacyInfo.xcprivacy']}

  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.11'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
