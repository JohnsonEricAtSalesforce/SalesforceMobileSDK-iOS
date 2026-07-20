// Copyright (c) 2012-present, salesforce.com, inc. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
// For full license text, see the LICENSE file in the repo root or https://opensource.org/licenses/BSD-3-Clause

import Foundation
import WebKit
import SalesforceSDKCommon

// MARK: - Typealiases

/// Factory block for creating an OAuth protocol client.
public typealias SFAuthClientFactoryBlock = () -> any SFSDKOAuthProtocol

/// Callback for successful authentication.
public typealias AccountManagerSuccessCallbackBlock = (SFOAuthInfo, UserAccount) -> Void

/// Callback for authentication failure.
public typealias AccountManagerFailureCallbackBlock = (SFOAuthInfo, Error) -> Void

// MARK: - Notification Names

public extension NSNotification.Name {
    static let SFUserAccountManagerDidChangeUser = NSNotification.Name("SFUserAccountManagerDidChangeUserNotification")
    static let SFUserAccountManagerDidChangeUserData = NSNotification.Name("SFUserAccountManagerDidChangeUserDataNotification")
    static let SFUserAccountManagerDidFinishUserInit = NSNotification.Name("SFUserAccountManagerDidFinishUserInitNotification")
    static let SFUserAccountManagerWillLogInUser = NSNotification.Name("SFNotificationUserWillLogIn")
    static let SFUserAccountManagerDidLogInUser = NSNotification.Name("SFNotificationUserDidLogIn")
    static let SFUserAccountManagerWillLogoutUser = NSNotification.Name("SFNotificationUserWillLogout")
    static let SFUserAccountManagerDidLogoutUser = NSNotification.Name("SFNotificationUserDidLogout")
    static let SFUserAccountManagerDidLogoutOrg = NSNotification.Name("SFNotificationOrgDidLogout")
    static let SFUserAccountManagerDidRefreshToken = NSNotification.Name("SFNotificationOAuthUserDidRefreshToken")
    static let SFUserAccountManagerDidMigrateRefreshToken = NSNotification.Name("SFNotificationUserDidMigrateRefreshToken")
    static let SFUserAccountManagerWillSwitchUser = NSNotification.Name("SFNotificationUserWillSwitch")
    static let SFUserAccountManagerDidSwitchUser = NSNotification.Name("SFNotificationUserDidSwitch")
    static let didChangeLoginHost = NSNotification.Name("SFNotificationDidChangeLoginHost")
    static let SFUserAccountManagerWillShowAuthenticationView = NSNotification.Name("SFNotificationUserWillShowAuthView")
    static let SFUserAccountManagerUserCancelledAuthentication = NSNotification.Name("SFNotificationUserCanceledAuthentication")
    static let SFUserAccountManagerWillSendIDPRequest = NSNotification.Name("SFNotificationUserWillSendIDPRequest")
    static let SFUserAccountManagerWillSendIDPResponse = NSNotification.Name("kSFNotificationUserWillSendIDPResponse")
    static let SFUserAccountManagerDidReceiveIDPRequest = NSNotification.Name("SFNotificationUserDidReceiveIDPRequest")
    static let SFUserAccountManagerDidReceiveIDPResponse = NSNotification.Name("SFNotificationUserDidReceiveIDPResponse")
    static let SFUserAccountManagerDidLogInAfterIDPInit = NSNotification.Name("SFNotificationUserIDPInitDidLogIn")
}

// MARK: - UserInfo Key Constants (ObjC-visible)

// These are kept as ObjC-visible constants for backward compat with existing notification observers.
public extension NSNotification {
    @objc static let sfUserAccountManagerDidChangeUserNotification: NSNotification.Name = .SFUserAccountManagerDidChangeUser
    @objc static let sfUserAccountManagerDidChangeUserDataNotification: NSNotification.Name = .SFUserAccountManagerDidChangeUserData
    @objc static let sfUserAccountManagerDidFinishUserInitNotification: NSNotification.Name = .SFUserAccountManagerDidFinishUserInit
    @objc static let sfNotificationUserWillLogIn: NSNotification.Name = .SFUserAccountManagerWillLogInUser
    @objc static let sfNotificationUserDidLogIn: NSNotification.Name = .SFUserAccountManagerDidLogInUser
    @objc static let sfNotificationUserWillLogout: NSNotification.Name = .SFUserAccountManagerWillLogoutUser
    @objc static let sfNotificationUserDidLogout: NSNotification.Name = .SFUserAccountManagerDidLogoutUser
    @objc static let sfNotificationOrgDidLogout: NSNotification.Name = .SFUserAccountManagerDidLogoutOrg
    @objc static let sfNotificationUserDidRefreshToken: NSNotification.Name = .SFUserAccountManagerDidRefreshToken
    @objc static let sfNotificationUserDidMigrateRefreshToken: NSNotification.Name = .SFUserAccountManagerDidMigrateRefreshToken
    @objc static let sfNotificationUserWillSwitch: NSNotification.Name = .SFUserAccountManagerWillSwitchUser
    @objc static let sfNotificationUserDidSwitch: NSNotification.Name = .SFUserAccountManagerDidSwitchUser
    @objc static let sfNotificationDidChangeLoginHost: NSNotification.Name = .didChangeLoginHost
    @objc static let sfNotificationUserWillShowAuthView: NSNotification.Name = .SFUserAccountManagerWillShowAuthenticationView
    @objc static let sfNotificationUserCancelledAuth: NSNotification.Name = .SFUserAccountManagerUserCancelledAuthentication
    @objc static let sfNotificationUserWillSendIDPRequest: NSNotification.Name = .SFUserAccountManagerWillSendIDPRequest
    @objc static let sfNotificationUserWillSendIDPResponse: NSNotification.Name = .SFUserAccountManagerWillSendIDPResponse
    @objc static let sfNotificationUserDidReceiveIDPRequest: NSNotification.Name = .SFUserAccountManagerDidReceiveIDPRequest
    @objc static let sfNotificationUserDidReceiveIDPResponse: NSNotification.Name = .SFUserAccountManagerDidReceiveIDPResponse
    @objc static let sfNotificationUserIDPInitDidLogIn: NSNotification.Name = .SFUserAccountManagerDidLogInAfterIDPInit
}

// MARK: - Enums

/// Status updates during SP login flow initiated by IDP.
@objc(SFSPLoginStatus)
public enum SPLoginStatus: UInt {
    case launchingSPWithUserHint
    case codeVerifierStoredInKeychain
    case gettingAuthCodeFromServer
}

/// Errors that can occur during SP login flow initiated by IDP.
@objc(SFSPLoginError)
public enum SPLoginError: UInt {
    case noScheme
    case noUserIdentity
    case keychainWriteFailed
    case credentialRefreshFailed
}

/// Error codes for UserAccountManager internal errors.
@objc(SFSDKUserAccountManagerErrorCode)
public enum SFSDKUserAccountManagerErrorCode: UInt {
    case error = 100
    case cannotEncrypt = 10005
}

// MARK: - Delegate Protocol

@objc(SFUserAccountManagerDelegate)
public protocol UserAccountManagerDelegate: NSObjectProtocol {
    @objc optional func userAccountManagerIsNetworkAvailable(_ userAccountManager: UserAccountManager) -> Bool

    @objc(userAccountManager:error:info:)
    optional func userAccountManager(accountManager: UserAccountManager, didFailAuthenticationWith error: Error, info: SFOAuthInfo) -> Bool

    @objc(userAccountManager:willSwitchFromUser:toUser:)
    optional func userAccountManager(accountManager: UserAccountManager, willSwitchFrom currentUser: UserAccount, to newUser: UserAccount?)

    @objc(userAccountManager:didSwitchFromUser:toUser:)
    optional func userAccountManager(accountManager: UserAccountManager, didSwitchFrom previousUser: UserAccount, to currentUser: UserAccount?)
}

// MARK: - NotificationUserInfo

@objc(SFNotificationUserInfo)
@objcMembers
public class SFNotificationUserInfo: NSObject {
    public private(set) var accountIdentity: UserAccountIdentity
    public private(set) var communityId: String?

    init(user: UserAccount) {
        self.accountIdentity = user.accountIdentity
        self.communityId = user.credentials.communityId
        super.init()
    }
}

// MARK: - SFUserAccountPersister Protocol

@objc(SFUserAccountPersister)
public protocol SFUserAccountPersister: NSObjectProtocol {
    @objc(saveAccountForUser:error:) func saveAccount(forUser userAccount: UserAccount) throws
    @objc func fetchAllAccounts(_ error: AutoreleasingUnsafeMutablePointer<NSError>) -> [UserAccountIdentity: UserAccount]
    @objc(deleteAccountForUser:error:) func deleteAccount(forUser user: UserAccount) throws
}

// MARK: - Error Domain Constant

public let kSFSDKUserAccountManagerErrorDomain = "com.salesforce.mobilesdk.SFUserAccountManager"

// MARK: - UserAccountManager

@objc(SFUserAccountManager)
@objcMembers
open class UserAccountManager: NSObject {

    // MARK: - Notification Names (static accessors matching NS_SWIFT_NAME pattern)

    @objc public static let didChangeUser: NSNotification.Name = .SFUserAccountManagerDidChangeUser
    @objc public static let didChangeUserData: NSNotification.Name = .SFUserAccountManagerDidChangeUserData
    @objc public static let didFinishUserInit: NSNotification.Name = .SFUserAccountManagerDidFinishUserInit
    @objc public static let willLogInUser: NSNotification.Name = .SFUserAccountManagerWillLogInUser
    @objc public static let didLogInUser: NSNotification.Name = .SFUserAccountManagerDidLogInUser
    @objc public static let willLogoutUser: NSNotification.Name = .SFUserAccountManagerWillLogoutUser
    @objc public static let didLogoutUser: NSNotification.Name = .SFUserAccountManagerDidLogoutUser
    @objc public static let willSwitchUser: NSNotification.Name = .SFUserAccountManagerWillSwitchUser
    @objc public static let didSwitchUser: NSNotification.Name = .SFUserAccountManagerDidSwitchUser
    @objc public static let didChangeLoginHost: NSNotification.Name = NSNotification.Name("SFNotificationDidChangeLoginHost")
    @objc public static let didLogoutOrg: NSNotification.Name = .SFUserAccountManagerDidLogoutOrg
    @objc public static let didRefreshToken: NSNotification.Name = .SFUserAccountManagerDidRefreshToken
    @objc public static let didMigrateRefreshToken: NSNotification.Name = .SFUserAccountManagerDidMigrateRefreshToken
    @objc public static let willShowAuthenticationView: NSNotification.Name = .SFUserAccountManagerWillShowAuthenticationView
    @objc public static let userCancelledAuthentication: NSNotification.Name = .SFUserAccountManagerUserCancelledAuthentication
    @objc public static let willSendIDPRequest: NSNotification.Name = .SFUserAccountManagerWillSendIDPRequest
    @objc public static let willSendIDPResponse: NSNotification.Name = .SFUserAccountManagerWillSendIDPResponse
    @objc public static let didReceiveIDPRequest: NSNotification.Name = .SFUserAccountManagerDidReceiveIDPRequest
    @objc public static let didReceiveIDPResponse: NSNotification.Name = .SFUserAccountManagerDidReceiveIDPResponse
    @objc public static let didLogInAfterIDPInit: NSNotification.Name = .SFUserAccountManagerDidLogInAfterIDPInit

    // MARK: - Notification UserInfo Keys

    @objc public static let changeSetKey = "change"
    @objc public static let userInfoUserKey = "user"
    @objc public static let userInfoAccountKey = "account"
    @objc public static let userInfoLogoutReasonKey = "logoutReason"
    @objc public static let userInfoCredentialsKey = "credentials"
    @objc public static let userInfoAuthenticationTypeKey = "authType"
    @objc public static let userInfoAdditionalOptionsKey = "options"
    @objc public static let userInfoSfUserInfoKey = "sfuserInfo"
    @objc public static let userInfoFromUserKey = "fromUser"
    @objc public static let userInfoToUserKey = "toUser"
    @objc public static let IDPSceneKey = "sceneIdentifier"

    // MARK: - Internal Constants

    private static let kUserDefaultsLastUserIdentityKey = "LastUserIdentity"
    private static let kUserDefaultsLastUserCommunityIdKey = "LastUserCommunityId"
    static let kAlertErrorTitleKey = "authAlertErrorTitle"
    static let kAlertOkButtonKey = "authAlertOkButton"
    static let kAlertRetryButtonKey = "authAlertRetryButton"
    static let kAlertDismissButtonKey = "authAlertDismissButton"
    static let kAlertConnectionErrorFormatStringKey = "authAlertConnectionErrorFormatString"
    static let kAlertVersionMismatchErrorKey = "authAlertVersionMismatchError"
    static let kErroredClientKey = "SFErroredOAuthClientKey"
    static let kOptionsClientKey = "clientIdentifier"
    static let kBiometricAuthenticationPolicyKey = "ENABLE_BIOMETRIC_AUTHENTICATION"
    static let kBiometricAuthenticationTimeoutKey = "BIOMETRIC_AUTHENTICATION_TIMEOUT"
    static let kHttpHeaderAuthorization = "Authorization"
    static let kHttpAuthHeaderFormatString = "Bearer %@"
    private static let kInvalidCredentialsAuthErrorHandler = "InvalidCredentialsErrorHandler"
    private static let kConnectedAppVersionAuthErrorHandler = "ConnectedAppVersionErrorHandler"
    private static let kNetworkFailureAuthErrorHandler = "NetworkFailureErrorHandler"
    private static let kGenericFailureAuthErrorHandler = "GenericFailureErrorHandler"
    static let kNotificationPreviousLoginHost = "prevLoginHost"
    static let kNotificationCurrentLoginHost = "currentLoginHost"

    // MARK: - Singleton

    private static var _shared: UserAccountManager?
    private static var onceToken = false

    @objc public static var shared: UserAccountManager {
        if !onceToken {
            onceToken = true
            _shared = UserAccountManager()
            NotificationCenter.default.post(name: .SFUserAccountManagerDidFinishUserInit, object: nil)
        }
        return _shared!
    }

    // MARK: - Public Properties

    /// Completion block invoked when authentication is cancelled by user.
    @objc public var authCancelledByUserHandlerBlock: (() -> Void)?

    /// The current user account. May be nil if no user is logged in.
    @objc public var currentUserAccount: UserAccount? {
        get {
            if _currentUser == nil {
                return resolveCurrentUser()
            }
            return _currentUser
        }
        set {
            setCurrentUserInternal(newValue)
        }
    }
    var _currentUser: UserAccount?

    /// Returns true if the current user is anonymous (i.e., no user is logged in).
    @objc public var isCurrentUserAnonymous: Bool {
        return _currentUser == nil
    }

    /// Returns true if logout is requested via app settings.
    @objc public var isLogoutSettingEnabled: Bool {
        let logoutSetting = SFManagedPreferences.sharedPreferences.requireCertificateAuthentication
        // TODO: verify logic — actual setting may differ
        return logoutSetting
    }

    /// Indicates if the app is configured to require browser-based authentication.
    @objc public var usesAdvancedAuthentication: Bool {
        get { authPreferences.requireBrowserAuthentication }
        set { authPreferences.requireBrowserAuthentication = newValue }
    }

    /// Additional keys to parse during OAuth.
    @objc public var additionalOAuthParameterKeys: [String] = []

    /// Additional parameters to send during token refresh.
    @objc public var additionalTokenRefreshParameters: [String: Any] = [:]

    /// The host used for login.
    @objc public var loginHost: String {
        get { authPreferences.loginHost ?? "login.salesforce.com" }
        set { authPreferences.loginHost = newValue }
    }

    /// The previous login host, captured before a user-initiated host change. Used to
    /// recover the active login host when the current host fails to connect.
    var previousLoginHost: String?

    /// Whether to retry login after failure (default: true).
    @objc public var retriesLoginAfterFailure: Bool = true

    /// OAuth client ID for login.
    @objc public var oauthClientID: String {
        get { authPreferences.oauthClientId ?? "" }
        set { authPreferences.oauthClientId = newValue }
    }

    /// OAuth callback URL used for login.
    @objc public var oauthCompletionURL: String {
        get { authPreferences.oauthCompletionUrl ?? "sfdc:///axm/detect/oauth/done" }
        set { authPreferences.oauthCompletionUrl = newValue }
    }

    /// Branded Login path configured for this app.
    @objc public var brandLoginPath: String?

