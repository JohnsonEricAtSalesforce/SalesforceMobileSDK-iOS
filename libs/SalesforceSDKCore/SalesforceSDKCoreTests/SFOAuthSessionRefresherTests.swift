//
//  SFOAuthSessionRefresherTests.swift
//  SalesforceSDKCoreTests
//
//  Copyright (c) 2015-present, salesforce.com, inc. All rights reserved.
//
//  Redistribution and use of this software in source and binary forms, with or without modification,
//  are permitted provided that the following conditions are met:
//  * Redistributions of source code must retain the above copyright notice, this list of conditions
//  and the following disclaimer.
//  * Redistributions in binary form must reproduce the above copyright notice, this list of
//  conditions and the following disclaimer in the documentation and/or other materials provided
//  with the distribution.
//  * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
//  endorse or promote products derived from this software without specific prior written
//  permission of salesforce.com, inc.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
//  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
//  FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
//  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
//  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
//  WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import XCTest
@testable import SalesforceSDKCore

// Minimal SFSDKOAuthProtocol stub that immediately calls the completion block with a preset response.
class SFSDKOAuthClientStub: NSObject, SFSDKOAuthProtocol {
    var stubbedResponse: SFSDKOAuthTokenEndpointResponse?

    func accessToken(forRefresh endpointReq: SFSDKOAuthTokenEndpointRequest, completion completionBlock: @escaping (SFSDKOAuthTokenEndpointResponse?) -> Void) {
        completionBlock(stubbedResponse)
    }
    func accessToken(forApprovalCode endpointReq: SFSDKOAuthTokenEndpointRequest, completion completionBlock: @escaping (SFSDKOAuthTokenEndpointResponse?) -> Void) {}
    func openIDToken(forRefresh endpointReq: SFSDKOAuthTokenEndpointRequest, completion completionBlock: @escaping (String?) -> Void) {}
    func revokeRefreshToken(_ credentials: OAuthCredentials, reason: SFLogoutReason) {}
}

class SFOAuthSessionRefresherTests: XCTestCase {

    var oauthSessionRefresher: SFOAuthSessionRefresher?

    override func setUp() {
        super.setUp()
        setupCoordinatorFlow()
    }

    override func tearDown() {
        tearDownCoordinatorFlow()
        super.tearDown()
    }

    func testBadInputData() {
        guard let refresher = oauthSessionRefresher, let credentials = refresher.credentials else {
            XCTFail("Refresher or credentials not set up")
            return
        }

        // Invalid Instance URL
        var inputError: NSError?
        var invalidInputExpectation = expectation(description: "Refresh with invalid Instance URL")
        let origUrl = credentials.instanceUrl
        credentials.instanceUrl = nil
        refresher.refreshSessionInternal(withCompletion: { _ in
            invalidInputExpectation.fulfill()
        }, error: { refreshError in
            inputError = refreshError as NSError
            invalidInputExpectation.fulfill()
        })

        waitForExpectations(timeout: 2.0) { error in
            XCTAssertNil(error, "Error waiting for completion: \(String(describing: error))")
            XCTAssertNotNil(inputError, "Should have received an input error for bad Instance URL.")
            XCTAssertEqual(inputError?.code, Int(SFOAuthSessionRefreshErrorCode.invalidCredentials.rawValue), "Wrong error code for input error")
            credentials.instanceUrl = origUrl
        }

        // Invalid Client ID
        inputError = nil
        invalidInputExpectation = expectation(description: "Refresh with invalid Client ID")
        let origClientId = credentials.clientId
        credentials.clientId = nil
        refresher.refreshSessionInternal(withCompletion: { _ in
            invalidInputExpectation.fulfill()
        }, error: { refreshError in
            inputError = refreshError as NSError
            invalidInputExpectation.fulfill()
        })

        waitForExpectations(timeout: 2.0) { error in
            XCTAssertNil(error, "Error waiting for completion: \(String(describing: error))")
            XCTAssertNotNil(inputError, "Should have received an input error for bad Client ID.")
            XCTAssertEqual(inputError?.code, Int(SFOAuthSessionRefreshErrorCode.invalidCredentials.rawValue), "Wrong error code for input error")
            credentials.clientId = origClientId
        }

        // Invalid Refresh Token
        inputError = nil
        invalidInputExpectation = expectation(description: "Refresh with invalid Refresh Token")
        let origRefreshToken = credentials.refreshToken
        credentials.refreshToken = nil
        credentials.instanceUrl = origUrl  // Nil'ed out as side effect of nil refresh token in OAuthCredentials.
        refresher.refreshSessionInternal(withCompletion: { _ in
            invalidInputExpectation.fulfill()
        }, error: { refreshError in
            inputError = refreshError as NSError
            invalidInputExpectation.fulfill()
        })

        waitForExpectations(timeout: 2.0) { error in
            XCTAssertNil(error, "Error waiting for completion: \(String(describing: error))")
            XCTAssertNotNil(inputError, "Should have received an input error for bad Refresh Token.")
            XCTAssertEqual(inputError?.code, Int(SFOAuthSessionRefreshErrorCode.invalidCredentials.rawValue), "Wrong error code for input error")
            credentials.refreshToken = origRefreshToken
        }
    }

