//
//  SFRestRequest.swift
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

/// The default REST endpoint used by requests.
public let kSFDefaultRestEndpoint: String = "/services/data"

// MARK: - RestRequestDelegate Protocol

/// Lifecycle events for REST requests.
@objc(SFRestRequestDelegate)
public protocol RestRequestDelegate: NSObjectProtocol {
    /// Called when a request was successful.
    @objc optional func request(_ request: RestRequest, didSucceed dataResponse: Any, rawResponse: URLResponse)
    /// Called when a request failed.
    @objc optional func request(_ request: RestRequest, didFail dataResponse: Any, rawResponse: URLResponse, error: Error)
}

// MARK: - RestRequest

/// Request object used to send a REST request to Salesforce.com.
@objc(SFRestRequest)
open class RestRequest: NSObject {

    // MARK: - Enums

    /// HTTP methods for requests.
    @objc(SFRestMethod)
    public enum Method: Int {
        case GET = 0
        case POST
        case PUT
        case DELETE
        case HEAD
        case PATCH
    }

    /// Network Service Types.
    @objc(SFSDKNetworkServiceType)
    public enum NetWorkServiceType: Int {
        case `default` = 0
        case responsiveData
        case background
    }

    /// The type of service host to use for REST requests.
    @objc(SFSDKRestServiceHostType)
    public enum ServiceHostType: UInt {
        /// Request uses the login endpoint.
        case login = 0
        /// Request uses the instance endpoint.
        case instance
        /// Request uses a custom endpoint.
        case custom
    }

    // MARK: - Public Properties

    /// The HTTP method of the request.
    @objc public var method: Method = .GET

    /// The network service type.
    @objc public var networkServiceType: NetWorkServiceType = .default

    /// The type of service host for the request.
    @objc public var serviceHostType: ServiceHostType = .instance

    /// The NSURLSessionDataTask instance associated with the request.
    @objc public var sessionDataTask: URLSessionDataTask?

    /// The base URL of the request.
    @objc public var baseURL: String?

    /// The path of the request or the full URL.
    @objc public var path: String = ""

    /// Used to specify if the response should be parsed. YES by default.
    @objc public var parseResponse: Bool = true

    /// The query parameters of the request.
    @objc public var queryParams: NSMutableDictionary?

    /// Dictionary of any custom HTTP headers.
    @objc public var customHeaders: NSMutableDictionary?

    /// The delegate for this request.
    @objc public weak var requestDelegate: RestRequestDelegate?

    /// Typically kSFDefaultRestEndpoint but you may use custom Apex endpoints.
    @objc public var endpoint: String = kSFDefaultRestEndpoint

    /// Whether or not this request requires authentication.
    @objc public var requiresAuthentication: Bool = true

    /// Assigns the timeout interval allowed for this request.
    @objc public var timeoutInterval: TimeInterval = 60.0

    // MARK: - Internal Properties

    @objc public var request: NSMutableURLRequest = NSMutableURLRequest()
    @objc public var requestBodyStreamBlock: (() -> InputStream)?
    @objc public var requestBodyAsDictionary: NSDictionary?
    @objc public var requestContentType: String?
    @objc public var instrumentationDelegateInternal: RestRequestDelegate?

    @objc public var failureBlock: RestRequestFailBlock?
    @objc public var successBlock: RestResponseBlock?

    // MARK: - Init

    @objc public override init() {
        super.init()
        self.request = NSMutableURLRequest()
        self.timeoutInterval = self.request.timeoutInterval
    }

    @objc public required init(method: Method, serviceHostType: ServiceHostType, baseURL: String?, path: String, queryParams: [String: Any]?) {
        super.init()
        self.method = method
        self.serviceHostType = serviceHostType
        self.baseURL = baseURL
        self.path = path
        self.requiresAuthentication = true
        self.queryParams = queryParams != nil ? NSMutableDictionary(dictionary: queryParams!) : nil
        self.endpoint = (serviceHostType == .custom) ? "" : kSFDefaultRestEndpoint
        self.parseResponse = true
        self.request = NSMutableURLRequest()
        self.timeoutInterval = self.request.timeoutInterval
    }

    // MARK: - Factory Methods

