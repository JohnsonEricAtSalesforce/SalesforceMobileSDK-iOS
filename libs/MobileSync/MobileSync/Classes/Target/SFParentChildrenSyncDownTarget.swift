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

@objc(SFParentChildrenSyncDownTarget)
@objcMembers
open class SFParentChildrenSyncDownTarget: SFSoqlSyncDownTarget {

    private var parentInfo: SFParentInfo = SFParentInfo()
    private var parentFieldlist: [String] = []
    private var parentSoqlFilter: String = ""
    private var childrenInfo: SFChildrenInfo = SFChildrenInfo()
    private var childrenFieldlist: [String] = []
    private var relationshipType: SFParentChildrenRelationshipType = .masterDetail

    // MARK: - Initialization

    @objc
    public init(parentInfo: SFParentInfo, parentFieldlist: [String], parentSoqlFilter: String, childrenInfo: SFChildrenInfo, childrenFieldlist: [String], relationshipType: SFParentChildrenRelationshipType) {
        super.init()
        self.queryType = .parentChildren
        self.parentInfo = parentInfo
        self.idFieldName = parentInfo.idFieldName
        self.modificationDateFieldName = parentInfo.modificationDateFieldName
        self.parentFieldlist = parentFieldlist
        self.parentSoqlFilter = parentSoqlFilter
        self.childrenInfo = childrenInfo
        self.childrenFieldlist = childrenFieldlist
        self.relationshipType = relationshipType
        SFParentChildrenSyncHelper.registerAppFeature()
    }

    public required init(dict: NSDictionary) {
        super.init()
        let dictionary = dict as? [String: Any] ?? [:]
        let pInfo = SFParentInfo.new(fromDict: dictionary[kSFParentChildrenSyncTargetParent] as? [String: Any] ?? [:])
        let cInfo = SFChildrenInfo.new(fromDict: dictionary[kSFParentChildrenSyncTargetChildren] as? [String: Any] ?? [:])
        self.queryType = .parentChildren
        self.parentInfo = pInfo
        self.idFieldName = pInfo.idFieldName
        self.modificationDateFieldName = pInfo.modificationDateFieldName
        self.parentFieldlist = dictionary[kSFParentChildrenSyncTargetParentFieldlist] as? [String] ?? []
        self.parentSoqlFilter = dictionary[kSFParentChildrenSyncTargetParentSoqlFilter] as? String ?? ""
        self.childrenInfo = cInfo
        self.childrenFieldlist = dictionary[kSFParentChildrenSyncTargetChildrenFieldlist] as? [String] ?? []
        self.relationshipType = SFParentChildrenSyncHelper.relationshipType(fromString: dictionary[kSFParentChildrenSyncTargetRelationshipType] as? String ?? "")
        SFParentChildrenSyncHelper.registerAppFeature()
    }

    // MARK: - Factory

    @objc
    open class func newSyncTarget(parentInfo: SFParentInfo, parentFieldlist: [String], parentSoqlFilter: String, childrenInfo: SFChildrenInfo, childrenFieldlist: [String], relationshipType: SFParentChildrenRelationshipType) -> SFParentChildrenSyncDownTarget {
        return SFParentChildrenSyncDownTarget(parentInfo: parentInfo, parentFieldlist: parentFieldlist, parentSoqlFilter: parentSoqlFilter, childrenInfo: childrenInfo, childrenFieldlist: childrenFieldlist, relationshipType: relationshipType)
    }

    @objc
    open override class func newFromDict(_ dict: NSDictionary) -> SFParentChildrenSyncDownTarget {
        return SFParentChildrenSyncDownTarget(dict: dict)
    }

    // MARK: - Serialization

    open override func asDict() -> NSMutableDictionary {
        let dict = super.asDict()
        dict[kSFParentChildrenSyncTargetParent] = self.parentInfo.asDict()
        dict[kSFParentChildrenSyncTargetParentFieldlist] = self.parentFieldlist
        dict[kSFParentChildrenSyncTargetParentSoqlFilter] = self.parentSoqlFilter
        dict[kSFParentChildrenSyncTargetChildren] = self.childrenInfo.asDict()
        dict[kSFParentChildrenSyncTargetChildrenFieldlist] = self.childrenFieldlist
        dict[kSFParentChildrenSyncTargetRelationshipType] = SFParentChildrenSyncHelper.relationshipTypeToString(self.relationshipType)
        return dict
    }

    // MARK: - Overrides

    open override func isSyncDownSortedByLatestModification() -> Bool {
        return true
    }

