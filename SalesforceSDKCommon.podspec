Pod::Spec.new do |s|

  s.name         = "SalesforceSDKCommon"
  s.version      = "14.0.0"
  s.summary      = "Salesforce Mobile SDK for iOS"
  s.homepage     = "https://github.com/forcedotcom/SalesforceMobileSDK-iOS"

  s.license      = { :type => "Salesforce.com Mobile SDK License", :file => "LICENSE.md" }
  s.author       = { "Raj Rao" => "rao.r@salesforce.com" }

  s.platforms    =  { :ios => "18.0", :visionos => "2.0" }
  s.swift_versions = ['5.0']

  s.source       = { :git => "https://github.com/forcedotcom/SalesforceMobileSDK-iOS.git",
                     :tag => "v#{s.version}" }

  s.requires_arc = true
  s.default_subspec  = 'SalesforceSDKCommon'

  s.subspec 'SalesforceSDKCommon' do |sdkcommon|
      sdkcommon.source_files = 'libs/SalesforceSDKCommon/SalesforceSDKCommon/Classes/**/*.{h,m,swift}', 'libs/SalesforceSDKCommon/SalesforceSDKCommon/SalesforceSDKCommon.h'
      sdkcommon.exclude_files = 'libs/SalesforceSDKCommon/SalesforceSDKCommon/Classes/Logger/*.{h,m}', 'libs/SalesforceSDKCommon/SalesforceSDKCommon/Classes/Util/SFJsonUtils.{h,m}', 'libs/SalesforceSDKCommon/SalesforceSDKCommon/Classes/Util/SFPathUtil.{h,m}', 'libs/SalesforceSDKCommon/SalesforceSDKCommon/Classes/Util/SFFileProtectionHelper.{h,m}', 'libs/SalesforceSDKCommon/SalesforceSDKCommon/Classes/Util/SFSDKDatasharingHelper.{h,m}', 'libs/SalesforceSDKCommon/SalesforceSDKCommon/Classes/Util/SFSDKReachability.{h,m}', 'libs/SalesforceSDKCommon/SalesforceSDKCommon/Classes/Util/NSUserDefaults+SFAdditions.{h,m}', 'libs/SalesforceSDKCommon/SalesforceSDKCommon/Classes/Util/SFSwiftDetectUtil.{h,m}'
      sdkcommon.public_header_files = 'libs/SalesforceSDKCommon/build/SalesforceSDKCommon.build/Release-iphoneos/SalesforceSDKCommon.build/Objects-normal/arm64/SalesforceSDKCommon-Swift.h, 'libs/SalesforceSDKCommon/SalesforceSDKCommon/Classes/Util/SFSDKSafeMutableArray.h, 'libs/SalesforceSDKCommon/SalesforceSDKCommon/Classes/Util/SFSDKSafeMutableDictionary.h, 'libs/SalesforceSDKCommon/SalesforceSDKCommon/Classes/Util/SFSDKSafeMutableSet.h, 'libs/SalesforceSDKCommon/SalesforceSDKCommon/SalesforceSDKCommon.h, libs/SalesforceSDKCommon/build/Release-iphoneos/SalesforceSDKCommon.framework/Headers/SalesforceSDKCommon-Swift.h', libs/SalesforceSDKCommon/build/Release-iphoneos/SalesforceSDKCommon.framework/Headers/SalesforceSDKCommon.h', libs/SalesforceSDKCommon/build/Release-iphoneos/SalesforceSDKCommon.framework/Headers/SFSDKSafeMutableArray.h', libs/SalesforceSDKCommon/build/Release-iphoneos/SalesforceSDKCommon.framework/Headers/SFSDKSafeMutableDictionary.h', libs/SalesforceSDKCommon/build/Release-iphoneos/SalesforceSDKCommon.framework/Headers/SFSDKSafeMutableSet.h'
      sdkcommon.prefix_header_contents = ''
      sdkcommon.resource_bundles = { 'SalesforceSDKCommon' => [ 'libs/SalesforceSDKCommon/SalesforceSDKCommon/PrivacyInfo.xcprivacy' ] }
      sdkcommon.requires_arc = true

  end

end
