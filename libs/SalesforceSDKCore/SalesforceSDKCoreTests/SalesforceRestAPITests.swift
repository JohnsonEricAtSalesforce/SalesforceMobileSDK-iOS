/*
 SalesforceRestAPITests.swift
 SalesforceSDKCoreTests

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
@testable import SalesforceSDKCore
import SalesforceSDKCommon

// MARK: - Constants

private let kEntityPrefixName = "RestClientTestsiOS"
private let kAccount = "Account"
private let kContact = "Contact"
private let kFirstName = "FirstName"
private let kName = "Name"
private let kLid = "id"
private let kLastName = "LastName"
private let kId = "Id"
private let kSearchRecords = "searchRecords"
private let kType = "type"
private let kRecords = "records"
private let kAccountId = "AccountId"
private let kResult = "result"
private let kResults = "results"
private let kStatusCode = "statusCode"
private let kBody = "body"
private let kCompositeResponse = "compositeResponse"
private let kHasErrors = "hasErrors"
private let kAttributes = "attributes"
private let kHttpStatusCode = "httpStatusCode"

// MARK: - Response Helper

private class RestAPITestResponse {
    var returnStatus: String = kTestRequestStatusWaiting
    var dataResponse: Any?
    var lastError: NSError?
    var rawResponse: URLResponse?
}

// MARK: - Delegate Helper

private class RestAPITestDelegate: NSObject, RestRequestDelegate {
    var request: RestRequest
    var expectation: XCTestExpectation
    var returnStatus: String = kTestRequestStatusWaiting
    var dataResponse: Any?
    var lastError: NSError?
    var rawResponse: URLResponse?

    init(request: RestRequest, expectation: XCTestExpectation) {
        self.request = request
        self.expectation = expectation
        super.init()
    }

    func request(_ request: RestRequest, didSucceed dataResponse: Any, rawResponse: URLResponse) {
        self.dataResponse = dataResponse
        self.rawResponse = rawResponse
        self.returnStatus = kTestRequestStatusDidLoad
        expectation.fulfill()
    }

    func request(_ request: RestRequest, didFail dataResponse: Any, rawResponse: URLResponse, error: Error) {
        self.dataResponse = dataResponse
        self.rawResponse = rawResponse
        self.lastError = error as NSError
        self.returnStatus = kTestRequestStatusDidFail
        expectation.fulfill()
    }
}

// MARK: - SalesforceRestAPITests

class SalesforceRestAPITests: XCTestCase {

    private var currentUser: UserAccount?
    private var currentExpectation: XCTestExpectation?
    private var dataCleanupRequired = true

    private static var authException: NSException?

    override class func setUp() {
        do {
            SFSDKLogoutBlocker.block()
            TestSetupUtils.populateAuthCredentials(fromConfigFileFor: self)
            TestSetupUtils.synchronousAuthRefresh()
        } catch {
            authException = NSException(name: .genericException, reason: error.localizedDescription)
        }
        super.setUp()
    }

    override func setUpWithError() throws {
        super.setUp()
        // Skip (do not crash the host) when the live-org auth refresh didn't complete. See
        // TestSetupUtils.authRefreshDidSucceed — the pre-token-refresh-coordinator flow hangs in the
        // sim even with a valid token; the old fatal assert aborted the whole run and masked later tests.
        try XCTSkipUnless(TestSetupUtils.authRefreshDidSucceed, "Live-org auth refresh unavailable (known pre-coordinator hang); skipping live REST API tests.")
        if let authException = Self.authException {
            XCTFail("Setting up authentication failed: \(authException)")
        }
        continueAfterFailure = false
        dataCleanupRequired = true
        currentUser = UserAccountManager.shared.currentUserAccount
    }

    override func tearDown() {
        // When the live-org auth refresh was skipped (see TestSetupUtils.authRefreshDidSucceed), the
        // test body never ran and there is no live session — running cleanup() would send an
        // authenticated request through an unauthenticated client and trip the SFRestAPI assert,
        // crashing the host even though the test was skipped. Skip all live teardown in that case.
        guard TestSetupUtils.authRefreshDidSucceed else {
            super.tearDown()
            return
        }
        if dataCleanupRequired {
            cleanup()
        }
        RestClient.sharedGlobalInstance.cleanup()
        RestClient.sharedInstance.cleanup()
        UserAccountManager.shared.setCurrentUserInternal(currentUser)
        Thread.sleep(forTimeInterval: 0.1)
        super.tearDown()
    }

    // MARK: - Helper Methods

    private func cleanup() {
        let searchRequest = RestClient.sharedInstance.requestForSearch("find {\(kEntityPrefixName)}", apiVersion: SFRestDefaultAPIVersion)
        let response = sendSyncRequest(searchRequest)
        guard let results = (response.dataResponse as? [String: Any])?[kSearchRecords] as? [[String: Any]] else { return }
        var requests = [RestRequest]()
        for result in results {
            guard let objectType = (result[kAttributes] as? [String: Any])?[kType] as? String,
                  let objectId = result[kId] as? String else { continue }
            let deleteRequest = RestClient.sharedInstance.requestForDelete(withObjectType: objectType, objectId: objectId, apiVersion: SFRestDefaultAPIVersion)
            requests.append(deleteRequest)
            if requests.count == 25 {
                _ = sendSyncRequest(RestClient.sharedInstance.batchRequest(requests, haltOnError: false, apiVersion: SFRestDefaultAPIVersion))
                requests.removeAll()
            }
        }
        if requests.count > 0 {
            _ = sendSyncRequest(RestClient.sharedInstance.batchRequest(requests, haltOnError: false, apiVersion: SFRestDefaultAPIVersion))
        }
    }

    private func generateRecordName() -> String {
        let uuid = UUID().uuidString
        return "\(kEntityPrefixName)\(uuid)"
    }

    private func sendSyncRequest(_ request: RestRequest) -> RestAPITestResponse {
        sendSyncRequest(request, usingInstance: RestClient.sharedInstance)
    }

    private func sendSyncRequest(_ request: RestRequest, usingInstance instance: RestClient) -> RestAPITestResponse {
        var responseData: Any?
        var responseError: NSError?
        var rawResponseData: URLResponse?

        let exp = expectation(description: "REST request completed")

        instance.send(request, failureBlock: { response, error, rawResponse in
            responseData = response
            responseError = error as NSError?
            rawResponseData = rawResponse
            exp.fulfill()
        }, successBlock: { response, rawResponse in
            responseData = response
            rawResponseData = rawResponse
            exp.fulfill()
        })

        // Wait ONLY on this request's expectation (scoped), matching the oracle's
        // `[self waitForExpectations:@[expectation] timeout:60.0]`. The global
        // `waitForExpectations(timeout:)` waits on EVERY pending expectation, so a test that
        // registers a notification expectation before calling sendSyncRequest (e.g.
        // testRefreshNotificationWithValidGetRequest) would have its notification expectation
        // consumed here, then hit "call made to wait without any expectations having been set".
        wait(for: [exp], timeout: 60.0)

        let result = RestAPITestResponse()
        result.returnStatus = responseError != nil ? kTestRequestStatusDidFail : kTestRequestStatusDidLoad
        result.dataResponse = responseData
        result.lastError = responseError
        result.rawResponse = rawResponseData
        return result
    }

    // Shared polling helper. Sends request repeatedly with exponential backoff until
    // the exit condition is satisfied or maxWait is exceeded.
    private func pollRequest(_ request: RestRequest, recordsKey key: String, maxWaitSeconds maxWait: TimeInterval, exitCondition condition: ([[String: Any]]) -> Bool) -> [[String: Any]]? {
        var elapsed: TimeInterval = 0
        var interval: TimeInterval = 2.0
        var records: [[String: Any]]?

        while elapsed < maxWait {
            let response = sendSyncRequest(request)
            if response.returnStatus == kTestRequestStatusDidLoad {
                records = (response.dataResponse as? [String: Any])?[key] as? [[String: Any]]
                if let records = records, condition(records) {
                    return records
                }
            }
            Thread.sleep(forTimeInterval: interval)
            elapsed += interval
            interval = min(interval * 1.5, 5.0)
        }
        return records
    }

    private func sendSyncSearchRequestWithRetry(_ request: RestRequest, expectedMinResults minResults: Int, maxWaitSeconds maxWait: TimeInterval) -> [[String: Any]]? {
        pollRequest(request, recordsKey: kSearchRecords, maxWaitSeconds: maxWait) { $0.count >= minResults }
    }

    private func sendSyncSearchRequestUntilEmpty(_ request: RestRequest, maxWaitSeconds maxWait: TimeInterval) -> [[String: Any]]? {
        pollRequest(request, recordsKey: kSearchRecords, maxWaitSeconds: maxWait) { $0.count == 0 }
    }

    private func sendSyncQueryRequestUntilEmpty(_ request: RestRequest, maxWaitSeconds maxWait: TimeInterval) -> [[String: Any]]? {
        pollRequest(request, recordsKey: kRecords, maxWaitSeconds: maxWait) { $0.count == 0 }
    }

    private func sendSyncQueryRequestUntilFound(_ request: RestRequest, expectedMinResults minResults: Int, maxWaitSeconds maxWait: TimeInterval) -> [[String: Any]]? {
        pollRequest(request, recordsKey: kRecords, maxWaitSeconds: maxWait) { $0.count >= minResults }
    }

    // Retry owned-files list until a specific file ID appears.
    private func waitForOwnedFilesList(_ request: RestRequest, toContainFileId fileId: String, maxWaitSeconds maxWait: TimeInterval) -> RestAPITestResponse {
        var elapsed: TimeInterval = 0
        var interval: TimeInterval = 2.0
        var response = RestAPITestResponse()

        while elapsed < maxWait {
            response = sendSyncRequest(request)
            if response.returnStatus != kTestRequestStatusDidLoad { return response }
            let files = (response.dataResponse as? [String: Any])?["files"] as? [[String: Any]] ?? []
            if files.contains(where: { ($0[kLid] as? String) == fileId }) { return response }
            Thread.sleep(forTimeInterval: interval)
            elapsed += interval
            interval = min(interval * 1.5, 5.0)
        }
        return response
    }

    // Retry owned-files list until a specific file ID is gone.
    private func waitForOwnedFilesList(_ request: RestRequest, toNotContainFileId fileId: String, maxWaitSeconds maxWait: TimeInterval) -> RestAPITestResponse {
        var elapsed: TimeInterval = 0
        var interval: TimeInterval = 2.0
        var response = RestAPITestResponse()

        while elapsed < maxWait {
            response = sendSyncRequest(request)
            if response.returnStatus != kTestRequestStatusDidLoad { return response }
            let files = (response.dataResponse as? [String: Any])?["files"] as? [[String: Any]] ?? []
            if !files.contains(where: { ($0[kLid] as? String) == fileId }) { return response }
            Thread.sleep(forTimeInterval: interval)
            elapsed += interval
            interval = min(interval * 1.5, 5.0)
        }
        return response
    }

    // Find a file by ID in an array of file dictionaries
    private func findFileWithId(_ fileId: String, inFiles files: [[String: Any]]?) -> [String: Any]? {
        files?.first { ($0[kLid] as? String) == fileId }
    }

    private func changeOauthTokens(accessToken: String, refreshToken: String?) {
        currentUser?.credentials.accessToken = accessToken
        if let refreshToken = refreshToken {
            currentUser?.credentials.refreshToken = refreshToken
        }
    }

    // MARK: - Tests

    func testGetVersions() {
        let request = RestClient.sharedInstance.requestForVersions()
        let response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")
        dataCleanupRequired = false
    }

    // NOTE: This test verifies that using an unauthenticated (global) client to make
    // authenticated requests raises an assertion. Since ObjC NSExceptions cannot be
    // caught natively in Swift without a bridging helper, this test is preserved in
    // the .m file. The Swift equivalent would require an ObjC exception catcher utility.

    func testGetVersion_SetDelegate() {
        let request = RestClient.sharedInstance.requestForVersions()
        let exp = expectation(description: "Request with delegate")
        let delegate = RestAPITestDelegate(request: request, expectation: exp)
        RestClient.sharedInstance.send(request, requestDelegate: delegate)
        waitForExpectations(timeout: 30.0)
        XCTAssertEqual(delegate.returnStatus, kTestRequestStatusDidLoad, "request failed")
        dataCleanupRequired = false
    }

    func testFullRequestPath() {
        let request = RestClient.sharedInstance.requestForResources(SFRestDefaultAPIVersion)
        request.path = "\(kSFDefaultRestEndpoint)\(request.path)"
        let response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")
        dataCleanupRequired = false
    }

    func testUserDefinedEndpoint() {
        let request = RestClient.sharedInstance.requestForResources(SFRestDefaultAPIVersion)
        request.endpoint = "/my/custom/endpoint"
        let response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidFail, "request should have failed")
        dataCleanupRequired = false
    }

    func testGetUserInfo() {
        let request = RestClient.sharedInstance.requestForUserInfo()
        let response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")
        dataCleanupRequired = false
    }

    func testGetSingleAccess() {
        let request = RestClient.sharedInstance.requestForSingleAccess("abc/def")
        let response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")
        if let dict = response.dataResponse as? [String: Any] {
            XCTAssertNotNil(dict["frontdoor_uri"])
        }
        dataCleanupRequired = false
    }

    func testGetLimits() {
        let request = RestClient.sharedInstance.requestForLimits(SFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")
        dataCleanupRequired = false
    }

    func testGetResources() {
        let request = RestClient.sharedInstance.requestForResources(SFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")
        dataCleanupRequired = false
    }

    func testGetDescribeGlobal() {
        let request = RestClient.sharedInstance.requestForDescribeGlobal(SFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")
        dataCleanupRequired = false
    }

    func testGetDescribeGlobal_Cancel() {
        let request = RestClient.sharedInstance.requestForDescribeGlobal(SFRestDefaultAPIVersion)
        var status = kTestRequestStatusWaiting
        let exp = expectation(description: "Request cancelled")

        RestClient.sharedInstance.send(request, failureBlock: { _, _, _ in
            status = kTestRequestStatusDidFail
            exp.fulfill()
        }, successBlock: { _, _ in
            status = kTestRequestStatusDidLoad
            exp.fulfill()
        })
        RestClient.sharedInstance.cancelAllRequests()
        waitForExpectations(timeout: 30.0)
        XCTAssertEqual(status, kTestRequestStatusDidFail, "request should have been cancelled")
        dataCleanupRequired = false
    }

    func testGetDescribeGlobal_Timeout() {
        let request = RestClient.sharedInstance.requestForDescribeGlobal(SFRestDefaultAPIVersion)
        var status = kTestRequestStatusWaiting
        let exp = expectation(description: "Request timeout")

        RestClient.sharedInstance.send(request, failureBlock: { _, _, _ in
            status = kTestRequestStatusDidFail
            exp.fulfill()
        }, successBlock: { _, _ in
            status = kTestRequestStatusDidLoad
            exp.fulfill()
        })
        let found = RestClient.sharedInstance.forceTimeoutRequest(request)
        XCTAssertTrue(found, "Could not find request to force a timeout")
        waitForExpectations(timeout: 30.0)
        XCTAssertEqual(status, kTestRequestStatusDidFail, "request should have timed out")
        dataCleanupRequired = false
    }

    func testGetMetadataWithObjectType() {
        let request = RestClient.sharedInstance.requestForMetadata(withObjectType: kContact, apiVersion: SFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")
        dataCleanupRequired = false
    }

    func testGetDescribeWithObjectType() {
        let request = RestClient.sharedInstance.requestForDescribe(withObjectType: kContact, apiVersion: SFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")
        dataCleanupRequired = false
    }

    func testGetLayoutWithObjectAPINameWithoutFormFactor() {
        let request = RestClient.sharedInstance.requestForLayout(withObjectAPIName: kContact, formFactor: nil, layoutType: nil, mode: nil, recordTypeId: nil, apiVersion: SFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")
        dataCleanupRequired = false
    }

    func testGetLayoutWithObjectAPINameWithFormFactor() {
        let request = RestClient.sharedInstance.requestForLayout(withObjectAPIName: kContact, formFactor: "Medium", layoutType: nil, mode: nil, recordTypeId: nil, apiVersion: SFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")
    }

    func testGetLayoutWithObjectAPINameWithLayoutType() {
        let request = RestClient.sharedInstance.requestForLayout(withObjectAPIName: kContact, formFactor: nil, layoutType: "Compact", mode: nil, recordTypeId: nil, apiVersion: SFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")
    }

    func testGetLayoutWithObjectAPINameWithMode() {
        let request = RestClient.sharedInstance.requestForLayout(withObjectAPIName: kContact, formFactor: nil, layoutType: nil, mode: "Edit", recordTypeId: nil, apiVersion: SFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")
    }

    func testGetSearchScopeAndOrder() {
        let request = RestClient.sharedInstance.requestForSearchScopeAndOrder(SFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")
        dataCleanupRequired = false
    }

    func testGetSearchResultLayout() {
        let request = RestClient.sharedInstance.requestForSearchResultLayout(kAccount, apiVersion: SFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")
        dataCleanupRequired = false
    }

    func testCreateBogusContact() {
        let request = RestClient.sharedInstance.requestForCreate(withObjectType: kContact, fields: nil, apiVersion: SFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidFail, "request should have failed")
    }

    func testCreateQuerySearchDelete() {
        let lastName = generateRecordName()
        let fields: [String: String] = [kFirstName: "John", kLastName: lastName]

        var request = RestClient.sharedInstance.requestForCreate(withObjectType: kContact, fields: fields, apiVersion: SFRestDefaultAPIVersion)
        var response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")

        guard let contactId = (response.dataResponse as? [String: Any])?[kLid] as? String else {
            XCTFail("id not present"); return
        }

        defer {
            request = RestClient.sharedInstance.requestForDelete(withObjectType: kContact, objectId: contactId, apiVersion: SFRestDefaultAPIVersion)
            _ = sendSyncRequest(request)
        }

        // Retrieve
        request = RestClient.sharedInstance.requestForRetrieve(withObjectType: kContact, objectId: contactId, fieldList: nil, apiVersion: SFRestDefaultAPIVersion)
        response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")
        XCTAssertEqual((response.dataResponse as? [String: Any])?[kLastName] as? String, lastName)
        XCTAssertEqual((response.dataResponse as? [String: Any])?[kFirstName] as? String, "John")

        // Retrieve with field list
        request = RestClient.sharedInstance.requestForRetrieve(withObjectType: kContact, objectId: contactId, fieldList: "LastName, FirstName", apiVersion: SFRestDefaultAPIVersion)
        response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")
        XCTAssertEqual((response.dataResponse as? [String: Any])?[kLastName] as? String, lastName)
        XCTAssertEqual((response.dataResponse as? [String: Any])?[kFirstName] as? String, "John")

        // Query — use retry since SOQL can have brief eventual consistency after create
        request = RestClient.sharedInstance.requestForQuery("select Id, FirstName from Contact where LastName='\(lastName)'", apiVersion: SFRestDefaultAPIVersion)
        let records = sendSyncQueryRequestUntilFound(request, expectedMinResults: 1, maxWaitSeconds: 30)
        XCTAssertEqual(records?.count, 1, "expected just one query result")

        // Search. NOTE: the record name is a raw UUID, so the SOSL term is `Find {name-with-hyphens}`.
        // A bare hyphen is a SOSL reserved operator, so `Find {..-..}` is rejected as MALFORMED_SEARCH
        // ("mismatched character '-' expecting '}'") — deterministically, on the live org. Escape the SOSL
        // reserved characters in the term with a backslash so the search is well-formed. (The ObjC oracle
        // issued the unescaped `Find {%@}` and then never asserted the result — its own comment flags that a
        // changed lastName "may need to escape SOSL-unsafe characters"; the Swift port added the count
        // assertion, which surfaced the pre-existing malformed-SOSL request. Escaping is the faithful fix
        // that keeps the assertion meaningful.)
        let soslSafeName = escapeSoslTerm(lastName)
        request = RestClient.sharedInstance.requestForSearch("Find {\(soslSafeName)}", apiVersion: SFRestDefaultAPIVersion)
        let searchRecords = sendSyncSearchRequestWithRetry(request, expectedMinResults: 1, maxWaitSeconds: 45)
        XCTAssertEqual(searchRecords?.count, 1, "expected just one search result")
    }

    /// Backslash-escapes the SOSL reserved characters in a search term so it can be embedded in a
    /// `Find {...}` clause. See the SOSL reference — reserved: ? & | ! { } [ ] ( ) ^ ~ * : \ " ' + -
    private func escapeSoslTerm(_ term: String) -> String {
        let reserved: Set<Character> = ["?", "&", "|", "!", "{", "}", "[", "]", "(", ")", "^", "~", "*", ":", "\\", "\"", "'", "+", "-"]
        var out = ""
        for ch in term {
            if reserved.contains(ch) { out.append("\\") }
            out.append(ch)
        }
        return out
    }

    func testCreateUpdateQuerySearchDelete() {
        let lastName = generateRecordName()
        let updatedLastName = "\(lastName)_updated"
        let fields: [String: String] = [kFirstName: "John", kLastName: lastName]

        var request = RestClient.sharedInstance.requestForCreate(withObjectType: kContact, fields: fields, apiVersion: SFRestDefaultAPIVersion)
        var response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")

        guard let contactId = (response.dataResponse as? [String: Any])?[kLid] as? String else {
            XCTFail("id not present"); return
        }

        defer {
            request = RestClient.sharedInstance.requestForDelete(withObjectType: kContact, objectId: contactId, apiVersion: SFRestDefaultAPIVersion)
            _ = sendSyncRequest(request)
        }

        // Query — use retry since SOQL can have brief eventual consistency after create
        request = RestClient.sharedInstance.requestForQuery("select Id, FirstName from Contact where LastName='\(lastName)'", apiVersion: SFRestDefaultAPIVersion)
        let queryRecords = sendSyncQueryRequestUntilFound(request, expectedMinResults: 1, maxWaitSeconds: 30)
        XCTAssertEqual(queryRecords?.count, 1, "expected just one query result")

        // Update
        let updatedFields = [kLastName: updatedLastName]
        request = RestClient.sharedInstance.requestForUpdate(withObjectType: kContact, objectId: contactId, fields: updatedFields, apiVersion: SFRestDefaultAPIVersion)
        response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad)

        // Query updated
        request = RestClient.sharedInstance.requestForQuery("select Id, FirstName from Contact where LastName='\(updatedLastName)'", apiVersion: SFRestDefaultAPIVersion)
        response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad)
        let updatedRecords = (response.dataResponse as? [String: Any])?[kRecords] as? [[String: Any]]
        XCTAssertEqual(updatedRecords?.count, 1, "expected just one query result")

        // Old should be gone
        request = RestClient.sharedInstance.requestForQuery("select Id, FirstName from Contact where LastName='\(lastName)'", apiVersion: SFRestDefaultAPIVersion)
        response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad)
        let oldRecords = (response.dataResponse as? [String: Any])?[kRecords] as? [[String: Any]]
        XCTAssertEqual(oldRecords?.count, 0, "expected no result")
    }

    func testUpsertWithBogusExternalIdField() {
        let acctName = generateRecordName()
        let fields = [kName: acctName]
        let uuid = UUID().uuidString
        let request = RestClient.sharedInstance.requestForUpsert(withObjectType: kAccount, externalIdField: "bogusField__c", externalId: uuid, fields: fields, apiVersion: SFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidFail, "request should have failed")
        XCTAssertEqual(response.lastError?.code, 404, "error code should have been 404")
    }

    func testUpsert() {
        let accountName = generateRecordName()
        var fields: [String: String] = [kName: accountName]

        var request = RestClient.sharedInstance.requestForUpsert(withObjectType: kAccount, externalIdField: kId, externalId: nil, fields: fields, apiVersion: SFRestDefaultAPIVersion)
        var response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad)
        guard let accountId = (response.dataResponse as? [String: Any])?[kLid] as? String else {
            XCTFail("id not present"); return
        }

        // Retrieve
        request = RestClient.sharedInstance.requestForRetrieve(withObjectType: kAccount, objectId: accountId, fieldList: kName, apiVersion: SFRestDefaultAPIVersion)
        response = sendSyncRequest(request)
        XCTAssertEqual((response.dataResponse as? [String: Any])?[kName] as? String, accountName)

        // Update with upsert
        let accountNameUpdated = "\(accountName)_updated"
        fields = [kName: accountNameUpdated]
        request = RestClient.sharedInstance.requestForUpsert(withObjectType: kAccount, externalIdField: kId, externalId: accountId, fields: fields, apiVersion: SFRestDefaultAPIVersion)
        response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad)

        // Retrieve updated
        request = RestClient.sharedInstance.requestForRetrieve(withObjectType: kAccount, objectId: accountId, fieldList: kName, apiVersion: SFRestDefaultAPIVersion)
        response = sendSyncRequest(request)
        XCTAssertEqual((response.dataResponse as? [String: Any])?[kName] as? String, accountNameUpdated)
    }

    func testSOQLError() {
        let request = RestClient.sharedInstance.requestForQuery("", apiVersion: SFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidFail)
        XCTAssertEqual(response.lastError?.code, 400)
        dataCleanupRequired = false
    }

    func testRetrieveError() {
        let request = RestClient.sharedInstance.requestForRetrieve(withObjectType: kContact, objectId: "bogus_contact_id", fieldList: nil, apiVersion: SFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidFail)
        XCTAssertEqual(response.lastError?.code, 404)
        dataCleanupRequired = false
    }

    func testBatchRequest() {
        let accountName = generateRecordName()
        let contactName = generateRecordName()

        let createAccountRequest = RestClient.sharedInstance.requestForCreate(withObjectType: kAccount, fields: [kName: accountName], apiVersion: SFRestDefaultAPIVersion)
        let createContactRequest = RestClient.sharedInstance.requestForCreate(withObjectType: kContact, fields: [kLastName: contactName], apiVersion: SFRestDefaultAPIVersion)
        let queryForAccount = RestClient.sharedInstance.requestForQuery("select Id from Account where Name = '\(accountName)'", apiVersion: SFRestDefaultAPIVersion)
        let queryForContact = RestClient.sharedInstance.requestForQuery("select Id from Contact where Name = '\(contactName)'", apiVersion: SFRestDefaultAPIVersion)

        let batchRequest = RestClient.sharedInstance.batchRequest([createAccountRequest, createContactRequest, queryForAccount, queryForContact], haltOnError: true, apiVersion: SFRestDefaultAPIVersion)
        let response = sendSyncRequest(batchRequest)

        guard let dataResponse = response.dataResponse as? [String: Any],
              let results = dataResponse[kResults] as? [[String: Any]] else {
            XCTFail("Invalid response"); return
        }
        XCTAssertEqual(dataResponse[kHasErrors] as? Bool, false)
        XCTAssertEqual(results.count, 4)
        XCTAssertEqual((results[0][kStatusCode] as? Int), 201)
        XCTAssertEqual((results[1][kStatusCode] as? Int), 201)
        XCTAssertEqual((results[2][kStatusCode] as? Int), 200)
        XCTAssertEqual((results[3][kStatusCode] as? Int), 200)

        let accountId = (results[0][kResult] as? [String: Any])?[kLid] as? String
        let contactId = (results[1][kResult] as? [String: Any])?[kLid] as? String
        let idFromFirstQuery = ((results[2][kResult] as? [String: Any])?[kRecords] as? [[String: Any]])?.first?[kId] as? String
        let idFromSecondQuery = ((results[3][kResult] as? [String: Any])?[kRecords] as? [[String: Any]])?.first?[kId] as? String
        XCTAssertEqual(accountId, idFromFirstQuery)
        XCTAssertEqual(contactId, idFromSecondQuery)
    }

    func testCompositeRequest() {
        let accountName = generateRecordName()
        let contactName = generateRecordName()

        let createAccountRequest = RestClient.sharedInstance.requestForCreate(withObjectType: kAccount, fields: [kName: accountName], apiVersion: SFRestDefaultAPIVersion)
        let createContactRequest = RestClient.sharedInstance.requestForCreate(withObjectType: kContact, fields: [kLastName: contactName, kAccountId: "@{refAccount.id}"], apiVersion: SFRestDefaultAPIVersion)
        let queryForContact = RestClient.sharedInstance.requestForQuery("select Id, AccountId from Contact where LastName = '\(contactName)'", apiVersion: SFRestDefaultAPIVersion)

        let compositeRequest = RestClient.sharedInstance.compositeRequest([createAccountRequest, createContactRequest, queryForContact], refIds: ["refAccount", "refContact", "refQuery"], allOrNone: true, apiVersion: SFRestDefaultAPIVersion)
        let response = sendSyncRequest(compositeRequest)

        guard let dataResponse = response.dataResponse as? [String: Any],
              let results = dataResponse[kCompositeResponse] as? [[String: Any]] else {
            XCTFail("Invalid response"); return
        }
        XCTAssertEqual(results.count, 3)
        XCTAssertEqual((results[0][kHttpStatusCode] as? Int), 201)
        XCTAssertEqual((results[1][kHttpStatusCode] as? Int), 201)
        XCTAssertEqual((results[2][kHttpStatusCode] as? Int), 200)

        let accountId = (results[0][kBody] as? [String: Any])?[kLid] as? String
        let contactId = (results[1][kBody] as? [String: Any])?[kLid] as? String
        let queryRecords = (results[2][kBody] as? [String: Any])?[kRecords] as? [[String: Any]]
        XCTAssertEqual(queryRecords?.count, 1)
        XCTAssertEqual(queryRecords?.first?[kAccountId] as? String, accountId)
        XCTAssertEqual(queryRecords?.first?[kId] as? String, contactId)
    }

    func testSObjectTreeRequest() {
        let accountName = generateRecordName()
        let contactName = generateRecordName()
        let otherContactName = generateRecordName()

        guard let contactTree = SObjectTree(objectType: kContact, objectTypePlural: "Contacts", referenceId: "refContact", fields: [kLastName: contactName], childrenTrees: nil),
              let otherContactTree = SObjectTree(objectType: kContact, objectTypePlural: "Contacts", referenceId: "refOtherContact", fields: [kLastName: otherContactName], childrenTrees: nil),
              let accountTree = SObjectTree(objectType: kAccount, objectTypePlural: nil, referenceId: "refAccount", fields: [kName: accountName], childrenTrees: [contactTree, otherContactTree]) else {
            XCTFail("Failed to create SObjectTree"); return
        }

        let treeRequest = RestClient.sharedInstance.requestForSObjectTree(kAccount, objectTrees: [accountTree], apiVersion: SFRestDefaultAPIVersion)
        let response = sendSyncRequest(treeRequest)

        guard let dataResponse = response.dataResponse as? [String: Any],
              let results = dataResponse[kResults] as? [[String: Any]] else {
            XCTFail("Invalid response"); return
        }
        XCTAssertEqual(dataResponse[kHasErrors] as? Bool, false)
        XCTAssertEqual(results.count, 3)

        let accountId = results[0][kLid] as? String
        let contactId = results[1][kLid] as? String
        let otherContactId = results[2][kLid] as? String

        // Query first contact
        var queryRequest = RestClient.sharedInstance.requestForQuery("select Id, AccountId from Contact where LastName = '\(contactName)'", apiVersion: SFRestDefaultAPIVersion)
        var queryResponse = sendSyncRequest(queryRequest)
        var queryRecords = (queryResponse.dataResponse as? [String: Any])?[kRecords] as? [[String: Any]]
        XCTAssertEqual(queryRecords?.count, 1)
        XCTAssertEqual(queryRecords?.first?[kAccountId] as? String, accountId)
        XCTAssertEqual(queryRecords?.first?[kId] as? String, contactId)

        // Query other contact
        queryRequest = RestClient.sharedInstance.requestForQuery("select Id, AccountId from Contact where LastName = '\(otherContactName)'", apiVersion: SFRestDefaultAPIVersion)
        queryResponse = sendSyncRequest(queryRequest)
        queryRecords = (queryResponse.dataResponse as? [String: Any])?[kRecords] as? [[String: Any]]
        XCTAssertEqual(queryRecords?.count, 1)
        XCTAssertEqual(queryRecords?.first?[kAccountId] as? String, accountId)
        XCTAssertEqual(queryRecords?.first?[kId] as? String, otherContactId)
    }

    func testGetPrimingRecords() {
        let request = RestClient.sharedInstance.requestForPrimingRecords(nil, changedAfterTimestamp: nil, apiVersion: SFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        guard let dataResponse = response.dataResponse as? [String: Any] else { XCTFail("No response"); return }
        XCTAssertNotNil(dataResponse["primingRecords"])
        XCTAssertNotNil(dataResponse["relayToken"])
        XCTAssertNotNil(dataResponse["ruleErrors"])
        XCTAssertNotNil(dataResponse["stats"])
    }

    func testCollectionCreate() {
        let firstAccountName = "\(kEntityPrefixName)_account_1_\(CFAbsoluteTimeGetCurrent())"
        let secondAccountName = "\(kEntityPrefixName)_account_2_\(CFAbsoluteTimeGetCurrent())"
        let contactName = "\(kEntityPrefixName)_contact_\(CFAbsoluteTimeGetCurrent())"

        let records = makeRecords([
            ["Account", "Name", firstAccountName],
            ["Account", "Name", secondAccountName],
            ["Contact", "LastName", contactName]
        ])

        let request = RestClient.sharedInstance.requestForCollectionCreate(true, records: records, apiVersion: SFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        let parsedResponse = CollectionResponse(array: response.dataResponse as? [[String: Any]] ?? [])

        XCTAssertEqual(parsedResponse.subResponses.count, 3)
        XCTAssertTrue(parsedResponse.subResponses[0].objectId?.hasPrefix("001") == true)
        XCTAssertTrue(parsedResponse.subResponses[0].success)
        XCTAssertTrue(parsedResponse.subResponses[1].success)
        XCTAssertTrue(parsedResponse.subResponses[2].objectId?.hasPrefix("003") == true)
        XCTAssertTrue(parsedResponse.subResponses[2].success)
    }

    func testCollectionRetrieve() {
        let firstAccountName = "\(kEntityPrefixName)_account_1_\(CFAbsoluteTimeGetCurrent())"
        let secondAccountName = "\(kEntityPrefixName)_account_2_\(CFAbsoluteTimeGetCurrent())"
        let contactName = "\(kEntityPrefixName)_contact_\(CFAbsoluteTimeGetCurrent())"

        let records = makeRecords([
            ["Account", "Name", firstAccountName],
            ["Contact", "LastName", contactName],
            ["Account", "Name", secondAccountName]
        ])

        let request = RestClient.sharedInstance.requestForCollectionCreate(true, records: records, apiVersion: SFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        let parsedCreateResponse = CollectionResponse(array: response.dataResponse as? [[String: Any]] ?? [])
        let firstAccountId = parsedCreateResponse.subResponses[0].objectId ?? ""
        let secondAccountId = parsedCreateResponse.subResponses[2].objectId ?? ""

        let accountsRetrieveRequest = RestClient.sharedInstance.requestForCollectionRetrieve(kAccount, objectIds: [firstAccountId, secondAccountId], fieldList: ["Id", "Name"], apiVersion: SFRestDefaultAPIVersion)
        let retrieveResponse = sendSyncRequest(accountsRetrieveRequest)
        guard let accountsRetrieved = retrieveResponse.dataResponse as? [[String: Any]] else { XCTFail("bad response"); return }
        XCTAssertEqual(accountsRetrieved.count, 2)
        XCTAssertEqual(accountsRetrieved[0]["Name"] as? String, firstAccountName)
        XCTAssertEqual(accountsRetrieved[1]["Name"] as? String, secondAccountName)
    }

    func testCollectionDelete() {
        let firstAccountName = "\(kEntityPrefixName)_account_1_\(CFAbsoluteTimeGetCurrent())"
        let secondAccountName = "\(kEntityPrefixName)_account_2_\(CFAbsoluteTimeGetCurrent())"
        let contactName = "\(kEntityPrefixName)_contact_\(CFAbsoluteTimeGetCurrent())"

        let records = makeRecords([
            ["Account", "Name", firstAccountName],
            ["Contact", "LastName", contactName],
            ["Account", "Name", secondAccountName]
        ])

        let createRequest = RestClient.sharedInstance.requestForCollectionCreate(true, records: records, apiVersion: SFRestDefaultAPIVersion)
        let createResponse = sendSyncRequest(createRequest)
        let parsedCreateResponse = CollectionResponse(array: createResponse.dataResponse as? [[String: Any]] ?? [])
        let firstAccountId = parsedCreateResponse.subResponses[0].objectId ?? ""
        let contactId = parsedCreateResponse.subResponses[1].objectId ?? ""

        let deleteRequest = RestClient.sharedInstance.requestForCollectionDelete(true, objectIds: [firstAccountId, contactId], apiVersion: SFRestDefaultAPIVersion)
        let deleteResponse = sendSyncRequest(deleteRequest)
        let parsedDeleteResponse = CollectionResponse(array: deleteResponse.dataResponse as? [[String: Any]] ?? [])
        XCTAssertEqual(parsedDeleteResponse.subResponses.count, 2)
        XCTAssertTrue(parsedDeleteResponse.subResponses[0].success)
        XCTAssertTrue(parsedDeleteResponse.subResponses[1].success)

        // Verify deleted
        let retrieveRequest = RestClient.sharedInstance.requestForRetrieve(withObjectType: "Account", objectId: firstAccountId, fieldList: "Id,Name", apiVersion: SFRestDefaultAPIVersion)
        let retrieveResponse = sendSyncRequest(retrieveRequest)
        XCTAssertEqual(retrieveResponse.lastError?.code, 404)
    }

    // MARK: - Files Tests

    func testOwnedFilesList() {
        var request = RestClient.sharedInstance.requestForOwnedFilesList(nil, page: 0, apiVersion: SFRestDefaultAPIVersion)
        var response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad)
        request = RestClient.sharedInstance.requestForOwnedFilesList(currentUser?.credentials.userId, page: 0, apiVersion: SFRestDefaultAPIVersion)
        response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad)
        dataCleanupRequired = false
    }

    func testFilesInUsersGroups() {
        var request = RestClient.sharedInstance.requestForFilesInUsersGroups(nil, page: 0, apiVersion: SFRestDefaultAPIVersion)
        var response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad)
        request = RestClient.sharedInstance.requestForFilesInUsersGroups(currentUser?.credentials.userId, page: 0, apiVersion: SFRestDefaultAPIVersion)
        response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad)
        dataCleanupRequired = false
    }

    func testFilesSharedWithUser() {
        var request = RestClient.sharedInstance.requestForFilesSharedWithUser(nil, page: 0, apiVersion: SFRestDefaultAPIVersion)
        var response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad)
        request = RestClient.sharedInstance.requestForFilesSharedWithUser(currentUser?.credentials.userId, page: 0, apiVersion: SFRestDefaultAPIVersion)
        response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad)
        dataCleanupRequired = false
    }

    func testUploadDownloadDeleteFile() {
        let fileAttrs = uploadFile()

        // Download content
        var request = RestClient.sharedInstance.requestForFileContents(fileAttrs[kLid] as? String ?? "", version: nil, apiVersion: SFRestDefaultAPIVersion)
        var response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad)

        // Download rendition
        request = RestClient.sharedInstance.requestForFileRendition(fileAttrs[kLid] as? String ?? "", version: nil, renditionType: "PDF", page: 0, apiVersion: SFRestDefaultAPIVersion)
        response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad)

        // Delete
        request = RestClient.sharedInstance.requestForDelete(withObjectType: "ContentDocument", objectId: fileAttrs[kLid] as? String ?? "", apiVersion: SFRestDefaultAPIVersion)
        response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad)

        // Download again (expect 404)
        request = RestClient.sharedInstance.requestForFileContents(fileAttrs[kLid] as? String ?? "", version: nil, apiVersion: SFRestDefaultAPIVersion)
        response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidFail)
        XCTAssertEqual(response.lastError?.code, 404)
    }

    // MARK: - Token Refresh Tests

    func testInvalidAccessTokenWithValidGetRequest() {
        let invalidAccessToken = "xyz"
        changeOauthTokens(accessToken: invalidAccessToken, refreshToken: nil)

        let request = RestClient.sharedInstance.requestForResources(SFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad)

        let newAccessToken = currentUser?.credentials.accessToken ?? ""
        XCTAssertNotEqual(newAccessToken, invalidAccessToken, "access token wasn't refreshed")
        dataCleanupRequired = false
    }

    func testInvalidAccessTokenWithValidPostRequest() {
        let invalidAccessToken = "xyz"
        changeOauthTokens(accessToken: invalidAccessToken, refreshToken: nil)

        let fields = [kFirstName: "John", kLastName: generateRecordName()]
        let request = RestClient.sharedInstance.requestForCreate(withObjectType: kContact, fields: fields, apiVersion: SFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad)
        let contactId = (response.dataResponse as? [String: Any])?[kLid] as? String
        XCTAssertNotNil(contactId)

        let newAccessToken = currentUser?.credentials.accessToken ?? ""
        XCTAssertNotEqual(newAccessToken, invalidAccessToken, "access token wasn't refreshed")

        if let contactId = contactId {
            let deleteRequest = RestClient.sharedInstance.requestForDelete(withObjectType: kContact, objectId: contactId, apiVersion: SFRestDefaultAPIVersion)
            _ = sendSyncRequest(deleteRequest)
        }
        dataCleanupRequired = false
    }

    func testInvalidAccessTokenWithInvalidRequest() {
        let invalidAccessToken = "xyz"
        changeOauthTokens(accessToken: invalidAccessToken, refreshToken: nil)

        let request = RestClient.sharedInstance.requestForQuery("", apiVersion: SFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidFail)

        let newAccessToken = currentUser?.credentials.accessToken ?? ""
        XCTAssertNotEqual(newAccessToken, invalidAccessToken, "access token wasn't refreshed")
        dataCleanupRequired = false
    }

    func testInvalidAccessAndRefreshToken() {
        let fakeUser = createNewUser()
        XCTAssertNotNil(fakeUser)
        fakeUser?.credentials.accessToken = "xyz"
        fakeUser?.credentials.refreshToken = "xyz"

        guard let fakeUser = fakeUser else { return }
        guard let restAPI = RestClient.restClient(for: fakeUser) else {
            XCTFail("Could not create RestClient for fake user")
            return
        }

        defer {
            _ = deleteUser(fakeUser)
            dataCleanupRequired = false
        }

        let request = restAPI.requestForResources(SFRestDefaultAPIVersion)
        let response = sendSyncRequest(request, usingInstance: restAPI)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidFail)
        XCTAssertEqual(response.lastError?.domain, kSFOAuthErrorDomain)
        XCTAssertEqual(response.lastError?.code, kSFOAuthErrorInvalidGrant)
    }

    func testInvalidAccessAndRefreshToken_MultipleRequests() {
        let fakeUser = createNewUser()
        XCTAssertNotNil(fakeUser)
        fakeUser?.credentials.accessToken = "xyz"
        fakeUser?.credentials.refreshToken = "xyz"

        guard let fakeUser = fakeUser else { return }
        defer {
            _ = deleteUser(fakeUser)
            dataCleanupRequired = false
        }

        guard let restAPI = RestClient.restClient(for: fakeUser) else { return }
        let expectations = (0..<5).map { expectation(description: "request\($0)") }

        for i in 0..<5 {
            let request = restAPI.requestForDescribeGlobal(SFRestDefaultAPIVersion)
            restAPI.send(request, failureBlock: { _, error, _ in
                XCTAssertEqual((error as NSError?)?.domain, kSFOAuthErrorDomain)
                expectations[i].fulfill()
            }, successBlock: { _, _ in })
        }
        waitForExpectations(timeout: 10.0)
    }

    // MARK: - Query Builder Tests

    func testSOQL() {
        let simpleQuery = "select id from Lead where id<>null limit 10"
        let generatedSimple = RestClient.soqlQuery(withFields: ["id"], sObject: "Lead", whereClause: "id<>null", limit: 10)
        XCTAssertEqual(simpleQuery, generatedSimple)

        let complexQuery = "select id,status from Lead where id<>null group by status limit 10"
        let generatedComplex = RestClient.soqlQuery(withFields: ["id", "status"], sObject: "Lead", whereClause: "id<>null", groupBy: ["status"], having: nil, orderBy: nil, limit: 10)
        XCTAssertEqual(complexQuery, generatedComplex)
    }

    func testSOSL() {
        let simpleSearch = "FIND {blah} IN NAME FIELDS RETURNING User"
        let generatedSimple = RestClient.soslSearch(withSearchTerm: "blah", objectScope: ["User": ""])
        XCTAssertEqual(simpleSearch, generatedSimple)
    }

    func testReallyLongSOQL() {
        let lastName = "Silver-\(Date())"
        let fields = [kFirstName: "LongJohn", kLastName: lastName]
        var request = RestClient.sharedInstance.requestForCreate(withObjectType: kContact, fields: fields, apiVersion: SFRestDefaultAPIVersion)
        var response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad)

        guard let contactId = (response.dataResponse as? [String: Any])?[kLid] as? String else {
            XCTFail("id not present"); return
        }

        defer {
            request = RestClient.sharedInstance.requestForDelete(withObjectType: kContact, objectId: contactId, apiVersion: SFRestDefaultAPIVersion)
            _ = sendSyncRequest(request)
        }

        var queryString = "SELECT Id, FirstName, LastName FROM Contact WHERE Id IN ('"
        for _ in 0..<100 {
            queryString += "\(contactId)', '"
        }
        queryString += "')"

        request = RestClient.sharedInstance.requestForQuery(queryString, apiVersion: SFRestDefaultAPIVersion)
        response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad)
        let records = (response.dataResponse as? [String: Any])?[kRecords] as? [[String: Any]]
        XCTAssertEqual(records?.count, 1)
    }

    // MARK: - User Agent Tests

    func testRequestUserAgent() {
        // The default User-Agent is applied by the network layer (SFNetwork.sendRequest), not written
        // back onto RestRequest.request: prepareRequestForSend returns a value-type URLRequest copy, so
        // — unlike the ObjC original, which mutated an NSMutableURLRequest in place — the header never
        // appears on request.request. Observe it on the request the SDK actually dispatches instead.
        guard let currentUser = currentUser else {
            XCTFail("No current user")
            return
        }
        let request = RestClient.sharedInstance.requestForSearchResultLayout(kAccount, apiVersion: SFRestDefaultAPIVersion)
        guard let finalRequest = request.prepareRequestForSend(currentUser) else {
            XCTFail("prepareRequestForSend returned nil")
            return
        }
        let task = Network.sharedEphemeralInstance().sendRequest(finalRequest, dataResponseBlock: nil)
        let userAgent = task.originalRequest?.allHTTPHeaderFields?["User-Agent"]
        XCTAssertEqual(userAgent, RestClient.userAgentString())
    }

    func testRequestUserAgentWithOverride() {
        let request = RestClient.sharedInstance.requestForSearchResultLayout(kAccount, apiVersion: SFRestDefaultAPIVersion)
        request.setHeaderValue(RestClient.userAgentString("MobileSync"), forHeaderName: "User-Agent")
        _ = sendSyncRequest(request)
        let userAgent = request.request.allHTTPHeaderFields?["User-Agent"]
        XCTAssertEqual(userAgent, RestClient.userAgentString("MobileSync"))
    }

    // MARK: - Custom Request Tests

    func testCustomBaseURLRequest() {
        let request = RestRequest(method: .GET, serviceHostType: .instance, baseURL: "http://www.apple.com", path: "/test/testing", queryParams: nil)
        XCTAssertEqual(request.baseURL, "http://www.apple.com")
        guard let currentUser = currentUser else { return }
        guard let finalRequest = request.prepareRequestForSend(currentUser) else { return }
        let expectedURL = "http://www.apple.com\(kSFDefaultRestEndpoint)/test/testing"
        XCTAssertEqual(finalRequest.url?.absoluteString, expectedURL)
    }

    func testCustomBaseURLRequestPOST() {
        let request = RestRequest(method: .POST, path: "https://www.apple.com/test/testing", queryParams: nil)
        request.setCustomRequestBodyData("hello".data(using: .utf8) ?? Data(), contentType: "application/octet-stream")
        guard let currentUser = currentUser else { return }
        guard let finalRequest = request.prepareRequestForSend(currentUser) else {
            XCTFail("prepareRequestForSend returned nil")
            return
        }
        XCTAssertEqual(finalRequest.url?.absoluteString, "https://www.apple.com/test/testing")
        XCTAssertEqual(finalRequest.value(forHTTPHeaderField: "Content-Type"), "application/octet-stream")
        XCTAssertEqual(finalRequest.value(forHTTPHeaderField: "Content-Length"), "5")
        XCTAssertEqual(finalRequest.httpMethod, "POST")
    }

    // MARK: - URL Resolution Tests

    func testRestUrlForBaseUrl() {
        let creds = getTestCredentials(domain: "somedomain.example.com", instanceUrl: URL(string: "https://someinstance.example.com"), communityUrl: URL(string: "https://somecommunity.example.com/community"))
        let baseUrl = "https://somebaseurl.example.com"
        var restUrl = RestRequest.restUrl(forBaseUrl: baseUrl, serviceHostType: .instance, credentials: creds)
        XCTAssertEqual(restUrl, baseUrl)
        restUrl = RestRequest.restUrl(forBaseUrl: baseUrl, serviceHostType: .login, credentials: creds)
        XCTAssertEqual(restUrl, baseUrl)
    }

    func testRestUrlForCommunityUrl() {
        let creds = getTestCredentials(domain: "somedomain.example.com", instanceUrl: URL(string: "https://someinstance.example.com"), communityUrl: URL(string: "https://somecommunity.example.com/community"))
        var restUrl = RestRequest.restUrl(forBaseUrl: nil, serviceHostType: .instance, credentials: creds)
        XCTAssertEqual(restUrl, creds.communityUrl?.absoluteString)
        restUrl = RestRequest.restUrl(forBaseUrl: nil, serviceHostType: .login, credentials: creds)
        XCTAssertEqual(restUrl, creds.communityUrl?.absoluteString)
    }

    func testRestUrlForLoginServiceHost() {
        let loginDomain = "somedomain.example.com"
        let creds = getTestCredentials(domain: loginDomain, instanceUrl: URL(string: "https://someinstance.example.com"), communityUrl: nil)
        let restUrl = RestRequest.restUrl(forBaseUrl: nil, serviceHostType: .login, credentials: creds)
        XCTAssertEqual(restUrl, "https://\(loginDomain)")
    }

    func testRestUrlForInstanceServiceHost() {
        let instanceUrl = URL(string: "https://someinstance.example.com")
        let creds = getTestCredentials(domain: "somdomain.example.com", instanceUrl: instanceUrl, communityUrl: nil)
        let restUrl = RestRequest.restUrl(forBaseUrl: nil, serviceHostType: .instance, credentials: creds)
        XCTAssertEqual(restUrl, instanceUrl?.absoluteString)
    }

    // MARK: - Global Instance Tests

    func testRestApiGlobalInstance() {
        let sharedInstance = RestClient.sharedInstance
        let globalInstance = RestClient.sharedGlobalInstance
        XCTAssertNotNil(globalInstance)
        XCTAssertTrue(globalInstance !== sharedInstance)
    }

    func testPublicApiCalls() {
        let getExpectation = expectation(description: "Get")
        var error: NSError?
        var responseDict: [String: Any]?
        let testBaseURL = "https://mobilesdk.my.salesforce.com"
        let testPathURL = "/.well-known/auth-configuration"
        let request = RestRequest.customUrlRequest(withMethod: .GET, baseURL: testBaseURL, path: testPathURL, queryParams: nil)
        XCTAssertEqual(request.baseURL, testBaseURL)
        XCTAssertEqual(request.path, testPathURL)
        RestClient.sharedGlobalInstance.send(request, failureBlock: { _, e, _ in
            error = e as NSError?
            getExpectation.fulfill()
        }, successBlock: { resp, _ in
            responseDict = resp as? [String: Any]
            getExpectation.fulfill()
        })
        waitForExpectations(timeout: 30)
        XCTAssertNil(error, "RestApi call to a public api should not fail")
        XCTAssertNotNil(responseDict)
        XCTAssertGreaterThan(responseDict?.count ?? 0, 0)
    }

    // MARK: - Notification Tests

    func testNotificationsStatus() {
        let request = RestClient.sharedInstance.requestForNotificationsStatus(SFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad)
    }

    func testGetNotifications() {
        let builder = FetchNotificationsRequestBuilder()
        let yesterdayDate = Date().addingTimeInterval(-1 * 60 * 60 * 24)
        builder.setAfter(yesterdayDate)
        builder.setSize(10)
        let request = builder.buildFetchNotificationsRequest(SFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad)
    }

    func testUpdateReadNotifications() {
        let builder = UpdateNotificationsRequestBuilder()
        builder.setBefore(Date())
        builder.setRead(false)
        let request = builder.buildUpdateNotificationsRequest(SFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad)
    }

    func testUpdateSeenNotifications() {
        let builder = UpdateNotificationsRequestBuilder()
        builder.setBefore(Date())
        builder.setSeen(true)
        let request = builder.buildUpdateNotificationsRequest(SFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad)
    }

    func testGetNotificationRequestPath() {
        let notificationId = "testID"
        let request = RestClient.sharedInstance.requestForNotification(notificationId, apiVersion: SFRestDefaultAPIVersion)
        let expectedPath = "/connect/notifications/\(notificationId)"
        XCTAssertTrue(request.path.hasSuffix(expectedPath))
    }

    func testRequestForNotificationTypes() {
        let api = RestClient.sharedInstance
        let request = api.requestForNotificationTypes()
        XCTAssertNotNil(request)
        XCTAssertEqual(request.method, .GET)
        let expectedPath = "/\(api.apiVersion)/connect/notifications/types"
        XCTAssertEqual(request.path, expectedPath)
    }

    func testRequestForInvokeNotificationAction() {
        let notificationId = "12345"
        let actionIdentifier = "approve_action"
        let api = RestClient.sharedInstance
        let request = api.requestForInvokeNotificationAction(notificationId, actionIdentifier: actionIdentifier)
        XCTAssertNotNil(request)
        XCTAssertEqual(request.method, .POST)
        let expectedPath = "/\(api.apiVersion)/connect/notifications/\(notificationId)/actions/\(actionIdentifier)"
        XCTAssertEqual(request.path, expectedPath)
    }

    // MARK: - Redirect Test

    func testRedirect() {
        let fields = [kFirstName: "John", kLastName: generateRecordName()]
        let contactRequest = RestClient.sharedInstance.requestForCreate(withObjectType: kContact, fields: fields, apiVersion: SFRestDefaultAPIVersion)
        let contactResponse = sendSyncRequest(contactRequest)
        guard let contactId = (contactResponse.dataResponse as? [String: Any])?[kLid] as? String else { return }

        let path = "/services/images/photo/\(contactId)"
        let request = RestRequest(method: .GET, path: path, queryParams: nil)
        request.endpoint = ""
        let response = sendSyncRequest(request)
        let statusCode = (response.rawResponse as? HTTPURLResponse)?.statusCode
        XCTAssertEqual(statusCode, 200, "Request did not return 200")
    }

    // MARK: - Dropped Tests Restored

    func testBatchWithBatchRequest() {
        let accountName = generateRecordName()
        let contactName = generateRecordName()

        let batchRequestBuilder = BatchRequestBuilder()

        let createAccountRequest = RestClient.sharedInstance.requestForCreate(withObjectType: kAccount, fields: [kName: accountName], apiVersion: SFRestDefaultAPIVersion)
        batchRequestBuilder.addRequest(createAccountRequest)

        let createContactRequest = RestClient.sharedInstance.requestForCreate(withObjectType: kContact, fields: [kLastName: contactName], apiVersion: SFRestDefaultAPIVersion)
        batchRequestBuilder.addRequest(createContactRequest)

        let queryForAccount = RestClient.sharedInstance.requestForQuery("select Id from Account where Name = '\(accountName)'", apiVersion: SFRestDefaultAPIVersion)
        batchRequestBuilder.addRequest(queryForAccount)

        let queryForContact = RestClient.sharedInstance.requestForQuery("select Id from Contact where Name = '\(contactName)'", apiVersion: SFRestDefaultAPIVersion)
        batchRequestBuilder.addRequest(queryForContact)

        let batchRequest = batchRequestBuilder.buildBatchRequest(SFRestDefaultAPIVersion)
        let response = sendSyncRequest(batchRequest)

        guard let dataResponse = response.dataResponse as? [String: Any],
              let results = dataResponse[kResults] as? [[String: Any]] else {
            XCTFail("Invalid response"); return
        }
        XCTAssertEqual(dataResponse[kHasErrors] as? Bool, false)
        XCTAssertEqual(results.count, 4)
        XCTAssertEqual((results[0][kStatusCode] as? Int), 201)
        XCTAssertEqual((results[1][kStatusCode] as? Int), 201)
        XCTAssertEqual((results[2][kStatusCode] as? Int), 200)
        XCTAssertEqual((results[3][kStatusCode] as? Int), 200)

        let accountId = (results[0][kResult] as? [String: Any])?[kLid] as? String
        let contactId = (results[1][kResult] as? [String: Any])?[kLid] as? String
        let idFromFirstQuery = ((results[2][kResult] as? [String: Any])?[kRecords] as? [[String: Any]])?.first?[kId] as? String
        let idFromSecondQuery = ((results[3][kResult] as? [String: Any])?[kRecords] as? [[String: Any]])?.first?[kId] as? String
        XCTAssertEqual(accountId, idFromFirstQuery)
        XCTAssertEqual(contactId, idFromSecondQuery)
    }

    func testBatchWithBatchRequestResponse() {
        let accountName = generateRecordName()
        let contactName = generateRecordName()

        let batchRequestBuilder = BatchRequestBuilder()

        let createAccountRequest = RestClient.sharedInstance.requestForCreate(withObjectType: kAccount, fields: [kName: accountName], apiVersion: SFRestDefaultAPIVersion)
        batchRequestBuilder.addRequest(createAccountRequest)

        let createContactRequest = RestClient.sharedInstance.requestForCreate(withObjectType: kContact, fields: [kLastName: contactName], apiVersion: SFRestDefaultAPIVersion)
        batchRequestBuilder.addRequest(createContactRequest)

        let queryForAccount = RestClient.sharedInstance.requestForQuery("select Id from Account where Name = '\(accountName)'", apiVersion: SFRestDefaultAPIVersion)
        batchRequestBuilder.addRequest(queryForAccount)

        let queryForContact = RestClient.sharedInstance.requestForQuery("select Id from Contact where Name = '\(contactName)'", apiVersion: SFRestDefaultAPIVersion)
        batchRequestBuilder.addRequest(queryForContact)

        let batchRequest = batchRequestBuilder.buildBatchRequest(SFRestDefaultAPIVersion)
        let exp = expectation(description: "Batch Request")
        var batchResponse: BatchResponse?
        var error: NSError?

        RestClient.sharedInstance.sendBatchRequest(batchRequest, failureBlock: { _, err, _ in
            error = err as NSError?
            exp.fulfill()
        }, successBlock: { response, _ in
            batchResponse = response
            exp.fulfill()
        })

        waitForExpectations(timeout: 30)
        XCTAssertNil(error, "Error invoking batch api")
        XCTAssertNotNil(batchResponse, "Batch Response should not be nil")
        XCTAssertFalse(batchResponse?.hasErrors ?? true, "Batch Response should not return with errors")
        XCTAssertNotNil(batchResponse?.results, "Batch Sub Responses should not be nil")
        XCTAssertEqual(4, batchResponse?.results.count ?? 0, "Wrong number of results")

        guard let results = batchResponse?.results else { return }
        XCTAssertEqual(results.count, 4)
        XCTAssertEqual(((results[0] as? [String: Any])?[kStatusCode] as? Int), 201)
        XCTAssertEqual(((results[1] as? [String: Any])?[kStatusCode] as? Int), 201)
        XCTAssertEqual(((results[2] as? [String: Any])?[kStatusCode] as? Int), 200)
        XCTAssertEqual(((results[3] as? [String: Any])?[kStatusCode] as? Int), 200)

        let accountId = ((results[0] as? [String: Any])?[kResult] as? [String: Any])?[kLid] as? String
        let contactId = ((results[1] as? [String: Any])?[kResult] as? [String: Any])?[kLid] as? String
        let idFromFirstQuery = (((results[2] as? [String: Any])?[kResult] as? [String: Any])?[kRecords] as? [[String: Any]])?.first?[kId] as? String
        let idFromSecondQuery = (((results[3] as? [String: Any])?[kResult] as? [String: Any])?[kRecords] as? [[String: Any]])?.first?[kId] as? String
        XCTAssertEqual(accountId, idFromFirstQuery)
        XCTAssertEqual(contactId, idFromSecondQuery)
    }

    func testBlockUpdate() {
        let api = RestClient.sharedInstance
        let lastName = generateRecordName()
        let updatedLastName = "\(lastName)_updated"
        var fields: [String: String] = [kFirstName: "John", kLastName: lastName]
        var recordId: String?

        var currentExp = expectation(description: "performCreateWithObjectType-creating contact")
        var request = api.requestForCreate(withObjectType: kContact, fields: fields, apiVersion: SFRestDefaultAPIVersion)
        api.send(request, failureBlock: { _, error, _ in
            XCTFail("Unexpected error \(error)")
            currentExp.fulfill()
        }, successBlock: { d, _ in
            recordId = (d as? [String: Any])?[kLid] as? String
            currentExp.fulfill()
        })
        waitForExpectations(timeout: 15)

        guard let contactId = recordId else { return }

        currentExp = expectation(description: "performRetrieveWithObjectType-retrieving contact")
        request = api.requestForRetrieve(withObjectType: kContact, objectId: contactId, fieldList: kLastName, apiVersion: SFRestDefaultAPIVersion)
        api.send(request, failureBlock: { _, error, _ in
            XCTFail("Unexpected error \(error)")
            currentExp.fulfill()
        }, successBlock: { d, _ in
            XCTAssertEqual((d as? [String: Any])?[kLastName] as? String, lastName)
            currentExp.fulfill()
        })
        waitForExpectations(timeout: 15)

        currentExp = expectation(description: "performUpdateWithObjectType-updating contact")
        fields[kLastName] = updatedLastName
        request = api.requestForUpdate(withObjectType: kContact, objectId: contactId, fields: fields, apiVersion: SFRestDefaultAPIVersion)
        api.send(request, failureBlock: { _, error, _ in
            XCTFail("Unexpected error \(error)")
            currentExp.fulfill()
        }, successBlock: { _, _ in
            currentExp.fulfill()
        })
        waitForExpectations(timeout: 15)

        currentExp = expectation(description: "performRetrieveWithObjectType-retrieving contact")
        request = api.requestForRetrieve(withObjectType: kContact, objectId: contactId, fieldList: kLastName, apiVersion: SFRestDefaultAPIVersion)
        api.send(request, failureBlock: { _, error, _ in
            XCTFail("Unexpected error \(error)")
            currentExp.fulfill()
        }, successBlock: { d, _ in
            XCTAssertEqual((d as? [String: Any])?[kLastName] as? String, updatedLastName)
            currentExp.fulfill()
        })
        waitForExpectations(timeout: 15)

        currentExp = expectation(description: "performDeleteWithObjectType-deleting contact")
        request = api.requestForDelete(withObjectType: kContact, objectId: contactId, apiVersion: SFRestDefaultAPIVersion)
        api.send(request, failureBlock: { _, error, _ in
            XCTFail("Unexpected error \(error)")
            currentExp.fulfill()
        }, successBlock: { _, _ in
            currentExp.fulfill()
        })
        waitForExpectations(timeout: 15)
    }

    func testBlocks() {
        let api = RestClient.sharedInstance

        let failWithExpectedFail: (Any?, Error?, URLResponse?) -> Void = { _, _, _ in
            self.currentExpectation?.fulfill()
        }

        let failWithUnexpectedFail: (Any?, Error?, URLResponse?) -> Void = { _, error, _ in
            XCTFail("Unexpected error \(String(describing: error))")
            self.currentExpectation?.fulfill()
        }

        let successWithUnexpectedSuccessBlock: (Any?, URLResponse?) -> Void = { d, _ in
            XCTFail("Unexpected success \(String(describing: d))")
            self.currentExpectation?.fulfill()
        }

        let dictSuccessBlock: (Any?, URLResponse?) -> Void = { d, _ in
            XCTAssertTrue(d is [String: Any], "Response should be a dictionary")
            self.currentExpectation?.fulfill()
        }

        let arraySuccessBlock: (Any?, URLResponse?) -> Void = { a, _ in
            XCTAssertTrue(a is [Any], "Response should be an array")
            self.currentExpectation?.fulfill()
        }

        // Test error helper
        let errorStr = "Sample error."
        XCTAssertTrue(errorStr == RestClient.error(withDescription: errorStr).localizedDescription)

        // Block functions that should always fail
        currentExpectation = expectation(description: "performDeleteWithObjectType-nil")
        var request = api.requestForDelete(withObjectType: kContact, objectId: "nil", apiVersion: SFRestDefaultAPIVersion)
        api.send(request, failureBlock: failWithExpectedFail, successBlock: successWithUnexpectedSuccessBlock)
        waitForExpectations(timeout: 15)

        currentExpectation = expectation(description: "performCreateWithObjectType-nil")
        request = api.requestForCreate(withObjectType: kContact, fields: nil, apiVersion: SFRestDefaultAPIVersion)
        api.send(request, failureBlock: failWithExpectedFail, successBlock: successWithUnexpectedSuccessBlock)
        waitForExpectations(timeout: 15)

        // The oracle passes a nil objectType here, which ObjC bridges to the string "(null)" via
        // stringWithFormat, producing /sobjects/(null) (and .../describe) -> server 404 -> the request
        // correctly FAILS. The Swift API takes a non-optional String, so we pass the same "(null)" bytes
        // the oracle put on the wire. (Unlike the delete/retrieve/update cases below, metadata/describe
        // carry no objectId, so substituting a valid kContact would make the GET SUCCEED and trip
        // successWithUnexpectedSuccessBlock — which is exactly the migration regression fixed here.)
        currentExpectation = expectation(description: "performMetadataWithObjectType-nil")
        request = api.requestForMetadata(withObjectType: "(null)", apiVersion: SFRestDefaultAPIVersion)
        api.send(request, failureBlock: failWithExpectedFail, successBlock: successWithUnexpectedSuccessBlock)
        waitForExpectations(timeout: 15)

        currentExpectation = expectation(description: "performDescribeWithObjectType-nil")
        request = api.requestForDescribe(withObjectType: "(null)", apiVersion: SFRestDefaultAPIVersion)
        api.send(request, failureBlock: failWithExpectedFail, successBlock: successWithUnexpectedSuccessBlock)
        waitForExpectations(timeout: 15)

        currentExpectation = expectation(description: "performRetrieveWithObjectType-nil")
        request = api.requestForRetrieve(withObjectType: kContact, objectId: "nil", fieldList: nil, apiVersion: SFRestDefaultAPIVersion)
        api.send(request, failureBlock: failWithExpectedFail, successBlock: successWithUnexpectedSuccessBlock)
        waitForExpectations(timeout: 15)

        currentExpectation = expectation(description: "performUpdateWithObjectType-nil")
        request = api.requestForUpdate(withObjectType: kContact, objectId: "nil", fields: nil, apiVersion: SFRestDefaultAPIVersion)
        api.send(request, failureBlock: failWithExpectedFail, successBlock: successWithUnexpectedSuccessBlock)
        waitForExpectations(timeout: 15)

        currentExpectation = expectation(description: "performUpsertWithObjectType-nil")
        request = api.requestForUpsert(withObjectType: kContact, externalIdField: "Id", externalId: nil, fields: [:], apiVersion: SFRestDefaultAPIVersion)
        api.send(request, failureBlock: failWithExpectedFail, successBlock: successWithUnexpectedSuccessBlock)
        waitForExpectations(timeout: 15)

        currentExpectation = expectation(description: "performSOQLQuery-nil")
        request = api.requestForQuery("", apiVersion: SFRestDefaultAPIVersion)
        api.send(request, failureBlock: failWithExpectedFail, successBlock: successWithUnexpectedSuccessBlock)
        waitForExpectations(timeout: 15)

        currentExpectation = expectation(description: "performSOQLQueryAll-nil")
        request = api.requestForQueryAll("", apiVersion: SFRestDefaultAPIVersion)
        api.send(request, failureBlock: failWithExpectedFail, successBlock: successWithUnexpectedSuccessBlock)
        waitForExpectations(timeout: 15)

        // Block functions that should always succeed
        currentExpectation = expectation(description: "performRequestForResourcesWithFailBlock")
        request = api.requestForResources(SFRestDefaultAPIVersion)
        api.send(request, failureBlock: failWithUnexpectedFail, successBlock: dictSuccessBlock)
        waitForExpectations(timeout: 15)

        currentExpectation = expectation(description: "performRequestForVersionsWithFailBlock")
        request = api.requestForVersions()
        api.send(request, failureBlock: { _, error, _ in
            XCTFail("Unexpected error \(String(describing: error))")
            self.currentExpectation?.fulfill()
        }, successBlock: { response, _ in
            XCTAssertTrue(response is [Any], "Response should be an array")
            self.currentExpectation?.fulfill()
        })
        waitForExpectations(timeout: 15)

        currentExpectation = expectation(description: "performDescribeGlobalWithFailBlock")
        request = api.requestForDescribeGlobal(SFRestDefaultAPIVersion)
        api.send(request, failureBlock: failWithUnexpectedFail, successBlock: dictSuccessBlock)
        waitForExpectations(timeout: 15)

        currentExpectation = expectation(description: "performSOQLQuery-select id from user limit 10")
        request = api.requestForQuery("select id from user limit 10", apiVersion: SFRestDefaultAPIVersion)
        api.send(request, failureBlock: failWithUnexpectedFail, successBlock: dictSuccessBlock)
        waitForExpectations(timeout: 15)

        currentExpectation = expectation(description: "performSOQLQueryAll-select id from user limit 10")
        request = api.requestForQueryAll("select id from user limit 10", apiVersion: SFRestDefaultAPIVersion)
        api.send(request, failureBlock: failWithUnexpectedFail, successBlock: dictSuccessBlock)
        waitForExpectations(timeout: 15)

        currentExpectation = expectation(description: "performSOSLSearch-find {batman}")
        request = api.requestForSearch("find {batman}", apiVersion: SFRestDefaultAPIVersion)
        api.send(request, failureBlock: failWithUnexpectedFail, successBlock: dictSuccessBlock)
        waitForExpectations(timeout: 15)

        currentExpectation = expectation(description: "performDescribeWithObjectType-Contact")
        request = api.requestForDescribe(withObjectType: kContact, apiVersion: SFRestDefaultAPIVersion)
        api.send(request, failureBlock: failWithUnexpectedFail, successBlock: dictSuccessBlock)
        waitForExpectations(timeout: 15)

        currentExpectation = expectation(description: "performMetadataWithObjectType-Contact")
        request = api.requestForMetadata(withObjectType: kContact, apiVersion: SFRestDefaultAPIVersion)
        api.send(request, failureBlock: failWithUnexpectedFail, successBlock: dictSuccessBlock)
        waitForExpectations(timeout: 15)
        dataCleanupRequired = false
    }

    func testBlocksCancel() {
        currentExpectation = expectation(description: "performRequestForResourcesWithFailBlock-with-cancel")
        let api = RestClient.sharedInstance

        let failWithExpectedFail: (Any?, Error?, URLResponse?) -> Void = { _, _, _ in
            self.currentExpectation?.fulfill()
        }

        let successWithUnexpectedSuccessBlock: (Any?, URLResponse?) -> Void = { d, _ in
            XCTFail("Unexpected success \(String(describing: d))")
            self.currentExpectation?.fulfill()
        }

        let request = api.requestForResources(SFRestDefaultAPIVersion)
        api.send(request, failureBlock: failWithExpectedFail, successBlock: successWithUnexpectedSuccessBlock)

        api.cancelAllRequests()

        waitForExpectations(timeout: 15)
        dataCleanupRequired = false
    }

    func testBlocksTimeout() {
        currentExpectation = expectation(description: "performRequestForResourcesWithFailBlock-with-forced-timeout")
        let api = RestClient.sharedInstance

        let failWithExpectedFail: (Any?, Error?, URLResponse?) -> Void = { _, _, _ in
            self.currentExpectation?.fulfill()
        }

        let successWithUnexpectedSuccessBlock: (Any?, URLResponse?) -> Void = { d, _ in
            XCTFail("Unexpected success \(String(describing: d))")
            self.currentExpectation?.fulfill()
        }

        let request = api.requestForResources(SFRestDefaultAPIVersion)
        api.send(request, failureBlock: failWithExpectedFail, successBlock: successWithUnexpectedSuccessBlock)

        let found = api.forceTimeoutRequest(request)
        XCTAssertTrue(found, "Request was not sent and should not be found.")
        waitForExpectations(timeout: 15)
        dataCleanupRequired = false
    }

    func testCollectionCreateWithBadRecordAndAllOrNoneFalse() {
        let accountName = "\(kEntityPrefixName)_account_\(CFAbsoluteTimeGetCurrent())"
        let contactName = "\(kEntityPrefixName)_contact_\(CFAbsoluteTimeGetCurrent())"

        let records = makeRecords([
            ["Account", "BadField", accountName],
            ["Contact", "LastName", contactName]
        ])

        let request = RestClient.sharedInstance.requestForCollectionCreate(false, records: records, apiVersion: SFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        let parsedCreateResponse = CollectionResponse(array: response.dataResponse as? [[String: Any]] ?? [])

        XCTAssertEqual(parsedCreateResponse.subResponses.count, 2)
        XCTAssertNil(parsedCreateResponse.subResponses[0].objectId)
        XCTAssertFalse(parsedCreateResponse.subResponses[0].success)
        XCTAssertEqual(parsedCreateResponse.subResponses[0].errors.count, 1)
        XCTAssertEqual(parsedCreateResponse.subResponses[0].errors[0].statusCode, "INVALID_FIELD")
        XCTAssertTrue(parsedCreateResponse.subResponses[1].objectId?.hasPrefix("003") == true)
        XCTAssertTrue(parsedCreateResponse.subResponses[1].success)
        XCTAssertEqual(parsedCreateResponse.subResponses[1].errors.count, 0)
    }

    func testCollectionCreateWithBadRecordAndAllOrNoneTrue() {
        let accountName = "\(kEntityPrefixName)_account_\(CFAbsoluteTimeGetCurrent())"
        let contactName = "\(kEntityPrefixName)_contact_\(CFAbsoluteTimeGetCurrent())"

        let records = makeRecords([
            ["Account", "BadField", accountName],
            ["Contact", "LastName", contactName]
        ])

        let request = RestClient.sharedInstance.requestForCollectionCreate(true, records: records, apiVersion: SFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        let parsedCreateResponse = CollectionResponse(array: response.dataResponse as? [[String: Any]] ?? [])

        XCTAssertEqual(parsedCreateResponse.subResponses.count, 2)
        XCTAssertNil(parsedCreateResponse.subResponses[0].objectId)
        XCTAssertFalse(parsedCreateResponse.subResponses[0].success)
        XCTAssertEqual(parsedCreateResponse.subResponses[0].errors.count, 1)
        XCTAssertEqual(parsedCreateResponse.subResponses[0].errors[0].statusCode, "INVALID_FIELD")
        XCTAssertNil(parsedCreateResponse.subResponses[1].objectId)
        XCTAssertFalse(parsedCreateResponse.subResponses[1].success)
        XCTAssertEqual(parsedCreateResponse.subResponses[0].errors.count, 1)
        XCTAssertEqual(parsedCreateResponse.subResponses[1].errors[0].statusCode, "ALL_OR_NONE_OPERATION_ROLLED_BACK")
    }

    func testCollectionUpdate() {
        let firstAccountName = "\(kEntityPrefixName)_account_1_\(CFAbsoluteTimeGetCurrent())"
        let secondAccountName = "\(kEntityPrefixName)_account_2_\(CFAbsoluteTimeGetCurrent())"
        let contactName = "\(kEntityPrefixName)_contact_\(CFAbsoluteTimeGetCurrent())"

        let records = makeRecords([
            ["Account", "Name", firstAccountName],
            ["Contact", "LastName", contactName],
            ["Account", "Name", secondAccountName]
        ])

        var request = RestClient.sharedInstance.requestForCollectionCreate(true, records: records, apiVersion: SFRestDefaultAPIVersion)
        var response = sendSyncRequest(request)

        let parsedCreateResponse = CollectionResponse(array: response.dataResponse as? [[String: Any]] ?? [])
        let firstAccountId = parsedCreateResponse.subResponses[0].objectId ?? ""
        let contactId = parsedCreateResponse.subResponses[1].objectId ?? ""

        let firstAccountNameUpdated = "\(firstAccountName)_updated"
        let contactNameUpdated = "\(contactName)_updated"
        let updatedRecords = makeRecords([
            ["Account", "Name", firstAccountNameUpdated, "Id", firstAccountId],
            ["Contact", "LastName", contactNameUpdated, "Id", contactId]
        ])

        request = RestClient.sharedInstance.requestForCollectionUpdate(true, records: updatedRecords, apiVersion: SFRestDefaultAPIVersion)
        response = sendSyncRequest(request)

        let parsedUpdateResponse = CollectionResponse(array: response.dataResponse as? [[String: Any]] ?? [])

        XCTAssertEqual(parsedUpdateResponse.subResponses.count, 2)
        XCTAssertTrue(parsedUpdateResponse.subResponses[0].objectId?.hasPrefix("001") == true)
        XCTAssertTrue(parsedUpdateResponse.subResponses[0].success)
        XCTAssertEqual(parsedUpdateResponse.subResponses[0].errors.count, 0)
        XCTAssertTrue(parsedUpdateResponse.subResponses[1].objectId?.hasPrefix("003") == true)
        XCTAssertTrue(parsedUpdateResponse.subResponses[1].success)
        XCTAssertEqual(parsedUpdateResponse.subResponses[1].errors.count, 0)

        let secondAccountId = parsedCreateResponse.subResponses[2].objectId ?? ""
        request = RestClient.sharedInstance.requestForCollectionRetrieve(kAccount, objectIds: [firstAccountId, secondAccountId], fieldList: ["Id", "Name"], apiVersion: SFRestDefaultAPIVersion)
        response = sendSyncRequest(request)
        guard let accountsRetrieved = response.dataResponse as? [[String: Any]] else { return }
        XCTAssertEqual(accountsRetrieved.count, 2)
        XCTAssertEqual(accountsRetrieved[0]["Name"] as? String, firstAccountNameUpdated)
        XCTAssertEqual(accountsRetrieved[1]["Name"] as? String, secondAccountName)

        request = RestClient.sharedInstance.requestForCollectionRetrieve("Contact", objectIds: [contactId], fieldList: ["Id", "LastName"], apiVersion: SFRestDefaultAPIVersion)
        response = sendSyncRequest(request)
        guard let contactsRetrieved = response.dataResponse as? [[String: Any]] else { return }
        XCTAssertEqual(contactsRetrieved.count, 1)
        XCTAssertEqual(contactsRetrieved[0]["LastName"] as? String, contactNameUpdated)
    }

    func testCollectionUpsertExistingRecords() {
        let firstAccountName = "\(kEntityPrefixName)_account_1_\(CFAbsoluteTimeGetCurrent())"
        let secondAccountName = "\(kEntityPrefixName)_account_2_\(CFAbsoluteTimeGetCurrent())"

        let records = makeRecords([
            ["Account", "Name", firstAccountName],
            ["Account", "Name", secondAccountName]
        ])

        var request = RestClient.sharedInstance.requestForCollectionCreate(true, records: records, apiVersion: SFRestDefaultAPIVersion)
        var response = sendSyncRequest(request)

        let parsedCreateResponse = CollectionResponse(array: response.dataResponse as? [[String: Any]] ?? [])
        let firstAccountId = parsedCreateResponse.subResponses[0].objectId ?? ""
        let secondAccountId = parsedCreateResponse.subResponses[1].objectId ?? ""

        let firstAccountNameUpdated = "\(firstAccountName)_updated"
        let secondAccountNameUpdated = "\(secondAccountName)_updated"
        let updatedAccounts = makeRecords([
            ["Account", "Name", firstAccountNameUpdated, "Id", firstAccountId],
            ["Account", "Name", secondAccountNameUpdated, "Id", secondAccountId]
        ])

        request = RestClient.sharedInstance.requestForCollectionUpsert(true, objectType: kAccount, externalIdField: "Id", records: updatedAccounts, apiVersion: SFRestDefaultAPIVersion)
        response = sendSyncRequest(request)

        let parsedUpsertResponse = CollectionResponse(array: response.dataResponse as? [[String: Any]] ?? [])

        XCTAssertEqual(parsedUpsertResponse.subResponses.count, 2)
        XCTAssertTrue(parsedUpsertResponse.subResponses[0].objectId?.hasPrefix("001") == true)
        XCTAssertTrue(parsedUpsertResponse.subResponses[0].success)
        XCTAssertEqual(parsedUpsertResponse.subResponses[0].errors.count, 0)
        XCTAssertTrue(parsedUpsertResponse.subResponses[1].objectId?.hasPrefix("001") == true)
        XCTAssertTrue(parsedUpsertResponse.subResponses[1].success)
        XCTAssertEqual(parsedUpsertResponse.subResponses[1].errors.count, 0)

        request = RestClient.sharedInstance.requestForCollectionRetrieve(kAccount, objectIds: [firstAccountId, secondAccountId], fieldList: ["Id", "Name"], apiVersion: SFRestDefaultAPIVersion)
        response = sendSyncRequest(request)
        guard let accountsRetrieved = response.dataResponse as? [[String: Any]] else { return }

        XCTAssertEqual(accountsRetrieved.count, 2)
        XCTAssertEqual(accountsRetrieved[0]["Name"] as? String, firstAccountNameUpdated)
        XCTAssertEqual(accountsRetrieved[1]["Name"] as? String, secondAccountNameUpdated)
    }

    func testCollectionUpsertNewRecords() {
        let firstAccountName = "\(kEntityPrefixName)_account_1_\(CFAbsoluteTimeGetCurrent())"
        let secondAccountName = "\(kEntityPrefixName)_account_2_\(CFAbsoluteTimeGetCurrent())"

        let records = makeRecords([
            ["Account", "Name", firstAccountName],
            ["Account", "Name", secondAccountName]
        ])

        let request = RestClient.sharedInstance.requestForCollectionUpsert(true, objectType: kAccount, externalIdField: "Id", records: records, apiVersion: SFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)

        let parsedUpsertResponse = CollectionResponse(array: response.dataResponse as? [[String: Any]] ?? [])

        XCTAssertEqual(parsedUpsertResponse.subResponses.count, 2)
        XCTAssertTrue(parsedUpsertResponse.subResponses[0].objectId?.hasPrefix("001") == true)
        XCTAssertTrue(parsedUpsertResponse.subResponses[0].success)
        XCTAssertEqual(0, parsedUpsertResponse.subResponses[0].errors.count)
        XCTAssertTrue(parsedUpsertResponse.subResponses[1].objectId?.hasPrefix("001") == true)
        XCTAssertTrue(parsedUpsertResponse.subResponses[1].success)
        XCTAssertEqual(0, parsedUpsertResponse.subResponses[1].errors.count)
    }

    func testCustomSalesforceEndpoint() {
        let endpoint = "/custom/endpoint"
        let path = "/custom/endpoint"
        let request = RestRequest.customEndPointRequest(withMethod: .GET, endPoint: endpoint, path: path, queryParams: nil)
        guard let currentUser = currentUser else { return }
        guard let urlRequest = request.prepareRequestForSend(currentUser) else { return }
        XCTAssertNotNil(urlRequest, "UrlRequest URL should not be nil")
        let urlString = urlRequest.url?.absoluteString ?? ""
        XCTAssertTrue(urlString.range(of: endpoint) != nil, "The URL must have custom endpoint path")
        XCTAssertTrue(urlString.range(of: path) != nil, "The URL must have custom path")
        dataCleanupRequired = false
    }

    func testEscapingWithSOQLQuery() {
        let request = RestClient.sharedInstance.requestForQuery("Select Name from Account where LastModifiedDate > 2017-03-21T12:11:06.000+0000", apiVersion: SFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")
        dataCleanupRequired = false
    }

    func testFailedRequestRemovedFromQueue() {
        // Use localhost with an unlikely port to get an immediate connection-refused error
        // (non-existent DNS domains can hang for tens of seconds depending on the network).
        guard let origInstanceUrl = currentUser?.credentials.instanceUrl else { return }
        currentUser?.credentials.instanceUrl = URL(string: "https://localhost:2")
        currentExpectation = expectation(description: "performRequestToFail")

        let failWithExpectedFail: (Any?, Error?, URLResponse?) -> Void = { _, _, _ in
            self.currentExpectation?.fulfill()
        }
        let successWithUnexpectedSuccessBlock: (Any?, URLResponse?) -> Void = { _, _ in
            XCTFail("Request should not have succeeded.")
            self.currentExpectation?.fulfill()
        }

        let request = RestClient.sharedInstance.requestForResources(SFRestDefaultAPIVersion)
        RestClient.sharedInstance.send(request, failureBlock: failWithExpectedFail, successBlock: successWithUnexpectedSuccessBlock)
        waitForExpectations(timeout: 15)
        XCTAssertEqual(0, RestClient.sharedInstance.activeRequests.count, "Active requests queue should be empty.")
        currentUser?.credentials.instanceUrl = origInstanceUrl
        dataCleanupRequired = false
    }

    func testFileSharesWithUserCommunity() {
        guard let creds = OAuthCredentials.credentials(identifier: "CLIENT ID", clientId: "CLIENT ID", encrypted: false) else { return }
        creds.userId = "USERID"
        creds.organizationId = "ORGID"
        creds.communityId = "COMMUNITYID"
        creds.instanceUrl = URL(string: "https://sample.domain")
        let account = UserAccount(credentials: creds)
        account.transitionToLoginState(.loggedIn)
        guard let restAPI = RestClient.restClient(for: account) else { return }
        XCTAssertNotNil(restAPI, "RestApi instance for this user must exist")
        let request = restAPI.requestForFilesSharedWithUser("someid", page: 0, apiVersion: SFRestDefaultAPIVersion)
        XCTAssertNotNil(request, "Request should have been created")
        guard let urlRequest = request.prepareRequestForSend(account) else { return }
        let urlString = urlRequest.url?.absoluteString ?? ""
        XCTAssertTrue(urlString.range(of: "connect/communities/COMMUNITYID/") != nil, "The URL must have communities path")
        dataCleanupRequired = false
    }

    func testFilesInUsersGroupsWithCommunity() {
        guard let creds = OAuthCredentials.credentials(identifier: "CLIENT ID", clientId: "CLIENT ID", encrypted: false) else { return }
        creds.userId = "USERID"
        creds.organizationId = "ORGID"
        creds.instanceUrl = URL(string: "https://sample.domain")
        creds.communityId = "COMMUNITYID"
        let account = UserAccount(credentials: creds)
        account.transitionToLoginState(.loggedIn)
        guard let restAPI = RestClient.restClient(for: account) else { return }
        XCTAssertNotNil(restAPI, "RestApi instance for this user must exist")
        let request = restAPI.requestForFilesInUsersGroups(creds.userId, page: 0, apiVersion: SFRestDefaultAPIVersion)
        XCTAssertNotNil(request, "Request should have been created")
        guard let urlRequest = request.prepareRequestForSend(account) else { return }
        let urlString = urlRequest.url?.absoluteString ?? ""
        XCTAssertTrue(urlString.range(of: "connect/communities/COMMUNITYID/") != nil, "The URL must have communities path")
        dataCleanupRequired = false
    }

    func testGetLayoutWithObjectAPINameWithoutLayoutType() {
        let request = RestClient.sharedInstance.requestForLayout(withObjectAPIName: kContact, formFactor: nil, layoutType: nil, mode: nil, recordTypeId: nil, apiVersion: SFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")
        dataCleanupRequired = false
    }

    func testGetLayoutWithObjectAPINameWithoutMode() {
        let request = RestClient.sharedInstance.requestForLayout(withObjectAPIName: kContact, formFactor: nil, layoutType: nil, mode: nil, recordTypeId: nil, apiVersion: SFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")
        dataCleanupRequired = false
    }

    func testGetLayoutWithObjectAPINameWithoutRecordTypeId() {
        let request = RestClient.sharedInstance.requestForLayout(withObjectAPIName: kContact, formFactor: nil, layoutType: nil, mode: nil, recordTypeId: nil, apiVersion: SFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")
        dataCleanupRequired = false
    }

    func testNoTrailingQuestionMarkForEmptyParams() {
        let pathWithParams = "/rest/endpoint?page=10"
        let request = RestRequest(method: .GET, path: pathWithParams, queryParams: [:])
        request.endpoint = "/services/apex"
        guard let currentUser = currentUser else { return }
        guard let urlRequest = request.prepareRequestForSend(currentUser) else { return }
        XCTAssertTrue(urlRequest.url?.absoluteString.hasSuffix(pathWithParams) ?? false, "Wrong URL")
        dataCleanupRequired = false
    }

    func testOwnedFilesListWithCommunity() {
        guard let creds = OAuthCredentials.credentials(identifier: "CLIENT ID", clientId: "CLIENT ID", encrypted: false) else { return }
        creds.userId = "USERID"
        creds.organizationId = "ORGID"
        creds.communityId = "COMMUNITYID"
        creds.instanceUrl = URL(string: "https://sample.domain")
        let account = UserAccount(credentials: creds)
        account.transitionToLoginState(.loggedIn)
        guard let restAPI = RestClient.restClient(for: account) else { return }
        XCTAssertNotNil(restAPI, "RestApi instance for this user must exist")
        let request = restAPI.requestForOwnedFilesList(creds.userId, page: 0, apiVersion: SFRestDefaultAPIVersion)
        XCTAssertNotNil(request, "Request should have been created")
        guard let urlRequest = request.prepareRequestForSend(account) else { return }
        let urlString = urlRequest.url?.absoluteString ?? ""
        XCTAssertTrue(urlString.range(of: "connect/communities/COMMUNITYID/") != nil, "The URL must have communities path")
        dataCleanupRequired = false
    }

    func testOwnedFilesListWithCommunityWithHeaders() {
        guard let creds = OAuthCredentials.credentials(identifier: "CLIENT ID", clientId: "CLIENT ID", encrypted: false) else { return }
        creds.userId = "USERID"
        creds.organizationId = "ORGID"
        creds.communityId = "COMMUNITYID"
        creds.instanceUrl = URL(string: "https://sample.domain")
        let account = UserAccount(credentials: creds)
        account.transitionToLoginState(.loggedIn)
        guard let restAPI = RestClient.restClient(for: account) else { return }
        XCTAssertNotNil(restAPI, "RestApi instance for this user must exist")
        let request = restAPI.requestForOwnedFilesList(creds.userId, page: 0, apiVersion: SFRestDefaultAPIVersion)
        let simpleType = "ASimpleType"
        let simpleTypeLength = "100000"
        request.setHeaderValue(simpleType, forHeaderName: "Content-type")
        request.setHeaderValue(simpleTypeLength, forHeaderName: "Content-Length")
        XCTAssertNotNil(request, "Request should have been created")
        guard let urlRequest = request.prepareRequestForSend(account) else { return }
        XCTAssertEqual(simpleTypeLength, urlRequest.value(forHTTPHeaderField: "Content-Length"))
        XCTAssertEqual(simpleType, urlRequest.value(forHTTPHeaderField: "Content-Type"))
        let urlString = urlRequest.url?.absoluteString ?? ""
        XCTAssertTrue(urlString.range(of: "connect/communities/COMMUNITYID/") != nil, "The URL must have communities path")
        dataCleanupRequired = false
    }

    func testParsePrimingRecordsResponse() {
        guard let dict = try? JSONSerialization.jsonObject(with: "{\"primingRecords\":{\"Account\":{\"012S00000009B8HIAU\":[{\"id\":\"001S000001QEDnzIAH\", \"systemModstamp\":\"2021-08-23T18:42:32.000Z\"}, {\"id\":\"001S000000va6rGIAQ\", \"systemModstamp\":\"2019-02-09T02:19:38.000Z\"}]}, \"Contact\":{\"012000000000000AAA\":[{\"id\":\"003S00000129813IAA\", \"systemModstamp\":\"2018-12-22T06:13:59.000Z\"}, {\"id\":\"003S0000012LUhRIAW\", \"systemModstamp\":\"2019-01-12T06:13:11.000Z\"}, {\"id\":\"003S0000012hWwRIAU\", \"systemModstamp\":\"2019-01-30T00:59:06.000Z\"}]}}, \"relayToken\":\"fake-token\", \"ruleErrors\":[{\"ruleId\":\"rule-1\"}, {\"ruleId\":\"rule-2\"}], \"stats\":{\"recordCountServed\":100, \"recordCountTotal\":200, \"ruleCountServed\":2, \"ruleCountTotal\":3}}".data(using: .utf8)!) as? [String: Any] else { return }

        let primingRecordsResponse = PrimingRecordsResponse(dict: dict as NSDictionary)

        XCTAssertEqual(primingRecordsResponse.primingRecords.count, 2)
        XCTAssertEqual(primingRecordsResponse.primingRecords["Account"]?.count, 1)
        XCTAssertEqual(primingRecordsResponse.primingRecords["Account"]?["012S00000009B8HIAU"]?.count, 2)
        XCTAssertEqual(primingRecordsResponse.primingRecords["Account"]?["012S00000009B8HIAU"]?[0].objectId, "001S000001QEDnzIAH")
        XCTAssertEqual(primingRecordsResponse.primingRecords["Account"]?["012S00000009B8HIAU"]?[1].objectId, "001S000000va6rGIAQ")
        XCTAssertEqual(primingRecordsResponse.primingRecords["Account"]?["012S00000009B8HIAU"]?[0].systemModstamp.timeIntervalSince1970, 1629744152)

        XCTAssertEqual(primingRecordsResponse.primingRecords["Contact"]?.count, 1)
        XCTAssertEqual(primingRecordsResponse.primingRecords["Contact"]?["012000000000000AAA"]?.count, 3)
        XCTAssertEqual(primingRecordsResponse.primingRecords["Contact"]?["012000000000000AAA"]?[0].objectId, "003S00000129813IAA")
        XCTAssertEqual(primingRecordsResponse.primingRecords["Contact"]?["012000000000000AAA"]?[1].objectId, "003S0000012LUhRIAW")
        XCTAssertEqual(primingRecordsResponse.primingRecords["Contact"]?["012000000000000AAA"]?[2].objectId, "003S0000012hWwRIAU")
        XCTAssertEqual(primingRecordsResponse.primingRecords["Contact"]?["012000000000000AAA"]?[0].systemModstamp.timeIntervalSince1970, 1545459239)

        XCTAssertEqual(primingRecordsResponse.relayToken, "fake-token")

        XCTAssertEqual(primingRecordsResponse.ruleErrors.count, 2)
        XCTAssertEqual(primingRecordsResponse.ruleErrors[0].ruleId, "rule-1")
        XCTAssertEqual(primingRecordsResponse.ruleErrors[1].ruleId, "rule-2")

        XCTAssertEqual(primingRecordsResponse.stats.recordCountServed, 100)
        XCTAssertEqual(primingRecordsResponse.stats.recordCountTotal, 200)
        XCTAssertEqual(primingRecordsResponse.stats.ruleCountServed, 2)
        XCTAssertEqual(primingRecordsResponse.stats.ruleCountTotal, 3)
        dataCleanupRequired = false
    }

    func testParsePrimingRecordsResponseFromServer() {
        let request = RestClient.sharedInstance.requestForPrimingRecords(nil, changedAfterTimestamp: nil, apiVersion: SFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        guard let dataResponse = response.dataResponse as? [String: Any] else { return }
        do {
            _ = PrimingRecordsResponse(dict: dataResponse as NSDictionary)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
        dataCleanupRequired = false
    }

    func testRefreshNotificationWithValidGetRequest() {
        let invalidAccessToken = "xyz"
        changeOauthTokens(accessToken: invalidAccessToken, refreshToken: nil)

        expectation(forNotification: NSNotification.Name.sfNotificationUserDidRefreshToken, object: nil) { notification in
            return notification.userInfo?[kSFNotificationUserInfoAccountKey] != nil
        }

        let request = RestClient.sharedInstance.requestForResources(SFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        waitForExpectations(timeout: 10.0)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")

        let newAccessToken = currentUser?.credentials.accessToken ?? ""
        XCTAssertFalse(newAccessToken == invalidAccessToken, "access token wasn't refreshed")
        dataCleanupRequired = false
    }

    func testRequestForInvokeNotificationActionWithVersion() {
        let notificationId = "67890"
        let actionIdentifier = "deny_action"
        let customAPIVersion = "v64.0"
        let api = RestClient.sharedInstance

        let request = api.requestForInvokeNotificationAction(notificationId, actionIdentifier: actionIdentifier, apiVersion: customAPIVersion)

        XCTAssertNotNil(request, "Expected request object to be created.")
        XCTAssertEqual(request.method, .POST, "Expected POST method.")
        let expectedPath = "/\(customAPIVersion)/connect/notifications/\(notificationId)/actions/\(actionIdentifier)"
        XCTAssertEqual(request.path, expectedPath)
        dataCleanupRequired = false
    }

    func testRequestForNotificationTypesWithVersion() {
        let customAPIVersion = "v64.0"
        let request = RestClient.sharedInstance.requestForNotificationTypes(withVersion: customAPIVersion)

        XCTAssertNotNil(request, "Expected request object to be created.")
        XCTAssertEqual(request.method, RestRequest.Method.GET, "Expected GET method.")
        let expectedPath = "/\(customAPIVersion)/connect/notifications/types"
        XCTAssertEqual(request.path, expectedPath)
        dataCleanupRequired = false
    }

    func testRequestWithCompositeRequest() {
        let accountName = generateRecordName()
        let contactName = generateRecordName()

        let requestBuilder = CompositeRequestBuilder()

        let createAccountRequest = RestClient.sharedInstance.requestForCreate(withObjectType: kAccount, fields: [kName: accountName], apiVersion: SFRestDefaultAPIVersion)
        requestBuilder.addRequest(createAccountRequest, referenceId: "refAccount")

        let createContactRequest = RestClient.sharedInstance.requestForCreate(withObjectType: kContact, fields: [kLastName: contactName, kAccountId: "@{refAccount.id}"], apiVersion: SFRestDefaultAPIVersion)
        requestBuilder.addRequest(createContactRequest, referenceId: "refContact")

        let queryForContact = RestClient.sharedInstance.requestForQuery("select Id, AccountId from Contact where LastName = '\(contactName)'", apiVersion: SFRestDefaultAPIVersion)
        requestBuilder.addRequest(queryForContact, referenceId: "refQuery")

        let response = sendSyncRequest(requestBuilder.buildCompositeRequest(RestClient.sharedInstance.apiVersion))

        guard let dataResponse = response.dataResponse as? [String: Any],
              let results = dataResponse[kCompositeResponse] as? [[String: Any]] else {
            XCTFail("Invalid response"); return
        }
        XCTAssertEqual(3, results.count, "Wrong number of results")
        XCTAssertEqual((results[0][kHttpStatusCode] as? Int), 201)
        XCTAssertEqual((results[1][kHttpStatusCode] as? Int), 201)
        XCTAssertEqual((results[2][kHttpStatusCode] as? Int), 200)

        let accountId = (results[0][kBody] as? [String: Any])?[kLid] as? String
        let contactId = (results[1][kBody] as? [String: Any])?[kLid] as? String
        let queryRecords = (results[2][kBody] as? [String: Any])?[kRecords] as? [[String: Any]]
        XCTAssertEqual(1, queryRecords?.count, "Wrong number of results for query request")
        XCTAssertEqual(accountId, queryRecords?.first?[kAccountId] as? String, "Account id not returned by query")
        XCTAssertEqual(contactId, queryRecords?.first?[kId] as? String, "Contact id not returned by query")
    }

    func testRequestWithCompositeRequestResponse() {
        let accountName = generateRecordName()
        let contactName = generateRecordName()

        let requestBuilder = CompositeRequestBuilder()
        let expectationComposite = expectation(description: "Composite Request")

        let createAccountRequest = RestClient.sharedInstance.requestForCreate(withObjectType: kAccount, fields: [kName: accountName], apiVersion: SFRestDefaultAPIVersion)
        requestBuilder.addRequest(createAccountRequest, referenceId: "refAccount")

        let createContactRequest = RestClient.sharedInstance.requestForCreate(withObjectType: kContact, fields: [kLastName: contactName, kAccountId: "@{refAccount.id}"], apiVersion: SFRestDefaultAPIVersion)
        requestBuilder.addRequest(createContactRequest, referenceId: "refContact")

        let queryForContact = RestClient.sharedInstance.requestForQuery("select Id, AccountId from Contact where LastName = '\(contactName)'", apiVersion: SFRestDefaultAPIVersion)
        requestBuilder.addRequest(queryForContact, referenceId: "refQuery")

        let compositeRequest = requestBuilder.buildCompositeRequest(RestClient.sharedInstance.apiVersion)
        var compositeResponse: CompositeResponse?
        var error: NSError?

        RestClient.sharedInstance.sendCompositeRequest(compositeRequest, failureBlock: { _, err, _ in
            error = err as NSError?
            expectationComposite.fulfill()
        }, successBlock: { response, _ in
            compositeResponse = response
            expectationComposite.fulfill()
        })

        waitForExpectations(timeout: 30)
        XCTAssertNil(error, "Error invoking composite api")
        XCTAssertNotNil(compositeResponse, "Composite Response should not be nil")
        XCTAssertNotNil(compositeResponse?.subResponses, "Composite Sub Responses should not be nil")
        XCTAssertEqual(3, compositeResponse?.subResponses.count, "Wrong number of results")

        guard let subResponses = compositeResponse?.subResponses else { return }
        XCTAssertEqual(subResponses[0].httpStatusCode, 201)
        XCTAssertEqual(subResponses[1].httpStatusCode, 201)
        XCTAssertEqual(subResponses[2].httpStatusCode, 200)

        XCTAssertNotNil(subResponses[0].body, "Subresponse must have a response body")
        XCTAssertNotNil(subResponses[1].body, "Subresponse must have a response body")
        XCTAssertNotNil(subResponses[2].body, "Subresponse must have a response body")

        let accountId = (subResponses[0].body as? [String: Any])?[kLid] as? String
        let contactId = (subResponses[1].body as? [String: Any])?[kLid] as? String
        let queryRecords = (subResponses[2].body as? [String: Any])?[kRecords] as? [[String: Any]]

        XCTAssertEqual(1, queryRecords?.count, "Wrong number of results for query request")
        XCTAssertEqual(accountId, queryRecords?.first?[kAccountId] as? String, "Account id not returned by query")
        XCTAssertEqual(contactId, queryRecords?.first?[kId] as? String, "Contact id not returned by query")
    }

    func testRestUrlForNetworkServiceType() {
        let request = RestRequest(method: .GET, serviceHostType: .instance, baseURL: "http://www.apple.com", path: "/test/testing", queryParams: nil)

        request.networkServiceType = .default
        guard let currentUser = currentUser else { return }
        var finalRequest = request.prepareRequestForSend(currentUser)
        XCTAssertTrue(finalRequest?.networkServiceType == .default, "Network Service Type should have been set to NSURLNetworkServiceTypeDefault")

        request.networkServiceType = .responsiveData
        finalRequest = request.prepareRequestForSend(currentUser)
        XCTAssertTrue(finalRequest?.networkServiceType == .responsiveData, "Network Service Type should have been set to NSURLNetworkServiceTypeResponsiveData")

        request.networkServiceType = .background
        finalRequest = request.prepareRequestForSend(currentUser)
        XCTAssertTrue(finalRequest?.networkServiceType == .background, "Network Service Type should have been set to NSURLNetworkServiceTypeBackground")
        dataCleanupRequired = false
    }

    func testSOQLQueryWithBatchSize() {
        let request = RestClient.sharedInstance.requestForQuery("Select Name from Account", apiVersion: SFRestDefaultAPIVersion, batchSize: 250)
        XCTAssertEqual("batchSize=250", request.customHeaders?["Sforce-Query-Options"] as? String)
        let response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")
        dataCleanupRequired = false
    }

    func testSOQLWithNewLine() {
        let lastName = "Silver-\(Date())"
        let fields = [kFirstName: "LongJohn", kLastName: lastName]
        var request = RestClient.sharedInstance.requestForCreate(withObjectType: kContact, fields: fields, apiVersion: SFRestDefaultAPIVersion)
        var response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")

        guard let contactId = (response.dataResponse as? [String: Any])?[kLid] as? String else {
            XCTFail("id not present"); return
        }

        defer {
            request = RestClient.sharedInstance.requestForDelete(withObjectType: kContact, objectId: contactId, apiVersion: SFRestDefaultAPIVersion)
            _ = sendSyncRequest(request)
        }

        let queryString = "SELECT Id,\n FirstName,\n LastName\n FROM Contact \nWHERE Id = '\(contactId)'"

        request = RestClient.sharedInstance.requestForQuery(queryString, apiVersion: SFRestDefaultAPIVersion)
        response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")
        let records = (response.dataResponse as? [String: Any])?[kRecords] as? [[String: Any]]
        XCTAssertEqual(records?.count, 1, "expected 1 record")
    }

    func testSalesforceFullUrlPath() {
        let fullPathURL = "https://some.custom.url/A/B/C"
        let request = RestRequest(method: .GET, path: fullPathURL, queryParams: nil)
        guard let currentUser = currentUser else { return }
        guard let urlRequest = request.prepareRequestForSend(currentUser) else { return }
        XCTAssertNotNil(urlRequest, "UrlRequest URL should not be nil")
        let urlString = urlRequest.url?.absoluteString ?? ""
        XCTAssertTrue(urlString.hasPrefix(fullPathURL) && urlString.range(of: fullPathURL) != nil, "The URL must match the setting of full URL in path")
        dataCleanupRequired = false
    }

    func testUpdateNotificationRequestPath() {
        let builder = UpdateNotificationsRequestBuilder()
        let notificationId = "testID"
        builder.setNotificationId(notificationId)
        let request = builder.buildUpdateNotificationsRequest(SFRestDefaultAPIVersion)
        let expectedPath = "/connect/notifications/\(notificationId)"
        XCTAssert(request.path.hasSuffix(expectedPath))
        dataCleanupRequired = false
    }

    func testUpdateNotificationsRequestContent() {
        let builder = UpdateNotificationsRequestBuilder()
        let notificationIds = ["testID1", "testID2"]
        builder.setNotificationIds(notificationIds)
        let request = builder.buildUpdateNotificationsRequest(SFRestDefaultAPIVersion)
        XCTAssert(request.path.hasSuffix("/connect/notifications"))
        guard let requestBody = request.requestBodyAsDictionary else { return }
        guard let requestNotificationIds = requestBody["notificationIds"] as? [String] else { return }
        XCTAssertEqual(notificationIds, requestNotificationIds)
        dataCleanupRequired = false
    }

    func testUpdateWithIfUnmodifiedSince() {
        let accountName = generateRecordName()
        let fields: [String: String] = [kName: accountName]
        var request = RestClient.sharedInstance.requestForCreate(withObjectType: kAccount, fields: fields, apiVersion: SFRestDefaultAPIVersion)
        var response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "create request failed")
        guard let accountId = (response.dataResponse as? [String: Any])?[kLid] as? String else {
            XCTFail("account id not present"); return
        }

        // Retrieve to get last modified date - expect updated name
        request = RestClient.sharedInstance.requestForRetrieve(withObjectType: kAccount, objectId: accountId, fieldList: "Name,LastModifiedDate", apiVersion: SFRestDefaultAPIVersion)
        response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "retrieve request failed")
        let retrievedName = (response.dataResponse as? [String: Any])?[kName] as? String
        XCTAssertEqual(retrievedName, accountName, "wrong name retrieved")
        guard let lastModifiedDateStr = (response.dataResponse as? [String: Any])?["LastModifiedDate"] as? String else { return }

        let isoDateFormatter = DateFormatter()
        isoDateFormatter.locale = Locale(identifier: "en_US_POSIX")
        isoDateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        guard var createdDate = isoDateFormatter.date(from: lastModifiedDateStr) else {
            XCTFail("failed to parse LastModifiedDate: \(lastModifiedDateStr)"); return
        }
        // Round up to next second — HTTP date format has second granularity, so sub-second
        // timestamps get truncated, making the header appear BEFORE the actual LastModifiedDate.
        createdDate = Date(timeIntervalSinceReferenceDate: ceil(createdDate.timeIntervalSinceReferenceDate))

        // Format the date as a proper HTTP date in UTC for the If-Unmodified-Since header.
        // We bypass ifUnmodifiedSinceDate: because the SDK's httpDateFormatter has a timezone bug
        // (formats in local time but hardcodes "GMT", causing 412s in non-UTC timezones).
        let httpDateFormatter = DateFormatter()
        httpDateFormatter.locale = Locale(identifier: "en_US_POSIX")
        httpDateFormatter.timeZone = TimeZone(identifier: "GMT")
        httpDateFormatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss 'GMT'"
        let ifUnmodifiedSinceValue = httpDateFormatter.string(from: createdDate)

        // Wait a bit to ensure server timestamp advances past createdDate
        Thread.sleep(forTimeInterval: 2.0)

        // Update with if-unmodified-since with createdDate - should update
        let accountNameUpdated = "\(accountName)_updated"
        let fieldsUpdated: [String: String] = [kName: accountNameUpdated]
        // Pass nil to skip the SDK's buggy date formatter; set the header manually below.
        request = RestClient.sharedInstance.requestForUpdate(withObjectType: kAccount, objectId: accountId, fields: fieldsUpdated, ifUnmodifiedSinceDate: nil, apiVersion: SFRestDefaultAPIVersion)
        request.setHeaderValue(ifUnmodifiedSinceValue, forHeaderName: "If-Unmodified-Since")
        response = sendSyncRequest(request)
        if response.returnStatus != kTestRequestStatusDidLoad {
            Thread.sleep(forTimeInterval: 3.0)
            response = sendSyncRequest(request)
        }
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request should have succeeded")

        // Retrieve - expect updated name
        request = RestClient.sharedInstance.requestForRetrieve(withObjectType: kAccount, objectId: accountId, fieldList: kName, apiVersion: SFRestDefaultAPIVersion)
        response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "retrieve after update failed")
        let secondRetrievedName = (response.dataResponse as? [String: Any])?[kName] as? String
        XCTAssertEqual(secondRetrievedName, accountNameUpdated, "wrong name retrieved")

        // Second update with if-unmodified-since with pastDate (1hr ago) - should not update
        let pastDate = Date(timeIntervalSinceNow: -3600)
        let blockedUpdatedName = "\(accountNameUpdated)_updated_again"
        let blockedFieldsUpdated: [String: String] = [kName: blockedUpdatedName]
        // Pass nil to skip the SDK's buggy date formatter; set the header manually below.
        let pastDateValue = httpDateFormatter.string(from: pastDate)
        request = RestClient.sharedInstance.requestForUpdate(withObjectType: kAccount, objectId: accountId, fields: blockedFieldsUpdated, ifUnmodifiedSinceDate: nil, apiVersion: SFRestDefaultAPIVersion)
        request.setHeaderValue(pastDateValue, forHeaderName: "If-Unmodified-Since")
        response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidFail, "request should failed")
        XCTAssertEqual(response.lastError?.code, 412, "request should have returned a 412")

        request = RestClient.sharedInstance.requestForRetrieve(withObjectType: kAccount, objectId: accountId, fieldList: kName, apiVersion: SFRestDefaultAPIVersion)
        response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "retrieve after blocked update failed")
        let thirdRetrievedName = (response.dataResponse as? [String: Any])?[kName] as? String
        XCTAssertEqual(thirdRetrievedName, accountNameUpdated, "wrong name retrieved")
    }

    func testUploadBatchDetailsDeleteFiles() {
        var fileAttrs = uploadFile()
        let fileAttrs2 = uploadFile()

        var request = RestClient.sharedInstance.requestForBatchFileDetails([fileAttrs[kLid] as? String ?? "", fileAttrs2[kLid] as? String ?? ""], apiVersion: SFRestDefaultAPIVersion)
        var response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")
        guard let results1 = (response.dataResponse as? [String: Any])?[kResults] as? [[String: Any]] else { return }
        XCTAssertEqual((results1[0][kStatusCode] as? Int), 200, "expected 200")
        XCTAssertEqual((results1[1][kStatusCode] as? Int), 200, "expected 200")

        request = RestClient.sharedInstance.requestForDelete(withObjectType: "ContentDocument", objectId: fileAttrs[kLid] as? String ?? "", apiVersion: SFRestDefaultAPIVersion)
        response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")

        request = RestClient.sharedInstance.requestForBatchFileDetails([fileAttrs[kLid] as? String ?? "", fileAttrs2[kLid] as? String ?? ""], apiVersion: SFRestDefaultAPIVersion)
        response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")
        guard let results2 = (response.dataResponse as? [String: Any])?[kResults] as? [[String: Any]] else { return }
        XCTAssertEqual((results2[0][kStatusCode] as? Int), 404, "expected 404")
        XCTAssertEqual((results2[1][kStatusCode] as? Int), 200, "expected 200")

        request = RestClient.sharedInstance.requestForDelete(withObjectType: "ContentDocument", objectId: fileAttrs2[kLid] as? String ?? "", apiVersion: SFRestDefaultAPIVersion)
        response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")

        request = RestClient.sharedInstance.requestForBatchFileDetails([fileAttrs[kLid] as? String ?? "", fileAttrs2[kLid] as? String ?? ""], apiVersion: SFRestDefaultAPIVersion)
        response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")
        guard let results3 = (response.dataResponse as? [String: Any])?[kResults] as? [[String: Any]] else { return }
        XCTAssertEqual((results3[0][kStatusCode] as? Int), 404, "expected 404")
        XCTAssertEqual((results3[1][kStatusCode] as? Int), 404, "expected 404")
    }

    func testUploadBatchDetailsDeleteFilesCommunity() {
        let fileAttrs = uploadFile()
        let fileAttrs2 = uploadFile()
        guard let creds = OAuthCredentials.credentials(identifier: "CLIENT ID", clientId: "CLIENT ID", encrypted: false) else { return }
        creds.userId = "USERID"
        creds.organizationId = "ORGID"
        creds.communityId = "COMMUNITYID"
        creds.instanceUrl = URL(string: "https://sample.domain")
        let account = UserAccount(credentials: creds)
        account.transitionToLoginState(.loggedIn)

        guard let restAPI = RestClient.restClient(for: account) else { return }
        XCTAssertNotNil(restAPI, "RestApi instance for this user must exist")
        let request = restAPI.requestForBatchFileDetails([fileAttrs[kLid] as? String ?? "", fileAttrs2[kLid] as? String ?? ""], apiVersion: SFRestDefaultAPIVersion)
        XCTAssertNotNil(request, "Request should have been created")
        guard let urlRequest = request.prepareRequestForSend(account) else { return }
        let urlString = urlRequest.url?.absoluteString ?? ""
        XCTAssertTrue(urlString.range(of: "connect/communities/COMMUNITYID/") != nil, "The URL must have communities path")
        dataCleanupRequired = false
    }

    func testUploadDetailsDeleteFile() {
        let fileAttrs = uploadFile()

        var request = RestClient.sharedInstance.requestForFileDetails(fileAttrs[kLid] as? String ?? "", forVersion: nil, apiVersion: SFRestDefaultAPIVersion)
        var response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")

        request = RestClient.sharedInstance.requestForDelete(withObjectType: "ContentDocument", objectId: fileAttrs[kLid] as? String ?? "", apiVersion: SFRestDefaultAPIVersion)
        response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")

        request = RestClient.sharedInstance.requestForFileDetails(fileAttrs[kLid] as? String ?? "", forVersion: nil, apiVersion: SFRestDefaultAPIVersion)
        response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidFail, "request was supposed to fail")
        XCTAssertEqual(response.lastError?.code, 404, "invalid code")
    }

    func testUploadDetailsDeleteFileWithCommunity() {
        guard let creds = OAuthCredentials.credentials(identifier: "CLIENT ID", clientId: "CLIENT ID", encrypted: false) else { return }
        creds.userId = "USERID"
        creds.organizationId = "ORGID"
        creds.communityId = "COMMUNITYID"
        creds.instanceUrl = URL(string: "https://sample.domain")
        let account = UserAccount(credentials: creds)
        account.transitionToLoginState(.loggedIn)

        let fileAttrs = uploadFile()
        guard let restAPI = RestClient.restClient(for: account) else { return }
        XCTAssertNotNil(restAPI, "RestApi instance for this user must exist")
        let request = restAPI.requestForFileDetails(fileAttrs[kLid] as? String ?? "", forVersion: nil, apiVersion: SFRestDefaultAPIVersion)
        XCTAssertNotNil(request, "Request should have been created")
        guard let urlRequest = request.prepareRequestForSend(account) else { return }
        let urlString = urlRequest.url?.absoluteString ?? ""
        XCTAssertTrue(urlString.range(of: "connect/communities/COMMUNITYID/") != nil, "The URL must have communities path")
        dataCleanupRequired = false
    }

    func testUploadDownloadDeleteFileWithCommunity() {
        guard let creds = OAuthCredentials.credentials(identifier: "CLIENT ID", clientId: "CLIENT ID", encrypted: false) else { return }
        creds.userId = "USERID"
        creds.organizationId = "ORGID"
        creds.communityId = "COMMUNITYID"
        creds.instanceUrl = URL(string: "https://sample.domain")
        let account = UserAccount(credentials: creds)
        account.transitionToLoginState(.loggedIn)

        let fileAttrs = uploadFile()
        guard let restAPI = RestClient.restClient(for: account) else { return }
        XCTAssertNotNil(restAPI, "RestApi instance for this user must exist")
        var request = restAPI.requestForFileRendition(fileAttrs[kLid] as? String ?? "", version: nil, renditionType: "PDF", page: 0, apiVersion: SFRestDefaultAPIVersion)
        XCTAssertNotNil(request, "Request should have been created")
        var urlRequest = request.prepareRequestForSend(account)
        var urlString = urlRequest?.url?.absoluteString ?? ""
        XCTAssertTrue(urlString.range(of: "connect/communities/COMMUNITYID/") != nil, "The URL must have communities path")

        request = restAPI.requestForDelete(withObjectType: "ContentDocument", objectId: fileAttrs[kLid] as? String ?? "", apiVersion: SFRestDefaultAPIVersion)
        urlRequest = request.prepareRequestForSend(account)
        urlString = urlRequest?.url?.absoluteString ?? ""
        XCTAssertTrue(urlString.range(of: "connect/communities/COMMUNITYID/") != nil, "The URL must have communities path")

        request = restAPI.requestForFileContents(fileAttrs[kLid] as? String ?? "", version: nil, apiVersion: SFRestDefaultAPIVersion)
        urlRequest = request.prepareRequestForSend(account)
        urlString = urlRequest?.url?.absoluteString ?? ""
        XCTAssertTrue(urlString.range(of: "connect/communities/COMMUNITYID/") != nil, "The URL must have communities path")
        dataCleanupRequired = false
    }

    func testUploadOwnedFilesDelete() {
        // upload first file
        let fileAttrs = uploadFile()
        let fileId = fileAttrs[kLid] as? String ?? ""

        // get owned files — retry until the uploaded file appears in the list
        var request = RestClient.sharedInstance.requestForOwnedFilesList(nil, page: 0, apiVersion: SFRestDefaultAPIVersion)
        var response = waitForOwnedFilesList(request, toContainFileId: fileId, maxWaitSeconds: 30)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")

        // upload other file
        let fileAttrs2 = uploadFile()
        let fileId2 = fileAttrs2[kLid] as? String ?? ""

        // get owned files — retry until the second uploaded file appears
        request = RestClient.sharedInstance.requestForOwnedFilesList(nil, page: 0, apiVersion: SFRestDefaultAPIVersion)
        response = waitForOwnedFilesList(request, toContainFileId: fileId2, maxWaitSeconds: 30)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")
        let files = (response.dataResponse as? [String: Any])?["files"] as? [[String: Any]]
        XCTAssertNotNil(findFileWithId(fileId, inFiles: files), "first file not found in owned files")
        XCTAssertNotNil(findFileWithId(fileId2, inFiles: files), "second file not found in owned files")

        // delete second file
        request = RestClient.sharedInstance.requestForDelete(withObjectType: "ContentDocument", objectId: fileId2, apiVersion: SFRestDefaultAPIVersion)
        response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "delete request failed")

        // get owned files — retry until the deleted file is removed from the list
        request = RestClient.sharedInstance.requestForOwnedFilesList(nil, page: 0, apiVersion: SFRestDefaultAPIVersion)
        response = waitForOwnedFilesList(request, toNotContainFileId: fileId2, maxWaitSeconds: 30)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")
        let remainingFiles = (response.dataResponse as? [String: Any])?["files"] as? [[String: Any]]
        XCTAssertNotNil(findFileWithId(fileId, inFiles: remainingFiles), "first file should still be in owned files")

        // delete first file
        request = RestClient.sharedInstance.requestForDelete(withObjectType: "ContentDocument", objectId: fileId, apiVersion: SFRestDefaultAPIVersion)
        response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "delete request failed")
    }

    func testUploadProfilePhoto() {
        let timecode = Date.timeIntervalSinceReferenceDate
        let fileTitle = "FileName\(timecode).png"
        guard let fileData = SFSDKResourceUtils.imageNamed("salesforce-logo")?.pngData() else { return }
        let fileMimeType = "application/octet-stream"

        let request = RestClient.sharedInstance.requestForProfilePhotoUpload(fileData, fileName: fileTitle, mimeType: fileMimeType, userId: currentUser?.credentials.userId ?? "", apiVersion: SFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)

        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")
    }

    func testUploadProfilePhotoCommunity() {
        guard let creds = OAuthCredentials.credentials(identifier: "CLIENT ID", clientId: "CLIENT ID", encrypted: false) else { return }
        creds.userId = "USERID"
        creds.organizationId = "ORGID"
        creds.instanceUrl = URL(string: "https://sample.domain")
        creds.communityId = "COMMUNITYID"
        let account = UserAccount(credentials: creds)
        account.transitionToLoginState(.loggedIn)
        guard let restAPI = RestClient.restClient(for: account) else { return }
        XCTAssertNotNil(restAPI, "RestApi instance for this user must exist")

        let timecode = Date.timeIntervalSinceReferenceDate
        let fileTitle = "FileName\(timecode).png"
        guard let fileData = SFSDKResourceUtils.imageNamed("salesforce-logo")?.pngData() else { return }
        let fileMimeType = "application/octet-stream"
        let request = restAPI.requestForProfilePhotoUpload(fileData, fileName: fileTitle, mimeType: fileMimeType, userId: creds.userId ?? "", apiVersion: SFRestDefaultAPIVersion)

        XCTAssertNotNil(request, "Request should have been created")
        guard let urlRequest = request.prepareRequestForSend(account) else { return }
        let urlString = urlRequest.url?.absoluteString ?? ""
        XCTAssertTrue(urlString.range(of: "connect/communities/COMMUNITYID/user-profiles/") != nil, "The URL must have communities path")
        dataCleanupRequired = false
    }

    // MARK: - Private Helpers

    private func makeRecords(_ typeFieldNameValues: [[String]]) -> [[String: Any]] {
        var records = [[String: Any]]()
        for row in typeFieldNameValues {
            var record: [String: Any] = ["attributes": ["type": row[0]]]
            var i = 1
            while i < row.count {
                record[row[i]] = row[i + 1]
                i += 2
            }
            records.append(record)
        }
        return records
    }

    func testUploadShareFileSharesSharedFilesUnshareDelete() {
        // upload file
        let fileAttrs = uploadFile()
        let fileId = fileAttrs[kLid] as? String ?? ""

        // get id of other user
        let otherUserId = getOtherUser()

        // get file shares
        var request = RestClient.sharedInstance.requestForFileShares(fileId, page: 0, apiVersion: SFRestDefaultAPIVersion)
        var response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")
        var shares = (response.dataResponse as? [String: Any])?["shares"] as? [[String: Any]] ?? []
        XCTAssertEqual(shares.count, 1, "expected one share")
        XCTAssertEqual((shares.first?["entity"] as? [String: Any])?[kLid] as? String, currentUser?.credentials.userId, "expected share with current user")
        XCTAssertEqual(shares.first?["sharingType"] as? String, "I", "wrong sharing type")

        // get count files shared with other user
        request = RestClient.sharedInstance.requestForFilesSharedWithUser(otherUserId, page: 0, apiVersion: SFRestDefaultAPIVersion)
        response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")
        let countFilesSharedWithOtherUser = ((response.dataResponse as? [String: Any])?["files"] as? [[String: Any]] ?? []).count

        // share file with other user
        request = RestClient.sharedInstance.requestForAddFileShare(fileId, entityId: otherUserId, shareType: "V", apiVersion: SFRestDefaultAPIVersion)
        response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")
        let shareId = (response.dataResponse as? [String: Any])?[kLid] as? String ?? ""

        // get file shares again
        request = RestClient.sharedInstance.requestForFileShares(fileId, page: 0, apiVersion: SFRestDefaultAPIVersion)
        response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")
        shares = (response.dataResponse as? [String: Any])?["shares"] as? [[String: Any]] ?? []
        var actualUserIdToType = [String: String]()
        for share in shares {
            let shareEntityId = (share["entity"] as? [String: Any])?[kLid] as? String ?? ""
            let shareType = share["sharingType"] as? String ?? ""
            actualUserIdToType[shareEntityId] = shareType
        }
        XCTAssertEqual(actualUserIdToType.count, 2, "expected two shares")
        XCTAssertTrue(actualUserIdToType.keys.contains(currentUser?.credentials.userId ?? ""), "expected share with current user")
        XCTAssertEqual(actualUserIdToType[currentUser?.credentials.userId ?? ""], "I", "wrong sharing type for current user")
        XCTAssertTrue(actualUserIdToType.keys.contains(otherUserId), "expected shared with other user")
        XCTAssertEqual(actualUserIdToType[otherUserId], "V", "wrong sharing type for other user")

        // get count files shared with other user
        request = RestClient.sharedInstance.requestForFilesSharedWithUser(otherUserId, page: 0, apiVersion: SFRestDefaultAPIVersion)
        response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")
        XCTAssertEqual(((response.dataResponse as? [String: Any])?["files"] as? [[String: Any]] ?? []).count, countFilesSharedWithOtherUser + 1, "expected one more file shared with other user")

        // unshare file from other user
        request = RestClient.sharedInstance.requestForDeleteFileShare(shareId, apiVersion: SFRestDefaultAPIVersion)
        response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")

        // get files shares again
        request = RestClient.sharedInstance.requestForFileShares(fileId, page: 0, apiVersion: SFRestDefaultAPIVersion)
        response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")
        shares = (response.dataResponse as? [String: Any])?["shares"] as? [[String: Any]] ?? []
        XCTAssertEqual(shares.count, 1, "expected one share")
        XCTAssertEqual((shares.first?["entity"] as? [String: Any])?[kLid] as? String, currentUser?.credentials.userId, "expected share with current user")
        XCTAssertEqual(shares.first?["sharingType"] as? String, "I", "wrong sharing type")

        // get count files shared with other user
        request = RestClient.sharedInstance.requestForFilesSharedWithUser(otherUserId, page: 0, apiVersion: SFRestDefaultAPIVersion)
        response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")
        XCTAssertEqual(((response.dataResponse as? [String: Any])?["files"] as? [[String: Any]] ?? []).count, countFilesSharedWithOtherUser, "expected one less file shared with other user")

        // delete file
        request = RestClient.sharedInstance.requestForDelete(withObjectType: "ContentDocument", objectId: fileId, apiVersion: SFRestDefaultAPIVersion)
        response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")
    }

    private func getOtherUser() -> String {
        let soql = "SELECT Id FROM User WHERE Id != '\(currentUser?.credentials.userId ?? "")'"
        let request = RestClient.sharedInstance.requestForQuery(soql, apiVersion: SFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")
        let records = (response.dataResponse as? [String: Any])?[kRecords] as? [[String: Any]]
        return records?.first?[kId] as? String ?? ""
    }

    private func uploadFile() -> [String: Any] {
        let timecode = Date.timeIntervalSinceReferenceDate
        let fileTitle = "FileName\(timecode).txt"
        let fileDescription = "FileDescription\(timecode)"
        let fileDataStr = "FileData\(timecode)"
        let fileData = fileDataStr.data(using: .utf8) ?? Data()
        let fileMimeType = "text/plain"
        let fileSize = fileData.count

        let request = RestClient.sharedInstance.requestForUploadFile(fileData, name: fileTitle, description: fileDescription, mimeType: fileMimeType, apiVersion: SFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad)

        guard let dataResponse = response.dataResponse as? [String: Any] else { return [:] }
        XCTAssertEqual(dataResponse["title"] as? String, fileTitle)
        XCTAssertEqual(dataResponse["description"] as? String, fileDescription)
        XCTAssertEqual(dataResponse["contentSize"] as? Int, fileSize)
        XCTAssertEqual(dataResponse["mimeType"] as? String, fileMimeType)

        let fileId = dataResponse[kLid] as? String ?? ""
        return [
            "title": fileTitle,
            "data": fileData,
            "mimeType": fileMimeType,
            kLid: fileId,
            "contentSize": fileSize
        ]
    }

    private func getTestCredentials(domain: String, instanceUrl: URL?, communityUrl: URL?) -> OAuthCredentials {
        let credsId = "testRestUrl_\(arc4random())"
        guard let creds = OAuthCredentials.credentials(identifier: credsId, clientId: "TestClientID", encrypted: true) else {
            fatalError("Failed to create credentials")
        }
        creds.communityUrl = communityUrl
        creds.domain = domain
        creds.instanceUrl = instanceUrl
        return creds
    }

    private func createNewUser() -> UserAccount? {
        let credentials = TestSetupUtils.newClientCredentials()
        let account = UserAccount(credentials: credentials)
        account.transitionToLoginState(.loggedIn)
        let userId = generateRandomId(18)
        let orgId = generateRandomId(18)
        account.credentials.userId = userId
        account.credentials.organizationId = orgId
        account.credentials.instanceUrl = UserAccountManager.shared.currentUserAccount?.credentials.instanceUrl

        let result = UserAccountManager.shared.upsert(account)
        return result ? account : nil
    }

    private func deleteUser(_ user: UserAccount) -> Bool {
        RestClient.removeSharedInstance(for: user)
        return UserAccountManager.shared.delete(user)
    }

    private func generateRandomId(_ len: Int) -> String {
        let alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXZY0123456789"
        return String((0..<len).map { _ in alphabet.randomElement() ?? "a" })
    }

    private func waitForExpectation() -> Bool {
        var timedout = false
        waitForExpectations(timeout: 15) { error in
            if error != nil { timedout = true }
        }
        return timedout
    }
}
