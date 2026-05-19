// SFSDKEventBuilderHelper.swift
// SalesforceSDKCore
//
// Created by Bharath Hariharan on 11/9/16.
// Copyright (c) 2016-present, salesforce.com, inc. All rights reserved.
//
// Redistribution and use of this software in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
// * Redistributions of source code must retain the above copyright notice, this list of conditions
// and the following disclaimer.
// * Redistributions in binary form must reproduce the above copyright notice, this list of
// conditions and the following disclaimer in the documentation and/or other materials provided
// with the distribution.
// * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
// endorse or promote products derived from this software without specific prior written
// permission of salesforce.com, inc.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
// IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
// FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
// CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
// WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
// WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import Foundation
import SalesforceAnalytics

@objc(SFSDKEventBuilderHelper)
@objcMembers
public class SFSDKEventBuilderHelper: NSObject {

    @objc public static let startTimeKey = "startTime"
    @objc public static let endTimeKey = "endTime"

    @objc public class func createAndStoreEvent(_ name: String, userAccount: UserAccount?, className: String, attributes: [String: Any]?) {
        var account = userAccount
        if account == nil {
            account = UserAccountManager.shared.currentUserAccount
        }
        guard let account = account else { return }

        guard let manager = SFSDKSalesforceAnalyticsManager.sharedInstance(with: account) else { return }

        let event = SFSDKInstrumentationEventBuilder.buildEvent(builderBlock: { builder in
            builder.name = name
            if let startTime = attributes?[SFSDKEventBuilderHelper.startTimeKey] as? NSNumber {
                builder.startTime = startTime.intValue
            }
            if let endTime = attributes?[SFSDKEventBuilderHelper.endTimeKey] as? NSNumber {
                builder.endTime = endTime.intValue
            }
            builder.page = ["context": className] as NSDictionary
            if let attributes = attributes {
                builder.attributes = attributes as NSDictionary
            }
            builder.schemaType = .interaction
            builder.eventType = .system
        }, analyticsManager: manager.analyticsManager)

        manager.analyticsManager.storeManager.storeEvent(event)
    }
}
