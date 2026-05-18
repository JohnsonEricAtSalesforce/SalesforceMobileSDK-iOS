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
import SalesforceSDKCommon
import SalesforceSDKCore

private typealias SFFetchLastModifiedDatesCompleteBlock = ([String: String]?) -> Void

@objc(SFParentChildrenSyncUpTarget)
@objcMembers
open class SFParentChildrenSyncUpTarget: SFSyncUpTarget, SFAdvancedSyncUpTarget {

    private var parentInfo: SFParentInfo = SFParentInfo()
    private var childrenInfo: SFChildrenInfo = SFChildrenInfo()
    private var childrenCreateFieldlist: [String] = []
    private var childrenUpdateFieldlist: [String] = []
    private var relationshipType: SFParentChildrenRelationshipType = .masterDetail

    open var maxBatchSize: UInt { return 1 }

    // MARK: - Initialization

    @objc
    public init(parentInfo: SFParentInfo, parentCreateFieldlist: [String], parentUpdateFieldlist: [String], childrenInfo: SFChildrenInfo, childrenCreateFieldlist: [String], childrenUpdateFieldlist: [String], relationshipType: SFParentChildrenRelationshipType) {
        super.init()
        self.parentInfo = parentInfo
        self.idFieldName = parentInfo.idFieldName
        self.modificationDateFieldName = parentInfo.modificationDateFieldName
        self.createFieldlist = parentCreateFieldlist
        self.updateFieldlist = parentUpdateFieldlist
        self.childrenInfo = childrenInfo
        self.childrenCreateFieldlist = childrenCreateFieldlist
        self.childrenUpdateFieldlist = childrenUpdateFieldlist
        self.relationshipType = relationshipType
        SFParentChildrenSyncHelper.registerAppFeature()
    }

    public required init(dict: NSDictionary) {
        super.init()
        let dictionary = dict as? [String: Any] ?? [:]
        let pInfo = SFParentInfo.new(fromDict: dictionary[kSFParentChildrenSyncTargetParent] as? [String: Any] ?? [:])
        let cInfo = SFChildrenInfo.new(fromDict: dictionary[kSFParentChildrenSyncTargetChildren] as? [String: Any] ?? [:])
        self.parentInfo = pInfo
        self.idFieldName = pInfo.idFieldName
        self.modificationDateFieldName = pInfo.modificationDateFieldName
        self.createFieldlist = dictionary[kSFSyncUpTargetCreateFieldlist] as? [String]
        self.updateFieldlist = dictionary[kSFSyncUpTargetUpdateFieldlist] as? [String]
        self.childrenInfo = cInfo
        self.childrenCreateFieldlist = dictionary[kSFParentChildrenSyncTargetChildrenCreateFieldlist] as? [String] ?? []
        self.childrenUpdateFieldlist = dictionary[kSFParentChildrenSyncTargetChildrenUpdateFieldlist] as? [String] ?? []
        self.relationshipType = SFParentChildrenSyncHelper.relationshipType(fromString: dictionary[kSFParentChildrenSyncTargetRelationshipType] as? String ?? "")
        SFParentChildrenSyncHelper.registerAppFeature()
    }

    // MARK: - Factory

    @objc
    open class func newSyncTarget(parentInfo: SFParentInfo, parentCreateFieldlist: [String], parentUpdateFieldlist: [String], childrenInfo: SFChildrenInfo, childrenCreateFieldlist: [String], childrenUpdateFieldlist: [String], relationshipType: SFParentChildrenRelationshipType) -> SFParentChildrenSyncUpTarget {
        return SFParentChildrenSyncUpTarget(parentInfo: parentInfo, parentCreateFieldlist: parentCreateFieldlist, parentUpdateFieldlist: parentUpdateFieldlist, childrenInfo: childrenInfo, childrenCreateFieldlist: childrenCreateFieldlist, childrenUpdateFieldlist: childrenUpdateFieldlist, relationshipType: relationshipType)
    }

    @objc
    open class override func newFromDict(_ dict: NSDictionary?) -> SFParentChildrenSyncUpTarget? {
        return SFParentChildrenSyncUpTarget(dict: dict ?? NSDictionary())
    }

    // MARK: - Serialization