    /// OAuth scopes associated with the app.
    @objc public var scopes: Set<String> {
        get { authPreferences.scopes }
        set { authPreferences.scopes = newValue }
    }

    /// Factory block for the auth client.
    @objc public var authClient: SFAuthClientFactoryBlock

    /// Current user's identity (convenience).
    @objc public var currentUserAccountIdentity: UserAccountIdentity? {
        return currentUserIdentityValue()
    }

    /// Block to replace the login flow selection dialog.
    @objc public var idpLoginFlowSelectionAction: IDPLoginFlowSelectionBlock?

    /// Block to replace the default user selection screen.
    @objc public var idpUserSelectionAction: IDPUserSelectionBlock?

    /// Block for handling navigation policy on login web view.
    @objc public var navigationPolicyForAction: ((WKWebView, WKNavigationAction) -> WKNavigationActionPolicy)?

    /// Block for custom webview creation from login web view.
    @objc public var createWebview: ((WKWebView, WKWebViewConfiguration, WKNavigationAction, WKWindowFeatures) -> WKWebView?)?

    /// Whether this app is an Identity Provider for other apps.
    @objc public var isIdentityProvider: Bool {
        get { authPreferences.isIdentityProvider }
        set {
            if newValue {
                SFSDKAppFeatureMarkers.registerAppFeature(kSFIDPAppFeatureIDPLogin)
            } else {
                SFSDKAppFeatureMarkers.unregisterAppFeature(kSFIDPAppFeatureIDPLogin)
            }
            authPreferences.isIdentityProvider = newValue
        }
    }

    /// Whether this app can use another app as Identity Provider.
    @objc public var isIDPEnabled: Bool {
        return authPreferences.idpEnabled
    }

    /// URL scheme for the Identity Provider app.
    @objc public var idpAppURIScheme: String? {
        get { authPreferences.idpAppURIScheme }
        set {
            if let scheme = newValue, scheme.trimmingCharacters(in: .whitespaces).count > 0 {
                SFSDKAppFeatureMarkers.registerAppFeature(kSFSPAppFeatureIDPLogin)
            } else {
                SFSDKAppFeatureMarkers.unregisterAppFeature(kSFSPAppFeatureIDPLogin)
            }
            authPreferences.idpAppURIScheme = newValue
        }
    }

    /// User-friendly display name for this app (used in IDP user selection).
    @objc public var appDisplayName: String {
        get { authPreferences.appDisplayName }
        set { authPreferences.appDisplayName = newValue }
    }

    /// Login view controller configuration (theme, navbar, settings icon).
    @objc public var loginViewControllerConfig: SalesforceLoginViewControllerConfig {
        get {
            if _loginViewControllerConfig == nil {
                _loginViewControllerConfig = SalesforceLoginViewControllerConfig()
            }
            return _loginViewControllerConfig!
        }
        set { _loginViewControllerConfig = newValue }
    }
    private var _loginViewControllerConfig: SalesforceLoginViewControllerConfig?

    /// Whether to fall back to web-based authentication instead of native login.
    @objc public var shouldFallbackToWebAuthentication: Bool = false

    /// Internal backing for `showAuthWindowWhileLoading`. Internal reads (e.g. SFOAuthCoordinator)
    /// use this to avoid the deprecation warning on the public property. This is the Swift
    /// equivalent of upstream's `SFSDK_USE_DEPRECATED_BEGIN/END` guard around the ObjC use sites.
    /// When the public property is removed in 15.0, the auth window will always be shown while
    /// loading, so this backing can be deleted and the coordinator reads unconditionalized.
    var showAuthWindowWhileLoadingInternal: Bool = true

    /// If true, present the auth window while the webview is loading. Otherwise wait to present the
    /// auth window until the webview has finished loading. Defaults to `true`.
    @available(*, deprecated, message: "This property will be removed in Salesforce Mobile SDK 15.0. The auth window will always be shown while loading.")
    @objc public var showAuthWindowWhileLoading: Bool {
        get { showAuthWindowWhileLoadingInternal }
        set { showAuthWindowWhileLoadingInternal = newValue }
    }

    /// Custom filter for supported notification types.
    @objc public var filterSupportedNotificationTypes: (([NotificationType]) -> [NotificationType])?

    /// Indicates if the app is configured for native login.
    @objc public var nativeLoginEnabled: Bool = false

    // MARK: - Internal Properties

    var delegates = NSHashTable<AnyObject>.weakObjects()
    var userAccountMap: NSMutableDictionary?
    var accountPersister: SFUserAccountPersister?
    var authPreferences: SFSDKAuthPreferences
    var alertView: SFSDKAlertView?
    var alertDisplayBlock: (AlertMessage, SFSDKWindowContainer) -> Void = { _, _ in }
    var errorManager: SFSDKAuthErrorManager?
    var authSessions: NSMutableDictionary
    var authViewHandler: SFSDKAuthViewHandler
    let accountsLock = NSRecursiveLock()

    // MARK: - Init

    override init() {
        authPreferences = SFSDKAuthPreferences()
        authSessions = NSMutableDictionary()

        // Default auth client (singleton)
        let defaultAuthClient: SFAuthClientFactoryBlock = {
            struct Holder {
                static let instance: any SFSDKOAuthProtocol = SFSDKOAuth2()
            }
            return Holder.instance
        }
        authClient = defaultAuthClient

        // Placeholder authViewHandler — will be properly set after super.init
        authViewHandler = SFSDKAuthViewHandler(displayBlock: { _ in }, dismissBlock: {})

        super.init()

        accountPersister = SFDefaultUserAccountPersister()
        migrateUserDefaults()
        errorManager = SFSDKAuthErrorManager()
        shouldFallbackToWebAuthentication = false
        // Defaults to true as of #4039 (was false). Set the internal backing directly to avoid
        // the deprecation warning on the public `showAuthWindowWhileLoading` property.
        showAuthWindowWhileLoadingInternal = true

        alertDisplayBlock = { [weak self] message, window in
            guard let self = self else { return }
            self.alertView = SFSDKAlertView(message: message, window: window)
            self.alertView?.presentViewController(animated: false, completion: nil)
        }

        idpUserSelectionAction = {
            let controller = SFSDKUserSelectionNavViewController(nibName: nil, bundle: nil)
            controller.userSelectionDelegate = UserAccountManager.shared
            return controller
        }

        idpLoginFlowSelectionAction = {
            let controller = SFSDKLoginFlowSelectionViewController()
            controller.selectionFlowDelegate = UserAccountManager.shared
            return controller
        }

        authViewHandler = SFSDKAuthViewHandler(
            displayBlock: { [weak self] viewHandler in
                self?.presentLoginView(viewHandler)
            },
            dismissBlock: { [weak self] in
                self?.dismissAuthViewControllerIfPresent()
            }
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sceneDidDisconnect(_:)),
            name: UIScene.didDisconnectNotification,
            object: nil
        )
        populateErrorHandlers()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Delegate Management

    @objc public func addDelegate(_ delegate: any UserAccountManagerDelegate) {
        delegates.add(delegate as AnyObject)
    }

    @objc public func removeDelegate(_ delegate: any UserAccountManagerDelegate) {
        delegates.remove(delegate as AnyObject)
    }

    func enumerateDelegates(_ block: ((any UserAccountManagerDelegate) -> Void)?) {
        guard let block = block else { return }
        let enumerator = delegates.objectEnumerator()
        while let delegate = enumerator.nextObject() as? any UserAccountManagerDelegate {
            block(delegate)
        }
    }

    // MARK: - Persistent Properties (delegated to authPreferences)

    // loginHost, scopes, oauthCompletionURL, oauthClientID, isIdentityProvider,
    // isIDPEnabled, appDisplayName, idpAppURIScheme, usesAdvancedAuthentication
    // are all implemented above via computed properties delegating to authPreferences.

    // MARK: - Internal Setter for Current User

    func setCurrentUserInternal(_ user: UserAccount?) {
        setCurrentUserInternalFull(user)
    }

    // MARK: - User Defaults Migration

    private func migrateUserDefaults() {
        let sharedDefaults = UserDefaults(suiteName: SFSDKDatasharingHelper.sharedInstance.appGroupName)
        let standardDefaults = UserDefaults.standard
        let isGroupAccessEnabled = SFSDKDatasharingHelper.sharedInstance.appGroupEnabled
        let userIdentityShared = sharedDefaults?.bool(forKey: "userIdentityShared") ?? false
        let communityIdShared = sharedDefaults?.bool(forKey: "communityIdShared") ?? false

        if isGroupAccessEnabled && !userIdentityShared {
            if let userData = standardDefaults.object(forKey: Self.kUserDefaultsLastUserIdentityKey) {
                sharedDefaults?.set(userData, forKey: Self.kUserDefaultsLastUserIdentityKey)
            }
            sharedDefaults?.set(true, forKey: "userIdentityShared")
        }

        if !isGroupAccessEnabled && userIdentityShared {
            if let userData = sharedDefaults?.object(forKey: Self.kUserDefaultsLastUserIdentityKey) {
                standardDefaults.set(userData, forKey: Self.kUserDefaultsLastUserIdentityKey)
            }
            sharedDefaults?.set(false, forKey: "userIdentityShared")
        } else if isGroupAccessEnabled && !communityIdShared {
            if let communityId = standardDefaults.string(forKey: Self.kUserDefaultsLastUserCommunityIdKey) {
                sharedDefaults?.set(communityId, forKey: Self.kUserDefaultsLastUserCommunityIdKey)
            }
            sharedDefaults?.set(true, forKey: "communityIdShared")
        } else if !isGroupAccessEnabled && communityIdShared {
            if let communityId = sharedDefaults?.string(forKey: Self.kUserDefaultsLastUserCommunityIdKey) {
                standardDefaults.set(communityId, forKey: Self.kUserDefaultsLastUserCommunityIdKey)
            }
            sharedDefaults?.set(false, forKey: "communityIdShared")
        }

        standardDefaults.synchronize()
        sharedDefaults?.synchronize()
    }

    // MARK: - Error Handlers Population

    private func populateErrorHandlers() {
        guard let errorManager = errorManager else { return }

        errorManager.invalidAuthCredentialsErrorHandlerBlock = { [weak self] error, session, options in
            guard let self = self else { return }
            SFSDKCoreLogger.w(type(of: self), message: "OAuth refresh failed due to invalid grant. Error code: \((error as NSError).code)")
            session.notifiesDelegatesOfFailure = false
            self.handleFailure(error as NSError, session: session)
        }

        errorManager.networkErrorHandlerBlock = { [weak self] error, session, options in
            guard let self = self else { return }
            session.notifiesDelegatesOfFailure = false
            self.loggedIn(true, coordinator: session.oauthCoordinator, notifyDelegatesOfFailure: false)
        }

        errorManager.hostConnectionErrorHandlerBlock = { [weak self] error, session, options in
            guard let self = self else { return }
            let alertMessage = String(format: SFSDKResourceUtils.localizedString(Self.kAlertConnectionErrorFormatStringKey), error.localizedDescription)
            let okButton = SFSDKResourceUtils.localizedString(Self.kAlertOkButtonKey)
            self.showErrorAlert(message: alertMessage, buttonTitle: okButton, scene: session.oauthRequest.scene) {
                session.oauthCoordinator.stopAuthentication()
                if let creds = session.oauthCoordinator.credentials {
                    self.notifyUserCancelledOrDismissedAuth(creds, andAuthInfo: session.oauthCoordinator.authInfo)
                }
                let failingHost = session.oauthRequest.loginHost
                let storage = SFSDKLoginHostStorage.sharedInstance
                let failing = storage.loginHostForHostAddress(failingHost)
                // Only auto-remove the host when the error is a strong signal that the host itself
                // is unusable: a URL-syntax problem, an ATS rejection, or an OAuth invalid-URL.
                // These are reliably under our control and not produced by network conditions.
                //
                // Codes that look host-specific but are actually ambiguous on real networks are
                // intentionally NOT treated as strong signals:
                //   - NSURLErrorCannotFindHost / NSURLErrorDNSLookupFailed — captive portals
                //     (hotel / airport / coffee-shop Wi-Fi) routinely hijack DNS and return these
                //     for perfectly valid enterprise hosts. Auto-removing on DNS errors would
                //     silently and permanently delete a user's custom org host the first time
                //     they open the app behind a captive portal.
                //   - NSURLErrorTimedOut / NSURLErrorCannotConnectToHost / NSURLErrorNotConnectedToInternet
                //     / NSURLErrorNetworkConnectionLost / roaming-off / data-not-allowed —
                //     transient connectivity failures against a host that is otherwise fine.
                //
                // Both buckets fall through to the "leave the host in storage" branch.
                let nsError = error as NSError
                var strongBadHostSignal = false
                if nsError.domain == kSFOAuthErrorDomain && nsError.code == Int(kSFOAuthErrorInvalidURL) {
                    strongBadHostSignal = true
                } else if nsError.domain == NSURLErrorDomain {
                    switch nsError.code {
                    case NSURLErrorBadURL,
                         NSURLErrorUnsupportedURL,
                         NSURLErrorAppTransportSecurityRequiresSecureConnection:
                        strongBadHostSignal = true
                    default:
                        break
                    }
                }
                if let failing, failing.deletable, strongBadHostSignal {
                    let index = storage.indexOfLoginHost(failing)
                    if index != UInt(NSNotFound) {
                        storage.removeLoginHost(at: index)
                    }
                } else if failing == nil {
                    SFSDKCoreLogger.w(type(of: self), message: "Failing host not found in storage; skipping removal.")
                } else if let failing, failing.deletable, !strongBadHostSignal {
                    SFSDKCoreLogger.d(type(of: self), message: "Failing host left in storage; error \(nsError.domain)/\(nsError.code) is ambiguous (likely transient).")
                }
                // Choose a recovery host. Prefer the snapshot of the host the user was working on before
                // the bad host change; fall back to the first entry in storage. The fallback can be unsafe
                // in one edge case: if the failing host was just removed above AND it was the only entry,
                // or if MDM `onlyShowAuthorizedHosts` is enabled with an empty MDM host list, storage may
                // be empty here — `loginHost(at: 0)` would raise NSRangeException. Guard the index call.
                let prev = self.previousLoginHost
                var recoveryHost: String?
                if let prev, storage.loginHostForHostAddress(prev) != nil {
                    recoveryHost = prev
                } else if storage.numberOfLoginHosts > 0 {
                    recoveryHost = storage.loginHost(at: 0).host
                }
                if let recoveryHost {
                    session.oauthRequest.loginHost = recoveryHost
                    self.loginHost = recoveryHost
                    self.restartAuthentication(session)
                } else {
                    SFSDKCoreLogger.e(type(of: self), message: "No recovery host available; skipping restart.")
                }
            }
        }

        errorManager.genericErrorHandlerBlock = { [weak self] error, session, options in
            guard let self = self else { return }
            let message = String(format: SFSDKResourceUtils.localizedString(Self.kAlertConnectionErrorFormatStringKey), error.localizedDescription)
            let retryButton = SFSDKResourceUtils.localizedString(Self.kAlertOkButtonKey)
            self.showErrorAlert(message: message, buttonTitle: retryButton, scene: session.oauthRequest.scene) {
                self.restartAuthentication(session)
            }
        }

        errorManager.connectedAppVersionMismatchErrorHandlerBlock = { [weak self] error, session, options in
            guard let self = self else { return }
            SFSDKCoreLogger.w(type(of: self), message: "OAuth refresh failed due to Connected App version mismatch. Error code: \((error as NSError).code)")
            self.showAlertForConnectedAppVersionMismatchError(error as NSError, session: session)
        }
    }

    // MARK: - Alert Helpers

