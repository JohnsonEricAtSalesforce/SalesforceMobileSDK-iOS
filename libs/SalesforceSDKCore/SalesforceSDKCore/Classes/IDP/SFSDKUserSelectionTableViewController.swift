// SFSDKUserSelectionTableViewController.swift
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

private let kVerticalSpace: CGFloat = 16
private let kHorizontalSpace: CGFloat = 12

@objc(SFSDKUserSelectionTableViewControllerDelegate)
public protocol SFSDKUserSelectionTableViewControllerDelegate: AnyObject {
    @objc func createNewuser(_ options: NSDictionary?)
    @objc func selectedUser(_ user: UserAccount?, options: NSDictionary?)
    @objc func cancel(_ options: NSDictionary?)
}

// MARK: - Header View

private class IDPHeaderView: UIView {
    var logoView: UIImageView?
    var descriptionLabel: UILabel?
    var appNameLabel: UILabel?
    var appName: String = ""

    init(frame: CGRect, appName: String) {
        self.appName = appName
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let logotmp = SFSDKResourceUtils.imageNamed("salesforce-logo")?.withRenderingMode(.alwaysOriginal)
        let logo = SFSDKUserSelectionTableViewController.resizeImage(logotmp, resizeSize: CGSize(width: 150, height: 120))

        let imgView = UIImageView(image: logo)
        imgView.contentMode = .scaleToFill
        self.backgroundColor = UIColor.salesforceSystemBackgroundColor

        let descLabel = UILabel()
        let nameLabel = UILabel()
        descLabel.text = SFSDKResourceUtils.localizedString("idpSelectUserLabel")
        nameLabel.text = appName
        descLabel.font = UIFont.sfsdk_textRegular(16.0)
        descLabel.textColor = UIColor.salesforceAltTextColor
        nameLabel.font = UIFont.sfsdk_textRegular(16.0)
        nameLabel.textColor = UIColor.salesforceAltTextColor

        superview?.addSubview(imgView)
        superview?.addSubview(descLabel)
        superview?.addSubview(nameLabel)

        imgView.translatesAutoresizingMaskIntoConstraints = false
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        imgView.topAnchor.constraint(equalTo: topAnchor, constant: kVerticalSpace).isActive = true
        imgView.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
        descLabel.topAnchor.constraint(equalTo: imgView.bottomAnchor, constant: kVerticalSpace).isActive = true
        descLabel.centerXAnchor.constraint(equalTo: imgView.centerXAnchor).isActive = true
        nameLabel.topAnchor.constraint(equalTo: descLabel.bottomAnchor, constant: kHorizontalSpace).isActive = true
        nameLabel.centerXAnchor.constraint(equalTo: descLabel.centerXAnchor).isActive = true

        self.logoView = imgView
        self.descriptionLabel = descLabel
        self.appNameLabel = nameLabel
    }
}

// MARK: - Footer View

private protocol IDPFooterViewDelegate: AnyObject {
    func createUser()
}

private class IDPFooterView: UIView {
    var addButton: UIButton?
    var descriptionLabel: UILabel?
    weak var footerDelegate: (any IDPFooterViewDelegate)?

    override func layoutSubviews() {
        super.layoutSubviews()
        backgroundColor = UIColor.salesforceSystemBackgroundColor

        let addAccountImageTmp = SFSDKResourceUtils.imageNamed("account-add")?.withRenderingMode(.alwaysOriginal)
        let addAccountImage = SFSDKUserSelectionTableViewController.resizeImage(addAccountImageTmp, resizeSize: CGSize(width: 18, height: 18))

        let button = UIButton(type: .custom)
        button.setBackgroundImage(addAccountImage, for: .normal)

        let label = UILabel()
        label.text = SFSDKResourceUtils.localizedString("idpAddNewAccountLabel")
        label.font = UIFont.sfsdk_textRegular(16)
        label.textColor = UIColor.salesforceDefaultTextColor

        button.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        superview?.addSubview(button)
        superview?.addSubview(label)
        button.addTarget(self, action: #selector(createUserTapped), for: .touchDown)

        button.leftAnchor.constraint(equalTo: leftAnchor, constant: kHorizontalSpace * 3).isActive = true
        button.topAnchor.constraint(equalTo: topAnchor, constant: kVerticalSpace).isActive = true
        label.leftAnchor.constraint(equalTo: button.rightAnchor, constant: kHorizontalSpace).isActive = true
        label.topAnchor.constraint(equalTo: topAnchor, constant: kVerticalSpace).isActive = true

        self.addButton = button
        self.descriptionLabel = label
    }

    @objc private func createUserTapped() {
        footerDelegate?.createUser()
    }
}

// MARK: - SFSDKUserSelectionTableViewController

@objc(SFSDKUserSelectionTableViewController)
@objcMembers
public class SFSDKUserSelectionTableViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, IDPFooterViewDelegate {

    public var selectedAccount: UserAccount?
    public weak var listViewDelegate: (any SFSDKUserSelectionTableViewControllerDelegate)?
    public var spAppOptions: NSDictionary?
    public var navigationBar: UINavigationBar?
    public var tableView: UITableView?