    open override func asDict() -> NSMutableDictionary {
        let dict = super.asDict()
        dict[kSFParentChildrenSyncTargetParent] = self.parentInfo.asDict()
        dict[kSFSyncUpTargetCreateFieldlist] = self.createFieldlist
        dict[kSFSyncUpTargetUpdateFieldlist] = self.updateFieldlist
        dict[kSFParentChildrenSyncTargetChildren] = self.childrenInfo.asDict()
        dict[kSFParentChildrenSyncTargetChildrenCreateFieldlist] = self.childrenCreateFieldlist
        dict[kSFParentChildrenSyncTargetChildrenUpdateFieldlist] = self.childrenUpdateFieldlist
        dict[kSFParentChildrenSyncTargetRelationshipType] = SFParentChildrenSyncHelper.relationshipTypeToString(self.relationshipType)
        return dict
    }

    // MARK: - SFAdvancedSyncUpTarget

    @objc
    open func syncUpRecords(_ syncManager: SFMobileSyncSyncManager, records: [NSMutableDictionary], fieldlist: [Any], mergeMode: SFSyncStateMergeMode, syncSoupName: String, completionBlock: @escaping SFSyncUpTargetCompleteBlock, failBlock: @escaping SFSyncUpTargetErrorBlock) {
        if records.isEmpty {
            completionBlock(nil)
        } else {
            syncUpRecord(syncManager, record: records[0], fieldlist: fieldlist as? [String] ?? [], mergeMode: mergeMode, completionBlock: completionBlock, failBlock: failBlock)
        }
    }

    // MARK: - Overrides

    open override func getDirtyRecordIdsSql(_ soupName: String, idField: String) -> String {
        return SFParentChildrenSyncHelper.getDirtyRecordIdsSql(self.parentInfo, childrenInfo: self.childrenInfo, parentFieldToSelect: idField)
    }

    open override func isNewerThanServer(_ syncManager: SFMobileSyncSyncManager, record: NSDictionary, resultBlock: @escaping SFSyncUpRecordNewerThanServerBlock) {
        if isLocallyCreated(record) {
            resultBlock(true)
            return
        }

        let idToLocalTimestamps = getLocalLastModifiedDates(syncManager, record: record)
        fetchLastModifiedDates(syncManager, record: record) { [weak self] idToRemoteTimestamps in
            guard let self = self, let localTimestamps = idToLocalTimestamps else {
                resultBlock(true)
                return
            }
            for (id, localModDate) in localTimestamps {
                let remoteTimestamp = idToRemoteTimestamps?[id]
                let remoteModDate = SFRecordModDate(timestamp: remoteTimestamp, isDeleted: remoteTimestamp == nil)
                if !self.isNewerThanServer(localModDate, remoteModDate: remoteModDate) {
                    resultBlock(false)
                    return
                }
            }
            resultBlock(true)
        }
    }

    // These methods should not be called for advanced sync up target
    open override func createOnServer(syncManager: SFMobileSyncSyncManager, record: NSDictionary, fieldlist: [Any], completionBlock: @escaping SFSyncUpTargetCompleteBlock, failBlock: @escaping SFSyncUpTargetErrorBlock) {
        NSException(name: .invalidArgumentException, reason: "For advanced sync up target, call syncUpRecords", userInfo: nil).raise()
    }

    open override func updateOnServer(syncManager: SFMobileSyncSyncManager, record: NSDictionary, fieldlist: [Any], completionBlock: @escaping SFSyncUpTargetCompleteBlock, failBlock: @escaping SFSyncUpTargetErrorBlock) {
        NSException(name: .invalidArgumentException, reason: "For advanced sync up target, call syncUpRecords", userInfo: nil).raise()
    }

    open override func deleteOnServer(syncManager: SFMobileSyncSyncManager, record: NSDictionary, completionBlock: @escaping SFSyncUpTargetCompleteBlock, failBlock: @escaping SFSyncUpTargetErrorBlock) {
        NSException(name: .invalidArgumentException, reason: "For advanced sync up target, call syncUpRecords", userInfo: nil).raise()
    }

    // MARK: - Private sync logic

    private func syncUpRecord(_ syncManager: SFMobileSyncSyncManager, record: NSMutableDictionary, fieldlist: [String], mergeMode: SFSyncStateMergeMode, completionBlock: @escaping SFSyncUpTargetCompleteBlock, failBlock: @escaping SFSyncUpTargetErrorBlock) {
        let isCreate = isLocallyCreated(record)
        let isDelete = isLocallyDeleted(record)

        let children: [NSMutableDictionary]
        if self.relationshipType == .masterDetail && isDelete && !isCreate {
            children = []
        } else {
            children = SFParentChildrenSyncHelper.getMutableChildren(fromLocalStore: syncManager.store, parentInfo: self.parentInfo, childrenInfo: self.childrenInfo, parent: record as? [String: Any] ?? [:])
        }

        syncUpRecord(syncManager, record: record, children: children, fieldlist: fieldlist, mergeMode: mergeMode, completionBlock: completionBlock, failBlock: failBlock)
    }

