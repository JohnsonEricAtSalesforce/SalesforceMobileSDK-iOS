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
import SalesforceSDKCore
import SmartStore
import MobileSync
import MobileSyncExplorerCommon

class ContactListViewController: UITableViewController, UISearchBarDelegate {

    // MARK: - Constants

    private static let kNavBarTitleText = "Contacts"
    private static let kNavBarTintColor: UInt = 0xf10000
    private static let kNavBarTitleFontSize: CGFloat = 27.0
    private static let kContactTitleTextColor: UInt = 0x696969
    private static let kContactTitleFontSize: CGFloat = 15.0
    private static let kContactDetailFontSize: CGFloat = 13.0
    private static let kControlBuffer: CGFloat = 5.0
    private static let kSearchHeaderHeight: CGFloat = 50.0
    private static let kTableViewRowHeight: CGFloat = 60.0
    private static let kInitialsCircleDiameter: CGFloat = 50.0
    private static let kInitialsFontSize: CGFloat = 19.0
    private static let kToastMessageFontSize: CGFloat = 16.0

    private static let kColorCodesList: [UInt] = [
        0x1abc9c, 0x2ecc71, 0x3498db, 0x9b59b6, 0x34495e,
        0x16a085, 0x27ae60, 0x2980b9, 0x8e44ad, 0x2c3e50,
        0xf1c40f, 0xe67e22, 0xe74c3c, 0x95a5a6, 0xf39c12,
        0xd35400, 0xc0392b, 0xbdc3c7, 0x7f8c8d
    ]

    // MARK: - Properties

    private var actionsPopupPresentingController: UIViewController?
    private var logoutActionSheet: UIAlertController?
    private var navBarLabel: UILabel?
    private var searchHeader: UIView?
    private var searchBar: UISearchBar?
    private var syncButton: UIBarButtonItem?
    private var addButton: UIBarButtonItem?
    private var moreButton: UIBarButtonItem?
    private var toastView: UIView?
    private var toastViewMessageLabel: UILabel?
    private var toastMessage: String?

    private var dataMgr: SObjectDataManager?
    private var isSearching = false
    private var searchText: String?

    // MARK: - Init

