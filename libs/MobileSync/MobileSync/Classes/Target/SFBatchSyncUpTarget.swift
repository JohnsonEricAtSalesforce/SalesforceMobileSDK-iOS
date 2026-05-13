/*
 Copyright (c) 2019-present, salesforce.com, inc. All rights reserved.

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

public let kSFSyncUpTargetMaxBatchSize = "maxBatchSize"

fileprivate let kSFMaxSubRequestsCompositeAPI: UInt = 25

/**
 * Subclass of `SFSyncUpTarget` that batches create, update, and delete operations by using the Salesforce composite API.
 */
@objc(SFBatchSyncUpTarget)
@objcMembers
public class BatchSyncUpTarget: SyncUpTarget, AdvancedSyncUpTarget {

    public private(set) var maxBatchSize: UInt

    // MARK: - Initialization methods

    required public init(dict: [String: Any]?) {
        self.maxBatchSize = BatchSyncUpTarget.computeMaxBatchSize(dict?[kSFSyncUpTargetMaxBatchSize] as? NSNumber)
        super.init(dict: dict)
    }

    public override init() {
        self.maxBatchSize = BatchSyncUpTarget.computeMaxBatchSize(nil)
        super.init()
    }

    @objc(initWithCreateFieldlist:updateFieldlist:)
    public override init(createFieldlist: [String]?, updateFieldlist: [String]?) {
        self.maxBatchSize = BatchSyncUpTarget.computeMaxBatchSize(nil)
        super.init(createFieldlist: createFieldlist, updateFieldlist: updateFieldlist)
    }

    /** Constructor.
     * @param createFieldlist List of fields that can be created on the server.
     * @param updateFieldlist List of fields that can be updated on the server.
     * @param maxBatchSize Maximum size of a batch.
     */
    @objc(initWithCreateFieldlist:updateFieldlist:maxBatchSize:)
    public init(createFieldlist: [String]?, updateFieldlist: [String]?, maxBatchSize: NSNumber?) {
        self.maxBatchSize = BatchSyncUpTarget.computeMaxBatchSize(maxBatchSize)
        super.init(createFieldlist: createFieldlist, updateFieldlist: updateFieldlist)
    }

    // MARK: - Factory method

    @objc(newFromDict:)
    public static func new(from dict: [String: Any]?) -> BatchSyncUpTarget {
        return BatchSyncUpTarget(dict: dict ?? [:])
    }

    // MARK: - To dictionary

    public override func asDict() -> [String: Any] {
        var dict = super.asDict()
        dict[kSFSyncUpTargetMaxBatchSize] = NSNumber(value: maxBatchSize)
        return dict
    }

    // MARK: - SFAdvancedSyncUpTarget methods

    public func syncUpRecords(
        _ syncManager: MobileSyncSyncManager,
        records: [NSMutableDictionary],
        fieldlist: [Any],
        mergeMode: SyncMergeMode,
        syncSoupName: String,
        completionBlock: @escaping SyncUpcompletionBlock,
        failBlock: @escaping SyncUpErrorBlock
    ) {
        syncUpRecords(
            syncManager,
            records: records,
            fieldlist: fieldlist,
            mergeMode: mergeMode,
            syncSoupName: syncSoupName,
            isReRun: false,
            completionBlock: completionBlock,
            failBlock: failBlock
        )
    }

    public func syncUpRecords(
        _ syncManager: MobileSyncSyncManager,
        records: [NSMutableDictionary],
        fieldlist: [Any],
        mergeMode: SyncMergeMode,
        syncSoupName: String,
        isReRun: Bool,
        completionBlock: @escaping SyncUpcompletionBlock,
        failBlock: @escaping SyncUpErrorBlock
    ) {
        if records.isEmpty {
            completionBlock(nil)
            return
        }

        var requests: [RecordRequest] = []

        // Preparing requests
        for record in records {
            let recordDict = record as NSDictionary as! [String: Any]
            let refId: String
            if record[idFieldName] == nil || (record[idFieldName] is NSNull) {
                // create local id - needed for refId
                refId = SyncTarget.createLocalId()
                record[idFieldName] = refId
            } else {
                refId = record[idFieldName] as? String ?? ""
            }

            if let request = buildRequest(forRecord: recordDict, fieldlist: fieldlist) {
                request.referenceId = refId
                requests.append(request)
            }
        }

        // Sending composite request
        let sendCompositeRequestCompleteBlock: OnSendCompleteCallback = { [weak self] refIdToResponses in
            guard let self = self else { return }

            // Build refId to server id
            let refIdToServerId = CompositeRequestHelper.parseIdsFromResponses(refIdToResponses)

            // Will a re-run be required?
            var needReRun = false

            // Update local store
            for record in records {
                let recordDict = record as NSDictionary as! [String: Any]
                if self.isDirty(recordDict) {
                    let response = refIdToResponses[recordDict[self.idFieldName] as? String ?? ""]
                    needReRun = needReRun || self.updateRecord(
                        inLocalStore: syncManager,
                        soupName: syncSoupName,
                        record: record,
                        mergeMode: mergeMode,
                        refIdToServerId: refIdToServerId,
                        response: response,
                        isReRun: isReRun
                    )
                }
            }

            // Re-run if required
            if needReRun && !isReRun {
                self.syncUpRecords(
                    syncManager,
                    records: records,
                    fieldlist: fieldlist,
                    mergeMode: mergeMode,
                    syncSoupName: syncSoupName,
                    isReRun: true,
                    completionBlock: completionBlock,
                    failBlock: failBlock
                )
            } else {
                // Done
                completionBlock(nil)
            }
        }

        sendRecordRequests(
            syncManager,
            recordRequests: requests,
            onComplete: sendCompositeRequestCompleteBlock,
            onFail: failBlock
        )
    }

