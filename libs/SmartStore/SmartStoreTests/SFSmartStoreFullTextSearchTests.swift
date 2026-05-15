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

private let kTestStore = "testSmartStoreFullTextSearchStore"
private let kEmployeesSoup = "employees"
private let kFirstName = "firstName"
private let kLastName = "lastName"
private let kEmployeeId = "employeeId"

class SFSmartStoreFullTextSearchTests: SFSmartStoreTestCase {

    private var store: SmartStore!
    private var christineHaasId: NSNumber!
    private var michaelThompsonId: NSNumber!
    private var aliHaasId: NSNumber!
    private var johnGeyerId: NSNumber!
    private var irvingSternId: NSNumber!
    private var evaPulaskiId: NSNumber!
    private var eileenEvaId: NSNumber!

    // MARK: - setup and teardown

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
        let soupIndices = SoupIndex.asArray([
            createFullTextIndexSpec(kFirstName),    // should be TABLE_1_0
            createFullTextIndexSpec(kLastName),     // should be TABLE_1_1
            createStringIndexSpec(kEmployeeId)      // should be TABLE_1_2
        ])
        try! store.registerSoup(withName: kEmployeesSoup, withIndices: soupIndices)
    }

    // MARK: - Tests

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
        XCTAssertTrue(store.soupExists(forName: kEmployeesSoup), "Register soup failed")

        let expectedCreateSql = "CREATE VIRTUAL TABLE TABLE_1_fts USING fts\(ftsExtension.rawValue)"
        checkCreateTableStatement("TABLE_1_fts", expectedSqlStatementPrefix: expectedCreateSql, store: store)

        // Drop
        store.removeSoup(kEmployeesSoup)

        // After
        XCTAssertFalse(store.soupExists(forName: kEmployeesSoup), "Soup employees should no longer exist")
        XCTAssertNil(getSoupTableName(kEmployeesSoup, store: store), "Soup employees should no longer exist")
        XCTAssertFalse(hasTable("TABLE_1", store: store), "Table for soup employees should not exit")
        XCTAssertFalse(hasTable("TABLE_1_fts", store: store), "FTS Table for soup employees should not exit")
    }

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
        store.storeQueue.inDatabase { db in
            let frs = self.store.queryTable("TABLE_1", forColumns: nil, orderBy: "id ASC", limit: nil, whereClause: nil, whereArgs: nil, with: db)
            self.checkSoupRow(frs!, withExpectedEntry: firstEmployee, withSoupIndexes: actualIndexSpecs)
            self.checkSoupRow(frs!, withExpectedEntry: secondEmployee, withSoupIndexes: actualIndexSpecs)
            XCTAssertFalse(frs!.next(), "Only two rows should have been returned")
            frs!.close()
        }

        // Check fts table
        store.storeQueue.inDatabase { db in
            let frs = self.store.queryTable("TABLE_1_fts", forColumns: [ROWID_COL, "TABLE_1_0", "TABLE_1_1"], orderBy: "rowid ASC", limit: nil, whereClause: nil, whereArgs: nil, with: db)
            self.checkFtsRow(frs!, withExpectedEntry: firstEmployee, withSoupIndexes: actualIndexSpecs)
            self.checkFtsRow(frs!, withExpectedEntry: secondEmployee, withSoupIndexes: actualIndexSpecs)
            XCTAssertFalse(frs!.next(), "Only two rows should have been returned")
            frs!.close()
        }
    }

    func testUpdateWithFts4() {
        tryUpdate(.fts4)
    }

    func testUpdateWithFts5() {
        tryUpdate(.fts5)
    }

    private func tryUpdate(_ ftsExtension: SmartStoreFtsExtension) {
        setupSoup(ftsExtension)

        // Insert a couple of rows
        let firstEmployee = createEmployee(firstName: "Christine", lastName: "Haas", employeeId: "00010")
        let secondEmployee = createEmployee(firstName: "Michael", lastName: "Thompson", employeeId: "00020")

        // Getting index specs from db
        let actualIndexSpecs = store.indices(forSoupNamed: kEmployeesSoup)

        // Update second employee
        let secondEmployeeUpdated = updateEmployee(firstName: "Michael-updated", lastName: "Thompson", employeeId: "00020-updated", soupEntryId: secondEmployee[SOUP_ENTRY_ID] as! NSNumber)

        // Check soup table
        store.storeQueue.inDatabase { db in
            let frs = self.store.queryTable("TABLE_1", forColumns: nil, orderBy: "id ASC", limit: nil, whereClause: nil, whereArgs: nil, with: db)
            self.checkSoupRow(frs!, withExpectedEntry: firstEmployee, withSoupIndexes: actualIndexSpecs)
            self.checkSoupRow(frs!, withExpectedEntry: secondEmployeeUpdated, withSoupIndexes: actualIndexSpecs)
            XCTAssertFalse(frs!.next(), "Only two rows should have been returned")
            frs!.close()
        }

        // Check fts table
        store.storeQueue.inDatabase { db in
            let frs = self.store.queryTable("TABLE_1_fts", forColumns: [ROWID_COL, "TABLE_1_0", "TABLE_1_1"], orderBy: "rowid ASC", limit: nil, whereClause: nil, whereArgs: nil, with: db)
            self.checkFtsRow(frs!, withExpectedEntry: firstEmployee, withSoupIndexes: actualIndexSpecs)
            self.checkFtsRow(frs!, withExpectedEntry: secondEmployeeUpdated, withSoupIndexes: actualIndexSpecs)
            XCTAssertFalse(frs!.next(), "Only two rows should have been returned")
            frs!.close()
        }
    }

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
        try! store.remove(entryIds: [firstEmployee[SOUP_ENTRY_ID] as! NSNumber], forSoupNamed: kEmployeesSoup)

        // Check soup table
        store.storeQueue.inDatabase { db in
            let frs = self.store.queryTable("TABLE_1", forColumns: nil, orderBy: "id ASC", limit: nil, whereClause: nil, whereArgs: nil, with: db)
            self.checkSoupRow(frs!, withExpectedEntry: secondEmployee, withSoupIndexes: actualIndexSpecs)
            XCTAssertFalse(frs!.next(), "Only one row should have been returned")
            frs!.close()
        }

        // Check fts table
        store.storeQueue.inDatabase { db in
            let frs = self.store.queryTable("TABLE_1_fts", forColumns: [ROWID_COL, "TABLE_1_0", "TABLE_1_1"], orderBy: "rowid ASC", limit: nil, whereClause: nil, whereArgs: nil, with: db)
            self.checkFtsRow(frs!, withExpectedEntry: secondEmployee, withSoupIndexes: actualIndexSpecs)
            XCTAssertFalse(frs!.next(), "Only one should have been returned")
            frs!.close()
        }

        // Delete second employee
        try! store.remove(entryIds: [secondEmployee[SOUP_ENTRY_ID] as! NSNumber], forSoupNamed: kEmployeesSoup)

        // Check soup table
        store.storeQueue.inDatabase { db in
            let frs = self.store.queryTable("TABLE_1", forColumns: nil, orderBy: "id ASC", limit: nil, whereClause: nil, whereArgs: nil, with: db)
            XCTAssertFalse(frs!.next(), "No rows should have been returned")
            frs!.close()
        }

        // Check fts table
        store.storeQueue.inDatabase { db in
            let frs = self.store.queryTable("TABLE_1_fts", forColumns: [ROWID_COL, "TABLE_1_0", "TABLE_1_1"], orderBy: "rowid ASC", limit: nil, whereClause: nil, whereArgs: nil, with: db)
            XCTAssertFalse(frs!.next(), "No rows should have been returned")
            frs!.close()
        }
    }

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
        store.storeQueue.inDatabase { db in
            let frs = self.store.queryTable("TABLE_1", forColumns: nil, orderBy: "id ASC", limit: nil, whereClause: nil, whereArgs: nil, with: db)
            XCTAssertFalse(frs!.next(), "No rows should have been returned")
            frs!.close()
        }

        // Check fts table
        store.storeQueue.inDatabase { db in
            let frs = self.store.queryTable("TABLE_1_fts", forColumns: [ROWID_COL, "TABLE_1_0", "TABLE_1_1"], orderBy: "rowid ASC", limit: nil, whereClause: nil, whereArgs: nil, with: db)
            XCTAssertFalse(frs!.next(), "No rows should have been returned")
            frs!.close()
        }
    }

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

    func testSearchSingleFieldSingleResultWithFts4() {
        trySearchSingleFieldSingleResult(.fts4)
    }

    func testSearchSingleFieldSingleResultWithFts5() {
        trySearchSingleFieldSingleResult(.fts5)
    }

    private func trySearchSingleFieldSingleResult(_ ftsExtension: SmartStoreFtsExtension) {
        loadData(ftsExtension)

        // One field - full word - one result
        trySearch([christineHaasId], path: kFirstName, matchKey: "Christine", orderPath: nil)
        trySearch([irvingSternId], path: kLastName, matchKey: "Stern", orderPath: nil)

        // One field - prefix - one result
        trySearch([christineHaasId], path: kFirstName, matchKey: "Christ*", orderPath: nil)
        trySearch([irvingSternId], path: kLastName, matchKey: "Ste*", orderPath: nil)

        // One field - set operation - one result
        trySearch([eileenEvaId], path: kFirstName, matchKey: "E* NOT Eva", orderPath: nil)
    }

    func testSearchSingleFieldMultipleResultsWithFts4() {
        trySearchSingleFieldMultipleResults(.fts4)
    }

    func testSearchSingleFieldMultipleResultsWithFts5() {
        trySearchSingleFieldMultipleResults(.fts5)
    }

    private func trySearchSingleFieldMultipleResults(_ ftsExtension: SmartStoreFtsExtension) {
        loadData(ftsExtension)

        // One field - full word - more than one results
        trySearch([christineHaasId, aliHaasId], path: kLastName, matchKey: "Haas", orderPath: kEmployeeId)
        trySearch([aliHaasId, christineHaasId], path: kLastName, matchKey: "Haas", orderPath: kFirstName)

        // One field - prefix - more than one results
        trySearch([evaPulaskiId, eileenEvaId], path: kFirstName, matchKey: "E*", orderPath: kEmployeeId)
        trySearch([eileenEvaId, evaPulaskiId], path: kFirstName, matchKey: "E*", orderPath: kFirstName)

        // One field - set operation - more than one results
        trySearch([evaPulaskiId, eileenEvaId], path: kFirstName, matchKey: "Eva OR Eileen", orderPath: kEmployeeId)
        trySearch([eileenEvaId, evaPulaskiId], path: kFirstName, matchKey: "Eva OR Eileen", orderPath: kFirstName)
    }

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

    func testSearchAllFieldsSingleResultWithFts4() {
        trySearchAllFieldsSingleResult(.fts4)
    }

    func testSearchAllFieldsSingleResultWithFts5() {
        trySearchAllFieldsSingleResult(.fts5)
    }

    private func trySearchAllFieldsSingleResult(_ ftsExtension: SmartStoreFtsExtension) {
        loadData(ftsExtension)

        // All fields - full word - one result
        trySearch([irvingSternId], path: nil, matchKey: "Stern", orderPath: nil)

        // All fields - prefix - one result
        trySearch([irvingSternId], path: nil, matchKey: "St*", orderPath: nil)

        // All fields - multiple words - one result
        trySearch([christineHaasId], path: nil, matchKey: "Haas Christine", orderPath: nil)

        // All fields - set operation - one result
        trySearch([aliHaasId], path: nil, matchKey: "Haas NOT Christine", orderPath: nil)
    }

    func testSearchAllFieldMultipleResultsWithFts4() {
        trySearchAllFieldMultipleResults(.fts4)
    }

    func testSearchAllFieldMultipleResultsWithFts5() {
        trySearchAllFieldMultipleResults(.fts5)
    }

    private func trySearchAllFieldMultipleResults(_ ftsExtension: SmartStoreFtsExtension) {
        loadData(ftsExtension)

        // All fields - full word - more than one results
        trySearch([evaPulaskiId, eileenEvaId], path: nil, matchKey: "Eva", orderPath: kEmployeeId)
        trySearch([eileenEvaId, evaPulaskiId], path: nil, matchKey: "Eva", orderPath: kLastName)

        // All fields - prefix - more than one results
        trySearch([evaPulaskiId, eileenEvaId], path: nil, matchKey: "Ev*", orderPath: kEmployeeId)
        trySearch([eileenEvaId, evaPulaskiId], path: nil, matchKey: "Ev*", orderPath: kLastName)

        // All fields - set operation - more than result
        trySearch([michaelThompsonId, aliHaasId], path: nil, matchKey: "Thompson OR Ali", orderPath: kEmployeeId)
        trySearch([aliHaasId, michaelThompsonId], path: nil, matchKey: "Thompson OR Ali", orderPath: kFirstName)
        trySearch([christineHaasId, evaPulaskiId, eileenEvaId], path: nil, matchKey: "Eva OR Haas NOT Ali", orderPath: kEmployeeId)
        trySearch([christineHaasId, eileenEvaId, evaPulaskiId], path: nil, matchKey: "Eva OR Haas NOT Ali", orderPath: kFirstName)
    }

    func testSearchWithFieldColonQueriesWithFts4() {
        trySearchWithFieldColonQueries(.fts4)
    }

    func testSearchWithFieldColonQueriesWithFts5() {
        trySearchWithFieldColonQueries(.fts5)
    }

    private func trySearchWithFieldColonQueries(_ ftsExtension: SmartStoreFtsExtension) {
        loadData(ftsExtension)

        // All fields - full word - no results
        trySearch([], path: nil, matchKey: "{employees:firstName}:Haas", orderPath: nil)

        // All fields - full word - one result
        trySearch([evaPulaskiId], path: nil, matchKey: "{employees:firstName}:Eva", orderPath: nil)
        trySearch([eileenEvaId], path: nil, matchKey: "{employees:lastName}:Eva", orderPath: nil)

        // All fields - full word - more than one results
        trySearch([christineHaasId, aliHaasId], path: nil, matchKey: "{employees:lastName}:Haas", orderPath: kEmployeeId)

        // All fields - prefix - more than one results
        trySearch([evaPulaskiId, eileenEvaId], path: nil, matchKey: "{employees:firstName}:E*", orderPath: kEmployeeId)
        trySearch([christineHaasId, aliHaasId], path: nil, matchKey: "{employees:lastName}:H*", orderPath: kEmployeeId)

        // All fields - set operation - more than result
        trySearch([michaelThompsonId, aliHaasId], path: nil, matchKey: "{employees:lastName}:Thompson OR {employees:firstName}:Ali", orderPath: kEmployeeId)
        trySearch([aliHaasId, michaelThompsonId], path: nil, matchKey: "{employees:lastName}:Thompson OR {employees:firstName}:Ali", orderPath: kFirstName)
        trySearch([christineHaasId, eileenEvaId], path: nil, matchKey: "{employees:lastName}:Eva OR Haas NOT Ali", orderPath: kEmployeeId)
        trySearch([eileenEvaId, christineHaasId], path: nil, matchKey: "{employees:lastName}:Eva OR Haas NOT Ali", orderPath: kLastName)
    }

    // MARK: - helper methods

    private func trySearch(_ expectedIds: [NSNumber], path: String?, matchKey: String, orderPath: String?) {
        // Returning soup elements
        let querySpec = QuerySpec.buildMatchQuerySpec(soupName: kEmployeesSoup, path: path ?? "", matchKey: matchKey, orderPath: orderPath ?? "", order: .ascending, pageSize: 25)
        let results = try! store.query(using: querySpec, startingFromPageIndex: 0) as! [[String: Any]]
        XCTAssertEqual(expectedIds.count, results.count, "Wrong number of results")
        for i in 0..<results.count {
            XCTAssertEqual(expectedIds[i].intValue, (results[i][SOUP_ENTRY_ID] as? NSNumber)?.intValue, "Wrong results for match query returning soup elements")
        }

        // Returning just id
        let querySpecWithSelect = QuerySpec.buildMatchQuerySpec(soupName: kEmployeesSoup, selectPaths: [SOUP_ENTRY_ID], path: path ?? "", matchKey: matchKey, orderPath: orderPath ?? "", order: .ascending, pageSize: 25)!
        let results2 = try! store.query(using: querySpecWithSelect, startingFromPageIndex: 0) as! [[Any]]
        XCTAssertEqual(expectedIds.count, results2.count, "Wrong number of results")
        for i in 0..<results2.count {
            XCTAssertEqual(expectedIds[i].intValue, (results2[i][0] as? NSNumber)?.intValue, "Wrong results for match query with selectPaths")
        }
    }

    private func loadData(_ ftsExtension: SmartStoreFtsExtension) {
        setupSoup(ftsExtension)

        christineHaasId = createEmployee(firstName: "Christine", lastName: "Haas", employeeId: "00010")[SOUP_ENTRY_ID] as? NSNumber
        michaelThompsonId = createEmployee(firstName: "Michael", lastName: "Thompson", employeeId: "00020")[SOUP_ENTRY_ID] as? NSNumber
        aliHaasId = createEmployee(firstName: "Ali", lastName: "Haas", employeeId: "00030")[SOUP_ENTRY_ID] as? NSNumber
        johnGeyerId = createEmployee(firstName: "John", lastName: "Geyer", employeeId: "00040")[SOUP_ENTRY_ID] as? NSNumber
        irvingSternId = createEmployee(firstName: "Irving", lastName: "Stern", employeeId: "00050")[SOUP_ENTRY_ID] as? NSNumber
        evaPulaskiId = createEmployee(firstName: "Eva", lastName: "Pulaski", employeeId: "00060")[SOUP_ENTRY_ID] as? NSNumber
        eileenEvaId = createEmployee(firstName: "Eileen", lastName: "Eva", employeeId: "00070")[SOUP_ENTRY_ID] as? NSNumber
    }

    @discardableResult
    private func createEmployee(firstName: String, lastName: String, employeeId: String) -> [String: Any] {
        let employee: NSDictionary = [kFirstName: firstName, kLastName: lastName, kEmployeeId: employeeId]
        return store.upsert(entries: [employee], forSoupNamed: kEmployeesSoup)[0] as! [String: Any]
    }

    private func updateEmployee(firstName: String, lastName: String, employeeId: String, soupEntryId: NSNumber) -> [String: Any] {
        let employee: NSDictionary = [SOUP_ENTRY_ID: soupEntryId, kFirstName: firstName, kLastName: lastName, kEmployeeId: employeeId]
        return store.upsert(entries: [employee], forSoupNamed: kEmployeesSoup)[0] as! [String: Any]
    }
}
