/*
 SFSDKInstrumentationEvent.swift
 SalesforceAnalytics

 Created by Bharath Hariharan on 5/25/16.

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

import Foundation
import SalesforceSDKCommon

public let kEventIdKey = "eventId"
public let kStartTimeKey = "startTime"
public let kEndTimeKey = "endTime"
public let kNameKey = "name"
public let kAttributesKey = "attributes"
public let kSessionIdKey = "sessionId"
public let kSequenceIdKey = "sequenceId"
public let kSenderIdKey = "senderId"
public let kSenderContextKey = "senderContext"
public let kSchemaTypeKey = "schemaType"
public let kEventTypeKey = "eventType"
public let kErrorTypeKey = "errorType"
public let kConnectionTypeKey = "connectionType"
public let kDeviceAppAttributesKey = "deviceAppAttributes"
public let kSenderParentIdKey = "senderParentId"
public let kSessionStartTimeKey = "sessionStartTime"
public let kPageKey = "page"
public let kPreviousPageKey = "previousPage"
public let kMarksKey = "marks"

/// Represents the type of schema being logged.
@objc(SFASchemaType)
public enum SFASchemaType: Int {
    case interaction = 0
    case pageView
    case perf
    case error
}

/// Represents the type of event being logged.
@objc(SFAEventType)
public enum SFAEventType: Int {
    case user = 0
    case system
    case error
    case crud
}

/// Represents the type of error being logged.
@objc(SFAErrorType)
public enum SFAErrorType: Int {
    case info = 0
    case warn
    case error
}

@objc(SFSDKInstrumentationEvent)
public class SFSDKInstrumentationEvent: NSObject, NSCopying {

    @objc public let eventId: String
    @objc public let startTime: Int
    @objc public let endTime: Int
    @objc public let name: String
    @objc public let attributes: [String: Any]?
    @objc public let sessionId: String?
    @objc public let sequenceId: Int
    @objc public let senderId: String?
    @objc public let senderContext: [String: Any]?
    @objc public let schemaType: SFASchemaType
    @objc public let eventType: SFAEventType
    @objc public let errorType: SFAErrorType
    @objc public let deviceAppAttributes: SFSDKDeviceAppAttributes
    @objc public let connectionType: String
    @objc public let senderParentId: String?
    @objc public let sessionStartTime: Int
    @objc public let page: [String: Any]?
    @objc public let previousPage: [String: Any]?
    @objc public let marks: [String: Any]?

    /// Parameterized initializer (internal use).
    ///
    /// - Parameters:
    ///   - eventId: Event ID.
    ///   - startTime: Start time.
    ///   - endTime: End time.
    ///   - name: Name.
    ///   - attributes: Attributes.
    ///   - sessionId: Session ID.
    ///   - sequenceId: Sequence ID.
    ///   - senderId: Sender ID.
    ///   - senderContext: Sender context.
    ///   - schemaType: Schema type.
    ///   - eventType: Event type.
    ///   - errorType: Error type.
    ///   - deviceAppAttributes: Device app attributes.
    ///   - connectionType: Connection type.
    ///   - senderParentId: Sender parent ID.
    ///   - sessionStartTime: Session start time.
    ///   - page: Page.
    ///   - previousPage: Previous page.
    ///   - marks: Marks.
    @objc
    public init(
        eventId: String,
        startTime: Int,
        endTime: Int,
        name: String,
        attributes: [String: Any]?,
        sessionId: String?,
        sequenceId: Int,
        senderId: String?,
        senderContext: [String: Any]?,
        schemaType: SFASchemaType,
        eventType: SFAEventType,
        errorType: SFAErrorType,
        deviceAppAttributes: SFSDKDeviceAppAttributes,
        connectionType: String,
        senderParentId: String?,
        sessionStartTime: Int,
        page: [String: Any]?,
        previousPage: [String: Any]?,
        marks: [String: Any]?
    ) {
        self.eventId = eventId
        self.startTime = startTime
        self.endTime = endTime
        self.name = name
        self.attributes = attributes
        self.sessionId = sessionId
        self.sequenceId = sequenceId
        self.senderId = senderId
        self.senderContext = senderContext
        self.schemaType = schemaType
        self.eventType = eventType
        self.errorType = errorType
        self.deviceAppAttributes = deviceAppAttributes
        self.connectionType = connectionType
        self.senderParentId = senderParentId
        self.sessionStartTime = sessionStartTime
        self.page = page
        self.previousPage = previousPage
        self.marks = marks
        super.init()
    }

    /// Parameterized initializer.
    ///
    /// - Parameter jsonRepresentation: JSON representation.
    @objc
    public init(json jsonRepresentation: Data) {
        guard let dict = SFJsonUtils.object(from: jsonRepresentation) as? [String: Any] else {
            self.eventId = ""
            self.startTime = 0
            self.endTime = 0
            self.name = ""
            self.attributes = nil
            self.sessionId = nil
            self.sequenceId = 0
            self.senderId = nil
            self.senderContext = nil
            self.schemaType = .error
            self.eventType = .error
            self.errorType = .error
            self.deviceAppAttributes = SFSDKDeviceAppAttributes(json: [:])
            self.connectionType = ""
            self.senderParentId = nil
            self.sessionStartTime = 0
            self.page = nil
            self.previousPage = nil
            self.marks = nil
            super.init()
            return
        }

        self.eventId = dict[kEventIdKey] as? String ?? ""
        self.startTime = (dict[kStartTimeKey] as? NSNumber)?.intValue ?? 0
        self.endTime = (dict[kEndTimeKey] as? NSNumber)?.intValue ?? 0
        self.name = dict[kNameKey] as? String ?? ""
        self.attributes = dict[kAttributesKey] as? [String: Any]
        self.sessionId = dict[kSessionIdKey] as? String
        self.sequenceId = (dict[kSequenceIdKey] as? NSNumber)?.intValue ?? 0
        self.senderId = dict[kSenderIdKey] as? String
        self.senderContext = dict[kSenderContextKey] as? [String: Any]

        if let stringSchemaType = dict[kSchemaTypeKey] as? String {
            self.schemaType = SFSDKInstrumentationEvent.schemaType(from: stringSchemaType)
        } else {
            self.schemaType = .error
        }

        if let stringEventType = dict[kEventTypeKey] as? String {
            self.eventType = SFSDKInstrumentationEvent.eventType(from: stringEventType)
        } else {
            self.eventType = .error
        }

        if let stringErrorType = dict[kErrorTypeKey] as? String {
            self.errorType = SFSDKInstrumentationEvent.errorType(from: stringErrorType)
        } else {
            self.errorType = .error
        }

        if let deviceAttrDict = dict[kDeviceAppAttributesKey] as? [String: Any] {
            self.deviceAppAttributes = SFSDKDeviceAppAttributes(json: deviceAttrDict)
        } else {
            self.deviceAppAttributes = SFSDKDeviceAppAttributes(json: [:])
        }

        self.connectionType = dict[kConnectionTypeKey] as? String ?? ""
        self.senderParentId = dict[kSenderParentIdKey] as? String
        self.sessionStartTime = (dict[kSessionStartTimeKey] as? NSNumber)?.intValue ?? 0
        self.page = dict[kPageKey] as? [String: Any]
        self.previousPage = dict[kPreviousPageKey] as? [String: Any]
        self.marks = dict[kMarksKey] as? [String: Any]

        super.init()
    }

    // MARK: - NSCopying

    @objc
    public func copy(with zone: NSZone? = nil) -> Any {
        let eventCopy = SFSDKInstrumentationEvent(
            eventId: self.eventId,
            startTime: self.startTime,
            endTime: self.endTime,
            name: self.name,
            attributes: self.attributes,
            sessionId: self.sessionId,
            sequenceId: self.sequenceId,
            senderId: self.senderId,
            senderContext: self.senderContext,
            schemaType: self.schemaType,
            eventType: self.eventType,
            errorType: self.errorType,
            deviceAppAttributes: self.deviceAppAttributes,
            connectionType: self.connectionType,
            senderParentId: self.senderParentId,
            sessionStartTime: self.sessionStartTime,
            page: self.page,
            previousPage: self.previousPage,
            marks: self.marks
        )
        return eventCopy
    }

    // MARK: - Equality

    public override var hash: Int {
        return eventId.hash
    }

    public override func isEqual(_ object: Any?) -> Bool {
        guard let otherObj = object as? SFSDKInstrumentationEvent else {
            return false
        }

        // Since event ID is globally unique and is set during construction of the event,
        // if the event IDs of both events are equal, the events themselves are the same.
        return self.eventId == otherObj.eventId
    }

    // MARK: - Public methods

    /// Returns a JSON representation of this event.
    ///
    /// - Returns: JSON representation.
    @objc
    public func jsonRepresentation() -> Data {
        let dict = jsonDictionary()
        guard let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: []) else {
            return Data()
        }
        return jsonData
    }

    /// Returns a string representation of schema type.
    ///
    /// - Parameter schemaType: Schema type.
    /// - Returns: String representation of schema type.
    @objc
    public func stringValue(ofSchemaType schemaType: SFASchemaType) -> String {
        switch schemaType {
        case .interaction:
            return "LightningInteraction"
        case .pageView:
            return "LightningPageView"
        case .perf:
            return "LightningPerformance"
        case .error:
            return "LightningError"
        }
    }

    /// Returns a string representation of event type.
    ///
    /// - Parameter eventType: Event type.
    /// - Returns: String representation of event type.
    @objc
    public func stringValue(ofEventType eventType: SFAEventType) -> String {
        switch eventType {
        case .user:
            return "user"
        case .system:
            return "system"
        case .error:
            return "error"
        case .crud:
            return "crud"
        }
    }

    /// Returns a string representation of error type.
    ///
    /// - Parameter errorType: Error type.
    /// - Returns: String representation of error type.
    @objc
    public func stringValue(ofErrorType errorType: SFAErrorType) -> String {
        switch errorType {
        case .info:
            return "info"
        case .warn:
            return "warn"
        case .error:
            return "error"
        }
    }

    // MARK: - Internal methods

    /// Returns a JSON dictionary representation of this event.
    ///
    /// - Returns: JSON dictionary representation.
    @objc
    public func jsonDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            kEventIdKey: eventId,
            kStartTimeKey: NSNumber(value: startTime),
            kEndTimeKey: NSNumber(value: endTime),
            kNameKey: name,
            kSequenceIdKey: NSNumber(value: sequenceId),
            kSchemaTypeKey: stringValue(ofSchemaType: schemaType),
            kEventTypeKey: stringValue(ofEventType: eventType),
            kErrorTypeKey: stringValue(ofErrorType: errorType),
            kConnectionTypeKey: connectionType,
            kSessionStartTimeKey: NSNumber(value: sessionStartTime)
        ]

        if let attributes = attributes {
            dict[kAttributesKey] = attributes
        }
        if let sessionId = sessionId {
            dict[kSessionIdKey] = sessionId
        }
        if let senderId = senderId {
            dict[kSenderIdKey] = senderId
        }
        if let senderContext = senderContext {
            dict[kSenderContextKey] = senderContext
        }
        dict[kDeviceAppAttributesKey] = deviceAppAttributes.jsonRepresentation()
        if let senderParentId = senderParentId {
            dict[kSenderParentIdKey] = senderParentId
        }
        if let page = page {
            dict[kPageKey] = page
        }
        if let previousPage = previousPage {
            dict[kPreviousPageKey] = previousPage
        }
        if let marks = marks {
            dict[kMarksKey] = marks
        }

        return dict
    }

    // MARK: - Private methods

    private static func schemaType(from string: String) -> SFASchemaType {
        switch string {
        case "LightningInteraction":
            return .interaction
        case "LightningPageView":
            return .pageView
        case "LightningPerformance":
            return .perf
        case "LightningError":
            return .error
        default:
            return .error
        }
    }

    private static func eventType(from string: String) -> SFAEventType {
        switch string {
        case "user":
            return .user
        case "system":
            return .system
        case "error":
            return .error
        case "crud":
            return .crud
        default:
            return .error
        }
    }

    private static func errorType(from string: String) -> SFAErrorType {
        switch string {
        case "info":
            return .info
        case "warn":
            return .warn
        case "error":
            return .error
        default:
            return .error
        }
    }
}