    public func sendRecordRequests(
        _ syncManager: MobileSyncSyncManager,
        recordRequests requests: [RecordRequest],
        onComplete sendCompleteBlock: @escaping OnSendCompleteCallback,
        onFail failBlock: @escaping SyncUpErrorBlock
    ) {
        CompositeRequestHelper.sendAsCompositeBatchRequest(
            syncManager,
            allOrNone: false,
            recordRequests: requests,
            onComplete: sendCompleteBlock,
            onFail: failBlock
        )
    }

    // MARK: - helper methods

    public func buildRequest(forRecord record: [String: Any], fieldlist: [Any]) -> RecordRequest? {
        if !isDirty(record) {
            return nil // nothing to do
        }

        let objectType = SFJsonUtils.projectIntoJson(record, path: kObjectTypeField) as? String ?? ""
        let objectId = record[idFieldName] as? String

        // Delete case
        let isCreate = isLocallyCreated(record)
        let isDelete = isLocallyDeleted(record)

        if isDelete {
            if isCreate {
                return nil // no need to go to server
            } else {
                return RecordRequest.requestForDelete(objectType: objectType, objectId: objectId ?? "")
            }
        }
        // Create/update cases
        else {
            var fieldlist = fieldlist
            let fields: [String: Any]

            if isCreate {
                fieldlist = self.createFieldlist ?? fieldlist
                fields = buildFieldsMap(
                    record: record,
                    fieldlist: fieldlist,
                    idFieldName: idFieldName,
                    modificationDateFieldName: modificationDateFieldName
                )
                let externalId = externalIdFieldName != nil ? record[externalIdFieldName!] as? String : nil
                if let externalId = externalId,
                   !SyncTarget.isLocalId(externalId) {
                    return RecordRequest.requestForUpsert(
                        objectType: objectType,
                        externalIdFieldName: externalIdFieldName!,
                        externalId: externalId,
                        fields: fields
                    )
                } else {
                    return RecordRequest.requestForCreate(
                        objectType: objectType,
                        fields: fields
                    )
                }
            } else {
                fieldlist = self.updateFieldlist ?? fieldlist
                fields = buildFieldsMap(
                    record: record,
                    fieldlist: fieldlist,
                    idFieldName: idFieldName,
                    modificationDateFieldName: modificationDateFieldName
                )
                return RecordRequest.requestForUpdate(
                    objectType: objectType,
                    objectId: objectId ?? "",
                    fields: fields
                )
            }
        }
    }

    private func updateRecord(
        inLocalStore syncManager: MobileSyncSyncManager,
        soupName: String,
        record: NSMutableDictionary,
        mergeMode: SyncMergeMode,
        refIdToServerId: [String: String],
        response: RecordResponse?,
        isReRun: Bool
    ) -> Bool {
        var needReRun = false
        let recordDict = record as NSDictionary as! [String: Any]
        let lastError = response?.errorJson != nil ? SFJsonUtils.jsonRepresentation(response!.errorJson!) : nil

        // Delete case
        if isLocallyDeleted(recordDict) {
            if isLocallyCreated(recordDict) // we didn't go to the sever
                || response?.success == true // or we successfully deleted on the server
                || response?.recordDoesNotExist == true { // or the record was already deleted on the server
                deleteFromLocalStore(syncManager: syncManager, soupName: soupName, record: recordDict)
            }
            // Failure
            else {
                saveRecordToLocalStoreWithLastError(syncManager: syncManager, soupName: soupName, record: recordDict, lastError: lastError)
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
            else if response?.recordDoesNotExist == true
                        && mergeMode == .overwrite // Record needs to be recreated
                        && !isReRun {
                record[syncTargetLocal] = true
                record[syncTargetLocallyCreated] = true
                needReRun = true
            }
            // Failure
            else {
                saveRecordToLocalStoreWithLastError(syncManager: syncManager, soupName: soupName, record: recordDict, lastError: lastError)
            }
        }

        return needReRun
    }

    private static func computeMaxBatchSize(_ maxBatchSize: NSNumber?) -> UInt {
        if let maxBatchSize = maxBatchSize?.uintValue,
           maxBatchSize <= kSFMaxSubRequestsCompositeAPI {
            return maxBatchSize
        }
        return kSFMaxSubRequestsCompositeAPI
    }

    private func maxAPIBatchSize() -> UInt {
        return kSFMaxSubRequestsCompositeAPI
    }
}
