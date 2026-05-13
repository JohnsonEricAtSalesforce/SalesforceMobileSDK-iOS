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
import QuartzCore
import SalesforceSDKCore
import SalesforceSDKCommon

// Nav bar
private let kNavBarHeight: CGFloat = 44.0
private let kNavBarTitleFontSize: CGFloat = 18.0
// Store picker
private let kStorePickerHeight: CGFloat = 44.0
// Text fields
private let kTextFieldFontName = "Courier"
private let kTextFieldFontSize: CGFloat = 12.0
private let kTextFieldBorderWidth: CGFloat = 3.0
private let kQueryFieldHeight: CGFloat = 96.0
private let kPageFieldHeight: CGFloat = 24.0
// Buttons
private let kButtonFontName = "HelveticaNeue-Bold"
private let kButtonFontSize: CGFloat = 16.0
private let kButtonHeight: CGFloat = 48.0
private let kButtonBorderWidth: CGFloat = 3.0
// Results
private let kResultGridBorderWidth: CGFloat = 3.0
private let kResultTextFontName = "Courier"
private let kResultTextFontSize: CGFloat = 12.0
private let kResultCellHeight: CGFloat = 24.0
private let kResultCellBorderWidth: CGFloat = 1.0
private let kCellIndentifier = "cellIdentifier"
private let kLabelTag: Int = 99
// Resource keys
private let kInspectorNoRowsReturnedKey = "inspectorNoRowsReturned"
private let kInspectorNoSoupsFoundKey = "inspectorNoSoupsFound"
private let kInspectorQueryFailedKey = "inspectorQueryFailed"
private let kInspectorOKKey = "inspectorOK"
private let kInspectorPageSizeHintKey = "inspectorPageSizeHint"
private let kInspectorPageIndexHintKey = "inspectorPageIndexHint"
private let kInspectorClearButtonTitleKey = "inspectorClearButtonTitle"
private let kInspectorSoupsButtonTitleKey = "inspectorSoupsButtonTitle"
private let kInspectorIndicesButtonTitleKey = "inspectorIndicesButtonTitle"
private let kInspectorTitleKey = "inspectorTitle"
private let kInspectorBackButtonTitleKey = "inspectorBackButtonTitle"
private let kInspectorRunButtonTitleKey = "inspectorRunButtonTitle"

// Other constants
private let kInspectorPickerUserStore = " (user store)"
private let kInspectorPickerGlobalStore = " (global store)"
private let kInspectorPickerDefault = "default"

/**
 * The view controller for managing the SmartStore inspector screen.
 */
@objc(SFSmartStoreInspectorViewController)
@objcMembers
public class InspectorViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UITextViewDelegate, UINavigationBarDelegate, UIPickerViewDelegate, UIPickerViewDataSource {

    private var _store: SmartStore
    private var storeDisplayNames: [String] = []
    private var navBar: UINavigationBar!
    private var storePickerView: UIPickerView!
    private var queryField: UITextView!
    private var pageSizeField: UITextField!
    private var pageIndexField: UITextField!
    private var clearButton: UIButton!
    private var soupsButton: UIButton!
    private var indicesButton: UIButton!
    private var resultGrid: UICollectionView!
    private var _results: [[Any]]?
    private var _countColumns: Int = 0
    private var _countRows: Int = 0

    @objc
    public var store: SmartStore {
        get {
            return _store
        }
        set {
            _store = newValue
            storeDisplayNames = getStoreNamesForPicker()
        }
    }

    private var results: [[Any]]? {
        get {
            return _results
        }
        set {
            if _results as NSArray? != newValue as NSArray? {
                _results = newValue
                _countRows = _results?.count ?? 0
                _countColumns = _countRows > 0 ? (_results![0].count) : 0
                DispatchQueue.main.async {
                    self.resultGrid.reloadData()
                }
            }
        }
    }

    private var countColumns: Int {
        return _countColumns
    }

    private var countRows: Int {
        return _countRows
    }

    // MARK: - Constructor

