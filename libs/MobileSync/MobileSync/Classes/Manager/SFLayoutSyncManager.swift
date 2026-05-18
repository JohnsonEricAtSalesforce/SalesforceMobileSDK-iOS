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
import SalesforceSDKCore
import SmartStore

/// Completion block triggered when layout sync completes.

public typealias LayoutSyncCompletionBlock = (_ objectAPIName: String, _ formFactor: String?, _ layoutType: String?, _ mode: String?, _ recordTypeId: String?, _ layout: SFLayout?) -> Void

/// Provides an easy way to fetch layout data using SFLayoutSyncDownTarget.
/// This class handles creating a soup, storing synched data and reading it into
/// a meaningful data structure, i.e. SFLayout.
@objc(SFLayoutSyncManager)
@objcMembers
public class SFLayoutSyncManager: NSObject {

    private static let lock = NSRecursiveLock()
    private static var syncMgrList = [String: SFLayoutSyncManager]()
    private static let indexSpecs: [SFSoupIndex] = [
        SFSoupIndex(path: "Id", indexType: kSoupIndexTypeJSON1, columnName: "Id")!
    ]

    private static let kSoupName = "sfdcLayouts"
    private static let kSFAppFeatureLayoutSync = "LY"
    private static let kQuery = "SELECT {%@:_soup} FROM {%@} WHERE {%@:Id} = '%@-%@-%@-%@-%@'"

    @objc public private(set) var smartStore: SFSmartStore
    @objc public private(set) var syncManager: SFMobileSyncSyncManager

    // MARK: - Shared instance

    @objc public class func sharedInstance() -> SFLayoutSyncManager {
        return sharedInstance(nil)
    }

    @objc public class func sharedInstance(_ user: SFUserAccount?) -> SFLayoutSyncManager {
        return sharedInstance(user, smartStore: nil)
    }

    @objc public class func sharedInstance(_ user: SFUserAccount?, smartStore storeName: String?) -> SFLayoutSyncManager {
        let resolvedUser = user ?? UserAccountManager.shared.currentUserAccount
        guard let resolvedUserNonNil = resolvedUser else { fatalError("No user for SFLayoutSyncManager") }
        guard let syncMgr = SFMobileSyncSyncManager.sharedInstance(named: storeName, forUserAccount: resolvedUserNonNil) else { fatalError("Cannot create SFMobileSyncSyncManager for SFLayoutSyncManager") }

        lock.lock()
        defer { lock.unlock() }

        let keyPrefix = SFKeyForUserAndScope(resolvedUserNonNil, .community) ?? ""
        let key = "\(keyPrefix)-\(syncMgr.store.name)"

        if let existing = syncMgrList[key] {
            SFSDKAppFeatureMarkers.registerAppFeature(kSFAppFeatureLayoutSync)
            return existing
        }

        let instance = SFLayoutSyncManager(syncManager: syncMgr)
        syncMgrList[key] = instance
        SFSDKAppFeatureMarkers.registerAppFeature(kSFAppFeatureLayoutSync)
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

    @objc public func fetchLayout(forObjectAPIName objectAPIName: String, formFactor: String?, layoutType: String?, mode: String?, recordTypeId: String?, syncMode: SFSDKFetchMode, completionBlock: @escaping LayoutSyncCompletionBlock) {
        switch syncMode {
        case .cacheOnly:
            fetchFromCache(objectAPIName, formFactor: formFactor, layoutType: layoutType, mode: mode, recordTypeId: recordTypeId, completionBlock: completionBlock, fallbackOnServer: false)
        case .cacheFirst:
            fetchFromCache(objectAPIName, formFactor: formFactor, layoutType: layoutType, mode: mode, recordTypeId: recordTypeId, completionBlock: completionBlock, fallbackOnServer: true)
        case .serverFirst:
            fetchFromServer(objectAPIName, formFactor: formFactor, layoutType: layoutType, mode: mode, recordTypeId: recordTypeId, completionBlock: completionBlock)
        @unknown default:
            fetchFromServer(objectAPIName, formFactor: formFactor, layoutType: layoutType, mode: mode, recordTypeId: recordTypeId, completionBlock: completionBlock)
        }
    }

    // MARK: - Private

    private func fetchFromServer(_ objectAPIName: String, formFactor: String?, layoutType: String?, mode: String?, recordTypeId: String?, completionBlock: @escaping LayoutSyncCompletionBlock) {
        let target = SFLayoutSyncDownTarget.newSyncTarget(objectAPIName, formFactor: formFactor, layoutType: layoutType, mode: mode, recordTypeId: recordTypeId)
        _ = syncManager.syncDownWithTarget(target, soupName: SFLayoutSyncManager.kSoupName) { [weak self] (sync: SFSyncState) in
            if sync.status == .done {
                self?.fetchFromCache(objectAPIName, formFactor: formFactor, layoutType: layoutType, mode: mode, recordTypeId: recordTypeId, completionBlock: completionBlock, fallbackOnServer: false)
            }
        }
    }

    private func fetchFromCache(_ objectAPIName: String, formFactor: String?, layoutType: String?, mode: String?, recordTypeId: String?, completionBlock: @escaping LayoutSyncCompletionBlock, fallbackOnServer: Bool) {
        let queryString = String(format: SFLayoutSyncManager.kQuery, SFLayoutSyncManager.kSoupName, SFLayoutSyncManager.kSoupName, SFLayoutSyncManager.kSoupName, objectAPIName, formFactor ?? "", layoutType ?? "", mode ?? "", recordTypeId ?? "")
        guard let querySpec = QuerySpec.buildSmartQuerySpec(smartSql: queryString, pageSize: 1) else {
            if fallbackOnServer {
                fetchFromServer(objectAPIName, formFactor: formFactor, layoutType: layoutType, mode: mode, recordTypeId: recordTypeId, completionBlock: completionBlock)
            } else {
                completionBlock(objectAPIName, formFactor, layoutType, mode, recordTypeId, nil)
            }
            return
        }
        let results = try? smartStore.query(using: querySpec, startingFromPageIndex: 0)
        if let results = results, results.count > 0, let row = results[0] as? [Any], let data = row[0] as? NSDictionary {
            completionBlock(objectAPIName, formFactor, layoutType, mode, recordTypeId, SFLayout.from(data as? [AnyHashable: Any] ?? [:]))
        } else {
            if fallbackOnServer {
                fetchFromServer(objectAPIName, formFactor: formFactor, layoutType: layoutType, mode: mode, recordTypeId: recordTypeId, completionBlock: completionBlock)
            } else {
                completionBlock(objectAPIName, formFactor, layoutType, mode, recordTypeId, nil)
            }
        }
    }

    private func initializeSoup() {
        if !smartStore.soupExists(SFLayoutSyncManager.kSoupName) {
            try? smartStore.registerSoup(withName: SFLayoutSyncManager.kSoupName, withIndices: SFLayoutSyncManager.indexSpecs)
        }
    }
}
