import XCTest
@testable import SalesforceAnalytics

private let kTestEventName = "TEST_EVENT_NAME_%f"
private let kTestSenderId = "TEST_SENDER_ID"
private let kTestSessionId = "TEST_SESSION_ID"

class InstrumentationEventBuilderTests: XCTestCase {

    var storeDirectory: String!
    var analyticsManager: SFSDKAnalyticsManager!

    override func setUp() {
        super.setUp()
        let deviceAppAttributes = SFSDKDeviceAppAttributes(
            appVersion: "TEST_APP_VERSION",
            appName: "TEST_APP_NAME",
            osVersion: "TEST_OS_VERSION",
            osName: "TEST_OS_NAME",
            nativeAppType: "TEST_NATIVE_APP_TYPE",
            mobileSdkVersion: "TEST_MOBILE_SDK_VERSION",
            deviceModel: "TEST_DEVICE_MODEL",
            deviceId: "TEST_DEVICE_ID",
            clientId: "TEST_CLIENT_ID"
        )
        storeDirectory = AnalyticsTestUtil.buildTestStoreDirectory()
        analyticsManager = SFSDKAnalyticsManager(
            storeDirectory: storeDirectory,
            dataEncryptorBlock: nil,
            dataDecryptorBlock: nil,
            deviceAttributes: deviceAppAttributes
        )
    }

    override func tearDown() {
        analyticsManager.reset()
        super.tearDown()
    }

    func testEventCopyAndEquality() {
        let event = standardTestEvent()
        let eventCopy = event?.copy() as? SFSDKInstrumentationEvent
        XCTAssertEqual(event, eventCopy, "Events should still be equivalent")
        XCTAssertFalse(event === eventCopy, "Copy should make a different event instance")
    }

    func testMissingName() {
        let event = SFSDKInstrumentationEventBuilder.buildEvent(builderBlock: { builder in
            let curTime = Int(1000 * Date().timeIntervalSince1970)
            builder.startTime = curTime
            builder.page = NSDictionary()
            builder.sessionId = kTestSessionId
            builder.senderId = kTestSenderId
            builder.schemaType = .error
            builder.eventType = .system
            builder.errorType = .warn
        }, analyticsManager: analyticsManager)
        XCTAssertNil(event, "Event should be nil due to missing mandatory field 'name'")
    }

    func testMissingPage() {
        let event = SFSDKInstrumentationEventBuilder.buildEvent(builderBlock: { builder in
            let curTime = Int(1000 * Date().timeIntervalSince1970)
            let eventName = String(format: kTestEventName, Double(curTime))
            builder.name = eventName
            builder.startTime = curTime
            builder.sessionId = kTestSessionId
            builder.senderId = kTestSenderId
            builder.schemaType = .error
            builder.eventType = .system
            builder.errorType = .warn
        }, analyticsManager: analyticsManager)
        XCTAssertNil(event, "Event should be nil due to missing mandatory field 'page'")
    }

    func testInvalidJsonProperties() {
        let event = SFSDKInstrumentationEventBuilder.buildEvent(builderBlock: { builder in
            let curTime = Int(1000 * Date().timeIntervalSince1970)
            let eventName = String(format: kTestEventName, Double(curTime))
            builder.startTime = curTime
            builder.name = eventName
            builder.sessionId = kTestSessionId
            builder.page = [NSNull(): ""] as NSDictionary
            builder.senderId = kTestSenderId
            builder.schemaType = .error
            builder.eventType = .system
            builder.errorType = .warn
        }, analyticsManager: analyticsManager)
        XCTAssertNil(event, "Event should be nil due to invalid json key of NSNull")
    }

    func testMissingDeviceAppAttributes() {
        analyticsManager.reset()
        analyticsManager = SFSDKAnalyticsManager(
            storeDirectory: storeDirectory,
            dataEncryptorBlock: nil,
            dataDecryptorBlock: nil,
            deviceAttributes: nil
        )
        let event = SFSDKInstrumentationEventBuilder.buildEvent(builderBlock: { builder in
            let curTime = Int(1000 * Date().timeIntervalSince1970)
            let eventName = String(format: kTestEventName, Double(curTime))
            builder.name = eventName
            builder.page = NSDictionary()
            builder.startTime = curTime
            builder.sessionId = kTestSessionId
            builder.senderId = kTestSenderId
            builder.schemaType = .error
            builder.eventType = .system
            builder.errorType = .warn
        }, analyticsManager: analyticsManager)
        XCTAssertNil(event, "Event should be nil due to missing mandatory field 'device app attributes'")
        analyticsManager.reset()
    }

    func testAutoPopulateStartTime() {
        let event = SFSDKInstrumentationEventBuilder.buildEvent(builderBlock: { builder in
            let curTime = Int(1000 * Date().timeIntervalSince1970)
            let eventName = String(format: kTestEventName, Double(curTime))
            builder.name = eventName
            builder.page = NSDictionary()
            builder.sessionId = kTestSessionId
            builder.senderId = kTestSenderId
            builder.schemaType = .error
            builder.eventType = .system
            builder.errorType = .warn
        }, analyticsManager: analyticsManager)
        XCTAssertNotNil(event)
        XCTAssertTrue(event!.startTime > 0, "Start time should have been auto populated")
    }

    func testAutoPopulateEventId() {
        let event = standardTestEvent()
        XCTAssertNotNil(event?.eventId, "Event ID should have been auto populated")
    }

    func testAutoPopulateSequenceId() {
        let event = standardTestEvent()
        XCTAssertNotNil(event)
        let sequenceId = event!.sequenceId
        XCTAssertTrue(sequenceId > 0, "Sequence ID should have been auto populated")
        let globalSequenceId = analyticsManager.globalSequenceId
        XCTAssertEqual(globalSequenceId - sequenceId, 0)
    }

    // MARK: - Helper

    private func standardTestEvent() -> SFSDKInstrumentationEvent? {
        return SFSDKInstrumentationEventBuilder.buildEvent(builderBlock: { builder in
            let curTime = Int(1000 * Date().timeIntervalSince1970)
            let eventName = String(format: kTestEventName, Double(curTime))
            builder.name = eventName
            builder.page = NSDictionary()
            builder.startTime = curTime
            builder.sessionId = kTestSessionId
            builder.senderId = kTestSenderId
            builder.schemaType = .error
            builder.eventType = .system
            builder.errorType = .warn
        }, analyticsManager: analyticsManager)
    }
}
