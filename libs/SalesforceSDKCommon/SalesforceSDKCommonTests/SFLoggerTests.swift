//
//  SFLoggerTests.swift
//  SalesforceSDKCommon
//
//  Created by Raj Rao on Tue Nov 6 12:04:13 PST 2018.
//
//  Copyright (c) 2018-present, salesforce.com, inc. All rights reserved.
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
@testable import SalesforceSDKCommon

private let kTestDefaultComponent = "TestDefaultComponent"
private let kTestComponent1 = "TestComponent1"
private let kLogNotification = NSNotification.Name("LogNotification")
private let kLogLevelKey = "loglevel"
private let kClassKey = "class"
private let kMessageKey = "message"

// MARK: - TestLoggingImpl

private class TestLoggingImpl: NSObject, SFLogging {
    let componentName: String
    let logger: Any
    var logLevel: SFLogLevel = .default

    required init(component componentName: String) {
        self.componentName = componentName
        self.logger = NSNull()
        super.init()
    }

    func log(_ cls: AnyClass, level: SFLogLevel, message: String) {
        NotificationCenter.default.post(
            name: kLogNotification,
            object: self,
            userInfo: [
                kLogLevelKey: NSNumber(value: level.rawValue),
                kMessageKey: message,
                kClassKey: cls
            ]
        )
    }
}

// MARK: - SFLoggerTests

final class SFLoggerTests: XCTestCase {

    private var origLogLevel: SFLogLevel = .default

    override func setUp() {
        super.setUp()
        SFLogger.setInstanceClass(TestLoggingImpl.self)
        origLogLevel = SFLogger.logger(forComponent: kTestDefaultComponent).level
    }

    override func tearDown() {
        SFLogger.setInstanceClass(SFDefaultLogger.self)
        SFLogger.clearAllComponents()
        super.tearDown()
    }

    /// Test Logger Class is correct
    func testLoggerInstance() {
        let logger = SFLogger.logger(forComponent: kTestDefaultComponent)
        XCTAssertNotNil(logger, "Logger instance should have been created")
        logger.level = .debug
        XCTAssertTrue(logger.level == .debug, "Logger level should be set to debug")
    }

    /// Test Multiple Logger Components
    func testMultipleLoggerComponents() {
        let logger = SFLogger.logger(forComponent: kTestDefaultComponent)
        let anotherLogger = SFLogger.logger(forComponent: kTestComponent1)
        XCTAssertNotNil(logger, "Logger instance should have been created")
        XCTAssertNotNil(anotherLogger, "Component Logger instance should have been created")
        XCTAssertTrue(logger !== anotherLogger, "Should be 2 different instances of logger")
        logger.level = .debug
        XCTAssertTrue(logger.level == .debug, "Logger level should be set to debug")
        XCTAssertTrue(anotherLogger.level == .default, "Component Logger level should not have changed")
    }

    /// Test Log Level debug
    func testLoggerDebugLog() {
        let logger = SFLogger.logger(forComponent: kTestDefaultComponent)
        XCTAssertNotNil(logger, "Logger instance should have been created")
        logger.level = .debug
        XCTAssertTrue(logger.level == .debug, "Logger level should be set to debug")

        let expectation = XCTestExpectation(description: "Log Notification")
        var logLevelUsed: SFLogLevel = .default
        var classUsed: AnyClass?
        var message: String?

        let observer = NotificationCenter.default.addObserver(forName: kLogNotification, object: nil, queue: nil) { note in
            if let userInfo = note.userInfo {
                logLevelUsed = SFLogLevel(rawValue: (userInfo[kLogLevelKey] as! NSNumber).uintValue) ?? .default
                classUsed = userInfo[kClassKey] as? AnyClass
                message = userInfo[kMessageKey] as? String
            }
            expectation.fulfill()
        }

        logger.d(type(of: self), format: "TestDebugStatement %@", "TestValue")
        wait(for: [expectation], timeout: 10)

        XCTAssertTrue(logLevelUsed == .debug, "Log statement should have been at Debug level")
        XCTAssertNotNil(classUsed, "Log statement should have been logged against the class")
        XCTAssertTrue(message != nil && !message!.isEmpty, "Log statement should not be empty")

        NotificationCenter.default.removeObserver(observer)
    }

