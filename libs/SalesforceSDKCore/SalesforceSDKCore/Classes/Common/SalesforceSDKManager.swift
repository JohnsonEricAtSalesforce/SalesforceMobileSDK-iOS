// SalesforceSDKManager.swift
// SalesforceSDKCore
//
// Copyright (c) 2014-present, salesforce.com, inc. All rights reserved.
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
import WebKit
import SalesforceSDKCommon

// MARK: - Enums (formerly in SalesforceSDKManager.h)

/// App type enum — corresponds to the ObjC SFAppType.
@objc(SFAppType)
public enum SFAppType: UInt {
    case native = 0
    case hybrid
    case reactNative
    case nativeSwift
}

/// URL cache type enum — corresponds to the ObjC SFURLCacheType.
@objc(SFURLCacheType)
public enum SFURLCacheType: UInt {
    case encrypted = 1
    case null
    case standard
}

// MARK: - Snapshot Block Types

/// Block that creates a snapshot view controller for app backgrounding.
public typealias SFSnapshotViewControllerCreationBlock = () -> UIViewController?
/// Block that presents a snapshot view controller.
public typealias SFSnapshotViewControllerPresentationBlock = (UIViewController) -> Void
/// Block that dismisses a snapshot view controller.
public typealias SFSnapshotViewControllerDismissalBlock = (UIViewController) -> Void

// Error constants (defined in SalesforceSDKCoreDefines.swift)

// Notification constants
public let kSFScreenLockFlowWillBegin = "SFScreenLockFlowWillBegin"
public let kSFScreenLockFlowCompleted = "SFScreenLockFlowCompleted"
public let kSFBiometricAuthenticationFlowWillBegin = "SFBiometricAuthenticationFlowWillBegin"
public let kSFBiometricAuthenticationFlowCompleted = "SFBiometricAuthenticationFlowCompleted"

// SDK Version (mirrors the ObjC SALESFORCE_SDK_VERSION macro from SalesforceSDKConstants.h)
let SALESFORCE_SDK_VERSION: String = {
    let versionNum = 140000 // __SALESFORCE_SDK_14_0_0
    let major = versionNum / 10000
    let minor = (versionNum % 10000) / 100
    let patch = (versionNum % 10000) % 100
    return "\(major).\(minor).\(patch)"
}()

// User agent constants
private let kSFMobileSDKNativeDesignator = "Native"
private let kSFMobileSDKHybridDesignator = "Hybrid"
private let kSFMobileSDKReactNativeDesignator = "ReactNative"
private let kSFMobileSDKNativeSwiftDesignator = "NativeSwift"
private let kWebViewUserAgentKey = "web_view_user_agent"

// URL cache
private let kDefaultCacheMemoryCapacity = 1024 * 1024 * 4  // 4MB
private let kDefaultCacheDiskCapacity = 1024 * 1024 * 20   // 20MB

// Dev support
private let SFSDKShowDevDialogNotification = "SFSDKShowDevDialogNotification"

private let kSFDefaultNativeLoginViewControllerKey = "defaultKey"

/// SnapshotViewController for background security view.
@available(visionOS, unavailable)
@objc(SnapshotViewController)
@objcMembers
public class SnapshotViewController: UIViewController {
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.frame = UIScreen.main.bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.backgroundColor = UIColor.salesforceSystemBackgroundColor
    }

    public override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .all
    }
}

/// DevAction for dev support dialog.
@objc(SFSDKDevAction)
@objcMembers
public class DevAction: NSObject {
    @objc public let name: String
    @objc public var handler: () -> Void

    @objc public init(name: String, handler: @escaping () -> Void) {
        self.name = name
        self.handler = handler
        super.init()
    }
}

/// Gets a string description for an SFAppType value.
public func SFAppTypeGetDescription(_ appType: SFAppType) -> String {
    switch appType {
    case .native: return kSFMobileSDKNativeDesignator
    case .hybrid: return kSFMobileSDKHybridDesignator
    case .reactNative: return kSFMobileSDKReactNativeDesignator
    case .nativeSwift: return kSFMobileSDKNativeSwiftDesignator
    @unknown default: return kSFMobileSDKNativeDesignator
    }
}

/// Swift-name compatibility. Prior SDK releases exposed this class to Swift as `SalesforceManager`
/// via `NS_SWIFT_NAME(SalesforceManager)` on the Objective-C `SalesforceSDKManager` interface. The
/// ObjC→Swift migration kept the native Swift name `SalesforceSDKManager`, dropping the historical
/// `SalesforceManager` Swift spelling. This typealias restores source compatibility for Swift
/// consumers (and the sample apps).
public typealias SalesforceManager = SalesforceSDKManager

