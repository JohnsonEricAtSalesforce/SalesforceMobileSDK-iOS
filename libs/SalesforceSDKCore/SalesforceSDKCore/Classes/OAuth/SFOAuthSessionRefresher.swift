// Copyright (c) 2015-present, salesforce.com, inc. All rights reserved.
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
import AuthenticationServices
import WebKit

/// Error codes for refresh failures.
@objc(SFOAuthSessionRefreshErrorCode)
public enum SFOAuthSessionRefreshErrorCode: UInt {
    case invalidCredentials = 766
}

/// This class refreshes stale OAuth sessions, if possible.
@objc(SFOAuthSessionRefresher)
@objcMembers
public class SFOAuthSessionRefresher: NSObject, SFOAuthCoordinatorDelegate {

    var credentials: OAuthCredentials?
    var completionBlock: ((OAuthCredentials) -> Void)?
    var errorBlock: ((Error) -> Void)?

    /// Initializes the object with the given credentials.
    @objc public init(credentials: OAuthCredentials?) {
        self.credentials = credentials
        super.init()
    }

    public override convenience init() {
        self.init(credentials: nil)
    }

    /// Refreshes the expired session.
    @objc public func refreshSession(withCompletion completionBlock: @escaping (OAuthCredentials) -> Void, error errorBlock: @escaping (Error) -> Void) {
        self.completionBlock = completionBlock
        self.errorBlock = errorBlock

        guard credentials?.instanceUrl != nil else {
            let error = NSError(domain: kSFOAuthErrorDomain, code: Int(SFOAuthSessionRefreshErrorCode.invalidCredentials.rawValue), userInfo: [NSLocalizedDescriptionKey: "Credentials do not contain an instanceUrl"])
            completeWithError(error)
            return
        }

        guard let clientId = credentials?.clientId, clientId.count > 0 else {
            let error = NSError(domain: kSFOAuthErrorDomain, code: Int(SFOAuthSessionRefreshErrorCode.invalidCredentials.rawValue), userInfo: [NSLocalizedDescriptionKey: "Credentials do not have an OAuth2 client_id set"])
            completeWithError(error)
            return
        }

        guard let refreshToken = credentials?.refreshToken, refreshToken.count > 0 else {
            let error = NSError(domain: kSFOAuthErrorDomain, code: Int(SFOAuthSessionRefreshErrorCode.invalidCredentials.rawValue), userInfo: [NSLocalizedDescriptionKey: "Credentials do not have an OAuth2 refresh_token set"])
            completeWithError(error)
            return
        }

        let request = SFSDKOAuthTokenEndpointRequest()
        request.additionalOAuthParameterKeys = UserAccountManager.shared.additionalOAuthParameterKeys
        request.additionalTokenRefreshParams = UserAccountManager.shared.additionalTokenRefreshParameters as NSDictionary
        request.clientID = credentials?.getClientIdForRefresh() ?? ""
        request.refreshToken = credentials?.refreshToken ?? ""
        request.redirectURI = credentials?.redirectUri ?? ""
        if let serverURL = credentials?.overrideDomainIfNeeded() {
            request.serverURL = serverURL
        }

        let authClient = UserAccountManager.shared.authClient() ?? SFSDKOAuth2()
        authClient.accessToken(forRefresh: request) { [weak self] (response: SFSDKOAuthTokenEndpointResponse?) in
            guard let self = self else { return }
            guard let response = response else {
                self.completeWithError(NSError(domain: kSFOAuthErrorDomain, code: -1, userInfo: nil))
                return
            }
            if response.hasError {
                self.completeWithError(response.error?.error ?? NSError(domain: kSFOAuthErrorDomain, code: -1, userInfo: nil))
            } else {
                self.credentials?.update(response.asDictionary() as? [AnyHashable: Any] ?? [:])
                if let additionalFields = response.additionalOAuthFields as? [AnyHashable: Any] {
                    self.credentials?.setValue(additionalFields, forKey: "additionalOAuthFields")
                }
                self.completeWithSuccess()
            }
        }
    }

    // MARK: - Private Methods

    private func completeWithSuccess() {
        SFSDKCoreLogger.i(Self.self, format: "%@ Session was successfully refreshed.", #function)
        if let block = completionBlock, let creds = credentials {
            DispatchQueue.main.async {
                let account = UserAccountManager.shared.userAccount(for: creds)
                var userInfo: [String: Any] = [:]
                if let account = account {
                    userInfo[UserAccountManager.userInfoAccountKey] = account
                } else {
                    SFSDKCoreLogger.e(Self.self, format: "%@ No account for credentials", #function)
                }
                NotificationCenter.default.post(name: UserAccountManager.didRefreshToken, object: self, userInfo: userInfo)
                block(creds)
            }
        }
    }

    private func completeWithError(_ error: Error) {
        SFSDKCoreLogger.e(Self.self, format: "%@ Refresh failed with error: %@", #function, error.localizedDescription)
        if let block = errorBlock {
            DispatchQueue.main.async {
                block(error)
            }
        }
    }

    // MARK: - SFOAuthCoordinatorDelegate (no-op for refresh flow)

    public func oauthCoordinator(_ coordinator: SFOAuthCoordinator, didBeginAuthenticationWithSession session: ASWebAuthenticationSession) {}
    public func oauthCoordinator(_ coordinator: SFOAuthCoordinator, didBeginAuthenticationWithView view: WKWebView) {}
    public func oauthCoordinatorDidCancelBrowserAuthentication(_ coordinator: SFOAuthCoordinator) {}
    public func oauthCoordinatorDidBeginNativeAuthentication(_ coordinator: SFOAuthCoordinator) {}
}
