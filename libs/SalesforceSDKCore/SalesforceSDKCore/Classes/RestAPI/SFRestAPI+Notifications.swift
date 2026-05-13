//
//  SFRestAPI+Notifications.swift
//  SalesforceSDKCore
//
//  Created by Brianna Birman on 4/7/20.
//  Copyright (c) 2020-present, salesforce.com, inc. All rights reserved.
//
//  Redistribution and use of this software in source and binary forms, with or without modification,
//  are permitted provided that the following conditions are met:
//  * Redistributions of source code must retain the above copyright notice, this list of conditions
//  and the following disclaimer.
//  * Redistributions in binary form must reproduce the above copyright notice, this list of
//  conditions and the following disclaimer in the documentation and/or other materials provided
//  with the distribution.
//  * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
//  endorse or promote products derived from this software without specific prior written
//  permission of salesforce.com, inc.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
//  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
//  FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
//  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
//  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
//  WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import Foundation

@objc
extension RestClient {

    /**
     * Returns a request to fetch the status of notifications, including unread and unseen count.
     * @param apiVersion API version.
     * @see https://developer.salesforce.com/docs/atlas.en-us.chatterapi.meta/chatterapi/connect_resources_notifications_status.htm
     */
    @objc
    public func requestForNotificationsStatus(_ apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/connect/notifications/status"
        return RestRequest.request(withMethod: .GET, path: path, queryParams: nil)
    }

    /**
     * Returns a request to fetch the given notification.
     * @param notificationId ID of notification to fetch.
     * @param apiVersion API version.
     * @see https://developer.salesforce.com/docs/atlas.en-us.chatterapi.meta/chatterapi/connect_resource_notifications_specific.htm
     */
    @objc
    public func requestForNotification(_ notificationId: String, apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/connect/notifications/\(notificationId)"
        return RestRequest.request(withMethod: .GET, path: path, queryParams: nil)
    }

    /**
     * Returns an `RestRequest` object to retrieve the available notification types.
     * The notification types define the possible push notifications the app can handle,
     * including their structure and associated actions.
     *
     * This method automatically uses the default API version.
     *
     * @return An `RestRequest` object for fetching the notification types.
     */
    @objc
    public func requestForNotificationTypes() -> RestRequest {
        return requestForNotificationTypesWithVersion(apiVersion)
    }

    /**
     * Returns an `RestRequest` object to retrieve the available notification types.
     * The notification types define the possible push notifications the app can handle,
     * including their structure and associated actions.
     *
     * @param apiVersion The API version to use. If `nil`, the default API version is used.
     * @return An `RestRequest` object for fetching the notification types.
     */
    @objc
    public func requestForNotificationTypesWithVersion(_ apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/connect/notifications/types"
        return RestRequest.request(withMethod: .GET, path: path, queryParams: nil)
    }

    /**
     * Returns an `RestRequest` object to invoke a server-side action for a specific notification.
     * This is used when the user selects an action on a notification, and the action requires
     * processing.
     *
     * This method automatically uses the default API version.
     *
     * @param notificationId The unique identifier of the notification.
     * @param actionIdentifier The identifier of the action to invoke on the server.
     * @return An `RestRequest` object for invoking a server-side notification action.
     */
    @objc
    public func requestForInvokeNotificationAction(_ notificationId: String, actionIdentifier: String) -> RestRequest {
        return requestForInvokeNotificationAction(notificationId, actionIdentifier: actionIdentifier, apiVersion: apiVersion)
    }

    /**
     * Returns an `RestRequest` object to invoke a server-side action for a specific notification.
     * This is used when the user selects an action on a notification, and the action requires
     * processing.
     *
     * @param notificationId The unique identifier of the notification.
     * @param actionIdentifier The identifier of the action to invoke on the server.
     * @param apiVersion The API version to use. If `nil`, the default API version is used.
     * @return An `RestRequest` object for invoking a server-side notification action.
     */
    @objc
    public func requestForInvokeNotificationAction(_ notificationId: String, actionIdentifier: String, apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/connect/notifications/\(notificationId)/actions/\(actionIdentifier)"
        return RestRequest.request(withMethod: .POST, path: path, queryParams: nil)
    }
}

/**
 * Use this interface to create a RestRequest object that calls the Notifications REST API.
 * @see https://developer.salesforce.com/docs/atlas.en-us.chatterapi.meta/chatterapi/connect_resources_notifications_list.htm
 */
@objc(SFSDKFetchNotificationsRequestBuilder)
@objcMembers
public class FetchNotificationsRequestBuilder: NSObject {

