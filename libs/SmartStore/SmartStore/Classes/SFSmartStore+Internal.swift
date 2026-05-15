/*
 Copyright (c) 2012-present, salesforce.com, inc. All rights reserved.

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
import SalesforceSDKCore
import SalesforceSDKCommon

@objc public enum SmartStoreFtsExtension: UInt {
    case fts4 = 4
    case fts5 = 5
}

// Buffer size when reading/writing bytes in memory
let kBufferSize = 4096

// Columns of a soup fts table
let ROWID_COL = "rowid"
let PATH_COL = "path"

// Columns of the soup index map table
let SOUP_NAME_COL = "soupName"
let COLUMN_TYPE_COL = "columnType"

// Table to keep track of soup attributes
let SOUP_ATTRS_TABLE = "soup_attrs"

// Table to keep track of soup's index specs
let SOUP_INDEX_MAP_TABLE = "soup_index_map"

// Columns of long operations status table
let TYPE_COL = "type"
let DETAILS_COL = "details"
let STATUS_COL = "status"

// Table to keep track of status of long operations in flight
let LONG_OPERATIONS_STATUS_TABLE = "long_operations_status"

// Explain support
let EXPLAIN_ROWS = "rows"

extension SmartStore {

    @objc public var storeQueue: FMDatabaseQueue {
        get { return _storeQueue }
        set { _storeQueue = newValue }
    }

    @objc public var dbMgr: DatabaseManager {
        get { return _dbMgr }
        set { _dbMgr = newValue }
    }

    @objc public var isGlobal: Bool {
        get { return _isGlobal }
        set { _isGlobal = newValue }
    }

    @objc public var ftsExtension: SmartStoreFtsExtension {
        get { return _ftsExtension }
        set { _ftsExtension = newValue }
    }

    /// Simply open the db file.
    /// - Returns: YES if we were able to open the DB file.
    @objc public func openStoreDatabase() -> Bool {
        var openDbError: NSError?
        let salt = type(of: self).encryptionSaltBlock?() ?? nil
        self._storeQueue = dbMgr.openStoreQueue(withName: name, key: type(of: self).encKey(), salt: salt, error: &openDbError)
        if _storeQueue == nil {
            SmartStoreLogger.e(type(of: self), message: "Error opening store '\(name)': \(openDbError?.localizedDescription ?? "")")
        }
        return _storeQueue != nil
    }

    /// Create soup index map table and soup attributes table
    /// - Returns: YES if we were able to create the meta tables, NO otherwise.
    @objc public func createMetaTables() -> Bool {
        var error: NSError?
        inDatabase({ db in
            self.createMetaTables(with: db)
        })
        return error == nil
    }

    @objc public func createMetaTables(with db: FMDatabase?) {
        // Create SOUP_INDEX_MAP_TABLE
        let createSoupIndexTableSql = """
            CREATE TABLE IF NOT EXISTS \(SOUP_INDEX_MAP_TABLE) (\(SOUP_NAME_COL) TEXT, \(PATH_COL) TEXT, \(COLUMN_NAME_COL) TEXT, \(COLUMN_TYPE_COL) TEXT )
            """
        SmartStoreLogger.d(type(of: self), message: "createSoupIndexTableSql: \(createSoupIndexTableSql)")

        // Create SOUP_ATTRS_TABLE
        let createSoupNamesTableSql = """
            CREATE TABLE IF NOT EXISTS \(SOUP_ATTRS_TABLE) (\(ID_COL) INTEGER PRIMARY KEY AUTOINCREMENT, \(SOUP_NAME_COL) TEXT )
            """
        SmartStoreLogger.d(type(of: self), message: "createSoupNamesTableSql: \(createSoupNamesTableSql)")

        // Create an index for SOUP_NAME_COL in SOUP_ATTRS_TABLE
        let createSoupNamesIndexSql = "CREATE INDEX \(SOUP_ATTRS_TABLE)_0 on \(SOUP_ATTRS_TABLE) ( \(SOUP_NAME_COL) )"
        SmartStoreLogger.d(type(of: self), message: "createSoupNamesIndexSql: \(createSoupNamesIndexSql)")

        executeUpdateThrows(createSoupIndexTableSql, with: db)
        executeUpdateThrows(createSoupNamesTableSql, with: db)
        createLongOperationsStatusTable(with: db)
        executeUpdateThrows(createSoupNamesIndexSql, with: db)
    }

    /// Create long operations status table
    /// - Returns: YES if we were able to create the table, NO otherwise.
    @objc public func createLongOperationsStatusTable() -> Bool {
        var error: NSError?
        inDatabase({ db in
            self.createLongOperationsStatusTable(with: db)
        })
        return error == nil
    }

    @objc public func createLongOperationsStatusTable(with db: FMDatabase?) {
        let createLongOperationsStatusTableSql = """
            CREATE TABLE IF NOT EXISTS \(LONG_OPERATIONS_STATUS_TABLE) (\(ID_COL) INTEGER PRIMARY KEY AUTOINCREMENT, \(TYPE_COL) TEXT, \(DETAILS_COL) TEXT, \(STATUS_COL) TEXT, \(CREATED_COL) INTEGER, \(LAST_MODIFIED_COL) INTEGER )
            """
        SmartStoreLogger.d(type(of: self), message: "createLongOperationsStatusTableSql: \(createLongOperationsStatusTableSql)")
        executeUpdateThrows(createLongOperationsStatusTableSql, with: db)
    }

    /// Register the soup
    /// - Parameters:
    ///   - soupName: The name of the soup to register
    ///   - indexSpecs: Array of one ore more IndexSpec objects
    ///   - soupTableName: The name of the table to use for the soup
    ///   - db: This method is expected to be called from [fmdbqueue inDatabase]
    @objc public func registerSoup(withName soupName: String, withIndexSpecs indexSpecs: [SoupIndex], withSoupTableName soupTableName: String?, with db: FMDatabase?) {
        guard !soupName.isEmpty else {
            let exception = NSException(name: NSExceptionName("Bogus soupName"), reason: soupName, userInfo: nil)
            exception.raise()
            return
        }

        guard !indexSpecs.isEmpty else {
            let exception = NSException(name: NSExceptionName("Bogus indexSpecs"), reason: nil, userInfo: nil)
            exception.raise()
            return
        }

        if soupExists(soupName, with: db) {
            return
        }

        let soupUsesJSON1 = SoupIndex.hasJSON1(indexSpecs)

        var tableName = soupTableName
        if tableName == nil {
            tableName = registerNewSoup(withName: soupName, with: db)
        }

        guard let soupTableName = tableName else { return }

        var soupIndexMapInserts: [[String: Any]] = []
        var createIndexStmts: [String] = []
        var createTableStmt = "CREATE TABLE IF NOT EXISTS \(soupTableName) ("
        createTableStmt += "\(ID_COL) INTEGER PRIMARY KEY AUTOINCREMENT"
        createTableStmt += ", \(SOUP_COL) TEXT"
        createTableStmt += ", \(CREATED_COL) INTEGER"
        createTableStmt += ", \(LAST_MODIFIED_COL) INTEGER"

        var createFtsStmt = ""
        var columnsForFts: [String] = []

        let createIndexFormat = "CREATE INDEX IF NOT EXISTS %@_%@_idx ON %@ ( %@ )"
        for col in [CREATED_COL, LAST_MODIFIED_COL] {
            createIndexStmts.append(String(format: createIndexFormat, soupTableName, col, soupTableName, col))
        }

        for i in 0..<indexSpecs.count {
            let indexSpec = indexSpecs[i]

            var columnName = "\(soupTableName)_\(i)"
            if kValueIndexedWithJSONExtract(indexSpec) {
                columnName = "json_extract(soup, '$.\(indexSpec.path)')"
            }
            if kValueExtractedToColumn(indexSpec) {
                if let columnType = indexSpec.columnType {
                    createTableStmt += ", \(columnName) \(columnType) "
                }
            }

            if indexSpec.indexType == kSoupIndexTypeFullText {
                columnsForFts.append(columnName)
            }

            var values: [String: Any] = [:]
            values[SOUP_NAME_COL] = soupName
            values[PATH_COL] = indexSpec.path
            values[COLUMN_NAME_COL] = columnName
            values[COLUMN_TYPE_COL] = indexSpec.indexType
            soupIndexMapInserts.append(values)

            createIndexStmts.append(String(format: createIndexFormat, soupTableName, String(i), soupTableName, columnName))
        }

        createTableStmt += ")"
        SmartStoreLogger.d(type(of: self), message: "createTableStmt: \(createTableStmt)")

        if !columnsForFts.isEmpty {
            createFtsStmt = "CREATE VIRTUAL TABLE \(soupTableName)_fts USING fts\(ftsExtension.rawValue)(\(columnsForFts.joined(separator: ",")))"
            SmartStoreLogger.d(type(of: self), message: "createFtsStmt: \(createFtsStmt)")
        }

        executeUpdateThrows(createTableStmt, with: db)

        if !columnsForFts.isEmpty {
            executeUpdateThrows(createFtsStmt, with: db)
        }

        for createIndexStmt in createIndexStmts {
            SmartStoreLogger.d(type(of: self), message: "createIndexStmt: \(createIndexStmt)")
            executeUpdateThrows(createIndexStmt, with: db)
        }
        insertIntoSoupIndexMap(soupIndexMapInserts, with: db)

        var features: [String] = []
        if soupUsesJSON1 {
            features.append("JSON1")
        }
        if SoupIndex.hasFts(indexSpecs) {
            features.append("FTS")
        }
        let attributes: [String: Any] = ["features": features]
        SFSDKEventBuilderHelper.createAndStoreEvent("registerSoup", userAccount: userAccount, className: NSStringFromClass(type(of: self)), attributes: attributes)
    }

    func registerNewSoup(withName soupName: String, with db: FMDatabase?) -> String? {
        let soupMapValues: [String: Any] = [SOUP_NAME_COL: soupName]
        insertIntoTable(SOUP_ATTRS_TABLE, values: soupMapValues, with: db)
        let soupTableName = tableName(bySoupId: db?.lastInsertRowId ?? 0)
        if soupTableName.isEmpty {
            SmartStoreLogger.d(type(of: self), message: "couldn't properly register soupName: '\(soupName)' ")
            return nil
        }
        return soupTableName
    }

    func insertIntoSoupIndexMap(_ soupIndexMapInserts: [[String: Any]], with db: FMDatabase?) {
        for map in soupIndexMapInserts {
            insertIntoTable(SOUP_INDEX_MAP_TABLE, values: map, with: db)
        }
    }

    /// Get the soup table name from SOUP_ATTRS_TABLE
    /// - Parameters:
    ///   - soupName: Soup name
    ///   - db: This method is expected to be called from [fmdbqueue inDatabase]
    /// - Returns: The soup table name
    @objc public func tableName(forSoup soupName: String, with db: FMDatabase?) -> String? {
        if let soupTableName = _soupNameToTableName.object(forKey: soupName as NSString) as String? {
            return soupTableName
        }

        let sql = "SELECT \(ID_COL) FROM \(SOUP_ATTRS_TABLE) WHERE \(SOUP_NAME_COL) = ?"
        let frs = executeQueryThrows(sql, withArgumentsInArray: [soupName], with: db)
        var soupTableName: String?

        if frs?.next() == true {
            let colIdx = frs?.columnIndex(forName: ID_COL) ?? 0
            let soupId = frs?.long(forColumnIndex: Int32(colIdx)) ?? 0
            soupTableName = tableName(bySoupId: Int64(soupId))

            if let soupTableName = soupTableName {
                _soupNameToTableName.setObject(soupTableName as NSString, forKey: soupName as NSString)
            }
        } else {
            SmartStoreLogger.d(type(of: self), message: "No table for: '\(soupName)'")
        }
        frs?.close()

        return soupTableName
    }

    /// Get soup indices
    /// - Parameters:
    ///   - soupName: the name of the soup
    ///   - db: This method is expected to be called from [fmdbqueue inDatabase]
    /// - Returns: NSArray of SFSoupIndex for the given soup
    @objc public func indices(forSoup soupName: String, with db: FMDatabase?) -> [SoupIndex] {
        if let result = _indexSpecsBySoup.object(forKey: soupName as NSString) as? [SoupIndex] {
            return result
        }

        var result: [SoupIndex] = []

        let querySql = "SELECT \(PATH_COL),\(COLUMN_NAME_COL),\(COLUMN_TYPE_COL) FROM \(SOUP_INDEX_MAP_TABLE) WHERE \(SOUP_NAME_COL) = ?"
        SmartStoreLogger.d(type(of: self), message: "indices sql: \(querySql)")
        let frs = executeQueryThrows(querySql, withArgumentsInArray: [soupName], with: db)

        while frs?.next() == true {
            if let path = frs?.string(forColumn: PATH_COL),
               let columnName = frs?.string(forColumn: COLUMN_NAME_COL),
               let type = frs?.string(forColumn: COLUMN_TYPE_COL),
               let spec = SoupIndex(path: path, indexType: type, columnName: columnName) {
                result.append(spec)
            }
        }
        frs?.close()

        _indexSpecsBySoup.setObject(result as NSArray, forKey: soupName as NSString)

        if result.isEmpty {
            SmartStoreLogger.d(type(of: self), message: "no indices for '\(soupName)'")
        }
        return result
    }

    /// Helper method re-index a soup.
    /// - Parameters:
    ///   - soupName: The soup to re-index
    ///   - indexPaths: Array of one ore more path strings
    ///   - db: This method is expected to be called from [fmdbqueue inDatabase]
    /// - Returns: YES if the insert was successful, NO otherwise.
    @objc public func reIndexSoup(named soupName: String, indexPaths: [String], with db: FMDatabase?) -> Bool {
        // This is handled by the main class - just forward to it
        return self.reIndexSoup(soupName, withIndexPaths: indexPaths, with: db)
    }

    /// Helper method to insert values into an arbitrary table.
    /// - Parameters:
    ///   - tableName: The table to insert the data into.
    ///   - map: A dictionary of key-value pairs to be inserted into table.
    ///   - db: This method is expected to be called from [fmdbqueue inDatabase]
    @objc public func insertIntoTable(_ tableName: String, values map: [String: Any], with db: FMDatabase?) {
        var fieldNames = ""
        var binds: [Any] = []
        var fieldValueMarkers = ""
        var fieldCount = 0

        for (key, obj) in map {
            if fieldCount > 0 {
                fieldNames += ",\(key)"
                fieldValueMarkers += ",?"
            } else {
                fieldNames += key
                fieldValueMarkers += "?"
            }
            binds.append(obj)
            fieldCount += 1
        }

        let insertSql = "INSERT INTO \(tableName) (\(fieldNames)) VALUES (\(fieldValueMarkers))"
        executeUpdateThrows(insertSql, withArgumentsInArray: binds, with: db)
    }

    /// Helper method to update existing values in a table.
    /// - Parameters:
    ///   - tableName: The name of the table to update.
    ///   - map: The column name/value mapping to update.
    ///   - entryId: The ID value used to determine what to update.
    ///   - idCol: The name of the ID column
    ///   - db: This method is expected to be called from [fmdbqueue inDatabase]
    @objc public func updateTable(_ tableName: String, values map: [String: Any], entryId: NSNumber, idCol: String, with db: FMDatabase?) {
        var fieldEntries = ""
        var binds: [Any] = []
        var fieldCount = 0

        for (key, obj) in map {
            if fieldCount > 0 {
                fieldEntries += ", "
            }
            fieldEntries += "\(key) = ?"
            binds.append(obj)
            fieldCount += 1
        }
        binds.append(entryId)

        let updateSql = "UPDATE \(tableName) SET \(fieldEntries) WHERE \(idCol) = ?"
        executeUpdateThrows(updateSql, withArgumentsInArray: binds, with: db)
    }

    /// Helper to query table
    /// - Parameters:
    ///   - table: Table
    ///   - columns: Column names
    ///   - orderBy: Order by column
    ///   - limit: Limit
    ///   - whereClause: Where clause
    ///   - whereArgs: Arguments to where clause
    ///   - db: This method is expected to be called from [fmdbqueue inDatabase]
    /// - Returns: FMResultSet
    @objc public func queryTable(_ table: String, forColumns columns: [String]?, orderBy: String?, limit: String?, whereClause: String?, whereArgs: [Any]?, with db: FMDatabase?) -> FMResultSet? {
        var columnsStr = columns?.joined(separator: ",") ?? ""
        if columnsStr.isEmpty {
            columnsStr = "*"
        }

        let orderByStr = orderBy != nil ? "ORDER BY \(orderBy!)" : ""
        let selectionStr = whereClause != nil ? "WHERE \(whereClause!)" : ""
        let limitStr = limit != nil ? "LIMIT \(limit!)" : ""

        let sql = "SELECT \(columnsStr) FROM \(table) \(selectionStr) \(orderByStr) \(limitStr)"
        let frs = executeQueryThrows(sql, withArgumentsInArray: whereArgs, with: db)
        return frs
    }

    /// Get column name for path
    /// - Parameters:
    ///   - path: Path of interest
    ///   - soupName: name of the soup
    ///   - db: This method is expected to be called from [fmdbqueue inDatabase]
    /// - Returns: The column name for the given path if indexed or nil otherwise.
    @objc public func columnName(forPath path: String, inSoup soupName: String, with db: FMDatabase?) -> String? {
        var result: String?
        let indexSpecs = indices(forSoup: soupName, with: db)
        for indexSpec in indexSpecs {
            if indexSpec.path == path {
                result = indexSpec.columnName
                break
            }
        }

        if result == nil {
            SmartStoreLogger.d(type(of: self), message: "Unknown index path '\(path)' in soup '\(soupName)' ")
        }
        return result
    }

    /// Check if path is indexed
    /// - Parameters:
    ///   - path: Path of interest
    ///   - soupName: name of the soup
    ///   - db: This method is expected to be called from [fmdbqueue inDatabase]
    /// - Returns: YES if the given path is indexed or NO otherwise.
    @objc public func hasIndex(forPath path: String, inSoup soupName: String, with db: FMDatabase?) -> Bool {
        let indexSpecs = indices(forSoup: soupName, with: db)
        for indexSpec in indexSpecs {
            if indexSpec.path == path {
                return true
            }
        }
        return false
    }

    /// Similar to System.currentTimeMillis: time in ms since Jan 1 1970
    /// - Returns: The current number of milliseconds since 1/1/1970.
    @objc public func currentTimeInMilliseconds() -> NSNumber {
        let rawTime = floor(1000 * Date().timeIntervalSince1970)
        return NSNumber(value: rawTime)
    }

    /// Get encryption key
    /// - Returns: The key used to encrypt the store.
    @objc public class func encKey() -> String? {
        if let keyGenerator = encryptionKeyGenerator {
            if let key = keyGenerator() {
                return key.base64EncodedString(options: [])
            }
        }
        return nil
    }

    /// Get salt
    /// - Returns: The key used to encrypt the store for shared mode.
    @objc public class func salt() -> String? {
        if let saltBlock = encryptionSaltBlock {
            return saltBlock()
        }
        return nil
    }

    /// FOR UNIT TESTING. Removes all of the shared smart store objects from memory.
    @objc public class func clearSharedStoreMemoryState() {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        _allSharedStores.removeAllObjects()
        _allGlobalSharedStores.removeAllObjects()
    }

    /// FOR UNIT TESTING.
    /// - Parameter inputStream: The input stream to read
    /// - Returns: string decoded from the specified input stream
    @objc public class func string(from inputStream: InputStream) -> String? {
        var buffer = [UInt8](repeating: 0, count: kBufferSize)
        let content = NSMutableData()
        inputStream.open()
        var len = inputStream.read(&buffer, maxLength: buffer.count)
        while len > 0 {
            content.append(buffer, length: len)
            len = inputStream.read(&buffer, maxLength: buffer.count)
        }
        inputStream.close()
        return String(data: content as Data, encoding: .utf8)
    }

    /// Convert smart sql to sql.
    /// - Parameter smartSql: The smart sql to convert.
    /// - Returns: The sql.
    @objc public func convertSmartSql(_ smartSql: String) -> String? {
        var result: String?
        var error: NSError?
        _ = inDatabase({ db in
            result = self.convertSmartSql(smartSql, with: db)
        })
        return result
    }

    func convertSmartSql(_ smartSql: String, with db: FMDatabase?) -> String? {
        SmartStoreLogger.v(type(of: self), message: "convertSmartSQL:\(smartSql)")
        var sql = _smartSqlToSql.sql(forSmartSql: smartSql)
        if sql == nil, let db = db {
            sql = SmartSqlHelper.shared.convertSmartSql(smartSql, store: self, db: db)

            if sql == nil {
                SmartStoreLogger.v(type(of: self), message: "convertSmartSql:putting NULL in cache")
                _smartSqlToSql.setSql("null", forSmartSql: smartSql)
            } else {
                SmartStoreLogger.v(type(of: self), message: "convertSmartSql:putting \(sql!) in cache")
                _smartSqlToSql.setSql(sql!, forSmartSql: smartSql)
            }
        } else if sql == "null" {
            SmartStoreLogger.v(type(of: self), message: "convertSmartSql:found NULL in cache")
            return nil
        }
        return sql
    }

    /// Remove soup from cache
    /// - Parameter soupName: The name of the soup to remove
    @objc public func removeFromCache(_ soupName: String) {
        _indexSpecsBySoup.removeObject(forKey: soupName as NSString)
        _soupNameToTableName.removeObject(forKey: soupName as NSString)
        _smartSqlToSql.removeEntries(forSoup: soupName)
    }

    /// Get unfinished long operations
    /// - Returns: unfinished long operations
    @objc public func getLongOperations() -> [AlterSoupLongOperation] {
        var results: [AlterSoupLongOperation] = []
        var error: NSError?
        _ = inDatabase({ db in
            results = self.getLongOperations(with: db)
        })
        return results
    }

    func getLongOperations(with db: FMDatabase?) -> [AlterSoupLongOperation] {
        var longOperations: [AlterSoupLongOperation] = []

        let frs = queryTable(LONG_OPERATIONS_STATUS_TABLE,
                            forColumns: [ID_COL, DETAILS_COL, STATUS_COL],
                            orderBy: nil,
                            limit: nil,
                            whereClause: nil,
                            whereArgs: nil,
                            with: db)

        while frs?.next() == true {
            let rowId = frs?.long(forColumn: ID_COL) ?? 0
            let detailsStr = frs?.string(forColumn: DETAILS_COL) ?? ""
            let details = SFJsonUtils.object(from: detailsStr) as? [String: Any] ?? [:]
            let statusInt = frs?.int(forColumn: STATUS_COL) ?? 0
            let status = AlterSoupStep(rawValue: UInt(statusInt)) ?? .starting

            let longOperation = AlterSoupLongOperation(store: self, rowId: Int(rowId), details: details, status: status)
            longOperations.append(longOperation)
        }
        frs?.close()

        return longOperations
    }

    /// Resume long operations
    @objc public func resumeLongOperations() {
        let longOperations = getLongOperations()
        for longOperation in longOperations {
            longOperation.run()
        }
    }

    /// Execute query
    /// - Parameters:
    ///   - sql: SQL query
    ///   - db: Database
    /// - Returns: Result set
    @objc public func executeQueryThrows(_ sql: String, with db: FMDatabase?) -> FMResultSet? {
        let result = db?.executeQuery(sql, withArgumentsIn: [])
        if result == nil {
            logAndThrowLastError("executeQuery [\(sql)] failed", with: db)
        }
        return result
    }

    /// Execute query with arguments
    /// - Parameters:
    ///   - sql: SQL query
    ///   - arguments: Query arguments
    ///   - db: Database
    /// - Returns: Result set
    @objc public func executeQueryThrows(_ sql: String, withArgumentsInArray arguments: [Any]?, with db: FMDatabase?) -> FMResultSet? {
        if capturesExplainQueryPlan {
            let explainSql = "EXPLAIN QUERY PLAN \(sql)"
            var lastPlan: [String: Any] = [EXPLAIN_SQL: explainSql]
            if let arguments = arguments, !arguments.isEmpty {
                lastPlan[EXPLAIN_ARGS] = arguments
            }
            var explainRows: [[String: String]] = []

            let frs = db?.executeQuery(explainSql, withArgumentsIn: arguments ?? [])
            while frs?.next() == true {
                var explainRow: [String: String] = [:]
                for i in 0..<(frs?.columnCount ?? 0) {
                    if let columnName = frs?.columnName(for: Int32(i)),
                       let value = frs?.string(forColumnIndex: Int32(i)) {
                        explainRow[columnName] = value
                    }
                }
                explainRows.append(explainRow)
            }
            frs?.close()
            lastPlan[EXPLAIN_ROWS] = explainRows
            lastExplainQueryPlan = lastPlan
        }

        let result = db?.executeQuery(sql, withArgumentsIn: arguments ?? [])
        if result == nil {
            logAndThrowLastError("executeQuery [\(sql)] failed", with: db)
        }
        return result
    }

    /// Execute update
    /// - Parameters:
    ///   - sql: SQL update
    ///   - db: Database
    @objc public func executeUpdateThrows(_ sql: String, with db: FMDatabase?) {
        let result = db?.executeUpdate(sql, withArgumentsIn: [])
        if result != true {
            logAndThrowLastError("executeUpdate [\(sql)] failed", with: db)
        }
    }

    /// Execute update with arguments
    /// - Parameters:
    ///   - sql: SQL update
    ///   - arguments: Update arguments
    ///   - db: Database
    @objc public func executeUpdateThrows(_ sql: String, withArgumentsInArray arguments: [Any]?, with db: FMDatabase?) {
        let result = db?.executeUpdate(sql, withArgumentsIn: arguments ?? [])
        if result != true {
            logAndThrowLastError("executeUpdate [\(sql)] failed", with: db)
        }
    }

    func logAndThrowLastError(_ message: String, with db: FMDatabase?) {
        let errorMessage = db?.lastErrorMessage() ?? "Unknown error"
        let exception = NSException(name: NSExceptionName(message), reason: errorMessage, userInfo: nil)
        exception.raise()
    }

    /// Check that the given raw JSON string represents valid JSON.
    /// - Parameters:
    ///   - rawJson: The raw JSON string to validate.
    ///   - fromMethod: The method making the call (for logging purposes on failure).
    /// - Returns: YES if the JSON string is valid JSON, NO otherwise.
    @objc public func checkRawJson(_ rawJson: String, fromMethod: String) -> Bool {
        if SmartStore.jsonSerializationCheckEnabled && SFJsonUtils.object(from: rawJson) == nil {
            SmartStoreLogger.e(type(of: self), message: "Error parsing JSON in SmartStore in \(fromMethod)")
            SmartStore.buildEventOnJsonParseError(forUser: userAccount, fromMethod: fromMethod, rawJson: rawJson)
            return false
        } else {
            return true
        }
    }
}

// Helper function to check if value is indexed with JSON extract
func kValueIndexedWithJSONExtract(_ indexSpec: SoupIndex) -> Bool {
    return indexSpec.indexType == kSoupIndexTypeJSON1
}

// Helper function to check if value is extracted to column
func kValueExtractedToColumn(_ indexSpec: SoupIndex) -> Bool {
    return indexSpec.indexType != kSoupIndexTypeJSON1 && indexSpec.indexType != kSoupIndexTypeFullText
}

// Helper function to check if value is extracted to FTS column
func kValueExtractedToFtsColumn(_ indexSpec: SoupIndex) -> Bool {
    return indexSpec.indexType == kSoupIndexTypeFullText
}

