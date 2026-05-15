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
import QuartzCore
@testable import SmartStore
import SalesforceSDKCore
import SalesforceSDKCommon

private let kTestStore = "testSmartSqlStore"
private let kEmployeesSoup = "employees"
private let kDepartmentsSoup = "departments"
private let kFirstName = "firstName"
private let kLastName = "lastName"
private let kDeptCode = "deptCode"
private let kEmployeeId = "employeeId"
private let kManagerId = "managerId"
private let kSalary = "salary"
private let kBudget = "budget"
private let kName = "name"
private let kEducation = "education"
private let kBuilding = "building"
private let kIsManager = "isManager"

class SFSmartSqlTests: SFSmartStoreTestCase {

    private var store: SmartStore!

    override func setUp() {
        super.setUp()
        let user = createUserAccount()
        UserAccountManager.shared.currentUserAccount = user
        store = SmartStore.shared(withName: kTestStore, forUserAccount: UserAccountManager.shared.currentUserAccount)

        // Employees soup
        try! store.registerSoup(withName: kEmployeesSoup, withIndices: SoupIndex.asArray([
            createStringIndexSpec(kFirstName),
            createStringIndexSpec(kLastName),
            createStringIndexSpec(kDeptCode),
            createStringIndexSpec(kEmployeeId),
            createStringIndexSpec(kManagerId),
            createFloatingIndexSpec(kSalary),
            createJSON1IndexSpec(kEducation),
            createJSON1IndexSpec(kIsManager)
        ]))

        // Departments soup
        try! store.registerSoup(withName: kDepartmentsSoup, withIndices: SoupIndex.asArray([
            createStringIndexSpec(kDeptCode),
            createStringIndexSpec(kName),
            createIntegerIndexSpec(kBudget),
            createJSON1IndexSpec(kBuilding)
        ]))
    }

    override func tearDown() {
        SmartStore.removeShared(withName: kTestStore, forUserAccount: UserAccountManager.shared.currentUserAccount)
        store = nil
        super.tearDown()
    }

    func createUserAccount() -> UserAccount {
        let userIdentifier = arc4random()
        let credentials = OAuthCredentials(identifier: "identifier-\(userIdentifier)", clientId: UserAccountManager.shared.oauthClientID, encrypted: true)
        let user = UserAccount(credentials: credentials)
        let userId = "user_\(userIdentifier)"
        let orgId = "org_\(userIdentifier)"
        user.credentials.identityUrl = URL(string: "https://test.salesforce.com/id/\(orgId)/\(userId)")
        _ = user.transitionToLoginState(.loggedIn)
        try? UserAccountManager.shared.loadAccounts()
        try? UserAccountManager.shared.upsert(user)
        return user
    }

    // MARK: - Tests

    func testSharedInstance() {
        let instance1 = SmartSqlHelper.shared
        let instance2 = SmartSqlHelper.shared
        XCTAssertEqual(instance1, instance2, "There should be only one instance")
    }

    func testConvertSmartSqlWithInsertUpdateDelete() {
        XCTAssertNotNil(store.convertSmartSql("select * from {employees}"), "Should not have returned nil for a proper query")
    }

    func testSimpleConvertSmartSql() {
        XCTAssertEqual("select TABLE_1_0, TABLE_1_1 from TABLE_1 order by TABLE_1_1",
                       store.convertSmartSql("select {employees:firstName}, {employees:lastName} from {employees} order by {employees:lastName}"),
                       "Bad conversion")

        XCTAssertEqual("select TABLE_2_1 from TABLE_2 order by TABLE_2_0",
                       store.convertSmartSql("select {departments:name} from {departments} order by {departments:deptCode}"),
                       "Bad conversion")
    }

    func testConvertSmartSqlWithJoin() {
        XCTAssertEqual("select TABLE_2_1, TABLE_1_0 || ' ' || TABLE_1_1 from TABLE_1, TABLE_2 where TABLE_2_0 = TABLE_1_2 order by TABLE_2_1, TABLE_1_1",
                       store.convertSmartSql("select {departments:name}, {employees:firstName} || ' ' || {employees:lastName} from {employees}, {departments} where {departments:deptCode} = {employees:deptCode} order by {departments:name}, {employees:lastName}"),
                       "Bad conversion")
    }

