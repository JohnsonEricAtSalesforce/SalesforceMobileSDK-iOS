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
import FMDB
import SalesforceSDKCommon

// Enum for alter steps
@objc(AlterSoupLongOperationStep)
public enum AlterSoupStep: UInt {
    case starting
    case renameOldSoupTable
    case dropOldIndexes
    case registerSoupUsingTableName
    case copyTable
    case reIndexSoup
    case dropOldTable
    case cleanup
}

// Fields of details for alter soup long operation row in long_operations_status table
let SOUP_NAME = "soupName"
let SOUP_TABLE_NAME = "soupTableName"
let NEW_SOUP_SPEC = "newSoupSpec"
let OLD_SOUP_SPEC = "oldSoupSpec"
let OLD_INDEX_SPECS = "oldIndexSpecs"
let NEW_INDEX_SPECS = "newIndexSpecs"
let RE_INDEX_DATA = "reIndexData"
let kLastStep = AlterSoupStep.cleanup

/// Use this class to configure and run alter soup "long" operations. Note that these operations can take a long time to complete.
@objc(AlterSoupLongOperation)
public class AlterSoupLongOperation: NSObject {

    /// Soup being altered.
    @objc public private(set) var soupName: String

    /// Backing table for soup being altered.
    @objc public private(set) var soupTableName: String

    /// Last step completed.
    @objc public private(set) var afterStep: AlterSoupStep

    /// New soup spec (optional).
    @objc public private(set) var soupSpec: [String: Any]?

    /// Old soup spec.
    @objc public private(set) var oldSoupSpec: [String: Any]?

    /// New index specs.
    @objc public private(set) var indexSpecs: [SoupIndex]

    /// Old index specs.
    @objc public private(set) var oldIndexSpecs: [SoupIndex]

    /// YES if soup elements should be brought to memory to be re-indexed.
    @objc public private(set) var reIndexData: Bool

    /// Instance of SmartStore.
    @objc public private(set) var store: SmartStore

    /// Underlying database.
    @objc public private(set) var queue: FMDatabaseQueue

    /// Row ID for long_operations_status table.
    @objc public private(set) var rowId: Int64

    /// Initializer for starting the alter soup operation.
    /// - Parameters:
    ///   - store: SmartStore instance.
    ///   - soupName: Soup name.
    ///   - newIndexSpecs: New index specs.
    ///   - reIndexData: YES to reindex.
    @objc public init(store: SmartStore, soupName: String, newIndexSpecs: [Any], reIndexData: Bool) {
        self.store = store
        self.queue = store.storeQueue
        self.soupName = soupName
        self.indexSpecs = SoupIndex.asArray(newIndexSpecs)
        self.oldIndexSpecs = store.indices(forSoupNamed: soupName)
        self.reIndexData = reIndexData
        self.afterStep = .starting
        self.soupTableName = ""
        self.rowId = 0

        super.init()

        var tableName: String = ""
        var rId: Int64 = 0

        store.storeQueue.inTransaction { db, rollback in
            tableName = store.tableName(forSoup: soupName, with: db) ?? ""
            self.soupTableName = tableName
            rId = self.createLongOperationDbRow(with: db)
        }

        self.soupTableName = tableName
        self.rowId = rId
    }

    /// Initializer for resuming an alter soup operation from the data stored in the long operations status table.
    /// - Parameters:
    ///   - store: SmartStore instance.
    ///   - rowId: Row ID.
    ///   - details: Details.
    ///   - status: Soup status.
    @objc public init(store: SmartStore, rowId: Int, details: [String: Any], status: AlterSoupStep) {
        self.store = store
        self.queue = store.storeQueue
        self.rowId = Int64(rowId)
        self.soupName = details[SOUP_NAME] as? String ?? ""
        self.soupTableName = details[SOUP_TABLE_NAME] as? String ?? ""
        self.indexSpecs = SoupIndex.asArray(details[NEW_INDEX_SPECS] as? [Any] ?? [])
        self.oldIndexSpecs = SoupIndex.asArray(details[OLD_INDEX_SPECS] as? [Any] ?? [])
        self.reIndexData = (details[RE_INDEX_DATA] as? NSNumber)?.boolValue ?? false
        self.afterStep = status
        super.init()
    }