    func showErrorAlert(message alertMessage: String, buttonTitle: String, scene: UIScene?, completion: @escaping () -> Void) {
        let message = AlertMessage.message { builder in
            builder.alertTitle = SFSDKResourceUtils.localizedString(Self.kAlertErrorTitleKey)
            builder.alertMessage = alertMessage
            builder.actionOneTitle = buttonTitle
            builder.actionOneCompletion = { completion() }
        }
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let scene = scene else { return }
            self.alertDisplayBlock(message, SFSDKWindowManager.shared.authWindow(scene))
        }
    }

    func showAlertForConnectedAppVersionMismatchError(_ error: NSError, session: SFSDKAuthSession) {
        let message = AlertMessage.message { builder in
            builder.alertTitle = SFSDKResourceUtils.localizedString(Self.kAlertErrorTitleKey)
            builder.alertMessage = SFSDKResourceUtils.localizedString(Self.kAlertVersionMismatchErrorKey)
            builder.actionOneTitle = SFSDKResourceUtils.localizedString(Self.kAlertErrorTitleKey)
            builder.actionTwoTitle = SFSDKResourceUtils.localizedString(Self.kAlertDismissButtonKey)
            builder.actionOneCompletion = { [weak self] in
                session.notifiesDelegatesOfFailure = false
                self?.handleFailure(error, session: session)
            }
        }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.alertDisplayBlock(message, SFSDKWindowManager.shared.authWindow(session.oauthRequest.scene))
        }
    }

    // MARK: - Internal Methods (delegating to extensions)

    @objc func presentLoginView(_ viewHandler: SFSDKAuthViewHolder) {
        presentLoginViewImpl(viewHandler)
    }

    @objc func dismissAuthViewControllerIfPresent() {
        guard let scenes = SFApplicationHelper.sharedApplication()?.connectedScenes as? Set<UIScene> else { return }
        for scene in scenes {
            dismissAuthViewControllerIfPresent(for: scene, completion: nil)
        }
    }

    @objc func sceneDidDisconnect(_ notification: Notification) {
        sceneDidDisconnectHandler(notification)
    }

    @objc func handleFailure(_ error: NSError, session: SFSDKAuthSession) {
        handleFailureImpl(error, session: session)
    }

    @objc func loggedIn(_ fromOffline: Bool, coordinator: SFOAuthCoordinator, notifyDelegatesOfFailure: Bool) {
        loggedInImpl(fromOffline, coordinator: coordinator, notifyDelegatesOfFailure: notifyDelegatesOfFailure)
    }

    @objc func restartAuthentication(_ session: SFSDKAuthSession) {
        session.oauthCoordinator.stopAuthentication()
        let scene = session.oauthRequest.scene
        dismissAuthViewControllerIfPresent(for: scene) { [weak self] in
            guard let self = self else { return }
            if let sceneId = scene?.session.persistentIdentifier,
               let existingSession = self.authSessions[sceneId] as? SFSDKAuthSession {
                existingSession.isAuthenticating = false
            }
            // LFA passes its hint via the request's loginAsAdminLoginHint override
            // (consulted in authenticateWithRequest:); other restart paths intentionally
            // pass nil so a hint set on a prior session does not bleed across server changes.
            _ = self.authenticateWithRequest(
                session.oauthRequest,
                loginHint: nil,
                completion: session.authSuccessCallback,
                failure: session.authFailureCallback,
                frontDoorBridgeUrl: nil,
                codeVerifier: nil
            )
        }
    }

    @objc func notifyUserCancelledOrDismissedAuth(_ credentials: OAuthCredentials, andAuthInfo authInfo: SFOAuthInfo?) {
        notifyUserCancelledOrDismissedAuthImpl(credentials, andAuthInfo: authInfo)
    }

    // MARK: - Authentication Methods (delegating to Accounts extension)

    @objc func authenticateWithRequest(_ request: SFSDKAuthRequest,
                                       loginHint: String?,
                                       completion completionBlock: ((SFOAuthInfo, UserAccount?) -> Void)?,
                                       failure failureBlock: ((SFOAuthInfo, Error) -> Void)?,
                                       frontDoorBridgeUrl: URL?,
                                       codeVerifier: String?) -> Bool {
        return authenticateWithRequestImpl(request, loginHint: loginHint, completion: completionBlock, failure: failureBlock, frontDoorBridgeUrl: frontDoorBridgeUrl, codeVerifier: codeVerifier)
    }

    @objc func authenticateWithCompletion(_ completionBlock: ((SFOAuthInfo, UserAccount?) -> Void)?,
                                          failure failureBlock: ((SFOAuthInfo, Error) -> Void)?,
                                          scene: UIScene?,
                                          loginHint: String?,
                                          loginHost loginHostParam: String?,
                                          frontDoorBridgeUrl: URL?,
                                          codeVerifier: String?) -> Bool {
        return authenticateWithCompletionImpl(completionBlock, failure: failureBlock, scene: scene, loginHint: loginHint, loginHost: loginHostParam, frontDoorBridgeUrl: frontDoorBridgeUrl, codeVerifier: codeVerifier)
    }

    @objc func defaultAuthRequest() -> SFSDKAuthRequest {
        return defaultAuthRequest(withLoginHost: nil)
    }

    @objc func defaultAuthRequest(withLoginHost loginHostParam: String?) -> SFSDKAuthRequest {
        let request = SFSDKAuthRequest()
        request.loginHost = loginHostParam ?? loginHost
        request.additionalOAuthParameterKeys = additionalOAuthParameterKeys
        request.loginViewControllerConfig = loginViewControllerConfig
        request.brandLoginPath = brandLoginPath
        request.oauthClientId = oauthClientID
        request.oauthCompletionUrl = oauthCompletionURL
        request.scopes = scopes
        request.retryLoginAfterFailure = retriesLoginAfterFailure
        request.useBrowserAuth = usesAdvancedAuthentication
        request.spAppLoginFlowSelectionAction = idpLoginFlowSelectionAction
        request.idpAppURIScheme = idpAppURIScheme
        request.scene = SFSDKWindowManager.shared.defaultScene()
        return request
    }

    @objc func migrateRefreshAuthRequest(_ newAppConfig: BootConfig) -> SFSDKAuthRequest {
        let request = SFSDKAuthRequest()
        request.loginHost = loginHost
        request.additionalOAuthParameterKeys = additionalOAuthParameterKeys
        request.oauthClientId = newAppConfig.remoteAccessConsumerKey
        request.oauthCompletionUrl = newAppConfig.oauthRedirectURI
        request.scopes = newAppConfig.oauthScopes
        request.scene = SFSDKWindowManager.shared.defaultScene()
        return request
    }

    @objc func authenticateWithRequestOnBehalfOfSpApp(_ request: SFSDKAuthRequest,
                                                      spAppCredentials spAppCreds: OAuthCredentials,
                                                      completion completionBlock: ((SFOAuthInfo, UserAccount?) -> Void)?,
                                                      failure failureBlock: ((SFOAuthInfo, Error) -> Void)?) -> Bool {
        return authenticateWithRequestOnBehalfOfSpAppImpl(request, spAppCredentials: spAppCreds, completion: completionBlock, failure: failureBlock)
    }

    @objc func authenticateOnBehalfOfSPApp(_ user: UserAccount,
                                           spAppCredentials: OAuthCredentials,
                                           authRequest: SFSDKAuthRequest?,
                                           success successBlock: (() -> Void)?,
                                           failure failureBlock: ((Error) -> Void)?) {
        authenticateOnBehalfOfSPAppImpl(user, spAppCredentials: spAppCredentials, authRequest: authRequest, success: successBlock, failure: failureBlock)
    }

    @objc func authenticateUsingIDP(_ request: SFSDKAuthRequest,
                                    completion completionBlock: @escaping (SFOAuthInfo, UserAccount?) -> Void,
                                    failure failureBlock: @escaping (SFOAuthInfo, Error) -> Void) -> Bool {
        return authenticateUsingIDPImpl(request, completion: completionBlock, failure: failureBlock)
    }

    @objc func applyCredentials(_ credentials: OAuthCredentials) -> UserAccount? {
        return applyCredentials(credentials, withIdData: nil)
    }

    @objc func retrieveUserPhotoIfNeeded(_ account: UserAccount) {
        retrieveUserPhotoIfNeededImpl(account)
    }

    @objc func resetAuthentication() {
        resetAllAuthentication()
    }

    @objc func setCurrentUserIdentity(_ identity: UserAccountIdentity?) {
        setCurrentUserIdentityInternal(identity)
    }

    @objc func postPushUnregistration(_ user: UserAccount, logoutReason reason: SFLogoutReason) {
        postPushUnregistrationImpl(user, logoutReason: reason)
    }

    @objc func retrievedIdentityData(_ authSession: SFSDKAuthSession) {
        retrievedIdentityDataImpl(authSession)
    }

    @objc func createLoginViewControllerInstance(_ coordinator: SFOAuthCoordinator) -> SalesforceLoginViewController {
        return createLoginViewControllerInstanceImpl(coordinator)
    }

    @objc func reload() {
        reloadImpl()
    }
}
// SFUserAccountManager+Auth.swift
// SalesforceSDKCore
//
// Copyright (c) 2012-present, salesforce.com, inc. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
// For full license text, see the LICENSE file in the repo root or https://opensource.org/licenses/BSD-3-Clause

import Foundation
import UIKit
import WebKit
import AuthenticationServices
import SalesforceSDKCommon

// MARK: - SFOAuthCoordinatorDelegate

extension UserAccountManager: SFOAuthCoordinatorDelegate {

    public func oauthCoordinatorWillBeginAuthentication(_ coordinator: SFOAuthCoordinator, authInfo info: SFOAuthInfo) {
        guard let credentials = coordinator.credentials else { return }
        let userInfo: [String: Any] = [
            Self.userInfoCredentialsKey: credentials,
            Self.userInfoAuthenticationTypeKey: coordinator.authInfo
        ]
        NotificationCenter.default.post(name: .SFUserAccountManagerWillLogInUser, object: self, userInfo: userInfo)
    }

    public func oauthCoordinatorDidAuthenticate(_ coordinator: SFOAuthCoordinator, authInfo info: SFOAuthInfo) {
        loggedIn(false, coordinator: coordinator, notifyDelegatesOfFailure: true)
    }

    public func oauthCoordinator(_ coordinator: SFOAuthCoordinator, didFailWithError error: Error, authInfo info: SFOAuthInfo?) {
        guard let authSession = coordinator.authSession else { return }
        authSession.authError = error

        // Check if the request was initiated by SP app (IDP scenario only)
        if authSession.oauthRequest.authenticateRequestFromSPApp {
            if let spAppCreds = coordinator.spAppCredentials {
                SFSDKIDPAuthHelper.invokeSPAppWithError(spAppCreds, error: error, reason: "User cancelled authentication")
            }
            return
        }

        authSession.notifiesDelegatesOfFailure = true
        handleFailure(error as NSError, session: authSession)
    }

    public func oauthCoordinatorIsNetworkAvailable(_ coordinator: SFOAuthCoordinator) -> Bool {
        var result = true
        enumerateDelegates { delegate in
            if let available = delegate.userAccountManagerIsNetworkAvailable?(self) {
                result = result && available
            }
        }
        return result
    }

    public func oauthCoordinator(_ coordinator: SFOAuthCoordinator, willBeginBrowserAuthentication callbackBlock: @escaping SFOAuthBrowserFlowCallbackBlock) {
        coordinator.authSession?.authCoordinatorBrowserBlock = callbackBlock
        callbackBlock(true)
    }

    public func oauthCoordinator(_ coordinator: SFOAuthCoordinator, displayAlertMessage message: String, completion: @escaping () -> Void) {
        let messageObject = AlertMessage.message { builder in
            builder.actionOneTitle = SFSDKResourceUtils.localizedString("authAlertOkButton")
            builder.alertTitle = "Authentication"
            builder.actionOneCompletion = { completion() }
        }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let window = SFSDKWindowManager.shared.authWindow(coordinator.authSession?.oauthRequest.scene)
            self.alertDisplayBlock(messageObject, window)
        }
    }

    public func oauthCoordinator(_ coordinator: SFOAuthCoordinator, displayConfirmationMessage message: String, completion: @escaping (Bool) -> Void) {
        let messageObject = AlertMessage.message { builder in
            builder.actionOneTitle = SFSDKResourceUtils.localizedString("authAlertOkButton")
            builder.actionTwoTitle = SFSDKResourceUtils.localizedString("authAlertCancelButton")
            builder.alertTitle = ""
            builder.alertMessage = message
            builder.actionOneCompletion = {
                completion(true)
            }
            builder.actionTwoCompletion = {
                completion(false)
            }
        }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let window = SFSDKWindowManager.shared.authWindow(coordinator.authSession?.oauthRequest.scene)
            self.alertDisplayBlock(messageObject, window)
        }
    }

    // IDP related code fetched as an identity provider app
    public func oauthCoordinatorDidFetchAuthCode(_ coordinator: SFOAuthCoordinator, authInfo: SFOAuthInfo) {
        guard let authSession = coordinator.authSession else { return }
        let authCommand: SFSDKAuthCommand
        let keychainReference = authSession.oauthRequest.keychainReference

        if let keychainRef = keychainReference { // IDP request to SP
            let command = SFSDKIDPAuthCodeLoginRequestCommand()
            if let identity = currentUserAccountIdentity {
                command.userHint = encodeUserIdentity(identity)
            }
            command.keychainReference = keychainRef
            command.keychainGroup = authSession.oauthRequest.keychainGroup
            command.authCode = authSession.spAppCredentials?.authCode
            authCommand = command
        } else { // SP - IDP response
            let command = SFSDKSPLoginResponseCommand()
            command.authCode = authSession.spAppCredentials?.authCode
            authCommand = command
        }

        if let spAppRedirectUri = authSession.spAppCredentials?.redirectUri,
           let spAppURL = URL(string: spAppRedirectUri) {
            authCommand.scheme = spAppURL.scheme ?? ""
        }

        // Fetched auth code as an idp app
        SFSDKIDPAuthHelper.invokeSPApp(authCommand.requestURL()) { [weak self] _ in
            self?.dismissAuthViewControllerIfPresent()
        }
    }

    public func oauthCoordinator(_ coordinator: SFOAuthCoordinator, didBeginAuthenticationWithView view: WKWebView) {
        let loginViewController = createLoginViewControllerInstance(coordinator)
        loginViewController.oauthView = view

        let viewHolder = SFSDKAuthViewHolder()
        viewHolder.loginController = loginViewController
        viewHolder.scene = coordinator.authSession?.oauthRequest.scene

        let authViewDisplayBlock: () -> Void = { [weak self] in
            guard let self = self else { return }
            self.authViewHandler.authViewDisplayBlock(viewHolder)

            if let override = coordinator.frontdoorBridgeLoginOverride {
                var errorTitle: String?
                var errorMessage: String?
                if !override.matchesConsumerKey {
                    errorTitle = SFSDKResourceUtils.localizedString("Error")
                    errorMessage = SFSDKResourceUtils.localizedString("authAlertFrontdoorLoginUrlConsumerKeyMismatch")
                }
                if let title = errorTitle, let message = errorMessage {
                    let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: SFSDKResourceUtils.localizedString("OK"), style: .default, handler: nil))
                    loginViewController.present(alertController, animated: true, completion: nil)
                }
            }
        }

        // Ensure this runs on the main thread. Has to be sync, because the coordinator expects
        // the auth view to be added to a superview by the end of this method.
        if !Thread.isMainThread {
            DispatchQueue.main.sync { authViewDisplayBlock() }
        } else {
            authViewDisplayBlock()
        }
    }

    public func oauthCoordinator(_ coordinator: SFOAuthCoordinator, didBeginAuthenticationWithSession session: ASWebAuthenticationSession) {
        let viewHolder = SFSDKAuthViewHolder()
        viewHolder.isAdvancedAuthFlow = true
        viewHolder.session = session
        viewHolder.scene = coordinator.authSession?.oauthRequest.scene

        guard let credentials = coordinator.credentials else { return }
        let userInfo: [String: Any] = [
            Self.userInfoCredentialsKey: credentials,
            Self.userInfoAuthenticationTypeKey: coordinator.authInfo
        ]
        NotificationCenter.default.post(name: .SFUserAccountManagerWillShowAuthenticationView, object: self, userInfo: userInfo)
        authViewHandler.authViewDisplayBlock(viewHolder)
    }

    public func oauthCoordinatorDidBeginNativeAuthentication(_ coordinator: SFOAuthCoordinator) {
        let viewHolder = SFSDKAuthViewHolder()
        viewHolder.scene = coordinator.authSession?.oauthRequest.scene

        // Ensure this runs on the main thread. Has to be sync, because the coordinator expects
        // the auth view to be added to a superview by the end of this method.
        if !Thread.isMainThread {
            DispatchQueue.main.sync { [weak self] in
                self?.authViewHandler.authViewDisplayBlock(viewHolder)
            }
        } else {
            authViewHandler.authViewDisplayBlock(viewHolder)
        }
    }

    public func oauthCoordinatorDidCancelBrowserAuthentication(_ coordinator: SFOAuthCoordinator) {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.oauthCoordinatorDidCancelBrowserAuthentication(coordinator)
            }
            return
        }

        guard let authSession = coordinator.authSession else { return }

        // When "Login for Admin" initiated the browser auth, clear the flag and
        // its My Domain / login hint overrides, then restart the WebView login
        // flow against the originally configured host instead of showing the
        // server picker. For Welcome Discovery, this means the user lands back
        // on the discovery page and re-picks an account.
        if authSession.oauthRequest.loginAsAdmin {
            authSession.oauthRequest.loginAsAdmin = false
            authSession.oauthRequest.loginAsAdminMyDomain = nil
            authSession.oauthRequest.loginAsAdminLoginHint = nil
            restartAuthentication(authSession)
            return
        }

        if nativeLoginEnabled && shouldFallbackToWebAuthentication {
            shouldFallbackToWebAuthentication = false
            stopCurrentAuthentication(nil)
            _ = loginWithCompletion(nil, failure: nil)
            return
        }

        let authInfo = SFOAuthInfo(authType: .advancedBrowser)
        guard let credentials = coordinator.credentials else { return }
        let userInfo: [String: Any] = [
            Self.userInfoCredentialsKey: credentials,
            Self.userInfoAuthenticationTypeKey: authInfo
        ]
        NotificationCenter.default.post(name: .SFUserAccountManagerUserCancelledAuthentication, object: self, userInfo: userInfo)

        if authCancelledByUserHandlerBlock == nil {
            let hostListViewController = LoginHostListViewController(style: .plain)
            hostListViewController.delegate = self
            let controller = SFSDKNavigationController(rootViewController: hostListViewController)
            hostListViewController.hidesCancelButton = true
            // This is the screen the user lands on in the forced-advanced-auth path (e.g. after
            // cancelling the browser), where SFLoginViewController is never created. Mark it as the
            // standalone login screen so it surfaces the back button and gear / "Login Options"
            // menu that would otherwise live on SFLoginViewController.
            hostListViewController.presentedAsLoginScreen = true
            controller.modalPresentationStyle = .fullScreen

            let authWindow = SFSDKWindowManager.shared.authWindow(authSession.oauthRequest.scene)
            authWindow.presentWindow(animated: false) {
                authWindow.viewController?.present(controller, animated: false, completion: nil)
            }
        } else {
            authCancelledByUserHandlerBlock?()
        }
    }
}

