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

/**
 The default REST endpoint used by requests.
 */
public let kSFDefaultRestEndpoint = "/services/data"

/**
 * Lifecycle events for REST requests.
 */
@objc(SFRestRequestDelegate)
public protocol RestRequestDelegate: AnyObject {
    /**
     * Called when a request was successful.
     *
     * @param request REST request.
     * @param dataResponse The data from the response.  By default, this will be an object
     * containing the parsed JSON response.  However, if the response is not JSON,
     * the data will be contained in a binary `NSData` object.
     * @param rawResponse Raw response returned by the server.
     */
    @objc optional func request(_ request: RestRequest, didSucceed dataResponse: Any, rawResponse: URLResponse)

    /**
     * Called when a request failed.
     *
     * @param request REST request.
     * @param dataResponse The data from the response.  By default, this will be an object
     * containing the parsed JSON response.  However, if the response is not JSON,
     * the data will be contained in a binary `NSData` object.
     * @param rawResponse Raw response returned by the server.
     * @param error Error received.
    */
    @objc optional func request(_ request: RestRequest, didFail dataResponse: Any, rawResponse: URLResponse, error: Error)
}

/**
 * Request object used to send a REST request to Salesforce.com
 * @see SFRestAPI
 */
@objc(SFRestRequest)
@objcMembers
public class RestRequest: NSObject {

    /**
     * HTTP methods for requests.
     */
    @objc(SFRestMethod)
    public enum Method: Int {
        case GET = 0
        case POST
        case PUT
        case DELETE
        case HEAD
        case PATCH
    }

    /**
     * Network Service Types.
     */
    @objc(SFSDKNetworkServiceType)
    public enum NetworkServiceType: Int {
        case `default`
        case responsiveData
        case background
    }

    /**
     * The type of service host to use for Rest requests.
     */
    @objc(SFSDKRestServiceHostType)
    public enum ServiceHostType: UInt {
        /**
         *  Request uses the login endpoint.
         */
        case login

        /**
         *  Request uses the instance endpoint.
         */
        case instance

        /**
         *  Request uses a custom endpoint.
         */
        case custom
    }

    /**
     * The HTTP method of the request. See Method.
     */
    public var method: Method

    /**
     * The network service type of the request. See NetworkServiceType.
     */
    public var networkServiceType: NetworkServiceType

    /**
     * The type of service host for the request (e.g. login or instance).
     */
    public var serviceHostType: ServiceHostType

    /**
     * The NSURLSesssionDataTask instance associated with the request. This is set only
     * once the request is queued and could be 'nil' before that happens.
     */
    public var sessionDataTask: URLSessionDataTask?

    /**
     * The base URL of the request, to be prepended to the value of the `path` property.
     * By default, this will be the API URL associated with the current user's account.
     * One use would be when in a community setting and you want to send a request against the base API URL.
     */
    public var baseURL: String?

    /**
     * The path of the request or the full URL to be used. If a full URL is passed in, the endpoint ceases to matter.
     * For instance, "" (empty string), "v22.0/recent", "v22.0/query".
     * Note that the path doesn't have to start with a '/'. For instance, passing "v22.0/recent" is the same as passing "/v22.0/recent".
     * @warning Do not pass URL encoded query parameters in the path. Use the `queryParams` property instead.
     */
    public var path: String

    /**
     * Used to specify if the response should be parsed. YES by default.
     */
    public var parseResponse: Bool

    /**
     * The query parameters of the request (could be nil).
     * Note that URL encoding of the parameters will automatically happen when the request is sent.
     */
    public var queryParams: [String: Any]?

    /**
     * Dictionary of any custom HTTP headers you wish to add to your request.  You can also use
     * `setHeaderValue:forHeaderName:` to add headers to this property.
     */
    public var customHeaders: [String: String]?

    /**
     * The delegate for this request. Notified of request status.
     */
    public weak var requestDelegate: RestRequestDelegate?

    /**
     * Typically kSFDefaultRestEndpoint but you may use eg custom Apex endpoints
     */
    public var endpoint: String

    /**
     * Whether or not this request requires authentication.  If YES, the credentials will be added to
     * the request headers before sending the request.  If NO, they will not.
     */
    public var requiresAuthentication: Bool

    /**
     * Assigns the timeout interval allowed for this request.
     */
    public var timeoutInterval: TimeInterval

    // Internal properties
    internal var request: NSMutableURLRequest
    internal var requestBodyStreamBlock: (() -> InputStream?)?
    internal var requestBodyAsDictionary: [String: Any]?
    internal var requestContentType: String?
    internal var instrumentationDelegateInternal: RestRequestDelegate?
    internal var failureBlock: RestRequestFailBlock?
    internal var successBlock: RestResponseBlock?

