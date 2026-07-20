// Copyright (c) 2019-present, salesforce.com, inc. All rights reserved.
//
// Redistribution and use of this software in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
// * Redistributions of source code must retain the above copyright notice, this list of conditions
// and the following disclaimer.
// * Redistributions in binary form must reproduce the above copyright notice, this list of
// conditions and the following disclaimer in the documentation and/or other materials provided
// with the distribution.
// * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
// endorse or promote products derived from this software without specific prior written
// permission of salesforce.com, inc.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
// IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
// FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
// CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
// WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
// WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import Foundation
import UIKit
import SalesforceSDKCommon

/// SFOAuth default network timeout in seconds.
public let kSFOAuthDefaultTimeout: TimeInterval = 120.0

/// This constant defines the SFOAuth framework error domain.
public let kSFOAuthErrorDomain: String = "com.salesforce.OAuth.ErrorDomain"

// MARK: - Error Codes (preserving the ObjC enum values)
public let kSFOAuthErrorUnknown: Int                      = 666
public let kSFOAuthErrorTimeout: Int                      = 667
public let kSFOAuthErrorMalformed: Int                    = 668
public let kSFOAuthErrorAccessDenied: Int                 = 669
public let kSFOAuthErrorInvalidClientId: Int              = 670
public let kSFOAuthErrorInvalidClientCredentials: Int     = 671
public let kSFOAuthErrorInvalidGrant: Int                 = 672
public let kSFOAuthErrorInvalidRequest: Int               = 673
public let kSFOAuthErrorInactiveUser: Int                 = 674
public let kSFOAuthErrorInactiveOrg: Int                  = 675
public let kSFOAuthErrorRateLimitExceeded: Int            = 676
public let kSFOAuthErrorUnsupportedResponseType: Int      = 677
public let kSFOAuthErrorWrongVersion: Int                 = 678
public let kSFOAuthErrorBrowserLaunchFailed: Int          = 679
public let kSFOAuthErrorUnknownAdvancedAuthConfig: Int    = 680
public let kSFOAuthErrorInvalidMDMConfiguration: Int      = 681
public let kSFOAuthErrorJWTInvalidGrant: Int              = 682
public let kSFOAuthErrorRequestCancelled: Int             = 683
public let kSFOAuthErrorRefreshFailed: Int                = 684
public let kSFOAuthErrorInvalidURL: Int                   = 685

// MARK: - OAuth String Constants (from SFSDKOAuthConstants.h)
let kSFOAuthEndPointAuthorize               = "/services/oauth2/authorize"
let kSFOAuthEndPointToken                   = "/services/oauth2/token"
let kSFRevokePath                           = "/services/oauth2/revoke"
let kSFOAuthCodeVerifierParamName           = "code_verifier"
let kSFOAuthCodeVerifierByteLength: UInt    = 128
let kSFOAuthCodeChallengeParamName          = "code_challenge"
let kSFOAuthDisplay                         = "display"
let kSFOAuthDisplayTouch                    = "touch"
let kSFOAuthResponseType                    = "response_type"
let kSFOAuthResponseTypeCode                = "code"
let kSFOAuthResponseTypeToken               = "token"
let kSFOAuthResponseTypeHybridToken         = "hybrid_token"
let kSFOAuthAccessToken                     = "access_token"
let kSFOAuthClientId                        = "client_id"
let kSFOAuthDeviceId                        = "device_id"
let kSFOAuthError                           = "error"
let kSFOAuthErrorDescription                = "error_description"
let kSFOAuthFormat                          = "format"
let kSFOAuthGrantType                       = "grant_type"
let kSFOAuthGrantTypeHybridRefresh          = "hybrid_refresh"
let kSFOAuthGrantTypeRefresh                = "refresh_token"
let kSFOAuthGrantTypeHybridAuthorizationCode = "hybrid_auth_code"
let kSFOAuthGrantTypeAuthorizationCode      = "authorization_code"
let kSFOAuthId                              = "id"
let kSFOAuthInstanceUrl                     = "instance_url"
let kSFOAuthApiInstanceUrl                  = "api_instance_url"
let kSFOAuthCommunityId                     = "sfdc_community_id"
let kSFOAuthCommunityUrl                    = "sfdc_community_url"
let kSFOAuthIdToken                         = "id_token"
let kSFOAuthIssuedAt                        = "issued_at"
let kSFOAuthRedirectUri                     = "redirect_uri"
let kSFOAuthRefreshToken                    = "refresh_token"
let kSFOAuthScope                           = "scope"
let kSFOAuthSignature                       = "signature"
let kSFOAuthLightningDomain                 = "lightning_domain"
let kSFOAuthLightningSID                    = "lightning_sid"
let kSFOAuthVFDomain                        = "visualforce_domain"
let kSFOAuthVFSID                           = "visualforce_sid"
let kSFOAuthContentDomain                   = "content_domain"
let kSFOAuthContentSID                      = "content_sid"
let kSFOAuthCSRFToken                       = "csrf_token"
let kSFOAuthCookieClientSrc                 = "cookie-clientSrc"
let kSFOAuthCookieSidClient                 = "cookie-sid_Client"
let kSFOAuthSidCookieName                   = "sidCookieName"
let kSFOAuthParentSid                       = "parent_sid"
let kSFOAuthTokenFormat                     = "token_format"
let kSFOAuthBeaconChildConsumerKey          = "auto_installed_app_org_consumer_key"
let kSFOAuthBeaconChildConsumerSecret       = "auto_installed_app_org_consumer_secret"
let kSFOAuthApprovalCode                    = "code"