// MARK: - SFIdentityCoordinatorDelegate

extension UserAccountManager: SFIdentityCoordinatorDelegate {

    public func identityCoordinatorRetrievedData(_ coordinator: SFIdentityCoordinator) {
        guard let authSession = coordinator.authSession else { return }
        retrievedIdentityData(authSession)
    }

    public func identityCoordinator(_ coordinator: SFIdentityCoordinator, didFailWithError error: Error) {
        guard let authSession = coordinator.authSession else { return }
        let nsError = error as NSError

        if nsError.code == kSFIdentityErrorMissingParameters {
            // No retry, as missing parameters are fatal
            SFSDKCoreLogger.e(type(of: self), message: "Missing parameters attempting to retrieve identity data. Error domain: \(nsError.domain), code: \(nsError.code), description: \(nsError.localizedDescription)")
            let authClient = self.authClient()
            if let credentials = coordinator.credentials {
                authClient.revokeRefreshToken(credentials, reason: .unexpectedResponse)
            }
            handleFailure(nsError, session: authSession)
        } else {
            SFSDKCoreLogger.e(type(of: self), message: "Error retrieving idData: \(error)")
            let message = AlertMessage.message { builder in
                builder.actionOneTitle = SFSDKResourceUtils.localizedString("authAlertRetryButton")
                builder.actionTwoTitle = SFSDKResourceUtils.localizedString("authAlertDismissButton")
                builder.alertTitle = SFSDKResourceUtils.localizedString("authAlertErrorTitle")
                builder.alertMessage = String(format: SFSDKResourceUtils.localizedString("authAlertConnectionErrorFormatString"), error.localizedDescription)
                builder.actionOneCompletion = {
                    coordinator.initiateIdentityDataRetrieval()
                }
            }
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let window = SFSDKWindowManager.shared.authWindow(authSession.oauthRequest.scene)
                self.alertDisplayBlock(message, window)
            }
        }
    }
}

// MARK: - SalesforceLoginViewControllerDelegate

extension UserAccountManager: SalesforceLoginViewControllerDelegate {

    public func loginViewController(_ loginViewController: SalesforceLoginViewController, didChangeLoginHost newLoginHost: SalesforceLoginHost) {
        let userInfo: [String: Any] = [
            Self.kNotificationPreviousLoginHost: loginHost,
            Self.kNotificationCurrentLoginHost: newLoginHost.host
        ]
        loginHost = newLoginHost.host
        let notification = Notification(name: .didChangeLoginHost, object: self, userInfo: userInfo)
        NotificationCenter.default.post(notification)

        if let sceneId = loginViewController.view.window?.windowScene?.session.persistentIdentifier,
           let session = authSessions[sceneId] as? SFSDKAuthSession {
            session.oauthRequest.loginHost = newLoginHost.host
        }
        restartAuthenticationForViewController(loginViewController)
    }

    public func loginViewControllerDidClearCache(_ loginViewController: SalesforceLoginViewController) {
        Task { @MainActor in
            await SFSDKWebViewStateManager.clearCache()
            self.restartAuthenticationForViewController(loginViewController)
        }
    }

    public func loginViewControllerDidClearCookies(_ loginViewController: SalesforceLoginViewController) {
        Task { @MainActor in
            await SFSDKWebViewStateManager.removeSessionForcefully()
            self.restartAuthenticationForViewController(loginViewController)
        }
    }

    public func loginViewControllerDidReload(_ loginViewController: SalesforceLoginViewController) {
        restartAuthenticationForViewController(loginViewController)
    }

    public func loginViewControllerDidSelectLoginForAdmin(_ loginViewController: SalesforceLoginViewController) {
        guard let sceneId = loginViewController.view.window?.windowScene?.session.persistentIdentifier,
              let session = authSessions[sceneId] as? SFSDKAuthSession else {
            restartAuthenticationForViewController(loginViewController)
            return
        }
        let coordinator = session.oauthCoordinator

        // Phase-1 Welcome Discovery: a discovery host is loaded but the user has not
        // yet picked an account, so credentials.domain is still the discovery host
        // and we have no My Domain to advance to. Switching to ASWebAuthenticationSession
        // here would launch the browser against welcome.salesforce.com — wrong UX.
        // No-op until phase 2 lands.
        if DomainDiscoveryCoordinator.isDiscoveryDomain(session.oauthRequest.loginHost) && !coordinator.domainUpdated {
            SFSDKCoreLogger.w(type(of: self), message: "loginViewControllerDidSelectLoginForAdmin: Login for Admin is not available before a My Domain has been selected on the Welcome Discovery page; ignoring.")
            return
        }

        // Phase-2 Welcome Discovery (or a non-discovery host): record the resolved
        // My Domain and login hint as LFA-scoped overrides on the request. The
        // request's loginHost is left untouched so that Reload / Clear Cache /
        // post-cancel restart continue to use the originally configured host.
        // These overrides are in-memory only and are cleared on LFA cancel.
        session.oauthRequest.loginAsAdminMyDomain = (coordinator.credentials?.domain?.count ?? 0) > 0 ? coordinator.credentials?.domain : nil
        session.oauthRequest.loginAsAdminLoginHint = (coordinator.loginHint?.count ?? 0) > 0 ? coordinator.loginHint : nil
        session.oauthRequest.loginAsAdmin = true
        restartAuthenticationForViewController(loginViewController)
    }

    public func loginViewControllerDidChangeLoginOptions(_ loginViewController: SalesforceLoginViewController) {
        restartAuthenticationForViewController(loginViewController, recreateAuthRequest: true)
    }
}

// MARK: - LoginHostDelegate

extension UserAccountManager: LoginHostDelegate {

    public func hostListViewControllerDidSelectLoginHost(_ hostListViewController: LoginHostListViewController) {
        loginHostSelected(hostListViewController)
    }

    public func hostListViewController(_ hostListViewController: LoginHostListViewController, didChange newLoginHost: SalesforceLoginHost) {
        accountsLock.lock()
        defer { accountsLock.unlock() }

        let userInfo: [String: Any] = [
            Self.kNotificationPreviousLoginHost: loginHost,
            Self.kNotificationCurrentLoginHost: newLoginHost.host
        ]
        previousLoginHost = loginHost
        loginHost = newLoginHost.host
        let notification = Notification(name: .didChangeLoginHost, object: self, userInfo: userInfo)
        NotificationCenter.default.post(notification)

        if let sceneId = hostListViewController.navigationController?.visibleViewController?.view.window?.windowScene?.session.persistentIdentifier,
           let session = authSessions[sceneId] as? SFSDKAuthSession {
            session.oauthRequest.loginHost = newLoginHost.host
        }
    }

    public func hostListViewControllerDidAddLoginHost(_ hostListViewController: LoginHostListViewController) {
        loginHostSelected(hostListViewController)
    }

    public func hostListViewControllerDidChangeLoginOptions(_ hostListViewController: LoginHostListViewController) {
        // Reached from the host list's gear menu in the forced-advanced-auth path. Recreate the
        // auth request and restart so changed login options (e.g. forceAdvancedAuthentication) take
        // effect, mirroring loginViewControllerDidChangeLoginOptions on the WebView screen.
        if let sceneId = hostListViewController.view.window?.windowScene?.session.persistentIdentifier,
           let session = authSessions[sceneId] as? SFSDKAuthSession {
            session.oauthRequest = defaultAuthRequest(withLoginHost: session.oauthRequest.loginHost)
            restartAuthentication(session)
        }
    }

    private func loginHostSelected(_ hostListViewController: LoginHostListViewController) {
        let sceneId = hostListViewController.navigationController?.visibleViewController?.view.window?.windowScene?.session.persistentIdentifier
        hostListViewController.dismiss(animated: true, completion: nil)
        if let sceneId = sceneId, let session = authSessions[sceneId] as? SFSDKAuthSession {
            restartAuthentication(session)
        }
    }
}

// MARK: - SFSDKLoginFlowSelectionViewDelegate (SP App flow Related Actions)

extension UserAccountManager: SFSDKLoginFlowSelectionViewDelegate {

    public func loginFlowSelectionIDPSelected(_ controller: UIViewController, options appOptions: [AnyHashable: Any]) {
        guard let scene = controller.view.window?.windowScene else { return }
        let sceneId = scene.session.persistentIdentifier

        if let loginHostValue = appOptions[SFSDKIDPConstants.kSFLoginHostParam] as? String,
           let session = authSessions[sceneId] as? SFSDKAuthSession {
            session.oauthCoordinator.credentials?.setValue(loginHostValue, forKey: "domain")
        }

        if let session = authSessions[sceneId] as? SFSDKAuthSession {
            session.oauthRequest.appDisplayName = appDisplayName
            SFSDKIDPAuthHelper.invokeIDPApp(session) { _ in
                SFSDKCoreLogger.d(type(of: self), message: "Launched IDP App")
            }
        }
    }

    public func loginFlowSelectionLocalLoginSelected(_ controller: UIViewController, options appOptions: [AnyHashable: Any]) {
        guard let scene = controller.view.window?.windowScene else { return }
        let sceneId = scene.session.persistentIdentifier

        dismissAuthViewControllerIfPresent(for: scene) { [weak self] in
            guard let self = self,
                  let session = self.authSessions[sceneId] as? SFSDKAuthSession else { return }
            _ = self.authenticateWithRequest(
                session.oauthRequest,
                loginHint: nil,
                completion: session.authSuccessCallback,
                failure: session.authFailureCallback,
                frontDoorBridgeUrl: nil,
                codeVerifier: nil
            )
        }
    }
}

// MARK: - SFSDKUserSelectionViewDelegate (IDP App flow Related Actions)

extension UserAccountManager: SFSDKUserSelectionViewDelegate {

    public func createNewUser(_ spAppOptions: [AnyHashable: Any]) {
        // Create new user selected in IDP flow in the idp app mode.
        let request = defaultAuthRequest()
        request.authenticateRequestFromSPApp = true
        let spAppCreds = spAppCredentials(from: spAppOptions)

        stopCurrentAuthentication { [weak self] _ in
            guard let self = self else { return }
            _ = self.authenticateWithRequestOnBehalfOfSpApp(request, spAppCredentials: spAppCreds, completion: { [weak self] _, user in
                guard let self = self else { return }
                if let user = user {
                    self.authenticateOnBehalfOfSPApp(user, spAppCredentials: spAppCreds, authRequest: nil, success: nil) { error in
                        SFSDKIDPAuthHelper.invokeSPAppWithError(spAppCreds, error: error, reason: "Failed refreshing credentials")
                    }
                }
            }, failure: { _, error in
                SFSDKIDPAuthHelper.invokeSPAppWithError(spAppCreds, error: error, reason: "Failed refreshing credentials")
            })
        }
    }

    public func selectedUser(_ user: UserAccount, spAppContext spAppOptions: [AnyHashable: Any]) {
        // User has been selected in the idp app mode.
        let spAppCreds = spAppCredentials(from: spAppOptions)
        if let currentUser = currentUserAccount {
            authenticateOnBehalfOfSPApp(currentUser, spAppCredentials: spAppCreds, authRequest: nil, success: nil) { error in
                SFSDKIDPAuthHelper.invokeSPAppWithError(spAppCreds, error: error, reason: "Failed refreshing credentials")
            }
        }
    }

    public func cancel(_ spAppOptions: [AnyHashable: Any]) {
        // User cancelled auth in the idp app mode
        let spAppCreds = spAppCredentials(from: spAppOptions)
        SFSDKIDPAuthHelper.invokeSPAppWithError(spAppCreds, error: nil, reason: "User cancelled Authentication")
    }

    private func spAppCredentials(from callingAppOptions: [AnyHashable: Any]) -> OAuthCredentials {
        let clientId = (callingAppOptions[SFSDKIDPConstants.kSFOAuthClientIdParam] as? String) ?? ""
        // Force unwrap is safe here: only fails if identifier is empty (it won't be)
        let creds = OAuthCredentials.credentials(identifier: clientId, clientId: clientId, encrypted: false, storageType: .keychain)!  // swiftlint:disable:this force_unwrapping
        creds.setValue(callingAppOptions[SFSDKIDPConstants.kSFOAuthRedirectUrlParam] as? String, forKey: "redirectUri")
        creds.setValue(callingAppOptions[SFSDKIDPConstants.kSFChallengeParamName] as? String, forKey: "challengeString")
        creds.setValue(nil, forKey: "accessToken")

        var loginHostValue = callingAppOptions[SFSDKIDPConstants.kSFLoginHostParam] as? String
        if loginHostValue == nil || loginHostValue?.sfsdk_isEmptyOrWhitespaceAndNewlines() == true {
            loginHostValue = loginHost
        }
        creds.setValue(loginHostValue, forKey: "domain")
        return creds
    }
}

// MARK: - Delegate Management (enumerateDelegates is in Part 1)
// addDelegate, removeDelegate, enumerateDelegates are defined in the main class (Part 1).

// MARK: - Anonymous User

extension UserAccountManager {

    /// Lazy accessor for userAccountMap that triggers reload if needed.
    @objc func ensureUserAccountMapLoaded() -> NSMutableDictionary {
        if userAccountMap == nil {
            reload()
        }
        return userAccountMap ?? NSMutableDictionary()
    }

    @objc func setAccountPersisterInternal(_ persister: (any SFUserAccountPersister)?) {
        guard let persister = persister, persister as AnyObject !== accountPersister as AnyObject else { return }
        accountsLock.lock()
        defer { accountsLock.unlock() }
        accountPersister = persister
        reload()
    }

    @objc func handleAdvancedAuthURL(_ advancedAuthURL: URL, options: [String: Any]?) -> Bool {
        var sceneId = options?[Self.IDPSceneKey] as? String
        if sceneId == nil {
            sceneId = SFSDKWindowManager.shared.defaultScene().session.persistentIdentifier
        }
        guard let sceneId = sceneId,
              let session = authSessions[sceneId] as? SFSDKAuthSession else {
            return false
        }
        return session.oauthCoordinator.handleAdvancedAuthenticationResponse(advancedAuthURL)
    }
}

// MARK: - Account Management

extension UserAccountManager {

    @objc public func userAccounts() -> [UserAccount]? {
        let map = ensureUserAccountMapLoaded()
        return map.allValues as? [UserAccount]
    }