    open override func getQueryToRun(_ maxTimeStamp: Int64) -> String {
        var childrenWhere = ""
        var parentWhere = ""

        if maxTimeStamp > 0 {
            childrenWhere = buildModificationDateFilter(self.childrenInfo.modificationDateFieldName, maxTimeStamp: maxTimeStamp)
            parentWhere = buildModificationDateFilter(self.modificationDateFieldName, maxTimeStamp: maxTimeStamp)
            if !self.parentSoqlFilter.isEmpty { parentWhere += " and " }
        }
        if !self.parentSoqlFilter.isEmpty { parentWhere += self.parentSoqlFilter }

        // Nested query
        var nestedFields = self.childrenFieldlist
        if !nestedFields.contains(self.childrenInfo.idFieldName) { nestedFields.append(self.childrenInfo.idFieldName) }
        if !nestedFields.contains(self.childrenInfo.modificationDateFieldName) { nestedFields.append(self.childrenInfo.modificationDateFieldName) }
        let builderNested = SFSDKSoqlBuilder.withFieldsArray(nestedFields)
            .from(self.childrenInfo.sobjectTypePlural)
            .whereClause(childrenWhere)

        // Parent query
        var fields = self.parentFieldlist
        if !fields.contains(self.idFieldName) { fields.append(self.idFieldName) }
        if !fields.contains(self.modificationDateFieldName) { fields.append(self.modificationDateFieldName) }
        fields.append("(\(builderNested.build() ?? ""))")
        let builder = SFSDKSoqlBuilder.withFieldsArray(fields)
            .from(self.parentInfo.sobjectType)
            .whereClause(parentWhere)
            .order(by: self.parentInfo.modificationDateFieldName)

        return builder.build() ?? ""
    }

    open override func cleanGhosts(_ syncManager: SFMobileSyncSyncManager, soupName: String, syncId: NSNumber, errorBlock: @escaping SFSyncDownTargetFetchErrorBlock, completeBlock: @escaping SFSyncDownTargetFetchCompleteBlock) {
        // Taking care of ghost parents
        super.cleanGhosts(syncManager, soupName: soupName, syncId: syncId, errorBlock: errorBlock) { [weak self] localIdsArr in
            guard let self = self else { return }

            // Taking care of ghost children
            let childNonDirtySql = self.superGetNonDirtyRecordIdsSql(self.childrenInfo.soupName, idField: self.childrenInfo.idFieldName, additionalPredicate: self.buildSyncIdPredicateIfIndexed(syncManager, soupName: self.childrenInfo.soupName, syncId: syncId))
            let localChildrenIds = NSMutableOrderedSet(orderedSet: self.getIdsWithQuery(childNonDirtySql, syncManager: syncManager))

            self.getChildrenRemoteIds(syncManager, soqlForChildrenRemoteIds: self.getSoqlForRemoteChildrenIds(), errorBlock: errorBlock) { remoteChildrenIds in
                if let remoteChildrenIds = remoteChildrenIds {
                    localChildrenIds.removeObjects(in: remoteChildrenIds)
                }
                self.deleteRecordsFromLocalStore(syncManager, soupName: self.childrenInfo.soupName, ids: localChildrenIds.array, idField: self.childrenInfo.idFieldName)
                completeBlock(localIdsArr)
            }
        }
    }

    open override func getLatestModificationTimeStamp(_ records: [Any]) -> Int64 {
        var maxTimeStamp = super.getLatestModificationTimeStamp(records)
        for record in records {
            guard let recordDict = record as? [String: Any] else { continue }
            if let children = recordDict[self.childrenInfo.sobjectTypePlural] as? [Any] {
                let maxTimeStampChildren = super.getLatestModificationTimeStamp(children, modificationDateFieldName: self.childrenInfo.modificationDateFieldName)
                maxTimeStamp = max(maxTimeStamp, maxTimeStampChildren)
            }
        }
        return maxTimeStamp
    }

    open override func cleanAndSaveRecordsToLocalStore(syncManager: SFMobileSyncSyncManager, soupName: String, records: [Any], syncId: NSNumber) {
        SFParentChildrenSyncHelper.saveRecordTrees(toLocalStore: syncManager, target: self, parentInfo: self.parentInfo, childrenInfo: self.childrenInfo, recordTrees: records, syncId: syncId)
    }

    open override func getDirtyRecordIdsSql(_ soupName: String, idField: String) -> String {
        return SFParentChildrenSyncHelper.getDirtyRecordIdsSql(self.parentInfo, childrenInfo: self.childrenInfo, parentFieldToSelect: idField)
    }

