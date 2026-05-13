/*
 Copyright (c) 2014-present, salesforce.com, inc. All rights reserved.

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

// Block type aliases
public typealias SyncDownCompletionBlock = ([Any]?) -> Void
public typealias SyncDownErrorBlock = (Error?) -> Void
public typealias SyncDownTargetFetchCompleteBlock = SyncDownCompletionBlock
public typealias SyncDownTargetFetchErrorBlock = SyncDownErrorBlock

// Query type strings
let kSFSyncTargetQueryTypeMru = "mru"
let kSFSyncTargetQueryTypeSoql = "soql"
let kSFSyncTargetQueryTypeSosl = "sosl"
let kSFSyncTargetQueryTypeRefresh = "refresh"
let kSFSyncTargetQueryTypeParentChildren = "parent_children"
let kSFSyncTargetQueryTypeCustom = "custom"
let kSFSyncTargetQueryTypeMetadata = "metadata"
let kSFSyncTargetQueryTypeLayout = "layout"
let kSFSyncTargetQueryTypeBriefcase = "briefcase"

@objc(SFSyncDownTarget)
open class SyncDownTarget: SyncTarget {

    @objc(SFSyncDownTargetQueryType)
    public enum QueryType: Int {
        case mru
        case sosl
        case soql
        case refresh
        case parentChildren
        case custom
        case metadata
        case layout
        case briefcase
    }

    @objc public var queryType: QueryType = .custom

    // Set during a fetch
    @objc public var totalSize: UInt = 0

    // MARK: - Initialization and serialization methods

    @objc(newFromDict:)
    open class func newFromDict(_ dict: [String: Any]?) -> SyncDownTarget? {
        guard let dict = dict else { return nil }

        // We should have an implementation class or a target type
        if let implClassName = dict[kSFSyncTargetiOSImplKey] as? String, !implClassName.isEmpty {
            guard let customSyncDownClass = NSClassFromString(implClassName) as? SyncDownTarget.Type else {
                SFSDKMobileSyncLogger.e(SyncDownTarget.self, message: "Class '\(implClassName)' is not a subclass of SyncDownTarget.")
                return nil
            }
            return customSyncDownClass.init(dict: dict)
        }
        // No implementation class - using query type
        else {
            switch queryType(from: dict[kSFSyncTargetTypeKey] as? String) {
            case .mru:
                return MruSyncDownTarget(dict: dict)
            case .sosl:
                return SoslSyncDownTarget(dict: dict)
            case .soql:
                return SoqlSyncDownTarget(dict: dict)
            case .refresh:
                return RefreshSyncDownTarget(dict: dict)
            case .parentChildren:
                return ParentChildrenSyncDownTarget(dict: dict)
            case .metadata:
                return MetadataSyncDownTarget(dict: dict)
            case .layout:
                return LayoutSyncDownTarget(dict: dict)
            case .briefcase:
                return BriefcaseSyncDownTarget(dict: dict)
            case .custom:
                SFSDKMobileSyncLogger.e(SyncDownTarget.self, message: "Custom class name not specified.")
                return nil
            }
        }
    }

    open override func asDict() -> [String: Any] {
        var dict = super.asDict()
        dict[kSFSyncTargetTypeKey] = Self.queryType(toString: queryType)
        return dict
    }

    // MARK: - Public sync down methods

    @objc(startFetch:maxTimeStamp:onFail:onComplete:)
    open func startFetch(syncManager: SFMobileSyncSyncManager,
                         maxTimeStamp: Int64,
                         onFail errorBlock: @escaping SyncDownErrorBlock,
                         onComplete completeBlock: @escaping SyncDownCompletionBlock) {
        fatalError("Abstract method - must be overridden by subclass")
    }

    @objc(continueFetch:onFail:onComplete:)
    open func continueFetch(syncManager: SFMobileSyncSyncManager,
                           onFail errorBlock: @escaping SyncDownErrorBlock,
                           onComplete completeBlock: SyncDownCompletionBlock?) {
        completeBlock?(nil)
    }

    @objc
    open func getRemoteIds(syncManager: SFMobileSyncSyncManager,
                          localIds: [Any],
                          errorBlock: @escaping SyncDownErrorBlock,
                          completeBlock: @escaping SyncDownCompletionBlock) {
        fatalError("Abstract method - must be overridden by subclass")
    }

    @objc
    open func getLatestModificationTimeStamp(_ records: [Any]) -> Int64 {
        return getLatestModificationTimeStamp(records, modificationDateFieldName: modificationDateFieldName)
    }

    @objc
    open func isSyncDownSortedByLatestModification() -> Bool {
        return false
    }

    @objc(cleanGhosts:soupName:syncId:onFail:onComplete:)
    open func cleanGhosts(syncManager: SFMobileSyncSyncManager,
                         soupName: String,
                         syncId: NSNumber,
                         onFail errorBlock: @escaping SyncDownErrorBlock,
                         onComplete completeBlock: @escaping SyncDownCompletionBlock) {
        // Fetches list of IDs present in local soup that have not been modified locally.
        var localIds = getNonDirtyRecordIds(syncManager: syncManager,
                                           soupName: soupName,
                                           idField: idFieldName,
                                           additionalPredicate: buildSyncIdPredicateIfIndexed(syncManager: syncManager,
                                                                                             soupName: soupName,
                                                                                             syncId: syncId))

        if localIds.count == 0 {
            completeBlock([])
            return
        }

        // Fetches list of IDs still present on the server from the list of local IDs
        // and removes the list of IDs that are still present on the server.
        var localIdsArr = localIds.array
        getRemoteIds(syncManager: syncManager,
                    localIds: localIdsArr,
                    errorBlock: errorBlock) { [weak self] remoteIds in
            guard let self = self, let remoteIds = remoteIds else { return }
            let localIdsSet = NSMutableOrderedSet(array: localIdsArr)
            let remoteIdsSet = NSOrderedSet(array: remoteIds)
            localIdsSet.minus(remoteIdsSet)
            localIdsArr = localIdsSet.array
            // Deletes extra IDs from SmartStore.
            self.deleteRecordsFromLocalStore(syncManager,
                                            soupName: soupName,
                                            ids: localIdsArr,
                                            idField: self.idFieldName)
            completeBlock(localIdsArr)
        }
    }

    @objc
    open func getIdsToSkip(syncManager: SFMobileSyncSyncManager, soupName: String) -> NSOrderedSet {
        return getDirtyRecordIds(syncManager, soupName: soupName, idField: idFieldName)
    }

    // MARK: - String to/from enum for query type

    @objc(queryTypeFromString:)
    open class func queryType(from queryType: String?) -> QueryType {
        guard let queryType = queryType else { return .custom }

        switch queryType {
        case kSFSyncTargetQueryTypeSoql:
            return .soql
        case kSFSyncTargetQueryTypeMru:
            return .mru
        case kSFSyncTargetQueryTypeSosl:
            return .sosl
        case kSFSyncTargetQueryTypeRefresh:
            return .refresh
        case kSFSyncTargetQueryTypeParentChildren:
            return .parentChildren
        case kSFSyncTargetQueryTypeMetadata:
            return .metadata
        case kSFSyncTargetQueryTypeLayout:
            return .layout
        case kSFSyncTargetQueryTypeBriefcase:
            return .briefcase
        default:
            return .custom
        }
    }

    @objc(queryTypeToString:)
    open class func queryType(toString queryType: QueryType) -> String {
        switch queryType {
        case .mru:
            return kSFSyncTargetQueryTypeMru
        case .sosl:
            return kSFSyncTargetQueryTypeSosl
        case .soql:
            return kSFSyncTargetQueryTypeSoql
        case .refresh:
            return kSFSyncTargetQueryTypeRefresh
        case .parentChildren:
            return kSFSyncTargetQueryTypeParentChildren
        case .custom:
            return kSFSyncTargetQueryTypeCustom
        case .metadata:
            return kSFSyncTargetQueryTypeMetadata
        case .layout:
            return kSFSyncTargetQueryTypeLayout
        case .briefcase:
            return kSFSyncTargetQueryTypeBriefcase
        }
    }

    // MARK: - Helper methods (Internal)

    @objc
    func buildSyncIdPredicateIfIndexed(syncManager: SFMobileSyncSyncManager,
                                       soupName: String,
                                       syncId: NSNumber) -> String {
        let indexSpecs = syncManager.store.indices(forSoupNamed: soupName)

        for indexSpec in indexSpecs {
            if indexSpec.path == syncTargetSyncId {
                return "AND {\(soupName):\(syncTargetSyncId)} = \(syncId.stringValue)"
            }
        }
        return ""
    }

    @objc
    func getNonDirtyRecordIds(syncManager: SFMobileSyncSyncManager,
                             soupName: String,
                             idField: String,
                             additionalPredicate: String) -> NSOrderedSet {
        let nonDirtyRecordsSql = getNonDirtyRecordIdsSql(soupName: soupName,
                                                         idField: idField,
                                                         additionalPredicate: additionalPredicate)
        return getIdsWithQuery(nonDirtyRecordsSql, syncManager: syncManager)
    }

    @objc
    func getNonDirtyRecordIdsSql(soupName: String,
                                 idField: String,
                                 additionalPredicate: String) -> String {
        return "SELECT {\(soupName):\(idField)} FROM {\(soupName)} WHERE {\(soupName):\(syncTargetLocal)} = '0' \(additionalPredicate) ORDER BY {\(soupName):\(idField)} ASC"
    }

    @objc
    func getLatestModificationTimeStamp(_ records: [Any],
                                       modificationDateFieldName: String) -> Int64 {
        var maxTimeStamp: Int64 = -1
        for record in records {
            guard let recordDict = record as? [String: Any],
                  let timeStampStr = recordDict[modificationDateFieldName] as? String else {
                break // LastModifiedDate field not present
            }
            let timeStamp = FormatUtils.getMillisFromIsoString(timeStampStr)
            maxTimeStamp = max(timeStamp, maxTimeStamp)
        }
        return maxTimeStamp
    }

    // MARK: - Additional helper methods (migrated from extension)

    @objc
    func idsWithQuery(_ query: String, syncManager: MobileSyncSyncManager) throws -> NSOrderedSet {
        guard let querySpec = QuerySpec.buildSmartQuerySpec(smartSql: query, pageSize: UInt(SyncTarget.pageSize)) else {
            return NSOrderedSet()
        }

        let ids = NSMutableOrderedSet()
        var pageIndex: UInt = 0
        var hasMore = true

        while hasMore {
            let results = try syncManager.store.query(using: querySpec, startingFromPageIndex: pageIndex)
            hasMore = (results.count) == SyncTarget.pageSize
            if results.count > 0 {
                pageIndex += 1
                ids.addObjects(from: results.compactMap { ($0 as? [Any])?.first })
            } else {
                hasMore = false
            }
        }
        return ids
    }
}
