Pod::Spec.new do |s|
  s.name             = 'credflare_sdk'
  s.version          = '0.1.0'
  s.summary          = 'Native document collection and scoped applicant sessions for CredFlare.'
  s.description      = 'Reads face signals for liveness with the Vision framework.'
  s.homepage         = 'https://github.com/credflare/flutter-sdk'
  s.license          = { :file => '../LICENSE' }
  s.authors          = 'Credflare'
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.frameworks       = 'Vision', 'CoreVideo', 'CoreML'
  s.platform         = :ios, '15.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version    = '5.0'
end