    func testConvertSmartSqlWithSelfJoin() {
        XCTAssertEqual("select mgr.TABLE_1_1, e.TABLE_1_1 from TABLE_1 as mgr, TABLE_1 as e where mgr.TABLE_1_3 = e.TABLE_1_4",
                       store.convertSmartSql("select mgr.{employees:lastName}, e.{employees:lastName} from {employees} as mgr, {employees} as e where mgr.{employees:employeeId} = e.{employees:managerId}"),
                       "Bad conversion")
    }

    func testConvertSmartSqlWithSelfJoinAndJsonExtractedField() {
        XCTAssertEqual("select json_extract(mgr.soup, '$.education'), json_extract(e.soup, '$.education') from TABLE_1 as mgr, TABLE_1 as e where json_extract(mgr.soup, '$.education') = json_extract(e.soup, '$.education')",
                       store.convertSmartSql("select mgr.{employees:education}, e.{employees:education} from {employees} as mgr, {employees} as e where mgr.{employees:education} = e.{employees:education}"),
                       "Bad conversion")
    }

    func testConvertSmartSqlWithSelfJoinAndJsonExtractedFieldNoLeadingSpaces() {
        XCTAssertEqual("select json_extract(mgr.soup, '$.education'),json_extract(e.soup, '$.education') from TABLE_1 as mgr, TABLE_1 as e where not (json_extract(mgr.soup, '$.education')=json_extract(e.soup, '$.education'))",
                       store.convertSmartSql("select mgr.{employees:education},e.{employees:education} from {employees} as mgr, {employees} as e where not (mgr.{employees:education}=e.{employees:education})"),
                       "Bad conversion")
    }

    func testConvertSmartSqlWithSpecialColumns() {
        XCTAssertEqual("select TABLE_1.id, TABLE_1.created, TABLE_1.lastModified, TABLE_1.soup from TABLE_1",
                       store.convertSmartSql("select {employees:_soupEntryId}, {employees:_soupCreatedDate}, {employees:_soupLastModifiedDate}, {employees:_soup} from {employees}"),
                       "Bad conversion")
    }

    func testConvertSmartSqlWithSpecialColumnsAndJoin() {
        XCTAssertEqual("select TABLE_1.id, TABLE_2.id from TABLE_1, TABLE_2",
                       store.convertSmartSql("select {employees:_soupEntryId}, {departments:_soupEntryId} from {employees}, {departments}"),
                       "Bad conversion")
    }

    func testConvertSmartSqlWithSpecialColumnsAndSelfJoin() {
        XCTAssertEqual("select mgr.id, e.id from TABLE_1 as mgr, TABLE_1 as e",
                       store.convertSmartSql("select mgr.{employees:_soupEntryId}, e.{employees:_soupEntryId} from {employees} as mgr, {employees} as e"),
                       "Bad conversion")
    }

    func testConvertSmartSqlWithJSON1() {
        XCTAssertEqual("select TABLE_1_1, json_extract(soup, '$.education') from TABLE_1 where json_extract(soup, '$.education') = 'MIT'",
                       store.convertSmartSql("select {employees:lastName}, {employees:education} from {employees} where {employees:education} = 'MIT'"),
                       "Bad conversion")
    }

    func testConvertSmartSqlWithJSON1AndTableQualifiedColumn() {
        XCTAssertEqual("select json_extract(TABLE_1.soup, '$.education') from TABLE_1 order by json_extract(TABLE_1.soup, '$.education')",
                       store.convertSmartSql("select {employees}.{employees:education} from {employees} order by {employees}.{employees:education}"),
                       "Bad conversion")
    }

    func testConvertSmartSqlWithJSON1AndTableAliases() {
        XCTAssertEqual("select json_extract(e.soup, '$.education'), json_extract(soup, '$.building') from TABLE_1 as e, TABLE_2",
                       store.convertSmartSql("select e.{employees:education}, {departments:building} from {employees} as e, {departments}"),
                       "Bad conversion")
    }

