/*
 Copyright (c) 2014-present, salesforce.com, inc. All rights reserved.

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
import WebKit
import SalesforceSDKCommon

// MARK: - Constants

public let kSalesforceSDKManagerErrorDomain = "com.salesforce.sdkmanager.error"
public let kSalesforceSDKManagerErrorDetailsKey = "SalesforceSDKManagerErrorDetails"
public let kSFScreenLockFlowWillBegin = "SFScreenLockFlowWillBegin"
public let kSFScreenLockFlowCompleted = "SFScreenLockFlowCompleted"
public let kSFBiometricAuthenticationFlowWillBegin = "SFBiometricAuthenticationFlowWillBegin"
public let kSFBiometricAuthenticationFlowCompleted = "SFBiometricAuthenticationFlowCompleted"

private let SALESFORCE_SDK_VERSION = "14.0.0"
private let SFSDKShowDevDialogNotification = "SFSDKShowDevDialogNotification"
private let kSFMobileSDKNativeDesignator = "Native"
private let kSFMobileSDKHybridDesignator = "Hybrid"
private let kSFMobileSDKReactNativeDesignator = "ReactNative"
private let kSFMobileSDKNativeSwiftDesignator = "NativeSwift"
private let kWebViewUserAgentKey = "web_view_user_agent"
private let kDefaultCacheMemoryCapacity = 1024 * 1024 * 4  // 4MB
private let kDefaultCacheDiskCapacity = 1024 * 1024 * 20   // 20MB
internal let kSFDefaultNativeLoginViewControllerKey = "defaultKey"

// Static variables
private var uid: String?
private var instanceClass: AnyClass?
private var ailtnAppName: String?
private var appName: String?
private var motionEndedImplementation: IMP?
private var nativeLogin: SFNativeLoginManagerInternal?

// MARK: - Type Aliases

public typealias SnapshotViewCreationBlock = () -> UIViewController?
public typealias SnapshotViewDisplayBlock = (UIViewController) -> Void
public typealias SnapshotViewDismissBlock = (UIViewController) -> Void

// MARK: - Enums

@objc public enum SFAppType: UInt {
    case native
    case hybrid
    case reactNative
    case nativeSwift

    public var description: String {
        return SFAppTypeGetDescription(self)
    }
}

@objc public enum SFURLCacheType: UInt {
    case encrypted = 1
    case null
    case standard
}

/// Note: Cannot use @objc on top-level functions in Swift
public func SFAppTypeGetDescription(_ appType: SFAppType) -> String {
    switch appType {
    case .native:
        return kSFMobileSDKNativeDesignator
    case .hybrid:
        return kSFMobileSDKHybridDesignator
    case .reactNative:
        return kSFMobileSDKReactNativeDesignator
    case .nativeSwift:
        return kSFMobileSDKNativeSwiftDesignator
    }
}

// MARK: - DevAction

@objc(SFSDKDevAction)
@objcMembers
public class DevAction: NSObject {
    public let name: String
    public var handler: () -> Void

    @objc(initWith:handler:)
    public init(name: String, handler: @escaping () -> Void) {
        self.name = name
        self.handler = handler
        super.init()
    }
}

// MARK: - SnapshotViewController

#if !os(visionOS)
@available(visionOS, unavailable)
@objc
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
#endif

// MARK: - UIWindow Extension

extension UIWindow {
    @objc dynamic func sfsdk_motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if event?.subtype == .motionShake {
            NotificationCenter.default.post(name: NSNotification.Name(SFSDKShowDevDialogNotification), object: nil)
        }
        // Call original implementation
        if let impl = motionEndedImplementation {
            typealias MotionEndedFunc = @convention(c) (AnyObject, Selector, UIEvent.EventSubtype, UIEvent?) -> Void
            let function = unsafeBitCast(impl, to: MotionEndedFunc.self)
            function(self, #selector(motionEnded(_:with:)), motion, event)
        }
    }
}

// MARK: - SalesforceSDKManagerFlow Protocol

@objc
public protocol SalesforceSDKManagerFlow: AnyObject {
    func handleAppForeground(_ notification: Notification)
    func handleAppBackground(_ notification: Notification)
    func handleAppTerminate(_ notification: Notification)
    func handlePostLogout()
    func handleAuthCompleted(_ notification: Notification)
    func handleIDPInitiatedAuthCompleted(_ notification: Notification)
    func handleUserDidLogout(_ notification: Notification)
}

// MARK: - SalesforceSDKManager

@objc(SalesforceSDKManager)
@objcMembers
open class SalesforceManager: NSObject, SalesforceSDKManagerFlow {

    // MARK: - Properties

    private var actionSheet: UIAlertController?
    private var webView: WKWebView?
    private var _webViewUserAgent: String?

    private var snapshotViewControllers = SFSDKSafeMutableDictionary<NSString, UIViewController>()
    internal var nativeLoginViewControllers = SFSDKSafeMutableDictionary<NSString, UIViewController>()

    weak var sdkManagerFlow: SalesforceSDKManagerFlow?

    public var appConfig: BootConfig? {
        didSet {
            setupServiceConfiguration()
        }
    }

    public private(set) var appType: SFAppType = .native

    public var brandLoginPath: String? {
        get { return SFUserAccountManager.shared.brandLoginPath }
        set { SFUserAccountManager.shared.brandLoginPath = newValue }
    }

    #if !targetEnvironment(macCatalyst)
    public var useSnapshotView: Bool = !SFSDKMacDetectUtil.isOnMac()
    #endif

    public var idpLoginFlowSelectionBlock: SFIDPLoginFlowSelectionBlock? {
        get { return SFUserAccountManager.shared.idpLoginFlowSelectionAction }
        set { SFUserAccountManager.shared.idpLoginFlowSelectionAction = newValue }
    }

    public var idpUserSelectionBlock: SFIDPUserSelectionBlock? {
        get { return SFUserAccountManager.shared.idpUserSelectionAction }
        set { SFUserAccountManager.shared.idpUserSelectionAction = newValue }
    }

    public var snapshotViewControllerCreationAction: SnapshotViewCreationBlock?

    #if !os(visionOS)
    @available(visionOS, unavailable)
    public var snapshotPresentationAction: SnapshotViewDisplayBlock?

    @available(visionOS, unavailable)
    public var snapshotDismissalAction: SnapshotViewDismissBlock?
    #endif

    public var userAgentString: (String) -> String = { qualifier in
        return SalesforceManager.defaultUserAgentString()(qualifier)
    }

    public var appConfigRuntimeSelectorBlock: SFSDKAppConfigRuntimeSelectorBlock?

    public var isIdentityProvider: Bool {
        get { return SFUserAccountManager.shared.isIdentityProvider }
        set { SFUserAccountManager.shared.isIdentityProvider = newValue }
    }

    public var idpAppURIScheme: String? {
        get { return SFUserAccountManager.shared.idpAppURIScheme }
        set { SFUserAccountManager.shared.idpAppURIScheme = newValue }
    }

    public var appDisplayName: String {
        get { return SFUserAccountManager.shared.appDisplayName }
        set { SFUserAccountManager.shared.appDisplayName = newValue }
    }

    public var isDevSupportEnabled: Bool = false {
        didSet {
            if isDevSupportEnabled {
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(showDevSupportDialog as () -> Void),
                    name: NSNotification.Name(SFSDKShowDevDialogNotification),
                    object: nil
                )
            } else {
                NotificationCenter.default.removeObserver(
                    self,
                    name: NSNotification.Name(SFSDKShowDevDialogNotification),
                    object: nil
                )
            }
        }
    }

    public var isLoginWebviewInspectable: Bool = false

    #if DEBUG
    public var simulatedDomainDiscoveryResult: DomainDiscoveryResult?
    #endif

    public var URLCacheType: SFURLCacheType = .encrypted {
        didSet {
            guard URLCacheType != oldValue else { return }
            URLCache.shared.removeAllCachedResponses()

            let cache: URLCache
            switch URLCacheType {
            case .encrypted:
                cache = SFSDKEncryptedURLCache(
                    memoryCapacity: kDefaultCacheMemoryCapacity,
                    diskCapacity: kDefaultCacheDiskCapacity,
                    diskPath: nil
                )
            case .null:
                cache = SFSDKNullURLCache(
                    memoryCapacity: kDefaultCacheMemoryCapacity,
                    diskCapacity: kDefaultCacheDiskCapacity,
                    diskPath: nil
                )
            case .standard:
                cache = URLCache(
                    memoryCapacity: kDefaultCacheMemoryCapacity,
                    diskCapacity: kDefaultCacheDiskCapacity,
                    diskPath: nil
                )
            }
            URLCache.shared = cache
        }
    }

    public var useEphemeralSessionForAdvancedAuth: Bool = true
    public var useWebServerAuthentication: Bool = true
    public var blockSalesforceIntegrationUser: Bool = false
    public var useHybridAuthentication: Bool = true
    public var customDomainInferencePattern: NSRegularExpression?

    private var webViewUserAgent: String? {
        get {
            if let agent = _webViewUserAgent {
                return agent
            } else {
                return UserDefaults.msdkUserDefaults().string(forKey: kWebViewUserAgentKey)
            }
        }
        set {
            _webViewUserAgent = newValue
            let defaults = UserDefaults.msdkUserDefaults()
            defaults.set(newValue, forKey: kWebViewUserAgentKey)
            defaults.synchronize()
        }
    }

    // MARK: - Class Properties

    public static var analyticsAppName: String {
        get {
            return ailtnAppName ?? ""
        }
        set {
            ailtnAppName = newValue
        }
    }

    public static var appName: String {
        get {
            return SalesforceManager.appName ?? ""
        }
        set {
            SalesforceManager.appName = newValue
        }
    }

    open class var shared: SalesforceManager {
        return sharedManager()
    }

    // MARK: - Initialization

    public required override init() {
        super.init()

        // Perform one-time class initialization (method swizzling)
        SalesforceManager.performClassInitialization()

        #if DEBUG
        isDevSupportEnabled = true
        #endif

        sdkManagerFlow = self

        // Register for notifications
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(handleAppForeground(_:)), name: UIApplication.willEnterForegroundNotification, object: nil)
        nc.addObserver(self, selector: #selector(handleAppBackground(_:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
        nc.addObserver(self, selector: #selector(handleAppTerminate(_:)), name: UIApplication.willTerminateNotification, object: nil)
        nc.addObserver(self, selector: #selector(handleSceneWillEnterForeground(_:)), name: UIScene.willEnterForegroundNotification, object: nil)
        nc.addObserver(self, selector: #selector(handleSceneDidActivate(_:)), name: UIScene.didActivateNotification, object: nil)
        nc.addObserver(self, selector: #selector(handleSceneDidEnterBackground(_:)), name: UIScene.didEnterBackgroundNotification, object: nil)
        nc.addObserver(self, selector: #selector(handleSceneWillConnect(_:)), name: UIScene.willConnectNotification, object: nil)
        nc.addObserver(self, selector: #selector(handleSceneDidDisconnect(_:)), name: UIScene.didDisconnectNotification, object: nil)
        nc.addObserver(self, selector: #selector(handleAuthCompleted(_:)), name: .UserAccountManagerDidLogInUser, object: nil)
        nc.addObserver(self, selector: #selector(handleIDPInitiatedAuthCompleted(_:)), name: .UserAccountManagerDidLogInAfterIDPInit, object: nil)
        nc.addObserver(self, selector: #selector(handleIDPUserAddCompleted(_:)), name: .UserAccountManagerWillSendIDPResponse, object: nil)
        nc.addObserver(self, selector: #selector(handleUserWillLogout(_:)), name: .UserAccountManagerWillLogoutUser, object: nil)
        nc.addObserver(self, selector: #selector(handleUserDidLogout(_:)), name: .UserAccountManagerDidLogoutUser, object: nil)
        nc.addObserver(self, selector: #selector(screenLockFlowWillBegin(_:)), name: NSNotification.Name(kSFScreenLockFlowWillBegin), object: nil)
        nc.addObserver(self, selector: #selector(screenLockFlowDidComplete(_:)), name: NSNotification.Name(kSFScreenLockFlowCompleted), object: nil)
        nc.addObserver(self, selector: #selector(biometricAuthenticationFlowWillBegin(_:)), name: NSNotification.Name(kSFBiometricAuthenticationFlowWillBegin), object: nil)
        nc.addObserver(self, selector: #selector(biometricAuthenticationFlowDidComplete(_:)), name: NSNotification.Name(kSFBiometricAuthenticationFlowCompleted), object: nil)

        #if !targetEnvironment(macCatalyst)
        useSnapshotView = !SFSDKMacDetectUtil.isOnMac()
        #endif

        computeWebViewUserAgent()
        userAgentString = SalesforceManager.defaultUserAgentString()
        URLCacheType = .encrypted
        useEphemeralSessionForAdvancedAuth = true
        useWebServerAuthentication = true
        blockSalesforceIntegrationUser = false
        useHybridAuthentication = true

        setupServiceConfiguration()
        SFSDKSalesforceSDKUpgradeManager.upgrade()
        SFScreenLockManagerInternal.shared.checkForScreenLockUsers()
    }

    // MARK: - Class Methods

    public static func setInstanceClass(_ className: AnyClass) {
        instanceClass = className
    }

    open class func initializeSDK() {
        initializeSDK(manager: instanceClass)

        #if DEBUG
        // For debug app builds only, use test instant log in if applicable.
        let arguments = ProcessInfo.processInfo.arguments
        if let credsIndex = arguments.firstIndex(of: "-creds"), credsIndex + 1 < arguments.count {
            let creds = arguments[credsIndex + 1]
            TestSetupUtils.populateAuthCredentials(fromString: creds, initializeSdk: false)
            TestSetupUtils.synchronousAuthRefresh(withUserDidLoginNotification: true)
        }
        #endif
    }

    open class func initializeSDK(manager className: AnyClass?) {
        setInstanceClass(className!)
        _ = sharedManager()
    }

    private static func sharedManager() -> SalesforceManager {
        struct Static {
            static var instance: SalesforceManager?
            static var token: DispatchSemaphore = DispatchSemaphore(value: 1)
        }

        Static.token.wait()
        defer { Static.token.signal() }

        if Static.instance == nil {
            uid = UIDevice.current.identifierForVendor?.uuidString

            if let cls = instanceClass as? SalesforceManager.Type {
                Static.instance = cls.init()
            } else {
                Static.instance = SalesforceManager()
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
        }

        return Static.instance!
    }

    /// Performs one-time class initialization (method swizzling for dev support)
    /// Note: In Objective-C this was +load, which Swift doesn't support. Must be called explicitly.
    public static func performClassInitialization() {
        DispatchQueue.once {
            // For dev support
            let sfsdkMotionEndedMethod = class_getInstanceMethod(UIWindow.self, #selector(UIWindow.sfsdk_motionEnded(_:with:)))
            let sfsdkMotionEndedImpl = method_getImplementation(sfsdkMotionEndedMethod!)
            motionEndedImplementation = method_setImplementation(
                class_getInstanceMethod(UIWindow.self, #selector(UIWindow.motionEnded(_:with:)))!,
                sfsdkMotionEndedImpl
            )

            // Pasteboard swizzling
            let generalPasteboardMethod = class_getClassMethod(UIPasteboard.self, #selector(getter: UIPasteboard.general))
            let generalPasteboardImpl = method_getImplementation(generalPasteboardMethod!)
            method_setImplementation(
                class_getClassMethod(SalesforceManager.self, #selector(SalesforceManager.generalPasteboard))!,
                generalPasteboardImpl
            )

            let sdkPasteboardMethod = class_getClassMethod(SalesforceManager.self, #selector(SalesforceManager.sdkPasteboard))
            let sdkPasteboardImpl = method_getImplementation(sdkPasteboardMethod!)
            method_setImplementation(
                class_getClassMethod(UIPasteboard.self, #selector(getter: UIPasteboard.general))!,
                sdkPasteboardImpl
            )
        }
    }

    @objc public static func generalPasteboard() -> UIPasteboard? {
        // As a result of swizzling, will contain the implementation of [UIPasteboard generalPasteboard]
        return nil
    }

    @objc public static func sdkNamedPasteboard() -> UIPasteboard {
        return UIPasteboard(name: UIPasteboard.Name("com.salesforce.mobilesdk.pasteboard"), create: true)!
    }

    @objc public static func sdkPasteboard() -> UIPasteboard? {
        if SFManagedPreferences.sharedPreferences().shouldDisableExternalPasteDefinedByConnectedApp {
            return sdkNamedPasteboard()
        }
        return generalPasteboard()
    }

    // MARK: - Instance Methods

    public func deviceId() -> String {
        return uid ?? ""
    }

    public func getAppTypeAsString() -> String {
        return appType.description
    }

    // MARK: - Dev Support

    @objc private func showDevSupportDialog() {
        guard let activeWindow = SFSDKWindowManager.shared.activeWindow(nil),
              activeWindow.isEnabled() else {
            return
        }

        if let topViewController = activeWindow.topViewController() {
            showDevSupportDialog(from: topViewController)
        }
    }

    public func showDevSupportDialog(from presentedViewController: UIViewController) {
        guard isDevSupportEnabled, actionSheet == nil else {
            return
        }

        let style: UIAlertController.Style = UIDevice.current.userInterfaceIdiom == .phone ? .actionSheet : .alert
        actionSheet = UIAlertController(title: devInfoTitleString(), message: "", preferredStyle: style)

        let devActions = self.devActionsList(presentedViewController: presentedViewController)
        for devAction in devActions {
            actionSheet?.addAction(UIAlertAction(title: devAction.name, style: .default) { [weak self] _ in
                devAction.handler()
                self?.actionSheet = nil
            })
        }

        actionSheet?.addAction(UIAlertAction(
            title: SFSDKResourceUtils.localizedString("devInfoCancelKey"),
            style: .cancel
        ) { [weak self] _ in
            self?.actionSheet = nil
        })

        presentedViewController.present(actionSheet!, animated: true)
    }

    public func devInfoTitleString() -> String {
        return SFSDKResourceUtils.localizedString("devInfoTitle")
    }

    open func devActionsList(presentedViewController: UIViewController) -> [DevAction] {
        var actions = [DevAction]()
        let userAccountManager = SFUserAccountManager.shared
        let currentUser = userAccountManager.currentUserAccount

        let isShowingLogin = presentedViewController is SFLoginViewController

        // Show dev info - always available
        actions.append(DevAction(name: "Show dev info") { [weak presentedViewController] in
            guard let presentedViewController = presentedViewController else { return }
            let devInfo = DevInfoViewController.makeViewController()
            presentedViewController.present(devInfo, animated: true)
        })

        // Login Options - only show on login screen
        if isShowingLogin {
            actions.append(DevAction(name: "Login Options") { [weak presentedViewController] in
                guard let presentedViewController = presentedViewController else { return }
                let configPicker = LoginOptionsViewController.makeViewController {
                    presentedViewController.dismiss(animated: true) {
                        // TODO: Implement restartAuthentication if needed
                        // if let loginVC = presentedViewController as? SFLoginViewController {
                        //     SFUserAccountManager.shared.restartAuthentication(
                        //         for: loginVC,
                        //         recreateAuthRequest: true
                        //     )
                        // }
                    }
                }
                presentedViewController.present(configPicker, animated: true)
            })
        }

        // Logout - only show if there's a current user and not on login screen
        if currentUser != nil && !isShowingLogin {
            actions.append(DevAction(name: "Logout") {
                SFUserAccountManager.shared.logout(.userInitiated)
            })
        }

        // Switch user - only show if there's a current user and not on login screen
        if currentUser != nil && !isShowingLogin {
            actions.append(DevAction(name: "Switch user") { [weak presentedViewController] in
                guard let presentedViewController = presentedViewController else { return }
                let umvc = SalesforceUserManagementViewController { _ in
                    presentedViewController.dismiss(animated: true)
                }
                presentedViewController.present(umvc, animated: true)
            })
        }

        // Inspect Key-Value Store - only show if there are stores
        let hasGlobalStores = KeyValueEncryptedFileStore.allGlobalNames().count > 0
        let hasUserStores = currentUser != nil && KeyValueEncryptedFileStore.allNames().count > 0

        if hasGlobalStores || hasUserStores {
            actions.append(DevAction(name: "Inspect Key-Value Store") { [weak presentedViewController] in
                guard let presentedViewController = presentedViewController else { return }
                let keyValueStoreInspector = KeyValueEncryptedFileStoreViewController().createUI()
                presentedViewController.present(keyValueStoreInspector, animated: true)
            })
        }

        return actions
    }

    open func devSupportInfoList() -> [String] {
        let userAccountManager = SFUserAccountManager.shared
        var devInfos = [String]()

        devInfos.append(contentsOf: [
            "SDK Version", SALESFORCE_SDK_VERSION,
            "App Type", getAppTypeAsString(),
            "User Agent", userAgentString("")
        ])

        let allUsers = userAccountManager.userAccounts() ?? []
        if !allUsers.isEmpty {
            devInfos.append(contentsOf: [
                "Authenticated Users", usersToString(allUsers)
            ])
        }

        // Auth configuration
        devInfos.append("section:Auth Config")
        devInfos.append(contentsOf: [
            "Use Web Server Authentication", useWebServerAuthentication ? "YES" : "NO",
            "Use Hybrid Authentication", useHybridAuthentication ? "YES" : "NO",
            "Browser Login Enabled", userAccountManager.usesAdvancedAuthentication ? "YES" : "NO",
            "IDP Enabled", idpEnabled ? "YES" : "NO",
            "Identity Provider", isIdentityProvider ? "YES" : "NO"
        ])

        // Static bootconfig
        devInfos.append("section:Bootconfig")
        if let config = appConfig {
            devInfos.append(contentsOf: dictToDevInfos(config.configDict as? [String: Any]))
        }

        // Current user info
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

        // Key Value Stores
        let globalKeyValueStores = KeyValueEncryptedFileStore.allGlobalNames()
        let userKeyValueStores = KeyValueEncryptedFileStore.allNames()
        if !userKeyValueStores.isEmpty || !globalKeyValueStores.isEmpty {
            devInfos.append("section:Key Value Stores")
            devInfos.append(contentsOf: [
                "Global stores", safeJoin(globalKeyValueStores, separator: ", "),
                "User stores", safeJoin(userKeyValueStores, separator: ", ")
            ])
        }

        // Managed prefs
        let managedPreferences = SFManagedPreferences.sharedPreferences()
        if managedPreferences.hasManagedPreferences {
            devInfos.append("section:Managed Pref")
            devInfos.append(contentsOf: ["Managed", managedPreferences.hasManagedPreferences ? "YES" : "NO"])
            devInfos.append(contentsOf: dictToDevInfos(managedPreferences.rawPreferences as? [String: Any]))
        }

        return devInfos
    }

    private func accessTokenExpiration() -> String {
        guard let creds = SFUserAccountManager.shared.currentUserAccount?.credentials else {
            return "Unknown"
        }

        var expiration = "Unknown"

        if creds.tokenFormat == "jwt" {
            if let accessToken = creds.accessToken,
               let jwtAccessToken = try? JwtAccessToken(jwt: accessToken),
               let expirationDate = jwtAccessToken.expirationDate() {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                expiration = dateFormatter.string(from: expirationDate)
            }
        }

        return expiration
    }

    private func userToString(_ user: SFUserAccount) -> String {
        return user.idData?.username ?? ""
    }

    private func scopesToString(_ user: SFUserAccount) -> String {
        return user.credentials.scopes?.joined(separator: " ") ?? ""
    }

    private func usersToString(_ userAccounts: [SFUserAccount]) -> String {
        let usernames = userAccounts.map { userToString($0) }
        return usernames.joined(separator: ", ")
    }

    private func dictToDevInfos(_ dict: [String: Any]?) -> [String] {
        guard let dict = dict else { return [] }
        var devInfos = [String]()
        for (key, value) in dict {
            devInfos.append(key)
            devInfos.append("\(value)".replacingOccurrences(of: "\n", with: ""))
        }
        return devInfos
    }

    private func safeJoin(_ array: [String], separator: String) -> String {
        return array.joined(separator: separator)
    }

    private var idpEnabled: Bool {
        return SFUserAccountManager.shared.idpAppURIScheme != nil
    }

    // MARK: - Configuration

    private func configureManagedSettings() {
        let managedPrefs = SFManagedPreferences.sharedPreferences()

        if managedPrefs.requireCertificateAuthentication {
            SFUserAccountManager.shared.usesAdvancedAuthentication = true
        }

        if let connectedAppId = managedPrefs.connectedAppId, !connectedAppId.isEmpty {
            appConfig?.remoteAccessConsumerKey = connectedAppId
        }

        if let connectedAppCallbackUri = managedPrefs.connectedAppCallbackUri, !connectedAppCallbackUri.isEmpty {
            appConfig?.oauthRedirectURI = connectedAppCallbackUri
        }

        if let scheme = managedPrefs.idpAppURLScheme {
            idpAppURIScheme = scheme
        }
    }

    private func setupServiceConfiguration() {
        guard let config = appConfig else { return }
        let accountManager = SFUserAccountManager.shared
        accountManager.oauthClientID = config.remoteAccessConsumerKey
        accountManager.oauthCompletionURL = config.oauthRedirectURI
        accountManager.scopes = config.oauthScopes
    }

    // MARK: - App Lifecycle

    @objc public func handleAppForeground(_ notification: Notification) {
        SFSDKSalesforceSDKUpgradeManager.upgrade()
        SFScreenLockManagerInternal.shared.handleAppForeground()
        SFBiometricAuthenticationManagerInternal.shared.handleAppForeground()
    }

    @objc public func handleAppBackground(_ notification: Notification) {
        SFSDKCoreLogger.d(type(of: self), message: "App is entering the background.")
        clearClipboard()
    }

    @objc public func handleAppTerminate(_ notification: Notification) {
        // Override in subclasses if needed
    }

    @objc private func handleSceneWillEnterForeground(_ notification: Notification) {
        guard let scene = sceneFromNotification(notification) else { return }
        let sceneId = scene.session.persistentIdentifier
        SFSDKCoreLogger.d(type(of: self), message: "Scene \(sceneId) is entering foreground.")

        // Using this to dismiss snapshot for screen mirroring
        if scene.session.role == .windowExternalDisplayNonInteractive {
            do {
                #if !os(visionOS)
                dismissSnapshot(scene, completion: nil)
                #endif
            } catch {
                SFSDKCoreLogger.w(type(of: self), message: "Exception thrown while removing security snapshot view for scene \(sceneId): '\(error.localizedDescription)'. Will continue to resume scene.")
            }
        }
    }

    @objc private func handleSceneDidActivate(_ notification: Notification) {
        guard let scene = sceneFromNotification(notification) else { return }
        let sceneId = scene.session.persistentIdentifier
        SFSDKCoreLogger.d(type(of: self), message: "Scene \(sceneId) is resuming active state.")

        do {
            #if !os(visionOS)
            dismissSnapshot(scene, completion: nil)
            #endif
        } catch {
            SFSDKCoreLogger.w(type(of: self), message: "Exception thrown while removing security snapshot view for scene \(sceneId): '\(error.localizedDescription)'. Will continue to resume scene.")
        }
    }

    @objc private func handleSceneWillConnect(_ notification: Notification) {
        guard let scene = sceneFromNotification(notification) else { return }
        if scene.activationState == .background {
            let activeWindow = SFSDKWindowManager.shared.activeWindow(scene)
            if activeWindow?.isAuthWindow() ?? false || activeWindow?.isScreenLockWindow() ?? false {
                return
            }
            #if !os(visionOS)
            presentSnapshot(scene)
            #endif
        }
    }

    @objc private func handleSceneDidEnterBackground(_ notification: Notification) {
        guard let scene = sceneFromNotification(notification) else { return }
        let sceneId = scene.session.persistentIdentifier

        SFSDKCoreLogger.d(type(of: self), message: "Scene \(sceneId) is entering background.")

        let activeWindow = SFSDKWindowManager.shared.activeWindow(scene)
        if activeWindow?.isAuthWindow() ?? false || activeWindow?.isScreenLockWindow() ?? false {
            return
        }

        do {
            #if !os(visionOS) && !targetEnvironment(macCatalyst)
            presentSnapshot(scene)
            #endif
        } catch {
            SFSDKCoreLogger.w(type(of: self), message: "Exception thrown while setting up security snapshot view for scene \(sceneId): '\(error.localizedDescription)'. Continuing background.")
        }
    }

    @objc private func handleSceneDidDisconnect(_ notification: Notification) {
        guard let scene = sceneFromNotification(notification) else { return }
        snapshotViewControllers.removeObject(scene.session.persistentIdentifier as NSString)
    }

    private func sceneFromNotification(_ notification: Notification) -> UIScene? {
        if let scene = notification.object as? UIScene {
            return scene
        } else {
            SFSDKCoreLogger.w(type(of: self), message: "Unable to derive scene from notification, using default")
            return SFSDKWindowManager.shared.defaultScene()
        }
    }

    @objc public func handleAuthCompleted(_ notification: Notification) {
        // Override in subclasses if needed
    }

    @objc public func handleIDPInitiatedAuthCompleted(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let userAccount = userInfo[kSFNotificationUserInfoAccountKey] as? UserAccount else {
            return
        }
        UserAccountManager.shared.switchToUserAccount(userAccount)
    }

    @objc private func handleIDPUserAddCompleted(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let userAccount = userInfo[kSFNotificationUserInfoAccountKey] as? UserAccount else {
            return
        }

        if userAccount == UserAccountManager.shared.currentUserAccount {
            UserAccountManager.shared.switchToUserAccount(userAccount)
        }
    }

    @objc private func handleUserWillLogout(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let user = userInfo[kSFNotificationUserInfoAccountKey] as? UserAccount else {
            return
        }
        KeyValueEncryptedFileStore.removeAll(forUserAccount: user)
        SFBiometricAuthenticationManagerInternal.shared.cleanup(user: user)
    }

    @objc public func handleUserDidLogout(_ notification: Notification) {
        handlePostLogout()
    }

    @objc public func handlePostLogout() {
        SFScreenLockManagerInternal.shared.checkForScreenLockUsers()
    }

    // MARK: - Snapshot

    #if !os(visionOS)
    @available(visionOS, unavailable)
    private func isSnapshotPresented(_ scene: UIScene) -> Bool {
        return SFSDKWindowManager.shared.snapshotWindow(scene).isEnabled()
    }

    @available(visionOS, unavailable)
    private func presentSnapshot(_ scene: UIScene) {
        #if !targetEnvironment(macCatalyst)
        guard useSnapshotView else { return }
        #endif

        let sceneId = scene.session.persistentIdentifier
        SFSDKCoreLogger.d(type(of: self), message: "Scene \(sceneId) is trying to present snapshot.")

        var customSnapshotViewController: UIViewController?
        if let creationAction = snapshotViewControllerCreationAction {
            customSnapshotViewController = creationAction()
        }

        let snapshotVC: UIViewController
        if let customVC = customSnapshotViewController {
            snapshotVC = customVC
        } else {
            snapshotVC = SnapshotViewController()
        }

        snapshotViewControllers.setObject(snapshotVC, forKey: sceneId as NSString)
        snapshotVC.modalPresentationStyle = .fullScreen

        let snapshotWindow = SFSDKWindowManager.shared.snapshotWindow(scene)
        snapshotWindow.presentWindowAnimated(false) { [weak self] in
            guard let self = self else { return }
            if let presentAction = self.snapshotPresentationAction,
               let dismissAction = self.snapshotDismissalAction {
                presentAction(self.snapshotViewControllers.object(forKey: sceneId as NSString)!)
            } else {
                snapshotWindow.viewController?.present(
                    self.snapshotViewControllers.object(forKey: sceneId as NSString)!,
                    animated: false
                )
            }
        }
    }

    @available(visionOS, unavailable)
    private func dismissSnapshot(_ scene: UIScene, completion: (() -> Void)?) {
        guard isSnapshotPresented(scene) else { return }

        if let presentAction = snapshotPresentationAction,
           let dismissAction = snapshotDismissalAction {
            dismissAction(snapshotViewControllers.object(forKey: scene.session.persistentIdentifier as NSString)!)
        } else {
            let snapshotWindow = SFSDKWindowManager.shared.snapshotWindow(scene)
            snapshotWindow.viewController?.dismiss(animated: false) {
                snapshotWindow.dismissWindowAnimated(false, withCompletion: {
                    completion?()
                })
            }
        }
    }
    #endif

    private func clearClipboard() {
        guard SFManagedPreferences.sharedPreferences().clearClipboardOnBackground else { return }

        SFSDKCoreLogger.i(type(of: self), message: "Clearing clipboard on app background.")

        if let generalPasteboard = SalesforceManager.generalPasteboard() {
            generalPasteboard.strings = []
            generalPasteboard.urls = []
            generalPasteboard.images = []
            generalPasteboard.colors = []
        }

        let namedPasteboard = SalesforceManager.sdkNamedPasteboard()
        namedPasteboard.strings = []
        namedPasteboard.urls = []
        namedPasteboard.images = []
        namedPasteboard.colors = []
    }

    // MARK: - User Agent

    private static func defaultUserAgentString() -> (String) -> String {
        return { qualifier in
            let curDevice = UIDevice.current
            let appName = SalesforceManager.appName
            let prodAppVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
            let buildNumber = Bundle.main.infoDictionary?[kCFBundleVersionKey as String] as? String ?? ""
            let appVersion = "\(prodAppVersion)(\(buildNumber))"

            let appTypeStr = SalesforceManager.shared.getAppTypeAsString()
            let myUserAgent = String(format:
                "SalesforceMobileSDK/%@ %@/%@ (%@) %@/%@ %@%@ uid_%@ ftr_%@ %@",
                SALESFORCE_SDK_VERSION,
                curDevice.systemName,
                curDevice.systemVersion,
                curDevice.model,
                appName,
                appVersion,
                appTypeStr,
                qualifier,
                uid ?? "",
                ((SFSDKAppFeatureMarkers.appFeatures() as NSSet).allObjects as? [String])?.sorted().joined(separator: ".") ?? "",
                SalesforceManager.shared.webViewUserAgent ?? ""
            )
            return myUserAgent
        }
    }

    private func computeWebViewUserAgent() {
        DispatchQueue.once {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.webView = WKWebView(frame: .zero)
                self.webView?.loadHTMLString("<html></html>", baseURL: nil)
                self.webView?.evaluateJavaScript("navigator.userAgent") { userAgent, _ in
                    self.webViewUserAgent = userAgent as? String
                    self.webView = nil
                }
            }
        }
    }

    // MARK: - Screen Lock & Biometric

    @objc private func screenLockFlowWillBegin(_ notification: Notification) {
        // Override in subclasses if needed
    }

    @objc private func screenLockFlowDidComplete(_ notification: Notification) {
        // Override in subclasses if needed
    }

    @objc private func biometricAuthenticationFlowWillBegin(_ notification: Notification) {
        // Override in subclasses if needed
    }

    @objc private func biometricAuthenticationFlowDidComplete(_ notification: Notification) {
        // Override in subclasses if needed
    }

    public func biometricAuthenticationManager() -> SFBiometricAuthenticationManager {
        return SFBiometricAuthenticationManagerInternal.shared
    }

    public func screenLockManager() -> SFScreenLockManager {
        return SFScreenLockManagerInternal.shared
    }

    // MARK: - Runtime App Config

    public func bootConfig(forLoginHost loginHost: String?, callback: @escaping (BootConfig?) -> Void) {
        if let selectorBlock = appConfigRuntimeSelectorBlock, let loginHost = loginHost {
            selectorBlock(loginHost) { [weak self] config in
                callback(config ?? self?.appConfig)
            }
        } else {
            callback(appConfig)
        }
    }

    // MARK: - Native Login

    public func useNativeLogin(
        consumerKey: String,
        callbackUrl: String,
        communityUrl: String,
        nativeLoginViewController: UIViewController,
        scene: UIScene?
    ) -> SFNativeLoginManager {
        return useNativeLogin(
            consumerKey: consumerKey,
            callbackUrl: callbackUrl,
            communityUrl: communityUrl,
            reCaptchaSiteKeyId: nil,
            googleCloudProjectId: nil,
            isReCaptchaEnterprise: false,
            nativeLoginViewController: nativeLoginViewController,
            scene: scene
        )
    }

    public func useNativeLogin(
        consumerKey: String,
        callbackUrl: String,
        communityUrl: String,
        reCaptchaSiteKeyId: String?,
        googleCloudProjectId: String?,
        isReCaptchaEnterprise: Bool,
        nativeLoginViewController: UIViewController,
        scene: UIScene?
    ) -> SFNativeLoginManager {
        SFSDKAppFeatureMarkers.registerAppFeature(kSFAppFeatureNativeLogin)

        let key = scene?.session.persistentIdentifier ?? kSFDefaultNativeLoginViewControllerKey
        nativeLoginViewControllers.setObject(nativeLoginViewController, forKey: key as NSString)

        nativeLogin = SFNativeLoginManagerInternal(
            clientId: consumerKey,
            redirectUri: callbackUrl,
            loginUrl: communityUrl,
            reCaptchaSiteKeyId: reCaptchaSiteKeyId,
            googleCloudProjectId: googleCloudProjectId,
            isReCaptchaEnterprise: isReCaptchaEnterprise,
            scene: scene
        )

        return nativeLogin!
    }

    public func nativeLoginManager() -> SFNativeLoginManager? {
        if nativeLogin == nil {
            SFSDKCoreLogger.e(type(of: self), message: "You must call 'useNativeLogin' to create the Native Login Manager instance before retrieving it.")
        }
        return nativeLogin
    }
}

// MARK: - DispatchQueue Extension

extension DispatchQueue {
    private static var _onceTracker = [String]()

    static func once(file: String = #file, function: String = #function, line: Int = #line, block: () -> Void) {
        let token = "\(file):\(function):\(line)"
        once(token: token, block: block)
    }

    static func once(token: String, block: () -> Void) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        guard !_onceTracker.contains(token) else { return }

        _onceTracker.append(token)
        block()
    }
}
