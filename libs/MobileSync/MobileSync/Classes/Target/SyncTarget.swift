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

// Page size
let syncTargetPageSize: UInt = 2000

// soups and soup fields
public let syncTargetLocal = "__local__"
public let syncTargetLocallyCreated = "__locally_created__"
public let syncTargetLocallyUpdated = "__locally_updated__"
public let syncTargetLocallyDeleted = "__locally_deleted__"
public let syncTargetSyncId = "__sync_id__"
public let syncTargetLastError = "__last_error__"

@objc(SFSyncTarget)
open class SyncTarget: NSObject {

    // Internal static constant for page size
    static let pageSize = 2000

    /// The field name of the ID field of the record.  Defaults to "Id".
    @objc public var idFieldName: String

    /// The field name of the modification date field of the record.  Defaults to "LastModifiedDate".
    @objc public var modificationDateFieldName: String

    public override init() {
        self.idFieldName = kId
        self.modificationDateFieldName = kLastModifiedDate
        super.init()
    }

    /// Designated initializer that initializes a sync target from the given dictionary.
    /// - Parameter dict: The sync target serialized to a Dictionary.
    @objc required public init(dict: [String: Any]?) {
        let dict = dict ?? [:]
        let idFieldName = dict[kSFSyncTargetIdFieldNameKey] as? String
        let modificationDateFieldName = dict[kSFSyncTargetModificationDateFieldNameKey] as? String
        self.idFieldName = (idFieldName?.isEmpty == false) ? idFieldName! : kId
        self.modificationDateFieldName = (modificationDateFieldName?.isEmpty == false) ? modificationDateFieldName! : kLastModifiedDate
        super.init()
    }

    /// The target represented as a dictionary.
    /// - Returns: The target represented as a dictionary.
    @objc open func asDict() -> [String: Any] {
        var dict: [String: Any] = [:]
        dict[kSFSyncTargetiOSImplKey] = NSStringFromClass(type(of: self))
        dict[kSFSyncTargetIdFieldNameKey] = idFieldName
        dict[kSFSyncTargetModificationDateFieldNameKey] = modificationDateFieldName
        return dict
    }

    // MARK: - Public methods

    /// Save record in local store (marked as clean)
    /// - Parameters:
    ///   - syncManager: The sync manager
    ///   - soupName: The soup
    ///   - record: The record
    @objc(cleanAndSaveInLocalStore:soupName:record:)
    open func cleanAndSaveInLocalStore(syncManager: MobileSyncSyncManager, soupName: String, record: [String: Any]) {
        SFSDKMobileSyncLogger.d(type(of: self), message: "cleanAndSaveInLocalStore:\(record)")
        saveInSmartStore(syncManager.store, soupName: soupName, records: [record], idFieldName: idFieldName, syncId: nil, lastError: nil, cleanFirst: true)
    }

    /// Save records in local store (marked as clean)
    /// - Parameters:
    ///   - syncManager: The sync manager
    ///   - soupName: The soup
    ///   - records: The records to save
    ///   - syncId: The sync id
    @objc(cleanAndSaveRecordsToLocalStore:soupName:records:syncId:)
    open func cleanAndSaveRecordsToLocalStore(syncManager: MobileSyncSyncManager, soupName: String, records: [[String: Any]], syncId: NSNumber) {
        saveInSmartStore(syncManager.store, soupName: soupName, records: records, idFieldName: idFieldName, syncId: syncId, lastError: nil, cleanFirst: true)
    }

    /// Check if record was locally created
    /// - Parameter record: The record
    /// - Returns: YES if record was locally created
    @objc open func isLocallyCreated(_ record: [String: Any]) -> Bool {
        return (record[syncTargetLocallyCreated] as? NSNumber)?.boolValue ?? false
    }

