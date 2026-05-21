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
@testable import SmartStore

class SFSmartStoreFullTextSearchTests: SFSmartStoreTestCase {

    // MARK: - Constants

    private let kTestStore = "testSmartStoreFullTextSearchStore"
    private let kEmployeesSoup = "employees"
    private let kFirstName = "firstName"
    private let kLastName = "lastName"
    private let kEmployeeId = "employeeId"

    // MARK: - Properties

    private var store: SmartStore!
    private var christineHaasId: NSNumber?
    private var michaelThompsonId: NSNumber?
    private var aliHaasId: NSNumber?
    private var johnGeyerId: NSNumber?
    private var irvingSternId: NSNumber?
    private var evaPulaskiId: NSNumber?
    private var eileenEvaId: NSNumber?

    // MARK: - Setup and Teardown

    override func setUp() {
        super.setUp()
        store = SmartStore.sharedGlobal(withName: kTestStore)
    }

    override func tearDown() {
        store.removeSoup(kEmployeesSoup)
        SmartStore.removeSharedGlobal(withName: kTestStore)
        super.tearDown()
        store = nil
    }

    private func setupSoup(_ ftsExtension: SmartStoreFtsExtension) {
        store.ftsExtension = ftsExtension
        let soupIndices = SoupIndex.asArraySoupIndexes([
            createFullTextIndexSpec(kFirstName),
            createFullTextIndexSpec(kLastName),
            createStringIndexSpec(kEmployeeId)
        ])
        try? store.registerSoup(withName: kEmployeesSoup, withIndices: soupIndices)
    }

    // MARK: - Tests: Register/Drop

    func testRegisterDropSoupFts4() {
        tryRegisterDropSoup(.fts4)
    }

    func testRegisterDropSoupFts5() {
        tryRegisterDropSoup(.fts5)
    }

    private func tryRegisterDropSoup(_ ftsExtension: SmartStoreFtsExtension) {
        setupSoup(ftsExtension)

        let soupTableName = getSoupTableName(kEmployeesSoup, store: store)
        XCTAssertEqual("TABLE_1", soupTableName, "getSoupTableName should have returned TABLE_1")
        XCTAssertTrue(hasTable("TABLE_1", store: store), "Table for soup employees does exit")
        XCTAssertTrue(hasTable("TABLE_1_fts", store: store), "FTS Table for soup employees does exit")
        XCTAssertTrue(store.soupExists(kEmployeesSoup), "Register soup failed")

        let expectedCreateSql = "CREATE VIRTUAL TABLE TABLE_1_fts USING fts\(ftsExtension.rawValue)"
        checkCreateTableStatement("TABLE_1_fts", expectedSqlStatementPrefix: expectedCreateSql, store: store)

        // Drop
        store.removeSoup(kEmployeesSoup)

        // After
        XCTAssertFalse(store.soupExists(kEmployeesSoup), "Soup employees should no longer exist")
        XCTAssertNil(getSoupTableName(kEmployeesSoup, store: store), "Soup employees should no longer exist")
        XCTAssertFalse(hasTable("TABLE_1", store: store), "Table for soup employees should not exit")
        XCTAssertFalse(hasTable("TABLE_1_fts", store: store), "FTS Table for soup employees should not exit")
    }

    // MARK: - Tests: Insert

    func testInsertWithFts4() {
        tryInsert(.fts4)
    }

    func testInsertWithFts5() {
        tryInsert(.fts5)
    }

