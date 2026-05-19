// SFSDKAuthErrorManager.swift
// SalesforceSDKCore
//
// Created by Raj Rao on 10/01/17.
//
// Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.
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

/// Block type for failure notification.
public typealias SFSDKFailureNotificationBlock = () -> Void

/// Block type for error handling.
public typealias SFSDKErrorHandlerBlock = (Error, SFSDKAuthSession, NSDictionary) -> Void

// Auth error handler name constants
private let kSFUserAgentErrorHandler = "UserAgentErrorHandler"
private let kSFInvalidCredentialsAuthErrorHandler = "InvalidCredentialsErrorHandler"
private let kSFConnectedAppVersionAuthErrorHandler = "ConnectedAppVersionErrorHandler"
private let kSFNetworkFailureAuthErrorHandler = "NetworkFailureErrorHandler"
private let kSFHostConnectionErrorHandler = "HostConnectionErrorHandler"
private let kSFGenericFailureAuthErrorHandler = "GenericFailureErrorHandler"

/// Manages authentication error handling using a chain of error handlers.
@objc(SFSDKAuthErrorManager)
@objcMembers public class SFSDKAuthErrorManager: NSObject {

    // MARK: - Public handler blocks

    @objc public var networkErrorHandlerBlock: SFSDKErrorHandlerBlock?
    @objc public var connectedAppVersionMismatchErrorHandlerBlock: SFSDKErrorHandlerBlock?
    @objc public var invalidAuthCredentialsErrorHandlerBlock: SFSDKErrorHandlerBlock?
    @objc public var hostConnectionErrorHandlerBlock: SFSDKErrorHandlerBlock?
    @objc public var genericErrorHandlerBlock: SFSDKErrorHandlerBlock?

    // MARK: - Private properties

    private var authErrorHandlerList: SFAuthErrorHandlerList
    private var invalidCredentialsAuthErrorHandler: SFAuthErrorHandler?
    private var genericAuthErrorHandler: SFAuthErrorHandler?
    private var networkFailureAuthErrorHandler: SFAuthErrorHandler?
    private var connectedAppVersionAuthErrorHandler: SFAuthErrorHandler?
    private var hostConnectionErrorHandler: SFAuthErrorHandler?
    private var userAgentErrorHandler: SFAuthErrorHandler?

    // MARK: - Initialization

    public override init() {
        authErrorHandlerList = SFAuthErrorHandlerList()
        super.init()
        authErrorHandlerList = populateDefaultAuthErrorHandlerList()
    }

    // MARK: - Public Methods

    /// Process an authentication error through the handler chain.
    @objc public func processAuthError(_ error: Error, authContext session: SFSDKAuthSession, options: NSDictionary?) -> Bool {
        var i = 0
        var errorHandled = false
        let authHandlerArray = authErrorHandlerList.authHandlerArray
        while i < authHandlerArray.count && !errorHandled {
            let currentHandler = authHandlerArray[i]
            errorHandled = currentHandler.authContextEvalBlock(error, session, options ?? NSDictionary())
            i += 1
        }
        return errorHandled
    }

    /// Determines whether an error is due to invalid auth credentials.
    @objc public class func errorIsInvalidAuthCredentials(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == kSFOAuthErrorDomain {
            if nsError.code == Int(kSFOAuthErrorInvalidGrant) {
                return true
            }
        }
        return false
    }

    // MARK: - Private

    private class func errorIsNetworkFailure(_ error: Error) -> Bool {
        let nsError = error as NSError
        guard let domain = nsError.domain as String? else { return false }