    open override func getNonDirtyRecordIdsSql(_ soupName: String, idField: String, additionalPredicate: String) -> String {
        return SFParentChildrenSyncHelper.getNonDirtyRecordIdsSql(self.parentInfo, childrenInfo: self.childrenInfo, parentFieldToSelect: idField, additionalPredicate: additionalPredicate)
    }

    // MARK: - Overridden from SFSoqlSyncDownTarget

    open override func getRecordsFromResponse(_ responseJson: NSDictionary) -> [Any]? {
        guard let responseDict = responseJson as? [String: Any],
              let originalRecords = responseDict[kResponseRecords] as? [[String: Any]] else { return nil }
        var records = [[String: Any]]()
        for originalRecord in originalRecords {
            let children = originalRecord[self.childrenInfo.sobjectTypePlural]
            let hasChildren = children != nil && !(children is NSNull)
            var childrenRecords = [[String: Any]]()
            if hasChildren, let childrenDict = children as? [String: Any], let recs = childrenDict[kResponseRecords] as? [[String: Any]] {
                childrenRecords = recs
            }
            var record = originalRecord
            record[self.childrenInfo.sobjectTypePlural] = childrenRecords
            records.append(record)
        }
        return records
    }

    open override func getSoqlForRemoteIds() -> String {
        let builder = SFSDKSoqlBuilder.withFieldsArray([self.idFieldName])
            .from(self.parentInfo.sobjectType)
            .whereClause(self.parentSoqlFilter)
        return builder.build() ?? ""
    }

    // MARK: - Private helpers

    /// Helper to call super's getNonDirtyRecordIdsSql from within a closure
    /// (Swift does not allow calling super in a closure that captures self)
    private func superGetNonDirtyRecordIdsSql(_ soupName: String, idField: String, additionalPredicate: String) -> String {
        return "SELECT {\(soupName):\(idField)} FROM {\(soupName)} WHERE {\(soupName):\(kSyncTargetLocal)} = '0' \(additionalPredicate) ORDER BY {\(soupName):\(idField)} ASC"
    }

    private func buildModificationDateFilter(_ modificationDateFieldName: String, maxTimeStamp: Int64) -> String {
        return "\(modificationDateFieldName) > \(SFMobileSyncObjectUtils.getIsoString(fromMillis: maxTimeStamp))"
    }

    private func getSoqlForRemoteChildrenIds() -> String {
        let builderNested = SFSDKSoqlBuilder.withFieldsArray([self.childrenInfo.idFieldName])
            .from(self.childrenInfo.sobjectTypePlural)
        let nestedSoql = builderNested.build() ?? ""
        let fields = [self.idFieldName, "(\(nestedSoql))"]
        let builder = SFSDKSoqlBuilder.withFieldsArray(fields)
            .from(self.parentInfo.sobjectType)
            .whereClause(self.parentSoqlFilter)
        return builder.build() ?? ""
    }

    private func getChildrenRemoteIds(_ syncManager: SFMobileSyncSyncManager, soqlForChildrenRemoteIds: String, errorBlock: @escaping SFSyncDownTargetFetchErrorBlock, completeBlock: @escaping SFSyncDownTargetFetchCompleteBlock) {
        var remoteChildrenIds = Set<String>()
        var fetchBlockRecurse: SFSyncDownTargetFetchCompleteBlock?

        let fetchErrorBlock: SFSyncDownTargetFetchErrorBlock = { error in
            fetchBlockRecurse = nil
            errorBlock(error)
        }

        let fetchBlock: SFSyncDownTargetFetchCompleteBlock = { [weak self] records in
            guard let self = self else { return }
            guard let records = records else {
                fetchBlockRecurse = nil
                completeBlock(Array(remoteChildrenIds))
                return
            }
            remoteChildrenIds.formUnion(self.parseChildrenIdsFromResponse(records))
            self.continueFetch(syncManager, errorBlock: errorBlock, completeBlock: fetchBlockRecurse ?? { _ in })
        }
        fetchBlockRecurse = fetchBlock
        startFetch(syncManager, queryToRun: soqlForChildrenRemoteIds, errorBlock: fetchErrorBlock, completeBlock: fetchBlock)
    }

    private func parseChildrenIdsFromResponse(_ records: [Any]) -> Set<String> {
        var remoteChildrenIds = Set<String>()
        for record in records {
            guard let recordDict = record as? [String: Any],
                  let childrenArr = recordDict[self.childrenInfo.sobjectTypePlural] as? [Any] else { continue }
            remoteChildrenIds.formUnion(parseIdsFromResponse(childrenArr))
        }
        return remoteChildrenIds
    }
}
