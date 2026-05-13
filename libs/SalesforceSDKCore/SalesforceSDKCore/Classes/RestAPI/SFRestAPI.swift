/*
 Copyright (c) 2011-present, salesforce.com, inc. All rights reserved.

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

public typealias RestRequestFailBlock = (_ response: Any?, _ error: Error?, _ rawResponse: URLResponse?) -> Void
public typealias RestResponseBlock = (_ response: Any?, _ rawResponse: URLResponse?) -> Void

// Domain used for errors reported by the rest API (non HTTP errors)
public let SFRestErrorDomain = "com.salesforce.RestAPI.ErrorDomain"

// Error code used for all rest API errors (non HTTP errors)
public let SFRestErrorCode = 999

// Default API version (currently "v66.0")
public let SFRestDefaultAPIVersion = "v66.0"

// Misc keys appearing in requests
public let SFRestIfUnmodifiedSince = "If-Unmodified-Since"

// SOQL batch related constants
public let SFRestSOQLMinBatchSize = 200
public let SFRestSOQLMaxBatchSize = 2000
public let SFRestSOQLDefaultBatchSize = 2000
public let SFRestQueryOptions = "Sforce-Query-Options"

// Other constants
public let SFRestCollectionRetrieveMaxSize = 2000

let kSFDefaultContentType = "application/json"
let kHttpPostContentType = "application/x-www-form-urlencoded"

private var kIsTestRun = false
private var sfRestApiList = SFSDKSafeMutableDictionary<NSString, RestClient>()
private let pred = DispatchQueue(label: "com.salesforce.restapi.singleton")
private var httpDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss 'GMT'"
    return formatter
}()

/**
 * Main class used to issue REST requests to the standard Force.com REST API.
 * See the [Force.com REST API Developer's Guide](http://www.salesforce.com/us/developer/docs/api_rest/index.htm)
 * for more information regarding the Force.com REST API.
 */
@objc(SFRestAPI)
@objcMembers
public class RestClient: NSObject {

    // MARK: - Properties

    /// The REST API version used for all the calls.
    /// The default value is `kSFRestDefaultAPIVersion` (currently "v66.0")
    public var apiVersion: String

    /// The user associated with this instance of SFRestAPI.
    public private(set) var userAccount: UserAccount

    var sessionRefreshInProgress = false
    var pendingRequestsBeingProcessed = false
    var oauthSessionRefresher: SFOAuthSessionRefresher?
    var activeRequests = SFSDKSafeMutableSet(capacity: 10)
    var requiresAuthentication = false

    // MARK: - Singleton Access

    /// Returns the singleton instance of `SFRestAPI` associated with the current user.
    @objc(sharedInstance)
    public static var shared: RestClient {
        return restClient(for: UserAccountManager.shared.currentUserAccount)!
    }

    /// Returns the singleton instance of `SFRestAPI` that's used to make unauthenticated calls.
    @objc(sharedGlobalInstance)
    public static var sharedGlobal: RestClient {
        return pred.sync {
            let key = SFKeyForGlobalScope() as NSString
            if let sfRestApi = sfRestApiList.object(forKey: key) as? RestClient {
                return sfRestApi
            }
            let sfRestApi = RestClient(user: nil)
            sfRestApiList.setObject(sfRestApi, forKey: key)
            return sfRestApi
        }
    }

    /// Returns the singleton instance of `SFRestAPI` associated with the specified user.
    @objc(sharedInstanceWithUser:)
    public static func restClient(for userAccount: UserAccount?) -> RestClient? {
        guard let user = userAccount ?? UserAccountManager.shared.currentUserAccount else {
            return nil
        }

        return pred.sync {
            let key = SFKeyForUserAndScope(user, .community) as NSString

            if let sfRestApi = sfRestApiList.object(forKey: key) as? RestClient {
                return sfRestApi
            }

            if user.loginState != .loggedIn {
                SFSDKCoreLogger.w(RestClient.self, message: "A user account must be in the UserAccountLoginStateLoggedIn state in order to create a SFRestAPI instance for a user.")
                return nil
            }

            let sfRestApi = RestClient(user: user)
            sfRestApiList.setObject(sfRestApi, forKey: key)
            return sfRestApi
        }
    }