// OAuth Error Type Strings
let kSFOAuthErrorTypeMalformedResponse          = "malformed_response"
let kSFOAuthErrorTypeAccessDenied               = "access_denied"
private let KSFOAuthErrorTypeInvalidClientId            = "invalid_client_id"
let kSFOAuthErrorTypeInvalidClient              = "invalid_client"
let kSFOAuthErrorTypeInvalidClientCredentials   = "invalid_client_credentials"
let kSFOAuthErrorTypeInvalidGrant               = "invalid_grant"
let kSFOAuthErrorTypeInvalidRequest             = "invalid_request"
let kSFOAuthErrorTypeInactiveUser               = "inactive_user"
let kSFOAuthErrorTypeInactiveOrg                = "inactive_org"
let kSFOAuthErrorTypeRateLimitExceeded          = "rate_limit_exceeded"
let kSFOAuthErrorTypeUnsupportedResponseType    = "unsupported_response_type"
let kSFOAuthErrorTypeTimeout                    = "auth_timeout"
let kSFOAuthErrorTypeWrongVersion               = "wrong_version"
let kSFOAuthErrorTypeBrowserLaunchFailed        = "browser_launch_failed"
let kSFOAuthErrorTypeUnknownAdvancedAuthConfig  = "unknown_advanced_auth_config"
let kSFOAuthErrorTypeJWTLaunchFailed            = "jwt_launch_failed"

// HTTP constants
let kHttpMethodPost                             = "POST"
let kHttpHeaderContentType                      = "Content-Type"
let kHttpPostContentType                        = "application/x-www-form-urlencoded"
let kHttpPostApplicationJsonContentType         = "application/json"

// Native Login / Headless Auth constants
let kSFOAuthRequestTypeParamName                = "Auth-Request-Type"
let kSFOAuthRequestTypeNamedUser                = "Named-User"
let kSFOAuthRequestTypePasswordlessLogin        = "passwordless-login"
let kSFOAuthRequestTypeUserRegistration         = "user-registration"
let kSFOAuthAuthorizationTypeParamName          = "Authorization"
let kSFOAuthAuthorizationTypeBasic              = "Basic"
let kSFOAuthEndPointHeadlessInitPasswordlessLogin = "services/auth/headless/init/passwordless/login"
let kSFOAuthEndPointHeadlessInitRegistration    = "services/auth/headless/init/registration"
let kSFOAuthEndPointHeadlessForgotPassword      = "services/auth/headless/forgot_password"
let kSFOAuthAuthVerificationTypeParamName       = "Auth-Verification-Type"
let kSFOAuthAuthVerificationTypeEmail           = "email"
let kSFOAuthAuthVerificationTypeSms             = "sms"
let kSFOAuthCodeCredentialsParamName            = "code_credentials"
let kSFOAuthReponseBufferLength: Int            = 512

// SFLogoutReason enum is defined in ObjC (SFSDKOAuth2.h) and bridged to Swift automatically.

