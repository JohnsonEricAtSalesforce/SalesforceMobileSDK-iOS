/*
 Copyright (c) 2014-present, salesforce.com, inc. All rights reserved.

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
import FMDB

// MARK: - AlterSoupStep Enum

/// Enum for alter steps.
@objc(SFAlterSoupStep)
public enum AlterSoupStep: UInt {
    case starting = 0
    case renameOldSoupTable
    case dropOldIndexes
    case registerSoupUsingTableName
    case copyTable
    case reIndexSoup
    case dropOldTable
    case cleanup
}

// MARK: - Detail Keys

private let kSoupName = "soupName"
private let kSoupTableName = "soupTableName"
private let kNewSoupSpec = "newSoupSpec"
private let kOldSoupSpec = "oldSoupSpec"
private let kOldIndexSpecs = "oldIndexSpecs"
private let kNewIndexSpecs = "newIndexSpecs"
private let kReIndexData = "reIndexData"
private let kLastStep = AlterSoupStep.cleanup

// MARK: - AlterSoupLongOperation

/// Use this class to configure and run alter soup "long" operations.
/// Note that these operations can take a long time to complete.
@objc(SFAlterSoupLongOperation)
@objcMembers
public class AlterSoupLongOperation: NSObject {

    /// Soup being altered.
    public private(set) var soupName: String

    /// Backing table for soup being altered.
    public private(set) var soupTableName: String

    /// Last step completed.
    public private(set) var afterStep: AlterSoupStep

    /// New index specs.
    public private(set) var indexSpecs: [SoupIndex]

    /// Old index specs.
    public private(set) var oldIndexSpecs: [SoupIndex]

    /// YES if soup elements should be brought to memory to be re-indexed.
    public private(set) var reIndexData: Bool

    /// Instance of SmartStore.
    public private(set) var store: SmartStore

    /// Underlying database queue.
    public private(set) var queue: FMDatabaseQueue?

    /// Row ID for long_operations_status table.
    public private(set) var rowId: Int64

    // MARK: - Initialization

    /// Initializer for starting the alter soup operation.
    @objc
    public init(store: SmartStore, soupName: String, newIndexSpecs: [Any], reIndexData: Bool) {
        self.store = store
        self.queue = store.storeQueue
        self.soupName = soupName
        self.indexSpecs = SoupIndex.asArraySoupIndexes(newIndexSpecs)
        self.oldIndexSpecs = store.indices(forSoupNamed: soupName)
        self.reIndexData = reIndexData
        self.afterStep = .starting
        self.soupTableName = ""
        self.rowId = 0
        super.init()

        store.storeQueue?.inTransaction { db, rollback in
            self.soupTableName = store.tableNameForSoup(soupName, with: db) ?? ""
            do {
                self.rowId = try self.createLongOperationDbRow(with: db)
            } catch {
                rollback.pointee = true
                SmartStoreLogger.e(AlterSoupLongOperation.self, message: "createLongOperationDbRow failed: \(error)")
            }
        }
    }

    /// Initializer for resuming an alter soup operation from the data stored in the long operations status table.
    @objc
    public init(store: SmartStore, rowId: Int, details: [String: Any], status: AlterSoupStep) {
        self.store = store
        self.queue = store.storeQueue
        self.rowId = Int64(rowId)
        self.soupName = details[kSoupName] as? String ?? ""
        self.soupTableName = details[kSoupTableName] as? String ?? ""
        self.indexSpecs = SoupIndex.asArraySoupIndexes(details[kNewIndexSpecs] as? [Any] ?? [])
        self.oldIndexSpecs = SoupIndex.asArraySoupIndexes(details[kOldIndexSpecs] as? [Any] ?? [])
        self.reIndexData = (details[kReIndexData] as? NSNumber)?.boolValue ?? false
        self.afterStep = status
        super.init()
    }

    // MARK: - Description

    public override var description: String {
        return "AlterSoupOperation = {rowId=\(rowId) soupName=\(soupName) soupTableName=\(soupTableName) afterStep=\(afterStep.rawValue) reIndexData=\(reIndexData ? "YES" : "NO") oldIndexSpecs=\(SFJsonUtils.jsonRepresentation(SoupIndex.asArrayOfDictionaries(oldIndexSpecs, withColumnName: true)) ?? "[]") newIndexSpecs=\(SFJsonUtils.jsonRepresentation(SoupIndex.asArrayOfDictionaries(indexSpecs, withColumnName: true)) ?? "[]")}"
    }

    // MARK: - Run

    /// Run this operation.
    @objc
    public func run() {
        // Since the soup will be altered, we should get rid of cached statements etc
        store.removeFromCache(soupName)
        runToStep(kLastStep)
    }

    /// Run this operation up to a given step (used by tests).
    @objc
    public func runToStep(_ toStep: AlterSoupStep) {
        // NB: if failure happens in the middle of a step before status row is updated
        //     it should be safe to re-play that step
        switch afterStep {
        case .starting:
            renameOldSoupTable()
            if toStep == .renameOldSoupTable { return }
            fallthrough
        case .renameOldSoupTable:
            dropOldIndexes()
            if toStep == .dropOldIndexes { return }
            fallthrough
        case .dropOldIndexes:
            registerSoupUsingTableName()
            if toStep == .registerSoupUsingTableName { return }
            fallthrough
        case .registerSoupUsingTableName:
            copyTable()
            if toStep == .copyTable { return }
            fallthrough
        case .copyTable:
            if reIndexData {
                reIndexSoup()
            }
            if toStep == .reIndexSoup { return }
            fallthrough
        case .reIndexSoup:
            dropOldTable()
            if toStep == .dropOldTable { return }
            fallthrough
        case .dropOldTable:
            cleanup()
            if toStep == .cleanup { return }
            fallthrough
        case .cleanup:
            // Nothing left to do
            break
        }
    }

    // MARK: - Steps

    /// Step 1: rename old table
    private func renameOldSoupTable() {
        queue?.inTransaction { db, rollback in
            do {
                let sql = "ALTER TABLE \(self.soupTableName) RENAME TO \(self.soupTableName)_old"
                try self.executeUpdate(db: db, sql: sql, context: "renameOldSoupTable")

                // Renaming fts table if any
                if SoupIndex.hasFts(self.oldIndexSpecs) {
                    let ftsSql = "ALTER TABLE \(self.soupTableName)_fts RENAME TO \(self.soupTableName)_fts_old"
                    try self.executeUpdate(db: db, sql: ftsSql, context: "renameOldSoupTable-fts")
                }

                // Update row in alter status table
                try self.updateLongOperationDbRow(.renameOldSoupTable, with: db)
            } catch {
                rollback.pointee = true
                SmartStoreLogger.e(AlterSoupLongOperation.self, message: "renameOldSoupTable failed: \(error)")
            }
        }
    }

    /// Step 2: drop old indexes / remove entries in soup_index_map / cleanup cache
    private func dropOldIndexes() {
        queue?.inTransaction { db, rollback in
            do {
                // Removing db indexes on table
                var dropIndexStatements: [String] = []
                let dropIndexFormat = "DROP INDEX IF EXISTS %@_%@_idx"
                for col in [SmartStoreCreatedColumn, SmartStoreLastModifiedColumn] {
                    dropIndexStatements.append(String(format: dropIndexFormat, self.soupTableName, col))
                }
                for i in 0..<self.oldIndexSpecs.count {
                    dropIndexStatements.append(String(format: dropIndexFormat, self.soupTableName, "\(i)"))
                }
                for dropIndexStatement in dropIndexStatements {
                    try self.executeUpdate(db: db, sql: dropIndexStatement, context: "dropOldIndexes")
                }

                // Removing row from soup index map table
                let sql = "DELETE FROM \(SOUP_INDEX_MAP_TABLE) WHERE \(SOUP_NAME_COL)=\"\(self.soupName)\""
                try self.executeUpdate(db: db, sql: sql, context: "dropOldIndexes")

                // Update row in alter status table
                try self.updateLongOperationDbRow(.dropOldIndexes, with: db)

                // Remove soup from cache
                self.store.removeFromCache(self.soupName)
            } catch {
                rollback.pointee = true
                SmartStoreLogger.e(AlterSoupLongOperation.self, message: "dropOldIndexes failed: \(error)")
            }
        }
    }

    /// Step 3: register soup with new indexes
    private func registerSoupUsingTableName() {
        queue?.inTransaction { db, rollback in
            do {
                try self.store.registerSoup(withName: self.soupName, indexSpecs: self.indexSpecs, soupTableName: self.soupTableName, with: db)
                // Update row in alter status table
                try self.updateLongOperationDbRow(.registerSoupUsingTableName, with: db)
            } catch {
                rollback.pointee = true
                SmartStoreLogger.e(AlterSoupLongOperation.self, message: "registerSoupUsingTableName failed: \(error)")
            }
        }
    }

    /// Step 4: copy data from old soup table to new soup table
    private func copyTable() {
        queue?.inTransaction { db, rollback in
            do {
                // We need column names in the index specs
                self.indexSpecs = try self.store.indices(forSoup: self.soupName, with: db)

                // Move data (core columns + indexed paths that we are still indexing)
                let mapOldSpecs = SoupIndex.map(forSoupIndexes: self.oldIndexSpecs)
                let mapNewSpecs = SoupIndex.map(forSoupIndexes: self.indexSpecs)

                // Figuring out paths we are keeping
                let oldPaths = Set(mapOldSpecs.keys)
                var keptPaths = Set(mapNewSpecs.keys)
                keptPaths = keptPaths.intersection(oldPaths)

                // Compute list of columns to copy from / list of columns to copy into
                var oldColumns = [SmartStoreIdColumn, SmartStoreCreatedColumn, SmartStoreLastModifiedColumn, SmartStoreSoupColumn]
                var newColumns = [SmartStoreIdColumn, SmartStoreCreatedColumn, SmartStoreLastModifiedColumn, SmartStoreSoupColumn]

                // Adding indexed path columns that we are keeping
                for keptPath in keptPaths {
                    guard let oldIndexSpec = mapOldSpecs[keptPath],
                          let newIndexSpec = mapNewSpecs[keptPath] else { continue }

                    if newIndexSpec.columnType == nil {
                        // we are now using json1, there is no column to populate
                        continue
                    }

                    if oldIndexSpec.columnType == newIndexSpec.columnType {
                        oldColumns.append(oldIndexSpec.columnName)
                        newColumns.append(newIndexSpec.columnName)
                    }
                }

                // Compute copy statement
                let copySql = "INSERT INTO \(self.soupTableName) (\(newColumns.joined(separator: ","))) SELECT \(oldColumns.joined(separator: ",")) FROM \(self.soupTableName)_old"
                try self.executeUpdate(db: db, sql: copySql, context: "copyTable")

                // Fts
                if SoupIndex.hasFts(self.indexSpecs) {
                    var oldColumnsFts = [SmartStoreIdColumn]
                    var newColumnsFts = [ROWID_COL]

                    for keptPath in keptPaths {
                        guard let oldIndexSpec = mapOldSpecs[keptPath],
                              let newIndexSpec = mapNewSpecs[keptPath] else { continue }
                        if oldIndexSpec.columnType == newIndexSpec.columnType
                            && newIndexSpec.indexType == kSoupIndexTypeFullText {
                            oldColumnsFts.append(oldIndexSpec.columnName)
                            newColumnsFts.append(newIndexSpec.columnName)
                        }
                    }

                    let copyFtsSql = "INSERT INTO \(self.soupTableName)_fts (\(newColumnsFts.joined(separator: ","))) SELECT \(oldColumnsFts.joined(separator: ",")) FROM \(self.soupTableName)_old"
                    try self.executeUpdate(db: db, sql: copyFtsSql, context: "copyTable-fts")
                }

                // Update row in alter status table
                try self.updateLongOperationDbRow(.copyTable, with: db)
            } catch {
                rollback.pointee = true
                SmartStoreLogger.e(AlterSoupLongOperation.self, message: "copyTable failed: \(error)")
            }
        }
    }

    /// Step 5: re-index soup for new indexes (optional step)
    private func reIndexSoup() {
        queue?.inTransaction { db, rollback in
            do {
                var oldPathTypeSet = Set<String>()
                // Putting path--type of old index specs in a set
                for oldIndexSpec in self.oldIndexSpecs {
                    oldPathTypeSet.insert(oldIndexSpec.getPathType())
                }

                // Filtering out the ones that do not have their path--type in oldPathTypeSet
                var indexPaths: [String] = []
                for indexSpec in self.indexSpecs {
                    if !oldPathTypeSet.contains(indexSpec.getPathType()) {
                        indexPaths.append(indexSpec.path)
                    }
                }

                // Re-index soup
                try self.store.reIndexSoup(self.soupName, withIndexPaths: indexPaths, with: db)

                // Update row in alter status table
                try self.updateLongOperationDbRow(.reIndexSoup, with: db)
            } catch {
                rollback.pointee = true
                SmartStoreLogger.e(AlterSoupLongOperation.self, message: "reIndexSoup failed: \(error)")
            }
        }
    }

    /// Step 6: drop old soup table
    private func dropOldTable() {
        queue?.inTransaction { db, rollback in
            do {
                let sql = "DROP TABLE IF EXISTS \(self.soupTableName)_old"
                try self.executeUpdate(db: db, sql: sql, context: "dropOldTable")

                // Dropping fts table if any
                if SoupIndex.hasFts(self.oldIndexSpecs) {
                    let ftsSql = "DROP TABLE IF EXISTS \(self.soupTableName)_fts_old"
                    try self.executeUpdate(db: db, sql: ftsSql, context: "dropOldTable-fts")
                }

                // Update status row
                try self.updateLongOperationDbRow(.dropOldTable, with: db)
            } catch {
                rollback.pointee = true
                SmartStoreLogger.e(AlterSoupLongOperation.self, message: "dropOldTable failed: \(error)")
            }
        }
    }

    /// Step 7: cleanup
    private func cleanup() {
        queue?.inTransaction { db, rollback in
            do {
                try self.updateLongOperationDbRow(.cleanup, with: db)
            } catch {
                rollback.pointee = true
                SmartStoreLogger.e(AlterSoupLongOperation.self, message: "cleanup failed: \(error)")
            }
        }
    }

    // MARK: - DB Row Management

    /// Create row in long operations status table for a new alter soup operation.
    private func createLongOperationDbRow(with db: FMDatabase) throws -> Int64 {
        let now = store.currentTimeInMilliseconds()
        var values: [String: Any] = [:]
        values[TYPE_COL] = "AlterSoup"
        values[DETAILS_COL] = SFJsonUtils.jsonRepresentation(getDetails())
        values[STATUS_COL] = NSNumber(value: AlterSoupStep.starting.rawValue)
        values[SmartStoreCreatedColumn] = now
        values[SmartStoreLastModifiedColumn] = now
        try store.insertIntoTable(LONG_OPERATIONS_STATUS_TABLE, values: values, with: db)
        return db.lastInsertRowId
    }

    private func getDetails() -> [String: Any] {
        var details: [String: Any] = [:]
        details[kSoupName] = soupName
        details[kSoupTableName] = soupTableName
        details[kOldIndexSpecs] = SoupIndex.asArrayOfDictionaries(oldIndexSpecs, withColumnName: true)
        details[kNewIndexSpecs] = SoupIndex.asArrayOfDictionaries(indexSpecs, withColumnName: true)
        details[kReIndexData] = NSNumber(value: reIndexData)
        return details
    }

    /// Update row in long operations status table for on-going alter soup operation.
    /// Deletes row if newStatus is the last step.
    private func updateLongOperationDbRow(_ newStatus: AlterSoupStep, with db: FMDatabase) throws {
        if newStatus == kLastStep {
            let sql = "DELETE FROM \(LONG_OPERATIONS_STATUS_TABLE) WHERE \(SmartStoreIdColumn) = \(rowId)"
            try store.executeUpdateThrows(sql, with: db)
        } else {
            let now = store.currentTimeInMilliseconds()
            var values: [String: Any] = [:]
            values[STATUS_COL] = NSNumber(value: newStatus.rawValue)
            values[SmartStoreLastModifiedColumn] = now
            try store.updateTable(LONG_OPERATIONS_STATUS_TABLE, values: values, entryId: NSNumber(value: rowId), idCol: SmartStoreIdColumn, with: db)
        }
    }

    private func executeUpdate(db: FMDatabase, sql: String, context: String) throws {
        SmartStoreLogger.d(AlterSoupLongOperation.self, message: "\(context): \(sql)")
        try store.executeUpdateThrows(sql, with: db)
    }
}
