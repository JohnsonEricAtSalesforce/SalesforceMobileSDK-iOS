//
//  SFRestAPI+Notifications.swift
//  SalesforceSDKCore
//
//  Copyright (c) 2020-present, salesforce.com, inc. All rights reserved.
//
//  Redistribution and use of this software in source and binary forms, with or without modification,
//  are permitted provided that the following conditions are met:
//  * Redistributions of source code must retain the above copyright notice, this list of conditions
//    and the following disclaimer.
//  * Redistributions in binary form must reproduce the above copyright notice, this list of
//    conditions and the following disclaimer in the documentation and/or other materials provided
//    with the distribution.
//  * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
//    endorse or promote products derived from this software without specific prior written
//    permission of salesforce.com, inc.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
//  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
//  FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
//  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
//  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
//  WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

import Foundation

// MARK: - RestClient Notifications Extension

extension RestClient {

    /// Returns a request to fetch the status of notifications.
    @objc public func requestForNotificationsStatus(_ apiVersion: String) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/connect/notifications/status"
        return RestRequest(method: .GET, path: path, queryParams: nil)
    }

    /// Returns a request to fetch a specific notification.
    @objc public func requestForNotification(_ notificationId: String, apiVersion: String) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/connect/notifications/\(notificationId)"
        return RestRequest(method: .GET, path: path, queryParams: nil)
    }

    /// Returns a request to retrieve the available notification types using the default API version.
    @objc public func requestForNotificationTypes() -> RestRequest {
        return requestForNotificationTypes(withVersion: apiVersion)
    }

    /// Returns a request to retrieve the available notification types.
    @objc public func requestForNotificationTypes(withVersion apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/connect/notifications/types"
        return RestRequest(method: .GET, path: path, queryParams: nil)
    }

    /// Returns a request to invoke a server-side action for a specific notification using the default API version.
    @objc public func requestForInvokeNotificationAction(_ notificationId: String, actionIdentifier: String) -> RestRequest {
        return requestForInvokeNotificationAction(notificationId, actionIdentifier: actionIdentifier, apiVersion: apiVersion)
    }

    /// Returns a request to invoke a server-side action for a specific notification.
    @objc public func requestForInvokeNotificationAction(_ notificationId: String, actionIdentifier: String, apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/connect/notifications/\(notificationId)/actions/\(actionIdentifier)"
        return RestRequest(method: .POST, path: path, queryParams: nil)
    }
}

// MARK: - FetchNotificationsRequestBuilder

/// Use this class to create a RestRequest object that calls the Notifications REST API.
@objcMembers
@objc(SFSDKFetchNotificationsRequestBuilder)
public class FetchNotificationsRequestBuilder: NSObject {

    private var parameters: [String: Any] = [:]

    /// Sets the number of notifications to fetch. Max and default are 20.
    @objc @discardableResult
    public func setSize(_ size: UInt) -> FetchNotificationsRequestBuilder {
        parameters["size"] = String(size)
        return self
    }

    /// Notifications occurring before the provided date will be fetched.
    @objc @discardableResult
    public func setBefore(_ date: Date) -> FetchNotificationsRequestBuilder {
        parameters["before"] = FormatUtils.getIsoString(from: date)
        return self
    }

    /// Notifications occurring after the provided date will be fetched.
    @objc @discardableResult
    public func setAfter(_ date: Date) -> FetchNotificationsRequestBuilder {
        parameters["after"] = FormatUtils.getIsoString(from: date)
        return self
    }

    /// Returns a request to fetch notifications based on values from the builder.
    @objc public func buildFetchNotificationsRequest(_ apiVersion: String) -> RestRequest {
        let path = "/\(apiVersion)/connect/notifications"
        return RestRequest(method: .GET, path: path, queryParams: parameters.isEmpty ? nil : parameters)
    }
}

// MARK: - UpdateNotificationsRequestBuilder

/// Use this class to create a PATCH RestRequest object that calls the Notifications REST API.
@objcMembers
@objc(SFSDKUpdateNotificationsRequestBuilder)
public class UpdateNotificationsRequestBuilder: NSObject {

    private var parameters: [String: Any] = [:]
    private var notifId: String?

    /// Sets the notification to update.
    @objc @discardableResult
    public func setNotificationId(_ notificationId: String) -> UpdateNotificationsRequestBuilder {
        notifId = notificationId
        return self
    }

    /// Sets a list of notifications to update (max 50).
    @objc @discardableResult
    public func setNotificationIds(_ notificationIds: [String]) -> UpdateNotificationsRequestBuilder {
        parameters["notificationIds"] = notificationIds
        return self
    }

    /// Notifications occurring before the provided date will be updated.
    @objc @discardableResult
    public func setBefore(_ date: Date) -> UpdateNotificationsRequestBuilder {
        parameters["before"] = FormatUtils.getIsoString(from: date)
        return self
    }

    /// Marks the notification(s) as seen (true) or unseen (false).
    @objc @discardableResult
    public func setSeen(_ seen: Bool) -> UpdateNotificationsRequestBuilder {
        parameters["seen"] = seen ? "true" : "false"
        return self
    }

    /// Marks the notification(s) as read (true) or unread (false).
    @objc @discardableResult
    public func setRead(_ read: Bool) -> UpdateNotificationsRequestBuilder {
        parameters["read"] = read ? "true" : "false"
        return self
    }

    /// Returns a request to update notifications based on values from the builder.
    @objc public func buildUpdateNotificationsRequest(_ apiVersion: String) -> RestRequest {
        let path: String
        if let notifId = notifId {
            path = "/\(apiVersion)/connect/notifications/\(notifId)"
        } else {
            path = "/\(apiVersion)/connect/notifications"
        }
        let request = RestRequest(method: .PATCH, path: path, queryParams: nil)
        request.setCustomRequestBodyDictionary(parameters, contentType: "application/json")
        return request
    }
}
