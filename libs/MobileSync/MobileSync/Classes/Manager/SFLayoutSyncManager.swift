/*
 SFLayoutSyncManager.swift
 MobileSync

 Created by Bharath Hariharan on 5/18/18.

 Copyright (c) 2018-present, salesforce.com, inc. All rights reserved.

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
import SmartStore
import SalesforceSDKCore

private let kSoupName = "sfdcLayouts"
private let kSFAppFeatureLayoutSync = "LY"
private let kQuery = "SELECT {%@:_soup} FROM {%@} WHERE {%@:Id} = '%@-%@-%@-%@-%@'"

/**
 * Completion block triggered when layout sync completes.
 *
 * @param objectAPIName Object API name.
 * @param formFactor Form factor.
 * @param layoutType Layout type.
 * @param mode Mode.
 * @param recordTypeId Record type ID.
 * @param layout Layout.
 */
public typealias LayoutSyncCompletionBlock = (String, String?, String?, String?, String?, SFLayout?) -> Void

/**
 * Provides an easy way to fetch layout data using SFLayoutSyncDownTarget.
 * This class handles creating a soup, storing synched data and reading it into
 * a meaningful data structure, i.e. SFLayout.
 */
@objc(SFLayoutSyncManager)
public class SFLayoutSyncManager: NSObject {

    @objc public private(set) var smartStore: SmartStore
    @objc public private(set) var syncManager: SFMobileSyncSyncManager

    private static var syncMgrList = [String: SFLayoutSyncManager]()
    private static var indexSpecs: [SoupIndex] = {
        return [SoupIndex(path: "Id", indexType: kSoupIndexTypeJSON1, columnName: "Id")!]
    }()

    /**
     * Returns the instance of this class associated with current user.
     *
     * @return Instance of this class.
     */
    @objc
    public class func sharedInstance() -> SFLayoutSyncManager {
        return SFLayoutSyncManager.sharedInstance(nil)
    }

    /**
     * Returns the instance of this class associated with this user account.
     *
     * @param user User account.
     * @return Instance of this class.
     */
    @objc
    public class func sharedInstance(_ user: SFUserAccount?) -> SFLayoutSyncManager {
        return SFLayoutSyncManager.sharedInstance(user, smartStore: nil)
    }

    /**
     * Returns the instance of this class associated with this user and SmartStore.
     *
     * @param user User account. Pass null to use current user.
     * @param smartStore SmartStore name. Pass nil to use current user default SmartStore.
     * @return Instance of this class.
     */
    @objc
    public class func sharedInstance(_ user: SFUserAccount?, smartStore: String?) -> SFLayoutSyncManager {
        let currentUser = user ?? UserAccountManager.shared.currentUserAccount
        guard let syncManager = SFMobileSyncSyncManager.sharedInstance(named: smartStore, forUserAccount: currentUser!) else {
            fatalError("Failed to get sync manager")
        }

        return objc_sync_enter(SFLayoutSyncManager.self) {
            let keyPrefix = currentUser == nil
                ? SFKeyForUserAndScope(nil, .global)
                : SFKeyForUserAndScope(currentUser, .community)
            let key = "\(keyPrefix)-\(syncManager.store.name)"

            if let syncMgr = syncMgrList[key] {
                SFSDKAppFeatureMarkers.registerAppFeature(kSFAppFeatureLayoutSync)
                return syncMgr
            } else {
                let syncMgr = SFLayoutSyncManager(syncManager: syncManager)
                syncMgrList[key] = syncMgr
                SFSDKAppFeatureMarkers.registerAppFeature(kSFAppFeatureLayoutSync)
                return syncMgr
            }
        }
    }

    /**
     * Resets all the layout sync managers.
     */
    @objc
    public class func reset() {
        objc_sync_enter(SFLayoutSyncManager.self)
        defer { objc_sync_exit(SFLayoutSyncManager.self) }
        syncMgrList.removeAll()
    }

    /**
     * Resets the layout sync manager for this user account.
     *
     * @param user User account.
     */
    @objc
    public class func reset(_ user: SFUserAccount?) {
        objc_sync_enter(SFLayoutSyncManager.self)
        defer { objc_sync_exit(SFLayoutSyncManager.self) }

        if let user = user {
            let matchingKey = SFKeyForUserAndScope(user, .community)
            let keys = Array(syncMgrList.keys)
            for key in keys {
                if key.hasPrefix(matchingKey) {
                    syncMgrList.removeValue(forKey: key)
                }
            }
        }
    }

