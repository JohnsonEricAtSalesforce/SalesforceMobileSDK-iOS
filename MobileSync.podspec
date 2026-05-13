Pod::Spec.new do |s|

  s.name         = "MobileSync"
  s.version      = "14.0.0"
  s.summary      = "Salesforce Mobile SDK for iOS - MobileSync"
  s.homepage     = "https://github.com/forcedotcom/SalesforceMobileSDK-iOS"

  s.license      = { :type => "Salesforce.com Mobile SDK License", :file => "LICENSE.md" }
  s.author       = { "Kevin Hawkins" => "khawkins@salesforce.com" }

  s.platforms    =  { :ios => "18.0", :visionos => "2.0" }
  s.swift_versions = ['5.0']

  s.source       = { :git => "https://github.com/forcedotcom/SalesforceMobileSDK-iOS.git",
                     :tag => "v#{s.version}" }
  
  s.requires_arc = true
  s.default_subspec  = 'MobileSync'

  s.subspec 'MobileSync' do |mobilesync|

      mobilesync.dependency 'SmartStore', "~>#{s.version}"
      mobilesync.source_files = 'libs/MobileSync/MobileSync/Classes/**/*.{h,m,swift}', 'libs/MobileSync/MobileSync/MobileSync.h'
      mobilesync.public_header_files = 'libs/MobileSync/MobileSync/MobileSync.h'
      mobilesync.prefix_header_contents = '#import "SFSDKMobileSyncLogger.h"'
      mobilesync.resource_bundles = { 'MobileSync' => [ 'libs/MobileSync/MobileSync/PrivacyInfo.xcprivacy' ] }
      mobilesync.requires_arc = true

  end

end