    public override var description: String {
        let oldIndexSpecsJson = SFJsonUtils.jsonRepresentation(SoupIndex.asArrayOfDictionaries(oldIndexSpecs, withColumnName: true))
        let newIndexSpecsJson = SFJsonUtils.jsonRepresentation(SoupIndex.asArrayOfDictionaries(indexSpecs, withColumnName: true))

        return "AlterSoupOperation = {rowId=\(rowId) soupName=\(soupName) soupTableName=\(soupTableName) afterStep=\(afterStep.rawValue) reIndexData=\(reIndexData ? "YES" : "NO") oldIndexSpecs=\(oldIndexSpecsJson ?? "") newIndexSpecs=\(newIndexSpecsJson ?? "")}\n"
    }

    /// Run this operation.
    @objc public func run() {
        // Since the soup will be altered, we should get rid of cached statements etc
        store.removeFromCache(soupName)
        runToStep(kLastStep)
    }

    /// Run this operation up to a given step (used by tests).
    /// - Parameter toStep: Target step.
    @objc public func runToStep(_ toStep: AlterSoupStep) {
        // NB: if failure happens in a middle of a step before status row is updated (e.g. in steps that do ddl steps)
        //     it should be safe to re-play that step
        switch afterStep {
        case .starting:
            renameOldSoupTable()
            if toStep == .renameOldSoupTable { break }
            fallthrough
        case .renameOldSoupTable:
            dropOldIndexes()
            if toStep == .dropOldIndexes { break }
            fallthrough
        case .dropOldIndexes:
            registerSoupUsingTableName()
            if toStep == .registerSoupUsingTableName { break }
            fallthrough
        case .registerSoupUsingTableName:
            copyTable()
            if toStep == .copyTable { break }
            fallthrough
        case .copyTable:
            // Re-index soup (if requested)
            if reIndexData {
                reIndexSoup()
            }
            if toStep == .reIndexSoup { break }
            fallthrough
        case .reIndexSoup:
            dropOldTable()
            if toStep == .dropOldTable { break }
            fallthrough
        case .dropOldTable:
            cleanup()
            if toStep == .cleanup { break }
            fallthrough
        case .cleanup:
            // Nothing left to do
            break
        }
    }

    // MARK: - Step 1: rename old table
    private func renameOldSoupTable() {
        queue.inTransaction { db, rollback in
            //TODO if app crashed after alter and before status row update, the re-play would fail
            //     we should only do the alter table if the x_old table is not found
            // Rename backing table for soup
            let sql = "ALTER TABLE \(self.soupTableName) RENAME TO \(self.soupTableName)_old"
            self.executeUpdate(db, sql: sql, context: "renameOldSoupTable")

            // Renaming fts table if any
            if SoupIndex.hasFts(self.oldIndexSpecs) {
                let ftsSql = "ALTER TABLE \(self.soupTableName)_fts RENAME TO \(self.soupTableName)_fts_old"
                self.executeUpdate(db, sql: ftsSql, context: "renameOldSoupTable-fts")
            }

            // Update row in alter status table
            self.updateLongOperationDbRow(.renameOldSoupTable, with: db)
        }
    }

    // MARK: - Step 2: drop old indexes / remove entries in soup_index_map / cleanup cache
    private func dropOldIndexes() {
        queue.inTransaction { db, rollback in
            // Removing db indexes on table (otherwise registerSoup will fail to create indexes with the same name)
            var dropIndexStatements: [String] = []
            let dropIndexFormat = "DROP INDEX IF EXISTS %@_%@_idx"

            for col in [CREATED_COL, LAST_MODIFIED_COL] {
                dropIndexStatements.append(String(format: dropIndexFormat, self.soupTableName, col))
            }

            for i in 0..<self.oldIndexSpecs.count {
                dropIndexStatements.append(String(format: dropIndexFormat, self.soupTableName, "\(i)"))
            }

            for dropIndexStatement in dropIndexStatements {
                self.executeUpdate(db, sql: dropIndexStatement, context: "dropOldIndexes")
            }

            // Removing row from soup index map table
            let sql = "DELETE FROM \(SOUP_INDEX_MAP_TABLE) WHERE \(SOUP_NAME_COL)=\"\(self.soupName)\""
            self.executeUpdate(db, sql: sql, context: "dropOldIndexes")

            // Update row in alter status table
            self.updateLongOperationDbRow(.dropOldIndexes, with: db)

            // Remove soup from cache
            self.store.removeFromCache(self.soupName)
        }
    }

