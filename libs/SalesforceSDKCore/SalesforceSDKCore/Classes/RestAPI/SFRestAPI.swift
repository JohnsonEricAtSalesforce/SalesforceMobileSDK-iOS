//
//  SFRestAPI.swift
//  SalesforceSDKCore
//
//  Copyright (c) 2011-present, salesforce.com, inc. All rights reserved.
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
import SalesforceSDKCommon

// MARK: - Type Aliases

public typealias RestRequestFailBlock = (_ response: Any?, _ error: Error?, _ rawResponse: URLResponse?) -> Void
public typealias RestResponseBlock = (_ response: Any?, _ rawResponse: URLResponse?) -> Void

// MARK: - Constants

/// Domain used for errors reported by the REST API (non-HTTP errors).
public let SFRestErrorDomain: String = "com.salesforce.RestAPI.ErrorDomain"

/// Error code used for all REST API errors (non-HTTP errors).
public let SFRestErrorCode: Int = 999

/// Default API version (currently "v66.0").
public let SFRestDefaultAPIVersion: String = "v66.0"

/// Misc keys appearing in requests.
public let SFRestIfUnmodifiedSince: String = "If-Unmodified-Since"

/// SOQL batch related constants.
public let SFRestSOQLMinBatchSize: Int = 200
public let SFRestSOQLMaxBatchSize: Int = 2000
public let SFRestSOQLDefaultBatchSize: Int = 2000
public let SFRestQueryOptions: String = "Sforce-Query-Options"

/// Other constants.
public let SFRestCollectionRetrieveMaxSize: Int = 2000

// MARK: - RestClient

/// Main class used to issue REST requests to the standard Force.com REST API.
@objc(SFRestAPI)
open class RestClient: NSObject {

    // MARK: - Private Static Properties

