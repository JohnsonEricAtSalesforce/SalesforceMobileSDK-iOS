//
//  SFSDKAuthErrorCommandTest.swift
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

class SFSDKAuthErrorCommandTest: XCTestCase {

    func testSFSDKAuthErrorCommand() {
        let test = SFSDKAuthErrorCommand()
        XCTAssertNotNil(test)

        guard let testURL = URL(string: "atest://atest/v1.0/error") else {
            XCTFail("Failed to create test URL")
            return
        }
        XCTAssertTrue(test.isAuthCommand(testURL))

        guard let uppercaseURL = URL(string: "atest://atest/v1.0/error".uppercased()) else {
            XCTFail("Failed to create uppercase test URL")
            return
        }
        XCTAssertTrue(test.isAuthCommand(uppercaseURL))
    }

    func testSFSDKAuthErrorCommandBadURL() {
        let test = SFSDKAuthErrorCommand()
        XCTAssertNotNil(test)

        guard let testURL = URL(string: "atest://atest/error") else {
            XCTFail("Failed to create test URL")
            return
        }
        XCTAssertFalse(test.isAuthCommand(testURL))
    }

    func testSFSDKAuthErrorCommandWithParameters() {
        let errorCode = "999"
        let errorDesc = "Aces%20High"
        let errorReason = "No%20Reason"

        let test = SFSDKAuthErrorCommand()
        XCTAssertNotNil(test)

        let testURLString = "atest://atest/v1.0/error?errorCode=\(errorCode)&errorDescription=\(errorDesc)&errorReason=\(errorReason)"
        guard let testURL = URL(string: testURLString) else {
            XCTFail("Failed to create test URL")
            return
        }

        test.fromRequestURL(testURL)

        XCTAssertNotNil(test.errorCode, "Error Code should not be nil")
        XCTAssertNotNil(test.errorDescription, "Error Description should not be nil")
        XCTAssertEqual(test.errorCode, errorCode, "Error Code should not have changed")
        XCTAssertEqual(test.errorDescription, errorDesc.removingPercentEncoding, "Error Desc should not have changed")
        XCTAssertEqual(test.errorReason, errorReason.removingPercentEncoding, "Error Reason should not have changed")
    }
}
