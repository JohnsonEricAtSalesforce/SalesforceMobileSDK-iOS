// LoginHostListViewController.swift
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

private let cellIdentifier = "SFDCLoginHostListCellIdentifier"

/// Displays a list of hosts that can be used for login.
@objc(SFSDKLoginHostListViewController)
@objcMembers
public class LoginHostListViewController: UITableViewController, UINavigationControllerDelegate {

    @objc public weak var delegate: LoginHostDelegate?
    @objc public var hidesCancelButton: Bool = false
    @objc public var hidesAddButton: Bool = false

    /// Marks this host list as a standalone login screen rather than a sub-sheet of another login
    /// screen. This is the case in the forced-advanced-auth path, where the host list is the screen
    /// the user lands on and SFLoginViewController (which would otherwise own this chrome) is never
    /// created.
    ///
    /// When set, this screen takes on the chrome that normally lives on SFLoginViewController: the
    /// navigation-bar back button (shown when there is an account or flow to return to) and the
    /// dev-only gear / "Login Options" menu. The two are gated independently — the back button by
    /// the account/flow logic in `shouldShowBackButton()`, the gear by dev-support being enabled —
    /// this flag only distinguishes the standalone-screen role from the sub-sheet role.
    ///
    /// Defaults to `false` so the transient "Choose Connection" sub-sheet and the IdP flow, which
    /// are presented on top of a screen that already owns this chrome, are unaffected.
    @objc public var presentedAsLoginScreen: Bool = false
    @objc public var config: SFSDKViewControllerConfig?

    // MARK: - Private helpers

    private func applyLoginHost(at index: UInt) {
        let loginHost = SFSDKLoginHostStorage.sharedInstance.loginHost(at: index)
        delegate?.hostListViewController?(self, didChange: loginHost)
    }

    private func makeLoginHostVisible(at index: UInt) {
        tableView.scrollToRow(at: IndexPath(row: Int(index), section: 0), at: .top, animated: false)
    }

    private func indexOfCurrentLoginHost() -> UInt {
        let currentLoginHost = UserAccountManager.shared.loginHost
        let numberOfHosts = SFSDKLoginHostStorage.sharedInstance.numberOfLoginHosts
        for index in 0..<numberOfHosts {
            let loginHost = SFSDKLoginHostStorage.sharedInstance.loginHost(at: index)
            if loginHost.host == currentLoginHost {
                return index
            }
        }
        return UInt(NSNotFound)
    }

    @objc public func addLoginHost(_ host: SalesforceLoginHost) {
        SFSDKLoginHostStorage.sharedInstance.addLoginHost(host)
        let hostIndex = SFSDKLoginHostStorage.sharedInstance.indexOfLoginHost(host)
        if hostIndex != UInt(NSNotFound) {
            applyLoginHost(at: hostIndex)
            delegateDidAddLoginHost()
        }
    }

    @objc public func showAddLoginHost() {
        showAddLoginHost(nil)
    }

    @objc private func showAddLoginHost(_ sender: Any?) {
        let detailViewController = NewLoginHostViewController.viewController(config: config) { [weak self] (host: String, label: String?) in
            guard let self = self else { return }
            self.addLoginHost(SalesforceLoginHost.host(withName: label ?? "", host: host, deletable: true))
        }

        delegate?.hostListViewController?(self, willPresentLoginHostViewController: self)

        if let navController = navigationController {
            navController.delegate = self
            navController.pushViewController(detailViewController, animated: true)
        } else {
            present(detailViewController, animated: true, completion: nil)
        }
    }

    // MARK: - View lifecycle

    private func resizeContentForPopover() {
        let r = tableView.rect(forSection: 0)
        let size = CGSize(width: 380, height: r.size.height)
        preferredContentSize = size
    }

