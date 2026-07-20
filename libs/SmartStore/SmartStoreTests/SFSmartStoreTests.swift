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

import XCTest
import FMDB
import SalesforceSDKCommon
@testable import SalesforceSDKCore
@testable import SmartStore
import SQLCipher

class SFSmartStoreTests: SFSmartStoreTestCase {

    // MARK: - Properties

    private let kTestSmartStoreName = "testSmartStore"
    private let kTestSoupName = "testSoup"

    var smartStoreUser: UserAccount?
    var store: SmartStore?
    var globalStore: SmartStore?

    // MARK: - Setup and Teardown

    override func setUp() {
        super.setUp()
        SmartStoreLogger.setLogLevel(.debug)
        smartStoreUser = setUpSmartStoreUser()
        store = SmartStore.shared(withName: kTestSmartStoreName)
        globalStore = SmartStore.sharedGlobal(withName: kTestSmartStoreName)
        store?.capturesExplainQueryPlan = true
        globalStore?.capturesExplainQueryPlan = true
    }

    override func tearDown() {
        SmartStore.removeShared(withName: kTestSmartStoreName)
        SmartStore.removeSharedGlobal(withName: kTestSmartStoreName)
        if let user = smartStoreUser {
            tearDownSmartStoreUser(user)
        }
        super.tearDown()

        smartStoreUser = nil
        store = nil
        globalStore = nil
    }

    // MARK: - Tests

    /// Test to check compile options
    func testCompileOptions() {
        guard let store = store else { return XCTFail("Store should not be nil") }
        let options = store.compileOptions() as? [String] ?? []

        XCTAssertTrue(options.contains("ENABLE_FTS4"))
        XCTAssertTrue(options.contains("ENABLE_FTS3_PARENTHESIS"))
        XCTAssertTrue(options.contains("ENABLE_FTS5"))
    }

    /// Test to check runtime settings
    func testRuntimeSettings() {
        guard let store = store else { return XCTFail("Store should not be nil") }
        let settings = store.runtimeSettings() as? [String] ?? []

        // Make sure run time settings are 4.x settings except for kdf_iter
        XCTAssertTrue(settings.contains("PRAGMA kdf_iter = 4000;"))
        XCTAssertTrue(settings.contains("PRAGMA cipher_page_size = 4096;"))
        XCTAssertTrue(settings.contains("PRAGMA cipher_use_hmac = 1;"))
        XCTAssertTrue(settings.contains("PRAGMA cipher_plaintext_header_size = 0;"))
        XCTAssertTrue(settings.contains("PRAGMA cipher_hmac_algorithm = HMAC_SHA512;"))
        XCTAssertTrue(settings.contains("PRAGMA cipher_kdf_algorithm = PBKDF2_HMAC_SHA512;"))
    }

    func testSqliteVersion() {
        let version = String(cString: sqlite3_libversion())
        XCTAssertEqual(version, "3.53.3")
    }

    func testSqlCipherVersion() {
        guard let store = store else { return XCTFail("Store should not be nil") }
        let version = store.versionOfSQLCipher()
        XCTAssertEqual(version, "4.17.0 community")
    }

    func testCipherProviderVersion() {
        guard let store = store else { return XCTFail("Store should not be nil") }
        let cipherProviderVersion = store.cipherProviderVersion()
        XCTAssertFalse(cipherProviderVersion.isEmpty, "cipherProviderVersion should not be an empty string")
    }

    func testCipherFIPSStatus() {
        guard let store = store else { return XCTFail("Store should not be nil") }
        let cipherFIPSStatus = store.cipherFIPSStatus()
        XCTAssertFalse(cipherFIPSStatus)
    }

    /// Test fts extension
    func testFtsExtension() {
        guard let store = store else { return XCTFail("Store should not be nil") }
        XCTAssertEqual(store.ftsExtension, .fts5, "Expected FTS5")
    }

    /// Testing method with paths to top level string/integer/array/map as well as edge cases (nil object/nil or empty path)
    func testProjectTopLevel() {
        let rawJson = "{\"a\":\"va\", \"b\":2, \"c\":[0,1,2], \"d\": {\"d1\":\"vd1\", \"d2\":\"vd2\", \"d3\":[1,2], \"d4\":{\"e\":5}}}"
        guard let json = SFJsonUtils.object(fromJSONString: rawJson) as? [String: Any] else {
            return XCTFail("Failed to parse JSON")
        }

        // Root object
        assertSameJSON(expected: json as NSDictionary, actual: SFJsonUtils.project(intoJson: json, path: "") as? NSDictionary, message: "Should have returned whole object")

        // Top-level elements
        assertSameJSON(expected: "va" as NSObject, actual: SFJsonUtils.project(intoJson: json, path: "a"), message: "Wrong value for key a")
        assertSameJSON(expected: 2 as NSObject, actual: SFJsonUtils.project(intoJson: json, path: "b"), message: "Wrong value for key b")
        assertSameJSON(expected: SFJsonUtils.object(fromJSONString: "[0,1,2]"), actual: SFJsonUtils.project(intoJson: json, path: "c"), message: "Wrong value for key c")
        assertSameJSON(expected: SFJsonUtils.object(fromJSONString: "{\"d1\":\"vd1\", \"d2\":\"vd2\", \"d3\":[1,2], \"d4\":{\"e\":5}}"), actual: SFJsonUtils.project(intoJson: json, path: "d"), message: "Wrong value for key d")
    }

    /// Testing method with paths to non-top level string/integer/array/map
    func testProjectNested() {
        let rawJson = "{\"a\":\"va\", \"b\":2, \"c\":[0,1,2], \"d\": {\"d1\":\"vd1\", \"d2\":\"vd2\", \"d3\":[1,2], \"d4\":{\"e\":5}}}"
        guard let json = SFJsonUtils.object(fromJSONString: rawJson) as? [String: Any] else {
            return XCTFail("Failed to parse JSON")
        }

        // Nested elements
        assertSameJSON(expected: "vd1" as NSObject, actual: SFJsonUtils.project(intoJson: json, path: "d.d1"), message: "Wrong value for key d.d1")
        assertSameJSON(expected: "vd2" as NSObject, actual: SFJsonUtils.project(intoJson: json, path: "d.d2"), message: "Wrong value for key d.d2")
        assertSameJSON(expected: SFJsonUtils.object(fromJSONString: "[1,2]"), actual: SFJsonUtils.project(intoJson: json, path: "d.d3"), message: "Wrong value for key d.d3")
        assertSameJSON(expected: SFJsonUtils.object(fromJSONString: "{\"e\":5}"), actual: SFJsonUtils.project(intoJson: json, path: "d.d4"), message: "Wrong value for key d.d4")
        assertSameJSON(expected: 5 as NSObject, actual: SFJsonUtils.project(intoJson: json, path: "d.d4.e"), message: "Wrong value for key d.d4.e")
    }