// MARK: - SFSDKOAuthTokenEndpointErrorResponse

@objc(SFSDKOAuthTokenEndpointErrorResponse)
@objcMembers public class SFSDKOAuthTokenEndpointErrorResponse: NSObject {
    @objc public private(set) var tokenEndpointErrorCode: String?
    @objc public private(set) var tokenEndpointErrorDescription: String?
    @objc public private(set) var error: NSError?

    init(errorType: String, description: String) {
        self.tokenEndpointErrorCode = errorType
        self.tokenEndpointErrorDescription = description
        self.error = SFSDKOAuth2.error(withType: errorType, description: description) as NSError
        super.init()
    }

    init(error: NSError) {
        self.error = error
        super.init()
    }
}

// MARK: - SFSDKOAuthTokenEndpointRequest

@objc(SFSDKOAuthTokenEndpointRequest)
@objcMembers public class SFSDKOAuthTokenEndpointRequest: NSObject {
    @objc public var refreshToken: String = ""
    @objc public var redirectURI: String = ""
    @objc public var clientID: String = ""
    @objc public var approvalCode: String?
    @objc public var codeVerifier: String?
    @objc public var timeout: TimeInterval = kSFOAuthDefaultTimeout
    @objc public var serverURL: URL = URL(string: "https://login.salesforce.com")!  // swiftlint:disable:this force_unwrapping
    @objc public var additionalTokenRefreshParams: NSDictionary?
    @objc public var additionalOAuthParameterKeys: [String]?
}

// MARK: - SFSDKOAuthTokenEndpointResponse

@objc(SFSDKOAuthTokenEndpointResponse)
@objcMembers public class SFSDKOAuthTokenEndpointResponse: NSObject {
    private var values: NSMutableDictionary = NSMutableDictionary()
    private var _additionalOAuthParameterKeys: [String]?

    @objc public private(set) var error: SFSDKOAuthTokenEndpointErrorResponse?
    @objc public private(set) var additionalOAuthFields: NSDictionary?
    @objc public private(set) var scopes: [String]?

    @objc public var hasError: Bool {
        return error != nil
    }

    @objc public var accessToken: String? {
        return values[kSFOAuthAccessToken] as? String
    }

    @objc public var idToken: String? {
        return values[kSFOAuthIdToken] as? String
    }

    @objc public var refreshToken: String? {
        get { return values[kSFOAuthRefreshToken] as? String }
        set { if let val = newValue { values[kSFOAuthRefreshToken] = val } }
    }

    @objc public var issuedAt: Date? {
        guard let timestamp = values[kSFOAuthIssuedAt] as? String else { return nil }
        return SFSDKOAuth2.timestampStringToDate(timestamp)
    }

    @objc public var instanceUrl: URL? {
        guard let str = values[kSFOAuthInstanceUrl] as? String else { return nil }
        return URL(string: str)
    }

    @objc public var apiInstanceUrl: URL? {
        guard let str = values[kSFOAuthApiInstanceUrl] as? String else { return nil }
        return URL(string: str)
    }

    @objc public var identityUrl: URL? {
        guard let str = values[kSFOAuthId] as? String else { return nil }
        return URL(string: str)
    }

    @objc public var communityId: String? {
        return values[kSFOAuthCommunityId] as? String
    }

    @objc public var communityUrl: URL? {
        guard let str = values[kSFOAuthCommunityUrl] as? String else { return nil }
        return URL(string: str)
    }

    @objc public var apiUrl: URL? { return nil }

