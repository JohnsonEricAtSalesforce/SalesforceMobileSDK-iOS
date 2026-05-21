import XCTest
@testable import SalesforceAnalytics

private let kTestEventName = "TEST_EVENT_NAME_%f"
private let kTestSenderId = "TEST_SENDER_ID"
private let kTestSessionId = "TEST_SESSION_ID"

class EventStoreManagerTests: XCTestCase {

    var storeDirectory: String!
    var analyticsManager: SFSDKAnalyticsManager!
    var storeManager: SFSDKEventStoreManager!

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
        storeManager = SFSDKEventStoreManager(
            storeDirectory: storeDirectory,
            dataEncryptorBlock: nil,
            dataDecryptorBlock: nil
        )
    }

    override func tearDown() {
        storeManager.deleteAllEvents()
        analyticsManager.reset()
        super.tearDown()
    }

    func testStoreOneEvent() {
        let event = createTestEvent()
        XCTAssertNotNil(event, "Generated event should not be nil")
        storeManager.storeEvent(event)
        let events = storeManager.fetchAllEvents()
        XCTAssertNotNil(events, "List of events should not be nil")
        XCTAssertEqual(events?.count, 1, "Number of events stored should be 1")
        XCTAssertEqual(event, events?.first, "Stored event should be the same as generated event")
    }

    func testStoreAndFetchMultipleEvents() {
        let event1 = createTestEvent()
        XCTAssertNotNil(event1, "Generated event should not be nil")
        let event2 = createTestEvent()
        XCTAssertNotNil(event2, "Generated event should not be nil")
        storeManager.storeEvents([event1!, event2!])
        let events = storeManager.fetchAllEvents()
        XCTAssertNotNil(events, "List of events should not be nil")
        XCTAssertEqual(events?.count, 2, "Number of events stored should be 2")
        XCTAssertTrue(events?.contains(event1!) ?? false, "Event should be stored")
        XCTAssertTrue(events?.contains(event2!) ?? false, "Event should be stored")
    }

    func testFetchOneEvent() {
        let event = createTestEvent()
        XCTAssertNotNil(event, "Generated event should not be nil")
        let eventId = event!.eventId
        storeManager.storeEvent(event)
        let storedEvent = storeManager.fetchEvent(eventId)
        XCTAssertNotNil(storedEvent, "Event stored should not be nil")
        XCTAssertEqual(event, storedEvent, "Stored event should be the same as generated event")
    }

    func testDeleteOneEvent() {
        let event = createTestEvent()
        XCTAssertNotNil(event, "Generated event should not be nil")
        let eventId = event!.eventId
        storeManager.storeEvent(event)
        let eventsBeforeDel = storeManager.fetchAllEvents()
        XCTAssertNotNil(eventsBeforeDel, "List of events should not be nil")
        XCTAssertEqual(eventsBeforeDel?.count, 1, "Number of events stored should be 1")
        XCTAssertEqual(event, eventsBeforeDel?.first, "Stored event should be the same as generated event")
        _ = storeManager.deleteEvent(eventId)
        let eventsAfterDel = storeManager.fetchAllEvents()
        XCTAssertNotNil(eventsAfterDel, "List of events should not be nil")
        XCTAssertEqual(eventsAfterDel?.count, 0, "Number of events stored should be 0")
    }

    func testDeleteMultipleEvents() {
        let event1 = createTestEvent()
        XCTAssertNotNil(event1, "Generated event should not be nil")
        let eventId1 = event1!.eventId
        let event2 = createTestEvent()
        XCTAssertNotNil(event2, "Generated event should not be nil")
        let eventId2 = event2!.eventId
        storeManager.storeEvents([event1!, event2!])
        let eventsBeforeDel = storeManager.fetchAllEvents()
        XCTAssertNotNil(eventsBeforeDel, "List of events should not be nil")
        XCTAssertEqual(eventsBeforeDel?.count, 2, "Number of events stored should be 2")
        storeManager.deleteEvents([eventId1, eventId2])
        let eventsAfterDel = storeManager.fetchAllEvents()
        XCTAssertNotNil(eventsAfterDel, "List of events should not be nil")
        XCTAssertEqual(eventsAfterDel?.count, 0, "Number of events stored should be 0")
    }

    func testDeleteAllEvents() {
        let event1 = createTestEvent()
        XCTAssertNotNil(event1, "Generated event should not be nil")
        let event2 = createTestEvent()
        XCTAssertNotNil(event2, "Generated event should not be nil")
        storeManager.storeEvents([event1!, event2!])
        let eventsBeforeDel = storeManager.fetchAllEvents()
        XCTAssertNotNil(eventsBeforeDel, "List of events should not be nil")
        XCTAssertEqual(eventsBeforeDel?.count, 2, "Number of events stored should be 2")
        storeManager.deleteAllEvents()
        let eventsAfterDel = storeManager.fetchAllEvents()
        XCTAssertNotNil(eventsAfterDel, "List of events should not be nil")
        XCTAssertEqual(eventsAfterDel?.count, 0, "Number of events stored should be 0")
    }

    func testDisablingLogging() {
        let event = createTestEvent()
        XCTAssertNotNil(event, "Generated event should not be nil")
        storeManager.loggingEnabled = false
        storeManager.storeEvent(event)
        let events = storeManager.fetchAllEvents()
        XCTAssertNotNil(events, "List of events should not be nil")
        XCTAssertEqual(events?.count, 0, "Number of events stored should be 0")
    }

    func testEnablingLogging() {
        let event = createTestEvent()
        XCTAssertNotNil(event, "Generated event should not be nil")
        storeManager.loggingEnabled = false
        storeManager.storeEvent(event)
        var events = storeManager.fetchAllEvents()
        XCTAssertNotNil(events, "List of events should not be nil")
        XCTAssertEqual(events?.count, 0, "Number of events stored should be 0")
        storeManager.loggingEnabled = true
        storeManager.storeEvent(event)
        events = storeManager.fetchAllEvents()
        XCTAssertNotNil(events, "List of events should not be nil")
        XCTAssertEqual(events?.count, 1, "Number of events stored should be 1")
        XCTAssertEqual(event, events?.first, "Stored event should be the same as generated event")
    }

    func testEventLimitExceeded() {
        let event = createTestEvent()
        XCTAssertNotNil(event, "Generated event should not be nil")
        storeManager.maxEvents = 0
        storeManager.storeEvent(event)
        let events = storeManager.fetchAllEvents()
        XCTAssertNotNil(events, "List of events should not be nil")
        XCTAssertEqual(events?.count, 0, "Number of events stored should be 0")
    }

    func testEventLimitNotExceeded() {
        let event = createTestEvent()
        XCTAssertNotNil(event, "Generated event should not be nil")
        storeManager.maxEvents = 0
        storeManager.storeEvent(event)
        var events = storeManager.fetchAllEvents()
        XCTAssertNotNil(events, "List of events should not be nil")
        XCTAssertEqual(events?.count, 0, "Number of events stored should be 0")
        storeManager.maxEvents = 1
        storeManager.storeEvent(event)
        events = storeManager.fetchAllEvents()
        XCTAssertNotNil(events, "List of events should not be nil")
        XCTAssertEqual(events?.count, 1, "Number of events stored should be 1")
        XCTAssertEqual(event, events?.first, "Stored event should be the same as generated event")
    }

    func testEventCountManipulation() {
        var event = createTestEvent()
        XCTAssertNotNil(event, "Generated event should not be nil")
        var eventCount = storeManager.numStoredEvents
        XCTAssertEqual(eventCount, 0, "Event count should be 0")
        storeManager.storeEvent(event)
        eventCount = storeManager.numStoredEvents
        XCTAssertEqual(eventCount, 1, "Event count should be 1")
        event = createTestEvent()
        XCTAssertNotNil(event, "Generated event should not be nil")
        storeManager.storeEvent(event)
        eventCount = storeManager.numStoredEvents
        XCTAssertEqual(eventCount, 2, "Event count should be 2")
        _ = storeManager.deleteEvent(event!.eventId)
        eventCount = storeManager.numStoredEvents
        XCTAssertEqual(eventCount, 1, "Event count should be 1")
        storeManager.deleteAllEvents()
        eventCount = storeManager.numStoredEvents
        XCTAssertEqual(eventCount, 0, "Event count should be 0")
    }

    // MARK: - Helper

    private func createTestEvent() -> SFSDKInstrumentationEvent? {
        return SFSDKInstrumentationEventBuilder.buildEvent(builderBlock: { builder in
            let curTime = Int(1000 * Date().timeIntervalSince1970)
            let eventName = String(format: kTestEventName, Double(curTime))
            builder.startTime = curTime
            builder.name = eventName
            builder.sessionId = kTestSessionId
            builder.page = NSDictionary()
            builder.senderId = kTestSenderId
            builder.schemaType = .error
            builder.eventType = .system
            builder.errorType = .warn
        }, analyticsManager: analyticsManager)
    }
}