    private func tryInsert(_ ftsExtension: SmartStoreFtsExtension) {
        setupSoup(ftsExtension)

        // Insert a couple of rows
        let firstEmployee = createEmployee(firstName: "Christine", lastName: "Haas", employeeId: "00010")
        let secondEmployee = createEmployee(firstName: "Michael", lastName: "Thompson", employeeId: "00020")

        // Getting index specs from db
        let actualIndexSpecs = store.indices(forSoupNamed: kEmployeesSoup)

        // Check DB
        let soupTableName = getSoupTableName(kEmployeesSoup, store: store)
        XCTAssertEqual("TABLE_1", soupTableName, "getSoupTableName should have returned TABLE_1")
        XCTAssertTrue(hasTable("TABLE_1", store: store), "Table for soup employees does exit")
        XCTAssertTrue(hasTable("TABLE_1_fts", store: store), "FTS Table for soup employees does exit")

        // Check soup table
        store.storeQueue?.inDatabase { db in
            guard let frs = self.store.queryTable("TABLE_1", forColumns: nil, orderBy: "id ASC", limit: nil, whereClause: nil, whereArgs: nil, with: db) else {
                XCTFail("Expected result set")
                return
            }
            self.checkSoupRow(frs, expectedEntry: firstEmployee, soupIndexes: actualIndexSpecs)
            self.checkSoupRow(frs, expectedEntry: secondEmployee, soupIndexes: actualIndexSpecs)
            XCTAssertFalse(frs.next(), "Only two rows should have been returned")
            frs.close()
        }

        // Check fts table
        store.storeQueue?.inDatabase { db in
            guard let frs = self.store.queryTable("TABLE_1_fts", forColumns: [SmartStoreConstants.rowidColumn, "TABLE_1_0", "TABLE_1_1"], orderBy: "rowid ASC", limit: nil, whereClause: nil, whereArgs: nil, with: db) else {
                XCTFail("Expected result set")
                return
            }
            self.checkFtsRow(frs, expectedEntry: firstEmployee, soupIndexes: actualIndexSpecs)
            self.checkFtsRow(frs, expectedEntry: secondEmployee, soupIndexes: actualIndexSpecs)
            XCTAssertFalse(frs.next(), "Only two rows should have been returned")
            frs.close()
        }
    }

    // MARK: - Tests: Update

    func testUpdateWithFts4() {
        tryUpdate(.fts4)
    }

    func testUpdateWithFts5() {
        tryUpdate(.fts5)
    }

    private func tryUpdate(_ ftsExtension: SmartStoreFtsExtension) {
        setupSoup(.fts5)

        // Insert a couple of rows
        let firstEmployee = createEmployee(firstName: "Christine", lastName: "Haas", employeeId: "00010")
        let secondEmployee = createEmployee(firstName: "Michael", lastName: "Thompson", employeeId: "00020")

        // Getting index specs from db
        let actualIndexSpecs = store.indices(forSoupNamed: kEmployeesSoup)

        // Update second employee
        guard let secondId = secondEmployee[SmartStoreConstants.soupEntryId] as? NSNumber else {
            XCTFail("Expected soup entry ID")
            return
        }
        let secondEmployeeUpdated = updateEmployee(firstName: "Michael-updated", lastName: "Thompson", employeeId: "00020-updated", soupEntryId: secondId)

        // Check soup table
        store.storeQueue?.inDatabase { db in
            guard let frs = self.store.queryTable("TABLE_1", forColumns: nil, orderBy: "id ASC", limit: nil, whereClause: nil, whereArgs: nil, with: db) else {
                XCTFail("Expected result set")
                return
            }
            self.checkSoupRow(frs, expectedEntry: firstEmployee, soupIndexes: actualIndexSpecs)
            self.checkSoupRow(frs, expectedEntry: secondEmployeeUpdated, soupIndexes: actualIndexSpecs)
            XCTAssertFalse(frs.next(), "Only two rows should have been returned")
            frs.close()
        }

        // Check fts table
        store.storeQueue?.inDatabase { db in
            guard let frs = self.store.queryTable("TABLE_1_fts", forColumns: [SmartStoreConstants.rowidColumn, "TABLE_1_0", "TABLE_1_1"], orderBy: "rowid ASC", limit: nil, whereClause: nil, whereArgs: nil, with: db) else {
                XCTFail("Expected result set")
                return
            }
            self.checkFtsRow(frs, expectedEntry: firstEmployee, soupIndexes: actualIndexSpecs)
            self.checkFtsRow(frs, expectedEntry: secondEmployeeUpdated, soupIndexes: actualIndexSpecs)
            XCTAssertFalse(frs.next(), "Only two rows should have been returned")
            frs.close()
        }
    }

    // MARK: - Tests: Delete

    func testDeleteWithFts4() {
        tryDelete(.fts4)
    }

    func testDeleteWithFts5() {
        tryDelete(.fts5)
    }

