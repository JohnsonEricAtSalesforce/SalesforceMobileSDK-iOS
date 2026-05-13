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

/**
 * Class encapsulating syncs definition.
 *
 * Config expected in a resource file in JSON with the following:
 * {
 *     syncs: [
 *          {
 *              syncType: syncUp | syncDown
 *              syncName: xxx
 *              soupName: yyy
 *              target: { depends on target - see SFSyncTarget  }
 *              options: { also depends on target - see SFSyncOptions }
 *          }
 *     ]
 * }
 */
@objc(SFSDKSyncsConfig)
public class SFSDKSyncsConfig: NSObject {

    private var syncConfigs: [[String: Any]]?

    /**
     * Constructor for config stored in resource file
     * @param path to the config file
     * @return instance of SFSDKSyncsConfig
     */
    @objc
    public init?(resourceAtPath path: String) {
        super.init()
        let config = try? SFSDKResourceUtils.loadConfig(fromFile: path)
        self.syncConfigs = config?[kSyncsConfigSyncs] as? [[String: Any]]
    }

    /**
     * Create the syncs from the config in the given store
     * NB: only feedback is through the logs - the config is static so getting it right is something the developer should do while writing the app
     *
     * @param store to create syncs in.
     */
    @objc
    public func createSyncs(_ store: SmartStore) {
        guard let syncConfigs = self.syncConfigs else {
            SFSDKMobileSyncLogger.d(type(of: self), message: "No store config available")
            return
        }

        guard let syncManager = MobileSyncSyncManager.sharedInstance(store: store) else {
            SFSDKMobileSyncLogger.d(type(of: self), message: "Could not get sync manager")
            return
        }

        for syncConfig in syncConfigs {
            guard let syncName = syncConfig.sfsdk_nonNullObject(forKey: kSyncsConfigSyncName) as? String else {
                continue
            }

            // Leaving sync alone if it already exists
            if syncManager.hasSync(forName: syncName) {
                SFSDKMobileSyncLogger.d(type(of: self), message: "Sync already exists:\(syncName) - skipping")
                continue
            }

            guard let syncTypeString = syncConfig[kSyncsConfigSyncType] as? String,
                  let soupName = syncConfig[kSyncsConfigSoupName] as? String else {
                continue
            }

            let syncType = SyncState.syncType(fromString: syncTypeString)
            let syncOptions = SFSyncOptions.newFromDict(syncConfig[kSyncsConfigOptions] as? [String: Any]) ?? SFSyncOptions.newSyncOptions(forSyncDown: syncType == .down ? .overwrite : .leaveIfChanged)
            SFSDKMobileSyncLogger.d(type(of: self), message: "Creating sync: \(syncName)")

            switch syncType {
            case .down:
                if let targetDict = syncConfig[kSyncsConfigTarget] as? [String: Any],
                   let target = SFSyncDownTarget.newFromDict(targetDict) {
                    syncManager.createSyncDown(target, options: syncOptions, soupName: soupName, syncName: syncName)
                }
            case .up:
                if let targetDict = syncConfig[kSyncsConfigTarget] as? [String: Any],
                   let target = SFSyncUpTarget.newFromDict(targetDict) {
                    syncManager.createSyncUp(target, options: syncOptions, soupName: soupName, syncName: syncName)
                }
            @unknown default:
                break
            }
        }
    }

    /**
     * Check for syncs in config
     * @return true if syncs are defined in config
     */
    @objc
    public func hasSyncs() -> Bool {
        return syncConfigs != nil && !(syncConfigs?.isEmpty ?? true)
    }
}
