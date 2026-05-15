/*
 SFSDKOAuth2.swift
 SalesforceSDKCore

 Created by Raj Rao on 7/11/19.
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
import UIKit
import SalesforceSDKCommon

/// SFOAuth default network timeout in seconds.
public let kSFOAuthDefaultTimeout: TimeInterval = 120.0

/// This constant defines the SFOAuth framework error domain.
/// Domain indicating an error occurred during OAuth authentication.
public let kSFOAuthErrorDomain = "com.salesforce.OAuth.ErrorDomain"

/// SFOAuthErrorDomain related error codes
/// Constants used by SFOAuthCoordinator to indicate errors in the SFOAuth domain
@objc public enum SFOAuthError: Int {
    case unknown = 666
    case timeout
    case malformed
    case accessDenied              // end user denied authorization
    case invalidClientId
    case invalidClientCredentials  // client secret invalid
    case invalidGrant              // expired access/refresh token, or IP restricted, or invalid login hours
    case invalidRequest
    case inactiveUser
    case inactiveOrg
    case rateLimitExceeded
    case unsupportedResponseType
    case wrongVersion              // credentials do not match current Connected App version in the org
    case browserLaunchFailed
    case unknownAdvancedAuthConfig
    case invalidMDMConfiguration
    case jwtInvalidGrant
    case requestCancelled
    case refreshFailed             // generic error
    case invalidURL
}

@objc public enum SFLogoutReason: Int {
    case corruptState                                  // Corrupted client state
    case corruptStateAppConfigurationSettings          // bad configuration settings
    case corruptStateAppProviderErrorInvalidUser       // invalid user
    case corruptStateAppInvalidRestClient              // invalid rest client
    case corruptStateAppOther                          // other
    case corruptStateMSDK                              // Corrupted client state detected by Mobile SDK
    case tokenExpired                                  // Refresh token expired
    case ssdkPolicy                                    // SSDK initiated logout for policy violation
    case timeout                                       // Timeout while waiting for server response
    case unexpected                                    // Unexpected error or crash
    case unexpectedResponse                            // Unexpected response from server
    case unknown                                       // Unknown
    case userInitiated                                 // User initiated logout
    case refreshTokenRotated                           // Refresh token rotated
}

// MARK: - SFSDKOAuthTokenEndpointErrorResponse

@objc(SFSDKOAuthTokenEndpointErrorResponse)
public class SFSDKOAuthTokenEndpointErrorResponse: NSObject {

    @objc public let tokenEndpointErrorCode: String
    @objc public let tokenEndpointErrorDescription: String
    @objc public let error: NSError

    init(errorType: String, description: String) {
        self.tokenEndpointErrorCode = errorType
        self.tokenEndpointErrorDescription = description
        self.error = SFSDKOAuth2.error(withType: errorType, description: description)
        super.init()
    }

    init(error: NSError) {
        self.tokenEndpointErrorCode = ""
        self.tokenEndpointErrorDescription = ""
        self.error = error
        super.init()
    }
}

// MARK: - SFSDKOAuthTokenEndpointRequest

@objc(SFSDKOAuthTokenEndpointRequest)
public class SFSDKOAuthTokenEndpointRequest: NSObject {
    @objc public var refreshToken: String = ""
    @objc public var userAgentForAuth: String?
    @objc public var redirectURI: String = ""
    @objc public var clientID: String = ""
    @objc public var approvalCode: String?
    @objc public var codeVerifier: String?
    @objc public var timeout: TimeInterval = kSFOAuthDefaultTimeout
    @objc public var serverURL: URL = URL(string: "https://login.salesforce.com")!
    @objc public var additionalTokenRefreshParams: [String: String]?
    @objc public var additionalOAuthParameterKeys: [String]?
}

// MARK: - SFSDKOAuthTokenEndpointResponse

@objc(SFSDKOAuthTokenEndpointResponse)
public class SFSDKOAuthTokenEndpointResponse: NSObject {

    private let values: NSMutableDictionary
    private var additionalOAuthParameterKeys: [String]?
    private var parsedScopes: [String]?
    private var parsedAdditionalOAuthFields: [String: Any]?

    @objc public var hasError: Bool {
        return error != nil
    }

    @objc public private(set) var error: SFSDKOAuthTokenEndpointErrorResponse?

    @objc public var accessToken: String {
        return values[kSFOAuthAccessToken] as? String ?? ""
    }

    @objc public var refreshToken: String {
        get {
            return values[kSFOAuthRefreshToken] as? String ?? ""
        }
        set {
            values[kSFOAuthRefreshToken] = newValue
        }
    }

    @objc public var issuedAt: Date {
        return SFSDKOAuth2.timestampString(toDate: values[kSFOAuthIssuedAt] as? String) ?? Date()
    }

    @objc public var instanceUrl: URL? {
        guard let urlString = values[kSFOAuthInstanceUrl] as? String else { return nil }
        return URL(string: urlString)
    }

    @objc public var apiInstanceUrl: URL? {
        guard let urlString = values[kSFOAuthApiInstanceUrl] as? String else { return nil }
        return URL(string: urlString)
    }

    @objc public var identityUrl: URL? {
        guard let urlString = values[kSFOAuthId] as? String else { return nil }
        return URL(string: urlString)
    }

    @objc public var idToken: String? {
        return values[kSFOAuthIdToken] as? String
    }

    @objc public var communityId: String? {
        return values[kSFOAuthCommunityId] as? String
    }

    @objc public var communityUrl: URL? {
        guard let urlString = values[kSFOAuthCommunityUrl] as? String else { return nil }
        return URL(string: urlString)
    }

    @objc public var apiUrl: URL? {
        return nil
    }

    @objc public var signature: String? {
        return values[kSFOAuthSignature] as? String
    }

    @objc public var scopes: [String]? {
        return parsedScopes
    }

    @objc public var additionalOAuthFields: [String: Any]? {
        return parsedAdditionalOAuthFields
    }

    @objc public var lightningDomain: String? {
        return values[kSFOAuthLightningDomain] as? String
    }

    @objc public var lightningSid: String? {
        return values[kSFOAuthLightningSID] as? String
    }

    @objc public var vfDomain: String? {
        return values[kSFOAuthVFDomain] as? String
    }

    @objc public var vfSid: String? {
        return values[kSFOAuthVFSID] as? String
    }

    @objc public var contentDomain: String? {
        return values[kSFOAuthContentDomain] as? String
    }

    @objc public var contentSid: String? {
        return values[kSFOAuthContentSID] as? String
    }

    @objc public var csrfToken: String? {
        return values[kSFOAuthCSRFToken] as? String
    }

    @objc public var cookieClientSrc: String? {
        return values[kSFOAuthCookieClientSrc] as? String
    }

    @objc public var cookieSidClient: String? {
        return values[kSFOAuthCookieSidClient] as? String
    }

    @objc public var sidCookieName: String? {
        return values[kSFOAuthSidCookieName] as? String
    }

    @objc public var parentSid: String? {
        return values[kSFOAuthParentSid] as? String
    }

    @objc public var tokenFormat: String? {
        return values[kSFOAuthTokenFormat] as? String
    }

    @objc public var beaconChildConsumerKey: String? {
        return values[kSFOAuthBeaconChildConsumerKey] as? String
    }

    @objc public var beaconChildConsumerSecret: String? {
        return values[kSFOAuthBeaconChildConsumerSecret] as? String
    }

    init(error: NSError) {
        self.values = NSMutableDictionary()
        self.error = SFSDKOAuthTokenEndpointErrorResponse(error: error)
        super.init()
    }

    init(dictionary nvPairs: [String: Any], parseAdditionalFields additionalOAuthParameterKeys: [String]?) {
        self.values = NSMutableDictionary(dictionary: nvPairs)
        self.additionalOAuthParameterKeys = additionalOAuthParameterKeys
        super.init()

        if let keys = additionalOAuthParameterKeys {
            var parsedValues: [String: Any] = [:]
            for key in keys {
                if let obj = nvPairs[key] {
                    parsedValues[key] = obj
                }
            }
            if !parsedValues.isEmpty {
                self.parsedAdditionalOAuthFields = parsedValues
            }
        }

        if let rawScope = nvPairs[kSFOAuthScope] as? String {
            self.parsedScopes = rawScope.components(separatedBy: " ")
        }

        if let errorType = nvPairs[kSFOAuthError] as? String {
            let description = nvPairs[kSFOAuthErrorDescription] as? String ?? ""
            self.error = SFSDKOAuthTokenEndpointErrorResponse(errorType: errorType, description: description)
        }
    }

    @objc public func asDictionary() -> [String: Any] {
        return values as? [String: Any] ?? [:]
    }
}

// MARK: - SFSDKOAuthProtocol

@objc(SFSDKOAuthProtocol)
public protocol SFSDKOAuthProtocol {
    func accessToken(forApprovalCode endpointReq: SFSDKOAuthTokenEndpointRequest, completion: @escaping (SFSDKOAuthTokenEndpointResponse) -> Void)
    func accessToken(forRefresh endpointReq: SFSDKOAuthTokenEndpointRequest, completion: @escaping (SFSDKOAuthTokenEndpointResponse) -> Void)
    func openIDToken(forRefresh endpointReq: SFSDKOAuthTokenEndpointRequest, completion: @escaping (String?) -> Void)
    func revokeRefreshToken(_ credentials: OAuthCredentials, reason: SFLogoutReason)
}

// MARK: - SFSDKOAuthSessionManaging (Deprecated)

@available(*, deprecated, message: "Will be removed.")
@objc(SFSDKOAuthSessionManaging)
public protocol SFSDKOAuthSessionManaging {
    func createURLSession(withIdentifier identifier: String) -> URLSession
}

// MARK: - SFSDKOAuth2

@objc(SFSDKOAuth2)
public class SFSDKOAuth2: NSObject, SFSDKOAuthProtocol, SFSDKOAuthSessionManaging {

    // MARK: - SFSDKOAuthProtocol

    @objc public func accessToken(forApprovalCode endpointReq: SFSDKOAuthTokenEndpointRequest, completion: @escaping (SFSDKOAuthTokenEndpointResponse) -> Void) {
        let request = prepareBasicRequest(endpointReq)

        let params = NSMutableString()
        params.append("\(kSFOAuthFormat)=json")
        params.append("&\(kSFOAuthRedirectUri)=\(endpointReq.redirectURI)")
        params.append("&\(kSFOAuthClientId)=\(endpointReq.clientID)")
        params.append("&\(kSFOAuthDeviceId)=\(UIDevice.current.identifierForVendor?.uuidString ?? "")")

        if let codeVerifier = endpointReq.codeVerifier {
            params.append("&\(kSFOAuthCodeVerifierParamName)=\(codeVerifier)")
        }

        let grantType = SalesforceManager.shared.useHybridAuthentication ? kSFOAuthGrantTypeHybridAuthorizationCode : kSFOAuthGrantTypeAuthorizationCode
        params.append("&\(kSFOAuthGrantType)=\(grantType)")

        if let approvalCode = endpointReq.approvalCode {
            params.append("&\(kSFOAuthApprovalCode)=\(approvalCode)")
        }

        let encodedBody = (params as String).data(using: .utf8)
        request.httpBody = encodedBody

        let networkIdentifier = Network.uniqueInstanceIdentifier()
        let network = Network.sharedEphemeralInstance(withIdentifier: networkIdentifier)

        network.sendRequest(request as URLRequest) { [weak self] (data: Data?, urlResponse: URLResponse?, error: Error?) in
            Network.removeSharedInstance(forIdentifier: networkIdentifier)

            guard let self = self else {
                DispatchQueue.main.async {
                    completion(SFSDKOAuthTokenEndpointResponse(error: NSError(domain: kSFOAuthErrorDomain, code: SFOAuthError.unknown.rawValue, userInfo: nil)))
                }
                return
            }

            if let error = error {
                let requestUrl = request.url
                let errorUrlString = "\(requestUrl?.scheme ?? "")://\(requestUrl?.host ?? "")\(requestUrl?.relativePath ?? "")"

                let endpointResponse: SFSDKOAuthTokenEndpointResponse
                let nsError = error as NSError
                if nsError.code == NSURLErrorTimedOut {
                    SFSDKCoreLogger.d(type(of: self), message: "Attempt to get access token for approval code timed out after \(endpointReq.timeout) seconds.")
                    endpointResponse = SFSDKOAuthTokenEndpointResponse(error: NSError(domain: kSFOAuthErrorDomain, code: SFOAuthError.timeout.rawValue, userInfo: nil))
                } else {
                    endpointResponse = SFSDKOAuthTokenEndpointResponse(error: nsError)
                }

                SFSDKCoreLogger.d(type(of: self), message: "SFOAuth2 session failed with error: error code: \(nsError.code), description: \(error.localizedDescription), URL: \(errorUrlString)")

                DispatchQueue.main.async {
                    completion(endpointResponse)
                }
                return
            }

            if let data = data, let urlResponse = urlResponse {
                self.handleTokenEndpointResponse(completion, request: endpointReq, data: data, urlResponse: urlResponse)
            }
        }
    }

    @objc public func accessToken(forRefresh endpointReq: SFSDKOAuthTokenEndpointRequest, completion: @escaping (SFSDKOAuthTokenEndpointResponse) -> Void) {
        let request = prepareBasicRequest(endpointReq)

        let params = NSMutableString()
        params.append("\(kSFOAuthFormat)=json")
        params.append("&\(kSFOAuthRedirectUri)=\(endpointReq.redirectURI)")
        params.append("&\(kSFOAuthClientId)=\(endpointReq.clientID)")
        params.append("&\(kSFOAuthDeviceId)=\(UIDevice.current.identifierForVendor?.uuidString ?? "")")

        SFSDKCoreLogger.i(type(of: self), message: "accessToken(forRefresh:completion:): Initiating refresh token flow.")

        let grantType = SalesforceManager.shared.useHybridAuthentication ? kSFOAuthGrantTypeHybridRefresh : kSFOAuthGrantTypeRefresh
        params.append("&\(kSFOAuthGrantType)=\(grantType)")
        params.append("&\(kSFOAuthRefreshToken)=\(endpointReq.refreshToken)")

        if let additionalParams = endpointReq.additionalTokenRefreshParams {
            for (key, value) in additionalParams {
                let encodedKey = key.sfsdk_stringByURLEncoding
                let encodedValue = value.sfsdk_stringByURLEncoding
                params.append("&\(encodedKey)=\(encodedValue)")
            }
        }

        let encodedBody = (params as String).data(using: .utf8)
        request.httpBody = encodedBody

        let instanceIdentifier = Network.uniqueInstanceIdentifier()
        let network = Network.sharedEphemeralInstance(withIdentifier: instanceIdentifier)
        let className = String(describing: type(of: self))

        network.sendRequest(request as URLRequest) { [weak self] (data: Data?, urlResponse: URLResponse?, error: Error?) in
            Network.removeSharedInstance(forIdentifier: instanceIdentifier)

            if let error = error {
                let requestUrl = request.url
                let errorUrlString = "\(requestUrl?.scheme ?? "")://\(requestUrl?.host ?? "")\(requestUrl?.relativePath ?? "")"

                let nsError = error as NSError
                let code = SFSDKOAuth2.sfErrorCode(from: nsError.code)
                let endpointResponse = SFSDKOAuthTokenEndpointResponse(error: NSError(domain: kSFOAuthErrorDomain, code: code, userInfo: nil))

                if nsError.code == NSURLErrorTimedOut {
                    SFSDKCoreLogger.d(SFSDKOAuth2.self, message: "Refresh attempt timed out after \(endpointReq.timeout) seconds.")
                }

                SFSDKCoreLogger.d(SFSDKOAuth2.self, message: "SFOAuth2 session failed with error: error code: \(nsError.code), description: \(error.localizedDescription), URL: \(errorUrlString)")

                DispatchQueue.main.async {
                    completion(endpointResponse)
                }
                return
            }

            SFSDKEventBuilderHelper.createAndStoreEvent("tokenRefresh", userAccount: UserAccountManager.shared.currentUserAccount, className: className, attributes: nil)

            if let self = self, let data = data, let urlResponse = urlResponse {
                self.handleTokenEndpointResponse(completion, request: endpointReq, data: data, urlResponse: urlResponse)
            } else {
                SFSDKCoreLogger.d(SFSDKOAuth2.self, message: "Token endpoint response handler skipped because self was deallocated.")
                DispatchQueue.main.async {
                    completion(SFSDKOAuthTokenEndpointResponse(error: NSError(domain: kSFOAuthErrorDomain, code: SFOAuthError.unknown.rawValue, userInfo: nil)))
                }
            }
        }
    }

    @objc public func openIDToken(forRefresh endpointReq: SFSDKOAuthTokenEndpointRequest, completion: @escaping (String?) -> Void) {
        accessToken(forRefresh: endpointReq) { authTokenEndpointResponse in
            let idToken = authTokenEndpointResponse.idToken
            completion(idToken)
        }
    }

    @objc public func revokeRefreshToken(_ credentials: OAuthCredentials, reason: SFLogoutReason) {
        if credentials.refreshToken != nil {
            let request = SFSDKOAuth2.request(forRevokeRefreshToken: credentials, reason: reason)

            let networkIdentifier = Network.uniqueInstanceIdentifier()
            let network = Network.sharedEphemeralInstance(withIdentifier: networkIdentifier)
            network.sendRequest(request as URLRequest) { _, _, _ in
                Network.removeSharedInstance(forIdentifier: networkIdentifier)
            }
        }
        credentials.revoke()
    }

    // MARK: - SFSDKOAuthSessionManaging

    @objc public func createURLSession(withIdentifier identifier: String) -> URLSession {
        let network = Network.sharedEphemeralInstance(withIdentifier: identifier)
        return network.activeSession
    }

    // MARK: - Private Methods

    private func prepareBasicRequest(_ endpointReq: SFSDKOAuthTokenEndpointRequest) -> NSMutableURLRequest {
        let protocolHost = endpointReq.serverURL.absoluteString
        var urlString = "\(protocolHost)\(kSFOAuthEndPointToken)"

        if !urlString.hasPrefix("http") {
            urlString = "https://\(urlString)"
        }

        guard let url = URL(string: urlString) else {
            return NSMutableURLRequest()
        }

        let request = NSMutableURLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: endpointReq.timeout)
        request.httpMethod = kHttpMethodPost
        request.setValue(kHttpPostContentType, forHTTPHeaderField: kHttpHeaderContentType)

        if let userAgent = endpointReq.userAgentForAuth {
            request.setValue(userAgent, forHTTPHeaderField: kHttpHeaderUserAgent)
        }

        request.httpShouldHandleCookies = false
        return request
    }

    internal func handleTokenEndpointResponse(_ completionBlock: @escaping (SFSDKOAuthTokenEndpointResponse) -> Void, request endpointReq: SFSDKOAuthTokenEndpointRequest, data: Data, urlResponse: URLResponse) {
        let responseData = NSMutableData(capacity: Int(kSFOAuthReponseBufferLength))
        responseData?.append(data)

        guard let responseString = String(data: data, encoding: .utf8) else {
            let error = SFSDKOAuth2.error(withType: kSFOAuthErrorTypeMalformedResponse, description: "failed to parse response")
            let endpointResponse = SFSDKOAuthTokenEndpointResponse(error: error)
            completionBlock(endpointResponse)
            return
        }

        guard let json = SFJsonUtils.object(from: data) as? [String: Any] else {
            let jsonError = SFJsonUtils.lastError
            SFSDKCoreLogger.d(type(of: self), message: "handleTokenEndpointResponse: JSON parse error: \(String(describing: jsonError))")

            let error = SFSDKOAuth2.error(withType: kSFOAuthErrorTypeMalformedResponse, description: "failed to parse response JSON")
            var errorDict = jsonError?.userInfo ?? [:]
            errorDict["response_data"] = responseString
            errorDict[NSUnderlyingErrorKey] = error

            let finalError = NSError(domain: kSFOAuthErrorDomain, code: error.code, userInfo: errorDict)
            let endpointResponse = SFSDKOAuthTokenEndpointResponse(error: finalError)
            completionBlock(endpointResponse)
            return
        }

        var endpointResponse = SFSDKOAuthTokenEndpointResponse(dictionary: json, parseAdditionalFields: endpointReq.additionalOAuthParameterKeys)

        if !endpointResponse.hasError {
            // Adds the refresh token to the response for consistency.
            let jsonRefreshToken = json[kSFOAuthRefreshToken] as? String
            if jsonRefreshToken == nil || jsonRefreshToken?.isEmpty == true {
                if !endpointReq.refreshToken.isEmpty {
                    endpointResponse.refreshToken = endpointReq.refreshToken
                } else {
                    SFSDKCoreLogger.e(type(of: self), message: "handleTokenEndpointResponse: Token endpoint call was made without the existence of a refresh token.")
                }
            }
        }

        completionBlock(endpointResponse)
    }

    // MARK: - Public Utilities

    @objc public static func request(forRevokeRefreshToken credentials: OAuthCredentials, reason: SFLogoutReason) -> NSMutableURLRequest {
        let host = "\(credentials.protocol)://\(credentials.domain)\(kSFRevokePath)"
        guard let url = URL(string: host) else {
            return NSMutableURLRequest()
        }

        let request = NSMutableURLRequest(url: url)
        request.httpMethod = kHttpMethodPost
        request.setValue(kHttpPostContentType, forHTTPHeaderField: kHttpHeaderContentType)
        request.httpShouldHandleCookies = false

        let encodedToken = credentials.refreshToken?.sfsdk_stringByURLEncoding ?? ""
        let params = "token=\(encodedToken)&revoke_reason=\(stringValue(forLogoutReason: reason))"
        let encodedBody = params.data(using: String.Encoding.utf8)
        request.httpBody = encodedBody

        return request
    }

    @objc public static func stringValue(forLogoutReason reason: SFLogoutReason) -> String {
        switch reason {
        case .corruptState:
            return "corrupt_state"
        case .corruptStateAppConfigurationSettings:
            return "corrupt_state_app_configuration_settings"
        case .corruptStateAppProviderErrorInvalidUser:
            return "corrupt_state_app_provider_error_invalid_user"
        case .corruptStateAppInvalidRestClient:
            return "corrupt_state_app_invalid_restclient"
        case .corruptStateAppOther:
            return "corrupt_state_app_other"
        case .corruptStateMSDK:
            return "corrupt_state_msdk"
        case .userInitiated:
            return "user_logout"
        case .unknown:
            return "unknown"
        case .unexpected:
            return "unexpected"
        case .tokenExpired:
            return "refresh_token_expired"
        case .ssdkPolicy:
            return "ssdk_logout_policy"
        case .timeout:
            return "timeout"
        case .unexpectedResponse:
            return "unexpected_response"
        case .refreshTokenRotated:
            return "refresh_token_rotated"
        @unknown default:
            return "unknown"
        }
    }

    @objc public static func parseQueryString(_ query: String) -> [String: String] {
        return parseQueryString(query, decodeParams: true)
    }

    @objc public static func parseQueryString(_ query: String, decodeParams: Bool) -> [String: String] {
        let pairs = query.components(separatedBy: "&")
        var dict: [String: String] = [:]

        for pair in pairs {
            let keyValue = pair.components(separatedBy: "=")
            guard keyValue.count == 2 else { continue }

            var key = keyValue[0]
            var value = keyValue[1]

            if decodeParams {
                key = key.replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? key
                value = value.replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? value
            }

            dict[key] = value
        }

        return dict
    }

    @objc public static func error(withType type: String, description: String) -> NSError {
        return error(withType: type, description: description, underlyingError: nil)
    }

    @objc public static func error(withType type: String, description: String, underlyingError: NSError?) -> NSError {
        var code = SFOAuthError.unknown.rawValue

        if type == kSFOAuthErrorTypeAccessDenied {
            code = SFOAuthError.accessDenied.rawValue
        } else if type == kSFOAuthErrorTypeMalformedResponse {
            code = SFOAuthError.malformed.rawValue
        } else if type == KSFOAuthErrorTypeInvalidClientId {
            code = SFOAuthError.invalidClientId.rawValue
        } else if type == kSFOAuthErrorTypeInvalidClient {
            code = SFOAuthError.invalidClientCredentials.rawValue
        } else if type == kSFOAuthErrorTypeInvalidClientCredentials {
            code = SFOAuthError.invalidClientCredentials.rawValue
        } else if type == kSFOAuthErrorTypeInvalidGrant {
            code = SFOAuthError.invalidGrant.rawValue
        } else if type == kSFOAuthErrorTypeInvalidRequest {
            code = SFOAuthError.invalidRequest.rawValue
        } else if type == kSFOAuthErrorTypeInactiveUser {
            code = SFOAuthError.inactiveUser.rawValue
        } else if type == kSFOAuthErrorTypeInactiveOrg {
            code = SFOAuthError.inactiveOrg.rawValue
        } else if type == kSFOAuthErrorTypeRateLimitExceeded {
            code = SFOAuthError.rateLimitExceeded.rawValue
        } else if type == kSFOAuthErrorTypeUnsupportedResponseType {
            code = SFOAuthError.unsupportedResponseType.rawValue
        } else if type == kSFOAuthErrorTypeTimeout {
            code = SFOAuthError.timeout.rawValue
        } else if type == kSFOAuthErrorTypeWrongVersion {
            code = SFOAuthError.wrongVersion.rawValue
        } else if type == kSFOAuthErrorTypeBrowserLaunchFailed {
            code = SFOAuthError.browserLaunchFailed.rawValue
        } else if type == kSFOAuthErrorTypeUnknownAdvancedAuthConfig {
            code = SFOAuthError.unknownAdvancedAuthConfig.rawValue
        } else if type == kSFOAuthErrorTypeJWTLaunchFailed {
            code = SFOAuthError.jwtInvalidGrant.rawValue
        }

        var userInfoDict: [String: Any] = [
            kSFOAuthError: type,
            NSLocalizedDescriptionKey: description
        ]

        if let underlyingError = underlyingError {
            userInfoDict[NSUnderlyingErrorKey] = underlyingError
        }

        return NSError(domain: kSFOAuthErrorDomain, code: code, userInfo: userInfoDict)
    }

    @objc public static func timestampString(toDate timestamp: String?) -> Date? {
        guard let timestamp = timestamp else { return nil }
        guard let unixTimeInMillis = Int64(timestamp) else { return nil }
        let unixTimeInSecs = TimeInterval(unixTimeInMillis) / 1000.0
        return Date(timeIntervalSince1970: unixTimeInSecs)
    }

    @objc public static func sfErrorCode(from code: Int) -> Int {
        switch code {
        case NSURLErrorTimedOut:
            return SFOAuthError.timeout.rawValue
        case NSURLErrorCancelled:
            return SFOAuthError.requestCancelled.rawValue
        default:
            return SFOAuthError.refreshFailed.rawValue
        }
    }
}