    /// Creates an `RestRequest` object with the given method, path, and query params.
    @objc public static func request(withMethod method: Method, path: String, queryParams: [String: Any]?) -> Self {
        return self.init(method: method, serviceHostType: .instance, baseURL: nil, path: path, queryParams: queryParams)
    }

    /// Creates an `RestRequest` object with the given method, base URL, path, and query params.
    @objc public static func request(withMethod method: Method, baseURL: String, path: String, queryParams: [String: Any]?) -> Self {
        return self.init(method: method, serviceHostType: .instance, baseURL: baseURL, path: path, queryParams: queryParams)
    }

    /// Creates an `RestRequest` object for custom (non-Salesforce) endpoints.
    @objc public static func customUrlRequest(withMethod method: Method, baseURL: String, path: String, queryParams: [String: Any]?) -> Self {
        let request = self.init(method: method, serviceHostType: .custom, baseURL: baseURL, path: path, queryParams: queryParams)
        request.requiresAuthentication = false
        return request
    }

    /// Creates an `RestRequest` object with a custom endpoint.
    @objc public static func customEndPointRequest(withMethod method: Method, endPoint: String, path: String, queryParams: [String: Any]?) -> Self {
        let request = self.init(method: method, serviceHostType: .instance, baseURL: nil, path: path, queryParams: queryParams)
        request.endpoint = endPoint
        return request
    }

    /// Creates an `RestRequest` object with a service host type.
    @objc public static func request(withMethod method: Method, serviceHostType: ServiceHostType, path: String, queryParams: [String: Any]?) -> Self {
        return self.init(method: method, serviceHostType: serviceHostType, baseURL: nil, path: path, queryParams: queryParams)
    }

    // MARK: - Convenience Init

    @objc public convenience init(method: Method, path: String, queryParams: [String: Any]?) {
        self.init(method: method, serviceHostType: .instance, baseURL: nil, path: path, queryParams: queryParams)
    }

    // MARK: - Description

    open override var description: String {
        let methodName: String
        switch method {
        case .GET: methodName = "GET"
        case .POST: methodName = "POST"
        case .PUT: methodName = "PUT"
        case .DELETE: methodName = "DELETE"
        case .HEAD: methodName = "HEAD"
        case .PATCH: methodName = "PATCH"
        }
        let paramStr = queryParams != nil ? (SFJsonUtils.jsonRepresentation(queryParams as Any) ?? "[]") : "[]"
        return "<RestRequest \(Unmanaged.passUnretained(self).toOpaque()) \nendpoint: \(endpoint) \nmethod: \(methodName) \npath: \(path) \nqueryParams: \(paramStr) \n>"
    }

    // MARK: - Custom Request Body

    /// Sets a custom request body based on a string representation.
    @objc public func setCustomRequestBodyString(_ bodyString: String, contentType: String) {
        let str = bodyString
        setCustomRequestBodyData(str.data(using: .utf8) ?? Data(), contentType: contentType)
    }

    /// Sets a custom request body based on a dictionary representation.
    @objc public func setCustomRequestBodyDictionary(_ bodyDictionary: [String: Any], contentType: String) {
        requestBodyAsDictionary = bodyDictionary as NSDictionary
        if let body = SFJsonUtils.jsonDataRepresentation(bodyDictionary, options: []) {
            setCustomRequestBodyData(body, contentType: contentType)
        }
    }

    /// Sets a custom request body based on a data representation.
    @objc public func setCustomRequestBodyData(_ bodyData: Data, contentType: String) {
        let data = bodyData
        let bodyStreamBlock: () -> InputStream = {
            return InputStream(data: data)
        }
        setCustomRequestBodyStream(bodyStreamBlock, contentType: contentType)
        setHeaderValue("\(data.count)", forHeaderName: "Content-Length")
    }

    /// Sets a custom request body based on a stream block.
    @objc public func setCustomRequestBodyStream(_ bodyStreamBlock: @escaping () -> InputStream, contentType: String) {
        self.requestBodyStreamBlock = bodyStreamBlock
        if !contentType.isEmpty {
            self.requestContentType = contentType
        }
    }

    // MARK: - Send and Cancel

