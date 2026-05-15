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
@testable import SmartStore
import SalesforceSDKCore
import SalesforceSDKCommon

class SFSmartStoreTestCase: XCTestCase {

    // MARK: - JSON comparison helpers

    func assertSameJSON(expected: Any?, actual: Any?, message: String) {
        // At least one nil
        if expected == nil || actual == nil {
            if expected == nil && actual == nil {
                return
            } else {
                XCTFail(message)
            }
        }
        // Both arrays
        else if let expectedArray = expected as? [Any], let actualArray = actual as? [Any] {
            assertSameJSONArray(expected: expectedArray, actual: actualArray, message: message)
        }
        // Both dictionaries
        else if let expectedDict = expected as? [String: Any], let actualDict = actual as? [String: Any] {
            assertSameJSONMap(expected: expectedDict, actual: actualDict, message: message)
        }
        // Strings/numbers/booleans
        else {
            let expectedObj = expected as? NSObject
            let actualObj = actual as? NSObject
            XCTAssertEqual(expectedObj, actualObj, message)
        }
    }

    func assertSameJSONArray(expected: [Any], actual: [Any], message: String) {
        XCTAssertEqual(expected.count, actual.count, message)

        if expected.count == actual.count {
            for i in 0..<expected.count {
                assertSameJSON(expected: expected[i], actual: actual[i], message: message)
            }
        }
    }

    func assertSameJSONMap(expected: [String: Any], actual: [String: Any], message: String) {
        XCTAssertEqual(expected.count, actual.count, message)

        for key in expected.keys {
            assertSameJSON(expected: expected[key], actual: actual[key], message: message)
        }
    }

    // MARK: - Index spec helpers

    func createIntegerIndexSpec(_ path: String) -> [String: String] {
        return createSimpleIndexSpec(path, withType: kSoupIndexTypeInteger)
    }

    func createFloatingIndexSpec(_ path: String) -> [String: String] {
        return createSimpleIndexSpec(path, withType: kSoupIndexTypeFloating)
    }

    func createFullTextIndexSpec(_ path: String) -> [String: String] {
        return createSimpleIndexSpec(path, withType: kSoupIndexTypeFullText)
    }

    func createStringIndexSpec(_ path: String) -> [String: String] {
        return createSimpleIndexSpec(path, withType: kSoupIndexTypeString)
    }

    func createJSON1IndexSpec(_ path: String) -> [String: String] {
        return createSimpleIndexSpec(path, withType: kSoupIndexTypeJSON1)
    }

    func createSimpleIndexSpec(_ path: String, withType pathType: String) -> [String: String] {
        return ["path": path, "type": pathType]
    }

    // MARK: - Database helpers

    func hasTable(_ tableName: String, store: SmartStore) -> Bool {
        var result: Int = NSNotFound
        store.storeQueue.inDatabase { db in
            let frs = db.executeQuery("select count(1) from sqlite_master where type = ? and name = ?", withArgumentsIn: ["table", tableName])
            if frs?.next() == true {
                result = Int(frs?.int(forColumnIndex: 0) ?? 0)
            }
            frs?.close()
        }
        return result == 1
    }

    func getSoupTableName(_ soupName: String, store: SmartStore) -> String? {
        var result: String?
        store.storeQueue.inDatabase { db in
            result = store.tableName(forSoup: soupName, with: db)
        }
        return result
    }

    func checkExplainQueryPlan(_ soupName: String, index: UInt, covering: Bool, dbOperation: String, store: SmartStore) {
        let soupTableName = getSoupTableName(soupName, store: store)!
        let indexName = "\(soupTableName)_\(index)_idx"
        let expectedDetailPrefix = "\(dbOperation) \(soupTableName) USING \(covering ? "COVERING " : "")INDEX \(indexName)"
        let rows = store.lastExplainQueryPlan?[EXPLAIN_ROWS] as? [[String: Any]]
        let actualDetail = rows?[0]["detail"] as? String ?? ""
        XCTAssertTrue(actualDetail.hasPrefix(expectedDetailPrefix), "Wrong explain plan actual: \(actualDetail)")
    }

