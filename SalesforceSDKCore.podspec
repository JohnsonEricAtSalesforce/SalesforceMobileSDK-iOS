Pod::Spec.new do |s|

  s.name         = "SalesforceSDKCore"
  s.version      = "14.0.0"
  s.summary      = "Salesforce Mobile SDK for iOS"
  s.homepage     = "https://github.com/forcedotcom/SalesforceMobileSDK-iOS"

  s.license      = { :type => "Salesforce.com Mobile SDK License", :file => "LICENSE.md" }
  s.author       = { "Kevin Hawkins" => "khawkins@salesforce.com" }

  s.platforms    =  { :ios => "18.0", :visionos => "2.0" }
  s.swift_versions = ['5.0']

  s.source       = { :git => "https://github.com/forcedotcom/SalesforceMobileSDK-iOS.git",
                     :tag => "v#{s.version}" }

  s.requires_arc = true
  s.default_subspec  = 'SalesforceSDKCore'

  s.subspec 'SalesforceSDKCore' do |sdkcore|

      sdkcore.dependency 'SalesforceAnalytics', "~>#{s.version}"
      sdkcore.libraries = 'z'
      sdkcore.resource_bundles = { 'SalesforceSDKResources' => [ 'shared/resources/SalesforceSDKResources.bundle/**' ], 'SalesforceSDKCore' => [ 'libs/SalesforceSDKCore/SalesforceSDKCore/PrivacyInfo.xcprivacy' ] }
      sdkcore.resources = ['shared/resources/SalesforceSDKAssets.xcassets']
      sdkcore.source_files = 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/**/*.{h,m,swift}', 'libs/SalesforceSDKCore/SalesforceSDKCore/SalesforceSDKCore.h'
      # public_header_files is automatically populated by update_podspec_headers.sh which is run when building SalesforceSDKCore
      sdkcore.public_header_files = 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Analytics/SFSDKAnalyticsPublisher.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Common/SalesforceSDKConstants.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/PushNotification/SFSDKPushNotificationFieldsConstants.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/UserAccount/SFUserAccountConstants.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Util/SFSDKOAuthConstants.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/SalesforceSDKCore.h'
      sdkcore.requires_arc = true
      sdkcore.prefix_header_contents = '#import "SFSDKCoreLogger.h"', '#import "SalesforceSDKConstants.h"'

  end

end
