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

// MARK: - JSON Keys

private let kEventIdKey = "eventId"
private let kStartTimeKey = "startTime"
private let kEndTimeKey = "endTime"
private let kNameKey = "name"
private let kAttributesKey = "attributes"
private let kSessionIdKey = "sessionId"
private let kSequenceIdKey = "sequenceId"
private let kSenderIdKey = "senderId"
private let kSenderContextKey = "senderContext"
private let kSchemaTypeKey = "schemaType"
private let kEventTypeKey = "eventType"
private let kErrorTypeKey = "errorType"
private let kConnectionTypeKey = "connectionType"
private let kDeviceAppAttributesKey = "deviceAppAttributes"
private let kSenderParentIdKey = "senderParentId"
private let kSessionStartTimeKey = "sessionStartTime"
private let kPageKey = "page"
private let kPreviousPageKey = "previousPage"
private let kMarksKey = "marks"

// MARK: - Enums

/// Represents the type of schema being logged.
@objc(SFASchemaType)
public enum SFASchemaType: Int {
    @objc(SchemaTypeInteraction)
    case interaction = 0
    @objc(SchemaTypePageView)
    case pageView
    @objc(SchemaTypePerf)
    case perf
    @objc(SchemaTypeError)
    case error
}

/// Represents the type of event being logged.
@objc(SFAEventType)
public enum SFAEventType: Int {
    @objc(EventTypeUser)
    case user = 0
    @objc(EventTypeSystem)
    case system
    @objc(EventTypeError)
    case error
    @objc(EventTypeCrud)
    case crud
}

/// Represents the type of error being logged.
@objc(SFAErrorType)
public enum SFAErrorType: Int {
    @objc(ErrorTypeInfo)
    case info = 0
    @objc(ErrorTypeWarn)
    case warn
    @objc(ErrorTypeError)
    case error
}

// MARK: - SFSDKInstrumentationEvent

/// Represents an instrumentation event for analytics.
@objc(SFSDKInstrumentationEvent)
@objcMembers
public class SFSDKInstrumentationEvent: NSObject, NSCopying {

    // MARK: - Properties

    public private(set) var eventId: String
    public private(set) var startTime: Int
    public private(set) var endTime: Int
    public private(set) var name: String
    public private(set) var attributes: NSDictionary?
    public private(set) var sessionId: String?
    public private(set) var sequenceId: Int
    public private(set) var senderId: String?
    public private(set) var senderContext: NSDictionary?
    public private(set) var schemaType: SFASchemaType
    public private(set) var eventType: SFAEventType
    public private(set) var errorType: SFAErrorType
    public private(set) var deviceAppAttributes: SFSDKDeviceAppAttributes
    public private(set) var connectionType: String
    public private(set) var senderParentId: String?
    public private(set) var sessionStartTime: Int
    public private(set) var page: NSDictionary?
    public private(set) var previousPage: NSDictionary?
    public private(set) var marks: NSDictionary?

    // MARK: - Internal Initializer (used by builder)