    func checkColumns(_ tableName: String, expectedColumns: [String], store: SmartStore) {
        var actualColumns: [String] = []
        store.storeQueue.inDatabase { db in
            let sql = "PRAGMA table_info(\(tableName))"
            let frs = db.executeQuery(sql, withArgumentsIn: [])
            while frs?.next() == true {
                if let col = frs?.string(forColumnIndex: 1) {
                    actualColumns.append(col)
                }
            }
            frs?.close()
        }
        let message = "Wrong columns actual: \(actualColumns.joined(separator: ","))"
        assertSameJSONArray(expected: expectedColumns, actual: actualColumns, message: message)
    }

    func checkDatabaseIndexes(_ tableName: String, expectedSqlStatements: [String], store: SmartStore) {
        var actualSqlStatements: [String] = []
        store.storeQueue.inDatabase { db in
            let frs = db.executeQuery("SELECT sql FROM sqlite_master WHERE type='index' AND tbl_name=? ORDER BY name", withArgumentsIn: [tableName])
            while frs?.next() == true {
                if let sql = frs?.string(forColumnIndex: 0) {
                    actualSqlStatements.append(sql)
                }
            }
            frs?.close()
        }
        let message = "Wrong indexes actual:\(actualSqlStatements.joined(separator: ","))"
        assertSameJSONArray(expected: expectedSqlStatements, actual: actualSqlStatements, message: message)
    }

    func checkCreateTableStatement(_ tableName: String, expectedSqlStatementPrefix: String, store: SmartStore) {
        var actualSqlStatement: String?
        store.storeQueue.inDatabase { db in
            let frs = db.executeQuery("SELECT sql FROM sqlite_master WHERE type='table' AND tbl_name=?", withArgumentsIn: [tableName])
            if frs?.next() == true {
                actualSqlStatement = frs?.string(forColumnIndex: 0)
            }
            frs?.close()
        }
        XCTAssert(actualSqlStatement?.contains(expectedSqlStatementPrefix) == true, "Wrong statement actual:\(actualSqlStatement ?? "")")
    }

    func checkSoupIndex(_ indexSpec: SoupIndex, expectedPath: String, expectedType: String, expectedColumnName: String) {
        XCTAssertEqual(expectedPath, indexSpec.path, "Wrong path")
        XCTAssertEqual(expectedType, indexSpec.indexType, "Wrong type")
        XCTAssertEqual(expectedColumnName, indexSpec.columnName, "Wrong column name")
    }

    func checkSoupRow(_ frs: FMResultSet, withExpectedEntry expectedEntry: [String: Any], withSoupIndexes arraySoupIndexes: [SoupIndex]) {
        XCTAssertTrue(frs.next(), "Expected rows to be returned")
        // Check id
        XCTAssertEqual(NSNumber(value: frs.long(forColumn: ID_COL)), expectedEntry[SOUP_ENTRY_ID] as? NSNumber, "Wrong id")

        // Check indexed columns
        for soupIndex in arraySoupIndexes {
            if kValueExtractedToColumn(soupIndex) {
                let actualValue = frs.string(forColumn: soupIndex.columnName ?? "")
                let expectedValue = SFJsonUtils.projectIntoJson(expectedEntry, path: soupIndex.path) as? String
                XCTAssertEqual(actualValue, expectedValue, "Wrong value in index column for \(soupIndex.path)")
            }
        }

        // Check soup column if there is one
        if frs.columnIndex(forName: SOUP_COL) >= 0 {
            let actualSoupJson = frs.string(forColumn: SOUP_COL)
            let actualSoupObj = actualSoupJson != nil ? SFJsonUtils.object(from: actualSoupJson!) : nil
            assertSameJSON(expected: expectedEntry, actual: actualSoupObj, message: "Wrong value in soup column")
        }
    }

