/*
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
import SalesforceSDKCore
import SmartStore

private let kSyncsConfigSyncs = "syncs"
private let kSyncsConfigSyncName = "syncName"
private let kSyncsConfigSyncType = "syncType"
private let kSyncsConfigOptions = "options"
private let kSyncsConfigSoupName = "soupName"
private let kSyncsConfigTarget = "target"

/// Class encapsulating syncs definition.
///
/// Config expected in a resource file in JSON with the following:
/// ```
/// {
///     syncs: [
///          {
///              syncType: syncUp | syncDown
///              syncName: xxx
///              soupName: yyy
///              target: { depends on target - see SFSyncTarget  }
///              options: { also depends on target - see SFSyncOptions }
///          }
///     ]
/// }
/// ```
@objc(SFSDKSyncsConfig)
@objcMembers
public class SFSDKSyncsConfig: NSObject {

    private var syncConfigs: [[String: Any]]?

    @objc public init?(resourceAtPath path: String) {
        super.init()
        let config = SFSDKResourceUtils.loadConfig(fromFile: path, error: nil) as? [AnyHashable: Any]
        syncConfigs = config?[kSyncsConfigSyncs] as? [[String: Any]]
    }

    @objc public func createSyncs(_ store: SFSmartStore?) {
        guard let store = store, let syncConfigs = syncConfigs else {
            SFSDKMobileSyncLogger.d(type(of: self), message: "No store config available")
            return
        }

        guard let syncManager = SFMobileSyncSyncManager.sharedInstance(store: store) else { return }

        for syncConfig in syncConfigs {
            guard let syncName = (syncConfig as NSDictionary).sfsdk_nonNullObject(forKey: kSyncsConfigSyncName) as? String else { continue }

            // Leaving sync alone if it already exists
            if syncManager.hasSyncWithName(syncName) {
                SFSDKMobileSyncLogger.d(type(of: self), message: "Sync already exists:\(syncName) - skipping")
                continue
            }

            let syncType = SFSyncState.syncType(fromString: syncConfig[kSyncsConfigSyncType] as? String ?? "")
            let syncOptions = SFSyncOptions.new(fromDict: syncConfig[kSyncsConfigOptions] as? [String: Any])
            let soupName = syncConfig[kSyncsConfigSoupName] as? String ?? ""
            SFSDKMobileSyncLogger.d(type(of: self), message: "Creating sync: \(syncName)")

            guard let syncOptions = syncOptions else {
                SFSDKMobileSyncLogger.e(type(of: self), message: "Failed to create sync options for: \(syncName)")
                continue
            }

            switch syncType {
            case .down:
                guard let target = SFSyncDownTarget.newFromDict((syncConfig[kSyncsConfigTarget] as? [String: Any] ?? [:]) as NSDictionary) else {
                    SFSDKMobileSyncLogger.e(type(of: self), message: "Failed to create sync down target for: \(syncName)")
                    continue
                }
                _ = syncManager.createSyncDown(target, options: syncOptions, soupName: soupName, syncName: syncName)
            case .up:
                guard let target = SFSyncUpTarget.newFromDict((syncConfig[kSyncsConfigTarget] as? [String: Any] ?? [:]) as NSDictionary) else {
                    SFSDKMobileSyncLogger.e(type(of: self), message: "Failed to create sync up target for: \(syncName)")
                    continue
                }
                _ = syncManager.createSyncUp(target, options: syncOptions, soupName: soupName, syncName: syncName)
            @unknown default:
                break
            }
        }
    }

    @objc public func hasSyncs() -> Bool {
        return syncConfigs != nil && (syncConfigs?.count ?? 0) > 0
    }
}