    private func tryDelete(_ ftsExtension: SmartStoreFtsExtension) {
        setupSoup(ftsExtension)

        // Insert a couple of rows
        let firstEmployee = createEmployee(firstName: "Christine", lastName: "Haas", employeeId: "00010")
        let secondEmployee = createEmployee(firstName: "Michael", lastName: "Thompson", employeeId: "00020")

        // Getting index specs from db
        let actualIndexSpecs = store.indices(forSoupNamed: kEmployeesSoup)

        // Delete first employee
        if let firstId = firstEmployee[SmartStoreConstants.soupEntryId] {
            store.removeEntries([firstId], fromSoup: kEmployeesSoup)
        }

        // Check soup table
        store.storeQueue?.inDatabase { db in
            guard let frs = self.store.queryTable("TABLE_1", forColumns: nil, orderBy: "id ASC", limit: nil, whereClause: nil, whereArgs: nil, with: db) else {
                XCTFail("Expected result set")
                return
            }
            self.checkSoupRow(frs, expectedEntry: secondEmployee, soupIndexes: actualIndexSpecs)
            XCTAssertFalse(frs.next(), "Only one row should have been returned")
            frs.close()
        }

        // Check fts table
        store.storeQueue?.inDatabase { db in
            guard let frs = self.store.queryTable("TABLE_1_fts", forColumns: [SmartStoreConstants.rowidColumn, "TABLE_1_0", "TABLE_1_1"], orderBy: "rowid ASC", limit: nil, whereClause: nil, whereArgs: nil, with: db) else {
                XCTFail("Expected result set")
                return
            }
            self.checkFtsRow(frs, expectedEntry: secondEmployee, soupIndexes: actualIndexSpecs)
            XCTAssertFalse(frs.next(), "Only one should have been returned")
            frs.close()
        }

        // Delete second employee
        if let secondId = secondEmployee[SmartStoreConstants.soupEntryId] {
            store.removeEntries([secondId], fromSoup: kEmployeesSoup)
        }

        // Check soup table
        store.storeQueue?.inDatabase { db in
            guard let frs = self.store.queryTable("TABLE_1", forColumns: nil, orderBy: "id ASC", limit: nil, whereClause: nil, whereArgs: nil, with: db) else {
                XCTFail("Expected result set")
                return
            }
            XCTAssertFalse(frs.next(), "No rows should have been returned")
            frs.close()
        }

        // Check fts table
        store.storeQueue?.inDatabase { db in
            guard let frs = self.store.queryTable("TABLE_1_fts", forColumns: [SmartStoreConstants.rowidColumn, "TABLE_1_0", "TABLE_1_1"], orderBy: "rowid ASC", limit: nil, whereClause: nil, whereArgs: nil, with: db) else {
                XCTFail("Expected result set")
                return
            }
            XCTAssertFalse(frs.next(), "No rows should have been returned")
            frs.close()
        }
    }

    // MARK: - Tests: Clear

    func testClearWithFts4() {
        tryClear(.fts4)
    }

    func testClearWithFts5() {
        tryClear(.fts5)
    }

    private func tryClear(_ ftsExtension: SmartStoreFtsExtension) {
        setupSoup(ftsExtension)

        // Insert a couple of rows
        _ = createEmployee(firstName: "Christine", lastName: "Haas", employeeId: "00010")
        _ = createEmployee(firstName: "Michael", lastName: "Thompson", employeeId: "00020")

        // Clear soup
        store.clearSoup(kEmployeesSoup)

        // Check soup table
        store.storeQueue?.inDatabase { db in
            guard let frs = self.store.queryTable("TABLE_1", forColumns: nil, orderBy: "id ASC", limit: nil, whereClause: nil, whereArgs: nil, with: db) else {
                XCTFail("Expected result set")
                return
            }
            XCTAssertFalse(frs.next(), "No rows should have been returned")
            frs.close()
        }

        // Check fts table
        store.storeQueue?.inDatabase { db in
            guard let frs = self.store.queryTable("TABLE_1_fts", forColumns: [SmartStoreConstants.rowidColumn, "TABLE_1_0", "TABLE_1_1"], orderBy: "rowid ASC", limit: nil, whereClause: nil, whereArgs: nil, with: db) else {
                XCTFail("Expected result set")
                return
            }
            XCTAssertFalse(frs.next(), "No rows should have been returned")
            frs.close()
        }
    }

    // MARK: - Tests: Search Single Field No Results

    func testSearchSingleFielNoResultsWithFts4() {
        trySearchSingleFieldNoResults(.fts4)
    }

    func testSearchSingleFielNoResultsWithFts5() {
        trySearchSingleFieldNoResults(.fts5)
    }

