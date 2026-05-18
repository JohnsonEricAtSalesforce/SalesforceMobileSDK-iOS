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
public let kSyncTargetPageSize: UInt = 2000

// Soups and soup fields
public let kSyncTargetLocal = "__local__"
public let kSyncTargetLocallyCreated = "__locally_created__"
public let kSyncTargetLocallyUpdated = "__locally_updated__"
public let kSyncTargetLocallyDeleted = "__locally_deleted__"
public let kSyncTargetSyncId = "__sync_id__"
public let kSyncTargetLastError = "__last_error__"

@objc(SFSyncTarget)
@objcMembers
open class SFSyncTarget: NSObject {

    open var idFieldName: String = kId
    open var modificationDateFieldName: String = kLastModifiedDate

    // MARK: - Initialization

    public override init() {
        super.init()
        self.idFieldName = kId
        self.modificationDateFieldName = kLastModifiedDate
    }

    @objc
    public required init(dict: NSDictionary) {
        super.init()
        let dictionary = dict as? [String: Any] ?? [:]
        let idField = dictionary[kSFSyncTargetIdFieldNameKey] as? String
        let modField = dictionary[kSFSyncTargetModificationDateFieldNameKey] as? String
        self.idFieldName = (idField?.isEmpty == false) ? idField ?? kId : kId
        self.modificationDateFieldName = (modField?.isEmpty == false) ? modField ?? kLastModifiedDate : kLastModifiedDate
    }

    // MARK: - Serialization

    @objc
    open func asDict() -> NSMutableDictionary {
        let dict = NSMutableDictionary()
        dict[kSFSyncTargetiOSImplKey] = NSStringFromClass(type(of: self))
        dict[kSFSyncTargetIdFieldNameKey] = self.idFieldName
        dict[kSFSyncTargetModificationDateFieldNameKey] = self.modificationDateFieldName
        return dict
    }

    // MARK: - Public methods

    @objc(cleanAndSaveInLocalStore:soupName:record:)
    open func cleanAndSaveInLocalStore(syncManager: SFMobileSyncSyncManager, soupName: String, record: NSDictionary) {
        SFSDKMobileSyncLogger.d(type(of: self), message: "cleanAndSaveInLocalStore:\(record)")
        saveInSmartStore(syncManager.store, soupName: soupName, records: [record], idFieldName: self.idFieldName, syncId: nil, lastError: nil, cleanFirst: true)
    }

    @objc(cleanAndSaveRecordsToLocalStore:soupName:records:syncId:)
    open func cleanAndSaveRecordsToLocalStore(syncManager: SFMobileSyncSyncManager, soupName: String, records: [Any], syncId: NSNumber) {
        saveInSmartStore(syncManager.store, soupName: soupName, records: records, idFieldName: self.idFieldName, syncId: syncId, lastError: nil, cleanFirst: true)
    }

    @objc
    open func isLocallyCreated(_ record: NSDictionary) -> Bool {
        return (record[kSyncTargetLocallyCreated] as? NSNumber)?.boolValue ?? false
    }

    @objc
    open func isLocallyUpdated(_ record: NSDictionary) -> Bool {
        return (record[kSyncTargetLocallyUpdated] as? NSNumber)?.boolValue ?? false
    }

    @objc
    open func isLocallyDeleted(_ record: NSDictionary) -> Bool {
        return (record[kSyncTargetLocallyDeleted] as? NSNumber)?.boolValue ?? false
    }

    @objc
    open func isDirty(_ record: NSDictionary) -> Bool {
        return (record[kSyncTargetLocal] as? NSNumber)?.boolValue ?? false
    }

    @objc
    open func getDirtyRecordIds(_ syncManager: SFMobileSyncSyncManager, soupName: String, idField: String) -> NSOrderedSet {
        let dirtyRecordSql = getDirtyRecordIdsSql(soupName, idField: idField)
        return getIdsWithQuery(dirtyRecordSql, syncManager: syncManager)
    }

    @objc
    open func getFromLocalStore(_ syncManager: SFMobileSyncSyncManager, soupName: String, storeId: NSNumber) -> NSDictionary {
        let entries = syncManager.store.retrieve(usingSoupEntryIds: [storeId], fromSoupNamed: soupName)
        return entries[0] as NSDictionary
    }

    @objc
    open func getFromLocalStore(_ syncManager: SFMobileSyncSyncManager, soupName: String, storeIds: [NSNumber]) -> [NSDictionary] {
        let entries = syncManager.store.retrieve(usingSoupEntryIds: storeIds, fromSoupNamed: soupName)
        return entries.map { $0 as NSDictionary }
    }

