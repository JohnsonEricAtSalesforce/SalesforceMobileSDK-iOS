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

private let kButtonWidth: CGFloat = 150.0
private let kButtonHeight: CGFloat = 40.0
private let kButtonPadding: CGFloat = 10.0
private let kControlVerticalPadding: CGFloat = 5.0

/// View controller for showing the user management details of a given user.
@objc(SFDefaultUserManagementDetailViewController)
open class SalesforceUserManagementDetailViewController: UIViewController {

    // MARK: - Properties

    private let user: UserAccount
    private var fullNameLabel: UILabel!
    private var userNameLabel: UILabel!
    private var switchToUserButton: UIButton!
    private var logoutUserButton: UIButton!

    // MARK: - Initialization

    /// Initialize to provide the details of the given user.
    /// - Parameter user: The user providing the details.
    @objc public init(user: UserAccount) {
        self.user = user
        super.init(nibName: nil, bundle: nil)
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    open override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = "User Detail"
        view.backgroundColor = UIColor.salesforceSystemBackgroundColor
        if responds(to: #selector(setter: edgesForExtendedLayout)) {
            edgesForExtendedLayout = []
        }

        // fullName label
        fullNameLabel = UILabel(frame: .zero)
        fullNameLabel.text = "\(user.idData?.firstName ?? "") \(user.idData?.lastName ?? "")"
        fullNameLabel.textAlignment = .center
        fullNameLabel.font = UIFont.systemFont(ofSize: 20.0)
        view.addSubview(fullNameLabel)

        // userName label
        userNameLabel = UILabel(frame: .zero)
        userNameLabel.text = user.idData?.username
        userNameLabel.textAlignment = .center
        userNameLabel.font = UIFont.systemFont(ofSize: 16.0)
        view.addSubview(userNameLabel)

        // Switch to user button
        switchToUserButton = UIButton(type: .system)
        switchToUserButton.setTitle("Switch to User", for: .normal)
        switchToUserButton.isEnabled = !user.isEqual(UserAccountManager.shared.currentUserAccount)
        switchToUserButton.addTarget(self, action: #selector(switchUserButtonClicked(_:)), for: .touchUpInside)
        view.addSubview(switchToUserButton)

        // Logout user button
        logoutUserButton = UIButton(type: .system)
        logoutUserButton.setTitle("Logout User", for: .normal)
        logoutUserButton.addTarget(self, action: #selector(logoutUserButtonClicked(_:)), for: .touchUpInside)
        view.addSubview(logoutUserButton)

        layoutSubviews()
    }

    open override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        layoutSubviews()
    }

    // MARK: - Layout

    private func layoutSubviews() {
        // fullNameLabel
        fullNameLabel.sizeToFit()
        var fullNameFrame = fullNameLabel.frame
        let fullNameLabelX = view.bounds.midX - (fullNameLabel.frame.size.width / 2.0)
        fullNameLabel.frame = CGRect(x: fullNameLabelX, y: view.bounds.origin.y + kControlVerticalPadding, width: fullNameFrame.size.width, height: fullNameFrame.size.height)

        // userNameLabel
        userNameLabel.sizeToFit()
        let userNameFrame = userNameLabel.frame
        let userNameLabelX = view.bounds.midX - (userNameLabel.frame.size.width / 2.0)
        userNameLabel.frame = CGRect(x: userNameLabelX,
                                     y: fullNameLabel.frame.maxY + kControlVerticalPadding,
                                     width: userNameFrame.size.width,
                                     height: userNameFrame.size.height)

        // switchToUserButton
        let switchToUserWidth = kButtonWidth
        let switchToUserHeight = kButtonHeight
        let totalButtonX = 2.0 * kButtonWidth + kButtonPadding
        let switchToUserX = view.bounds.midX - (totalButtonX / 2.0)
        let switchToUserY = userNameLabel.frame.maxY + kControlVerticalPadding
        switchToUserButton.frame = CGRect(x: switchToUserX, y: switchToUserY, width: switchToUserWidth, height: switchToUserHeight)

        // logoutUserButton
        let logoutUserWidth = kButtonWidth
        let logoutUserHeight = kButtonHeight
        let logoutUserX = switchToUserButton.frame.maxX + kButtonPadding
        let logoutUserY = userNameLabel.frame.maxY + kControlVerticalPadding
        logoutUserButton.frame = CGRect(x: logoutUserX, y: logoutUserY, width: logoutUserWidth, height: logoutUserHeight)
    }

    // MARK: - Actions

    @IBAction private func switchUserButtonClicked(_ sender: Any) {
        if let mainController = navigationController as? SalesforceUserManagementViewController {
            mainController.execCompletionBlock(.switchUser, account: user)
        }
    }

    @IBAction private func logoutUserButtonClicked(_ sender: Any) {
        if user.isEqual(UserAccountManager.shared.currentUserAccount) {
            // Current user is a full logout and app state change.
            if let mainController = navigationController as? SalesforceUserManagementViewController {
                mainController.execCompletionBlock(.logoutUser, account: nil)
            }
        } else {
            // Logging out a different user than the current user. Clear the account state and go
            // back to the user list.
            UserAccountManager.shared.logout(user, reason: .userInitiated)
            navigationController?.popViewController(animated: true)
        }
    }
}