    @objc public var signature: String? {
        return values[kSFOAuthSignature] as? String
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

    @objc public func asDictionary() -> NSDictionary {
        return values.copy() as? NSDictionary ?? NSDictionary()
    }

    // Internal initializers
    init(withError error: NSError) {
        self.error = SFSDKOAuthTokenEndpointErrorResponse(error: error)
        super.init()
    }

    init(dictionary nvPairs: NSDictionary, parseAdditionalFields additionalOAuthParameterKeys: [String]?) {
        super.init()
        values = NSMutableDictionary(dictionary: nvPairs)
        _additionalOAuthParameterKeys = additionalOAuthParameterKeys

        if let keys = additionalOAuthParameterKeys {
            var parsedValues: [String: Any] = [:]
            for key in keys {
                if let obj = nvPairs[key] {
                    parsedValues[key] = obj
                }
            }
            additionalOAuthFields = parsedValues as NSDictionary
        }

        if let rawScope = nvPairs[kSFOAuthScope] as? String {
            scopes = rawScope.components(separatedBy: " ")
        }

        if let errorType = nvPairs[kSFOAuthError] as? String {
            let errorDesc = nvPairs[kSFOAuthErrorDescription] as? String ?? ""
            error = SFSDKOAuthTokenEndpointErrorResponse(errorType: errorType, description: errorDesc)
        }
    }
}

// MARK: - SFSDKOAuthProtocol

@objc(SFSDKOAuthProtocol)
public protocol SFSDKOAuthProtocol: NSObjectProtocol {
    func accessToken(forApprovalCode endpointReq: SFSDKOAuthTokenEndpointRequest, completion completionBlock: @escaping (SFSDKOAuthTokenEndpointResponse?) -> Void)
    func accessToken(forRefresh endpointReq: SFSDKOAuthTokenEndpointRequest, completion completionBlock: @escaping (SFSDKOAuthTokenEndpointResponse?) -> Void)
    func openIDToken(forRefresh endpointReq: SFSDKOAuthTokenEndpointRequest, completion completionBlock: @escaping (String?) -> Void)
    func revokeRefreshToken(_ credentials: OAuthCredentials, reason: SFLogoutReason)
}

// MARK: - SFSDKOAuth2

@objc(SFSDKOAuth2)
@objcMembers public class SFSDKOAuth2: NSObject, SFSDKOAuthProtocol {

    // MARK: - Protocol Methods

    @objc public func accessToken(forApprovalCode endpointReq: SFSDKOAuthTokenEndpointRequest, completion completionBlock: @escaping (SFSDKOAuthTokenEndpointResponse?) -> Void) {
        let request = prepareBasicRequest(endpointReq)
        var params = "\(kSFOAuthFormat)=json&\(kSFOAuthRedirectUri)=\(endpointReq.redirectURI)&\(kSFOAuthClientId)=\(endpointReq.clientID)&\(kSFOAuthDeviceId)=\(UIDevice.current.identifierForVendor?.uuidString ?? "")"
        if let codeVerifier = endpointReq.codeVerifier {
            params += "&\(kSFOAuthCodeVerifierParamName)=\(codeVerifier)"
        }
        let grantType = SalesforceSDKManager.shared.useHybridAuthentication ? kSFOAuthGrantTypeHybridAuthorizationCode : kSFOAuthGrantTypeAuthorizationCode
        params += "&\(kSFOAuthGrantType)=\(grantType)&\(kSFOAuthApprovalCode)=\(endpointReq.approvalCode ?? "")"
        request.httpBody = params.data(using: .utf8)

        let networkIdentifier = Network.uniqueInstanceIdentifier()
        let network = Network.sharedEphemeralInstance(withIdentifier: networkIdentifier)

        network.sendRequest(request as URLRequest) { [weak self] data, urlResponse, error in
            Network.removeSharedInstance(forIdentifier: networkIdentifier)
            guard let strongSelf = self else { return }

            if let error = error {
                let requestUrl = request.url
                let errorUrlString = "\(requestUrl?.scheme ?? "")://\(requestUrl?.host ?? "")\(requestUrl?.relativePath ?? "")"
                var endpointResponse: SFSDKOAuthTokenEndpointResponse
                if (error as NSError).code == NSURLErrorTimedOut {
                    SFSDKCoreLogger.d(SFSDKOAuth2.self, message: "Attempt to get access token for approval code timed out after \(endpointReq.timeout) seconds.")
                    endpointResponse = SFSDKOAuthTokenEndpointResponse(withError: NSError(domain: kSFOAuthErrorDomain, code: kSFOAuthErrorTimeout, userInfo: nil))
                } else {
                    endpointResponse = SFSDKOAuthTokenEndpointResponse(withError: error as NSError)
                }
                SFSDKCoreLogger.d(SFSDKOAuth2.self, message: "SFOAuth2 session failed with error: error code: \((error as NSError).code), description: \(error.localizedDescription), URL: \(errorUrlString)")
                DispatchQueue.main.async {
                    completionBlock(endpointResponse)
                }
                return
            }

            strongSelf.handleTokenEndpointResponse(completionBlock, request: endpointReq, data: data, urlResponse: urlResponse)
        }
    }