/// This class manages the basic infrastructure of the Mobile SDK elements of the app.
@objc(SalesforceSDKManager)
@objcMembers
open class SalesforceSDKManager: NSObject {

    // MARK: - Static properties

    private static var instanceClass: AnyClass?
    private static var uid: String = ""
    private static let ailtnAppNameLock = NSRecursiveLock()
    private static var _ailtnAppName: String?
    private static let appNameLock = NSRecursiveLock()
    private static var _appName: String?
    private static var nativeLogin: NativeLoginManagerInternal?

    @objc public class var ailtnAppName: String? {
        get { return _ailtnAppName }
        set {
            ailtnAppNameLock.lock()
            defer { ailtnAppNameLock.unlock() }
            if let name = newValue { _ailtnAppName = name }
        }
    }

    @objc public class var appName: String? {
        get { return _appName }
        set {
            appNameLock.lock()
            defer { appNameLock.unlock() }
            if let name = newValue { _appName = name }
        }
    }

    @objc public class var shared: SalesforceSDKManager {
        return sharedInstance
    }

    private static let sharedInstance: SalesforceSDKManager = {
        uid = UIDevice.current.identifierForVendor?.uuidString ?? ""

        // Set default app names if not already set
        if _ailtnAppName == nil {
            _ailtnAppName = Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String
        }
        if _appName == nil {
            _appName = Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String
        }

        let manager: SalesforceSDKManager
        if let cls = instanceClass as? SalesforceSDKManager.Type {
            manager = cls.init()
        } else {
            manager = SalesforceSDKManager()
        }

        if SFSwiftDetectUtil.isSwiftApp() {
            SFSDKAppFeatureMarkers.registerAppFeature(kSFAppFeatureSwiftApp)
        }
        if SFSDKMacDetectUtil.isOnMac() {
            SFSDKAppFeatureMarkers.registerAppFeature(kSFAppFeatureMacApp)
        }
        if (UserAccountManager.shared.userIdentities()?.count ?? 0) > 1 {
            SFSDKAppFeatureMarkers.registerAppFeature(kSFAppFeatureMultiUser)
        } else {
            SFSDKAppFeatureMarkers.unregisterAppFeature(kSFAppFeatureMultiUser)
        }
        manager.hydratePerUserFeatureFlags()
        return manager
    }()

    @objc public class func setInstanceClass(_ className: AnyClass?) {
        instanceClass = className
    }

    @objc open class func initializeSDK() {
        initializeSDK(manager: instanceClass)
    }

    @objc public class func initializeSDK(manager className: AnyClass?) {
        setInstanceClass(className)

        #if DEBUG
        // For debug app builds only, use test instant log in if applicable.
        let arguments = ProcessInfo.processInfo.arguments
        if let credsIndex = arguments.firstIndex(of: "-creds"), credsIndex + 1 < arguments.count {
            let creds = arguments[credsIndex + 1]
            TestSetupUtils.populateAuthCredentials(fromString: creds, initializeSdk: false)
            TestSetupUtils.synchronousAuthRefresh(withUserDidLoginNotification: true)
        }
        #endif

        _ = SalesforceSDKManager.shared
    }

    // MARK: - Instance properties

    @objc public var appConfig: BootConfig? {
        get {
            if _appConfig == nil {
                _appConfig = BootConfig.fromDefaultConfigFile() ?? BootConfig(dict: NSDictionary())
            }
            return _appConfig
        }
        set { _appConfig = newValue }
    }
    // Alias for ObjC compatibility
    @objc public var bootConfig: BootConfig? {
        get { return appConfig }
        set { appConfig = newValue }
    }
    private var _appConfig: BootConfig?

    @objc public var appType: SFAppType {
        if NSClassFromString("SFHybridViewController") != nil {
            return .hybrid
        }
        if NSClassFromString("SFNetReactBridge") != nil {
            return .reactNative
        }
        return .native
    }

    @objc public var brandLoginPath: String? {
        get { UserAccountManager.shared.brandLoginPath }
        set { UserAccountManager.shared.brandLoginPath = newValue }
    }

    @objc public var useSnapshotView: Bool = !SFSDKMacDetectUtil.isOnMac()

    @objc public var idpLoginFlowSelectionBlock: IDPLoginFlowSelectionBlock? {
        get { UserAccountManager.shared.idpLoginFlowSelectionAction }
        set { UserAccountManager.shared.idpLoginFlowSelectionAction = newValue }
    }

    @objc public var idpUserSelectionBlock: IDPUserSelectionBlock? {
        get { UserAccountManager.shared.idpUserSelectionAction }
        set { UserAccountManager.shared.idpUserSelectionAction = newValue }
    }

