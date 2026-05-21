/*
 Copyright (c) 2016-present, salesforce.com, inc. All rights reserved.

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

class SFSmartStoreLoadTests: SFSmartStoreTestCase {

    // MARK: - Constants

    private let numberEntries = 1000
    private let numberEntriesPerBatch = 100
    private let msInS: Double = 1000
    private let testSmartStore = "testSmartStore"
    private let testSoup = "testSoup"

    // MARK: - Properties

    private var smartStoreUser: UserAccount!
    private var store: SmartStore!

    // MARK: - Setup and Teardown

    override func setUp() {
        super.setUp()
        SmartStoreLogger.setLogLevel(.debug)
        smartStoreUser = setUpSmartStoreUser()
        store = SmartStore.shared(withName: testSmartStore)
    }

    override func tearDown() {
        SmartStore.removeShared(withName: testSmartStore)
        tearDownSmartStoreUser(smartStoreUser)
        super.tearDown()
        smartStoreUser = nil
        store = nil
    }

    // MARK: - Tests

    func testUpsertQuery1StringIndex1field20characters() {
        tryUpsertQuery(indexType: kSoupIndexTypeString, numberEntries: numberEntries, numberFieldsPerEntry: 1, numberCharactersPerField: 20, numberIndexes: 1)
    }

    func testUpsertQuery1StringIndex1field1000characters() {
        tryUpsertQuery(indexType: kSoupIndexTypeString, numberEntries: numberEntries, numberFieldsPerEntry: 1, numberCharactersPerField: 1000, numberIndexes: 1)
    }

    func testUpsertQuery1StringIndex10fields20characters() {
        tryUpsertQuery(indexType: kSoupIndexTypeString, numberEntries: numberEntries, numberFieldsPerEntry: 10, numberCharactersPerField: 20, numberIndexes: 1)
    }

    func testUpsertQuery10StringIndexes10fields20characters() {
        tryUpsertQuery(indexType: kSoupIndexTypeString, numberEntries: numberEntries, numberFieldsPerEntry: 10, numberCharactersPerField: 20, numberIndexes: 10)
    }

    func testUpsertQuery1JSON1Index1field20characters() {
        tryUpsertQuery(indexType: kSoupIndexTypeJSON1, numberEntries: numberEntries, numberFieldsPerEntry: 1, numberCharactersPerField: 20, numberIndexes: 1)
    }

    func testUpsertQuery1JSON1Index1field1000characters() {
        tryUpsertQuery(indexType: kSoupIndexTypeJSON1, numberEntries: numberEntries, numberFieldsPerEntry: 1, numberCharactersPerField: 1000, numberIndexes: 1)
    }

    func testUpsertQuery1JSON1Index10fields20characters() {
        tryUpsertQuery(indexType: kSoupIndexTypeJSON1, numberEntries: numberEntries, numberFieldsPerEntry: 10, numberCharactersPerField: 20, numberIndexes: 1)
    }

    func testUpsertQuery10JSON1Indexes10fields20characters() {
        tryUpsertQuery(indexType: kSoupIndexTypeJSON1, numberEntries: numberEntries, numberFieldsPerEntry: 10, numberCharactersPerField: 20, numberIndexes: 10)
    }

    func testAlterSoupClassicIndexing() {
        tryAlterSoup(indexType: kSoupIndexTypeString)
    }

    func testAlterSoupJSON1Indexing() {
        tryAlterSoup(indexType: kSoupIndexTypeJSON1)
    }

    // MARK: - Helper Methods

    private func tryUpsertQuery(indexType: String, numberEntries: Int, numberFieldsPerEntry: Int, numberCharactersPerField: Int, numberIndexes: Int) {
        setupSoup(soupName: testSoup, numberIndexes: numberIndexes, indexType: indexType)
        upsertEntries(numberBatches: numberEntries / numberEntriesPerBatch, numberEntriesPerBatch: numberEntriesPerBatch, numberFieldsPerEntry: numberFieldsPerEntry, numberCharactersPerField: numberCharactersPerField)
        queryEntries()
    }

    private func setupSoup(soupName: String, numberIndexes: Int, indexType: String) {
        var indexSpecs: [[String: String]] = []
        for indexNumber in 0..<numberIndexes {
            indexSpecs.append([kSoupIndexPath: "k_\(indexNumber)", kSoupIndexType: indexType])
        }
        let indices = SoupIndex.asArraySoupIndexes(indexSpecs)
        do {
            try store.registerSoup(withName: soupName, withIndices: indices)
        } catch {
            XCTFail("There should be no errors: \(error)")
        }
        SmartStoreLogger.d(type(of: self), message: "Creating table with \(numberIndexes) \(indexType) indexes")
    }

    private func upsertEntries(numberBatches: Int, numberEntriesPerBatch: Int, numberFieldsPerEntry: Int, numberCharactersPerField: Int) {
        var times: [Double] = []
        for batchNumber in 0..<numberBatches {
            let start = Date()
            var entries: [[String: Any]] = []
            for entryNumber in 0..<numberEntriesPerBatch {
                var entry: [String: Any] = [:]
                for fieldNumber in 0..<numberFieldsPerEntry {
                    let value = pad("v_\(batchNumber)_\(entryNumber)_\(fieldNumber)_", numberCharacters: numberCharactersPerField)
                    entry["k_\(fieldNumber)"] = value
                }
                entries.append(entry)
            }
            store.upsert(entries: entries, forSoupNamed: testSoup)
            let end = Date()
            times.append(end.timeIntervalSince(start) * msInS)
        }
        let avgMilliseconds = average(times)
        SmartStoreLogger.d(type(of: self), message: "Upserting \(numberBatches * numberEntriesPerBatch) entries with \(numberEntriesPerBatch) per batch with \(numberFieldsPerEntry) fields with \(numberCharactersPerField) characters: average time per batch --> \(String(format: "%.3f", avgMilliseconds)) ms")
    }

    private func queryEntries() {
        // Should find all
        queryEntries(QuerySpec.buildAllQuerySpec(soupName: testSoup, orderPath: "", order: .ascending, pageSize: 10))
        queryEntries(QuerySpec.buildAllQuerySpec(soupName: testSoup, orderPath: "", order: .ascending, pageSize: 100))

        // Should find 100
        queryEntries(QuerySpec.buildLikeQuerySpec(soupName: testSoup, path: "k_0", likeKey: "v_0_%", orderPath: "", order: .ascending, pageSize: 1))
        queryEntries(QuerySpec.buildLikeQuerySpec(soupName: testSoup, path: "k_0", likeKey: "v_0_%", orderPath: "", order: .ascending, pageSize: 10))
        queryEntries(QuerySpec.buildLikeQuerySpec(soupName: testSoup, path: "k_0", likeKey: "v_0_%", orderPath: "", order: .ascending, pageSize: 100))

        // Should find 10
        queryEntries(QuerySpec.buildLikeQuerySpec(soupName: testSoup, path: "k_0", likeKey: "v_0_0_%", orderPath: "", order: .ascending, pageSize: 1))
        queryEntries(QuerySpec.buildLikeQuerySpec(soupName: testSoup, path: "k_0", likeKey: "v_0_0_%", orderPath: "", order: .ascending, pageSize: 10))

        // Should find none
        queryEntries(QuerySpec.buildExactQuerySpec(soupName: testSoup, path: "k_0", matchKey: "missing", orderPath: "", order: .ascending, pageSize: 1))
    }

    private func queryEntries(_ querySpec: QuerySpec) {
        var times: [Double] = []
        var countMatches = 0
        var hasMore = true
        var pageIndex: UInt = 0
        while hasMore {
            let start = Date()
            do {
                let results = try store.query(using: querySpec, startingFromPageIndex: pageIndex)
                let end = Date()
                times.append(end.timeIntervalSince(start) * msInS)
                hasMore = (results.count == Int(querySpec.pageSize))
                countMatches += results.count
            } catch {
                XCTFail("There should be no errors: \(error)")
                hasMore = false
            }
            pageIndex += 1
        }
        let avgMilliseconds = average(times)
        let queryTypeDict = querySpec.asDictionary()
        let queryType = queryTypeDict[kQuerySpecParamQueryType] as? String ?? "unknown"
        SmartStoreLogger.d(type(of: self), message: "Querying with \(queryType) query matching \(countMatches) entries and \(querySpec.pageSize) page size: average time per page --> \(String(format: "%.3f", avgMilliseconds)) ms")
    }

    private func pad(_ s: String, numberCharacters: Int) -> String {
        var result = s
        while result.count < numberCharacters {
            result += "x"
        }
        return result
    }

    private func average(_ times: [Double]) -> Double {
        guard !times.isEmpty else { return 0 }
        return times.reduce(0, +) / Double(times.count)
    }

    private func tryAlterSoup(indexType: String) {
        SmartStoreLogger.d(type(of: self), message: "Initial database size: \(store.databaseSize()) bytes")
        setupSoup(soupName: testSoup, numberIndexes: 1, indexType: indexType)
        upsertEntries(numberBatches: numberEntries / numberEntriesPerBatch, numberEntriesPerBatch: numberEntriesPerBatch, numberFieldsPerEntry: 10, numberCharactersPerField: 20)
        SmartStoreLogger.d(type(of: self), message: "Database size after: \(store.databaseSize()) bytes")

        // Without indexing for new index specs
        alterSoup(msg: "Adding one index / no re-indexing", reIndexData: false, indexSpecs: SoupIndex.asArraySoupIndexes([
            [kSoupIndexPath: "k_0", kSoupIndexType: indexType],
            [kSoupIndexPath: "k_1", kSoupIndexType: indexType]
        ]))
        alterSoup(msg: "Adding one index / dropping one index / no re-indexing", reIndexData: false, indexSpecs: SoupIndex.asArraySoupIndexes([
            [kSoupIndexPath: "k_0", kSoupIndexType: indexType],
            [kSoupIndexPath: "k_2", kSoupIndexType: indexType]
        ]))
        alterSoup(msg: "Dropping one index / no re-indexing", reIndexData: false, indexSpecs: SoupIndex.asArraySoupIndexes([
            [kSoupIndexPath: "k_0", kSoupIndexType: indexType]
        ]))

        // With indexing for new index specs
        alterSoup(msg: "Adding one index / with re-indexing", reIndexData: true, indexSpecs: SoupIndex.asArraySoupIndexes([
            [kSoupIndexPath: "k_0", kSoupIndexType: indexType],
            [kSoupIndexPath: "k_1", kSoupIndexType: indexType]
        ]))
        alterSoup(msg: "Adding one index / dropping one index / with re-indexing", reIndexData: true, indexSpecs: SoupIndex.asArraySoupIndexes([
            [kSoupIndexPath: "k_0", kSoupIndexType: indexType],
            [kSoupIndexPath: "k_2", kSoupIndexType: indexType]
        ]))
        alterSoup(msg: "Dropping one index / with re-indexing", reIndexData: true, indexSpecs: SoupIndex.asArraySoupIndexes([
            [kSoupIndexPath: "k_0", kSoupIndexType: indexType]
        ]))
    }

    private func alterSoup(msg: String, reIndexData: Bool, indexSpecs: [SoupIndex]) {
        let start = Date()
        store.alterSoup(named: testSoup, indexSpecs: indexSpecs, reIndexData: reIndexData)
        let end = Date()
        let duration = end.timeIntervalSince(start) * msInS
        SmartStoreLogger.d(type(of: self), message: "\(msg) completed in: \(String(format: "%.3f", duration)) ms")
    }
}