    // MARK: - Step 3: register soup with new indexes
    private func registerSoupUsingTableName() {
        queue.inTransaction { db, rollback in
            self.store.registerSoup(withName: self.soupName, withIndexSpecs: self.indexSpecs, withSoupTableName: self.soupTableName, with: db)

            // Update row in alter status table -auto commit
            self.updateLongOperationDbRow(.registerSoupUsingTableName, with: db)
        }
    }

    // MARK: - Step 4: copy data from old soup table to new soup table
    private func copyTable() {
        queue.inTransaction { db, rollback in
            // We need column names in the index specs
            self.indexSpecs = self.store.indices(forSoup: self.soupName, with: db)

            // Move data (core columns + indexed paths that we are still indexing)
            let mapOldSpecs = SoupIndex.map(forSoupIndexes: self.oldIndexSpecs)
            let mapNewSpecs = SoupIndex.map(forSoupIndexes: self.indexSpecs)

            // Figuring out paths we are keeping
            let oldPaths = Set(mapOldSpecs.keys)
            var keptPaths = Set(mapNewSpecs.keys)
            keptPaths.formIntersection(oldPaths)

            // Compute list of columns to copy from / list of columns to copy into
            var oldColumns = [ID_COL, CREATED_COL, LAST_MODIFIED_COL]
            var newColumns = [ID_COL, CREATED_COL, LAST_MODIFIED_COL]

            oldColumns.append(SOUP_COL)
            newColumns.append(SOUP_COL)

            // Adding indexed path columns that we are keeping
            for keptPath in keptPaths {
                guard let oldIndexSpec = mapOldSpecs[keptPath],
                      let newIndexSpec = mapNewSpecs[keptPath] else {
                    continue
                }

                if newIndexSpec.columnType == nil {
                    // we are now using json1, there is no column to populate
                    continue
                }

                if oldIndexSpec.columnType == newIndexSpec.columnType {
                    oldColumns.append(oldIndexSpec.columnName ?? "")
                    newColumns.append(newIndexSpec.columnName ?? "")
                }
            }

            // Compute copy statement
            let copySql = "INSERT INTO \(self.soupTableName) (\(newColumns.joined(separator: ","))) SELECT \(oldColumns.joined(separator: ",")) FROM \(self.soupTableName)_old"
            self.executeUpdate(db, sql: copySql, context: "copyTable")

            // Fts
            if SoupIndex.hasFts(self.indexSpecs) {
                var oldColumnsFts = [ID_COL]
                var newColumnsFts = [ROWID_COL]

                // Adding indexed path columns that we are keeping
                for keptPath in keptPaths {
                    guard let oldIndexSpec = mapOldSpecs[keptPath],
                          let newIndexSpec = mapNewSpecs[keptPath] else {
                        continue
                    }

                    if oldIndexSpec.columnType == newIndexSpec.columnType &&
                        newIndexSpec.indexType == kSoupIndexTypeFullText,
                       let oldColumnName = oldIndexSpec.columnName,
                       let newColumnName = newIndexSpec.columnName {
                        oldColumnsFts.append(oldColumnName)
                        newColumnsFts.append(newColumnName)
                    }
                }

                // Compute copy statement for fts table
                let copyFtsSql = "INSERT INTO \(self.soupTableName)_fts (\(newColumnsFts.joined(separator: ","))) SELECT \(oldColumnsFts.joined(separator: ",")) FROM \(self.soupTableName)_old"
                self.executeUpdate(db, sql: copyFtsSql, context: "copyTable-fts")
            }

            // Update row in alter status table
            self.updateLongOperationDbRow(.copyTable, with: db)
        }
    }