    func checkFtsRow(_ frs: FMResultSet, withExpectedEntry expectedEntry: [String: Any], withSoupIndexes arraySoupIndexes: [SoupIndex]) {
        XCTAssertTrue(frs.next(), "Expected rows to be returned")

        // Check rowid
        XCTAssertEqual(NSNumber(value: frs.long(forColumn: ROWID_COL)), expectedEntry[SOUP_ENTRY_ID] as? NSNumber, "Wrong id")

        // Check indexed columns
        for soupIndex in arraySoupIndexes {
            if kValueExtractedToFtsColumn(soupIndex) {
                let actualValue = frs.string(forColumn: soupIndex.columnName ?? "")
                let expectedValue = SFJsonUtils.projectIntoJson(expectedEntry, path: soupIndex.path) as? String
                XCTAssertEqual(actualValue, expectedValue, "Wrong value in index column for \(soupIndex.path)")
            }
        }
    }

    func checkSoupTable(_ expectedEntries: [[String: Any]], shouldExist: Bool, store: SmartStore, soupName: String) {
        // Getting ids of expected entries and building id to entry map
        var expectedEntriesIds: [NSNumber] = []
        var idToExpectedEntries: [NSNumber: [String: Any]] = [:]

        for expectedEntry in expectedEntries {
            if let soupEntryId = expectedEntry[SOUP_ENTRY_ID] as? NSNumber {
                expectedEntriesIds.append(soupEntryId)
                idToExpectedEntries[soupEntryId] = expectedEntry
            }
        }

        // Getting soup table name and storage type
        var soupTableName: String?
        store.storeQueue.inDatabase { db in
            soupTableName = store.tableName(forSoup: soupName, with: db)
        }

        // Getting soup indexes
        let soupIndexes = store.indices(forSoupNamed: soupName)

        // Getting data from soup table
        store.storeQueue.inDatabase { db in
            let idsString = expectedEntriesIds.map { "\($0)" }.joined(separator: ",")
            let pred = "\(ID_COL) IN (\(idsString)) "
            let frs = db.executeQuery("SELECT * FROM \(soupTableName!) WHERE \(pred)", withArgumentsIn: [])

            if shouldExist {
                var actualRows: [[String: Any]] = []

                while frs?.next() == true {
                    if let row = frs?.resultDictionary as? [String: Any] {
                        actualRows.append(row)
                    }
                }

                XCTAssertEqual(actualRows.count, expectedEntries.count, "Wrong number of entries found")

                for actualRow in actualRows {
                    let soupEntryId = actualRow[ID_COL] as? NSNumber
                    let expectedEntry = idToExpectedEntries[soupEntryId!]!

                    for soupIndex in soupIndexes {
                        if soupIndex.indexType != kSoupIndexTypeJSON1 {
                            let actualVal = actualRow[soupIndex.columnName ?? ""] as? NSObject
                            let expectedVal = expectedEntry[soupIndex.path] as? NSObject
                            XCTAssertEqual(actualVal, expectedVal, "Mismatching values for path \(soupIndex.path) for entry \(soupEntryId!)")
                        }
                        if let soupCol = actualRow[SOUP_COL] as? String,
                           let actualEntry = SFJsonUtils.object(from: soupCol) as? [String: Any] {
                            self.assertSameJSON(expected: expectedEntry, actual: actualEntry, message: "Mismatching json for entry \(soupEntryId!)")
                        }
                    }
                }
            } else {
                XCTAssertFalse(frs?.next() == true, "None of the entries should have been found")
            }
        }
    }

    // MARK: - User account helpers

    func setUpSmartStoreUser() -> UserAccount {
        let userIdentifier = arc4random()
        let credentials = OAuthCredentials(identifier: "identifier-\(userIdentifier)", clientId: UserAccountManager.shared.oauthClientID, encrypted: true)
        let user = UserAccount(credentials: credentials)
        let userId = "user_\(userIdentifier)"
        let orgId = "org_\(userIdentifier)"
        user.credentials.identityUrl = URL(string: "https://login.salesforce.com/id/\(orgId)/\(userId)")
        _ = user.transitionToLoginState(.loggedIn)
        try? UserAccountManager.shared.loadAccounts()
        try? UserAccountManager.shared.upsert(user)
        UserAccountManager.shared.currentUserAccount = user
        return user
    }

    func tearDownSmartStoreUser(_ user: UserAccount) {
        try? UserAccountManager.shared.delete(user)
        UserAccountManager.shared.currentUserAccount = nil
    }
}
