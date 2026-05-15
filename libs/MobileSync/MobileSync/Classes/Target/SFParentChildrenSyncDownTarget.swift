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
public class ParentChildrenSyncDownTarget: SoqlSyncDownTarget {

    var parentInfo: ParentInfo
    var parentFieldlist: [String]
    var parentSoqlFilter: String?
    var childrenInfo: ChildrenInfo
    var childrenFieldlist: [String]
    var relationshipType: ParentChildrenRelationshipType

    init(
        parentInfo: ParentInfo,
        parentFieldlist: [String],
        parentSoqlFilter: String?,
        childrenInfo: ChildrenInfo,
        childrenFieldlist: [String],
        relationshipType: ParentChildrenRelationshipType
    ) {
        self.parentInfo = parentInfo
        self.parentFieldlist = parentFieldlist
        self.parentSoqlFilter = parentSoqlFilter
        self.childrenInfo = childrenInfo
        self.childrenFieldlist = childrenFieldlist
        self.relationshipType = relationshipType
        super.init()
        self.queryType = .parentChildren
        self.idFieldName = parentInfo.idFieldName
        self.modificationDateFieldName = parentInfo.modificationDateFieldName
        ParentChildrenSyncHelper.registerAppFeature()
    }

    public required init(dict: [String: Any]?) {
        let dict = dict ?? [:]
        self.parentInfo = ParentInfo.newFromDict(dict[kSFParentChildrenSyncTargetParent] as? [String: Any] ?? [:])
        self.parentFieldlist = dict[kSFParentChildrenSyncTargetParentFieldlist] as? [String] ?? []
        self.parentSoqlFilter = dict[kSFParentChildrenSyncTargetParentSoqlFilter] as? String
        self.childrenInfo = ChildrenInfo.new(from: dict[kSFParentChildrenSyncTargetChildren] as? [String: Any] ?? [:])
        self.childrenFieldlist = dict[kSFParentChildrenSyncTargetChildrenFieldlist] as? [String] ?? []
        self.relationshipType = ParentChildrenSyncHelper.relationshipType(
            fromString: dict[kSFParentChildrenSyncTargetRelationshipType] as? String ?? ""
        )
        super.init(dict: dict)
    }

    // MARK: - Factory methods

    @objc(newSyncTargetWithParentInfo:parentFieldlist:parentSoqlFilter:childrenInfo:childrenFieldlist:relationshipType:)
    public static func newSyncTarget(
        withParentInfo parentInfo: ParentInfo,
        parentFieldlist: [String],
        parentSoqlFilter: String?,
        childrenInfo: ChildrenInfo,
        childrenFieldlist: [String],
        relationshipType: ParentChildrenRelationshipType
    ) -> ParentChildrenSyncDownTarget {
        return ParentChildrenSyncDownTarget(
            parentInfo: parentInfo,
            parentFieldlist: parentFieldlist,
            parentSoqlFilter: parentSoqlFilter,
            childrenInfo: childrenInfo,
            childrenFieldlist: childrenFieldlist,
            relationshipType: relationshipType
        )
    }

    @objc(newParentChildrenSyncDownTargetFromDict:)
    public static func new(from dict: [String: Any]) -> ParentChildrenSyncDownTarget {
        return ParentChildrenSyncDownTarget(dict: dict)
    }

    // MARK: - To dictionary

    public override func asDict() -> [String: Any] {
        var dict = super.asDict()
        dict[kSFParentChildrenSyncTargetParent] = parentInfo.asDict()
        dict[kSFParentChildrenSyncTargetParentFieldlist] = parentFieldlist
        dict[kSFParentChildrenSyncTargetParentSoqlFilter] = parentSoqlFilter
        dict[kSFParentChildrenSyncTargetChildren] = childrenInfo.asDict()
        dict[kSFParentChildrenSyncTargetChildrenFieldlist] = childrenFieldlist
        dict[kSFParentChildrenSyncTargetRelationshipType] = ParentChildrenSyncHelper.relationshipTypeToString(relationshipType)
        return dict
    }

    // MARK: - Other public methods

    public override func isSyncDownSortedByLatestModification() -> Bool {
        return true
    }

