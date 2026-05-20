//
//  SDSDKAlertMessageTest.swift
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

class SDSDKAlertMessageTest: XCTestCase {

    func testMessageCreate() {
        let alertTitle = "Title"
        let buttonOneTitle = "ButtonOne"
        let buttonTwoTitle = "ButtonTwo"
        let alertMessage = "Message for the alert"

        let message = AlertMessage.message { builder in
            builder.alertTitle = alertTitle
            builder.actionOneTitle = buttonOneTitle
            builder.actionTwoTitle = buttonTwoTitle
            builder.alertMessage = alertMessage
        }

        XCTAssertNotNil(message)
        XCTAssertEqual(message.alertTitle, alertTitle)
        XCTAssertEqual(message.actionOneTitle, buttonOneTitle)
        XCTAssertEqual(message.actionTwoTitle, buttonTwoTitle)
        XCTAssertEqual(message.alertMessage, alertMessage)
    }

    func testMessageCreateWithCompletionBlocks() {
        let alertTitle = "Title"
        let buttonOneTitle = "ButtonOne"
        let buttonTwoTitle = "ButtonTwo"
        let alertMessage = "Message for the alert"

        let expectationOne = expectation(description: "messageActionOne")
        let expectationTwo = expectation(description: "messageActionTwo")

        let message = AlertMessage.message { builder in
            builder.alertTitle = alertTitle
            builder.actionOneTitle = buttonOneTitle
            builder.actionTwoTitle = buttonTwoTitle
            builder.alertMessage = alertMessage
            builder.actionOneCompletion = {
                expectationOne.fulfill()
            }
            builder.actionTwoCompletion = {
                expectationTwo.fulfill()
            }
        }

        XCTAssertNotNil(message)
        XCTAssertNotNil(message.actionOneCompletion)
        message.actionOneCompletion?()
        XCTAssertNotNil(message.actionTwoCompletion)
        message.actionTwoCompletion?()
        waitForExpectations(timeout: 20.0, handler: nil)
    }

    func testAlertViewCreate() {
        let alertTitle = "Title"
        let buttonOneTitle = "ButtonOne"
        let buttonTwoTitle = "ButtonTwo"
        let alertMessage = "Message for the alert"

        let message = AlertMessage.message { builder in
            builder.alertTitle = alertTitle
            builder.actionOneTitle = buttonOneTitle
            builder.actionTwoTitle = buttonTwoTitle
            builder.alertMessage = alertMessage
            builder.actionOneCompletion = {}
            builder.actionTwoCompletion = {}
        }

        let authWindow = SFSDKWindowManager.shared.authWindow(nil)
        let view = SFSDKAlertView(message: message, window: authWindow)
        XCTAssertNotNil(view)
        XCTAssertNotNil(view.controller)
        XCTAssertNotNil(view.window)
        XCTAssertTrue(view.window === authWindow)
    }
}
