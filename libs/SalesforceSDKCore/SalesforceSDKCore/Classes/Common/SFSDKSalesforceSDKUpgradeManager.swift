// SFSDKSalesforceSDKUpgradeManager.swift
//
// Copyright (c) 2021-present, salesforce.com, inc. All rights reserved.
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

public let kSalesforceSDKManagerVersionKey: String = "com.salesforce.mobilesdk.salesforcesdkmanager.version"

@objc(SFSDKSalesforceSDKUpgradeManager)
@objcMembers
public class SFSDKSalesforceSDKUpgradeManager: NSObject {

    private static let upgradeLock = NSRecursiveLock()
    private static var _lastVersion: String?
    private static var _currentVersion: String?

    @objc public static func upgrade() {
        upgradeLock.lock()
        defer { upgradeLock.unlock() }

        let lastVersion = self.lastVersion()
        let currentVersion = self.currentVersion()

        guard currentVersion != lastVersion else { return }

        if lastVersion == nil || lastVersion?.compare("9.2.1", options: .numeric) == .orderedAscending {
            // 9.2.0 & 9.2.1 upgrade steps both need file and keychain access

            if KeychainHelper.accessibilityAttribute == nil {
                SFSDKCoreLogger.log(self, level: .error, message: "Attempt keychain attribute update")
                let result = KeychainHelper.setAccessibleAttribute(.afterFirstUnlockThisDeviceOnly)
                if result.status == errSecInteractionNotAllowed {
                    SFSDKCoreLogger.log(self, level: .error, message: "Upgrade step skipped because keychain access not allowed")
                    return
                }
            }

            let filesWithCompleteProtection = self.filesWithCompleteProtection()
            if !filesWithCompleteProtection.isEmpty {
                if SFApplicationHelper.sharedApplication()?.isProtectedDataAvailable != true {
                    SFSDKCoreLogger.log(self, level: .error, message: "Upgrade step skipped because files have complete protection and protected data isn't available")
                    return
                }
                updateDefaultProtection(filesWithCompleteProtection)
            }
        }

        if lastVersion == nil || lastVersion?.compare("9.2.0", options: .numeric) == .orderedAscending {
            SFDirectoryManager.upgradeUserDirectories()
            URLCache.shared.removeAllCachedResponses()
        }

        if lastVersion == nil || lastVersion?.compare("10.1.1", options: .numeric) == .orderedAscending {
            upgradePasscode()
        }

        setLastVersion(currentVersion)
    }

    private static func filesWithCompleteProtection() -> [String] {
        var filesToReturn: [String] = []

        let directories = [
            SFDirectoryManager.sharedManager.directory(forOrg: nil, user: nil, community: nil, type: .libraryDirectory, components: nil),
            SFDirectoryManager.sharedManager.directory(forOrg: nil, user: nil, community: nil, type: .documentDirectory, components: nil)
        ]

        for directory in directories {
            guard let directory = directory,
                  let directoryURL = URL(string: directory) else { continue }

            guard let enumerator = FileManager.default.enumerator(
                at: directoryURL,
                includingPropertiesForKeys: [.fileProtectionKey],
                options: .producesRelativePathURLs,
                errorHandler: nil
            ) else { continue }

            while let fileURL = enumerator.nextObject() as? URL {
                let fileString = fileURL.relativePath
                // Anything scoped to the org and below, or global stores
                if fileString.hasPrefix("00D") || fileString.hasPrefix("stores") || fileString.hasPrefix("key_value_stores") {
                    var fileProtection: AnyObject?
                    try? (fileURL as NSURL).getResourceValue(&fileProtection, forKey: .fileProtectionKey)
                    if let protectionValue = fileProtection as? String,
                       protectionValue == URLFileProtection.complete.rawValue {
                        filesToReturn.append((directory as NSString).appendingPathComponent(fileString))
                    }
                }
            }
        }
        return filesToReturn
    }

    private static func updateDefaultProtection(_ paths: [String]) {
        for path in paths {
            let fileProtection = FileProtectionHelper.protection(for: path)
            try? FileManager.default.setAttributes(
                [.protectionKey: fileProtection],
                ofItemAtPath: path
            )
        }
    }

    private static func setLastVersion(_ version: String) {
        UserDefaults.msdkUserDefaults().setValue(version, forKey: kSalesforceSDKManagerVersionKey)
        UserDefaults.msdkUserDefaults().synchronize()
        _lastVersion = version
        SFSDKCoreLogger.log(self, level: .info, message: "Upgraded to \(version)")
    }

    private static func lastVersion() -> String? {
        if _lastVersion == nil {
            _lastVersion = UserDefaults.msdkUserDefaults().string(forKey: kSalesforceSDKManagerVersionKey)
        }
        return _lastVersion
    }

    private static func currentVersion() -> String {
        if _currentVersion == nil {
            _currentVersion = Bundle(for: SFSDKSalesforceSDKUpgradeManager.self).infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        }
        return _currentVersion ?? ""
    }

    private static func upgradePasscode() {
        ScreenLockManagerInternal.shared.upgradePasscode()
    }
}
