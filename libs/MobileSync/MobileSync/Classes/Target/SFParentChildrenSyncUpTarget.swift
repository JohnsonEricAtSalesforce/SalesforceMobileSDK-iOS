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
import SalesforceSDKCommon

typealias FetchLastModifiedDatesCompleteBlock = ([String: String]) -> Void
typealias SendCompositeRequestCompleteBlock = OnSendCompleteCallback

@objc(SFParentChildrenSyncUpTarget)
@objcMembers
public class ParentChildrenSyncUpTarget: SyncUpTarget, AdvancedSyncUpTarget {

    var parentInfo: ParentInfo
    var childrenInfo: ChildrenInfo
    var childrenCreateFieldlist: [String]?
    var childrenUpdateFieldlist: [String]?
    var relationshipType: ParentChildrenRelationshipType

    init(
        parentInfo: ParentInfo,
        parentCreateFieldlist: [String]?,
        parentUpdateFieldlist: [String]?,
        childrenInfo: ChildrenInfo,
        childrenCreateFieldlist: [String]?,
        childrenUpdateFieldlist: [String]?,
        relationshipType: ParentChildrenRelationshipType
    ) {
        self.parentInfo = parentInfo
        self.childrenInfo = childrenInfo
        self.childrenCreateFieldlist = childrenCreateFieldlist
        self.childrenUpdateFieldlist = childrenUpdateFieldlist
        self.relationshipType = relationshipType
        super.init()
        self.idFieldName = parentInfo.idFieldName
        self.modificationDateFieldName = parentInfo.modificationDateFieldName
        self.createFieldlist = parentCreateFieldlist
        self.updateFieldlist = parentUpdateFieldlist
        ParentChildrenSyncHelper.registerAppFeature()
    }

    public required init(dict: [String: Any]?) {
        let dict = dict ?? [:]
        self.parentInfo = ParentInfo.newFromDict(dict[kSFParentChildrenSyncTargetParent] as? [String: Any] ?? [:])
        self.childrenInfo = ChildrenInfo.new(from: dict[kSFParentChildrenSyncTargetChildren] as? [String: Any] ?? [:])
        self.childrenCreateFieldlist = dict[kSFParentChildrenSyncTargetChildrenCreateFieldlist] as? [String]
        self.childrenUpdateFieldlist = dict[kSFParentChildrenSyncTargetChildrenUpdateFieldlist] as? [String]
        self.relationshipType = ParentChildrenSyncHelper.relationshipType(
            fromString: dict[kSFParentChildrenSyncTargetRelationshipType] as? String ?? ""
        )
        super.init(dict: dict)
    }

    // MARK: - Factory methods

    @objc(newSyncTargetWithParentInfo:parentCreateFieldlist:parentUpdateFieldlist:childrenInfo:childrenCreateFieldlist:childrenUpdateFieldlist:relationshipType:)
    public static func newSyncTarget(
        withParentInfo parentInfo: ParentInfo,
        parentCreateFieldlist: [String]?,
        parentUpdateFieldlist: [String]?,
        childrenInfo: ChildrenInfo,
        childrenCreateFieldlist: [String]?,
        childrenUpdateFieldlist: [String]?,
        relationshipType: ParentChildrenRelationshipType
    ) -> ParentChildrenSyncUpTarget {
        return ParentChildrenSyncUpTarget(
            parentInfo: parentInfo,
            parentCreateFieldlist: parentCreateFieldlist,
            parentUpdateFieldlist: parentUpdateFieldlist,
            childrenInfo: childrenInfo,
            childrenCreateFieldlist: childrenCreateFieldlist,
            childrenUpdateFieldlist: childrenUpdateFieldlist,
            relationshipType: relationshipType
        )
    }

    @objc(newFromDict:)
    public static func new(from dict: [String: Any]?) -> ParentChildrenSyncUpTarget {
        return ParentChildrenSyncUpTarget(dict: dict ?? [:])
    }

    // MARK: - To dictionary