    @objc public func accessToken(forRefresh endpointReq: SFSDKOAuthTokenEndpointRequest, completion completionBlock: @escaping (SFSDKOAuthTokenEndpointResponse?) -> Void) {
        let request = prepareBasicRequest(endpointReq)
        var params = "\(kSFOAuthFormat)=json&\(kSFOAuthRedirectUri)=\(endpointReq.redirectURI)&\(kSFOAuthClientId)=\(endpointReq.clientID)&\(kSFOAuthDeviceId)=\(UIDevice.current.identifierForVendor?.uuidString ?? "")"

        let targetHost = endpointReq.serverURL.host ?? "<unknown>"
        SFSDKCoreLogger.i(SFSDKOAuth2.self, message: "\(#function): Initiating refresh token flow to host: \(targetHost)")
        let grantType = SalesforceSDKManager.shared.useHybridAuthentication ? kSFOAuthGrantTypeHybridRefresh : kSFOAuthGrantTypeRefresh
        params += "&\(kSFOAuthGrantType)=\(grantType)&\(kSFOAuthRefreshToken)=\(endpointReq.refreshToken)"

        if let additionalParams = endpointReq.additionalTokenRefreshParams as? [String: String] {
            for (key, value) in additionalParams {
                params += "&\(key.sfsdk_stringByURLEncoding())=\(value.sfsdk_stringByURLEncoding())"
            }
        }
        request.httpBody = params.data(using: .utf8)

        let instanceIdentifier = Network.uniqueInstanceIdentifier()
        let network = Network.sharedEphemeralInstance(withIdentifier: instanceIdentifier)
        let className = NSStringFromClass(SFSDKOAuth2.self)

        network.sendRequest(request as URLRequest) { [weak self] data, urlResponse, error in
            Network.removeSharedInstance(forIdentifier: instanceIdentifier)

            if let error = error {
                let requestUrl = request.url
                let errorUrlString = "\(requestUrl?.scheme ?? "")://\(requestUrl?.host ?? "")\(requestUrl?.relativePath ?? "")"
                let code = SFSDKOAuth2.sfErrorCode(fromError: (error as NSError).code)
                let endpointResponse = SFSDKOAuthTokenEndpointResponse(withError: NSError(domain: kSFOAuthErrorDomain, code: code, userInfo: nil))

                if (error as NSError).code == NSURLErrorTimedOut {
                    SFSDKCoreLogger.d(SFSDKOAuth2.self, message: "Refresh attempt timed out after \(endpointReq.timeout) seconds.")
                }

                SFSDKCoreLogger.d(SFSDKOAuth2.self, message: "SFOAuth2 session failed with error: error code: \((error as NSError).code), description: \(error.localizedDescription), URL: \(errorUrlString)")
                DispatchQueue.main.async {
                    completionBlock(endpointResponse)
                }
                return
            }

            SFSDKEventBuilderHelper.createAndStoreEvent("tokenRefresh", userAccount: UserAccountManager.shared.currentUserAccount, className: className, attributes: nil)

            if let strongSelf = self {
                strongSelf.handleTokenEndpointResponse(completionBlock, request: endpointReq, data: data, urlResponse: urlResponse)
            } else {
                SFSDKCoreLogger.d(SFSDKOAuth2.self, message: "Token endpoint response handler skipped because self was deallocated.")
                DispatchQueue.main.async {
                    completionBlock(nil)
                }
            }
        }
    }

    @objc public func openIDToken(forRefresh endpointReq: SFSDKOAuthTokenEndpointRequest, completion completionBlock: @escaping (String?) -> Void) {
        accessToken(forRefresh: endpointReq) { response in
            completionBlock(response?.idToken)
        }
    }

    @objc public func revokeRefreshToken(_ credentials: OAuthCredentials, reason: SFLogoutReason) {
        if credentials.refreshToken != nil {
            let request = SFSDKOAuth2.requestForRevokeRefreshToken(credentials, reason: reason)
            let networkIdentifier = Network.uniqueInstanceIdentifier()
            let network = Network.sharedEphemeralInstance(withIdentifier: networkIdentifier)
            network.sendRequest(request as URLRequest) { _, _, _ in
                Network.removeSharedInstance(forIdentifier: networkIdentifier)
            }
        }
        credentials.revoke()
    }