    @objc public var snapshotViewControllerCreationAction: SFSnapshotViewControllerCreationBlock?
    @objc public var snapshotPresentationAction: SFSnapshotViewControllerPresentationBlock?
    @objc public var snapshotDismissalAction: SFSnapshotViewControllerDismissalBlock?
    @objc public var userAgentString: UserAgentGeneratorBlock?
    @objc public var appConfigRuntimeSelectorBlock: BootConfigRuntimeSelector?

    @objc public var isIdentityProvider: Bool {
        get { UserAccountManager.shared.isIdentityProvider }
        set { UserAccountManager.shared.isIdentityProvider = newValue }
    }

    @objc public var idpAppURIScheme: String? {
        get { UserAccountManager.shared.idpAppURIScheme }
        set { UserAccountManager.shared.idpAppURIScheme = newValue }
    }

    @objc public var appDisplayName: String? {
        get {
            let name = UserAccountManager.shared.appDisplayName
            return name.isEmpty ? nil : name
        }
        set { UserAccountManager.shared.appDisplayName = newValue ?? "" }
    }

    @objc public var idpEnabled: Bool {
        return UserAccountManager.shared.idpAppURIScheme != nil
    }

    @objc public var isDevSupportEnabled: Bool = false {
        didSet {
            if isDevSupportEnabled {
                NotificationCenter.default.addObserver(self, selector: #selector(showDevSupportDialog as () -> Void), name: NSNotification.Name(SFSDKShowDevDialogNotification), object: nil)
            } else {
                NotificationCenter.default.removeObserver(self, name: NSNotification.Name(SFSDKShowDevDialogNotification), object: nil)
            }
        }
    }

    @objc public var isLoginWebviewInspectable: Bool = false

    #if DEBUG
    @objc public var simulatedDomainDiscoveryResult: SFDomainDiscoveryResult?
    public var bootConfigRuntimeSelector: ((String, @escaping (BootConfig?) -> Void) -> Void)?
    #endif

    @objc public var URLCacheType: SFURLCacheType = .encrypted {
        didSet {
            guard URLCacheType != oldValue else { return }
            installSharedURLCache(for: URLCacheType)
        }
    }

    /// Installs the shared `URLCache` matching the given type. Factored out of the `URLCacheType`
    /// `didSet` so it can also run from `init()`: Swift does not fire property observers when a class
    /// assigns its own stored property inside its own initializer, so the initial `.encrypted`
    /// assignment must install the cache explicitly (the ObjC original did this via its setter).
    private func installSharedURLCache(for type: SFURLCacheType) {
        URLCache.shared.removeAllCachedResponses()
        let cache: URLCache
        switch type {
        case .encrypted:
            cache = SFSDKEncryptedURLCache(memoryCapacity: kDefaultCacheMemoryCapacity, diskCapacity: kDefaultCacheDiskCapacity, cacheDirectory: nil)
        case .null:
            cache = SFSDKNullURLCache(memoryCapacity: kDefaultCacheMemoryCapacity, diskCapacity: kDefaultCacheDiskCapacity, directory: nil)
        case .standard:
            cache = URLCache(memoryCapacity: kDefaultCacheMemoryCapacity, diskCapacity: kDefaultCacheDiskCapacity, directory: nil)
        @unknown default:
            cache = URLCache(memoryCapacity: kDefaultCacheMemoryCapacity, diskCapacity: kDefaultCacheDiskCapacity, directory: nil)
        }
        URLCache.shared = cache
    }

    @objc public var useEphemeralSessionForAdvancedAuth: Bool = true
    @objc public var useWebServerAuthentication: Bool = true
    @objc public var useHybridAuthentication: Bool = true

    /// Non-deprecated internal backing for the deprecated public `forceAdvancedAuthentication`
    /// property. Internal SDK code (e.g. SFOAuthCoordinator, the dev-info dump) reads/writes the
    /// flag through this accessor so its own use does not trip a deprecation warning. This is the
    /// Swift equivalent of upstream's `sdk_forceAdvancedAuthentication` accessor in
    /// SalesforceSDKManager+Internal.h. Delete alongside the public property in 15.0. Defaults to
    /// `true` (Advanced Authentication is the default).
    var forceAdvancedAuthenticationInternal: Bool = true

    /// Whether Advanced Authentication (browser-based OAuth) should always be used for interactive
    /// login, regardless of the target server's My Domain auth-configuration. When `true` (the
    /// default), Advanced Auth is used even on standard login servers such as login.salesforce.com.
    /// When `false`, Advanced Auth is used only when the server's My Domain auth-configuration opts
    /// into it (legacy behavior). Defaults to `true`.
    @available(*, deprecated, message: "Advanced Authentication is becoming mandatory; this flag will be removed in Salesforce Mobile SDK 15.0.")
    @objc public var forceAdvancedAuthentication: Bool {
        get { forceAdvancedAuthenticationInternal }
        set { forceAdvancedAuthenticationInternal = newValue }
    }

    @objc public var blockSalesforceIntegrationUser: Bool = false
    @objc public var customDomainInferencePattern: NSRegularExpression?

    private var snapshotViewControllers = SafeMutableDictionary<NSString, UIViewController>()
    @objc var nativeLoginViewControllers = SFSDKSafeMutableDictionary()
    private var actionSheet: UIAlertController?
    private var webView: WKWebView?
    private var _webViewUserAgent: String?

    // MARK: - Initialization

    public required override init() {
        super.init()
        #if DEBUG
        isDevSupportEnabled = true
        #endif

        NotificationCenter.default.addObserver(self, selector: #selector(handleAppForeground(_:)), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleAppBackground(_:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleAppTerminate(_:)), name: UIApplication.willTerminateNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleSceneWillEnterForeground(_:)), name: UIScene.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleSceneDidActivate(_:)), name: UIScene.didActivateNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleSceneDidEnterBackground(_:)), name: UIScene.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleSceneWillConnect(_:)), name: UIScene.willConnectNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleSceneDidDisconnect(_:)), name: UIScene.didDisconnectNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleAuthCompleted(_:)), name: UserAccountManager.didLogInUser, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleIDPInitiatedAuthCompleted(_:)), name: UserAccountManager.didLogInAfterIDPInit, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleIDPUserAddCompleted(_:)), name: UserAccountManager.willSendIDPResponse, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleUserWillLogout(_:)), name: UserAccountManager.willLogoutUser, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleUserDidLogout(_:)), name: UserAccountManager.didLogoutUser, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(screenLockFlowWillBegin(_:)), name: NSNotification.Name(kSFScreenLockFlowWillBegin), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(screenLockFlowDidComplete(_:)), name: NSNotification.Name(kSFScreenLockFlowCompleted), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(biometricAuthenticationFlowWillBegin(_:)), name: NSNotification.Name(kSFBiometricAuthenticationFlowWillBegin), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(biometricAuthenticationFlowDidComplete(_:)), name: NSNotification.Name(kSFBiometricAuthenticationFlowCompleted), object: nil)

        computeWebViewUserAgent()
        userAgentString = defaultUserAgentString()
        URLCacheType = .encrypted
        // didSet does not fire for a class assigning its own property in its own init, so install
        // the initial cache explicitly (matches the ObjC setter-invoked-in-init behavior).
        installSharedURLCache(for: URLCacheType)
        setupServiceConfiguration()
        SFSDKSalesforceSDKUpgradeManager.upgrade()
        ScreenLockManagerInternal.shared.checkForScreenLockUsers()
    }

    // MARK: - Public methods

    @objc public func deviceId() -> String {
        return SalesforceSDKManager.uid
    }

    @objc public func getAppTypeAsString() -> String {
        return SFAppTypeGetDescription(appType)
    }

    @objc public func showDevSupportDialog(from presentedViewController: UIViewController) {
        guard isDevSupportEnabled, actionSheet == nil else { return }

        let style: UIAlertController.Style = UIDevice.current.userInterfaceIdiom == .phone ? .actionSheet : .alert
        actionSheet = UIAlertController(title: devInfoTitleString(), message: "", preferredStyle: style)
        let devActions = getDevActions(presentedViewController)
        for action in devActions {
            actionSheet?.addAction(UIAlertAction(title: action.name, style: .default) { [weak self] _ in
                action.handler()
                self?.actionSheet = nil
            })
        }
        actionSheet?.addAction(UIAlertAction(title: SFSDKResourceUtils.localizedString("devInfoCancelKey"), style: .cancel) { [weak self] _ in
            self?.actionSheet = nil
        })
        if let actionSheet = actionSheet {
            presentedViewController.present(actionSheet, animated: true, completion: nil)
        }
    }

    @objc public func devInfoTitleString() -> String {
        return SFSDKResourceUtils.localizedString("devInfoTitle")
    }

    @objc open func getDevActions(_ presentedViewController: UIViewController) -> [DevAction] {
        var actions: [DevAction] = []
        let userAccountManager = UserAccountManager.shared
        let currentUser = userAccountManager.currentUserAccount
        // Check if we're showing a login screen. This is the in-app WebView screen
        // (SalesforceLoginViewController) or, in the forced-advanced-auth path where
        // SalesforceLoginViewController is never created, the host list
        // (LoginHostListViewController) the user lands on.
        let isShowingWebViewLogin = presentedViewController is SalesforceLoginViewController
        let isShowingHostList = (presentedViewController as? LoginHostListViewController)?.presentedAsLoginScreen ?? false
        let isShowingLogin = isShowingWebViewLogin || isShowingHostList

        actions.append(DevAction(name: "Show dev info") {
            let devInfo = DevInfoViewController.makeViewController()
            presentedViewController.present(devInfo, animated: true, completion: nil)
        })

        if isShowingLogin {
            actions.append(DevAction(name: "Login Options") {
                let configPicker = LoginOptionsViewController.makeViewController {
                    presentedViewController.dismiss(animated: true) {
                        // Restart authentication with the updated configuration
                        if let loginVC = presentedViewController as? SalesforceLoginViewController {
                            UserAccountManager.shared.restartAuthenticationForViewController(loginVC, recreateAuthRequest: true)
                        } else if let hostListVC = presentedViewController as? LoginHostListViewController {
                            UserAccountManager.shared.hostListViewControllerDidChangeLoginOptions(hostListVC)
                        }
                    }
                }
                presentedViewController.present(configPicker, animated: true, completion: nil)
            })
        }

        if currentUser != nil && !isShowingLogin {
            actions.append(DevAction(name: "Logout") {
                UserAccountManager.shared.logout(.userInitiated)
            })
        }

        if currentUser != nil && !isShowingLogin {
            actions.append(DevAction(name: "Switch user") {
                let umvc = SalesforceUserManagementViewController { action in
                    presentedViewController.dismiss(animated: true, completion: nil)
                }
                presentedViewController.present(umvc, animated: true, completion: nil)
            })
        }

        let hasGlobalStores = KeyValueEncryptedFileStore.allGlobalNames().count > 0
        let hasUserStores = currentUser != nil && KeyValueEncryptedFileStore.allNames().count > 0
        if hasGlobalStores || hasUserStores {
            actions.append(DevAction(name: "Inspect Key-Value Store") {
                let inspector = KeyValueEncryptedFileStoreViewController().createUI()
                presentedViewController.present(inspector, animated: true, completion: nil)
            })
        }

        return actions
    }

    @objc open func getDevSupportInfos() -> [String] {
        let userAccountManager = UserAccountManager.shared
        var devInfos: [String] = [
            "SDK Version", SALESFORCE_SDK_VERSION,
            "App Type", getAppTypeAsString(),
            "User Agent", userAgentString?("") ?? ""
        ]

        if let allUsers = userAccountManager.userAccounts(), allUsers.count > 0 {
            devInfos.append(contentsOf: ["Authenticated Users", usersToString(allUsers)])
        }

        devInfos.append("section:Auth Config")
        devInfos.append(contentsOf: [
            "Use Web Server Authentication", useWebServerAuthentication ? "YES" : "NO",
            "Use Hybrid Authentication", useHybridAuthentication ? "YES" : "NO",
            "Force Advanced Authentication", forceAdvancedAuthenticationInternal ? "YES" : "NO",
            "Browser Login Enabled", UserAccountManager.shared.usesAdvancedAuthentication ? "YES" : "NO",
            "IDP Enabled", idpEnabled ? "YES" : "NO",
            "Identity Provider", isIdentityProvider ? "YES" : "NO"
        ])

        devInfos.append("section:Bootconfig")
        if let configDict = appConfig?.configDict as? [String: Any] {
            devInfos.append(contentsOf: dictToDevInfos(configDict))
        }

        if let currentUser = userAccountManager.currentUserAccount {
            let creds = currentUser.credentials
            devInfos.append("section:Current User")
            devInfos.append(contentsOf: [
                "Username", userToString(currentUser),
                "Consumer Key", creds.clientId ?? "(nil)",
                "Redirect URI", creds.redirectUri ?? "(nil)",
                "Scopes", scopesToString(currentUser),
                "Instance URL", creds.instanceUrl?.absoluteString ?? "(nil)",
                "Token format", creds.tokenFormat == "jwt" ? "jwt" : "opaque",
                "Access Token Expiration", accessTokenExpiration(),
                "Beacon Child Consumer Key", creds.beaconChildConsumerKey ?? "(empty)"
            ])
        }

        let globalKeyValueStores = KeyValueEncryptedFileStore.allGlobalNames()
        let userKeyValueStores = KeyValueEncryptedFileStore.allNames()
        if userKeyValueStores.count > 0 || globalKeyValueStores.count > 0 {
            devInfos.append("section:Key Value Stores")
            devInfos.append(contentsOf: ["Global stores", globalKeyValueStores.joined(separator: ", ")])
            devInfos.append(contentsOf: ["User stores", userKeyValueStores.joined(separator: ", ")])
        }

        let managedPreferences = SFManagedPreferences.sharedPreferences
        if managedPreferences.hasManagedPreferences {
            devInfos.append("section:Managed Pref")
            devInfos.append(contentsOf: ["Managed", "YES"])
            if let rawPrefs = managedPreferences.rawPreferences as? [String: Any] {
                devInfos.append(contentsOf: dictToDevInfos(rawPrefs))
            }
        }

        return devInfos
    }

    @objc public func screenLockManager() -> ScreenLockManager {
        return ScreenLockManagerInternal.shared
    }

    @objc public func biometricAuthenticationManager() -> BiometricAuthenticationManager {
        return BiometricAuthenticationManagerInternal.shared
    }

    @objc public func bootConfig(forLoginHost loginHost: String?, callback: @escaping (BootConfig?) -> Void) {
        if let selectorBlock = appConfigRuntimeSelectorBlock {
            selectorBlock(loginHost ?? "") { [weak self] config in
                callback(config ?? self?.appConfig)
            }
        } else {
            callback(appConfig)
        }
    }

    // MARK: - Native Login

    @objc public func useNativeLogin(withConsumerKey consumerKey: String, callbackUrl: String, communityUrl: String, nativeLoginViewController: UIViewController, scene: UIScene?) -> NativeLoginManager {
        return useNativeLogin(withConsumerKey: consumerKey, callbackUrl: callbackUrl, communityUrl: communityUrl, reCaptchaSiteKeyId: nil, googleCloudProjectId: nil, isReCaptchaEnterprise: false, nativeLoginViewController: nativeLoginViewController, scene: scene)
    }

    @objc public func useNativeLogin(withConsumerKey consumerKey: String, callbackUrl: String, communityUrl: String, reCaptchaSiteKeyId: String?, googleCloudProjectId: String?, isReCaptchaEnterprise: Bool, nativeLoginViewController: UIViewController, scene: UIScene?) -> NativeLoginManager {
        SFSDKAppFeatureMarkers.registerAppFeature(kSFAppFeatureNativeLogin)
        let key = scene?.session.persistentIdentifier ?? kSFDefaultNativeLoginViewControllerKey
        nativeLoginViewControllers.setObject(nativeLoginViewController, forKey: key as NSString)

        let login = NativeLoginManagerInternal(clientId: consumerKey, redirectUri: callbackUrl, loginUrl: communityUrl, reCaptchaSiteKeyId: reCaptchaSiteKeyId, googleCloudProjectId: googleCloudProjectId, isReCaptchaEnterprise: isReCaptchaEnterprise, scene: scene)
        SalesforceSDKManager.nativeLogin = login
        UserAccountManager.shared.nativeLoginEnabled = true
        return login
    }

    @objc public func nativeLoginManager() -> NativeLoginManager? {
        if SalesforceSDKManager.nativeLogin == nil {
            SFSDKCoreLogger.e(SalesforceSDKManager.self, message: "You must call 'useNativeLogin' to create the Native Login Manager instance before retrieving it.")
        }
        return SalesforceSDKManager.nativeLogin
    }

    // MARK: - Private methods

    private func accessTokenExpiration() -> String {
        guard let creds = UserAccountManager.shared.currentUserAccount?.credentials,
              creds.tokenFormat == "jwt",
              let accessToken = creds.accessToken,
              let jwtAccessToken = try? JwtAccessToken(jwt: accessToken),
              let expirationDate = jwtAccessToken.expirationDate() else {
            return "Unknown"
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return dateFormatter.string(from: expirationDate)
    }

    private func userToString(_ user: UserAccount) -> String {
        return user.idData?.username ?? ""
    }

    private func scopesToString(_ user: UserAccount) -> String {
        if let scopes = user.credentials.scopes as? Set<String> {
            return scopes.joined(separator: " ")
        }
        return ""
    }

    private func usersToString(_ userAccounts: [UserAccount]) -> String {
        return userAccounts.map { userToString($0) }.joined(separator: ", ")
    }

    private func dictToDevInfos(_ dict: [String: Any]) -> [String] {
        var devInfos: [String] = []
        for (key, value) in dict {
            devInfos.append(key)
            devInfos.append(String(describing: value).replacingOccurrences(of: "\n", with: ""))
        }
        return devInfos
    }

    private func setupServiceConfiguration() {
        UserAccountManager.shared.oauthClientID = appConfig?.remoteAccessConsumerKey ?? ""
        UserAccountManager.shared.oauthCompletionURL = appConfig?.oauthRedirectURI ?? ""
        UserAccountManager.shared.scopes = appConfig?.oauthScopes ?? Set()
    }

    @objc private func handleAppForeground(_ notification: Notification) {
        SFSDKSalesforceSDKUpgradeManager.upgrade()
        ScreenLockManagerInternal.shared.handleAppForeground()
        BiometricAuthenticationManagerInternal.shared.handleAppForeground()
    }

    @objc private func handleAppBackground(_ notification: Notification) {
        SFSDKCoreLogger.d(SalesforceSDKManager.self, message: "App is entering the background.")
        clearClipboard()
    }

    @objc private func handleAppTerminate(_ notification: Notification) {}

    @objc private func handleSceneWillEnterForeground(_ notification: Notification) {
        let scene = sceneFromNotification(notification)
        if scene.session.role == .windowExternalDisplayNonInteractive {
            do {
                dismissSnapshot(scene, completion: nil)
            } catch {
                SFSDKCoreLogger.w(SalesforceSDKManager.self, message: "Exception thrown while removing security snapshot view. Will continue to resume scene.")
            }
        }
    }

    @objc private func handleSceneDidActivate(_ notification: Notification) {
        let scene = sceneFromNotification(notification)
        dismissSnapshot(scene, completion: nil)
    }

    @objc private func handleSceneWillConnect(_ notification: Notification) {
        let scene = sceneFromNotification(notification)
        if scene.activationState == .background {
            let activeWindow = SFSDKWindowManager.shared.activeWindow(scene)
            if activeWindow?.isAuthWindow == true || activeWindow?.isScreenLockWindow == true {
                return
            }
            presentSnapshot(scene)
        }
    }

    @objc private func handleSceneDidEnterBackground(_ notification: Notification) {
        let scene = sceneFromNotification(notification)
        let activeWindow = SFSDKWindowManager.shared.activeWindow(scene)
        if activeWindow?.isAuthWindow == true || activeWindow?.isScreenLockWindow == true {
            return
        }
        #if !os(visionOS)
        presentSnapshot(scene)
        #endif
    }

    @objc private func handleSceneDidDisconnect(_ notification: Notification) {
        let scene = sceneFromNotification(notification)
        snapshotViewControllers.removeObject(scene.session.persistentIdentifier as NSString)
    }

    private func sceneFromNotification(_ notification: Notification) -> UIScene {
        if let scene = notification.object as? UIScene {
            return scene
        }
        SFSDKCoreLogger.w(SalesforceSDKManager.self, message: "Unable to derive scene from notification, using default")
        return SFSDKWindowManager.shared.defaultScene()
    }

    @objc private func handleAuthCompleted(_ notification: Notification) {}

    @objc private func handleIDPInitiatedAuthCompleted(_ notification: Notification) {
        if let userAccount = notification.userInfo?[UserAccountManager.userInfoAccountKey] as? UserAccount {
            UserAccountManager.shared.switchToUserAccount(userAccount)
        }
    }

    @objc private func handleIDPUserAddCompleted(_ notification: Notification) {
        if let userAccount = notification.userInfo?[UserAccountManager.userInfoAccountKey] as? UserAccount,
           userAccount == UserAccountManager.shared.currentUserAccount {
            UserAccountManager.shared.switchToUserAccount(userAccount)
        }
    }

    @objc private func handleUserWillLogout(_ notification: Notification) {
        if let user = notification.userInfo?[UserAccountManager.userInfoAccountKey] as? UserAccount {
            KeyValueEncryptedFileStore.removeAll(forUserAccount: user)
            BiometricAuthenticationManagerInternal.shared.cleanup(user: user)
        }
    }

    @objc open func handlePostLogout() {
        ScreenLockManagerInternal.shared.checkForScreenLockUsers()
    }

    @objc private func handleUserDidLogout(_ notification: Notification) {
        handlePostLogout()
    }

    @objc func isSnapshotPresented(_ scene: UIScene) -> Bool {
        return SFSDKWindowManager.shared.snapshotWindow(scene).isEnabled
    }

    private func presentSnapshot(_ scene: UIScene) {
        guard useSnapshotView else { return }
        let sceneId = scene.session.persistentIdentifier as NSString

        var customSnapshotVC: UIViewController?
        if let creationAction = snapshotViewControllerCreationAction {
            customSnapshotVC = creationAction()
        }

        if let custom = customSnapshotVC {
            snapshotViewControllers[sceneId] = custom
        } else {
            snapshotViewControllers[sceneId] = SnapshotViewController(nibName: nil, bundle: nil)
        }
        snapshotViewControllers[sceneId]?.modalPresentationStyle = .fullScreen

        let snapshotWindow = SFSDKWindowManager.shared.snapshotWindow(scene)
        snapshotWindow.presentWindow(animated: false) { [weak self] in
            guard let self = self else { return }
            if self.snapshotPresentationAction != nil && self.snapshotDismissalAction != nil {
                self.snapshotPresentationAction?(self.snapshotViewControllers[sceneId]!)
            } else {
                snapshotWindow.viewController?.present(self.snapshotViewControllers[sceneId]!, animated: false, completion: nil)
            }
        }
    }

    @objc func dismissSnapshot(_ scene: UIScene, completion: (() -> Void)?) {
        guard isSnapshotPresented(scene) else { return }
        let sceneId = scene.session.persistentIdentifier as NSString
        if snapshotPresentationAction != nil && snapshotDismissalAction != nil {
            if let vc = snapshotViewControllers[sceneId] {
                snapshotDismissalAction?(vc)
            }
        } else {
            let snapshotWindow = SFSDKWindowManager.shared.snapshotWindow(scene)
            snapshotWindow.viewController?.dismiss(animated: false) {
                snapshotWindow.dismissWindow(animated: false) {
                    completion?()
                }
            }
        }
    }

    private func clearClipboard() {
        guard SFManagedPreferences.sharedPreferences.clearClipboardOnBackground else { return }
        SFSDKCoreLogger.i(SalesforceSDKManager.self, message: "Clearing clipboard on app background.")
        UIPasteboard.general.strings = []
        UIPasteboard.general.urls = []
        UIPasteboard.general.images = []
        UIPasteboard.general.colors = []
    }

    /// Returns a user agent string that includes both global and per-user feature flags.
    /// - Parameters:
    ///   - qualifier: Optional string appended to the app type (e.g., "Local" for hybrid).
    ///   - user: The user account whose per-user flags to include, or nil to use the current user.
    /// - Returns: The user agent string for the given user.
    @objc(userAgentString:forUser:) public func userAgent(qualifier: String, for user: UserAccount?) -> String {
        let resolvedUser = user ?? UserAccountManager.shared.currentUserAccount
        let curDevice = UIDevice.current
        let appName = SalesforceSDKManager.appName ?? ""
        let prodAppVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let buildNumber = Bundle.main.infoDictionary?[kCFBundleVersionKey as String] as? String ?? ""
        let appVersion = "\(prodAppVersion)(\(buildNumber))"
        let appTypeStr = self.getAppTypeAsString()
        let features = SFSDKAppFeatureMarkers.appFeatures(forUser: resolvedUser).sorted { $0.caseInsensitiveCompare($1) == .orderedAscending }
        let featuresStr = features.joined(separator: ".")
        let webViewAgent = self.webViewUserAgent ?? ""
        return "SalesforceMobileSDK/\(SALESFORCE_SDK_VERSION) \(curDevice.systemName)/\(curDevice.systemVersion) (\(curDevice.model)) \(appName)/\(appVersion) \(appTypeStr)\(qualifier) uid_\(SalesforceSDKManager.uid) ftr_\(featuresStr) \(webViewAgent)"
    }

    private func defaultUserAgentString() -> UserAgentGeneratorBlock {
        return { [weak self] qualifier in
            guard let self = self else { return "" }
            return self.userAgent(qualifier: qualifier, for: nil)
        }
    }

    @objc func hydratePerUserFeatureFlags() {
        guard let allUsers = UserAccountManager.shared.userAccounts() else { return }
        for account in allUsers {
            if let flags = account.persistedFeatureFlags, !flags.isEmpty {
                SFSDKAppFeatureMarkers.loadPersistedFeatures(flags, forUser: account)
            }
        }
    }

    private var webViewUserAgent: String? {
        get {
            if let agent = _webViewUserAgent {
                return agent
            }
            return UserDefaults.msdkUserDefaults().string(forKey: kWebViewUserAgentKey)
        }
        set {
            _webViewUserAgent = newValue
            UserDefaults.msdkUserDefaults().set(newValue, forKey: kWebViewUserAgentKey)
            UserDefaults.msdkUserDefaults().synchronize()
        }
    }

    private func computeWebViewUserAgent() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.webView = WKWebView(frame: .zero)
            self.webView?.loadHTMLString("<html></html>", baseURL: nil)
            self.webView?.evaluateJavaScript("navigator.userAgent") { [weak self] userAgent, error in
                self?.webViewUserAgent = userAgent as? String
                self?.webView = nil
            }
        }
    }

    @objc private func showDevSupportDialog() {
        let activeWindow = SFSDKWindowManager.shared.activeWindow(nil)
        if isDevSupportEnabled, let activeWindow = activeWindow, activeWindow.isEnabled {
            if let topVC = activeWindow.topViewController() {
                showDevSupportDialog(from: topVC)
            }
        }
    }

    @objc private func screenLockFlowWillBegin(_ notification: Notification) {}
    @objc private func screenLockFlowDidComplete(_ notification: Notification) {}
    @objc private func biometricAuthenticationFlowWillBegin(_ notification: Notification) {}
    @objc private func biometricAuthenticationFlowDidComplete(_ notification: Notification) {}
}
