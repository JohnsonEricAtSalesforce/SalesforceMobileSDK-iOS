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
import SalesforceSDKCore

public let kSFSyncUpTargetMaxBatchSize = "maxBatchSize"

private let kSFMaxSubRequestsCompositeAPI: UInt = 25

@objc(SFBatchSyncUpTarget)
@objcMembers
open class SFBatchSyncUpTarget: SFSyncUpTarget, SFAdvancedSyncUpTarget {

    open var maxBatchSize: UInt = kSFMaxSubRequestsCompositeAPI

    // MARK: - Initialization

    public override init() {
        super.init(createFieldlist: nil, updateFieldlist: nil)
        self.maxBatchSize = computeMaxBatchSize(nil)
    }

    public override init(createFieldlist: [String]?, updateFieldlist: [String]?) {
        super.init(createFieldlist: createFieldlist, updateFieldlist: updateFieldlist)
        self.maxBatchSize = computeMaxBatchSize(nil)
    }

    @objc
    public init(createFieldlist: [String]?, updateFieldlist: [String]?, maxBatchSize: NSNumber?) {
        super.init(createFieldlist: createFieldlist, updateFieldlist: updateFieldlist)
        self.maxBatchSize = computeMaxBatchSize(maxBatchSize)
    }

    public required init(dict: NSDictionary) {
        super.init(dict: dict)
        let dictionary = dict as? [String: Any] ?? [:]
        self.maxBatchSize = computeMaxBatchSize(dictionary[kSFSyncUpTargetMaxBatchSize] as? NSNumber)
    }

    // MARK: - Factory

    @objc
    open class override func newFromDict(_ dict: NSDictionary?) -> SFBatchSyncUpTarget? {
        return SFBatchSyncUpTarget(dict: dict ?? NSDictionary())
    }

    // MARK: - Serialization

    open override func asDict() -> NSMutableDictionary {
        let dict = super.asDict()
        dict[kSFSyncUpTargetMaxBatchSize] = NSNumber(value: self.maxBatchSize)
        return dict
    }

    // MARK: - SFAdvancedSyncUpTarget

    @objc
    open func syncUpRecords(_ syncManager: SFMobileSyncSyncManager, records: [NSMutableDictionary], fieldlist: [Any], mergeMode: SFSyncStateMergeMode, syncSoupName: String, completionBlock: @escaping SFSyncUpTargetCompleteBlock, failBlock: @escaping SFSyncUpTargetErrorBlock) {
        syncUpRecords(syncManager, records: records, fieldlist: fieldlist, mergeMode: mergeMode, syncSoupName: syncSoupName, isReRun: false, completionBlock: completionBlock, failBlock: failBlock)
    }

    @objc
    open func syncUpRecords(_ syncManager: SFMobileSyncSyncManager, records: [NSMutableDictionary], fieldlist: [Any], mergeMode: SFSyncStateMergeMode, syncSoupName: String, isReRun: Bool, completionBlock: @escaping SFSyncUpTargetCompleteBlock, failBlock: @escaping SFSyncUpTargetErrorBlock) {

        if records.isEmpty {
            completionBlock(nil)
            return
        }

        var requests = [RecordRequest]()

        for record in records {
            var refId: String
            if record[self.idFieldName] == nil || record[self.idFieldName] is NSNull {
                let localId = SFSyncTarget.createLocalId()
                record[self.idFieldName] = localId
                refId = localId
            } else {
                refId = record[self.idFieldName] as? String ?? ""
            }

            if let request = buildRequestForRecord(record, fieldlist: fieldlist as? [String] ?? []) {
                request.referenceId = refId
                requests.append(request)
            }
        }

        // Sending composite request
        let sendCompleteBlock: OnSendCompleteCallback = { [weak self] refIdToResponses in
            guard let self = self else { return }

            let refIdToServerId = CompositeRequestHelper.parseIdsFromResponses(refIdToResponses)
            var needReRun = false

            for record in records {
                if self.isDirty(record) {
                    let recordId = record[self.idFieldName] as? String ?? ""
                    let response = refIdToResponses[recordId]
                    needReRun = self.updateRecordInLocalStore(syncManager, soupName: syncSoupName, record: record, mergeMode: mergeMode, refIdToServerId: refIdToServerId, response: response, isReRun: isReRun) || needReRun
                }
            }

            if needReRun && !isReRun {
                self.syncUpRecords(syncManager, records: records, fieldlist: fieldlist, mergeMode: mergeMode, syncSoupName: syncSoupName, isReRun: true, completionBlock: completionBlock, failBlock: failBlock)
            } else {
                completionBlock(nil)
            }
        }

        sendRecordRequests(syncManager, recordRequests: requests, onComplete: sendCompleteBlock, onFail: failBlock)
    }

