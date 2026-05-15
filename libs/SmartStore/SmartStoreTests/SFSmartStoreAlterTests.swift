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

import XCTest
import FMDB
@testable import SmartStore
import SalesforceSDKCore
import SalesforceSDKCommon

private let kTestSmartStoreName = "testSmartStore"
private let kTestSoupName = "testSoup"
private let kName = "name"
private let kPopulation = "population"
private let kCity = "city"
private let kCountry = "country"
private let kTestSoupTableName = "TABLE_1"
private let kTestSoupFtsTableName = "TABLE_1_fts"
private let kCityCol = "TABLE_1_0"
private let kCountryCol = "TABLE_1_1"
private let kLastName = "lastName"
private let kAddress = "address"
private let kStreet = "street"
private let kAddressCity = "address.city"
private let kAddressStreet = "address.street"
private let kLastNameCol = "TABLE_1_0"
private let kAddressStreetCol = "TABLE_1_1"

class SFSmartStoreAlterTests: SFSmartStoreTestCase {

    private var smartStoreUser: UserAccount!
    private var store: SmartStore!
    private var globalStore: SmartStore!

    override func setUp() {
        super.setUp()
        SmartStoreLogger.setLogLevel(.debug)
        smartStoreUser = setUpSmartStoreUser()
        store = SmartStore.shared(withName: kTestSmartStoreName)
        globalStore = SmartStore.sharedGlobal(withName: kTestSmartStoreName)
    }

    override func tearDown() {
        SmartStore.removeShared(withName: kTestSmartStoreName)
        SmartStore.removeSharedGlobal(withName: kTestSmartStoreName)
        tearDownSmartStoreUser(smartStoreUser)
        super.tearDown()
        smartStoreUser = nil
        store = nil
        globalStore = nil
    }

    // MARK: - tests

    func testGetSoupIndexSpecs() {
        let indexSpecs = SoupIndex.asArray([
            ["path": "lastName", "type": "string"],
            ["path": "address.city", "type": "string"],
            ["path": "salary", "type": "integer"],
            ["path": "interest", "type": "floating"],
            ["path": "note", "type": "full_text"]
        ])

        XCTAssertFalse(store.soupExists(forName: kTestSoupName), "Test soup should not exists")
        try! store.registerSoup(withName: kTestSoupName, withIndices: indexSpecs)
        XCTAssertTrue(store.soupExists(forName: kTestSoupName), "Register soup call failed")

        // Check indices
        let actualIndexSpecs = store.indices(forSoupNamed: kTestSoupName)
        checkIndexSpecs(actualIndexSpecs, withExpectedIndexSpecs: indexSpecs, checkColumnName: false)
    }

    func testAlterSoupNoReIndexing() {
        alterSoupHelper(reIndexData: false)
    }

    func testAlterSoupWithReIndexing() {
        alterSoupHelper(reIndexData: true)
    }

    func testAlterSoupTypeChangeStringToInteger() {
        let indexSpecs = SoupIndex.asArray([["path": kName, "type": "string"], ["path": kPopulation, "type": "string"]])
        XCTAssertFalse(store.soupExists(forName: kTestSoupName), "Test soup should not exists")
        try! store.registerSoup(withName: kTestSoupName, withIndices: indexSpecs)
        XCTAssertTrue(store.soupExists(forName: kTestSoupName), "Register soup call failed")

        store.upsert(entries: [[kName: "San Francisco", kPopulation: 825863] as NSDictionary, [kName: "Paris", kPopulation: 2234105] as NSDictionary], forSoupNamed: kTestSoupName)

        // Query all sorted by population ascending - we should get Paris first because we indexed population as a string
        let querySpec = QuerySpec.buildAllQuerySpec(soupName: kTestSoupName, orderPath: kPopulation, order: .ascending, pageSize: 2)
        let results = try! store.query(using: querySpec, startingFromPageIndex: 0) as! [[String: Any]]
        XCTAssertEqual(results[0][kName] as? String, "Paris", "Paris should be first")
        XCTAssertEqual(results[1][kName] as? String, "San Francisco", "San Francisco should be second")

        // Alter soup - index population as integer
        let indexSpecsNew = SoupIndex.asArray([["path": kName, "type": "string"], ["path": kPopulation, "type": "integer"]])
        store.alterSoup(named: kTestSoupName, indexSpecs: indexSpecsNew, reIndexData: true)

        // Query all sorted by population ascending - we should get San Francisco first because we indexed population as an integer
        let results2 = try! store.query(using: querySpec, startingFromPageIndex: 0) as! [[String: Any]]
        XCTAssertEqual(results2[0][kName] as? String, "San Francisco", "San Francisco should be first")
        XCTAssertEqual(results2[1][kName] as? String, "Paris", "Paris should be second")
    }

