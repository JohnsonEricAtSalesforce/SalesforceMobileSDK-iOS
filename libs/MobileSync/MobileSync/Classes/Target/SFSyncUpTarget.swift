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
import SmartStore
import SalesforceSDKCommon
import SalesforceSDKCore

public let kSFSyncUpTargetCreateFieldlist = "createFieldlist"
public let kSFSyncUpTargetUpdateFieldlist = "updateFieldlist"
public let kSFSyncUpTargetExternalIdFieldName = "externalIdFieldName"

// Target type string constants
private let kSFSyncUpTargetTypeRestStandard = "rest"
private let kSFSyncUpTargetTypeCustom = "custom"

// Block typedefs
public typealias SFSyncUpRecordNewerThanServerBlock = (Bool) -> Void
public typealias SFSyncUpRecordsNewerThanServerBlock = (NSDictionary) -> Void
public typealias SFSyncUpTargetCompleteBlock = (NSDictionary?) -> Void
public typealias SFSyncUpTargetErrorBlock = (Error) -> Void

@objc
public enum SFSyncUpTargetType: UInt {
    case restStandard = 0
    case custom
}

@objc
public enum SFSyncUpTargetAction: UInt {
    case none = 0
    case create
    case update
    case delete
}

// MARK: - SFRecordModDate

@objc(SFRecordModDate)
@objcMembers
public class SFRecordModDate: NSObject {
    public var timestamp: Date?
    public var isDeleted: Bool = false

    @objc
    public init(timestamp: String?, isDeleted: Bool) {
        super.init()
        self.timestamp = FormatUtils.getDate(fromIsoDateString: timestamp)
        self.isDeleted = isDeleted
    }
}

// MARK: - SFSyncUpTarget

@objc(SFSyncUpTarget)
@objcMembers
open class SFSyncUpTarget: SFSyncTarget {

    open var targetType: SFSyncUpTargetType = .restStandard
    open var createFieldlist: [String]?
    open var updateFieldlist: [String]?
    open var externalIdFieldName: String?

    private var lastError: String?

    // MARK: - Initialization

    public override init() {
        super.init()
        self.targetType = .restStandard
    }

    @objc
    public init(createFieldlist: [String]?, updateFieldlist: [String]?) {
        super.init()
        self.targetType = .restStandard
        self.createFieldlist = createFieldlist
        self.updateFieldlist = updateFieldlist
    }

    public required init(dict: NSDictionary) {
        super.init(dict: dict)
        let dictionary = dict as? [String: Any] ?? [:]
        self.createFieldlist = dictionary[kSFSyncUpTargetCreateFieldlist] as? [String]
        self.updateFieldlist = dictionary[kSFSyncUpTargetUpdateFieldlist] as? [String]
        self.externalIdFieldName = dictionary[kSFSyncUpTargetExternalIdFieldName] as? String
    }

    // MARK: - Factory