    public override func asDict() -> [String: Any] {
        var dict = super.asDict()
        dict[kSFParentChildrenSyncTargetParent] = parentInfo.asDict()
        dict[kSFSyncUpTargetCreateFieldlist] = createFieldlist
        dict[kSFSyncUpTargetUpdateFieldlist] = updateFieldlist
        dict[kSFParentChildrenSyncTargetChildren] = childrenInfo.asDict()
        dict[kSFParentChildrenSyncTargetChildrenCreateFieldlist] = childrenCreateFieldlist
        dict[kSFParentChildrenSyncTargetChildrenUpdateFieldlist] = childrenUpdateFieldlist
        dict[kSFParentChildrenSyncTargetRelationshipType] = ParentChildrenSyncHelper.relationshipTypeToString(relationshipType)
        return dict
    }

    // MARK: - Other public methods

    public func create(
        onServer syncManager: MobileSyncSyncManager,
        record: [AnyHashable: Any],
        fieldlist: [Any],
        completionBlock: @escaping SyncUpTargetCompleteBlock,
        failBlock: @escaping SyncUpTargetErrorBlock
    ) {
        // For advanced sync up target, call syncUpOneRecord
        fatalError("For advanced sync up target, call syncUpOneRecord")
    }

    public func update(
        onServer syncManager: MobileSyncSyncManager,
        record: [AnyHashable: Any],
        fieldlist: [Any],
        completionBlock: @escaping SyncUpTargetCompleteBlock,
        failBlock: @escaping SyncUpTargetErrorBlock
    ) {
        // For advanced sync up target, call syncUpOneRecord
        fatalError("For advanced sync up target, call syncUpOneRecord")
    }

    public func delete(
        onServer syncManager: MobileSyncSyncManager,
        record: [AnyHashable: Any],
        completionBlock: @escaping SyncUpTargetCompleteBlock,
        failBlock: @escaping SyncUpTargetErrorBlock
    ) {
        // For advanced sync up target, call syncUpOneRecord
        fatalError("For advanced sync up target, call syncUpOneRecord")
    }

    public var maxBatchSize: UInt {
        return 1
    }

    public func syncUpRecords(
        _ syncManager: MobileSyncSyncManager,
        records: [NSMutableDictionary],
        fieldlist: [Any],
        mergeMode: SyncMergeMode,
        syncSoupName: String,
        completionBlock: @escaping SyncUpcompletionBlock,
        failBlock: @escaping SyncUpErrorBlock
    ) {
        if records.isEmpty {
            // Nothing to do
            completionBlock(nil)
        } else {
            syncUpRecord(
                syncManager,
                record: records[0],
                fieldlist: fieldlist,
                mergeMode: mergeMode,
                completionBlock: completionBlock,
                failBlock: failBlock
            )
        }
    }

    public func syncUpRecord(
        _ syncManager: MobileSyncSyncManager,
        record: NSMutableDictionary,
        fieldlist: [Any],
        mergeMode: SyncStateMergeMode,
        completionBlock: @escaping SyncUpTargetCompleteBlock,
        failBlock: @escaping SyncUpTargetErrorBlock
    ) {
        let recordDict = record as! [String: Any]
        let isCreate = isLocallyCreated(recordDict)
        let isDelete = isLocallyDeleted(recordDict)

        // Getting children
        let children: [[String: Any]]
        if relationshipType == .masterDetail && isDelete && !isCreate {
            // deleting master in a master-detail relationship will delete the children
            // so no need to actually do any work on the children
            children = []
        } else {
            children = ParentChildrenSyncHelper.getMutableChildrenFromLocalStore(
                syncManager.store,
                parentInfo: parentInfo,
                childrenInfo: childrenInfo,
                parent: recordDict
            )
        }

        syncUpRecord(
            syncManager,
            record: record,
            children: children,
            fieldlist: fieldlist,
            mergeMode: mergeMode,
            completionBlock: completionBlock,
            failBlock: failBlock
        )
    }

    public override func getDirtyRecordIdsSql(_ soupName: String, idField: String) -> String {
        return ParentChildrenSyncHelper.getDirtyRecordIdsSql(
            parentInfo,
            childrenInfo: childrenInfo,
            parentFieldToSelect: idField
        )
    }

