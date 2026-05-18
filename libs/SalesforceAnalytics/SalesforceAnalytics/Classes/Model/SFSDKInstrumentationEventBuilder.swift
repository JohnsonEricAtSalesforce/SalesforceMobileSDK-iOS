/*
 SFSDKInstrumentationEventBuilder.swift
 SalesforceAnalytics

 Created by Bharath Hariharan on 6/5/16.

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
#if canImport(CoreTelephony)
import CoreTelephony
#endif

/// Builder for instrumentation events.
@objc(SFSDKInstrumentationEventBuilder)
@objcMembers
public class SFSDKInstrumentationEventBuilder: NSObject {

    // MARK: - Public Properties

    public var startTime: Int = 0
    public var endTime: Int = 0
    public var name: String = ""
    public var attributes: NSDictionary?
    public var sessionId: String?
    public var senderId: String?
    public var senderContext: NSDictionary?
    public var schemaType: SFASchemaType = .interaction
    public var eventType: SFAEventType = .user
    public var errorType: SFAErrorType = .info
    public var senderParentId: String?
    public var sessionStartTime: Int = 0
    public var page: NSDictionary?
    public var previousPage: NSDictionary?
    public var marks: NSDictionary?

    // MARK: - Private Properties

    private var analyticsManager: SFSDKAnalyticsManager

    // MARK: - Public Class Methods

    /// Builds the event using a builder block. Returns nil if required fields are missing.
    ///
    /// - Parameters:
    ///   - builderBlock: Block that configures the builder.
    ///   - analyticsManager: Analytics manager instance.
    /// - Returns: Event instance, or nil if validation fails.
    @objc(buildEventWithBuilderBlock:analyticsManager:)
    public class func buildEvent(builderBlock: @escaping (SFSDKInstrumentationEventBuilder) -> Void, analyticsManager: SFSDKAnalyticsManager) -> SFSDKInstrumentationEvent? {
        let builder = SFSDKInstrumentationEventBuilder(analyticsManager: analyticsManager)
        builderBlock(builder)
        return builder.buildEvent()
    }

    // MARK: - Private Initializer

    private init(analyticsManager: SFSDKAnalyticsManager) {
        self.analyticsManager = analyticsManager
        super.init()
    }

    // MARK: - Private Methods

    private func buildEvent() -> SFSDKInstrumentationEvent? {
        let eventId = UUID().uuidString
        var errorMessage: String?

        if name.isEmpty {
            errorMessage = "Mandatory field 'name' not set!"
        }

        guard let deviceAppAttributes = analyticsManager.deviceAttributes else {
            SFSDKAnalyticsLogger.w(SFSDKInstrumentationEventBuilder.self, format: "WARNING: Building event failed! REASON: %@", "Mandatory field 'device app attributes' not set!")
            return nil
        }
        if schemaType != .perf && page == nil {
            errorMessage = "Mandatory field 'page' not set!"
        }

        if let errorMessage = errorMessage {
            SFSDKAnalyticsLogger.w(SFSDKInstrumentationEventBuilder.self, format: "WARNING: Building event failed! REASON: %@", errorMessage)
            return nil
        }

        let sequenceId = analyticsManager.globalSequenceId + 1
        analyticsManager.globalSequenceId = sequenceId

        // Defaults to current time if not explicitly set.
        let curTime = Int(Date().timeIntervalSince1970 * 1000)
        if startTime == 0 {
            startTime = curTime
        }
        if sessionStartTime == 0 {
            sessionStartTime = curTime
        }

        let event = SFSDKInstrumentationEvent(
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
            connectionType: getConnectionType(),
            senderParentId: senderParentId,
            sessionStartTime: sessionStartTime,
            page: page,
            previousPage: previousPage,
            marks: marks
        )

        if JSONSerialization.isValidJSONObject(event.jsonDictionary()) {
            return event
        } else {
            SFSDKAnalyticsLogger.w(SFSDKInstrumentationEventBuilder.self, format: "WARNING: Building event failed! REASON: Invalid JSON properties set!")
            return nil
        }
    }

    private func getConnectionType() -> String {
        let defaultType = "Unknown"
        #if os(visionOS)
        return defaultType
        #else
        guard let reachability = SFSDKReachability.reachabilityForInternetConnection() else {
            return defaultType
        }
        _ = reachability.startNotifier()
        let networkStatus = reachability.currentReachabilityStatus()
        switch networkStatus {
        case .notReachable:
            return "None"
        case .reachableViaWWAN:
            return getMobileConnectionSubType()
        case .reachableViaWiFi:
            return "WiFi"
        @unknown default:
            return defaultType
        }
        #endif
    }

    private func getMobileConnectionSubType() -> String {
        var type = "Mobile"
        #if canImport(CoreTelephony) && !os(visionOS)
        let telephonyInfo = CTTelephonyNetworkInfo()
        if let subType = telephonyInfo.serviceCurrentRadioAccessTechnology?.values.first {
            type = "Mobile;\(subType)"
        }
        #endif
        return type
    }
}
