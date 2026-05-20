// Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.
// Redistribution and use of this software in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
// * Redistributions of source code must retain the above copyright notice, this list of conditions
// and the following disclaimer.
// * Redistributions in binary form must reproduce the above copyright notice, this list of
// conditions and the following disclaimer in the documentation and/or other materials provided
// with the distribution.
// * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
// endorse or promote products derived from this software without specific prior written
// permission of salesforce.com, inc.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
// IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
// FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
// CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
// WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
// WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import Foundation
import SalesforceSDKCommon

private let kSFLoginHostChangedNotification = "kSFLoginHostChanged"
private let kSFLoginHostChangedNotificationOriginalHostKey = "originalLoginHost"
private let kSFLoginHostChangedNotificationUpdatedHostKey = "updatedLoginHost"
private let kDeprecatedLoginHostPrefKey = "login_host_pref"
private let kSFUserAccountOAuthLoginHostDefault = "login.salesforce.com"
private let kSFUserAccountOAuthLoginHost = "SFDCOAuthLoginHost"
private let kOAuthScopesKey = "oauth_scopes"
private let kOAuthClientIdKey = "oauth_client_id"
private let kOAuthRedirectUriKey = "oauth_redirect_uri"
private let kSFIDPKey = "SFDCIdp"
private let kSFIDPProviderKey = "SFIDPProvider"
private let kOAuthAppName = "oauth_app_name"

@objc(SFSDKAuthPreferences)
@objcMembers
public class SFSDKAuthPreferences: NSObject {

    public var additionalOAuthParameterKeys: [String] = []
    public var additionalTokenRefreshParams: [String: Any] = [:]
    public var retryLoginAfterFailure: Bool = false
    public var brandLoginPath: String?

    private var _requireBrowserAuthentication: Bool = false

    public var loginHost: String? {
        get {
            let defaults = UserDefaults.msdkUserDefaults()
            // Import previously stored settings
            if let host = defaults.string(forKey: kDeprecatedLoginHostPrefKey) {
                defaults.set(host, forKey: kSFUserAccountOAuthLoginHost)
                defaults.removeObject(forKey: kDeprecatedLoginHostPrefKey)
                defaults.synchronize()
                return host
            }

            let storedHost = defaults.string(forKey: kSFUserAccountOAuthLoginHost)
            if let stored = storedHost, stored.count > 0, SFSDKLoginHostStorage.sharedInstance.loginHostForHostAddress( stored) != nil {
                return stored
            }

            // Not initialized
            var loginHost: String?
            let managedHosts = SFManagedPreferences.sharedPreferences.loginHosts
            if let firstHost = managedHosts?.first as? String, firstHost.count > 0 {
                loginHost = firstHost
            } else {
                if !SFManagedPreferences.sharedPreferences.onlyShowAuthorizedHosts {
                    if let bundleHost = Bundle.main.object(forInfoDictionaryKey: kSFUserAccountOAuthLoginHost) as? String, bundleHost.count > 0 {
                        loginHost = bundleHost
                    } else {
                        loginHost = kSFUserAccountOAuthLoginHostDefault
                    }
                }
            }
            defaults.set(loginHost, forKey: kSFUserAccountOAuthLoginHost)
            defaults.synchronize()
            return loginHost
        }
        set {
            let oldLoginHost = loginHost
            let defaults = UserDefaults.msdkUserDefaults()
            if let host = newValue {
                if SFSDKLoginHostStorage.sharedInstance.loginHostForHostAddress( host) == nil {
                    let loginHostObj = SalesforceLoginHost.host(withName: host, host: host, deletable: true)
                    SFSDKLoginHostStorage.sharedInstance.addLoginHost(loginHostObj)
                }
                defaults.set(host, forKey: kSFUserAccountOAuthLoginHost)
            } else {
                defaults.removeObject(forKey: kSFUserAccountOAuthLoginHost)
            }
            defaults.synchronize()

            if (oldLoginHost != nil || newValue != nil) && newValue != oldLoginHost {
                let userInfo: [String: Any] = [
                    kSFLoginHostChangedNotificationOriginalHostKey: oldLoginHost ?? NSNull(),
                    kSFLoginHostChangedNotificationUpdatedHostKey: newValue ?? NSNull()
                ]
                NotificationCenter.default.post(name: NSNotification.Name(kSFLoginHostChangedNotification), object: self, userInfo: userInfo)
            }
        }
    }

    public var scopes: Set<String> {
        get {
            let defaults = UserDefaults.msdkUserDefaults()
            let scopesArray = defaults.object(forKey: kOAuthScopesKey) as? [String] ?? []
            return Set(scopesArray)
        }
        set {
            let defaults = UserDefaults.msdkUserDefaults()
            defaults.set(Array(newValue), forKey: kOAuthScopesKey)
            defaults.synchronize()
        }
    }

    public var oauthCompletionUrl: String? {
        get {
            let managedUri = SFManagedPreferences.sharedPreferences.connectedAppCallbackUri; if managedUri.count > 0 {
                return managedUri
            }
            return UserDefaults.msdkUserDefaults().object(forKey: kOAuthRedirectUriKey) as? String
        }
        set {
            UserDefaults.msdkUserDefaults().set(newValue, forKey: kOAuthRedirectUriKey)
            UserDefaults.msdkUserDefaults().synchronize()
        }
    }

    public var oauthClientId: String? {
        get {
            let managedId = SFManagedPreferences.sharedPreferences.connectedAppId; if managedId.count > 0 {
                return managedId
            }
            return UserDefaults.msdkUserDefaults().object(forKey: kOAuthClientIdKey) as? String
        }
        set {
            UserDefaults.msdkUserDefaults().set(newValue, forKey: kOAuthClientIdKey)
            UserDefaults.msdkUserDefaults().synchronize()
        }
    }

    public var idpAppURIScheme: String? {
        get {
            let managedScheme = SFManagedPreferences.sharedPreferences.idpAppURLScheme; if managedScheme.count > 0 {
                return managedScheme
            }
            return UserDefaults.msdkUserDefaults().string(forKey: kSFIDPKey)
        }
        set {
            UserDefaults.msdkUserDefaults().set(newValue, forKey: kSFIDPKey)
            UserDefaults.msdkUserDefaults().synchronize()
        }
    }

    public var requireBrowserAuthentication: Bool {
        get {
            return SFManagedPreferences.sharedPreferences.requireCertificateAuthentication || _requireBrowserAuthentication
        }
        set {
            _requireBrowserAuthentication = newValue
        }
    }

    public var idpEnabled: Bool {
        return (idpAppURIScheme?.count ?? 0) > 0
    }

    public var isIdentityProvider: Bool {
        get {
            return UserDefaults.msdkUserDefaults().bool(forKey: kSFIDPProviderKey)
        }
        set {
            UserDefaults.msdkUserDefaults().set(newValue, forKey: kSFIDPProviderKey)
            UserDefaults.msdkUserDefaults().synchronize()
        }
    }

    public var appDisplayName: String {
        get {
            if let name = UserDefaults.msdkUserDefaults().string(forKey: kOAuthAppName) {
                return name
            }
            if let displayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String {
                return displayName
            }
            return Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? ""
        }
        set {
            if newValue.isEmpty {
                UserDefaults.msdkUserDefaults().removeObject(forKey: kOAuthAppName)
            } else {
                UserDefaults.msdkUserDefaults().set(newValue, forKey: kOAuthAppName)
            }
            UserDefaults.msdkUserDefaults().synchronize()
        }
    }
}
