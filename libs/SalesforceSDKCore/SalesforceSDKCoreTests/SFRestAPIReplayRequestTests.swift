/*
 Copyright (c) 2026-present, salesforce.com, inc. All rights reserved.

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

/*
 * Test coverage note: These tests verify that the correct NSError codes are propagated
 * to pending requests when token refresh fails with App Attestation errors. The logout
 * side-effects (logout(_:reason:)) are observable in the logs but difficult to verify
 * via notification in a unit test environment due to asynchronous account deletion.
 * Integration tests provide full end-to-end coverage of the logout flow.
 */

import XCTest
@testable import SalesforceSDKCore

// MARK: - DeferredURLProtocol

/// URLProtocol subclass that intercepts the initial network request and holds it
/// indefinitely (never delivers a response). This keeps the request pending in
/// `activeRequests` so the manually-invoked `replayRequest(_:response:)` — and the
/// flush it triggers on refresh failure — is the *only* source of the failure
/// callback. Without this, the initial request can fail-fast against the unreachable
/// test host and race the flushed refresh error into the failure block.
private class DeferredURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { return true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { return request }
    override func startLoading() {
        // Intentionally never deliver: hold the request open.
    }
    override func stopLoading() {
        // Intentionally empty.
    }
}

// MARK: - Auth client stub

/// Stubs the OAuth token-refresh call so `replayRequest` receives a canned error
/// response instead of hitting the network.
private class SFRestAPIReplayTestStub: NSObject, SFSDKOAuthProtocol {
    var stubbedResponse: SFSDKOAuthTokenEndpointResponse?

    func accessToken(forRefresh endpointReq: SFSDKOAuthTokenEndpointRequest, completion completionBlock: @escaping (SFSDKOAuthTokenEndpointResponse?) -> Void) {
        completionBlock(stubbedResponse)
    }

    func accessToken(forApprovalCode endpointReq: SFSDKOAuthTokenEndpointRequest, completion completionBlock: @escaping (SFSDKOAuthTokenEndpointResponse?) -> Void) {}

    func openIDToken(forRefresh endpointReq: SFSDKOAuthTokenEndpointRequest, completion completionBlock: @escaping (String?) -> Void) {}

    func revokeRefreshToken(_ credentials: OAuthCredentials, reason: SFLogoutReason) {}
}

// MARK: - Expose private replayRequest for testing via ObjC runtime

private extension RestClient {
    func replayRequest(_ request: RestRequest, response: URLResponse?) {
        let selector = NSSelectorFromString("replayRequest:response:")
        guard responds(to: selector) else { return }
        let impl = method(for: selector)
        typealias MethodType = @convention(c) (AnyObject, Selector, RestRequest, URLResponse?) -> Void
        let method = unsafeBitCast(impl, to: MethodType.self)
        method(self, selector, request, response)
    }
}

// MARK: - Tests

class SFRestAPIReplayRequestTests: XCTestCase {

    private var restAPI: RestClient?
    private var testAccount: UserAccount?
    private var originalAuthClientFactory: SFAuthClientFactoryBlock?