    private func trySearchSingleFieldNoResults(_ ftsExtension: SmartStoreFtsExtension) {
        loadData(ftsExtension)

        // One field - full word - no results
        trySearch([], path: kFirstName, matchKey: "Christina", orderPath: nil)
        trySearch([], path: kLastName, matchKey: "Sternn", orderPath: nil)

        // One field - prefix - no results
        trySearch([], path: kFirstName, matchKey: "Christo*", orderPath: nil)
        trySearch([], path: kLastName, matchKey: "Stel*", orderPath: nil)

        // One field - set operation - no results
        trySearch([], path: kFirstName, matchKey: "Ei* NOT Eileen", orderPath: nil)
    }

    // MARK: - Tests: Search Single Field Single Result

    func testSearchSingleFieldSingleResultWithFts4() {
        trySearchSingleFieldSingleResult(.fts4)
    }

    func testSearchSingleFieldSingleResultWithFts5() {
        trySearchSingleFieldSingleResult(.fts5)
    }

    private func trySearchSingleFieldSingleResult(_ ftsExtension: SmartStoreFtsExtension) {
        loadData(ftsExtension)

        guard let christineId = christineHaasId,
              let irvingId = irvingSternId,
              let eileenId = eileenEvaId else {
            XCTFail("Expected IDs to be set")
            return
        }

        // One field - full word - one result
        trySearch([christineId], path: kFirstName, matchKey: "Christine", orderPath: nil)
        trySearch([irvingId], path: kLastName, matchKey: "Stern", orderPath: nil)

        // One field - prefix - one result
        trySearch([christineId], path: kFirstName, matchKey: "Christ*", orderPath: nil)
        trySearch([irvingId], path: kLastName, matchKey: "Ste*", orderPath: nil)

        // One field - set operation - one result
        trySearch([eileenId], path: kFirstName, matchKey: "E* NOT Eva", orderPath: nil)
    }

    // MARK: - Tests: Search Single Field Multiple Results

    func testSearchSingleFieldMultipleResultsWithFts4() {
        trySearchSingleFieldMultipleResults(.fts4)
    }

    func testSearchSingleFieldMultipleResultsWithFts5() {
        trySearchSingleFieldMultipleResults(.fts5)
    }

    private func trySearchSingleFieldMultipleResults(_ ftsExtension: SmartStoreFtsExtension) {
        loadData(ftsExtension)

        guard let christineId = christineHaasId,
              let aliId = aliHaasId,
              let evaId = evaPulaskiId,
              let eileenId = eileenEvaId else {
            XCTFail("Expected IDs to be set")
            return
        }

        // One field - full word - more than one results
        trySearch([christineId, aliId], path: kLastName, matchKey: "Haas", orderPath: kEmployeeId)
        trySearch([aliId, christineId], path: kLastName, matchKey: "Haas", orderPath: kFirstName)

        // One field - prefix - more than one results
        trySearch([evaId, eileenId], path: kFirstName, matchKey: "E*", orderPath: kEmployeeId)
        trySearch([eileenId, evaId], path: kFirstName, matchKey: "E*", orderPath: kFirstName)

        // One field - set operation - more than one results
        trySearch([evaId, eileenId], path: kFirstName, matchKey: "Eva OR Eileen", orderPath: kEmployeeId)
        trySearch([eileenId, evaId], path: kFirstName, matchKey: "Eva OR Eileen", orderPath: kFirstName)
    }

    // MARK: - Tests: Search All Fields No Results

    func testSearchAllFieldsNoResultsWithFts4() {
        trySearchAllFieldsNoResults(.fts4)
    }

    func testSearchAllFieldsNoResultsWithFts5() {
        trySearchAllFieldsNoResults(.fts5)
    }

    private func trySearchAllFieldsNoResults(_ ftsExtension: SmartStoreFtsExtension) {
        loadData(ftsExtension)

        // All fields - full word - no results
        trySearch([], path: nil, matchKey: "Sternn", orderPath: nil)

        // All fields - prefix - no results
        trySearch([], path: nil, matchKey: "Stel*", orderPath: nil)

        // All fields - multiple words - no results
        trySearch([], path: nil, matchKey: "Haas Christina", orderPath: nil)

        // All fields - set operation - no results
        trySearch([], path: nil, matchKey: "Christine NOT Haas", orderPath: nil)
    }

    // MARK: - Tests: Search All Fields Single Result

    func testSearchAllFieldsSingleResultWithFts4() {
        trySearchAllFieldsSingleResult(.fts4)
    }

    func testSearchAllFieldsSingleResultWithFts5() {
        trySearchAllFieldsSingleResult(.fts5)
    }

