/*
 SFSDKAILTNTransform.swift
 SalesforceAnalytics

 Created by Bharath Hariharan on 6/16/16.

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

private let kSFConnectionTypeKey = "connectionType"
private let kSFVersionKey = "version"
private let kSFVersionValue = "0.2"
private let kSFSchemaTypeKey = "schemaType"
private let kSFIdKey = "id"
private let kSFEventSourceKey = "eventSource"
private let kSFTsKey = "ts"
private let kSFPageStartTimeKey = "pageStartTime"
private let kSFDurationKey = "duration"
private let kSFEptKey = "ept"
private let kSFClientSessionIdKey = "clientSessionId"
private let kSFSequenceKey = "sequence"
private let kSFAttributesKey = "attributes"
private let kSFLocatorKey = "locator"
private let kSFEventTypeKey = "eventType"
private let kSFErrorTypeKey = "errorType"
private let kSFTargetKey = "target"
private let kSFScopeKey = "scope"
private let kSFContextKey = "context"
private let kSFDeviceAttributesKey = "deviceAttributes"
private let kSFPageKey = "page"
private let kSFPreviousPageKey = "previousPage"
private let kSFMarksKey = "marks"
private let kSFPerfEventType = "defs"

@objc(SFSDKAILTNTransform)
public class SFSDKAILTNTransform: NSObject, SFSDKTransform {

    @objc
    public func transform(_ event: SFSDKInstrumentationEvent) -> Any? {
        var logLine: [String: Any] = [:]

        if let payload = SFSDKAILTNTransform.buildPayload(event) {
            logLine = payload
            logLine[kSFDeviceAttributesKey] = SFSDKAILTNTransform.buildDeviceAttributes(event)
        }

        return logLine
    }

    // MARK: - Private class methods

    private static func buildDeviceAttributes(_ event: SFSDKInstrumentationEvent) -> [String: Any] {
        var deviceAttributes = event.deviceAppAttributes.jsonRepresentation()
        deviceAttributes[kSFConnectionTypeKey] = event.connectionType
        return deviceAttributes
    }

    private static func buildPayload(_ event: SFSDKInstrumentationEvent) -> [String: Any]? {
        var payload: [String: Any] = [:]

        payload[kSFVersionKey] = kSFVersionValue

        let schemaType = event.schemaType
        payload[kSFSchemaTypeKey] = event.stringValue(ofSchemaType: schemaType)
        payload[kSFIdKey] = event.eventId
        payload[kSFEventSourceKey] = event.name

        let startTime = event.startTime
        payload[kSFTsKey] = NSNumber(value: startTime)
        payload[kSFPageStartTimeKey] = NSNumber(value: event.sessionStartTime)

        let endTime = event.endTime
        let duration = endTime - startTime

        if duration > 0 {
            if schemaType == .interaction || schemaType == .perf {
                payload[kSFDurationKey] = NSNumber(value: duration)
            } else if schemaType == .pageView {
                payload[kSFEptKey] = NSNumber(value: duration)
            }
        }

        if let sessionId = event.sessionId {
            payload[kSFClientSessionIdKey] = sessionId
        }

        if schemaType != .perf {
            payload[kSFSequenceKey] = NSNumber(value: event.sequenceId)
        }

        if let attributes = event.attributes {
            payload[kSFAttributesKey] = attributes
        }

        if schemaType != .perf {
            payload[kSFPageKey] = event.page
        }

        if let previousPage = event.previousPage, schemaType == .pageView {
            payload[kSFPreviousPageKey] = previousPage
        }

        if let marks = event.marks, (schemaType == .pageView || schemaType == .perf) {
            payload[kSFMarksKey] = marks
        }

        if schemaType == .interaction || schemaType == .pageView {
            if let locator = SFSDKAILTNTransform.buildLocator(event) {
                payload[kSFLocatorKey] = locator
            }
        }

        let eventType = event.eventType
        var eventTypeString: String?

        if schemaType == .perf {
            eventTypeString = kSFPerfEventType
        } else if schemaType == .interaction {
            eventTypeString = event.stringValue(ofEventType: eventType)
        }

        if let eventTypeString = eventTypeString {
            payload[kSFEventTypeKey] = eventTypeString
        }

        let errorType = event.errorType
        if schemaType == .error {
            payload[kSFErrorTypeKey] = event.stringValue(ofErrorType: errorType)
        }

        return payload
    }

    private static func buildLocator(_ event: SFSDKInstrumentationEvent) -> [String: Any]? {
        guard let senderId = event.senderId,
              let senderParentId = event.senderParentId else {
            return nil
        }

        var locator: [String: Any] = [:]
        locator[kSFTargetKey] = senderId
        locator[kSFScopeKey] = senderParentId

        if let senderContext = event.senderContext {
            locator[kSFContextKey] = senderContext
        }

        return locator
    }
}
