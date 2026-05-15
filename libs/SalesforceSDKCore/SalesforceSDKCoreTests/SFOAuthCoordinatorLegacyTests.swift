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

final class SFOAuthCoordinatorLegacyTests: XCTestCase {

    func testMigrateRefreshTokenSetup() {
        // Create test credentials
        let credentials = OAuthCredentials(identifier: "testIdentifier", clientId: "testClientId", encrypted: false)
        credentials.redirectUri = "testapp://callback"
        credentials.setValue("test.salesforce.com", forKey: "domain")
        credentials.accessToken = "testAccessToken"
        credentials.refreshToken = "testRefreshToken"
        credentials.instanceUrl = URL(string: "https://test.salesforce.com")

        // Create a test user account
        let userAccount = UserAccount(credentials: credentials)

        // Create auth request and session
        let authRequest = AuthRequest()
        authRequest.oauthClientId = "newClientId"
        authRequest.oauthCompletionUrl = "newapp://callback"
        authRequest.loginHost = "login.salesforce.com"

        let authSession = AuthSession(with: authRequest, credentials: nil)

        // Track whether callbacks are invoked
        var failureCallbackInvoked = false
        var capturedAuthInfo: SFOAuthInfo?
        var capturedError: NSError?

        authSession.authFailureCallback = { authInfo, error in
            failureCallbackInvoked = true
            capturedAuthInfo = authInfo
            capturedError = error
        }

        // Create coordinator
        let coordinator = SFOAuthCoordinator(authSession: authSession)
        coordinator.credentials = credentials

        // Verify initial state
        XCTAssertNotNil(coordinator.credentials)
        XCTAssertEqual(coordinator.credentials?.clientId, "testClientId")

        // Call migrateRefreshToken - this will attempt to make a REST API call
        // which will fail because the user is not properly logged in
        coordinator.migrateRefreshToken(userAccount)

        // Wait a bit for the async failure callback
        let waitExpectation = expectation(description: "Wait for failure callback")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            waitExpectation.fulfill()
        }
        wait(for: [waitExpectation], timeout: 2.0)

        // Verify that the auth info was set to the correct type
        XCTAssertNotNil(coordinator.authInfo, "Auth info should be set")
        XCTAssertEqual(coordinator.authInfo.authType, .refreshTokenMigration, "Auth type should be refresh token migration")

        // Verify initialRequestLoaded was set to false
        XCTAssertFalse(coordinator.initialRequestLoaded, "Initial request loaded should be false")

        // Verify the failure callback was invoked
        XCTAssertTrue(failureCallbackInvoked, "Failure callback should be invoked when REST API fails")
        XCTAssertNotNil(capturedError, "Should have captured an error")
        XCTAssertEqual(capturedAuthInfo?.authType, .refreshTokenMigration, "AuthInfo type should be refresh token migration")
    }
}