    func testAlterSoupTypeChangeStringToFullText() {
        tryAlterSoupTypeChange(fromType: "string", toType: "full_text")
    }

    func testAlterSoupTypeChangeFullTextToString() {
        tryAlterSoupTypeChange(fromType: "full_text", toType: "string")
    }

    func testAlterSoupTypeChangeStringToJSON1() {
        tryAlterSoupTypeChange(fromType: "string", toType: "json1")
    }

    func testAlterSoupTypeChangeJSON1ToString() {
        tryAlterSoupTypeChange(fromType: "json1", toType: "string")
    }

    func testAlterSoupTypeChangeFullTextToJSON1() {
        tryAlterSoupTypeChange(fromType: "full_text", toType: "json1")
    }

    func testAlterSoupTypeChangeJSON1ToFullText() {
        tryAlterSoupTypeChange(fromType: "json1", toType: "full_text")
    }

    func testAlterSoupWithStringIndexesToGetIndexesOnCreatedAndLastModified() {
        tryAlterSoupToGetIndexesOnCreatedAndLastModified(indexType: "string")
    }

    func testAlterSoupWithJSON1IndexesToGetIndexesOnCreatedAndLastModified() {
        tryAlterSoupToGetIndexesOnCreatedAndLastModified(indexType: "json1")
    }

    func testAlterSoupWithFullTextIndexesToGetIndexesOnCreatedAndLastModified() {
        tryAlterSoupToGetIndexesOnCreatedAndLastModified(indexType: "full_text")
    }

    func testAlterSoupResumeAfterRenameOldSoupTable() {
        tryAlterSoupInterruptResume(toStep: .renameOldSoupTable)
    }

    func testAlterSoupResumeAfterDropOldIndexes() {
        tryAlterSoupInterruptResume(toStep: .dropOldIndexes)
    }

    func testAlterSoupResumeAfterRegisterSoupUsingTableName() {
        tryAlterSoupInterruptResume(toStep: .registerSoupUsingTableName)
    }

    func testAlterSoupResumeAfterCopyTable() {
        tryAlterSoupInterruptResume(toStep: .copyTable)
    }

    func testAlterSoupResumeAfterReIndexSoup() {
        tryAlterSoupInterruptResume(toStep: .reIndexSoup)
    }

    func testAlterSoupResumeAfterDropOldTable() {
        tryAlterSoupInterruptResume(toStep: .dropOldTable)
    }

    // MARK: - helper methods

    private func tryAlterSoupTypeChange(fromType: String, toType: String) {
        let indexSpecs = SoupIndex.asArray([["path": kCity, "type": fromType], ["path": kCountry, "type": fromType]])
        XCTAssertFalse(store.soupExists(forName: kTestSoupName), "Test soup should not exists")
        try! store.registerSoup(withName: kTestSoupName, withIndices: indexSpecs)
        XCTAssertTrue(store.soupExists(forName: kTestSoupName), "Register soup call failed")

        let savedEntries = store.upsert(entries: [[kCity: "San Francisco", kCountry: "United States"] as NSDictionary, [kName: "Paris", kCountry: "France"] as NSDictionary], forSoupNamed: kTestSoupName)

        // Check db
        checkDb(savedEntries as! [[String: Any]], cityColType: fromType, countryColType: fromType)

        // Alter soup - country now toType
        let indexSpecsNew = SoupIndex.asArray([["path": kCity, "type": fromType], ["path": kCountry, "type": toType]])
        store.alterSoup(named: kTestSoupName, indexSpecs: indexSpecsNew, reIndexData: true)

        // Check db
        checkDb(savedEntries as! [[String: Any]], cityColType: fromType, countryColType: toType)

        // Alter soup - city now toType
        let indexSpecsNew2 = SoupIndex.asArray([["path": kCity, "type": toType], ["path": kCountry, "type": toType]])
        store.alterSoup(named: kTestSoupName, indexSpecs: indexSpecsNew2, reIndexData: true)

        // Check db
        checkDb(savedEntries as! [[String: Any]], cityColType: toType, countryColType: toType)
    }