    func testConvertSmartSqlForNonIndexedColumns() {
        XCTAssertEqual("select json_extract(soup, '$.education'), json_extract(soup, '$.address.zipcode') from TABLE_1 where json_extract(soup, '$.address.city') = 'San Francisco'",
                       store.convertSmartSql("select {employees:education}, {employees:address.zipcode} from {employees} where {employees:address.city} = 'San Francisco'"),
                       "Bad conversion")
    }

    func testConvertSmartSqlWithQuotedCurlyBraces() {
        XCTAssertEqual("select json_extract(soup, '$.education') from TABLE_1 where json_extract(soup, '$.education') like 'Account(where: {Name: {eq: \"Jason\"}})'",
                       store.convertSmartSql("select {employees:education} from {employees} where {employees:education} like 'Account(where: {Name: {eq: \"Jason\"}})'"))
    }

    func testConvertSmartSqlWithMultipleQuotedCurlyBraces() {
        XCTAssertEqual("select json_extract(soup, '$.education'), '{a:b}', TABLE_1_0 from TABLE_1 where json_extract(soup, '$.address') = '{\"city\": \"San Francisco\"}' or TABLE_1_1 like 'B%'",
                       store.convertSmartSql("select {employees:education}, '{a:b}', {employees:firstName} from {employees} where {employees:address} = '{\"city\": \"San Francisco\"}' or {employees:lastName} like 'B%'"))
    }

    func testConvertSmartSqlWithQuotedUnbalancedCurlyBrace() {
        XCTAssertEqual("select json_extract(soup, '$.education') from TABLE_1 where json_extract(soup, '$.education') like ' { { { } } '",
                       store.convertSmartSql("select {employees:education} from {employees} where {employees:education} like ' { { { } } '"))
    }

    func testConvertOtherComplexSmartSql() {
        XCTAssertEqual("SELECT json_set('{}', '$.data.uiapi.query.Account.edges', ( SELECT json_group_array(json_set('{}', '$.node.Id', (json_extract('Account.JSON', '$.data.fields.Id.value')) )) FROM (SELECT 'Account'.TABLE_1_1 as 'Account.JSON' FROM TABLE_1 as 'Account' WHERE ( json_extract('Account.JSON', '$.data.apiName') = 'Account' ) ) ) ) as json",
                       store.convertSmartSql("SELECT json_set('{}', '$.data.uiapi.query.Account.edges', ( SELECT json_group_array(json_set('{}', '$.node.Id', (json_extract('Account.JSON', '$.data.fields.Id.value')) )) FROM (SELECT 'Account'.TABLE_1_1 as 'Account.JSON' FROM TABLE_1 as 'Account' WHERE ( json_extract('Account.JSON', '$.data.apiName') = 'Account' ) ) ) ) as json"))
    }

    func testSmartQueryDoingCount() {
        loadData()
        let querySpec = QuerySpec.buildSmartQuerySpec(smartSql: "select count(*) from {employees}", pageSize: 1)!
        let result = try! store.query(using: querySpec, startingFromPageIndex: 0)
        assertSameJSONArray(expected: SFJsonUtils.object(from: "[[7]]") as! [Any], actual: result, message: "Wrong result")
    }

    func testSmartQueryDoingSum() {
        loadData()
        let querySpec = QuerySpec.buildSmartQuerySpec(smartSql: "select sum({departments:budget}) from {departments}", pageSize: 1)!
        let result = try! store.query(using: querySpec, startingFromPageIndex: 0)
        assertSameJSONArray(expected: SFJsonUtils.object(from: "[[3000000]]") as! [Any], actual: result, message: "Wrong result")
    }

    func testSmartQueryReturningOneRowWithOneInteger() {
        loadData()
        let querySpec = QuerySpec.buildSmartQuerySpec(smartSql: "select {employees:salary} from {employees} where {employees:lastName} = 'Haas'", pageSize: 1)!
        let result = try! store.query(using: querySpec, startingFromPageIndex: 0)
        assertSameJSONArray(expected: SFJsonUtils.object(from: "[[200000.10]]") as! [Any], actual: result, message: "Wrong result")
    }

