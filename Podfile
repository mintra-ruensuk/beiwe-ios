platform :ios, '9.3'

target 'Beiwe' do
  use_frameworks!
  pod 'Crashlytics', '~> 3.4'
  pod 'KeychainSwift', '~> 8.0'
  pod "PromiseKit", '~> 6'
  pod 'Alamofire', '~> 4.5'
  pod 'ObjectMapper', :git => 'https://github.com/Hearst-DD/ObjectMapper.git', :branch => 'master'
  pod 'Eureka'
  pod 'SwiftValidator', :git => 'https://github.com/jpotts18/SwiftValidator.git', :branch => 'master'
  pod "PKHUD", :git => 'https://github.com/pkluz/PKHUD.git', :branch => 'swift4'
  pod 'IDZSwiftCommonCrypto', '~> 0.13.0'
  pod 'couchbase-lite-ios'
  pod 'ResearchKit'
  pod 'ReachabilitySwift', '~>3'
  pod 'EmitterKit', '~> 5.1'
  pod 'Hakuba', :git => 'https://github.com/eskizyen/Hakuba.git', :branch => 'Swift3'
  pod 'XLActionController', '~>5.0.1'
  pod 'XCGLogger', '~> 7.0.0'

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    next unless (target.name == 'PromiseKit')
    target.build_configurations.each do |config|
      config.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = '-Onone'
    end
  end
  installer.pods_project.targets.each do |target|
    if target.name == 'Eureka' || target.name == 'XLActionController'
      target.build_configurations.each do |config|
        config.build_settings['SWIFT_VERSION'] = '4.2'
        config.build_settings['ENABLE_BITCODE'] = 'NO'
      end
    else
      target.build_configurations.each do |config|
        config.build_settings['SWIFT_VERSION'] = '4.0'
        config.build_settings['ENABLE_BITCODE'] = 'NO'
      end
    end
  end
end


