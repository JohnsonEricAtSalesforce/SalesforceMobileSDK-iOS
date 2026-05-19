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

import UIKit

/// Shows the list of users who have authenticated to this app, allowing the user to switch between
/// users, revoke credentials, etc.
@objc(SFDefaultUserManagementListViewController)
@objcMembers public class SalesforceUserManagementListViewController: UITableViewController {

    private static let cellIdentifier = "CellIdentifier"
    private static let headerIdentifier = "HeaderIdentifier"

    private var userAccountList: [UserAccount] = []
    private var hasCurrentUser: Bool = false

    // MARK: - View Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()

        view.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        navigationItem.title = "User List"

        let newUserItem = UIBarButtonItem(title: "New User", style: .plain, target: self, action: #selector(createNewUser))
        navigationItem.rightBarButtonItem = newUserItem

        let cancelItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        navigationItem.leftBarButtonItem = cancelItem
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let allAccounts = UserAccountManager.shared.userAccounts() ?? []
        userAccountList = accountListMinusCurrentUser(allAccounts)
        hasCurrentUser = (UserAccountManager.shared.currentUserAccount != nil)

        // If there's no current user, don't let the user cancel or dismiss the window before
        // selecting an existing user or logging into a new one
        navigationItem.leftBarButtonItem?.isEnabled = hasCurrentUser
        isModalInPresentation = !hasCurrentUser

        tableView.reloadData()
    }

    // MARK: - Private Methods

    private func accountListMinusCurrentUser(_ originalAccountList: [UserAccount]) -> [UserAccount] {
        let currentUser = UserAccountManager.shared.currentUserAccount
        return originalAccountList.filter { !$0.isEqual(currentUser) }
    }

    @objc private func createNewUser() {
        guard let mainController = navigationController as? SalesforceUserManagementViewController else { return }
        mainController.execCompletionBlock(.createNewUser, account: nil)
    }

    @objc private func cancel() {
        guard let mainController = navigationController as? SalesforceUserManagementViewController else { return }
        mainController.execCompletionBlock(.cancel, account: nil)
    }

    // MARK: - UITableViewDelegate

    public override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        var headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: Self.headerIdentifier)
        if headerView == nil {
            headerView = UITableViewHeaderFooterView(reuseIdentifier: Self.headerIdentifier)
        }
        if section == 0 {
            headerView?.textLabel?.text = "Current User"
        } else {
            headerView?.textLabel?.text = "Other Users"
        }
        return headerView
    }

    public override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)

        let selectedUser: UserAccount
        if indexPath.section == 0 {
            guard let current = UserAccountManager.shared.currentUserAccount else { return }
            selectedUser = current
        } else {
            selectedUser = userAccountList[indexPath.row]
        }

        let dvc = SalesforceUserManagementDetailViewController(user: selectedUser)
        navigationController?.pushViewController(dvc, animated: true)
    }

    // MARK: - UITableViewDataSource

    public override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    public override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return hasCurrentUser ? 1 : 0
        } else {
            return userAccountList.count
        }
    }

    public override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Self.cellIdentifier) ??
            UITableViewCell(style: .subtitle, reuseIdentifier: Self.cellIdentifier)

        let displayUser: UserAccount
        if indexPath.section == 0 {
            displayUser = UserAccountManager.shared.currentUserAccount ?? UserAccount()
        } else {
            displayUser = userAccountList[indexPath.row]
        }

        cell.textLabel?.text = displayUser.idData?.displayName
        cell.detailTextLabel?.text = displayUser.idData?.username
        cell.accessoryType = .disclosureIndicator

        return cell
    }
}