    public init(method: Method, serviceHostType: ServiceHostType = .instance, baseURL: String? = nil, path: String, queryParams: [String: Any]? = nil) {
        self.method = method
        self.serviceHostType = serviceHostType
        self.baseURL = baseURL
        self.path = path
        self.requiresAuthentication = true
        self.queryParams = queryParams
        self.endpoint = (serviceHostType == .custom) ? "" : kSFDefaultRestEndpoint
        self.parseResponse = true
        self.request = NSMutableURLRequest()
        self.timeoutInterval = self.request.timeoutInterval
        self.networkServiceType = .default
        super.init()
    }

    /**
     * Creates an `SFRestRequest` object. See Method. If you need to set body on the request, use one of the 'setCustomRequestBody...' methods to do so with the instance returned by this method.
     * @param method the HTTP method
     * @param path the request path
     * @param queryParams the parameters of the request (could be nil)
     */
    @objc
    public static func request(withMethod method: Method, path: String, queryParams: [String: Any]?) -> RestRequest {
        return RestRequest(method: method, serviceHostType: .instance, baseURL: nil, path: path, queryParams: queryParams)
    }

    /**
     * Creates an `SFRestRequest` object. See Method. If you need to set body on the request, use one of the 'setCustomRequestBody...' methods to do so with the instance returned by this method.
     * @param method the HTTP method
     * @param hostType the type of service host for the request.
     * @param path the request path
     * @param queryParams the parameters of the request (could be nil)
     */
    @objc
    public static func request(withMethod method: Method, serviceHostType hostType: ServiceHostType, path: String, queryParams: [String: Any]?) -> RestRequest {
        return RestRequest(method: method, serviceHostType: hostType, baseURL: nil, path: path, queryParams: queryParams)
    }

    /**
     * Creates an `SFRestRequest` object. To set the body of the request, use one of the `setCustomRequestBody...` methods on the returned instance.
     * @param method HTTP method
     * @param baseURL Request URL
     * @param path Request path
     * @param queryParams Parameters of the request (can be nil)
     * @see Method.
     */
    @objc
    public static func request(withMethod method: Method, baseURL: String, path: String, queryParams: [String: Any]?) -> RestRequest {
        return RestRequest(method: method, serviceHostType: .instance, baseURL: baseURL, path: path, queryParams: queryParams)
    }

    /**
     * Creates an `SFRestRequest` object to be used with non-Salesforce endpoints. To set body on the request, use one of the 'setCustomRequestBody...' methods on the returned instance.
     * @param method the HTTP method
     * @param baseURL the request URL
     * @param path the request path
     * @param queryParams the parameters of the request (could be nil)
     * @see Method.
     */
    @objc
    public static func customUrlRequest(withMethod method: Method, baseURL: String, path: String, queryParams: [String: Any]?) -> RestRequest {
        let request = RestRequest(method: method, serviceHostType: .custom, baseURL: baseURL, path: path, queryParams: queryParams)
        request.requiresAuthentication = false
        return request
    }

    /**
     * Creates an `SFRestRequest` object to be used with custom Salesforce endpoints. See Method. If you need to set body on the request, use one of the 'setCustomRequestBody...' methods to do so with the instance returned by this method.
     * @param method the HTTP method
     * @param path the request path
     * @param queryParams the parameters of the request (could be nil)
     */
    @objc
    public static func customEndPointRequest(withMethod method: Method, endPoint: String, path: String, queryParams: [String: Any]?) -> RestRequest {
        let request = RestRequest(method: method, serviceHostType: .instance, baseURL: nil, path: path, queryParams: queryParams)
        request.endpoint = endPoint
        return request
    }

    public override var description: String {
        let methodName: String
        switch method {
        case .GET: methodName = "GET"
        case .POST: methodName = "POST"
        case .PUT: methodName = "PUT"
        case .DELETE: methodName = "DELETE"
        case .HEAD: methodName = "HEAD"
        case .PATCH: methodName = "PATCH"
        }
        let paramStr = queryParams != nil ? (SFJsonUtils.jsonRepresentation(queryParams) ?? "[]") : "[]"
        return """
        <SFRestRequest \(Unmanaged.passUnretained(self).toOpaque())
        endpoint: \(endpoint)
        method: \(methodName)
        path: \(path)
        queryParams: \(paramStr)
        >
        """
    }

    // MARK: - Custom request body

    /**
     * Sets a custom request body based on an NSString representation.
     * @param bodyString The NSString object representing the request body.
     * @param contentType The content type associated with this request.
     */
    @objc
    public func setCustomRequestBodyString(_ bodyString: String?, contentType: String) {
        let bodyString = bodyString ?? ""
        setCustomRequestBodyData(bodyString.data(using: .utf8) ?? Data(), contentType: contentType)
    }