    func testSmartQueryReturningOneRowWithTwoIntegers() {
        loadData()
        let querySpec = QuerySpec.buildSmartQuerySpec(smartSql: "select mgr.{employees:salary}, e.{employees:salary} from {employees} as mgr, {employees} as e where mgr.{employees:employeeId} = e.{employees:managerId} and e.{employees:lastName} = 'Thompson'", pageSize: 1)!
        let result = try! store.query(using: querySpec, startingFromPageIndex: 0)
        assertSameJSONArray(expected: SFJsonUtils.object(from: "[[200000.10,120000.10]]") as! [Any], actual: result, message: "Wrong result")
    }

    func testSmartQueryReturningTwoRowsWithOneIntegerEach() {
        loadData()
        let querySpec = QuerySpec.buildSmartQuerySpec(smartSql: "select {employees:salary} from {employees} where {employees:managerId} = '00010' order by {employees:firstName}", pageSize: 2)!
        let result = try! store.query(using: querySpec, startingFromPageIndex: 0)
        assertSameJSONArray(expected: SFJsonUtils.object(from: "[[120000.10],[100000.10]]") as! [Any], actual: result, message: "Wrong result")
    }

    func testSmartQueryReturningSoupStringAndInteger() {
        loadData()
        let exactQuerySpec = QuerySpec.buildExactQuerySpec(soupName: kEmployeesSoup, path: "employeeId", matchKey: "00010", orderPath: "employeeId", order: .ascending, pageSize: 1)
        let christineJson = (try! store.query(using: exactQuerySpec, startingFromPageIndex: 0))[0] as! [String: Any]
        XCTAssertEqual("Christine", christineJson[kFirstName] as? String, "Wrong elt")

        let querySpec = QuerySpec.buildSmartQuerySpec(smartSql: "select {employees:_soup}, {employees:firstName}, {employees:salary} from {employees} where {employees:lastName} = 'Haas'", pageSize: 1)!
        let result = try! store.query(using: querySpec, startingFromPageIndex: 0) as! [[Any]]
        XCTAssertTrue(1 == result.count, "Expected one row")
        assertSameJSON(expected: christineJson as NSDictionary, actual: result[0][0] as? NSDictionary, message: "Wrong soup")
        XCTAssertEqual("Christine", result[0][1] as? String, "Wrong first name")
        let dubNum = result[0][2] as! NSNumber
        XCTAssertEqual(200000.10, dubNum.doubleValue, "Wrong salary")
    }

    func testSmartQueryWithPaging() {
        loadData()
        let querySpec = QuerySpec.buildSmartQuerySpec(smartSql: "select {employees:firstName} from {employees} order by {employees:firstName}", pageSize: 1)!
        XCTAssertTrue(7 == (try! store.count(using: querySpec)).uintValue, "Expected 7 employees")
        let expectedResults = ["Christine", "Eileen", "Eva", "Irving", "John", "Michael", "Sally"]
        for i in 0..<7 {
            let result = try! store.query(using: querySpec, startingFromPageIndex: UInt(i))
            let expectedResult: [Any] = [[expectedResults[i]]]
            assertSameJSONArray(expected: expectedResult, actual: result, message: "Wrong result at page \(i)")
        }
    }

    func testSmartQueryWithSpecialFields() {
        loadData()
        let exactQuerySpec = QuerySpec.buildExactQuerySpec(soupName: kEmployeesSoup, path: "employeeId", matchKey: "00010", orderPath: "employeeId", order: .ascending, pageSize: 1)
        let christineJson = (try! store.query(using: exactQuerySpec, startingFromPageIndex: 0))[0] as! [String: Any]
        XCTAssertEqual("Christine", christineJson[kFirstName] as? String, "Wrong elt")

        let querySpec = QuerySpec.buildSmartQuerySpec(smartSql: "select {employees:_soup}, {employees:_soupEntryId}, {employees:_soupLastModifiedDate} from {employees} where {employees:lastName} = 'Haas'", pageSize: 1)!
        let result = try! store.query(using: querySpec, startingFromPageIndex: 0) as! [[Any]]
        XCTAssertTrue(1 == result.count, "Expected one row")
        assertSameJSON(expected: christineJson as NSDictionary, actual: result[0][0] as? NSDictionary, message: "Wrong soup")
        XCTAssertEqual(christineJson["_soupEntryId"] as? NSNumber, result[0][1] as? NSNumber, "Wrong soupEntryId")
        XCTAssertEqual(christineJson["_soupLastModifiedDate"] as? NSNumber, result[0][2] as? NSNumber, "Wrong soupLastModifiedDate")
    }

