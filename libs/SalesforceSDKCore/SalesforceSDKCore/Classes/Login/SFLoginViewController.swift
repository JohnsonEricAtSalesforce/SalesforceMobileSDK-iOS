// SFLoginViewController.swift
// SalesforceSDKCore
//
// Created by Kunal Chitalia on 1/22/16.
// Copyright (c) 2016-present, salesforce.com, inc. All rights reserved.
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

import UIKit
import LocalAuthentication

/// Delegate protocol for the owner of SFLoginViewController.
@objc(SFLoginViewControllerDelegate)
public protocol SalesforceLoginViewControllerDelegate: AnyObject {
    @objc optional func loginViewController(_ loginViewController: SalesforceLoginViewController, didChangeLoginHost newLoginHost: SalesforceLoginHost)
    @objc optional func loginViewControllerDidClearCache(_ loginViewController: SalesforceLoginViewController)
    @objc optional func loginViewControllerDidClearCookies(_ loginViewController: SalesforceLoginViewController)
    @objc optional func loginViewControllerDidReload(_ loginViewController: SalesforceLoginViewController)
    @objc optional func loginViewControllerDidChangeLoginOptions(_ loginViewController: SalesforceLoginViewController)
    @objc optional func loginViewControllerDidSelectLoginForAdmin(_ loginViewController: SalesforceLoginViewController)
}

/// The Salesforce login screen view.
@objc(SFLoginViewController)
@objcMembers
public class SalesforceLoginViewController: SFSDKViewController, LoginHostDelegate, UserAccountManagerDelegate {

    @objc public weak var delegate: SalesforceLoginViewControllerDelegate?
    @objc public var oauthView: UIView? {
        didSet {
            if let oldView = oldValue, oldView !== oauthView {
                oldView.removeFromSuperview()
            }
        }
    }

    @objc public private(set) var biometricButton: UIButton?
    @objc public private(set) var navBar: UINavigationBar?

    @objc public var navBarFont: UIFont? {
        get { config.navBarFont }
        set { config.navBarFont = newValue }
    }

    @objc public var navBarTintColor: UIColor? {
        get { config.navBarTintColor }
        set { config.navBarTintColor = newValue }
    }

    @objc public var navBarTitleColor: UIColor? {
        get { config.navBarTitleColor }
        set { config.navBarTitleColor = newValue }
    }

    @objc public var navBarColor: UIColor? {
        get { config.navBarColor }
        set { config.navBarColor = newValue }
    }

    @objc public var showNavbar: Bool {
        get { config.showNavbar }
        set { config.showNavbar = newValue }
    }

    @objc public var showSettingsIcon: Bool {
        get { config.showSettingsIcon }
        set { config.showSettingsIcon = newValue }
    }

    @objc public var showServerPicker: Bool {
        get { config.showServerPicker }
        set { config.showServerPicker = newValue }
    }

    @objc public var config: SalesforceLoginViewControllerConfig = SalesforceLoginViewControllerConfig()

    @objc public lazy var loginHostListViewController: LoginHostListViewController = {
        return createLoginHostListViewController()
    }()

    private var previousUserAccount: UserAccount?