    /**
     * Sets a custom request body based on an NSDictionary representation.
     * @param bodyDictionary The NSDictionary object representing the request body.
     * @param contentType The content type associated with this request.
     */
    @objc
    public func setCustomRequestBodyDictionary(_ bodyDictionary: [String: Any], contentType: String) {
        self.requestBodyAsDictionary = bodyDictionary
        if let body = SFJsonUtils.jsonDataRepresentation(bodyDictionary, options: []) {
            setCustomRequestBodyData(body, contentType: contentType)
        }
    }

    /**
     * Sets a custom request body based on an NSData representation.
     * @param bodyData The NSData object representing the request body.
     * @param contentType The content type associated with this request.
     */
    @objc
    public func setCustomRequestBodyData(_ bodyData: Data?, contentType: String) {
        let bodyData = bodyData ?? Data()
        let bodyStreamBlock: () -> InputStream? = {
            return InputStream(data: bodyData)
        }
        setCustomRequestBodyStream(bodyStreamBlock, contentType: contentType)
        setHeaderValue("\(bodyData.count)", forHeaderName: "Content-Length")
    }

    /**
     * Sets a custom request body based on an NSInputStream representation.
     * @param bodyStreamBlock The block that will return an NSInputStream object representing the request body.
     * @param contentType The content type associated with this request.
     */
    @objc
    public func setCustomRequestBodyStream(_ bodyStreamBlock: @escaping () -> InputStream?, contentType: String) {
        self.requestBodyStreamBlock = bodyStreamBlock
        if !contentType.isEmpty {
            self.requestContentType = contentType
        }
    }

    // MARK: - send and cancel

