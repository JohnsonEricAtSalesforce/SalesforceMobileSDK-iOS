//
//  SFSDKErrorManagerTests.swift
//  SalesforceSDKCoreTests
//
//  Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.
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

class SFSDKErrorManagerTests: XCTestCase {

    private var origCurrentUser: UserAccount?

    override func setUp() {
        super.setUp()
        origCurrentUser = UserAccountManager.shared.currentUserAccount
    }

    override func tearDown() {
        super.tearDown()
        UserAccountManager.shared.setCurrentUserInternal(origCurrentUser)
    }

    func testNetworkError() {
        let errorManager = SFSDKAuthErrorManager()

        let credentials = TestSetupUtils.newClientCredentials()
        credentials.accessToken = "__ACCESS_TOKEN__"
        credentials.refreshToken = "__REFRESH_TOKEN__"
        credentials.userId = "USER123"
        credentials.organizationId = "ORG123"

        let account = UserAccount(credentials: credentials)
        _ = UserAccountManager.shared.upsert(account)
        UserAccountManager.shared.setCurrentUserInternal(account)
        let request = SFSDKAuthRequest()
        let session = SFSDKAuthSession(with: request, credentials: credentials, spAppCredentials: nil)
        session.oauthCoordinator.authInfo = SFOAuthInfo(authType: .refresh)

        XCTAssertNotNil(errorManager)
        let networkErrorExpectation = expectation(description: "networkErrorExpectation")
        let userInfo: [String: Any] = [:]
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: userInfo)

        errorManager.networkErrorHandlerBlock = { error, authSession, options in
            networkErrorExpectation.fulfill()
        }