    @objc public func userIdentities() -> [UserAccountIdentity]? {
        accountsLock.lock()
        defer { accountsLock.unlock() }
        let map = ensureUserAccountMapLoaded()
        guard let keys = map.allKeys as? [UserAccountIdentity] else { return nil }
        return keys.sorted { $0.compare($1) == .orderedAscending }
    }

    @objc(accountForCredentials:) public func userAccount(for credentials: OAuthCredentials) -> UserAccount? {
        accountsLock.lock()
        defer { accountsLock.unlock() }
        let map = ensureUserAccountMapLoaded()
        guard let keys = map.allKeys as? [UserAccountIdentity] else { return nil }
        for identity in keys {
            if identity.matchesCredentials(credentials) {
                return map[identity] as? UserAccount
            }
        }
        return nil
    }

    /// Returns all existing account names in the keychain.
    func allExistingAccountNames() -> Set<String>? {
        var tokenQuery: [String: Any] = [:]
        tokenQuery[kSecClass as String] = kSecClassGenericPassword
        tokenQuery[kSecMatchLimit as String] = kSecMatchLimitAll
        tokenQuery[kSecReturnAttributes as String] = kCFBooleanTrue

        var outArr: CFTypeRef?
        let result = SecItemOperations.copyMatching(tokenQuery, &outArr)
        if result == noErr, let items = outArr as? [[String: Any]] {
            var accounts = Set<String>()
            for info in items {
                if let accountName = info[kSecAttrAccount as String] as? String {
                    accounts.insert(accountName)
                }
            }
            return accounts
        } else {
            SFSDKCoreLogger.d(type(of: self), message: "Error querying for all existing accounts in the keychain: \(result)")
            return nil
        }
    }

    /// Returns a unique user account identifier.
    func uniqueUserAccountIdentifier(_ clientId: String) -> String {
        let existingAccountNames = allExistingAccountNames() ?? []
        var identifier: String
        repeat {
            let randomNumber = arc4random()
            identifier = "\(clientId)-\(randomNumber)"
        } while existingAccountNames.contains(identifier)
        return identifier
    }

    @objc public func createUserAccount(with credentials: OAuthCredentials) -> UserAccount {
        let newAcct = UserAccount(credentials: credentials)
        _ = upsert(newAcct)
        return newAcct
    }

    @objc public func createNativeUserAccount(with data: Data, scene: UIScene?) {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.createNativeUserAccount(with: data, scene: scene)
            }
            return
        }

        let nativeLoginScene: UIScene?
        if let scene = scene {
            nativeLoginScene = scene
        } else {
            let nativeLoginVCs = SalesforceSDKManager.shared.nativeLoginViewControllers
            let defaultKey: NSString = "defaultKey"
            nativeLoginScene = (nativeLoginVCs[defaultKey] as? UIViewController)?.view.window?.windowScene
        }

        guard let sceneId = nativeLoginScene?.session.persistentIdentifier,
              let authSession = authSessions[sceneId] as? SFSDKAuthSession else { return }

        // Dummy request is necessary for flow
        let request = SFSDKOAuthTokenEndpointRequest()
        request.additionalOAuthParameterKeys = []

        // Let SFSDKOAuth2 do error handling
        (authClient() as? SFSDKOAuth2)?.handleTokenEndpointResponse({ response in
            guard let response = response else { return }
            authSession.oauthCoordinator.updateCredentials(response.asDictionary() as! [String: Any])
            authSession.credentials = authSession.oauthCoordinator.credentials ?? authSession.credentials
            authSession.identityCoordinator = SFIdentityCoordinator(credentials: authSession.credentials)

            authSession.oauthCoordinator.delegate = self
            authSession.identityCoordinator?.delegate = self
            authSession.oauthCoordinator.authSession = authSession
            authSession.identityCoordinator?.authSession = authSession
            authSession.nativeLogin = true

            authSession.identityCoordinator?.initiateIdentityDataRetrieval()
        }, request: request, data: data, urlResponse: URLResponse())
    }

    @objc public func userAccount(for userIdentity: UserAccountIdentity) -> UserAccount? {
        accountsLock.lock()
        defer { accountsLock.unlock() }
        let map = ensureUserAccountMapLoaded()
        return map[userIdentity] as? UserAccount
    }

    @objc public func userAccounts(forDomain domain: String) -> [UserAccount] {
        var responseArray: [UserAccount] = []
        accountsLock.lock()
        defer { accountsLock.unlock() }
        let map = ensureUserAccountMapLoaded()
        guard let keys = map.allKeys as? [UserAccountIdentity] else { return responseArray }
        for key in keys {
            if let account = map[key] as? UserAccount,
               let accountDomain = account.credentials.domain,
               accountDomain.lowercased() == domain.lowercased() {
                responseArray.append(account)
            }
        }
        return responseArray
    }

    @objc func orgHasLoggedInUsers(_ orgId: String) -> Bool {
        let accounts = userAccounts(forOrg: orgId)
        return !accounts.isEmpty
    }

    @objc public func userAccounts(forOrg orgId: String) -> [UserAccount] {
        var responseArray: [UserAccount] = []
        accountsLock.lock()
        defer { accountsLock.unlock() }
        let map = ensureUserAccountMapLoaded()
        guard let keys = map.allKeys as? [UserAccountIdentity] else { return responseArray }
        for key in keys {
            if let account = map[key] as? UserAccount,
               let accountOrg = account.credentials.organizationId,
               (accountOrg as NSString).sfsdk_isEqual(toEntityId: orgId) {
                responseArray.append(account)
            }
        }
        return responseArray
    }

    @objc public func userAccounts(at instanceURL: URL) -> [UserAccount] {
        var responseArray: [UserAccount] = []
        accountsLock.lock()
        defer { accountsLock.unlock() }
        let map = ensureUserAccountMapLoaded()
        guard let keys = map.allKeys as? [UserAccountIdentity] else { return responseArray }
        for key in keys {
            if let account = map[key] as? UserAccount,
               account.credentials.instanceUrl?.host == instanceURL.host {
                responseArray.append(account)
            }
        }
        return responseArray
    }

    @objc public func clearAllAccountState() {
        accountsLock.lock()
        defer { accountsLock.unlock() }
        _currentUser = nil
        userAccountMap?.removeAllObjects()
        userAccountMap = nil
    }

    @objc func encodeUserIdentity(_ userIdentity: UserAccountIdentity) -> String {
        return "\(userIdentity.userId ?? ""):\(userIdentity.orgId ?? "")"
    }

    @objc func decodeUserIdentity(_ userIdentityEncoded: String?) -> UserAccountIdentity? {
        guard let encoded = userIdentityEncoded else { return nil }
        let components = encoded.components(separatedBy: ":")
        guard components.count >= 2 else { return nil }
        return UserAccountIdentity(userId: components[0], orgId: components[1])
    }

    @objc public func upsert(_ userAccount: UserAccount) -> Bool {
        accountsLock.lock()
        defer { accountsLock.unlock() }
        let map = ensureUserAccountMapLoaded()
        let oldCount = map.count

        // Remove from cache
        if map[userAccount.accountIdentity] != nil {
            map.removeObject(forKey: userAccount.accountIdentity)
        }

        let success: Bool
        do {
            try accountPersister?.saveAccount(forUser: userAccount)
            success = true
        } catch {
            success = false
        }
        if success {
            map[userAccount.accountIdentity] = userAccount
            if map.count > 1 && UInt(oldCount) < map.count {
                SFSDKAppFeatureMarkers.registerAppFeature(kSFAppFeatureMultiUser)
            }
        }
        return success
    }

    @objc public func delete(_ user: UserAccount) -> Bool {
        accountsLock.lock()
        defer { accountsLock.unlock() }

        let success: Bool
        do {
            try accountPersister?.deleteAccount(forUser: user)
            success = true
        } catch {
            success = false
        }

        if success {
            user.isUserDeleted = true
            let map = ensureUserAccountMapLoaded()
            map.removeObject(forKey: user.accountIdentity)
            if map.count < 2 {
                SFSDKAppFeatureMarkers.unregisterAppFeature(kSFAppFeatureMultiUser)
            }
            if user.accountIdentity.isEqual(_currentUser?.accountIdentity) {
                _currentUser = nil
                setCurrentUserIdentity(nil)
            }
        }
        return success
    }

    @objc public func loadAllUserAccounts() -> Bool {
        accountsLock.lock()
        defer { accountsLock.unlock() }

        var internalError: NSError? = nil
        let errorPointer = AutoreleasingUnsafeMutablePointer<NSError>(&internalError)
        let accounts = accountPersister?.fetchAllAccounts(errorPointer) ?? [:]

        if userAccountMap != nil {
            userAccountMap?.removeAllObjects()
        }
        userAccountMap = NSMutableDictionary(dictionary: accounts)

        return internalError == nil
    }

    // MARK: - Login / Logout / Refresh

    @objc public func loginWithCompletion(_ completionBlock: ((SFOAuthInfo, UserAccount?) -> Void)?, failure failureBlock: ((SFOAuthInfo, Error) -> Void)?) -> Bool {
        var result = false
        guard let scenes = SFApplicationHelper.sharedApplication()?.connectedScenes else { return false }
        for scene in scenes {
            result = loginWithCompletion(completionBlock, failure: failureBlock, scene: scene) || result
        }
        return result
    }

    @objc func loginWithCompletion(_ completionBlock: ((SFOAuthInfo, UserAccount?) -> Void)?,
                                   failure failureBlock: ((SFOAuthInfo, Error) -> Void)?,
                                   scene: UIScene?) -> Bool {
        return loginWithCompletion(completionBlock, failure: failureBlock, scene: scene, loginHint: nil, loginHost: nil, frontDoorBridgeUrl: nil, codeVerifier: nil)
    }

    @objc func loginWithCompletion(_ completionBlock: ((SFOAuthInfo, UserAccount?) -> Void)?,
                                   failure failureBlock: ((SFOAuthInfo, Error) -> Void)?,
                                   scene: UIScene?,
                                   loginHint: String?,
                                   loginHost loginHostParam: String?,
                                   frontDoorBridgeUrl: URL?,
                                   codeVerifier: String?) -> Bool {
        return authenticateWithCompletion(completionBlock, failure: failureBlock, scene: scene, loginHint: loginHint, loginHost: loginHostParam, frontDoorBridgeUrl: frontDoorBridgeUrl, codeVerifier: codeVerifier)
    }

    @objc public func refreshCredentials(_ credentials: OAuthCredentials,
                                          completion completionBlock: ((SFOAuthInfo, UserAccount?) -> Void)?,
                                          failure failureBlock: ((SFOAuthInfo, Error) -> Void)?) -> Bool {
        assert((credentials.refreshToken?.count ?? 0) > 0, "Refresh token required to refresh credentials.")

        // Route through the centralized coordinator so concurrent refreshes for the same credential
        // are coalesced into a single network call (protects single-use / rotating refresh tokens).
        // The coordinator (via SFOAuthSessionRefresher) posts the SFUserAccountManagerDidRefreshToken
        // notification, so this method no longer posts it directly.
        SFSDKTokenRefreshCoordinator.shared.refreshSession(forCredentials: credentials, completion: { [weak self] updatedCredentials in
            let authInfo = SFOAuthInfo(authType: .refresh)
            var userAccount = self?.userAccount(for: updatedCredentials)
            if userAccount == nil {
                userAccount = self?.applyCredentials(updatedCredentials)
            }
            if let account = userAccount {
                self?.retrieveUserPhotoIfNeeded(account)
            }
            completionBlock?(authInfo, userAccount)
        }, error: { error in
            let authInfo = SFOAuthInfo(authType: .refresh)
            failureBlock?(authInfo, error)
        })
        return true
    }

    @objc public func stopCurrentAuthentication(_ completionBlock: ((Bool) -> Void)?) {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.stopCurrentAuthentication(completionBlock)
            }
            return
        }

        var result = false
        for sceneId in authSessions.allKeys {
            guard let sceneIdStr = sceneId as? String,
                  let authSession = authSessions[sceneIdStr] as? SFSDKAuthSession else { continue }
            if authSession.isAuthenticating {
                result = true
                dismissAuthViewControllerIfPresent(for: authSession.oauthRequest.scene, completion: nil)
            }
        }

        resetAuthentication()

        if !result {
            SFSDKCoreLogger.e(type(of: self), message: "Authentication has already been stopped.")
        }
        completionBlock?(result)
    }

    @objc public func logout() {
        if let current = currentUserAccount {
            logout(current)
        }
    }

    @objc public func logout(_ reason: SFLogoutReason) {
        if let current = currentUserAccount {
            logout(current, reason: reason)
        }
    }

    @objc(logoutUser:) public func logout(_ user: UserAccount) {
        logout(user, reason: .unknown)
    }

    @objc public func logout(_ user: UserAccount, reason: SFLogoutReason) {
        // No-op if the user is not valid
        let loggingOutTransitionSucceeded = user.transitionToLoginState(.loggingOut)
        if !loggingOutTransitionSucceeded {
            // SFUserAccount already logs the transition failure.
            return
        }

        // Before starting actual logout (which will tear down SFRestAPI), first unregister from push notifications if needed
        PushNotificationManager.sharedInstance().unregisterSalesforceNotifications(for: user) { [weak self] in
            self?.postPushUnregistration(user, logoutReason: reason)
        }
    }

    @objc public func logoutAllUsers() {
        // Log out all other users, then the current user.
        if let accounts = userAccounts() {
            for account in accounts where account !== currentUserAccount {
                logout(account)
            }
        }
        if let current = currentUserAccount {
            logout(current)
        }
    }

    @objc public func loginWithJwtToken(_ jwtToken: String,
                                         completion completionBlock: ((SFOAuthInfo, UserAccount?) -> Void)?,
                                         failure failureBlock: ((SFOAuthInfo, Error) -> Void)?) -> Bool {
        assert(!jwtToken.isEmpty, "JWT token value required.")
        let request = defaultAuthRequest()
        request.jwtToken = jwtToken
        return authenticateWithRequest(request, loginHint: nil, completion: completionBlock, failure: failureBlock, frontDoorBridgeUrl: nil, codeVerifier: nil)
    }

    @objc public func migrateRefreshToken(for user: UserAccount,
                                           newAppConfig: BootConfig,
                                           success completionBlock: @escaping (SFOAuthInfo, UserAccount?) -> Void,
                                           failure failureBlock: @escaping (SFOAuthInfo, Error) -> Void) {
        // Store current user credentials to revoke them once migration completes
        let preMigrationCredentials = currentUserAccount?.credentials

        // Creating a SFSDKAuthRequest and SFSDKAuthSession
        let request = migrateRefreshAuthRequest(newAppConfig)
        let authSession = SFSDKAuthSession(with: request, credentials: nil)
        authSession.isAuthenticating = true
        authSession.authSuccessCallback = { [weak self] authInfo, newUserAccount in
            if let preMigCreds = preMigrationCredentials,
               let newRefresh = newUserAccount?.credentials.refreshToken,
               preMigCreds.refreshToken != newRefresh {
                let authClient = self?.authClient()
                authClient?.revokeRefreshToken(preMigCreds, reason: .refreshTokenRotated)
            }
            completionBlock(authInfo, newUserAccount)
        }
        authSession.authFailureCallback = failureBlock
        authSession.oauthCoordinator.delegate = self
        authSession.identityCoordinator?.delegate = self
        authSessions[authSession.sceneId] = authSession

        // Kicking off the actual migration (will load front-door approval URL in web view)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.dismissAuthViewControllerIfPresent(for: authSession.oauthRequest.scene) {
                authSession.oauthCoordinator.migrateRefreshToken(user)
            }
        }
    }

    // MARK: - Restart Authentication

    @objc func restartAuthenticationForViewController(_ loginViewController: SalesforceLoginViewController) {
        restartAuthenticationForViewController(loginViewController, recreateAuthRequest: false)
    }

    @objc func restartAuthenticationForViewController(_ loginViewController: SalesforceLoginViewController, recreateAuthRequest: Bool) {
        guard let sceneId = loginViewController.view.window?.windowScene?.session.persistentIdentifier,
              let session = authSessions[sceneId] as? SFSDKAuthSession else { return }

        // Recreate the oauth request
        // Otherwise changes to consumer key / callback url or scopes will not get picked up
        if recreateAuthRequest {
            session.oauthRequest = defaultAuthRequest(withLoginHost: session.oauthRequest.loginHost)
        }

        restartAuthentication(session)
    }

    // MARK: - Dismiss Auth View Controller

    @objc func dismissAuthViewControllerIfPresent(for scene: UIScene?, completion completionBlock: (() -> Void)?) {
        guard let scene = scene else {
            completionBlock?()
            return
        }
        if !Thread.isMainThread {
            DispatchQueue.main.sync { [weak self] in
                self?.dismissAuthViewControllerIfPresent(for: scene, completion: completionBlock)
            }
            return
        }

        let authWindow = SFSDKWindowManager.shared.authWindow(scene)
        if !authWindow.isEnabled {
            completionBlock?()
            return
        }

        let presentedViewController = authWindow.viewController?.presentedViewController
        if let presented = presentedViewController, presented.isBeingPresented {
            presented.dismiss(animated: false) {
                SFSDKWindowManager.shared.authWindow(scene).dismissWindow(animated: false) {
                    completionBlock?()
                }
            }
        } else {
            SFSDKWindowManager.shared.authWindow(scene).dismissWindow(animated: false) {
                completionBlock?()
            }
        }
    }

    // MARK: - IDP Authentication Response Handling

    @objc public func handleIdentityProviderResponse(from url: URL, with options: [AnyHashable: Any]) -> Bool {
        return handleIDPAuthenticationCommand(url, options: options, completion: nil, failure: nil)
    }

    @objc func handleIDPAuthenticationCommand(_ url: URL,
                                              options: [AnyHashable: Any],
                                              completion completionBlock: AccountManagerSuccessCallbackBlock?,
                                              failure failureBlock: AccountManagerFailureCallbackBlock?) -> Bool {
        SFSDKCoreLogger.d(type(of: self), message: "handleIDPAuthenticationResponse \(url.description)")
        let result = SFSDKURLHandlerManager.sharedInstance.canHandleRequest(url, options: options)
        if result {
            return SFSDKURLHandlerManager.sharedInstance.processRequest(url, options: options, completion: completionBlock, failure: failureBlock)
        }
        return result
    }

    @objc public func kickOffIDPInitiatedLoginFlow(forSP config: SPConfig,
                                                    statusUpdate statusBlock: @escaping (SPLoginStatus) -> Void,
                                                    failure failureBlock: @escaping (SPLoginError) -> Void) {
        guard let scheme = URL(string: config.oauthCallbackURL)?.scheme else {
            failureBlock(.noScheme)
            return
        }

        guard let currentUser = currentUserAccount,
              let accountIdentifier = encodeUserIdentity(currentUser.accountIdentity) as String? else {
            failureBlock(.noScheme)
            return
        }
        _ = accountIdentifier // consumed below

        let keychainGroup = config.keychainGroup
        let keyIdentifier = "com.salesforce.idp.codeverifier-\(scheme)"
        let codeVerifier = SFSDKCryptoUtils.randomByteData(withLength: SFSDKIDPConstants.kSFVerifierByteLength)
        let keychainResult = KeychainHelper.write(service: keyIdentifier, data: codeVerifier, account: nil, accessGroup: keychainGroup, cacheMode: .disabled)

        if keychainResult.success {
            statusBlock(.codeVerifierStoredInKeychain)
        } else {
            failureBlock(.keychainWriteFailed)
            return
        }

        let base64Verifier = (codeVerifier as NSData).sfsdk_base64UrlString()
        let sha256Data = (base64Verifier as NSString).sfsdk_sha256()
        let challengeString = sha256Data.sfsdk_base64UrlString()
        let appContext: [String: Any] = [
            SFSDKIDPConstants.kSFOAuthClientIdParam: config.oauthClientId,
            SFSDKIDPConstants.kSFOAuthRedirectUrlParam: config.oauthCallbackURL,
            SFSDKIDPConstants.kSFChallengeParamName: challengeString,
            SFSDKIDPConstants.kSFLoginHostParam: currentUser.credentials.domain ?? "",
            SFSDKIDPConstants.kSFScopesParam: SFSDKIDPAuthHelper.encodeScopes(config.oauthScopes)
        ]

        let request = defaultAuthRequest()
        request.keychainReference = keyIdentifier
        request.keychainGroup = config.keychainGroup
        let spAppCreds = spAppCredentials(from: appContext)
        authenticateOnBehalfOfSPApp(currentUser, spAppCredentials: spAppCreds, authRequest: request, success: {
            statusBlock(.gettingAuthCodeFromServer)
        }, failure: { _ in
            failureBlock(.credentialRefreshFailed)
        })
    }

    // MARK: - Switch User

    @objc public func switchToNewUser(completion: @escaping (Error?, UserAccount?) -> Void) {
        switchToNewUserWithCompletionImpl(completion)
    }

    @objc public func switchToUserAccount(_ userAccount: UserAccount?) {
        switchToUserImpl(userAccount)
    }

    @objc public func setCustomData(withObject object: NSObject & NSCoding, key: String, userAccount: UserAccount) {
        userAccount.setCustomDataObject(object, forKey: key as NSCopying)
        _ = upsert(userAccount)
    }
}
// SFUserAccountManager+Accounts.swift
// SalesforceSDKCore
//
// Copyright (c) 2012-present, salesforce.com, inc. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
// For full license text, see the LICENSE file in the repo root or https://opensource.org/licenses/BSD-3-Clause