    public override func getQueryToRun(_ maxTimeStamp: Int64) -> String {
        var childrenWhere = ""
        var parentWhere = ""

        if maxTimeStamp > 0 {
            // This is for re-sync
            childrenWhere = buildModificationDateFilter(
                childrenInfo.modificationDateFieldName,
                maxTimeStamp: maxTimeStamp
            )
            parentWhere = buildModificationDateFilter(
                modificationDateFieldName,
                maxTimeStamp: maxTimeStamp
            )
            if let filter = parentSoqlFilter, !filter.isEmpty {
                parentWhere += " and "
            }
        }
        if let filter = parentSoqlFilter {
            parentWhere += filter
        }

        // Nested query
        var nestedFields = childrenFieldlist
        if !nestedFields.contains(childrenInfo.idFieldName) {
            nestedFields.append(childrenInfo.idFieldName)
        }
        if !nestedFields.contains(childrenInfo.modificationDateFieldName) {
            nestedFields.append(childrenInfo.modificationDateFieldName)
        }
        let builderNested = SFSDKSoqlBuilder.withFields(array: nestedFields)
            .from(childrenInfo.sobjectTypePlural)

        if !childrenWhere.isEmpty {
            builderNested.whereClause(childrenWhere)
        }

        // Parent query
        var fields = parentFieldlist
        if !fields.contains(idFieldName) {
            fields.append(idFieldName)
        }
        if !fields.contains(modificationDateFieldName) {
            fields.append(modificationDateFieldName)
        }
        fields.append("(\(builderNested.build()))")

        let builder = SFSDKSoqlBuilder.withFields(array: fields)
            .from(parentInfo.sobjectType)

        if !parentWhere.isEmpty {
            builder.whereClause(parentWhere)
        }
        builder.orderBy(parentInfo.modificationDateFieldName)

        return builder.build() ?? ""
    }

    public override func cleanGhosts(
        syncManager: SFMobileSyncSyncManager,
        soupName: String,
        syncId: NSNumber,
        onFail errorBlock: @escaping SyncDownErrorBlock,
        onComplete completeBlock: @escaping SyncDownCompletionBlock
    ) {
        // Store references we'll need in the closure
        let childrenInfo = self.childrenInfo
        let soqlForRemoteChildrenIds = self.getSoqlForRemoteChildrenIds()

        // Taking care of ghost parents
        super.cleanGhosts(
            syncManager: syncManager,
            soupName: soupName,
            syncId: syncId,
            onFail: errorBlock,
            onComplete: { [weak self] localIdsArr in
                guard let self = self else { return }

                // Build the SQL query
                let additionalPredicate = self.buildSyncIdPredicateIfIndexed(
                    syncManager: syncManager,
                    soupName: childrenInfo.soupName,
                    syncId: syncId
                )

                let nonDirtyRecordsSql = ParentChildrenSyncHelper.getNonDirtyRecordIdsSql(
                    self.parentInfo,
                    childrenInfo: childrenInfo,
                    parentFieldToSelect: childrenInfo.idFieldName,
                    additionalPredicate: additionalPredicate
                )

                // Taking care of ghost children
                let localChildrenIds = NSMutableOrderedSet(
                    array: self.getIdsWithQuery(
                        nonDirtyRecordsSql,
                        syncManager: syncManager
                    ).array
                )

                self.getChildrenRemoteIds(
                    with: syncManager,
                    soqlForChildrenRemoteIds: soqlForRemoteChildrenIds,
                    onFail: errorBlock,
                    onComplete: { remoteChildrenIds in
                        if let remoteIds = remoteChildrenIds as? [String] {
                            localChildrenIds.removeObjects(in: remoteIds)
                        }

                        // Delete extra IDs from SmartStore.
                        self.deleteRecordsFromLocalStore(
                            syncManager,
                            soupName: childrenInfo.soupName,
                            ids: localChildrenIds.array as [Any],
                            idField: childrenInfo.idFieldName
                        )

                        completeBlock(localIdsArr)
                    }
                )
            }
        )
    }

    public override func getLatestModificationTimeStamp(_ records: [Any]) -> Int64 {
        // NB: method is called during sync down so for this target records contain parent and children

        // Compute max time stamp of parents
        var maxTimeStamp = super.getLatestModificationTimeStamp(records)

        // Compute max time stamp of parents and children
        if let recordDicts = records as? [[String: Any]] {
            for record in recordDicts {
                if let children = record[childrenInfo.sobjectTypePlural] as? [Any] {
                    let maxTimeStampChildren = super.getLatestModificationTimeStamp(
                        children,
                        modificationDateFieldName: childrenInfo.modificationDateFieldName
                    )
                    maxTimeStamp = max(maxTimeStamp, maxTimeStampChildren)
                }
            }
        }

        return maxTimeStamp
    }

    public override func cleanAndSaveRecordsToLocalStore(syncManager: SFMobileSyncSyncManager, soupName: String, records: [[String: Any]], syncId: NSNumber) {
        // NB: method is called during sync down so for this target records contain parent and children
        ParentChildrenSyncHelper.saveRecordTreesToLocalStore(
            syncManager,
            target: self,
            parentInfo: parentInfo,
            childrenInfo: childrenInfo,
            recordTrees: records,
            syncId: syncId
        )
    }

