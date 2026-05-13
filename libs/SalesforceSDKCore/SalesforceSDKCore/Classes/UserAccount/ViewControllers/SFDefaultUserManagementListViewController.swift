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

import UIKit

/// Shows the list of users who have authenticated to this app, allowing the user to switch between
/// users, revoke credentials, etc.
@objc(SFDefaultUserManagementListViewController)
open class SalesforceUserManagementListViewController: UITableViewController {

    // MARK: - Properties

    private var userAccountList: [UserAccount] = []
    private var hasCurrentUser = false

    // MARK: - Initialization

    public override init(style: UITableView.Style) {
        super.init(style: style)
    }

    required public init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    // MARK: - Lifecycle

    open override func viewDidLoad() {
        super.viewDidLoad()

        view.autoresizingMask = [.flexibleHeight, .flexibleWidth]

        navigationItem.title = "User List"

        let newUserItem = UIBarButtonItem(title: "New User", style: .plain, target: self, action: #selector(createNewUser))
        navigationItem.rightBarButtonItem = newUserItem

        let cancelItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        navigationItem.leftBarButtonItem = cancelItem
    }

    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // The account list is going to be easier to manage as a data source without the current user, since
        // the current user, if present, will be separated from the other users in the table view.
        if let allAccounts = UserAccountManager.shared.userAccounts() {
            userAccountList = accountListMinusCurrentUser(allAccounts)
        }
        hasCurrentUser = (UserAccountManager.shared.currentUserAccount != nil)

        // If there's no current user, don't let the user cancel or dismiss the window before
        // selecting an existing user or logging into a new one
        navigationItem.leftBarButtonItem?.isEnabled = hasCurrentUser
        isModalInPresentation = !hasCurrentUser

        tableView.reloadData()
    }

    // MARK: - Private Methods

    private func accountListMinusCurrentUser(_ originalAccountList: [UserAccount]) -> [UserAccount] {
        return originalAccountList.filter { !$0.isEqual(UserAccountManager.shared.currentUserAccount) }
    }

    @objc private func createNewUser() {
        if let mainController = navigationController as? SalesforceUserManagementViewController {
            mainController.execCompletionBlock(.createNewUser, account: nil)
        }
    }

    @objc private func cancel() {
        if let mainController = navigationController as? SalesforceUserManagementViewController {
            mainController.execCompletionBlock(.cancel, account: nil)
        }
    }

    // MARK: - UITableViewDelegate

    open override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let HeaderIdentifier = "HeaderIdentifier"

        let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: HeaderIdentifier) ?? UITableViewHeaderFooterView(reuseIdentifier: HeaderIdentifier)

        if section == 0 {
            headerView.textLabel?.text = "Current User"
        } else {
            headerView.textLabel?.text = "Other Users"
        }
        return headerView
    }

    open override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        let selectedUser = (indexPath.section == 0) ? UserAccountManager.shared.currentUserAccount : userAccountList[indexPath.row]
        if let selectedUser = selectedUser {
            let dvc = SalesforceUserManagementDetailViewController(user: selectedUser)
            navigationController?.pushViewController(dvc, animated: true)
        }
    }

    // MARK: - UITableViewDataSource

    open override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    open override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return hasCurrentUser ? 1 : 0
        } else {
            return userAccountList.count
        }
    }

    open override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let CellIdentifier = "CellIdentifier"

        let cell = tableView.dequeueReusableCell(withIdentifier: CellIdentifier) ?? UITableViewCell(style: .subtitle, reuseIdentifier: CellIdentifier)

        // Configure the cell to show the data.
        let displayUser = (indexPath.section == 0) ? UserAccountManager.shared.currentUserAccount : userAccountList[indexPath.row]

        cell.textLabel?.text = displayUser?.idData?.displayName
        cell.detailTextLabel?.text = displayUser?.idData?.username
        cell.accessoryType = .disclosureIndicator

        return cell
    }
}
