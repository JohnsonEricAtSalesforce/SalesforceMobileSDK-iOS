/*
 SFSDKUserSelectionTableViewController.swift
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

private let kVerticalSpace: CGFloat = 16
private let kHorizontalSpace: CGFloat = 12

@objc protocol UIFooterViewDelegate {
    func createUser()
}

@objc(SFSDKUserSelectionTableViewController)
public class SFSDKUserSelectionTableViewController: UIViewController, SFSDKUserSelectionView {

    @objc public var selectedAccount: UserAccount?
    @objc public weak var userSelectionDelegate: SFSDKUserSelectionViewDelegate?
    @objc public var spAppOptions: [AnyHashable: Any]?
    @objc public var navigationBar: UINavigationBar?
    @objc public var tableView: UITableView!

    private var userData: [UserAccount] = []

    public override func loadView() {
        super.loadView()

        tableView = createTableView()
        view.backgroundColor = UIColor.salesforceSystemBackgroundColor
        title = SFSDKResourceUtils.localizedString("idpSelectUserTitleLabel")

        let headerView = createHeaderView()
        let footerView = createFooterView()
        tableView = createTableView()

        tableView.tableFooterView = footerView
        tableView.tableFooterView?.bottomAnchor.constraint(equalTo: tableView.bottomAnchor).isActive = true
        tableView.heightAnchor.constraint(equalToConstant: (view.bounds.size.height * 3) / 4).isActive = true
        tableView.widthAnchor.constraint(equalToConstant: view.bounds.size.width).isActive = true

        let stack = UIStackView(frame: .zero)
        stack.backgroundColor = UIColor.salesforceSystemBackgroundColor
        stack.distribution = .equalSpacing
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.spacing = 0
        stack.axis = .vertical
        stack.addArrangedSubview(headerView)
        stack.addArrangedSubview(tableView)

        view.addSubview(stack)
        edgesForExtendedLayout = []

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor),
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        initData()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.reloadData()
    }

    private func initData() {
        let loginHost = spAppOptions?[kSFLoginHostParam] as? String
        userData = filterUsers(byHost: loginHost, data: UserAccountManager.shared.userAccounts() ?? [])
    }

    private func filterUsers(byHost host: String?, data accounts: [UserAccount]) -> [UserAccount] {
        guard let host = host else { return accounts }
        let hostPredicate = NSPredicate(format: "credentials.domain==%@", host)
        return (accounts as NSArray).filtered(using: hostPredicate) as? [UserAccount] ?? []
    }

    // MARK: - Factory Methods

    @objc public func createFooterView() -> UIView {
        let footerView = UIFooterView()
        footerView.footerDelegate = self
        return footerView
    }

    @objc public func createTableView() -> UITableView {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.backgroundColor = UIColor.salesforceSystemBackgroundColor
        tableView.register(SFSDKUITableViewCell.self, forCellReuseIdentifier: SFSDKUITableViewCell.reuseCellIdentifier)
        return tableView
    }

    @objc public func createHeaderView() -> UIView {
        let appName = spAppOptions?[kSFAppNameParam] as? String ?? "Application"
        let headerView = UIHeaderView(frame: .zero, andAppName: appName)
        headerView.heightAnchor.constraint(equalToConstant: (view.bounds.size.height / 4) + 20).isActive = true
        headerView.widthAnchor.constraint(equalToConstant: view.bounds.size.width).isActive = true
        return headerView
    }

    @objc public class func resizeImage(_ originalImage: UIImage?, resizeSize size: CGSize) -> UIImage? {
        guard let originalImage = originalImage else { return nil }

        let actualHeight = originalImage.size.height
        let actualWidth = originalImage.size.width

        var oldRatio = actualWidth / actualHeight
        let newRatio = size.width / size.height

        var finalWidth: CGFloat
        var finalHeight: CGFloat

        if oldRatio < newRatio {
            oldRatio = size.height / actualHeight
            finalWidth = oldRatio * actualWidth
            finalHeight = size.height
        } else {
            oldRatio = size.width / actualWidth
            finalHeight = oldRatio * actualHeight
            finalWidth = size.width
        }

        let rect = CGRect(x: 0.0, y: 0.0, width: finalWidth, height: finalHeight)
        UIGraphicsBeginImageContext(rect.size)
        originalImage.draw(in: rect)
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resizedImage
    }
}

// MARK: - UITableViewDataSource
extension SFSDKUserSelectionTableViewController: UITableViewDataSource {
    public func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return userData.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SFSDKUITableViewCell.reuseCellIdentifier, for: indexPath) as! SFSDKUITableViewCell

        let userAccount = userData[indexPath.row]
        cell.userName = "\(userAccount.idData?.firstName ?? "") \(userAccount.idData?.lastName ?? "")"
        cell.hostName = "\(userAccount.credentials.domain ?? "")"

        cell.imageURL = userAccount.idData?.profileUrl
        if let photo = userAccount.photo {
            cell.profileImage = photo
        }

        // Don't allow these users to be selected
        if userAccount.idData?.nativeLogin == true {
            cell.isUserInteractionEnabled = false
            cell.selectionStyle = .none
        }

        return cell
    }
}

// MARK: - UITableViewDelegate
extension SFSDKUserSelectionTableViewController: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return SFSDKUITableViewCell.cellHeight
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        if let options = spAppOptions {
            userSelectionDelegate?.selectedUser(userData[indexPath.row], spAppContext: options)
        }
    }
}

// MARK: - UIFooterViewDelegate
extension SFSDKUserSelectionTableViewController: UIFooterViewDelegate {
    func createUser() {
        if let options = spAppOptions {
            userSelectionDelegate?.createNewUser(options)
        }
    }
}

// MARK: - UIHeaderView
private class UIHeaderView: UIView {
    var logoView: UIImageView!
    var descriptionLabel: UILabel!
    var appNameLabel: UILabel!
    var appName: String

    init(frame: CGRect, andAppName appName: String) {
        self.appName = appName
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        self.appName = "Application"
        super.init(coder: coder)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let logotmp = SFSDKResourceUtils.imageNamed("salesforce-logo")?.withRenderingMode(.alwaysOriginal)
        let logo = SFSDKUserSelectionTableViewController.resizeImage(logotmp, resizeSize: CGSize(width: 150, height: 120))

        logoView = UIImageView(image: logo)
        logoView.contentMode = .scaleToFill
        backgroundColor = UIColor.salesforceSystemBackgroundColor

        descriptionLabel = UILabel()
        appNameLabel = UILabel()
        descriptionLabel.text = SFSDKResourceUtils.localizedString("idpSelectUserLabel")
        appNameLabel.text = appName
        descriptionLabel.font = UIFont.sfsdk_textRegular(16.0)
        descriptionLabel.textColor = UIColor.salesforceAltTextColor
        appNameLabel.font = UIFont.sfsdk_textRegular(16.0)
        appNameLabel.textColor = UIColor.salesforceAltTextColor

        superview?.addSubview(logoView)
        superview?.addSubview(descriptionLabel)
        superview?.addSubview(appNameLabel)

        logoView.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        appNameLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            logoView.topAnchor.constraint(equalTo: topAnchor, constant: kVerticalSpace),
            logoView.centerXAnchor.constraint(equalTo: centerXAnchor),
            descriptionLabel.topAnchor.constraint(equalTo: logoView.bottomAnchor, constant: kVerticalSpace),
            descriptionLabel.centerXAnchor.constraint(equalTo: logoView.centerXAnchor),
            appNameLabel.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: kHorizontalSpace),
            appNameLabel.centerXAnchor.constraint(equalTo: descriptionLabel.centerXAnchor)
        ])
    }
}

// MARK: - UIFooterView
private class UIFooterView: UIView {
    var addButton: UIButton!
    var descriptionLabel: UILabel!
    weak var footerDelegate: UIFooterViewDelegate?

    override func layoutSubviews() {
        super.layoutSubviews()

        backgroundColor = UIColor.salesforceSystemBackgroundColor
        let addAccountImageTmp = SFSDKResourceUtils.imageNamed("account-add")?.withRenderingMode(.alwaysOriginal)
        let addAccountImage = SFSDKUserSelectionTableViewController.resizeImage(addAccountImageTmp, resizeSize: CGSize(width: 18, height: 18))

        addButton = UIButton(type: .custom)
        addButton.setBackgroundImage(addAccountImage, for: .normal)
        descriptionLabel = UILabel()
        descriptionLabel.text = SFSDKResourceUtils.localizedString("idpAddNewAccountLabel")
        descriptionLabel.font = UIFont.sfsdk_textRegular(16)
        descriptionLabel.textColor = UIColor.salesforceDefaultTextColor

        addButton.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false

        superview?.addSubview(addButton)
        superview?.addSubview(descriptionLabel)
        addButton.addTarget(self, action: #selector(createUser), for: .touchDown)

        NSLayoutConstraint.activate([
            addButton.leftAnchor.constraint(equalTo: leftAnchor, constant: kHorizontalSpace * 3),
            addButton.topAnchor.constraint(equalTo: topAnchor, constant: kVerticalSpace),
            descriptionLabel.leftAnchor.constraint(equalTo: addButton.rightAnchor, constant: kHorizontalSpace),
            descriptionLabel.topAnchor.constraint(equalTo: topAnchor, constant: kVerticalSpace)
        ])
    }

    @objc func createUser() {
        footerDelegate?.createUser()
    }
}
