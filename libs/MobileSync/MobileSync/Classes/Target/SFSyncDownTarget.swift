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

// Query type string constants
public let kSFSyncTargetQueryTypeMru = "mru"
public let kSFSyncTargetQueryTypeSoql = "soql"
public let kSFSyncTargetQueryTypeSosl = "sosl"
public let kSFSyncTargetQueryTypeRefresh = "refresh"
public let kSFSyncTargetQueryTypeParentChildren = "parent_children"
public let kSFSyncTargetQueryTypeCustom = "custom"
public let kSFSyncTargetQueryTypeMetadata = "metadata"
public let kSFSyncTargetQueryTypeLayout = "layout"
public let kSFSyncTargetQueryTypeBriefcase = "briefcase"

// Completion block typedefs
public typealias SFSyncDownTargetFetchCompleteBlock = ([Any]?) -> Void
public typealias SFSyncDownTargetFetchErrorBlock = (Error?) -> Void

@objc
public enum SFSyncDownTargetQueryType: Int {
    case mru = 0
    case sosl
    case soql
    case refresh
    case parentChildren
    case custom
    case metadata
    case layout
    case briefcase
}

@objc(SFSyncDownTarget)
@objcMembers
open class SFSyncDownTarget: SFSyncTarget {

    open var queryType: SFSyncDownTargetQueryType = .custom
    open var totalSize: UInt = 0

    // MARK: - Factory

    @objc
    open class func newFromDict(_ dict: NSDictionary) -> SFSyncDownTarget? {
        let dictionary = dict as? [String: Any] ?? [:]
        // We should have an implementation class or a target type
        if let implClassName = dictionary[kSFSyncTargetiOSImplKey] as? String, !implClassName.isEmpty {
            guard let customClass = NSClassFromString(implClassName) as? SFSyncDownTarget.Type else {
                SFSDKMobileSyncLogger.e(self, message: "\(#function) Class '\(implClassName)' is not a subclass of \(NSStringFromClass(SFSyncDownTarget.self)).")
                return nil
            }
            return customClass.init(dict: dict)
        } else {
            // No implementation class - using query type
            let queryTypeStr = dictionary[kSFSyncTargetTypeKey] as? String ?? ""
            switch SFSyncDownTarget.queryTypeFromString(queryTypeStr) {
            case .mru:
                return SFMruSyncDownTarget(dict: dict)
            case .sosl:
                return SFSoslSyncDownTarget(dict: dict)
            case .soql:
                return SFSoqlSyncDownTarget(dict: dict)
            case .refresh:
                return SFRefreshSyncDownTarget(dict: dict)
            case .parentChildren:
                return SFParentChildrenSyncDownTarget(dict: dict)
            case .metadata:
                return SFMetadataSyncDownTarget(dict: dict)
            case .layout:
                return SFLayoutSyncDownTarget(dict: dict)
            case .briefcase:
                return SFBriefcaseSyncDownTarget(dict: dict)
            case .custom:
                SFSDKMobileSyncLogger.e(self, message: "\(#function) Custom class name not specified.")
                return nil
            @unknown default:
                return nil
            }
        }
    }

    // MARK: - Serialization

    open override func asDict() -> NSMutableDictionary {
        let dict = super.asDict()
        dict[kSFSyncTargetTypeKey] = SFSyncDownTarget.queryTypeToString(self.queryType)
        return dict
    }

    // MARK: - Fetch methods (open for subclass override)

    @objc(startFetch:maxTimeStamp:onFail:onComplete:)
    open func startFetch(_ syncManager: SFMobileSyncSyncManager, maxTimeStamp: Int64, errorBlock: @escaping SFSyncDownTargetFetchErrorBlock, completeBlock: @escaping SFSyncDownTargetFetchCompleteBlock) {
        // Abstract - subclasses must override
        NSException(name: .internalInconsistencyException, reason: "Subclasses must override startFetch", userInfo: nil).raise()
    }

    @objc(continueFetch:onFail:onComplete:)
    open func continueFetch(_ syncManager: SFMobileSyncSyncManager, errorBlock: @escaping SFSyncDownTargetFetchErrorBlock, completeBlock: @escaping SFSyncDownTargetFetchCompleteBlock) {
        completeBlock(nil)
    }

    @objc
    open func getRemoteIds(_ syncManager: SFMobileSyncSyncManager, localIds: [Any], errorBlock: @escaping SFSyncDownTargetFetchErrorBlock, completeBlock: @escaping SFSyncDownTargetFetchCompleteBlock) {
        // Abstract - subclasses must override
        NSException(name: .internalInconsistencyException, reason: "Subclasses must override getRemoteIds", userInfo: nil).raise()
    }

    @objc
    open func getLatestModificationTimeStamp(_ records: [Any]) -> Int64 {
        return getLatestModificationTimeStamp(records, modificationDateFieldName: self.modificationDateFieldName)
    }

    @objc
    open func isSyncDownSortedByLatestModification() -> Bool {
        return false
    }

