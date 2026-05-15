/*
 Copyright (c) 2018-present, salesforce.com, inc. All rights reserved.

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

final class SFSDKAuthConfigUtilTestsSwift: XCTestCase {

    private let kSFTestId = "test_id"
    private let kSFTestClientId = "test_client_id"
    private let kSFMyDomainEndpoint = "mobilesdk.my.salesforce.com"
    private let kSFAlternateMyDomainEndpoint = "powerofus.salesforce.com"
    private let kSFAlternateMyDomainLoginURL = "powerofus.salesforce.com/s/login"
    private let kSFSandboxEndpoint = "test.salesforce.com"

    func testGetAuthConfig() {
        let credentials = OAuthCredentials(identifier: kSFTestId, clientId: kSFTestClientId, encrypted: true)
        credentials.setValue(kSFMyDomainEndpoint, forKey: "domain")
        let expect = expectation(description: "testGetAuthConfig")
        SFSDKAuthConfigUtil.getMyDomainAuthConfig({ authConfig, error in
            XCTAssertNil(error, "Error should be nil")
            XCTAssertNotNil(authConfig, "Auth config should not be nil")
            XCTAssertNotNil(authConfig?.authConfigDict, "Auth config dictionary should not be nil")
            expect.fulfill()
        }, loginDomain: credentials.domain!)
        waitForExpectations(timeout: 20, handler: nil)
    }

    func testBrowserBasedLoginEnabled() {
        let credentials = OAuthCredentials(identifier: kSFTestId, clientId: kSFTestClientId, encrypted: true)
        credentials.setValue(kSFMyDomainEndpoint, forKey: "domain")
        let expect = expectation(description: "testBrowserBasedLoginEnabled")
        SFSDKAuthConfigUtil.getMyDomainAuthConfig({ authConfig, error in
            XCTAssertNil(error, "Error should be nil")
            XCTAssertNotNil(authConfig, "Auth config should not be nil")
            XCTAssertNotNil(authConfig?.authConfigDict, "Auth config dictionary should not be nil")
            XCTAssertTrue(authConfig?.useNativeBrowserForAuth ?? false, "Browser based login should be enabled")
            expect.fulfill()
        }, loginDomain: credentials.domain!)
        waitForExpectations(timeout: 20, handler: nil)
    }

    func testGetSSOUrls() {
        let credentials = OAuthCredentials(identifier: kSFTestId, clientId: kSFTestClientId, encrypted: true)
        credentials.setValue(kSFMyDomainEndpoint, forKey: "domain")
        let expect = expectation(description: "testGetSSOUrls")
        SFSDKAuthConfigUtil.getMyDomainAuthConfig({ authConfig, error in
            XCTAssertNil(error, "Error should be nil")
            XCTAssertNotNil(authConfig, "Auth config should not be nil")
            XCTAssertNotNil(authConfig?.authConfigDict, "Auth config dictionary should not be nil")
            XCTAssertNotNil(authConfig?.ssoUrls, "SSO URLs should not be nil")
            XCTAssertEqual(authConfig?.ssoUrls?.count, 1, "SSO URLs should have 1 valid entries")
            expect.fulfill()
        }, loginDomain: credentials.domain!)
        waitForExpectations(timeout: 20, handler: nil)
    }

    func testGetLoginPageUrl() {
        let credentials = OAuthCredentials(identifier: kSFTestId, clientId: kSFTestClientId, encrypted: true)
        credentials.setValue(kSFAlternateMyDomainEndpoint, forKey: "domain")
        let expect = expectation(description: "testGetLoginPageUrl")
        SFSDKAuthConfigUtil.getMyDomainAuthConfig({ authConfig, error in
            XCTAssertNil(error, "Error should be nil")
            XCTAssertNotNil(authConfig, "Auth config should not be nil")
            XCTAssertNotNil(authConfig?.authConfigDict, "Auth config dictionary should not be nil")
            XCTAssertNotNil(authConfig?.loginPageUrl, "Login page URL should not be nil")
            XCTAssertTrue(authConfig?.loginPageUrl?.contains(self.kSFAlternateMyDomainLoginURL) ?? false, "Login page URL should contain correct URL")
            expect.fulfill()
        }, loginDomain: credentials.domain!)
        waitForExpectations(timeout: 20, handler: nil)
    }

    func testGetNoAuthConfig() {
        let credentials = OAuthCredentials(identifier: kSFTestId, clientId: kSFTestClientId, encrypted: true)
        credentials.setValue(kSFSandboxEndpoint, forKey: "domain")
        let expect = expectation(description: "testGetNoAuthConfig")
        SFSDKAuthConfigUtil.getMyDomainAuthConfig({ authConfig, error in
            XCTAssertNil(authConfig, "Auth config should be nil")
            expect.fulfill()
        }, loginDomain: credentials.domain!)
        waitForExpectations(timeout: 20, handler: nil)
    }
}