    @objc
    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        if let user = SFUserAccountManager.shared.currentUserAccount {
            _store = SmartStore.shared(withName: kDefaultSmartStoreName) ?? SmartStore.sharedGlobal(withName: kDefaultSmartStoreName)!
        } else {
            _store = SmartStore.sharedGlobal(withName: kDefaultSmartStoreName)!
        }
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    @objc
    public convenience init() {
        self.init(nibName: nil, bundle: nil)
    }

    @objc(initWithStore:)
    public init(store: SmartStore) {
        self._store = store
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Store picker

    private func getStoreNamesForPicker() -> [String] {
        var pickerStoreNames: [String] = []
        for storeName in SmartStore.allStoreNames {
            pickerStoreNames.append(getDisplayName(forStore: false, dbName: storeName))
        }
        for storeName in SmartStore.allGlobalStoreNames {
            pickerStoreNames.append(getDisplayName(forStore: true, dbName: storeName))
        }
        return pickerStoreNames
    }

    private func getDisplayName(forStore isGlobal: Bool, dbName: String) -> String {
        let name = dbName == kDefaultSmartStoreName ? kInspectorPickerDefault : dbName
        let suffix = isGlobal ? kInspectorPickerGlobalStore : kInspectorPickerUserStore
        return name + suffix
    }

    private func getStore(fromDisplayName storeDisplayName: String) -> (isGlobal: Bool, dbName: String) {
        let isGlobal: Bool
        let dbName: String

        if storeDisplayName.contains(kInspectorPickerGlobalStore) {
            isGlobal = true
            let endIndex = storeDisplayName.index(storeDisplayName.endIndex, offsetBy: -kInspectorPickerGlobalStore.count)
            dbName = String(storeDisplayName[..<endIndex])
        } else {
            isGlobal = false
            let endIndex = storeDisplayName.index(storeDisplayName.endIndex, offsetBy: -kInspectorPickerUserStore.count)
            dbName = String(storeDisplayName[..<endIndex])
        }

        let finalDbName = dbName == kInspectorPickerDefault ? kDefaultSmartStoreName : dbName
        return (isGlobal, finalDbName)
    }

    @objc(numberOfComponentsInPickerView:)
    public func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    @objc(pickerView:numberOfRowsInComponent:)
    public func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return storeDisplayNames.count
    }