    func testSmartQueryWithNullField() {
        var createdEmployee: [String: Any]

        createdEmployee = createEmployeeWithJsonString("{\"employeeId\":\"001\",\"deptCode\":\"xyz\"}")
        XCTAssertEqual(createdEmployee["deptCode"] as? String, "xyz")

        createdEmployee = createEmployeeWithJsonString("{\"employeeId\":\"002\",\"deptCode\":null}")
        XCTAssertTrue(createdEmployee["deptCode"] is NSNull)

        createdEmployee = createEmployeeWithJsonString("{\"employeeId\":\"003\",\"deptCode\":\"\"}")
        XCTAssertEqual(createdEmployee["deptCode"] as? String, "")

        createdEmployee = createEmployeeWithJsonString("{\"employeeId\":\"004\"}")
        XCTAssertNil(createdEmployee["deptCode"])

        // Smart sql with is not null
        var querySpec = QuerySpec.buildSmartQuerySpec(smartSql: "select {employees:employeeId} from {employees} where {employees:deptCode} is not null order by {employees:employeeId}", pageSize: 4)!
        var result = try! store.query(using: querySpec, startingFromPageIndex: 0)
        assertSameJSONArray(expected: SFJsonUtils.object(from: "[[\"001\"],[\"003\"]]") as! [Any], actual: result, message: "Wrong result")

        // Smart sql with is null
        querySpec = QuerySpec.buildSmartQuerySpec(smartSql: "select {employees:employeeId} from {employees} where {employees:deptCode} is null order by {employees:employeeId}", pageSize: 4)!
        result = try! store.query(using: querySpec, startingFromPageIndex: 0)
        assertSameJSONArray(expected: SFJsonUtils.object(from: "[[\"002\"],[\"004\"]]") as! [Any], actual: result, message: "Wrong result")

        // Smart sql looking for empty string
        querySpec = QuerySpec.buildSmartQuerySpec(smartSql: "select {employees:employeeId} from {employees} where {employees:deptCode} = \"\" order by {employees:employeeId}", pageSize: 4)!
        result = try! store.query(using: querySpec, startingFromPageIndex: 0)
        assertSameJSONArray(expected: SFJsonUtils.object(from: "[[\"003\"]]") as! [Any], actual: result, message: "Wrong result")

        // Smart sql returning null values
        querySpec = QuerySpec.buildSmartQuerySpec(smartSql: "select {employees:employeeId},{employees:deptCode},{employees:deptCode} from {employees} order by {employees:employeeId}", pageSize: 4)!
        result = try! store.query(using: querySpec, startingFromPageIndex: 0)
        assertSameJSONArray(expected: SFJsonUtils.object(from: "[[\"001\",\"xyz\",\"xyz\"],[\"002\",null,null],[\"003\",\"\",\"\"],[\"004\",null,null]]") as! [Any], actual: result, message: "Wrong result")
    }

    func testSmartQueryMachingBooleanInJSON1Field() {
        loadData()

        _ = createEmployeeWithJsonString("{\"employeeId\":\"101\",\"isManager\":true}")
        _ = createEmployeeWithJsonString("{\"employeeId\":\"102\",\"isManager\":false}")

        var querySpec = QuerySpec.buildSmartQuerySpec(smartSql: "select {employees:employeeId} from {employees} where {employees:isManager} = 1 order by {employees:employeeId}", pageSize: 10)!
        var result = try! store.query(using: querySpec, startingFromPageIndex: 0)
        assertSameJSONArray(expected: SFJsonUtils.object(from: "[[\"00010\"],[\"00040\"],[\"00050\"],[\"101\"]]") as! [Any], actual: result, message: "Wrong result")

        querySpec = QuerySpec.buildSmartQuerySpec(smartSql: "select {employees:employeeId} from {employees} where {employees:isManager} = 0 order by {employees:employeeId}", pageSize: 10)!
        result = try! store.query(using: querySpec, startingFromPageIndex: 0)
        assertSameJSONArray(expected: SFJsonUtils.object(from: "[[\"00020\"],[\"00060\"],[\"00070\"],[\"00310\"],[\"102\"]]") as! [Any], actual: result, message: "Wrong result")
    }