    override func setUp() {
        super.setUp()

        // Hold the initial network request open so only the flushed refresh error reaches
        // the failure block (see DeferredURLProtocol).
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [DeferredURLProtocol.self]
        Network.setSessionConfiguration(config, identifier: NetworkEphemeralInstanceIdentifier)

        // Save original factory
        originalAuthClientFactory = UserAccountManager.shared.authClient

        // Create test account.
        // Migration note: OAuthCredentials(identifier:clientId:encrypted:) returns nil for
        // keychain-backed storage, so use the OAuthCredentials.credentials(...) factory.
        let identifier = "testuser_\(UInt32.random(in: 0 ... .max))"
        let clientId = "testclient_\(UInt32.random(in: 0 ... .max))"
        guard let credentials = OAuthCredentials.credentials(identifier: identifier, clientId: clientId, encrypted: true) else {
            XCTFail("Failed to create credentials")
            return
        }
        credentials.redirectUri = "testapp:///oauth_\(UInt32.random(in: 0 ... .max))"
        credentials.instanceUrl = URL(string: "https://test.salesforce.com")
        credentials.accessToken = "access_\(UInt32.random(in: 0 ... .max))"
        credentials.refreshToken = "refresh_\(UInt32.random(in: 0 ... .max))"
        credentials.userId = "005000000000001"
        credentials.organizationId = "00D000000000001"

        let account = UserAccount(credentials: credentials)
        _ = UserAccountManager.shared.upsert(account)
        testAccount = account

        // Migration note: use a standalone RestClient (not the shared-registry instance) so this
        // test is isolated from the global didLogoutUser observer. A sibling test's App Attestation
        // failure schedules an async logout(_:reason:) whose cleanup() flushes any registry RestClient
        // for that user; a standalone instance isn't in sfRestApiList, so that leaked logout cannot
        // reach — and prematurely fail — this test's pending request. replayRequest reads user
        // credentials directly, so the refresh path is unaffected. (The upstream ObjC test does not
        // verify the logout side-effect; see the coverage note above.)
        restAPI = RestClient(user: account)
    }

    override func tearDown() {
        if let originalAuthClientFactory = originalAuthClientFactory {
            UserAccountManager.shared.authClient = originalAuthClientFactory
        }
        restAPI?.cancelAllRequests()
        restAPI?.cleanup()
        if let testAccount = testAccount {
            _ = UserAccountManager.shared.delete(testAccount)
        }
        Network.removeSharedEphemeralInstance()
        testAccount = nil
        restAPI = nil
        super.tearDown()
    }

    private func unauthorizedResponse() -> HTTPURLResponse? {
        guard let url = URL(string: "https://test.salesforce.com/services/data/v66.0") else { return nil }
        return HTTPURLResponse(url: url, statusCode: 401, httpVersion: "HTTP/1.1", headerFields: nil)
    }

    func test_given_invalidGrant_when_replayRequest_then_logsOutWithTokenExpired() {
        guard let restAPI = restAPI else { XCTFail("restAPI not initialized"); return }

        // Arrange: stub returns invalid_grant error
        let errorDict: NSDictionary = [
            "error": "invalid_grant",
            "error_description": "expired refresh token"
        ]
        let response = SFSDKOAuthTokenEndpointResponse(dictionary: errorDict, parseAdditionalFields: nil)
        let stub = SFRestAPIReplayTestStub()
        stub.stubbedResponse = response
        UserAccountManager.shared.authClient = { stub }

        // Create a pending request
        let request = restAPI.requestForResources(nil)
        var receivedError: NSError?
        var expectationFulfilled = false
        let failureExpectation = expectation(description: "Request fails")

        restAPI.send(request, failureBlock: { _, error, _ in
            // Capture only the FIRST failure (the flushed refresh error). A later cancellation /
            // logout callback from cleanup can otherwise overwrite it with a nil-userInfo error.
            if !expectationFulfilled {
                receivedError = error as NSError?
                expectationFulfilled = true
                failureExpectation.fulfill()
            }
        }, successBlock: { _, _ in
            XCTFail("Should not succeed")
        })

        // Trigger replay by simulating a 401
        restAPI.replayRequest(request, response: unauthorizedResponse())

        wait(for: [failureExpectation], timeout: 5.0)

        // Assert
        XCTAssertNotNil(receivedError, "Request should receive error")
        XCTAssertEqual(receivedError?.code, kSFOAuthErrorInvalidGrant, "Error code should be invalid_grant")
        XCTAssertEqual(receivedError?.userInfo[kSFOAuthError] as? String, "invalid_grant", "Wire value should be preserved")
    }