import Foundation
import UIKit
import AuthenticationServices
import SalesforceSDKCommon

// MARK: - Account Management (continuation)

extension UserAccountManager {

    // MARK: - Apply Credentials

    @objc func applyCredentials(_ credentials: OAuthCredentials, withIdData identityData: SFIdentityData?) -> UserAccount? {
        var currentAccount = userAccount(for: credentials)
        var accountDataChange: UserAccount.AccountDataChange = .unknown
        var userAccountChange: UserAccount.AccountChange = .unknown

        if let existingAccount = currentAccount {
            if identityData != nil {
                accountDataChange.insert(.idData)
            }
            if credentials.hasPropertyValueChangedForKey("accessToken") {
                accountDataChange.insert(.accessToken)
            }
            if credentials.hasPropertyValueChangedForKey("instanceUrl") {
                accountDataChange.insert(.instanceURL)
            }
            if credentials.hasPropertyValueChangedForKey("communityId") {
                accountDataChange.insert(.communityId)
            }
            if accountDataChange != .unknown {
                accountDataChange.remove(.unknown)
            }
            existingAccount.credentials = credentials
        } else {
            currentAccount = UserAccount(credentials: credentials)
            userAccountChange = .newUser
        }

        credentials.resetCredentialsChangeSet()
        if let idData = identityData {
            currentAccount?.idData = idData
        }

        if let account = currentAccount {
            _ = upsert(account)
        }

        if accountDataChange != .unknown {
            if let account = currentAccount {
                notifyUserDataChange(.SFUserAccountManagerDidChangeUserData, withUser: account, andChange: accountDataChange)
            }
        } else if userAccountChange != .unknown {
            if let account = currentAccount {
                notifyUserChange(.SFUserAccountManagerDidChangeUser, withUser: account, andChange: userAccountChange)
            }
        }

        return currentAccount
    }

    // MARK: - Current User Identity

    @objc func currentUserIdentityValue() -> UserAccountIdentity? {
        accountsLock.lock()
        defer { accountsLock.unlock() }
        if _currentUser == nil {
            let userDefaults = UserDefaults.msdkUserDefaults()
            return userDefaults.object(forKey: "LastUserIdentity") as? UserAccountIdentity
        }
        return _currentUser?.accountIdentity
    }

    @objc func setCurrentUserIdentityInternal(_ userAccountIdentity: UserAccountIdentity?) {
        let standardDefaults = UserDefaults.msdkUserDefaults()
        accountsLock.lock()
        if let identity = userAccountIdentity {
            let archiver = NSKeyedArchiver(requiringSecureCoding: true)
            archiver.encode(identity, forKey: "LastUserIdentity")
            archiver.finishEncoding()
            standardDefaults.set(archiver.encodedData, forKey: "LastUserIdentity")
        } else {
            standardDefaults.removeObject(forKey: "LastUserIdentity")
        }
        accountsLock.unlock()
        standardDefaults.synchronize()
    }

    @objc var currentCommunityId: String? {
        let userDefaults = UserDefaults.msdkUserDefaults()
        return userDefaults.string(forKey: "LastUserCommunityId")
    }

    // MARK: - Current User Resolution

    /// Resolves the current user from persisted identity if not already set.
    @objc func resolveCurrentUser() -> UserAccount? {
        if _currentUser == nil {
            accountsLock.lock()
            defer { accountsLock.unlock() }
            let userDefaults = UserDefaults.msdkUserDefaults()
            guard let resultData = userDefaults.object(forKey: "LastUserIdentity") as? Data else {
                return nil
            }
            do {
                let unarchiver = try NSKeyedUnarchiver(forReadingFrom: resultData)
                unarchiver.requiresSecureCoding = true
                if let result = unarchiver.decodeObject(of: UserAccountIdentity.self, forKey: "LastUserIdentity") {
                    unarchiver.finishDecoding()
                    _currentUser = userAccount(for: result)
                    if _currentUser == nil {
                        SFSDKCoreLogger.e(type(of: self), message: "Located current user Identity in NSUserDefaults but was not found in list of accounts managed by SFUserAccountManager.")
                    }
                } else {
                    SFSDKCoreLogger.e(type(of: self), message: "Located current user Identity in NSUserDefaults but was not found in list of accounts managed by SFUserAccountManager.")
                }
            } catch {
                SFSDKCoreLogger.e(type(of: self), message: "Failed to init unarchiver for current user identity from user defaults: \(error).")
            }
        }
        return _currentUser
    }
}

// MARK: - Private Methods

extension UserAccountManager {

    // MARK: - Authentication with Request

    @objc func authenticateWithRequestImpl(_ request: SFSDKAuthRequest,
                                           loginHint: String?,
                                           completion completionBlock: ((SFOAuthInfo, UserAccount?) -> Void)?,
                                           failure failureBlock: ((SFOAuthInfo, Error) -> Void)?,
                                           frontDoorBridgeUrl: URL?,
                                           codeVerifier: String?) -> Bool {
        let authSession = SFSDKAuthSession(with: request, credentials: nil)
        authSession.isAuthenticating = true
        authSession.authFailureCallback = failureBlock
        authSession.authSuccessCallback = completionBlock
        authSession.oauthCoordinator.delegate = self

        // Only allow use of front door bridge URLs with matching consumer keys.
        if let bridgeUrl = frontDoorBridgeUrl {
            authSession.oauthCoordinator.frontdoorBridgeLoginOverride = AuthCoordinatorFrontdoorBridgeLoginOverride(
                frontdoorBridgeUrl: bridgeUrl,
                codeVerifier: codeVerifier
            )
        }
        // Login for Admin: when the request carries a My Domain override (set by
        // loginViewControllerDidSelectLoginForAdmin: in phase-2 Welcome Discovery),
        // route the browser session to the resolved My Domain and forward the
        // captured login hint, while leaving request.loginHost — and therefore
        // every other restart path — pointed at the originally configured host.
        let useLfaOverride = request.loginAsAdmin && (request.loginAsAdminMyDomain?.count ?? 0) > 0
        if useLfaOverride {
            authSession.credentials.domain = request.loginAsAdminMyDomain
            authSession.oauthCoordinator.loginHint = request.loginAsAdminLoginHint
        } else {
            authSession.oauthCoordinator.loginHint = loginHint
        }
        let appConfigLoginHost = useLfaOverride ? request.loginAsAdminMyDomain : request.loginHost
        let sceneId = authSession.sceneId
        authSessions[sceneId] = authSession

        if nativeLoginEnabled && !shouldFallbackToWebAuthentication {
            authSession.oauthCoordinator.useNativeAuth = true
        }

        Task { @MainActor in
            await SFSDKWebViewStateManager.removeSessionForcefully()
            SalesforceSDKManager.shared.bootConfig(forLoginHost: appConfigLoginHost) { appConfig in
                guard let appConfig = appConfig else { return }
                authSession.credentials.setValue(appConfig.remoteAccessConsumerKey, forKey: "clientId")
                authSession.credentials.setValue(appConfig.oauthRedirectURI, forKey: "redirectUri")
                authSession.credentials.setValue(appConfig.oauthScopes.map { $0 as? String ?? "" }, forKey: "scopes")
                authSession.oauthCoordinator.authenticate(withCredentials: authSession.credentials)
            }
        }
        return (authSessions[sceneId] as? SFSDKAuthSession)?.isAuthenticating ?? false
    }

    // MARK: - Authenticate with Completion

    @objc func authenticateWithCompletionImpl(_ completionBlock: ((SFOAuthInfo, UserAccount?) -> Void)?,
                                              failure failureBlock: ((SFOAuthInfo, Error) -> Void)?,
                                              scene: UIScene?,
                                              loginHint: String?,
                                              loginHost loginHostParam: String?,
                                              frontDoorBridgeUrl: URL?,
                                              codeVerifier: String?) -> Bool {
        guard let scene = scene else { return false }
        let sceneId = scene.session.persistentIdentifier

        if let existingSession = authSessions[sceneId] as? SFSDKAuthSession, existingSession.isAuthenticating {
            SFSDKCoreLogger.e(type(of: self), message: "Login has already been called. Stop current authentication using SFUserAccountManager::stopCurrentAuthentication and then retry.")
            return false
        }

        let request: SFSDKAuthRequest
        if nativeLoginEnabled && !shouldFallbackToWebAuthentication {
            request = nativeLoginAuthRequest()
        } else {
            request = defaultAuthRequest(withLoginHost: loginHostParam)
        }

        request.scene = scene

        if request.idpEnabled {
            return authenticateUsingIDPImpl(request, completion: completionBlock, failure: failureBlock)
        }

        return authenticateWithRequestImpl(
            request,
            loginHint: loginHint,
            completion: completionBlock,
            failure: failureBlock,
            frontDoorBridgeUrl: frontDoorBridgeUrl,
            codeVerifier: codeVerifier
        )
    }

    // MARK: - Native Login Auth Request

    @objc func nativeLoginAuthRequest() -> SFSDKAuthRequest {
        let nativeLoginManager = SalesforceSDKManager.shared.nativeLoginManager as? NativeLoginManagerInternal
        let request = SFSDKAuthRequest()
        request.loginHost = nativeLoginManager?.loginUrl ?? loginHost
        request.additionalOAuthParameterKeys = additionalOAuthParameterKeys
        request.oauthClientId = nativeLoginManager?.clientId ?? oauthClientID
        request.oauthCompletionUrl = nativeLoginManager?.redirectUri ?? oauthCompletionURL
        request.scene = SFSDKWindowManager.shared.defaultScene()
        return request
    }

    // MARK: - Authenticate on Behalf of SP App

    @objc func authenticateWithRequestOnBehalfOfSpAppImpl(_ request: SFSDKAuthRequest,
                                                          spAppCredentials spAppCreds: OAuthCredentials,
                                                          completion completionBlock: ((SFOAuthInfo, UserAccount?) -> Void)?,
                                                          failure failureBlock: ((SFOAuthInfo, Error) -> Void)?) -> Bool {
        let authSession = SFSDKAuthSession(with: request, credentials: nil, spAppCredentials: spAppCreds)
        authSession.isAuthenticating = true
        authSession.authFailureCallback = failureBlock
        authSession.authSuccessCallback = completionBlock
        authSession.oauthCoordinator.delegate = self
        authSessions[authSession.sceneId] = authSession

        Task { @MainActor in
            await SFSDKWebViewStateManager.removeSessionForcefully()
            authSession.oauthCoordinator.authenticate()
        }
        return (authSessions[authSession.sceneId] as? SFSDKAuthSession)?.isAuthenticating ?? false
    }

    // MARK: - Authenticate Using IDP

