import XCTest
@testable import SmartStore

class SFQuerySpecTests: SFSmartStoreTestCase {

    override func setUp() {
        super.setUp()
        SmartStoreLogger.setLogLevel(.debug)
    }

    // MARK: - All Query

    func testAllQuerySmartSql() {
        let querySpec = QuerySpec.buildAllQuerySpec(soupName: "employees", orderPath: "lastName", order: .descending, pageSize: 1)
        XCTAssertEqual(querySpec.smartSql, "SELECT {employees:_soup} FROM {employees} ORDER BY {employees:lastName} DESC ", "Wrong smart sql for all query spec")
    }

    func testAllQuerySmartSqlWithSelectPaths() {
        let querySpec = QuerySpec.buildAllQuerySpec(soupName: "employees", selectPaths: ["firstName", "lastName"], orderPath: "lastName", order: .descending, pageSize: 1)
        XCTAssertEqual(querySpec.smartSql, "SELECT {employees:firstName}, {employees:lastName} FROM {employees} ORDER BY {employees:lastName} DESC ", "Wrong ids smart sql for all query spec with select paths")
    }

    func testAllQueryCountSmartSql() {
        let querySpec = QuerySpec.buildAllQuerySpec(soupName: "employees", orderPath: "lastName", order: .descending, pageSize: 1)
        XCTAssertEqual(querySpec.countSmartSql, "SELECT count(*) FROM {employees} ", "Wrong count smart sql for all query spec")
    }

    func testAllQueryIdsSmartSql() {
        let querySpec = QuerySpec.buildAllQuerySpec(soupName: "employees", orderPath: "lastName", order: .descending, pageSize: 1)
        XCTAssertEqual(querySpec.idsSmartSql, "SELECT id FROM {employees} ORDER BY {employees:lastName} DESC ", "Wrong ids smart sql for all query spec")
    }

    // MARK: - Range Query

    func testRangeQuerySmartSql() {
        let querySpec = QuerySpec.buildRangeQuerySpec(soupName: "employees", path: "lastName", beginKey: "Bond", endKey: "Smith", orderPath: "lastName", order: .ascending, pageSize: 1)
        XCTAssertEqual(querySpec.smartSql, "SELECT {employees:_soup} FROM {employees} WHERE {employees:lastName} >= ? AND {employees:lastName} <= ? ORDER BY {employees:lastName} ASC ", "Wrong smart sql for range query spec")
    }

    func testRangeQuerySmartSqlWithSelectPaths() {
        let querySpec = QuerySpec.buildRangeQuerySpec(soupName: "employees", selectPaths: ["firstName"], path: "lastName", beginKey: "Bond", endKey: "Smith", orderPath: "lastName", order: .ascending, pageSize: 1)
        XCTAssertEqual(querySpec?.smartSql, "SELECT {employees:firstName} FROM {employees} WHERE {employees:lastName} >= ? AND {employees:lastName} <= ? ORDER BY {employees:lastName} ASC ", "Wrong smart sql for range query spec with select paths")
    }

    func testRangeQueryCountSmartSql() {
        let querySpec = QuerySpec.buildRangeQuerySpec(soupName: "employees", path: "lastName", beginKey: "Bond", endKey: "Smith", orderPath: "lastName", order: .ascending, pageSize: 1)
        XCTAssertEqual(querySpec.countSmartSql, "SELECT count(*) FROM {employees} WHERE {employees:lastName} >= ? AND {employees:lastName} <= ? ", "Wrong count smart sql for range query spec")
    }

    func testRangeQueryIdsSmartSql() {
        let querySpec = QuerySpec.buildRangeQuerySpec(soupName: "employees", path: "lastName", beginKey: "Bond", endKey: "Smith", orderPath: "lastName", order: .ascending, pageSize: 1)
        XCTAssertEqual(querySpec.idsSmartSql, "SELECT id FROM {employees} WHERE {employees:lastName} >= ? AND {employees:lastName} <= ? ORDER BY {employees:lastName} ASC ", "Wrong ids smart sql for range query spec")
    }