    /// Check if record was locally updated
    /// - Parameter record: The record
    /// - Returns: YES if record was locally updated
    @objc open func isLocallyUpdated(_ record: [String: Any]) -> Bool {
        return (record[syncTargetLocallyUpdated] as? NSNumber)?.boolValue ?? false
    }

    /// Check if record was locally deleted
    /// - Parameter record: The record
    /// - Returns: YES if record was locally deleted
    @objc open func isLocallyDeleted(_ record: [String: Any]) -> Bool {
        return (record[syncTargetLocallyDeleted] as? NSNumber)?.boolValue ?? false
    }

    /// Check if record was locally created/updated or deleted
    /// - Parameter record: The record
    /// - Returns: YES if record was locally created/updated or deleted
    @objc open func isDirty(_ record: [String: Any]) -> Bool {
        return (record[syncTargetLocal] as? NSNumber)?.boolValue ?? false
    }

    /// Get ids of "dirty" records (records locally created/upated or deleted)
    /// - Parameters:
    ///   - syncManager: The sync manager
    ///   - soupName: The soup
    ///   - idField: The field containing the ids to return
    /// - Returns: ids of "dirty" records
    @objc open func getDirtyRecordIds(_ syncManager: MobileSyncSyncManager, soupName: String, idField: String) -> NSOrderedSet {
        let dirtyRecordSql = getDirtyRecordIdsSql(soupName, idField: idField)
        return getIdsWithQuery(dirtyRecordSql, syncManager: syncManager)
    }

    /// Get record from local store by storeId
    /// - Parameters:
    ///   - syncManager: The sync manager
    ///   - soupName: The soup
    ///   - storeId: The soup entry id
    /// - Returns: Record from local store by storeId
    @objc open func getFromLocalStore(_ syncManager: MobileSyncSyncManager, soupName: String, storeId: NSNumber) -> [String: Any] {
        return syncManager.store.retrieve(usingSoupEntryIds: [storeId], fromSoupNamed: soupName)[0] as! [String: Any]
    }

    /// Get records from local store by storeIds
    /// - Parameters:
    ///   - syncManager: The sync manager
    ///   - soupName: The soup
    ///   - storeIds: The soup entry ids
    /// - Returns: Records from local store by storeIds
    @objc open func getFromLocalStore(_ syncManager: MobileSyncSyncManager, soupName: String, storeIds: [NSNumber]) -> [[String: Any]] {
        return syncManager.store.retrieve(usingSoupEntryIds: storeIds, fromSoupNamed: soupName) as! [[String: Any]]
    }

    /// Delete record from local store
    /// - Parameters:
    ///   - syncManager: The sync manager
    ///   - soupName: The soup
    ///   - record: The record to delete
    @objc(deleteFromLocalStore:soupName:record:)
    open func deleteFromLocalStore(syncManager: MobileSyncSyncManager, soupName: String, record: [String: Any]) {
        SFSDKMobileSyncLogger.d(type(of: self), message: "deleteFromLocalStore:\(record)")
        if let entryId = record[SOUP_ENTRY_ID] as? NSNumber {
            try? syncManager.store.remove(entryIds: [entryId], forSoupNamed: soupName)
        }
    }

    /// Generate local id for record
    /// - Returns: A locally generated ID
    @objc public static func createLocalId() -> String {
        return String(format: "local_%09d", arc4random_uniform(1000000000))
    }

    /// Check if record id was locally generated
    /// - Parameter recordId: The record id
    /// - Returns: YES if recordId was locally generated
    @objc public static func isLocalId(_ recordId: String?) -> Bool {
        return recordId?.hasPrefix("local_") ?? false
    }

    // MARK: - Helper methods

