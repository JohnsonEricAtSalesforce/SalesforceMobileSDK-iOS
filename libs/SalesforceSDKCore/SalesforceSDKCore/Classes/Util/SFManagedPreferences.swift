// Copyright (c) 2015-present, salesforce.com, inc. All rights reserved.
//
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

/// Class to handle preferences set by an MDM provider.
@objc(SFManagedPreferences)
@objcMembers public class SFManagedPreferences: NSObject {

    // Managed key constants
    private static let kManagedConfigurationKey = "com.apple.configuration.managed"
    private static let kManagedKeyRequireCertAuth = "RequireCertAuth"
    private static let kManagedKeyLoginHosts = "AppServiceHosts"
    private static let kManagedKeyLoginHostLabels = "AppServiceHostLabels"
    private static let kManagedKeyConnectedAppId = "ManagedAppOAuthID"
    private static let kManagedKeyConnectedAppCallbackUri = "ManagedAppCallbackURL"
    private static let kManagedKeyClearClipboardOnBackground = "ClearClipboardOnBackground"
    private static let kManagedKeyOnlyShowAuthorizedHosts = "OnlyShowAuthorizedHosts"
    private static let kManagedKeyIDPAppURLScheme = "IDPAppURLScheme"
    private static let kSFDisableExternalPaste = "DISABLE_EXTERNAL_PASTE"

    @objc public static let sharedPreferences: SFManagedPreferences = {
        let prefs = SFManagedPreferences()
        return prefs
    }()

    /// The raw NSDictionary of managed preferences.
    @objc public private(set) var rawPreferences: NSDictionary?

    private var syncQueue: OperationQueue

    override init() {
        syncQueue = OperationQueue()
        syncQueue.name = "NSUserDefaults Sync Queue"
        super.init()

        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: syncQueue) { [weak self] _ in
            self?.configurePreferences()
        }
        configurePreferences()
        NotificationCenter.default.addObserver(self, selector: #selector(storeAnalyticsEvent), name: UserAccountManager.didFinishUserInit, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Configuration

    private func configurePreferences() {
        rawPreferences = UserDefaults.standard.dictionary(forKey: SFManagedPreferences.kManagedConfigurationKey) as NSDictionary?
        if hasManagedPreferences {
            SFSDKAppFeatureMarkers.registerAppFeature(kSFAppFeatureManagedByMDM)
        }
    }

    // MARK: - Properties

    @objc public var hasManagedPreferences: Bool {
        return (rawPreferences?.allKeys.count ?? 0) > 0
    }

    @objc public var requireCertificateAuthentication: Bool {
        return (rawPreferences?[SFManagedPreferences.kManagedKeyRequireCertAuth] as? NSNumber)?.boolValue ?? false
    }

    @objc public var onlyShowAuthorizedHosts: Bool {
        return (rawPreferences?[SFManagedPreferences.kManagedKeyOnlyShowAuthorizedHosts] as? NSNumber)?.boolValue ?? false
    }

    @objc public var idpAppURLScheme: String {
        return rawPreferences?[SFManagedPreferences.kManagedKeyIDPAppURLScheme] as? String ?? ""
    }

    @objc public var loginHosts: NSArray? {
        var objLoginHosts: Any? = rawPreferences?[SFManagedPreferences.kManagedKeyLoginHosts]
        if let stringHost = objLoginHosts as? String {
            objLoginHosts = [stringHost]
        }
        if let arrayHosts = objLoginHosts as? NSArray, arrayHosts.count > 0 {
            return arrayHosts
        }
        return nil
    }

    @objc public var loginHostLabels: NSArray? {
        var objLoginHostLabels: Any? = rawPreferences?[SFManagedPreferences.kManagedKeyLoginHostLabels]
        if let stringLabel = objLoginHostLabels as? String {
            objLoginHostLabels = [stringLabel]
        }
        if let arrayLabels = objLoginHostLabels as? NSArray, arrayLabels.count > 0 {
            return arrayLabels
        }
        return nil
    }

    @objc public var connectedAppId: String {
        return rawPreferences?[SFManagedPreferences.kManagedKeyConnectedAppId] as? String ?? ""
    }

    @objc public var connectedAppCallbackUri: String {
        return rawPreferences?[SFManagedPreferences.kManagedKeyConnectedAppCallbackUri] as? String ?? ""
    }

    @objc public var shouldDisableExternalPasteDefinedByConnectedApp: Bool {
        if let customAttributes = UserAccountManager.shared.currentUserAccount?.idData?.customAttributes {
            if let disableExternalPaste = customAttributes[SFManagedPreferences.kSFDisableExternalPaste] as? String {
                return (disableExternalPaste as NSString).boolValue
            }
        }
        return false
    }

    @objc public var clearClipboardOnBackground: Bool {
        let rawValue = (rawPreferences?[SFManagedPreferences.kManagedKeyClearClipboardOnBackground] as? NSNumber)?.boolValue ?? false
        return rawValue || shouldDisableExternalPasteDefinedByConnectedApp
    }

    // MARK: - Analytics

    @objc private func storeAnalyticsEvent() {
        var attributes: [String: Any] = [:]
        if let rawPrefs = rawPreferences {
            attributes["mdmIsActive"] = NSNumber(value: true)
            attributes["mdmConfigs"] = rawPrefs
        } else {
            attributes["mdmIsActive"] = NSNumber(value: false)
        }
        SFSDKEventBuilderHelper.createAndStoreEvent("mdmConfiguration", userAccount: nil, className: NSStringFromClass(SFManagedPreferences.self), attributes: attributes)
    }
}
