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
import SalesforceSDKCommon
@testable import SalesforceSDKCore
@testable import SmartStore

class SFSmartStoreAlterTests: SFSmartStoreTestCase {

    // MARK: - Constants

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

    // MARK: - Properties

    private var smartStoreUser: UserAccount!
    private var store: SmartStore!
    private var globalStore: SmartStore!

    // MARK: - Setup and Teardown

    override func setUp() {
        super.setUp()
        SmartStoreLogger.setLogLevel(.debug)
        smartStoreUser = setUpSmartStoreUser()
        guard let userStore = SmartStore.shared(withName: kTestSmartStoreName) else {
            XCTFail("Failed to create shared store")
            return
        }
        store = userStore
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

    // MARK: - Tests

    /// Test for getSoupIndexSpecs
    func testGetSoupIndexSpecs() {
        let indexSpecs = SoupIndex.asArraySoupIndexes([
            ["path": "lastName", "type": "string"],
            ["path": "address.city", "type": "string"],
            ["path": "salary", "type": "integer"],
            ["path": "interest", "type": "floating"],
            ["path": "note", "type": "full_text"]
        ])

        XCTAssertFalse(store.soupExists(kTestSoupName), "Test soup should not exist")
        try? store.registerSoup(withName: kTestSoupName, withIndices: indexSpecs)
        XCTAssertTrue(store.soupExists(kTestSoupName), "Register soup call failed")

        // Check indices
        let actualIndexSpecs = store.indices(forSoupNamed: kTestSoupName)
        checkIndexSpecs(actualIndexSpecs, expectedIndexSpecs: indexSpecs, checkColumnName: false)
    }

    /// Test for alterSoup with reIndexData = false
    func testAlterSoupNoReIndexing() {
        alterSoupHelper(reIndexData: false)
    }

    /// Test for alterSoup with reIndexData = true
    func testAlterSoupWithReIndexing() {
        alterSoupHelper(reIndexData: true)
    }

    /// Test for alterSoup with column type change from string to integer
    func testAlterSoupTypeChangeStringToInteger() {
        let indexSpecs = SoupIndex.asArraySoupIndexes([
            ["path": kName, "type": "string"],
            ["path": kPopulation, "type": "string"]
        ])
        XCTAssertFalse(store.soupExists(kTestSoupName), "Test soup should not exist")
        try? store.registerSoup(withName: kTestSoupName, withIndices: indexSpecs)
        XCTAssertTrue(store.soupExists(kTestSoupName), "Register soup call failed")

        _ = store.upsert(entries: [
            [kName: "San Francisco", kPopulation: 825863],
            [kName: "Paris", kPopulation: 2234105]
        ], forSoupNamed: kTestSoupName)

        // Query all sorted by population ascending - we should get Paris first because we indexed population as a string
        let allQuerySpec = QuerySpec.buildAllQuerySpec(soupName: kTestSoupName, orderPath: kPopulation, order: .ascending, pageSize: 2)
        let results = try? store.query(using: allQuerySpec, startingFromPageIndex: 0) as? [[String: Any]]
        XCTAssertEqual(results?[0][kName] as? String, "Paris", "Paris should be first")
        XCTAssertEqual(results?[1][kName] as? String, "San Francisco", "San Francisco should be second")

        // Alter soup - index population as integer
        let indexSpecsNew = SoupIndex.asArraySoupIndexes([
            ["path": kName, "type": "string"],
            ["path": kPopulation, "type": "integer"]
        ])
        _ = store.alterSoup(named: kTestSoupName, indexSpecs: indexSpecsNew, reIndexData: true)

        // Query all sorted by population ascending - we should get San Francisco first because we indexed population as an integer
        let results2 = try? store.query(using: allQuerySpec, startingFromPageIndex: 0) as? [[String: Any]]
        XCTAssertEqual(results2?[0][kName] as? String, "San Francisco", "San Francisco should be first")
        XCTAssertEqual(results2?[1][kName] as? String, "Paris", "Paris should be second")
    }

    /// Test for alterSoup with column type change from string to full_text
    func testAlterSoupTypeChangeStringToFullText() {
        tryAlterSoupTypeChange(fromType: "string", toType: "full_text")
    }

    /// Test for alterSoup with column type change from full_text to string
    func testAlterSoupTypeChangeFullTextToString() {
        tryAlterSoupTypeChange(fromType: "full_text", toType: "string")
    }

    /// Test for alterSoup with column type change from string to json1
    func testAlterSoupTypeChangeStringToJSON1() {
        tryAlterSoupTypeChange(fromType: "string", toType: "json1")
    }

    /// Test for alterSoup with column type change from json1 to string
    func testAlterSoupTypeChangeJSON1ToString() {
        tryAlterSoupTypeChange(fromType: "json1", toType: "string")
    }

    /// Test for alterSoup with column type change from full_text to json1
    func testAlterSoupTypeChangeFullTextToJSON1() {
        tryAlterSoupTypeChange(fromType: "full_text", toType: "json1")
    }

    /// Test for alterSoup with column type change from json1 to full_text
    func testAlterSoupTypeChangeJSON1ToFullText() {
        tryAlterSoupTypeChange(fromType: "json1", toType: "full_text")
    }

    /// Test for alterSoup passing in same index specs (string)
    /// Make sure db table / indexes are recreated
    /// That way soup created before 4.2 can get the new indexes (create/lastModified) by calling alterSoup
    func testAlterSoupWithStringIndexesToGetIndexesOnCreatedAndLastModified() {
        tryAlterSoupToGetIndexesOnCreatedAndLastModified(indexType: "string")
    }

    /// Test for alterSoup passing in same index specs (json1)
    /// Make sure db table / indexes are recreated
    func testAlterSoupWithJSON1IndexesToGetIndexesOnCreatedAndLastModified() {
        tryAlterSoupToGetIndexesOnCreatedAndLastModified(indexType: "json1")
    }

    /// Test for alterSoup passing in same index specs (full_text)
    /// Make sure db table / indexes are recreated
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

    // MARK: - Helper Methods

    /// Start with country and city as fromType
    /// Alter soup to have country as toType
    /// Alter soup a second time to have city as toType
    ///
    /// Only use internal storage
    private func tryAlterSoupTypeChange(fromType: String, toType: String) {
        let indexSpecs = SoupIndex.asArraySoupIndexes([
            ["path": kCity, "type": fromType],
            ["path": kCountry, "type": fromType]
        ])
        XCTAssertFalse(store.soupExists(kTestSoupName), "Test soup should not exist")
        try? store.registerSoup(withName: kTestSoupName, withIndices: indexSpecs)
        XCTAssertTrue(store.soupExists(kTestSoupName), "Register soup call failed")

        let savedEntries = store.upsert(entries: [
            [kCity: "San Francisco", kCountry: "United States"],
            [kName: "Paris", kCountry: "France"]
        ], forSoupNamed: kTestSoupName)

        // Check db
        checkDb(savedEntries, cityColType: fromType, countryColType: fromType)

        // Alter soup - country now toType
        let indexSpecsNew = SoupIndex.asArraySoupIndexes([
            ["path": kCity, "type": fromType],
            ["path": kCountry, "type": toType]
        ])
        _ = store.alterSoup(named: kTestSoupName, indexSpecs: indexSpecsNew, reIndexData: true)

        // Check db
        checkDb(savedEntries, cityColType: fromType, countryColType: toType)

        // Alter soup - city now toType
        let indexSpecsNew2 = SoupIndex.asArraySoupIndexes([
            ["path": kCity, "type": toType],
            ["path": kCountry, "type": toType]
        ])
        _ = store.alterSoup(named: kTestSoupName, indexSpecs: indexSpecsNew2, reIndexData: true)

        // Check db
        checkDb(savedEntries, cityColType: toType, countryColType: toType)
    }

    private func checkDb(_ expectedEntries: [[String: Any]], cityColType: String, countryColType: String) {
        // Expected column names
        let expectedCityCol = (cityColType == kSoupIndexTypeJSON1) ? "json_extract(soup, '$.\(kCity)')" : kCityCol
        let expectedCountryCol = (countryColType == kSoupIndexTypeJSON1) ? "json_extract(soup, '$.\(kCountry)')" : kCountryCol

        // Check indices
        let expectedIndexSpecs = SoupIndex.asArraySoupIndexes([
            ["path": kCity, "type": cityColType, "columnName": expectedCityCol],
            ["path": kCountry, "type": countryColType, "columnName": expectedCountryCol]
        ])
        let actualIndexSpecs = store.indices(forSoupNamed: kTestSoupName)
        checkIndexSpecs(actualIndexSpecs, expectedIndexSpecs: expectedIndexSpecs, checkColumnName: true)

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
        store.storeQueue?.inDatabase { db in
            guard let frs = self.store.queryTable(self.kTestSoupTableName, forColumns: nil, orderBy: "id ASC", limit: nil, whereClause: nil, whereArgs: nil, with: db) else {
                XCTFail("Query returned nil")
                return
            }
            self.checkSoupRow(frs, expectedEntry: expectedEntries[0], soupIndexes: actualIndexSpecs)
            self.checkSoupRow(frs, expectedEntry: expectedEntries[1], soupIndexes: actualIndexSpecs)
            XCTAssertFalse(frs.next(), "Only two rows should have been returned")
            frs.close()
        }

        if cityColType == kSoupIndexTypeFullText || countryColType == kSoupIndexTypeFullText {
            // Check fts table columns. PRAGMA table_info on an fts4/fts5 virtual table reports only the
            // declared (indexed) columns, not the implicit `rowid`, so `rowid` is not part of the
            // expected column set. (The ObjC original asserted `rowid` here, but that block was dead
            // code — its outer guard `[kCityCol isEqualToString:kSoupIndexTypeFullText]` compared a
            // column name against a type constant and was always false, so it never actually ran.)
            var ftsExpectedColumns: [String] = []
            if cityColType == kSoupIndexTypeFullText { ftsExpectedColumns.append(kCityCol) }
            if countryColType == kSoupIndexTypeFullText { ftsExpectedColumns.append(kCountryCol) }
            checkColumns(kTestSoupFtsTableName, expectedColumns: ftsExpectedColumns, store: store)

            // Check fts table rows. `rowid` is not a declared column but is still selectable, so query
            // it explicitly (checkFtsRow reads it and we order by it).
            let ftsQueryColumns = [SmartStoreConstants.rowidColumn] + ftsExpectedColumns
            store.storeQueue?.inDatabase { db in
                guard let frs = self.store.queryTable(self.kTestSoupFtsTableName, forColumns: ftsQueryColumns, orderBy: "rowid ASC", limit: nil, whereClause: nil, whereArgs: nil, with: db) else {
                    XCTFail("FTS query returned nil")
                    return
                }
                self.checkFtsRow(frs, expectedEntry: expectedEntries[0], soupIndexes: actualIndexSpecs)
                self.checkFtsRow(frs, expectedEntry: expectedEntries[1], soupIndexes: actualIndexSpecs)
                XCTAssertFalse(frs.next(), "Only two rows should have been returned")
                frs.close()
            }
        }
    }

    /// Create soup
    /// Drop created/lastModified indexes - to simulate the soup having been created before SDK 4.2
    /// Alter soup passing in the same indexes
    /// Check underlying table
    private func tryAlterSoupToGetIndexesOnCreatedAndLastModified(indexType: String) {
        let indexSpecs = SoupIndex.asArraySoupIndexes([
            ["path": kCity, "type": indexType],
            ["path": kCountry, "type": indexType]
        ])
        XCTAssertFalse(store.soupExists(kTestSoupName), "Test soup should not exist")
        try? store.registerSoup(withName: kTestSoupName, withIndices: indexSpecs)
        XCTAssertTrue(store.soupExists(kTestSoupName), "Register soup call failed")

        let savedEntries = store.upsert(entries: [
            [kCity: "San Francisco", kCountry: "United States"],
            [kName: "Paris", kCountry: "France"]
        ], forSoupNamed: kTestSoupName)

        // Check db
        checkDb(savedEntries, cityColType: indexType, countryColType: indexType)

        // Drop db indexes on created and lastModified to simulate soup having been created before SDK 4.2
        let dropIndexStatements = [
            "DROP INDEX \(kTestSoupTableName)_created_idx",
            "DROP INDEX \(kTestSoupTableName)_lastModified_idx"
        ]

        store.storeQueue?.inDatabase { db in
            for dropIndexStatement in dropIndexStatements {
                db.executeUpdate(dropIndexStatement, withArgumentsIn: [])
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
        _ = store.alterSoup(named: kTestSoupName, indexSpecs: indexSpecs, reIndexData: true)

        // Check db - created and lastModified indexes should be there
        checkDb(savedEntries, cityColType: indexType, countryColType: indexType)
    }

    /// Create soup with fts4 virtual table
    /// Call alterSoup passing in same index specs
    /// Make sure virtual table is recreated with fts5
    /// That way soup created before 4.2 (using fts4 virtual table) can be migrated to fts5 by calling alterSoup
    func testAlterSoupWithFullTextIndexesFromFts4ToFts5() {
        let indexSpecs = SoupIndex.asArraySoupIndexes([
            ["path": kCity, "type": kSoupIndexTypeFullText],
            ["path": kCountry, "type": kSoupIndexTypeFullText]
        ])

        // Using fts4 to simulate pre 4.2 sdk
        store.ftsExtension = .fts4

        XCTAssertFalse(store.soupExists(kTestSoupName), "Test soup should not exist")
        try? store.registerSoup(withName: kTestSoupName, withIndices: indexSpecs)
        XCTAssertTrue(store.soupExists(kTestSoupName), "Register soup call failed")

        let savedEntries = store.upsert(entries: [
            [kCity: "San Francisco", kCountry: "United States"],
            [kName: "Paris", kCountry: "France"]
        ], forSoupNamed: kTestSoupName)

        // Check db
        checkDb(savedEntries, cityColType: kSoupIndexTypeFullText, countryColType: kSoupIndexTypeFullText)

        // Check type of fts table
        checkCreateTableStatement(kTestSoupFtsTableName, expectedSqlStatementPrefix: "CREATE VIRTUAL TABLE \(kTestSoupFtsTableName) USING fts4", store: store)

        // Using fts5
        store.ftsExtension = .fts5

        // Alter soup - passing same indexSpecs as before
        _ = store.alterSoup(named: kTestSoupName, indexSpecs: indexSpecs, reIndexData: true)

        // Check db
        checkDb(savedEntries, cityColType: kSoupIndexTypeFullText, countryColType: kSoupIndexTypeFullText)

        // Check type of fts table
        checkCreateTableStatement(kTestSoupFtsTableName, expectedSqlStatementPrefix: "CREATE VIRTUAL TABLE \(kTestSoupFtsTableName) USING fts5", store: store)
    }

    private func alterSoupHelper(reIndexData: Bool) {
        let indexSpecs = SoupIndex.asArraySoupIndexes([
            ["path": kLastName, "type": "string"],
            ["path": kAddressCity, "type": "string"]
        ])
        XCTAssertFalse(store.soupExists(kTestSoupName), "Test soup should not exist")
        try? store.registerSoup(withName: kTestSoupName, withIndices: indexSpecs)
        XCTAssertTrue(store.soupExists(kTestSoupName), "Register soup call failed")

        let savedEntries = store.upsert(entries: [
            [kLastName: "Doe", kAddress: [kCity: "San Francisco", kStreet: "1 market"]],
            [kLastName: "Jackson", kAddress: [kCity: "Los Angeles", kStreet: "100 mission"]],
            [kLastName: "Watson", kAddress: [kCity: "London", kStreet: "50 market"]]
        ], forSoupNamed: kTestSoupName)

        // Check indices
        let actualIndexSpecs = store.indices(forSoupNamed: kTestSoupName)
        checkIndexSpecs(actualIndexSpecs, expectedIndexSpecs: indexSpecs, checkColumnName: false)

        // Check soup table
        store.storeQueue?.inDatabase { db in
            guard let frs = self.store.queryTable(self.kTestSoupTableName, forColumns: nil, orderBy: "id ASC", limit: nil, whereClause: nil, whereArgs: nil, with: db) else {
                XCTFail("Query returned nil")
                return
            }
            self.checkSoupRow(frs, expectedEntry: savedEntries[0], soupIndexes: actualIndexSpecs)
            self.checkSoupRow(frs, expectedEntry: savedEntries[1], soupIndexes: actualIndexSpecs)
            self.checkSoupRow(frs, expectedEntry: savedEntries[2], soupIndexes: actualIndexSpecs)
            XCTAssertFalse(frs.next(), "Only three rows should have been returned")
            frs.close()
        }

        // Alter soup - address.street now indexed
        let indexSpecsNew = SoupIndex.asArraySoupIndexes([
            ["path": kLastName, "type": "string"],
            ["path": kAddressStreet, "type": "string"]
        ])
        _ = store.alterSoup(named: kTestSoupName, indexSpecs: indexSpecsNew, reIndexData: reIndexData)

        // Check indices
        let actualIndexSpecsNew = store.indices(forSoupNamed: kTestSoupName)
        checkIndexSpecs(actualIndexSpecsNew, expectedIndexSpecs: indexSpecsNew, checkColumnName: false)

        // Check soup table
        store.storeQueue?.inDatabase { db in
            guard let frs = self.store.queryTable(self.kTestSoupTableName, forColumns: nil, orderBy: "id ASC", limit: nil, whereClause: nil, whereArgs: nil, with: db) else {
                XCTFail("Query returned nil")
                return
            }

            for i in 0..<3 {
                frs.next()
                XCTAssertEqual(
                    NSNumber(value: frs.long(forColumn: SmartStoreConstants.idColumn)),
                    savedEntries[i][SmartStoreConstants.soupEntryId] as? NSNumber,
                    "Wrong id"
                )
                XCTAssertEqual(
                    frs.string(forColumn: self.kLastNameCol),
                    savedEntries[i][self.kLastName] as? String,
                    "Wrong name"
                )
                if reIndexData {
                    let expectedStreet = (savedEntries[i][self.kAddress] as? [String: Any])?[self.kStreet] as? String
                    XCTAssertEqual(frs.string(forColumn: self.kAddressStreetCol), expectedStreet, "Wrong street")
                } else {
                    XCTAssertNil(frs.string(forColumn: self.kAddressStreetCol), "Wrong street - nil expected")
                }
            }
            XCTAssertFalse(frs.next(), "Only three rows should have been returned")
            frs.close()
        }
    }

    private func tryAlterSoupInterruptResume(toStep: AlterSoupStep) {
        let stores: [SmartStore] = [store, globalStore]
        for currentStore in stores {
            // Before
            XCTAssertFalse(currentStore.soupExists(kTestSoupName), "Soup \(kTestSoupName) should not exist")

            // Register
            let lastNameSoupIndex: [String: String] = ["path": "lastName", "type": "string"]
            let indexSpecs = SoupIndex.asArraySoupIndexes([lastNameSoupIndex])
            try? currentStore.registerSoup(withName: kTestSoupName, withIndices: indexSpecs)
            let testSoupExists = currentStore.soupExists(kTestSoupName)
            XCTAssertTrue(testSoupExists, "Soup \(kTestSoupName) should exist")

            var soupTableName: String?
            currentStore.storeQueue?.inDatabase { db in
                soupTableName = currentStore.tableNameForSoup(self.kTestSoupName, with: db)
            }

            // Populate soup
            guard let entries = SFJsonUtils.object(fromJSONString: "[{\"lastName\":\"Doe\", \"address\":{\"city\":\"San Francisco\",\"street\":\"1 market\"}},{\"lastName\":\"Jackson\", \"address\":{\"city\":\"Los Angeles\",\"street\":\"100 mission\"}}]") as? [[String: Any]] else {
                XCTFail("Failed to parse entries JSON")
                return
            }
            let insertedEntries = currentStore.upsert(entries: entries, forSoupNamed: kTestSoupName)

            // Partial alter - up to toStep included
            let citySoupIndex: [String: String] = ["path": "address.city", "type": "string"]
            let streetSoupIndex: [String: String] = ["path": "address.street", "type": "string"]
            let indexSpecsNew = SoupIndex.asArraySoupIndexes([lastNameSoupIndex, citySoupIndex, streetSoupIndex])
            let operation = AlterSoupLongOperation(store: currentStore, soupName: kTestSoupName, newIndexSpecs: indexSpecsNew, reIndexData: true)
            operation.runToStep(toStep)

            // Validate long_operations_status table
            let operations = currentStore.getLongOperations()
            let expectedCount = (toStep == .cleanup) ? 0 : 1
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
                checkIndexSpecs(actualIndexSpecs, expectedIndexSpecs: indexSpecsNew, checkColumnName: false)

                // Check data
                guard let tableNameForCheck = soupTableName else {
                    XCTFail("soupTableName is nil")
                    return
                }
                currentStore.storeQueue?.inDatabase { db in
                    guard let frs = currentStore.queryTable(tableNameForCheck, forColumns: nil, orderBy: "id ASC", limit: nil, whereClause: nil, whereArgs: nil, with: db) else {
                        XCTFail("Query returned nil")
                        return
                    }
                    self.checkSoupRow(frs, expectedEntry: insertedEntries[0], soupIndexes: actualIndexSpecs)
                    self.checkSoupRow(frs, expectedEntry: insertedEntries[1], soupIndexes: actualIndexSpecs)
                    XCTAssertFalse(frs.next(), "Only two rows should have been returned")
                    frs.close()
                }
            }
        }
    }

    private func checkIndexSpecs(_ actualSoupIndexes: [SoupIndex], expectedIndexSpecs: [SoupIndex], checkColumnName: Bool) {
        XCTAssertTrue(actualSoupIndexes.count == expectedIndexSpecs.count, "Wrong number of index specs")
        for i in 0..<expectedIndexSpecs.count {
            let actualSoupIndex = actualSoupIndexes[i]
            let expectedSoupIndex = expectedIndexSpecs[i]
            XCTAssertEqual(actualSoupIndex.path, expectedSoupIndex.path, "Wrong path")
            XCTAssertEqual(actualSoupIndex.indexType, expectedSoupIndex.indexType, "Wrong type")
            if checkColumnName {
                XCTAssertEqual(actualSoupIndex.columnName, expectedSoupIndex.columnName, "Wrong column name")
            }
        }
    }
}