    func test_given_clientBlocked_when_replayRequest_then_logsOutWithAppAttestationFailed() {
        guard let restAPI = restAPI else { XCTFail("restAPI not initialized"); return }

        // Arrange: stub returns client_blocked error
        let errorDict: NSDictionary = [
            "error": "client_blocked",
            "error_description": "app attestation failed"
        ]
        let response = SFSDKOAuthTokenEndpointResponse(dictionary: errorDict, parseAdditionalFields: nil)
        let stub = SFRestAPIReplayTestStub()
        stub.stubbedResponse = response
        UserAccountManager.shared.authClient = { stub }

        // Create a pending request
        let request = restAPI.requestForResources(nil)
        var receivedError: NSError?
        var expectationFulfilled = false
        let failureExpectation = expectation(description: "Request fails")

        restAPI.send(request, failureBlock: { _, error, _ in
            // Capture only the FIRST failure (the flushed refresh error). A later cancellation /
            // logout callback from cleanup can otherwise overwrite it with a nil-userInfo error.
            if !expectationFulfilled {
                receivedError = error as NSError?
                expectationFulfilled = true
                failureExpectation.fulfill()
            }
        }, successBlock: { _, _ in
            XCTFail("Should not succeed")
        })

        // Trigger replay
        restAPI.replayRequest(request, response: unauthorizedResponse())

        wait(for: [failureExpectation], timeout: 5.0)

        // Assert: wire value is preserved so replayRequest can parse it via SFOAuthErrorCode.from(_:)
        XCTAssertNotNil(receivedError, "Request should receive error")
        XCTAssertEqual(receivedError?.userInfo[kSFOAuthError] as? String, "client_blocked", "Wire value should be preserved")
        XCTAssertEqual(SFOAuthErrorCode.from(receivedError?.userInfo[kSFOAuthError] as? String),
                       .appAttestationFailed,
                       "Wire value should map to appAttestationFailed via typed enum")
    }

    func test_given_clientBlockedRetry_when_replayRequest_then_doesNotLogout_andFlushesErrorToPending() {
        guard let restAPI = restAPI else { XCTFail("restAPI not initialized"); return }

        // Arrange: stub returns client_blocked_retry error
        let errorDict: NSDictionary = [
            "error": "client_blocked_retry",
            "error_description": "attestation verification failed transiently"
        ]
        let response = SFSDKOAuthTokenEndpointResponse(dictionary: errorDict, parseAdditionalFields: nil)
        let stub = SFRestAPIReplayTestStub()
        stub.stubbedResponse = response
        UserAccountManager.shared.authClient = { stub }

        // Create a pending request
        let request = restAPI.requestForResources(nil)
        var receivedError: NSError?
        var expectationFulfilled = false
        let failureExpectation = expectation(description: "Request fails")

        restAPI.send(request, failureBlock: { _, error, _ in
            // Capture only the FIRST failure (the flushed refresh error). A later cancellation /
            // logout callback from cleanup can otherwise overwrite it with a nil-userInfo error.
            if !expectationFulfilled {
                receivedError = error as NSError?
                expectationFulfilled = true
                failureExpectation.fulfill()
            }
        }, successBlock: { _, _ in
            XCTFail("Should not succeed")
        })

        // Trigger replay
        restAPI.replayRequest(request, response: unauthorizedResponse())

        wait(for: [failureExpectation], timeout: 5.0)

        // Assert: wire value is preserved so replayRequest can parse it via SFOAuthErrorCode.from(_:)
        XCTAssertNotNil(receivedError, "Request should receive error")
        XCTAssertEqual(receivedError?.userInfo[kSFOAuthError] as? String, "client_blocked_retry", "Wire value should be preserved")
        XCTAssertEqual(SFOAuthErrorCode.from(receivedError?.userInfo[kSFOAuthError] as? String),
                       .appAttestationFailedRetry,
                       "Wire value should map to appAttestationFailedRetry via typed enum")
    }
}
