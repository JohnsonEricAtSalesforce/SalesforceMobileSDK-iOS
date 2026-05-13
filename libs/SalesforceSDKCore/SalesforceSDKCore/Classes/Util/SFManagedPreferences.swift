/*
 Copyright (c) 2015-present, salesforce.com, inc. All rights reserved.

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
import SalesforceSDKCommon

/**
 Class to handle preferences set by an MDM provider.
 */
@objc(SFManagedPreferences)
public class SFManagedPreferences: NSObject {

    // See "Extending Your Apps for Enterprise and Education Use" in the WWDC 2013 videos
    // See https://developer.apple.com/library/ios/samplecode/sc2279/ManagedAppConfig.zip
    private static let managedConfigurationKey = "com.apple.configuration.managed"
    private static let managedFeedbackKey = "com.apple.feedback.managed" // XXX - For future "feedback" impl

    // Managed key constants
    private static let managedKeyRequireCertAuth = "RequireCertAuth"
    private static let managedKeyLoginHosts = "AppServiceHosts"
    private static let managedKeyLoginHostLabels = "AppServiceHostLabels"
    private static let managedKeyConnectedAppId = "ManagedAppOAuthID"
    private static let managedKeyConnectedAppCallbackUri = "ManagedAppCallbackURL"
    private static let managedKeyClearClipboardOnBackground = "ClearClipboardOnBackground"
    private static let managedKeyOnlyShowAuthorizedHosts = "OnlyShowAuthorizedHosts"
    private static let managedKeyIDPAppURLScheme = "IDPAppURLScheme"
    private static let sfDisableExternalPaste = "DISABLE_EXTERNAL_PASTE"

    private let syncQueue: OperationQueue

    /**
     @return The shared instance of this class.
     */
    @objc
    public static func sharedPreferences() -> SFManagedPreferences {
        return shared
    }

    private static let shared: SFManagedPreferences = {
        return SFManagedPreferences()
    }()

    /**
     The raw NSDictionary of managed preferences.
     */
    @objc
    public private(set) var rawPreferences: NSDictionary = [:]

    private override init() {
        self.syncQueue = OperationQueue()
        self.syncQueue.name = "NSUserDefaults Sync Queue"
        super.init()

        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: syncQueue
        ) { [weak self] _ in
            self?.configurePreferences()
        }

        configurePreferences()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storeAnalyticsEvent),
            name: .UserAccountManagerDidFinishUserInit,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func configurePreferences() {
        if let prefs = UserDefaults.standard.dictionary(forKey: SFManagedPreferences.managedConfigurationKey) {
            rawPreferences = prefs as NSDictionary
        } else {
            rawPreferences = [:]
        }

        if hasManagedPreferences {
            SFSDKAppFeatureMarkers.registerAppFeature(kSFAppFeatureManagedByMDM)
        }
    }

    /**
     Whether or not any managed preferences have been configured for this app.
     */
    @objc
    public var hasManagedPreferences: Bool {
        return rawPreferences.allKeys.count > 0
    }

    /**
     Whether the app is configured to require certificate-based authentication. (RequireCertAuth)
     */
    @objc
    public var requireCertificateAuthentication: Bool {
        return (rawPreferences[SFManagedPreferences.managedKeyRequireCertAuth] as? NSNumber)?.boolValue ?? false
    }

    /**
     Whether or not to display only the authorized hosts. (OnlyShowAuthorizedHosts)
     */
    @objc
    public var onlyShowAuthorizedHosts: Bool {
        return (rawPreferences[SFManagedPreferences.managedKeyOnlyShowAuthorizedHosts] as? NSNumber)?.boolValue ?? false
    }

    /**
     The idp App's URL Scheme
     */
    @objc
    public var idpAppURLScheme: String? {
        return rawPreferences[SFManagedPreferences.managedKeyIDPAppURLScheme] as? String
    }

    /**
     An array of prescribed login hosts from the MDM provider. (AppServiceHosts)
     */
    @objc
    public var loginHosts: [Any]? {
        var objLoginHosts = rawPreferences[SFManagedPreferences.managedKeyLoginHosts]

        if let stringHost = objLoginHosts as? String {
            objLoginHosts = [stringHost]
        }

        if let arrayHosts = objLoginHosts as? [Any], !arrayHosts.isEmpty {
            return arrayHosts
        }

        return nil
    }

    /**
     The associated labels for the provided login hosts. (AppServiceHostLabels)
     */
    @objc
    public var loginHostLabels: [Any]? {
        var objLoginHostLabels = rawPreferences[SFManagedPreferences.managedKeyLoginHostLabels]

        if let stringLabel = objLoginHostLabels as? String {
            objLoginHostLabels = [stringLabel]
        }

        if let arrayLabels = objLoginHostLabels as? [Any], !arrayLabels.isEmpty {
            return arrayLabels
        }

        return nil
    }

    /**
     The managed Connected App ID. (ManagedAppOAuthID)
     */
    @objc
    public var connectedAppId: String? {
        return rawPreferences[SFManagedPreferences.managedKeyConnectedAppId] as? String
    }

    /**
     The managed Conneced App Callback URI. (ManagedAppCallbackURL)
     */
    @objc
    public var connectedAppCallbackUri: String? {
        return rawPreferences[SFManagedPreferences.managedKeyConnectedAppCallbackUri] as? String
    }

    /**
     Whether or not external paste is disabled in the connected app.
     */
    @objc
    public var shouldDisableExternalPasteDefinedByConnectedApp: Bool {
        guard let customAttributes = UserAccountManager.shared.currentUserAccount?.idData?.customAttributes,
              let disableExternalPaste = customAttributes[SFManagedPreferences.sfDisableExternalPaste] as? String else {
            return false
        }
        return (disableExternalPaste as NSString).boolValue
    }

    /**
     Whether or not to clear the clipboard when the app is backgrounded. (ClearClipboardOnBackground)
     */
    @objc
    public var clearClipboardOnBackground: Bool {
        let managedValue = (rawPreferences[SFManagedPreferences.managedKeyClearClipboardOnBackground] as? NSNumber)?.boolValue ?? false
        return managedValue || shouldDisableExternalPasteDefinedByConnectedApp
    }

    @objc
    private func storeAnalyticsEvent() {
        var attributes: [String: Any] = [:]

        if hasManagedPreferences {
            attributes["mdmIsActive"] = NSNumber(value: true)
            attributes["mdmConfigs"] = rawPreferences
        } else {
            attributes["mdmIsActive"] = NSNumber(value: false)
        }

        SFSDKEventBuilderHelper.createAndStoreEvent(
            "mdmConfiguration",
            userAccount: nil,
            className: NSStringFromClass(type(of: self)),
            attributes: attributes
        )
    }
}