    func testSmartQueryMachingNonAsciiInStringField() {
        _ = createEmployeeWithJsonString("{\"employeeId\":\"101\",\"firstName\":\"G\u{00F6}ktu\u{011F}\"}")
        _ = createEmployeeWithJsonString("{\"employeeId\":\"102\",\"firstName\":\"\u{BCF4}\u{BC30}\"}")

        var querySpec = QuerySpec.buildSmartQuerySpec(smartSql: "select {employees:employeeId} from {employees} where {employees:firstName} like '%\u{011F}%'", pageSize: 10)!
        var result = try! store.query(using: querySpec, startingFromPageIndex: 0)
        assertSameJSONArray(expected: SFJsonUtils.object(from: "[[\"101\"]]") as! [Any], actual: result, message: "Wrong result")

        querySpec = QuerySpec.buildSmartQuerySpec(smartSql: "select {employees:employeeId} from {employees} where {employees:firstName} like '%\u{BC30}%'", pageSize: 10)!
        result = try! store.query(using: querySpec, startingFromPageIndex: 0)
        assertSameJSONArray(expected: SFJsonUtils.object(from: "[[\"102\"]]") as! [Any], actual: result, message: "Wrong result")
    }

    func testSmartQueryMachingNonAsciiInJSON1Field() {
        _ = createEmployeeWithJsonString("{\"employeeId\":\"101\",\"education\":\"latince uzman\u{0131}\"}")
        _ = createEmployeeWithJsonString("{\"employeeId\":\"102\",\"education\":\"\u{B77C}\u{D2F4}\u{C5B4} \u{C804}\u{BB38}\u{AC00}\"}")

        var querySpec = QuerySpec.buildSmartQuerySpec(smartSql: "select {employees:employeeId} from {employees} where {employees:education} like '%\u{0131}%'", pageSize: 10)!
        var result = try! store.query(using: querySpec, startingFromPageIndex: 0)
        assertSameJSONArray(expected: SFJsonUtils.object(from: "[[\"101\"]]") as! [Any], actual: result, message: "Wrong result")

        querySpec = QuerySpec.buildSmartQuerySpec(smartSql: "select {employees:employeeId} from {employees} where {employees:education} like '%\u{BB38}%'", pageSize: 10)!
        result = try! store.query(using: querySpec, startingFromPageIndex: 0)
        assertSameJSONArray(expected: SFJsonUtils.object(from: "[[\"102\"]]") as! [Any], actual: result, message: "Wrong result")
    }

    func testSmartQueryMachingNonAsciiInNonIndexedField() {
        _ = createEmployeeWithJsonString("{\"employeeId\":\"101\",\"country\":\"T\u{00FC}rk\u{00E7}e\"}")
        _ = createEmployeeWithJsonString("{\"employeeId\":\"102\",\"country\":\"\u{D55C}\u{AD6D}\"}")

        var querySpec = QuerySpec.buildSmartQuerySpec(smartSql: "select {employees:employeeId} from {employees} where {employees:country} like '%\u{00E7}%'", pageSize: 10)!
        var result = try! store.query(using: querySpec, startingFromPageIndex: 0)
        assertSameJSONArray(expected: SFJsonUtils.object(from: "[[\"101\"]]") as! [Any], actual: result, message: "Wrong result")

        querySpec = QuerySpec.buildSmartQuerySpec(smartSql: "select {employees:employeeId} from {employees} where {employees:country} like '%\u{AD6D}%'", pageSize: 10)!
        result = try! store.query(using: querySpec, startingFromPageIndex: 0)
        assertSameJSONArray(expected: SFJsonUtils.object(from: "[[\"102\"]]") as! [Any], actual: result, message: "Wrong result")
    }

