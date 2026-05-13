/*
Copyright (c) 2019-present, salesforce.com, inc. All rights reserved.

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

@objc(SFSDKCompositeSubRequest)
@objcMembers
public class CompositeSubRequest: RestRequest {
    public var referenceId: String

    @objc
    public init(referenceId: String) {
        self.referenceId = referenceId
        // Initialize with default values - these will be overridden when copying from an existing request
        super.init(method: .GET, serviceHostType: .instance, baseURL: nil, path: "", queryParams: nil)
    }

    @objc
    public convenience init(request: RestRequest, referenceId: String) {
        self.init(referenceId: referenceId)
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
}

@objc(SFSDKCompositeRequest)
@objcMembers
public class CompositeRequest: RestRequest {
    private var requests = [CompositeSubRequest]()
    internal var allOrNone: Bool = false
    internal var apiVersion: String?

    public var allSubRequests: [CompositeSubRequest] {
        return requests
    }

    internal init() {
        // Initialize with defaults for a composite request
        super.init(method: .POST, serviceHostType: .instance, baseURL: nil, path: "", queryParams: nil)
    }

    internal func addRequest(_ subRequest: CompositeSubRequest) {
        requests.append(subRequest)
    }

    public override func prepareRequestForSend(_ user: UserAccount) -> URLRequest? {
        var requestsArrayJSON = [[String: Any]]()
        let subRequests = allSubRequests
        for subRequest in subRequests {
            var requestJSON = [String: Any]()
            requestJSON["referenceId"] = subRequest.referenceId
            requestJSON["method"] = RestRequest.httpMethod(from: subRequest.method)

            // queryParams belong in url
            if subRequest.method == .GET || subRequest.method == .DELETE {
                requestJSON["url"] = "\(subRequest.endpoint)\(subRequest.path)\(RestRequest.toQueryString(subRequest.queryParams))"
            }
            // queryParams belongs in body
            else {
                requestJSON["url"] = "\(subRequest.endpoint)\(subRequest.path)"
                requestJSON["body"] = subRequest.requestBodyAsDictionary
            }
            requestsArrayJSON.append(requestJSON)
        }

        var compositeRequestJSON = [String: Any]()
        compositeRequestJSON["compositeRequest"] = requestsArrayJSON
        compositeRequestJSON["allOrNone"] = allOrNone

        let versionToUse = apiVersion ?? SFRestDefaultAPIVersion
        path = "/\(versionToUse)/composite"
        setCustomRequestBodyDictionary(compositeRequestJSON, contentType: "application/json")
        serviceHostType = .instance
        method = .POST
        baseURL = nil
        queryParams = nil
        endpoint = kSFDefaultRestEndpoint
        parseResponse = true
        return super.prepareRequestForSend(user)
    }

    // Override with NOOP
    public override var method: RestRequest.Method {
        get { return super.method }
        set { /* NOOP */ }
    }

    public override var networkServiceType: RestRequest.NetworkServiceType {
        get { return super.networkServiceType }
        set { /* NOOP */ }
    }

    public override var serviceHostType: RestRequest.ServiceHostType {
        get { return super.serviceHostType }
        set { /* NOOP */ }
    }

    public override var queryParams: [String: Any]? {
        get { return super.queryParams }
        set { /* NOOP */ }
    }

    public override func addPostFileData(_ fileData: Data, paramName: String, fileName: String, mimeType: String, params: [String: Any]?) {
        // NOOP
    }
}

@objc(SFSDKCompositeRequestBuilder)
@objcMembers
public class CompositeRequestBuilder: NSObject {
    private var allOrNone: Bool = false
    private var allSubRequests = [CompositeSubRequest]()

    @objc
    @discardableResult
    public func setAllOrNone(_ allOrNone: Bool) -> CompositeRequestBuilder {
        self.allOrNone = allOrNone
        return self
    }

    @objc
    @discardableResult
    public func addRequest(_ request: RestRequest, referenceId: String) -> CompositeRequestBuilder {
        let subRequest = CompositeSubRequest(request: request, referenceId: referenceId)
        allSubRequests.append(subRequest)
        return self
    }

    @objc
    @discardableResult
    public func addRequest(_ subRequest: CompositeSubRequest) -> CompositeRequestBuilder {
        allSubRequests.append(subRequest)
        return self
    }

    @objc
    public func buildCompositeRequest(_ apiVersion: String) -> CompositeRequest {
        let compRequest = CompositeRequest()
        compRequest.apiVersion = apiVersion
        compRequest.allOrNone = allOrNone
        compRequest.requiresAuthentication = true
        for subRequest in allSubRequests {
            compRequest.addRequest(subRequest)
        }
        return compRequest
    }
}