    private func trySearchAllFieldsSingleResult(_ ftsExtension: SmartStoreFtsExtension) {
        loadData(ftsExtension)

        guard let christineId = christineHaasId,
              let aliId = aliHaasId,
              let irvingId = irvingSternId else {
            XCTFail("Expected IDs to be set")
            return
        }

        // All fields - full word - one result
        trySearch([irvingId], path: nil, matchKey: "Stern", orderPath: nil)

        // All fields - prefix - one result
        trySearch([irvingId], path: nil, matchKey: "St*", orderPath: nil)

        // All fields - multiple words - one result
        trySearch([christineId], path: nil, matchKey: "Haas Christine", orderPath: nil)

        // All fields - set operation - one result
        trySearch([aliId], path: nil, matchKey: "Haas NOT Christine", orderPath: nil)
    }

    // MARK: - Tests: Search All Fields Multiple Results

    func testSearchAllFieldMultipleResultsWithFts4() {
        trySearchAllFieldMultipleResults(.fts4)
    }

    func testSearchAllFieldMultipleResultsWithFts5() {
        trySearchAllFieldMultipleResults(.fts5)
    }

    private func trySearchAllFieldMultipleResults(_ ftsExtension: SmartStoreFtsExtension) {
        loadData(ftsExtension)

        guard let christineId = christineHaasId,
              let michaelId = michaelThompsonId,
              let aliId = aliHaasId,
              let evaId = evaPulaskiId,
              let eileenId = eileenEvaId else {
            XCTFail("Expected IDs to be set")
            return
        }

        // All fields - full word - more than one results
        trySearch([evaId, eileenId], path: nil, matchKey: "Eva", orderPath: kEmployeeId)
        trySearch([eileenId, evaId], path: nil, matchKey: "Eva", orderPath: kLastName)

        // All fields - prefix - more than one results
        trySearch([evaId, eileenId], path: nil, matchKey: "Ev*", orderPath: kEmployeeId)
        trySearch([eileenId, evaId], path: nil, matchKey: "Ev*", orderPath: kLastName)

        // All fields - set operation - more than result
        trySearch([michaelId, aliId], path: nil, matchKey: "Thompson OR Ali", orderPath: kEmployeeId)
        trySearch([aliId, michaelId], path: nil, matchKey: "Thompson OR Ali", orderPath: kFirstName)
        trySearch([christineId, evaId, eileenId], path: nil, matchKey: "Eva OR Haas NOT Ali", orderPath: kEmployeeId)
        trySearch([christineId, eileenId, evaId], path: nil, matchKey: "Eva OR Haas NOT Ali", orderPath: kFirstName)
    }

    // MARK: - Tests: Search with field:value predicates

    func testSearchWithFieldColonQueriesWithFts4() {
        trySearchWithFieldColonQueries(.fts4)
    }

    func testSearchWithFieldColonQueriesWithFts5() {
        trySearchWithFieldColonQueries(.fts5)
    }

    private func trySearchWithFieldColonQueries(_ ftsExtension: SmartStoreFtsExtension) {
        loadData(ftsExtension)

        guard let christineId = christineHaasId,
              let michaelId = michaelThompsonId,
              let aliId = aliHaasId,
              let evaId = evaPulaskiId,
              let eileenId = eileenEvaId else {
            XCTFail("Expected IDs to be set")
            return
        }

        // All fields - full word - no results
        trySearch([], path: nil, matchKey: "{employees:firstName}:Haas", orderPath: nil)

        // All fields - full word - one result
        trySearch([evaId], path: nil, matchKey: "{employees:firstName}:Eva", orderPath: nil)
        trySearch([eileenId], path: nil, matchKey: "{employees:lastName}:Eva", orderPath: nil)

        // All fields - full word - more than one results
        trySearch([christineId, aliId], path: nil, matchKey: "{employees:lastName}:Haas", orderPath: kEmployeeId)

        // All fields - prefix - more than one results
        trySearch([evaId, eileenId], path: nil, matchKey: "{employees:firstName}:E*", orderPath: kEmployeeId)
        trySearch([christineId, aliId], path: nil, matchKey: "{employees:lastName}:H*", orderPath: kEmployeeId)

        // All fields - set operation - more than result
        trySearch([michaelId, aliId], path: nil, matchKey: "{employees:lastName}:Thompson OR {employees:firstName}:Ali", orderPath: kEmployeeId)
        trySearch([aliId, michaelId], path: nil, matchKey: "{employees:lastName}:Thompson OR {employees:firstName}:Ali", orderPath: kFirstName)
        trySearch([christineId, eileenId], path: nil, matchKey: "{employees:lastName}:Eva OR Haas NOT Ali", orderPath: kEmployeeId)
        trySearch([eileenId, christineId], path: nil, matchKey: "{employees:lastName}:Eva OR Haas NOT Ali", orderPath: kLastName)
    }

