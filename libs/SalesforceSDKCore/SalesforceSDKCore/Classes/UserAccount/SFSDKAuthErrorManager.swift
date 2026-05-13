/*
 SFSDKAuthErrorManager.swift
 SalesforceSDKCore

 Created by Raj Rao on 10/01/17.

 Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.

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

public typealias SFSDKFailureNotificationBlock = () -> Void
public typealias SFSDKErrorHandlerBlock = (Error, AuthSession, [AnyHashable: Any]) -> Void

// Auth error handler name constants
private let kSFUserAgentErrorHandler = "UserAgentErrorHandler"
private let kSFInvalidCredentialsAuthErrorHandler = "InvalidCredentialsErrorHandler"
private let kSFConnectedAppVersionAuthErrorHandler = "ConnectedAppVersionErrorHandler"
private let kSFNetworkFailureAuthErrorHandler = "NetworkFailureErrorHandler"
private let kSFHostConnectionErrorHandler = "HostConnectionErrorHandler"
private let kSFGenericFailureAuthErrorHandler = "GenericFailureErrorHandler"

@objc(SFSDKAuthErrorManager)
public class SDKAuthErrorManager: NSObject {

    @objc public var networkErrorHandlerBlock: SFSDKErrorHandlerBlock?
    @objc public var connectedAppVersionMismatchErrorHandlerBlock: SFSDKErrorHandlerBlock?
    @objc public var invalidAuthCredentialsErrorHandlerBlock: SFSDKErrorHandlerBlock?
    @objc public var hostConnectionErrorHandlerBlock: SFSDKErrorHandlerBlock?
    @objc public var genericErrorHandlerBlock: SFSDKErrorHandlerBlock?

    private var authErrorHandlerList: AuthErrorHandlerList
    private var invalidCredentialsAuthErrorHandler: AuthErrorHandler?
    private var genericAuthErrorHandler: AuthErrorHandler?
    private var networkFailureAuthErrorHandler: AuthErrorHandler?
    private var connectedAppVersionAuthErrorHandler: AuthErrorHandler?
    private var hostConnectionErrorHandler: AuthErrorHandler?
    private var userAgentErrorHandler: AuthErrorHandler?

    // MARK: - Initialization

    public override init() {
        self.authErrorHandlerList = AuthErrorHandlerList()
        super.init()
        self.authErrorHandlerList = self.populateDefaultAuthErrorHandlerList()
    }

    // MARK: - Public Methods

    @objc(processAuthError:authContext:options:)
    public func processAuthError(_ error: Error, authContext session: AuthSession, options: [AnyHashable: Any]?) -> Bool {
        var i = 0
        var errorHandled = false
        let authHandlerArray = self.authErrorHandlerList.authHandlerArray
        while i < authHandlerArray.count && !errorHandled {
            if let currentHandler = authHandlerArray[i] as? AuthErrorHandler {
                errorHandled = currentHandler.authContextEvalBlock(error, session, options ?? [:])
            }
            i += 1
        }
        return errorHandled
    }

    /**
     Determines whether an error is due to invalid auth credentials.
     - Parameter error: The error to check against an invalid credentials error.
     - Returns: true if the error is due to invalid credentials, false otherwise.
     */
    @objc(errorIsInvalidAuthCredentials:)
    public static func errorIsInvalidAuthCredentials(_ error: Error) -> Bool {
        let nsError = error as NSError
        var errorIsInvalidCreds = false
        if nsError.domain == kSFOAuthErrorDomain {
            if nsError.code == Int(kSFOAuthErrorInvalidGrant) {
                errorIsInvalidCreds = true
            }
        }
        return errorIsInvalidCreds
    }

    // MARK: - Private Methods

    private func populateDefaultAuthErrorHandlerList() -> AuthErrorHandlerList {
        let authHandlerList = AuthErrorHandlerList()

        // User agent disabled handler
        self.userAgentErrorHandler = AuthErrorHandler(name: kSFUserAgentErrorHandler) { [weak self] error, authSession, options in
            guard let self = self else { return false }
            if error.localizedDescription.contains("user-agent flow has been disabled") {
                if let genericErrorHandlerBlock = self.genericErrorHandlerBlock {
                    genericErrorHandlerBlock(error, authSession, options)
                    return true
                }
            }
            return false
        }
        if let userAgentErrorHandler = self.userAgentErrorHandler {
            authHandlerList.addAuthErrorHandler(userAgentErrorHandler)
        }

        // Invalid credentials handler
        self.invalidCredentialsAuthErrorHandler = AuthErrorHandler(name: kSFInvalidCredentialsAuthErrorHandler) { [weak self] error, authSession, options in
            guard let self = self else { return false }
            if SDKAuthErrorManager.errorIsInvalidAuthCredentials(error) {
                if let invalidAuthCredentialsErrorHandlerBlock = self.invalidAuthCredentialsErrorHandlerBlock {
                    invalidAuthCredentialsErrorHandlerBlock(error, authSession, options)
                    return true
                }
            }
            return false
        }
        if let invalidCredentialsAuthErrorHandler = self.invalidCredentialsAuthErrorHandler {
            authHandlerList.addAuthErrorHandler(invalidCredentialsAuthErrorHandler)
        }

        // Connected app version mismatch handler
        self.connectedAppVersionAuthErrorHandler = AuthErrorHandler(name: kSFConnectedAppVersionAuthErrorHandler) { [weak self] error, authSession, options in
            guard let self = self else { return false }
            let nsError = error as NSError
            if nsError.code == Int(kSFOAuthErrorWrongVersion) {
                if let connectedAppVersionMismatchErrorHandlerBlock = self.connectedAppVersionMismatchErrorHandlerBlock {
                    connectedAppVersionMismatchErrorHandlerBlock(error, authSession, options)
                    return true
                }
            }
            return false
        }
        if let connectedAppVersionAuthErrorHandler = self.connectedAppVersionAuthErrorHandler {
            authHandlerList.addAuthErrorHandler(connectedAppVersionAuthErrorHandler)
        }

        // Network failure handler
        self.networkFailureAuthErrorHandler = AuthErrorHandler(name: kSFNetworkFailureAuthErrorHandler) { [weak self] error, authSession, options in
            guard let self = self else { return false }
            var result = false
            if SDKAuthErrorManager.errorIsNetworkFailure(error) {
                guard let coord = authSession.oauthCoordinator else {
                    return false
                }
                let authInfo = coord.authInfo
                if authInfo.authType != .refresh {
                    SFSDKCoreLogger.e(type(of: self), message: "Network failure for non-Refresh OAuth flow (\(authInfo.authTypeDescription)) is a fatal error.")
                } else if authSession.credentials.accessToken == nil {
                    SFSDKCoreLogger.w(type(of: self), message: "Network unreachable for access token refresh, and no access token is configured.  Cannot continue.")
                } else {
                    SFSDKCoreLogger.i(type(of: self), message: "Network failure for OAuth Refresh flow (existing credentials)  Try to continue.")
                    if let networkErrorHandlerBlock = self.networkErrorHandlerBlock {
                        networkErrorHandlerBlock(error, authSession, options)
                        result = true
                    }
                }
            }
            return result
        }
        if let networkFailureAuthErrorHandler = self.networkFailureAuthErrorHandler {
            authHandlerList.addAuthErrorHandler(networkFailureAuthErrorHandler)
        }

        // Host connection error handler
        self.hostConnectionErrorHandler = AuthErrorHandler(name: kSFHostConnectionErrorHandler) { [weak self] error, authSession, options in
            guard let self = self else { return false }
            let nsError = error as NSError
            if (nsError.userInfo["_kCFStreamErrorCodeKey"] != nil && nsError.userInfo["_kCFStreamErrorDomainKey"] != nil) ||
                (nsError.domain == kSFOAuthErrorDomain && nsError.code == Int(kSFOAuthErrorInvalidURL)) {
                if let hostConnectionErrorHandlerBlock = self.hostConnectionErrorHandlerBlock {
                    hostConnectionErrorHandlerBlock(error, authSession, options)
                    return true
                }
            }
            return false
        }
        if let hostConnectionErrorHandler = self.hostConnectionErrorHandler {
            authHandlerList.addAuthErrorHandler(hostConnectionErrorHandler)
        }

        // Generic failure handler
        self.genericAuthErrorHandler = AuthErrorHandler(name: kSFGenericFailureAuthErrorHandler) { [weak self] error, authSession, options in
            guard let self = self else { return false }
            if let genericErrorHandlerBlock = self.genericErrorHandlerBlock {
                genericErrorHandlerBlock(error, authSession, options)
                return true
            }
            return false
        }
        if let genericAuthErrorHandler = self.genericAuthErrorHandler {
            authHandlerList.addAuthErrorHandler(genericAuthErrorHandler)
        }

        return authHandlerList
    }

    /**
     Evaluates an NSError object to see if it represents a network failure during
     an attempted connection.
     - Parameter error: The NSError to evaluate.
     - Returns: true if the error represents a network failure, false otherwise.
     */
    private static func errorIsNetworkFailure(_ error: Error) -> Bool {
        let nsError = error as NSError
        var isNetworkFailure = false

        if nsError.domain.isEmpty {
            return isNetworkFailure
        }

        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorTimedOut,
                 NSURLErrorCannotConnectToHost,
                 NSURLErrorNetworkConnectionLost,
                 NSURLErrorNotConnectedToInternet,
                 NSURLErrorInternationalRoamingOff:
                isNetworkFailure = true
            default:
                break
            }
        } else if nsError.domain == kSFOAuthErrorDomain {
            switch nsError.code {
            case Int(kSFOAuthErrorTimeout):
                isNetworkFailure = true
            default:
                break
            }
        }

        return isNetworkFailure
    }
}
