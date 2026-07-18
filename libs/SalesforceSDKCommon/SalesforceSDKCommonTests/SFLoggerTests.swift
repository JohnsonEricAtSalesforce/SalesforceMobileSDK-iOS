import XCTest
@testable import SalesforceSDKCommon

private let kTestDefaultComponent = "TestDefaultComponent"
private let kTestComponent1 = "TestComponent1"
private let kLogNotification = NSNotification.Name("LogNotification")
private let kLogLevelKey = "loglevel"
private let kClassKey = "class"
private let kMessageKey = "message"

// MARK: - TestLoggingImpl

class TestLoggingImpl: NSObject, SFLogging {
    let componentName: String
    var logger: Any { self }
    var logLevel: SFLogLevel = .default

    required init(component componentName: String) {
        self.componentName = componentName
        super.init()
    }

    func log(_ cls: AnyClass, level: SFLogLevel, message: String) {
        NotificationCenter.default.post(
            name: kLogNotification,
            object: self,
            userInfo: [kLogLevelKey: NSNumber(value: level.rawValue), kMessageKey: message, kClassKey: cls]
        )
    }
}

// MARK: - SFLoggerTests

class SFLoggerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        SalesforceLogger.setInstanceClass(TestLoggingImpl.self)
        SalesforceLogger.clearAllComponents()
    }

    override func tearDown() {
        SalesforceLogger.setInstanceClass(SFDefaultLogger.self)
        SalesforceLogger.clearAllComponents()
        super.tearDown()
    }

    func testLoggerInstance() {
        let logger = SalesforceLogger.logger(forComponent: kTestDefaultComponent)
        XCTAssertNotNil(logger, "Logger instance should have been created")
        // Faithful to the oracle's XCTAssertTrue([logger.logger isKindOfClass:[TestLoggingImpl class]]):
        // verify the injected backing impl is the test double registered in setUp.
        XCTAssertTrue(logger.underlyingLoggerImpl is TestLoggingImpl, "Logger should be an instance of TestLoggingImpl")
        logger.level = .debug
        XCTAssertEqual(logger.level, .debug, "Logger level should be set to debug")
    }

    func testMultipleLoggerComponents() {
        let logger = SalesforceLogger.logger(forComponent: kTestDefaultComponent)
        let anotherLogger = SalesforceLogger.logger(forComponent: kTestComponent1)
        XCTAssertNotNil(logger, "Logger instance should have been created")
        XCTAssertNotNil(anotherLogger, "Component Logger instance should have been created")
        XCTAssertFalse(logger === anotherLogger, "Should be 2 different instances of logger")
        logger.level = .debug
        XCTAssertEqual(logger.level, .debug, "Logger level should be set to debug")
        XCTAssertEqual(anotherLogger.level, .default, "Component Logger level should not have changed")
    }

    func testLoggerDebugLog() {
        let logger = SalesforceLogger.logger(forComponent: kTestDefaultComponent)
        XCTAssertNotNil(logger, "Logger instance should have been created")
        logger.level = .debug
        XCTAssertEqual(logger.level, .debug, "Logger level should be set to debug")

        let expectation = XCTestExpectation(description: "Log Notification")
        var logLevelUsed: SFLogLevel = .default
        var classUsed: AnyClass?
        var message: String?

        let observer = NotificationCenter.default.addObserver(forName: kLogNotification, object: nil, queue: nil) { note in
            logLevelUsed = SFLogLevel(rawValue: (note.userInfo?[kLogLevelKey] as? NSNumber)?.uintValue ?? 0) ?? .default
            classUsed = note.userInfo?[kClassKey] as? AnyClass
            message = note.userInfo?[kMessageKey] as? String
            expectation.fulfill()
        }

        logger.d(type(of: self), message: "TestDebugStatement TestValue")
        wait(for: [expectation], timeout: 10)

        NotificationCenter.default.removeObserver(observer)
        XCTAssertEqual(logLevelUsed, .debug, "Log statement should have been at Debug level")
        XCTAssertTrue(self.isKind(of: classUsed!), "Log statement should have been logged against the class")
        XCTAssertTrue(message != nil && !message!.isEmpty, "Log statement should not be empty")
    }

    func testLoggerInfoLog() {
        let logger = SalesforceLogger.logger(forComponent: kTestDefaultComponent)
        XCTAssertNotNil(logger, "Logger instance should have been created")
        logger.level = .info
        XCTAssertEqual(logger.level, .info, "Logger level should be set to info")

        let expectation = XCTestExpectation(description: "Log Notification")
        var logLevelUsed: SFLogLevel = .default
        var classUsed: AnyClass?
        var message: String?

        let observer = NotificationCenter.default.addObserver(forName: kLogNotification, object: nil, queue: nil) { note in
            logLevelUsed = SFLogLevel(rawValue: (note.userInfo?[kLogLevelKey] as? NSNumber)?.uintValue ?? 0) ?? .default
            classUsed = note.userInfo?[kClassKey] as? AnyClass
            message = note.userInfo?[kMessageKey] as? String
            expectation.fulfill()
        }

        logger.i(type(of: self), message: "TestInfoStatement TestValue")
        wait(for: [expectation], timeout: 10)

        NotificationCenter.default.removeObserver(observer)
        XCTAssertEqual(logLevelUsed, .info, "Log statement should have been at Info level")
        XCTAssertTrue(self.isKind(of: classUsed!), "Log statement should have been logged against the class")
        XCTAssertTrue(message != nil && !message!.isEmpty, "Log statement should not be empty")
    }

    func testLoggerErrorLog() {
        let logger = SalesforceLogger.logger(forComponent: kTestDefaultComponent)
        XCTAssertNotNil(logger, "Logger instance should have been created")
        logger.level = .error
        XCTAssertEqual(logger.level, .error, "Logger level should be set to error")

        let expectation = XCTestExpectation(description: "Log Notification")
        var logLevelUsed: SFLogLevel = .default
        var classUsed: AnyClass?
        var message: String?

        let observer = NotificationCenter.default.addObserver(forName: kLogNotification, object: nil, queue: nil) { note in
            logLevelUsed = SFLogLevel(rawValue: (note.userInfo?[kLogLevelKey] as? NSNumber)?.uintValue ?? 0) ?? .default
            classUsed = note.userInfo?[kClassKey] as? AnyClass
            message = note.userInfo?[kMessageKey] as? String
            expectation.fulfill()
        }

        logger.e(type(of: self), message: "TestErrorStatement TestValue")
        wait(for: [expectation], timeout: 10)

        NotificationCenter.default.removeObserver(observer)
        XCTAssertEqual(logLevelUsed, .error, "Log statement should have been at Error level")
        XCTAssertTrue(self.isKind(of: classUsed!), "Log statement should have been logged against the class")
        XCTAssertTrue(message != nil && !message!.isEmpty, "Log statement should not be empty")
    }

    func testLoggerFaultLog() {
        let logger = SalesforceLogger.logger(forComponent: kTestDefaultComponent)
        XCTAssertNotNil(logger, "Logger instance should have been created")
        logger.level = .fault
        XCTAssertEqual(logger.level, .fault, "Logger level should be set to fault")

        let expectation = XCTestExpectation(description: "Log Notification")
        var logLevelUsed: SFLogLevel = .default
        var classUsed: AnyClass?
        var message: String?

        let observer = NotificationCenter.default.addObserver(forName: kLogNotification, object: nil, queue: nil) { note in
            logLevelUsed = SFLogLevel(rawValue: (note.userInfo?[kLogLevelKey] as? NSNumber)?.uintValue ?? 0) ?? .default
            classUsed = note.userInfo?[kClassKey] as? AnyClass
            message = note.userInfo?[kMessageKey] as? String
            expectation.fulfill()
        }

        logger.f(type(of: self), message: "TestFaultStatement TestValue")
        wait(for: [expectation], timeout: 10)

        NotificationCenter.default.removeObserver(observer)
        XCTAssertEqual(logLevelUsed, .fault, "Log statement should have been at Fault level")
        XCTAssertTrue(self.isKind(of: classUsed!), "Log statement should have been logged against the class")
        XCTAssertTrue(message != nil && !message!.isEmpty, "Log statement should not be empty")
    }
}