    /**
     * Fetches layout data for the specified parameters using the specified sync
     * mode and triggers the supplied completion block once complete.
     *
     * @param objectAPIName Object API name.
     * @param formFactor Form factor. Could be "Large", "Medium" or "Small". Default value is "Large".
     * @param layoutType Layout type. Defaults to "Full" if nil is passed in.
     * @param mode Mode. Could be "Create", "Edit" or "View". Default value is "View".
     * @param recordTypeId Record type ID. Default will be used if not supplied.
     * @param syncMode Fetch mode. See SFSDKFetchMode for available modes.
     * @param completionBlock Layout sync completion block.
     */
    @objc
    public func fetchLayout(forObjectAPIName objectAPIName: String,
                           formFactor: String?,
                           layoutType: String?,
                           mode: String?,
                           recordTypeId: String?,
                           syncMode: SFSDKFetchMode,
                           completionBlock: @escaping LayoutSyncCompletionBlock) {
        switch syncMode {
        case .cacheOnly:
            fetchFromCache(objectAPIName, formFactor: formFactor, layoutType: layoutType, mode: mode, recordTypeId: recordTypeId, completionBlock: completionBlock, fallbackOnServer: false)
        case .cacheFirst:
            fetchFromCache(objectAPIName, formFactor: formFactor, layoutType: layoutType, mode: mode, recordTypeId: recordTypeId, completionBlock: completionBlock, fallbackOnServer: true)
        case .serverFirst:
            fetchFromServer(objectAPIName, formFactor: formFactor, layoutType: layoutType, mode: mode, recordTypeId: recordTypeId, completionBlock: completionBlock)
        @unknown default:
            completionBlock(objectAPIName, formFactor, layoutType, mode, recordTypeId, nil)
        }
    }

    private init(syncManager: SFMobileSyncSyncManager) {
        self.syncManager = syncManager
        self.smartStore = syncManager.store
        super.init()
        initializeSoup()
    }

    private func fetchFromServer(_ objectAPIName: String,
                                formFactor: String?,
                                layoutType: String?,
                                mode: String?,
                                recordTypeId: String?,
                                completionBlock: @escaping LayoutSyncCompletionBlock) {
        let target = LayoutSyncDownTarget.newSyncTarget(objectAPIName, formFactor: formFactor, layoutType: layoutType, mode: mode, recordTypeId: recordTypeId)
        _ = syncManager.syncDown(target: target, soupName: kSoupName, onUpdate: { [weak self] sync in
            guard let self = self else { return }
            if sync.status == .done {
                self.fetchFromCache(objectAPIName, formFactor: formFactor, layoutType: layoutType, mode: mode, recordTypeId: recordTypeId, completionBlock: completionBlock, fallbackOnServer: false)
            }
        })
    }

    private func fetchFromCache(_ objectAPIName: String,
                               formFactor: String?,
                               layoutType: String?,
                               mode: String?,
                               recordTypeId: String?,
                               completionBlock: @escaping LayoutSyncCompletionBlock,
                               fallbackOnServer: Bool) {
        let query = String(format: kQuery, kSoupName, kSoupName, kSoupName, objectAPIName, formFactor ?? "", layoutType ?? "", mode ?? "", recordTypeId ?? "")
        guard let querySpec = QuerySpec.buildSmartQuerySpec(smartSql: query, pageSize: 1) else {
            if fallbackOnServer {
                fetchFromServer(objectAPIName, formFactor: formFactor, layoutType: layoutType, mode: mode, recordTypeId: recordTypeId, completionBlock: completionBlock)
            } else {
                completionBlock(objectAPIName, formFactor, layoutType, mode, recordTypeId, nil)
            }
            return
        }

        let results = try? smartStore.query(using: querySpec, startingFromPageIndex: 0)

        if let results = results, !results.isEmpty, let firstResult = results[0] as? [Any], !firstResult.isEmpty {
            if let layoutDict = firstResult[0] as? [String: Any] {
                completionBlock(objectAPIName, formFactor, layoutType, mode, recordTypeId, SFLayout.from(json: layoutDict))
            } else {
                completionBlock(objectAPIName, formFactor, layoutType, mode, recordTypeId, nil)
            }
        } else {
            if fallbackOnServer {
                fetchFromServer(objectAPIName, formFactor: formFactor, layoutType: layoutType, mode: mode, recordTypeId: recordTypeId, completionBlock: completionBlock)
            } else {
                completionBlock(objectAPIName, formFactor, layoutType, mode, recordTypeId, nil)
            }
        }
    }

    private func initializeSoup() {
        if !smartStore.soupExists(forName: kSoupName) {
            try? smartStore.registerSoup(withName: kSoupName, withIndices: SFLayoutSyncManager.indexSpecs)
        }
    }
}

// Helper function for synchronized blocks
private func objc_sync_enter<T>(_ obj: AnyObject, closure: () -> T) -> T {
    objc_sync_enter(obj)
    defer { objc_sync_exit(obj) }
    return closure()
}
