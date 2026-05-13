/*
 SFSDKLoginHostListViewController.swift
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

private let SFDCLoginHostListCellIdentifier = "SFDCLoginHostListCellIdentifier"

/// Displays a list of hosts that can be used for login.
/// A customer can either add a new host or select an existing host to reload the login web page.
@objc(SFSDKLoginHostListViewController)
@objcMembers
public class LoginHostListViewController: UITableViewController {

    /// Delegate object of the host list view controller.
    public weak var delegate: SFSDKLoginHostDelegate?

    /// Hides the Cancel button if it exists. If you've used a navigation controller
    /// to present this view controller, a Cancel button is automatically added to
    /// the left bar button item.
    public var hidesCancelButton: Bool = false

    /// Hides the Add button if it exists.  Enables the adding of hosts to the host list.
    public var hidesAddButton: Bool = false

    public var config: SFSDKViewControllerConfig?

    // MARK: - Private Methods

    /// Apply (that is, reload the web view) with the host at the specified index.
    private func applyLoginHost(at index: Int) {
        let loginHost = SFSDKLoginHostStorage.shared.loginHost(at: index)
        delegate?.hostListViewController?(self, didChangeLoginHost: loginHost)
    }

    /// Scroll the table to make sure the host at the specified index is visible.
    private func makeLoginHostVisible(at index: Int) {
        tableView.scrollToRow(at: IndexPath(row: index, section: 0),
                             at: .top,
                             animated: false)
    }

    /// Returns the index of the current login host.
    private func indexOfCurrentLoginHost() -> Int {
        let accountManager = UserAccountManager.shared
        let currentLoginHost = accountManager.loginHost
        let numberOfLoginHosts = SFSDKLoginHostStorage.shared.numberOfLoginHosts()
        for index in 0..<numberOfLoginHosts {
            let loginHost = SFSDKLoginHostStorage.shared.loginHost(at: index)
            if loginHost.host == currentLoginHost {
                return index
            }
        }
        return NSNotFound
    }

    // MARK: - Public Methods

    /// Adds a new login host. Also updates the underlying storage and refreshes
    /// the list of login hosts.
    /// - Parameter host: Login host to be added.
    public func addLoginHost(_ host: SalesforceLoginHost) {
        SFSDKLoginHostStorage.shared.add(host)
        let hostIndex = SFSDKLoginHostStorage.shared.index(of: host)
        if hostIndex != NSNotFound {
            // Apply the selected login host
            applyLoginHost(at: hostIndex)

            // Notify the delegate that a new login host has been added.
            delegateDidAddLoginHost()
        }
    }

    /// Displays a view for adding a new login host.
    /// If you've used a navigation controller to present this view controller,
    /// an add button is automatically added to the right bar button item.
    public func showAddLoginHost() {
        showAddLoginHost(nil)
    }

    /// Invoked when the user presses the Add button. This method presents the new login host view.
    @objc private func showAddLoginHost(_ sender: Any?) {
        let detailViewController = NewLoginHostViewController.viewController(
            config: config,
            saveAction: { [weak self] (host: String, label: String?) in
                guard let self = self else { return }
                self.addLoginHost(SalesforceLoginHost.host(withName: label ?? "", host: host, deletable: true))
            }
        )

        delegate?.hostListViewController?(self, willPresentLoginHostViewController: detailViewController)

        if let navigationController = navigationController {
            navigationController.delegate = self
            navigationController.pushViewController(detailViewController, animated: true)
        } else {
            present(detailViewController, animated: true, completion: nil)
        }
    }

    // MARK: - View Lifecycle

    /// Set the proper size of the view so its popover controller will resize to fit neatly.
    private func resizeContentForPopover() {
        let rect = tableView.rect(forSection: 0)
        let size = CGSize(width: 380, height: rect.size.height)
        preferredContentSize = size
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        // Displays the 'Add Server' button only if the MDM policy allows us to.
        let managedPreferences = SFManagedPreferences.sharedPreferences()
        if !(managedPreferences.hasManagedPreferences && managedPreferences.onlyShowAuthorizedHosts) && !hidesAddButton {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .add,
                target: self,
                action: #selector(showAddLoginHost(_:))
            )
        }
        title = SFSDKResourceUtils.localizedString("LOGIN_CHOOSE_SERVER")
        navigationItem.backBarButtonItem = UIBarButtonItem(
            title: "",
            style: .plain,
            target: nil,
            action: nil
        )
        if !hidesCancelButton {
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .cancel,
                target: self,
                action: #selector(cancelLoginPicker(_:))
            )
        }

        // Make sure the current login host exists.
        var index = indexOfCurrentLoginHost()
        if index == NSNotFound {
            index = 0 // revert to standard in case there is no current login host
            applyLoginHost(at: index)
        }

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: SFDCLoginHostListCellIdentifier)

        // Refresh the UI and make sure the size is correct.
        tableView.reloadData()
        makeLoginHostVisible(at: index)
        resizeContentForPopover()
        edgesForExtendedLayout = []
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(notification: .screenChanged, argument: view)
        }
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // We need to make sure the table is refreshed
        // and the size updated when we appear because
        // a new host could have been added by the user.
        setupBrandingForNavBar()
        tableView.reloadData()
        resizeContentForPopover()
    }

    private func setupBrandingForNavBar() {
        navigationController?.navigationBar.isTranslucent = false
        if let navBar = navigationController?.navigationBar,
           let navControllerClass = navigationController?.classForCoder {
            SFSDKViewUtils.styleNavigationBar(
                navBar,
                config: UserAccountManager.shared.loginViewControllerConfig,
                classes: [navControllerClass]
            )
        }
    }

    // MARK: - Action Methods

    @objc private func cancelLoginPicker(_ sender: Any?) {
        delegateDidCancelLoginHost()
    }

    // MARK: - Delegate Wrapper Methods

    private func delegateDidAddLoginHost() {
        delegate?.hostListViewControllerDidAddLoginHost?(self)
    }

    private func delegateDidSelectLoginHost() {
        delegate?.hostListViewControllerDidSelectLoginHost?(self)
    }

    private func delegateDidCancelLoginHost() {
        delegate?.hostListViewControllerDidCancelLoginHost?(self)
    }

    // MARK: - UITableViewDataSource Methods

    public override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    public override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return SFSDKLoginHostStorage.shared.numberOfLoginHosts()
    }

    public override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        // Allow the swipe and delete action to take place
        if editingStyle == .delete {
            // Remember if the item being deleted is the current host
            let selectionDeleted = (indexPath.row == indexOfCurrentLoginHost())

            // Delete the item
            tableView.beginUpdates()
            SFSDKLoginHostStorage.shared.removeLoginHost(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
            tableView.endUpdates()

            // Update the current login host if it was deleted
            if selectionDeleted {
                applyLoginHost(at: 0)
                makeLoginHostVisible(at: 0)
                tableView.reloadData()
            }

            // Update the size now that we've deleted an item
            resizeContentForPopover()
        }
    }

    public override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return SFSDKLoginHostStorage.shared.loginHost(at: indexPath.row).isDeletable
    }

    public override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        // Set the checkmark when the current row is the current login host
        if indexOfCurrentLoginHost() == indexPath.row {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }
    }

    public override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SFDCLoginHostListCellIdentifier, for: indexPath)

        // Displays the name of the login host or the host itself if no name is specified
        let loginHost = SFSDKLoginHostStorage.shared.loginHost(at: indexPath.row)
        if !loginHost.name.isEmpty {
            cell.textLabel?.text = loginHost.name
        } else {
            cell.textLabel?.text = loginHost.host
        }

        return cell
    }

    // MARK: - UITableViewDelegate Methods

    public override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Apply the selected login host
        applyLoginHost(at: indexPath.row)

        // Reload the table to show the correct row with the checkmark.
        tableView.reloadData()

        // Notify the delegate.
        delegateDidSelectLoginHost()
    }
}

// MARK: - UINavigationControllerDelegate

extension LoginHostListViewController: UINavigationControllerDelegate {
    public func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        if viewController is LoginHostListViewController {
            tableView.reloadData()
            resizeContentForPopover()
        }
    }
}