    private func checkDb(_ expectedEntries: [[String: Any]], cityColType: String, countryColType: String) {
        // Expected column names
        let expectedCityCol = (cityColType == kSoupIndexTypeJSON1) ? "json_extract(soup, '$.\(kCity)')" : kCityCol
        let expectedCountryCol = (countryColType == kSoupIndexTypeJSON1) ? "json_extract(soup, '$.\(kCountry)')" : kCountryCol

        // Check indices
        let expectedIndexSpecs = SoupIndex.asArray([
            ["path": kCity, "type": cityColType, "columnName": expectedCityCol],
            ["path": kCountry, "type": countryColType, "columnName": expectedCountryCol]
        ])
        let actualIndexSpecs = store.indices(forSoupNamed: kTestSoupName)
        checkIndexSpecs(actualIndexSpecs, withExpectedIndexSpecs: expectedIndexSpecs, checkColumnName: true)

        // Check db indexes
        let indexSqlFormat = "CREATE INDEX %@_%@_idx ON %@ ( %@ )"
        checkDatabaseIndexes(kTestSoupTableName, expectedSqlStatements: [
            String(format: indexSqlFormat, kTestSoupTableName, "0", kTestSoupTableName, expectedCityCol),
            String(format: indexSqlFormat, kTestSoupTableName, "1", kTestSoupTableName, expectedCountryCol),
            String(format: indexSqlFormat, kTestSoupTableName, "created", kTestSoupTableName, "created"),
            String(format: indexSqlFormat, kTestSoupTableName, "lastModified", kTestSoupTableName, "lastModified")
        ], store: store)

        // Check soup table columns
        var expectedColumns: [String] = ["id", "soup", "created", "lastModified"]
        if cityColType != kSoupIndexTypeJSON1 { expectedColumns.append(kCityCol) }
        if countryColType != kSoupIndexTypeJSON1 { expectedColumns.append(kCountryCol) }
        checkColumns(kTestSoupTableName, expectedColumns: expectedColumns, store: store)

        // Check soup table rows
        store.storeQueue.inDatabase { db in
            let frs = self.store.queryTable(kTestSoupTableName, forColumns: nil, orderBy: "id ASC", limit: nil, whereClause: nil, whereArgs: nil, with: db)
            self.checkSoupRow(frs!, withExpectedEntry: expectedEntries[0], withSoupIndexes: actualIndexSpecs)
            self.checkSoupRow(frs!, withExpectedEntry: expectedEntries[1], withSoupIndexes: actualIndexSpecs)
            XCTAssertFalse(frs!.next(), "Only two rows should have been returned")
            frs!.close()
        }

        if cityColType == kSoupIndexTypeFullText || countryColType == kSoupIndexTypeFullText {
            // Check fts table columns (rowid is implicit in FTS5, not returned by PRAGMA table_info)
            var ftsExpectedColumns: [String] = []
            if cityColType == kSoupIndexTypeFullText { ftsExpectedColumns.append(kCityCol) }
            if countryColType == kSoupIndexTypeFullText { ftsExpectedColumns.append(kCountryCol) }
            checkColumns(kTestSoupFtsTableName, expectedColumns: ftsExpectedColumns, store: store)

            // Check fts table rows
            store.storeQueue.inDatabase { db in
                var ftsQueryColumns = [ROWID_COL] + ftsExpectedColumns
                let frs = self.store.queryTable(kTestSoupFtsTableName, forColumns: ftsQueryColumns, orderBy: "rowid ASC", limit: nil, whereClause: nil, whereArgs: nil, with: db)
                self.checkFtsRow(frs!, withExpectedEntry: expectedEntries[0], withSoupIndexes: actualIndexSpecs)
                self.checkFtsRow(frs!, withExpectedEntry: expectedEntries[1], withSoupIndexes: actualIndexSpecs)
                XCTAssertFalse(frs!.next(), "Only two rows should have been returned")
                frs!.close()
            }
        }
    }