    // MARK: - Utility methods

    private func buildModificationDateFilter(
        _ modificationDateFieldName: String,
        maxTimeStamp: Int64
    ) -> String {
        return "\(modificationDateFieldName) > \(FormatUtils.getIsoStringFromMillis(maxTimeStamp) ?? "")"
    }

    public override func getSoqlForRemoteIds() -> String {
        // This is for clean re-sync ghosts
        // This is the soql to identify parents
        let builder = SFSDKSoqlBuilder.withFields(array: [idFieldName])
            .from(parentInfo.sobjectType)

        if let filter = parentSoqlFilter, !filter.isEmpty {
            builder.whereClause(filter)
        }

        return builder.build() ?? ""
    }

    private func getSoqlForRemoteChildrenIds() -> String {
        // This is for clean re-sync ghosts
        // This is the soql to identify children

        // Nested query
        let builderNested = SFSDKSoqlBuilder.withFields(array: [childrenInfo.idFieldName])
            .from(childrenInfo.sobjectTypePlural)

        // Parent query
        let fields = [idFieldName, "(\(builderNested.build()))"]
        let builder = SFSDKSoqlBuilder.withFields(array: fields)
            .from(parentInfo.sobjectType)

        if let filter = parentSoqlFilter, !filter.isEmpty {
            builder.whereClause(filter)
        }

        return builder.build() ?? ""
    }

    private func getChildrenRemoteIds(
        with syncManager: SFMobileSyncSyncManager,
        soqlForChildrenRemoteIds: String,
        onFail errorBlock: @escaping SyncDownErrorBlock,
        onComplete completeBlock: @escaping SyncDownCompletionBlock
    ) {
        var remoteChildrenIds = Set<String>()
        var fetchBlockRecurse: SyncDownCompletionBlock?

        let fetchErrorBlock: SyncDownErrorBlock = { error in
            fetchBlockRecurse = nil
            errorBlock(error)
        }

        let fetchBlock: SyncDownCompletionBlock = { [weak self] records in
            guard let self = self else { return }

            if records == nil {
                fetchBlockRecurse = nil
                completeBlock(Array(remoteChildrenIds))
                return
            }

            if let recordsArray = records as? [[String: Any]] {
                remoteChildrenIds.formUnion(self.parseChildrenIds(fromResponse: recordsArray))
            }
            self.continueFetch(syncManager: syncManager, onFail: errorBlock, onComplete: fetchBlockRecurse!)
        }

        fetchBlockRecurse = fetchBlock
        startFetch(
            syncManager: syncManager,
            queryToRun: soqlForChildrenRemoteIds,
            onFail: fetchErrorBlock,
            onComplete: fetchBlock
        )
    }

    private func parseChildrenIds(fromResponse records: [[String: Any]]) -> Set<String> {
        var remoteChildrenIds = Set<String>()
        for record in records {
            if let children = record[childrenInfo.sobjectTypePlural] as? [Any] {
                remoteChildrenIds.formUnion(self.parseIdsFromResponse(children))
            }
        }
        return remoteChildrenIds
    }

    public override func getRecordsFromResponse(_ responseJson: [String: Any]) -> [Any] {
        var records: [[String: Any]] = []

        if let originalRecords = responseJson[kResponseRecords] as? [[String: Any]] {
            for originalRecord in originalRecords {
                let children = originalRecord[childrenInfo.sobjectTypePlural]
                let hasChildren = children != nil && !(children is NSNull)
                var childrenRecords: [[String: Any]] = []
                if hasChildren,
                   let childrenDict = children as? [String: Any],
                   let childrenArray = childrenDict[kResponseRecords] as? [[String: Any]] {
                    childrenRecords = childrenArray
                }

                // Cleaning up record
                var record = originalRecord
                record[childrenInfo.sobjectTypePlural] = childrenRecords
                records.append(record)
            }
        }

        return records
    }

    public override func getDirtyRecordIdsSql(_ soupName: String, idField: String) -> String {
        return ParentChildrenSyncHelper.getDirtyRecordIdsSql(
            parentInfo,
            childrenInfo: childrenInfo,
            parentFieldToSelect: idField
        )
    }

    public override func getNonDirtyRecordIdsSql(
        soupName: String,
        idField: String,
        additionalPredicate: String?
    ) -> String {
        return ParentChildrenSyncHelper.getNonDirtyRecordIdsSql(
            parentInfo,
            childrenInfo: childrenInfo,
            parentFieldToSelect: idField,
            additionalPredicate: additionalPredicate ?? ""
        )
    }
}