    // MARK: - Class Methods

    @objc public class func requestForRevokeRefreshToken(_ credentials: OAuthCredentials, reason: SFLogoutReason) -> NSMutableURLRequest {
        let host = "\(credentials.protocol ?? "https")://\(credentials.domain ?? "")\(kSFRevokePath)"
        let url = URL(string: host) ?? URL(string: "https://login.salesforce.com")!  // swiftlint:disable:this force_unwrapping
        let request = NSMutableURLRequest(url: url)
        request.httpMethod = kHttpMethodPost
        request.setValue(kHttpPostContentType, forHTTPHeaderField: kHttpHeaderContentType)
        request.httpShouldHandleCookies = false

        let refreshTokenEncoded = credentials.refreshToken?.sfsdk_stringByURLEncoding() ?? ""
        let reasonString = stringValue(forLogoutReason: reason)
        let params = "token=\(refreshTokenEncoded)&revoke_reason=\(reasonString)"
        request.httpBody = params.data(using: .utf8)

        return request
    }

    // MARK: - Utilities

    @objc public class func parseQueryString(_ query: String) -> NSDictionary {
        return parseQueryString(query, decodeParams: true)
    }

    @objc public class func parseQueryString(_ query: String, decodeParams: Bool) -> NSDictionary {
        let pairs = query.components(separatedBy: "&")
        let dict = NSMutableDictionary(capacity: pairs.count)
        for pair in pairs {
            let keyValue = pair.components(separatedBy: "=")
            guard keyValue.count >= 2 else { continue }
            var key = keyValue[0]
            var value = keyValue[1]
            if decodeParams {
                key = key.replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? key
                value = value.replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? value
            }
            dict[key] = value
        }
        return NSDictionary(dictionary: dict)
    }

    @objc public class func error(withType type: String, description: String) -> NSError {
        return error(withType: type, description: description, underlyingError: nil)
    }

    @objc public class func error(withType type: String, description: String, underlyingError: NSError?) -> NSError {
        assert(!type.isEmpty, "error type can't be nil")
        var code = kSFOAuthErrorUnknown
        if type == kSFOAuthErrorTypeAccessDenied {
            code = kSFOAuthErrorAccessDenied
        } else if type == kSFOAuthErrorTypeMalformedResponse {
            code = kSFOAuthErrorMalformed
        } else if type == KSFOAuthErrorTypeInvalidClientId {
            code = kSFOAuthErrorInvalidClientId
        } else if type == kSFOAuthErrorTypeInvalidClient {
            code = kSFOAuthErrorInvalidClientCredentials
        } else if type == kSFOAuthErrorTypeInvalidClientCredentials {
            code = kSFOAuthErrorInvalidClientCredentials
        } else if type == kSFOAuthErrorTypeInvalidGrant {
            code = kSFOAuthErrorInvalidGrant
        } else if type == kSFOAuthErrorTypeInvalidRequest {
            code = kSFOAuthErrorInvalidRequest
        } else if type == kSFOAuthErrorTypeInactiveUser {
            code = kSFOAuthErrorInactiveUser
        } else if type == kSFOAuthErrorTypeInactiveOrg {
            code = kSFOAuthErrorInactiveOrg
        } else if type == kSFOAuthErrorTypeRateLimitExceeded {
            code = kSFOAuthErrorRateLimitExceeded
        } else if type == kSFOAuthErrorTypeUnsupportedResponseType {
            code = kSFOAuthErrorUnsupportedResponseType
        } else if type == kSFOAuthErrorTypeTimeout {
            code = kSFOAuthErrorTimeout
        } else if type == kSFOAuthErrorTypeWrongVersion {
            code = kSFOAuthErrorWrongVersion
        } else if type == kSFOAuthErrorTypeBrowserLaunchFailed {
            code = kSFOAuthErrorBrowserLaunchFailed
        } else if type == kSFOAuthErrorTypeUnknownAdvancedAuthConfig {
            code = kSFOAuthErrorUnknownAdvancedAuthConfig
        } else if type == kSFOAuthErrorTypeJWTLaunchFailed {
            code = kSFOAuthErrorJWTInvalidGrant
        }