    @objc(initWithEventId:startTime:endTime:name:attributes:sessionId:sequenceId:senderId:senderContext:schemaType:eventType:errorType:deviceAppAttributes:connectionType:senderParentId:sessionStartTime:page:previousPage:marks:)
    public init(eventId: String, startTime: Int, endTime: Int, name: String, attributes: NSDictionary?, sessionId: String?, sequenceId: Int, senderId: String?, senderContext: NSDictionary?, schemaType: SFASchemaType, eventType: SFAEventType, errorType: SFAErrorType, deviceAppAttributes: SFSDKDeviceAppAttributes, connectionType: String, senderParentId: String?, sessionStartTime: Int, page: NSDictionary?, previousPage: NSDictionary?, marks: NSDictionary?) {
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

    /// Parameterized initializer from JSON data.
    ///
    /// - Parameter jsonRepresentation: JSON data representation.
    @objc(initWithJson:)
    public init(json jsonRepresentation: Data) {
        let dict = SFJsonUtils.object(fromJSONData: jsonRepresentation) as? NSDictionary

        self.eventId = dict?[kEventIdKey] as? String ?? ""
        self.startTime = (dict?[kStartTimeKey] as? NSNumber)?.intValue ?? 0
        self.endTime = (dict?[kEndTimeKey] as? NSNumber)?.intValue ?? 0
        self.name = dict?[kNameKey] as? String ?? ""
        self.attributes = dict?[kAttributesKey] as? NSDictionary
        self.sessionId = dict?[kSessionIdKey] as? String
        self.sequenceId = (dict?[kSequenceIdKey] as? NSNumber)?.intValue ?? 0
        self.senderId = dict?[kSenderIdKey] as? String
        self.senderContext = dict?[kSenderContextKey] as? NSDictionary
        self.connectionType = dict?[kConnectionTypeKey] as? String ?? ""
        self.senderParentId = dict?[kSenderParentIdKey] as? String
        self.sessionStartTime = (dict?[kSessionStartTimeKey] as? NSNumber)?.intValue ?? 0
        self.page = dict?[kPageKey] as? NSDictionary
        self.previousPage = dict?[kPreviousPageKey] as? NSDictionary
        self.marks = dict?[kMarksKey] as? NSDictionary

        // Schema type
        if let stringSchemaType = dict?[kSchemaTypeKey] as? String {
            self.schemaType = SFSDKInstrumentationEvent.schemaType(from: stringSchemaType)
        } else {
            self.schemaType = .error
        }

        // Event type
        if let stringEventType = dict?[kEventTypeKey] as? String {
            self.eventType = SFSDKInstrumentationEvent.eventType(from: stringEventType)
        } else {
            self.eventType = .error
        }

        // Error type
        if let stringErrorType = dict?[kErrorTypeKey] as? String {
            self.errorType = SFSDKInstrumentationEvent.errorType(from: stringErrorType)
        } else {
            self.errorType = .error
        }

        // Device app attributes
        if let deviceAttrDict = dict?[kDeviceAppAttributesKey] as? NSDictionary {
            self.deviceAppAttributes = SFSDKDeviceAppAttributes(json: deviceAttrDict)
        } else {
            // Provide a default to avoid uninitialized state
            self.deviceAppAttributes = SFSDKDeviceAppAttributes(appVersion: "", appName: "", osVersion: "", osName: "", nativeAppType: "", mobileSdkVersion: "", deviceModel: "", deviceId: "", clientId: "")
        }

        super.init()
    }

    // MARK: - NSCopying

    public func copy(with zone: NSZone? = nil) -> Any {
        let eventCopy = SFSDKInstrumentationEvent(
            eventId: eventId,
            startTime: startTime,
            endTime: endTime,
            name: name,
            attributes: attributes,
            sessionId: sessionId,
            sequenceId: sequenceId,
            senderId: senderId,
            senderContext: senderContext,
            schemaType: schemaType,
            eventType: eventType,
            errorType: errorType,
            deviceAppAttributes: deviceAppAttributes,
            connectionType: connectionType,
            senderParentId: senderParentId,
            sessionStartTime: sessionStartTime,
            page: page,
            previousPage: previousPage,
            marks: marks
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
        return eventId == otherObj.eventId
    }

    // MARK: - Public Methods

    /// Returns a JSON representation of this event.
    ///
    /// - Returns: JSON data representation.
    @objc public func jsonRepresentation() -> Data {
        let dict = jsonDictionary()
        let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: [])
        return jsonData ?? Data()
    }

    /// Returns a string representation of schema type.
    ///
    /// - Parameter schemaType: Schema type.
    /// - Returns: String representation of schema type.
    @objc(stringValueOfSchemaType:)
    public func stringValue(of schemaType: SFASchemaType) -> String {
        switch schemaType {
        case .interaction:
            return "LightningInteraction"
        case .pageView:
            return "LightningPageView"
        case .perf:
            return "LightningPerformance"
        case .error:
            return "LightningError"
        @unknown default:
            return "LightningError"
        }
    }

    /// Returns a string representation of event type.
    ///
    /// - Parameter eventType: Event type.
    /// - Returns: String representation of event type.
    @objc(stringValueOfEventType:)
    public func stringValue(of eventType: SFAEventType) -> String {
        switch eventType {
        case .user:
            return "user"
        case .system:
            return "system"
        case .error:
            return "error"
        case .crud:
            return "crud"
        @unknown default:
            return "error"
        }
    }

    /// Returns a string representation of error type.
    ///
    /// - Parameter errorType: Error type.
    /// - Returns: String representation of error type.
    @objc(stringValueOfErrorType:)
    public func stringValue(of errorType: SFAErrorType) -> String {
        switch errorType {
        case .info:
            return "info"
        case .warn:
            return "warn"
        case .error:
            return "error"
        @unknown default:
            return "error"
        }
    }

    // MARK: - Internal Methods

    /// Returns a JSON dictionary representation of this event.
    ///
    /// - Returns: JSON dictionary representation.
    @objc public func jsonDictionary() -> NSDictionary {
        let dict = NSMutableDictionary()
        dict[kEventIdKey] = eventId
        dict[kStartTimeKey] = NSNumber(value: startTime)
        dict[kEndTimeKey] = NSNumber(value: endTime)
        dict[kNameKey] = name
        dict[kAttributesKey] = attributes
        dict[kSessionIdKey] = sessionId
        dict[kSequenceIdKey] = NSNumber(value: sequenceId)
        dict[kSenderIdKey] = senderId
        dict[kSenderContextKey] = senderContext
        dict[kSchemaTypeKey] = stringValue(of: schemaType)
        dict[kEventTypeKey] = stringValue(of: eventType)
        dict[kErrorTypeKey] = stringValue(of: errorType)
        dict[kDeviceAppAttributesKey] = deviceAppAttributes.jsonRepresentation()
        dict[kConnectionTypeKey] = connectionType
        dict[kSenderParentIdKey] = senderParentId
        dict[kSessionStartTimeKey] = NSNumber(value: sessionStartTime)
        dict[kPageKey] = page
        dict[kPreviousPageKey] = previousPage
        dict[kMarksKey] = marks
        return dict
    }

    // MARK: - Private Static Helpers

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
