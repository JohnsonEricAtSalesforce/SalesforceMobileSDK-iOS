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

/// The various actions that may have been taken for account management.
@objc(SFUserManagementAction)
public enum SalesforceUserManagementAction: UInt {
    /// No action was taken.
    case cancel = 0
    /// A user was logged out.
    case logoutUser
    /// Switched from one user to another.
    case switchUser
    /// Logging in as a new user.
    case createNewUser
}

/// Type definition for the user management completion block.
public typealias SalesforceUserCompletionBlock = (SalesforceUserManagementAction) -> Void

/// View controller for managing the different users of the app.
@objc(SFDefaultUserManagementViewController)
open class SalesforceUserManagementViewController: UINavigationController {

    // MARK: - Properties

    @objc public var completionBlock: SalesforceUserCompletionBlock?
    @objc public var action: SalesforceUserManagementAction = .cancel
    @objc public var actionAccount: UserAccount?
    private var scene: UIScene?

    // MARK: - Initialization

    /// Creates an instance with the given completion block.
    /// - Parameter completionBlock: The (optional) completion block to execute once action has been taken.
    @objc public init(completionBlock: SalesforceUserCompletionBlock?) {
        super.init(nibName: nil, bundle: nil)
        self.completionBlock = completionBlock
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    // MARK: - Lifecycle

    open override func viewDidLoad() {
        super.viewDidLoad()
        navigationBar.backgroundColor = UIColor.salesforceSystemBackgroundColor
        let rvc = SalesforceUserManagementListViewController(style: .plain)
        pushViewController(rvc, animated: false)
    }

    // Don't take action before the user interface is cleared. Allow the consumer to drive the
    // flow of the app, avoid async state issues, etc.
    open override func viewDidDisappear(_ animated: Bool) {
        switch action {
        case .logoutUser:
            // If it's in this controller, it's logging out the current user.
            actionLogout()
        case .switchUser:
            if let actionAccount = actionAccount {
                actionSwitchUser(actionAccount)
            }
        case .createNewUser:
            actionCreateNewUser()
        case .cancel:
            break
        }
        super.viewDidDisappear(animated)
    }

    // MARK: - Actions

    private func actionLogout() {
        UserAccountManager.shared.logout(.userInitiated)
    }

    private func actionSwitchUser(_ user: UserAccount) {
        UserAccountManager.shared.switchToUserAccount(user)
    }

    private func actionCreateNewUser() {
        UserAccountManager.shared.switchToNewUser { error, newUser in
            if let error = error {
                SFSDKCoreLogger.e(type(of: self), message: "Attempt to add new user failed \(error.localizedDescription)")
            } else {
                SFSDKCoreLogger.d(type(of: self), message: "Switch to new User succeeded")
            }
        }
    }

    @objc public func execCompletionBlock(_ action: SalesforceUserManagementAction, account actionAccount: UserAccount?) {
        self.action = action
        self.actionAccount = actionAccount
        self.scene = view.window?.windowScene
        completionBlock?(action)
    }
}