    // MARK: - Helper Methods

    private func trySearch(_ expectedIds: [NSNumber], path: String?, matchKey: String, orderPath: String?) {
        // Returning soup elements
        let querySpec = QuerySpec.buildMatchQuerySpec(soupName: kEmployeesSoup, path: path ?? "", matchKey: matchKey, orderPath: orderPath ?? "", order: .ascending, pageSize: 25)
        let results = (try? store.query(using: querySpec, startingFromPageIndex: 0)) ?? []
        XCTAssertEqual(expectedIds.count, results.count, "Wrong number of results")
        for i in 0..<results.count {
            if let resultDict = results[i] as? [String: Any],
               let resultId = resultDict[SmartStoreConstants.soupEntryId] as? NSNumber {
                XCTAssertEqual(expectedIds[i].intValue, resultId.intValue, "Wrong results for match query returning soup elements")
            }
        }

        // Returning just id
        guard let querySpecWithPaths = QuerySpec.buildMatchQuerySpec(soupName: kEmployeesSoup, selectPaths: [SmartStoreConstants.soupEntryId], path: path ?? "", matchKey: matchKey, orderPath: orderPath ?? "", order: .ascending, pageSize: 25) else {
            XCTFail("Failed to build query spec with select paths")
            return
        }
        let resultsWithPaths = (try? store.query(using: querySpecWithPaths, startingFromPageIndex: 0)) ?? []
        XCTAssertEqual(expectedIds.count, resultsWithPaths.count, "Wrong number of results")
        for i in 0..<resultsWithPaths.count {
            if let row = resultsWithPaths[i] as? [Any], let resultId = row[0] as? NSNumber {
                XCTAssertEqual(expectedIds[i].intValue, resultId.intValue, "Wrong results for match query with selectPaths")
            }
        }
    }

    private func loadData(_ ftsExtension: SmartStoreFtsExtension) {
        setupSoup(ftsExtension)

        christineHaasId = createEmployee(firstName: "Christine", lastName: "Haas", employeeId: "00010")[SmartStoreConstants.soupEntryId] as? NSNumber
        michaelThompsonId = createEmployee(firstName: "Michael", lastName: "Thompson", employeeId: "00020")[SmartStoreConstants.soupEntryId] as? NSNumber
        aliHaasId = createEmployee(firstName: "Ali", lastName: "Haas", employeeId: "00030")[SmartStoreConstants.soupEntryId] as? NSNumber
        johnGeyerId = createEmployee(firstName: "John", lastName: "Geyer", employeeId: "00040")[SmartStoreConstants.soupEntryId] as? NSNumber
        irvingSternId = createEmployee(firstName: "Irving", lastName: "Stern", employeeId: "00050")[SmartStoreConstants.soupEntryId] as? NSNumber
        evaPulaskiId = createEmployee(firstName: "Eva", lastName: "Pulaski", employeeId: "00060")[SmartStoreConstants.soupEntryId] as? NSNumber
        eileenEvaId = createEmployee(firstName: "Eileen", lastName: "Eva", employeeId: "00070")[SmartStoreConstants.soupEntryId] as? NSNumber
    }

    @discardableResult
    private func createEmployee(firstName: String, lastName: String, employeeId: String) -> [String: Any] {
        let employee: [String: Any] = [kFirstName: firstName, kLastName: lastName, kEmployeeId: employeeId]
        let results = store.upsert(entries: [employee], forSoupNamed: kEmployeesSoup)
        guard let first = results.first else {
            XCTFail("Expected upsert to return at least one entry")
            return employee
        }
        return first
    }

    private func updateEmployee(firstName: String, lastName: String, employeeId: String, soupEntryId: NSNumber) -> [String: Any] {
        let employee: [String: Any] = [SmartStoreConstants.soupEntryId: soupEntryId, kFirstName: firstName, kLastName: lastName, kEmployeeId: employeeId]
        let results = store.upsert(entries: [employee], forSoupNamed: kEmployeesSoup)
        guard let first = results.first else {
            XCTFail("Expected upsert to return at least one entry")
            return employee
        }
        return first
    }
}