    @objc func deleteRecordsFromLocalStore(_ syncManager: MobileSyncSyncManager, soupName: String, ids: [Any], idField: String) {
        if ids.count > 0 {
            let smartSql = String(format: "SELECT {%@:%@} FROM {%@} WHERE {%@:%@} IN ('%@')",
                                soupName, SOUP_ENTRY_ID, soupName, soupName, idField,
                                (ids as! [String]).joined(separator: "','"))

            if let querySpec = QuerySpec.buildSmartQuerySpec(smartSql:smartSql, pageSize: UInt(ids.count)) {
                try? syncManager.store.removeEntries(usingQuerySpec: querySpec, forSoupNamed: soupName)
            }
        }
    }

    @objc func getDirtyRecordIdsSql(_ soupName: String, idField: String) -> String {
        return String(format: "SELECT {%@:%@} FROM {%@} WHERE {%@:%@} = '1' ORDER BY {%@:%@} ASC",
                     soupName, idField, soupName, soupName, syncTargetLocal, soupName, idField)
    }

    @objc func getIdsWithQuery(_ idsSql: String, syncManager: MobileSyncSyncManager) -> NSOrderedSet {
        let ids = NSMutableOrderedSet()
        guard let querySpec = QuerySpec.buildSmartQuerySpec(smartSql:idsSql, pageSize: syncTargetPageSize) else {
            return ids
        }

        var hasMore = true
        var pageIndex: UInt = 0
        while hasMore {
            let results = try? syncManager.store.query(using: querySpec, startingFromPageIndex: pageIndex, whereArgs: nil)
            hasMore = (results?.count ?? 0) == syncTargetPageSize
            if let results = results {
                ids.addObjects(from: results)
            }
            pageIndex += 1
        }
        return ids
    }

    @objc func saveInLocalStore(_ syncManager: MobileSyncSyncManager, soupName: String, records: [[String: Any]], idFieldName: String, syncId: NSNumber?, lastError: String?, cleanFirst: Bool) {
        saveInSmartStore(syncManager.store, soupName: soupName, records: records, idFieldName: idFieldName, syncId: syncId, lastError: lastError, cleanFirst: cleanFirst)
    }

    func saveInSmartStore(_ smartStore: SmartStore, soupName: String, records: [[String: Any]], idFieldName: String, syncId: NSNumber?, lastError: String?, cleanFirst: Bool) {
        var recordsFromSmartStore: [[String: Any]] = []
        var recordsFromServer: [[String: Any]] = []

        for record in records {
            var mutableRecord = record
            if cleanFirst {
                cleanRecord(&mutableRecord)
            }
            addSyncId(&mutableRecord, syncId: syncId)
            addLastError(&mutableRecord, lastError: lastError)
            if mutableRecord[SOUP_ENTRY_ID] != nil {
                // Record came from smartstore
                recordsFromSmartStore.append(mutableRecord)
            } else {
                // Record came from server
                recordsFromServer.append(mutableRecord)
            }
        }

        // Saving in bulk
        _ = smartStore.upsert(entries: recordsFromSmartStore.map { $0 as NSDictionary }, forSoupNamed: soupName)
        _ = smartStore.upsert(entries: recordsFromServer.map { $0 as NSDictionary }, forSoupNamed: soupName, withExternalIdPath: idFieldName)
    }

    func addSyncId(_ record: inout [String: Any], syncId: NSNumber?) {
        if let syncId = syncId {
            record[syncTargetSyncId] = syncId
        }
    }

    func addLastError(_ record: inout [String: Any], lastError: String?) {
        if let lastError = lastError {
            record[syncTargetLastError] = lastError
        }
    }

    func cleanRecord(_ record: inout [String: Any]) {
        record[syncTargetLocal] = NSNumber(value: false)
        record[syncTargetLocallyCreated] = NSNumber(value: false)
        record[syncTargetLocallyUpdated] = NSNumber(value: false)
        record[syncTargetLocallyDeleted] = NSNumber(value: false)
        record[syncTargetLastError] = nil
    }

    func flatten(_ results: [[Any]]) -> [Any] {
        var flatArray: [Any] = []
        for row in results {
            flatArray.append(contentsOf: row)
        }
        return flatArray
    }
}