    /// Testing method with path through arrays
    func testProjectThroughArrays() {
        let rawJson = "{\"a\":\"a1\", \"b\":2, \"c\":[{\"cc\":\"cc1\"}, {\"cc\":2}, {\"cc\":[1,2,3]}, {}, {\"cc\":{\"cc5\":5}}], \"d\":[{\"dd\":[{\"ddd\":\"ddd11\"},{\"ddd\":\"ddd12\"}]}, {\"dd\":[{\"ddd\":\"ddd21\"}]}, {\"dd\":[{\"ddd\":\"ddd31\"},{\"ddd3\":\"ddd32\"}]}]}"
        guard let json = SFJsonUtils.object(fromJSONString: rawJson) as? [String: Any] else {
            return XCTFail("Failed to parse JSON")
        }

        assertSameJSON(expected: SFJsonUtils.object(fromJSONString: "[{\"cc\":\"cc1\"}, {\"cc\":2}, {\"cc\":[1,2,3]}, {}, {\"cc\":{\"cc5\":5}}]"), actual: SFJsonUtils.project(intoJson: json, path: "c"), message: "Wrong value for key c")

        assertSameJSON(expected: SFJsonUtils.object(fromJSONString: "[\"cc1\",2, [1,2,3], {\"cc5\":5}]"), actual: SFJsonUtils.project(intoJson: json, path: "c.cc"), message: "Wrong value for key c.cc")

        assertSameJSON(expected: SFJsonUtils.object(fromJSONString: "[5]"), actual: SFJsonUtils.project(intoJson: json, path: "c.cc.cc5"), message: "Wrong value for key c.cc.cc5")

        assertSameJSON(expected: SFJsonUtils.object(fromJSONString: "[{\"dd\":[{\"ddd\":\"ddd11\"},{\"ddd\":\"ddd12\"}]}, {\"dd\":[{\"ddd\":\"ddd21\"}]}, {\"dd\":[{\"ddd\":\"ddd31\"},{\"ddd3\":\"ddd32\"}]}]"), actual: SFJsonUtils.project(intoJson: json, path: "d"), message: "Wrong value for key d")

        assertSameJSON(expected: SFJsonUtils.object(fromJSONString: "[[{\"ddd\":\"ddd11\"},{\"ddd\":\"ddd12\"}], [{\"ddd\":\"ddd21\"}], [{\"ddd\":\"ddd31\"},{\"ddd3\":\"ddd32\"}]]"), actual: SFJsonUtils.project(intoJson: json, path: "d.dd"), message: "Wrong value for key d.dd")

        assertSameJSON(expected: SFJsonUtils.object(fromJSONString: "[[\"ddd11\",\"ddd12\"],[\"ddd21\"],[\"ddd31\"]]"), actual: SFJsonUtils.project(intoJson: json, path: "d.dd.ddd"), message: "Wrong value for key d.dd.ddd")

        assertSameJSON(expected: SFJsonUtils.object(fromJSONString: "[[\"ddd32\"]]"), actual: SFJsonUtils.project(intoJson: json, path: "d.dd.ddd3"), message: "Wrong value for key d.dd.ddd3")
    }

    /// Check that the meta data tables (soup index map and soup names) have been created
    func testMetaDataTablesCreated() {
        for store in stores() {
            let hasSoupIndexMapTable = hasTable("soup_index_map", store: store)
            XCTAssertTrue(hasSoupIndexMapTable, "Soup index map table not found")
            let hasTableSoupAttrs = hasTable("soup_attrs", store: store)
            XCTAssertTrue(hasTableSoupAttrs, "Soup attrs table not found")
        }
    }

    /// Test register/remove soup with only string indexes
    func testRegisterRemoveSoupWithStringIndexes() {
        tryRegisterRemoveSoup(indexType: kSoupIndexTypeString)
    }

    /// Test register/remove soup with json1 and string indexes
    func testRegisterRemoveSoupWithJSON1Indexes() {
        tryRegisterRemoveSoup(indexType: kSoupIndexTypeJSON1)
    }

    /// Test query when looking for all elements when soup has string index
    func testAllQueryWithStringIndex() {
        tryAllQuery(indexType: kSoupIndexTypeString)
    }

    /// Test query when looking for all elements when soup has json1 index
    func testAllQueryWithJSON1Index() {
        tryAllQuery(indexType: kSoupIndexTypeJSON1)
    }

    /// Test range query when soup has string index
    func testRangeQueryWithStringIndex() {
        tryRangeQuery(indexType: kSoupIndexTypeString)
    }

    /// Test range query when soup has json1 index
    func testRangeQueryWithJSON1Index() {
        tryRangeQuery(indexType: kSoupIndexTypeJSON1)
    }

    /// Test like query when soup has string index
    func testLikeQueryWithStringIndex() {
        tryLikeQuery(indexType: kSoupIndexTypeString)
    }

    /// Test like query when soup has json1 index
    func testLikeQueryWithJSON1Index() {
        tryLikeQuery(indexType: kSoupIndexTypeJSON1)
    }

    /// Test smart query when soup has string index
    func testSmartQueryWithStringIndex() {
        trySmartQuery(indexType: kSoupIndexTypeString)
    }

    /// Test smart query when soup has json1 index
    func testSmartQueryWithJSON1Index() {
        trySmartQuery(indexType: kSoupIndexTypeJSON1)
    }

    /// Test query against soup with special characters when soup has string index
    func testQueryDataWithSpecialCharactersWithStringIndex() {
        tryQueryDataWithSpecialCharacters(indexType: kSoupIndexTypeString)
    }

    /// Test query against soup with special characters when soup has json1 index
    func testQueryDataWithSpecialCharactersWithJSON1Index() {
        tryQueryDataWithSpecialCharacters(indexType: kSoupIndexTypeJSON1)
    }

    /// Test remove entries with ids
    func testRemoveEntriesByIds() {
        for store in stores() {
            // Before
            XCTAssertFalse(store.soupExists(kTestSoupName), "\(kTestSoupName) should not exist before registration.")

            // Register
            let indexSpecs = SoupIndex.asArraySoupIndexes([["path": "key", "type": kSoupIndexTypeString]])
            try? store.registerSoup(withName: kTestSoupName, withIndices: indexSpecs)
            let testSoupExists = store.soupExists(kTestSoupName)
            XCTAssertTrue(testSoupExists, "Soup \(kTestSoupName) should exist after registration.")

            // Populate soup
            let soupElt0: [String: Any] = ["key": "abcd", "value": "va1", "otherValue": "ova1"]
            let soupElt1: [String: Any] = ["key": "bbcd", "value": "va2", "otherValue": "ova2"]
            let soupElt2: [String: Any] = ["key": "abcc", "value": "va3", "otherValue": "ova3"]
            let soupElt3: [String: Any] = ["key": "defg", "value": "va1", "otherValue": "ova1"]

            let soupEltsCreated = store.upsert(entries: [soupElt0, soupElt1, soupElt2, soupElt3], forSoupNamed: kTestSoupName)

            // Remove two entries
            let id1 = soupEltsCreated[1][SmartStoreConstants.soupEntryId] as? NSNumber
            let id3 = soupEltsCreated[3][SmartStoreConstants.soupEntryId] as? NSNumber
            if let id1 = id1, let id3 = id3 {
                try? store.remove(entryIds: [id1, id3], forSoupNamed: kTestSoupName)
            }

            // Query all and make sure the two entries are gone
            runQueryCheckResultsAndExplainPlan(
                querySpec: QuerySpec.buildAllQuerySpec(soupName: kTestSoupName, orderPath: "key", order: .ascending, pageSize: 10),
                page: 0,
                expectedResults: [soupEltsCreated[2], soupEltsCreated[0]],
                covering: false,
                expectedDbOperation: "SCAN",
                store: store
            )

            // Remove one more entry
            let id0 = soupEltsCreated[0][SmartStoreConstants.soupEntryId] as? NSNumber
            if let id0 = id0 {
                try? store.remove(entryIds: [id0], forSoupNamed: kTestSoupName)
            }

            // Query all and make sure the removed entry is gone
            runQueryCheckResultsAndExplainPlan(
                querySpec: QuerySpec.buildAllQuerySpec(soupName: kTestSoupName, orderPath: "key", order: .ascending, pageSize: 10),
                page: 0,
                expectedResults: [soupEltsCreated[2]],
                covering: false,
                expectedDbOperation: "SCAN",
                store: store
            )
        }
    }

