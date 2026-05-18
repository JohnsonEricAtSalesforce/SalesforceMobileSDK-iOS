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
import SalesforceSDKCore
import SmartStore

/// Completion block triggered when metadata sync completes.

public typealias MetadataSyncCompletionBlock = (_ metadata: SFMetadata?) -> Void

/// Provides an easy way to fetch metadata using SFMetadataSyncDownTarget.
/// This class handles creating a soup, storing synched data and reading it into
/// a meaningful data structure, i.e. SFMetadata.
@objc(SFMetadataSyncManager)
@objcMembers
public class SFMetadataSyncManager: NSObject {

    private static let lock = NSRecursiveLock()
    private static var syncMgrList = [String: SFMetadataSyncManager]()
    private static let indexSpecs: [SFSoupIndex] = [
        SFSoupIndex(path: "Id", indexType: kSoupIndexTypeJSON1, columnName: "Id")!
    ]

    private static let kSoupName = "sfdcMetadata"
    private static let kSFAppFeatureMetadataSync = "MD"
    private static let kQuery = "SELECT {%@:_soup} FROM {%@} WHERE {%@:Id} = '%@'"

    @objc public private(set) var smartStore: SFSmartStore
    @objc public private(set) var syncManager: SFMobileSyncSyncManager

    // MARK: - Shared instance

    @objc public class func sharedInstance() -> SFMetadataSyncManager {
        return sharedInstance(nil)
    }

    @objc public class func sharedInstance(_ user: SFUserAccount?) -> SFMetadataSyncManager {
        return sharedInstance(user, smartStore: nil)
    }

    @objc public class func sharedInstance(_ user: SFUserAccount?, smartStore storeName: String?) -> SFMetadataSyncManager {
        let resolvedUser = user ?? UserAccountManager.shared.currentUserAccount
        guard let resolvedUserNonNil = resolvedUser else { fatalError("No user for SFMetadataSyncManager") }
        guard let syncMgr = SFMobileSyncSyncManager.sharedInstance(named: storeName, forUserAccount: resolvedUserNonNil) else { fatalError("Cannot create SFMobileSyncSyncManager for SFMetadataSyncManager") }

        lock.lock()
        defer { lock.unlock() }

        let keyPrefix = SFKeyForUserAndScope(resolvedUserNonNil, .community) ?? ""
        let key = "\(keyPrefix)-\(syncMgr.store.name)"

        if let existing = syncMgrList[key] {
            SFSDKAppFeatureMarkers.registerAppFeature(kSFAppFeatureMetadataSync)
            return existing
        }

        let instance = SFMetadataSyncManager(syncManager: syncMgr)
        syncMgrList[key] = instance
        SFSDKAppFeatureMarkers.registerAppFeature(kSFAppFeatureMetadataSync)
        return instance
    }

    // MARK: - Reset

    @objc public class func reset() {
        lock.lock()
        defer { lock.unlock() }
        syncMgrList.removeAll()
    }

    @objc public class func reset(_ user: SFUserAccount?) {
        lock.lock()
        defer { lock.unlock() }
        guard let user = user else { return }
        guard let matchingKey = SFKeyForUserAndScope(user, .community) else { return }
        let keys = syncMgrList.keys.filter { $0.hasPrefix(matchingKey) }
        for key in keys {
            syncMgrList.removeValue(forKey: key)
        }
    }

    // MARK: - Init

    private init(syncManager: SFMobileSyncSyncManager) {
        self.syncManager = syncManager
        self.smartStore = syncManager.store
        super.init()
        initializeSoup()
    }

    // MARK: - Fetch

    @objc public func fetchMetadata(forObject objectType: String, mode: SFSDKFetchMode, completionBlock: @escaping MetadataSyncCompletionBlock) {
        switch mode {
        case .cacheOnly:
            fetchFromCache(objectType, completionBlock: completionBlock, fallbackOnServer: false)
        case .cacheFirst:
            fetchFromCache(objectType, completionBlock: completionBlock, fallbackOnServer: true)
        case .serverFirst:
            fetchFromServer(objectType, completionBlock: completionBlock)
        @unknown default:
            fetchFromServer(objectType, completionBlock: completionBlock)
        }
    }

    // MARK: - Private

    private func fetchFromServer(_ objectType: String, completionBlock: @escaping MetadataSyncCompletionBlock) {
        let target = SFMetadataSyncDownTarget.newSyncTarget(objectType)
        _ = syncManager.syncDownWithTarget(target, soupName: SFMetadataSyncManager.kSoupName) { [weak self] (sync: SFSyncState) in
            if sync.status == .done {
                self?.fetchFromCache(objectType, completionBlock: completionBlock, fallbackOnServer: false)
            } else if sync.status == .failed {
                completionBlock(nil)
            }
        }
    }

    private func fetchFromCache(_ objectType: String, completionBlock: @escaping MetadataSyncCompletionBlock, fallbackOnServer: Bool) {
        let queryString = String(format: SFMetadataSyncManager.kQuery, SFMetadataSyncManager.kSoupName, SFMetadataSyncManager.kSoupName, SFMetadataSyncManager.kSoupName, objectType)
        guard let querySpec = QuerySpec.buildSmartQuerySpec(smartSql: queryString, pageSize: 1) else {
            if fallbackOnServer {
                fetchFromServer(objectType, completionBlock: completionBlock)
            } else {
                completionBlock(nil)
            }
            return
        }
        let results = try? smartStore.query(using: querySpec, startingFromPageIndex: 0)
        if let results = results, results.count > 0, let row = results[0] as? [Any], let data = row[0] as? NSDictionary {
            completionBlock(SFMetadata.from(data as? [AnyHashable: Any] ?? [:]))
        } else {
            if fallbackOnServer {
                fetchFromServer(objectType, completionBlock: completionBlock)
            } else {
                completionBlock(nil)
            }
        }
    }

    private func initializeSoup() {
        if !smartStore.soupExists(SFMetadataSyncManager.kSoupName) {
            try? smartStore.registerSoup(withName: SFMetadataSyncManager.kSoupName, withIndices: SFMetadataSyncManager.indexSpecs)
        }
    }
}
