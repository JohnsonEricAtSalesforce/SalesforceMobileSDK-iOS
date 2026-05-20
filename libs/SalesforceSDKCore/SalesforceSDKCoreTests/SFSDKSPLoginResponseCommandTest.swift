//
//  SFSDKSPLoginResponseCommandTest.swift
//  SalesforceSDKCore
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

class SFSDKSPLoginResponseCommandTest: XCTestCase {

    func testSFSDKSPLoginResponseCommand() {
        let test = SFSDKSPLoginResponseCommand()
        XCTAssertNotNil(test)

        guard let testURL = URL(string: "atest://atest/v1.0/authresponse") else {
            XCTFail("Failed to create test URL")
            return
        }
        XCTAssertTrue(test.isAuthCommand(testURL))

        guard let uppercaseURL = URL(string: "atest://atest/v1.0/authresponse".uppercased()) else {
            XCTFail("Failed to create uppercase test URL")
            return
        }
        XCTAssertTrue(test.isAuthCommand(uppercaseURL))
    }

    func testSFSDKSPLoginResponseCommandBadURL() {
        let test = SFSDKSPLoginResponseCommand()
        XCTAssertNotNil(test)

        guard let testURL = URL(string: "atest://atest/authresponse") else {
            XCTFail("Failed to create test URL")
            return
        }
        XCTAssertFalse(test.isAuthCommand(testURL))
    }

    func testSFSDKSPLoginCommandWithParameters() {
        let test = SFSDKSPLoginResponseCommand()
        XCTAssertNotNil(test)
        test.scheme = "scheme"
        test.state = "astate"
        test.authCode = "authCode"

        let requestURL = test.requestURL()

        let test2 = SFSDKSPLoginResponseCommand()
        _ = test2.isAuthCommand(requestURL)
        test2.fromRequestURL(requestURL)

        XCTAssertEqual(test2.authCode, test.authCode, "Auth codes should be the same after decoding")
        XCTAssertEqual(test2.state, test.state, "State should be the same after decoding")
    }
}