    @objc
    public static func removeSharedInstance(with user: UserAccount?) {
        pred.sync {
            guard let user = user ?? UserAccountManager.shared.currentUserAccount else {
                return
            }

            let userKey = SFKeyForUserAndScope(user, .user)

            // Remove all sub-instances (community users) for this user as well.
            let keys = sfRestApiList.allKeys as? [String] ?? []
            for key in keys {
                if key.hasPrefix(userKey) {
                    sfRestApiList.removeObject(key as NSString)
                }
            }
        }
    }

    // MARK: - Initialization

    @objc
    public init(user: UserAccount?) {
        self.userAccount = user ?? UserAccount()
        self.apiVersion = SFRestDefaultAPIVersion
        super.init()

        self.requiresAuthentication = (user != nil && user?.credentials.accessToken != nil)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUserDidLogout(_:)),
            name: .UserAccountManagerDidLogoutUser,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Cleanup / Cancel All

    @objc
    public func cleanup() {
        activeRequests.removeAllObjects()
    }

    @objc
    public func cancelAllRequests() {
        activeRequests.enumerateObjects { obj, stop in
            if let request = obj as? RestRequest {
                request.cancel()
            }
        }
        activeRequests.removeAllObjects()
    }

    // MARK: - Send Methods

    @objc
    public func send(_ request: RestRequest, requestDelegate: RestRequestDelegate?) {
        send(request, requestDelegate: requestDelegate, shouldRetry: requiresAuthentication && request.requiresAuthentication)
    }

    private func send(_ request: RestRequest, requestDelegate: RestRequestDelegate?, shouldRetry: Bool) {
        if let delegate = requestDelegate {
            request.requestDelegate = delegate
        }

        send(request, failureBlock: { [weak self] response, error, rawResponse in
            self?.notifyDelegateOfFailure(delegate: requestDelegate, request: request, data: response, rawResponse: rawResponse, error: error)
        }, successBlock: { [weak self] response, rawResponse in
            self?.notifyDelegateOfSuccess(delegate: requestDelegate, request: request, data: response, rawResponse: rawResponse)
        }, shouldRetry: shouldRetry)
    }

    @objc
    public func send(_ request: RestRequest, failureBlock: @escaping RestRequestFailBlock, successBlock: @escaping RestResponseBlock) {
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
            assert(!request.requiresAuthentication, "Use SFRestAPI sharedInstance for authenticated requests")
        }

        activeRequests.add(request)

