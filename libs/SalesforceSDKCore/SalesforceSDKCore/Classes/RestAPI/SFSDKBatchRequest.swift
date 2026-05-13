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

@objc(SFSDKBatchRequest)
@objcMembers
public class BatchRequest: RestRequest {
    internal var haltOnError: Bool = false
    private(set) public var batchRequests: [RestRequest] = []
    internal var apiVersion: String?

    internal init(requests: [RestRequest]) {
        self.batchRequests = requests
        super.init(method: .POST, serviceHostType: .instance, baseURL: nil, path: "", queryParams: nil)
    }

    public override func prepareRequestForSend(_ user: SFUserAccount) -> URLRequest? {
        var requestsArrayJSON = [[String: Any]]()
        for request in batchRequests {
            var requestJSON = [String: Any]()
            requestJSON["method"] = RestRequest.httpMethod(from: request.method)

            // queryParams belong in url
            if request.method == .GET || request.method == .DELETE {
                requestJSON["url"] = "\(request.path)\(RestRequest.toQueryString(request.queryParams))"
            }
            // queryParams belongs in body
            else {
                requestJSON["url"] = request.path
                requestJSON["richInput"] = request.requestBodyAsDictionary
            }
            requestsArrayJSON.append(requestJSON)
        }

        var batchRequestJSON = [String: Any]()
        batchRequestJSON["batchRequests"] = requestsArrayJSON
        batchRequestJSON["haltOnError"] = haltOnError

        let versionToUse = apiVersion ?? ""
        path = "/\(versionToUse)/composite/batch"
        serviceHostType = .instance
        method = .POST
        baseURL = nil
        queryParams = nil
        endpoint = kSFDefaultRestEndpoint
        parseResponse = true
        setCustomRequestBodyDictionary(batchRequestJSON, contentType: "application/json")
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

@objc(SFSDKBatchRequestBuilder)
@objcMembers
public class BatchRequestBuilder: NSObject {
    private var haltOnError: Bool = false
    private var allSubRequests = [RestRequest]()

    @objc
    @discardableResult
    public func setHaltOnError(_ haltOnError: Bool) -> BatchRequestBuilder {
        self.haltOnError = haltOnError
        return self
    }

    @objc
    @discardableResult
    public func addRequest(_ request: RestRequest) -> BatchRequestBuilder {
        allSubRequests.append(request)
        return self
    }

    @objc
    public func buildBatchRequest(_ apiVersion: String) -> BatchRequest {
        let batchRequest = BatchRequest(requests: allSubRequests)
        batchRequest.apiVersion = apiVersion
        batchRequest.haltOnError = haltOnError
        batchRequest.requiresAuthentication = true
        return batchRequest
    }
}
