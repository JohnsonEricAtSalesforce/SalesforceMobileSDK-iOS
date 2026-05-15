/*
 EventStoreManagerTests.swift
 SalesforceAnalytics

 Created by Bharath Hariharan on 6/15/16.

 Copyright (c) 2016-present, salesforce.com, inc. All rights reserved.

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
@testable import SalesforceAnalytics

private let kTestEventName = "TEST_EVENT_NAME_%lf"
private let kTestSenderId = "TEST_SENDER_ID"
private let kTestSessionId = "TEST_SESSION_ID"

final class EventStoreManagerTests: XCTestCase {

    private var storeDirectory: String!
    private var analyticsManager: SFSDKAnalyticsManager!
    private var storeManager: SFSDKEventStoreManager!

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

    /// Test for storing one event and retrieving it.
    func testStoreOneEvent() {
        let event = createTestEvent()
        XCTAssertNotNil(event, "Generated event stored should not be nil")
        storeManager.storeEvent(event)
        let events = storeManager.fetchAllEvents()
        XCTAssertNotNil(events, "List of events should not be nil")
        XCTAssertEqual(1, events?.count, "Number of events stored should be 1")
        XCTAssertEqual(event, events?.first, "Stored event should be the same as generated event")
    }

    /// Test for storing many events and retrieving them.
    func testStoreAndFetchMultipleEvents() {
        let event1 = createTestEvent()
        XCTAssertNotNil(event1, "Generated event stored should not be nil")
        let event2 = createTestEvent()
        XCTAssertNotNil(event2, "Generated event stored should not be nil")
        let genEvents = [event1!, event2!]
        storeManager.storeEvents(genEvents)
        let events = storeManager.fetchAllEvents()
        XCTAssertNotNil(events, "List of events should not be nil")
        XCTAssertEqual(2, events?.count, "Number of events stored should be 2")
        XCTAssertTrue(events?.contains(event1!) ?? false, "Event should be stored")
        XCTAssertTrue(events?.contains(event2!) ?? false, "Event should be stored")
    }

    /// Test for fetching one event by specifying event ID.
    func testFetchOneEvent() {
        let event = createTestEvent()
        XCTAssertNotNil(event, "Generated event stored should not be nil")
        let eventId = event!.eventId
        storeManager.storeEvent(event)
        let storedEvent = storeManager.fetchEvent(eventId)
        XCTAssertNotNil(storedEvent, "Event stored should not be nil")
        XCTAssertEqual(event, storedEvent, "Stored event should be the same as generated event")
    }

    /// Test for deleting one event by specifying event ID.
    func testDeleteOneEvent() {
        let event = createTestEvent()
        XCTAssertNotNil(event, "Generated event stored should not be nil")
        let eventId = event!.eventId
        storeManager.storeEvent(event)
        let eventsBeforeDel = storeManager.fetchAllEvents()
        XCTAssertNotNil(eventsBeforeDel, "List of events should not be nil")
        XCTAssertEqual(1, eventsBeforeDel?.count, "Number of events stored should be 1")
        XCTAssertEqual(event, eventsBeforeDel?.first, "Stored event should be the same as generated event")
        _ = storeManager.deleteEvent(eventId)
        let eventsAfterDel = storeManager.fetchAllEvents()
        XCTAssertNotNil(eventsAfterDel, "List of events should not be nil")
        XCTAssertEqual(0, eventsAfterDel?.count, "Number of events stored should be 0")
    }

    /// Test for deleting multiple events by specifying event IDs.
    func testDeleteMultipleEvents() {
        let event1 = createTestEvent()
        XCTAssertNotNil(event1, "Generated event stored should not be nil")
        let eventId1 = event1!.eventId
        let event2 = createTestEvent()
        XCTAssertNotNil(event2, "Generated event stored should not be nil")
        let eventId2 = event2!.eventId
        let genEvents = [event1!, event2!]
        storeManager.storeEvents(genEvents)
        let eventsBeforeDel = storeManager.fetchAllEvents()
        XCTAssertNotNil(eventsBeforeDel, "List of events should not be nil")
        XCTAssertEqual(2, eventsBeforeDel?.count, "Number of events stored should be 2")
        let eventIds = [eventId1, eventId2]
        storeManager.deleteEvents(eventIds)
        let eventsAfterDel = storeManager.fetchAllEvents()
        XCTAssertNotNil(eventsAfterDel, "List of events should not be nil")
        XCTAssertEqual(0, eventsAfterDel?.count, "Number of events stored should be 0")
    }

    /// Test for deleting all events stored.
    func testDeleteAllEvents() {
        let event1 = createTestEvent()
        XCTAssertNotNil(event1, "Generated event stored should not be nil")
        let event2 = createTestEvent()
        XCTAssertNotNil(event2, "Generated event stored should not be nil")
        let genEvents = [event1!, event2!]
        storeManager.storeEvents(genEvents)
        let eventsBeforeDel = storeManager.fetchAllEvents()
        XCTAssertNotNil(eventsBeforeDel, "List of events should not be nil")
        XCTAssertEqual(2, eventsBeforeDel?.count, "Number of events stored should be 2")
        storeManager.deleteAllEvents()
        let eventsAfterDel = storeManager.fetchAllEvents()
        XCTAssertNotNil(eventsAfterDel, "List of events should not be nil")
        XCTAssertEqual(0, eventsAfterDel?.count, "Number of events stored should be 0")
    }

    /// Test for disabling logging.
    func testDisablingLogging() {
        let event = createTestEvent()
        XCTAssertNotNil(event, "Generated event stored should not be nil")
        storeManager.isLoggingEnabled = false
        storeManager.storeEvent(event)
        let events = storeManager.fetchAllEvents()
        XCTAssertNotNil(events, "List of events should not be nil")
        XCTAssertEqual(0, events?.count, "Number of events stored should be 0")
    }

    /// Test for enabling logging.
    func testEnablingLogging() {
        let event = createTestEvent()
        XCTAssertNotNil(event, "Generated event stored should not be nil")
        storeManager.isLoggingEnabled = false
        storeManager.storeEvent(event)
        var events = storeManager.fetchAllEvents()
        XCTAssertNotNil(events, "List of events should not be nil")
        XCTAssertEqual(0, events?.count, "Number of events stored should be 0")
        storeManager.isLoggingEnabled = true
        storeManager.storeEvent(event)
        events = storeManager.fetchAllEvents()
        XCTAssertNotNil(events, "List of events should not be nil")
        XCTAssertEqual(1, events?.count, "Number of events stored should be 1")
        XCTAssertEqual(event, events?.first, "Stored event should be the same as generated event")
    }

    /// Test for event limit exceeded.
    func testEventLimitExceeded() {
        let event = createTestEvent()
        XCTAssertNotNil(event, "Generated event stored should not be nil")
        storeManager.maxEvents = 0
        storeManager.storeEvent(event)
        let events = storeManager.fetchAllEvents()
        XCTAssertNotNil(events, "List of events should not be nil")
        XCTAssertEqual(0, events?.count, "Number of events stored should be 0")
    }

    /// Test for event limit not exceeded.
    func testEventLimitNotExceeded() {
        let event = createTestEvent()
        XCTAssertNotNil(event, "Generated event stored should not be nil")
        storeManager.maxEvents = 0
        storeManager.storeEvent(event)
        var events = storeManager.fetchAllEvents()
        XCTAssertNotNil(events, "List of events should not be nil")
        XCTAssertEqual(0, events?.count, "Number of events stored should be 0")
        storeManager.maxEvents = 1
        storeManager.storeEvent(event)
        events = storeManager.fetchAllEvents()
        XCTAssertNotNil(events, "List of events should not be nil")
        XCTAssertEqual(1, events?.count, "Number of events stored should be 1")
        XCTAssertEqual(event, events?.first, "Stored event should be the same as generated event")
    }

    /// Test for event count manipulation.
    func testEventCountManipulation() {
        var event = createTestEvent()
        XCTAssertNotNil(event, "Generated event stored should not be nil")
        var eventCount = storeManager.numStoredEvents
        XCTAssertEqual(0, eventCount, "Event count should be 0")
        storeManager.storeEvent(event)
        eventCount = storeManager.numStoredEvents
        XCTAssertEqual(1, eventCount, "Event count should be 1")
        event = createTestEvent()
        XCTAssertNotNil(event, "Generated event stored should not be nil")
        storeManager.storeEvent(event)
        eventCount = storeManager.numStoredEvents
        XCTAssertEqual(2, eventCount, "Event count should be 2")
        storeManager.deleteEvent(event!.eventId)
        eventCount = storeManager.numStoredEvents
        XCTAssertEqual(1, eventCount, "Event count should be 1")
        storeManager.deleteAllEvents()
        eventCount = storeManager.numStoredEvents
        XCTAssertEqual(0, eventCount, "Event count should be 0")
    }

    // MARK: - Helper methods

    private func createTestEvent() -> SFSDKInstrumentationEvent? {
        return SFSDKInstrumentationEventBuilder.buildEvent(withBuilderBlock: { builder in
            let curTime = Int(Date().timeIntervalSince1970 * 1000)
            let eventName = String(format: kTestEventName, Double(curTime))
            builder.startTime = curTime
            builder.name = eventName
            builder.sessionId = kTestSessionId
            builder.page = [:]
            builder.senderId = kTestSenderId
            builder.schemaType = .error
            builder.eventType = .system
            builder.errorType = .warn
        }, analyticsManager: analyticsManager)
    }
}