    // MARK: - Exact Query

    func testExactQuerySmartSql() {
        let querySpec = QuerySpec.buildExactQuerySpec(soupName: "employees", path: "lastName", matchKey: "Bond", orderPath: "lastName", order: .ascending, pageSize: 1)
        XCTAssertEqual(querySpec.smartSql, "SELECT {employees:_soup} FROM {employees} WHERE {employees:lastName} = ? ORDER BY {employees:lastName} ASC ", "Wrong smart sql for exact query spec")
    }

    func testExactQuerySmartSqlWithSelectPaths() {
        let querySpec = QuerySpec.buildExactQuerySpec(soupName: "employees", selectPaths: ["firstName", "lastName"], path: "lastName", matchKey: "Bond", orderPath: "lastName", order: .ascending, pageSize: 1)
        XCTAssertEqual(querySpec?.smartSql, "SELECT {employees:firstName}, {employees:lastName} FROM {employees} WHERE {employees:lastName} = ? ORDER BY {employees:lastName} ASC ", "Wrong smart sql for exact query spec with select paths")
    }

    func testExactQueryCountSmartSql() {
        let querySpec = QuerySpec.buildExactQuerySpec(soupName: "employees", path: "lastName", matchKey: "Bond", orderPath: "lastName", order: .ascending, pageSize: 1)
        XCTAssertEqual(querySpec.countSmartSql, "SELECT count(*) FROM {employees} WHERE {employees:lastName} = ? ", "Wrong count smart sql for exact query spec")
    }

    func testExactQueryIdsSmartSql() {
        let querySpec = QuerySpec.buildExactQuerySpec(soupName: "employees", path: "lastName", matchKey: "Bond", orderPath: "lastName", order: .ascending, pageSize: 1)
        XCTAssertEqual(querySpec.idsSmartSql, "SELECT id FROM {employees} WHERE {employees:lastName} = ? ORDER BY {employees:lastName} ASC ", "Wrong ids smart sql for exact query spec")
    }

    // MARK: - Match Query

    func testMatchQuerySmartSql() {
        let querySpec = QuerySpec.buildMatchQuerySpec(soupName: "employees", path: "lastName", matchKey: "Bond", orderPath: "firstName", order: .ascending, pageSize: 1)
        XCTAssertEqual(querySpec.smartSql, "SELECT {employees:_soup} FROM {employees} WHERE {employees:_soupEntryId} IN (SELECT rowid FROM {employees}_fts WHERE {employees}_fts MATCH '{employees:lastName}:Bond') ORDER BY {employees:firstName} ASC ", "Wrong smart sql for match query spec")
    }

    func testMatchQuerySmartSqlWithSelectPaths() {
        let querySpec = QuerySpec.buildMatchQuerySpec(soupName: "employees", selectPaths: ["firstName", "lastName", "title"], path: "lastName", matchKey: "Bond", orderPath: "firstName", order: .ascending, pageSize: 1)
        XCTAssertEqual(querySpec?.smartSql, "SELECT {employees:firstName}, {employees:lastName}, {employees:title} FROM {employees} WHERE {employees:_soupEntryId} IN (SELECT rowid FROM {employees}_fts WHERE {employees}_fts MATCH '{employees:lastName}:Bond') ORDER BY {employees:firstName} ASC ", "Wrong smart sql for match query spec with select paths")
    }

    func testMatchQueryCountSmartSql() {
        let querySpec = QuerySpec.buildMatchQuerySpec(soupName: "employees", path: "lastName", matchKey: "Bond", orderPath: "firstName", order: .ascending, pageSize: 1)
        XCTAssertEqual(querySpec.countSmartSql, "SELECT count(*) FROM {employees} WHERE {employees:_soupEntryId} IN (SELECT rowid FROM {employees}_fts WHERE {employees}_fts MATCH '{employees:lastName}:Bond') ", "Wrong count smart sql for match query spec")
    }