    public override func viewDidLoad() {
        // Right bar buttons. In the forced-advanced-auth path the gear / "Login Options" menu
        // is shown alongside the Add button (matching the in-app login screen). The 'Add Server'
        // button is shown only if the MDM policy allows it.
        var rightItems: [UIBarButtonItem] = []
        if let settingsButton = loginOptionsButton() {
            rightItems.append(settingsButton)
        }
        let managedPreferences = SFManagedPreferences.sharedPreferences
        if !(managedPreferences.hasManagedPreferences && managedPreferences.onlyShowAuthorizedHosts) && !hidesAddButton {
            rightItems.append(UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(showAddLoginHost(_:))))
        }
        if !rightItems.isEmpty {
            navigationItem.rightBarButtonItems = rightItems
        }
        title = SFSDKResourceUtils.localizedString("LOGIN_CHOOSE_SERVER")
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)

        // Left bar button. In the forced-advanced-auth path the back button replaces Cancel when
        // there is an account to return to (matching the WebView screen); otherwise Cancel is used.
        if presentedAsLoginScreen && shouldShowBackButton() {
            navigationItem.leftBarButtonItem = createBackButton()
        } else if !hidesCancelButton {
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelLoginPicker(_:)))
        }

        var index = indexOfCurrentLoginHost()
        if index == UInt(NSNotFound) {
            index = 0
            applyLoginHost(at: index)
        }

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellIdentifier)
        tableView.reloadData()
        makeLoginHostVisible(at: index)
        resizeContentForPopover()
        super.viewDidLoad()
        edgesForExtendedLayout = []
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(notification: .screenChanged, argument: view)
        }
    }

    public override func viewWillAppear(_ animated: Bool) {
        setupBrandingForNavBar()
        tableView.reloadData()
        resizeContentForPopover()
        super.viewWillAppear(animated)
    }

    private func setupBrandingForNavBar() {
        navigationController?.navigationBar.isTranslucent = false
        if let navBar = navigationController?.navigationBar {
            let classes: [UIAppearanceContainer.Type] = [type(of: self) as UIAppearanceContainer.Type]
            SFSDKViewUtils.styleNavigationBar(navBar, config: UserAccountManager.shared.loginViewControllerConfig, classes: classes)
        }
    }

    // MARK: - Actions

    @objc private func cancelLoginPicker(_ sender: Any?) {
        delegateDidCancelLoginHost()
    }

    @objc private func backToPreviousHost(_ sender: Any?) {
        handleBackButtonAction()
    }

    // MARK: - Forced Advanced Auth Chrome
    // The back button and gear / "Login Options" menu below mirror SFLoginViewController. They are
    // added when presentedAsLoginScreen is set, i.e. when the host list is the screen the user lands
    // on in the forced-advanced-auth path (SFLoginViewController is never created there). The two are
    // gated independently: the back button by shouldShowBackButton() (account/flow state), the gear
    // by dev support. presentedAsLoginScreen only gates whether this screen owns that chrome at all.

    /// Mirrors SFLoginViewController.shouldShowBackButton(): shows the back button when there is an
    /// account to return to, or when an idp / web-auth-fallback flow is in progress.
    @objc public func shouldShowBackButton() -> Bool {
        if BiometricAuthenticationManagerInternal.shared.locked {
            return false
        }

        let accountManager = UserAccountManager.shared
        if presentedAsLoginScreen,
           let loginConfig = config as? SalesforceLoginViewControllerConfig,
           loginConfig.shouldDisplayBackButton {
            return true
        }
        if accountManager.isIDPEnabled || accountManager.shouldFallbackToWebAuthentication {
            return true
        }
        let totalAccounts = accountManager.userAccounts()?.count ?? 0
        return totalAccounts > 0 && accountManager.currentUserAccount != nil
    }

    @objc public func createBackButton() -> UIBarButtonItem {
        let image = SFSDKResourceUtils.imageNamed("globalheader-back-arrow")?.withRenderingMode(.alwaysTemplate)
        return UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(backToPreviousHost(_:)))
    }

    /// Mirrors SFLoginViewController.handleBackButtonAction(): stops the in-flight auth and dismisses
    /// the auth window so the user returns to the account list.
    @objc public func handleBackButtonAction() {
        let scene = view.window?.windowScene
        let accountManager = UserAccountManager.shared
        accountManager.stopCurrentAuthentication(nil)

        if accountManager.shouldFallbackToWebAuthentication {
            accountManager.shouldFallbackToWebAuthentication = false
            _ = accountManager.loginWithCompletion(nil, failure: nil)
        }

        if !accountManager.isIDPEnabled {
            SFSDKWindowManager.shared.authWindow(scene).viewController?.presentedViewController?.dismiss(animated: false) {
                SFSDKWindowManager.shared.authWindow(scene).dismissWindow()
            }
        } else {
            SFSDKWindowManager.shared.authWindow(scene).viewController?.dismiss(animated: false, completion: nil)
        }
    }

    /// Builds the gear menu hosting the debug-only "Login Options" entry. Returns nil unless this is
    /// the forced-advanced-auth host list and dev support is enabled; the menu's only purpose here is
    /// to surface Login Options (the WebView-specific clear-cookies/cache/reload actions do not apply
    /// to the host list, where no in-app WebView is shown).
    @objc public func loginOptionsButton() -> UIBarButtonItem? {
        guard presentedAsLoginScreen, SalesforceSDKManager.shared.isDevSupportEnabled else {
            return nil
        }

        let image = SFSDKResourceUtils.imageNamed("login-window-gear")?.withRenderingMode(.alwaysTemplate)
        let loginOptions = UIAction(title: SFSDKResourceUtils.localizedString("LOGIN_OPTIONS"), image: nil, identifier: nil) { [weak self] _ in
            guard let self = self else { return }
            let configPicker = LoginOptionsViewController.makeViewController {
                self.dismiss(animated: true) {
                    self.delegateDidChangeLoginOptions()
                }
            }
            self.present(configPicker, animated: true, completion: nil)
        }

        let menu = UIMenu(title: "", children: [loginOptions])
        let settingsButton = UIBarButtonItem(image: image, menu: menu)
        settingsButton.accessibilityLabel = SFSDKResourceUtils.localizedString("LOGIN_SETTINGS_BUTTON")
        settingsButton.accessibilityIdentifier = "settings"
        return settingsButton
    }

    // MARK: - Delegate wrappers

    private func delegateDidAddLoginHost() {
        delegate?.hostListViewControllerDidAddLoginHost?(self)
    }

    private func delegateDidSelectLoginHost() {
        delegate?.hostListViewControllerDidSelectLoginHost?(self)
    }

    private func delegateDidCancelLoginHost() {
        delegate?.hostListViewControllerDidCancelLoginHost?(self)
    }

    private func delegateDidChangeLoginOptions() {
        delegate?.hostListViewControllerDidChangeLoginOptions?(self)
    }

    // MARK: - UITableViewDataSource

    public override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    public override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Int(SFSDKLoginHostStorage.sharedInstance.numberOfLoginHosts)
    }

    public override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let selectionDeleted = (indexPath.row == Int(indexOfCurrentLoginHost()))

            tableView.beginUpdates()
            SFSDKLoginHostStorage.sharedInstance.removeLoginHost(at: UInt(indexPath.row))
            tableView.deleteRows(at: [indexPath], with: .fade)
            tableView.endUpdates()

            if selectionDeleted {
                applyLoginHost(at: 0)
                makeLoginHostVisible(at: 0)
                tableView.reloadData()
            }

            resizeContentForPopover()
        }
    }

    public override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return SFSDKLoginHostStorage.sharedInstance.loginHost(at: UInt(indexPath.row)).deletable
    }

    public override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if indexOfCurrentLoginHost() == UInt(indexPath.row) {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }
    }

    public override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)
        let loginHost = SFSDKLoginHostStorage.sharedInstance.loginHost(at: UInt(indexPath.row))
        if loginHost.name.count > 0 {
            cell.textLabel?.text = loginHost.name
        } else {
            cell.textLabel?.text = loginHost.host
        }
        return cell
    }

    // MARK: - UITableViewDelegate

    public override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        applyLoginHost(at: UInt(indexPath.row))
        tableView.reloadData()
        delegateDidSelectLoginHost()
    }

    // MARK: - UINavigationControllerDelegate

    public func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        if viewController is LoginHostListViewController {
            tableView.reloadData()
            resizeContentForPopover()
        }
    }
}
