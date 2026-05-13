/*
 Copyright (c) 2016-present, salesforce.com, inc. All rights reserved.

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

/// Block to return a user agent string, with an optional qualifier.
public typealias UserAgentGeneratorBlock = (String) -> String

/// Block typedef for creating a custom login flow selection dialog.
public typealias IDPLoginFlowSelectionBlock = () -> UIViewController & SFSDKLoginFlowSelectionView

/// Block typedef for creating a custom user selection flow for idp provider app.
public typealias IDPUserSelectionBlock = () -> UIViewController & SFSDKUserSelectionView

/// Block to select an app config at runtime based on the login host.
/// The block takes a login host and a callback. The callback should be invoked with the selected app config.
public typealias BootConfigRuntimeSelector = (String, @escaping (BootConfig?) -> Void) -> Void

// MARK: - Objective-C Block Type Aliases

/// Objective-C typealias for IDPLoginFlowSelectionBlock
public typealias SFIDPLoginFlowSelectionBlock = IDPLoginFlowSelectionBlock

/// Objective-C typealias for IDPUserSelectionBlock
public typealias SFIDPUserSelectionBlock = IDPUserSelectionBlock

/// Objective-C typealias for BootConfigRuntimeSelector
public typealias SFSDKAppConfigRuntimeSelectorBlock = BootConfigRuntimeSelector

// MARK: - Type Aliases for Objective-C to Swift Migration Compatibility

/// Typealias for backward compatibility with Objective-C code that references SFOAuthCredentials
public typealias SFOAuthCredentials = OAuthCredentials

/// Typealias for backward compatibility with Objective-C code that references SFUserAccount
public typealias SFUserAccount = UserAccount

/// Typealias for backward compatibility with Objective-C code that references SFUserAccountIdentity
public typealias SFUserAccountIdentity = UserAccountIdentity

/// Typealias for backward compatibility with Objective-C code that references SFRestAPI
public typealias SFRestAPI = RestClient

/// Typealias for backward compatibility with Objective-C code that references SFRestRequest
public typealias SFRestRequest = RestRequest

/// Typealias for backward compatibility with Objective-C code that references SFBiometricAuthenticationManagerInternal
public typealias SFBiometricAuthenticationManagerInternal = BiometricAuthenticationManagerInternal

/// Typealias for backward compatibility with Objective-C code that references SFScreenLockManagerInternal
public typealias SFScreenLockManagerInternal = ScreenLockManagerInternal

/// Typealias for backward compatibility with Objective-C code that references SFUserAccountManager
public typealias SFUserAccountManager = UserAccountManager

/// Typealias for backward compatibility with Objective-C code that references SFIdentityData
public typealias SFIdentityData = IdentityData

/// Typealias for backward compatibility with Objective-C code that references SFLoginViewController
public typealias SFLoginViewController = SalesforceLoginViewController

/// Typealias for backward compatibility with Objective-C code that references SFLoginViewControllerDelegate
public typealias SFLoginViewControllerDelegate = SalesforceLoginViewControllerDelegate

// Additional typealiases for Swift naming conventions (used internally, not Obj-C bridging)
// Note: These types are defined in Swift with @objc() names but are referenced without the SF prefix internally

/// Typealias for LoginViewController (Swift naming convention)
public typealias LoginViewController = SalesforceLoginViewController

/// Typealias for OAuthSessionRefresher (Swift naming convention)
public typealias OAuthSessionRefresher = SFOAuthSessionRefresher

/// Typealias for LoginViewControllerConfig (using actual Swift class name)
public typealias LoginViewControllerConfig = SalesforceLoginViewControllerConfig

/// Typealias for LoginFlowSelectionView (Swift naming convention)
public typealias LoginFlowSelectionView = SFSDKLoginFlowSelectionView

/// Typealias for UserSelectionView (Swift naming convention)
public typealias UserSelectionView = SFSDKUserSelectionView

/// Typealias for URLHandlerManager (Swift naming convention)
public typealias URLHandlerManager = SFSDKURLHandlerManager

// Note: SFSDKLoginHostListViewController is the @objc name for LoginHostListViewController
// Note: SFSDKLoginHostDelegate is an Objective-C protocol defined in a header file

/// Typealias for LoginHost (using actual Swift class name)
public typealias LoginHost = SalesforceLoginHost

/// Typealias for SFSDK LoginHost (Objective-C naming convention)
public typealias SFSDKLoginHost = SalesforceLoginHost

/// Typealias for LoginViewControllerConfig - matches Obj-C naming
public typealias SFSDKLoginViewControllerConfig = SalesforceLoginViewControllerConfig

/// Typealias for AuthErrorManager (Swift naming convention)
public typealias SFSDKAuthErrorManager = SDKAuthErrorManager

/// Typealias for AlertMessage (Swift naming convention)
public typealias SFSDKAlertMessage = AlertMessage

/// Typealias for AuthViewHandler (Swift naming convention)
public typealias SFSDKAuthViewHandler = AuthViewHandler

/// Typealias for AuthHelper (Swift naming convention)
public typealias AuthHelper = SFSDKAuthHelper

/// Typealias for KeyGenerator (Swift naming convention)
public typealias SFSDKKeyGenerator = KeyGenerator

/// Typealias for Encryptor (Swift naming convention)
public typealias SFSDKEncryptor = Encryptor

/// Typealias for NotificationType (Swift naming convention)
public typealias SFSDKNotificationType = NotificationType

/// Typealias for UserAccountManagerError (Swift naming convention)
public typealias SFSDKUserAccountManagerError = UserAccountManagerError

// MARK: - Constants

/// Default community name constant
public let kDefaultCommunityName = "Internal"

/// Notification userInfo key for user account
public let kSFNotificationUserInfoAccountKey = "SFNotificationUserInfoAccountKey"

/// Notification userInfo key for notification user info object
public let kSFNotificationUserInfoKey = "SFNotificationUserInfoKey"

/// Typealias for NotificationUserInfo (Swift naming convention)
public typealias SFNotificationUserInfo = NotificationUserInfo

// MARK: - UserAccountPersister Protocol

/// Protocol for persisting user account data
/// Note: This mirrors the Objective-C SFUserAccountPersister protocol
/// These methods throw and return Bool, so cannot be marked @objc
public protocol UserAccountPersister: NSObjectProtocol {
    /// Saves a user account
    /// - Parameter userAccount: The account to save
    /// - Returns: true if successful
    /// - Throws: An error if the save fails
    func saveAccount(for userAccount: UserAccount) throws -> Bool

    /// Fetches all user accounts
    /// - Returns: Dictionary mapping account identities to user accounts
    /// - Throws: An error if the fetch fails
    func fetchAllAccounts() throws -> [UserAccountIdentity: UserAccount]

    /// Deletes a user account
    /// - Parameter userAccount: The account to delete
    /// - Returns: true if successful
    /// - Throws: An error if the delete fails
    func deleteAccount(for userAccount: UserAccount) throws -> Bool
}

/// Typealias for UserAccountPersister protocol (Obj-C naming)
public typealias SFUserAccountPersister = UserAccountPersister

// MARK: - Manager Protocol Typealiases

/// Typealias for BiometricAuthenticationManager protocol (Obj-C naming)
public typealias SFBiometricAuthenticationManager = BiometricAuthenticationManager

/// Typealias for ScreenLockManager protocol (Obj-C naming)
public typealias SFScreenLockManager = ScreenLockManager

/// Typealias for NativeLoginManager protocol (Obj-C naming)
public typealias SFNativeLoginManager = NativeLoginManager

/// Typealias for NativeLoginManagerInternal (Obj-C naming)
public typealias SFNativeLoginManagerInternal = NativeLoginManagerInternal

/// Typealias for AuthViewHolder (Obj-C naming)
public typealias SFSDKAuthViewHolder = AuthViewHolder

/// Typealias for EncryptedURLCache (Obj-C naming)
public typealias SFSDKEncryptedURLCache = EncryptedURLCache

/// Typealias for NullURLCache (Obj-C naming)
public typealias SFSDKNullURLCache = NullURLCache

/// Typealias for AuthSession (Obj-C naming)
public typealias SFSDKAuthSession = AuthSession

// MARK: - UserAccount Change Types

/// The various changes that can affect a user account
/// Note: Defined in SFUserAccountConstants.h with NS_OPTIONS
public struct SFUserAccountChange: OptionSet {
    public let rawValue: UInt

    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    /// Unknown change
    public static let unknown = SFUserAccountChange(rawValue: 1 << 0)

    /// New User
    public static let newUser = SFUserAccountChange(rawValue: 1 << 1)

    /// Change of Current User
    public static let currentUser = SFUserAccountChange(rawValue: 1 << 2)
}

/// The various data changes that can affect a user account
/// Note: Defined in SFUserAccountConstants.h with NS_OPTIONS
public struct SFUserAccountDataChange: OptionSet {
    public let rawValue: UInt

    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    /// Unknown change
    public static let unknown = SFUserAccountDataChange(rawValue: 1 << 0)

    /// The community ID changed
    public static let communityId = SFUserAccountDataChange(rawValue: 1 << 1)

    /// The ID data changed
    public static let idData = SFUserAccountDataChange(rawValue: 1 << 2)

    /// InstanceURL Changed
    public static let instanceURL = SFUserAccountDataChange(rawValue: 1 << 3)

    /// AccessToken Changed
    public static let accessToken = SFUserAccountDataChange(rawValue: 1 << 4)
}

// MARK: - IDP Constants

/// IDP Scene ID Key constant
public let kSFIDPSceneIdKey = UserAccountManager.IDPSceneKey

// MARK: - OAuth Error Constants (for backward compatibility)

/// OAuth error constant for invalid grant
public let kSFOAuthErrorInvalidGrant = SFOAuthError.invalidGrant.rawValue

/// OAuth error constant for invalid client ID
public let kSFOAuthErrorInvalidClientId = SFOAuthError.invalidClientId.rawValue

/// OAuth error constant for timeout
public let kSFOAuthErrorTimeout = SFOAuthError.timeout.rawValue

/// OAuth error constant for wrong version
public let kSFOAuthErrorWrongVersion = SFOAuthError.wrongVersion.rawValue

/// OAuth error constant for invalid URL
public let kSFOAuthErrorInvalidURL = SFOAuthError.invalidURL.rawValue

// MARK: - Protocol Definitions

/// Protocol for login host delegate callbacks
/// Note: This mirrors the Objective-C SFSDKLoginHostDelegate protocol
@objc public protocol SFSDKLoginHostDelegate: NSObjectProtocol {
    @objc optional func hostListViewController(_ hostListViewController: LoginHostListViewController, willPresentLoginHostViewController loginHostViewController: UIViewController)
    @objc optional func hostListViewControllerDidSelectLoginHost(_ hostListViewController: LoginHostListViewController)
    @objc optional func hostListViewControllerDidAddLoginHost(_ hostListViewController: LoginHostListViewController)
    @objc optional func hostListViewControllerDidCancelLoginHost(_ hostListViewController: LoginHostListViewController)
    @objc optional func hostListViewController(_ hostListViewController: LoginHostListViewController, didChangeLoginHost newLoginHost: SalesforceLoginHost)
}

/// Typealias for Swift naming convention
public typealias LoginHostDelegate = SFSDKLoginHostDelegate

/// Protocol for URL request handling
/// Note: This mirrors the Objective-C SFSDKURLHandler protocol
@objc public protocol SFSDKURLHandler: NSObjectProtocol {
    @objc func canHandleRequest(_ url: URL, options: [AnyHashable: Any]?) -> Bool
    @objc func processRequest(_ url: URL, options: [AnyHashable: Any]?) -> Bool

    @objc optional func processRequest(_ url: URL,
                                       options: [AnyHashable: Any]?,
                                       completion: SFUserAccountManagerSuccessCallbackBlock?,
                                       failure: SFUserAccountManagerFailureCallbackBlock?) -> Bool
}

// MARK: - Callback Block Types

/// Callback block for successful user account operations
public typealias SFUserAccountManagerSuccessCallbackBlock = (_ authInfo: SFOAuthInfo?, _ userAccount: UserAccount?) -> Void

/// Callback block for failed user account operations
public typealias SFUserAccountManagerFailureCallbackBlock = (_ authInfo: SFOAuthInfo?, _ error: Error?) -> Void