    @objc(build:)
    open class func newFromDict(_ dict: NSDictionary?) -> SFSyncUpTarget? {
        let dictionary = dict as? [String: Any]
        // We should have an implementation class or a target type
        if let implClassName = dictionary?[kSFSyncTargetiOSImplKey] as? String, !implClassName.isEmpty {
            guard let customClass = NSClassFromString(implClassName) as? SFSyncUpTarget.Type else {
                SFSDKMobileSyncLogger.e(self, message: "\(#function) Class '\(implClassName)' is not a subclass of \(NSStringFromClass(SFSyncUpTarget.self)).")
                return nil
            }
            return customClass.init(dict: dict ?? NSDictionary())
        } else {
            // No implementation class - using target type
            let targetTypeString = dictionary?[kSFSyncTargetTypeKey] as? String ?? kSFSyncUpTargetTypeRestStandard
            switch SFSyncUpTarget.targetTypeFromString(targetTypeString) {
            case .restStandard:
                return SFCollectionSyncUpTarget(dict: dict ?? NSDictionary())
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
        dict[kSFSyncTargetTypeKey] = SFSyncUpTarget.targetTypeToString(self.targetType)
        if let createFieldlist = self.createFieldlist { dict[kSFSyncUpTargetCreateFieldlist] = createFieldlist }
        if let updateFieldlist = self.updateFieldlist { dict[kSFSyncUpTargetUpdateFieldlist] = updateFieldlist }
        if let externalIdFieldName = self.externalIdFieldName { dict[kSFSyncUpTargetExternalIdFieldName] = externalIdFieldName }
        return dict
    }

    // MARK: - Public sync up methods

    @objc
    open func isNewerThanServer(_ syncManager: SFMobileSyncSyncManager, record: NSDictionary, resultBlock: @escaping SFSyncUpRecordNewerThanServerBlock) {
        if isLocallyCreated(record) {
            resultBlock(true)
        } else {
            let localModDate = SFRecordModDate(timestamp: record[self.modificationDateFieldName] as? String, isDeleted: isLocallyDeleted(record))
            fetchLastModifiedDate(record) { [weak self] remoteModDate in
                guard let self = self else { return }
                resultBlock(self.isNewerThanServer(localModDate, remoteModDate: remoteModDate))
            }
        }
    }

    @objc
    open func areNewerThanServer(_ syncManager: SFMobileSyncSyncManager, records: [NSDictionary], resultBlock: @escaping SFSyncUpRecordsNewerThanServerBlock) {
        isNewerThanServerRecursive(syncManager, records: records, index: 0, result: NSMutableDictionary(), resultBlock: resultBlock)
    }

    private func isNewerThanServerRecursive(_ syncManager: SFMobileSyncSyncManager, records: [NSDictionary], index: UInt, result: NSMutableDictionary, resultBlock: @escaping SFSyncUpRecordsNewerThanServerBlock) {
        if index < records.count {
            let record = records[Int(index)]
            let storeId = record[SmartStoreSoupEntryId] as? NSNumber ?? NSNumber(value: 0)
            isNewerThanServer(syncManager, record: record) { [weak self] isNewer in
                guard let self = self else { return }
                result[storeId] = NSNumber(value: isNewer)
                self.isNewerThanServerRecursive(syncManager, records: records, index: index + 1, result: result, resultBlock: resultBlock)
            }
        } else {
            resultBlock(result)
        }
    }

    @objc(createOnServer:record:fieldlist:onComplete:onFail:)
    open func createOnServer(syncManager: SFMobileSyncSyncManager, record: NSDictionary, fieldlist: [Any], completionBlock: @escaping SFSyncUpTargetCompleteBlock, failBlock: @escaping SFSyncUpTargetErrorBlock) {
        let effectiveFieldlist = self.createFieldlist ?? (fieldlist as? [String] ?? [])
        let objectType = SFJsonUtils.project(intoJson:record, path: kObjectTypeField) as? String ?? ""
        let fields = buildFieldsMap(record, fieldlist: effectiveFieldlist)
        let externalId: String? = self.externalIdFieldName != nil ? record[self.externalIdFieldName ?? ""] as? String : nil

        if let externalId = externalId, !SFSyncTarget.isLocalId(externalId) {
            upsertOnServer(objectType, fields: fields, externalId: externalId, completionBlock: completionBlock, failBlock: failBlock)
        } else {
            createOnServer(objectType, fields: fields, completionBlock: completionBlock, failBlock: failBlock)
        }
    }

    @objc(updateOnServer:record:fieldlist:onComplete:onFail:)
    open func updateOnServer(syncManager: SFMobileSyncSyncManager, record: NSDictionary, fieldlist: [Any], completionBlock: @escaping SFSyncUpTargetCompleteBlock, failBlock: @escaping SFSyncUpTargetErrorBlock) {
        let effectiveFieldlist = self.updateFieldlist ?? (fieldlist as? [String] ?? [])
        let objectType = SFJsonUtils.project(intoJson:record, path: kObjectTypeField) as? String ?? ""
        let objectId = record[self.idFieldName] as? String ?? ""
        let fields = buildFieldsMap(record, fieldlist: effectiveFieldlist)
        updateOnServer(objectType, objectId: objectId, fields: fields, completionBlock: completionBlock, failBlock: failBlock)
    }

    @objc(deleteOnServer:record:onComplete:onFail:)
    open func deleteOnServer(syncManager: SFMobileSyncSyncManager, record: NSDictionary, completionBlock: @escaping SFSyncUpTargetCompleteBlock, failBlock: @escaping SFSyncUpTargetErrorBlock) {
        let objectType = SFJsonUtils.project(intoJson:record, path: kObjectTypeField) as? String ?? ""
        let objectId = record[self.idFieldName] as? String ?? ""
        deleteOnServer(objectType, objectId: objectId, completionBlock: completionBlock, failBlock: failBlock)
    }

    @objc
    open func getIdsOfRecordsToSyncUp(_ syncManager: SFMobileSyncSyncManager, soupName: String) -> [Any] {
        return getDirtyRecordIds(syncManager, soupName: soupName, idField: SmartStoreSoupEntryId).array
    }

    @objc(saveRecordToLocalStoreWithLastError:soupName:record:)
    open func saveRecordToLocalStoreWithLastError(syncManager: SFMobileSyncSyncManager, soupName: String, record: NSDictionary) {
        saveRecordToLocalStoreWithLastError(syncManager, soupName: soupName, record: record, lastError: self.lastError)
        self.lastError = nil
    }

    // MARK: - Type conversion helpers

    @objc
    open class func targetTypeFromString(_ targetType: String) -> SFSyncUpTargetType {
        if targetType == kSFSyncUpTargetTypeRestStandard {
            return .restStandard
        }
        return .custom
    }

    @objc
    open class func targetTypeToString(_ targetType: SFSyncUpTargetType) -> String {
        switch targetType {
        case .restStandard: return kSFSyncUpTargetTypeRestStandard
        case .custom: return kSFSyncUpTargetTypeCustom
        @unknown default: return kSFSyncUpTargetTypeCustom
        }
    }

    // MARK: - isNewerThanServer comparison

    @objc
    open func isNewerThanServer(_ localModDate: SFRecordModDate?, remoteModDate: SFRecordModDate?) -> Bool {
        if (localModDate?.timestamp != nil && remoteModDate?.timestamp != nil
            && localModDate?.timestamp?.compare(remoteModDate?.timestamp ?? Date()) != .orderedAscending)
            || (localModDate?.isDeleted == true && remoteModDate?.isDeleted == true)
            || localModDate?.timestamp == nil {
            return true
        }
        return false
    }

    // MARK: - Helper methods

    @objc
    open func buildFieldsMap(_ record: NSDictionary, fieldlist: [String]) -> NSDictionary {
        return buildFieldsMap(record, fieldlist: fieldlist, idFieldName: self.idFieldName, modificationDateFieldName: self.modificationDateFieldName)
    }

    @objc
    open func buildFieldsMap(_ record: NSDictionary, fieldlist: [String], idFieldName: String, modificationDateFieldName: String) -> NSMutableDictionary {
        let fields = NSMutableDictionary()
        for fieldName in fieldlist {
            if fieldName != idFieldName && fieldName != modificationDateFieldName {
                if let fieldValue = SFJsonUtils.project(intoJson:record, path: fieldName) {
                    fields[fieldName] = fieldValue
                }
            }
        }
        return fields
    }

    @objc
    open func saveRecordToLocalStoreWithLastError(_ syncManager: SFMobileSyncSyncManager, soupName: String, record: NSDictionary, lastError: String?) {
        if let lastError = lastError {
            saveInLocalStore(syncManager, soupName: soupName, records: [record], idFieldName: self.idFieldName, syncId: nil, lastError: lastError, cleanFirst: false)
        }
    }

    // MARK: - Private network methods

    private func createOnServer(_ objectType: String, fields: NSDictionary, completionBlock: @escaping SFSyncUpTargetCompleteBlock, failBlock: @escaping SFSyncUpTargetErrorBlock) {
        let request = RestClient.sharedInstance.requestForCreate(withObjectType: objectType, fields: fields as? [String: Any], apiVersion: nil)
        sendRequest(request, completionBlock: completionBlock, failBlock: failBlock)
    }

    private func upsertOnServer(_ objectType: String, fields: NSDictionary, externalId: String, completionBlock: @escaping SFSyncUpTargetCompleteBlock, failBlock: @escaping SFSyncUpTargetErrorBlock) {
        let request = RestClient.sharedInstance.requestForUpsert(withObjectType: objectType, externalIdField: self.externalIdFieldName ?? "", externalId: externalId, fields: (fields as? [String: Any]) ?? [:], apiVersion: nil)
        sendRequest(request, completionBlock: completionBlock, failBlock: failBlock)
    }

    private func updateOnServer(_ objectType: String, objectId: String, fields: NSDictionary, completionBlock: @escaping SFSyncUpTargetCompleteBlock, failBlock: @escaping SFSyncUpTargetErrorBlock) {
        let request = RestClient.sharedInstance.requestForUpdate(withObjectType: objectType, objectId: objectId, fields: fields as? [String: Any], apiVersion: nil)
        sendRequest(request, completionBlock: completionBlock, failBlock: failBlock)
    }

    private func deleteOnServer(_ objectType: String, objectId: String, completionBlock: @escaping SFSyncUpTargetCompleteBlock, failBlock: @escaping SFSyncUpTargetErrorBlock) {
        let request = RestClient.sharedInstance.requestForDelete(withObjectType: objectType, objectId: objectId, apiVersion: nil)
        sendRequest(request, completionBlock: completionBlock, failBlock: failBlock)
    }

    private func sendRequest(_ request: RestRequest, completionBlock: @escaping SFSyncUpTargetCompleteBlock, failBlock: @escaping SFSyncUpTargetErrorBlock) {
        SFMobileSyncNetworkUtils.sendRequest(withMobileSyncUserAgent: request, failureBlock: { [weak self] response, error, _ in
            self?.lastError = SFJsonUtils.jsonRepresentation(response)
            if let error = error {
                failBlock(error)
            }
        }, successBlock: { dict, _ in
            completionBlock(dict as? NSDictionary)
        })
    }

    private func fetchLastModifiedDate(_ record: NSDictionary, completeBlock: @escaping (SFRecordModDate) -> Void) {
        let objectType = SFJsonUtils.project(intoJson:record, path: kObjectTypeField) as? String ?? ""
        let objectId = record[self.idFieldName] as? String ?? ""
        let request = RestClient.sharedInstance.requestForRetrieve(withObjectType: objectType, objectId: objectId, fieldList: self.modificationDateFieldName, apiVersion: nil)

        SFMobileSyncNetworkUtils.sendRequest(withMobileSyncUserAgent: request, failureBlock: { _, error, _ in
            completeBlock(SFRecordModDate(timestamp: nil, isDeleted: (error as NSError?)?.code == 404))
        }, successBlock: { [weak self] response, _ in
            guard let self = self else { return }
            let responseDict = response as? [String: Any]
            completeBlock(SFRecordModDate(timestamp: responseDict?[self.modificationDateFieldName] as? String, isDeleted: false))
        })
    }
}