        if domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorTimedOut,
                 NSURLErrorCannotConnectToHost,
                 NSURLErrorNetworkConnectionLost,
                 NSURLErrorNotConnectedToInternet,
                 NSURLErrorInternationalRoamingOff:
                return true
            default:
                return false
            }
        } else if domain == kSFOAuthErrorDomain {
            if nsError.code == Int(kSFOAuthErrorTimeout) {
                return true
            }
        }
        return false
    }

    private func populateDefaultAuthErrorHandlerList() -> SFAuthErrorHandlerList {
        let authHandlerList = SFAuthErrorHandlerList()

        // User agent disabled handler
        let uaHandler = SFAuthErrorHandler(name: kSFUserAgentErrorHandler) { [weak self] error, authSession, options in
            if error.localizedDescription.contains("user-agent flow has been disabled") {
                if let block = self?.genericErrorHandlerBlock {
                    block(error, authSession, options)
                    return true
                }
            }
            return false
        }
        self.userAgentErrorHandler = uaHandler
        authHandlerList.addAuthErrorHandler(uaHandler)

        // Invalid credentials handler
        let invalidCredsHandler = SFAuthErrorHandler(name: kSFInvalidCredentialsAuthErrorHandler) { [weak self] error, authSession, options in
            if SFSDKAuthErrorManager.errorIsInvalidAuthCredentials(error) {
                if let block = self?.invalidAuthCredentialsErrorHandlerBlock {
                    block(error, authSession, options)
                    return true
                }
            }
            return false
        }
        self.invalidCredentialsAuthErrorHandler = invalidCredsHandler
        authHandlerList.addAuthErrorHandler(invalidCredsHandler)

        // Connected app version mismatch handler
        let connectedAppHandler = SFAuthErrorHandler(name: kSFConnectedAppVersionAuthErrorHandler) { [weak self] error, authSession, options in
            let nsError = error as NSError
            if nsError.code == Int(kSFOAuthErrorWrongVersion) {
                if let block = self?.connectedAppVersionMismatchErrorHandlerBlock {
                    block(error, authSession, options)
                    return true
                }
            }
            return false
        }
        self.connectedAppVersionAuthErrorHandler = connectedAppHandler
        authHandlerList.addAuthErrorHandler(connectedAppHandler)

        // Network failure handler
        let networkHandler = SFAuthErrorHandler(name: kSFNetworkFailureAuthErrorHandler) { [weak self] error, authSession, options in
            guard SFSDKAuthErrorManager.errorIsNetworkFailure(error) else { return false }

            let coord = authSession.oauthCoordinator
            let authInfo = coord.authInfo

            if authInfo.authType != .refresh {
                SFSDKCoreLogger.e(SFSDKAuthErrorManager.self, format: "Network failure for non-Refresh OAuth flow (%@) is a fatal error.", authInfo.authTypeDescription)
            } else if authSession.credentials.accessToken == nil {
                SFSDKCoreLogger.w(SFSDKAuthErrorManager.self, format: "Network unreachable for access token refresh, and no access token is configured. Cannot continue.")
            } else {
                SFSDKCoreLogger.i(SFSDKAuthErrorManager.self, format: "Network failure for OAuth Refresh flow (existing credentials) Try to continue.")
                if let block = self?.networkErrorHandlerBlock {
                    block(error, authSession, options)
                    return true
                }
            }
            return false
        }
        self.networkFailureAuthErrorHandler = networkHandler
        authHandlerList.addAuthErrorHandler(networkHandler)

        // Host connection error handler
        let hostHandler = SFAuthErrorHandler(name: kSFHostConnectionErrorHandler) { [weak self] error, authSession, options in
            let nsError = error as NSError
            if (nsError.userInfo["_kCFStreamErrorCodeKey"] != nil && nsError.userInfo["_kCFStreamErrorDomainKey"] != nil) ||
                (nsError.domain == kSFOAuthErrorDomain && nsError.code == Int(kSFOAuthErrorInvalidURL)) {
                if let block = self?.hostConnectionErrorHandlerBlock {
                    block(error, authSession, options)
                    return true
                }
            }
            return false
        }
        self.hostConnectionErrorHandler = hostHandler
        authHandlerList.addAuthErrorHandler(hostHandler)

        // Generic failure handler
        let genericHandler = SFAuthErrorHandler(name: kSFGenericFailureAuthErrorHandler) { [weak self] error, authSession, options in
            if let block = self?.genericErrorHandlerBlock {
                block(error, authSession, options)
                return true
            }
            return false
        }
        self.genericAuthErrorHandler = genericHandler
        authHandlerList.addAuthErrorHandler(genericHandler)

        return authHandlerList
    }
}