    private static let defaultContentType = "application/json"
    private static var isTestRun = false
    private static var sfRestApiList = SafeMutableDictionary<NSString, RestClient>()
    private static let httpDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss 'GMT'"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(abbreviation: "GMT")
        return formatter
    }()

    // MARK: - Public Properties

    /// The REST API version used for all calls.
    @objc public var apiVersion: String = SFRestDefaultAPIVersion

    /// The user associated with this instance of RestClient.
    @objc(userAccount)
    public private(set) var user: UserAccount?

    /// Active requests.
    @objc public private(set) var activeRequests: SafeMutableSet = SafeMutableSet()

    /// Whether this client requires authentication.
    @objc public var requiresAuthentication: Bool = false

    /// Instrumentation delegate for internal use.
    @objc public var instrumentationDelegateInternal: RestRequestDelegate?

    // MARK: - Private Properties

    private var sessionRefreshInProgress = false
    private var pendingRequestsBeingProcessed = false
    private var oauthSessionRefresher: SFOAuthSessionRefresher?

    // MARK: - Singleton Accessors

    /// Returns the singleton instance of `RestClient` associated with the current user.
    @objc(shared)
    public static var sharedInstance: RestClient {
        return restClient(for: UserAccountManager.shared.currentUserAccount) ?? {
            // Fallback: return global instance if no current user
            return sharedGlobalInstance
        }()
    }

    /// Returns the singleton instance of `RestClient` used for unauthenticated calls.
    @objc(sharedGlobal)
    public static var sharedGlobalInstance: RestClient {
        let key = SFKeyForGlobalScope()
        if let existing = sfRestApiList.object(forKey: key as NSString) as? RestClient {
            return existing
        }
        let instance = RestClient(user: nil)
        sfRestApiList.setObject(instance, forKey: key as NSString)
        return instance
    }

    /// Returns the singleton instance of `RestClient` associated with the specified user.
    @objc(restClientFor:)
    public static func restClient(for userAccount: UserAccount?) -> RestClient? {
        guard let user = userAccount ?? UserAccountManager.shared.currentUserAccount else {
            return nil
        }
        guard let key = SFKeyForUserAndScope(user, .community) else {
            return nil
        }
        if let existing = sfRestApiList.object(forKey: key as NSString) as? RestClient {
            return existing
        }
        guard user.loginState == .loggedIn else {
            SFSDKCoreLogger.w(RestClient.self, message: "\(#function) A user account must be in the loggedIn state in order to create a RestClient instance for a user.")
            return nil
        }
        let instance = RestClient(user: user)
        sfRestApiList.setObject(instance, forKey: key as NSString)
        return instance
    }

    /// Removes the shared instance for a user.
    @objc public static func removeSharedInstance(for user: UserAccount?) {
        guard let resolvedUser = user ?? UserAccountManager.shared.currentUserAccount else {
            return
        }
        guard let userKey = SFKeyForUserAndScope(resolvedUser, .user) else {
            return
        }
        let keys = sfRestApiList.allKeys as? [String] ?? []
        for key in keys {
            if key.hasPrefix(userKey) {
                sfRestApiList.removeObject(key as NSString)
            }
        }
    }

    // MARK: - Test Support

    @objc public static func setIsTestRun(_ isTestRun: Bool) {
        self.isTestRun = isTestRun
    }

    @objc public static func getIsTestRun() -> Bool {
        return isTestRun
    }

    // MARK: - Init

    @objc public init(user: UserAccount?) {
        self.user = user
        super.init()
        self.requiresAuthentication = (user != nil && user?.credentials.accessToken != nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleUserDidLogout(_:)), name: UserAccountManager.didLogoutUser, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Cleanup / Cancel

    /// Perform cleanup due to a host change or logout.
    @objc public func cleanup() {
        activeRequests.removeAllObjects()
    }

    /// Cancel all requests that are waiting to be executed.
    @objc public func cancelAllRequests() {
        activeRequests.enumerateObjects { obj, stop in
            if let request = obj as? RestRequest {
                request.cancel()
            }
        }
        activeRequests.removeAllObjects()
    }

    // MARK: - Internal

    @objc public func removeActiveRequestObject(_ request: RestRequest) {
        activeRequests.remove(request)
    }

    @objc public func forceTimeoutRequest(_ req: RestRequest?) -> Bool {
        let toCancel: RestRequest? = req ?? (activeRequests.anyObject() as? RestRequest)
        guard let request = toCancel else { return false }
        request.cancel()
        return true
    }

    // MARK: - User Agent

    /// Provides the User-Agent string used by Mobile SDK.
    @objc public static func userAgentString() -> String {
        return userAgentString("")
    }

    /// Returns the User-Agent string used by Mobile SDK, adding the qualifier after the app type.
    @objc public static func userAgentString(_ qualifier: String) -> String {
        return SalesforceSDKManager.shared.userAgentString?(qualifier) ?? ""
    }

    // MARK: - Send Methods

    /// Sends a REST request with a delegate.
    @objc public func send(_ request: RestRequest, requestDelegate: RestRequestDelegate?) {
        send(request, requestDelegate: requestDelegate, shouldRetry: requiresAuthentication && request.requiresAuthentication)
    }

    private func send(_ request: RestRequest, requestDelegate: RestRequestDelegate?, shouldRetry: Bool) {
        if let delegate = requestDelegate {
            request.requestDelegate = delegate
        }

        send(request, failureBlock: { [weak self] response, error, rawResponse in
            self?.notifyDelegateOfFailure(requestDelegate, request: request, data: response, rawResponse: rawResponse, error: error)
        }, successBlock: { [weak self] response, rawResponse in
            self?.notifyDelegateOfSuccess(requestDelegate, request: request, data: response, rawResponse: rawResponse)
        }, shouldRetry: shouldRetry)
    }

    /// Sends a REST request with blocks.
    @objc public func send(_ request: RestRequest, failureBlock: @escaping RestRequestFailBlock, successBlock: @escaping RestResponseBlock) {
        send(request, failureBlock: { [weak self] response, error, rawResponse in
            failureBlock(response, error, rawResponse)
            self?.removeActiveRequestObject(request)
        }, successBlock: { [weak self] response, rawResponse in
            successBlock(response, rawResponse)
            self?.removeActiveRequestObject(request)
        }, shouldRetry: requiresAuthentication && request.requiresAuthentication)
    }

    private func send(_ request: RestRequest, failureBlock: @escaping RestRequestFailBlock, successBlock: @escaping RestResponseBlock, shouldRetry: Bool) {
        request.failureBlock = failureBlock
        request.successBlock = successBlock

        if !requiresAuthentication {
            assert(!request.requiresAuthentication, "Use RestClient sharedInstance for authenticated requests")
        }

        activeRequests.add(request)

        if user?.credentials.accessToken == nil && user?.credentials.refreshToken == nil && requiresAuthentication {
            SFSDKCoreLogger.i(RestClient.self, message: "No auth credentials found. Authenticating before sending request: \(request.description)")
            UserAccountManager.shared.loginWithCompletion({ [weak self] authInfo, userAccount in
                guard let self = self else { return }
                self.user = userAccount
                self.enqueueRequest(request, shouldRetry: shouldRetry)
            }, failure: { [weak self] authInfo, error in
                guard let self = self else { return }
                SFSDKCoreLogger.e(type(of: self), message: "Authentication failed in RestClient: \(String(describing: error)). Logging out.")
                UserAccountManager.shared.logout(.unexpected)
            })
        } else {
            enqueueRequest(request, shouldRetry: shouldRetry)
        }
    }

    // MARK: - Enqueue

    private func enqueueRequest(_ request: RestRequest, shouldRetry: Bool) {
        guard let finalRequest = request.prepareRequestForSend(user ?? UserAccount()) else { return }

        var network: Network
        var instanceIdentifier: String?

        if request.serviceHostType == .custom {
            instanceIdentifier = Network.uniqueInstanceIdentifier()
            network = networkForRequest(request, identifier: instanceIdentifier ?? "")
        } else {
            network = networkForRequest(request)
        }

        var dataTask: URLSessionDataTask?
        dataTask = network.sendRequest(finalRequest) { [weak self] data, response, error in
            guard let self = self else { return }

            if let identifier = instanceIdentifier {
                Network.removeSharedInstance(forIdentifier: identifier)
            }

            // Guard: ignore callbacks from stale dataTasks superseded by retry.
            guard dataTask === request.sessionDataTask else {
                SFSDKCoreLogger.d(type(of: self), message: "Ignoring callback from stale task for request: \(request.path)")
                return
            }

            // Network error.
            if let error = error {
                SFSDKCoreLogger.d(type(of: self), message: "REST request failed with error: Error Code: \(error._code), Description: \(error.localizedDescription), URL: \(String(describing: finalRequest.url))")
                let dataForDelegate = self.prepareDataForDelegate(data, request: request, response: response)
                request.failureBlock?(dataForDelegate, error, response)
                return
            }

            // Timeout.
            guard let response = response else {
                request.failureBlock?(nil, nil, nil)
                return
            }

            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

            // 2xx indicates success.
            if RestClient.isStatusCodeSuccess(UInt(statusCode)) {
                let dataForDelegate = self.prepareDataForDelegate(data, request: request, response: response)
                request.successBlock?(dataForDelegate, response)
            } else {
                if shouldRetry && self.shouldRetryTask(request.sessionDataTask, withData: data) {
                    self.replayRequest(request, response: response)
                } else {
                    let errorForDelegate = self.prepareErrorForDelegate(data, response: response)
                    let dataForDelegate = self.prepareDataForDelegate(data, request: request, response: response)
                    request.failureBlock?(dataForDelegate, errorForDelegate, response)
                }
            }
        }
        request.sessionDataTask = dataTask
    }

    private func shouldRetryTask(_ task: URLSessionTask?, withData data: Data?) -> Bool {
        guard let task = task else { return false }
        return task.shouldRetry(with: data, biometricAuthManager: BiometricAuthenticationManagerInternal.shared)
    }

    // MARK: - Network Helpers

    private func networkForRequest(_ request: RestRequest) -> Network {
        if request.networkServiceType == .background {
            return Network.sharedBackgroundInstance()
        } else {
            return Network.sharedEphemeralInstance()
        }
    }

    private func networkForRequest(_ request: RestRequest, identifier: String) -> Network {
        if request.networkServiceType == .background {
            return Network.sharedBackgroundInstance(withIdentifier: identifier)
        } else {
            return Network.sharedEphemeralInstance(withIdentifier: identifier)
        }
    }

    // MARK: - Response Processing

    private func prepareDataForDelegate(_ data: Data?, request: RestRequest, response: URLResponse?) -> Any? {
        guard request.parseResponse else {
            return data
        }

        guard let data = data else { return nil }
        if let jsonObj = SFJsonUtils.object(fromJSONData: data) {
            return jsonObj
        }
        return data.isEmpty ? nil : data
    }

    private func prepareErrorForDelegate(_ data: Data?, response: URLResponse?) -> NSError {
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        var errorDict: [String: Any]?

        if let data = data {
            if let errorObj = SFJsonUtils.object(fromJSONData: data) {
                if let dict = errorObj as? [String: Any] {
                    errorDict = dict
                } else {
                    errorDict = ["error": errorObj]
                }
            } else {
                let errorString = String(data: data, encoding: .utf8) ?? ""
                errorDict = ["error": errorString]
            }
        }
        return NSError(domain: SFRestErrorDomain, code: statusCode, userInfo: errorDict)
    }

    // MARK: - Session Refresh

    private func sessionRefresher(for user: UserAccount) -> SFOAuthSessionRefresher {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        if oauthSessionRefresher == nil {
            oauthSessionRefresher = SFOAuthSessionRefresher(credentials: user.credentials)
        }
        return oauthSessionRefresher!
    }

    private func replayRequest(_ request: RestRequest, response: URLResponse?) {
        SFSDKCoreLogger.i(RestClient.self, message: "\(#function): REST request failed due to expired credentials. Attempting to refresh credentials.")

        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        guard !sessionRefreshInProgress else { return }
        sessionRefreshInProgress = true

        let refresher = sessionRefresher(for: user ?? UserAccount())
        refresher.refreshSession(withCompletion: { [weak self] updatedCredentials in
            guard let self = self else { return }
            SFSDKCoreLogger.i(RestClient.self, message: "\(#function): Credentials refresh successful. Replaying original REST request.")
            objc_sync_enter(self)
            self.sessionRefreshInProgress = false
            self.oauthSessionRefresher = nil
            if !self.pendingRequestsBeingProcessed {
                self.pendingRequestsBeingProcessed = true
                self.resendActiveRequestsRequiringAuthentication()
            }
            objc_sync_exit(self)
        }, error: { [weak self] refreshError in
            guard let self = self else { return }
            SFSDKCoreLogger.e(RestClient.self, message: "Failed to refresh expired session. Error: \(String(describing: refreshError))")
            objc_sync_enter(self)
            self.pendingRequestsBeingProcessed = true
            self.flushPendingRequestQueue(refreshError, rawResponse: response)
            self.sessionRefreshInProgress = false
            self.oauthSessionRefresher = nil
            objc_sync_exit(self)

            if let error = refreshError as NSError?,
               error.domain == kSFOAuthErrorDomain,
               error.code == kSFOAuthErrorInvalidGrant {
                SFSDKCoreLogger.i(RestClient.self, message: "\(#function) Invalid grant error received, triggering logout.")
                DispatchQueue.main.async {
                    if let user = self.user {
                        UserAccountManager.shared.logout(user, reason: .tokenExpired)
                    }
                }
            }
        })
    }

    // @objc so the ObjC runtime exposes it (the ObjC original was a runtime-visible method); the
    // data-task race tests invoke it via perform(NSSelectorFromString("flushPendingRequestQueue:rawResponse:")).
    @objc private func flushPendingRequestQueue(_ error: Error?, rawResponse: URLResponse?) {
        let pendingRequests = activeRequests.asSet() as? Set<AnyHashable> ?? []
        for case let request as RestRequest in pendingRequests {
            let oldTask = request.sessionDataTask
            request.sessionDataTask = nil
            oldTask?.cancel()
            request.failureBlock?(nil as Any?, error, rawResponse)
        }
        pendingRequestsBeingProcessed = false
    }

    // @objc so the ObjC runtime exposes it; invoked by the data-task race tests via
    // perform(NSSelectorFromString("resendActiveRequestsRequiringAuthentication")).
    @objc private func resendActiveRequestsRequiringAuthentication() {
        let pendingRequests = activeRequests.asSet() as? Set<AnyHashable> ?? []
        for case let request as RestRequest in pendingRequests {
            let oldTask = request.sessionDataTask
            send(request, failureBlock: request.failureBlock ?? { _, _, _ in }, successBlock: request.successBlock ?? { _, _ in }, shouldRetry: false)
            oldTask?.cancel()
        }
        pendingRequestsBeingProcessed = false
    }

    // MARK: - Delegate Notification

    private func notifyDelegateOfSuccess(_ delegate: RestRequestDelegate?, request: RestRequest, data: Any?, rawResponse: URLResponse?) {
        delegate?.request?(request, didSucceed: data as Any, rawResponse: rawResponse ?? URLResponse())
        removeActiveRequestObject(request)
    }

    private func notifyDelegateOfFailure(_ delegate: RestRequestDelegate?, request: RestRequest, data: Any?, rawResponse: URLResponse?, error: Error?) {
        delegate?.request?(request, didFail: data as Any, rawResponse: rawResponse ?? URLResponse(), error: error ?? NSError(domain: SFRestErrorDomain, code: SFRestErrorCode, userInfo: nil))
        removeActiveRequestObject(request)
    }

    // MARK: - Factory Methods

    /// Returns a request for user info.
    @objc public func requestForUserInfo() -> RestRequest {
        let path = "/services/oauth2/userinfo"
        let request = RestRequest(method: .GET, serviceHostType: .login, baseURL: nil, path: path, queryParams: nil)
        request.endpoint = ""
        return request
    }

    /// Returns a request for single access (front door URL).
    @objc public func requestForSingleAccess(_ redirectUri: String) -> RestRequest {
        let path = "/services/oauth2/singleaccess"
        let bodyStr = "redirect_uri=" + (redirectUri.sfsdk_stringByURLEncoding() ?? "")
        let request = RestRequest(method: .POST, serviceHostType: .instance, baseURL: nil, path: path, queryParams: nil)
        request.setCustomRequestBodyString(bodyStr, contentType: "application/x-www-form-urlencoded")
        request.endpoint = ""
        return request
    }

    /// Returns a request for versions.
    @objc public func requestForVersions() -> RestRequest {
        let request = RestRequest(method: .GET, path: "/", queryParams: nil)
        request.requiresAuthentication = false
        return request
    }

    /// Returns a request for limits.
    @objc public func requestForLimits(_ apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/limits"
        return RestRequest(method: .GET, path: path, queryParams: nil)
    }

    /// Returns a cheap request to re-hydrate the access token.
    @objc public func cheapRequest(_ apiVersion: String?) -> RestRequest {
        return requestForResources(apiVersion)
    }

    /// Returns a request for available resources.
    @objc public func requestForResources(_ apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))"
        return RestRequest(method: .GET, path: path, queryParams: nil)
    }

    /// Returns a request for describe global.
    @objc public func requestForDescribeGlobal(_ apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/sobjects"
        return RestRequest(method: .GET, path: path, queryParams: nil)
    }

    /// Returns a request for metadata with object type.
    @objc public func requestForMetadata(withObjectType objectType: String, apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/sobjects/\(objectType)"
        return RestRequest(method: .GET, path: path, queryParams: nil)
    }

    /// Returns a request for describe with object type.
    @objc public func requestForDescribe(withObjectType objectType: String, apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/sobjects/\(objectType)/describe"
        return RestRequest(method: .GET, path: path, queryParams: nil)
    }

    /// Returns a request for layout.
    @objc public func requestForLayout(withObjectAPIName objectAPIName: String, formFactor: String?, layoutType: String?, mode: String?, recordTypeId: String?, apiVersion: String?) -> RestRequest {
        var queryParams: [String: String] = [:]
        if let formFactor = formFactor { queryParams["formFactor"] = formFactor }
        if let layoutType = layoutType { queryParams["layoutType"] = layoutType }
        if let mode = mode { queryParams["mode"] = mode }
        if let recordTypeId = recordTypeId { queryParams["recordTypeId"] = recordTypeId }
        let path = "/\(computeAPIVersion(apiVersion))/ui-api/layout/\(objectAPIName)"
        return RestRequest(method: .GET, path: path, queryParams: queryParams.isEmpty ? nil : queryParams)
    }

    /// Returns a request for retrieve.
    @objc public func requestForRetrieve(withObjectType objectType: String, objectId: String, fieldList: String?, apiVersion: String?) -> RestRequest {
        let queryParams: [String: Any]? = fieldList != nil ? ["fields": fieldList as Any] : nil
        let path = "/\(computeAPIVersion(apiVersion))/sobjects/\(objectType)/\(objectId)"
        return RestRequest(method: .GET, path: path, queryParams: queryParams)
    }

    /// Returns a request for create.
    @objc public func requestForCreate(withObjectType objectType: String, fields: [String: Any]?, apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/sobjects/\(objectType)"
        let request = RestRequest(method: .POST, path: path, queryParams: nil)
        return addBodyForPostRequest(fields, request: request)
    }

    /// Returns a request for update.
    @objc public func requestForUpdate(withObjectType objectType: String, objectId: String, fields: [String: Any]?, apiVersion: String?) -> RestRequest {
        return requestForUpdate(withObjectType: objectType, objectId: objectId, fields: fields, ifUnmodifiedSinceDate: nil, apiVersion: apiVersion)
    }

    /// Returns a request for update with conditional modification date.
    @objc public func requestForUpdate(withObjectType objectType: String, objectId: String, fields: [String: Any]?, ifUnmodifiedSinceDate: Date?, apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/sobjects/\(objectType)/\(objectId)"
        var request = RestRequest(method: .PATCH, path: path, queryParams: nil)
        request = addBodyForPostRequest(fields, request: request)
        if let date = ifUnmodifiedSinceDate {
            request.setHeaderValue(RestClient.httpStringFrom(date: date), forHeaderName: SFRestIfUnmodifiedSince)
        }
        return request
    }

    /// Returns a request for upsert.
    @objc public func requestForUpsert(withObjectType objectType: String, externalIdField: String, externalId: String?, fields: [String: Any], apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/sobjects/\(objectType)/\(externalIdField)/\(externalId ?? "")"
        let method: RestRequest.Method = externalId == nil ? .POST : .PATCH
        let request = RestRequest(method: method, path: path, queryParams: nil)
        return addBodyForPostRequest(fields, request: request)
    }

    /// Returns a request for delete.
    @objc public func requestForDelete(withObjectType objectType: String, objectId: String, apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/sobjects/\(objectType)/\(objectId)"
        return RestRequest(method: .DELETE, path: path, queryParams: nil)
    }

    /// Returns a request for SOQL query.
    @objc public func requestForQuery(_ soql: String, apiVersion: String?) -> RestRequest {
        let queryParams: [String: Any]? = ["q": soql]
        let path = "/\(computeAPIVersion(apiVersion))/query"
        return RestRequest(method: .GET, path: path, queryParams: queryParams)
    }

    /// Returns a request for SOQL query with batch size.
    @objc public func requestForQuery(_ soql: String, apiVersion: String?, batchSize: Int) -> RestRequest {
        let request = requestForQuery(soql, apiVersion: apiVersion)
        let validatedBatchSize = max(min(batchSize, SFRestSOQLMaxBatchSize), SFRestSOQLMinBatchSize)
        if batchSize != SFRestSOQLDefaultBatchSize {
            request.setHeaderValue("batchSize=\(validatedBatchSize)", forHeaderName: SFRestQueryOptions)
        }
        return request
    }

    /// Returns a request for query all (includes deleted objects).
    @objc public func requestForQueryAll(_ soql: String, apiVersion: String?) -> RestRequest {
        let queryParams: [String: Any]? = ["q": soql]
        let path = "/\(computeAPIVersion(apiVersion))/queryAll"
        return RestRequest(method: .GET, path: path, queryParams: queryParams)
    }

    /// Returns a request for SOSL search.
    @objc public func requestForSearch(_ sosl: String, apiVersion: String?) -> RestRequest {
        let queryParams: [String: Any]? = ["q": sosl]
        let path = "/\(computeAPIVersion(apiVersion))/search"
        return RestRequest(method: .GET, path: path, queryParams: queryParams)
    }

    /// Returns a request for search scope and order.
    @objc public func requestForSearchScopeAndOrder(_ apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/search/scopeOrder"
        return RestRequest(method: .GET, path: path, queryParams: nil)
    }

    /// Returns a request for search result layout.
    @objc public func requestForSearchResultLayout(_ objectList: String, apiVersion: String?) -> RestRequest {
        let queryParams: [String: Any] = ["q": objectList]
        let path = "/\(computeAPIVersion(apiVersion))/search/layout"
        return RestRequest(method: .GET, path: path, queryParams: queryParams)
    }

    /// Returns a batch request.
    @objc public func batchRequest(_ requests: [RestRequest], haltOnError: Bool, apiVersion: String?) -> RestRequest {
        let builder = BatchRequestBuilder()
        for request in requests {
            _ = builder.addRequest(request)
        }
        _ = builder.setHaltOnError(haltOnError)
        return builder.buildBatchRequest(computeAPIVersion(apiVersion))
    }

    /// Returns a composite request.
    @objc public func compositeRequest(_ requests: [RestRequest], refIds: [String], allOrNone: Bool, apiVersion: String?) -> RestRequest {
        let builder = CompositeRequestBuilder()
        for i in 0..<requests.count {
            _ = builder.addRequest(requests[i], referenceId: refIds[i])
        }
        _ = builder.setAllOrNone(allOrNone)
        return builder.buildCompositeRequest(computeAPIVersion(apiVersion))
    }

    /// Returns a request for sObject tree.
    @objc public func requestForSObjectTree(_ objectType: String, objectTrees: [SObjectTree], apiVersion: String?) -> RestRequest {
        var jsonTrees: [[String: Any]] = []
        for objectTree in objectTrees {
            jsonTrees.append(objectTree.asJSON())
        }
        let requestJson: [String: Any] = ["records": jsonTrees]
        let path = "/\(computeAPIVersion(apiVersion))/composite/tree/\(objectType)"
        let request = RestRequest(method: .POST, path: path, queryParams: nil)
        return addBodyForPostRequest(requestJson, request: request)
    }

    /// Returns a request for priming records.
    @objc public func requestForPrimingRecords(_ relayToken: String?, changedAfterTimestamp timestamp: NSNumber?, apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/connect/briefcase/priming-records"
        var queryParams: [String: Any]?
        if let relayToken = relayToken {
            queryParams = ["relayToken": relayToken]
        }
        if let timestamp = timestamp {
            if let isoTimestamp = FormatUtils.getIsoString(fromMillis: timestamp.int64Value) {
                queryParams = ["changedAfterTimestamp": isoTimestamp]
            }
        }
        return RestRequest(method: .GET, path: path, queryParams: queryParams)
    }

    /// Returns a request for collection create.
    @objc public func requestForCollectionCreate(_ allOrNone: Bool, records: [[String: Any]], apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/composite/sobjects"
        let requestJson: [String: Any] = ["allOrNone": NSNumber(value: allOrNone), "records": records]
        let request = RestRequest(method: .POST, path: path, queryParams: nil)
        return addBodyForPostRequest(requestJson, request: request)
    }

    /// Returns a request for collection retrieve.
    @objc public func requestForCollectionRetrieve(_ objectType: String, objectIds: [String], fieldList: [String], apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/composite/sobjects/\(objectType)"
        let requestJson: [String: Any] = ["ids": objectIds, "fields": fieldList]
        let request = RestRequest(method: .POST, path: path, queryParams: nil)
        return addBodyForPostRequest(requestJson, request: request)
    }

    /// Returns a request for collection update.
    @objc public func requestForCollectionUpdate(_ allOrNone: Bool, records: [[String: Any]], apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/composite/sobjects"
        let requestJson: [String: Any] = ["allOrNone": NSNumber(value: allOrNone), "records": records]
        let request = RestRequest(method: .PATCH, path: path, queryParams: nil)
        return addBodyForPostRequest(requestJson, request: request)
    }

    /// Returns a request for collection upsert.
    @objc public func requestForCollectionUpsert(_ allOrNone: Bool, objectType: String, externalIdField: String, records: [[String: Any]], apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/composite/sobjects/\(objectType)/\(externalIdField)"
        let requestJson: [String: Any] = ["allOrNone": NSNumber(value: allOrNone), "records": records]
        let request = RestRequest(method: .PATCH, path: path, queryParams: nil)
        return addBodyForPostRequest(requestJson, request: request)
    }

    /// Returns a request for collection delete.
    @objc public func requestForCollectionDelete(_ allOrNone: Bool, objectIds: [String], apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/composite/sobjects"
        let queryParams: [String: Any] = [
            "allOrNone": allOrNone ? "true" : "false",
            "ids": objectIds.joined(separator: ",")
        ]
        return RestRequest(method: .DELETE, path: path, queryParams: queryParams)
    }

    // MARK: - Utility Methods

    @objc public static func isStatusCodeSuccess(_ statusCode: UInt) -> Bool {
        return statusCode >= 200 && statusCode < 300
    }

    @objc public static func isStatusCodeNotFound(_ statusCode: UInt) -> Bool {
        return statusCode == 404
    }

    @objc public static func httpStringFrom(date: Date) -> String? {
        return httpDateFormatter.string(from: date)
    }

    // MARK: - Private Helpers

    @objc public func computeAPIVersion(_ apiVersion: String?) -> String {
        return apiVersion ?? self.apiVersion
    }

    private func addBodyForPostRequest(_ params: [String: Any]?, request: RestRequest) -> RestRequest {
        if let params = params {
            request.setCustomRequestBodyDictionary(params, contentType: RestClient.defaultContentType)
        }
        return request
    }

    // MARK: - Logout Handling

    @objc private func handleUserDidLogout(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let user = userInfo[UserAccountManager.userInfoAccountKey] as? UserAccount else {
            return
        }
        handleLogout(for: user)
    }

    private func handleLogout(for user: UserAccount) {
        guard let key = SFKeyForUserAndScope(user, .community) else { return }
        if let restApi = RestClient.sfRestApiList.object(forKey: key as NSString) as? RestClient {
            restApi.cleanup()
        }
        RestClient.removeSharedInstance(for: user)
    }
}