    private func tryAlterSoupToGetIndexesOnCreatedAndLastModified(indexType: String) {
        let indexSpecs = SoupIndex.asArray([["path": kCity, "type": indexType], ["path": kCountry, "type": indexType]])
        XCTAssertFalse(store.soupExists(forName: kTestSoupName), "Test soup should not exists")
        try! store.registerSoup(withName: kTestSoupName, withIndices: indexSpecs)
        XCTAssertTrue(store.soupExists(forName: kTestSoupName), "Register soup call failed")

        let savedEntries = store.upsert(entries: [[kCity: "San Francisco", kCountry: "United States"] as NSDictionary, [kName: "Paris", kCountry: "France"] as NSDictionary], forSoupNamed: kTestSoupName)

        // Check db
        checkDb(savedEntries as! [[String: Any]], cityColType: indexType, countryColType: indexType)

        // Drop db indexes on created and lastModified to simulate soup having been created before SDK 4.2
        let dropIndexStatements = [
            "DROP INDEX \(kTestSoupTableName)_created_idx",
            "DROP INDEX \(kTestSoupTableName)_lastModified_idx"
        ]

        store.storeQueue.inDatabase { db in
            for stmt in dropIndexStatements {
                db.executeUpdate(stmt, withArgumentsIn: [])
            }
        }

        // Check db indexes after the drop - created and lastModified should be gone
        let expectedCityCol = (indexType == kSoupIndexTypeJSON1) ? "json_extract(soup, '$.\(kCity)')" : kCityCol
        let expectedCountryCol = (indexType == kSoupIndexTypeJSON1) ? "json_extract(soup, '$.\(kCountry)')" : kCountryCol
        let indexSqlFormat = "CREATE INDEX %@_%@_idx ON %@ ( %@ )"
        checkDatabaseIndexes(kTestSoupTableName, expectedSqlStatements: [
            String(format: indexSqlFormat, kTestSoupTableName, "0", kTestSoupTableName, expectedCityCol),
            String(format: indexSqlFormat, kTestSoupTableName, "1", kTestSoupTableName, expectedCountryCol)
        ], store: store)

        // Alter soup - passing same indexSpecs as before
        store.alterSoup(named: kTestSoupName, indexSpecs: indexSpecs, reIndexData: true)

        // Check db - created and lastModified indexes should be there
        checkDb(savedEntries as! [[String: Any]], cityColType: indexType, countryColType: indexType)
    }

    func testAlterSoupwithFullTextIndexesFromFts4ToFts5() {
        let indexSpecs = SoupIndex.asArray([["path": kCity, "type": kSoupIndexTypeFullText], ["path": kCountry, "type": kSoupIndexTypeFullText]])

        // Using fts4 to simulate pre 4.2 sdk
        store.ftsExtension = .fts4

        XCTAssertFalse(store.soupExists(forName: kTestSoupName), "Test soup should not exists")
        try! store.registerSoup(withName: kTestSoupName, withIndices: indexSpecs)
        XCTAssertTrue(store.soupExists(forName: kTestSoupName), "Register soup call failed")

        let savedEntries = store.upsert(entries: [[kCity: "San Francisco", kCountry: "United States"] as NSDictionary, [kName: "Paris", kCountry: "France"] as NSDictionary], forSoupNamed: kTestSoupName)

        // Check db
        checkDb(savedEntries as! [[String: Any]], cityColType: kSoupIndexTypeFullText, countryColType: kSoupIndexTypeFullText)

        // Check type of fts table
        checkCreateTableStatement(kTestSoupFtsTableName, expectedSqlStatementPrefix: "CREATE VIRTUAL TABLE \(kTestSoupFtsTableName) USING fts4", store: store)

        // Using fts5
        store.ftsExtension = .fts5

        // Alter soup - passing same indexSpecs as before
        store.alterSoup(named: kTestSoupName, indexSpecs: indexSpecs, reIndexData: true)

        // Check db
        checkDb(savedEntries as! [[String: Any]], cityColType: kSoupIndexTypeFullText, countryColType: kSoupIndexTypeFullText)

        // Check type of fts table
        checkCreateTableStatement(kTestSoupFtsTableName, expectedSqlStatementPrefix: "CREATE VIRTUAL TABLE \(kTestSoupFtsTableName) USING fts5", store: store)
    }

