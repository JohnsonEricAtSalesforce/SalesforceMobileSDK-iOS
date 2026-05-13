/*
 Copyright (c) 2015-present, salesforce.com, inc. All rights reserved.

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
import SmartStore

public let kSFSyncUpTargetCreateFieldlist = "createFieldlist"
public let kSFSyncUpTargetUpdateFieldlist = "updateFieldlist"
public let kSFSyncUpTargetExternalIdFieldName = "externalIdFieldName"

// Target types
let kSFSyncUpTargetTypeRestStandard = "rest"
let kSFSyncUpTargetTypeCustom = "custom"

// Block type aliases
public typealias RecordNewerThanServerBlock = (Bool) -> Void
public typealias RecordsNewerThanServerBlock = ([String: Any]) -> Void
public typealias SyncUpcompletionBlock = ([String: Any]?) -> Void
public typealias SyncUpErrorBlock = (Error) -> Void
public typealias SyncUpTargetAction = SyncUpTarget.Action
public typealias SyncUpTargetCompleteBlock = ([String: Any]?) -> Void
public typealias SyncUpTargetErrorBlock = (Error) -> Void
public typealias SyncUpRecordNewerThanServerBlock = (Bool) -> Void

// Helper class for isNewerThanServer
@objc(SFRecordModDate)
public class RecordModDate: NSObject {
    @objc public var timestamp: Date?
    @objc public var isDeleted: Bool = false

    @objc
    public init(timestamp: String?, isDeleted: Bool) {
        self.timestamp = timestamp != nil ? FormatUtils.getDateFromIsoDateString(timestamp!) : nil
        self.isDeleted = isDeleted
        super.init()
    }
}

typealias SFSyncUpRecordModDateBlock = (RecordModDate) -> Void

@objc(SFSyncUpTarget)
open class SyncUpTarget: SyncTarget {

    @objc
    public enum TargetType: UInt {
        case standard
        case custom
    }

    @objc
    public enum Action: UInt {
        case none
        case create
        case update
        case delete
    }

    @objc public var targetType: TargetType = .standard

    @objc public internal(set) var createFieldlist: [String]?

    @objc public internal(set) var updateFieldlist: [String]?

    @objc public var externalIdFieldName: String?

    var lastError: String?

    // MARK: - Initialization and serialization methods

    required public init(dict: [String: Any]?) {
        super.init(dict: dict)
        let dict = dict ?? [:]
        self.createFieldlist = dict[kSFSyncUpTargetCreateFieldlist] as? [String]
        self.updateFieldlist = dict[kSFSyncUpTargetUpdateFieldlist] as? [String]
        self.externalIdFieldName = dict[kSFSyncUpTargetExternalIdFieldName] as? String
    }

    public override init() {
        super.init()
        self.targetType = .standard
        self.createFieldlist = nil
        self.updateFieldlist = nil
    }

    @objc
    public init(createFieldlist: [String]?, updateFieldlist: [String]?) {
        super.init()
        self.targetType = .standard
        self.createFieldlist = createFieldlist
        self.updateFieldlist = updateFieldlist
    }

    @objc(build:)
    open class func newFromDict(_ dict: [String: Any]?) -> SyncUpTarget? {
        guard let dict = dict else { return nil }

        // We should have an implementation class or a target type
        if let implClassName = dict[kSFSyncTargetiOSImplKey] as? String, !implClassName.isEmpty {
            guard let customSyncUpClass = NSClassFromString(implClassName) as? SyncUpTarget.Type else {
                SFSDKMobileSyncLogger.e(SyncUpTarget.self, message: "Class '\(implClassName)' is not a subclass of SyncUpTarget.")
                return nil
            }
            return customSyncUpClass.init(dict: dict)
        }
        // No implementation class - using target type
        else {
            // No target type - assume kSFSyncUpTargetTypeRestStandard (hybrid apps don't specify it a sync up target type by default)
            let targetTypeString = dict[kSFSyncTargetTypeKey] as? String ?? kSFSyncUpTargetTypeRestStandard
            switch targetType(from: targetTypeString) {
            case .standard:
                // Default sync up target (it's CollectionSyncUpTarget starting in Mobile SDK 10.1)
                return CollectionSyncUpTarget(dict: dict)
            case .custom:
                SFSDKMobileSyncLogger.e(SyncUpTarget.self, message: "Custom class name not specified.")
                return nil
            }
        }
    }

    open override func asDict() -> [String: Any] {
        var dict = super.asDict()
        dict[kSFSyncTargetTypeKey] = Self.targetType(toString: targetType)
        if let createFieldlist = createFieldlist {
            dict[kSFSyncUpTargetCreateFieldlist] = createFieldlist
        }
        if let updateFieldlist = updateFieldlist {
            dict[kSFSyncUpTargetUpdateFieldlist] = updateFieldlist
        }
        if let externalIdFieldName = externalIdFieldName {
            dict[kSFSyncUpTargetExternalIdFieldName] = externalIdFieldName
        }
        return dict
    }

    // MARK: - Public sync up methods

    @objc
    open func isNewerThanServer(syncManager: MobileSyncSyncManager,
                               record: [String: Any],
                               resultBlock: @escaping RecordNewerThanServerBlock) {
        if isLocallyCreated(record) {
            resultBlock(true)
        } else {
            let localModDate = RecordModDate(
                timestamp: record[modificationDateFieldName] as? String,
                isDeleted: isLocallyDeleted(record)
            )

            fetchLastModifiedDate(record) { [weak self] remoteModDate in
                guard let self = self else { return }
                resultBlock(self.isNewerThanServer(localModDate: localModDate, remoteModDate: remoteModDate))
            }
        }
    }

    @objc
    open func areNewerThanServer(syncManager: MobileSyncSyncManager,
                                records: [[String: Any]],
                                resultBlock: @escaping RecordsNewerThanServerBlock) {
        isNewerThanServer(syncManager: syncManager,
                         records: records,
                         index: 0,
                         result: [:],
                         resultBlock: resultBlock)
    }

    func isNewerThanServer(syncManager: MobileSyncSyncManager,
                          records: [[String: Any]],
                          index: Int,
                          result: [String: Any],
                          resultBlock: @escaping RecordsNewerThanServerBlock) {
        var mutableResult = result
        if index < records.count {
            let record = records[index]
            guard let storeId = record[SOUP_ENTRY_ID] as? NSNumber else { return }

            isNewerThanServer(syncManager: syncManager, record: record) { [weak self] isNewerThanServer in
                guard let self = self else { return }
                mutableResult[storeId.stringValue] = isNewerThanServer
                self.isNewerThanServer(syncManager: syncManager,
                                      records: records,
                                      index: index + 1,
                                      result: mutableResult,
                                      resultBlock: resultBlock)
            }
        } else {
            resultBlock(mutableResult)
        }
    }

    @objc(createOnServer:record:fieldlist:onComplete:onFail:)
    open func createOnServer(syncManager: MobileSyncSyncManager,
                            record: [String: Any],
                            fieldlist: [Any],
                            onComplete completionBlock: @escaping SyncUpcompletionBlock,
                            onFail failBlock: @escaping SyncUpErrorBlock) {
        let actualFieldlist = createFieldlist ?? fieldlist
        guard let objectType = SFJsonUtils.projectIntoJson(record, path: kObjectTypeField) as? String else { return }
        let fields = buildFieldsMap(record: record, fieldlist: actualFieldlist)

        if let externalIdFieldName = self.externalIdFieldName,
           let externalId = record[externalIdFieldName] as? String,
           !SyncTarget.isLocalId(externalId) {
            upsertOnServer(objectType: objectType,
                          fields: fields,
                          externalId: externalId,
                          completionBlock: completionBlock,
                          failBlock: failBlock)
        } else {
            createOnServer(objectType: objectType,
                          fields: fields,
                          completionBlock: completionBlock,
                          failBlock: failBlock)
        }
    }

    @objc(updateOnServer:record:fieldlist:onComplete:onFail:)
    open func updateOnServer(syncManager: MobileSyncSyncManager,
                            record: [String: Any],
                            fieldlist: [Any],
                            onComplete completionBlock: @escaping SyncUpcompletionBlock,
                            onFail failBlock: @escaping SyncUpErrorBlock) {
        let actualFieldlist = updateFieldlist ?? fieldlist
        guard let objectType = SFJsonUtils.projectIntoJson(record, path: kObjectTypeField) as? String,
              let objectId = record[idFieldName] as? String else { return }
        let fields = buildFieldsMap(record: record, fieldlist: actualFieldlist)
        updateOnServer(objectType: objectType,
                      objectId: objectId,
                      fields: fields,
                      completionBlock: completionBlock,
                      failBlock: failBlock)
    }

    @objc(deleteOnServer:record:onComplete:onFail:)
    open func deleteOnServer(syncManager: MobileSyncSyncManager,
                            record: [String: Any],
                            onComplete completionBlock: @escaping SyncUpcompletionBlock,
                            onFail failBlock: @escaping SyncUpErrorBlock) {
        guard let objectType = SFJsonUtils.projectIntoJson(record, path: kObjectTypeField) as? String,
              let objectId = record[idFieldName] as? String else { return }
        deleteOnServer(objectType: objectType,
                      objectId: objectId,
                      completionBlock: completionBlock,
                      failBlock: failBlock)
    }

    @objc
    open func getIdsOfRecordsToSyncUp(syncManager: MobileSyncSyncManager, soupName: String) -> [Any] {
        return getDirtyRecordIds(syncManager, soupName: soupName, idField: SOUP_ENTRY_ID).array
    }

    @objc(saveRecordToLocalStoreWithLastError:soupName:record:)
    open func saveRecordToLocalStoreWithLastError(syncManager: MobileSyncSyncManager,
                                                  soupName: String,
                                                  record: [String: Any]) {
        saveRecordToLocalStoreWithLastError(syncManager: syncManager,
                                           soupName: soupName,
                                           record: record,
                                           lastError: self.lastError)
        self.lastError = nil
    }

    // MARK: - String to/from enum for sync up target type

    @objc
    open class func targetType(from targetType: String) -> TargetType {
        if targetType == kSFSyncUpTargetTypeRestStandard {
            return .standard
        } else {
            return .custom
        }
    }

    @objc
    open class func targetType(toString targetType: TargetType) -> String {
        switch targetType {
        case .standard:
            return kSFSyncUpTargetTypeRestStandard
        case .custom:
            return kSFSyncUpTargetTypeCustom
        }
    }

    // MARK: - Helper methods

    @objc
    func buildFieldsMap(record: [String: Any], fieldlist: [Any]) -> [String: Any] {
        return buildFieldsMap(record: record,
                            fieldlist: fieldlist,
                            idFieldName: idFieldName,
                            modificationDateFieldName: modificationDateFieldName)
    }

    @objc
    func buildFieldsMap(record: [String: Any],
                       fieldlist: [Any],
                       idFieldName: String,
                       modificationDateFieldName: String) -> [String: Any] {
        var fields: [String: Any] = [:]
        for fieldName in fieldlist {
            guard let fieldNameStr = fieldName as? String,
                  fieldNameStr != idFieldName,
                  fieldNameStr != modificationDateFieldName else {
                continue
            }
            if let fieldValue = SFJsonUtils.projectIntoJson(record, path: fieldNameStr) {
                fields[fieldNameStr] = fieldValue
            }
        }
        return fields
    }

    func createOnServer(objectType: String,
                       fields: [String: Any],
                       completionBlock: @escaping SyncUpcompletionBlock,
                       failBlock: @escaping SyncUpErrorBlock) {
        let request = RestClient.shared.requestForCreate(withObjectType: objectType, fields: fields, apiVersion: nil)
        sendRequest(request: request, completionBlock: completionBlock, failBlock: failBlock)
    }

    func upsertOnServer(objectType: String,
                       fields: [String: Any],
                       externalId: String,
                       completionBlock: @escaping SyncUpcompletionBlock,
                       failBlock: @escaping SyncUpErrorBlock) {
        guard let externalIdFieldName = self.externalIdFieldName else { return }
        let request = RestClient.shared.requestForUpsert(withObjectType: objectType,
                                                        externalIdField: externalIdFieldName,
                                                        externalId: externalId,
                                                        fields: fields,
                                                        apiVersion: nil)
        sendRequest(request: request, completionBlock: completionBlock, failBlock: failBlock)
    }

    func updateOnServer(objectType: String,
                       objectId: String,
                       fields: [String: Any],
                       completionBlock: @escaping SyncUpcompletionBlock,
                       failBlock: @escaping SyncUpErrorBlock) {
        let request = RestClient.shared.requestForUpdate(withObjectType: objectType,
                                                        objectId: objectId,
                                                        fields: fields,
                                                        apiVersion: nil)
        sendRequest(request: request, completionBlock: completionBlock, failBlock: failBlock)
    }

    func deleteOnServer(objectType: String,
                       objectId: String,
                       completionBlock: @escaping SyncUpcompletionBlock,
                       failBlock: @escaping SyncUpErrorBlock) {
        let request = RestClient.shared.requestForDelete(withObjectType: objectType,
                                                        objectId: objectId,
                                                        apiVersion: nil)
        sendRequest(request: request, completionBlock: completionBlock, failBlock: failBlock)
    }

    func sendRequest(request: RestRequest,
                    completionBlock: @escaping SyncUpcompletionBlock,
                    failBlock: @escaping SyncUpErrorBlock) {
        SFMobileSyncNetworkUtils.sendRequest(withMobileSyncUserAgent:
            request,
            failureBlock: { [weak self] (response: Any?, error: (any Error)?, rawResponse: URLResponse?) in
                if let response = response {
                    self?.lastError = SFJsonUtils.jsonRepresentation(response)
                }
                if let error = error {
                    failBlock(error)
                }
            },
            successBlock: { (dict: Any?, rawResponse: URLResponse?) in
                completionBlock(dict as? [String: Any])
            }
        )
    }

    func fetchLastModifiedDate(_ record: [String: Any],
                              completeBlock: @escaping SFSyncUpRecordModDateBlock) {
        guard let objectType = SFJsonUtils.projectIntoJson(record, path: kObjectTypeField) as? String,
              let objectId = record[idFieldName] as? String else { return }

        let request = RestClient.shared.requestForRetrieve(
            withObjectType: objectType,
            objectId: objectId,
            fieldList: modificationDateFieldName,
            apiVersion: nil
        )

        SFMobileSyncNetworkUtils.sendRequest(withMobileSyncUserAgent:
            request,
            failureBlock: { (response: Any?, error: (any Error)?, rawResponse: URLResponse?) in
                let isDeleted = (error as NSError?)?.code == 404
                completeBlock(RecordModDate(timestamp: nil, isDeleted: isDeleted))
            },
            successBlock: { [weak self] (response: Any?, rawResponse: URLResponse?) in
                guard let self = self,
                      let responseDict = response as? [String: Any],
                      let timestamp = responseDict[self.modificationDateFieldName] as? String else { return }
                completeBlock(RecordModDate(timestamp: timestamp, isDeleted: false))
            }
        )
    }

    @objc
    func isNewerThanServer(localModDate: RecordModDate, remoteModDate: RecordModDate) -> Bool {
        if let localTimestamp = localModDate.timestamp,
           let remoteTimestamp = remoteModDate.timestamp,
           localTimestamp >= remoteTimestamp {
            return true
        }
        if localModDate.isDeleted && remoteModDate.isDeleted {
            return true
        }
        if localModDate.timestamp == nil {
            return true
        }
        return false
    }

    @objc
    func saveRecordToLocalStoreWithLastError(syncManager: MobileSyncSyncManager,
                                            soupName: String,
                                            record: [String: Any],
                                            lastError: String?) {
        if let lastError = lastError {
            saveInLocalStore(syncManager,
                           soupName: soupName,
                           records: [record],
                           idFieldName: idFieldName,
                           syncId: nil,
                           lastError: lastError,
                           cleanFirst: false)
        }
    }
}
