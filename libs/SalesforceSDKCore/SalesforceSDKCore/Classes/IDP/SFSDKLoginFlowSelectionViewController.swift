// SFSDKLoginFlowSelectionViewController.swift
// SalesforceSDKCore
//
// Created by Raj Rao on 8/28/17.
// Converted to Swift
//
// Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.
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

@objc(SFSDKLoginFlowSelectionViewController)
@objcMembers
public class SFSDKLoginFlowSelectionViewController: UIViewController, SFSDKLoginFlowSelectionView, LoginHostDelegate {

    public weak var selectionFlowDelegate: (any SFSDKLoginFlowSelectionViewDelegate)?
    public var appOptions: [AnyHashable: Any]?

    private var navBar: UINavigationBar?
    private var navBarFont: UIFont?
    private var navBarTextColor: UIColor?
    private var navBarColor: UIColor?
    private var showNavbar: Bool = true
    private var _loginHostListViewController: LoginHostListViewController?

    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        navBarColor = UIColor.salesforceBlueColor
        navBarFont = nil
        navBarTextColor = .white
        showNavbar = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        navBarColor = UIColor.salesforceBlueColor
        navBarFont = nil
        navBarTextColor = .white
        showNavbar = true
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        if showNavbar {
            setupNavigationBar()
        }
        setupContent()
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if showNavbar {
            styleNavigationBar(navBar)
        }
    }

    public override var prefersStatusBarHidden: Bool {
        return false
    }

    // MARK: - Navigation Bar

    private func setupNavigationBar() {
        navBar = navigationController?.navigationBar
        var title = SFSDKResourceUtils.localizedString("TITLE_LOGIN")
        if title == nil {
            title = "Log In"
        }

        let item = UILabel(frame: .zero)
        item.text = title
        item.sizeToFit()
        navBar?.topItem?.titleView = item
        showSettingsIcon()
        #if !os(visionOS)
        setNeedsStatusBarAppearanceUpdate()
        #endif
    }

    private func styleNavigationBar(_ navigationBar: UINavigationBar?) {
        guard let navigationBar = navigationBar else { return }
        let classes: [UIAppearanceContainer.Type] = [type(of: self) as UIAppearanceContainer.Type]
        SFSDKViewUtils.styleNavigationBar(navigationBar, config: UserAccountManager.shared.loginViewControllerConfig, classes: classes)
    }

    private func showSettingsIcon() {
        let managedPreferences = SFManagedPreferences.sharedPreferences
        if !managedPreferences.onlyShowAuthorizedHosts && (managedPreferences.loginHosts?.count ?? 0) == 0 {
            let image = SFSDKResourceUtils.imageNamed("login-window-gear")?.withRenderingMode(.alwaysTemplate)
            let rightButton = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(showLoginHost(_:)))
            rightButton.accessibilityLabel = SFSDKResourceUtils.localizedString("LOGIN_CHOOSE_SERVER")
            navBar?.topItem?.rightBarButtonItem = rightButton
            navBar?.topItem?.rightBarButtonItem?.tintColor = UIColor.salesforceNavBarTintColor
        }
    }

    // MARK: - Content

    private func setupContent() {
        view.backgroundColor = UIColor.salesforceSystemBackgroundColor
        let darkblue = UIColor(displayP3Red: 20.0 / 255.0, green: 50.0 / 255.0, blue: 92.0 / 255.0, alpha: 1.0)
        navigationController?.navigationBar.barTintColor = darkblue
        navigationController?.navigationBar.isTranslucent = false
        navigationController?.navigationBar.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 20, weight: .regular)
        ]

        self.title = "Log in"
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(container)
        container.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        container.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
        container.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 1.0, constant: -100).isActive = true

        let selectLabel = UILabel()
        selectLabel.translatesAutoresizingMaskIntoConstraints = false
        selectLabel.text = "Select a login flow"
        selectLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        selectLabel.textAlignment = .center
        selectLabel.textColor = UIColor.salesforceLabelColor

        let idpLabel = UILabel()
        idpLabel.translatesAutoresizingMaskIntoConstraints = false
        idpLabel.text = "Use the IDP option if you prefer to share your credentials between multiple apps"
        idpLabel.numberOfLines = 2
        idpLabel.lineBreakMode = .byWordWrapping
        idpLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        idpLabel.textAlignment = .center
        idpLabel.textColor = UIColor.salesforceLabelColor

        let idpButton = UIButton(type: .custom)
        idpButton.translatesAutoresizingMaskIntoConstraints = false
        idpButton.setTitle("Log in Using IDP Application", for: .normal)
        idpButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        idpButton.backgroundColor = UIColor(displayP3Red: 0.0 / 255.0, green: 112.0 / 255.0, blue: 210.0 / 255.0, alpha: 1.0)
        idpButton.layer.cornerRadius = 4.0
        idpButton.addTarget(self, action: #selector(useIDPAction(_:)), for: .touchUpInside)

        let appLabel = UILabel()
        appLabel.translatesAutoresizingMaskIntoConstraints = false
        appLabel.text = "Use this option if you prefer to use your credentials for this app only."
        appLabel.lineBreakMode = .byWordWrapping
        appLabel.numberOfLines = 2
        appLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        appLabel.textColor = UIColor.salesforceLabelColor

        let appButton = UIButton(type: .custom)
        appButton.translatesAutoresizingMaskIntoConstraints = false
        appButton.setTitle("Log in Using App", for: .normal)
        appButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        appButton.backgroundColor = UIColor(displayP3Red: 0.0 / 255.0, green: 112.0 / 255.0, blue: 210.0 / 255.0, alpha: 1.0)
        appButton.layer.cornerRadius = 4.0
        appButton.addTarget(self, action: #selector(useLocalAction(_:)), for: .touchUpInside)

        container.addSubview(selectLabel)
        container.addSubview(idpLabel)
        container.addSubview(idpButton)
        container.addSubview(appLabel)
        container.addSubview(appButton)

        selectLabel.topAnchor.constraint(equalTo: container.topAnchor).isActive = true
        selectLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor).isActive = true

        idpLabel.topAnchor.constraint(equalTo: selectLabel.bottomAnchor).isActive = true
        idpLabel.leftAnchor.constraint(equalTo: container.leftAnchor).isActive = true
        idpLabel.rightAnchor.constraint(equalTo: container.rightAnchor).isActive = true

        idpButton.topAnchor.constraint(equalTo: idpLabel.bottomAnchor, constant: 14).isActive = true
        idpButton.leftAnchor.constraint(equalTo: container.leftAnchor).isActive = true
        idpButton.rightAnchor.constraint(equalTo: container.rightAnchor).isActive = true
        idpButton.heightAnchor.constraint(equalToConstant: 50.0).isActive = true

        appLabel.topAnchor.constraint(equalTo: idpButton.bottomAnchor, constant: 60).isActive = true
        appLabel.leftAnchor.constraint(equalTo: container.leftAnchor).isActive = true
        appLabel.rightAnchor.constraint(equalTo: container.rightAnchor).isActive = true

        appButton.topAnchor.constraint(equalTo: appLabel.bottomAnchor, constant: 14).isActive = true
        appButton.leftAnchor.constraint(equalTo: container.leftAnchor).isActive = true
        appButton.rightAnchor.constraint(equalTo: container.rightAnchor).isActive = true
        appButton.heightAnchor.constraint(equalToConstant: 50.0).isActive = true
        appButton.bottomAnchor.constraint(equalTo: container.bottomAnchor).isActive = true
    }

    // MARK: - Actions

    @objc private func showLoginHost(_ sender: Any) {
        showHostListView()
    }

    @objc private func useIDPAction(_ sender: Any) {
        selectionFlowDelegate?.loginFlowSelectionIDPSelected(self, options: appOptions ?? [:])
    }

    @objc private func useLocalAction(_ sender: Any) {
        selectionFlowDelegate?.loginFlowSelectionLocalLoginSelected(self, options: appOptions ?? [:])
    }

    // MARK: - Login Host

    private var loginHostListViewController: LoginHostListViewController {
        if _loginHostListViewController == nil {
            _loginHostListViewController = LoginHostListViewController(style: .plain)
            _loginHostListViewController?.delegate = self
        }
        return _loginHostListViewController ?? LoginHostListViewController(style: .plain)
    }

    private func showHostListView() {
        let navController = UINavigationController(rootViewController: loginHostListViewController)
        navController.modalPresentationStyle = .pageSheet
        present(navController, animated: true, completion: nil)
    }

    private func hideHostListView(animated: Bool) {
        dismiss(animated: animated, completion: nil)
    }

    // MARK: - LoginHostDelegate

    public func hostListViewControllerDidAddLoginHost(_ hostListViewController: LoginHostListViewController) {
        hideHostListView(animated: false)
    }

    public func hostListViewControllerDidSelectLoginHost(_ hostListViewController: LoginHostListViewController) {
        hideHostListView(animated: false)
    }

    public func hostListViewControllerDidCancelLoginHost(_ hostListViewController: LoginHostListViewController) {
        hideHostListView(animated: true)
    }

    public func hostListViewController(_ hostListViewController: LoginHostListViewController, didChange newLoginHost: SalesforceLoginHost) {
        var mutableOptions = appOptions ?? [:]
        mutableOptions[SFSDKIDPConstants.kSFLoginHostParam] = newLoginHost.host
        appOptions = mutableOptions
        selectionFlowDelegate?.loginFlowSelectionIDPSelected(self, options: appOptions ?? [:])
    }
}
