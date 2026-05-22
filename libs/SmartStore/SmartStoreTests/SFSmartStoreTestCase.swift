/*
 Copyright (c) 2013-present, salesforce.com, inc. All rights reserved.

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

import XCTest
import FMDB
import SalesforceSDKCommon
@testable import SalesforceSDKCore
@testable import SmartStore

/// Base class for SmartStore test cases, providing common helper methods.
class SFSmartStoreTestCase: XCTestCase {

    // MARK: - JSON Comparison Helpers

    func assertSameJSON(expected: Any?, actual: Any?, message: String, file: StaticString = #file, line: UInt = #line) {
        // At least one nil
        if expected == nil || actual == nil {
            if expected == nil && actual == nil {
                return
            } else {
                XCTFail(message, file: file, line: line)
            }
            return
        }

        // Both arrays
        if let expectedArray = expected as? [Any], let actualArray = actual as? [Any] {
            assertSameJSONArray(expected: expectedArray, actual: actualArray, message: message, file: file, line: line)
        }
        // Both dictionaries
        else if let expectedDict = expected as? [String: Any], let actualDict = actual as? [String: Any] {
            assertSameJSONMap(expected: expectedDict, actual: actualDict, message: message, file: file, line: line)
        }
        // Strings/numbers/booleans
        else {
            let expectedObj = expected as? NSObject
            let actualObj = actual as? NSObject
            XCTAssertEqual(expectedObj, actualObj, message, file: file, line: line)
        }
    }

    func assertSameJSONArray(expected: [Any], actual: [Any], message: String, file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(expected.count, actual.count, message, file: file, line: line)

        if expected.count == actual.count {
            for i in 0..<expected.count {
                assertSameJSON(expected: expected[i], actual: actual[i], message: message, file: file, line: line)
            }
        }
    }

    func assertSameJSONMap(expected: [String: Any], actual: [String: Any], message: String, file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(expected.count, actual.count, message, file: file, line: line)

        for key in expected.keys {
            assertSameJSON(expected: expected[key], actual: actual[key], message: message, file: file, line: line)
        }
    }

    // MARK: - Index Spec Creation Helpers

    func createStringIndexSpec(_ path: String) -> [String: String] {
        return createSimpleIndexSpec(path, withType: kSoupIndexTypeString)
    }

    func createIntegerIndexSpec(_ path: String) -> [String: String] {
        return createSimpleIndexSpec(path, withType: kSoupIndexTypeInteger)
    }

    func createFloatingIndexSpec(_ path: String) -> [String: String] {
        return createSimpleIndexSpec(path, withType: kSoupIndexTypeFloating)
    }

    func createFullTextIndexSpec(_ path: String) -> [String: String] {
        return createSimpleIndexSpec(path, withType: kSoupIndexTypeFullText)
    }

    func createJSON1IndexSpec(_ path: String) -> [String: String] {
        return createSimpleIndexSpec(path, withType: kSoupIndexTypeJSON1)
    }

    func createSimpleIndexSpec(_ path: String, withType pathType: String) -> [String: String] {
        return ["path": path, "type": pathType]
    }

    // MARK: - Table Inspection Helpers

    func hasTable(_ tableName: String, store: SmartStore) -> Bool {
        var result: Int = NSNotFound
        store.storeQueue?.inDatabase { db in
            if let frs = db.executeQuery(
                "select count(1) from sqlite_master where type = ? and name = ?",
                withArgumentsIn: ["table", tableName]
            ) {
                if frs.next() {
                    result = Int(frs.int(forColumnIndex: 0))
                }
                frs.close()
            }
        }
        return result == 1
    }

    func getSoupTableName(_ soupName: String, store: SmartStore) -> String? {
        var result: String?
        store.storeQueue?.inDatabase { db in
            result = store.tableNameForSoup(soupName, with: db)
        }
        return result
    }

    // MARK: - Query Plan and Schema Checks

    func checkExplainQueryPlan(_ soupName: String, index: UInt, covering: Bool, dbOperation: String, store: SmartStore, file: StaticString = #file, line: UInt = #line) {
        guard let soupTableName = getSoupTableName(soupName, store: store) else {
            XCTFail("Could not get soup table name for \(soupName)", file: file, line: line)
            return
        }
        let indexName = "\(soupTableName)_\(index)_idx"
        let coveringStr = covering ? "COVERING " : ""
        let expectedDetailPrefix = "\(dbOperation) \(soupTableName) USING \(coveringStr)INDEX \(indexName)"

        guard let explainPlan = store.lastExplainQueryPlan,
              let rows = explainPlan["rows"] as? [[String: Any]],
              let firstRow = rows.first,
              let actualDetail = firstRow["detail"] as? String else {
            XCTFail("No explain query plan available", file: file, line: line)
            return
        }
        XCTAssertTrue(actualDetail.hasPrefix(expectedDetailPrefix), "Wrong explain plan actual: \(actualDetail)", file: file, line: line)
    }

    func checkColumns(_ tableName: String, expectedColumns: [String], store: SmartStore, file: StaticString = #file, line: UInt = #line) {
        var actualColumns: [String] = []
        store.storeQueue?.inDatabase { db in
            let sql = "PRAGMA table_info(\(tableName))"
            if let frs = db.executeQuery(sql, withArgumentsIn: []) {
                while frs.next() {
                    if let colName = frs.string(forColumnIndex: 1) {
                        actualColumns.append(colName)
                    }
                }
                frs.close()
            }
        }
        let message = "Wrong columns actual: \(actualColumns.joined(separator: ","))"
        assertSameJSONArray(expected: expectedColumns, actual: actualColumns, message: message, file: file, line: line)
    }

    func checkDatabaseIndexes(_ tableName: String, expectedSqlStatements: [String], store: SmartStore, file: StaticString = #file, line: UInt = #line) {
        var actualSqlStatements: [String] = []
        store.storeQueue?.inDatabase { db in
            if let frs = db.executeQuery(
                "SELECT sql FROM sqlite_master WHERE type='index' AND tbl_name=? ORDER BY name",
                withArgumentsIn: [tableName]
            ) {
                while frs.next() {
                    if let sql = frs.string(forColumnIndex: 0) {
                        actualSqlStatements.append(sql)
                    }
                }
                frs.close()
            }
        }
        let message = "Wrong indexes actual:\(actualSqlStatements.joined(separator: ","))"
        assertSameJSONArray(expected: expectedSqlStatements, actual: actualSqlStatements, message: message, file: file, line: line)
    }

    func checkCreateTableStatement(_ tableName: String, expectedSqlStatementPrefix: String, store: SmartStore, file: StaticString = #file, line: UInt = #line) {
        var actualSqlStatement: String?
        store.storeQueue?.inDatabase { db in
            if let frs = db.executeQuery(
                "SELECT sql FROM sqlite_master WHERE type='table' AND tbl_name=?",
                withArgumentsIn: [tableName]
            ) {
                if frs.next() {
                    actualSqlStatement = frs.string(forColumnIndex: 0)
                }
                frs.close()
            }
        }
        guard let actual = actualSqlStatement else {
            XCTFail("No create table statement found for \(tableName)", file: file, line: line)
            return
        }
        XCTAssertTrue(actual.contains(expectedSqlStatementPrefix), "Wrong statement actual:\(actual)", file: file, line: line)
    }

    func checkSoupIndex(_ indexSpec: SoupIndex, expectedPath: String, expectedType: String, expectedColumnName: String, file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(expectedPath, indexSpec.path, "Wrong path", file: file, line: line)
        XCTAssertEqual(expectedType, indexSpec.indexType, "Wrong type", file: file, line: line)
        XCTAssertEqual(expectedColumnName, indexSpec.columnName, "Wrong column name", file: file, line: line)
    }

    // MARK: - Row Verification Helpers

    func checkSoupRow(_ frs: FMResultSet, expectedEntry: [String: Any], soupIndexes: [SoupIndex], file: StaticString = #file, line: UInt = #line) {
        XCTAssertTrue(frs.next(), "Expected rows to be returned", file: file, line: line)

        // Check id
        let actualId = NSNumber(value: frs.long(forColumn: SmartStoreConstants.idColumn))
        let expectedId = expectedEntry[SmartStoreConstants.soupEntryId] as? NSNumber
        XCTAssertEqual(actualId, expectedId, "Wrong id", file: file, line: line)

        // Check indexed columns
        for soupIndex in soupIndexes {
            if kValueExtractedToColumn(soupIndex) {
                let actualValue = frs.string(forColumn: soupIndex.columnName)
                let expectedValue = SFJsonUtils.project(intoJson: expectedEntry, path: soupIndex.path) as? String
                XCTAssertEqual(actualValue, expectedValue, "Wrong value in index column for \(soupIndex.path)", file: file, line: line)
            }
        }

        // Check soup column if there is one
        if frs.columnIndex(forName: SmartStoreConstants.soupColumn) >= 0 {
            let actualSoup = frs.string(forColumn: SmartStoreConstants.soupColumn)
            let expectedSoup = SFJsonUtils.jsonRepresentation(expectedEntry)
            XCTAssertEqual(actualSoup, expectedSoup, "Wrong value in soup column", file: file, line: line)
        }
    }

    func checkFtsRow(_ frs: FMResultSet, expectedEntry: [String: Any], soupIndexes: [SoupIndex], file: StaticString = #file, line: UInt = #line) {
        XCTAssertTrue(frs.next(), "Expected rows to be returned", file: file, line: line)

        // Check rowid
        let actualRowId = NSNumber(value: frs.long(forColumn: SmartStoreConstants.rowidColumn))
        let expectedRowId = expectedEntry[SmartStoreConstants.soupEntryId] as? NSNumber
        XCTAssertEqual(actualRowId, expectedRowId, "Wrong id", file: file, line: line)

        // Check indexed columns
        for soupIndex in soupIndexes {
            if kValueExtractedToFtsColumn(soupIndex) {
                let actualValue = frs.string(forColumn: soupIndex.columnName)
                let expectedValue = SFJsonUtils.project(intoJson: expectedEntry, path: soupIndex.path) as? String
                XCTAssertEqual(actualValue, expectedValue, "Wrong value in index column for \(soupIndex.path)", file: file, line: line)
            }
        }
    }

    // MARK: - Soup Table Verification

    func checkSoupTable(expectedEntries: [[ String: Any]], shouldExist: Bool, store: SmartStore, soupName: String, file: StaticString = #file, line: UInt = #line) {
        // Getting ids of expected entries and building id to entry map
        var expectedEntriesIds: [NSNumber] = []
        var idToExpectedEntries: [NSNumber: [String: Any]] = [:]

        for expectedEntry in expectedEntries {
            if let soupEntryId = expectedEntry[SmartStoreConstants.soupEntryId] as? NSNumber {
                expectedEntriesIds.append(soupEntryId)
                idToExpectedEntries[soupEntryId] = expectedEntry
            }
        }

        // Getting soup table name
        var soupTableName: String?
        store.storeQueue?.inDatabase { db in
            soupTableName = store.tableNameForSoup(soupName, with: db)
        }

        guard let tableName = soupTableName else {
            XCTFail("Could not get soup table name for \(soupName)", file: file, line: line)
            return
        }

        // Getting soup indexes
        let soupIndexes = store.indices(forSoupNamed: soupName)

        // Getting data from soup table
        store.storeQueue?.inDatabase { db in
            let idsString = expectedEntriesIds.map { "\($0)" }.joined(separator: ",")
            let pred = "\(SmartStoreConstants.idColumn) IN (\(idsString))"
            let query = "SELECT * FROM \(tableName) WHERE \(pred)"

            guard let frs = db.executeQuery(query, withArgumentsIn: []) else {
                XCTFail("Failed to execute query on soup table", file: file, line: line)
                return
            }

            if shouldExist {
                var actualRows: [[String: Any]] = []
                while frs.next() {
                    if let row = frs.resultDictionary as? [String: Any] {
                        actualRows.append(row)
                    }
                }
                frs.close()

                XCTAssertEqual(actualRows.count, expectedEntries.count, "Wrong number of entries found", file: file, line: line)

                for actualRow in actualRows {
                    guard let soupEntryId = actualRow[SmartStoreConstants.idColumn] as? NSNumber,
                          let expectedEntry = idToExpectedEntries[soupEntryId] else {
                        XCTFail("Could not find expected entry for row", file: file, line: line)
                        continue
                    }

                    for soupIndex in soupIndexes {
                        if soupIndex.indexType != kSoupIndexTypeJSON1 {
                            let actualValue = actualRow[soupIndex.columnName]
                            let expectedValue = expectedEntry[soupIndex.path]
                            XCTAssertEqual(
                                actualValue as? NSObject,
                                expectedValue as? NSObject,
                                "Mismatching values for path \(soupIndex.path) for entry \(soupEntryId)",
                                file: file,
                                line: line
                            )
                        }
                    }

                    if let soupColumnValue = actualRow[SmartStoreConstants.soupColumn] as? String,
                       let actualEntry = SFJsonUtils.object(fromJSONString: soupColumnValue) as? [String: Any] {
                        self.assertSameJSON(
                            expected: expectedEntry,
                            actual: actualEntry,
                            message: "Mismatching json for entry \(soupEntryId)",
                            file: file,
                            line: line
                        )
                    }
                }
            } else {
                XCTAssertFalse(frs.next(), "None of the entries should have been found", file: file, line: line)
                frs.close()
            }
        }
    }

    // MARK: - User Account Helpers

    func setUpSmartStoreUser() -> UserAccount {
        let userIdentifier = arc4random()
        let identifier = "identifier-\(userIdentifier)"
        let clientId = UserAccountManager.shared.oauthClientID

        guard let credentials = OAuthCredentials.credentials(identifier: identifier, clientId: clientId, encrypted: true) else {
            fatalError("Failed to create OAuthCredentials for test user")
        }

        let user = UserAccount(credentials: credentials)
        let userId = "user_\(userIdentifier)"
        let orgId = "org_\(userIdentifier)"
        credentials.identityUrl = URL(string: "https://login.salesforce.com/id/\(orgId)/\(userId)")
        user.transitionToLoginState(.loggedIn)

        let success = UserAccountManager.shared.upsert(user)
        XCTAssertTrue(success, "Failed to save user account")

        UserAccountManager.shared.setCurrentUserInternal(user)

        return user
    }

    func tearDownSmartStoreUser(_ user: UserAccount) {
        _ = UserAccountManager.shared.delete(user)
        UserAccountManager.shared.setCurrentUserInternal(nil)
    }
}
