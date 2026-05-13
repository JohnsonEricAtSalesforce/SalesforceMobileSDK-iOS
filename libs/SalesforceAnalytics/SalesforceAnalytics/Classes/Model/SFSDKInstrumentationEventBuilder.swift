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

@objc(SFSDKInstrumentationEventBuilder)
public class SFSDKInstrumentationEventBuilder: NSObject {

    @objc public var startTime: Int = 0
    @objc public var endTime: Int = 0
    @objc public var name: String = ""
    @objc public var attributes: [String: Any]?
    @objc public var sessionId: String?
    @objc public var senderId: String?
    @objc public var senderContext: [String: Any]?
    @objc public var schemaType: SFASchemaType = .error
    @objc public var eventType: SFAEventType = .error
    @objc public var errorType: SFAErrorType = .error
    @objc public var senderParentId: String?
    @objc public var sessionStartTime: Int = 0
    @objc public var page: [String: Any]?
    @objc public var previousPage: [String: Any]?
    @objc public var marks: [String: Any]?

    private var analyticsManager: SFSDKAnalyticsManager?

    /// Builds the event. Returns nil if required fields are missing.
    ///
    /// - Parameters:
    ///   - builderBlock: Block that configures the event builder.
    ///   - analyticsManager: Analytics manager.
    /// - Returns: Event instance.
    @objc
    public class func buildEvent(
        withBuilderBlock builderBlock: @escaping (SFSDKInstrumentationEventBuilder) -> Void,
        analyticsManager: SFSDKAnalyticsManager
    ) -> SFSDKInstrumentationEvent? {
        let builder = SFSDKInstrumentationEventBuilder(analyticsManager: analyticsManager)
        builderBlock(builder)
        return builder.buildEvent()
    }

    @objc
    init(analyticsManager: SFSDKAnalyticsManager) {
        self.analyticsManager = analyticsManager
        super.init()
    }

    private func buildEvent() -> SFSDKInstrumentationEvent? {
        let eventId = UUID().uuidString
        var errorMessage: String?

        if name.isEmpty {
            errorMessage = "Mandatory field 'name' not set!"
        }

        guard let deviceAppAttributes = analyticsManager?.deviceAttributes else {
            errorMessage = "Mandatory field 'device app attributes' not set!"
            SFSDKAnalyticsLogger.w(type(of: self), message: "WARNING: Building event failed! REASON: \(errorMessage ?? "")")
            return nil
        }

        if schemaType != .perf && page == nil {
            errorMessage = "Mandatory field 'page' not set!"
        }

        if let errorMessage = errorMessage {
            SFSDKAnalyticsLogger.w(type(of: self), message: "WARNING: Building event failed! REASON: \(errorMessage)")
            return nil
        }

        guard let manager = analyticsManager else {
            return nil
        }

        let sequenceId = manager.globalSequenceId + 1
        manager.globalSequenceId = sequenceId

        // Defaults to current time if not explicitly set.
        let curTime = Int(Date().timeIntervalSince1970 * 1000)
        self.startTime = (self.startTime == 0) ? curTime : self.startTime
        self.sessionStartTime = (self.sessionStartTime == 0) ? curTime : self.sessionStartTime

        let event = SFSDKInstrumentationEvent(
            eventId: eventId,
            startTime: self.startTime,
            endTime: self.endTime,
            name: self.name,
            attributes: self.attributes,
            sessionId: self.sessionId,
            sequenceId: sequenceId,
            senderId: self.senderId,
            senderContext: self.senderContext,
            schemaType: self.schemaType,
            eventType: self.eventType,
            errorType: self.errorType,
            deviceAppAttributes: deviceAppAttributes,
            connectionType: getConnectionType(),
            senderParentId: self.senderParentId,
            sessionStartTime: self.sessionStartTime,
            page: self.page,
            previousPage: self.previousPage,
            marks: self.marks
        )

        if JSONSerialization.isValidJSONObject(event.jsonDictionary()) {
            return event
        } else {
            SFSDKAnalyticsLogger.w(type(of: self), message: "WARNING: Building event failed! REASON: Invalid JSON properties set!")
            return nil
        }
    }

    private func getConnectionType() -> String {
        let defaultType = "Unknown"

        #if os(visionOS)
        return defaultType
        #else
        let reachability = SFSDKReachability.reachabilityForInternetConnection()
        reachability?.startNotifier()
        let networkStatus = reachability?.currentReachabilityStatus() ?? .notReachable

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

        #if canImport(CoreTelephony)
        let telephonyInfo = CTTelephonyNetworkInfo()
        if let subType = telephonyInfo.serviceCurrentRadioAccessTechnology?.values.first {
            type = "Mobile;\(subType)"
        }
        #endif

        return type
    }
}