    private func syncUpRecord(_ syncManager: SFMobileSyncSyncManager, record: NSMutableDictionary, children: [NSMutableDictionary], fieldlist: [String], mergeMode: SFSyncStateMergeMode, completionBlock: @escaping SFSyncUpTargetCompleteBlock, failBlock: @escaping SFSyncUpTargetErrorBlock) {
        let isCreate = isLocallyCreated(record)
        let isDelete = isLocallyDeleted(record)

        var requests = [RecordRequest]()

        // Preparing request for parent
        let parentId = record[self.idFieldName] as? String ?? ""
        let parentRequest = buildRequestForParentRecord(record, fieldlist: fieldlist)

        // Parent request goes first unless it's a delete
        if let parentRequest = parentRequest, !isDelete {
            parentRequest.referenceId = parentId
            requests.append(parentRequest)
        }

        // Preparing requests for children
        for childRecord in children {
            let childId = childRecord[self.childrenInfo.idFieldName] as? String ?? ""

            if isCreate {
                childRecord[kSyncTargetLocal] = NSNumber(value: true)
                childRecord[kSyncTargetLocallyUpdated] = NSNumber(value: true)
            }

            let childRequest = buildRequestForChildRecord(childRecord, useParentIdReference: isCreate, parentId: isDelete ? nil : parentId)
            if let childRequest = childRequest {
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
        let sendCompleteBlock: OnSendCompleteCallback = { [weak self] refIdToResponses in
            guard let self = self else { return }
            let refIdToServerId = CompositeRequestHelper.parseIdsFromResponses(refIdToResponses)
            var needReRun = false

            if self.isDirty(record) {
                needReRun = self.updateParentRecordInLocalStore(syncManager, record: record, children: children, mergeMode: mergeMode, refIdToServerId: refIdToServerId, response: refIdToResponses[record[self.idFieldName] as? String ?? ""])
            }

            for childRecord in children {
                if self.isDirty(childRecord) || isCreate {
                    let childResponse = refIdToResponses[childRecord[self.childrenInfo.idFieldName] as? String ?? ""]
                    needReRun = self.updateChildRecordInLocalStore(syncManager, record: childRecord, parent: record, mergeMode: mergeMode, refIdToServerId: refIdToServerId, response: childResponse) || needReRun
                }
            }

            if needReRun {
                SFSDKMobileSyncLogger.d(type(of: self), message: "syncUpOneRecord:\(record)")
                self.syncUpRecord(syncManager, record: record, children: children, fieldlist: fieldlist, mergeMode: mergeMode, completionBlock: completionBlock, failBlock: failBlock)
            } else {
                completionBlock(nil)
            }
        }

        CompositeRequestHelper.sendAsCompositeBatchRequest(syncManager, allOrNone: false, recordRequests: requests, onComplete: sendCompleteBlock, onFail: failBlock)
    }

    // MARK: - Request building

    private func buildRequestForParentRecord(_ record: NSDictionary, fieldlist: [String]) -> RecordRequest? {
        return buildRequestForRecord(record, fieldlist: fieldlist, isParent: true, useParentIdReference: false, parentId: nil)
    }

    private func buildRequestForChildRecord(_ record: NSDictionary, useParentIdReference: Bool, parentId: String?) -> RecordRequest? {
        return buildRequestForRecord(record, fieldlist: nil, isParent: false, useParentIdReference: useParentIdReference, parentId: parentId)
    }

    private func buildRequestForRecord(_ record: NSDictionary, fieldlist: [String]?, isParent: Bool, useParentIdReference: Bool, parentId: String?) -> RecordRequest? {
        if !isDirty(record) {
            return nil
        }

        let info: SFParentInfo = isParent ? self.parentInfo : self.childrenInfo
        let recordId = record[info.idFieldName] as? String ?? ""
        let isCreate = isLocallyCreated(record)
        let isDelete = isLocallyDeleted(record)

        if isDelete {
            if isCreate { return nil }
            return RecordRequest.requestForDelete(objectType: info.sobjectType, objectId: recordId)
        }

        var effectiveFieldlist: [String]
        if isParent {
            effectiveFieldlist = isCreate ? (self.createFieldlist ?? fieldlist ?? []) : (self.updateFieldlist ?? fieldlist ?? [])
        } else {
            effectiveFieldlist = isCreate ? self.childrenCreateFieldlist : self.childrenUpdateFieldlist
        }

        let fields = buildFieldsMap(record, fieldlist: effectiveFieldlist, idFieldName: info.idFieldName, modificationDateFieldName: info.modificationDateFieldName)
        if let parentId = parentId {
            let childInfo = info as? SFChildrenInfo
            let parentIdFieldName = childInfo?.parentIdFieldName ?? ""
            if useParentIdReference {
                fields[parentIdFieldName] = "@{\(parentId).\(kCreatedId)}"
            } else {
                fields[parentIdFieldName] = parentId
            }
        }

        if isCreate {
            let externalId: String? = info.externalIdFieldName != nil ? record[info.externalIdFieldName ?? ""] as? String : nil
            if let externalId = externalId, !SFSyncTarget.isLocalId(externalId) {
                return RecordRequest.requestForUpsert(objectType: info.sobjectType, externalIdFieldName: info.externalIdFieldName ?? "", externalId: externalId, fields: fields as? [String: Any] ?? [:])
            } else {
                return RecordRequest.requestForCreate(objectType: info.sobjectType, fields: fields as? [String: Any] ?? [:])
            }
        } else {
            return RecordRequest.requestForUpdate(objectType: info.sobjectType, objectId: recordId, fields: fields as? [String: Any] ?? [:])
        }
    }

    // MARK: - Local store update helpers

    private func updateParentRecordInLocalStore(_ syncManager: SFMobileSyncSyncManager, record: NSMutableDictionary, children: [NSMutableDictionary], mergeMode: SFSyncStateMergeMode, refIdToServerId: [String: String], response: RecordResponse?) -> Bool {
        var needReRun = false
        let soupName = self.parentInfo.soupName
        let idFieldName = self.idFieldName
        let lastError = SFJsonUtils.jsonRepresentation(response?.errorJson)

        if isLocallyDeleted(record) {
            if isLocallyCreated(record) || (response?.success == true) || (response?.recordDoesNotExist == true) {
                if self.relationshipType == .masterDetail {
                    SFParentChildrenSyncHelper.deleteChildren(fromLocalStore: syncManager.store, parentInfo: self.parentInfo, childrenInfo: self.childrenInfo, parentIds: [record[idFieldName] as Any])
                }
                deleteFromLocalStore(syncManager: syncManager, soupName: soupName, record: record)
            } else {
                saveRecordToLocalStoreWithLastError(syncManager, soupName: soupName, record: record, lastError: lastError)
            }
        } else {
            if response?.success == true {
                let updatedRecord = CompositeRequestHelper.updateReferences(record as? [String: Any] ?? [:], fieldWithRefId: idFieldName, refIdToServerId: refIdToServerId)
                cleanAndSaveInLocalStore(syncManager: syncManager, soupName: soupName, record: updatedRecord as NSDictionary)
            } else if response?.recordDoesNotExist == true {
                if mergeMode == .overwrite {
                    record[kSyncTargetLocal] = NSNumber(value: true)
                    record[kSyncTargetLocallyCreated] = NSNumber(value: true)
                    for childRecord in children {
                        childRecord[kSyncTargetLocal] = NSNumber(value: true)
                        childRecord[self.relationshipType == .masterDetail ? kSyncTargetLocallyCreated : kSyncTargetLocallyUpdated] = NSNumber(value: true)
                    }
                    needReRun = true
                }
            } else {
                saveRecordToLocalStoreWithLastError(syncManager, soupName: soupName, record: record, lastError: lastError)
            }
        }
        return needReRun
    }

    private func updateChildRecordInLocalStore(_ syncManager: SFMobileSyncSyncManager, record: NSMutableDictionary, parent: NSMutableDictionary, mergeMode: SFSyncStateMergeMode, refIdToServerId: [String: String], response: RecordResponse?) -> Bool {
        var needReRun = false
        let soupName = self.childrenInfo.soupName
        let lastError = SFJsonUtils.jsonRepresentation(response?.errorJson)

        if isLocallyDeleted(record) {
            if isLocallyCreated(record) || (response?.success == true) || (response?.recordDoesNotExist == true) {
                deleteFromLocalStore(syncManager: syncManager, soupName: soupName, record: record)
            } else {
                saveRecordToLocalStoreWithLastError(syncManager, soupName: soupName, record: record, lastError: lastError)
            }
        } else {
            if response?.success == true {
                var updatedRecord = CompositeRequestHelper.updateReferences(record as? [String: Any] ?? [:], fieldWithRefId: self.childrenInfo.idFieldName, refIdToServerId: refIdToServerId)
                updatedRecord = CompositeRequestHelper.updateReferences(updatedRecord, fieldWithRefId: self.childrenInfo.parentIdFieldName, refIdToServerId: refIdToServerId)
                cleanAndSaveInLocalStore(syncManager: syncManager, soupName: soupName, record: updatedRecord as NSDictionary)
            } else if response?.recordDoesNotExist == true {
                if mergeMode == .overwrite {
                    record[kSyncTargetLocal] = NSNumber(value: true)
                    record[kSyncTargetLocallyCreated] = NSNumber(value: true)
                    needReRun = true
                }
            } else if response?.relatedRecordDoesNotExist == true {
                if mergeMode == .overwrite {
                    parent[kSyncTargetLocal] = NSNumber(value: true)
                    parent[kSyncTargetLocallyCreated] = NSNumber(value: true)
                    needReRun = true
                }
            } else {
                saveRecordToLocalStoreWithLastError(syncManager, soupName: soupName, record: record, lastError: lastError)
            }
        }
        return needReRun
    }

    // MARK: - Timestamp helpers

    private func getLocalLastModifiedDates(_ syncManager: SFMobileSyncSyncManager, record: NSDictionary) -> [String: SFRecordModDate]? {
        var idToLocalTimestamps = [String: SFRecordModDate]()
        let isParentDeleted = isLocallyDeleted(record)
        let parentModDate = SFRecordModDate(timestamp: record[self.modificationDateFieldName] as? String, isDeleted: isParentDeleted)
        idToLocalTimestamps[record[self.idFieldName] as? String ?? ""] = parentModDate

        let children = SFParentChildrenSyncHelper.getMutableChildren(fromLocalStore: syncManager.store, parentInfo: self.parentInfo, childrenInfo: self.childrenInfo, parent: record as? [String: Any] ?? [:])

        for childRecord in children {
            let childModDate = SFRecordModDate(
                timestamp: childRecord[self.childrenInfo.modificationDateFieldName] as? String,
                isDeleted: isLocallyDeleted(childRecord) || (isParentDeleted && self.relationshipType == .masterDetail)
            )
            idToLocalTimestamps[childRecord[self.childrenInfo.idFieldName] as? String ?? ""] = childModDate
        }
        return idToLocalTimestamps
    }

    private func fetchLastModifiedDates(_ syncManager: SFMobileSyncSyncManager, record: NSDictionary, completionBlock: @escaping SFFetchLastModifiedDatesCompleteBlock) {
        if isLocallyCreated(record) {
            completionBlock(nil)
            return
        }

        let parentId = record[self.idFieldName] as? String ?? ""
        let request = getRequestForTimestamps(parentId)
        SFMobileSyncNetworkUtils.sendRequest(withMobileSyncUserAgent: request, failureBlock: { _, _, _ in
            completionBlock(nil)
        }, successBlock: { [weak self] lastModResponse, _ in
            guard let self = self, let response = lastModResponse as? [String: Any] else {
                completionBlock(nil)
                return
            }
            var idToRemoteTimestamps: [String: String]?
            if let rows = response[kResponseRecords] as? [[String: Any]], !rows.isEmpty {
                idToRemoteTimestamps = [String: String]()
                let row = rows[0]
                if let id = row[self.idFieldName] as? String, let ts = row[self.modificationDateFieldName] as? String {
                    idToRemoteTimestamps?[id] = ts
                }
                if let childrenRows = row[self.childrenInfo.sobjectTypePlural] as? [String: Any],
                   let childRecords = childrenRows[kResponseRecords] as? [[String: Any]] {
                    for childRow in childRecords {
                        if let childId = childRow[self.childrenInfo.idFieldName] as? String,
                           let childTs = childRow[self.childrenInfo.modificationDateFieldName] as? String {
                            idToRemoteTimestamps?[childId] = childTs
                        }
                    }
                }
            }
            completionBlock(idToRemoteTimestamps)
        })
    }

    private func getRequestForTimestamps(_ parentId: String) -> RestRequest {
        let builderNested = SFSDKSoqlBuilder.withFieldsArray([self.childrenInfo.idFieldName, self.childrenInfo.modificationDateFieldName])
            .from(self.childrenInfo.sobjectTypePlural)
        let nestedSoql = builderNested.build() ?? ""

        let builder = SFSDKSoqlBuilder.withFieldsArray([self.idFieldName, self.modificationDateFieldName, "(\(nestedSoql))"])
            .from(self.parentInfo.sobjectType)
            .whereClause("\(self.idFieldName) = '\(parentId)'")

        return RestClient.shared.request(forQuery: builder.build() ?? "", apiVersion: nil)
    }
}
