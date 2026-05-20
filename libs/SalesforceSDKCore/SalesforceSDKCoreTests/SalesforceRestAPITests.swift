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

private class RestAPITestDelegate: NSObject, SFRestRequestDelegate {
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

    func request(_ request: RestRequest, didFail dataResponse: Any?, rawResponse: URLResponse?, error: Error) {
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
            TestSetupUtils.populateAuthCredentialsFromConfigFile(for: self)
            TestSetupUtils.synchronousAuthRefresh()
        } catch {
            authException = NSException(name: .genericException, reason: error.localizedDescription)
        }
        super.setUp()
    }

    override func setUp() {
        super.setUp()
        if let authException = Self.authException {
            XCTFail("Setting up authentication failed: \(authException)")
        }
        dataCleanupRequired = true
        currentUser = UserAccountManager.shared.currentUserAccount
    }

    override func tearDown() {
        if dataCleanupRequired {
            cleanup()
        }
        RestClient.sharedGlobal.cleanup()
        RestClient.sharedInstance.cleanup()
        UserAccountManager.shared.setCurrentUserInternal(currentUser)
        Thread.sleep(forTimeInterval: 0.1)
        super.tearDown()
    }

    // MARK: - Helper Methods

    private func cleanup() {
        let searchRequest = RestClient.sharedInstance.requestForSearch("find {\(kEntityPrefixName)}", apiVersion: kSFRestDefaultAPIVersion)
        let response = sendSyncRequest(searchRequest)
        guard let results = (response.dataResponse as? [String: Any])?[kSearchRecords] as? [[String: Any]] else { return }
        var requests = [RestRequest]()
        for result in results {
            guard let objectType = (result[kAttributes] as? [String: Any])?[kType] as? String,
                  let objectId = result[kId] as? String else { continue }
            let deleteRequest = RestClient.sharedInstance.requestForDelete(withObjectType: objectType, objectId: objectId, apiVersion: kSFRestDefaultAPIVersion)
            requests.append(deleteRequest)
            if requests.count == 25 {
                _ = sendSyncRequest(RestClient.sharedInstance.batchRequest(requests, haltOnError: false, apiVersion: kSFRestDefaultAPIVersion))
                requests.removeAll()
            }
        }
        if requests.count > 0 {
            _ = sendSyncRequest(RestClient.sharedInstance.batchRequest(requests, haltOnError: false, apiVersion: kSFRestDefaultAPIVersion))
        }
    }

    private func generateRecordName() -> String {
        let timecode = Date.timeIntervalSinceReferenceDate
        return "\(kEntityPrefixName)\(timecode)"
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

        waitForExpectations(timeout: 30.0)

        let result = RestAPITestResponse()
        result.returnStatus = responseError != nil ? kTestRequestStatusDidFail : kTestRequestStatusDidLoad
        result.dataResponse = responseData
        result.lastError = responseError
        result.rawResponse = rawResponseData
        return result
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
        let request = RestClient.sharedInstance.requestForResources(kSFRestDefaultAPIVersion)
        request.path = "\(kSFDefaultRestEndpoint)\(request.path)"
        let response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")
        dataCleanupRequired = false
    }

    func testUserDefinedEndpoint() {
        let request = RestClient.sharedInstance.requestForResources(kSFRestDefaultAPIVersion)
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
        let request = RestClient.sharedInstance.requestForLimits(kSFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")
        dataCleanupRequired = false
    }

    func testGetResources() {
        let request = RestClient.sharedInstance.requestForResources(kSFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")
        dataCleanupRequired = false
    }

    func testGetDescribeGlobal() {
        let request = RestClient.sharedInstance.requestForDescribeGlobal(kSFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")
        dataCleanupRequired = false
    }

    func testGetDescribeGlobal_Cancel() {
        let request = RestClient.sharedInstance.requestForDescribeGlobal(kSFRestDefaultAPIVersion)
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
        let request = RestClient.sharedInstance.requestForDescribeGlobal(kSFRestDefaultAPIVersion)
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
        let request = RestClient.sharedInstance.requestForMetadata(withObjectType: kContact, apiVersion: kSFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")
        dataCleanupRequired = false
    }

    func testGetDescribeWithObjectType() {
        let request = RestClient.sharedInstance.requestForDescribe(withObjectType: kContact, apiVersion: kSFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")
        dataCleanupRequired = false
    }

    func testGetLayoutWithObjectAPINameWithoutFormFactor() {
        let request = RestClient.sharedInstance.requestForLayout(withObjectAPIName: kContact, formFactor: nil, layoutType: nil, mode: nil, recordTypeId: nil, apiVersion: kSFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")
        dataCleanupRequired = false
    }

    func testGetLayoutWithObjectAPINameWithFormFactor() {
        let request = RestClient.sharedInstance.requestForLayout(withObjectAPIName: kContact, formFactor: "Medium", layoutType: nil, mode: nil, recordTypeId: nil, apiVersion: kSFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")
    }

    func testGetLayoutWithObjectAPINameWithLayoutType() {
        let request = RestClient.sharedInstance.requestForLayout(withObjectAPIName: kContact, formFactor: nil, layoutType: "Compact", mode: nil, recordTypeId: nil, apiVersion: kSFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")
    }

    func testGetLayoutWithObjectAPINameWithMode() {
        let request = RestClient.sharedInstance.requestForLayout(withObjectAPIName: kContact, formFactor: nil, layoutType: nil, mode: "Edit", recordTypeId: nil, apiVersion: kSFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")
    }

    func testGetSearchScopeAndOrder() {
        let request = RestClient.sharedInstance.requestForSearchScopeAndOrder(kSFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")
        dataCleanupRequired = false
    }

    func testGetSearchResultLayout() {
        let request = RestClient.sharedInstance.requestForSearchResultLayout(kAccount, apiVersion: kSFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")
        dataCleanupRequired = false
    }

    func testCreateBogusContact() {
        let request = RestClient.sharedInstance.requestForCreate(withObjectType: kContact, fields: nil, apiVersion: kSFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidFail, "request should have failed")
    }

    func testCreateQuerySearchDelete() {
        let lastName = generateRecordName()
        let fields: [String: String] = [kFirstName: "John", kLastName: lastName]

        var request = RestClient.sharedInstance.requestForCreate(withObjectType: kContact, fields: fields, apiVersion: kSFRestDefaultAPIVersion)
        var response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")

        guard let contactId = (response.dataResponse as? [String: Any])?[kLid] as? String else {
            XCTFail("id not present"); return
        }

        defer {
            request = RestClient.sharedInstance.requestForDelete(withObjectType: kContact, objectId: contactId, apiVersion: kSFRestDefaultAPIVersion)
            _ = sendSyncRequest(request)
        }

        // Retrieve
        request = RestClient.sharedInstance.requestForRetrieve(withObjectType: kContact, objectId: contactId, fieldList: nil, apiVersion: kSFRestDefaultAPIVersion)
        response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")
        XCTAssertEqual((response.dataResponse as? [String: Any])?[kLastName] as? String, lastName)
        XCTAssertEqual((response.dataResponse as? [String: Any])?[kFirstName] as? String, "John")

        // Retrieve with field list
        request = RestClient.sharedInstance.requestForRetrieve(withObjectType: kContact, objectId: contactId, fieldList: "LastName, FirstName", apiVersion: kSFRestDefaultAPIVersion)
        response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")
        XCTAssertEqual((response.dataResponse as? [String: Any])?[kLastName] as? String, lastName)
        XCTAssertEqual((response.dataResponse as? [String: Any])?[kFirstName] as? String, "John")

        // Query
        request = RestClient.sharedInstance.requestForQuery("select Id, FirstName from Contact where LastName='\(lastName)'", apiVersion: kSFRestDefaultAPIVersion)
        response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")
        let records = (response.dataResponse as? [String: Any])?[kRecords] as? [[String: Any]]
        XCTAssertEqual(records?.count, 1, "expected just one query result")

        // Search (wait for indexing)
        Thread.sleep(forTimeInterval: 5.0)
        request = RestClient.sharedInstance.requestForSearch("Find {\(lastName)}", apiVersion: kSFRestDefaultAPIVersion)
        response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")
    }

    func testCreateUpdateQuerySearchDelete() {
        let lastName = generateRecordName()
        let updatedLastName = "\(lastName)_updated"
        let fields: [String: String] = [kFirstName: "John", kLastName: lastName]

        var request = RestClient.sharedInstance.requestForCreate(withObjectType: kContact, fields: fields, apiVersion: kSFRestDefaultAPIVersion)
        var response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad, "request failed")

        guard let contactId = (response.dataResponse as? [String: Any])?[kLid] as? String else {
            XCTFail("id not present"); return
        }

        defer {
            request = RestClient.sharedInstance.requestForDelete(withObjectType: kContact, objectId: contactId, apiVersion: kSFRestDefaultAPIVersion)
            _ = sendSyncRequest(request)
        }

        // Query
        request = RestClient.sharedInstance.requestForQuery("select Id, FirstName from Contact where LastName='\(lastName)'", apiVersion: kSFRestDefaultAPIVersion)
        response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad)
        let queryRecords = (response.dataResponse as? [String: Any])?[kRecords] as? [[String: Any]]
        XCTAssertEqual(queryRecords?.count, 1, "expected just one query result")

        // Update
        let updatedFields = [kLastName: updatedLastName]
        request = RestClient.sharedInstance.requestForUpdate(withObjectType: kContact, objectId: contactId, fields: updatedFields, apiVersion: kSFRestDefaultAPIVersion)
        response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad)

        // Query updated
        request = RestClient.sharedInstance.requestForQuery("select Id, FirstName from Contact where LastName='\(updatedLastName)'", apiVersion: kSFRestDefaultAPIVersion)
        response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad)
        let updatedRecords = (response.dataResponse as? [String: Any])?[kRecords] as? [[String: Any]]
        XCTAssertEqual(updatedRecords?.count, 1, "expected just one query result")

        // Old should be gone
        request = RestClient.sharedInstance.requestForQuery("select Id, FirstName from Contact where LastName='\(lastName)'", apiVersion: kSFRestDefaultAPIVersion)
        response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad)
        let oldRecords = (response.dataResponse as? [String: Any])?[kRecords] as? [[String: Any]]
        XCTAssertEqual(oldRecords?.count, 0, "expected no result")
    }

    func testUpsertWithBogusExternalIdField() {
        let acctName = generateRecordName()
        let fields = [kName: acctName]
        let uuid = UUID().uuidString
        let request = RestClient.sharedInstance.requestForUpsert(withObjectType: kAccount, externalIdField: "bogusField__c", externalId: uuid, fields: fields, apiVersion: kSFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidFail, "request should have failed")
        XCTAssertEqual(response.lastError?.code, 404, "error code should have been 404")
    }

    func testUpsert() {
        let accountName = generateRecordName()
        var fields: [String: String] = [kName: accountName]

        var request = RestClient.sharedInstance.requestForUpsert(withObjectType: kAccount, externalIdField: kId, externalId: nil, fields: fields, apiVersion: kSFRestDefaultAPIVersion)
        var response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad)
        guard let accountId = (response.dataResponse as? [String: Any])?[kLid] as? String else {
            XCTFail("id not present"); return
        }

        // Retrieve
        request = RestClient.sharedInstance.requestForRetrieve(withObjectType: kAccount, objectId: accountId, fieldList: kName, apiVersion: kSFRestDefaultAPIVersion)
        response = sendSyncRequest(request)
        XCTAssertEqual((response.dataResponse as? [String: Any])?[kName] as? String, accountName)

        // Update with upsert
        let accountNameUpdated = "\(accountName)_updated"
        fields = [kName: accountNameUpdated]
        request = RestClient.sharedInstance.requestForUpsert(withObjectType: kAccount, externalIdField: kId, externalId: accountId, fields: fields, apiVersion: kSFRestDefaultAPIVersion)
        response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad)

        // Retrieve updated
        request = RestClient.sharedInstance.requestForRetrieve(withObjectType: kAccount, objectId: accountId, fieldList: kName, apiVersion: kSFRestDefaultAPIVersion)
        response = sendSyncRequest(request)
        XCTAssertEqual((response.dataResponse as? [String: Any])?[kName] as? String, accountNameUpdated)
    }

    func testSOQLError() {
        let request = RestClient.sharedInstance.requestForQuery(nil, apiVersion: kSFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidFail)
        XCTAssertEqual(response.lastError?.code, 400)
        dataCleanupRequired = false
    }

    func testRetrieveError() {
        let request = RestClient.sharedInstance.requestForRetrieve(withObjectType: kContact, objectId: "bogus_contact_id", fieldList: nil, apiVersion: kSFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidFail)
        XCTAssertEqual(response.lastError?.code, 404)
        dataCleanupRequired = false
    }

    func testBatchRequest() {
        let accountName = generateRecordName()
        let contactName = generateRecordName()

        let createAccountRequest = RestClient.sharedInstance.requestForCreate(withObjectType: kAccount, fields: [kName: accountName], apiVersion: kSFRestDefaultAPIVersion)
        let createContactRequest = RestClient.sharedInstance.requestForCreate(withObjectType: kContact, fields: [kLastName: contactName], apiVersion: kSFRestDefaultAPIVersion)
        let queryForAccount = RestClient.sharedInstance.requestForQuery("select Id from Account where Name = '\(accountName)'", apiVersion: kSFRestDefaultAPIVersion)
        let queryForContact = RestClient.sharedInstance.requestForQuery("select Id from Contact where Name = '\(contactName)'", apiVersion: kSFRestDefaultAPIVersion)

        let batchRequest = RestClient.sharedInstance.batchRequest([createAccountRequest, createContactRequest, queryForAccount, queryForContact], haltOnError: true, apiVersion: kSFRestDefaultAPIVersion)
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

        let createAccountRequest = RestClient.sharedInstance.requestForCreate(withObjectType: kAccount, fields: [kName: accountName], apiVersion: kSFRestDefaultAPIVersion)
        let createContactRequest = RestClient.sharedInstance.requestForCreate(withObjectType: kContact, fields: [kLastName: contactName, kAccountId: "@{refAccount.id}"], apiVersion: kSFRestDefaultAPIVersion)
        let queryForContact = RestClient.sharedInstance.requestForQuery("select Id, AccountId from Contact where LastName = '\(contactName)'", apiVersion: kSFRestDefaultAPIVersion)

        let compositeRequest = RestClient.sharedInstance.compositeRequest([createAccountRequest, createContactRequest, queryForContact], refIds: ["refAccount", "refContact", "refQuery"], allOrNone: true, apiVersion: kSFRestDefaultAPIVersion)
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

        let contactTree = SFSObjectTree(objectType: kContact, objectTypePlural: "Contacts", referenceId: "refContact", fields: [kLastName: contactName], childrenTrees: nil)
        let otherContactTree = SFSObjectTree(objectType: kContact, objectTypePlural: "Contacts", referenceId: "refOtherContact", fields: [kLastName: otherContactName], childrenTrees: nil)
        let accountTree = SFSObjectTree(objectType: kAccount, objectTypePlural: nil, referenceId: "refAccount", fields: [kName: accountName], childrenTrees: [contactTree, otherContactTree])

        let treeRequest = RestClient.sharedInstance.requestForSObjectTree(kAccount, objectTrees: [accountTree], apiVersion: kSFRestDefaultAPIVersion)
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
        var queryRequest = RestClient.sharedInstance.requestForQuery("select Id, AccountId from Contact where LastName = '\(contactName)'", apiVersion: kSFRestDefaultAPIVersion)
        var queryResponse = sendSyncRequest(queryRequest)
        var queryRecords = (queryResponse.dataResponse as? [String: Any])?[kRecords] as? [[String: Any]]
        XCTAssertEqual(queryRecords?.count, 1)
        XCTAssertEqual(queryRecords?.first?[kAccountId] as? String, accountId)
        XCTAssertEqual(queryRecords?.first?[kId] as? String, contactId)

        // Query other contact
        queryRequest = RestClient.sharedInstance.requestForQuery("select Id, AccountId from Contact where LastName = '\(otherContactName)'", apiVersion: kSFRestDefaultAPIVersion)
        queryResponse = sendSyncRequest(queryRequest)
        queryRecords = (queryResponse.dataResponse as? [String: Any])?[kRecords] as? [[String: Any]]
        XCTAssertEqual(queryRecords?.count, 1)
        XCTAssertEqual(queryRecords?.first?[kAccountId] as? String, accountId)
        XCTAssertEqual(queryRecords?.first?[kId] as? String, otherContactId)
    }

    func testGetPrimingRecords() {
        let request = RestClient.sharedInstance.requestForPrimingRecords(nil, changedAfterTimestamp: nil, apiVersion: kSFRestDefaultAPIVersion)
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

        let request = RestClient.sharedInstance.requestForCollectionCreate(true, records: records, apiVersion: kSFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        let parsedResponse = SFSDKCollectionResponse(response.dataResponse)

        XCTAssertEqual(parsedResponse.subResponses.count, 3)
        XCTAssertTrue(parsedResponse.subResponses[0].objectId?.hasPrefix("001") ?? false)
        XCTAssertTrue(parsedResponse.subResponses[0].success)
        XCTAssertTrue(parsedResponse.subResponses[1].success)
        XCTAssertTrue(parsedResponse.subResponses[2].objectId?.hasPrefix("003") ?? false)
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

        let request = RestClient.sharedInstance.requestForCollectionCreate(true, records: records, apiVersion: kSFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        let parsedCreateResponse = SFSDKCollectionResponse(response.dataResponse)
        let firstAccountId = parsedCreateResponse.subResponses[0].objectId ?? ""
        let secondAccountId = parsedCreateResponse.subResponses[2].objectId ?? ""

        let accountsRetrieveRequest = RestClient.sharedInstance.requestForCollectionRetrieve(kAccount, objectIds: [firstAccountId, secondAccountId], fieldList: ["Id", "Name"], apiVersion: kSFRestDefaultAPIVersion)
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

        let createRequest = RestClient.sharedInstance.requestForCollectionCreate(true, records: records, apiVersion: kSFRestDefaultAPIVersion)
        let createResponse = sendSyncRequest(createRequest)
        let parsedCreateResponse = SFSDKCollectionResponse(createResponse.dataResponse)
        let firstAccountId = parsedCreateResponse.subResponses[0].objectId ?? ""
        let contactId = parsedCreateResponse.subResponses[1].objectId ?? ""

        let deleteRequest = RestClient.sharedInstance.requestForCollectionDelete(true, objectIds: [firstAccountId, contactId], apiVersion: kSFRestDefaultAPIVersion)
        let deleteResponse = sendSyncRequest(deleteRequest)
        let parsedDeleteResponse = SFSDKCollectionResponse(deleteResponse.dataResponse)
        XCTAssertEqual(parsedDeleteResponse.subResponses.count, 2)
        XCTAssertTrue(parsedDeleteResponse.subResponses[0].success)
        XCTAssertTrue(parsedDeleteResponse.subResponses[1].success)

        // Verify deleted
        let retrieveRequest = RestClient.sharedInstance.requestForRetrieve(withObjectType: "Account", objectId: firstAccountId, fieldList: "Id,Name", apiVersion: kSFRestDefaultAPIVersion)
        let retrieveResponse = sendSyncRequest(retrieveRequest)
        XCTAssertEqual(retrieveResponse.lastError?.code, 404)
    }

    // MARK: - Files Tests

    func testOwnedFilesList() {
        var request = RestClient.sharedInstance.requestForOwnedFilesList(nil, page: 0, apiVersion: kSFRestDefaultAPIVersion)
        var response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad)
        request = RestClient.sharedInstance.requestForOwnedFilesList(currentUser?.credentials.userId, page: 0, apiVersion: kSFRestDefaultAPIVersion)
        response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad)
        dataCleanupRequired = false
    }

    func testFilesInUsersGroups() {
        var request = RestClient.sharedInstance.requestForFilesInUsersGroups(nil, page: 0, apiVersion: kSFRestDefaultAPIVersion)
        var response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad)
        request = RestClient.sharedInstance.requestForFilesInUsersGroups(currentUser?.credentials.userId, page: 0, apiVersion: kSFRestDefaultAPIVersion)
        response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad)
        dataCleanupRequired = false
    }

    func testFilesSharedWithUser() {
        var request = RestClient.sharedInstance.requestForFilesShared(withUser: nil, page: 0, apiVersion: kSFRestDefaultAPIVersion)
        var response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad)
        request = RestClient.sharedInstance.requestForFilesShared(withUser: currentUser?.credentials.userId, page: 0, apiVersion: kSFRestDefaultAPIVersion)
        response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad)
        dataCleanupRequired = false
    }

    func testUploadDownloadDeleteFile() {
        let fileAttrs = uploadFile()

        // Download content
        var request = RestClient.sharedInstance.requestForFileContents(fileAttrs[kLid] as? String ?? "", version: nil, apiVersion: kSFRestDefaultAPIVersion)
        var response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad)

        // Download rendition
        request = RestClient.sharedInstance.requestForFileRendition(fileAttrs[kLid] as? String ?? "", version: nil, renditionType: "PDF", page: 0, apiVersion: kSFRestDefaultAPIVersion)
        response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad)

        // Delete
        request = RestClient.sharedInstance.requestForDelete(withObjectType: "ContentDocument", objectId: fileAttrs[kLid] as? String ?? "", apiVersion: kSFRestDefaultAPIVersion)
        response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad)

        // Download again (expect 404)
        request = RestClient.sharedInstance.requestForFileContents(fileAttrs[kLid] as? String ?? "", version: nil, apiVersion: kSFRestDefaultAPIVersion)
        response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidFail)
        XCTAssertEqual(response.lastError?.code, 404)
    }

    // MARK: - Token Refresh Tests

    func testInvalidAccessTokenWithValidGetRequest() {
        let invalidAccessToken = "xyz"
        changeOauthTokens(accessToken: invalidAccessToken, refreshToken: nil)

        let request = RestClient.sharedInstance.requestForResources(kSFRestDefaultAPIVersion)
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
        let request = RestClient.sharedInstance.requestForCreate(withObjectType: kContact, fields: fields, apiVersion: kSFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad)
        let contactId = (response.dataResponse as? [String: Any])?[kLid] as? String
        XCTAssertNotNil(contactId)

        let newAccessToken = currentUser?.credentials.accessToken ?? ""
        XCTAssertNotEqual(newAccessToken, invalidAccessToken, "access token wasn't refreshed")

        if let contactId = contactId {
            let deleteRequest = RestClient.sharedInstance.requestForDelete(withObjectType: kContact, objectId: contactId, apiVersion: kSFRestDefaultAPIVersion)
            _ = sendSyncRequest(deleteRequest)
        }
        dataCleanupRequired = false
    }

    func testInvalidAccessTokenWithInvalidRequest() {
        let invalidAccessToken = "xyz"
        changeOauthTokens(accessToken: invalidAccessToken, refreshToken: nil)

        let request = RestClient.sharedInstance.requestForQuery(nil, apiVersion: kSFRestDefaultAPIVersion)
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
        let restAPI = RestClient.restClient(for: fakeUser)
        XCTAssertNotNil(restAPI)

        defer {
            _ = deleteUser(fakeUser)
            dataCleanupRequired = false
        }

        let request = restAPI.requestForResources(kSFRestDefaultAPIVersion)
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

        let restAPI = RestClient.restClient(for: fakeUser)
        let expectations = (0..<5).map { expectation(description: "request\($0)") }

        for i in 0..<5 {
            let request = restAPI.requestForDescribeGlobal(kSFRestDefaultAPIVersion)
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
        let generatedSimple = RestClient.soslSearch(withSearchTerm: "blah", objectScope: ["User": NSNull()])
        XCTAssertEqual(simpleSearch, generatedSimple)
    }

    func testReallyLongSOQL() {
        let lastName = "Silver-\(Date())"
        let fields = [kFirstName: "LongJohn", kLastName: lastName]
        var request = RestClient.sharedInstance.requestForCreate(withObjectType: kContact, fields: fields, apiVersion: kSFRestDefaultAPIVersion)
        var response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad)

        guard let contactId = (response.dataResponse as? [String: Any])?[kLid] as? String else {
            XCTFail("id not present"); return
        }

        defer {
            request = RestClient.sharedInstance.requestForDelete(withObjectType: kContact, objectId: contactId, apiVersion: kSFRestDefaultAPIVersion)
            _ = sendSyncRequest(request)
        }

        var queryString = "SELECT Id, FirstName, LastName FROM Contact WHERE Id IN ('"
        for _ in 0..<100 {
            queryString += "\(contactId)', '"
        }
        queryString += "')"

        request = RestClient.sharedInstance.requestForQuery(queryString, apiVersion: kSFRestDefaultAPIVersion)
        response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad)
        let records = (response.dataResponse as? [String: Any])?[kRecords] as? [[String: Any]]
        XCTAssertEqual(records?.count, 1)
    }

    // MARK: - User Agent Tests

    func testRequestUserAgent() {
        let request = RestClient.sharedInstance.requestForSearchResultLayout(kAccount, apiVersion: kSFRestDefaultAPIVersion)
        _ = sendSyncRequest(request)
        let userAgent = request.request?.allHTTPHeaderFields?["User-Agent"]
        XCTAssertEqual(userAgent, RestClient.userAgentString())
    }

    func testRequestUserAgentWithOverride() {
        let request = RestClient.sharedInstance.requestForSearchResultLayout(kAccount, apiVersion: kSFRestDefaultAPIVersion)
        request.setHeaderValue(RestClient.userAgentString("MobileSync"), forHeaderName: "User-Agent")
        _ = sendSyncRequest(request)
        let userAgent = request.request?.allHTTPHeaderFields?["User-Agent"]
        XCTAssertEqual(userAgent, RestClient.userAgentString("MobileSync"))
    }

    // MARK: - Custom Request Tests

    func testCustomBaseURLRequest() {
        let request = RestRequest(method: .GET, baseURL: "http://www.apple.com", path: "/test/testing", queryParams: nil)
        XCTAssertEqual(request.baseURL, "http://www.apple.com")
        guard let currentUser = currentUser else { return }
        let finalRequest = request.prepareRequestForSend(currentUser)
        let expectedURL = "http://www.apple.com\(kSFDefaultRestEndpoint)/test/testing"
        XCTAssertEqual(finalRequest.url?.absoluteString, expectedURL)
    }

    func testCustomBaseURLRequestPOST() {
        let request = RestRequest(method: .POST, path: "https://www.apple.com/test/testing", queryParams: nil)
        request.setCustomRequestBodyData("hello".data(using: .utf8), contentType: "application/octet-stream")
        guard let currentUser = currentUser else { return }
        let finalRequest = request.prepareRequestForSend(currentUser)
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
        let globalInstance = RestClient.sharedGlobal
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
        RestClient.sharedGlobal.send(request, failureBlock: { _, e, _ in
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
        let request = RestClient.sharedInstance.requestForNotificationsStatus(kSFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad)
    }

    func testGetNotifications() {
        let builder = SFSDKFetchNotificationsRequestBuilder()
        let yesterdayDate = Date().addingTimeInterval(-1 * 60 * 60 * 24)
        builder.setAfter(yesterdayDate)
        builder.setSize(10)
        let request = builder.buildFetchNotificationsRequest(kSFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad)
    }

    func testUpdateReadNotifications() {
        let builder = SFSDKUpdateNotificationsRequestBuilder()
        builder.setBefore(Date())
        builder.setRead(false)
        let request = builder.buildUpdateNotificationsRequest(kSFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad)
    }

    func testUpdateSeenNotifications() {
        let builder = SFSDKUpdateNotificationsRequestBuilder()
        builder.setBefore(Date())
        builder.setSeen(true)
        let request = builder.buildUpdateNotificationsRequest(kSFRestDefaultAPIVersion)
        let response = sendSyncRequest(request)
        XCTAssertEqual(response.returnStatus, kTestRequestStatusDidLoad)
    }

    func testGetNotificationRequestPath() {
        let notificationId = "testID"
        let request = RestClient.sharedInstance.requestForNotification(notificationId, apiVersion: kSFRestDefaultAPIVersion)
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
        let contactRequest = RestClient.sharedInstance.requestForCreate(withObjectType: kContact, fields: fields, apiVersion: kSFRestDefaultAPIVersion)
        let contactResponse = sendSyncRequest(contactRequest)
        guard let contactId = (contactResponse.dataResponse as? [String: Any])?[kLid] as? String else { return }

        let path = "/services/images/photo/\(contactId)"
        let request = RestRequest(method: .GET, path: path, queryParams: nil)
        request.endpoint = ""
        let response = sendSyncRequest(request)
        let statusCode = (response.rawResponse as? HTTPURLResponse)?.statusCode
        XCTAssertEqual(statusCode, 200, "Request did not return 200")
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

    private func uploadFile() -> [String: Any] {
        let timecode = Date.timeIntervalSinceReferenceDate
        let fileTitle = "FileName\(timecode).txt"
        let fileDescription = "FileDescription\(timecode)"
        let fileDataStr = "FileData\(timecode)"
        let fileData = fileDataStr.data(using: .utf8) ?? Data()
        let fileMimeType = "text/plain"
        let fileSize = fileData.count

        let request = RestClient.sharedInstance.requestForUploadFile(fileData, name: fileTitle, description: fileDescription, mimeType: fileMimeType, apiVersion: kSFRestDefaultAPIVersion)
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
        let creds = OAuthCredentials(identifier: credsId, clientId: "TestClientID", encrypted: true)
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

        var error: NSError?
        let result = UserAccountManager.shared.saveAccount(forUser: account, error: &error)
        return result ? account : nil
    }

    private func deleteUser(_ user: UserAccount) -> Bool {
        RestClient.removeSharedInstance(with: user)
        var error: NSError?
        return UserAccountManager.shared.deleteAccount(forUser: user, error: &error)
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
