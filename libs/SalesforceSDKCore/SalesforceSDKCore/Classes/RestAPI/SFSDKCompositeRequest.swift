//
//  SFSDKCompositeRequest.swift
//  SalesforceSDKCore
//
//  Copyright (c) 2019-present, salesforce.com, inc. All rights reserved.
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

// MARK: - CompositeSubRequest

/// Represents a single subrequest within a composite request.
@objc(SFSDKCompositeSubRequest)
@objcMembers
public class CompositeSubRequest: RestRequest {

    /// The reference ID for this subrequest.
    @objc public var referenceId: String = ""

    /// Initializes with a reference ID.
    @objc public init(referenceId: String) {
        super.init()
        self.referenceId = referenceId
    }

    /// Initializes by copying properties from an existing request.
    @objc public init(request: RestRequest, referenceId: String) {
        super.init()
        self.referenceId = referenceId
        self.method = request.method
        self.path = request.path
        self.baseURL = request.baseURL
        self.endpoint = request.endpoint
        self.requiresAuthentication = request.requiresAuthentication
        self.customHeaders = request.customHeaders
        self.requestBodyStreamBlock = request.requestBodyStreamBlock
        self.parseResponse = request.parseResponse
        self.queryParams = request.queryParams
        self.requestContentType = request.requestContentType
        self.networkServiceType = request.networkServiceType
        self.serviceHostType = request.serviceHostType
        self.requestBodyAsDictionary = request.requestBodyAsDictionary
        self.requestDelegate = request.requestDelegate
    }

    required public init(method: RestRequest.Method, serviceHostType: RestRequest.ServiceHostType, baseURL: String?, path: String, queryParams: [String: Any]?) {
        super.init(method: method, serviceHostType: serviceHostType, baseURL: baseURL, path: path, queryParams: queryParams)
    }
}

// MARK: - CompositeRequest

/// Represents a composite REST request containing multiple subrequests.
@objc(SFSDKCompositeRequest)
@objcMembers
public class CompositeRequest: RestRequest {

    /// Whether all subrequests should succeed or none.
    public var allOrNone: Bool = false

    /// Internal API version storage.
    fileprivate var compositeApiVersion: String = SFRestDefaultAPIVersion

    /// The list of subrequests.
    private var requests: [CompositeSubRequest] = []

    /// Returns all subrequests.
    @objc public var allSubRequests: [CompositeSubRequest] {
        return requests
    }

    override public init() {
        super.init()
    }

    required public init(method: RestRequest.Method, serviceHostType: RestRequest.ServiceHostType, baseURL: String?, path: String, queryParams: [String: Any]?) {
        super.init(method: method, serviceHostType: serviceHostType, baseURL: baseURL, path: path, queryParams: queryParams)
    }

    /// Adds a subrequest.
    @objc public func addRequest(_ subRequest: CompositeSubRequest) {
        requests.append(subRequest)
    }

    override public func prepareRequestForSend(_ user: UserAccount) -> URLRequest? {
        var requestsArrayJson: [[String: Any]] = []
        for subRequest in allSubRequests {
            var requestJson: [String: Any] = [:]
            requestJson["referenceId"] = subRequest.referenceId
            requestJson["method"] = RestRequest.httpMethod(from: subRequest.method)

            // queryParams belong in url
            if subRequest.method == .GET || subRequest.method == .DELETE {
                let queryString = RestRequest.toQueryString(subRequest.queryParams as? [String: Any])
                requestJson["url"] = "\(subRequest.endpoint)\(subRequest.path)\(queryString)"
            } else {
                // queryParams belongs in body
                requestJson["url"] = "\(subRequest.endpoint)\(subRequest.path)"
                requestJson["body"] = subRequest.requestBodyAsDictionary
            }
            requestsArrayJson.append(requestJson)
        }

        var compositeRequestJson: [String: Any] = [:]
        compositeRequestJson["compositeRequest"] = requestsArrayJson
        compositeRequestJson["allOrNone"] = NSNumber(value: allOrNone)

        self.path = "/\(compositeApiVersion)/composite"
        super.setCustomRequestBodyDictionary(compositeRequestJson, contentType: "application/json")
        super.serviceHostType = .instance
        super.method = .POST
        super.baseURL = nil
        super.queryParams = nil
        super.endpoint = kSFDefaultRestEndpoint
        super.parseResponse = true
        return super.prepareRequestForSend(user)
    }

    // MARK: - NOOP Overrides

    override public var method: RestRequest.Method {
        get { return super.method }
        set { /* NOOP */ }
    }

    override public var networkServiceType: RestRequest.NetWorkServiceType {
        get { return super.networkServiceType }
        set { /* NOOP */ }
    }

    override public var serviceHostType: RestRequest.ServiceHostType {
        get { return super.serviceHostType }
        set { /* NOOP */ }
    }

    override public var queryParams: NSMutableDictionary? {
        get { return super.queryParams }
        set { /* NOOP */ }
    }

    override public func addPostFileData(_ fileData: Data, paramName: String, fileName: String, mimeType: String, params: [String: Any]?) {
        // NOOP
    }
}

// MARK: - CompositeRequestBuilder

/// Builder class for constructing composite requests.
@objc(SFSDKCompositeRequestBuilder)
@objcMembers
public class CompositeRequestBuilder: NSObject {

    private var allSubRequests: [CompositeSubRequest] = []
    private var allOrNoneFlag: Bool = false

    /// Sets whether all subrequests should succeed or none.
    @objc @discardableResult
    public func setAllOrNone(_ allOrNone: Bool) -> CompositeRequestBuilder {
        self.allOrNoneFlag = allOrNone
        return self
    }

    /// Adds a request with a reference ID.
    @objc @discardableResult
    public func addRequest(_ request: RestRequest, referenceId: String) -> CompositeRequestBuilder {
        let subRequest = CompositeSubRequest(request: request, referenceId: referenceId)
        allSubRequests.append(subRequest)
        return self
    }

    /// Adds a composite subrequest directly.
    @objc @discardableResult
    public func addRequest(_ subRequest: CompositeSubRequest) -> CompositeRequestBuilder {
        allSubRequests.append(subRequest)
        return self
    }

    /// Builds and returns the composite request.
    @objc public func buildCompositeRequest(_ apiVersion: String) -> CompositeRequest {
        let compRequest = CompositeRequest()
        compRequest.compositeApiVersion = apiVersion
        compRequest.allOrNone = allOrNoneFlag
        compRequest.requiresAuthentication = true
        for subRequest in allSubRequests {
            compRequest.addRequest(subRequest)
        }
        return compRequest
    }
}