    @objc(pickerView:titleForRow:forComponent:)
    public func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return storeDisplayNames[row]
    }

    @objc(pickerView:didSelectRow:inComponent:)
    public func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        let selectedStore = getStore(fromDisplayName: storeDisplayNames[row])
        store = selectedStore.isGlobal ? SmartStore.sharedGlobal(withName: selectedStore.dbName)! : SmartStore.shared(withName: selectedStore.dbName)!
    }

    private func selectCurrentStoreInPicker() {
        let userId = UserAccountManager.shared.currentUserAccount?.credentials.userId
        let isGlobal = userId == nil || !(store.path?.contains(userId!) ?? false)
        let dbName = store.name
        let storeDisplayName = getDisplayName(forStore: isGlobal, dbName: dbName)
        if let row = storeDisplayNames.firstIndex(of: storeDisplayName) {
            storePickerView.selectRow(row, inComponent: 0, animated: false)
        }
    }

    // MARK: - Actions handlers

    @objc
    private func backButtonClicked() {
        presentingViewController?.dismiss(animated: false, completion: nil)
    }

    @objc
    private func runQuery() {
        stopEditing()
        let smartSql = queryField.text ?? ""
        var pageSize = Int(pageSizeField.text ?? "") ?? 0
        pageSize = (pageSize <= 0 && pageSizeField.text != "0") ? 100 : pageSize
        let pageIndex = Int(pageIndexField.text ?? "") ?? 0

        do {
            if let querySpec = QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: UInt(pageSize)) {
                let results = try store.query(using: querySpec, startingFromPageIndex: UInt(pageIndex))
                let errorAlertTitle = SFSDKResourceUtils.localizedString(kInspectorQueryFailedKey)
                if results.isEmpty {
                    showAlert(SFSDKResourceUtils.localizedString(kInspectorNoRowsReturnedKey), title: errorAlertTitle)
                }
                self.results = results as? [[Any]]
            }
        } catch {
            let errorAlertTitle = SFSDKResourceUtils.localizedString(kInspectorQueryFailedKey)
            showAlert(error.localizedDescription, title: errorAlertTitle)
        }
    }

    private func showAlert(_ message: String, title: String?) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: SFSDKResourceUtils.localizedString(kInspectorOKKey), style: .default, handler: nil)
        alert.addAction(okAction)
        present(alert, animated: true, completion: nil)
    }

    @objc
    private func soupsButtonClicked() {
        let names = store.allSoupNames()
        if names.isEmpty {
            let errorAlertTitle = SFSDKResourceUtils.localizedString(kInspectorQueryFailedKey)
            showAlert(SFSDKResourceUtils.localizedString(kInspectorNoSoupsFoundKey), title: errorAlertTitle)
        }
        if names.count > 100 {
            queryField.text = "select \(SOUP_NAME_COL) from \(SOUP_ATTRS_TABLE)"
        } else {
            let q = NSMutableString()
            var first = true
            for name in names {
                if !first {
                    q.append(" union ")
                }
                q.append("SELECT '\(name)', count(*) FROM {\(name)}")
                first = false
            }
            queryField.text = q as String
        }
        runQuery()
    }

    @objc
    private func indicesButtonClicked() {
        queryField.text = "select \(SOUP_NAME_COL),\(PATH_COL),\(COLUMN_TYPE_COL) from \(SOUP_INDEX_MAP_TABLE)"
        runQuery()
    }

    @objc
    private func clearButtonClicked() {
        stopEditing()
        queryField.text = ""
        pageSizeField.text = ""
        pageIndexField.text = ""
        results = nil
    }

    private func stopEditing() {
        queryField.endEditing(true)
        pageSizeField.endEditing(true)
        pageIndexField.endEditing(true)
    }

    // MARK: - View layout

    public override func loadView() {
        super.loadView()

        // Background color
        view.backgroundColor = UIColor.salesforceBlueColor

        // Nav bar
        navBar = createNavBar()

        // Store picker
        storePickerView = createStorePicker()

        // Query field
        queryField = createTextView()

        // Page size field
        pageSizeField = createTextField()
        pageSizeField.placeholder = SFSDKResourceUtils.localizedString(kInspectorPageSizeHintKey)
        pageSizeField.keyboardType = .numberPad

        // Page index field
        pageIndexField = createTextField()
        pageIndexField.placeholder = SFSDKResourceUtils.localizedString(kInspectorPageIndexHintKey)
        pageIndexField.keyboardType = .numberPad

        // Buttons
        clearButton = createButton(withLabel: SFSDKResourceUtils.localizedString(kInspectorClearButtonTitleKey), action: #selector(clearButtonClicked))
        soupsButton = createButton(withLabel: SFSDKResourceUtils.localizedString(kInspectorSoupsButtonTitleKey), action: #selector(soupsButtonClicked))
        indicesButton = createButton(withLabel: SFSDKResourceUtils.localizedString(kInspectorIndicesButtonTitleKey), action: #selector(indicesButtonClicked))

        // Results grid
        resultGrid = createGridView()
    }

    private func createNavBar() -> UINavigationBar {
        let navBar = UINavigationBar(frame: CGRect(x: 0, y: 0, width: view.bounds.size.width, height: kNavBarHeight))
        navBar.delegate = self
        let navItem = UINavigationItem(title: SFSDKResourceUtils.localizedString(kInspectorTitleKey))
        let backItem = UIBarButtonItem(title: SFSDKResourceUtils.localizedString(kInspectorBackButtonTitleKey), style: .plain, target: self, action: #selector(backButtonClicked))
        let runItem = UIBarButtonItem(title: SFSDKResourceUtils.localizedString(kInspectorRunButtonTitleKey), style: .plain, target: self, action: #selector(runQuery))
        navItem.leftBarButtonItem = backItem
        navItem.rightBarButtonItem = runItem
        navBar.items = [navItem]
        navBar.isTranslucent = false
        navBar.barTintColor = UIColor.salesforceBlueColor
        navBar.tintColor = UIColor.salesforceNavBarTintColor
        navBar.titleTextAttributes = [.foregroundColor: UIColor.white, .font: UIFont.systemFont(ofSize: kNavBarTitleFontSize)]
        view.addSubview(navBar)
        return navBar
    }

    private func createStorePicker() -> UIPickerView {
        let storePicker = UIPickerView(frame: .zero)
        storePicker.delegate = self
        storePicker.backgroundColor = UIColor.salesforceSystemBackgroundColor
        storePicker.layer.borderColor = borderColor()
        storePicker.layer.borderWidth = kTextFieldBorderWidth
        storePicker.dataSource = self
        view.addSubview(storePicker)
        return storePicker
    }

    private func createTextView() -> UITextView {
        let textView = UITextView(frame: .zero)
        textView.delegate = self
        textView.textColor = textColor()
        textView.backgroundColor = UIColor.salesforceSystemBackgroundColor
        textView.font = UIFont(name: kTextFieldFontName, size: kTextFieldFontSize)
        textView.text = ""
        textView.layer.borderColor = borderColor()
        textView.layer.borderWidth = kTextFieldBorderWidth
        view.addSubview(textView)
        return textView
    }

    private func createTextField() -> UITextField {
        let textField = UITextField(frame: .zero)
        textField.textColor = textColor()
        textField.backgroundColor = UIColor.salesforceSystemBackgroundColor
        textField.font = UIFont(name: kTextFieldFontName, size: kTextFieldFontSize)
        textField.text = ""
        textField.textAlignment = .center
        textField.layer.borderColor = borderColor()
        textField.layer.borderWidth = kTextFieldBorderWidth
        view.addSubview(textField)
        return textField
    }

    private func createButton(withLabel label: String, action: Selector) -> UIButton {
        let button = UIButton(type: .custom)
        button.setTitle(label, for: .normal)
        button.backgroundColor = UIColor.salesforceSystemBackgroundColor
        button.titleLabel?.textAlignment = .center
        button.setTitleColor(textColor(), for: .normal)
        button.addTarget(self, action: action, for: .touchUpInside)
        button.titleLabel?.font = UIFont(name: kButtonFontName, size: kButtonFontSize)
        button.layer.borderColor = borderColor()
        button.layer.borderWidth = kButtonBorderWidth
        view.addSubview(button)
        return button
    }

    private func createGridView() -> UICollectionView {
        let layout = UICollectionViewFlowLayout()
        let gridView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        layout.scrollDirection = .vertical
        gridView.layer.borderColor = borderColor()
        gridView.layer.borderWidth = kResultGridBorderWidth
        gridView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: kCellIndentifier)
        gridView.backgroundColor = UIColor.salesforceSystemBackgroundColor
        gridView.dataSource = self
        gridView.delegate = self
        view.addSubview(gridView)
        return gridView
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        layoutSubviews()
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        selectCurrentStoreInPicker()
    }

    public override func viewWillLayoutSubviews() {
        layoutSubviews()
        super.viewWillLayoutSubviews()
    }

    private func layoutSubviews() {
        layoutNavBar()
        layoutStorePicker()
        layoutQueryField()
        layoutPageFields()
        layoutButtons()
        layoutResultGrid()
        resultGrid.reloadData()
    }

    public override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .all
    }

    private func belowFrame(_ frame: CGRect) -> CGFloat {
        return frame.origin.y + frame.size.height
    }

    private func layoutNavBar() {
        let x: CGFloat = 0
        let y = view.safeAreaInsets.top
        let w = view.bounds.size.width
        let h = kNavBarHeight
        navBar.frame = CGRect(x: x, y: y, width: w, height: h)
    }

    private func layoutStorePicker() {
        let x: CGFloat = 0
        let y = belowFrame(navBar.frame)
        let w = view.bounds.size.width
        let h = kStorePickerHeight
        storePickerView.frame = CGRect(x: x, y: y, width: w, height: h)
    }

    private func layoutQueryField() {
        let x: CGFloat = 0
        let y = belowFrame(storePickerView.frame)
        let w = view.bounds.size.width
        let h = kQueryFieldHeight
        queryField.frame = CGRect(x: x, y: y, width: w, height: h)
    }

    private func layoutPageFields() {
        let w = view.bounds.size.width / 2.0
        let y = belowFrame(queryField.frame)
        let h = kPageFieldHeight
        pageSizeField.frame = CGRect(x: 0, y: y, width: w, height: h)
        pageIndexField.frame = CGRect(x: w, y: y, width: w, height: h)
    }

    private func layoutButtons() {
        let w = view.bounds.size.width / 3.0
        let y = belowFrame(pageSizeField.frame)
        let h = kButtonHeight
        clearButton.frame = CGRect(x: 0, y: y, width: w, height: h)
        soupsButton.frame = CGRect(x: w, y: y, width: w, height: h)
        indicesButton.frame = CGRect(x: w * 2.0, y: y, width: w, height: h)
    }

    private func layoutResultGrid() {
        let x: CGFloat = 0
        let y = belowFrame(clearButton.frame)
        let w = view.bounds.size.width
        let h = view.bounds.size.height - y
        resultGrid.frame = CGRect(x: x, y: y, width: w, height: h)
    }

    private func textColor() -> UIColor {
        return UIColor.label
    }

    private func borderColor() -> CGColor {
        return UIColor.separator.cgColor
    }

    // MARK: - Text view delegate

    @objc(textView:shouldChangeTextInRange:replacementText:)
    public func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" {
            runQuery()
        }
        return true
    }

    // MARK: - Collection view delegate

    @objc(collectionView:didSelectItemAtIndexPath:)
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let label = String(describing: cellData(with: indexPath))
        showAlert(label, title: nil)
    }

    @objc(collectionView:cellForItemAtIndexPath:)
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: kCellIndentifier, for: indexPath)
        let labelView = cellView(with: indexPath)
        labelView.tag = kLabelTag
        cell.contentView.viewWithTag(kLabelTag)?.removeFromSuperview()
        cell.contentView.addSubview(labelView)
        return cell
    }

    @objc(collectionView:layout:sizeForItemAtIndexPath:)
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let w = cellWidth(with: indexPath)
        let h = cellHeight(with: indexPath)
        return CGSize(width: w, height: h)
    }

    @objc(numberOfSectionsInCollectionView:)
    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        return countRows
    }

    @objc(collectionView:numberOfItemsInSection:)
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return countColumns
    }

    private func compactDescription(_ obj: Any) -> String {
        let str = String(describing: obj)
        return str.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression, range: str.startIndex..<str.endIndex)
    }

    private func cellView(with indexPath: IndexPath) -> UILabel {
        let w = cellWidth(with: indexPath)
        let h = cellHeight(with: indexPath)
        let title = UILabel(frame: CGRect(x: 0, y: 0, width: w, height: h))
        title.textColor = textColor()
        title.layer.borderColor = borderColor()
        title.layer.borderWidth = kResultCellBorderWidth
        title.font = UIFont(name: kResultTextFontName, size: kResultTextFontSize)
        title.textAlignment = .center
        title.text = compactDescription(cellData(with: indexPath))
        return title
    }

    private func cellWidth(with indexPath: IndexPath) -> CGFloat {
        return countColumns > 0 ? resultGrid.frame.size.width / CGFloat(countColumns) : 0
    }

    private func cellHeight(with indexPath: IndexPath) -> CGFloat {
        return kResultCellHeight
    }

    private func cellData(with indexPath: IndexPath) -> Any {
        return results![indexPath.section][indexPath.row]
    }
}
