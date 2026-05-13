/*
 SFSDKAuthPreferences.swift
 SalesforceSDKCore

 Created by Raj Rao on 7/25/17.

 Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.

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

// Notification name for login host changes
private let kSFLoginHostChangedNotification = "kSFLoginHostChanged"
private let kSFLoginHostChangedNotificationOriginalHostKey = "originalLoginHost"
private let kSFLoginHostChangedNotificationUpdatedHostKey = "updatedLoginHost"
private let kDeprecatedLoginHostPrefKey = "login_host_pref"
private let kSFUserAccountOAuthLoginHostDefault = "login.salesforce.com" // last resort
private let kSFUserAccountOAuthLoginHost = "SFDCOAuthLoginHost"

// The key for storing the persisted OAuth scopes.
private let kOAuthScopesKey = "oauth_scopes"

// The key for storing the persisted OAuth client ID.
private let kOAuthClientIdKey = "oauth_client_id"

// The key for storing the persisted OAuth redirect URI.
private let kOAuthRedirectUriKey = "oauth_redirect_uri"

// The key for storing the persisted IDP app identifier
public let kSFIDPKey = "SFDCIdp"

// The key for storing the IDP Provider Enabled flag
public let kSFIDPProviderKey = "SFIDPProvider"

// The key for storing the persisted OAuth scopes.
public let kOAuthAppName = "oauth_app_name"

@objc(SFSDKAuthPreferences)
public class SFSDKAuthPreferences: NSObject {

    /**
     An array of additional keys (NSString) to parse during OAuth
     */
    @objc public var additionalOAuthParameterKeys: [String]?

    /**
     A dictionary of additional parameters (key value pairs) to send during token refresh
     */
    @objc public var additionalTokenRefreshParams: [String: Any]?

    /** The host that will be used for login.
     */
    @objc public var loginHost: String? {
        get {
            let defaults = UserDefaults.msdkUserDefaults()

            // First let's import any previously stored settings, if available.
            if let host = defaults.string(forKey: kDeprecatedLoginHostPrefKey) {
                defaults.set(host, forKey: kSFUserAccountOAuthLoginHost)
                defaults.removeObject(forKey: kDeprecatedLoginHostPrefKey)
                defaults.synchronize()
                return host
            }

            // Fetch from the standard defaults or bundle and ensures that login host still exists.
            if let loginHost = defaults.string(forKey: kSFUserAccountOAuthLoginHost),
               !loginHost.isEmpty,
               SFSDKLoginHostStorage.shared.loginHost(forHostAddress: loginHost) != nil {
                return loginHost
            }

            // Login host not initialized. Set it up.
            var loginHost: String?
            let managedLoginHost = SFManagedPreferences.sharedPreferences().loginHosts?.first as? String
            if let managedHost = managedLoginHost, !managedHost.isEmpty {
                loginHost = managedHost
            } else {
                /*
                 * Do not fall back to default login host if MDM only permits authorized hosts, even if there are no other hosts.
                 */
                if !SFManagedPreferences.sharedPreferences().onlyShowAuthorizedHosts {
                    if let bundleLoginHost = Bundle.main.object(forInfoDictionaryKey: kSFUserAccountOAuthLoginHost) as? String,
                       !bundleLoginHost.isEmpty {
                        loginHost = bundleLoginHost
                    } else {
                        loginHost = kSFUserAccountOAuthLoginHostDefault
                    }
                }
            }
            if let loginHost = loginHost {
                defaults.set(loginHost, forKey: kSFUserAccountOAuthLoginHost)
                defaults.synchronize()
            }
            return loginHost
        }
        set {
            let oldLoginHost = self.loginHost
            if let host = newValue {
                // Persists the login host if it doesn't exist already.
                if SFSDKLoginHostStorage.shared.loginHost(forHostAddress: host) == nil {
                    let loginHost = SFSDKLoginHost.host(withName: host, host: host, deletable: true)
                    SFSDKLoginHostStorage.shared.add(loginHost)
                }
                UserDefaults.msdkUserDefaults().set(host, forKey: kSFUserAccountOAuthLoginHost)
            } else {
                UserDefaults.msdkUserDefaults().removeObject(forKey: kSFUserAccountOAuthLoginHost)
            }
            UserDefaults.msdkUserDefaults().synchronize()

            // Only post the login host change notification if the host actually changed.
            if (oldLoginHost != nil || newValue != nil) && newValue != oldLoginHost {
                let userInfoDict: [String: Any] = [
                    kSFLoginHostChangedNotificationOriginalHostKey: oldLoginHost ?? NSNull(),
                    kSFLoginHostChangedNotificationUpdatedHostKey: newValue ?? NSNull()
                ]
                let loginHostUpdateNotification = Notification(name: Notification.Name(rawValue: kSFLoginHostChangedNotification),
                                                              object: self,
                                                              userInfo: userInfoDict)
                NotificationCenter.default.post(loginHostUpdateNotification)
            }
        }
    }

    /** Should the login process start again if it fails (default: YES)
     */
    @objc public var retryLoginAfterFailure: Bool = true

    /** OAuth client ID to use for login.  Apps may customize
     by setting this property before login; otherwise, this
     value is determined by the SFDCOAuthClientIdPreference
     configured via the settings bundle.
     */
    @objc public var oauthClientId: String? {
        get {
            if let connectedAppId = SFManagedPreferences.sharedPreferences().connectedAppId,
               !connectedAppId.isEmpty {
                return connectedAppId
            } else {
                let defaults = UserDefaults.msdkUserDefaults()
                return defaults.string(forKey: kOAuthClientIdKey)
            }
        }
        set {
            let defaults = UserDefaults.msdkUserDefaults()
            defaults.set(newValue, forKey: kOAuthClientIdKey)
            defaults.synchronize()
        }
    }

    /** OAuth callback url to use for the OAuth login process.
     Apps may customize this by setting this property before login.
     By default this value is picked up from the main
     bundle property SFDCOAuthRedirectUri
     */
    @objc public var oauthCompletionUrl: String? {
        get {
            if let callbackUri = SFManagedPreferences.sharedPreferences().connectedAppCallbackUri,
               !callbackUri.isEmpty {
                return callbackUri
            } else {
                let defaults = UserDefaults.msdkUserDefaults()
                return defaults.string(forKey: kOAuthRedirectUriKey)
            }
        }
        set {
            let defaults = UserDefaults.msdkUserDefaults()
            defaults.set(newValue, forKey: kOAuthRedirectUriKey)
            defaults.synchronize()
        }
    }

    /**
     The Branded Login path configured for this application.
     */
    @objc public var brandLoginPath: String?

    /**
     The OAuth scopes associated with the app.
     */
    @objc public var scopes: Set<String> {
        get {
            let defaults = UserDefaults.msdkUserDefaults()
            let scopesArray = defaults.array(forKey: kOAuthScopesKey) as? [String] ?? []
            return Set(scopesArray)
        }
        set {
            let scopesArray = Array(newValue)
            let defaults = UserDefaults.msdkUserDefaults()
            defaults.set(scopesArray, forKey: kOAuthScopesKey)
            defaults.synchronize()
        }
    }

    /**  Use this property to enable an app to become and IdentityProvider for other apps
     *
     */
    @objc public var isIdentityProvider: Bool {
        get {
            let defaults = UserDefaults.msdkUserDefaults()
            return defaults.bool(forKey: kSFIDPProviderKey)
        }
        set {
            let defaults = UserDefaults.msdkUserDefaults()
            defaults.set(newValue, forKey: kSFIDPProviderKey)
            defaults.synchronize()
        }
    }

    /** Check if the idp apps URI scheme  has been set.
     *
     */
    @objc public var idpEnabled: Bool {
        if let scheme = idpAppURIScheme, !scheme.isEmpty {
            return true
        }
        return false
    }

    /** Use this property to indicate the url scheme  for the Identity Provider app
     *
     */
    @objc public var idpAppURIScheme: String? {
        get {
            if let idpAppScheme = SFManagedPreferences.sharedPreferences().idpAppURLScheme,
               !idpAppScheme.isEmpty {
                return idpAppScheme
            } else {
                let defaults = UserDefaults.msdkUserDefaults()
                return defaults.string(forKey: kSFIDPKey)
            }
        }
        set {
            let defaults = UserDefaults.msdkUserDefaults()
            defaults.set(newValue, forKey: kSFIDPKey)
            defaults.synchronize()
        }
    }

    /**
     A user friendly display name for use in UI by the SDK on behalf of the app.  This value will be used on various authentication screens
     such as biometric enrollment or IDP login. If left unset, this property will fallback to CFBundleDisplayName or CFBundleName depending on what is available.

     This name will be displayed in the user selection view of the identity provider app.
     */
    @objc public var appDisplayName: String {
        get {
            let defaults = UserDefaults.msdkUserDefaults()
            if let appName = defaults.string(forKey: kOAuthAppName) {
                return appName
            } else {
                if let bundleDisplayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String {
                    return bundleDisplayName
                } else {
                    return Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? ""
                }
            }
        }
        set {
            let defaults = UserDefaults.msdkUserDefaults()
            defaults.set(newValue, forKey: kOAuthAppName)
            defaults.synchronize()
        }
    }

    /**
     Whether the app is configured to require certificate-based authentication. (RequireCertAuth)
     */
    @objc public var requireBrowserAuthentication: Bool = false {
        didSet {
            // The property is also true if managed preferences require certificate authentication
        }
    }

    @objc public var computedRequireBrowserAuthentication: Bool {
        return SFManagedPreferences.sharedPreferences().requireCertificateAuthentication || requireBrowserAuthentication
    }
}