        XCTAssertNotNil(errorManager.networkErrorHandlerBlock)
        let handled = errorManager.processAuthError(error, authContext: session, options: userInfo as NSDictionary)
        XCTAssertTrue(handled, "Network Error Should have been handled by the ErrorManager")
        _ = UserAccountManager.shared.delete(account)
        waitForExpectations(timeout: 20.0, handler: nil)
    }

    func testAuthError() {
        let errorManager = SFSDKAuthErrorManager()
        let authSession = SFSDKAuthSession(with: SFSDKAuthRequest(), credentials: nil)
        XCTAssertNotNil(errorManager)
        let errorExpectation = expectation(description: "authErrorExpectation")
        let userInfo: [String: Any] = [:]
        let error = NSError(domain: kSFOAuthErrorDomain, code: kSFOAuthErrorInvalidGrant, userInfo: userInfo)

        errorManager.invalidAuthCredentialsErrorHandlerBlock = { error, authSession, options in
            errorExpectation.fulfill()
        }
        XCTAssertNotNil(errorManager.invalidAuthCredentialsErrorHandlerBlock)
        let handled = errorManager.processAuthError(error, authContext: authSession, options: userInfo as NSDictionary)
        XCTAssertTrue(handled, "Invalid grant auth error Should have been handled by the ErrorManager")
        waitForExpectations(timeout: 20.0, handler: nil)
    }

    func testAuthErrorConvenienceClassMethod() {
        let userInfo: [String: Any] = [:]
        let error = NSError(domain: kSFOAuthErrorDomain, code: kSFOAuthErrorInvalidGrant, userInfo: userInfo)
        XCTAssertTrue(SFSDKAuthErrorManager.errorIsInvalidAuthCredentials(error), "Should be a valid auth error handled by the ErrorManager")
    }

    func testConnectedAppVersionMismatchError() {
        let errorManager = SFSDKAuthErrorManager()
        let authSession = SFSDKAuthSession(with: SFSDKAuthRequest(), credentials: nil)
        XCTAssertNotNil(errorManager)
        let errorExpectation = expectation(description: "connectedAppVersionMismatchErrorExpectation")
        let userInfo: [String: Any] = [:]
        let error = NSError(domain: kSFOAuthErrorDomain, code: kSFOAuthErrorWrongVersion, userInfo: userInfo)

        errorManager.connectedAppVersionMismatchErrorHandlerBlock = { error, authSession, options in
            errorExpectation.fulfill()
        }
        XCTAssertNotNil(errorManager.connectedAppVersionMismatchErrorHandlerBlock)
        let handled = errorManager.processAuthError(error, authContext: authSession, options: userInfo as NSDictionary)
        XCTAssertTrue(handled, "Connected app version mismatch should have been handled by the ErrorManager")
        waitForExpectations(timeout: 20.0, handler: nil)
    }

    func testGenericError() {
        let errorManager = SFSDKAuthErrorManager()
        let authSession = SFSDKAuthSession(with: SFSDKAuthRequest(), credentials: nil)
        XCTAssertNotNil(errorManager)
        let errorExpectation = expectation(description: "genericErrorExpectation")
        let userInfo: [String: Any] = [:]
        let error = NSError(domain: "someError", code: -999, userInfo: userInfo)

        errorManager.genericErrorHandlerBlock = { error, authSession, options in
            errorExpectation.fulfill()
        }

        XCTAssertNotNil(errorManager.genericErrorHandlerBlock)
        let handled = errorManager.processAuthError(error, authContext: authSession, options: userInfo as NSDictionary)
        XCTAssertTrue(handled, "Generic Error should have been handled by the ErrorManager")
        waitForExpectations(timeout: 20.0, handler: nil)
    }

    // MARK: - Host connection classifier tests

    /// Shared helper: assert that the host connection handler claims a bare NSError
    /// (no CFStream keys) constructed with the given domain and code, when the
    /// session is not a Refresh-with-existing-token flow.
    private func assertHostConnectionClaims(domain: String, code: Int, description: String) {
        let errorManager = SFSDKAuthErrorManager()
        let authSession = SFSDKAuthSession(with: SFSDKAuthRequest(), credentials: nil)
        let expectation = expectation(description: description)
        let userInfo: [String: Any] = [:]
        let error = NSError(domain: domain, code: code, userInfo: userInfo)

        errorManager.hostConnectionErrorHandlerBlock = { _, _, _ in
            expectation.fulfill()
        }
        let handled = errorManager.processAuthError(error, authContext: authSession, options: userInfo as NSDictionary)
        XCTAssertTrue(handled, "Host connection error should have been handled by the ErrorManager")
        waitForExpectations(timeout: 20.0, handler: nil)
    }

    // NSURLErrorDomain host-connection codes with NO CFStream keys claim the host handler.
    // This is the iOS 26 shape — DNS resolution moved to Network.framework, so the legacy
    // _kCFStreamError* keys are absent from top-level userInfo.
    func testHostConnectionError_NSURLErrorCannotFindHost() {
        assertHostConnectionClaims(domain: NSURLErrorDomain, code: NSURLErrorCannotFindHost, description: "hostConnectionExpectation_CannotFindHost")
    }

    func testHostConnectionError_NSURLErrorDNSLookupFailed() {
        assertHostConnectionClaims(domain: NSURLErrorDomain, code: NSURLErrorDNSLookupFailed, description: "hostConnectionExpectation_DNSLookupFailed")
    }

    func testHostConnectionError_NSURLErrorCannotConnectToHost() {
        assertHostConnectionClaims(domain: NSURLErrorDomain, code: NSURLErrorCannotConnectToHost, description: "hostConnectionExpectation_CannotConnectToHost")
    }

    func testHostConnectionError_NSURLErrorTimedOut() {
        assertHostConnectionClaims(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, description: "hostConnectionExpectation_TimedOut")
    }

    func testHostConnectionError_NSURLErrorNotConnectedToInternet() {
        assertHostConnectionClaims(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet, description: "hostConnectionExpectation_NotConnectedToInternet")
    }

    func testHostConnectionError_NSURLErrorNetworkConnectionLost() {
        assertHostConnectionClaims(domain: NSURLErrorDomain, code: NSURLErrorNetworkConnectionLost, description: "hostConnectionExpectation_NetworkConnectionLost")
    }

    // Legacy iOS <= 18 shape — NSURLErrorDomain / -1003 with CFStream keys in userInfo — still claimed.
    func testHostConnectionError_LegacyCFStreamKeys() {
        let errorManager = SFSDKAuthErrorManager()
        let authSession = SFSDKAuthSession(with: SFSDKAuthRequest(), credentials: nil)
        let expectation = expectation(description: "hostConnectionExpectation_LegacyCFStreamKeys")
        let userInfo: [String: Any] = ["_kCFStreamErrorCodeKey": 8, "_kCFStreamErrorDomainKey": 12]
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotFindHost, userInfo: userInfo)

        errorManager.hostConnectionErrorHandlerBlock = { _, _, _ in
            expectation.fulfill()
        }
        let handled = errorManager.processAuthError(error, authContext: authSession, options: userInfo as NSDictionary)
        XCTAssertTrue(handled, "Legacy CFStream-shaped host connection error should have been handled by the ErrorManager")
        waitForExpectations(timeout: 20.0, handler: nil)
    }

    // kSFOAuthErrorInvalidURL still claimed by the host handler.
    func testHostConnectionError_SFOAuthInvalidURL() {
        let errorManager = SFSDKAuthErrorManager()
        let authSession = SFSDKAuthSession(with: SFSDKAuthRequest(), credentials: nil)
        let expectation = expectation(description: "hostConnectionExpectation_SFOAuthInvalidURL")
        let userInfo: [String: Any] = [:]
        let error = NSError(domain: kSFOAuthErrorDomain, code: kSFOAuthErrorInvalidURL, userInfo: userInfo)

        errorManager.hostConnectionErrorHandlerBlock = { _, _, _ in
            expectation.fulfill()
        }
        let handled = errorManager.processAuthError(error, authContext: authSession, options: userInfo as NSDictionary)
        XCTAssertTrue(handled, "kSFOAuthErrorInvalidURL should have been handled by the ErrorManager host connection handler")
        waitForExpectations(timeout: 20.0, handler: nil)
    }

    // Unrelated NSURLErrorDomain codes are not host-connectivity — fall through to generic.
    func testGenericError_Cancelled() {
        let errorManager = SFSDKAuthErrorManager()
        let authSession = SFSDKAuthSession(with: SFSDKAuthRequest(), credentials: nil)
        let expectation = expectation(description: "genericErrorExpectation_Cancelled")
        let userInfo: [String: Any] = [:]
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled, userInfo: userInfo)

        errorManager.hostConnectionErrorHandlerBlock = { _, _, _ in
            XCTFail("Cancelled error must not be claimed by the host connection handler")
        }
        errorManager.genericErrorHandlerBlock = { _, _, _ in
            expectation.fulfill()
        }
        let handled = errorManager.processAuthError(error, authContext: authSession, options: userInfo as NSDictionary)
        XCTAssertTrue(handled, "Cancelled error should have been handled by the generic handler")
        waitForExpectations(timeout: 20.0, handler: nil)
    }

    func testGenericError_UserAuthRequired() {
        let errorManager = SFSDKAuthErrorManager()
        let authSession = SFSDKAuthSession(with: SFSDKAuthRequest(), credentials: nil)
        let expectation = expectation(description: "genericErrorExpectation_UserAuthRequired")
        let userInfo: [String: Any] = [:]
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorUserAuthenticationRequired, userInfo: userInfo)

        errorManager.hostConnectionErrorHandlerBlock = { _, _, _ in
            XCTFail("UserAuthenticationRequired must not be claimed by the host connection handler")
        }
        errorManager.genericErrorHandlerBlock = { _, _, _ in
            expectation.fulfill()
        }
        let handled = errorManager.processAuthError(error, authContext: authSession, options: userInfo as NSDictionary)
        XCTAssertTrue(handled, "UserAuthenticationRequired error should have been handled by the generic handler")
        waitForExpectations(timeout: 20.0, handler: nil)
    }

    // kSFOAuthErrorInvalidGrant must not be claimed by the host connection handler.
    func testHostConnectionDoesNotClaim_SFOAuthInvalidGrant() {
        let errorManager = SFSDKAuthErrorManager()
        let authSession = SFSDKAuthSession(with: SFSDKAuthRequest(), credentials: nil)
        let expectation = expectation(description: "invalidGrantExpectation")
        let userInfo: [String: Any] = [:]
        let error = NSError(domain: kSFOAuthErrorDomain, code: kSFOAuthErrorInvalidGrant, userInfo: userInfo)

        errorManager.hostConnectionErrorHandlerBlock = { _, _, _ in
            XCTFail("kSFOAuthErrorInvalidGrant must not be claimed by the host connection handler")
        }
        errorManager.invalidAuthCredentialsErrorHandlerBlock = { _, _, _ in
            expectation.fulfill()
        }
        let handled = errorManager.processAuthError(error, authContext: authSession, options: userInfo as NSDictionary)
        XCTAssertTrue(handled, "kSFOAuthErrorInvalidGrant should have been handled by the invalid credentials handler")
        waitForExpectations(timeout: 20.0, handler: nil)
    }

    // On a Refresh flow with an existing access token, the network handler still
    // claims -1001 TimedOut before the host connection handler sees it.
    func testNetworkFailureClaimsFirst_RefreshWithToken() {
        let errorManager = SFSDKAuthErrorManager()

        let credentials = TestSetupUtils.newClientCredentials()
        credentials.accessToken = "__ACCESS_TOKEN__"
        credentials.refreshToken = "__REFRESH_TOKEN__"
        credentials.userId = "USER123"
        credentials.organizationId = "ORG123"

        let account = UserAccount(credentials: credentials)
        _ = UserAccountManager.shared.upsert(account)
        UserAccountManager.shared.setCurrentUserInternal(account)
        let request = SFSDKAuthRequest()
        let session = SFSDKAuthSession(with: request, credentials: credentials, spAppCredentials: nil)
        session.oauthCoordinator.authInfo = SFOAuthInfo(authType: .refresh)

        let networkErrorExpectation = expectation(description: "networkErrorExpectation_RefreshWithToken")
        let userInfo: [String: Any] = [:]
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: userInfo)

        errorManager.networkErrorHandlerBlock = { _, _, _ in
            networkErrorExpectation.fulfill()
        }
        errorManager.hostConnectionErrorHandlerBlock = { _, _, _ in
            XCTFail("Host connection handler must not claim network errors on Refresh-with-token flows")
        }

        let handled = errorManager.processAuthError(error, authContext: session, options: userInfo as NSDictionary)
        XCTAssertTrue(handled, "Network Error Should have been handled by the ErrorManager on Refresh flow")
        waitForExpectations(timeout: 20.0, handler: nil)
        _ = UserAccountManager.shared.delete(account)
    }

    // MARK: - errorIsHostConnectionFailure predicate

    // The shared predicate is the single source of truth for what counts as a
    // host-connection failure. Both the classifier block and SFOAuthCoordinator's
    // auth-config prefetch callback consult it, so exercising it directly guards
    // both call sites against silent classification drift.

    func testErrorIsHostConnectionFailure_NilAndEmptyDomain() {
        XCTAssertFalse(SFSDKAuthErrorManager.errorIsHostConnectionFailure(nil))
        // A truly nil domain cannot be constructed here: NSError(domain:code:userInfo:)
        // raises NSInvalidArgumentException on a nil domain. The nil-domain branch in
        // errorIsHostConnectionFailure(_:) is exercised only via the nil-error path
        // above; an empty-string domain covers the "unknown foreign domain" fallthrough.
        let emptyDomain = NSError(domain: "", code: 0, userInfo: nil)
        XCTAssertFalse(SFSDKAuthErrorManager.errorIsHostConnectionFailure(emptyDomain))
    }

    func testErrorIsHostConnectionFailure_LegacyCFStreamKeys() {
        let error = NSError(domain: NSURLErrorDomain,
                            code: NSURLErrorCannotFindHost,
                            userInfo: ["_kCFStreamErrorCodeKey": 8, "_kCFStreamErrorDomainKey": 12])
        XCTAssertTrue(SFSDKAuthErrorManager.errorIsHostConnectionFailure(error))
    }

    func testErrorIsHostConnectionFailure_SFOAuthInvalidURL() {
        let error = NSError(domain: kSFOAuthErrorDomain, code: kSFOAuthErrorInvalidURL, userInfo: nil)
        XCTAssertTrue(SFSDKAuthErrorManager.errorIsHostConnectionFailure(error))
    }

    func testErrorIsHostConnectionFailure_ModernNSURLCodes() {
        let codes = [NSURLErrorCannotFindHost,
                     NSURLErrorDNSLookupFailed,
                     NSURLErrorCannotConnectToHost,
                     NSURLErrorTimedOut,
                     NSURLErrorNotConnectedToInternet,
                     NSURLErrorNetworkConnectionLost]
        for code in codes {
            let error = NSError(domain: NSURLErrorDomain, code: code, userInfo: nil)
            XCTAssertTrue(SFSDKAuthErrorManager.errorIsHostConnectionFailure(error),
                          "Expected NSURLError \(code) to be classified as a host connection failure")
        }
    }

    func testErrorIsHostConnectionFailure_UnrelatedCodesReturnNO() {
        let cancelled = NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled, userInfo: nil)
        XCTAssertFalse(SFSDKAuthErrorManager.errorIsHostConnectionFailure(cancelled))

        let userAuth = NSError(domain: NSURLErrorDomain, code: NSURLErrorUserAuthenticationRequired, userInfo: nil)
        XCTAssertFalse(SFSDKAuthErrorManager.errorIsHostConnectionFailure(userAuth))

        let invalidGrant = NSError(domain: kSFOAuthErrorDomain, code: kSFOAuthErrorInvalidGrant, userInfo: nil)
        XCTAssertFalse(SFSDKAuthErrorManager.errorIsHostConnectionFailure(invalidGrant))

        let foreign = NSError(domain: "com.example.some-other-domain", code: -1001, userInfo: nil)
        XCTAssertFalse(SFSDKAuthErrorManager.errorIsHostConnectionFailure(foreign))
    }
}
