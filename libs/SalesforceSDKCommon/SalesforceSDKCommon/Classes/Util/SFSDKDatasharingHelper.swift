/*
 SFSDKDatasharingHelper.swift
 SalesforceSDKCommon

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

/// Helper class for managing app data sharing settings via app groups.
@objc(SFSDKDatasharingHelper)
@objcMembers
public class SFSDKDatasharingHelper: NSObject {

    // MARK: - Constants

    private static let kAppGroupEnabled = "kAccessGroupEnabled"
    private static let kAppGroupName = "KAppGroupName"
    private static let kDidMigrateToAppGroupsKey = "kAppDefaultsMigratedToAppGroups"

    // MARK: - Singleton

    /// Shared singleton instance.
    @objc public static let sharedInstance = SFSDKDatasharingHelper()

    private override init() {
        super.init()
    }

    // MARK: - Properties

    /// Name of the app group to use to share data.
    @objc public var appGroupName: String? {
        get {
            return UserDefaults.standard.string(forKey: SFSDKDatasharingHelper.kAppGroupName)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: SFSDKDatasharingHelper.kAppGroupName)
            UserDefaults.standard.synchronize()
        }
    }

    /// Set to YES to enable app group.
    @objc public var appGroupEnabled: Bool {
        get {
            guard let groupName = appGroupName else { return false }
            let sharedDefaults = UserDefaults(suiteName: groupName)
            return sharedDefaults?.bool(forKey: SFSDKDatasharingHelper.kAppGroupEnabled) ?? false
        }
        set {
            guard let groupName = appGroupName,
                  let sharedDefaults = UserDefaults(suiteName: groupName) else { return }
            sharedDefaults.set(newValue, forKey: SFSDKDatasharingHelper.kAppGroupEnabled)
            sharedDefaults.synchronize()
            if newValue {
                migrateUserDefaultsToAppContainer(sharedDefaults)
            } else {
                migrateFromAppContainerToUserDefaults(sharedDefaults)
            }
        }
    }

    // MARK: - Migration

    private func migrateUserDefaultsToAppContainer(_ sharedDefaults: UserDefaults) {
        guard appGroupEnabled,
              !UserDefaults.standard.bool(forKey: SFSDKDatasharingHelper.kDidMigrateToAppGroupsKey) else { return }

        SalesforceLogger.w(SFSDKDatasharingHelper.self, message: "Ensure that you have enabled app-groups for your app in the entitlements for your app.")
        UserDefaults.standard.set(true, forKey: SFSDKDatasharingHelper.kDidMigrateToAppGroupsKey)
        migrate(from: UserDefaults.standard, to: sharedDefaults)
        UserDefaults.standard.synchronize()
    }

    private func migrateFromAppContainerToUserDefaults(_ sharedDefaults: UserDefaults) {
        guard !appGroupEnabled,
              UserDefaults.standard.bool(forKey: SFSDKDatasharingHelper.kDidMigrateToAppGroupsKey) else { return }

        SalesforceLogger.w(SFSDKDatasharingHelper.self, message: "Ensure that you have not disabled app-groups for your app in the entitlements. Data will not be migrated from app containers if app-groups are disabled")
        UserDefaults.standard.set(false, forKey: SFSDKDatasharingHelper.kDidMigrateToAppGroupsKey)
        migrate(from: sharedDefaults, to: UserDefaults.standard)
        UserDefaults.standard.synchronize()
    }

    private func migrate(from source: UserDefaults, to target: UserDefaults) {
        let sourceDictionary = source.dictionaryRepresentation()
        for (key, value) in sourceDictionary {
            target.set(value, forKey: key)
        }
        target.synchronize()
    }
}