    public func isNewerThanServer(
        _ syncManager: MobileSyncSyncManager,
        record: [AnyHashable: Any],
        resultBlock: @escaping SyncUpRecordNewerThanServerBlock
    ) {
        let recordDict = record as? [String: Any] ?? [:]
        if isLocallyCreated(recordDict) {
            resultBlock(true)
            return
        }

        let idToLocalTimestamps = getLocalLastModifiedDates(syncManager, record: recordDict)
        fetchLastModifiedDates(
            syncManager,
            record: recordDict,
            completionBlock: { [weak self] idToRemoteTimestamps in
                guard let self = self else { return }
                if let idToLocalTimestamps = idToLocalTimestamps {
                    for (id, localModDate) in idToLocalTimestamps {
                        let remoteTimestamp = idToRemoteTimestamps[id]
                        let remoteModDate = RecordModDate(
                            timestamp: remoteTimestamp,
                            isDeleted: remoteTimestamp == nil
                        )

                        if !self.isNewerThanServer(localModDate: localModDate, remoteModDate: remoteModDate) {
                            resultBlock(false)
                            return
                        }
                    }
                }

                resultBlock(true)
            }
        )
    }

    // MARK: - Helper methods

    private func getLocalLastModifiedDates(
        _ syncManager: MobileSyncSyncManager,
        record: [String: Any]
    ) -> [String: RecordModDate]? {
        var idToLocalTimestamps: [String: RecordModDate] = [:]
        let isParentDeleted = isLocallyDeleted(record)

        if let parentId = record[idFieldName] as? String,
           let parentTimestamp = record[modificationDateFieldName] as? String {
            let parentModDate = RecordModDate(timestamp: parentTimestamp, isDeleted: isParentDeleted)
            idToLocalTimestamps[parentId] = parentModDate
        }

        let children = ParentChildrenSyncHelper.getMutableChildrenFromLocalStore(
            syncManager.store,
            parentInfo: parentInfo,
            childrenInfo: childrenInfo,
            parent: record
        )

        for childRecord in children {
            if let childId = childRecord[childrenInfo.idFieldName] as? String,
               let childTimestamp = childRecord[childrenInfo.modificationDateFieldName] as? String {
                let childIsDeleted = isLocallyDeleted(childRecord)
                    || (isParentDeleted && relationshipType == .masterDetail)
                let childModDate = RecordModDate(timestamp: childTimestamp, isDeleted: childIsDeleted)
                idToLocalTimestamps[childId] = childModDate
            }
        }

        return idToLocalTimestamps
    }

    private func fetchLastModifiedDates(
        _ manager: MobileSyncSyncManager,
        record: [String: Any],
        completionBlock: @escaping FetchLastModifiedDatesCompleteBlock
    ) {
        if isLocallyCreated(record) {
            completionBlock([:])
            return
        }

        guard let parentId = record[idFieldName] as? String else {
            completionBlock([:])
            return
        }

        let lastModRequest = getRequest(forTimestamps: parentId)
        let capturedIdFieldName = self.idFieldName
        let capturedModificationDateFieldName = self.modificationDateFieldName
        let capturedChildrenInfo = self.childrenInfo

        SFMobileSyncNetworkUtils.sendRequest(
            withMobileSyncUserAgent: lastModRequest,
            failureBlock: { response, error, rawResponse in
                completionBlock([:])
            },
            successBlock: { lastModResponse, rawResponse in
                var idToRemoteTimestamps: [String: String] = [:]

                if let responseDict = lastModResponse as? [String: Any],
                   let rows = responseDict[kResponseRecords] as? [[String: Any]],
                   !rows.isEmpty {
                    let row = rows[0]
                    if let parentId = row[capturedIdFieldName] as? String,
                       let parentTimestamp = row[capturedModificationDateFieldName] as? String {
                        idToRemoteTimestamps[parentId] = parentTimestamp
                    }

                    if let childrenRows = row[capturedChildrenInfo.sobjectTypePlural],
                       !(childrenRows is NSNull),
                       let childrenDict = childrenRows as? [String: Any],
                       let childRecords = childrenDict[kResponseRecords] as? [[String: Any]] {
                        for childRow in childRecords {
                            if let childId = childRow[capturedChildrenInfo.idFieldName] as? String,
                               let childTimestamp = childRow[capturedChildrenInfo.modificationDateFieldName] as? String {
                                idToRemoteTimestamps[childId] = childTimestamp
                            }
                        }
                    }
                }

                completionBlock(idToRemoteTimestamps)
            }
        )
    }