    /// Test remove entries by query
    func testRemoveEntriesByQuery() {
        for store in stores() {
            // Before
            XCTAssertFalse(store.soupExists(kTestSoupName), "\(kTestSoupName) should not exist before registration.")

            // Register
            let indexSpecs = SoupIndex.asArraySoupIndexes([["path": "key", "type": kSoupIndexTypeString]])
            try? store.registerSoup(withName: kTestSoupName, withIndices: indexSpecs)
            let testSoupExists = store.soupExists(kTestSoupName)
            XCTAssertTrue(testSoupExists, "Soup \(kTestSoupName) should exist after registration.")

            // Populate soup
            let soupElt0: [String: Any] = ["key": "abcd", "value": "va1", "otherValue": "ova1"]
            let soupElt1: [String: Any] = ["key": "bbcd", "value": "va2", "otherValue": "ova2"]
            let soupElt2: [String: Any] = ["key": "abcc", "value": "va3", "otherValue": "ova3"]
            let soupElt3: [String: Any] = ["key": "defg", "value": "va1", "otherValue": "ova1"]

            let soupEltsCreated = store.upsert(entries: [soupElt0, soupElt1, soupElt2, soupElt3], forSoupNamed: kTestSoupName)

            // Remove two entries
            let likeQuery = QuerySpec.buildLikeQuerySpec(soupName: kTestSoupName, path: "key", likeKey: "abc%", orderPath: "key", order: .ascending, pageSize: 10)
            try? store.removeEntries(usingQuerySpec: likeQuery, forSoupNamed: kTestSoupName)

            // Query all and make sure the removed entries are gone
            runQueryCheckResultsAndExplainPlan(
                querySpec: QuerySpec.buildAllQuerySpec(soupName: kTestSoupName, orderPath: "key", order: .ascending, pageSize: 10),
                page: 0,
                expectedResults: [soupEltsCreated[1], soupEltsCreated[3]],
                covering: false,
                expectedDbOperation: "SCAN",
                store: store
            )

            // Remove one more entry using a query all with page size of 1
            let allQuery = QuerySpec.buildAllQuerySpec(soupName: kTestSoupName, orderPath: "key", order: .ascending, pageSize: 1)
            try? store.removeEntries(usingQuerySpec: allQuery, forSoupNamed: kTestSoupName)

            // Query all and make sure the removed entry is gone
            runQueryCheckResultsAndExplainPlan(
                querySpec: QuerySpec.buildAllQuerySpec(soupName: kTestSoupName, orderPath: "key", order: .ascending, pageSize: 10),
                page: 0,
                expectedResults: [soupEltsCreated[3]],
                covering: false,
                expectedDbOperation: "SCAN",
                store: store
            )
        }
    }

    /// Test to verify an aggregate query on floating point values indexed as floating.
    func testAggregateQueryOnFloatingIndexedField() {
        tryAggregateQueryOnIndexedField(indexType: kSoupIndexTypeFloating)
    }

    /// Test to verify an aggregate query on floating point values indexed as JSON1.
    func testAggregateQueryOnJSON1IndexedField() {
        tryAggregateQueryOnIndexedField(indexType: kSoupIndexTypeJSON1)
    }

