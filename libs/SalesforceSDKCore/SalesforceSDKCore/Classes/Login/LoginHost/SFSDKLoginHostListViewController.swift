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
        let managedPreferences = SFManagedPreferences.sharedPreferences
        if !(managedPreferences.hasManagedPreferences && managedPreferences.onlyShowAuthorizedHosts) && !hidesAddButton {
            navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(showAddLoginHost(_:)))
        }
        title = SFSDKResourceUtils.localizedString("LOGIN_CHOOSE_SERVER")
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        if !hidesCancelButton {
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
