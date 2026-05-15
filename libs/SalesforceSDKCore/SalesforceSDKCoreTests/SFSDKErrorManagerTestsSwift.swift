/*
 Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.

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

final class SFSDKErrorManagerTestsSwift: XCTestCase {

    private var origCurrentUser: SFUserAccount?

    override func setUp() {
        super.setUp()
        origCurrentUser = SFUserAccountManager.shared.currentUserAccount
    }

    override func tearDown() {
        SFUserAccountManager.shared.currentUserAccount = origCurrentUser
        super.tearDown()
    }

    func testNetworkError() {
        let errorManager = SFSDKAuthErrorManager()

        let credentials = OAuthCredentials(identifier: "test-client", clientId: "testClient123", encrypted: false)
        credentials.accessToken = "__ACCESS_TOKEN__"
        credentials.refreshToken = "__REFRESH_TOKEN__"
        credentials.userId = "USER123"
        credentials.organizationId = "ORG123"

        let account = SFUserAccount(credentials: credentials)
        try? SFUserAccountManager.shared.upsert(account)
        SFUserAccountManager.shared.currentUserAccount = account
        let request = AuthRequest()
        let session = SFSDKAuthSession(with: request, credentials: credentials, spAppCredentials: nil)
        session.oauthCoordinator.authInfo = SFOAuthInfo(authType: .refresh)

        XCTAssertNotNil(errorManager)
        let networkErrorExpectation = expectation(description: "networkErrorExpectation")
        let userInfo = [String: Any]()
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: userInfo)

        errorManager.networkErrorHandlerBlock = { error, authSession, options in
            networkErrorExpectation.fulfill()
        }

        XCTAssertNotNil(errorManager.networkErrorHandlerBlock)
        let handled = errorManager.processAuthError(error, authContext: session, options: userInfo)
        XCTAssertTrue(handled, "Network Error Should have been handled by the ErrorManager")
        try? SFUserAccountManager.shared.delete(account)
        waitForExpectations(timeout: 20.0, handler: nil)
    }

    func testAuthError() {
        let errorManager = SFSDKAuthErrorManager()
        let authSession = SFSDKAuthSession(with: AuthRequest())
        XCTAssertNotNil(errorManager)
        let errorExpectation = expectation(description: "authErrorExpectation")
        let userInfo = [String: Any]()
        let error = NSError(domain: kSFOAuthErrorDomain, code: kSFOAuthErrorInvalidGrant, userInfo: userInfo)

        errorManager.invalidAuthCredentialsErrorHandlerBlock = { error, authSession, options in
            errorExpectation.fulfill()
        }
        XCTAssertNotNil(errorManager.invalidAuthCredentialsErrorHandlerBlock)
        let handled = errorManager.processAuthError(error, authContext: authSession, options: userInfo)
        XCTAssertTrue(handled, "Invalid grant auth error Should have been handled by the ErrorManager")
        waitForExpectations(timeout: 20.0, handler: nil)
    }

    func testAuthErrorConvenienceClassMethod() {
        let userInfo = [String: Any]()
        let error = NSError(domain: kSFOAuthErrorDomain, code: kSFOAuthErrorInvalidGrant, userInfo: userInfo)
        XCTAssertTrue(SFSDKAuthErrorManager.errorIsInvalidAuthCredentials(error), "Should be a valid auth error handled by the ErrorManager")
    }

    func testConnectedAppVersionMismatchError() {
        let errorManager = SFSDKAuthErrorManager()
        let authSession = SFSDKAuthSession(with: AuthRequest())
        XCTAssertNotNil(errorManager)
        let errorExpectation = expectation(description: "connectedAppVersionMismatchErrorExpectation")
        let userInfo = [String: Any]()
        let error = NSError(domain: kSFOAuthErrorDomain, code: kSFOAuthErrorWrongVersion, userInfo: userInfo)

        errorManager.connectedAppVersionMismatchErrorHandlerBlock = { error, authSession, options in
            errorExpectation.fulfill()
        }
        XCTAssertNotNil(errorManager.connectedAppVersionMismatchErrorHandlerBlock)
        let handled = errorManager.processAuthError(error, authContext: authSession, options: userInfo)
        XCTAssertTrue(handled, "Connected app version mismatch should have been handled by the ErrorManager")
        waitForExpectations(timeout: 20.0, handler: nil)
    }

    func testGenericError() {
        let errorManager = SFSDKAuthErrorManager()
        let authSession = SFSDKAuthSession(with: AuthRequest())
        XCTAssertNotNil(errorManager)
        let errorExpectation = expectation(description: "genericErrorExpectation")
        let userInfo = [String: Any]()
        let error = NSError(domain: "someError", code: -999, userInfo: userInfo)

        errorManager.genericErrorHandlerBlock = { error, authSession, options in
            errorExpectation.fulfill()
        }

        XCTAssertNotNil(errorManager.genericErrorHandlerBlock)
        let handled = errorManager.processAuthError(error, authContext: authSession, options: userInfo)
        XCTAssertTrue(handled, "Generic Error should have been handled by the ErrorManager")
        waitForExpectations(timeout: 20.0, handler: nil)
    }
}
