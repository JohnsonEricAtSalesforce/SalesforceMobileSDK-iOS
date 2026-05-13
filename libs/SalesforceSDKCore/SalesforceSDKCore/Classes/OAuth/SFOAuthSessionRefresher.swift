/*
 Copyright (c) 2015-present, salesforce.com, inc. All rights reserved.

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
import AuthenticationServices
import WebKit

/**
 * Error codes for refresh failures.
 */
@objc(SFOAuthSessionRefreshErrorCode)
public enum SFOAuthSessionRefreshErrorCode: UInt {
    case invalidCredentials = 766
}

/** This class refreshes stale OAuth sessions, if possible.
 */
@objc(SFOAuthSessionRefresher)
public class SFOAuthSessionRefresher: NSObject {

    @objc public var credentials: OAuthCredentials?
    var completionBlock: ((OAuthCredentials) -> Void)?
    var errorBlock: ((Error) -> Void)?

    /**
     * Initializes the object with the given credentials.
     * @param credentials The OAuth credentials used to refresh the session.
     */
    @objc(initWithCredentials:)
    public init(credentials: OAuthCredentials?) {
        self.credentials = credentials
        super.init()
    }

    /**
     * Refreshes the expired session, with the given completion and error handler blocks.
     * @param completionBlock Called once the session has been refreshed.
     * @param errorBlock Called if there was an error refreshing the session.
     */
    @objc(refreshSessionWithCompletion:error:)
    public func refreshSession(completion: @escaping (OAuthCredentials) -> Void, error: @escaping (Error) -> Void) {
        self.completionBlock = completion
        self.errorBlock = error

        guard let credentials = self.credentials else {
            let error = NSError(domain: kSFOAuthErrorDomain,
                              code: Int(SFOAuthSessionRefreshErrorCode.invalidCredentials.rawValue),
                              userInfo: [NSLocalizedDescriptionKey: "Credentials are nil"])
            completeWithError(error)
            return
        }

        if credentials.instanceUrl == nil {
            let error = NSError(domain: kSFOAuthErrorDomain,
                              code: Int(SFOAuthSessionRefreshErrorCode.invalidCredentials.rawValue),
                              userInfo: [NSLocalizedDescriptionKey: "Credentials do not contain an instanceUrl"])
            completeWithError(error)
            return
        }

        if credentials.clientId?.isEmpty ?? true {
            let error = NSError(domain: kSFOAuthErrorDomain,
                              code: Int(SFOAuthSessionRefreshErrorCode.invalidCredentials.rawValue),
                              userInfo: [NSLocalizedDescriptionKey: "Credentials do not have an OAuth2 client_id set"])
            completeWithError(error)
            return
        }

        if credentials.refreshToken?.isEmpty ?? true {
            let error = NSError(domain: kSFOAuthErrorDomain,
                              code: Int(SFOAuthSessionRefreshErrorCode.invalidCredentials.rawValue),
                              userInfo: [NSLocalizedDescriptionKey: "Credentials do not have an OAuth2 refresh_token set"])
            completeWithError(error)
            return
        }

        let request = SFSDKOAuthTokenEndpointRequest()
        request.additionalOAuthParameterKeys = UserAccountManager.shared.additionalOAuthParameterKeys
        request.clientID = credentials.getClientIdForRefresh() ?? ""
        request.refreshToken = credentials.refreshToken ?? ""
        request.redirectURI = credentials.redirectUri ?? ""
        request.serverURL = credentials.overrideDomainIfNeeded() ?? URL(string: "")!

        guard let authClient = UserAccountManager.shared.authClient?() else {
            let error = NSError(domain: kSFOAuthErrorDomain,
                              code: Int(SFOAuthSessionRefreshErrorCode.invalidCredentials.rawValue),
                              userInfo: [NSLocalizedDescriptionKey: "No auth client available"])
            completeWithError(error)
            return
        }

        authClient.accessToken(forRefresh: request) { [weak self] (response: SFSDKOAuthTokenEndpointResponse) in
            guard let self = self else { return }

            if response.hasError {
                if let error = response.error?.error {
                    self.completeWithError(error)
                }
            } else {
                self.credentials?.updateCredentials(response.asDictionary())
                if let additionalFields = response.additionalOAuthFields {
                    self.credentials?.additionalOAuthFields = additionalFields as NSDictionary
                }
                self.completeWithSuccess()
            }
        }
    }

    // MARK: - Private methods
    private func completeWithSuccess() {
        SFSDKCoreLogger.i(type(of: self), message: "\(#function) Session was successfully refreshed.")

        if let completionBlock = self.completionBlock, let credentials = self.credentials {
            DispatchQueue.main.async {
                let account = UserAccountManager.shared.userAccount(for: credentials)
                var userInfo: [String: Any] = [:]
                if let account = account {
                    userInfo[UserAccountManager.userInfoAccountKey] = account
                } else {
                    SFSDKCoreLogger.e(type(of: self), message: "\(#function) No account for credentials")
                }
                NotificationCenter.default.post(name: .UserAccountManagerDidRefreshToken,
                                              object: self,
                                              userInfo: userInfo)
                completionBlock(credentials)
            }
        }
    }

    private func completeWithError(_ error: Error) {
        SFSDKCoreLogger.e(type(of: self), message: "\(#function) Refresh failed with error: \(error)")

        if let errorBlock = self.errorBlock {
            DispatchQueue.main.async {
                errorBlock(error)
            }
        }
    }
}

// MARK: - SFOAuthCoordinatorDelegate conformance (stub methods for compatibility)
extension SFOAuthSessionRefresher: SFOAuthCoordinatorDelegate {

    @objc(oauthCoordinator:didBeginAuthenticationWithASWebAuthenticationSession:)
    public func oauthCoordinator(_ coordinator: SFOAuthCoordinator, didBeginAuthenticationWith session: ASWebAuthenticationSession) {
        // Do nothing - doesn't apply to the refresh flow.
    }

    @objc(oauthCoordinator:didBeginAuthenticationWithWKWebView:)
    public func oauthCoordinator(_ coordinator: SFOAuthCoordinator, didBeginAuthenticationWith view: WKWebView) {
        // Do nothing - doesn't apply to the refresh flow.
    }

    @objc public func oauthCoordinatorDidCancelBrowserAuthentication(_ coordinator: SFOAuthCoordinator) {
        // Do nothing - doesn't apply to the refresh flow.
    }

    @objc public func oauthCoordinatorDidBeginNativeAuthentication(_ coordinator: SFOAuthCoordinator) {
        // Do nothing - doesn't apply to the refresh flow.
    }
}
