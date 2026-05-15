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

final class SFSDKAuthRequestCommandTestSwift: XCTestCase {

    func testSFSDKAuthRequestCommand() {
        let test = SFSDKSPLoginRequestCommand()
        XCTAssertNotNil(test)
        let testURL = "atest://atest/v1.0/authrequest"
        XCTAssertTrue(test.isAuthCommand(URL(string: testURL)!))
        XCTAssertTrue(test.isAuthCommand(URL(string: testURL.uppercased())!))
    }

    func testSFSDKAuthRequestCommandBadURL() {
        let test = SFSDKSPLoginRequestCommand()
        XCTAssertNotNil(test)
        let testURL = "atest://atest/authrequest"
        let url = URL(string: testURL)!
        XCTAssertNotNil(url)
        XCTAssertFalse(test.isAuthCommand(url))
    }

    func testSFSDKAuthRequestCommandWithParameters() {
        let spClientId = "AClientID"
        let spRedirectURI = "anapp://some/oauth/callback"
        let spState = "AState"
        let spChallengeCode = "AChallenge"
        let userHint = "USER:ORG"
        let spAppName = "AnApp"
        let spAppScopes = "Scope1,Scope2"

        let test = SFSDKSPLoginRequestCommand()
        XCTAssertNotNil(test)
        test.spClientId = spClientId
        test.spAppName = spAppName
        test.spCodeChallenge = spChallengeCode
        test.spUserHint = userHint
        test.spRedirectURI = spRedirectURI
        test.spAppScopes = spAppScopes
        test.spState = spState
        test.scheme = "app"
        test.path = "oauth2"

        XCTAssertNotNil(test.requestURL())
        XCTAssertTrue(test.isAuthCommand(test.requestURL()!))

        let test2 = SFSDKSPLoginRequestCommand()
        XCTAssertTrue(test2.isAuthCommand(test.requestURL()!))
        test2.from(requestURL: test.requestURL()!)

        XCTAssertTrue(test2.isAuthCommand(test2.requestURL()!))
        XCTAssertEqual(test2.spAppScopes, test.spAppScopes, "App Scopes should match after decoding")
        XCTAssertEqual(test2.spRedirectURI, test.spRedirectURI, "App RedirectURI should match after decoding")
        XCTAssertEqual(test2.spCodeChallenge, test.spCodeChallenge, "Code Challenge should match after decoding")
        XCTAssertEqual(test2.spUserHint, test.spUserHint, "App userHint should match after decoding")
        XCTAssertEqual(test2.spAppName, test.spAppName, "App Name should match after decoding")
    }
}
