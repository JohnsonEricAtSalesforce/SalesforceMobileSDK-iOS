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
@testable import SmartStore

final class SFQuerySpecTests: SFSmartStoreTestCase {

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        SmartStoreLogger.setLogLevel(.debug)
    }

    // MARK: - Tests

    func testAllQuerySmartSql() {
        let querySpec = QuerySpec.buildAllQuerySpec(soupName: "employees", orderPath: "lastName", order: .descending, pageSize: 1)
        XCTAssertEqual("SELECT {employees:_soup} FROM {employees} ORDER BY {employees:lastName} DESC ", querySpec.smartSql, "Wrong smart sql for all query spec")
    }

    func testAllQuerySmartSqlWithSelectPaths() {
        let querySpec = QuerySpec.buildAllQuerySpec(soupName: "employees", selectPaths: ["firstName", "lastName"], orderPath: "lastName", order: .descending, pageSize: 1)
        XCTAssertEqual("SELECT {employees:firstName}, {employees:lastName} FROM {employees} ORDER BY {employees:lastName} DESC ", querySpec.smartSql, "Wrong ids smart sql for all query spec with select paths")
    }

    func testAllQueryCountSmartSql() {
        let querySpec = QuerySpec.buildAllQuerySpec(soupName: "employees", orderPath: "lastName", order: .descending, pageSize: 1)
        XCTAssertEqual("SELECT count(*) FROM {employees} ", querySpec.countSmartSql, "Wrong count smart sql for all query spec")
    }

    func testAllQueryIdsSmartSql() {
        let querySpec = QuerySpec.buildAllQuerySpec(soupName: "employees", orderPath: "lastName", order: .descending, pageSize: 1)
        XCTAssertEqual("SELECT id FROM {employees} ORDER BY {employees:lastName} DESC ", querySpec.idsSmartSql, "Wrong ids smart sql for all query spec")
    }

    func testRangeQuerySmartSql() {
        let querySpec = QuerySpec.buildRangeQuerySpec(soupName: "employees", path: "lastName", beginKey: "Bond", endKey: "Smith", orderPath: "lastName", order: .ascending, pageSize: 1)
        XCTAssertEqual("SELECT {employees:_soup} FROM {employees} WHERE {employees:lastName} >= ? AND {employees:lastName} <= ? ORDER BY {employees:lastName} ASC ", querySpec.smartSql, "Wrong smart sql for range query spec")
    }

    func testRangeQuerySmartSqlWithSelectPaths() {
        let querySpec = QuerySpec.buildRangeQuerySpec(soupName: "employees", selectPaths: ["firstName"], path: "lastName", beginKey: "Bond", endKey: "Smith", orderPath: "lastName", order: .ascending, pageSize: 1)!
        XCTAssertEqual("SELECT {employees:firstName} FROM {employees} WHERE {employees:lastName} >= ? AND {employees:lastName} <= ? ORDER BY {employees:lastName} ASC ", querySpec.smartSql, "Wrong smart sql for range query spec with select paths")
    }

    func testRangeQueryCountSmartSql() {
        let querySpec = QuerySpec.buildRangeQuerySpec(soupName: "employees", path: "lastName", beginKey: "Bond", endKey: "Smith", orderPath: "lastName", order: .ascending, pageSize: 1)
        XCTAssertEqual("SELECT count(*) FROM {employees} WHERE {employees:lastName} >= ? AND {employees:lastName} <= ? ", querySpec.countSmartSql, "Wrong count smart sql for range query spec")
    }

    func testRangeQueryIdsSmartSql() {
        let querySpec = QuerySpec.buildRangeQuerySpec(soupName: "employees", path: "lastName", beginKey: "Bond", endKey: "Smith", orderPath: "lastName", order: .ascending, pageSize: 1)
        XCTAssertEqual("SELECT id FROM {employees} WHERE {employees:lastName} >= ? AND {employees:lastName} <= ? ORDER BY {employees:lastName} ASC ", querySpec.idsSmartSql, "Wrong ids smart sql for range query spec")
    }

    func testExactQuerySmartSql() {
        let querySpec = QuerySpec.buildExactQuerySpec(soupName: "employees", path: "lastName", matchKey: "Bond", orderPath: "lastName", order: .ascending, pageSize: 1)
        XCTAssertEqual("SELECT {employees:_soup} FROM {employees} WHERE {employees:lastName} = ? ORDER BY {employees:lastName} ASC ", querySpec.smartSql, "Wrong smart sql for exact query spec")
    }

    func testExactQuerySmartSqlWithSelectPaths() {
        let querySpec = QuerySpec.buildExactQuerySpec(soupName: "employees", selectPaths: ["firstName", "lastName"], path: "lastName", matchKey: "Bond", orderPath: "lastName", order: .ascending, pageSize: 1)!
        XCTAssertEqual("SELECT {employees:firstName}, {employees:lastName} FROM {employees} WHERE {employees:lastName} = ? ORDER BY {employees:lastName} ASC ", querySpec.smartSql, "Wrong smart sql for exact query spec with select paths")
    }

    func testExactQueryCountSmartSql() {
        let querySpec = QuerySpec.buildExactQuerySpec(soupName: "employees", path: "lastName", matchKey: "Bond", orderPath: "lastName", order: .ascending, pageSize: 1)
        XCTAssertEqual("SELECT count(*) FROM {employees} WHERE {employees:lastName} = ? ", querySpec.countSmartSql, "Wrong count smart sql for exact query spec")
    }

    func testExactQueryIdsSmartSql() {
        let querySpec = QuerySpec.buildExactQuerySpec(soupName: "employees", path: "lastName", matchKey: "Bond", orderPath: "lastName", order: .ascending, pageSize: 1)
        XCTAssertEqual("SELECT id FROM {employees} WHERE {employees:lastName} = ? ORDER BY {employees:lastName} ASC ", querySpec.idsSmartSql, "Wrong ids smart sql for exact query spec")
    }

    func testMatchQuerySmartSql() {
        let querySpec = QuerySpec.buildMatchQuerySpec(soupName: "employees", path: "lastName", matchKey: "Bond", orderPath: "firstName", order: .ascending, pageSize: 1)
        XCTAssertEqual("SELECT {employees:_soup} FROM {employees} WHERE {employees:_soupEntryId} IN (SELECT rowid FROM {employees}_fts WHERE {employees}_fts MATCH '{employees:lastName}:Bond') ORDER BY {employees:firstName} ASC ", querySpec.smartSql, "Wrong smart sql for match query spec")
    }

    func testMatchQuerySmartSqlWithSelectPaths() {
        let querySpec = QuerySpec.buildMatchQuerySpec(soupName: "employees", selectPaths: ["firstName", "lastName", "title"], path: "lastName", matchKey: "Bond", orderPath: "firstName", order: .ascending, pageSize: 1)!
        XCTAssertEqual("SELECT {employees:firstName}, {employees:lastName}, {employees:title} FROM {employees} WHERE {employees:_soupEntryId} IN (SELECT rowid FROM {employees}_fts WHERE {employees}_fts MATCH '{employees:lastName}:Bond') ORDER BY {employees:firstName} ASC ", querySpec.smartSql, "Wrong smart sql for match query spec with select paths")
    }

    func testMatchQueryCountSmartSql() {
        let querySpec = QuerySpec.buildMatchQuerySpec(soupName: "employees", path: "lastName", matchKey: "Bond", orderPath: "firstName", order: .ascending, pageSize: 1)
        XCTAssertEqual("SELECT count(*) FROM {employees} WHERE {employees:_soupEntryId} IN (SELECT rowid FROM {employees}_fts WHERE {employees}_fts MATCH '{employees:lastName}:Bond') ", querySpec.countSmartSql, "Wrong count smart sql for match query spec")
    }

    func testMatchQueryIdsSmartSql() {
        let querySpec = QuerySpec.buildMatchQuerySpec(soupName: "employees", path: "lastName", matchKey: "Bond", orderPath: "firstName", order: .ascending, pageSize: 1)
        XCTAssertEqual("SELECT id FROM {employees} WHERE {employees:_soupEntryId} IN (SELECT rowid FROM {employees}_fts WHERE {employees}_fts MATCH '{employees:lastName}:Bond') ORDER BY {employees:firstName} ASC ", querySpec.idsSmartSql, "Wrong ids smart sql for match query spec")
    }

    func testLikeQuerySmartSql() {
        let querySpec = QuerySpec.buildLikeQuerySpec(soupName: "employees", path: "lastName", likeKey: "Bon%", orderPath: "lastName", order: .ascending, pageSize: 1)
        XCTAssertEqual("SELECT {employees:_soup} FROM {employees} WHERE {employees:lastName} LIKE ? ORDER BY {employees:lastName} ASC ", querySpec.smartSql, "Wrong smart sql for like query spec")
    }

    func testLikeQuerySmartSqlWithSelectPaths() {
        let querySpec = QuerySpec.buildLikeQuerySpec(soupName: "employees", selectPaths: ["title"], path: "lastName", likeKey: "Bon%", orderPath: "lastName", order: .ascending, pageSize: 1)!
        XCTAssertEqual("SELECT {employees:title} FROM {employees} WHERE {employees:lastName} LIKE ? ORDER BY {employees:lastName} ASC ", querySpec.smartSql, "Wrong smart sql for like query spec")
    }

    func testLikeQueryCountSmartSql() {
        let querySpec = QuerySpec.buildLikeQuerySpec(soupName: "employees", path: "lastName", likeKey: "Bon%", orderPath: "lastName", order: .ascending, pageSize: 1)
        XCTAssertEqual("SELECT count(*) FROM {employees} WHERE {employees:lastName} LIKE ? ", querySpec.countSmartSql, "Wrong count smart sql for like query spec")
    }

    func testLikeQueryIdsSmartSql() {
        let querySpec = QuerySpec.buildLikeQuerySpec(soupName: "employees", path: "lastName", likeKey: "Bon%", orderPath: "lastName", order: .ascending, pageSize: 1)
        XCTAssertEqual("SELECT id FROM {employees} WHERE {employees:lastName} LIKE ? ORDER BY {employees:lastName} ASC ", querySpec.idsSmartSql, "Wrong ids smart sql for like query spec")
    }

    func testSmartQueryCountSmartSql() {
        let querySpec = QuerySpec.buildSmartQuerySpec(smartSql: "select {employees:salary} from {employees} where {employees:lastName} = 'Haas'", pageSize: 1)!
        XCTAssertEqual("SELECT count(*) FROM (select {employees:salary} from {employees} where {employees:lastName} = 'Haas')", querySpec.countSmartSql, "Wrong count smart sql")
    }

    func testSmartQueryIdsSmartSql() {
        let querySpec = QuerySpec.buildSmartQuerySpec(smartSql: "select {employees:salary} from {employees} where {employees:lastName} = 'Haas'", pageSize: 1)!
        XCTAssertEqual("SELECT id FROM (select {employees:salary} from {employees} where {employees:lastName} = 'Haas')", querySpec.idsSmartSql, "Wrong ids smart sql")
    }

    func testQualifyMatchKey() {
        XCTAssertEqual(QuerySpec.qualifyMatchKey("abc", field: ""), "abc", "Wrong qualified match query")
        XCTAssertEqual(QuerySpec.qualifyMatchKey("abc", field: "{soup:path}"), "{soup:path}:abc", "Wrong qualified match query")
        XCTAssertEqual(QuerySpec.qualifyMatchKey("{soup:path2}:abc", field: "{soup:path1}"), "{soup:path2}:abc", "Wrong qualified match query")
        XCTAssertEqual(QuerySpec.qualifyMatchKey("abc AND def", field: "{soup:path}"), "{soup:path}:abc AND {soup:path}:def", "Wrong qualified match query")
        XCTAssertEqual(QuerySpec.qualifyMatchKey("abc OR def", field: "{soup:path}"), "{soup:path}:abc OR {soup:path}:def", "Wrong qualified match query")
        XCTAssertEqual(QuerySpec.qualifyMatchKey("abc OR {soup:path2}:def", field: "{soup:path1}"), "{soup:path1}:abc OR {soup:path2}:def", "Wrong qualified match query")
        XCTAssertEqual(QuerySpec.qualifyMatchKey("(abc AND def) OR ghi", field: "{soup:path}"), "({soup:path}:abc AND {soup:path}:def) OR {soup:path}:ghi", "Wrong qualified match query")
        XCTAssertEqual(QuerySpec.qualifyMatchKey("(abc AND {soup:path2}:def) OR ghi", field: "{soup:path1}"), "({soup:path1}:abc AND {soup:path2}:def) OR {soup:path1}:ghi", "Wrong qualified match query")
        XCTAssertEqual(QuerySpec.qualifyMatchKey("((abc AND {soup:path2}:def) AND NOT ghi) OR jkl", field: "{soup:path1}"), "(({soup:path1}:abc AND {soup:path2}:def) AND NOT {soup:path1}:ghi) OR {soup:path1}:jkl", "Wrong qualified match query")
    }
}