    @objc func authenticateUsingIDPImpl(_ request: SFSDKAuthRequest,
                                        completion completionBlock: ((SFOAuthInfo, UserAccount?) -> Void)?,
                                        failure failureBlock: ((SFOAuthInfo, Error) -> Void)?) -> Bool {
        let authSession = SFSDKAuthSession(with: request, credentials: nil)
        authSession.isAuthenticating = true
        authSession.authFailureCallback = failureBlock
        authSession.authSuccessCallback = completionBlock
        authSession.oauthCoordinator.delegate = self
        let sceneId = request.scene?.session.persistentIdentifier ?? ""
        authSessions[sceneId] = authSession

        if request.idpInitiatedAuth && request.userHint != nil {
            // No need to show login selection view
            (authSessions[sceneId] as? SFSDKAuthSession)?.oauthRequest.appDisplayName = appDisplayName
            if let session = authSessions[sceneId] as? SFSDKAuthSession {
                SFSDKIDPAuthHelper.invokeIDPApp(session) { _ in
                    SFSDKCoreLogger.d(type(of: self), message: "Launched IDP App")
                }
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                guard let selectionAction = request.spAppLoginFlowSelectionAction,
                      let controller = selectionAction() else { return }
                controller.selectionFlowDelegate = self
                var options: [AnyHashable: Any] = [:]
                if let userHint = request.userHint {
                    options["user_hint"] = userHint
                }
                controller.appOptions = options
                controller.selectionFlowDelegate = UserAccountManager.shared

                let authWindow = SFSDKWindowManager.shared.authWindow(request.scene)
                let navController = SFSDKNavigationController(rootViewController: controller)
                navController.modalPresentationStyle = .fullScreen

                authWindow.presentWindow(animated: false) {
                    authWindow.viewController?.modalPresentationStyle = .fullScreen
                    authWindow.viewController?.present(navController, animated: true, completion: nil)
                }
            }
        }
        return (authSessions[sceneId] as? SFSDKAuthSession)?.isAuthenticating ?? false
    }

    // MARK: - Authenticate on Behalf of SP App (User)

    @objc func authenticateOnBehalfOfSPAppImpl(_ user: UserAccount,
                                               spAppCredentials: OAuthCredentials,
                                               authRequest request: SFSDKAuthRequest?,
                                               success successBlock: (() -> Void)?,
                                               failure failureBlock: ((Error) -> Void)?) {
        let effectiveRequest = request ?? defaultAuthRequest()

        let authSession = SFSDKAuthSession(with: effectiveRequest, credentials: user.credentials, spAppCredentials: spAppCredentials)
        authSession.oauthCoordinator.delegate = self
        authSession.identityCoordinator?.delegate = self
        authSessions[authSession.sceneId] = authSession

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.dismissAuthViewControllerIfPresent(for: authSession.oauthRequest.scene) { [weak self] in
                guard let self = self else { return }
                if let session = self.authSessions[authSession.sceneId] as? SFSDKAuthSession {
                    session.oauthCoordinator.beginIDPFlow(user, success: successBlock ?? {}, failure: failureBlock ?? { _ in })
                }
            }
        }
    }

    // MARK: - Logged In

    @objc func loggedInImpl(_ fromOffline: Bool, coordinator: SFOAuthCoordinator, notifyDelegatesOfFailure shouldNotify: Bool) {
        if !fromOffline {
            guard let authSession = coordinator.authSession else { return }
            authSession.notifiesDelegatesOfFailure = shouldNotify
            shouldBlockUser(coordinator.credentials) { [weak self] blockUser in
                guard let self = self else { return }
                if blockUser {
                    SFSDKCoreLogger.e(type(of: self), message: "Salesforce integration users are prohibited from successfully authenticating")
                    let error = NSError(domain: kSFOAuthErrorDomain, code: Int(kSFOAuthErrorAccessDenied), userInfo: nil)
                    self.handleFailureImpl(error, session: authSession)
                } else {
                    let identityCoordinator = SFIdentityCoordinator(authSession: authSession)
                    (self.authSessions[authSession.sceneId] as? SFSDKAuthSession)?.identityCoordinator = identityCoordinator
                    identityCoordinator.delegate = self
                    identityCoordinator.initiateIdentityDataRetrieval()
                }
            } errorBlock: { [weak self] error in
                guard let self = self, let authSession = coordinator.authSession else { return }
                self.handleFailureImpl(error as NSError, session: authSession)
            }
        } else {
            if let authSession = coordinator.authSession {
                retrievedIdentityDataImpl(authSession)
            }
        }
    }

    // MARK: - Retrieved Identity Data

    @objc func retrievedIdentityDataImpl(_ authSession: SFSDKAuthSession) {
        // NB: This method is assumed to run after identity data has been refreshed from the service,
        // or otherwise already exists.
        guard let identityCoordinator = authSession.identityCoordinator,
              let idData = identityCoordinator.idData else {
            assertionFailure("Identity data should not be nil/empty at this point.")
            return
        }

        let hasMobilePolicy = idData.mobilePoliciesConfigured
        let lockTimeout = Int(idData.mobileAppScreenLockTimeout)
        let customAttributes = idData.customAttributes
        let hasBioAuthPolicy = customAttributes?[Self.kBiometricAuthenticationPolicyKey] != nil
        var sessionTimeout = Int(truncating: (customAttributes?[Self.kBiometricAuthenticationTimeoutKey] as? NSNumber) ?? 0)
        let bioAuthManager = BiometricAuthenticationManagerInternal.shared

        // Store current user credentials in case they need to be revoked for Biometric Authentication
        let preLoginCredentials = currentUserAccount?.credentials

        // Set session timeout to the lowest value (15 minutes) if not specified.
        if hasBioAuthPolicy && sessionTimeout < 1 {
            sessionTimeout = 15
        }

        dismissAuthViewControllerIfPresent(for: authSession.oauthRequest.scene) { [weak self] in
            guard let self = self else { return }
            self.finalizeAuthCompletion(authSession)

            if authSession.oauthCoordinator.authInfo.authType != .refresh {
                if hasBioAuthPolicy {
                    if bioAuthManager.locked {
                        bioAuthManager.unlockPostProcessing()
                    }

                    SFSDKAppFeatureMarkers.registerAppFeature(kSFAppFeatureBioAuth, forUser: self.currentUserAccount)
                    if let currentUser = self.currentUserAccount {
                        bioAuthManager.storePolicy(userAccount: currentUser, hasMobilePolicy: hasBioAuthPolicy, sessionTimeout: Int32(sessionTimeout))
                    }

                    if !bioAuthManager.hasBiometricOptedIn() && bioAuthManager.automaticPresentation {
                        if let topVC = SFSDKWindowManager.shared.mainWindow(authSession.oauthRequest.scene).topViewController() {
                            bioAuthManager.presentOptInDialog(viewController: topVC)
                        }
                    }

                    if let preCreds = preLoginCredentials,
                       let currentRefresh = self.currentUserAccount?.credentials.refreshToken,
                       preCreds.refreshToken != currentRefresh {
                        let authClient = self.authClient()
                        authClient.revokeRefreshToken(preCreds, reason: .refreshTokenRotated)
                    }
                } else if hasMobilePolicy {
                    SFSDKAppFeatureMarkers.registerAppFeature(kSFAppFeatureScreenLock, forUser: self.currentUserAccount)
                    if let currentUser = self.currentUserAccount {
                        ScreenLockManagerInternal.shared.storeMobilePolicy(userAccount: currentUser, hasMobilePolicy: hasMobilePolicy, lockTimeout: Int32(lockTimeout))
                    }
                }
            }
        }
        dismissAuthViewControllerIfPresent()
    }

    // MARK: - Handle Failure

    @objc func handleFailureImpl(_ error: NSError, session authSession: SFSDKAuthSession) {
        if let failureCallback = authSession.authFailureCallback {
            failureCallback(authSession.oauthCoordinator.authInfo, error)
        }

        if authSession.notifiesDelegatesOfFailure {
            var errorWasHandledByDelegate = false
            enumerateDelegates { [weak self] delegate in
                guard let self = self else { return }
                if let handled = delegate.userAccountManager?(accountManager: self, didFailAuthenticationWith: error, info: authSession.oauthCoordinator.authInfo) {
                    errorWasHandledByDelegate = errorWasHandledByDelegate || handled
                }
            }

            if !errorWasHandledByDelegate {
                let errorWasHandledBySDK = errorManager?.processAuthError(error, authContext: authSession, options: nil) ?? false
                if !errorWasHandledBySDK {
                    SFSDKCoreLogger.e(type(of: self), message: "Unhandled Error during authentication. Handle the error using [SFUserAccountManagerDelegate userAccountManager:error:info:] and return true. \(error.localizedDescription)")
                }
            }
        }
        resetAuthenticationForSession(authSession)
    }

    // MARK: - Reset Authentication

    @objc func resetAllAuthentication() {
        accountsLock.lock()
        let allKeys = authSessions.allKeys
        for key in allKeys {
            guard let sceneIdStr = key as? String,
                  let authSession = authSessions[sceneIdStr] as? SFSDKAuthSession else { continue }
            if authSession.oauthCoordinator.authInfo.authType == .userAgent {
                authSession.oauthCoordinator.view.removeFromSuperview()
            }
            let sceneId = authSession.sceneId
            (authSessions[sceneId] as? SFSDKAuthSession)?.oauthCoordinator.stopAuthentication()
            (authSessions[sceneId] as? SFSDKAuthSession)?.identityCoordinator?.idData = nil
            (authSessions[sceneId] as? SFSDKAuthSession)?.isAuthenticating = false
            authSessions.removeObject(forKey: sceneId)
        }
        accountsLock.unlock()
    }

    @objc func resetAuthenticationForSession(_ authSession: SFSDKAuthSession) {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.resetAuthenticationForSession(authSession)
            }
            return
        }

        accountsLock.lock()
        if authSession.oauthCoordinator.authInfo.authType == .userAgent {
            authSession.oauthCoordinator.view.removeFromSuperview()
        }
        let sceneId = authSession.sceneId
        (authSessions[sceneId] as? SFSDKAuthSession)?.oauthCoordinator.stopAuthentication()
        (authSessions[sceneId] as? SFSDKAuthSession)?.identityCoordinator?.idData = nil
        (authSessions[sceneId] as? SFSDKAuthSession)?.isAuthenticating = false
        authSessions.removeObject(forKey: sceneId)
        accountsLock.unlock()
    }

    // MARK: - Finalize Auth Completion

    @objc func finalizeAuthCompletion(_ authSession: SFSDKAuthSession) {
        // Apply the credentials that will ensure there is a user and that this
        // current user has the proper credentials.
        guard let coordinatorCredentials = authSession.oauthCoordinator.credentials,
              let userAccount = applyCredentials(coordinatorCredentials, withIdData: authSession.identityCoordinator?.idData) else {
            return
        }

        let loginStateTransitionSucceeded = userAccount.transitionToLoginState(.loggedIn)
        if !loginStateTransitionSucceeded {
            // We're in an unlikely, but nevertheless bad state. Fail this authentication.
            SFSDKCoreLogger.e(type(of: self), message: "\(#function): Unable to transition user to a logged in state. Login failed.")
            let reason = "Unable to transition user to a logged in state. Login failed "
            SFSDKCoreLogger.w(type(of: self), message: reason)
            let error = NSError(domain: "SFUserAccountManager", code: 1005, userInfo: [NSLocalizedDescriptionKey: reason])
            authSession.notifiesDelegatesOfFailure = true
            handleFailureImpl(error, session: authSession)
            return
        }

        // Notify the session is ready.
        initAnalyticsManager()
        handleAnalyticsAddUserEvent(authSession, account: userAccount)

        // Promote auth-method feature flags to the now-known user account.
        // Write the per-user flag and clear the transient global flag so it does not
        // bleed into other users' User-Agent strings.
        let completedAuthType = authSession.oauthCoordinator.authInfo.authType
        if completedAuthType == .advancedBrowser {
            SFSDKAppFeatureMarkers.registerAppFeature(kSFAppFeatureSafariBrowserForLogin, forUser: userAccount)
        } else {
            SFSDKAppFeatureMarkers.unregisterAppFeature(kSFAppFeatureSafariBrowserForLogin, forUser: userAccount)
        }
        SFSDKAppFeatureMarkers.unregisterAppFeature(kSFAppFeatureSafariBrowserForLogin)
        if completedAuthType != .refresh {
            // Check the transient global flag rather than re-deriving from credentials.domain, which by
            // this point has been replaced with the resolved org domain (no longer contains "/discovery").
            let usedWelcomeDiscovery = SFSDKAppFeatureMarkers.appFeatures().contains(kSFAppFeatureWelcomeDiscovery)
            if usedWelcomeDiscovery {
                SFSDKAppFeatureMarkers.registerAppFeature(kSFAppFeatureWelcomeDiscovery, forUser: userAccount)
            } else {
                SFSDKAppFeatureMarkers.unregisterAppFeature(kSFAppFeatureWelcomeDiscovery, forUser: userAccount)
            }
            // WD: clear the transient global flag after promoting to per-user
            SFSDKAppFeatureMarkers.unregisterAppFeature(kSFAppFeatureWelcomeDiscovery)

            // QR: write per-user and clear the transient global flag
            let usedQrLogin = SFSDKAppFeatureMarkers.appFeatures().contains(kSFAppFeatureQrCodeLogin)
            if usedQrLogin {
                SFSDKAppFeatureMarkers.registerAppFeature(kSFAppFeatureQrCodeLogin, forUser: userAccount)
                SFSDKAppFeatureMarkers.unregisterAppFeature(kSFAppFeatureQrCodeLogin)
            } else {
                SFSDKAppFeatureMarkers.unregisterAppFeature(kSFAppFeatureQrCodeLogin, forUser: userAccount)
            }
        }

        // Async call, ignore if there's a failure. If success save the user photo locally.
        retrieveUserPhotoIfNeededImpl(userAccount)
        var shouldNotify = true

        if currentUserAccount == nil || !authSession.oauthRequest.authenticateRequestFromSPApp {
            setCurrentUserInternalFull(userAccount)
        }

        shouldNotify = authSession.oauthRequest.authenticateRequestFromSPApp
            ? (authSession.oauthRequest.authenticateRequestFromSPApp && currentUserAccount == nil)
            : true

        let authInfo = authSession.oauthCoordinator.authInfo

        if let successCallback = authSession.authSuccessCallback {
            successCallback(authInfo, userAccount)
        }

        // Notify for all login flows except during an SP app's login request.
        if shouldNotify {
            notifyLoginCompletion(userAccount, authInfo: authInfo)
        }

        if !authSession.oauthRequest.authenticateRequestFromSPApp {
            resetAllAuthentication()
        }
    }

    // MARK: - Notify Login Completion

    @objc func notifyLoginCompletion(_ userAccount: UserAccount, authInfo: SFOAuthInfo) {
        let userInfo: [String: Any] = [
            Self.userInfoAccountKey: userAccount,
            Self.userInfoAuthenticationTypeKey: authInfo
        ]

        if authInfo.authType == .refresh {
            NotificationCenter.default.post(name: .SFUserAccountManagerDidRefreshToken, object: self, userInfo: userInfo)
        } else if authInfo.authType == .refreshTokenMigration {
            NotificationCenter.default.post(name: .SFUserAccountManagerDidMigrateRefreshToken, object: self, userInfo: userInfo)
        } else {
            NotificationCenter.default.post(name: .SFUserAccountManagerDidLogInUser, object: self, userInfo: userInfo)
        }
    }

    // MARK: - Retrieve User Photo

    @objc func retrieveUserPhotoIfNeededImpl(_ account: UserAccount) {
        guard let thumbnailUrl = account.idData?.thumbnailUrl else { return }

        var request = URLRequest(url: thumbnailUrl)
        request.httpMethod = "GET"
        if let accessToken = account.credentials.accessToken {
            request.setValue(String(format: Self.kHttpAuthHeaderFormatString, accessToken), forHTTPHeaderField: Self.kHttpHeaderAuthorization)
        }

        let network = Network.sharedEphemeralInstance()
        _ = network.sendRequest(request) { data, _, error in
            if let error = error {
                SFSDKCoreLogger.w(type(of: self), message: "Error while trying to retrieve user photo: \((error as NSError).code) \(error.localizedDescription)")
                return
            }
            if let data = data {
                let photo = UIImage(data: data)
                account.setPhoto(photo, completion: nil)
            }
        }
    }

    // MARK: - Analytics

    @objc func handleAnalyticsAddUserEvent(_ authSession: SFSDKAuthSession, account userAccount: UserAccount) {
        if authSession.oauthCoordinator.authInfo.authType == .refresh {
            SFSDKEventBuilderHelper.createAndStoreEvent("tokenRefresh", userAccount: userAccount, className: String(describing: type(of: self)), attributes: nil)
        } else {
            // Logging events for add user and number of servers.
            let accounts = userAccounts()
            var userAttributes: [String: Any] = [:]
            userAttributes["numUsers"] = NSNumber(value: accounts?.count ?? 0)
            SFSDKEventBuilderHelper.createAndStoreEvent("addUser", userAccount: userAccount, className: String(describing: type(of: self)), attributes: userAttributes)

            let numHosts = SFSDKLoginHostStorage.sharedInstance.numberOfLoginHosts
            var hosts: [String] = []
            for i in 0..<numHosts {
                let host = SFSDKLoginHostStorage.sharedInstance.loginHost(at: i)
                hosts.append(host.host)
            }
            var serverAttributes: [String: Any] = [:]
            serverAttributes["numLoginServers"] = NSNumber(value: numHosts)
            serverAttributes["loginServers"] = hosts
            SFSDKEventBuilderHelper.createAndStoreEvent("addUser", userAccount: nil, className: String(describing: type(of: self)), attributes: serverAttributes)
        }
    }

    @objc func initAnalyticsManager() {
        guard let currentUser = currentUserAccount else { return }
        let analyticsManager = SFSDKSalesforceAnalyticsManager.sharedInstance(with: currentUser)
        analyticsManager?.updateLoggingPrefs()
    }

    // MARK: - Scene Disconnect

    @objc func sceneDidDisconnectHandler(_ notification: Notification) {
        guard let scene = notification.object as? UIScene else { return }
        authSessions.removeObject(forKey: scene.session.persistentIdentifier)
    }

    // MARK: - Post Push Unregistration (Logout continuation)

    @objc func postPushUnregistrationImpl(_ user: UserAccount, logoutReason reason: SFLogoutReason) {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.postPushUnregistrationImpl(user, logoutReason: reason)
            }
            return
        }

        SFSDKCoreLogger.d(type(of: self), message: "Logging out user '\(user.idData?.username ?? "")'.")

        // Save for use with didLogout notification
        let userId = user.credentials.userId
        let orgId = user.credentials.organizationId
        let communityId = user.credentials.communityId
        let logoutReasonNumber = NSNumber(value: reason.rawValue)

        let userInfo: [String: Any] = [
            Self.userInfoAccountKey: user,
            Self.userInfoLogoutReasonKey: logoutReasonNumber
        ]
        NotificationCenter.default.post(name: .SFUserAccountManagerWillLogoutUser, object: self, userInfo: userInfo)

        _ = delete(user)
        let authClientInstance = authClient()
        authClientInstance.revokeRefreshToken(user.credentials, reason: reason)

        let isCurrentUser = (user == currentUserAccount)
        if isCurrentUser {
            setCurrentUserInternalFull(nil)
        }

        MainActor.assumeIsolated {
            SFSDKWebViewStateManager.resetSessionCookie()
        }

        // Restore these IDs to enable post-logout cleanup of components
        user.credentials.setValue(userId, forKey: "userId")
        user.credentials.setValue(orgId, forKey: "organizationId")
        user.credentials.setValue(communityId, forKey: "communityId")

        let logoutNotification = Notification(name: .SFUserAccountManagerDidLogoutUser, object: self, userInfo: userInfo)
        NotificationCenter.default.post(logoutNotification)

        // Post a notification if all users of the given org have logged out.
        if let orgId = orgId, !orgHasLoggedInUsers(orgId) {
            let sfUserInfo = SFNotificationUserInfo(user: user)
            let notificationUserInfo: [String: Any] = [Self.userInfoSfUserInfoKey: sfUserInfo]
            let orgLogoutNotification = Notification(name: .SFUserAccountManagerDidLogoutOrg, object: self, userInfo: notificationUserInfo)
            NotificationCenter.default.post(orgLogoutNotification)
        }

        // NB: There's no real action that can be taken if this login state transition fails.
        _ = user.transitionToLoginState(.notLoggedIn)
        dismissAuthViewControllerIfPresent()
    }

    // MARK: - Should Block User

    @objc func shouldBlockUser(_ credentials: OAuthCredentials?,
                               completion: @escaping (Bool) -> Void,
                               errorBlock: @escaping (Error) -> Void) {
        guard SalesforceSDKManager.shared.blockSalesforceIntegrationUser else {
            completion(false)
            return
        }

        guard let credentials = credentials,
              let instanceUrl = credentials.instanceUrl else {
            completion(false)
            return
        }

        let url = instanceUrl.appendingPathComponent("/services/oauth2/userinfo")
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.httpMethod = "GET"
        request.httpShouldHandleCookies = false
        if let accessToken = credentials.accessToken {
            request.setValue(String(format: Self.kHttpAuthHeaderFormatString, accessToken), forHTTPHeaderField: Self.kHttpHeaderAuthorization)
        }

        let networkIdentifier = Network.uniqueInstanceIdentifier()
        let network = Network.sharedEphemeralInstance(withIdentifier: networkIdentifier)
        _ = network.sendRequest(request) { data, _, error in
            if let error = error {
                errorBlock(error)
            } else if let data = data {
                let userInfoDict = SFJsonUtils.object(fromJSONData: data) as? [String: Any]
                let isIntegrationUser = (userInfoDict?["is_salesforce_integration_user"] as? NSNumber)?.boolValue ?? false
                completion(isIntegrationUser)
            } else {
                completion(false)
            }
            Network.removeSharedInstance(forIdentifier: networkIdentifier)
        }
    }
}

