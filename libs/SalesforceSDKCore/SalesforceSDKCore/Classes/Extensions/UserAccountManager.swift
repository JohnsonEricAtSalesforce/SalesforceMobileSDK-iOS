
/*
 UserAccountManager.swift
 SalesforceSDKCore
 
 Created by Raj Rao on 10/21/19.
 
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

public typealias AuthInfo = SFOAuthInfo

public enum UserAccountManagerError: Error {
    case loginFailed(underlyingError: Error, authInfo: AuthInfo)
    case loginJWTFailed(underlyingError: Error, authInfo: AuthInfo)
    case refreshFailed(underlyingError: Error, authInfo: AuthInfo)
    case userSwitchFailed(underlyingError: Error)
    case userSwitchFailedUnknown
}

protocol UserAccountManaging {
    func account() -> UserAccount?
    
    func refresh(credentials: OAuthCredentials, _ completionBlock: @escaping (Result<(UserAccount, AuthInfo), UserAccountManagerError>) -> Void) -> Bool
}

extension UserAccountManager: UserAccountManaging {
    // Current User Account
    func account() -> UserAccount? {
        return UserAccountManager.shared.currentUserAccount
    }
    
    ///  Kick off the login process for credentials that's previously configured.
    /// - Parameter completionBlock: completion block to invoke with a success tuple (UserAccount, AuthInfo) or   UserAccountManagerError for failure wrapped in a Result type.
    public func login(_ completionBlock: @escaping (Result<(UserAccount, AuthInfo), UserAccountManagerError>) -> Void) -> Bool {
        return login(completion: { (authInfo, userAccount) in
             completionBlock(Result.success((userAccount,authInfo)))
        }) { (authInfo, error) in
            completionBlock(Result.failure(.loginFailed(underlyingError: error, authInfo: authInfo)))
        }
    }

    /// Kick off the login process for jwt token with credentials previously configured.
    /// - Parameters:
    ///   - jwt: the jwt token
    ///   - completionBlock: completion block to invoke with a success tuple (UserAccount, AuthInfo) or   UserAccountManagerError for failure wrapped in a Result type.
   public func login(using jwt: String, _ completionBlock: @escaping (Result<(UserAccount, AuthInfo), UserAccountManagerError>) -> Void) -> Bool {
        // JWT login is not directly supported - would need to implement or remove
        // For now, return false to indicate not supported
        SFSDKCoreLogger.e(UserAccountManager.self, message: "JWT login is not currently supported in this version")
        return false
   }

    /// Kick off the login process for jwt token with credentials previously configured.
    /// - Parameters:
    ///   - credentials: the OAuthCredentials object
    ///   - completionBlock: completion block to invoke with a success tuple (UserAccount, AuthInfo) or   UserAccountManagerError for failure wrapped in a Result type.
   public func refresh(credentials: OAuthCredentials, _ completionBlock: @escaping (Result<(UserAccount, AuthInfo), UserAccountManagerError>) -> Void) -> Bool {
        // Refresh credentials is not directly exposed - would need to implement or call internal method
        // For now, return false to indicate not supported
        SFSDKCoreLogger.e(UserAccountManager.self, message: "Refresh credentials is not currently supported in this version")
        return false
    }

    /// Switch to a new user. Kicks off the login flow. Once complete switches to a new user on success else does not change the current user.
    /// - Parameter completionBlock: completion block to invoke with a  UserAccount on success or  UserAccountManagerError on  failure wrapped in a Result type.
    public func switchToNewUserAccount(_ completionBlock: @escaping (Result<UserAccount, UserAccountManagerError>) -> Void) {
        return switchToNewUser { (err, userAccount) in
            guard let user = userAccount else {
                var switchUserError = UserAccountManagerError.userSwitchFailedUnknown
                if let error = err {
                   switchUserError = UserAccountManagerError.userSwitchFailed(underlyingError: error)
                }
                completionBlock(Result.failure(switchUserError))
                return
            }
            completionBlock(Result.success(user))
        }
    }

    /// Handle an authentication request with auth code from the IDP application
    /// - Parameters:
    ///    - url: The URL response returned to the app from the IDP application.
    ///    - options: Dictionary of name-value pairs received from open URL
    ///    - completion: Completion block to invoke with a UserAccount on success or UserAccountManagerError on failure wrapped in a Result type.
    /// - Returns: true if this is a valid URL response from IDP authentication that should be handled, false otherwise.
    public func handleIdentityProviderCommand(from url: URL, with options: [AnyHashable: Any], completion: @escaping (Result<(UserAccount, AuthInfo), UserAccountManagerError>) -> Void) -> Bool {
        // IDP authentication command handling is managed through URL handlers
        // This method is deprecated - use URL handler infrastructure instead
        SFSDKCoreLogger.e(UserAccountManager.self, message: "handleIdentityProviderCommand is not currently supported - use URL handler infrastructure")
        return false
    }

    /// Handle an advanced authentication URL response
    /// - Parameters:
    ///   - advancedAuthURL: The URL response from advanced authentication
    ///   - options: Optional dictionary of name-value pairs
    /// - Returns: true if the URL was handled successfully, false otherwise
    @objc public func handleAdvancedAuthURL(_ advancedAuthURL: URL, options: [AnyHashable: Any]?) -> Bool {
        // Get the scene identifier from the default scene
        let sceneId = SFSDKWindowManager.shared.defaultScene().session.persistentIdentifier
        guard let authSession = authSessions[sceneId as NSString] as? AuthSession else {
            SFSDKCoreLogger.d(Self.self, message: "No active auth session found for advanced auth URL")
            return false
        }

        return authSession.oauthCoordinator.handleAdvancedAuthenticationResponse(advancedAuthURL)
    }
}
