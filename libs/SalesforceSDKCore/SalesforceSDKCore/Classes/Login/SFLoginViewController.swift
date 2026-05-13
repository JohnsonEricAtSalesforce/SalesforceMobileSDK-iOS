/*
 SFLoginViewController.swift
 SalesforceSDKCore

 Created by Kunal Chitalia on 1/22/16.
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

import UIKit
import LocalAuthentication

/// Delegate protocol for the owner of SFLoginViewController.
@objc(SFLoginViewControllerDelegate)
public protocol SalesforceLoginViewControllerDelegate: AnyObject {

    /// Notifies the delegate that the selected login host has been changed.
    /// - Parameters:
    ///   - loginViewController: The instance sending this message.
    ///   - newLoginHost: The updated login host.
    @objc optional func loginViewController(_ loginViewController: SalesforceLoginViewController, didChangeLoginHost newLoginHost: SalesforceLoginHost)

    @objc optional func loginViewControllerDidClearCache(_ loginViewController: SalesforceLoginViewController)

    @objc optional func loginViewControllerDidClearCookies(_ loginViewController: SalesforceLoginViewController)

    @objc optional func loginViewControllerDidReload(_ loginViewController: SalesforceLoginViewController)

    @objc optional func loginViewControllerDidChangeLoginOptions(_ loginViewController: SalesforceLoginViewController)

    /// Notifies the delegate that the user selected "Login for Admin" from the settings menu.
    /// This forces browser-based (advanced) authentication via ASWebAuthenticationSession,
    /// regardless of org configuration, to support phishing-resistant MFA.
    /// - Parameter loginViewController: The instance sending this message.
    @objc optional func loginViewControllerDidSelectLoginForAdmin(_ loginViewController: SalesforceLoginViewController)
}

/// The Salesforce login screen view.
@objc(SFLoginViewController)
@objcMembers
public class SalesforceLoginViewController: SDKViewController {

    /// The delegate representing the owner of this object.
    public weak var delegate: SalesforceLoginViewControllerDelegate?

    /// Outlet to the OAuth web view.
    @IBOutlet public var oauthView: UIView? {
        didSet {
            if let oldValue = oldValue, oldValue != oauthView {
                oldValue.removeFromSuperview()
            }
        }
    }

    /// The biometric log in button
    public private(set) var biometricButton: UIButton?

    /// Specify the font to use for navigation bar header text.
    public var navigationBarFont: UIFont? {
        get { return config.navigationBarFont }
        set { config.navigationBarFont = newValue }
    }

    /// Specify the text color to use for navigation bar header text.
    public var navigationBarTintColor: UIColor? {
        get { return config.navigationBarTintColor }
        set { config.navigationBarTintColor = newValue }
    }

    /// Specify the text color to use for navigation bar header text.
    public var navigationBarTitleColor: UIColor? {
        get { return config.navigationTitleColor }
        set { config.navigationTitleColor = newValue }
    }

    /// Specify navigation bar color. This color will be used by the login view header.
    public var navigationBarColor: UIColor? {
        get { return config.navigationBarColor }
        set { config.navigationBarColor = newValue }
    }

    /// Specify visibility of nav bar. This property will be used to hide/show the nav bar
    public var showsNavigationBar: Bool {
        get { return config.showNavbar }
        set { config.showNavbar = newValue }
    }

    /// Specify the visibility of the settings icon. This property will be used to hide/show the settings icon
    public var showsSettingsIcon: Bool {
        get { return config.showSettingsIcon }
        set { config.showSettingsIcon = newValue }
    }

    /// Specify the visibility of the server picker option in the settings menu.
    public var showsServerPicker: Bool {
        get { return config.showServerPicker }
        set { config.showServerPicker = newValue }
    }

    /// Specify all display properties in a config. All the above properties are backed by a config object
    public var config: SalesforceLoginViewControllerConfig

    /// Get the instance of nav bar. Use this property to get the instance of navBar
    public private(set) var navBar: UINavigationBar?

    /// Get the reference to the SFSDKLoginHostListViewController
    public lazy var loginHostListViewController: LoginHostListViewController = {
        return createLoginHostListViewController()
    }()

    /// Reference to previous user account
    private var previousUserAccount: UserAccount?

    // MARK: - Initialization

    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        config = SalesforceLoginViewControllerConfig()
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        UserAccountManager.shared.addDelegate(self)
    }

    required init?(coder: NSCoder) {
        config = SalesforceLoginViewControllerConfig()
        super.init(coder: coder)
        UserAccountManager.shared.addDelegate(self)
    }

    // MARK: - View Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()

        // as this view is not part of navigation controller stack, needs to set the proper view background so that status bar has the
        // right background color
        view.backgroundColor = navigationBarColor
        view.autoresizesSubviews = true
        view.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        view.clipsToBounds = true

        if showsNavigationBar {
            setupNavigationBar()
        } else {
            navigationController?.isNavigationBarHidden = true
        }

        if let oauthView = oauthView {
            view.addSubview(oauthView)
        }

        let bioAuthManager = SFBiometricAuthenticationManagerInternal.shared
        let showBioAuthButton = bioAuthManager.showNativeLoginButton()

        if showBioAuthButton {
            let button = UIButton(type: .custom)
            button.setTitle(SFSDKResourceUtils.localizedString("biometricLoginButton"), for: .normal)
            button.addTarget(self, action: #selector(presentBioAuthAction(_:)), for: .touchUpInside)
            biometricButton = button
            view.addSubview(button)
        }

        if bioAuthManager.locked && bioAuthManager.hasBiometricOptedIn() {
            if let scene = view.window?.windowScene {
                bioAuthManager.presentBiometric(scene: scene)
            }
        }

        registerForTraitChanges([UITraitDisplayScale.self]) { (self: Self, previousTraitCollection: UITraitCollection) in
            self.setupNavigationBar()
        }
    }

    private func belowFrame(_ frame: CGRect) -> CGFloat {
        return frame.origin.y + frame.size.height
    }

    public override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        let heightOffsetMultiplier: CGFloat = biometricButton != nil ? 0.9 : 1.0
        let bottomOffset: CGFloat = biometricButton != nil ? view.safeAreaInsets.bottom : 0

        // Web view
        let x: CGFloat = 0
        var y: CGFloat = belowFrame(navBar?.frame ?? .zero)
        let w: CGFloat = view.bounds.size.width
        var h: CGFloat = ((view.bounds.size.height - y) * heightOffsetMultiplier) - bottomOffset
        oauthView?.frame = CGRect(x: x, y: y, width: w, height: h)

        // Biometric button
        h = (view.bounds.size.height - y) * 0.1
        y = view.bounds.size.height - h - bottomOffset
        biometricButton?.frame = CGRect(x: x, y: y, width: w, height: h)
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if showsNavigationBar {
            styleNavigationBar(navBar)
        }
        setupBackButton()
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    public override var prefersStatusBarHidden: Bool {
        return false
    }

    // MARK: - Setup Navigation bar

    private func setupNavigationBar() {
        if showsNavigationBar {
            navBar = navigationController?.navigationBar
            navBar?.topItem?.titleView = createTitleItem()

            if showsSettingsIcon {
                // Setup right bar button.
                let button = createSettingsButton()
                navBar?.topItem?.rightBarButtonItem = button
            }
            styleNavigationBar(navBar)

            if navigationController == nil, let navBar = navBar {
                view.addSubview(navBar)
            }

            #if !targetEnvironment(simulator) && !os(visionOS)
            setNeedsStatusBarAppearanceUpdate()
            #endif
        }
    }

    private func setupBackButton() {
        // setup left bar button
        if shouldShowBackButton() {
            let button = createBackButton()
            if button.target == nil {
                button.target = self
            }
            if button.action == nil {
                button.action = #selector(backToPreviousHost(_:))
            }
            navBar?.topItem?.leftBarButtonItem = button
        } else {
            navBar?.topItem?.leftBarButtonItem = nil
        }
    }

    /// Logic to show back button.
    @objc public func shouldShowBackButton() -> Bool {
        if SFBiometricAuthenticationManagerInternal.shared.locked {
            return false
        }

        if config.showsBackButton || UserAccountManager.shared.shouldFallbackToWebAuthentication {
            return true
        }
        let totalAccounts = UserAccountManager.shared.userAccounts()?.count ?? 0
        return (totalAccounts > 0 && UserAccountManager.shared.currentUserAccount != nil)
    }

    /// Factory Method to create the back button.
    @objc public func createBackButton() -> UIBarButtonItem {
        // setup left bar button
        let image = SFSDKResourceUtils.imageNamed("globalheader-back-arrow")?.withRenderingMode(.alwaysTemplate)
        return UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(backToPreviousHost(_:)))
    }

    /// Factory Method to create the settings button.
    @objc public func createSettingsButton() -> UIBarButtonItem {
        let image = SFSDKResourceUtils.imageNamed("login-window-gear")?.withRenderingMode(.alwaysTemplate)

        var menuActions: [UIAction] = []

        // Don't show the change server option if there are no hosts to switch to.
        let managedPreferences = SFManagedPreferences.sharedPreferences()
        if managedPreferences.onlyShowAuthorizedHosts && (managedPreferences.loginHosts?.isEmpty ?? true) {
            showsServerPicker = false
        }

        if showsServerPicker {
            menuActions.append(UIAction(title: SFSDKResourceUtils.localizedString("LOGIN_CHOOSE_SERVER"),
                                       image: nil,
                                       identifier: nil) { [weak self] _ in
                guard let self = self else { return }
                self.showLoginHost(self)
            })
        }

        menuActions.append(UIAction(title: SFSDKResourceUtils.localizedString("LOGIN_CLEAR_COOKIES"),
                                   image: nil,
                                   identifier: nil) { [weak self] _ in
            guard let self = self else { return }
            self.delegate?.loginViewControllerDidClearCookies?(self)
        })

        menuActions.append(UIAction(title: SFSDKResourceUtils.localizedString("LOGIN_CLEAR_CACHE"),
                                   image: nil,
                                   identifier: nil) { [weak self] _ in
            guard let self = self else { return }
            self.delegate?.loginViewControllerDidClearCache?(self)
        })

        menuActions.append(UIAction(title: SFSDKResourceUtils.localizedString("LOGIN_RELOAD"),
                                   image: nil,
                                   identifier: nil) { [weak self] _ in
            guard let self = self else { return }
            self.delegate?.loginViewControllerDidReload?(self)
        })

        if SalesforceManager.shared.isDevSupportEnabled {
            menuActions.append(UIAction(title: SFSDKResourceUtils.localizedString("LOGIN_OPTIONS"),
                                       image: nil,
                                       identifier: nil) { [weak self] _ in
                guard let self = self else { return }
                let configPicker = LoginOptionsViewController.makeViewController {
                    self.dismiss(animated: true) {
                        self.delegate?.loginViewControllerDidChangeLoginOptions?(self)
                    }
                }
                self.present(configPicker, animated: true, completion: nil)
            })
        }

        // Login for Admin - forces browser-based (advanced) authentication to support phishing-resistant MFA.
        menuActions.append(UIAction(title: SFSDKResourceUtils.localizedString("LOGIN_FOR_ADMIN"),
                                   image: nil,
                                   identifier: nil) { [weak self] _ in
            guard let self = self else { return }
            self.delegate?.loginViewControllerDidSelectLoginForAdmin?(self)
        })

        let menu = UIMenu(title: "", children: menuActions)
        let settingsButton = UIBarButtonItem(image: image, menu: menu)
        settingsButton.accessibilityLabel = SFSDKResourceUtils.localizedString("LOGIN_SETTINGS_BUTTON")
        settingsButton.accessibilityIdentifier = "settings"
        return settingsButton
    }

    /// Factory Method to create the navigation title.
    @objc public func createTitleItem() -> UIView {
        let title = SFSDKResourceUtils.localizedString("TITLE_LOGIN")
        // Setup top item.
        let item = UILabel(frame: .zero)
        if let titleColor = config.navigationTitleColor {
            item.textColor = titleColor
        }
        if let font = config.navigationBarFont {
            item.font = font
        } else {
            item.font = UIFont.preferredFont(forTextStyle: .headline)
        }

        item.text = title
        item.textAlignment = .center
        item.adjustsFontForContentSizeCategory = true
        return item
    }

    /// Factory Method to create the hostListView Controller.
    @objc public func createLoginHostListViewController() -> LoginHostListViewController {
        let loginHostListViewController = LoginHostListViewController(style: .plain)
        loginHostListViewController.config = config
        loginHostListViewController.delegate = self
        return loginHostListViewController
    }

    public override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .all
    }

    // MARK: - Action Methods

    @IBAction func presentBioAuthAction(_ sender: Any?) {
        if let scene = view.window?.windowScene {
            SFBiometricAuthenticationManagerInternal.shared.presentBiometric(scene: scene)
        }
    }

    @IBAction func showLoginHost(_ sender: Any?) {
        showHostListView()
    }

    @IBAction func backToPreviousHost(_ sender: Any?) {
        handleBackButtonAction()
    }

    /// Back Button was pressed by user
    @objc public func handleBackButtonAction() {
        let scene = view.window?.windowScene
        UserAccountManager.shared.stopCurrentAuthentication(nil)

        if UserAccountManager.shared.shouldFallbackToWebAuthentication {
            UserAccountManager.shared.shouldFallbackToWebAuthentication = false
            UserAccountManager.shared.login(completion: nil, failure: nil)
        }

        // Dismiss the auth window
        let authWindow = SFSDKWindowManager.shared.authWindow(scene)
        if let presentedVC = authWindow.viewController?.presentedViewController {
            presentedVC.dismiss(animated: false) {
                authWindow.dismissWindow()
            }
        } else {
            authWindow.viewController?.dismiss(animated: false, completion: nil)
        }
    }

    // MARK: - Styling Methods for Nav bar

    /// Applies the view's style attributes to the given navigation bar.
    /// - Parameter navigationBar: The navigation bar that the style is applied to.
    @objc public func styleNavigationBar(_ navigationBar: UINavigationBar?) {
        guard let navigationBar = navigationBar else { return }
        var classes: [AnyClass] = []
        if let navController = navigationController {
            classes = [type(of: navController)]
        }
        SFSDKViewUtils.styleNavigationBar(navigationBar, config: config, classes: classes)
    }

    // MARK: - Login Host

    /// Present the Host List View.
    @objc public func showHostListView() {
        // Create a FRESH instance each time instead of reusing the cached one
        let hostListVC = createLoginHostListViewController()

        let navController = SFSDKNavigationController(rootViewController: hostListVC)
        navController.modalPresentationStyle = .pageSheet

        present(navController, animated: true, completion: nil)
    }

    /// Hide the Host List View.
    /// - Parameter animated: Indicates whether or not the hiding should be animated.
    @objc public func hideHostListView(_ animated: Bool) {
        dismiss(animated: animated, completion: nil)
    }

    /// User Selected a host from the host list
    /// - Parameter host: SFSDKLoginHost
    @objc public func handleLoginHostSelectedAction(_ host: SalesforceLoginHost) {
        delegate?.loginViewController?(self, didChangeLoginHost: host)
    }
}

// MARK: - SFSDKLoginHostDelegate

extension SalesforceLoginViewController: SFSDKLoginHostDelegate {
    public func hostListViewControllerDidAddLoginHost(_ hostListViewController: LoginHostListViewController) {
        hideHostListView(true)
    }

    public func hostListViewControllerDidSelectLoginHost(_ hostListViewController: LoginHostListViewController) {
        // Hide the popover
        hideHostListView(true)
    }

    public func hostListViewControllerDidCancelLoginHost(_ hostListViewController: LoginHostListViewController) {
        hideHostListView(true)
    }

    public func hostListViewController(_ hostListViewController: LoginHostListViewController, didChangeLoginHost newLoginHost: SalesforceLoginHost) {
        handleLoginHostSelectedAction(newLoginHost)
    }
}

// MARK: - UserAccountManagerDelegate

extension SalesforceLoginViewController: UserAccountManagerDelegate {
    public func userAccountManager(accountManager: UserAccountManager,
                                   willSwitchFrom currentUserAccount: UserAccount,
                                   to anotherUserAccount: UserAccount?) {
        previousUserAccount = currentUserAccount
    }
}