// MARK: - Switching Users

extension UserAccountManager {

    @objc func switchToNewUserWithCompletionImpl(_ completion: @escaping (Error?, UserAccount?) -> Void) {
        let prevUser = currentUserAccount
        let nativeLoginFallback = nativeLoginEnabled && shouldFallbackToWebAuthentication

        if currentUserAccount == nil && !nativeLoginFallback {
            let error = NSError(
                domain: kSFSDKUserAccountManagerErrorDomain,
                code: Int(SFSDKUserAccountManagerErrorCode.error.rawValue),
                userInfo: [NSLocalizedDescriptionKey: "Cannot switch to new user. No currentUser has been set."]
            )
            completion(error, nil)
        } else {
            stopCurrentAuthentication { [weak self] _ in
                guard let self = self else { return }
                _ = self.loginWithCompletion({ [weak self] authInfo, userAccount in
                    guard let self = self else { return }
                    self.fireNotificationForSwitchUser(from: prevUser, to: userAccount)
                    completion(nil, userAccount)
                }, failure: { _, error in
                    completion(error, nil)
                })
            }
        }
    }

    @objc func switchToUserImpl(_ newCurrentUser: UserAccount?) {
        guard let newCurrentUser = newCurrentUser else { return }

        let bioAuthManager = BiometricAuthenticationManagerInternal.shared
        let screenLockManager = ScreenLockManagerInternal.shared

        if let userId = newCurrentUser.credentials.userId {
            if bioAuthManager.checkForPolicy(userId: userId) {
                bioAuthManager.lock()
            } else if screenLockManager.checkForPolicy(userId: userId) {
                screenLockManager.lock()
            }
        }

        if let currentIdentity = currentUserAccount?.accountIdentity,
           currentIdentity.isEqual(newCurrentUser.accountIdentity) {
            SFSDKCoreLogger.w(type(of: self), message: "\(#function) new user identity is the same as the current user. No action taken.")
        } else {
            fireNotificationForSwitchUser(from: currentUserAccount, to: newCurrentUser)
        }
    }

    @objc func fireNotificationForSwitchUser(from fromUser: UserAccount?, to toUser: UserAccount?) {
        enumerateDelegates { delegate in
            if let from = fromUser {
                delegate.userAccountManager?(accountManager: self, willSwitchFrom: from, to: toUser)
            }
        }

        var userInfo: [String: Any] = [:]
        userInfo[Self.userInfoFromUserKey] = fromUser ?? NSNull()
        userInfo[Self.userInfoToUserKey] = toUser ?? NSNull()
        NotificationCenter.default.post(name: .SFUserAccountManagerWillSwitchUser, object: self, userInfo: userInfo)

        setCurrentUserInternalFull(toUser)

        enumerateDelegates { delegate in
            if let from = fromUser {
                delegate.userAccountManager?(accountManager: self, didSwitchFrom: from, to: toUser)
            }
        }
        NotificationCenter.default.post(name: .SFUserAccountManagerDidSwitchUser, object: self, userInfo: userInfo)
    }
}

// MARK: - User Change Notifications

extension UserAccountManager {

    // Not `@objc`: `AccountDataChange` is an `OptionSet` (not ObjC-representable) and this method has
    // no ObjC callers. The notification's userInfo still carries the raw `UInt` mask for any consumer.
    func notifyUserDataChange(_ notificationName: NSNotification.Name, withUser user: UserAccount, andChange change: UserAccount.AccountDataChange) {
        let userInfo: [String: Any] = [
            Self.changeSetKey: NSNumber(value: change.rawValue)
        ]
        NotificationCenter.default.post(name: notificationName, object: user, userInfo: userInfo)
    }

    @objc func notifyUserChange(_ notificationName: NSNotification.Name, withUser user: UserAccount?, andChange change: UserAccount.AccountChange) {
        var userInfo: [String: Any] = [
            Self.changeSetKey: NSNumber(value: change.rawValue)
        ]
        if let user = user {
            userInfo[Self.userInfoUserKey] = user
        }
        NotificationCenter.default.post(name: notificationName, object: self, userInfo: userInfo)
    }

    @objc func notifyUserCancelledOrDismissedAuthImpl(_ credentials: OAuthCredentials, andAuthInfo info: SFOAuthInfo?) {
        var userInfo: [String: Any] = [Self.userInfoCredentialsKey: credentials]
        if let info = info {
            userInfo[Self.userInfoAuthenticationTypeKey] = info
        }
        NotificationCenter.default.post(name: .SFUserAccountManagerUserCancelledAuthentication, object: self, userInfo: userInfo)
    }

    @objc func reloadImpl() {
        accountsLock.lock()
        if accountPersister == nil {
            accountPersister = SFDefaultUserAccountPersister()
        }
        _ = loadAllUserAccounts()
        accountsLock.unlock()
    }

    // MARK: - Set Current User Internal (Full Implementation)

    /// Full implementation of setCurrentUserInternal with biometric auth checks.
    @objc func setCurrentUserInternalFull(_ user: UserAccount?) {
        var userChanged = false
        if user !== _currentUser {
            accountsLock.lock()
            if user == nil {
                // Clear current user if nil
                willChangeValue(forKey: "currentUser")
                _currentUser = nil
                setCurrentUserIdentityInternal(nil)
                didChangeValue(forKey: "currentUser")
                userChanged = true
            } else if let user = user {
                // Check if this is a valid managed user
                let managedAccount = userAccount(for: user.accountIdentity)
                if managedAccount != nil {
                    willChangeValue(forKey: "currentUser")
                    _currentUser = user
                    setCurrentUserIdentityInternal(user.accountIdentity)

                    let isNativeLogin = nativeLoginEnabled && !shouldFallbackToWebAuthentication
                    // Native Login uses a secondary Connected App tied to a specific community URL.
                    // If the next login is web based it should not try to use that URL.
                    // Also skip if the app uses a Welcome/Discovery domain — persisting the My Domain
                    // would pollute the server picker and prevent returning to the discovery page on logout.
                    let isDiscoveryLogin = DomainDiscoveryCoordinator.isDiscoveryDomain(loginHost)
                    if let domain = user.credentials.domain, !isNativeLogin, !isDiscoveryLogin {
                        loginHost = domain
                    }
                    didChangeValue(forKey: "currentUser")
                    userChanged = true
                } else {
                    SFSDKCoreLogger.e(type(of: self), message: "Cannot set the currentUser. Add the account to the SFAccountManager before making this call.")
                }
            }
            accountsLock.unlock()
        }

        if userChanged {
            notifyUserChange(.SFUserAccountManagerDidChangeUser, withUser: _currentUser, andChange: .currentUser)

            let bioAuthManager = BiometricAuthenticationManagerInternal.shared
            if bioAuthManager.enabled {
                if let keys = userAccountMap?.allKeys as? [UserAccountIdentity] {
                    for identity in keys {
                        // Logout any other user with Biometric Authentication.
                        // This is an unexpected logout because we only support one Bio Auth user.
                        let userId = identity.userId
                        if bioAuthManager.checkForPolicy(userId: userId),
                           !identity.isEqual(currentUserIdentityValue()) {
                            if let accountToLogout = userAccount(for: identity) {
                                logout(accountToLogout, reason: .unexpected)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Present Login View

extension UserAccountManager {

    @objc func presentLoginViewImpl(_ viewHandler: SFSDKAuthViewHolder) {
        let presentViewBlock: () -> Void = { [weak self] in
            guard let self = self else { return }

            if self.nativeLoginEnabled && !self.shouldFallbackToWebAuthentication {
                let sceneKey = (viewHandler.scene?.session.persistentIdentifier ?? "") as NSString
                let multiWindowNativeLoginVC = SalesforceSDKManager.shared.nativeLoginViewControllers[sceneKey] as? UIViewController
                let nativeLogin = multiWindowNativeLoginVC ?? (SalesforceSDKManager.shared.nativeLoginViewControllers["defaultKey" as NSString] as? UIViewController)
                guard let nativeLoginVC = nativeLogin else { return }
                let controllerToPresent = SFSDKNavigationController(rootViewController: nativeLoginVC)
                // Hide the nav bar for custom native login views. SFLoginViewController hides it
                // internally, but custom VCs don't — without this, a Salesforce-blue nav bar appears
                // on top of the native login view on re-presentation (e.g. after fallback to web auth).
                controllerToPresent.setNavigationBarHidden(true, animated: false)
                controllerToPresent.modalPresentationStyle = .fullScreen
                SFSDKWindowManager.shared.authWindow(viewHandler.scene).viewController?.present(controllerToPresent, animated: false, completion: {})
            } else if !viewHandler.isAdvancedAuthFlow {
                let loginController = viewHandler.loginController
                let controllerToPresent = SFSDKNavigationController(rootViewController: loginController)
                if !(self.nativeLoginEnabled && self.shouldFallbackToWebAuthentication) {
                    controllerToPresent.modalPresentationStyle = .fullScreen
                }
                SFSDKWindowManager.shared.authWindow(viewHandler.scene).viewController?.present(controllerToPresent, animated: false, completion: {
                    assert(loginController.oauthView?.superview != nil, "No superview for oauth web view invoke [super viewDidLayoutSubviews] in the SFLoginViewController subclass")
                })
            } else {
                let authRootController = SFSDKAuthRootController()
                SFSDKWindowManager.shared.authWindow(viewHandler.scene).viewController = authRootController
                authRootController.modalPresentationStyle = .fullScreen
                if let presentationProvider = SFSDKWindowManager.shared.authWindow(viewHandler.scene).viewController as? ASWebAuthenticationPresentationContextProviding {
                    viewHandler.session?.presentationContextProvider = presentationProvider
                }
                viewHandler.session?.start()
            }
        }

        let presentWindowBlock: () -> Void = { [weak self] in
            guard let self = self else { return }
            SFSDKWindowManager.shared.authWindow(viewHandler.scene).presentWindow()

            // Dismiss if already presented and then present
            let presentedViewController = SFSDKWindowManager.shared.authWindow(viewHandler.scene).viewController?.presentedViewController
            if self.isAlreadyPresentingLoginController(presentedViewController) {
                presentedViewController?.dismiss(animated: false, completion: {
                    presentViewBlock()
                })
            } else {
                presentViewBlock()
            }
        }

        #if os(visionOS)
        presentWindowBlock()
        #else
        if let scene = viewHandler.scene, SalesforceSDKManager.shared.isSnapshotPresented(scene) {
            SalesforceSDKManager.shared.dismissSnapshot(scene) {
                presentWindowBlock()
            }
        } else {
            presentWindowBlock()
        }
        #endif
    }

    @objc func isAlreadyPresentingLoginController(_ presentedViewController: UIViewController?) -> Bool {
        guard let presented = presentedViewController,
              !presented.isBeingDismissed,
              let navController = presented as? SFSDKNavigationController,
              navController.topViewController is SalesforceLoginViewController else {
            return false
        }
        return true
    }

    @objc func createLoginViewControllerInstanceImpl(_ coordinator: SFOAuthCoordinator) -> SalesforceLoginViewController {
        let controller: SalesforceLoginViewController
        if let creationBlock = coordinator.authSession?.oauthRequest.loginViewControllerConfig.loginViewControllerCreationBlock {
            controller = creationBlock()
        } else {
            controller = SalesforceLoginViewController(nibName: nil, bundle: nil)
        }
        if let config = coordinator.authSession?.oauthRequest.loginViewControllerConfig {
            controller.config = config
        }
        controller.delegate = self
        return controller
    }
}