    private func syncUpRecord(
        _ syncManager: MobileSyncSyncManager,
        record: NSMutableDictionary,
        children: [[String: Any]],
        fieldlist: [Any],
        mergeMode: SyncStateMergeMode,
        completionBlock: @escaping SyncUpTargetCompleteBlock,
        failBlock: @escaping SyncUpTargetErrorBlock
    ) {
        let recordDict = record as! [String: Any]
        let isCreate = isLocallyCreated(recordDict)
        let isDelete = isLocallyDeleted(recordDict)

        var requests: [RecordRequest] = []

        // Preparing request for parent
        let parentId = recordDict[idFieldName] as? String ?? ""
        let parentRequest = buildRequest(forParentRecord: recordDict, fieldlist: fieldlist)

        // Parent request goes first unless it's a delete
        if let parentRequest = parentRequest, !isDelete {
            parentRequest.referenceId = parentId
            requests.append(parentRequest)
        }

        // Preparing requests for children
        for var childRecord in children {
            let childId = childRecord[childrenInfo.idFieldName] as? String ?? ""

            // Parent will get a server id
            // Children need to be updated
            if isCreate {
                childRecord[syncTargetLocal] = true
                childRecord[syncTargetLocallyUpdated] = true
            }

            if let childRequest = buildRequest(
                forChildRecord: childRecord,
                useParentIdReference: isCreate,
                parentId: isDelete ? nil : parentId
            ) {
                childRequest.referenceId = childId
                requests.append(childRequest)
            }
        }

        // Parent request goes last when it's a delete
        if let parentRequest = parentRequest, isDelete {
            parentRequest.referenceId = parentId
            requests.append(parentRequest)
        }

        // Sending composite request
        let sendCompositeRequestCompleteBlock: SendCompositeRequestCompleteBlock = { [weak self] refIdToResponses in
            guard let self = self else { return }

            // Build refId to server id
            let refIdToServerId = CompositeRequestHelper.parseIdsFromResponses(refIdToResponses)

            // Will a re-run be required?
            var needReRun = false

            // Update parent in local store
            if self.isDirty(recordDict) {
                needReRun = self.updateParentRecord(
                    inLocalStore: syncManager,
                    record: record,
                    children: children,
                    mergeMode: mergeMode,
                    refIdToServerId: refIdToServerId,
                    response: refIdToResponses[recordDict[self.idFieldName] as? String ?? ""]
                )
            }

            // Update children local store
            for childRecord in children {
                if self.isDirty(childRecord) || isCreate {
                    needReRun = needReRun || self.updateChildRecord(
                        inLocalStore: syncManager,
                        record: childRecord,
                        parent: record,
                        mergeMode: mergeMode,
                        refIdToServerId: refIdToServerId,
                        response: refIdToResponses[childRecord[self.childrenInfo.idFieldName] as? String ?? ""]
                    )
                }
            }

            // Re-run if required
            if needReRun {
                SFSDKMobileSyncLogger.d(type(of: self), message: "syncUpOneRecord:\(recordDict)")
                self.syncUpRecord(
                    syncManager,
                    record: record,
                    children: children,
                    fieldlist: fieldlist,
                    mergeMode: mergeMode,
                    completionBlock: completionBlock,
                    failBlock: failBlock
                )
            } else {
                // Done
                completionBlock(nil)
            }
        }

        CompositeRequestHelper.sendAsCompositeBatchRequest(
            syncManager,
            allOrNone: false,
            recordRequests: requests,
            onComplete: sendCompositeRequestCompleteBlock,
            onFail: failBlock
        )
    }

    private func buildRequest(
        forParentRecord record: [AnyHashable: Any],
        fieldlist: [Any]
    ) -> RecordRequest? {
        return buildRequest(
            forRecord: record,
            fieldlist: fieldlist,
            isParent: true,
            useParentIdReference: false,
            parentId: nil
        )
    }

    private func buildRequest(
        forChildRecord record: [AnyHashable: Any],
        useParentIdReference: Bool,
        parentId: String?
    ) -> RecordRequest? {
        return buildRequest(
            forRecord: record,
            fieldlist: nil,
            isParent: false,
            useParentIdReference: useParentIdReference,
            parentId: parentId
        )
    }