    func testSmartQueryFilteringByNonIndexedField() {
        _ = createEmployeeWithJsonString("{\"employeeId\":\"101\",\"address\":{\"city\":\"San Francisco\", \"zipcode\":94105}}")
        _ = createEmployeeWithJsonString("{\"employeeId\":\"102\",\"address\":{\"city\":\"New York City\", \"zipcode\":10004}}")
        _ = createEmployeeWithJsonString("{\"employeeId\":\"103\",\"address\":{\"city\":\"San Francisco\", \"zipcode\":94106}}")
        _ = createEmployeeWithJsonString("{\"employeeId\":\"104\",\"address\":{\"city\":\"New York City\", \"zipcode\":10006}}")

        let querySpec = QuerySpec.buildSmartQuerySpec(smartSql: "select {employees:employeeId} from {employees} where {employees:address.city} = 'San Francisco' order by {employees:employeeId}", pageSize: 10)!
        let result = try! store.query(using: querySpec, startingFromPageIndex: 0)
        assertSameJSONArray(expected: SFJsonUtils.object(from: "[[\"101\"],[\"103\"]]") as! [Any], actual: result, message: "Wrong result")
    }

    func testSmartQueryReturningNonIndexedField() {
        _ = createEmployeeWithJsonString("{\"employeeId\":\"101\",\"address\":{\"city\":\"San Francisco\", \"zipcode\":94105}}")
        _ = createEmployeeWithJsonString("{\"employeeId\":\"102\",\"address\":{\"city\":\"New York City\", \"zipcode\":10004}}")
        _ = createEmployeeWithJsonString("{\"employeeId\":\"103\",\"address\":{\"city\":\"San Francisco\", \"zipcode\":94106}}")
        _ = createEmployeeWithJsonString("{\"employeeId\":\"104\",\"address\":{\"city\":\"New York City\", \"zipcode\":10006}}")

        let querySpec = QuerySpec.buildSmartQuerySpec(smartSql: "select {employees:employeeId}, {employees:address.zipcode} from {employees} where {employees:address.city} = 'San Francisco' order by {employees:employeeId}", pageSize: 10)!
        let result = try! store.query(using: querySpec, startingFromPageIndex: 0)
        assertSameJSONArray(expected: SFJsonUtils.object(from: "[[\"101\", 94105],[\"103\", 94106]]") as! [Any], actual: result, message: "Wrong result")
    }

    func testSmartQueryUsingWhereArgs() {
        _ = createEmployeeWithJsonString("{\"employeeId\":\"101\",\"address\":{\"city\":\"San Francisco\", \"zipcode\":94105}}")
        _ = createEmployeeWithJsonString("{\"employeeId\":\"102\",\"address\":{\"city\":\"New York City\", \"zipcode\":10004}}")
        _ = createEmployeeWithJsonString("{\"employeeId\":\"103\",\"address\":{\"city\":\"San Francisco\", \"zipcode\":94106}}")
        _ = createEmployeeWithJsonString("{\"employeeId\":\"104\",\"address\":{\"city\":\"New York City\", \"zipcode\":10006}}")

        let querySpec = QuerySpec.buildSmartQuerySpec(smartSql: "select {employees:employeeId}, {employees:address.zipcode} from {employees} where {employees:address.city} = ? order by {employees:employeeId}", pageSize: 10)!

        var result = try! store.query(using: querySpec, startingFromPageIndex: 0, whereArgs: ["San Francisco"])
        assertSameJSONArray(expected: SFJsonUtils.object(from: "[[\"101\", 94105],[\"103\", 94106]]") as! [Any], actual: result, message: "Wrong result")

        result = try! store.query(using: querySpec, startingFromPageIndex: 0, whereArgs: ["New York City"])
        assertSameJSONArray(expected: SFJsonUtils.object(from: "[[\"102\", 10004],[\"104\", 10006]]") as! [Any], actual: result, message: "Wrong result")
    }

    func testNonSmartQueryUsingWhereArgs() {
        let querySpec = QuerySpec.buildAllQuerySpec(soupName: kEmployeesSoup, orderPath: kEmployeeId, order: .ascending, pageSize: 10)
        do {
            _ = try store.query(using: querySpec, startingFromPageIndex: 0, whereArgs: ["San Francisco"])
            XCTFail("Should have thrown")
        } catch {
            let nsError = error as NSError
            XCTAssertEqual(nsError.userInfo[NSLocalizedDescriptionKey] as? String, "whereArgs can only be provided for smart queries")
        }
    }