    // MARK: - Step 5: re-index soup for new indexes (optional step)
    private func reIndexSoup() {
        queue.inTransaction { db, rollback in
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
            _ = self.store.reIndexSoup(named: self.soupName, indexPaths: indexPaths, with: db)

            // Update row in alter status table
            self.updateLongOperationDbRow(.reIndexSoup, with: db)
        }
    }

    // MARK: - Step 6: drop old soup table
    private func dropOldTable() {
        queue.inTransaction { db, rollback in
            // Drop old table
            let sql = "DROP TABLE IF EXISTS \(self.soupTableName)_old"
            self.executeUpdate(db, sql: sql, context: "dropOldTable")

            // Dropping fts table if any
            if SoupIndex.hasFts(self.oldIndexSpecs) {
                let ftsSql = "DROP TABLE IF EXISTS \(self.soupTableName)_fts_old"
                self.executeUpdate(db, sql: ftsSql, context: "dropOldTable-fts")
            }

            // Update status row - auto commit
            self.updateLongOperationDbRow(.dropOldTable, with: db)
        }
    }

    // MARK: - Step 7: cleanup
    private func cleanup() {
        // Update status row
        queue.inTransaction { db, rollback in
            self.updateLongOperationDbRow(.cleanup, with: db)
        }
    }

    // MARK: - Helper methods

    /// Create row in long operations status table for a new alter soup operation
    /// - Parameter db: Database
    /// - Returns: row id
    private func createLongOperationDbRow(with db: FMDatabase) -> Int64 {
        let now = store.currentTimeInMilliseconds()
        var values: [String: Any] = [:]
        values[TYPE_COL] = "AlterSoup"
        values[DETAILS_COL] = SFJsonUtils.jsonRepresentation(getDetails())
        values[STATUS_COL] = NSNumber(value: AlterSoupStep.starting.rawValue)
        values[CREATED_COL] = now
        values[LAST_MODIFIED_COL] = now
        store.insertIntoTable(LONG_OPERATIONS_STATUS_TABLE, values: values, with: db)
        return db.lastInsertRowId
    }

    private func getDetails() -> [String: Any] {
        var details: [String: Any] = [:]
        details[SOUP_NAME] = soupName
        details[SOUP_TABLE_NAME] = soupTableName
        details[OLD_INDEX_SPECS] = SoupIndex.asArrayOfDictionaries(oldIndexSpecs, withColumnName: true)
        details[NEW_INDEX_SPECS] = SoupIndex.asArrayOfDictionaries(indexSpecs, withColumnName: true)
        details[RE_INDEX_DATA] = NSNumber(value: reIndexData)
        return details
    }

    /// Update row in long operations status table for on-going alter soup operation
    /// Delete row if newStatus is AlterStatus.LAST
    /// - Parameters:
    ///   - newStatus: New status
    ///   - db: Database
    private func updateLongOperationDbRow(_ newStatus: AlterSoupStep, with db: FMDatabase) {
        if newStatus == kLastStep {
            let sql = "DELETE FROM \(LONG_OPERATIONS_STATUS_TABLE) WHERE \(ID_COL) = \(rowId)"
            store.executeUpdateThrows(sql, with: db)
        } else {
            let now = store.currentTimeInMilliseconds()
            var values: [String: Any] = [:]
            values[STATUS_COL] = NSNumber(value: newStatus.rawValue)
            values[LAST_MODIFIED_COL] = now
            store.updateTable(LONG_OPERATIONS_STATUS_TABLE, values: values, entryId: NSNumber(value: rowId), idCol: ID_COL, with: db)
        }
    }

    private func executeUpdate(_ db: FMDatabase?, sql: String, context: String) {
        SmartStoreLogger.d(type(of: self), message: "\(context): \(sql)")
        store.executeUpdateThrows(sql, with: db)
    }
}