        var userInfoDict: [String: Any] = [kSFOAuthError: type, NSLocalizedDescriptionKey: description]
        if let underlyingError = underlyingError {
            userInfoDict[NSUnderlyingErrorKey] = underlyingError
        }
        return NSError(domain: kSFOAuthErrorDomain, code: code, userInfo: userInfoDict)
    }

    @objc public class func timestampStringToDate(_ timestamp: String?) -> Date? {
        guard let timestamp = timestamp else { return nil }
        let unixTimeInSecs = (Double(timestamp) ?? 0) / 1000.0
        return Date(timeIntervalSince1970: unixTimeInSecs)
    }

    @objc public class func sfErrorCode(fromError code: Int) -> Int {
        switch code {
        case NSURLErrorTimedOut:
            return kSFOAuthErrorTimeout
        case NSURLErrorCancelled:
            return kSFOAuthErrorRequestCancelled
        default:
            return kSFOAuthErrorRefreshFailed
        }
    }

    @objc public class func stringValue(forLogoutReason reason: SFLogoutReason) -> String {
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

    // MARK: - Private Methods

    // Exposed to tests (mirrors upstream's SFSDKOAuth2+Internal.h declaration of -prepareBasicRequest:).
    func prepareBasicRequest(_ endpointReq: SFSDKOAuthTokenEndpointRequest) -> NSMutableURLRequest {
        let protocolHost = endpointReq.serverURL.absoluteString
        var urlString = "\(protocolHost)\(kSFOAuthEndPointToken)"
        if !urlString.hasPrefix("http") {
            urlString = "https://\(urlString)"
        }
        let url = URL(string: urlString) ?? endpointReq.serverURL
        let request = NSMutableURLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: endpointReq.timeout)
        request.httpMethod = kHttpMethodPost
        request.setValue(kHttpPostContentType, forHTTPHeaderField: kHttpHeaderContentType)
        request.httpShouldHandleCookies = false
        return request
    }

    @objc func handleTokenEndpointResponse(_ completionBlock: @escaping (SFSDKOAuthTokenEndpointResponse?) -> Void, request endpointReq: SFSDKOAuthTokenEndpointRequest, data: Data?, urlResponse: URLResponse?) {
        guard let data = data else {
            let error = SFSDKOAuth2.error(withType: kSFOAuthErrorTypeMalformedResponse, description: "No data in token endpoint response")
            let endpointResponse = SFSDKOAuthTokenEndpointResponse(withError: error)
            completionBlock(endpointResponse)
            return
        }

        if let json = SFJsonUtils.object(fromJSONData: data) as? NSDictionary {
            let endpointResponse = SFSDKOAuthTokenEndpointResponse(dictionary: json, parseAdditionalFields: endpointReq.additionalOAuthParameterKeys)
            if !endpointResponse.hasError {
                let jsonRefreshToken = json[kSFOAuthRefreshToken] as? String
                if jsonRefreshToken == nil || jsonRefreshToken?.isEmpty == true {
                    if !endpointReq.refreshToken.isEmpty {
                        endpointResponse.refreshToken = endpointReq.refreshToken
                    } else {
                        SFSDKCoreLogger.e(SFSDKOAuth2.self, message: "\(#function): Token endpoint call was made without the existence of a refresh token.")
                    }
                }
            }
            completionBlock(endpointResponse)
        } else {
            let jsonError = SFJsonUtils.lastError()
            SFSDKCoreLogger.d(SFSDKOAuth2.self, message: "\(#function): JSON parse error: \(String(describing: jsonError))")
            let error = SFSDKOAuth2.error(withType: kSFOAuthErrorTypeMalformedResponse, description: "failed to parse response JSON")
            var errorDict: [String: Any] = jsonError?.userInfo as? [String: Any] ?? [:]
            if let responseString = String(data: data, encoding: .utf8) {
                errorDict["response_data"] = responseString
            }
            errorDict[NSUnderlyingErrorKey] = error
            let finalError = NSError(domain: kSFOAuthErrorDomain, code: error.code, userInfo: errorDict)
            let endpointResponse = SFSDKOAuthTokenEndpointResponse(withError: finalError)
            completionBlock(endpointResponse)
        }
    }
}
