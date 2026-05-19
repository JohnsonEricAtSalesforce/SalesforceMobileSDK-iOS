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

private let kButtonWidth: CGFloat = 150.0
private let kButtonHeight: CGFloat = 40.0
private let kButtonPadding: CGFloat = 10.0
private let kControlVerticalPadding: CGFloat = 5.0

/// View controller for showing the user management details of a given user.
@objc(SFDefaultUserManagementDetailViewController)
@objcMembers public class SalesforceUserManagementDetailViewController: UIViewController {

    private let user: UserAccount
    private var fullNameLabel: UILabel?
    private var userNameLabel: UILabel?
    private var switchToUserButton: UIButton?
    private var logoutUserButton: UIButton?

    // MARK: - Initialization

    /// Initialize to provide the details of the given user.
    @objc public init(user: UserAccount) {
        self.user = user
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - View Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = "User Detail"
        view.backgroundColor = UIColor.salesforceSystemBackgroundColor
        edgesForExtendedLayout = []

        // fullName label
        let fullName = UILabel(frame: .zero)
        fullName.text = "\(user.idData?.firstName ?? "") \(user.idData?.lastName ?? "")"
        fullName.textAlignment = .center
        fullName.font = UIFont.systemFont(ofSize: 20.0)
        view.addSubview(fullName)
        self.fullNameLabel = fullName

        // userName label
        let userName = UILabel(frame: .zero)
        userName.text = user.idData?.username
        userName.textAlignment = .center
        userName.font = UIFont.systemFont(ofSize: 16.0)
        view.addSubview(userName)
        self.userNameLabel = userName

        // Switch to user button
        let switchButton = UIButton(type: .system)
        switchButton.setTitle("Switch to User", for: .normal)
        switchButton.isEnabled = !user.isEqual(UserAccountManager.shared.currentUserAccount)
        switchButton.addTarget(self, action: #selector(switchUserButtonClicked(_:)), for: .touchUpInside)
        view.addSubview(switchButton)
        self.switchToUserButton = switchButton

        // Logout user button
        let logoutButton = UIButton(type: .system)
        logoutButton.setTitle("Logout User", for: .normal)
        logoutButton.addTarget(self, action: #selector(logoutUserButtonClicked(_:)), for: .touchUpInside)
        view.addSubview(logoutButton)
        self.logoutUserButton = logoutButton

        layoutSubviews()
    }

    public override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        layoutSubviews()
    }

    // MARK: - Layout

    private func layoutSubviews() {
        guard let fullNameLabel = fullNameLabel,
              let userNameLabel = userNameLabel,
              let switchToUserButton = switchToUserButton,
              let logoutUserButton = logoutUserButton else { return }

        // fullNameLabel
        fullNameLabel.sizeToFit()
        let fullNameFrame = fullNameLabel.frame
        let fullNameLabelX = view.bounds.midX - (fullNameFrame.size.width / 2.0)
        fullNameLabel.frame = CGRect(x: fullNameLabelX,
                                     y: view.bounds.origin.y + kControlVerticalPadding,
                                     width: fullNameFrame.size.width,
                                     height: fullNameFrame.size.height)

        // userNameLabel
        userNameLabel.sizeToFit()
        let userNameFrame = userNameLabel.frame
        let userNameLabelX = view.bounds.midX - (userNameFrame.size.width / 2.0)
        userNameLabel.frame = CGRect(x: userNameLabelX,
                                     y: fullNameLabel.frame.maxY + kControlVerticalPadding,
                                     width: userNameFrame.size.width,
                                     height: userNameFrame.size.height)

        // switchToUserButton
        let totalButtonX = 2.0 * kButtonWidth + kButtonPadding
        let switchToUserX = view.bounds.midX - (totalButtonX / 2.0)
        let switchToUserY = userNameLabel.frame.maxY + kControlVerticalPadding
        switchToUserButton.frame = CGRect(x: switchToUserX, y: switchToUserY, width: kButtonWidth, height: kButtonHeight)

        // logoutUserButton
        let logoutUserX = switchToUserButton.frame.maxX + kButtonPadding
        let logoutUserY = userNameLabel.frame.maxY + kControlVerticalPadding
        logoutUserButton.frame = CGRect(x: logoutUserX, y: logoutUserY, width: kButtonWidth, height: kButtonHeight)
    }

    // MARK: - Actions

    @objc private func switchUserButtonClicked(_ sender: Any) {
        guard let mainController = navigationController as? SalesforceUserManagementViewController else { return }
        mainController.execCompletionBlock(.switchUser, account: user)
    }

    @objc private func logoutUserButtonClicked(_ sender: Any) {
        if user.isEqual(UserAccountManager.shared.currentUserAccount) {
            // Current user is a full logout and app state change.
            guard let mainController = navigationController as? SalesforceUserManagementViewController else { return }
            mainController.execCompletionBlock(.logoutUser, account: nil)
        } else {
            // Logging out a different user than the current user. Clear the account state and go
            // back to the user list.
            UserAccountManager.shared.logout(user, reason: .userInitiated)
            navigationController?.popViewController(animated: true)
        }
    }
}
