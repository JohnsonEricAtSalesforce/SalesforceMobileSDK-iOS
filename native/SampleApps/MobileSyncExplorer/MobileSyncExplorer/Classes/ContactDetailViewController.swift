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
import MobileSync
import MobileSyncExplorerCommon

class ContactDetailViewController: UITableViewController {

    private var contact: ContactSObjectData
    private var dataMgr: SObjectDataManager
    private var saveBlock: (() -> Void)?
    private var dataRows: [[Any]] = []
    private var contactDataRows: [[Any]] = []
    private var deleteButtonDataRow: [Any] = []
    private var isEditingContact = false
    private var contactUpdated = false
    private var isNewContact = false

    init(newContactWithDataManager dataMgr: SObjectDataManager, saveBlock: @escaping () -> Void) {
        self.contact = ContactSObjectData()
        self.dataMgr = dataMgr
        self.saveBlock = saveBlock
        self.isNewContact = true
        super.init(nibName: nil, bundle: nil)
    }

    init(contact: ContactSObjectData, dataManager dataMgr: SObjectDataManager, saveBlock: @escaping () -> Void) {
        self.contact = contact
        self.dataMgr = dataMgr
        self.saveBlock = saveBlock
        self.isNewContact = false
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        super.loadView()

        dataRows = dataRowsFromContact()
        navigationController?.navigationBar.tintColor = .white
        configureInitialBarButtonItems()
        tableView.separatorStyle = .none
        tableView.sectionHeaderTopPadding = 0.0

        if isNewContact {
            editContact()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if contactUpdated, let saveBlock = saveBlock {
            DispatchQueue.main.async(execute: saveBlock)
        }
    }

    // MARK: - UITableView delegate methods

    override func numberOfSections(in tableView: UITableView) -> Int {
        return dataRows.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellIdentifier = "ContactDetailCellIdentifier"
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier)
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: cellIdentifier)

        if indexPath.section < contactDataRows.count {
            if isEditingContact {
                cell.textLabel?.text = nil
                if let editField = dataRows[indexPath.section][3] as? UITextField {
                    editField.frame = cell.contentView.bounds
                    contactTextFieldAddLeftMargin(editField)
                    cell.contentView.addSubview(editField)
                }
            } else {
                if let editField = dataRows[indexPath.section][3] as? UITextField {
                    editField.removeFromSuperview()
                }
                let rowValueData = dataRows[indexPath.section][2] as? String ?? ""
                cell.textLabel?.text = rowValueData
            }
        } else {
            if let deleteButton = dataRows[indexPath.section][1] as? UIButton {
                deleteButton.frame = cell.contentView.bounds
                cell.contentView.addSubview(deleteButton)
            }
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return dataRows[section][0] as? String
    }

    // MARK: - Private methods

    private func configureInitialBarButtonItems() {
        if isNewContact {
            navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(saveContact))
        } else {
            navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(editContact))
        }
        navigationItem.leftBarButtonItem = nil
    }

    private func dataRowsFromContact() -> [[Any]] {
        contactDataRows = [
            ["First name", kContactFirstNameField, Self.emptyStringForNullValue(contact.firstName), contactTextField(contact.firstName)],
            ["Last name", kContactLastNameField, Self.emptyStringForNullValue(contact.lastName), contactTextField(contact.lastName)],
            ["Title", kContactTitleField, Self.emptyStringForNullValue(contact.title), contactTextField(contact.title)],
            ["Mobile phone", kContactMobilePhoneField, Self.emptyStringForNullValue(contact.mobilePhone), contactTextField(contact.mobilePhone)],
            ["Email address", kContactEmailField, Self.emptyStringForNullValue(contact.email), contactTextField(contact.email)],
            ["Department", kContactDepartmentField, Self.emptyStringForNullValue(contact.department), contactTextField(contact.department)],
            ["Home phone", kContactHomePhoneField, Self.emptyStringForNullValue(contact.homePhone), contactTextField(contact.homePhone)]
        ]
        deleteButtonDataRow = ["", deleteButtonView()]

        var workingDataRows = contactDataRows
        if !isNewContact {
            workingDataRows.append(deleteButtonDataRow)
        }
        return workingDataRows
    }

    @objc private func editContact() {
        isEditingContact = true
        if !isNewContact {
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelEditContact))
            navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(saveContact))
        }
        tableView.reloadData()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let firstField = self.dataRows[0][3] as? UITextField {
                firstField.becomeFirstResponder()
            }
        }
    }

    @objc private func cancelEditContact() {
        isEditingContact = false
        configureInitialBarButtonItems()
        tableView.reloadData()
    }

    @objc private func saveContact() {
        configureInitialBarButtonItems()

        contactUpdated = false
        for fieldArray in contactDataRows {
            guard let fieldName = fieldArray[1] as? String,
                  let origFieldData = fieldArray[2] as? String,
                  let textField = fieldArray[3] as? UITextField else { continue }
            let newFieldData = textField.text ?? ""
            if newFieldData != origFieldData {
                contact.updateSoupForFieldName(fieldName, fieldValue: newFieldData)
                contactUpdated = true
            }
        }

        if contactUpdated {
            if isNewContact {
                dataMgr.createLocalData(contact)
            } else {
                dataMgr.updateLocalData(contact)
            }
            navigationController?.popViewController(animated: true)
        } else {
            tableView.reloadData()
        }
    }

    @objc private func deleteContactConfirm() {
        let alert = UIAlertController(title: "Confirm Delete",
                                      message: "Are you sure you want to delete this contact?",
                                      preferredStyle: .alert)

        let cancelAction = UIAlertAction(title: "Cancel", style: .default) { [weak self] _ in
            self?.presentedViewController?.dismiss(animated: true)
        }

        let okAction = UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.presentedViewController?.dismiss(animated: true)
            self?.deleteContact()
        }

        alert.addAction(cancelAction)
        alert.addAction(okAction)
        present(alert, animated: true)
    }

    private func deleteContact() {
        dataMgr.deleteLocalData(contact)
        contactUpdated = true
        navigationController?.popViewController(animated: true)
    }

    @objc private func undeleteContact() {
        dataMgr.undeleteLocalData(contact)
        contactUpdated = true
        navigationController?.popViewController(animated: true)
    }

    private func contactTextField(_ propertyValue: String?) -> UITextField {
        let textField = UITextField(frame: .zero)
        textField.text = propertyValue
        return textField
    }

    private func deleteButtonView() -> UIButton {
        let deleted = (contact.fieldValueForFieldName(kSyncTargetLocallyDeleted) as? Bool) ?? false
        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 15, bottom: 0, trailing: 0)
        let deleteButton = UIButton(configuration: configuration)
        deleteButton.setTitle(deleted ? "Undelete Contact" : "Delete Contact", for: .normal)
        deleteButton.setTitleColor(.red, for: .normal)
        deleteButton.titleLabel?.font = UIFont.systemFont(ofSize: 18.0)
        deleteButton.contentHorizontalAlignment = .left
        deleteButton.addTarget(self, action: deleted ? #selector(undeleteContact) : #selector(deleteContactConfirm), for: .touchUpInside)
        return deleteButton
    }

    private func contactTextFieldAddLeftMargin(_ textField: UITextField) {
        let leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: textField.frame.size.height))
        leftView.backgroundColor = textField.backgroundColor
        textField.leftView = leftView
        textField.leftViewMode = .always
    }

    private static func emptyStringForNullValue(_ origValue: Any?) -> String {
        guard let value = origValue else { return "" }
        if value is NSNull { return "" }
        return value as? String ?? ""
    }
}