    private func alterSoupHelper(reIndexData: Bool) {
        let indexSpecs = SoupIndex.asArray([["path": kLastName, "type": "string"], ["path": kAddressCity, "type": "string"]])
        XCTAssertFalse(store.soupExists(forName: kTestSoupName), "Test soup should not exists")
        try! store.registerSoup(withName: kTestSoupName, withIndices: indexSpecs)
        XCTAssertTrue(store.soupExists(forName: kTestSoupName), "Register soup call failed")

        let savedEntries = store.upsert(entries: [
            [kLastName: "Doe", kAddress: [kCity: "San Francisco", kStreet: "1 market"]] as NSDictionary,
            [kLastName: "Jackson", kAddress: [kCity: "Los Angeles", kStreet: "100 mission"]] as NSDictionary,
            [kLastName: "Watson", kAddress: [kCity: "London", kStreet: "50 market"]] as NSDictionary
        ], forSoupNamed: kTestSoupName)

        // Check indices
        let actualIndexSpecs = store.indices(forSoupNamed: kTestSoupName)
        checkIndexSpecs(actualIndexSpecs, withExpectedIndexSpecs: indexSpecs, checkColumnName: false)

        // Check soup table
        store.storeQueue.inDatabase { db in
            let frs = self.store.queryTable(kTestSoupTableName, forColumns: nil, orderBy: "id ASC", limit: nil, whereClause: nil, whereArgs: nil, with: db)
            self.checkSoupRow(frs!, withExpectedEntry: savedEntries[0] as! [String: Any], withSoupIndexes: actualIndexSpecs)
            self.checkSoupRow(frs!, withExpectedEntry: savedEntries[1] as! [String: Any], withSoupIndexes: actualIndexSpecs)
            self.checkSoupRow(frs!, withExpectedEntry: savedEntries[2] as! [String: Any], withSoupIndexes: actualIndexSpecs)
            XCTAssertFalse(frs!.next(), "Only three rows should have been returned")
            frs!.close()
        }

        // Alter soup - street now string
        let indexSpecsNew = SoupIndex.asArray([["path": kLastName, "type": "string"], ["path": kAddressStreet, "type": "string"]])
        store.alterSoup(named: kTestSoupName, indexSpecs: indexSpecsNew, reIndexData: reIndexData)

        // Check indices
        let actualIndexSpecsNew = store.indices(forSoupNamed: kTestSoupName)
        checkIndexSpecs(actualIndexSpecsNew, withExpectedIndexSpecs: indexSpecsNew, checkColumnName: false)

        // Check soup table
        store.storeQueue.inDatabase { db in
            let frs = self.store.queryTable(kTestSoupTableName, forColumns: nil, orderBy: "id ASC", limit: nil, whereClause: nil, whereArgs: nil, with: db)

            for i in 0..<3 {
                frs!.next()
                let entry = savedEntries[i] as! [String: Any]
                XCTAssertEqual(NSNumber(value: frs!.long(forColumn: ID_COL)), entry[SOUP_ENTRY_ID] as? NSNumber, "Wrong id")
                XCTAssertEqual(frs!.string(forColumn: kLastNameCol), entry[kLastName] as? String, "Wrong name")
                if reIndexData {
                    let address = entry[kAddress] as? [String: Any]
                    XCTAssertEqual(frs!.string(forColumn: kAddressStreetCol), address?[kStreet] as? String, "Wrong street")
                } else {
                    XCTAssertNil(frs!.string(forColumn: kAddressStreetCol), "Wrong street - nil expected")
                }
            }
            XCTAssertFalse(frs!.next(), "Only three rows should have been returned")
            frs!.close()
        }
    }

