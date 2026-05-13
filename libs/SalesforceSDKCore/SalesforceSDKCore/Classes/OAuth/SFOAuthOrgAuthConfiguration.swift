/*
 Copyright (c) 2014-present, salesforce.com, inc. All rights reserved.

 Redistribution and use of this software in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright notice, this list of conditions
 and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of
 conditions and the following disclaimer in the documentation and/or other materials provided
 with the distribution.
 * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
 endorse or promote products derived from this software without specific prior written
 permission of salesforce.com, inc.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
 FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
 WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation

private let kAuthConfigMobileSDKKey = "MobileSDK"
private let kAuthConfigUseNativeBrowserKey = "UseiOSNativeBrowserForAuthentication"
private let kAuthConfigShareBrowserSession = "shareBrowserSessionIOS"
private let kAuthConfigSamlProvidersKey = "SamlProviders"
private let kAuthConfigAuthProvidersKey = "AuthProviders"
private let kAuthConfigSSOUrlKey = "SsoUrl"
private let kAuthConfigLoginPageKey = "LoginPage"
private let kAuthConfigLoginPageUrlKey = "LoginPageUrl"

/**
 Data class representing the org authentication configuration.
 */
@objc(SFOAuthOrgAuthConfiguration)
public class SFOAuthOrgAuthConfiguration: NSObject {

    /**
     Raw dictionary data representing the org auth configuration.
     */
    @objc public private(set) var authConfigDict: [String: Any]?

    /**
     Tells Mobile SDK whether to use the native browser for authentication.
     */
    @objc public var useNativeBrowserForAuth: Bool {
        guard let mobileSDK = authConfigDict?[kAuthConfigMobileSDKKey] as? [String: Any],
              let value = mobileSDK[kAuthConfigUseNativeBrowserKey] as? Bool else {
            return false
        }
        return value
    }

    /**
     Tells Mobile SDK to share the native browser session for authentication.
     */
    @objc public var shareBrowserSession: Bool {
        guard let mobileSDK = authConfigDict?[kAuthConfigMobileSDKKey] as? [String: Any] else {
            return false
        }

        if let value = mobileSDK[kAuthConfigShareBrowserSession] as? Bool {
            return value
        } else {
            // return false which means prompt=login being appended to login url
            return false
        }
    }

    /**
     List of configured SSO URLs.
     */
    @objc public var ssoUrls: [String]? {
        var ssoUrls: [String] = []

        // Parses SAML provider list and adds it to the list of SSO URLs.
        if let samlProviders = authConfigDict?[kAuthConfigSamlProvidersKey] as? [[String: Any]] {
            for provider in samlProviders {
                if let ssoUrl = provider[kAuthConfigSSOUrlKey] as? String {
                    ssoUrls.append(ssoUrl)
                }
            }
        }

        // Parses auth provider list and adds it to the list of SSO URLs.
        if let authProviders = authConfigDict?[kAuthConfigAuthProvidersKey] as? [[String: Any]] {
            for provider in authProviders {
                if let ssoUrl = provider[kAuthConfigSSOUrlKey] as? String {
                    ssoUrls.append(ssoUrl)
                }
            }
        }

        return ssoUrls.isEmpty ? nil : ssoUrls
    }

    /**
     Configured login page URL.
     */
    @objc public var loginPageUrl: String? {
        guard let loginPage = authConfigDict?[kAuthConfigLoginPageKey] as? [String: Any],
              !(loginPage is NSNull),
              !loginPage.isEmpty else {
            return nil
        }
        return loginPage[kAuthConfigLoginPageUrlKey] as? String
    }

    /**
     Designated initializer.
     - Parameter authConfigDict: NSDictionary containing the org auth configuration.
     */
    @objc public init(configDict authConfigDict: [String: Any]?) {
        self.authConfigDict = authConfigDict
        super.init()
    }

    public override var description: String {
        return "<\(type(of: self)):\(Unmanaged.passUnretained(self).toOpaque())> authConfigDict: \(authConfigDict ?? [:])"
    }
}