    @objc(cleanGhosts:soupName:syncId:onFail:onComplete:)
    open func cleanGhosts(_ syncManager: SFMobileSyncSyncManager, soupName: String, syncId: NSNumber, errorBlock: @escaping SFSyncDownTargetFetchErrorBlock, completeBlock: @escaping SFSyncDownTargetFetchCompleteBlock) {

        // Fetches list of IDs present in local soup that have not been modified locally.
        let localIds = NSMutableOrderedSet(orderedSet: getNonDirtyRecordIds(syncManager, soupName: soupName, idField: self.idFieldName, additionalPredicate: buildSyncIdPredicateIfIndexed(syncManager, soupName: soupName, syncId: syncId)))

        if localIds.count == 0 {
            completeBlock([])
            return
        }

        let localIdsArr = localIds.array
        getRemoteIds(syncManager, localIds: localIdsArr, errorBlock: errorBlock) { [weak self] remoteIds in
            guard let self = self else { return }
            if let remoteIds = remoteIds {
                localIds.removeObjects(in: remoteIds)
            }
            // Snapshot the GHOST ids AFTER removing the still-remote ones. The ObjC oracle captured
            // `[localIds array]` before removal, but -[NSMutableOrderedSet array] returns a LIVE-backed
            // proxy that reflected the subsequent removeObjectsInArray:. Swift's `localIds.array` bridges
            // to a frozen snapshot, so reusing the pre-removal array here would delete every non-dirty
            // local record (including ones still present on the server). Re-read after removal to match.
            let ghostIds = localIds.array
            // Deletes extra IDs from SmartStore.
            self.deleteRecordsFromLocalStore(syncManager, soupName: soupName, ids: ghostIds, idField: self.idFieldName)
            completeBlock(ghostIds)
        }
    }

    @objc
    open func getIdsToSkip(_ syncManager: SFMobileSyncSyncManager, soupName: String) -> NSOrderedSet {
        return getDirtyRecordIds(syncManager, soupName: soupName, idField: self.idFieldName)
    }

    // MARK: - Query type enum helpers

    @objc
    open class func queryTypeFromString(_ queryType: String) -> SFSyncDownTargetQueryType {
        if queryType == kSFSyncTargetQueryTypeSoql { return .soql }
        if queryType == kSFSyncTargetQueryTypeMru { return .mru }
        if queryType == kSFSyncTargetQueryTypeSosl { return .sosl }
        if queryType == kSFSyncTargetQueryTypeRefresh { return .refresh }
        if queryType == kSFSyncTargetQueryTypeParentChildren { return .parentChildren }
        if queryType == kSFSyncTargetQueryTypeMetadata { return .metadata }
        if queryType == kSFSyncTargetQueryTypeLayout { return .layout }
        if queryType == kSFSyncTargetQueryTypeBriefcase { return .briefcase }
        return .custom
    }

    @objc
    open class func queryTypeToString(_ queryType: SFSyncDownTargetQueryType) -> String {
        switch queryType {
        case .mru: return kSFSyncTargetQueryTypeMru
        case .sosl: return kSFSyncTargetQueryTypeSosl
        case .soql: return kSFSyncTargetQueryTypeSoql
        case .refresh: return kSFSyncTargetQueryTypeRefresh
        case .parentChildren: return kSFSyncTargetQueryTypeParentChildren
        case .custom: return kSFSyncTargetQueryTypeCustom
        case .metadata: return kSFSyncTargetQueryTypeMetadata
        case .layout: return kSFSyncTargetQueryTypeLayout
        case .briefcase: return kSFSyncTargetQueryTypeBriefcase
        @unknown default: return kSFSyncTargetQueryTypeCustom
        }
    }

    // MARK: - Internal helper methods

    @objc
    open func getLatestModificationTimeStamp(_ records: [Any], modificationDateFieldName: String) -> Int64 {
        var maxTimeStamp: Int64 = -1
        for record in records {
            guard let recordDict = record as? [String: Any] else { continue }
            guard let timeStampStr = recordDict[modificationDateFieldName] as? String else { break }
            let timeStamp = FormatUtils.getMillis(fromIsoString: timeStampStr)
            maxTimeStamp = (timeStamp > maxTimeStamp) ? timeStamp : maxTimeStamp
        }
        return maxTimeStamp
    }

    @objc
    open func getNonDirtyRecordIds(_ syncManager: SFMobileSyncSyncManager, soupName: String, idField: String, additionalPredicate: String) -> NSOrderedSet {
        let sql = getNonDirtyRecordIdsSql(soupName, idField: idField, additionalPredicate: additionalPredicate)
        return getIdsWithQuery(sql, syncManager: syncManager)
    }

    @objc
    open func getNonDirtyRecordIdsSql(_ soupName: String, idField: String, additionalPredicate: String) -> String {
        return "SELECT {\(soupName):\(idField)} FROM {\(soupName)} WHERE {\(soupName):\(kSyncTargetLocal)} = '0' \(additionalPredicate) ORDER BY {\(soupName):\(idField)} ASC"
    }

    @objc
    open func buildSyncIdPredicateIfIndexed(_ syncManager: SFMobileSyncSyncManager, soupName: String, syncId: NSNumber) -> String {
        let indexSpecs = syncManager.store.indices(forSoupNamed: soupName)
        for indexSpec in indexSpecs {
            if let spec = indexSpec as? SFSoupIndex, spec.path == kSyncTargetSyncId {
                return "AND {\(soupName):\(kSyncTargetSyncId)} = \(syncId.stringValue)"
            }
        }
        return ""
    }
}