    @objc
    open func sendRecordRequests(_ syncManager: SFMobileSyncSyncManager, recordRequests requests: [RecordRequest], onComplete sendCompleteBlock: @escaping OnSendCompleteCallback, onFail failBlock: @escaping SFSyncUpTargetErrorBlock) {
        CompositeRequestHelper.sendAsCompositeBatchRequest(syncManager, allOrNone: false, recordRequests: requests, onComplete: sendCompleteBlock, onFail: failBlock)
    }

    // MARK: - Helper methods

    @objc
    open func buildRequestForRecord(_ record: NSDictionary, fieldlist: [String]) -> RecordRequest? {
        if !isDirty(record) {
            return nil
        }

        let objectType = SFJsonUtils.project(intoJson:record, path: kObjectTypeField) as? String ?? ""
        let objectId = record[self.idFieldName] as? String ?? ""

        let isCreate = isLocallyCreated(record)
        let isDelete = isLocallyDeleted(record)

        if isDelete {
            if isCreate {
                return nil
            } else {
                return RecordRequest.requestForDelete(objectType: objectType, objectId: objectId)
            }
        } else {
            if isCreate {
                let effectiveFieldlist = self.createFieldlist ?? fieldlist
                let fields = buildFieldsMap(record, fieldlist: effectiveFieldlist, idFieldName: self.idFieldName, modificationDateFieldName: self.modificationDateFieldName)
                let externalId: String? = self.externalIdFieldName != nil ? record[self.externalIdFieldName ?? ""] as? String : nil
                if let externalId = externalId, !SFSyncTarget.isLocalId(externalId) {
                    return RecordRequest.requestForUpsert(objectType: objectType, externalIdFieldName: self.externalIdFieldName ?? "", externalId: externalId, fields: fields as? [String: Any] ?? [:])
                } else {
                    return RecordRequest.requestForCreate(objectType: objectType, fields: fields as? [String: Any] ?? [:])
                }
            } else {
                let effectiveFieldlist = self.updateFieldlist ?? fieldlist
                let fields = buildFieldsMap(record, fieldlist: effectiveFieldlist, idFieldName: self.idFieldName, modificationDateFieldName: self.modificationDateFieldName)
                return RecordRequest.requestForUpdate(objectType: objectType, objectId: objectId, fields: fields as? [String: Any] ?? [:])
            }
        }
    }

    @objc
    open func updateRecordInLocalStore(_ syncManager: SFMobileSyncSyncManager, soupName: String, record: NSMutableDictionary, mergeMode: SFSyncStateMergeMode, refIdToServerId: [String: String], response: RecordResponse?, isReRun: Bool) -> Bool {
        var needReRun = false
        let lastError = SFJsonUtils.jsonRepresentation(response?.errorJson)

        if isLocallyDeleted(record) {
            if isLocallyCreated(record) || (response?.success == true) || (response?.recordDoesNotExist == true) {
                deleteFromLocalStore(syncManager: syncManager, soupName: soupName, record: record)
            } else {
                saveRecordToLocalStoreWithLastError(syncManager, soupName: soupName, record: record, lastError: lastError)
            }
        } else {
            if response?.success == true {
                let updatedRecord = CompositeRequestHelper.updateReferences(record as? [String: Any] ?? [:], fieldWithRefId: self.idFieldName, refIdToServerId: refIdToServerId)
                cleanAndSaveInLocalStore(syncManager: syncManager, soupName: soupName, record: updatedRecord as NSDictionary)
            } else if response?.recordDoesNotExist == true && mergeMode == .overwrite && !isReRun {
                record[kSyncTargetLocal] = NSNumber(value: true)
                record[kSyncTargetLocallyCreated] = NSNumber(value: true)
                needReRun = true
            } else {
                saveRecordToLocalStoreWithLastError(syncManager, soupName: soupName, record: record, lastError: lastError)
            }
        }
        return needReRun
    }

    @objc
    open func computeMaxBatchSize(_ maxBatchSize: NSNumber?) -> UInt {
        if maxBatchSize == nil || maxBatchSize?.uintValue ?? 0 > maxAPIBatchSize() {
            return maxAPIBatchSize()
        }
        return maxBatchSize?.uintValue ?? maxAPIBatchSize()
    }

    @objc
    open func maxAPIBatchSize() -> UInt {
        return kSFMaxSubRequestsCompositeAPI
    }
}