    func testFailedRefresh() {
        guard let refresher = oauthSessionRefresher else {
            XCTFail("Refresher not set up")
            return
        }

        var refreshFailsError: NSError?
        let refreshAccessTokenExpectation = expectation(description: "Refresh Access Token fails")
        refresher.refreshSessionInternal(withCompletion: { _ in
            refreshAccessTokenExpectation.fulfill()
        }, error: { refreshError in
            refreshFailsError = refreshError as NSError
            refreshAccessTokenExpectation.fulfill()
        })

        waitForExpectations(timeout: 2.0) { error in
            XCTAssertNil(error, "Error waiting for completion: \(String(describing: error))")
            XCTAssertNotNil(refreshFailsError, "Should have received an error refreshing the access token.")
        }
    }

    func test_givenRotatedRefreshToken_whenRefreshSucceeds_thenRTFlagRegisteredPerUser() {
        // Arrange: register a user account whose credentials match the refresher's.
        guard let refresher = oauthSessionRefresher, let creds = refresher.credentials else {
            XCTFail("Refresher or credentials not set up")
            return
        }
        let account = UserAccount(credentials: creds)
        _ = UserAccountManager.shared.upsert(account)

        let newRefreshToken = "rotated_token_\(arc4random())"
        let responseDict: NSDictionary = [
            kSFOAuthAccessToken: "new_access_token",
            kSFOAuthRefreshToken: newRefreshToken,
        ]
        let response = SFSDKOAuthTokenEndpointResponse(dictionary: responseDict, parseAdditionalFields: nil)
        let stub = SFSDKOAuthClientStub()
        stub.stubbedResponse = response
        let originalFactory = UserAccountManager.shared.authClient
        UserAccountManager.shared.authClient = { stub }

        // Pre-condition: RT flag not set
        SFSDKAppFeatureMarkers.unregisterAppFeature(kSFAppFeatureRTR, forUser: account)

        let expectation = self.expectation(description: "Refresh with rotated token")
        refresher.refreshSessionInternal(withCompletion: { _ in
            expectation.fulfill()
        }, error: { error in
            XCTFail("Refresh should not fail: \(error)")
            expectation.fulfill()
        })

        waitForExpectations(timeout: 2.0, handler: nil)

        // Assert: RT flag registered for the user
        let features = SFSDKAppFeatureMarkers.appFeatures(forUser: account)
        XCTAssertTrue(features.contains(kSFAppFeatureRTR), "RT flag should be registered after refresh token rotation")

        // Cleanup
        UserAccountManager.shared.authClient = originalFactory
        SFSDKAppFeatureMarkers.unregisterAppFeature(kSFAppFeatureRTR, forUser: account)
        _ = UserAccountManager.shared.delete(account)
    }

    func test_givenUnchangedRefreshToken_whenRefreshSucceeds_thenRTFlagNotRegistered() {
        // Arrange: same refresh token in response — no rotation
        guard let refresher = oauthSessionRefresher, let creds = refresher.credentials else {
            XCTFail("Refresher or credentials not set up")
            return
        }
        let account = UserAccount(credentials: creds)
        _ = UserAccountManager.shared.upsert(account)

        let responseDict: NSDictionary = [
            kSFOAuthAccessToken: "new_access_token",
            kSFOAuthRefreshToken: creds.refreshToken ?? "",  // same token — no rotation
        ]
        let response = SFSDKOAuthTokenEndpointResponse(dictionary: responseDict, parseAdditionalFields: nil)
        let stub = SFSDKOAuthClientStub()
        stub.stubbedResponse = response
        let originalFactory = UserAccountManager.shared.authClient
        UserAccountManager.shared.authClient = { stub }

        let expectation = self.expectation(description: "Refresh without rotation")
        refresher.refreshSessionInternal(withCompletion: { _ in
            expectation.fulfill()
        }, error: { error in
            XCTFail("Refresh should not fail: \(error)")
            expectation.fulfill()
        })

        waitForExpectations(timeout: 2.0, handler: nil)

        // Assert: RT flag NOT registered
        let features = SFSDKAppFeatureMarkers.appFeatures(forUser: account)
        XCTAssertFalse(features.contains(kSFAppFeatureRTR), "RT flag should not be registered when refresh token did not rotate")

        // Cleanup
        UserAccountManager.shared.authClient = originalFactory
        _ = UserAccountManager.shared.delete(account)
    }

    // MARK: - Private methods

    private func setupCoordinatorFlow() {
        let credsIdentifier = "CredsIdentifier_\(arc4random())"
        let credsClientId = "CredsClientId_\(arc4random())"
        let credsAccessToken = "CredsAccessToken_\(arc4random())"
        let credsRefreshToken = "CredsRefreshToken_\(arc4random())"
        guard let creds = OAuthCredentials.credentials(identifier: credsIdentifier, clientId: credsClientId, encrypted: true) else {
            XCTFail("Failed to create credentials")
            return
        }
        creds.redirectUri = "sfdcUnitTest:///redirect_uri_\(arc4random())"
        creds.instanceUrl = URL(string: "https://cs1.salesforce.com")
        creds.accessToken = credsAccessToken
        creds.refreshToken = credsRefreshToken
        // Set userId and orgId as valid 15-char Salesforce entity IDs so matchesCredentials: can compare them.
        // (sfsdk_entityId18 returns nil for non-conforming strings, making isEqualToString:nil == NO.)
        creds.userId = "005000000000001"
        creds.organizationId = "00D000000000001"
        oauthSessionRefresher = SFOAuthSessionRefresher(internalCredentials: creds)
    }

    private func tearDownCoordinatorFlow() {
        oauthSessionRefresher?.credentials?.revoke()
        oauthSessionRefresher = nil
    }
}
