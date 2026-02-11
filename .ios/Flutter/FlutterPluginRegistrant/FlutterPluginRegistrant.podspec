#
# Generated file, do not edit.
#

Pod::Spec.new do |s|
  s.name             = 'FlutterPluginRegistrant'
  s.version          = '0.0.1'
  s.summary          = 'Registers plugins with your Flutter app'
  s.description      = <<-DESC
Depends on all your plugins, and provides a function to register them.
                       DESC
  s.homepage         = 'https://flutter.dev'
  s.license          = { :type => 'BSD' }
  s.author           = { 'Flutter Dev Team' => 'flutter-dev@googlegroups.com' }
  s.ios.deployment_target = '13.0'
  s.source_files =  "Classes", "Classes/**/*.{h,m}"
  s.source           = { :path => '.' }
  s.public_header_files = './Classes/**/*.h'
  s.static_framework    = true
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.dependency 'Flutter'
  s.dependency 'appinio_social_share'
  s.dependency 'blue_thermal_printer'
  s.dependency 'connectivity_plus'
  s.dependency 'device_info_plus'
  s.dependency 'file_picker'
  s.dependency 'firebase_core'
  s.dependency 'firebase_messaging'
  s.dependency 'flutter_blue_plus_darwin'
  s.dependency 'flutter_callkit_incoming'
  s.dependency 'flutter_contacts'
  s.dependency 'flutter_local_notifications'
  s.dependency 'flutter_secure_storage'
  s.dependency 'image_picker_ios'
  s.dependency 'objectbox_flutter_libs'
  s.dependency 'open_file_ios'
  s.dependency 'package_info_plus'
  s.dependency 'permission_handler_apple'
  s.dependency 'pos_universal_printer_ios'
  s.dependency 'printing'
  s.dependency 'share_plus'
  s.dependency 'shared_preferences_foundation'
  s.dependency 'url_launcher_ios'
  s.dependency 'whatsapp_share_plus'
end