    // MARK: - Initialization

    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        UserAccountManager.shared.addDelegate(self)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        UserAccountManager.shared.addDelegate(self)
    }

    // MARK: - View lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = navBarColor
        view.autoresizesSubviews = true
        view.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        view.clipsToBounds = true

        if showNavbar {
            setupNavigationBar()
        } else {
            navigationController?.isNavigationBarHidden = true
        }

        if let oauthView = oauthView {
            view.addSubview(oauthView)
        }

        let bioAuthManager = BiometricAuthenticationManagerInternal.shared
        let showBioAuthButton = bioAuthManager.showNativeLoginButton()

        if showBioAuthButton {
            let button = UIButton(type: .custom)
            button.setTitle(SFSDKResourceUtils.localizedString("biometricLoginButton"), for: .normal)
            button.addTarget(self, action: #selector(presentBioAuthAction(_:)), for: .touchUpInside)
            biometricButton = button
            view.addSubview(button)
        }

        if bioAuthManager.locked && bioAuthManager.hasBiometricOptedIn(), let scene = view.window?.windowScene {
            bioAuthManager.presentBiometric(scene: scene)
        }

        registerForTraitChanges([UITraitDisplayScale.self], action: #selector(setupNavigationBar))
    }

    private func belowFrame(_ frame: CGRect) -> CGFloat {
        return frame.origin.y + frame.size.height
    }

    public override func viewWillLayoutSubviews() {
        let heightOffsetMultiplier: CGFloat = biometricButton != nil ? 0.9 : 1.0
        let bottomOffset: CGFloat = biometricButton != nil ? view.safeAreaInsets.bottom : 0

        let x: CGFloat = 0
        let y = belowFrame(navBar?.frame ?? .zero)
        let w = view.bounds.size.width
        let h = ((view.bounds.size.height - y) * heightOffsetMultiplier) - bottomOffset
        oauthView?.frame = CGRect(x: x, y: y, width: w, height: h)

        let buttonH = (view.bounds.size.height - y) * 0.1
        let buttonY = view.bounds.size.height - buttonH - bottomOffset
        biometricButton?.frame = CGRect(x: x, y: buttonY, width: w, height: buttonH)
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if showNavbar {
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

    // MARK: - Navigation bar setup

    @objc public func setupNavigationBar() {
        guard showNavbar else { return }
        navBar = navigationController?.navigationBar
        navBar?.topItem?.titleView = createTitleItem()

        if showSettingsIcon {
            let button = createSettingsButton()
            navBar?.topItem?.rightBarButtonItem = button
        }
        styleNavigationBar(navBar)

        if navigationController == nil, let navBar = navBar {
            view.addSubview(navBar)
        }

        #if !os(visionOS)
        setNeedsStatusBarAppearanceUpdate()
        #endif
    }

    private func setupBackButton() {
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

    @objc public func shouldShowBackButton() -> Bool {
        if BiometricAuthenticationManagerInternal.shared.locked {
            return false
        }
        if config.shouldDisplayBackButton || UserAccountManager.shared.isIDPEnabled
            || UserAccountManager.shared.shouldFallbackToWebAuthentication {
            return true
        }
        let totalAccounts = UserAccountManager.shared.userAccounts()?.count ?? 0
        return totalAccounts > 0 && UserAccountManager.shared.currentUserAccount != nil
    }

    @objc public func createBackButton() -> UIBarButtonItem {
        let image = SFSDKResourceUtils.imageNamed( "globalheader-back-arrow")?.withRenderingMode(.alwaysTemplate)
        return UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(backToPreviousHost(_:)))
    }

    @objc public func createSettingsButton() -> UIBarButtonItem {
        let image = SFSDKResourceUtils.imageNamed( "login-window-gear")?.withRenderingMode(.alwaysTemplate)

        var menuActions: [UIAction] = []

        let managedPreferences = SFManagedPreferences.sharedPreferences
        if managedPreferences.onlyShowAuthorizedHosts && (managedPreferences.loginHosts?.count ?? 0) == 0 {
            showServerPicker = false
        }

        if showServerPicker {
            menuActions.append(UIAction(title: SFSDKResourceUtils.localizedString("LOGIN_CHOOSE_SERVER"), image: nil, identifier: nil) { [weak self] _ in
                self?.showLoginHost(self as Any)
            })
        }

        menuActions.append(UIAction(title: SFSDKResourceUtils.localizedString("LOGIN_CLEAR_COOKIES"), image: nil, identifier: nil) { [weak self] _ in
            guard let self = self else { return }
            self.delegate?.loginViewControllerDidClearCookies?(self)
        })

        menuActions.append(UIAction(title: SFSDKResourceUtils.localizedString("LOGIN_CLEAR_CACHE"), image: nil, identifier: nil) { [weak self] _ in
            guard let self = self else { return }
            self.delegate?.loginViewControllerDidClearCache?(self)
        })

        menuActions.append(UIAction(title: SFSDKResourceUtils.localizedString("LOGIN_RELOAD"), image: nil, identifier: nil) { [weak self] _ in
            guard let self = self else { return }
            self.delegate?.loginViewControllerDidReload?(self)
        })

        if SalesforceSDKManager.shared.isDevSupportEnabled {
            menuActions.append(UIAction(title: SFSDKResourceUtils.localizedString("LOGIN_OPTIONS"), image: nil, identifier: nil) { [weak self] _ in
                guard let self = self else { return }
                let configPicker = LoginOptionsViewController.makeViewController {
                    self.dismiss(animated: true) {
                        self.delegate?.loginViewControllerDidChangeLoginOptions?(self)
                    }
                }
                self.present(configPicker, animated: true, completion: nil)
            })
        }

        menuActions.append(UIAction(title: SFSDKResourceUtils.localizedString("LOGIN_FOR_ADMIN"), image: nil, identifier: nil) { [weak self] _ in
            guard let self = self else { return }
            self.delegate?.loginViewControllerDidSelectLoginForAdmin?(self)
        })

        let menu = UIMenu(title: "", children: menuActions)
        let settingsButton = UIBarButtonItem(image: image, menu: menu)
        settingsButton.accessibilityLabel = SFSDKResourceUtils.localizedString("LOGIN_SETTINGS_BUTTON")
        settingsButton.accessibilityIdentifier = "settings"
        return settingsButton
    }

    @objc public func createTitleItem() -> UIView {
        let title = SFSDKResourceUtils.localizedString("TITLE_LOGIN")
        let item = UILabel(frame: .zero)
        if let titleColor = config.navBarTitleColor {
            item.textColor = titleColor
        }
        if let font = config.navBarFont {
            item.font = font
        } else {
            item.font = UIFont.preferredFont(forTextStyle: .headline)
        }
        item.text = title
        item.textAlignment = .center
        item.adjustsFontForContentSizeCategory = true
        return item
    }

    @objc public func createLoginHostListViewController() -> LoginHostListViewController {
        let loginHostListVC = LoginHostListViewController(style: .plain)
        loginHostListVC.config = config
        loginHostListVC.delegate = self
        return loginHostListVC
    }

    public override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .all
    }

    // MARK: - Actions

    @IBAction func presentBioAuthAction(_ sender: Any?) {
        if let scene = view.window?.windowScene {
            BiometricAuthenticationManagerInternal.shared.presentBiometric(scene: scene)
        }
    }

    @IBAction func showLoginHost(_ sender: Any?) {
        showHostListView()
    }

    @IBAction func backToPreviousHost(_ sender: Any?) {
        handleBackButtonAction()
    }

    @objc public func handleBackButtonAction() {
        let scene = view.window?.windowScene
        UserAccountManager.shared.stopCurrentAuthentication(nil)

        if UserAccountManager.shared.shouldFallbackToWebAuthentication {
            UserAccountManager.shared.shouldFallbackToWebAuthentication = false
            _ = UserAccountManager.shared.loginWithCompletion(nil, failure: nil)
        }

        if !UserAccountManager.shared.isIDPEnabled {
            SFSDKWindowManager.shared.authWindow(scene).viewController?.presentedViewController?.dismiss(animated: false) {
                SFSDKWindowManager.shared.authWindow(scene).dismissWindow()
            }
        } else {
            SFSDKWindowManager.shared.authWindow(scene).viewController?.dismiss(animated: false, completion: nil)
        }
    }

    // MARK: - Styling

    @objc public func styleNavigationBar(_ navigationBar: UINavigationBar?) {
        guard let navigationBar = navigationBar else { return }
        let classes: [UIAppearanceContainer.Type] = [type(of: self) as UIAppearanceContainer.Type]
        SFSDKViewUtils.styleNavigationBar(navigationBar, config: config, classes: classes)
    }

    // MARK: - Host list view

    @objc public func showHostListView() {
        let hostListVC = createLoginHostListViewController()
        let navController = SFSDKNavigationController(rootViewController: hostListVC)
        navController.modalPresentationStyle = .pageSheet
        present(navController, animated: true, completion: nil)
    }

    @objc public func hideHostListView(_ animated: Bool) {
        dismiss(animated: animated, completion: nil)
    }

    @objc public func handleLoginHostSelectedAction(_ newLoginHost: SalesforceLoginHost) {
        delegate?.loginViewController?(self, didChangeLoginHost: newLoginHost)
    }

    // MARK: - LoginHostDelegate

    public func hostListViewControllerDidAddLoginHost(_ hostListViewController: LoginHostListViewController) {
        hideHostListView(true)
    }

    public func hostListViewControllerDidSelectLoginHost(_ hostListViewController: LoginHostListViewController) {
        hideHostListView(true)
    }

    public func hostListViewControllerDidCancelLoginHost(_ hostListViewController: LoginHostListViewController) {
        hideHostListView(true)
    }

    public func hostListViewController(_ hostListViewController: LoginHostListViewController, didChange newLoginHost: SalesforceLoginHost) {
        handleLoginHostSelectedAction(newLoginHost)
    }

    // MARK: - UserAccountManagerDelegate

    public func userAccountManager(_ userAccountManager: UserAccountManager, willSwitch fromUser: UserAccount?, toUser: UserAccount?) {
        previousUserAccount = fromUser
    }
}