    func testCleanupRegexpFaster() {
        let oldRegexp = "([^ ]+)\\.json_extract\\(soup"
        let newRegexp = "(\\w+)\\.json_extract\\(soup"

        let newTime = timeRegexp(newRegexp)
        let oldTime = timeRegexp(oldRegexp)
        // New regexp should be faster than old regexp
        XCTAssertTrue(newTime <= oldTime || newTime < 1, "New regexp should not be slower: new=\(newTime)ms old=\(oldTime)ms")
        // No more than 25ms
        XCTAssertTrue(newTime < 25, "New regexp took \(newTime)ms, expected < 25ms")
    }

    // MARK: - Helper methods

    private func timeRegexp(_ pattern: String) -> Double {
        let q = "SELECT {DEFAULT:LdsSoupKey}, {DEFAULT:LdsSoupValue}\nFROM {DEFAULT}\nWHERE {DEFAULT:LdsSoupKey}\nIN (\'UiApi::BatchRepresentation(childRelationships:undefined,fields:undefined,layoutTypes:undefined,modes:undefined,optionalFields:Account.AccountSource,Account.AnnualRevenue,Account.BillingAddress\')"
        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        let sql = NSMutableString(string: q)
        let startTime = CACurrentMediaTime()
        regex.replaceMatches(in: sql, options: [], range: NSRange(location: 0, length: sql.length), withTemplate: "json_extract($1.soup")
        let elapsedTime = CACurrentMediaTime() - startTime
        return elapsedTime * 1000.0
    }

    private func loadData() {
        createEmployee(firstName: "Christine", lastName: "Haas", deptCode: "A00", employeeId: "00010", managerId: "", salary: 200000.10, isManager: true)
        createEmployee(firstName: "Michael", lastName: "Thompson", deptCode: "A00", employeeId: "00020", managerId: "00010", salary: 120000.10, isManager: false)
        createEmployee(firstName: "Sally", lastName: "Kwan", deptCode: "A00", employeeId: "00310", managerId: "00010", salary: 100000.10, isManager: false)
        createEmployee(firstName: "John", lastName: "Geyer", deptCode: "B00", employeeId: "00040", managerId: "", salary: 102000.10, isManager: true)
        createEmployee(firstName: "Irving", lastName: "Stern", deptCode: "B00", employeeId: "00050", managerId: "00040", salary: 100000.10, isManager: true)
        createEmployee(firstName: "Eva", lastName: "Pulaski", deptCode: "B00", employeeId: "00060", managerId: "00050", salary: 80000.10, isManager: false)
        createEmployee(firstName: "Eileen", lastName: "Henderson", deptCode: "B00", employeeId: "00070", managerId: "00050", salary: 70000.10, isManager: false)

        createDepartment(code: "A00", name: "Sales", budget: 1000000)
        createDepartment(code: "B00", name: "R&D", budget: 2000000)
    }

    private func createEmployee(firstName: String, lastName: String, deptCode: String, employeeId: String, managerId: String, salary: Double, isManager: Bool) {
        let employee: NSDictionary = [kFirstName: firstName, kLastName: lastName, kDeptCode: deptCode, kEmployeeId: employeeId, kManagerId: managerId, kSalary: NSNumber(value: salary), kIsManager: NSNumber(value: isManager)]
        store.upsert(entries: [employee], forSoupNamed: kEmployeesSoup)
    }

    @discardableResult
    private func createEmployeeWithJsonString(_ jsonString: String) -> [String: Any] {
        let employee = SFJsonUtils.object(from: jsonString) as! NSDictionary
        return store.upsert(entries: [employee], forSoupNamed: kEmployeesSoup)[0] as! [String: Any]
    }

    private func createDepartment(code: String, name: String, budget: Int) {
        let department: NSDictionary = [kDeptCode: code, kName: name, kBudget: NSNumber(value: budget)]
        store.upsert(entries: [department], forSoupNamed: kDepartmentsSoup)
    }
}