    private func buildRequest(
        forRecord record: [AnyHashable: Any],
        fieldlist: [Any]?,
        isParent: Bool,
        useParentIdReference: Bool,
        parentId: String?
    ) -> RecordRequest? {
        let recordDict = record as? [String: Any] ?? [:]
        if !isDirty(recordDict) {
            return nil // nothing to do
        }

        let info: ParentInfo = isParent ? parentInfo : childrenInfo
        let id = recordDict[info.idFieldName] as? String ?? ""

        // Delete case
        let isCreate = isLocallyCreated(recordDict)
        let isDelete = isLocallyDeleted(recordDict)

        if isDelete {
            if isCreate {
                return nil // no need to go to server
            } else {
                return RecordRequest.requestForDelete(objectType: info.sobjectType, objectId: id)
            }
        }
        // Create/update cases
        else {
            var fieldlist = fieldlist
            if isParent {
                fieldlist = isCreate
                    ? (createFieldlist ?? fieldlist)
                    : (updateFieldlist ?? fieldlist)
            } else {
                fieldlist = isCreate
                    ? childrenCreateFieldlist
                    : childrenUpdateFieldlist
            }

            var fields = buildFieldsMap(
                record: recordDict,
                fieldlist: fieldlist ?? [],
                idFieldName: info.idFieldName,
                modificationDateFieldName: info.modificationDateFieldName
            )

            if let parentId = parentId, !isParent {
                let childrenInfo = info as? ChildrenInfo
                let parentIdFieldName = childrenInfo?.parentIdFieldName ?? ""
                if useParentIdReference {
                    fields[parentIdFieldName] = "@{\(parentId).\(kCreatedId)}"
                } else {
                    fields[parentIdFieldName] = parentId
                }
            }

            if isCreate {
                let externalId = info.externalIdFieldName != nil ? recordDict[info.externalIdFieldName!] as? String : nil
                if let externalId = externalId,
                   !SyncTarget.isLocalId(externalId) {
                    return RecordRequest.requestForUpsert(
                        objectType: info.sobjectType,
                        externalIdFieldName: info.externalIdFieldName!,
                        externalId: externalId,
                        fields: fields
                    )
                } else {
                    return RecordRequest.requestForCreate(
                        objectType: info.sobjectType,
                        fields: fields
                    )
                }
            } else {
                return RecordRequest.requestForUpdate(
                    objectType: info.sobjectType,
                    objectId: id,
                    fields: fields
                )
            }
        }
    }

    private func updateParentRecord(
        inLocalStore syncManager: MobileSyncSyncManager,
        record: NSMutableDictionary,
        children: [[String: Any]],
        mergeMode: SyncStateMergeMode,
        refIdToServerId: [String: String],
        response: RecordResponse?
    ) -> Bool {
        var needReRun = false
        let soupName = parentInfo.soupName
        let idFieldName = self.idFieldName
        let lastError = response?.errorJson != nil ? SFJsonUtils.jsonRepresentation(response!.errorJson!) : nil
        let recordDict = record as! [String: Any]

        // Delete case
        if isLocallyDeleted(recordDict) {
            if isLocallyCreated(recordDict) // we didn't go to the sever
                || response?.success == true // or we successfully deleted on the server
                || response?.recordDoesNotExist == true { // or the record was already deleted on the server

                if relationshipType == .masterDetail {
                    ParentChildrenSyncHelper.deleteChildrenFromLocalStore(
                        syncManager.store,
                        parentInfo: parentInfo,
                        childrenInfo: childrenInfo,
                        parentIds: [recordDict[idFieldName] as? String ?? ""]
                    )
                }

                deleteFromLocalStore(syncManager: syncManager, soupName: soupName, record: recordDict)
            }
            // Failure
            else {
                saveInLocalStore(syncManager, soupName: soupName, records: [recordDict], idFieldName: idFieldName, syncId: nil, lastError: lastError, cleanFirst: false)
            }
        }

        // Create / update case
        else {
            // Success case
            if response?.success == true {
                // Plugging server id in id field
                let updatedRecord = CompositeRequestHelper.updateReferences(
                    recordDict,
                    fieldWithRefId: idFieldName,
                    refIdToServerId: refIdToServerId
                )

                // Clean and save
                cleanAndSaveInLocalStore(syncManager: syncManager, soupName: soupName, record: updatedRecord)
            }
            // Handling remotely deleted records
            else if response?.recordDoesNotExist == true {
                // Record needs to be recreated
                if mergeMode == .overwrite {
                    record[syncTargetLocal] = true
                    record[syncTargetLocallyCreated] = true

                    // Children need to be updated or recreated as well (since the parent will get a new server id)
                    // Note: children array is immutable, need to handle this in the caller
                    needReRun = true
                }
            }
            // Failure
            else {
                saveInLocalStore(syncManager, soupName: soupName, records: [recordDict], idFieldName: idFieldName, syncId: nil, lastError: lastError, cleanFirst: false)
            }
        }

        return needReRun
    }