        if userAccount.credentials.accessToken == nil && userAccount.credentials.refreshToken == nil && requiresAuthentication {
            SFSDKCoreLogger.i(RestClient.self, message: "No auth credentials found. Authenticating before sending request: \(request.description)")

            UserAccountManager.shared.login { [weak self] authInfo, userAccount in
                guard let self = self else { return }
                self.userAccount = userAccount
                self.enqueueRequest(request, shouldRetry: shouldRetry)
            } failure: { authInfo, error in
                SFSDKCoreLogger.e(RestClient.self, message: "Authentication failed in SFRestAPI: \(error). Logging out.")
                UserAccountManager.shared.logout(.unexpected)
            }
        } else {
            enqueueRequest(request, shouldRetry: shouldRetry)
        }
    }

    // MARK: - Internal Methods

    @objc
    func removeActiveRequestObject(_ request: RestRequest?) {
        if let request = request {
            activeRequests.remove(request)
        }
    }

    @objc
    func forceTimeoutRequest(_ req: RestRequest?) -> Bool {
        var found = false
        let toCancel = req ?? (activeRequests.anyObject() as? RestRequest)
        if let toCancel = toCancel {
            found = true
            toCancel.cancel()
        }
        return found
    }

    private func sessionRefresher(for user: UserAccount) -> SFOAuthSessionRefresher {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        if oauthSessionRefresher == nil {
            oauthSessionRefresher = SFOAuthSessionRefresher(credentials: user.credentials)
        }
        return oauthSessionRefresher!
    }

    private func enqueueRequest(_ request: RestRequest, shouldRetry: Bool) {
        guard let finalRequest = request.prepareRequestForSend(userAccount) else {
            return
        }

        let network: Network
        var instanceIdentifier: String?

        if request.serviceHostType == .custom {
            instanceIdentifier = Network.uniqueInstanceIdentifier()
            network = self.network(for: request, identifier: instanceIdentifier!)
        } else {
            network = self.network(for: request)
        }

        let dataTask = network.sendRequest(finalRequest) { [weak self] data, response, error in
            guard let self = self else { return }

            if let identifier = instanceIdentifier {
                Network.removeSharedInstance(forIdentifier: identifier)
            }

            // Network error
            if let error = error {
                SFSDKCoreLogger.d(RestClient.self, message: "REST request failed with error: Error Code: \(error._code), Description: \(error.localizedDescription), URL: \(finalRequest.url?.absoluteString ?? "")")
                let dataForDelegate = self.prepareData(forDelegate: data, request: request, response: response)
                request.failureBlock?(dataForDelegate, error, response)
                return
            }

            // Timeout
            guard let response = response else {
                request.failureBlock?(nil, nil, nil)
                return
            }

            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

            // 2xx indicates success
            if RestClient.isStatusCodeSuccess(statusCode) {
                let dataForDelegate = self.prepareData(forDelegate: data, request: request, response: response)
                request.successBlock?(dataForDelegate, response)
            } else {
                if shouldRetry && self.shouldRetryTask(request.sessionDataTask, with: data) {
                    self.replayRequest(request, response: response)
                } else {
                    let errorForDelegate = self.prepareError(forDelegate: data, response: response)
                    let dataForDelegate = self.prepareData(forDelegate: data, request: request, response: response)
                    request.failureBlock?(dataForDelegate, errorForDelegate, response)
                }
            }
        }
        request.sessionDataTask = dataTask
    }

    private func shouldRetryTask(_ task: URLSessionTask?, with data: Data?) -> Bool {
        guard let task = task, let data = data else { return false }
        return task.shouldRetry(with: data, biometricAuthManager: SFBiometricAuthenticationManagerInternal.shared)
    }

    private func network(for request: RestRequest) -> Network {
        if request.networkServiceType == .background {
            return Network.sharedBackgroundInstance()
        } else {
            return Network.sharedEphemeralInstance()
        }
    }

    private func network(for request: RestRequest, identifier: String) -> Network {
        if request.networkServiceType == .background {
            return Network.sharedBackgroundInstance(withIdentifier: identifier)
        } else {
            return Network.sharedEphemeralInstance(withIdentifier: identifier)
        }
    }

    private func prepareData(forDelegate data: Data?, request: RestRequest, response: URLResponse?) -> Any? {
        // No parsing
        if !request.parseResponse {
            return data
        }

        // Parsing
        if let data = data, let jsonDict = SFJsonUtils.object(from: data) {
            return jsonDict
        }

        // Parsing failed
        return (data?.count ?? 0) == 0 ? nil : data
    }

    private func prepareError(forDelegate data: Data?, response: URLResponse?) -> NSError {
        var errorDict: [String: Any]?
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

        if let data = data, let errorObj = SFJsonUtils.object(from: data) {
            if let dict = errorObj as? [String: Any] {
                errorDict = dict
            } else {
                errorDict = ["error": errorObj]
            }
        } else if let data = data, let errorString = String(data: data, encoding: .utf8) {
            errorDict = ["error": errorString]
        }

        return NSError(domain: SFRestErrorDomain, code: statusCode, userInfo: errorDict)
    }

    private func replayRequest(_ request: RestRequest, response: URLResponse?) {
        SFSDKCoreLogger.i(RestClient.self, message: "REST request failed due to expired credentials. Attempting to refresh credentials.")

        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        if !sessionRefreshInProgress {
            sessionRefreshInProgress = true
            let sessionRefresher = self.sessionRefresher(for: userAccount)

            sessionRefresher.refreshSession(completion: { [weak self] updatedCredentials in
                guard let self = self else { return }

                SFSDKCoreLogger.i(RestClient.self, message: "Credentials refresh successful. Replaying original REST request.")

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

                SFSDKCoreLogger.e(RestClient.self, message: "Failed to refresh expired session. Error: \(refreshError)")

                objc_sync_enter(self)
                self.pendingRequestsBeingProcessed = true
                self.flushPendingRequestQueue(error: refreshError, rawResponse: response)
                self.sessionRefreshInProgress = false
                self.oauthSessionRefresher = nil
                objc_sync_exit(self)

                if let nsError = refreshError as? NSError,
                   nsError.domain == kSFOAuthErrorDomain && nsError.code == kSFOAuthErrorInvalidGrant {
                    SFSDKCoreLogger.i(RestClient.self, message: "Invalid grant error received, triggering logout.")

                    DispatchQueue.main.async {
                        UserAccountManager.shared.logout(self.userAccount, reason: .tokenExpired)
                    }
                }
            })
        }
    }

    private func flushPendingRequestQueue(error: Error, rawResponse: URLResponse?) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        let pendingRequests = activeRequests.asSet() as? Set<RestRequest> ?? []
        for request in pendingRequests {
            let oldTask = request.sessionDataTask
            request.sessionDataTask = nil
            oldTask?.cancel()
            request.failureBlock?(nil, error, rawResponse)
        }
        pendingRequestsBeingProcessed = false
    }

    private func resendActiveRequestsRequiringAuthentication() {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        let pendingRequests = activeRequests.asSet() as? Set<RestRequest> ?? []
        for request in pendingRequests {
            let oldTask = request.sessionDataTask
            send(request, failureBlock: request.failureBlock!, successBlock: request.successBlock!, shouldRetry: false)
            oldTask?.cancel()
        }
        pendingRequestsBeingProcessed = false
    }

    private func notifyDelegateOfSuccess(delegate: RestRequestDelegate?, request: RestRequest, data: Any?, rawResponse: URLResponse?) {
        if let rawResponse = rawResponse, let data = data {
            delegate?.request?(request, didSucceed: data, rawResponse: rawResponse)
        }
        removeActiveRequestObject(request)
    }

    private func notifyDelegateOfFailure(delegate: RestRequestDelegate?, request: RestRequest, data: Any?, rawResponse: URLResponse?, error: Error?) {
        if let rawResponse = rawResponse, let data = data, let error = error {
            delegate?.request?(request, didFail: data, rawResponse: rawResponse, error: error)
        }
        removeActiveRequestObject(request)
    }

    // MARK: - SFRestRequest Factory Methods

    @objc
    public func requestForUserInfo() -> RestRequest {
        let path = "/services/oauth2/userinfo"
        let request = RestRequest.request(withMethod: .GET, serviceHostType: .login, path: path, queryParams: nil)
        request.endpoint = ""
        return request
    }

    @objc
    public func requestForSingleAccess(_ redirectUri: String) -> RestRequest {
        let path = "/services/oauth2/singleaccess"
        let bodyStr = "redirect_uri=" + (redirectUri.sfsdk_stringByURLEncoding ?? "")
        let request = RestRequest.request(withMethod: .POST, serviceHostType: .instance, path: path, queryParams: nil)
        request.setCustomRequestBodyString(bodyStr, contentType: kHttpPostContentType)
        request.endpoint = ""
        return request
    }

    @objc
    public func requestForVersions() -> RestRequest {
        let path = "/"
        let request = RestRequest.request(withMethod: .GET, path: path, queryParams: nil)
        request.requiresAuthentication = false
        return request
    }

    @objc
    public func requestForLimits(_ apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/limits"
        return RestRequest.request(withMethod: .GET, path: path, queryParams: nil)
    }

    @objc
    public func cheapRequest(_ apiVersion: String?) -> RestRequest {
        return requestForResources(apiVersion)
    }

    @objc
    public func requestForResources(_ apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))"
        return RestRequest.request(withMethod: .GET, path: path, queryParams: nil)
    }

    @objc
    public func requestForDescribeGlobal(_ apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/sobjects"
        return RestRequest.request(withMethod: .GET, path: path, queryParams: nil)
    }

    @objc
    public func requestForMetadata(withObjectType objectType: String, apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/sobjects/\(objectType)"
        return RestRequest.request(withMethod: .GET, path: path, queryParams: nil)
    }

    @objc
    public func requestForDescribe(withObjectType objectType: String, apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/sobjects/\(objectType)/describe"
        return RestRequest.request(withMethod: .GET, path: path, queryParams: nil)
    }

    @objc
    public func requestForLayout(withObjectAPIName objectAPIName: String, formFactor: String?, layoutType: String?, mode: String?, recordTypeId: String?, apiVersion: String?) -> RestRequest {
        var queryParams: [String: String] = [:]
        if let formFactor = formFactor {
            queryParams["formFactor"] = formFactor
        }
        if let layoutType = layoutType {
            queryParams["layoutType"] = layoutType
        }
        if let mode = mode {
            queryParams["mode"] = mode
        }
        if let recordTypeId = recordTypeId {
            queryParams["recordTypeId"] = recordTypeId
        }
        let path = "/\(computeAPIVersion(apiVersion))/ui-api/layout/\(objectAPIName)"
        return RestRequest.request(withMethod: .GET, path: path, queryParams: queryParams)
    }

    @objc
    public func requestForRetrieve(withObjectType objectType: String, objectId: String, fieldList: String?, apiVersion: String?) -> RestRequest {
        let queryParams = fieldList != nil ? ["fields": fieldList!] : nil
        let path = "/\(computeAPIVersion(apiVersion))/sobjects/\(objectType)/\(objectId)"
        return RestRequest.request(withMethod: .GET, path: path, queryParams: queryParams)
    }

    @objc
    public func requestForCreate(withObjectType objectType: String, fields: [String: Any]?, apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/sobjects/\(objectType)"
        let request = RestRequest.request(withMethod: .POST, path: path, queryParams: nil)
        return addBodyForPostRequest(fields, request: request)
    }

    @objc
    public func requestForUpdate(withObjectType objectType: String, objectId: String, fields: [String: Any]?, apiVersion: String?) -> RestRequest {
        return requestForUpdate(withObjectType: objectType, objectId: objectId, fields: fields, ifUnmodifiedSinceDate: nil, apiVersion: computeAPIVersion(apiVersion))
    }

    @objc
    public func requestForUpdate(withObjectType objectType: String, objectId: String, fields: [String: Any]?, ifUnmodifiedSinceDate: Date?, apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/sobjects/\(objectType)/\(objectId)"
        let request = RestRequest.request(withMethod: .PATCH, path: path, queryParams: nil)
        let updatedRequest = addBodyForPostRequest(fields, request: request)

        if let ifUnmodifiedSinceDate = ifUnmodifiedSinceDate {
            updatedRequest.setHeaderValue(RestClient.getHttpStringFrom(date: ifUnmodifiedSinceDate), forHeaderName: SFRestIfUnmodifiedSince)
        }
        return updatedRequest
    }

    @objc
    public func requestForUpsert(withObjectType objectType: String, externalIdField: String, externalId: String?, fields: [String: Any], apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/sobjects/\(objectType)/\(externalIdField)/\(externalId ?? "")"
        let method: RestRequest.Method = externalId == nil ? .POST : .PATCH
        let request = RestRequest.request(withMethod: method, path: path, queryParams: nil)
        return addBodyForPostRequest(fields, request: request)
    }

    @objc
    public func requestForDelete(withObjectType objectType: String, objectId: String, apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/sobjects/\(objectType)/\(objectId)"
        return RestRequest.request(withMethod: .DELETE, path: path, queryParams: nil)
    }

    @objc
    public func requestForQuery(_ soql: String, apiVersion: String?) -> RestRequest {
        let queryParams = soql.isEmpty ? nil : ["q": soql]
        let path = "/\(computeAPIVersion(apiVersion))/query"
        return RestRequest.request(withMethod: .GET, path: path, queryParams: queryParams)
    }

    @objc
    public func requestForQuery(_ soql: String, apiVersion: String?, batchSize: Int) -> RestRequest {
        let request = self.requestForQuery(soql, apiVersion: apiVersion)
        let validatedBatchSize = max(min(batchSize, SFRestSOQLMaxBatchSize), SFRestSOQLMinBatchSize)
        if batchSize != SFRestSOQLDefaultBatchSize {
            request.setHeaderValue("batchSize=\(validatedBatchSize)", forHeaderName: SFRestQueryOptions)
        }
        return request
    }

    @objc
    public func requestForQueryAll(_ soql: String, apiVersion: String?) -> RestRequest {
        let queryParams = soql.isEmpty ? nil : ["q": soql]
        let path = "/\(computeAPIVersion(apiVersion))/queryAll"
        return RestRequest.request(withMethod: .GET, path: path, queryParams: queryParams)
    }

    @objc
    public func requestForSearch(_ sosl: String, apiVersion: String?) -> RestRequest {
        let queryParams = sosl.isEmpty ? nil : ["q": sosl]
        let path = "/\(computeAPIVersion(apiVersion))/search"
        return RestRequest.request(withMethod: .GET, path: path, queryParams: queryParams)
    }

    @objc
    public func requestForSearchScopeAndOrder(_ apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/search/scopeOrder"
        return RestRequest.request(withMethod: .GET, path: path, queryParams: nil)
    }

    @objc
    public func requestForSearchResultLayout(_ objectList: String, apiVersion: String?) -> RestRequest {
        let queryParams = ["q": objectList]
        let path = "/\(computeAPIVersion(apiVersion))/search/layout"
        return RestRequest.request(withMethod: .GET, path: path, queryParams: queryParams)
    }

    @objc
    public func batchRequest(_ requests: [RestRequest], haltOnError: Bool, apiVersion: String?) -> RestRequest {
        let builder = BatchRequestBuilder()
        for request in requests {
            builder.addRequest(request)
        }
        builder.setHaltOnError(haltOnError)
        return builder.buildBatchRequest(computeAPIVersion(apiVersion))
    }

    @objc
    public func compositeRequest(_ requests: [RestRequest], refIds: [String], allOrNone: Bool, apiVersion: String?) -> RestRequest {
        let builder = CompositeRequestBuilder()
        for (index, request) in requests.enumerated() {
            builder.addRequest(request, referenceId: refIds[index])
        }
        builder.setAllOrNone(allOrNone)
        return builder.buildCompositeRequest(computeAPIVersion(apiVersion))
    }

    @objc
    public func requestForSObjectTree(_ objectType: String, objectTrees: [SObjectTree], apiVersion: String?) -> RestRequest {
        let jsonTrees = objectTrees.map { $0.asJSON() }
        let requestJson: [String: Any] = ["records": jsonTrees]
        let path = "/\(computeAPIVersion(apiVersion))/composite/tree/\(objectType)"
        let request = RestRequest.request(withMethod: .POST, path: path, queryParams: nil)
        return addBodyForPostRequest(requestJson, request: request)
    }

    @objc
    public func requestForPrimingRecords(_ relayToken: String?, changedAfterTimestamp timestamp: NSNumber?, apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/connect/briefcase/priming-records"

        var queryParams: [String: String]?
        if let relayToken = relayToken {
            queryParams = ["relayToken": relayToken]
        }
        if let timestamp = timestamp {
            if let isoTimestamp = FormatUtils.getIsoStringFromMillis(timestamp.int64Value) {
                queryParams = ["changedAfterTimestamp": isoTimestamp]
            }
        }

        return RestRequest.request(withMethod: .GET, path: path, queryParams: queryParams)
    }

    @objc
    public func requestForCollectionCreate(_ allOrNone: Bool, records: [[String: Any]], apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/composite/sobjects"
        let requestJson: [String: Any] = ["allOrNone": allOrNone, "records": records]
        let request = RestRequest.request(withMethod: .POST, path: path, queryParams: nil)
        return addBodyForPostRequest(requestJson, request: request)
    }

    @objc
    public func requestForCollectionRetrieve(_ objectType: String, objectIds: [String], fieldList: [String], apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/composite/sobjects/\(objectType)"
        let requestJson: [String: Any] = ["ids": objectIds, "fields": fieldList]
        let request = RestRequest.request(withMethod: .POST, path: path, queryParams: nil)
        return addBodyForPostRequest(requestJson, request: request)
    }

    @objc
    public func requestForCollectionUpdate(_ allOrNone: Bool, records: [[String: Any]], apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/composite/sobjects"
        let requestJson: [String: Any] = ["allOrNone": allOrNone, "records": records]
        let request = RestRequest.request(withMethod: .PATCH, path: path, queryParams: nil)
        return addBodyForPostRequest(requestJson, request: request)
    }

    @objc
    public func requestForCollectionUpsert(_ allOrNone: Bool, objectType: String, externalIdField: String, records: [[String: Any]], apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/composite/sobjects/\(objectType)/\(externalIdField)"
        let requestJson: [String: Any] = ["allOrNone": allOrNone, "records": records]
        let request = RestRequest.request(withMethod: .PATCH, path: path, queryParams: nil)
        return addBodyForPostRequest(requestJson, request: request)
    }

    @objc
    public func requestForCollectionDelete(_ allOrNone: Bool, objectIds: [String], apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/composite/sobjects"
        let queryParams = [
            "allOrNone": allOrNone ? "true" : "false",
            "ids": objectIds.joined(separator: ",")
        ]
        return RestRequest.request(withMethod: .DELETE, path: path, queryParams: queryParams)
    }

    // MARK: - Helper Methods

    private func toQueryString(_ components: [String: String]?) -> String {
        var params = ""
        guard let components = components, !components.isEmpty else {
            return params
        }

        var parts: [String] = []
        params.append("?")

        for (paramName, paramValue) in components {
            let encodedName = paramName.sfsdk_stringByURLEncoding ?? paramName
            let encodedValue = paramValue.sfsdk_stringByURLEncoding ?? paramValue
            let part = "\(encodedName)=\(encodedValue)"
            parts.append(part)
        }
        params.append(parts.joined(separator: "&"))
        return params
    }

    private func addBodyForPostRequest(_ params: [String: Any]?, request: RestRequest) -> RestRequest {
        request.setCustomRequestBodyDictionary(params ?? [:], contentType: kSFDefaultContentType)
        return request
    }

    @objc
    public static func isStatusCodeSuccess(_ statusCode: Int) -> Bool {
        return statusCode >= 200 && statusCode < 300
    }

    @objc
    public static func isStatusCodeNotFound(_ statusCode: Int) -> Bool {
        return statusCode == 404
    }

    @objc
    public static func getHttpStringFrom(date: Date?) -> String? {
        guard let date = date else { return nil }
        return httpDateFormatter.string(from: date)
    }

    @objc
    public static func userAgentString() -> String {
        return userAgentString("")
    }

    @objc
    public static func userAgentString(_ qualifier: String) -> String {
        return SalesforceManager.shared.userAgentString(qualifier)
    }

    // MARK: - User Account Manager Delegate

    @objc
    private func handleUserDidLogout(_ notification: Notification) {
        if let user = notification.userInfo?[UserAccountManager.userInfoAccountKey] as? UserAccount {
            handleLogout(for: user)
        }
    }

    @objc
    func handleLogout(for user: UserAccount) {
        let key = SFKeyForUserAndScope(user, .community) as NSString
        if let sfRestApi = sfRestApiList.object(forKey: key) as? RestClient {
            sfRestApi.cleanup()
        }
        RestClient.removeSharedInstance(with: user)
    }

    @objc
    func computeAPIVersion(_ apiVersion: String?) -> String {
        return apiVersion ?? self.apiVersion
    }
}