    @objc(deleteFromLocalStore:soupName:record:)
    open func deleteFromLocalStore(syncManager: SFMobileSyncSyncManager, soupName: String, record: NSDictionary) {
        SFSDKMobileSyncLogger.d(type(of: self), message: "deleteFromLocalStore:\(record)")
        if let entryId = record[SmartStoreSoupEntryId] {
            syncManager.store.removeEntries([entryId], fromSoup: soupName)
        }
    }

    // MARK: - Class methods

    @objc
    open class func createLocalId() -> String {
        return String(format: "local_%09d", arc4random_uniform(1000000000))
    }

    @objc
    open class func isLocalId(_ recordId: String) -> Bool {
        return recordId.hasPrefix("local_")
    }

    // MARK: - Internal helper methods

    @objc
    open func getDirtyRecordIdsSql(_ soupName: String, idField: String) -> String {
        return "SELECT {\(soupName):\(idField)} FROM {\(soupName)} WHERE {\(soupName):\(kSyncTargetLocal)} = '1' ORDER BY {\(soupName):\(idField)} ASC"
    }

    @objc
    open func getIdsWithQuery(_ idsSql: String, syncManager: SFMobileSyncSyncManager) -> NSOrderedSet {
        let ids = NSMutableOrderedSet()
        guard let querySpec = QuerySpec.buildSmartQuerySpec(smartSql: idsSql, pageSize: kSyncTargetPageSize) else { return ids }
        var hasMore = true
        var pageIndex: UInt = 0
        while hasMore {
            let results = (try? syncManager.store.query(using: querySpec, startingFromPageIndex: pageIndex)) ?? []
            hasMore = (UInt(results.count) == kSyncTargetPageSize)
            ids.addObjects(from: flatten(results))
            pageIndex += 1
        }
        return ids
    }

    @objc
    open func deleteRecordsFromLocalStore(_ syncManager: SFMobileSyncSyncManager, soupName: String, ids: [Any], idField: String) {
        if ids.count > 0 {
            let idsAsStrings = ids.map { "\($0)" }
            let smartSql = "SELECT {\(soupName):\(SmartStoreSoupEntryId)} FROM {\(soupName)} WHERE {\(soupName):\(idField)} IN ('\(idsAsStrings.joined(separator: "','"))')"
            if let querySpec = QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: UInt(ids.count)) {
                try? syncManager.store.removeEntries(usingQuerySpec: querySpec, forSoupNamed: soupName)
            }
        }
    }

    @objc
    open func saveInLocalStore(_ syncManager: SFMobileSyncSyncManager, soupName: String, records: [Any], idFieldName: String, syncId: NSNumber?, lastError: String?, cleanFirst: Bool) {
        saveInSmartStore(syncManager.store, soupName: soupName, records: records, idFieldName: idFieldName, syncId: syncId, lastError: lastError, cleanFirst: cleanFirst)
    }

    @objc
    open func saveInSmartStore(_ smartStore: SFSmartStore, soupName: String, records: [Any], idFieldName: String, syncId: NSNumber?, lastError: String?, cleanFirst: Bool) {
        var recordsFromSmartStore = [[String: Any]]()
        var recordsFromServer = [[String: Any]]()

        for record in records {
            guard let recordDict = record as? [String: Any] else { continue }
            var mutableRecord = recordDict
            if cleanFirst {
                cleanRecord(&mutableRecord)
            }
            addSyncId(&mutableRecord, syncId: syncId)
            addLastError(&mutableRecord, lastError: lastError)
            if mutableRecord[SmartStoreSoupEntryId] != nil {
                recordsFromSmartStore.append(mutableRecord)
            } else {
                recordsFromServer.append(mutableRecord)
            }
        }

        // Saving in bulk
        _ = smartStore.upsert(entries: recordsFromSmartStore, forSoupNamed: soupName)
        _ = try? smartStore.upsert(entries: recordsFromServer as [Any], forSoupNamed: soupName, withExternalIdPath: idFieldName)
    }

    // MARK: - Private helpers

    private func addSyncId(_ record: inout [String: Any], syncId: NSNumber?) {
        if let syncId = syncId {
            record[kSyncTargetSyncId] = syncId
        }
    }

    private func addLastError(_ record: inout [String: Any], lastError: String?) {
        if let lastError = lastError {
            record[kSyncTargetLastError] = lastError
        }
    }

    private func cleanRecord(_ record: inout [String: Any]) {
        record[kSyncTargetLocal] = NSNumber(value: false)
        record[kSyncTargetLocallyCreated] = NSNumber(value: false)
        record[kSyncTargetLocallyUpdated] = NSNumber(value: false)
        record[kSyncTargetLocallyDeleted] = NSNumber(value: false)
        record[kSyncTargetLastError] = nil
    }

    private func flatten(_ results: [Any]) -> [Any] {
        var flatArray = [Any]()
        for row in results {
            if let rowArray = row as? [Any] {
                flatArray.append(contentsOf: rowArray)
            }
        }
        return flatArray
    }
}
