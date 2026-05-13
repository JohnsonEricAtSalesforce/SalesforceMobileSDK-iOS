/*
 Copyright (c) 2021-present, salesforce.com, inc. All rights reserved.

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

public let kSalesforceSDKManagerVersionKey = "com.salesforce.mobilesdk.salesforcesdkmanager.version"

private var _lastVersion: String?
private var _currentVersion: String?

@objc(SFSDKSalesforceSDKUpgradeManager)
public class SFSDKSalesforceSDKUpgradeManager: NSObject {

    @objc public static func upgrade() {
        objc_sync_enter(SFSDKSalesforceSDKUpgradeManager.self)
        defer { objc_sync_exit(SFSDKSalesforceSDKUpgradeManager.self) }

        let lastVersion = SFSDKSalesforceSDKUpgradeManager.lastVersion()
        let currentVersion = SFSDKSalesforceSDKUpgradeManager.currentVersion()

        if currentVersion == lastVersion {
            return
        }

        if lastVersion == nil || lastVersion!.compare("9.2.1", options: .numeric) == .orderedAscending {
            // 9.2.0 & 9.2.1 upgrade steps both need file and keychain access, if we don't have those,
            // abort the upgrade so that it can rerun

            if KeychainHelper.accessibilityAttribute == nil {
                // Only update accessible attribute if the app isn't setting it
                SFLogger.log(Self.self, level: .error, message: "Attempt keychain attribute update")
                let result = KeychainHelper.setAccessibleAttribute(.afterFirstUnlockThisDeviceOnly)
                if result.status == errSecInteractionNotAllowed {
                    SFLogger.log(Self.self, level: .error, message: "Upgrade step skipped because keychain access not allowed")
                    return
                }
            }

            let filesWithCompleteProtection = SFSDKSalesforceSDKUpgradeManager.filesWithCompleteProtection()
            if filesWithCompleteProtection.count > 0 {
                if let app = SFApplicationHelper.sharedApplication(), !app.isProtectedDataAvailable {
                    SFLogger.log(Self.self, level: .error, message: "Upgrade step skipped because files have complete protection and protected data isn't available")
                    return
                }
                SFSDKSalesforceSDKUpgradeManager.updateDefaultProtection(filesWithCompleteProtection)
            }
        }

        if lastVersion == nil || lastVersion!.compare("9.2.0", options: .numeric) == .orderedAscending {
            SFDirectoryManager.upgradeUserDirectories()
            URLCache.shared.removeAllCachedResponses() // For cache encryption key change
        }

        if lastVersion == nil || lastVersion!.compare("10.1.1", options: .numeric) == .orderedAscending {
            SFSDKSalesforceSDKUpgradeManager.upgradePasscode()
        }

        if let currentVersion = currentVersion {
            SFSDKSalesforceSDKUpgradeManager.setLastVersion(currentVersion)
        }
    }

    @objc static func filesWithCompleteProtection() -> [String] {
        var filesToReturn = [String]()

        let directories = [
            SFDirectoryManager.sharedManager().directory(forOrg: nil, user: nil, community: nil, type: FileManager.SearchPathDirectory.libraryDirectory, components: nil),
            SFDirectoryManager.sharedManager().directory(forOrg: nil, user: nil, community: nil, type: FileManager.SearchPathDirectory.documentDirectory, components: nil)
        ]

        for directory in directories {
            guard let dir = directory, let dirURL = URL(string: dir) else { continue }
            let enumerator = FileManager.default.enumerator(
                at: dirURL,
                includingPropertiesForKeys: [.fileProtectionKey],
                options: .producesRelativePathURLs,
                errorHandler: nil
            )

            while let fileURL = enumerator?.nextObject() as? URL {
                let fileString = fileURL.relativeString
                // Anything scoped to the org and below, or global stores
                if fileString.hasPrefix("00D") || fileString.hasPrefix("stores") || fileString.hasPrefix("key_value_stores") {
                    var fileProtection: AnyObject?
                    try? (fileURL as NSURL).getResourceValue(&fileProtection, forKey: .fileProtectionKey)
                    if let protection = fileProtection as? String, protection == URLFileProtection.complete.rawValue {
                        filesToReturn.append((dir as NSString).appendingPathComponent(fileString))
                    }
                }
            }
        }
        return filesToReturn
    }

    @objc static func updateDefaultProtection(_ paths: [String]) {
        for path in paths {
            let fileProtection = SFFileProtectionHelper.protection(for: path)
            try? FileManager.default.setAttributes([.protectionKey: fileProtection], ofItemAtPath: path)
        }
    }

    @objc static func setLastVersion(_ version: String) {
        UserDefaults.msdkUserDefaults().setValue(version, forKey: kSalesforceSDKManagerVersionKey)
        UserDefaults.msdkUserDefaults().synchronize()
        _lastVersion = version
        SFLogger.log(Self.self, level: .info, message: "Upgraded to \(version)")
    }

    @objc static func lastVersion() -> String? {
        if _lastVersion == nil {
            _lastVersion = UserDefaults.msdkUserDefaults().string(forKey: kSalesforceSDKManagerVersionKey)
        }
        return _lastVersion
    }

    @objc static func currentVersion() -> String? {
        if _currentVersion == nil {
            _currentVersion = Bundle(for: SFSDKSalesforceSDKUpgradeManager.self).infoDictionary?["CFBundleShortVersionString"] as? String
        }
        return _currentVersion
    }

    @objc static func upgradePasscode() {
        SFScreenLockManagerInternal.shared.upgradePasscode()
    }
}
