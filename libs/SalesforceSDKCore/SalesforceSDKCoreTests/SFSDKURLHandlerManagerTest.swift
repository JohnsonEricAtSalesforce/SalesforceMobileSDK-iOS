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

class SFSDKURLHandlerManagerTest: XCTestCase {

    func testHandlerManagerNotHandledUrl() {
        let manager = SFSDKURLHandlerManager.sharedInstance
        XCTAssertNotNil(manager)
        guard let url = URL(string: "http://test/test") else {
            XCTFail("Failed to create URL")
            return
        }
        let result = manager.canHandleRequest(url, options: nil)
        XCTAssertFalse(result)
    }

    func testHandlerManagerForAdvancedAuth() {
        let manager = SFSDKURLHandlerManager.sharedInstance
        XCTAssertNotNil(manager)
        guard let url = URL(string: "myapp://test/test/code=666") else {
            XCTFail("Failed to create URL")
            return
        }
        let result = manager.canHandleRequest(url, options: nil)
        XCTAssertTrue(result, "SFSDKURLHandlerManager should be able to consume a valid advanced auth request")
    }

    func testHandlerManagerForAdvancedAuthWithHandler() {
        guard let url = URL(string: "myapp://test/test/code=666") else {
            XCTFail("Failed to create URL")
            return
        }
        let handler = SFSDKAdvancedAuthURLHandler()
        let result = handler.canHandleRequest(url, options: nil)
        XCTAssertTrue(result, "SFSDKURLHandlerManager should be able to consume a valid advanced auth request")
    }

    func testHandlerManagerForAuthError() {
        let manager = SFSDKURLHandlerManager.sharedInstance
        XCTAssertNotNil(manager)
        guard let url = URL(string: "myapp://test/test/code=") else {
            XCTFail("Failed to create URL")
            return
        }
        let result = manager.canHandleRequest(url, options: nil)
        XCTAssertTrue(result, "SFSDKURLHandlerManager should be able to consume a valid advanced auth request")
    }

    func testHandlerManagerForIDPRequest() {
        let manager = SFSDKURLHandlerManager.sharedInstance

        let test = SFSDKSPLoginRequestCommand()
        XCTAssertNotNil(test)
        test.spClientId = "AClientID"
        test.spAppName = "AnApp"
        test.spCodeChallenge = "AChallenge"
        test.spUserHint = "USER:ORG"
        test.spRedirectURI = "anapp://some/oauth/callback"
        test.spAppScopes = "Scope1,Scope2"
        test.spState = "AState"
        test.scheme = "someapp"

        let result = manager.canHandleRequest(test.requestURL(), options: nil)
        XCTAssertTrue(result, "SFSDKURLHandlerManager should be able to consume a valid id p auth request")
    }

    func testHandlerManagerForIDPRequestWithHandler() {
        let handler = SFSDKIDPRequestHandler()

        let test = SFSDKSPLoginRequestCommand()
        XCTAssertNotNil(test)
        test.spClientId = "AClientID"
        test.spAppName = "AnApp"
        test.spCodeChallenge = "AChallenge"
        test.spUserHint = "USER:ORG"
        test.spRedirectURI = "anapp://some/oauth/callback"
        test.spAppScopes = "Scope1,Scope2"
        test.spState = "AState"
        test.scheme = "someapp"

        let result = handler.canHandleRequest(test.requestURL(), options: nil)
        XCTAssertTrue(result, "SFSDKIDPRequestHandler should be able to consume a valid id p auth request")
    }

    func testHandlerManagerForIDPRequestError() {
        let manager = SFSDKURLHandlerManager.sharedInstance

        let test = SFSDKSPLoginRequestCommand()
        XCTAssertNotNil(test)
        test.spClientId = "%@$&7&"
        test.spAppName = "===&&"
        test.spCodeChallenge = ""
        test.spUserHint = "&%20%36^^***"
        test.spRedirectURI = ""
        test.spAppScopes = ""
        test.spState = ""
        test.scheme = "someapp"

        let result = manager.canHandleRequest(test.requestURL(), options: nil)
        XCTAssertTrue(result, "SFSDKURLHandlerManager should be able to consume a valid id p auth request")
    }

    func testHandlerManagerForIDPResponse() {
        let manager = SFSDKURLHandlerManager.sharedInstance

        let test = SFSDKSPLoginResponseCommand()
        XCTAssertNotNil(test)
        test.state = "astate"
        test.authCode = "authCode"
        test.scheme = "anapp"

        let result = manager.canHandleRequest(test.requestURL(), options: nil)
        XCTAssertTrue(result, "SFSDKURLHandlerManager should be able to consume a valid id p auth response")
    }

    func testHandlerManagerForIDPResponseWithHandler() {
        let handler = SFSDKSPLoginResponseHandler()

        let test = SFSDKSPLoginResponseCommand()
        XCTAssertNotNil(test)
        test.state = "astate"
        test.authCode = "authCode"
        test.scheme = "anapp"

        let result = handler.canHandleRequest(test.requestURL(), options: nil)
        XCTAssertTrue(result, "SFIDPResponseHandler should be able to consume a valid id p auth response")
    }

    func testHandlerManagerForIDPError() {
        let manager = SFSDKURLHandlerManager.sharedInstance

        let test = SFSDKAuthErrorCommand()
        XCTAssertNotNil(test)
        test.errorReason = "No%20Reason"
        test.errorCode = "999"
        test.errorDescription = "Aces%20High"
        test.scheme = "anapp"

        let result = manager.canHandleRequest(test.requestURL(), options: nil)
        XCTAssertTrue(result, "SFSDKURLHandlerManager should be able to consume a valid id p auth error")
    }

    func testHandlerManagerForIDPRequestErrorWithHandler() {
        let handler = SFSDKIDPErrorHandler()

        let test = SFSDKAuthErrorCommand()
        XCTAssertNotNil(test)
        test.errorReason = "No%20Reason"
        test.errorCode = "999"
        test.errorDescription = "Aces%20High"
        test.scheme = "anapp"

        let result = handler.canHandleRequest(test.requestURL(), options: nil)
        XCTAssertTrue(result, "SFSDKAuthErrorCommand should be able to consume a valid id p auth error")
    }
}
