/*
 SFMetadataSyncManager.swift
 MobileSync

 Created by Bharath Hariharan on 5/24/18.

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

private let kSoupName = "sfdcMetadata"
private let kSFAppFeatureMetadataSync = "MD"
private let kQuery = "SELECT {%@:_soup} FROM {%@} WHERE {%@:Id} = '%@'"

/**
 * Completion block triggered when metadata sync completes.
 *
 * @param metadata Metadata.
 */
public typealias MetadataSyncCompletionBlock = (SFMetadata?) -> Void

/**
 * Provides an easy way to fetch metadata using SFMetadataSyncDownTarget.
 * This class handles creating a soup, storing synched data and reading it into
 * a meaningful data structure, i.e. SFMetadata.
 */
@objc(SFMetadataSyncManager)
public class SFMetadataSyncManager: NSObject {

    @objc public private(set) var smartStore: SmartStore
    @objc public private(set) var syncManager: SFMobileSyncSyncManager

    private static var syncMgrList = [String: SFMetadataSyncManager]()
    private static var indexSpecs: [SoupIndex] = {
        return [SoupIndex(path: "Id", indexType: kSoupIndexTypeJSON1, columnName: "Id")!]
    }()

    /**
     * Returns the instance of this class associated with current user.
     *
     * @return Instance of this class.
     */
    @objc
    public class func sharedInstance() -> SFMetadataSyncManager {
        return SFMetadataSyncManager.sharedInstance(nil)
    }

    /**
     * Returns the instance of this class associated with this user account.
     *
     * @param user User account.
     * @return Instance of this class.
     */
    @objc
    public class func sharedInstance(_ user: SFUserAccount?) -> SFMetadataSyncManager {
        return SFMetadataSyncManager.sharedInstance(user, smartStore: nil)
    }

    /**
     * Returns the instance of this class associated with this user and SmartStore.
     *
     * @param user User account. Pass null to use current user.
     * @param smartStore SmartStore name. Pass nil to use current user default SmartStore.
     * @return Instance of this class.
     */
    @objc
    public class func sharedInstance(_ user: SFUserAccount?, smartStore: String?) -> SFMetadataSyncManager {
        let currentUser = user ?? UserAccountManager.shared.currentUserAccount
        guard let store = smartStore != nil ? SmartStore.shared(withName: smartStore!, forUserAccount: currentUser) : nil else { fatalError("SmartStore required") }
        guard let syncManager = SFMobileSyncSyncManager.sharedInstance(store: store) else { fatalError("SyncManager required") }

        return objc_sync_enter(SFMetadataSyncManager.self) {
            let keyPrefix = currentUser == nil
                ? SFKeyForUserAndScope(nil, .global)
                : SFKeyForUserAndScope(currentUser, .community)
            let key = "\(keyPrefix)-\(syncManager.store.name)"

            if let syncMgr = syncMgrList[key] {
                SFSDKAppFeatureMarkers.registerAppFeature(kSFAppFeatureMetadataSync)
                return syncMgr
            } else {
                let syncMgr = SFMetadataSyncManager(syncManager: syncManager)
                syncMgrList[key] = syncMgr
                SFSDKAppFeatureMarkers.registerAppFeature(kSFAppFeatureMetadataSync)
                return syncMgr
            }
        }
    }

    /**
     * Resets all the metadata sync managers.
     */
    @objc
    public class func reset() {
        objc_sync_enter(SFMetadataSyncManager.self)
        defer { objc_sync_exit(SFMetadataSyncManager.self) }
        syncMgrList.removeAll()
    }

    /**
     * Resets the metadata sync manager for this user account.
     *
     * @param user User account.
     */
    @objc
    public class func reset(_ user: SFUserAccount?) {
        objc_sync_enter(SFMetadataSyncManager.self)
        defer { objc_sync_exit(SFMetadataSyncManager.self) }

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
     * Fetches metadata for the specified object type using the specified
     * mode and triggers the supplied completion block once complete.
     *
     * @param objectType Object type.
     * @param mode Fetch mode. See SFSDKFetchMode for available modes.
     * @param completionBlock Metadata sync completion block.
     */
    @objc
    public func fetchMetadata(forObject objectType: String, mode: SFSDKFetchMode, completionBlock: @escaping MetadataSyncCompletionBlock) {
        switch mode {
        case .cacheOnly:
            fetchFromCache(objectType, completionBlock: completionBlock, fallbackOnServer: false)
        case .cacheFirst:
            fetchFromCache(objectType, completionBlock: completionBlock, fallbackOnServer: true)
        case .serverFirst:
            fetchFromServer(objectType, completionBlock: completionBlock)
        @unknown default:
            completionBlock(nil)
        }
    }

    private init(syncManager: SFMobileSyncSyncManager) {
        self.syncManager = syncManager
        self.smartStore = syncManager.store
        super.init()
        initializeSoup()
    }

    private func fetchFromServer(_ objectType: String, completionBlock: @escaping MetadataSyncCompletionBlock) {
        let target = MetadataSyncDownTarget.newSyncTarget(objectType)
        syncManager.syncDown(target: target, soupName: kSoupName) { [weak self] sync in
            guard let self = self else { return }
            if sync.status == .done {
                self.fetchFromCache(objectType, completionBlock: completionBlock, fallbackOnServer: false)
            } else if sync.status == .failed {
                completionBlock(nil)
            }
        }
    }

    private func fetchFromCache(_ objectType: String, completionBlock: @escaping MetadataSyncCompletionBlock, fallbackOnServer: Bool) {
        let query = String(format: kQuery, kSoupName, kSoupName, kSoupName, objectType)
        guard let querySpec = QuerySpec.buildSmartQuerySpec(smartSql: query, pageSize: 1) else { return }
        let results = try? smartStore.query(using: querySpec, startingFromPageIndex: 0)

        if let results = results, !results.isEmpty, let firstResult = results[0] as? [Any], !firstResult.isEmpty {
            if let metadataDict = firstResult[0] as? [String: Any] {
                completionBlock(SFMetadata.from(json: metadataDict))
            } else {
                completionBlock(nil)
            }
        } else {
            if fallbackOnServer {
                fetchFromServer(objectType, completionBlock: completionBlock)
            } else {
                completionBlock(nil)
            }
        }
    }

    private func initializeSoup() {
        if !smartStore.soupExists(forName: kSoupName) {
            do {
                try smartStore.registerSoup(withName: kSoupName, withIndices: SFMetadataSyncManager.indexSpecs)
            } catch {
                SFSDKMobileSyncLogger.e(type(of: self), message: "Failed to register soup: \(error)")
            }
        }
    }
}

// Helper function for synchronized blocks
private func objc_sync_enter<T>(_ obj: AnyObject, closure: () -> T) -> T {
    objc_sync_enter(obj)
    defer { objc_sync_exit(obj) }
    return closure()
}
