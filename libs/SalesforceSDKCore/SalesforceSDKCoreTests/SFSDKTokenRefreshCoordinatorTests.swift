/*
 Copyright (c) 2025-present, salesforce.com, inc. All rights reserved.

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

// Delay to allow the coordinator's serial queue to process dispatched blocks before test assertions
// run. The 0.1s value is generous for work that takes microseconds — it simply needs to exceed one
// main-queue run-loop tick.
private let kDispatchDelay: TimeInterval = 0.1

// MARK: - Single-Use Token Mock Refresher

/// A mock refresher that enforces single-use refresh token semantics:
/// Only the current valid refresh token succeeds. Any attempt to use a
/// previously-valid (now stale) token fails with kSFOAuthErrorInvalidGrant,
/// exactly like Salesforce orgs with refresh token rotation enabled.
///
/// Overrides the non-deprecated internal seam `refreshSessionInternal(withCompletion:error:)` —
/// the same method the coordinator invokes — so the mock stays warning-free (the public
/// `refreshSession(withCompletion:error:)` is deprecated as of 14.0).
private class SingleUseTokenMockRefresher: SFOAuthSessionRefresher {

    /// The one refresh token that will succeed. Updated on each successful refresh.
    var validRefreshToken: String?
    private let callCountLock = NSLock()
    private var _refreshCallCount = 0
    var refreshCallCount: Int {
        callCountLock.lock(); defer { callCountLock.unlock() }
        return _refreshCallCount
    }

    /// If set, the next refresh call will fail with this error regardless of token validity. Cleared after use.
    var forcedError: NSError?

    override func refreshSessionInternal(withCompletion completionBlock: @escaping (OAuthCredentials) -> Void, error errorBlock: @escaping (Error) -> Void) {
        callCountLock.lock()
        _refreshCallCount += 1
        let currentCount = _refreshCallCount
        callCountLock.unlock()

        // Allow tests to force an arbitrary error (e.g. network failure)
        if let err = forcedError {
            forcedError = nil
            errorBlock(err)
            return
        }

        let presentedToken = credentials?.refreshToken

        if presentedToken == validRefreshToken {
            // Token is valid — rotate it (single-use: old token is now dead)
            let newAccess = "access_\(currentCount)"
            let newRefresh = "refresh_\(currentCount)"

            validRefreshToken = newRefresh
            credentials?.accessToken = newAccess
            credentials?.refreshToken = newRefresh

            NotificationCenter.default.post(name: UserAccountManager.didRefreshToken, object: UserAccountManager.shared, userInfo: [:])
            if let creds = credentials {
                completionBlock(creds)
            }
        } else {
            // Stale token — simulate invalid_grant (the real server response)
            let invalidGrant = NSError(domain: kSFOAuthErrorDomain,
                                       code: kSFOAuthErrorInvalidGrant,
                                       userInfo: [NSLocalizedDescriptionKey: "invalid_grant: token \(presentedToken ?? "") was already consumed"])
            errorBlock(invalidGrant)
        }
    }
}

// MARK: - Mock OAuth Protocol (for integration tests)

private class MockAuthClient: NSObject, SFSDKOAuthProtocol {
    private let callCountLock = NSLock()
    private var _accessTokenForRefreshCallCount = 0
    var accessTokenForRefreshCallCount: Int {
        callCountLock.lock(); defer { callCountLock.unlock() }
        return _accessTokenForRefreshCallCount
    }
    var responseDict: NSDictionary?

    func accessToken(forRefresh endpointReq: SFSDKOAuthTokenEndpointRequest, completion completionBlock: @escaping (SFSDKOAuthTokenEndpointResponse?) -> Void) {
        callCountLock.lock()
        _accessTokenForRefreshCallCount += 1
        callCountLock.unlock()

        // Build a minimal success response dictionary
        let dict: NSDictionary = responseDict ?? [
            "access_token": "integration_new_access_token",
            "refresh_token": "integration_new_refresh_token",
            "instance_url": "https://test.salesforce.com",
            "id": "https://test.salesforce.com/id/orgId/userId",
            "issued_at": "1234567890"
        ]
        let response = SFSDKOAuthTokenEndpointResponse(dictionary: dict, parseAdditionalFields: [])
        completionBlock(response)
    }

    func accessToken(forApprovalCode endpointReq: SFSDKOAuthTokenEndpointRequest, completion completionBlock: @escaping (SFSDKOAuthTokenEndpointResponse?) -> Void) {
        // Not needed for these tests
    }

    func openIDToken(forRefresh endpointReq: SFSDKOAuthTokenEndpointRequest, completion completionBlock: @escaping (String?) -> Void) {
        // Not needed for these tests
    }

    func revokeRefreshToken(_ credentials: OAuthCredentials, reason: SFLogoutReason) {
        // Not needed for these tests
    }
}

// MARK: - Tests

/// Tests for SFSDKTokenRefreshCoordinator.
///
/// All tests use SingleUseTokenMockRefresher, which enforces single-use (rotating)
/// refresh token semantics — the most restrictive case. This ensures correctness
/// even when orgs have refresh token rotation enabled: any coalescing failure or
/// stale-token reuse immediately surfaces as an invalid_grant error rather than
/// silently passing with a reusable token.
class SFSDKTokenRefreshCoordinatorTests: XCTestCase {

    private var coordinator: SFSDKTokenRefreshCoordinator!
    private var mockRefresher: SingleUseTokenMockRefresher!
    private var credentials: OAuthCredentials!

    override func setUp() {
        super.setUp()
        coordinator = SFSDKTokenRefreshCoordinator()

        let identifier = "TestCreds_\(arc4random())"
        guard let creds = OAuthCredentials.credentials(identifier: identifier, clientId: "TestClientId", encrypted: true) else {
            XCTFail("Failed to create credentials")
            return
        }
        credentials = creds
        credentials.refreshToken = "test_refresh_token"
        credentials.accessToken = "test_access_token"
        credentials.instanceUrl = URL(string: "https://test.salesforce.com")
        credentials.redirectUri = "testapp://callback"

        mockRefresher = SingleUseTokenMockRefresher(internalCredentials: credentials)
        mockRefresher.validRefreshToken = credentials.refreshToken

        coordinator.refresherFactory = { [weak self] _ in
            return self?.mockRefresher ?? SFOAuthSessionRefresher(internalCredentials: nil)
        }
    }

    override func tearDown() {
        coordinator.refresherFactory = nil
        coordinator = nil
        mockRefresher = nil
        credentials?.revoke()
        credentials = nil
        super.tearDown()
    }

    // MARK: - Basic Refresh Tests

    func testSingleCallerSuccess() {
        let completionExp = expectation(description: "Completion called")

        coordinator.refreshSession(forCredentials: credentials, completion: { updated in
            XCTAssertNotNil(updated)
            XCTAssertNotNil(updated.accessToken)
            completionExp.fulfill()
        }, error: { _ in
            XCTFail("Should not receive error")
        })

        waitForExpectations(timeout: 2.0, handler: nil)
        XCTAssertEqual(mockRefresher.refreshCallCount, 1)
    }

    func testSingleCallerFailure() {
        let errorExp = expectation(description: "Error called")
        let expectedError = NSError(domain: "test", code: 42, userInfo: nil)

        // Force the refresher to fail with a specific error
        mockRefresher.forcedError = expectedError

        coordinator.refreshSession(forCredentials: credentials, completion: { _ in
            XCTFail("Should not receive completion")
        }, error: { error in
            XCTAssertEqual((error as NSError).code, 42)
            errorExp.fulfill()
        })

        waitForExpectations(timeout: 2.0, handler: nil)
    }

    // MARK: - Credential Mutation Tests

    func testAllWaitersReceiveUpdatedCredentials() {
        let completion1 = expectation(description: "Completion 1")
        let completion2 = expectation(description: "Completion 2")

        var token1: String?
        var token2: String?

        coordinator.refreshSession(forCredentials: credentials, completion: { updated in
            XCTAssertNotNil(updated.accessToken)
            XCTAssertNotNil(updated.refreshToken)
            token1 = updated.accessToken
            completion1.fulfill()
        }, error: { error in
            XCTFail("Error on refresh #1: \(error.localizedDescription)")
        })

        coordinator.refreshSession(forCredentials: credentials, completion: { updated in
            XCTAssertNotNil(updated.accessToken)
            XCTAssertNotNil(updated.refreshToken)
            token2 = updated.accessToken
            completion2.fulfill()
        }, error: { error in
            XCTFail("Error on refresh #2: \(error.localizedDescription)")
        })

        waitForExpectations(timeout: 2.0, handler: nil)

        // Both waiters received the same rotated credentials (coalesced)
        XCTAssertEqual(token1, token2, "Both waiters should receive the same updated access token")
        XCTAssertNotEqual(token1, "test_access_token", "Token should have rotated")
    }

    // MARK: - Notification Tests

    func testNotificationPostedExactlyOnceForCoalescedRefresh() {
        var notificationCount = 0
        let observer = NotificationCenter.default.addObserver(forName: UserAccountManager.didRefreshToken, object: nil, queue: .main) { _ in
            notificationCount += 1
        }

        let completion1 = expectation(description: "Completion 1")
        let completion2 = expectation(description: "Completion 2")
        let completion3 = expectation(description: "Completion 3")

        coordinator.refreshSession(forCredentials: credentials, completion: { _ in
            completion1.fulfill()
        }, error: { error in
            XCTFail("Error on refresh #1: \(error.localizedDescription)")
        })

        coordinator.refreshSession(forCredentials: credentials, completion: { _ in
            completion2.fulfill()
        }, error: { error in
            XCTFail("Error on refresh #2: \(error.localizedDescription)")
        })

        coordinator.refreshSession(forCredentials: credentials, completion: { _ in
            completion3.fulfill()
        }, error: { error in
            XCTFail("Error on refresh #3: \(error.localizedDescription)")
        })

        waitForExpectations(timeout: 2.0, handler: nil)

        // Give run loop a tick to deliver any additional notifications
        let drain = expectation(description: "Drain runloop")
        DispatchQueue.main.asyncAfter(deadline: .now() + kDispatchDelay) {
            XCTAssertEqual(notificationCount, 1, "Notification should fire exactly once for one refresh, regardless of waiter count")
            drain.fulfill()
        }
        waitForExpectations(timeout: 2.0, handler: nil)

        NotificationCenter.default.removeObserver(observer)
    }

    // MARK: - Coalescing Tests

    func testMultipleCallersAllReceiveError() {
        let error1 = expectation(description: "Error 1")
        let error2 = expectation(description: "Error 2")
        let expectedError = NSError(domain: "test", code: 99, userInfo: nil)

        // Force the refresher to fail on the next call
        mockRefresher.forcedError = expectedError

        coordinator.refreshSession(forCredentials: credentials, completion: { _ in
            XCTFail("Completion 1")
        }, error: { error in
            XCTAssertEqual((error as NSError).code, 99)
            error1.fulfill()
        })

        coordinator.refreshSession(forCredentials: credentials, completion: { _ in
            XCTFail("Completion 2")
        }, error: { error in
            XCTAssertEqual((error as NSError).code, 99)
            error2.fulfill()
        })

        waitForExpectations(timeout: 2.0, handler: nil)
    }

    // MARK: - Independent Credentials Tests

    func testDifferentCredentialsRefreshIndependently() {
        let identifier2 = "TestCreds2_\(arc4random())"
        guard let credentials2 = OAuthCredentials.credentials(identifier: identifier2, clientId: "TestClient2", encrypted: true) else {
            XCTFail("Failed to create credentials2")
            return
        }
        credentials2.refreshToken = "refresh_token_2"
        credentials2.accessToken = "access_token_2"
        credentials2.instanceUrl = URL(string: "https://test2.salesforce.com")
        credentials2.redirectUri = "testapp2://callback"

        var factoryCallCount = 0
        var refresher1: SingleUseTokenMockRefresher?
        var refresher2: SingleUseTokenMockRefresher?

        coordinator.refresherFactory = { creds in
            factoryCallCount += 1
            let refresher = SingleUseTokenMockRefresher(internalCredentials: creds)
            refresher.validRefreshToken = creds.refreshToken
            if factoryCallCount == 1 {
                refresher1 = refresher
            } else {
                refresher2 = refresher
            }
            return refresher
        }

        let comp1 = expectation(description: "Completion for creds 1")
        let comp2 = expectation(description: "Completion for creds 2")

        coordinator.refreshSession(forCredentials: credentials, completion: { _ in
            comp1.fulfill()
        }, error: { error in
            XCTFail("Error on refresh #1: \(error.localizedDescription)")
        })

        coordinator.refreshSession(forCredentials: credentials2, completion: { _ in
            comp2.fulfill()
        }, error: { error in
            XCTFail("Error on refresh #2: \(error.localizedDescription)")
        })

        waitForExpectations(timeout: 2.0, handler: nil)

        XCTAssertEqual(factoryCallCount, 2, "Two different credentials should create two refreshers")
        XCTAssertEqual(refresher1?.refreshCallCount, 1)
        XCTAssertEqual(refresher2?.refreshCallCount, 1)
        credentials2.revoke()
    }

    // MARK: - Thread Safety Stress Test

    func testConcurrentCallsDoNotCrashAndCoalesce() {
        let allDone = expectation(description: "All concurrent calls completed")
        allDone.expectedFulfillmentCount = 50

        for _ in 0..<50 {
            DispatchQueue.global(qos: .default).async {
                self.coordinator.refreshSession(forCredentials: self.credentials, completion: { _ in
                    allDone.fulfill()
                }, error: { error in
                    XCTFail("Error on refresh: \(error.localizedDescription)")
                })
            }
        }

        waitForExpectations(timeout: 5.0, handler: nil)

        XCTAssertEqual(mockRefresher.refreshCallCount, 1,
                       "Only one refresh should have been initiated despite 50 concurrent calls")
    }

    // MARK: - Rotating Refresh Token Tests

    /// Verifies that concurrent callers are coalesced into a single refresh call,
    /// consuming the token exactly once. If coalescing failed and a second refresh
    /// were attempted, the now-stale token would trigger invalid_grant.
    func testConcurrentRefreshWithSingleUseTokenSucceedsBecauseCoalesced() {
        let completion1 = expectation(description: "Caller 1 completes")
        let completion2 = expectation(description: "Caller 2 completes")
        let completion3 = expectation(description: "Caller 3 completes")

        coordinator.refreshSession(forCredentials: credentials, completion: { updated in
            XCTAssertNotNil(updated.accessToken)
            completion1.fulfill()
        }, error: { error in
            XCTFail("Caller 1 should not fail (coalesced): \(error)")
        })

        coordinator.refreshSession(forCredentials: credentials, completion: { updated in
            XCTAssertNotNil(updated.accessToken)
            completion2.fulfill()
        }, error: { error in
            XCTFail("Caller 2 should not fail (coalesced): \(error)")
        })

        coordinator.refreshSession(forCredentials: credentials, completion: { updated in
            XCTAssertNotNil(updated.accessToken)
            completion3.fulfill()
        }, error: { error in
            XCTFail("Caller 3 should not fail (coalesced): \(error)")
        })

        waitForExpectations(timeout: 2.0, handler: nil)

        XCTAssertEqual(mockRefresher.refreshCallCount, 1,
                       "Only one refresh call should have been made — the token was consumed exactly once")
    }

    /// Verifies that after a successful refresh rotates the token, the next refresh
    /// cycle uses the rotated token rather than the stale original.
    func testSequentialRefreshUsesRotatedTokenNotStale() {
        let originalRefreshToken = credentials.refreshToken // "test_refresh_token"

        // --- Cycle 1: consumes the original token, rotates it ---
        let cycle1Done = expectation(description: "Cycle 1 complete")

        coordinator.refreshSession(forCredentials: credentials, completion: { updated in
            XCTAssertNotNil(updated.accessToken)
            XCTAssertNotNil(updated.refreshToken)
            cycle1Done.fulfill()
        }, error: { error in
            XCTFail("Cycle 1 should not fail: \(error)")
        })

        waitForExpectations(timeout: 2.0, handler: nil)

        // The original token is now dead — reusing it would trigger invalid_grant
        XCTAssertNotEqual(credentials.refreshToken, originalRefreshToken,
                          "Original token should be consumed and rotated")
        let cycle1Token = credentials.refreshToken

        // --- Cycle 2: must use the rotated token, not the original ---
        let cycle2Done = expectation(description: "Cycle 2 complete")

        coordinator.refreshSession(forCredentials: credentials, completion: { updated in
            XCTAssertNotNil(updated.accessToken)
            cycle2Done.fulfill()
        }, error: { error in
            XCTFail("Cycle 2 should not fail — but WOULD fail with invalid_grant if the stale original token was presented instead of the rotated one. Error: \(error)")
        })

        waitForExpectations(timeout: 2.0, handler: nil)

        XCTAssertNotEqual(credentials.refreshToken, cycle1Token,
                          "Token should have rotated again in cycle 2")
        XCTAssertEqual(mockRefresher.refreshCallCount, 2,
                       "Two sequential cycles should each make exactly one refresh call")
    }

    // MARK: - Nil Identifier Test

    func testNilIdentifierCredentialsReturnsError() {
        let nilIdCreds = OAuthCredentials()

        let errorExp = expectation(description: "Error for nil identifier")

        coordinator.refreshSession(forCredentials: nilIdCreds, completion: { _ in
            XCTFail("Should not succeed")
        }, error: { error in
            XCTAssertNotNil(error)
            errorExp.fulfill()
        })

        waitForExpectations(timeout: 2.0, handler: nil)
    }

    // MARK: - Integration Test (Mock at authClient level)

    func testIntegrationSingleNetworkCallForConcurrentRefreshes() {
        // This test verifies that when multiple callers go through
        // SFUserAccountManager.refreshCredentials: concurrently,
        // only ONE network call (accessTokenForRefresh:) is made.

        // Use the real coordinator singleton for this test
        let realCoordinator = SFSDKTokenRefreshCoordinator.shared

        // Inject a mock authClient that counts calls
        let mockClient = MockAuthClient()
        let originalFactory = UserAccountManager.shared.authClient
        UserAccountManager.shared.authClient = { mockClient }

        // Use the real refresher (not our test mock) to exercise the full path
        realCoordinator.refresherFactory = nil

        // Create credentials for this integration test
        let integrationId = "IntegrationCreds_\(arc4random())"
        guard let integrationCreds = OAuthCredentials.credentials(identifier: integrationId, clientId: "IntegClientId", encrypted: true) else {
            XCTFail("Failed to create integration credentials")
            return
        }
        integrationCreds.refreshToken = "integration_refresh_token"
        integrationCreds.accessToken = "old_access_token"
        integrationCreds.instanceUrl = URL(string: "https://test.salesforce.com")
        integrationCreds.redirectUri = "testapp://callback"

        let allDone = expectation(description: "All concurrent refreshes completed")
        allDone.expectedFulfillmentCount = 5

        // Fire 5 concurrent refreshes through the coordinator
        for _ in 0..<5 {
            DispatchQueue.global(qos: .default).async {
                realCoordinator.refreshSession(forCredentials: integrationCreds, completion: { updated in
                    XCTAssertEqual(updated.accessToken, "integration_new_access_token")
                    allDone.fulfill()
                }, error: { error in
                    XCTFail("Integration refresh should not fail: \(error)")
                    allDone.fulfill()
                })
            }
        }

        waitForExpectations(timeout: 5.0, handler: nil)

        // Guard: verify the mock was actually exercised (not vacuously passing)
        XCTAssertGreaterThan(mockClient.accessTokenForRefreshCallCount, 0,
                             "Mock authClient was never called — the test is not exercising the intended path")
        // THE KEY ASSERTION: Only one network call was made
        XCTAssertEqual(mockClient.accessTokenForRefreshCallCount, 1,
                       "Only one accessTokenForRefresh: call should have been made despite 5 concurrent callers")

        // Cleanup
        UserAccountManager.shared.authClient = originalFactory
        realCoordinator.refresherFactory = nil
        integrationCreds.revoke()
    }
}