    override init(style: UITableView.Style) {
        super.init(style: style)
        self.dataMgr = SObjectDataManager(dataSpec: ContactSObjectData.dataSpec())
        self.isSearching = false
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - View lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        if dataMgr == nil {
            dataMgr = SObjectDataManager(dataSpec: ContactSObjectData.dataSpec())
        }

        let completionBlock: () -> Void = { [weak self] in
            self?.refreshList()
        }

        dataMgr?.refreshLocalData(completionBlock)
        if dataMgr?.dataRows?.count == 0 {
            dataMgr?.refreshRemoteData(completionBlock)
        }

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(clearPopovers(_:)),
                                               name: NSNotification.Name(kSFScreenLockFlowWillBegin),
                                               object: nil)
    }

    override func loadView() {
        super.loadView()

        navigationController?.navigationBar.barTintColor = Self.colorFromRgbHexValue(Self.kNavBarTintColor)

        // Without the following, the top bar becomes transparent on iOS 15 unless one scrolls all the way up
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .red
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance

        addTapGestureRecognizers()

        // Nav bar label
        let label = UILabel(frame: .zero)
        label.text = Self.kNavBarTitleText
        label.textAlignment = .left
        label.textColor = .white
        label.backgroundColor = .clear
        label.font = UIFont.systemFont(ofSize: Self.kNavBarTitleFontSize)
        navigationItem.titleView = label
        navBarLabel = label

        // Navigation bar buttons
        let addBtn = UIBarButtonItem(image: UIImage(named: "add"), style: .plain, target: self, action: #selector(addContact))
        let syncBtn = UIBarButtonItem(image: UIImage(named: "sync"), style: .plain, target: self, action: #selector(syncUpDown))
        let moreBtn = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(showOtherActions))
        navigationItem.rightBarButtonItems = [moreBtn, syncBtn, addBtn]
        for bbi in navigationItem.rightBarButtonItems ?? [] {
            bbi.tintColor = .white
        }
        addButton = addBtn
        syncButton = syncBtn
        moreButton = moreBtn

        // Search header
        let header = UIView(frame: .zero)
        let bar = UISearchBar(frame: .zero)
        bar.placeholder = "Search"
        bar.delegate = self
        header.addSubview(bar)
        searchHeader = header
        searchBar = bar

        // Toast view
        let toast = UIView(frame: .zero)
        toast.backgroundColor = UIColor(red: 38.0/255.0, green: 38.0/255.0, blue: 38.0/255.0, alpha: 0.7)
        toast.layer.cornerRadius = 10.0
        toast.alpha = 0.0

        let messageLabel = UILabel(frame: .zero)
        messageLabel.font = UIFont.systemFont(ofSize: Self.kToastMessageFontSize)
        messageLabel.textColor = .white
        toast.addSubview(messageLabel)
        view.addSubview(toast)
        toastView = toast
        toastViewMessageLabel = messageLabel

        // To address iOS 15 spacing issue
        tableView.sectionHeaderTopPadding = 0.0
    }

    override func viewWillLayoutSubviews() {
        if #available(iOS 26, *) {
            // No-op - skipping code in else block for iOS 26 because the view controller doesn't display with it
        } else {
            if let navBar = navigationController?.navigationBar,
               let rightButtonImage = navigationItem.rightBarButtonItem?.image {
                let navBarFrame = navBar.frame
                let navBarLabelFrame = CGRect(x: 0,
                                              y: 0,
                                              width: navBarFrame.size.width - rightButtonImage.size.width,
                                              height: navBarFrame.size.height)
                navBarLabel?.frame = navBarLabelFrame
            }
        }
        layoutSearchHeader()
        layoutToastView()
    }

    // MARK: - UITableView delegate methods

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellIdentifier = "ContactListCellIdentifier"
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier)
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: cellIdentifier)

        guard let obj = dataMgr?.dataRows?[indexPath.row] as? ContactSObjectData else { return cell }
        cell.textLabel?.text = formatNameFromContact(obj)
        cell.textLabel?.font = UIFont.systemFont(ofSize: Self.kContactTitleFontSize)
        cell.detailTextLabel?.text = formatTitle(obj.title)
        cell.detailTextLabel?.font = UIFont.systemFont(ofSize: Self.kContactDetailFontSize)
        cell.detailTextLabel?.textColor = Self.colorFromRgbHexValue(Self.kContactTitleTextColor)
        cell.imageView?.image = initialsBackgroundImage(with: colorFromContact(obj), initials: formatInitialsFromContact(obj))
        cell.accessoryView = accessoryViewForContact(obj)

        return cell
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataMgr?.dataRows?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard section == 0 else { return nil }
        layoutSearchHeader()
        return searchHeader
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return section == 0 ? Self.kSearchHeaderHeight : 0
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let contact = dataMgr?.dataRows?[indexPath.row] as? ContactSObjectData,
              let dataMgr = dataMgr else { return }
        navigationItem.backBarButtonItem = UIBarButtonItem(title: Self.kNavBarTitleText, style: .plain, target: nil, action: nil)
        let detailVc = ContactDetailViewController(contact: contact, dataManager: dataMgr, saveBlock: { [weak self] in
            self?.tableView.beginUpdates()
            self?.tableView.reloadRows(at: [indexPath], with: .none)
            self?.tableView.endUpdates()
        })
        navigationController?.pushViewController(detailVc, animated: true)
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return Self.kTableViewRowHeight
    }

    // MARK: - UISearchBarDelegate methods

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        SFSDKMobileSyncLogger.log(type(of: self), level: .debug, message: "searching with text: \(searchText)")
        self.searchText = searchText
        refreshList()
    }

    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        isSearching = true
    }

    // MARK: - Private methods

    private func refreshList() {
        dataMgr?.filterOnSearchTerm(searchText) { [weak self] in
            guard let self = self else { return }
            self.tableView.reloadData()
            if self.isSearching, let searchBar = self.searchBar, !searchBar.isFirstResponder {
                searchBar.becomeFirstResponder()
            }
        }
    }

    private func accessoryViewForContact(_ contact: ContactSObjectData) -> UIView {
        let localAddImage = UIImage(named: "local-add")
        let localUpdateImage = UIImage(named: "local-update")
        let localDeleteImage = UIImage(named: "local-delete")
        let chevronRightImage = UIImage(named: "chevron-right")

        guard let dataMgr = dataMgr else {
            return UIView()
        }

        if dataMgr.dataHasLocalChanges(contact) {
            let localImage: UIImage?
            if dataMgr.dataLocallyDeleted(contact) {
                localImage = localDeleteImage
            } else if dataMgr.dataLocallyCreated(contact) {
                localImage = localAddImage
            } else {
                localImage = localUpdateImage
            }

            let localImageSize = localImage?.size ?? .zero
            let chevronSize = chevronRightImage?.size ?? .zero
            let accessoryViewWidth = localImageSize.width + Self.kControlBuffer + chevronSize.width
            let accessoryViewRect = CGRect(x: 0, y: 0, width: accessoryViewWidth, height: tableView.rowHeight)
            let accessoryView = UIView(frame: accessoryViewRect)

            let localImageViewRect = CGRect(x: 0,
                                            y: accessoryView.bounds.midY - (localImageSize.height / 2.0),
                                            width: localImageSize.width,
                                            height: localImageSize.height)
            let localImageView = UIImageView(frame: localImageViewRect)
            localImageView.image = localImage
            accessoryView.addSubview(localImageView)

            let spacerView = UIView(frame: CGRect(x: localImageSize.width, y: 0, width: Self.kControlBuffer, height: tableView.rowHeight))
            accessoryView.addSubview(spacerView)

            let chevronViewRect = CGRect(x: localImageSize.width + spacerView.frame.size.width,
                                         y: accessoryView.bounds.midY - (chevronSize.height / 2.0),
                                         width: chevronSize.width,
                                         height: chevronSize.height)
            let chevronView = UIImageView(frame: chevronViewRect)
            chevronView.image = chevronRightImage
            accessoryView.addSubview(chevronView)

            return accessoryView
        } else {
            let chevronSize = chevronRightImage?.size ?? .zero
            let accessoryViewRect = CGRect(x: 0, y: 0, width: chevronSize.width, height: tableView.rowHeight)
            let accessoryView = UIView(frame: accessoryViewRect)

            let chevronViewRect = CGRect(x: 0,
                                         y: accessoryView.bounds.midY - (chevronSize.height / 2.0),
                                         width: chevronSize.width,
                                         height: chevronSize.height)
            let chevronView = UIImageView(frame: chevronViewRect)
            chevronView.image = chevronRightImage
            accessoryView.addSubview(chevronView)

            return accessoryView
        }
    }

    private func addTapGestureRecognizers() {
        let navBarTapGesture = UITapGestureRecognizer(target: self, action: #selector(searchResignFirstResponder))
        navBarTapGesture.cancelsTouchesInView = false
        navigationController?.navigationBar.addGestureRecognizer(navBarTapGesture)

        let tableViewTapGesture = UITapGestureRecognizer(target: self, action: #selector(searchResignFirstResponder))
        tableViewTapGesture.cancelsTouchesInView = false
        tableView.addGestureRecognizer(tableViewTapGesture)
    }

    @objc private func syncUpDown() {
        navigationItem.rightBarButtonItem?.isEnabled = false
        showToast("Syncing with Salesforce")
        let completionBlock: () -> Void = { [weak self] in
            self?.refreshList()
        }

        dataMgr?.updateRemoteData { [weak self] syncProgressDetails in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.navigationItem.rightBarButtonItem?.isEnabled = true
                self.dataMgr?.refreshLocalData(completionBlock)
                self.dataMgr?.refreshRemoteData(completionBlock)

                if syncProgressDetails.isDone() {
                    self.showToast("Sync complete!")
                } else if syncProgressDetails.hasFailed() {
                    self.showToast("Sync failed.")
                }
            }
        }
    }

    @objc private func addContact() {
        guard let dataMgr = dataMgr else { return }
        navigationItem.backBarButtonItem = UIBarButtonItem(title: Self.kNavBarTitleText, style: .plain, target: nil, action: nil)
        let detailVc = ContactDetailViewController(newContactWithDataManager: dataMgr, saveBlock: { [weak self] in
            self?.dataMgr?.refreshLocalData {
                self?.refreshList()
            }
        })
        navigationController?.pushViewController(detailVc, animated: true)
    }

    @objc private func showOtherActions() {
        if let presentingController = actionsPopupPresentingController, presentingController.presentedViewController != nil {
            presentingController.dismiss(animated: false)
            return
        }

        let popupContent = ActionsPopupController(appViewController: self)
        popupContent.preferredContentSize = CGSize(width: 260, height: 180)
        popupContent.modalPresentationStyle = .popover
        popupContent.popoverPresentationController?.barButtonItem = moreButton
        present(popupContent, animated: true)
        actionsPopupPresentingController = popupContent.presentingViewController
    }

    func popoverOptionSelected(_ text: String) {
        if let presentingController = actionsPopupPresentingController, presentingController.presentedViewController != nil {
            presentingController.dismiss(animated: true)
        }

        if text == kActionLogout {
            showLogoutActionSheet()
        } else if text == kActionSwitchUser {
            let umvc = SalesforceUserManagementViewController { [weak self] _ in
                self?.dismiss(animated: true)
            }
            present(umvc, animated: true)
        } else if text == kActionDbInspector {
            if let store = dataMgr?.store {
                let inspector = InspectorViewController(store: store)
                present(inspector, animated: false)
            }
        }
    }

    private func showLogoutActionSheet() {
        let alert = UIAlertController(title: nil, message: "Are you sure you want to log out?", preferredStyle: .alert)
        let logoutAction = UIAlertAction(title: "Logout", style: .destructive) { [weak self] _ in
            self?.logoutActionSheet = nil
            UserAccountManager.shared.logout()
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alert.addAction(logoutAction)
        alert.addAction(cancelAction)
        logoutActionSheet = alert
        present(alert, animated: true)
    }

    private func layoutToastView() {
        let toastWidth: CGFloat = 250.0
        let toastHeight: CGFloat = 50.0
        let bottomScreenPadding: CGFloat = 40.0

        guard let toastView = toastView, let superView = toastView.superview else { return }
        toastView.frame = CGRect(x: superView.bounds.midX - (toastWidth / 2.0),
                                  y: superView.bounds.maxY - bottomScreenPadding - toastHeight,
                                  width: toastWidth,
                                  height: toastHeight)

        guard let messageLabel = toastViewMessageLabel else { return }
        let message = toastMessage ?? " "
        let messageAttrs: [NSAttributedString.Key: Any] = [.foregroundColor: messageLabel.textColor as Any, .font: messageLabel.font as Any]
        let messageTextSize = (message as NSString).size(withAttributes: messageAttrs)
        let messageRect = CGRect(x: toastView.bounds.midX - (messageTextSize.width / 2.0),
                                  y: toastView.bounds.midY - (messageTextSize.height / 2.0),
                                  width: messageTextSize.width,
                                  height: messageTextSize.height)
        messageLabel.frame = messageRect
        messageLabel.text = message
    }

    private func showToast(_ message: String) {
        let toastDisplayTimeSecs: TimeInterval = 2.0

        toastMessage = message
        layoutToastView()
        toastView?.alpha = 0.0
        UIView.animate(withDuration: 0.3) { [weak self] in
            self?.toastView?.alpha = 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + toastDisplayTimeSecs) { [weak self] in
            UIView.animate(withDuration: 0.3) {
                self?.toastView?.alpha = 0.0
            }
        }
    }

    @objc private func searchResignFirstResponder() {
        if let searchBar = searchBar, searchBar.isFirstResponder {
            searchBar.resignFirstResponder()
            isSearching = false
        }
    }

    private func layoutSearchHeader() {
        guard let navBar = navigationController?.navigationBar else { return }
        let searchHeaderFrame = CGRect(x: 0, y: 0, width: navBar.frame.size.width, height: Self.kSearchHeaderHeight)
        searchHeader?.frame = searchHeaderFrame

        let searchBarFrame = CGRect(x: 0, y: 0, width: searchHeaderFrame.size.width, height: searchHeaderFrame.size.height)
        searchBar?.frame = searchBarFrame
    }

    private func formatNameFromContact(_ contact: ContactSObjectData) -> String {
        let firstName = contact.firstName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let lastName = contact.lastName?.trimmingCharacters(in: .whitespacesAndNewlines)

        if firstName == nil && lastName == nil {
            return ""
        } else if firstName == nil {
            return lastName ?? ""
        } else if lastName == nil {
            return firstName ?? ""
        } else {
            return "\(firstName ?? "") \(lastName ?? "")"
        }
    }

    private func formatInitialsFromContact(_ contact: ContactSObjectData) -> String {
        let firstName = contact.firstName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let lastName = contact.lastName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        var initialsString = ""
        if !firstName.isEmpty {
            initialsString.append(String(firstName.prefix(1)))
        }
        if !lastName.isEmpty {
            initialsString.append(String(lastName.prefix(1)))
        }
        return initialsString
    }

    private func formatTitle(_ title: String?) -> String {
        return title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func colorFromContact(_ contact: ContactSObjectData) -> UIColor {
        let lastName = contact.lastName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var codeSeedFromName: UInt = 0
        for char in lastName.unicodeScalars {
            codeSeedFromName += UInt(char.value)
        }

        let colorCodesListCount = UInt(Self.kColorCodesList.count)
        let colorCodesListIndex = Int(codeSeedFromName % colorCodesListCount)
        let colorCodeHexValue = Self.kColorCodesList[colorCodesListIndex]
        return Self.colorFromRgbHexValue(colorCodeHexValue)
    }

    private static func colorFromRgbHexValue(_ rgbHexColorValue: UInt) -> UIColor {
        return UIColor(red: CGFloat((rgbHexColorValue & 0xFF0000) >> 16) / 255.0,
                       green: CGFloat((rgbHexColorValue & 0xFF00) >> 8) / 255.0,
                       blue: CGFloat(rgbHexColorValue & 0xFF) / 255.0,
                       alpha: 1.0)
    }

    private func initialsBackgroundImage(with circleColor: UIColor, initials: String) -> UIImage? {
        let diameter = Self.kInitialsCircleDiameter
        UIGraphicsBeginImageContextWithOptions(CGSize(width: diameter, height: diameter), false, UIScreen.main.scale)

        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        UIGraphicsPushContext(context)

        // Draw the circle.
        let circleCenter = CGPoint(x: diameter / 2.0, y: diameter / 2.0)
        context.setFillColor(circleColor.cgColor)
        context.beginPath()
        context.addArc(center: circleCenter, radius: diameter / 2.0, startAngle: 0, endAngle: 2 * .pi, clockwise: false)
        context.fillPath()

        // Draw the initials.
        let initialsAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: Self.kInitialsFontSize)
        ]
        let initialsTextSize = (initials as NSString).size(withAttributes: initialsAttrs)
        let initialsRect = CGRect(x: circleCenter.x - (initialsTextSize.width / 2.0),
                                   y: circleCenter.y - (initialsTextSize.height / 2.0),
                                   width: initialsTextSize.width,
                                   height: initialsTextSize.height)
        (initials as NSString).draw(in: initialsRect, withAttributes: initialsAttrs)

        UIGraphicsPopContext()
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return image
    }

    // MARK: - Passcode handling

    @objc private func clearPopovers(_ note: Notification) {
        SFSDKMobileSyncLogger.log(type(of: self), level: .debug, message: "Passcode screen loading. Clearing popovers.")
        if let presentingController = actionsPopupPresentingController, presentingController.presentedViewController != nil {
            presentingController.dismiss(animated: false)
        }
        if let logoutSheet = logoutActionSheet {
            logoutSheet.dismiss(animated: true)
        }
    }
}