    func testMatchQueryIdsSmartSql() {
        let querySpec = QuerySpec.buildMatchQuerySpec(soupName: "employees", path: "lastName", matchKey: "Bond", orderPath: "firstName", order: .ascending, pageSize: 1)
        XCTAssertEqual(querySpec.idsSmartSql, "SELECT id FROM {employees} WHERE {employees:_soupEntryId} IN (SELECT rowid FROM {employees}_fts WHERE {employees}_fts MATCH '{employees:lastName}:Bond') ORDER BY {employees:firstName} ASC ", "Wrong ids smart sql for match query spec")
    }

    // MARK: - Like Query

    func testLikeQuerySmartSql() {
        let querySpec = QuerySpec.buildLikeQuerySpec(soupName: "employees", path: "lastName", likeKey: "Bon%", orderPath: "lastName", order: .ascending, pageSize: 1)
        XCTAssertEqual(querySpec.smartSql, "SELECT {employees:_soup} FROM {employees} WHERE {employees:lastName} LIKE ? ORDER BY {employees:lastName} ASC ", "Wrong smart sql for like query spec")
    }

    func testLikeQuerySmartSqlWithSelectPaths() {
        let querySpec = QuerySpec.buildLikeQuerySpec(soupName: "employees", selectPaths: ["title"], path: "lastName", likeKey: "Bon%", orderPath: "lastName", order: .ascending, pageSize: 1)
        XCTAssertEqual(querySpec?.smartSql, "SELECT {employees:title} FROM {employees} WHERE {employees:lastName} LIKE ? ORDER BY {employees:lastName} ASC ", "Wrong smart sql for like query spec")
    }

    func testLikeQueryCountSmartSql() {
        let querySpec = QuerySpec.buildLikeQuerySpec(soupName: "employees", path: "lastName", likeKey: "Bon%", orderPath: "lastName", order: .ascending, pageSize: 1)
        XCTAssertEqual(querySpec.countSmartSql, "SELECT count(*) FROM {employees} WHERE {employees:lastName} LIKE ? ", "Wrong count smart sql for like query spec")
    }

    func testLikeQueryIdsSmartSql() {
        let querySpec = QuerySpec.buildLikeQuerySpec(soupName: "employees", path: "lastName", likeKey: "Bon%", orderPath: "lastName", order: .ascending, pageSize: 1)
        XCTAssertEqual(querySpec.idsSmartSql, "SELECT id FROM {employees} WHERE {employees:lastName} LIKE ? ORDER BY {employees:lastName} ASC ", "Wrong ids smart sql for like query spec")
    }

    // MARK: - Smart Query

    func testSmartQueryCountSmartSql() {
        let querySpec = QuerySpec.buildSmartQuerySpec(smartSql: "select {employees:salary} from {employees} where {employees:lastName} = 'Haas'", pageSize: 1)
        XCTAssertEqual(querySpec?.countSmartSql, "SELECT count(*) FROM (select {employees:salary} from {employees} where {employees:lastName} = 'Haas')", "Wrong count smart sql")
    }

    func testSmartQueryIdsSmartSql() {
        let querySpec = QuerySpec.buildSmartQuerySpec(smartSql: "select {employees:salary} from {employees} where {employees:lastName} = 'Haas'", pageSize: 1)
        XCTAssertEqual(querySpec?.idsSmartSql, "SELECT id FROM (select {employees:salary} from {employees} where {employees:lastName} = 'Haas')", "Wrong ids smart sql")
    }

    // MARK: - Qualify Match Key

    func testQualifyMatchKey() {
        XCTAssertEqual(QuerySpec.qualifyMatchKey("abc", field: nil), "abc", "Wrong qualified match query")
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