    /// Test Log Level Info
    func testLoggerInfoLog() {
        let logger = SFLogger.logger(forComponent: kTestDefaultComponent)
        XCTAssertNotNil(logger, "Logger instance should have been created")
        logger.level = .info
        XCTAssertTrue(logger.level == .info, "Logger level should be set to info")

        let expectation = XCTestExpectation(description: "Log Notification")
        var logLevelUsed: SFLogLevel = .default
        var classUsed: AnyClass?
        var message: String?

        let observer = NotificationCenter.default.addObserver(forName: kLogNotification, object: nil, queue: nil) { note in
            if let userInfo = note.userInfo {
                logLevelUsed = SFLogLevel(rawValue: (userInfo[kLogLevelKey] as! NSNumber).uintValue) ?? .default
                classUsed = userInfo[kClassKey] as? AnyClass
                message = userInfo[kMessageKey] as? String
            }
            expectation.fulfill()
        }

        logger.i(type(of: self), format: "TestDebugStatement %@", "TestValue")
        wait(for: [expectation], timeout: 10)

        XCTAssertTrue(logLevelUsed == .info, "Log statement should have been at Info level")
        XCTAssertNotNil(classUsed, "Log statement should have been logged against the class")
        XCTAssertTrue(message != nil && !message!.isEmpty, "Log statement should not be empty")

        NotificationCenter.default.removeObserver(observer)
    }

    /// Test Log Level Error
    func testLoggerErrorLog() {
        let logger = SFLogger.logger(forComponent: kTestDefaultComponent)
        XCTAssertNotNil(logger, "Logger instance should have been created")
        logger.level = .error
        XCTAssertTrue(logger.level == .error, "Logger level should be set to error")

        let expectation = XCTestExpectation(description: "Log Notification")
        var logLevelUsed: SFLogLevel = .default
        var classUsed: AnyClass?
        var message: String?

        let observer = NotificationCenter.default.addObserver(forName: kLogNotification, object: nil, queue: nil) { note in
            if let userInfo = note.userInfo {
                logLevelUsed = SFLogLevel(rawValue: (userInfo[kLogLevelKey] as! NSNumber).uintValue) ?? .default
                classUsed = userInfo[kClassKey] as? AnyClass
                message = userInfo[kMessageKey] as? String
            }
            expectation.fulfill()
        }

        logger.e(type(of: self), format: "TestDebugStatement %@", "TestValue")
        wait(for: [expectation], timeout: 10)

        XCTAssertTrue(logLevelUsed == .error, "Log statement should have been at Error level")
        XCTAssertNotNil(classUsed, "Log statement should have been logged against the class")
        XCTAssertTrue(message != nil && !message!.isEmpty, "Log statement should not be empty")

        NotificationCenter.default.removeObserver(observer)
    }

    /// Test Log Level Fault
    func testLoggerFaultLog() {
        let logger = SFLogger.logger(forComponent: kTestDefaultComponent)
        XCTAssertNotNil(logger, "Logger instance should have been created")
        logger.level = .fault
        XCTAssertTrue(logger.level == .fault, "Logger level should be set to fault")

        let expectation = XCTestExpectation(description: "Log Notification")
        var logLevelUsed: SFLogLevel = .default
        var classUsed: AnyClass?
        var message: String?

        let observer = NotificationCenter.default.addObserver(forName: kLogNotification, object: nil, queue: nil) { note in
            if let userInfo = note.userInfo {
                logLevelUsed = SFLogLevel(rawValue: (userInfo[kLogLevelKey] as! NSNumber).uintValue) ?? .default
                classUsed = userInfo[kClassKey] as? AnyClass
                message = userInfo[kMessageKey] as? String
            }
            expectation.fulfill()
        }

        logger.f(type(of: self), format: "TestDebugStatement %@", "TestValue")
        wait(for: [expectation], timeout: 10)

        XCTAssertTrue(logLevelUsed == .fault, "Log statement should have been at Fault level")
        XCTAssertNotNil(classUsed, "Log statement should have been logged against the class")
        XCTAssertTrue(message != nil && !message!.isEmpty, "Log statement should not be empty")

        NotificationCenter.default.removeObserver(observer)
    }
}