    /**
     * Prepares the request before sending it out.
     *
     * @param user User account.
     * @return NSURLRequest instance.
     */
    @objc
    public func prepareRequestForSend(_ user: UserAccount) -> URLRequest? {
        /*
         * If an absolute URL is passed in, use it as-is. If a relative URL is passed in,
         * parse it and put the pieces together to construct the full URL.
         */
        var fullUrl: String

        /* FIXME: Remove handling of full url in the path component for the next major release.
         * Leaving this code in place for backward compatibility for sdk versions 7.0 and prior.
         */
        if path.lowercased().hasPrefix("https://") {
            fullUrl = path
            request = NSMutableURLRequest(url: URL(string: fullUrl)!)
        } else {
            let baseUrl = RestRequest.restUrl(forBaseUrl: baseURL, serviceHostType: serviceHostType, credentials: user.credentials)

            // Performs sanity checks on the path against the endpoint value.
            if serviceHostType != .custom {
                if !endpoint.isEmpty && path.hasPrefix(endpoint) {
                    self.path = String(path.dropFirst(endpoint.count))
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
            if let queryParams = queryParams {
                fullUrl += RestRequest.toQueryString(queryParams)
            }
            request = NSMutableURLRequest(url: URL(string: fullUrl)!)
        }

        // Sets the timeout interval.
        request.timeoutInterval = timeoutInterval

        // Sets the service host type.
        let serviceType = urlRequestServiceType(networkServiceType)
        request.networkServiceType = serviceType

        // Sets HTTP method on the request.
        request.httpMethod = RestRequest.httpMethod(from: method)

        // Sets OAuth Bearer token header on the request (if not already present).
        // Allows Authenticated clients to make api calls that dont require access token.
        if requiresAuthentication, let allHeaders = request.allHTTPHeaderFields, !allHeaders.keys.contains("Authorization") {
            let bearer = "Bearer \(user.credentials.accessToken ?? "")"
            request.setValue(bearer, forHTTPHeaderField: "Authorization")
        }

        // Adds custom headers to the request if any are set.
        if let customHeaders = customHeaders {
            for (key, value) in customHeaders {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        // Sets HTTP body if body exists.
        if let requestBodyStreamBlock = requestBodyStreamBlock {
            if let requestContentType = requestContentType {
                request.setValue(requestContentType, forHTTPHeaderField: "Content-Type")
                request.httpBodyStream = requestBodyStreamBlock()
            }
        }
        return request as URLRequest
    }

    /**
     * Cancels this request if it is running.
     */
    @objc
    public func cancel() {
        sessionDataTask?.cancel()
    }

    /**
     * Sets the value for the specified HTTP header.
     * @param value The header value. If value is `nil`, this method will remove the HTTP header
     * from the collection of headers.
     * @param name The name of the HTTP header to set.
     */
    @objc
    public func setHeaderValue(_ value: String?, forHeaderName name: String) {
        if customHeaders == nil {
            customHeaders = [:]
        }
        if let value = value {
            customHeaders?[name] = value
        } else {
            customHeaders?.removeValue(forKey: name)
        }
    }

    @objc
    internal static func restUrl(forBaseUrl baseUrl: String?, serviceHostType hostType: ServiceHostType, credentials: OAuthCredentials) -> String {
        if let baseUrl = baseUrl {
            return baseUrl
        }
        if let communityUrl = credentials.communityUrl {
            return communityUrl.absoluteString
        }
        if hostType == .login {
            return "\(credentials.protocol)://\(credentials.domain ?? "")"
        } else {
            return credentials.instanceUrl?.absoluteString ?? ""
        }
    }

    // MARK: - Upload

    /**
     * Add file to upload
     * @param fileData Value of this POST parameter
     * @param paramName Name of the POST parameter
     * @param fileName Name of the file
     * @param mimeType MIME type of the file
     * @param params File properties (e.g. title, desc, contentSize)
     */
    @objc
    public func addPostFileData(_ fileData: Data, paramName: String, fileName: String, mimeType: String, params: [String: Any]?) {
        let mpeBoundary = UUID().uuidString
        let mpeSeparator = "--"
        let newline = "\r\n"
        var body = Data()

        // PART 1
        if let params = params {
            if let jsonData = try? JSONSerialization.data(withJSONObject: params, options: .prettyPrinted) {
                body.append("\(mpeSeparator)\(mpeBoundary)\(newline)".data(using: .utf8)!)
                body.append(multiPartRequestBody(forKey: "json", mimeType: "application/json", fileName: nil, file: jsonData))
            }
        }

        body.append("\(mpeSeparator)\(mpeBoundary)\(newline)".data(using: .utf8)!)

        // PART 2
        let mimeType = mimeType.isEmpty ? "application/octet-stream" : mimeType
        body.append(multiPartRequestBody(forKey: paramName, mimeType: mimeType, fileName: fileName, file: fileData))
        body.append("\(mpeSeparator)\(mpeBoundary)\(mpeSeparator)\(newline)".data(using: .utf8)!)

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
        body.append(bodyContentDisposition.data(using: .utf8)!)
        body.append(newline.data(using: .utf8)!)
        body.append("Content-Type: \(mimeType); charset=UTF-8\(newline)".data(using: .utf8)!)
        body.append(newline.data(using: .utf8)!)
        body.append(fileData)
        body.append(newline.data(using: .utf8)!)
        return body
    }

    /** Indicates whether the error code of the given error specifies a network error.
     * @param error The error object to check
     * @return YES if the error code of the given error specifies a network error
     */
    @objc
    public static func isNetworkError(_ error: Error) -> Bool {
        let code = (error as NSError).code
        switch code {
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

    /**
     * Return HTTP method as string for Method
     * @param restMethod The Method
     * @return the HTTP string for the given Method
     */
    @objc
    public static func httpMethod(from restMethod: Method) -> String {
        switch restMethod {
        case .GET: return "GET"
        case .POST: return "POST"
        case .PUT: return "PUT"
        case .DELETE: return "DELETE"
        case .HEAD: return "HEAD"
        case .PATCH: return "PATCH"
        }
    }

    /**
     * Return Method from string
     @param httpMethod An HTTP method; for example, "get" or "post"
     @return The Method enumerator for the given HTTP method
     */
    @objc
    public static func method(fromHTTPMethod httpMethod: String) -> Method {
        let httpMethod = httpMethod.lowercased()
        if httpMethod == "get" { return .GET }
        else if httpMethod == "post" { return .POST }
        else if httpMethod == "put" { return .PUT }
        else if httpMethod == "delete" { return .DELETE }
        else if httpMethod == "head" { return .HEAD }
        else if httpMethod == "patch" { return .PATCH }
        return .GET
    }

    @objc
    internal static func toQueryString(_ components: [String: Any]?) -> String {
        guard let components = components, !components.isEmpty else {
            return ""
        }

        var queryString = "?"
        var parts = [String]()
        for (paramName, paramValue) in components {
            let paramValueStr = "\(paramValue)"
            let part = "\((paramName as NSString).sfsdk_stringByURLEncoding)=\((paramValueStr as NSString).sfsdk_stringByURLEncoding)"
            parts.append(part)
        }
        queryString += parts.joined(separator: "&")
        return queryString
    }

    private func urlRequestServiceType(_ sfNetworkServiceType: NetworkServiceType) -> URLRequest.NetworkServiceType {
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

// MARK: - Block type definitions
// Note: RestRequestFailBlock and RestResponseBlock are defined in SFRestAPI.swift

public typealias RestDictionaryResponseBlock = (_ dict: [String: Any]?, _ rawResponse: URLResponse?) -> Void
public typealias RestArrayResponseBlock = (_ arr: [Any]?, _ rawResponse: URLResponse?) -> Void
public typealias RestDataResponseBlock = (_ data: Data?, _ rawResponse: URLResponse?) -> Void
public typealias RestCompositeResponseBlock = (_ response: CompositeResponse, _ rawResponse: URLResponse?) -> Void
public typealias RestBatchResponseBlock = (_ response: BatchResponse, _ rawResponse: URLResponse?) -> Void