    private var userData: [UserAccount] = []

    // MARK: - View Lifecycle

    public override func loadView() {
        super.loadView()

        view.backgroundColor = UIColor.salesforceSystemBackgroundColor
        title = SFSDKResourceUtils.localizedString("idpSelectUserTitleLabel")

        let headerView = createHeaderView()
        let footerView = createFooterView()
        let table = createTableView()
        self.tableView = table

        table.tableFooterView = footerView
        table.tableFooterView?.bottomAnchor.constraint(equalTo: table.bottomAnchor).isActive = true
        table.heightAnchor.constraint(equalToConstant: (view.bounds.size.height * 3) / 4).isActive = true
        table.widthAnchor.constraint(equalToConstant: view.bounds.size.width).isActive = true

        let stack = UIStackView(frame: .zero)
        stack.backgroundColor = UIColor.salesforceSystemBackgroundColor
        stack.distribution = .equalSpacing
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.spacing = 0
        stack.axis = .vertical

        stack.addArrangedSubview(headerView)
        stack.addArrangedSubview(table)
        view.addSubview(stack)
        edgesForExtendedLayout = []

        stack.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        stack.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        initData()
        tableView?.delegate = self
        tableView?.dataSource = self
        tableView?.reloadData()
    }

    // MARK: - UITableViewDataSource

    public func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return userData.count
    }

    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return SFSDKUITableViewCell.cellHeight
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SFSDKUITableViewCell.reuseCellIdentifier, for: indexPath) as? SFSDKUITableViewCell ?? SFSDKUITableViewCell(style: .default, reuseIdentifier: SFSDKUITableViewCell.reuseCellIdentifier)

        let userAccount = userData[indexPath.row]
        cell.userName = "\(userAccount.idData?.firstName ?? "") \(userAccount.idData?.lastName ?? "")"
        cell.hostName = userAccount.credentials.domain ?? ""

        let url = userAccount.idData?.profileUrl
        cell.imageURL = url
        if let photo = userAccount.photo {
            cell.profileImage = photo
        }

        // Don't allow these users to be selected.
        if userAccount.idData?.nativeLogin == true {
            cell.isUserInteractionEnabled = false
            cell.selectionStyle = .none
        }

        return cell
    }

    // MARK: - UITableViewDelegate

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        listViewDelegate?.selectedUser(userData[indexPath.row], options: spAppOptions)
    }

    // MARK: - IDPFooterViewDelegate

    func createUser() {
        listViewDelegate?.createNewuser(spAppOptions)
    }

    // MARK: - Private

    private func initData() {
        let loginHost = (spAppOptions as? [String: Any])?[SFSDKIDPConstants.kSFLoginHostParam] as? String
        userData = filterUsers(byHost: loginHost, data: UserAccountManager.shared.userAccounts() ?? [])
    }

    private func filterUsers(byHost host: String?, data accounts: [UserAccount]) -> [UserAccount] {
        guard let host = host else { return accounts }
        return accounts.filter { $0.credentials.domain == host }
    }

    // MARK: - Factory Methods

    @objc public func createFooterView() -> UIView {
        let footerView = IDPFooterView()
        footerView.footerDelegate = self
        return footerView
    }

    private func createTableView() -> UITableView {
        let table = UITableView(frame: .zero, style: .plain)
        table.backgroundColor = UIColor.salesforceSystemBackgroundColor
        table.register(SFSDKUITableViewCell.self, forCellReuseIdentifier: SFSDKUITableViewCell.reuseCellIdentifier)
        return table
    }

    @objc public func createHeaderView() -> UIView {
        let appName = (spAppOptions as? [String: Any])?[SFSDKIDPConstants.kSFAppNameParam] as? String ?? "Application"
        let headerView = IDPHeaderView(frame: .zero, appName: appName)
        headerView.heightAnchor.constraint(equalToConstant: (view.bounds.size.height / 4) + 20).isActive = true
        headerView.widthAnchor.constraint(equalToConstant: view.bounds.size.width).isActive = true
        return headerView
    }

    @objc public class func resizeImage(_ originalImage: UIImage?, resizeSize size: CGSize) -> UIImage? {
        guard let originalImage = originalImage else { return nil }
        let actualHeight = originalImage.size.height
        let actualWidth = originalImage.size.width

        var ratio = actualWidth / actualHeight
        let newRatio = size.width / size.height

        var finalWidth: CGFloat
        var finalHeight: CGFloat

        if ratio < newRatio {
            ratio = size.height / actualHeight
            finalWidth = ratio * actualWidth
            finalHeight = size.height
        } else {
            ratio = size.width / actualWidth
            finalHeight = ratio * actualHeight
            finalWidth = size.width
        }

        let rect = CGRect(x: 0, y: 0, width: finalWidth, height: finalHeight)
        UIGraphicsBeginImageContext(rect.size)
        originalImage.draw(in: rect)
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resized
    }
}
