/*
 SFSDKLoginFlowSelectionViewController.swift
 SalesforceSDKCore

 Created by Raj Rao on 8/28/17.

 Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.

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

@objc(SFSDKLoginFlowSelectionViewController)
public class SFSDKLoginFlowSelectionViewController: UIViewController, SFSDKLoginFlowSelectionView {

    @objc public weak var selectionFlowDelegate: SFSDKLoginFlowSelectionViewDelegate?
    @objc public var appOptions: [AnyHashable: Any]?

    private var navBar: UINavigationBar?
    private var navBarFont: UIFont?
    private var navBarTextColor: UIColor?
    private var navBarColor: UIColor?
    private var showNavbar: Bool = true
    private var loginHostListViewController: LoginHostListViewController?

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
        // as this view is not part of navigation controller stack, needs to set the proper view background so that status bar has the
        // right background color
        view.backgroundColor = .white
        if showNavbar {
            setupNavigationBar()
        }
        setupContent()
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
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

    private func setupNavigationBar() {
        navBar = navigationController?.navigationBar
        var title = SFSDKResourceUtils.localizedString("TITLE_LOGIN")
        if title.isEmpty {
            title = "Log In"
        }
        // Setup top item
        let item = UILabel(frame: .zero)
        item.text = title
        item.sizeToFit()

        navBar?.topItem?.titleView = item
        showSettingsIcon()
        #if !targetEnvironment(simulator) && !os(visionOS)
        setNeedsStatusBarAppearanceUpdate()
        #endif
    }

    @objc class func imageWithImage(_ image: UIImage, scaledToSize newSize: CGSize) -> UIImage {
        UIGraphicsBeginImageContext(newSize)
        image.draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return newImage
    }

    private func setupContent() {
        view.backgroundColor = UIColor.salesforceSystemBackgroundColor
        let darkblue = UIColor(displayP3Red: 20.0/255.0, green: 50.0/255.0, blue: 92.0/255.0, alpha: 1.0)
        navigationController?.navigationBar.barTintColor = darkblue
        navigationController?.navigationBar.isTranslucent = false

        navigationController?.navigationBar.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 20, weight: .regular)
        ]

        title = "Log in"

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(container)

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
        idpButton.backgroundColor = UIColor(displayP3Red: 0.0/255.0, green: 112.0/255.0, blue: 210.0/255.0, alpha: 1.0)
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
        appButton.backgroundColor = UIColor(displayP3Red: 0.0/255.0, green: 112.0/255.0, blue: 210.0/255.0, alpha: 1.0)
        appButton.layer.cornerRadius = 4.0
        appButton.addTarget(self, action: #selector(useLocalAction(_:)), for: .touchUpInside)

        container.addSubview(selectLabel)
        container.addSubview(idpLabel)
        container.addSubview(idpButton)
        container.addSubview(appLabel)
        container.addSubview(appButton)

        NSLayoutConstraint.activate([
            container.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            container.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            container.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 1.0, constant: -100),

            selectLabel.topAnchor.constraint(equalTo: container.topAnchor),
            selectLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),

            idpLabel.topAnchor.constraint(equalTo: selectLabel.bottomAnchor),
            idpLabel.leftAnchor.constraint(equalTo: container.leftAnchor),
            idpLabel.rightAnchor.constraint(equalTo: container.rightAnchor),

            idpButton.topAnchor.constraint(equalTo: idpLabel.bottomAnchor, constant: 14),
            idpButton.leftAnchor.constraint(equalTo: container.leftAnchor),
            idpButton.rightAnchor.constraint(equalTo: container.rightAnchor),
            idpButton.heightAnchor.constraint(equalToConstant: 50.0),

            appLabel.topAnchor.constraint(equalTo: idpButton.bottomAnchor, constant: 60),
            appLabel.leftAnchor.constraint(equalTo: container.leftAnchor),
            appLabel.rightAnchor.constraint(equalTo: container.rightAnchor),

            appButton.topAnchor.constraint(equalTo: appLabel.bottomAnchor, constant: 14),
            appButton.leftAnchor.constraint(equalTo: container.leftAnchor),
            appButton.rightAnchor.constraint(equalTo: container.rightAnchor),
            appButton.heightAnchor.constraint(equalToConstant: 50.0),
            appButton.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
    }

    private func styleNavigationBar(_ navigationBar: UINavigationBar?) {
        guard let navigationBar = navigationBar else { return }
        SFSDKViewUtils.styleNavigationBar(navigationBar, config: UserAccountManager.shared.loginViewControllerConfig, classes: [type(of: navigationController!)])
    }

    private func showSettingsIcon() {
        let managedPreferences = SFManagedPreferences.sharedPreferences()
        if !managedPreferences.onlyShowAuthorizedHosts && (managedPreferences.loginHosts?.count ?? 0) == 0 {
            let image = SFSDKResourceUtils.imageNamed("login-window-gear")?.withRenderingMode(UIImage.RenderingMode.alwaysTemplate)
            let rightButton = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(showLoginHost(_:)))
            rightButton.accessibilityLabel = SFSDKResourceUtils.localizedString("LOGIN_CHOOSE_SERVER")
            navBar?.topItem?.rightBarButtonItem = rightButton
            navBar?.topItem?.rightBarButtonItem?.tintColor = UIColor.salesforceNavBarTintColor
        }
    }

    private func getLoginHostListViewController() -> LoginHostListViewController {
        if loginHostListViewController == nil {
            loginHostListViewController = LoginHostListViewController(style: .plain)
            loginHostListViewController?.delegate = self
        }
        return loginHostListViewController!
    }

    @objc func showLoginHost(_ sender: Any) {
        showHostListView()
    }

    @objc func useIDPAction(_ sender: Any) {
        selectionFlowDelegate?.loginFlowSelectionIDPSelected(self, options: appOptions ?? [:])
    }

    @objc func useLocalAction(_ sender: Any) {
        selectionFlowDelegate?.loginFlowSelectionLocalLoginSelected(self, options: appOptions ?? [:])
    }

    private func showHostListView() {
        let navController = UINavigationController(rootViewController: getLoginHostListViewController())
        navController.modalPresentationStyle = .pageSheet
        present(navController, animated: true, completion: nil)
    }

    private func hideHostListView(_ animated: Bool) {
        dismiss(animated: animated, completion: nil)
    }
}

// MARK: - SFSDKLoginHostDelegate
extension SFSDKLoginFlowSelectionViewController: SFSDKLoginHostDelegate {
    public func hostListViewControllerDidAddLoginHost(_ hostListViewController: LoginHostListViewController) {
        hideHostListView(false)
    }

    public func hostListViewControllerDidSelectLoginHost(_ hostListViewController: LoginHostListViewController) {
        hideHostListView(false)
    }

    public func hostListViewControllerDidCancelLoginHost(_ hostListViewController: LoginHostListViewController) {
        hideHostListView(true)
    }

    public func hostListViewController(_ hostListViewController: LoginHostListViewController, didChangeLoginHost newLoginHost: SalesforceLoginHost) {
        if appOptions == nil {
            appOptions = [:]
        }
        var mutableOptions = appOptions as? [AnyHashable: Any] ?? [:]
        mutableOptions[kSFLoginHostParam] = newLoginHost.host
        appOptions = mutableOptions
        selectionFlowDelegate?.loginFlowSelectionIDPSelected(self, options: appOptions ?? [:])
    }
}
