//
//  SFSDKBatchRequest.swift
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

/// Represents a batch REST request containing multiple subrequests.
@objc(SFSDKBatchRequest)
@objcMembers
public class BatchRequest: RestRequest {

    /// Whether to halt on error.
    public internal(set) var haltOnError: Bool = false

    /// The array of batch subrequests.
    public private(set) var batchRequests: [RestRequest] = []

    /// Internal API version storage.
    internal var batchApiVersion: String = SFRestDefaultAPIVersion

    init(requests: [RestRequest]) {
        super.init()
        self.batchRequests = requests
    }

    override public required init(method: RestRequest.Method, serviceHostType: RestRequest.ServiceHostType, baseURL: String?, path: String, queryParams: [String: Any]?) {
        super.init(method: method, serviceHostType: serviceHostType, baseURL: baseURL, path: path, queryParams: queryParams)
    }

    override public func prepareRequestForSend(_ user: UserAccount) -> URLRequest? {
        var requestsArrayJson: [[String: Any]] = []
        for request in batchRequests {
            var requestJson: [String: Any] = [:]
            requestJson["method"] = RestRequest.httpMethod(from: request.method)

            // queryParams belong in url
            if request.method == .GET || request.method == .DELETE {
                let queryString = RestRequest.toQueryString(request.queryParams as? [String: Any])
                requestJson["url"] = "\(request.path)\(queryString)"
            } else {
                // queryParams belongs in body
                requestJson["url"] = request.path
                requestJson["richInput"] = request.requestBodyAsDictionary
            }
            requestsArrayJson.append(requestJson)
        }

        var batchRequestJson: [String: Any] = [:]
        batchRequestJson["batchRequests"] = requestsArrayJson
        batchRequestJson["haltOnError"] = NSNumber(value: haltOnError)

        let path = "/\(batchApiVersion)/composite/batch"
        super.path = path
        super.serviceHostType = .instance
        super.method = .POST
        super.baseURL = nil
        super.queryParams = nil
        super.endpoint = kSFDefaultRestEndpoint
        super.parseResponse = true
        super.setCustomRequestBodyDictionary(batchRequestJson, contentType: "application/json")
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

// MARK: - BatchRequestBuilder

/// Builder class for constructing batch requests.
@objc(SFSDKBatchRequestBuilder)
@objcMembers
public class BatchRequestBuilder: NSObject {

    private var allSubRequests: [RestRequest] = []
    private var haltOnErrorFlag: Bool = false

    /// Sets whether to halt on error.
    @objc @discardableResult
    public func setHaltOnError(_ haltOnError: Bool) -> BatchRequestBuilder {
        self.haltOnErrorFlag = haltOnError
        return self
    }

    /// Adds a request to the batch.
    @objc @discardableResult
    public func addRequest(_ request: RestRequest) -> BatchRequestBuilder {
        allSubRequests.append(request)
        return self
    }

    /// Builds and returns the batch request.
    @objc public func buildBatchRequest(_ apiVersion: String) -> BatchRequest {
        let batchRequest = BatchRequest(requests: allSubRequests)
        batchRequest.batchApiVersion = apiVersion
        batchRequest.haltOnError = haltOnErrorFlag
        batchRequest.requiresAuthentication = true
        return batchRequest
    }
}
