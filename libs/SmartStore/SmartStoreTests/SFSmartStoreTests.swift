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
@testable import SmartStore
import SalesforceSDKCore
import SalesforceSDKCommon
import SQLCipher

private let kTestSmartStoreName = "testSmartStore"
private let kTestSoupName = "testSoup"

class SFSmartStoreTests: SFSmartStoreTestCase {

    private var smartStoreUser: UserAccount!
    private var store: SmartStore!
    private var globalStore: SmartStore!

    // MARK: - Setup and teardown

    override func setUp() {
        super.setUp()
        SmartStoreLogger.setLogLevel(.debug)
        smartStoreUser = setUpSmartStoreUser()
        store = SmartStore.shared(withName: kTestSmartStoreName)
        globalStore = SmartStore.sharedGlobal(withName: kTestSmartStoreName)
        store.capturesExplainQueryPlan = true
        globalStore.capturesExplainQueryPlan = true
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

    func testCompileOptions() {
        let options = store.compileOptions()
        XCTAssertTrue(options.contains("ENABLE_FTS4"))
        XCTAssertTrue(options.contains("ENABLE_FTS3_PARENTHESIS"))
        XCTAssertTrue(options.contains("ENABLE_FTS5"))
    }

    func testRuntimeSettings() {
        let settings = store.runtimeSettings()
        XCTAssertTrue(settings.contains("PRAGMA kdf_iter = 4000;"))
        XCTAssertTrue(settings.contains("PRAGMA cipher_page_size = 4096;"))
        XCTAssertTrue(settings.contains("PRAGMA cipher_use_hmac = 1;"))
        XCTAssertTrue(settings.contains("PRAGMA cipher_plaintext_header_size = 0;"))
        XCTAssertTrue(settings.contains("PRAGMA cipher_hmac_algorithm = HMAC_SHA512;"))
        XCTAssertTrue(settings.contains("PRAGMA cipher_kdf_algorithm = PBKDF2_HMAC_SHA512;"))
    }

    func testSqliteVersion() {
        let version = String(cString: sqlite3_libversion())
        XCTAssertEqual(version, "3.50.4")
    }

    func testSqlCipherVersion() {
        let version = store.versionOfSQLCipher()
        XCTAssertEqual(version, "4.10.0 community")
    }

    func testCipherProviderVersion() {
        let cipherProviderVersion = store.cipherProviderVersion()
        XCTAssertNotNil(cipherProviderVersion)
        XCTAssertTrue(cipherProviderVersion.count > 0, "cipherProviderVersion should not be an empty string")
    }

    func testCipherFIPSStatus() {
        let cipherFIPSStatus = store.cipherFIPSStatus()
        XCTAssertFalse(cipherFIPSStatus)
    }

    func testFtsExtension() {
        XCTAssertEqual(store.ftsExtension, .fts5, "Expected FTS5")
    }

    func testProjectTopLevel() {
        let rawJson = "{\"a\":\"va\", \"b\":2, \"c\":[0,1,2], \"d\": {\"d1\":\"vd1\", \"d2\":\"vd2\", \"d3\":[1,2], \"d4\":{\"e\":5}}}"
        let json = SFJsonUtils.object(from: rawJson) as! [String: Any]

        // Root object
        assertSameJSON(expected: json as NSDictionary, actual: SFJsonUtils.projectIntoJson(json, path: "") as? NSDictionary, message: "Should have returned whole object")

        // Top-level elements
        assertSameJSON(expected: "va" as NSObject, actual: SFJsonUtils.projectIntoJson(json, path: "a") as? NSObject, message: "Wrong value for key a")
        assertSameJSON(expected: 2 as NSObject, actual: SFJsonUtils.projectIntoJson(json, path: "b") as? NSObject, message: "Wrong value for key b")
        assertSameJSON(expected: SFJsonUtils.object(from: "[0,1,2]"), actual: SFJsonUtils.projectIntoJson(json, path: "c"), message: "Wrong value for key c")
        assertSameJSON(expected: SFJsonUtils.object(from: "{\"d1\":\"vd1\", \"d2\":\"vd2\", \"d3\":[1,2], \"d4\":{\"e\":5}}"), actual: SFJsonUtils.projectIntoJson(json, path: "d"), message: "Wrong value for key d")
    }

    func testProjectNested() {
        let rawJson = "{\"a\":\"va\", \"b\":2, \"c\":[0,1,2], \"d\": {\"d1\":\"vd1\", \"d2\":\"vd2\", \"d3\":[1,2], \"d4\":{\"e\":5}}}"
        let json = SFJsonUtils.object(from: rawJson) as! [String: Any]

        assertSameJSON(expected: "vd1" as NSObject, actual: SFJsonUtils.projectIntoJson(json, path: "d.d1") as? NSObject, message: "Wrong value for key d.d1")
        assertSameJSON(expected: "vd2" as NSObject, actual: SFJsonUtils.projectIntoJson(json, path: "d.d2") as? NSObject, message: "Wrong value for key d.d2")
        assertSameJSON(expected: SFJsonUtils.object(from: "[1,2]"), actual: SFJsonUtils.projectIntoJson(json, path: "d.d3"), message: "Wrong value for key d.d3")
        assertSameJSON(expected: SFJsonUtils.object(from: "{\"e\":5}"), actual: SFJsonUtils.projectIntoJson(json, path: "d.d4"), message: "Wrong value for key d.d4")
        assertSameJSON(expected: 5 as NSObject, actual: SFJsonUtils.projectIntoJson(json, path: "d.d4.e") as? NSObject, message: "Wrong value for key d.d4.e")
    }

    func testProjectThroughArrays() {
        let rawJson = "{\"a\":\"a1\", \"b\":2, \"c\":[{\"cc\":\"cc1\"}, {\"cc\":2}, {\"cc\":[1,2,3]}, {}, {\"cc\":{\"cc5\":5}}], \"d\":[{\"dd\":[{\"ddd\":\"ddd11\"},{\"ddd\":\"ddd12\"}]}, {\"dd\":[{\"ddd\":\"ddd21\"}]}, {\"dd\":[{\"ddd\":\"ddd31\"},{\"ddd3\":\"ddd32\"}]}]}"
        let json = SFJsonUtils.object(from: rawJson) as! [String: Any]

        assertSameJSON(expected: SFJsonUtils.object(from: "[{\"cc\":\"cc1\"}, {\"cc\":2}, {\"cc\":[1,2,3]}, {}, {\"cc\":{\"cc5\":5}}]"), actual: SFJsonUtils.projectIntoJson(json, path: "c"), message: "Wrong value for key c")
        assertSameJSON(expected: SFJsonUtils.object(from: "[\"cc1\",2, [1,2,3], {\"cc5\":5}]"), actual: SFJsonUtils.projectIntoJson(json, path: "c.cc"), message: "Wrong value for key c.cc")
        assertSameJSON(expected: SFJsonUtils.object(from: "[5]"), actual: SFJsonUtils.projectIntoJson(json, path: "c.cc.cc5"), message: "Wrong value for key c.cc.cc5")
        assertSameJSON(expected: SFJsonUtils.object(from: "[{\"dd\":[{\"ddd\":\"ddd11\"},{\"ddd\":\"ddd12\"}]}, {\"dd\":[{\"ddd\":\"ddd21\"}]}, {\"dd\":[{\"ddd\":\"ddd31\"},{\"ddd3\":\"ddd32\"}]}]"), actual: SFJsonUtils.projectIntoJson(json, path: "d"), message: "Wrong value for key d")
        assertSameJSON(expected: SFJsonUtils.object(from: "[[{\"ddd\":\"ddd11\"},{\"ddd\":\"ddd12\"}], [{\"ddd\":\"ddd21\"}], [{\"ddd\":\"ddd31\"},{\"ddd3\":\"ddd32\"}]]"), actual: SFJsonUtils.projectIntoJson(json, path: "d.dd"), message: "Wrong value for key d.dd")
        assertSameJSON(expected: SFJsonUtils.object(from: "[[\"ddd11\",\"ddd12\"],[\"ddd21\"],[\"ddd31\"]]"), actual: SFJsonUtils.projectIntoJson(json, path: "d.dd.ddd"), message: "Wrong value for key d.dd.ddd")
        assertSameJSON(expected: SFJsonUtils.object(from: "[[\"ddd32\"]]"), actual: SFJsonUtils.projectIntoJson(json, path: "d.dd.ddd3"), message: "Wrong value for key d.dd.ddd3")
    }

    func testMetaDataTablesCreated() {
        for store in [self.store!, self.globalStore!] {
            XCTAssertTrue(hasTable("soup_index_map", store: store), "Soup index map table not found")
            XCTAssertTrue(hasTable("soup_attrs", store: store), "Soup attrs table not found")
        }
    }

    func testRegisterRemoveSoupWithStringIndexes() {
        tryRegisterRemoveSoup("string")
    }

    func testRegisterRemoveSoupWithJSON1Indexes() {
        tryRegisterRemoveSoup("json1")
    }

    private func tryRegisterRemoveSoup(_ indexType: String) {
        let numRegisterAndDropIterations: UInt = 10

        for store in [self.store!, self.globalStore!] {
            for i in 0..<numRegisterAndDropIterations {
                // Before
                XCTAssertFalse(store.soupExists(forName: kTestSoupName), "In iteration \(i + 1): Soup \(kTestSoupName) should not exist before registration.")

                // Register
                let indexSpecs = SoupIndex.asArray([["path": "key", "type": indexType], ["path": "value", "type": "string"]])
                try! store.registerSoup(withName: kTestSoupName, withIndices: indexSpecs)
                XCTAssertTrue(store.soupExists(forName: kTestSoupName), "In iteration \(i + 1): Soup \(kTestSoupName) should exist after registration.")
                let soupTableName = getSoupTableName(kTestSoupName, store: store)!

                // Check soup indexes
                let expectedColumnName0 = (indexType == "json1")
                    ? "json_extract(soup, '$.key')"
                    : "\(soupTableName)_0"
                let expectedColumnName1 = "\(soupTableName)_1"

                let indexSpecs2 = store.indices(forSoupNamed: kTestSoupName)
                checkSoupIndex(indexSpecs2[0], expectedPath: "key", expectedType: indexType, expectedColumnName: expectedColumnName0)
                checkSoupIndex(indexSpecs2[1], expectedPath: "value", expectedType: "string", expectedColumnName: expectedColumnName1)

                // Check db columns
                let expectedColumns: [String] = (indexType == "json1")
                    ? ["id", "soup", "created", "lastModified", expectedColumnName1]
                    : ["id", "soup", "created", "lastModified", expectedColumnName0, expectedColumnName1]
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
                XCTAssertFalse(store.soupExists(forName: kTestSoupName), "In iteration \(i + 1): Soup \(kTestSoupName) should no longer exist after dropping.")
            }
        }
    }

    func testAllQueryWithStringIndex() {
        tryAllQuery(kSoupIndexTypeString)
    }

    func testAllQueryWithJSON1Index() {
        tryAllQuery(kSoupIndexTypeJSON1)
    }

    private func tryAllQuery(_ indexType: String) {
        for store in [self.store!, self.globalStore!] {
            XCTAssertFalse(store.soupExists(forName: kTestSoupName), "\(kTestSoupName) should not exist before registration.")

            let indexSpecs = SoupIndex.asArray([["path": "key", "type": indexType]])
            try! store.registerSoup(withName: kTestSoupName, withIndices: indexSpecs)
            XCTAssertTrue(store.soupExists(forName: kTestSoupName), "Soup \(kTestSoupName) should exist after registration.")

            let soupElt0: NSDictionary = ["key": "ka1", "value": "va1", "otherValue": "ova1"]
            let soupElt1: NSDictionary = ["key": "ka2", "value": "va2", "otherValue": "ova2"]
            let soupElt2: NSDictionary = ["key": "ka3", "value": "va3", "otherValue": "ova3"]

            let soupEltsCreated = store.upsert(entries: [soupElt0, soupElt1, soupElt2], forSoupNamed: kTestSoupName)

            // Query all - small page
            runQueryCheckResultsAndExplainPlan(QuerySpec.buildAllQuerySpec(soupName: kTestSoupName, orderPath: "key", order: .ascending, pageSize: 2), page: 0, expectedResults: [soupEltsCreated[0], soupEltsCreated[1]], covering: false, expectedDbOperation: "SCAN", store: store)

            // Query all - next small page
            runQueryCheckResultsAndExplainPlan(QuerySpec.buildAllQuerySpec(soupName: kTestSoupName, orderPath: "key", order: .ascending, pageSize: 2), page: 1, expectedResults: [soupEltsCreated[2]], covering: false, expectedDbOperation: "SCAN", store: store)

            // Query all - large page
            runQueryCheckResultsAndExplainPlan(QuerySpec.buildAllQuerySpec(soupName: kTestSoupName, orderPath: "key", order: .ascending, pageSize: 10), page: 0, expectedResults: [soupEltsCreated[0], soupEltsCreated[1], soupEltsCreated[2]], covering: false, expectedDbOperation: "SCAN", store: store)

            // Query all with select paths
            runQueryCheckResultsAndExplainPlan(QuerySpec.buildAllQuerySpec(soupName: kTestSoupName, selectPaths: ["key"], orderPath: "key", order: .ascending, pageSize: 10), page: 0, expectedResults: [["ka1"] as NSArray, ["ka2"] as NSArray, ["ka3"] as NSArray], covering: true, expectedDbOperation: "SCAN", store: store)
        }
    }

    func testRangeQueryWithStringIndex() {
        tryRangeQuery(kSoupIndexTypeString)
    }

    func testRangeQueryWithJSON1Index() {
        tryRangeQuery(kSoupIndexTypeJSON1)
    }

    private func tryRangeQuery(_ indexType: String) {
        for store in [self.store!, self.globalStore!] {
            XCTAssertFalse(store.soupExists(forName: kTestSoupName))

            let indexSpecs = SoupIndex.asArray([["path": "key", "type": indexType]])
            try! store.registerSoup(withName: kTestSoupName, withIndices: indexSpecs)
            XCTAssertTrue(store.soupExists(forName: kTestSoupName))

            let soupElt0: NSDictionary = ["key": "ka1", "value": "va1", "otherValue": "ova1"]
            let soupElt1: NSDictionary = ["key": "ka2", "value": "va2", "otherValue": "ova2"]
            let soupElt2: NSDictionary = ["key": "ka3", "value": "va3", "otherValue": "ova3"]
            let soupEltsCreated = store.upsert(entries: [soupElt0, soupElt1, soupElt2], forSoupNamed: kTestSoupName)

            // Range query
            runQueryCheckResultsAndExplainPlan(QuerySpec.buildRangeQuerySpec(soupName: kTestSoupName, path: "key", beginKey: "ka2", endKey: "ka3", orderPath: "key", order: .ascending, pageSize: 10), page: 0, expectedResults: [soupEltsCreated[1], soupEltsCreated[2]], covering: false, expectedDbOperation: "SEARCH", store: store)

            // Range query - descending order
            runQueryCheckResultsAndExplainPlan(QuerySpec.buildRangeQuerySpec(soupName: kTestSoupName, path: "key", beginKey: "ka2", endKey: "ka3", orderPath: "key", order: .descending, pageSize: 10), page: 0, expectedResults: [soupEltsCreated[2], soupEltsCreated[1]], covering: false, expectedDbOperation: "SEARCH", store: store)

            // Range query with select paths
            runQueryCheckResultsAndExplainPlan(QuerySpec.buildRangeQuerySpec(soupName: kTestSoupName, selectPaths: ["key"], path: "key", beginKey: "ka2", endKey: "ka3", orderPath: "key", order: .descending, pageSize: 10)!, page: 0, expectedResults: [["ka3"] as NSArray, ["ka2"] as NSArray], covering: true, expectedDbOperation: "SEARCH", store: store)
        }
    }

    func testLikeQueryWithStringIndex() {
        tryLikeQuery(kSoupIndexTypeString)
    }

    func testLikeQueryWithJSON1Index() {
        tryLikeQuery(kSoupIndexTypeJSON1)
    }

    private func tryLikeQuery(_ indexType: String) {
        for store in [self.store!, self.globalStore!] {
            XCTAssertFalse(store.soupExists(forName: kTestSoupName))

            let indexSpecs = SoupIndex.asArray([["path": "key", "type": indexType]])
            try! store.registerSoup(withName: kTestSoupName, withIndices: indexSpecs)
            XCTAssertTrue(store.soupExists(forName: kTestSoupName))

            let soupElt0: NSDictionary = ["key": "abcd", "value": "va1", "otherValue": "ova1"]
            let soupElt1: NSDictionary = ["key": "bbcd", "value": "va2", "otherValue": "ova2"]
            let soupElt2: NSDictionary = ["key": "abcc", "value": "va3", "otherValue": "ova3"]
            let soupElt3: NSDictionary = ["key": "defg", "value": "va1", "otherValue": "ova1"]
            let soupEltsCreated = store.upsert(entries: [soupElt0, soupElt1, soupElt2, soupElt3], forSoupNamed: kTestSoupName)

            // Like query (starts with)
            runQueryCheckResultsAndExplainPlan(QuerySpec.buildLikeQuerySpec(soupName: kTestSoupName, path: "key", likeKey: "abc%", orderPath: "key", order: .ascending, pageSize: 10), page: 0, expectedResults: [soupEltsCreated[2], soupEltsCreated[0]], covering: false, expectedDbOperation: "SCAN", store: store)

            // Like query (ends with)
            runQueryCheckResultsAndExplainPlan(QuerySpec.buildLikeQuerySpec(soupName: kTestSoupName, path: "key", likeKey: "%bcd", orderPath: "key", order: .ascending, pageSize: 10), page: 0, expectedResults: [soupEltsCreated[0], soupEltsCreated[1]], covering: false, expectedDbOperation: "SCAN", store: store)

            // Like query (starts with) - descending order
            runQueryCheckResultsAndExplainPlan(QuerySpec.buildLikeQuerySpec(soupName: kTestSoupName, path: "key", likeKey: "abc%", orderPath: "key", order: .descending, pageSize: 10), page: 0, expectedResults: [soupEltsCreated[0], soupEltsCreated[2]], covering: false, expectedDbOperation: "SCAN", store: store)

            // Like query (ends with) - descending order
            runQueryCheckResultsAndExplainPlan(QuerySpec.buildLikeQuerySpec(soupName: kTestSoupName, path: "key", likeKey: "%bcd", orderPath: "key", order: .descending, pageSize: 10), page: 0, expectedResults: [soupEltsCreated[1], soupEltsCreated[0]], covering: false, expectedDbOperation: "SCAN", store: store)

            // Like query (contains)
            runQueryCheckResultsAndExplainPlan(QuerySpec.buildLikeQuerySpec(soupName: kTestSoupName, path: "key", likeKey: "%bc%", orderPath: "key", order: .ascending, pageSize: 10), page: 0, expectedResults: [soupEltsCreated[2], soupEltsCreated[0], soupEltsCreated[1]], covering: false, expectedDbOperation: "SCAN", store: store)

            // Like query (contains) - descending order
            runQueryCheckResultsAndExplainPlan(QuerySpec.buildLikeQuerySpec(soupName: kTestSoupName, path: "key", likeKey: "%bc%", orderPath: "key", order: .descending, pageSize: 10), page: 0, expectedResults: [soupEltsCreated[1], soupEltsCreated[0], soupEltsCreated[2]], covering: false, expectedDbOperation: "SCAN", store: store)

            // Like query (contains) with select paths
            runQueryCheckResultsAndExplainPlan(QuerySpec.buildLikeQuerySpec(soupName: kTestSoupName, selectPaths: ["key"], path: "key", likeKey: "%bc%", orderPath: "key", order: .descending, pageSize: 10)!, page: 0, expectedResults: [["bbcd"] as NSArray, ["abcd"] as NSArray, ["abcc"] as NSArray], covering: true, expectedDbOperation: "SCAN", store: store)
        }
    }

    func testSmartQueryWithStringIndex() {
        trySmartQuery(kSoupIndexTypeString)
    }

    func testSmartQueryWithJSON1Index() {
        trySmartQuery(kSoupIndexTypeJSON1)
    }

    private func trySmartQuery(_ indexType: String) {
        for store in [self.store!, self.globalStore!] {
            XCTAssertFalse(store.soupExists(forName: kTestSoupName))

            let indexSpecs = SoupIndex.asArray([["path": "key", "type": indexType]])
            try! store.registerSoup(withName: kTestSoupName, withIndices: indexSpecs)
            XCTAssertTrue(store.soupExists(forName: kTestSoupName))

            let soupElt0: NSDictionary = ["key": "abcd", "value": "va1", "otherValue": "ova1"]
            let soupElt1: NSDictionary = ["key": "bbcd", "value": "va2", "otherValue": "ova2"]
            let soupElt2: NSDictionary = ["key": "abcc", "value": "va3", "otherValue": "ova3"]
            let soupElt3: NSDictionary = ["key": "defg", "value": "va1", "otherValue": "ova1"]
            store.upsert(entries: [soupElt0, soupElt1, soupElt2, soupElt3], forSoupNamed: kTestSoupName)

            // Smart query
            var smartSql = "SELECT {\(kTestSoupName):key} FROM {\(kTestSoupName)} WHERE {\(kTestSoupName):key} LIKE 'abc%' ORDER BY {\(kTestSoupName):key}"
            runQueryCheckResultsAndExplainPlan(QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: 10)!, page: 0, expectedResults: [["abcc"] as NSArray, ["abcd"] as NSArray], covering: true, expectedDbOperation: "SCAN", store: store)

            // Another smart query
            smartSql = "SELECT {\(kTestSoupName):key} FROM {\(kTestSoupName)} ORDER BY {\(kTestSoupName):key}"
            runQueryCheckResultsAndExplainPlan(QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: 2)!, page: 0, expectedResults: [["abcc"] as NSArray, ["abcd"] as NSArray], covering: true, expectedDbOperation: "SCAN", store: store)
        }
    }

    func testQueryDataWithSpecialCharactersWithStringIndex() {
        tryQueryDataWithSpecialCharacters(kSoupIndexTypeString)
    }

    func testQueryDataWithSpecialCharactersWithJSON1Index() {
        tryQueryDataWithSpecialCharacters(kSoupIndexTypeJSON1)
    }

    private func tryQueryDataWithSpecialCharacters(_ indexType: String) {
        for store in [self.store!, self.globalStore!] {
            XCTAssertFalse(store.soupExists(forName: kTestSoupName))

            let indexSpecs = SoupIndex.asArray([["path": "key", "type": indexType], ["path": "value", "type": indexType]])
            try! store.registerSoup(withName: kTestSoupName, withIndices: indexSpecs)
            XCTAssertTrue(store.soupExists(forName: kTestSoupName))

            var value = ""
            for i: unichar in 1..<1000 {
                value.append(String(Character(UnicodeScalar(i)!)))
            }
            let valueForAbcd = "abcd\(value)"
            let valueForDefg = "defg\(value)"

            let soupElt0: NSDictionary = ["key": "abcd", "value": valueForAbcd]
            let soupElt1: NSDictionary = ["key": "defg", "value": valueForDefg]
            store.upsert(entries: [soupElt0, soupElt1], forSoupNamed: kTestSoupName)

            // Smart query
            let smartSql = "SELECT {\(kTestSoupName):value} FROM {\(kTestSoupName)} ORDER BY {\(kTestSoupName):key}"
            runQueryCheckResultsAndExplainPlan(QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: 10)!, page: 0, expectedResults: [[valueForAbcd] as NSArray, [valueForDefg] as NSArray], covering: false, expectedDbOperation: nil, store: store)
        }
    }

    func testRemoveEntriesByIds() {
        for store in [self.store!, self.globalStore!] {
            XCTAssertFalse(store.soupExists(forName: kTestSoupName))

            let indexSpecs = SoupIndex.asArray([["path": "key", "type": kSoupIndexTypeString]])
            try! store.registerSoup(withName: kTestSoupName, withIndices: indexSpecs)
            XCTAssertTrue(store.soupExists(forName: kTestSoupName))

            let soupElt0: NSDictionary = ["key": "abcd", "value": "va1", "otherValue": "ova1"]
            let soupElt1: NSDictionary = ["key": "bbcd", "value": "va2", "otherValue": "ova2"]
            let soupElt2: NSDictionary = ["key": "abcc", "value": "va3", "otherValue": "ova3"]
            let soupElt3: NSDictionary = ["key": "defg", "value": "va1", "otherValue": "ova1"]
            let soupEltsCreated = store.upsert(entries: [soupElt0, soupElt1, soupElt2, soupElt3], forSoupNamed: kTestSoupName)

            // Remove two entries
            let id1 = soupEltsCreated[1][SOUP_ENTRY_ID] as! NSNumber
            let id3 = soupEltsCreated[3][SOUP_ENTRY_ID] as! NSNumber
            try! store.remove(entryIds: [id1, id3], forSoupNamed: kTestSoupName)

            // Query all and make sure the two entries are gone
            runQueryCheckResultsAndExplainPlan(QuerySpec.buildAllQuerySpec(soupName: kTestSoupName, orderPath: "key", order: .ascending, pageSize: 10), page: 0, expectedResults: [soupEltsCreated[2], soupEltsCreated[0]], covering: false, expectedDbOperation: "SCAN", store: store)

            // Remove one more entry
            let id0 = soupEltsCreated[0][SOUP_ENTRY_ID] as! NSNumber
            try! store.remove(entryIds: [id0], forSoupNamed: kTestSoupName)

            // Query all and make sure the removed entry is gone
            runQueryCheckResultsAndExplainPlan(QuerySpec.buildAllQuerySpec(soupName: kTestSoupName, orderPath: "key", order: .ascending, pageSize: 10), page: 0, expectedResults: [soupEltsCreated[2]], covering: false, expectedDbOperation: "SCAN", store: store)
        }
    }

    func testRemoveEntriesByQuery() {
        for store in [self.store!, self.globalStore!] {
            XCTAssertFalse(store.soupExists(forName: kTestSoupName))

            let indexSpecs = SoupIndex.asArray([["path": "key", "type": kSoupIndexTypeString]])
            try! store.registerSoup(withName: kTestSoupName, withIndices: indexSpecs)
            XCTAssertTrue(store.soupExists(forName: kTestSoupName))

            let soupElt0: NSDictionary = ["key": "abcd", "value": "va1", "otherValue": "ova1"]
            let soupElt1: NSDictionary = ["key": "bbcd", "value": "va2", "otherValue": "ova2"]
            let soupElt2: NSDictionary = ["key": "abcc", "value": "va3", "otherValue": "ova3"]
            let soupElt3: NSDictionary = ["key": "defg", "value": "va1", "otherValue": "ova1"]
            let soupEltsCreated = store.upsert(entries: [soupElt0, soupElt1, soupElt2, soupElt3], forSoupNamed: kTestSoupName)

            // Remove entries by query
            try! store.removeEntries(usingQuerySpec: QuerySpec.buildLikeQuerySpec(soupName: kTestSoupName, path: "key", likeKey: "abc%", orderPath: "key", order: .ascending, pageSize: 10), forSoupNamed: kTestSoupName)

            // Query all and make sure the removed entries are gone
            runQueryCheckResultsAndExplainPlan(QuerySpec.buildAllQuerySpec(soupName: kTestSoupName, orderPath: "key", order: .ascending, pageSize: 10), page: 0, expectedResults: [soupEltsCreated[1], soupEltsCreated[3]], covering: false, expectedDbOperation: "SCAN", store: store)

            // Remove one more entry using a query all with page size of 1
            try! store.removeEntries(usingQuerySpec: QuerySpec.buildAllQuerySpec(soupName: kTestSoupName, orderPath: "key", order: .ascending, pageSize: 1), forSoupNamed: kTestSoupName)

            // Query all and make sure the removed entry is gone
            runQueryCheckResultsAndExplainPlan(QuerySpec.buildAllQuerySpec(soupName: kTestSoupName, orderPath: "key", order: .ascending, pageSize: 10), page: 0, expectedResults: [soupEltsCreated[3]], covering: false, expectedDbOperation: "SCAN", store: store)
        }
    }

    func testAggregateQueryOnFloatingIndexedField() {
        tryAggregateQueryOnIndexedField(kSoupIndexTypeFloating)
    }

    func testAggregateQueryOnJSON1IndexedField() {
        tryAggregateQueryOnIndexedField(kSoupIndexTypeJSON1)
    }

    private func tryAggregateQueryOnIndexedField(_ indexType: String) {
        for store in [self.store!, self.globalStore!] {
            XCTAssertFalse(store.soupExists(forName: kTestSoupName))

            let indexSpecs = SoupIndex.asArray([["path": "amount", "type": indexType]])
            try! store.registerSoup(withName: kTestSoupName, withIndices: indexSpecs)
            XCTAssertTrue(store.soupExists(forName: kTestSoupName))

            let soupElt1: NSDictionary = ["amount": NSNumber(value: 10.2)]
            let soupElt2: NSDictionary = ["amount": NSNumber(value: 9.9)]
            store.upsert(entries: [soupElt1, soupElt2], forSoupNamed: kTestSoupName)

            // Aggregate query
            let smartSql = "SELECT SUM({\(kTestSoupName):amount}) FROM {\(kTestSoupName)}"
            runQueryCheckResultsAndExplainPlan(QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: 10)!, page: 0, expectedResults: [[NSNumber(value: 20.1)] as NSArray], covering: false, expectedDbOperation: nil, store: store)
        }
    }

    private func runQueryCheckResultsAndExplainPlan(_ querySpec: QuerySpec, page: UInt, expectedResults: [Any], covering: Bool, expectedDbOperation: String?, store: SmartStore) {
        // Run query
        let results = try! store.query(using: querySpec, startingFromPageIndex: page)

        // Check results
        assertSameJSONArray(expected: expectedResults, actual: results, message: "Wrong results")

        // Check explain plan and make sure index was used unless caller passed nil for expectedDbOperation
        if let expectedDbOperation = expectedDbOperation {
            checkExplainQueryPlan(kTestSoupName, index: 0, covering: covering, dbOperation: expectedDbOperation, store: store)
        }
    }

    func testSelectUnderscoreSoup() {
        // Create soup
        try! store.registerSoup(withName: kTestSoupName, withIndices: SoupIndex.asArray([["path": "key", "type": kSoupIndexTypeString]]))

        // Create soup elements
        let soupElt1: NSDictionary = ["key": "ka1", "value": "va1"]
        let soupElt2: NSDictionary = ["key": "ka2", "value": "va2"]
        let soupElt3: NSDictionary = ["key": "ka3", "value": "va3"]
        let soupElt4: NSDictionary = ["key": "ka4", "value": "va4"]
        let soupEltsCreated = store.upsert(entries: [soupElt1, soupElt2, soupElt3, soupElt4], forSoupNamed: kTestSoupName)

        // Query _soup
        let smartSql = "SELECT {\(kTestSoupName):_soup} FROM {\(kTestSoupName)} ORDER BY {\(kTestSoupName):key}"
        runQueryCheckResultsAndExplainPlan(QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: 10)!, page: 0, expectedResults: [[soupEltsCreated[0]] as NSArray, [soupEltsCreated[1]] as NSArray, [soupEltsCreated[2]] as NSArray, [soupEltsCreated[3]] as NSArray], covering: false, expectedDbOperation: "SCAN", store: store)
    }

    func testSelectUnderscoreSoupFromMultipleSoups() {
        // Create soups
        let otherTestSoupName = "otherTestSoup"
        try! store.registerSoup(withName: kTestSoupName, withIndices: SoupIndex.asArray([["path": "key", "type": kSoupIndexTypeString]]))
        try! store.registerSoup(withName: otherTestSoupName, withIndices: SoupIndex.asArray([["path": "key", "type": "string"]]))

        // Create soup elements
        let soupElt1: NSDictionary = ["key": "ka1", "value": "va1"]
        let soupElt1Created = store.upsert(entries: [soupElt1], forSoupNamed: kTestSoupName)[0]

        let soupElt2: NSDictionary = ["key": "ka1", "value": "va1", "otherValue": "ova1"]
        let soupElt2Created = store.upsert(entries: [soupElt2], forSoupNamed: otherTestSoupName)[0]

        // Query _soup from both soups
        let smartSql = "SELECT {\(kTestSoupName):_soup}, {\(otherTestSoupName):_soup} FROM {\(kTestSoupName)}, {\(otherTestSoupName)}"
        runQueryCheckResultsAndExplainPlan(QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: 10)!, page: 0, expectedResults: [[soupElt1Created, soupElt2Created] as NSArray], covering: false, expectedDbOperation: nil, store: store)
    }

    func testMultipleRegisterSameSoup() {
        for store in [self.store!, self.globalStore!] {
            XCTAssertFalse(store.soupExists(forName: kTestSoupName), "Soup \(kTestSoupName) should not exist")

            // Register first time
            let soupIndex: [String: String] = ["path": "name", "type": "string"]
            try! store.registerSoup(withName: kTestSoupName, withIndices: SoupIndex.asArray([soupIndex]))
            XCTAssertTrue(store.soupExists(forName: kTestSoupName), "Soup \(kTestSoupName) should exist")

            // Register second time - should only create one soup per unique soup name
            try! store.registerSoup(withName: kTestSoupName, withIndices: SoupIndex.asArray([soupIndex]))
            var rowCount: Int32 = 0
            store.storeQueue.inDatabase { db in
                if let rs = db.executeQuery("SELECT COUNT(*) FROM soup_attrs WHERE soupName = ?", withArgumentsIn: [kTestSoupName]) {
                    if rs.next() {
                        rowCount = rs.int(forColumnIndex: 0)
                    }
                    rs.close()
                }
            }
            XCTAssertEqual(rowCount, 1, "Soup names should be unique within a store.")

            // Remove
            store.removeSoup(kTestSoupName)
            XCTAssertFalse(store.soupExists(forName: kTestSoupName), "Soup \(kTestSoupName) should no longer exist")
        }
    }

    func testQuerySpecPageSize() {
        let allQueryNoPageSize: [String: Any] = [kQuerySpecParamQueryType: kQuerySpecTypeRange,
                                                  kQuerySpecParamIndexPath: "a"]
        let querySpec = QuerySpec(querySpec: allQueryNoPageSize, targetSoupName: kTestSoupName)!
        XCTAssertEqual(querySpec.pageSize, kQuerySpecDefaultPageSize, "Page size value should be default, if not specified.")

        let expectedPageSize: UInt = 42
        let allQueryWithPageSize: [String: Any] = [kQuerySpecParamQueryType: kQuerySpecTypeRange,
                                                    kQuerySpecParamIndexPath: "a",
                                                    kQuerySpecParamPageSize: expectedPageSize]
        let querySpec2 = QuerySpec(querySpec: allQueryWithPageSize, targetSoupName: kTestSoupName)!
        XCTAssertEqual(querySpec2.pageSize, expectedPageSize, "Page size value should reflect input value.")
    }

    func testPersistentStoreExists() {
        for dbMgr in [DatabaseManager.sharedManager()!, DatabaseManager.sharedGlobalManager()] {
            let storeName = "xyzpdq"
            XCTAssertFalse(dbMgr.persistentStoreExists(storeName), "Store should not exist at this point.")
            createDbDir(storeName, withManager: dbMgr)
            let db = openDatabase(storeName, withManager: dbMgr, key: "", openShouldFail: false)
            XCTAssertTrue(dbMgr.persistentStoreExists(storeName), "Store should exist after creation.")
            db?.close()
            dbMgr.removeStoreDir(storeName)
            XCTAssertFalse(dbMgr.persistentStoreExists(storeName), "Store should no longer exist at this point.")
        }
    }

    func testSmartStoreIsRecreatedWhenKeyIsLost() {
        let storeName = "testSmartStoreIsRecreatedWhenKeyIsLost"
        let keyLabel = "com.salesforce.keystore.\(kSFSmartStoreEncryptionKeyLabel)"
        let originalKey = KeychainHelper.read(service: keyLabel, account: nil).data

        defer {
            // Drop store
            SmartStore.removeShared(withName: storeName)
            // Restore key
            if let originalKey = originalKey {
                XCTAssertTrue(KeychainHelper.write(service: keyLabel, data: originalKey, account: nil).success)
            }
        }

        // Create store
        var store = SmartStore.shared(withName: storeName)
        XCTAssertNotNil(store, "New store should have been created")

        // Create soup in store
        registerTestSoup(store!, indexType: kSoupIndexTypeString)

        // Close store
        store!.storeQueue.close()

        // Clear store map
        SmartStore.clearSharedStoreMemoryState()

        // Re-open store
        store = SmartStore.shared(withName: storeName)
        XCTAssertNotNil(store, "Existing store should have been found")
        XCTAssertTrue(store!.soupExists(forName: kTestSoupName), "Soup should still exist")

        // Close store
        store!.storeQueue.close()

        // Clear store map
        SmartStore.clearSharedStoreMemoryState()

        // Drop key
        _ = KeyGenerator.removeEncryptionKey(for: kSFSmartStoreEncryptionKeyLabel)

        // Re-open store -- but expect new empty store since key has changed
        store = SmartStore.shared(withName: storeName)
        XCTAssertNotNil(store, "A store should have been returned")
        XCTAssertFalse(store!.soupExists(forName: kTestSoupName), "Soup should no longer exist")
    }

    func testOpenDatabase() {
        for dbMgr in [DatabaseManager.sharedManager()!, DatabaseManager.sharedGlobalManager()] {
            let storeName = "awesometown"
            createDbDir(storeName, withManager: dbMgr)
            let createDb = openDatabase(storeName, withManager: dbMgr, key: "", openShouldFail: false)!
            var actualRowCount = rowCountForTable("sqlite_master", db: createDb)
            XCTAssertEqual(actualRowCount, 0, "\(storeName) should be a new database with no schema.")

            let tableName = "My_Table"
            createTestTable(tableName, db: createDb)
            actualRowCount = rowCountForTable("sqlite_master", db: createDb)
            XCTAssertEqual(actualRowCount, 1, "\(storeName) should now have one table in the DB schema.")

            createDb.close()
            let existingDb = openDatabase(storeName, withManager: dbMgr, key: "", openShouldFail: false)!
            actualRowCount = rowCountForTable("sqlite_master", db: existingDb)
            XCTAssertEqual(actualRowCount, 1, "Existing database \(storeName) should have one table in the DB schema.")

            existingDb.close()
            dbMgr.removeStoreDir(storeName)
        }
    }

    func testEncryptDatabase() {
        let storeName = "nunyaBusiness"

        for dbMgr in [DatabaseManager.sharedManager()!, DatabaseManager.sharedGlobalManager()] {
            createDbDir(storeName, withManager: dbMgr)
            let unencryptedDb = openDatabase(storeName, withManager: dbMgr, key: "", openShouldFail: false)!
            let tableName = "My_Table"
            createTestTable(tableName, db: unencryptedDb)
            XCTAssertTrue(tableNameInMaster(tableName, db: unencryptedDb), "Table \(tableName) should have been added to sqlite_master.")

            let encKey = "BigSecret"
            var encryptError: NSError?
            let encryptedDb = dbMgr.encryptDb(unencryptedDb, name: storeName, key: encKey, salt: nil, error: &encryptError)
            XCTAssertNotNil(encryptedDb, "Encrypted DB should be a valid object.")
            XCTAssertNil(encryptError, "Error encrypting the DB: \(encryptError?.localizedDescription ?? "")")
            XCTAssertTrue(tableNameInMaster(tableName, db: encryptedDb!), "Table \(tableName) should still exist in sqlite_master, for encrypted DB.")
            encryptedDb?.close()

            // Try to open the DB with an empty key, verify no read access
            let encryptedDbEmptyKey = openDatabase(storeName, withManager: dbMgr, key: "", openShouldFail: true)
            XCTAssertNil(encryptedDbEmptyKey, "Shouldn't be able to read encrypted database, opened as unencrypted.")
            encryptedDbEmptyKey?.close()

            // Try to read the encrypted database with the wrong key
            let encryptedDbWrongKey = openDatabase(storeName, withManager: dbMgr, key: "WrongKey", openShouldFail: true)
            XCTAssertNil(encryptedDbWrongKey, "Shouldn't be able to read encrypted database, opened with the wrong key.")
            encryptedDbWrongKey?.close()

            // Finally, try to re-open the encrypted database with the right key
            let encryptedDbCorrectKey = openDatabase(storeName, withManager: dbMgr, key: encKey, openShouldFail: false)!
            XCTAssertTrue(tableNameInMaster(tableName, db: encryptedDbCorrectKey), "Should find the original table name in sqlite_master, with proper encryption key.")
            encryptedDbCorrectKey.close()

            dbMgr.removeStoreDir(storeName)
        }
    }

    func testUnencryptDatabase() {
        let storeName = "lookAtThatData"

        for dbMgr in [DatabaseManager.sharedManager()!, DatabaseManager.sharedGlobalManager()] {
            createDbDir(storeName, withManager: dbMgr)
            let encKey = "GiantSecret"
            let encryptedDb = openDatabase(storeName, withManager: dbMgr, key: encKey, openShouldFail: false)!
            let tableName = "My_Table"
            createTestTable(tableName, db: encryptedDb)
            XCTAssertTrue(tableNameInMaster(tableName, db: encryptedDb), "Table \(tableName) should have been added to sqlite_master.")
            encryptedDb.close()

            // Verify that we can't read data with a plaintext DB open
            let encryptedDbEmptyKey = openDatabase(storeName, withManager: dbMgr, key: "", openShouldFail: true)
            XCTAssertNil(encryptedDbEmptyKey, "Shouldn't be able to read encrypted database, opened as unencrypted.")
            encryptedDbEmptyKey?.close()

            // Unencrypt the database, verify data
            let encryptedDb2 = openDatabase(storeName, withManager: dbMgr, key: encKey, openShouldFail: false)!
            var unencryptError: NSError?
            let unencryptedDb2 = dbMgr.unencryptDb(encryptedDb2, name: storeName, oldKey: encKey, salt: nil, error: &unencryptError)
            XCTAssertNil(unencryptError, "Error unencrypting the database: \(unencryptError?.localizedDescription ?? "")")
            XCTAssertTrue(tableNameInMaster(tableName, db: unencryptedDb2!), "Table should be present in unencrypted DB.")
            unencryptedDb2?.close()

            // Open the database with no key, out of band - verify data
            let unencryptedDb3 = openDatabase(storeName, withManager: dbMgr, key: "", openShouldFail: false)!
            XCTAssertTrue(tableNameInMaster(tableName, db: unencryptedDb3), "Table should be present in unencrypted DB.")
            unencryptedDb3.close()

            dbMgr.removeStoreDir(storeName)
        }
    }

    func testAllStoreNames() {
        // Test with no stores
        store = nil
        globalStore = nil
        SmartStore.removeShared(withName: kTestSmartStoreName)
        SmartStore.removeSharedGlobal(withName: kTestSmartStoreName)

        for dbMgr in [DatabaseManager.sharedManager()!, DatabaseManager.sharedGlobalManager()] {
            let noStoresArray = dbMgr.allStoreNames()
            if let noStoresArray = noStoresArray {
                XCTAssertEqual(noStoresArray.count, 0, "There should not be any stores defined. Count = \(noStoresArray.count)")
            }

            // Create some stores - verify them
            let numStores = Int(arc4random() % 20 + 1)
            var initialStoreList = Set<String>()
            let tableName = "My_Table"
            for i in 0..<numStores {
                let storeName = "myStore\(i + 1)"
                createDbDir(storeName, withManager: dbMgr)
                let db = openDatabase(storeName, withManager: dbMgr, key: "", openShouldFail: false)!
                createTestTable(tableName, db: db)
                db.close()
                initialStoreList.insert(storeName)
            }
            let allStoresStoreList = Set(dbMgr.allStoreNames() ?? [])
            XCTAssertEqual(initialStoreList, allStoresStoreList, "Store list is not equal!")

            // Cleanup
            for storeName in initialStoreList {
                dbMgr.removeStoreDir(storeName)
            }
        }
    }

    func testGetDatabaseSize() {
        for store in [self.store!, self.globalStore!] {
            let initialSize = store.databaseSize()

            let soupIndex: [String: String] = ["path": "name", "type": "string"]
            try! store.registerSoup(withName: kTestSoupName, withIndices: SoupIndex.asArray([soupIndex]))

            var entries: [NSDictionary] = []
            for i in 0..<100 {
                entries.append(["name": "name_\(i)", "value": "value_\(i)"])
            }
            store.upsert(entries: entries, forSoupNamed: kTestSoupName)

            XCTAssertTrue(store.databaseSize() > initialSize, "Database size should be larger")
        }
    }

    func testReadMultiByteCharacterAroundBufferBoundary() {
        var text = ""
        for _ in 0..<(kBufferSize - 1) {
            text.append("A")
        }
        // Let's use the character that uses 4 bytes (internally stored as UTF-16 surrogate pair)
        text.append("\u{1D11E}")
        for _ in 0..<125 {
            text.append("B")
        }
        let inputStream = InputStream(data: text.data(using: .utf8)!)
        let outputText = SmartStore.string(from: inputStream)
        XCTAssertEqual(text, outputText)
    }

    func testValidQueryWithStoreCursor() {
        for store in [self.store!, self.globalStore!] {
            let soupIndex: [String: String] = ["path": "key", "type": "string"]
            try! store.registerSoup(withName: kTestSoupName, withIndices: SoupIndex.asArray([soupIndex]))

            let soupElt0: NSDictionary = ["key": "ka1", "value": "va1", "otherValue": "ova1"]
            let soupElt1: NSDictionary = ["key": "ka2", "value": "va2", "otherValue": "ova2"]
            let soupElt2: NSDictionary = ["key": "ka3", "value": "va3", "otherValue": "ova3"]
            store.upsert(entries: [soupElt0, soupElt1, soupElt2], forSoupNamed: kTestSoupName)

            let querySpec = QuerySpec.buildAllQuerySpec(soupName: kTestSoupName, orderPath: "key", order: .ascending, pageSize: 2)

            // Run query with cursor
            let cursor = StoreCursor(store: store, querySpec: querySpec)
            let serializedCursorStr = try! cursor.getDataSerialized(store)
            let serializedCursorDeserialized = SFJsonUtils.object(from: serializedCursorStr!) as! [String: Any]
            let cursorDeserialized = try! cursor.getDataDeserialized(store)!

            // Check cursor
            XCTAssertEqual(cursor.pageSize, 2, "Wrong page size")
            XCTAssertEqual(cursor.currentPageIndex, 0, "Wrong page index")
            XCTAssertEqual(cursor.totalPages, 2, "Wrong total pages count")
            XCTAssertEqual(cursor.totalEntries, 3, "Wrong total entries count")

            // Check serialized cursor
            XCTAssertEqual(serializedCursorDeserialized["pageSize"] as? Int, 2, "Wrong page size")
            XCTAssertEqual(serializedCursorDeserialized["currentPageIndex"] as? Int, 0, "Wrong page index")
            XCTAssertEqual(serializedCursorDeserialized["totalPages"] as? Int, 2, "Wrong total pages count")
            XCTAssertEqual(serializedCursorDeserialized["totalEntries"] as? Int, 3, "Wrong total entries count")
            var currentPageOrderedEntries = serializedCursorDeserialized["currentPageOrderedEntries"] as! [[String: Any]]
            XCTAssertEqual(currentPageOrderedEntries.count, 2, "Wrong entries count in page")
            XCTAssertEqual(currentPageOrderedEntries[0]["key"] as? String, "ka1", "Wrong first entry")
            XCTAssertEqual(currentPageOrderedEntries[1]["key"] as? String, "ka2", "Wrong second entry")

            // Check deserialized cursor
            XCTAssertEqual(cursorDeserialized["pageSize"] as? Int, 2, "Wrong page size")
            XCTAssertEqual(cursorDeserialized["currentPageIndex"] as? Int, 0, "Wrong page index")
            XCTAssertEqual(cursorDeserialized["totalPages"] as? Int, 2, "Wrong total pages count")
            XCTAssertEqual(cursorDeserialized["totalEntries"] as? Int, 3, "Wrong total entries count")
            currentPageOrderedEntries = cursorDeserialized["currentPageOrderedEntries"] as! [[String: Any]]
            XCTAssertEqual(currentPageOrderedEntries.count, 2, "Wrong entries count in page")
            XCTAssertEqual(currentPageOrderedEntries[0]["key"] as? String, "ka1", "Wrong first entry")
            XCTAssertEqual(currentPageOrderedEntries[1]["key"] as? String, "ka2", "Wrong second entry")
        }
    }

    func testInvalidQueryWithStoreCursor() {
        for store in [self.store!, self.globalStore!] {
            XCTAssertFalse(store.soupExists(forName: kTestSoupName))

            let querySpec = QuerySpec.buildAllQuerySpec(soupName: kTestSoupName, orderPath: "key", order: .ascending, pageSize: 2)
            let cursor = StoreCursor(store: store, querySpec: querySpec)

            // Run query by getting serialized data from cursor
            do {
                _ = try cursor.getDataSerialized(store)
                XCTFail("Should have thrown an error")
            } catch {
                // Expected
            }

            // Run query by getting deserialized data from cursor
            do {
                _ = try cursor.getDataDeserialized(store)
                XCTFail("Should have thrown an error")
            } catch {
                // Expected
            }
        }
    }

    func testInvalidQueryWithStoreCursorWithRawJsonCheckOn() {
        SmartStore.jsonSerializationCheckEnabled = true
        for store in [self.store!, self.globalStore!] {
            XCTAssertFalse(store.soupExists(forName: kTestSoupName))

            let querySpec = QuerySpec.buildAllQuerySpec(soupName: kTestSoupName, orderPath: "key", order: .ascending, pageSize: 2)

            // Setup notification observer
            let expectation = XCTestExpectation(description: "JSON parse error notification")
            expectation.isInverted = true
            let observer = NotificationCenter.default.addObserver(forName: NSNotification.Name(kSFSmartStoreJSONParseErrorNotification), object: nil, queue: nil) { _ in
                expectation.fulfill()
            }

            // Run query with cursor
            let cursor = StoreCursor(store: store, querySpec: querySpec)
            do {
                _ = try cursor.getDataSerialized(store)
                XCTFail("Should have thrown an error")
            } catch {
                // Expected
            }

            // Wait for notification (timeout expected)
            wait(for: [expectation], timeout: 1)
            NotificationCenter.default.removeObserver(observer)
        }
        SmartStore.jsonSerializationCheckEnabled = false
    }

    // MARK: - Helper methods

    private func createDbDir(_ dbName: String, withManager dbMgr: DatabaseManager) {
        let result = dbMgr.createStoreDir(dbName)
        XCTAssertTrue(result, "Create db dir failed")
    }

    private func openDatabase(_ dbName: String, withManager dbMgr: DatabaseManager, key: String, openShouldFail: Bool) -> FMDatabase? {
        var openDbError: NSError?
        let db = dbMgr.openStoreDatabase(withName: dbName, key: key, salt: nil, error: &openDbError)
        if openShouldFail {
            XCTAssertNil(db, "Opening database should have failed.")
        } else {
            XCTAssertNotNil(db, "Opening database with name '\(dbName)' should have returned a non-nil DB object. Error: \(openDbError?.localizedDescription ?? "")")
        }
        return db
    }

    private func createTestTable(_ tableName: String, db: FMDatabase) {
        let tableSql = "CREATE TABLE IF NOT EXISTS \(tableName) (Col1 TEXT, Col2 TEXT, Col3 TEXT, Col4 TEXT)"
        let createSucceeded = db.executeUpdate(tableSql, withArgumentsIn: [])
        XCTAssertTrue(createSucceeded, "Could not create table \(tableName): \(db.lastErrorMessage())")
    }

    private func rowCountForTable(_ tableName: String, db: FMDatabase) -> Int32 {
        let rowCountQuery = "SELECT COUNT(*) FROM \(tableName)"
        if let rs = db.executeQuery(rowCountQuery, withArgumentsIn: []) {
            if rs.next() {
                let count = rs.int(forColumnIndex: 0)
                rs.close()
                return count
            }
            rs.close()
        }
        return 0
    }

    private func tableNameInMaster(_ tableName: String, db: FMDatabase) -> Bool {
        let origCrashOnErrors = db.crashOnErrors
        db.crashOnErrors = false

        let querySql = "SELECT * FROM sqlite_master WHERE name = ?"
        let rs = db.executeQuery(querySql, withArgumentsIn: [tableName])
        var result = true
        if rs == nil || !(rs?.next() ?? false) {
            result = false
        }
        rs?.close()
        db.crashOnErrors = origCrashOnErrors
        return result
    }

    private func registerTestSoup(_ store: SmartStore, indexType: String) {
        try! store.registerSoup(withName: kTestSoupName, withIndices: SoupIndex.asArray([["path": "key", "type": indexType], ["path": "value", "type": kSoupIndexTypeString]]))
        XCTAssertTrue(store.soupExists(forName: kTestSoupName), "Soup should exist after registration")
    }
}