    /// Test smart sql returning entire soup elements (i.e. select {soup:_soup} from {soup})
    func testSelectUnderscoreSoup() {
        guard let store = store else { return XCTFail("Store should not be nil") }

        // Create soup
        let indexSpecs = SoupIndex.asArraySoupIndexes([["path": "key", "type": kSoupIndexTypeString]])
        try? store.registerSoup(withName: kTestSoupName, withIndices: indexSpecs)

        // Create soup elements
        let soupElt1: [String: Any] = ["key": "ka1", "value": "va1"]
        let soupElt2: [String: Any] = ["key": "ka2", "value": "va2"]
        let soupElt3: [String: Any] = ["key": "ka3", "value": "va3"]
        let soupElt4: [String: Any] = ["key": "ka4", "value": "va4"]
        let soupEltsCreated = store.upsert(entries: [soupElt1, soupElt2, soupElt3, soupElt4], forSoupNamed: kTestSoupName)

        // Query _soup
        let smartSql = "SELECT {\(kTestSoupName):_soup} FROM {\(kTestSoupName)} ORDER BY {\(kTestSoupName):key}"
        guard let querySpec = QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: 10) else {
            return XCTFail("Failed to build smart query spec")
        }
        runQueryCheckResultsAndExplainPlan(
            querySpec: querySpec,
            page: 0,
            expectedResults: [[soupEltsCreated[0]], [soupEltsCreated[1]], [soupEltsCreated[2]], [soupEltsCreated[3]]],
            covering: false,
            expectedDbOperation: "SCAN",
            store: store
        )
    }

    /// Test smart sql returning entire soup elements from multiple soups
    func testSelectUnderscoreSoupFromMultipleSoups() {
        guard let store = store else { return XCTFail("Store should not be nil") }

        // Create soups
        let otherTestSoupName = "otherTestSoup"
        let indexSpecs = SoupIndex.asArraySoupIndexes([["path": "key", "type": kSoupIndexTypeString]])
        try? store.registerSoup(withName: kTestSoupName, withIndices: indexSpecs)
        try? store.registerSoup(withName: otherTestSoupName, withIndices: indexSpecs)

        // Create soup elements
        let soupElt1: [String: Any] = ["key": "ka1", "value": "va1"]
        let soupElt1Created = store.upsert(entries: [soupElt1], forSoupNamed: kTestSoupName)[0]

        let soupElt2: [String: Any] = ["key": "ka1", "value": "va1", "otherValue": "ova1"]
        let soupElt2Created = store.upsert(entries: [soupElt2], forSoupNamed: otherTestSoupName)[0]

        // Query _soup from both soups
        let smartSql = "SELECT {\(kTestSoupName):_soup}, {\(otherTestSoupName):_soup} FROM {\(kTestSoupName)}, {\(otherTestSoupName)}"
        guard let querySpec = QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: 10) else {
            return XCTFail("Failed to build smart query spec")
        }
        runQueryCheckResultsAndExplainPlan(
            querySpec: querySpec,
            page: 0,
            expectedResults: [[soupElt1Created, soupElt2Created]],
            covering: false,
            expectedDbOperation: nil,
            store: store
        )
    }

    /// Test registering same soup name multiple times.
    func testMultipleRegisterSameSoup() {
        for store in stores() {
            // Before
            var testSoupExists = store.soupExists(kTestSoupName)
            XCTAssertFalse(testSoupExists, "Soup \(kTestSoupName) should not exist")

            // Register first time.
            let soupIndex: [String: Any] = ["path": "name", "type": "string"]
            let indexSpecs = SoupIndex.asArraySoupIndexes([soupIndex])
            try? store.registerSoup(withName: kTestSoupName, withIndices: indexSpecs)
            testSoupExists = store.soupExists(kTestSoupName)
            XCTAssertTrue(testSoupExists, "Soup \(kTestSoupName) should exist")

            // Register second time. Should only create one soup per unique soup name.
            try? store.registerSoup(withName: kTestSoupName, withIndices: indexSpecs)
            var rowCount: Int32 = 0
            store.storeQueue?.inDatabase { db in
                if let rs = db.executeQuery("SELECT COUNT(*) FROM soup_attrs WHERE soupName = ?", withArgumentsIn: [kTestSoupName]) {
                    if rs.next() { rowCount = rs.int(forColumnIndex: 0) }
                    rs.close()
                }
            }
            XCTAssertEqual(rowCount, 1, "Soup names should be unique within a store.")

            // Remove
            store.removeSoup(kTestSoupName)
            testSoupExists = store.soupExists(kTestSoupName)
            XCTAssertFalse(testSoupExists, "Soup \(kTestSoupName) should no longer exist")
        }
    }

    func testQuerySpecPageSize() {
        let allQueryNoPageSize: [String: Any] = [
            kQuerySpecParamQueryType: kQuerySpecTypeRange,
            kQuerySpecParamIndexPath: "a"
        ]

        let querySpec = QuerySpec(querySpec: allQueryNoPageSize, targetSoupName: kTestSoupName)
        let querySpecPageSize = querySpec?.pageSize ?? 0
        XCTAssertEqual(querySpecPageSize, kQuerySpecDefaultPageSize, "Page size value should be default, if not specified.")

        let expectedPageSize: UInt = 42
        let allQueryWithPageSize: [String: Any] = [
            kQuerySpecParamQueryType: kQuerySpecTypeRange,
            kQuerySpecParamIndexPath: "a",
            kQuerySpecParamPageSize: NSNumber(value: expectedPageSize)
        ]
        let querySpec2 = QuerySpec(querySpec: allQueryWithPageSize, targetSoupName: kTestSoupName)
        let querySpec2PageSize = querySpec2?.pageSize ?? 0
        XCTAssertEqual(querySpec2PageSize, expectedPageSize, "Page size value should reflect input value.")
    }

    func testPersistentStoreExists() {
        for dbMgr in databaseManagers() {
            let storeName = "xyzpdq"
            var persistentStoreExists = dbMgr.persistentStoreExists(storeName)
            XCTAssertFalse(persistentStoreExists, "Store should not exist at this point.")
            createDbDir(storeName, manager: dbMgr)
            let db = openDatabase(storeName, manager: dbMgr, key: "", openShouldFail: false)
            persistentStoreExists = dbMgr.persistentStoreExists(storeName)
            XCTAssertTrue(persistentStoreExists, "Store should exist after creation.")
            db?.close()
            dbMgr.removeStoreDir(storeName)
            persistentStoreExists = dbMgr.persistentStoreExists(storeName)
            XCTAssertFalse(persistentStoreExists, "Store should no longer exist at this point.")
        }
    }

    func testSmartStoreIsRecreatedWhenKeyIsLost() {
        let storeName = "testSmartStoreIsRecreatedWhenKeyIsLost"
        let keyLabel = "com.salesforce.keystore.\(SmartStoreConstants.encryptionKeyLabel)"
        let originalKey = KeychainHelper.read(service: keyLabel, account: nil).data
        // Oracle's @finally unconditionally restores + asserts success; assert we captured
        // the original key so the restore below is exercised (faithful to that contract).
        XCTAssertNotNil(originalKey, "Original encryption key should have been read before the test drops it")

        defer {
            // Drop store
            SmartStore.removeShared(withName: storeName)
            // Restore key
            if let originalKey = originalKey {
                let result = KeychainHelper.write(service: keyLabel, data: originalKey, account: nil)
                XCTAssertTrue(result.success)
            }
        }

        // Create store
        guard var storeInstance = SmartStore.shared(withName: storeName) else {
            return XCTFail("New store should have been created")
        }

        // Create soup in store
        registerTestSoup(store: storeInstance, indexType: kSoupIndexTypeString)

        // Close store
        storeInstance.storeQueue?.close()

        // Clear store map
        SmartStore.clearSharedStoreMemoryState()

        // Re-open store
        guard let storeInstance2 = SmartStore.shared(withName: storeName) else {
            return XCTFail("Existing store should have been found")
        }
        storeInstance = storeInstance2
        XCTAssertTrue(storeInstance.soupExists(kTestSoupName), "Soup should still exist")

        // Close store
        storeInstance.storeQueue?.close()

        // Clear store map
        SmartStore.clearSharedStoreMemoryState()

        // Drop key
        _ = KeyGenerator.removeEncryptionKey(for: SmartStoreConstants.encryptionKeyLabel)

        // Re-open store -- but expect new empty store since key has changed
        guard let storeInstance3 = SmartStore.shared(withName: storeName) else {
            return XCTFail("A store should have been returned")
        }
        XCTAssertFalse(storeInstance3.soupExists(kTestSoupName), "Soup should no longer exist")
    }

    func testOpenDatabase() {
        for dbMgr in databaseManagers() {
            // Create a new DB. Verify its emptiness.
            let storeName = "awesometown"
            createDbDir(storeName, manager: dbMgr)
            let createDb = openDatabase(storeName, manager: dbMgr, key: "", openShouldFail: false)
            var actualRowCount = rowCount(forTable: "sqlite_master", db: createDb)
            XCTAssertEqual(actualRowCount, 0, "\(storeName) should be a new database with no schema.")

            // Create a table, verify its addition to the DB.
            let tableName = "My_Table"
            createTestTable(tableName, db: createDb)
            actualRowCount = rowCount(forTable: "sqlite_master", db: createDb)
            XCTAssertEqual(actualRowCount, 1, "\(storeName) should now have one table in the DB schema.")

            // Close the current handle, open the database in another call, verify it has a previously-defined table.
            createDb?.close()
            let existingDb = openDatabase(storeName, manager: dbMgr, key: "", openShouldFail: false)
            actualRowCount = rowCount(forTable: "sqlite_master", db: existingDb)
            XCTAssertEqual(actualRowCount, 1, "Existing database \(storeName) should have one table in the DB schema.")

            existingDb?.close()
            dbMgr.removeStoreDir(storeName)
        }
    }

    func testEncryptDatabase() {
        let storeName = "nunyaBusiness"

        for dbMgr in databaseManagers() {
            // Create the unencrypted database, add a table.
            createDbDir(storeName, manager: dbMgr)
            let unencryptedDb = openDatabase(storeName, manager: dbMgr, key: "", openShouldFail: false)
            let tableName = "My_Table"
            createTestTable(tableName, db: unencryptedDb)
            var isTableNameInMaster = tableNameInMaster(tableName, db: unencryptedDb)
            XCTAssertTrue(isTableNameInMaster, "Table \(tableName) should have been added to sqlite_master.")

            // Encrypt the DB, verify access.
            let encKey = "BigSecret"
            guard let unencDb = unencryptedDb else {
                XCTFail("unencryptedDb should not be nil")
                continue
            }
            do {
                let encryptedDb = try dbMgr.encryptDb(unencDb, name: storeName, key: encKey, salt: nil)
                isTableNameInMaster = tableNameInMaster(tableName, db: encryptedDb)
                XCTAssertTrue(isTableNameInMaster, "Table \(tableName) should still exist in sqlite_master, for encrypted DB.")
                encryptedDb.close()
            } catch {
                XCTFail("Error encrypting the DB: \(error.localizedDescription)")
                continue
            }

            // Try to open the DB with an empty key, verify no read access.
            let encryptedDbEmptyKey = openDatabase(storeName, manager: dbMgr, key: "", openShouldFail: true)
            XCTAssertNil(encryptedDbEmptyKey, "Shouldn't be able to read encrypted database, opened as unencrypted.")
            encryptedDbEmptyKey?.close()

            // Try to read the encrypted database with the wrong key.
            let encryptedDbWrongKey = openDatabase(storeName, manager: dbMgr, key: "WrongKey", openShouldFail: true)
            XCTAssertNil(encryptedDbWrongKey, "Shouldn't be able to read encrypted database, opened with the wrong key.")
            encryptedDbWrongKey?.close()

            // Finally, try to re-open the encrypted database with the right key. Verify read access.
            let encryptedDbCorrectKey = openDatabase(storeName, manager: dbMgr, key: encKey, openShouldFail: false)
            isTableNameInMaster = tableNameInMaster(tableName, db: encryptedDbCorrectKey)
            XCTAssertTrue(isTableNameInMaster, "Should find the original table name in sqlite_master, with proper encryption key.")
            encryptedDbCorrectKey?.close()

            dbMgr.removeStoreDir(storeName)
        }
    }

    func testUnencryptDatabase() {
        let storeName = "lookAtThatData"

        for dbMgr in databaseManagers() {
            // Create the encrypted database, add a table.
            createDbDir(storeName, manager: dbMgr)
            let encKey = "GiantSecret"
            let encryptedDb = openDatabase(storeName, manager: dbMgr, key: encKey, openShouldFail: false)
            let tableName = "My_Table"
            createTestTable(tableName, db: encryptedDb)
            var isTableNameInMaster = tableNameInMaster(tableName, db: encryptedDb)
            XCTAssertTrue(isTableNameInMaster, "Table \(tableName) should have been added to sqlite_master.")
            encryptedDb?.close()

            // Verify that we can't read data with a plaintext DB open.
            let encryptedDbEmptyKey = openDatabase(storeName, manager: dbMgr, key: "", openShouldFail: true)
            XCTAssertNil(encryptedDbEmptyKey, "Shouldn't be able to read encrypted database, opened as unencrypted.")
            encryptedDbEmptyKey?.close()

            // Unencrypt the database, verify data.
            let encryptedDb2 = openDatabase(storeName, manager: dbMgr, key: encKey, openShouldFail: false)
            guard let encDb2 = encryptedDb2 else {
                XCTFail("encryptedDb2 should not be nil")
                continue
            }
            do {
                let unencryptedDb2 = try dbMgr.unencryptDb(encDb2, name: storeName, oldKey: encKey, salt: nil)
                isTableNameInMaster = tableNameInMaster(tableName, db: unencryptedDb2)
                XCTAssertTrue(isTableNameInMaster, "Table should be present in unencrypted DB.")
                unencryptedDb2.close()
            } catch {
                XCTFail("Error unencrypting the database: \(error.localizedDescription)")
                continue
            }

            // Open the database with no key, out of band. Verify data.
            let unencryptedDb3 = openDatabase(storeName, manager: dbMgr, key: "", openShouldFail: false)
            isTableNameInMaster = tableNameInMaster(tableName, db: unencryptedDb3)
            XCTAssertTrue(isTableNameInMaster, "Table should be present in unencrypted DB.")
            unencryptedDb3?.close()

            dbMgr.removeStoreDir(storeName)
        }
    }

    func testAllStoreNames() {
        // Test with no stores. (Note: Have to get rid of the 'default' store created at setup.)
        store = nil
        globalStore = nil
        SmartStore.removeShared(withName: kTestSmartStoreName)
        SmartStore.removeSharedGlobal(withName: kTestSmartStoreName)

        for dbMgr in databaseManagers() {
            let noStoresArray = dbMgr.allStoreNames()
            if let noStoresArray = noStoresArray {
                let expectedCount = noStoresArray.count
                XCTAssertEqual(expectedCount, 0, "There should not be any stores defined. Count = \(expectedCount)")
            }

            // Create some stores. Verify them.
            let numStores = Int(arc4random() % 20) + 1
            var initialStoreList = Set<String>()
            let tableName = "My_Table"
            for i in 0..<numStores {
                let storeName = "myStore\(i + 1)"
                createDbDir(storeName, manager: dbMgr)
                let db = openDatabase(storeName, manager: dbMgr, key: "", openShouldFail: false)
                createTestTable(tableName, db: db)
                db?.close()
                initialStoreList.insert(storeName)
            }
            let allStoresStoreList = Set(dbMgr.allStoreNames() ?? [])
            let setsAreEqual = initialStoreList == allStoresStoreList
            XCTAssertTrue(setsAreEqual, "Store list is not equal!")

            // Cleanup.
            for storeName in initialStoreList {
                dbMgr.removeStoreDir(storeName)
            }
        }
    }

    func testGetDatabaseSize() {
        for store in stores() {
            // Before
            let initialSize = store.databaseSize()

            // Register
            let soupIndex: [String: Any] = ["path": "name", "type": "string"]
            let indexSpecs = SoupIndex.asArraySoupIndexes([soupIndex])
            try? store.registerSoup(withName: kTestSoupName, withIndices: indexSpecs)

            // Upserts
            var entries: [[String: Any]] = []
            for i in 0..<100 {
                var soupElt: [String: Any] = [:]
                soupElt["name"] = "name_\(i)"
                soupElt["value"] = "value_\(i)"
                entries.append(soupElt)
            }
            _ = store.upsert(entries: entries, forSoupNamed: kTestSoupName)

            // After
            XCTAssertTrue(store.databaseSize() > initialSize, "Database size should be larger")
        }
    }

    func testReadMultiByteCharacterAroundBufferBoundary() {
        // This test ensures that a string containing a multi-byte character is properly read back
        // when that character is located at the buffer boundary.
        var text = ""
        // Fill the string up to one byte before the buffer ends
        for _ in 0..<(kBufferSize - 1) {
            text += "A"
        }
        // Let's use the character treble clef which uses 4 bytes (internally stored as UTF-16 surrogate pair)
        // and will span the buffer boundary
        text += "\u{1D11E}"
        // Add a few more characters after the buffer boundary
        for _ in 0..<125 {
            text += "B"
        }

        guard let data = text.data(using: .utf8) else {
            return XCTFail("Failed to encode text to UTF-8 data")
        }
        let inputStream = InputStream(data: data)

        let outputText = SmartStore.stringFromInputStream(inputStream)
        XCTAssertEqual(text, outputText)
    }

    /// Test running a valid query with StoreCursor
    func testValidQueryWithStoreCursor() {
        for store in stores() {
            // Register
            let soupIndex: [String: Any] = ["path": "key", "type": "string"]
            let indexSpecs = SoupIndex.asArraySoupIndexes([soupIndex])
            try? store.registerSoup(withName: kTestSoupName, withIndices: indexSpecs)

            // Populate soup
            let soupElt0: [String: Any] = ["key": "ka1", "value": "va1", "otherValue": "ova1"]
            let soupElt1: [String: Any] = ["key": "ka2", "value": "va2", "otherValue": "ova2"]
            let soupElt2: [String: Any] = ["key": "ka3", "value": "va3", "otherValue": "ova3"]

            _ = store.upsert(entries: [soupElt0, soupElt1, soupElt2], forSoupNamed: kTestSoupName)

            // Query spec
            let querySpec = QuerySpec.buildAllQuerySpec(soupName: kTestSoupName, orderPath: "key", order: .ascending, pageSize: 2)

            // Run query with cursor
            let cursor = StoreCursor(store: store, querySpec: querySpec)
            do {
                let serializedString = try cursor.getDataSerialized(store)
                guard let serializedCursorDeserialized = SFJsonUtils.object(fromJSONString: serializedString) as? [String: Any] else {
                    XCTFail("Failed to deserialize serialized cursor")
                    continue
                }
                let cursorDeserialized = try cursor.getDataDeserialized(store)

                // Check cursor
                XCTAssertEqual(cursor.pageSize, NSNumber(value: 2), "Wrong page size")
                XCTAssertEqual(cursor.currentPageIndex, NSNumber(value: 0), "Wrong page index")
                XCTAssertEqual(cursor.totalPages, NSNumber(value: 2), "Wrong total pages count")
                XCTAssertEqual(cursor.totalEntries, NSNumber(value: 3), "Wrong total entries count")

                // Check serialized cursor
                XCTAssertEqual(serializedCursorDeserialized["pageSize"] as? Int, 2, "Wrong page size")
                XCTAssertEqual(serializedCursorDeserialized["currentPageIndex"] as? Int, 0, "Wrong page index")
                XCTAssertEqual(serializedCursorDeserialized["totalPages"] as? Int, 2, "Wrong total pages count")
                XCTAssertEqual(serializedCursorDeserialized["totalEntries"] as? Int, 3, "Wrong total entries count")
                if let currentPageOrderedEntries = serializedCursorDeserialized["currentPageOrderedEntries"] as? [[String: Any]] {
                    XCTAssertEqual(currentPageOrderedEntries.count, 2, "Wrong entries count in page")
                    XCTAssertEqual(currentPageOrderedEntries[0]["key"] as? String, "ka1", "Wrong first entry")
                    XCTAssertEqual(currentPageOrderedEntries[1]["key"] as? String, "ka2", "Wrong second entry")
                } else {
                    XCTFail("currentPageOrderedEntries should not be nil")
                }

                // Check deserialized cursor
                XCTAssertEqual(cursorDeserialized["pageSize"] as? Int, 2, "Wrong page size")
                XCTAssertEqual(cursorDeserialized["currentPageIndex"] as? Int, 0, "Wrong page index")
                XCTAssertEqual(cursorDeserialized["totalPages"] as? Int, 2, "Wrong total pages count")
                XCTAssertEqual(cursorDeserialized["totalEntries"] as? Int, 3, "Wrong total entries count")
                if let currentPageOrderedEntries = cursorDeserialized["currentPageOrderedEntries"] as? [[String: Any]] {
                    XCTAssertEqual(currentPageOrderedEntries.count, 2, "Wrong entries count in page")
                    XCTAssertEqual(currentPageOrderedEntries[0]["key"] as? String, "ka1", "Wrong first entry")
                    XCTAssertEqual(currentPageOrderedEntries[1]["key"] as? String, "ka2", "Wrong second entry")
                } else {
                    XCTFail("currentPageOrderedEntries should not be nil")
                }
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    /// Test running an invalid query with StoreCursor
    func testInvalidQueryWithStoreCursor() {
        for store in stores() {
            // Make sure soup does NOT exist
            XCTAssertFalse(store.soupExists(kTestSoupName))

            // Query spec
            let querySpec = QuerySpec.buildAllQuerySpec(soupName: kTestSoupName, orderPath: "key", order: .ascending, pageSize: 2)

            let cursor = StoreCursor(store: store, querySpec: querySpec)

            // Run query by getting serialized data from cursor
            do {
                _ = try cursor.getDataSerialized(store)
                XCTFail("Error expected")
            } catch {
                // Expected
            }

            // Run query by getting deserialized data from cursor
            do {
                _ = try cursor.getDataDeserialized(store)
                XCTFail("Error expected")
            } catch {
                // Expected
            }
        }
    }

    /// Test running an invalid query with StoreCursor while JSON checks are on
    /// Make sure we do NOT get a notification for a JSON parsing error
    func testInvalidQueryWithStoreCursorWithRawJsonCheckOn() {
        SmartStore.jsonSerializationCheckEnabled = true
        defer { SmartStore.jsonSerializationCheckEnabled = false }

        for store in stores() {
            // Make sure soup does NOT exist
            XCTAssertFalse(store.soupExists(kTestSoupName))

            // Query spec
            let querySpec = QuerySpec.buildAllQuerySpec(soupName: kTestSoupName, orderPath: "key", order: .ascending, pageSize: 2)

            // Setup notification observer
            let expectation = XCTestExpectation(description: "JSON parse error notification")
            expectation.isInverted = true // not supposed to be fulfilled
            let observer = NotificationCenter.default.addObserver(
                forName: Notification.Name(SmartStoreConstants.jsonParseErrorNotification),
                object: nil,
                queue: nil
            ) { _ in
                expectation.fulfill()
            }

            // Run query with cursor
            let cursor = StoreCursor(store: store, querySpec: querySpec)
            do {
                _ = try cursor.getDataSerialized(store)
                XCTFail("Error expected")
            } catch {
                // Expected
            }

            // Wait for notification (timeout expected)
            wait(for: [expectation], timeout: 1)

            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Private Helpers

    private func stores() -> [SmartStore] {
        var result: [SmartStore] = []
        if let s = store { result.append(s) }
        if let g = globalStore { result.append(g) }
        return result
    }

    private func databaseManagers() -> [SmartStoreDatabaseManager] {
        var managers: [SmartStoreDatabaseManager] = []
        if let shared = SmartStoreDatabaseManager.shared() {
            managers.append(shared)
        }
        managers.append(SmartStoreDatabaseManager.sharedGlobal())
        return managers
    }

    private func tryRegisterRemoveSoup(indexType: String) {
        let numRegisterAndDropIterations = 10

        for store in stores() {
            for i in 0..<numRegisterAndDropIterations {
                // Before
                XCTAssertFalse(store.soupExists(kTestSoupName), "In iteration \(i + 1): Soup \(kTestSoupName) should not exist before registration.")

                // Register
                let indexSpecs = SoupIndex.asArraySoupIndexes([["path": "key", "type": indexType], ["path": "value", "type": "string"]])
                do {
                    try store.registerSoup(withName: kTestSoupName, withIndices: indexSpecs)
                } catch {
                    XCTFail("There should be no errors: \(error)")
                }
                let testSoupExists = store.soupExists(kTestSoupName)
                XCTAssertTrue(testSoupExists, "In iteration \(i + 1): Soup \(kTestSoupName) should exist after registration.")

                guard let soupTableName = getSoupTableName(kTestSoupName, store: store) else {
                    XCTFail("Failed to get soup table name")
                    continue
                }

                // Check soup indexes
                let expectedColumnName0: String
                if indexType == kSoupIndexTypeJSON1 {
                    expectedColumnName0 = "json_extract(soup, '$.key')"
                } else {
                    expectedColumnName0 = "\(soupTableName)_0"
                }
                let expectedColumnName1 = "\(soupTableName)_1"

                let indexSpecsResult = store.indices(forSoupNamed: kTestSoupName)
                checkSoupIndex(indexSpecsResult[0], expectedPath: "key", expectedType: indexType, expectedColumnName: expectedColumnName0)
                checkSoupIndex(indexSpecsResult[1], expectedPath: "value", expectedType: "string", expectedColumnName: expectedColumnName1)

                // Check db columns
                let expectedColumns: [String]
                if indexType == kSoupIndexTypeJSON1 {
                    expectedColumns = ["id", "soup", "created", "lastModified", expectedColumnName1]
                } else {
                    expectedColumns = ["id", "soup", "created", "lastModified", expectedColumnName0, expectedColumnName1]
                }
                checkColumns(soupTableName, expectedColumns: expectedColumns, store: store)

                // Check db indexes
                let indexSqlFormat = "CREATE INDEX %@_%@_idx ON %@ ( %@ )"
                checkDatabaseIndexes(soupTableName, expectedSqlStatements: [
                    String(format: indexSqlFormat, soupTableName, "0", soupTableName, expectedColumnName0),
                    String(format: indexSqlFormat, soupTableName, "1", soupTableName, expectedColumnName1),
                    String(format: indexSqlFormat, soupTableName, "created", soupTableName, "created"),
                    String(format: indexSqlFormat, soupTableName, "lastModified", soupTableName, "lastModified")
                ], store: store)

                // Remove
                store.removeSoup(kTestSoupName)
                let testSoupExistsAfterRemove = store.soupExists(kTestSoupName)
                XCTAssertFalse(testSoupExistsAfterRemove, "In iteration \(i + 1): Soup \(kTestSoupName) should no longer exist after dropping.")
            }
        }
    }

    private func tryAllQuery(indexType: String) {
        for store in stores() {
            // Before
            XCTAssertFalse(store.soupExists(kTestSoupName), "\(kTestSoupName) should not exist before registration.")

            // Register
            let indexSpecs = SoupIndex.asArraySoupIndexes([["path": "key", "type": indexType]])
            do {
                try store.registerSoup(withName: kTestSoupName, withIndices: indexSpecs)
            } catch {
                XCTFail("There should be no errors: \(error)")
            }
            let testSoupExists = store.soupExists(kTestSoupName)
            XCTAssertTrue(testSoupExists, "Soup \(kTestSoupName) should exist after registration.")

            // Populate soup
            let soupElt0: [String: Any] = ["key": "ka1", "value": "va1", "otherValue": "ova1"]
            let soupElt1: [String: Any] = ["key": "ka2", "value": "va2", "otherValue": "ova2"]
            let soupElt2: [String: Any] = ["key": "ka3", "value": "va3", "otherValue": "ova3"]

            let soupEltsCreated = store.upsert(entries: [soupElt0, soupElt1, soupElt2], forSoupNamed: kTestSoupName)

            // Query all - small page
            runQueryCheckResultsAndExplainPlan(
                querySpec: QuerySpec.buildAllQuerySpec(soupName: kTestSoupName, orderPath: "key", order: .ascending, pageSize: 2),
                page: 0,
                expectedResults: [soupEltsCreated[0], soupEltsCreated[1]],
                covering: false,
                expectedDbOperation: "SCAN",
                store: store
            )

            // Query all - next small page
            runQueryCheckResultsAndExplainPlan(
                querySpec: QuerySpec.buildAllQuerySpec(soupName: kTestSoupName, orderPath: "key", order: .ascending, pageSize: 2),
                page: 1,
                expectedResults: [soupEltsCreated[2]],
                covering: false,
                expectedDbOperation: "SCAN",
                store: store
            )

            // Query all - large page
            runQueryCheckResultsAndExplainPlan(
                querySpec: QuerySpec.buildAllQuerySpec(soupName: kTestSoupName, orderPath: "key", order: .ascending, pageSize: 10),
                page: 0,
                expectedResults: [soupEltsCreated[0], soupEltsCreated[1], soupEltsCreated[2]],
                covering: false,
                expectedDbOperation: "SCAN",
                store: store
            )

            // Query all with select paths
            runQueryCheckResultsAndExplainPlan(
                querySpec: QuerySpec.buildAllQuerySpec(soupName: kTestSoupName, selectPaths: ["key"], orderPath: "key", order: .ascending, pageSize: 10),
                page: 0,
                expectedResults: [["ka1"], ["ka2"], ["ka3"]],
                covering: true,
                expectedDbOperation: "SCAN",
                store: store
            )
        }
    }

    private func tryRangeQuery(indexType: String) {
        for store in stores() {
            // Before
            XCTAssertFalse(store.soupExists(kTestSoupName), "\(kTestSoupName) should not exist before registration.")

            // Register
            let indexSpecs = SoupIndex.asArraySoupIndexes([["path": "key", "type": indexType]])
            do {
                try store.registerSoup(withName: kTestSoupName, withIndices: indexSpecs)
            } catch {
                XCTFail("There should be no errors: \(error)")
            }
            let testSoupExists = store.soupExists(kTestSoupName)
            XCTAssertTrue(testSoupExists, "Soup \(kTestSoupName) should exist after registration.")

            // Populate soup
            let soupElt0: [String: Any] = ["key": "ka1", "value": "va1", "otherValue": "ova1"]
            let soupElt1: [String: Any] = ["key": "ka2", "value": "va2", "otherValue": "ova2"]
            let soupElt2: [String: Any] = ["key": "ka3", "value": "va3", "otherValue": "ova3"]

            let soupEltsCreated = store.upsert(entries: [soupElt0, soupElt1, soupElt2], forSoupNamed: kTestSoupName)

            // Range query
            runQueryCheckResultsAndExplainPlan(
                querySpec: QuerySpec.buildRangeQuerySpec(soupName: kTestSoupName, path: "key", beginKey: "ka2", endKey: "ka3", orderPath: "key", order: .ascending, pageSize: 10),
                page: 0,
                expectedResults: [soupEltsCreated[1], soupEltsCreated[2]],
                covering: false,
                expectedDbOperation: "SEARCH",
                store: store
            )

            // Range query - descending order
            runQueryCheckResultsAndExplainPlan(
                querySpec: QuerySpec.buildRangeQuerySpec(soupName: kTestSoupName, path: "key", beginKey: "ka2", endKey: "ka3", orderPath: "key", order: .descending, pageSize: 10),
                page: 0,
                expectedResults: [soupEltsCreated[2], soupEltsCreated[1]],
                covering: false,
                expectedDbOperation: "SEARCH",
                store: store
            )

            // Range query with select paths
            guard let rangeQueryWithPaths = QuerySpec.buildRangeQuerySpec(soupName: kTestSoupName, selectPaths: ["key"], path: "key", beginKey: "ka2", endKey: "ka3", orderPath: "key", order: .descending, pageSize: 10) else {
                XCTFail("Failed to build range query spec with select paths")
                return
            }
            runQueryCheckResultsAndExplainPlan(
                querySpec: rangeQueryWithPaths,
                page: 0,
                expectedResults: [["ka3"], ["ka2"]],
                covering: true,
                expectedDbOperation: "SEARCH",
                store: store
            )
        }
    }

    private func tryLikeQuery(indexType: String) {
        for store in stores() {
            // Before
            XCTAssertFalse(store.soupExists(kTestSoupName), "\(kTestSoupName) should not exist before registration.")

            // Register
            let indexSpecs = SoupIndex.asArraySoupIndexes([["path": "key", "type": indexType]])
            do {
                try store.registerSoup(withName: kTestSoupName, withIndices: indexSpecs)
            } catch {
                XCTFail("There should be no errors: \(error)")
            }
            let testSoupExists = store.soupExists(kTestSoupName)
            XCTAssertTrue(testSoupExists, "Soup \(kTestSoupName) should exist after registration.")

            // Populate soup
            let soupElt0: [String: Any] = ["key": "abcd", "value": "va1", "otherValue": "ova1"]
            let soupElt1: [String: Any] = ["key": "bbcd", "value": "va2", "otherValue": "ova2"]
            let soupElt2: [String: Any] = ["key": "abcc", "value": "va3", "otherValue": "ova3"]
            let soupElt3: [String: Any] = ["key": "defg", "value": "va1", "otherValue": "ova1"]

            let soupEltsCreated = store.upsert(entries: [soupElt0, soupElt1, soupElt2, soupElt3], forSoupNamed: kTestSoupName)

            // Like query (starts with)
            runQueryCheckResultsAndExplainPlan(
                querySpec: QuerySpec.buildLikeQuerySpec(soupName: kTestSoupName, path: "key", likeKey: "abc%", orderPath: "key", order: .ascending, pageSize: 10),
                page: 0,
                expectedResults: [soupEltsCreated[2], soupEltsCreated[0]],
                covering: false,
                expectedDbOperation: "SCAN",
                store: store
            )

            // Like query (ends with)
            runQueryCheckResultsAndExplainPlan(
                querySpec: QuerySpec.buildLikeQuerySpec(soupName: kTestSoupName, path: "key", likeKey: "%bcd", orderPath: "key", order: .ascending, pageSize: 10),
                page: 0,
                expectedResults: [soupEltsCreated[0], soupEltsCreated[1]],
                covering: false,
                expectedDbOperation: "SCAN",
                store: store
            )

            // Like query (starts with) - descending order
            runQueryCheckResultsAndExplainPlan(
                querySpec: QuerySpec.buildLikeQuerySpec(soupName: kTestSoupName, path: "key", likeKey: "abc%", orderPath: "key", order: .descending, pageSize: 10),
                page: 0,
                expectedResults: [soupEltsCreated[0], soupEltsCreated[2]],
                covering: false,
                expectedDbOperation: "SCAN",
                store: store
            )

            // Like query (ends with) - descending order
            runQueryCheckResultsAndExplainPlan(
                querySpec: QuerySpec.buildLikeQuerySpec(soupName: kTestSoupName, path: "key", likeKey: "%bcd", orderPath: "key", order: .descending, pageSize: 10),
                page: 0,
                expectedResults: [soupEltsCreated[1], soupEltsCreated[0]],
                covering: false,
                expectedDbOperation: "SCAN",
                store: store
            )

            // Like query (contains)
            runQueryCheckResultsAndExplainPlan(
                querySpec: QuerySpec.buildLikeQuerySpec(soupName: kTestSoupName, path: "key", likeKey: "%bc%", orderPath: "key", order: .ascending, pageSize: 10),
                page: 0,
                expectedResults: [soupEltsCreated[2], soupEltsCreated[0], soupEltsCreated[1]],
                covering: false,
                expectedDbOperation: "SCAN",
                store: store
            )

            // Like query (contains) - descending order
            runQueryCheckResultsAndExplainPlan(
                querySpec: QuerySpec.buildLikeQuerySpec(soupName: kTestSoupName, path: "key", likeKey: "%bc%", orderPath: "key", order: .descending, pageSize: 10),
                page: 0,
                expectedResults: [soupEltsCreated[1], soupEltsCreated[0], soupEltsCreated[2]],
                covering: false,
                expectedDbOperation: "SCAN",
                store: store
            )

            // Like query (contains) with select paths
            guard let likeQueryWithPaths = QuerySpec.buildLikeQuerySpec(soupName: kTestSoupName, selectPaths: ["key"], path: "key", likeKey: "%bc%", orderPath: "key", order: .descending, pageSize: 10) else {
                XCTFail("Failed to build like query spec with select paths")
                return
            }
            runQueryCheckResultsAndExplainPlan(
                querySpec: likeQueryWithPaths,
                page: 0,
                expectedResults: [["bbcd"], ["abcd"], ["abcc"]],
                covering: true,
                expectedDbOperation: "SCAN",
                store: store
            )
        }
    }

    private func trySmartQuery(indexType: String) {
        for store in stores() {
            // Before
            XCTAssertFalse(store.soupExists(kTestSoupName), "\(kTestSoupName) should not exist before registration.")

            // Register
            let indexSpecs = SoupIndex.asArraySoupIndexes([["path": "key", "type": indexType]])
            do {
                try store.registerSoup(withName: kTestSoupName, withIndices: indexSpecs)
            } catch {
                XCTFail("There should be no errors: \(error)")
            }
            let testSoupExists = store.soupExists(kTestSoupName)
            XCTAssertTrue(testSoupExists, "Soup \(kTestSoupName) should exist after registration.")

            // Populate soup
            let soupElt0: [String: Any] = ["key": "abcd", "value": "va1", "otherValue": "ova1"]
            let soupElt1: [String: Any] = ["key": "bbcd", "value": "va2", "otherValue": "ova2"]
            let soupElt2: [String: Any] = ["key": "abcc", "value": "va3", "otherValue": "ova3"]
            let soupElt3: [String: Any] = ["key": "defg", "value": "va1", "otherValue": "ova1"]

            _ = store.upsert(entries: [soupElt0, soupElt1, soupElt2, soupElt3], forSoupNamed: kTestSoupName)

            // Smart query
            var smartSql = "SELECT {\(kTestSoupName):key} FROM {\(kTestSoupName)} WHERE {\(kTestSoupName):key} LIKE 'abc%' ORDER BY {\(kTestSoupName):key}"
            guard let querySpec1 = QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: 10) else {
                XCTFail("Failed to build smart query spec")
                return
            }
            runQueryCheckResultsAndExplainPlan(
                querySpec: querySpec1,
                page: 0,
                expectedResults: [["abcc"], ["abcd"]],
                covering: true,
                expectedDbOperation: "SCAN",
                store: store
            )

            // Another smart query
            smartSql = "SELECT {\(kTestSoupName):key} FROM {\(kTestSoupName)} ORDER BY {\(kTestSoupName):key}"
            guard let querySpec2 = QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: 2) else {
                XCTFail("Failed to build smart query spec")
                return
            }
            runQueryCheckResultsAndExplainPlan(
                querySpec: querySpec2,
                page: 0,
                expectedResults: [["abcc"], ["abcd"]],
                covering: true,
                expectedDbOperation: "SCAN",
                store: store
            )
        }
    }

    private func tryQueryDataWithSpecialCharacters(indexType: String) {
        for store in stores() {
            // Before
            XCTAssertFalse(store.soupExists(kTestSoupName), "\(kTestSoupName) should not exist before registration.")

            // Register
            let indexSpecs = SoupIndex.asArraySoupIndexes([["path": "key", "type": indexType], ["path": "value", "type": indexType]])
            do {
                try store.registerSoup(withName: kTestSoupName, withIndices: indexSpecs)
            } catch {
                XCTFail("There should be no errors: \(error)")
            }
            let testSoupExists = store.soupExists(kTestSoupName)
            XCTAssertTrue(testSoupExists, "Soup \(kTestSoupName) should exist after registration.")

            var value = ""
            for i: unichar in 1..<1000 {
                if let scalar = Unicode.Scalar(i) {
                    value.append(Character(scalar))
                }
            }
            let valueForAbcd = "abcd\(value)"
            let valueForDefg = "defg\(value)"

            // Populate soup
            let soupElt0: [String: Any] = ["key": "abcd", "value": valueForAbcd]
            let soupElt1: [String: Any] = ["key": "defg", "value": valueForDefg]

            _ = store.upsert(entries: [soupElt0, soupElt1], forSoupNamed: kTestSoupName)

            // Smart query
            let smartSql = "SELECT {\(kTestSoupName):value} FROM {\(kTestSoupName)} ORDER BY {\(kTestSoupName):key}"
            guard let querySpec = QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: 10) else {
                XCTFail("Failed to build smart query spec")
                return
            }
            runQueryCheckResultsAndExplainPlan(
                querySpec: querySpec,
                page: 0,
                expectedResults: [[valueForAbcd], [valueForDefg]],
                covering: false,
                expectedDbOperation: nil,
                store: store
            )
        }
    }

    private func tryAggregateQueryOnIndexedField(indexType: String) {
        for store in stores() {
            // Before
            XCTAssertFalse(store.soupExists(kTestSoupName), "\(kTestSoupName) should not exist before registration.")

            // Register
            let indexSpecs = SoupIndex.asArraySoupIndexes([["path": "amount", "type": indexType]])
            do {
                try store.registerSoup(withName: kTestSoupName, withIndices: indexSpecs)
            } catch {
                XCTFail("There should be no errors: \(error)")
            }
            let testSoupExists = store.soupExists(kTestSoupName)
            XCTAssertTrue(testSoupExists, "Soup \(kTestSoupName) should exist after registration.")

            // Populate soup
            let soupElt1: [String: Any] = ["amount": NSNumber(value: 10.2)]
            let soupElt2: [String: Any] = ["amount": NSNumber(value: 9.9)]
            _ = store.upsert(entries: [soupElt1, soupElt2], forSoupNamed: kTestSoupName)

            // Aggregate query
            let smartSql = "SELECT SUM({\(kTestSoupName):amount}) FROM {\(kTestSoupName)}"
            guard let querySpec = QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: 10) else {
                XCTFail("Failed to build smart query spec")
                return
            }
            runQueryCheckResultsAndExplainPlan(
                querySpec: querySpec,
                page: 0,
                expectedResults: [[NSNumber(value: 20.1)]],
                covering: false,
                expectedDbOperation: nil,
                store: store
            )
        }
    }

    private func runQueryCheckResultsAndExplainPlan(querySpec: QuerySpec, page: UInt, expectedResults: [Any], covering: Bool, expectedDbOperation: String?, store: SmartStore) {
        // Run query
        do {
            let results = try store.query(using: querySpec, startingFromPageIndex: page)

            // Check results
            assertSameJSONArray(expected: expectedResults, actual: results, message: "Wrong results")

            // Check explain plan and make sure index was used unless caller passed nil for expectedDbOperation
            if let expectedDbOperation = expectedDbOperation {
                checkExplainQueryPlan(kTestSoupName, index: 0, covering: covering, dbOperation: expectedDbOperation, store: store)
            }
        } catch {
            XCTFail("There should be no errors: \(error)")
        }
    }

    private func createDbDir(_ dbName: String, manager dbMgr: SmartStoreDatabaseManager) {
        let result = dbMgr.createStoreDir(dbName)
        XCTAssertTrue(result, "Create db dir failed")
    }

    private func openDatabase(_ dbName: String, manager dbMgr: SmartStoreDatabaseManager, key: String, openShouldFail: Bool) -> FMDatabase? {
        do {
            let db = try dbMgr.openStoreDatabase(withName: dbName, key: key, salt: nil)
            if openShouldFail {
                XCTFail("Opening database should have failed.")
                return nil
            }
            return db
        } catch {
            if !openShouldFail {
                XCTFail("Opening database with name '\(dbName)' should have returned a non-nil DB object. Error: \(error.localizedDescription)")
            }
            return nil
        }
    }

    private func createTestTable(_ tableName: String, db: FMDatabase?) {
        guard let db = db else { return }
        let tableSql = "CREATE TABLE IF NOT EXISTS \(tableName) (Col1 TEXT, Col2 TEXT, Col3 TEXT, Col4 TEXT)"
        let createSucceeded = db.executeUpdate(tableSql, withArgumentsIn: [])
        XCTAssertTrue(createSucceeded, "Could not create table \(tableName): \(db.lastErrorMessage())")
    }

    private func rowCount(forTable tableName: String, db: FMDatabase?) -> Int {
        guard let db = db else { return 0 }
        let rowCountQuery = "SELECT COUNT(*) FROM \(tableName)"
        guard let rs = db.executeQuery(rowCountQuery, withArgumentsIn: []) else { return 0 }
        defer { rs.close() }
        return rs.next() ? Int(rs.int(forColumnIndex: 0)) : 0
    }

    private func tableNameInMaster(_ tableName: String, db: FMDatabase?) -> Bool {
        guard let db = db else { return false }
        let origCrashOnErrors = db.crashOnErrors
        db.crashOnErrors = false

        var result = true
        let querySql = "SELECT * FROM sqlite_master WHERE name = ?"
        let rs = db.executeQuery(querySql, withArgumentsIn: [tableName])
        if rs == nil || !(rs?.next() ?? false) {
            result = false
        }

        rs?.close()
        db.crashOnErrors = origCrashOnErrors
        return result
    }

    private func registerTestSoup(store: SmartStore, indexType: String) {
        let indexSpecs = SoupIndex.asArraySoupIndexes([["path": "key", "type": indexType], ["path": "value", "type": kSoupIndexTypeString]])
        do {
            try store.registerSoup(withName: kTestSoupName, withIndices: indexSpecs)
        } catch {
            XCTFail("Soup should have registered without error: \(error)")
        }
        XCTAssertTrue(store.soupExists(kTestSoupName), "Soup should exist after registration")
    }
}