    private func tryAlterSoupInterruptResume(toStep: AlterSoupStep) {
        for currentStore in [store!, globalStore!] {
            // Before
            XCTAssertFalse(currentStore.soupExists(forName: kTestSoupName), "Soup \(kTestSoupName) should not exist")

            // Register
            let lastNameSoupIndex: [String: String] = ["path": "lastName", "type": "string"]
            let indexSpecs = SoupIndex.asArray([lastNameSoupIndex])
            try! currentStore.registerSoup(withName: kTestSoupName, withIndices: indexSpecs)
            let testSoupExists = currentStore.soupExists(forName: kTestSoupName)
            XCTAssertTrue(testSoupExists, "Soup \(kTestSoupName) should exist")
            var soupTableName: String?
            currentStore.storeQueue.inDatabase { db in
                soupTableName = currentStore.tableName(forSoup: kTestSoupName, with: db)
            }

            // Populate soup
            let entries = SFJsonUtils.object(from: "[{\"lastName\":\"Doe\", \"address\":{\"city\":\"San Francisco\",\"street\":\"1 market\"}},{\"lastName\":\"Jackson\", \"address\":{\"city\":\"Los Angeles\",\"street\":\"100 mission\"}}]") as! [NSDictionary]
            let insertedEntries = currentStore.upsert(entries: entries, forSoupNamed: kTestSoupName)

            // Partial alter - up to toStep included
            let citySoupIndex: [String: String] = ["path": "address.city", "type": "string"]
            let streetSoupIndex: [String: String] = ["path": "address.street", "type": "string"]
            let indexSpecsNew = SoupIndex.asArray([lastNameSoupIndex, citySoupIndex, streetSoupIndex])
            let operation = AlterSoupLongOperation(store: currentStore, soupName: kTestSoupName, newIndexSpecs: indexSpecsNew, reIndexData: true)
            operation.runToStep(toStep)

            // Validate long_operations_status table
            let operations = currentStore.getLongOperations()
            let expectedCount = (toStep == kLastStep) ? 0 : 1
            XCTAssertTrue(operations.count == expectedCount, "Wrong number of long operations found")
            if operations.count > 0 {
                // Check details
                let actualOperation = operations[0]
                XCTAssertEqual(actualOperation.soupName, kTestSoupName, "Wrong soup name")
                XCTAssertEqual(actualOperation.soupTableName, soupTableName, "Wrong soup table name")
                XCTAssertTrue(actualOperation.reIndexData, "Wrong re-index data")

                // Check last step completed
                XCTAssertEqual(actualOperation.afterStep, toStep, "Wrong step")

                // Simulate restart (clear cache and call resumeLongOperations)
                currentStore.resumeLongOperations()

                // Check that long operations table is now empty
                XCTAssertTrue(currentStore.getLongOperations().count == 0, "There should be no long operations left")

                // Check index specs
                let actualIndexSpecs = currentStore.indices(forSoupNamed: kTestSoupName)
                checkIndexSpecs(actualIndexSpecs, withExpectedIndexSpecs: SoupIndex.asArray(indexSpecsNew), checkColumnName: false)

                // Check data
                currentStore.storeQueue.inDatabase { db in
                    let frs = currentStore.queryTable(soupTableName!, forColumns: nil, orderBy: "id ASC", limit: nil, whereClause: nil, whereArgs: nil, with: db)
                    self.checkSoupRow(frs!, withExpectedEntry: insertedEntries[0] as! [String: Any], withSoupIndexes: actualIndexSpecs)
                    self.checkSoupRow(frs!, withExpectedEntry: insertedEntries[1] as! [String: Any], withSoupIndexes: actualIndexSpecs)
                    XCTAssertFalse(frs!.next(), "Only two rows should have been returned")
                    frs!.close()
                }
            }
        }
    }

    private func checkIndexSpecs(_ actualSoupIndexes: [SoupIndex], withExpectedIndexSpecs expectedSoupIndexes: [SoupIndex], checkColumnName: Bool) {
        XCTAssertTrue(actualSoupIndexes.count == expectedSoupIndexes.count, "Wrong number of index specs")
        for i in 0..<expectedSoupIndexes.count {
            let actualSoupIndex = actualSoupIndexes[i]
            let expectedSoupIndex = expectedSoupIndexes[i]
            XCTAssertEqual(actualSoupIndex.path, expectedSoupIndex.path, "Wrong path")
            XCTAssertEqual(actualSoupIndex.indexType, expectedSoupIndex.indexType, "Wrong type")
            if checkColumnName {
                XCTAssertEqual(actualSoupIndex.columnName, expectedSoupIndex.columnName, "Wrong column name")
            }
        }
    }
}