    /// Prepares the request before sending it out.
    @objc public func prepareRequestForSend(_ user: UserAccount) -> URLRequest? {
        var fullUrl: String

        // If an absolute URL is passed in, use it as-is.
        if path.lowercased().hasPrefix("https://") {
            fullUrl = path
            request = NSMutableURLRequest(url: URL(string: fullUrl) ?? URL(fileURLWithPath: ""))
        } else {
            let baseUrl = RestRequest.restUrl(forBaseUrl: baseURL, serviceHostType: serviceHostType, credentials: user.credentials)

            // Performs sanity checks on the path against the endpoint value.
            if serviceHostType != .custom {
                if !endpoint.isEmpty && path.hasPrefix(endpoint) {
                    path = String(path.dropFirst(endpoint.count))
                }
            }

            // Puts the pieces together and constructs a full URL.
            fullUrl = baseUrl
            if !fullUrl.hasSuffix("/") {
                fullUrl += "/"
            }

            // 'endpoint' could be empty for a custom endpoint like 'apexrest'.
            var endpointStr = endpoint
            if !endpointStr.isEmpty {
                if endpointStr.hasPrefix("/") {
                    endpointStr = String(endpointStr.dropFirst())
                }
                if !endpointStr.hasSuffix("/") {
                    endpointStr += "/"
                }
                fullUrl += endpointStr
            }

            var pathStr = path
            if pathStr.hasPrefix("/") {
                pathStr = String(pathStr.dropFirst())
            }
            fullUrl += pathStr

            // Adds query parameters to the request if any are set.
            if let queryParams = queryParams as? [String: Any], !queryParams.isEmpty {
                fullUrl += RestRequest.toQueryString(queryParams)
            }
            request = NSMutableURLRequest(url: URL(string: fullUrl) ?? URL(fileURLWithPath: ""))
        }

        // Sets the timeout interval.
        request.timeoutInterval = timeoutInterval

        // Sets the service host type.
        request.networkServiceType = urlRequestServiceType(networkServiceType)

        // Sets HTTP method on the request.
        request.httpMethod = RestRequest.httpMethod(from: method)

        // Sets OAuth Bearer token header on the request (if not already present).
        if requiresAuthentication && !(request.allHTTPHeaderFields?.keys.contains("Authorization") ?? false) {
            if let accessToken = user.credentials.accessToken {
                request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            }
        }

        // Adds custom headers to the request if any are set.
        if let customHeaders = customHeaders as? [String: String] {
            for (key, value) in customHeaders {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        // Sets HTTP body if body exists.
        if let streamBlock = requestBodyStreamBlock, let contentType = requestContentType {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
            request.httpBodyStream = streamBlock()
        }

        return request as URLRequest
    }

    /// Cancels this request if it is running.
    @objc public func cancel() {
        sessionDataTask?.cancel()
    }

    /// Sets the value for the specified HTTP header.
    @objc public func setHeaderValue(_ value: String?, forHeaderName name: String) {
        if customHeaders == nil {
            customHeaders = NSMutableDictionary()
        }
        if let value = value {
            customHeaders?.setObject(value, forKey: name as NSString)
        } else {
            customHeaders?.removeObject(forKey: name)
        }
    }

    // MARK: - URL Building

    @objc public static func restUrl(forBaseUrl baseUrl: String?, serviceHostType: ServiceHostType, credentials: OAuthCredentials) -> String {
        if let baseUrl = baseUrl {
            return baseUrl
        }
        if let communityUrl = credentials.communityUrl {
            return communityUrl.absoluteString
        }
        if serviceHostType == .login {
            return "\(credentials.protocol ?? "https")://\(credentials.domain ?? "")"
        }
        return credentials.instanceUrl?.absoluteString ?? ""
    }

    @objc public static func toQueryString(_ components: [String: Any]?) -> String {
        guard let components = components, !components.isEmpty else { return "" }
        var parts: [String] = []
        for (paramName, paramValue) in components {
            let encodedName = (paramName as NSString).sfsdk_stringByURLEncoding() ?? paramName
            let valueStr = "\(paramValue)"
            let encodedValue = (valueStr as NSString).sfsdk_stringByURLEncoding() ?? valueStr
            parts.append("\(encodedName)=\(encodedValue)")
        }
        return "?" + parts.joined(separator: "&")
    }

    // MARK: - Upload

    /// Add file to upload.
    @objc public func addPostFileData(_ fileData: Data, paramName: String, fileName: String, mimeType: String, params: [String: Any]?) {
        let mpeBoundary = UUID().uuidString
        let mpeSeparator = "--"
        let newline = "\r\n"
        var body = Data()

        // PART 1
        if let params = params {
            if let jsonData = try? JSONSerialization.data(withJSONObject: params, options: .prettyPrinted) {
                body.append(Data("\(mpeSeparator)\(mpeBoundary)\(newline)".utf8))
                body.append(multiPartRequestBody(forKey: "json", mimeType: "application/json", fileName: nil, file: jsonData))
            }
        }

        body.append(Data("\(mpeSeparator)\(mpeBoundary)\(newline)".utf8))

        // PART 2
        let resolvedMimeType = mimeType.isEmpty ? "application/octet-stream" : mimeType
        body.append(multiPartRequestBody(forKey: paramName, mimeType: resolvedMimeType, fileName: fileName, file: fileData))
        body.append(Data("\(mpeSeparator)\(mpeBoundary)\(mpeSeparator)\(newline)".utf8))

        setCustomRequestBodyData(body, contentType: "multipart/form-data; boundary=\(mpeBoundary)")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.httpShouldHandleCookies = false
        setHeaderValue("Keep-Alive", forHeaderName: "Connection")
        setHeaderValue("multipart/form-data; boundary=\(mpeBoundary)", forHeaderName: "Content-Type")
    }

    private func multiPartRequestBody(forKey key: String, mimeType: String, fileName: String?, file fileData: Data) -> Data {
        var body = Data()
        let newline = "\r\n"
        var bodyContentDisposition = "Content-Disposition: form-data; name=\"\(key)\";"
        if let fileName = fileName {
            bodyContentDisposition += " filename=\"\(fileName)\""
        }
        body.append(Data(bodyContentDisposition.utf8))
        body.append(Data(newline.utf8))
        body.append(Data("Content-Type: \(mimeType); charset=UTF-8\(newline)".utf8))
        body.append(Data(newline.utf8))
        body.append(fileData)
        body.append(Data(newline.utf8))
        return body
    }

    // MARK: - Static Utility Methods

    /// Indicates whether the error code of the given error specifies a network error.
    @objc public static func isNetworkError(_ error: Error) -> Bool {
        let nsError = error as NSError
        switch nsError.code {
        case Int(CFNetworkErrors.cfurlErrorNotConnectedToInternet.rawValue),
             Int(CFNetworkErrors.cfurlErrorCannotFindHost.rawValue),
             Int(CFNetworkErrors.cfurlErrorCannotConnectToHost.rawValue),
             Int(CFNetworkErrors.cfurlErrorNetworkConnectionLost.rawValue),
             Int(CFNetworkErrors.cfurlErrorDNSLookupFailed.rawValue),
             Int(CFNetworkErrors.cfurlErrorResourceUnavailable.rawValue),
             Int(CFNetworkErrors.cfurlErrorTimedOut.rawValue),
             Int(CFNetworkErrors.cfurlErrorDataNotAllowed.rawValue):
            return true
        default:
            return false
        }
    }

    /// Return HTTP method as string for a Method enum value.
    @objc public static func httpMethod(from restMethod: Method) -> String {
        switch restMethod {
        case .GET: return "GET"
        case .POST: return "POST"
        case .PUT: return "PUT"
        case .DELETE: return "DELETE"
        case .HEAD: return "HEAD"
        case .PATCH: return "PATCH"
        }
    }

    /// Return Method enum from string.
    @objc public static func sfRestMethod(from httpMethod: String) -> Method {
        switch httpMethod.lowercased() {
        case "get": return .GET
        case "post": return .POST
        case "put": return .PUT
        case "delete": return .DELETE
        case "head": return .HEAD
        case "patch": return .PATCH
        default: return .GET
        }
    }

    // MARK: - Private Helpers

    private func urlRequestServiceType(_ sfNetworkServiceType: NetWorkServiceType) -> URLRequest.NetworkServiceType {
        switch sfNetworkServiceType {
        case .background:
            return .background
        case .responsiveData:
            return .responsiveData
        default:
            return .default
        }
    }
}