    private var parameters = NSMutableDictionary()

    /**
     * Sets the number of notifications to fetch. Max and default are 20.
     * @param size Number of notifications to fetch.
     */
    @objc
    @discardableResult
    public func setSize(_ size: UInt) -> FetchNotificationsRequestBuilder {
        parameters["size"] = "\(size)"
        return self
    }

    /**
     * Notifications occurring before the provided date will be fetched. Shouldn't be used with `setAfter`.
     * @param date Before date. If unspecified, defaults to current date and time.
     */
    @objc
    @discardableResult
    public func setBefore(_ date: Date) -> FetchNotificationsRequestBuilder {
        parameters["before"] = FormatUtils.getIsoStringFromDate( date)
        return self
    }

    /**
     * Notifications occurring after the provided date will be fetched. Shouldn't be used with `setBefore`.
     * @param date After date.
     */
    @objc
    @discardableResult
    public func setAfter(_ date: Date) -> FetchNotificationsRequestBuilder {
        parameters["after"] = FormatUtils.getIsoStringFromDate( date)
        return self
    }

    /**
     * Returns a request to fetch notifications based on values from the builder.
     * @param apiVersion API version.
     */
    @objc
    public func buildFetchNotificationsRequest(_ apiVersion: String) -> RestRequest {
        let path = "/\(apiVersion)/connect/notifications"
        return RestRequest.request(withMethod: .GET, path: path, queryParams: parameters as? [String: String])
    }
}

/**
 * Use this interface to create a PATCH RestRequest object that calls the Notifications REST API.
 * @see https://developer.salesforce.com/docs/atlas.en-us.chatterapi.meta/chatterapi/connect_resources_notifications_list.htm
 * @see https://developer.salesforce.com/docs/atlas.en-us.chatterapi.meta/chatterapi/connect_resource_notifications_specific.htm
 */
@objc(SFSDKUpdateNotificationsRequestBuilder)
@objcMembers
public class UpdateNotificationsRequestBuilder: NSObject {

    private var parameters = NSMutableDictionary()
    private var notifId: String?

    /**
     * Sets the notification to update. Shouldn't be used with `setNotificationIds` or `setBefore`.
     * @param notificationId ID of notification to update.
     */
    @objc
    @discardableResult
    public func setNotificationId(_ notificationId: String) -> UpdateNotificationsRequestBuilder {
        self.notifId = notificationId
        return self
    }

    /**
     * Sets a list of notifications to update (max 50). Shouldn't be used with `setNotificationId` or `setBefore`.
     * @param notificationIds Array of notifications IDs to update.
     */
    @objc
    @discardableResult
    public func setNotificationIds(_ notificationIds: [String]) -> UpdateNotificationsRequestBuilder {
        parameters["notificationIds"] = notificationIds
        return self
    }

    /**
     * Notifications occurring before the provided date will be updated. Shouldn't be used with `setNotificationId` or `setNotificationIds`.
     * @param date Before date. If unspecified, defaults to current date and time.
     */
    @objc
    @discardableResult
    public func setBefore(_ date: Date) -> UpdateNotificationsRequestBuilder {
        parameters["before"] = FormatUtils.getIsoStringFromDate( date)
        return self
    }

    /**
     * Marks the notification(s) as seen (true) or unseen (false)
     * @param seen If the notification is seen or not.
     */
    @objc
    @discardableResult
    public func setSeen(_ seen: Bool) -> UpdateNotificationsRequestBuilder {
        parameters["seen"] = seen ? "true" : "false"
        return self
    }

    /**
     * Marks the notification(s) as read (true) or unread (false)
     * @param read If the notification is read or not.
     */
    @objc
    @discardableResult
    public func setRead(_ read: Bool) -> UpdateNotificationsRequestBuilder {
        parameters["read"] = read ? "true" : "false"
        return self
    }

    /**
     * Returns a request to update notifications based on values from the builder.
     * @param apiVersion API version.
     */
    @objc
    public func buildUpdateNotificationsRequest(_ apiVersion: String) -> RestRequest {
        let path: String
        if let notifId = notifId {
            path = "/\(apiVersion)/connect/notifications/\(notifId)"
        } else {
            path = "/\(apiVersion)/connect/notifications"
        }

        let request = RestRequest.request(withMethod: .PATCH, path: path, queryParams: nil)
        request.setCustomRequestBodyDictionary(parameters as NSDictionary as! [String: Any], contentType: "application/json")
        return request
    }
}