    private func updateChildRecord(
        inLocalStore syncManager: MobileSyncSyncManager,
        record: [String: Any],
        parent: NSMutableDictionary,
        mergeMode: SyncStateMergeMode,
        refIdToServerId: [String: String],
        response: RecordResponse?
    ) -> Bool {
        var needReRun = false
        let soupName = childrenInfo.soupName
        let lastError = response?.errorJson != nil ? SFJsonUtils.jsonRepresentation(response!.errorJson!) : nil

        // Delete case
        if isLocallyDeleted(record) {
            if isLocallyCreated(record) // we didn't go to the sever
                || response?.success == true // or we successfully deleted on the server
                || response?.recordDoesNotExist == true { // or the record was already deleted on the server
                deleteFromLocalStore(syncManager: syncManager, soupName: soupName, record: record)
            }
            // Failure
            else {
                saveInLocalStore(syncManager, soupName: soupName, records: [record], idFieldName: childrenInfo.idFieldName, syncId: nil, lastError: lastError, cleanFirst: false)
            }
        }

        // Create / update case
        else {
            // Success case
            if response?.success == true {
                // Plugging server id in id field
                let updatedRecord = CompositeRequestHelper.updateReferences(
                    record,
                    fieldWithRefId: childrenInfo.idFieldName,
                    refIdToServerId: refIdToServerId
                )

                // Plugging server id in parent id field
                let fullUpdatedRecord = CompositeRequestHelper.updateReferences(
                    updatedRecord,
                    fieldWithRefId: childrenInfo.parentIdFieldName,
                    refIdToServerId: refIdToServerId
                )

                // Clean and save
                cleanAndSaveInLocalStore(syncManager: syncManager, soupName: soupName, record: fullUpdatedRecord)
            }

            // Handling remotely deleted records
            else if response?.recordDoesNotExist == true {
                // Record needs to be recreated
                if mergeMode == .overwrite {
                    // Note: record is immutable, need to handle this in the caller
                    needReRun = true
                }
            }

            // Handling remotely deleted parent
            else if response?.relatedRecordDoesNotExist == true {
                // Parent record needs to be recreated
                if mergeMode == .overwrite {
                    parent[syncTargetLocal] = true
                    parent[syncTargetLocallyCreated] = true

                    // We need a re-run
                    needReRun = true
                }
            }

            // Failure
            else {
                saveInLocalStore(syncManager, soupName: soupName, records: [record], idFieldName: childrenInfo.idFieldName, syncId: nil, lastError: lastError, cleanFirst: false)
            }
        }

        return needReRun
    }

    private func getRequest(forTimestamps parentId: String) -> RestRequest {
        let builderNested = SFSDKSoqlBuilder.withFields(array: [
            childrenInfo.idFieldName,
            childrenInfo.modificationDateFieldName
        ])
        _ = builderNested.from(childrenInfo.sobjectTypePlural)

        let builder = SFSDKSoqlBuilder.withFields(array: [
            idFieldName,
            modificationDateFieldName,
            "(\(builderNested.build() ?? ""))"
        ])
        _ = builder.from(parentInfo.sobjectType)
        _ = builder.whereClause("\(idFieldName) = '\(parentId)'")

        return RestClient.shared.requestForQuery(builder.build() ?? "", apiVersion: nil)
    }
}
