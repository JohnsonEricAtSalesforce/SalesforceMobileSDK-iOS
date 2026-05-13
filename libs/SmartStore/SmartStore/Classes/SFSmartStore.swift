/*
 Copyright (c) 2011-present, salesforce.com, inc. All rights reserved.

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

import Foundation
import UIKit
import SQLCipher
import FMDB
import SalesforceSDKCore
import SalesforceSDKCommon

// MARK: - Static Variables and Constants
internal var _allSharedStores = NSMutableDictionary()
internal var _allGlobalSharedStores = NSMutableDictionary()
internal var _encryptionKeyGenerator: EncryptionKeyGenerator?
internal var _encryptionSaltBlock: EncryptionSaltBlock?
internal var _jsonSerializationCheckEnabled: Bool = false
internal var _postRawJsonOnError: Bool = false
internal var _licenseKey: String?

// Public Constants
public let kDefaultSmartStoreName = "defaultStore"
public let kSFAppFeatureSmartStoreUser = "US"
public let kSFAppFeatureSmartStoreGlobal = "GS"
public let kSFSmartStoreJSONParseErrorNotification = "SFSmartStoreJSONParseErrorNotification"
public let kSFSmartStoreJSONSerializationErrorNotification = "SFSmartStoreJSONSerializationErrorNotification"

// NSError constants
public let kSFSmartStoreErrorDomain = "com.salesforce.smartstore.error"
internal let kSFSmartStoreTooManyEntriesCode = 1
internal let kSFSmartStoreTooManyEntriesDescription = "Cannot update entry: the value '%@' for path '%@' does not represent a unique entry!"
internal let kSFSmartStoreIndexNotDefinedCode = 2
internal let kSFSmartStoreIndexNotDefinedDescription = "No index column defined for field '%@'."
internal let kSFSmartStoreExternalIdNilCode = 3
internal let kSFSmartStoreExternalIdNilDescription = "For upsert with external ID path '%@', value cannot be empty for any entries."
internal let kSFSmartStoreExtIdLookupError = "There was an error retrieving the soup entry ID for path '%@' and value '%@': %@"
internal let kSFSmartStoreWhereArgsNotSupportedCode = 5
internal let kSFSmartStoreWhereArgsNotSupportedDescription = "whereArgs can only be provided for smart queries"
internal let kSFSmartStoreOtherErrorCode = 999

public let kSFSmartStoreErrorLoadExternalSoup = "com.salesforce.smartstore.LoadExternalSoupError"

// Encryption constants
public let kSFSmartStoreEncryptionKeyLabel = "com.salesforce.smartstore.encryption.keyLabel"
public let kSFSmartStoreEncryptionSaltLabel = "com.salesforce.smartstore.encryption.saltLabel"
public let kSFSmartStoreEncryptionSaltLength: UInt = 16

// Table to keep track of soup attributes
internal let SOUP_NAMES_TABLE = "soup_names"

// Columns of the soup index map table
public let COLUMN_NAME_COL = "columnName"

// Columns of a soup table
public let ID_COL = "id"
public let CREATED_COL = "created"
public let LAST_MODIFIED_COL = "lastModified"
public let SOUP_COL = "soup"

// JSON fields added to soup element on insert/update
public let SOUP_ENTRY_ID = "_soupEntryId"
public let SOUP_LAST_MODIFIED_DATE = "_soupLastModifiedDate"

// Explain support
internal let EXPLAIN_SQL = "sql"
internal let EXPLAIN_ARGS = "args"

// Caches count limit
internal let CACHES_COUNT_LIMIT = 1024

// MARK: - Type Aliases
public typealias EncryptionKeyGenerator = () -> Data?
public typealias EncryptionSaltBlock = () -> String?
typealias SFIndexSpecTypeFilterBlock = (SoupIndex) -> Bool

// MARK: - SmartStore Main Class
@objc(SFSmartStore)
public class SmartStore: NSObject {

    // Static initializer to set up encryption defaults
    private static let initializeOnce: Void = {
        SmartStore.initializeSmartStore()
    }()

    // MARK: - Instance Variables
    var _storeQueue: FMDatabaseQueue!
    var _dbMgr: DatabaseManager!
    var _isGlobal: Bool = false
    var _ftsExtension: SmartStoreFtsExtension = .fts5

    internal var _dataProtectionKnownAvailable: Bool = false
    internal var _dataProtectAvailObserverToken: Any?
    internal var _dataProtectUnavailObserverToken: Any?
    internal var _soupNameToTableName: NSCache<NSString, NSString>!
    internal var _indexSpecsBySoup: NSCache<NSString, NSArray>!
    internal var _smartSqlToSql: SmartSqlCache!

    // MARK: - Public Properties
    @objc public var name: String
    @objc public var userAccount: SFUserAccount?
    @objc public var capturesExplainQueryPlan: Bool = false
    @objc public var lastExplainQueryPlan: [String: Any]?

    @objc public var path: String? {
        if name.isEmpty {
            return nil
        }
        return _dbMgr.fullDbFilePath(forStoreName: name)
    }

    // MARK: - Class Properties
    @objc public class var allStoreNames: [String] {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        let allStoreNames = DatabaseManager.sharedManager(for: UserAccountManager.shared.currentUserAccount)?.allStoreNames() ?? []
        return allStoreNames
    }

    @objc public class var allGlobalStoreNames: [String] {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        return DatabaseManager.sharedGlobalManager().allStoreNames() ?? []
    }

    @objc public class var encryptionKeyGenerator: EncryptionKeyGenerator? {
        return _encryptionKeyGenerator
    }

    @objc public class func setEncryptionKeyGenerator(_ newGenerator: @escaping EncryptionKeyGenerator) {
        _encryptionKeyGenerator = newGenerator
    }

    @objc public class var encryptionSaltBlock: EncryptionSaltBlock? {
        return _encryptionSaltBlock
    }

    @objc public class func setEncryptionSaltBlock(_ newBlock: @escaping EncryptionSaltBlock) {
        _encryptionSaltBlock = newBlock
    }

    @objc public class var jsonSerializationCheckEnabled: Bool {
        get { return _jsonSerializationCheckEnabled }
        set { _jsonSerializationCheckEnabled = newValue }
    }

    @objc public class func setPostRawJsonOnError(_ value: Bool) {
        _postRawJsonOnError = value
    }

    @objc public class var licenseKey: String? {
        return _licenseKey
    }

    @objc public class func setLicenseKey(_ key: String?) {
        _licenseKey = key
    }

    // MARK: - Initialization
    @objc(initializeSmartStore)
    public class func initializeSmartStore() {
        if _encryptionKeyGenerator == nil {
            _encryptionKeyGenerator = {
                do {
                    let key = try SFSDKKeyGenerator.encryptionKey(for: kSFSmartStoreEncryptionKeyLabel)
                    return key.withUnsafeBytes { Data($0) }
                } catch {
                    SmartStoreLogger.e(SmartStore.self, message: "Error getting encryption key: \(error.localizedDescription)")
                    return nil
                }
            }
        }

        if _encryptionSaltBlock == nil {
            _encryptionSaltBlock = {
                var salt: String?

                let existingSalt = KeychainHelper.read(service: kSFSmartStoreEncryptionSaltLabel, account: nil).data
                if let existingSalt = existingSalt {
                    salt = (existingSalt as NSData).sfsdk_newHexStringFromBytes
                } else if SFSDKDatasharingHelper.shared.isAppGroupEnabled {
                    let newSalt = NSMutableData(length: Int(kSFSmartStoreEncryptionSaltLength))?.sfsdk_randomData(ofLength: Int(kSFSmartStoreEncryptionSaltLength))
                    if let newSalt = newSalt {
                        let result = KeychainHelper.write(service: kSFSmartStoreEncryptionSaltLabel, data: newSalt, account: nil)
                        if result.success {
                            salt = (newSalt as NSData).sfsdk_newHexStringFromBytes
                        } else {
                            SmartStoreLogger.e(SmartStore.self, message: "Error writing salt to keychain: \(result.error?.localizedDescription ?? "")")
                        }
                    }
                }
                return salt
            }
        }
    }

    @objc public convenience init?(name: String, user: SFUserAccount?) {
        self.init(name: name, user: user, isGlobal: false)
    }

    @objc public init?(name: String, user: SFUserAccount?, isGlobal: Bool) {
        // Ensure static initialization runs
        _ = SmartStore.initializeOnce

        self.name = name
        self.userAccount = user

        super.init()

        if user == nil && !isGlobal {
            SmartStoreLogger.w(type(of: self), message: "Cannot create SmartStore with name '\(name)': user is not configured, and isGlobal is not configured. Did you mean to call sharedGlobalStoreWithName?")
            return nil
        }

        SmartStoreLogger.d(type(of: self), message: "init \(name), user: \(Utils.userKey(for: user) ?? ""), isGlobal: \(isGlobal)")

        self._isGlobal = isGlobal
        if _isGlobal {
            self._dbMgr = DatabaseManager.sharedGlobalManager()
            SFSDKAppFeatureMarkers.registerAppFeature(kSFAppFeatureSmartStoreGlobal)
        } else {
            self._dbMgr = DatabaseManager.sharedManager(for: user)
            SFSDKAppFeatureMarkers.registerAppFeature(kSFAppFeatureSmartStoreUser)
        }

        // Setup listening for data protection available / unavailable
        _dataProtectionKnownAvailable = false
        let this = self
        _dataProtectAvailObserverToken = NotificationCenter.default.addObserver(
            forName: UIApplication.protectedDataDidBecomeAvailableNotification,
            object: nil,
            queue: nil
        ) { _ in
            SmartStoreLogger.d(type(of: this), message: "SFSmartStore UIApplicationProtectedDataDidBecomeAvailable")
            this._dataProtectionKnownAvailable = true
        }

        _dataProtectUnavailObserverToken = NotificationCenter.default.addObserver(
            forName: UIApplication.protectedDataWillBecomeUnavailableNotification,
            object: nil,
            queue: nil
        ) { _ in
            SmartStoreLogger.d(type(of: this), message: "SFSmartStore UIApplicationProtectedDataWillBecomeUnavailable")
            this._dataProtectionKnownAvailable = false
        }

        _soupNameToTableName = NSCache<NSString, NSString>()
        _soupNameToTableName.countLimit = CACHES_COUNT_LIMIT

        _indexSpecsBySoup = NSCache<NSString, NSArray>()
        _indexSpecsBySoup.countLimit = CACHES_COUNT_LIMIT

        _smartSqlToSql = SmartSqlCache(countLimit: UInt(CACHES_COUNT_LIMIT))

        // Using FTS5 by default
        _ftsExtension = .fts5

        if !_dbMgr.persistentStoreExists(name) {
            if !firstTimeStoreDatabaseSetup() {
                return nil
            }
        } else {
            if !subsequentTimesStoreDatabaseSetup() {
                if !firstTimeStoreDatabaseSetup() {
                    return nil
                }
            }
        }
    }

    deinit {
        SmartStoreLogger.d(type(of: self), message: "dealloc store: '\(name)'")
        _storeQueue?.close()

        if let token = _dataProtectAvailObserverToken {
            NotificationCenter.default.removeObserver(token)
        }
        if let token = _dataProtectUnavailObserverToken {
            NotificationCenter.default.removeObserver(token)
        }
    }

    // MARK: - Database Setup
    fileprivate func firstTimeStoreDatabaseSetup() -> Bool {
        var result = false

        result = _dbMgr.createStoreDir(name)
        result = result && openStoreDatabase() && createMetaTables()

        if result {
            _storeQueue.close()
            _storeQueue = nil
            result = _dbMgr.protectStoreDirIfNeeded(name, protection: FileProtectionType.completeUntilFirstUserAuthentication.rawValue)
        }

        result = result && openStoreDatabase()

        if !result {
            SmartStoreLogger.e(type(of: self), message: "Deleting store dir since we can't set it up properly: \(name)")
            _dbMgr.removeStoreDir(name)
        }
        return result
    }

    fileprivate func subsequentTimesStoreDatabaseSetup() -> Bool {
        var result = false

        result = _dbMgr.protectStoreDirIfNeeded(name, protection: FileProtectionType.completeUntilFirstUserAuthentication.rawValue)
        result = result && openStoreDatabase()

        if !result {
            SmartStoreLogger.e(type(of: self), message: "Deleting store dir since we can't open it anymore: \(name)")
            _dbMgr.removeStoreDir(name)
        }

        if result {
            _ = createLongOperationsStatusTable()
            resumeLongOperations()
            upgradeRenameTableSoupNamesToSoupAttrs()
        }

        return result
    }

    // MARK: - Store Methods
    @objc public class func shared(withName storeName: String) -> SmartStore? {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        return shared(withName: storeName, forUserAccount: UserAccountManager.shared.currentUserAccount)
    }

    @objc public class func shared(withName storeName: String, forUserAccount user: SFUserAccount?) -> SmartStore? {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        guard let user = user else {
            SmartStoreLogger.w(SmartStore.self, message: "Cannot create shared store with name '\(storeName)' for nil user. Did you mean to call sharedGlobalStoreWithName?")
            return nil
        }

        if _allSharedStores.count == 0 {
            _allSharedStores = NSMutableDictionary()
        }

        let userKey = Utils.userKey(for: user)

        if _allSharedStores[userKey] == nil {
            _allSharedStores[userKey] = NSMutableDictionary()
        }

        let userStores = _allSharedStores[userKey] as? NSMutableDictionary
        var store = userStores?[storeName] as? SmartStore

        if store == nil {
            if user.loginState != .loggedIn {
                SmartStoreLogger.w(SmartStore.self, message: "A user account must be in the SFUserAccountLoginStateLoggedIn state in order to create a store.")
                return nil
            }
            store = SmartStore(name: storeName, user: user)
            if let store = store {
                userStores?[storeName] = store
            }

            let numUserStores = userStores?.count ?? 0
            SFSDKEventBuilderHelper.createAndStoreEvent("userSmartStoreInit", userAccount: user, className: NSStringFromClass(SmartStore.self), attributes: ["numUserStores": numUserStores])
        }
        return store
    }

    @objc public class func sharedGlobal(withName storeName: String) -> SmartStore? {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        if _allGlobalSharedStores.count == 0 {
            _allGlobalSharedStores = NSMutableDictionary()
        }

        var store = _allGlobalSharedStores[storeName] as? SmartStore
        if store == nil {
            store = SmartStore(name: storeName, user: nil, isGlobal: true)
            if let store = store {
                _allGlobalSharedStores[storeName] = store
            }
        }

        let numGlobalStores = _allGlobalSharedStores.allKeys.count
        SFSDKEventBuilderHelper.createAndStoreEvent("globalSmartStoreInit", userAccount: nil, className: NSStringFromClass(SmartStore.self), attributes: ["numGlobalStores": numGlobalStores])
        return store
    }

    @objc public class func removeShared(withName storeName: String) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        removeShared(withName: storeName, forUserAccount: UserAccountManager.shared.currentUserAccount)
    }

    @objc public class func removeShared(withName storeName: String, forUserAccount user: SFUserAccount?) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        guard let user = user else {
            SmartStoreLogger.i(SmartStore.self, message: "Cannot remove store with name '\(storeName)' for nil user. Did you mean to call removeSharedGlobalStoreWithName?")
            return
        }

        SmartStoreLogger.d(SmartStore.self, message: "removeSharedStoreWithName: \(storeName), user: \(user)")
        let userKey = Utils.userKey(for: user)

        let userStores = _allSharedStores[userKey] as? NSMutableDictionary
        if let existingStore = userStores?[storeName] as? SmartStore {
            existingStore._storeQueue.close()
            userStores?.removeObject(forKey: storeName)
        }
        DatabaseManager.sharedManager(for: user)?.removeStoreDir(storeName)
    }

    @objc public class func removeSharedGlobal(withName storeName: String) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        SmartStoreLogger.d(SmartStore.self, message: "removeSharedGlobalStoreWithName: \(storeName)")
        if let existingStore = _allGlobalSharedStores[storeName] as? SmartStore {
            existingStore._storeQueue.close()
            _allGlobalSharedStores.removeObject(forKey: storeName)
        }
        DatabaseManager.sharedGlobalManager().removeStoreDir(storeName)
    }

    @objc public class func removeAllForCurrentUser() {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        removeAll(forUserAccount: UserAccountManager.shared.currentUserAccount)
    }

    @objc public class func removeAll(forUserAccount user: SFUserAccount?) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        guard let user = user else {
            SmartStoreLogger.i(SmartStore.self, message: "Cannot remove all stores for nil user. Did you mean to call removeAllGlobalStores?")
            return
        }

        let allStoreNames = DatabaseManager.sharedManager(for: user)?.allStoreNames() ?? []
        for storeName in allStoreNames {
            removeShared(withName: storeName, forUserAccount: user)
        }
        DatabaseManager.removeSharedManager(for: user)
    }

    @objc public class func removeAllGlobal() {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        let allStoreNames = DatabaseManager.sharedGlobalManager().allStoreNames() ?? []
        for storeName in allStoreNames {
            removeSharedGlobal(withName: storeName)
        }
    }

    // MARK: - Utility Methods
    @objc public func allSoupNames() -> [String] {
        var result: [String] = []
        var localError: NSError?
        _ = inDatabase({ db in
            result = self.allSoupNames(with: db)
        }, error: &localError)
        return result
    }

    func allSoupNames(with db: FMDatabase?) -> [String] {
        var soupNames: [String] = []
        let frs = executeQueryThrows("SELECT \(SOUP_NAME_COL) FROM \(SOUP_ATTRS_TABLE)", with: db)
        while frs?.next() == true {
            if let name = frs?.string(forColumnIndex: 0) {
                soupNames.append(name)
            }
        }
        frs?.close()
        return soupNames
    }

    @objc public class func date(lastModifiedValue: NSNumber) -> Date {
        let lastModifiedSecs = lastModifiedValue.doubleValue / 1000.0
        return Date(timeIntervalSince1970: lastModifiedSecs)
    }

    @objc public func isFileDataProtectionActive() -> Bool {
        return _dataProtectionKnownAvailable
    }

    @objc public class func buildEventOnJsonParseError(forUser user: SFUserAccount?, fromMethod: String, rawJson: String) {
        var attributes: [String: Any] = [:]
        attributes["errorCode"] = SFJsonUtils.lastError?.code ?? 0
        attributes["errorMessage"] = SFJsonUtils.lastError?.localizedDescription ?? ""
        attributes["fromMethod"] = fromMethod
        SFSDKEventBuilderHelper.createAndStoreEvent("SmartStoreJSONParseError", userAccount: user, className: NSStringFromClass(SmartStore.self), attributes: attributes)

        var info = attributes
        if _postRawJsonOnError {
            info["rawJson"] = rawJson
        }
        NotificationCenter.default.post(name: NSNotification.Name(kSFSmartStoreJSONParseErrorNotification), object: self, userInfo: info)
    }

    @objc public class func buildEventOnJsonSerializationError(forUser user: SFUserAccount?, fromMethod: String, error: Error) {
        var attributes: [String: Any] = [:]
        attributes["errorCode"] = (error as NSError).code
        attributes["errorMessage"] = error.localizedDescription
        attributes["fromMethod"] = fromMethod
        SFSDKEventBuilderHelper.createAndStoreEvent("SmartStoreJSONSerializationError", userAccount: user, className: NSStringFromClass(SmartStore.self), attributes: attributes)

        NotificationCenter.default.post(name: NSNotification.Name(kSFSmartStoreJSONSerializationErrorNotification), object: self, userInfo: attributes)
    }

    // MARK: - Soup Manipulation Methods
    @objc public func indices(forSoupNamed soupName: String) -> [SoupIndex] {
        var result: [SoupIndex] = []
        var localError: NSError?
        _ = inDatabase({ db in
            result = self.indices(forSoup: soupName, with: db)
        }, error: &localError)
        return result
    }

    @objc public func soupExists(forName soupName: String) -> Bool {
        var result = false
        var localError: NSError?
        _ = inDatabase({ db in
            result = self.soupExists(soupName, with: db)
        }, error: &localError)
        return result
    }

    func soupExists(_ soupName: String, with db: FMDatabase?) -> Bool {
        var result = false
        let soupTableName = tableName(forSoup: soupName, with: db)
        if let soupTableName = soupTableName {
            result = db?.tableExists(soupTableName) ?? false
        }
        return result
    }

    @objc(registerSoup:withIndexSpecs:error:)
    public func registerSoup(withName soupName: String, withIndices indexSpecs: [SoupIndex]) throws {
        var localError: NSError?
        _ = inTransaction({ db, rollback in
            self.registerSoup(withName: soupName, withIndexSpecs: indexSpecs, withSoupTableName: nil, with: db)
        }, error: &localError)

        if let localError = localError {
            throw localError
        }
    }

    @objc public func count(using querySpec: QuerySpec) throws -> NSNumber {
        var localError: NSError?
        var result: Int = 0
        _ = inDatabase({ db in
            result = self.count(with: querySpec, with: db)
        }, error: &localError)

        if let localError = localError {
            throw localError
        }
        return NSNumber(value: result)
    }

    func count(with querySpec: QuerySpec, with db: FMDatabase?) -> Int {
        SmartStoreLogger.d(type(of: self), message: "countWithQuerySpec: \nquerySpec:\(querySpec) \n")
        var result = 0

        let countSql = convertSmartSql(querySpec.countSmartSql, with: db)
        SmartStoreLogger.d(type(of: self), message: "countWithQuerySpec: countSql:\(countSql ?? "") \n")

        let args = querySpec.binds()

        let frs = executeQueryThrows(countSql ?? "", withArgumentsInArray: args, with: db)
        if frs?.next() == true {
            result = Int(frs?.int(forColumnIndex: 0) ?? 0)
        }
        frs?.close()

        return result
    }

    @objc public func query(using querySpec: QuerySpec, startingFromPageIndex pageIndex: UInt) throws -> [Any] {
        return try query(using: querySpec, startingFromPageIndex: pageIndex, whereArgs: nil)
    }

    @objc public func query(using querySpec: QuerySpec, startingFromPageIndex pageIndex: UInt, whereArgs: [Any]?) throws -> [Any] {
        if whereArgs != nil && querySpec.queryType != .smart {
            throw NSError(domain: kSFSmartStoreErrorDomain,
                         code: kSFSmartStoreWhereArgsNotSupportedCode,
                         userInfo: [NSLocalizedDescriptionKey: kSFSmartStoreWhereArgsNotSupportedDescription])
        }

        var localError: NSError?
        var resultArray: [Any]? = []
        let success = inDatabase({ db in
            self.runQuery(&resultArray, resultString: nil, querySpec: querySpec, pageIndex: pageIndex, whereArgs: whereArgs, with: db)
        }, error: &localError)

        if !success, let localError = localError {
            throw localError
        }
        return resultArray ?? []
    }

    @objc public func query(result resultString: NSMutableString, querySpec: QuerySpec, pageIndex: UInt) throws {
        var localError: NSError?
        _ = inDatabase({ db in
            var emptyArray: [Any]? = nil
            self.runQuery(&emptyArray, resultString: resultString, querySpec: querySpec, pageIndex: pageIndex, whereArgs: nil, with: db)
        }, error: &localError)

        if let localError = localError {
            throw localError
        }
    }

    func runQuery(_ resultArray: inout [Any]?, resultString: NSMutableString?, querySpec: QuerySpec, pageIndex: UInt, whereArgs: [Any]?, with db: FMDatabase?) {
        let computeResultAsString = resultString != nil

        let offsetRows = querySpec.pageSize * pageIndex
        let numberRows = querySpec.pageSize
        let limit = "\(offsetRows),\(numberRows)"

        let sql = convertSmartSql(querySpec.smartSql, with: db)
        let limitSql = ["SELECT * FROM (", sql ?? "", ") LIMIT ", limit].joined()

        let args = querySpec.queryType != .smart ? querySpec.binds() : whereArgs

        let frs = executeQueryThrows(limitSql, withArgumentsInArray: args, with: db)
        var resultStrings: [String] = []

        while frs?.next() == true {
            if querySpec.queryType == .smart || querySpec.selectPaths != nil {
                if computeResultAsString {
                    var emptyArray: [Any]? = nil
                    let rowData = NSMutableString()
                    getDataFromRow(&emptyArray, resultString: rowData, resultSet: frs)
                    if rowData.length > 0 {
                        resultStrings.append(rowData as String)
                    }
                } else {
                    var rowData: [Any]? = []
                    getDataFromRow(&rowData, resultString: nil, resultSet: frs)
                    if let rowData = rowData, !rowData.isEmpty {
                        resultArray?.append(rowData)
                    }
                }
            } else {
                var rawJson: String?
                let columnName = frs?.columnName(for: 0)
                if columnName == SOUP_COL {
                    rawJson = frs?.string(forColumnIndex: 0)
                }
                if computeResultAsString {
                    if let rawJson = rawJson {
                        resultStrings.append(rawJson)
                    }
                } else {
                    if let rawJson = rawJson, let entry = SFJsonUtils.object(from: rawJson) {
                        resultArray?.append(entry)
                    }
                }
            }
        }
        frs?.close()

        if computeResultAsString {
            resultString?.append("[")
            resultString?.append(resultStrings.joined(separator: ","))
            resultString?.append("]")
        }
    }

    func getDataFromRow(_ resultArray: inout [Any]?, resultString: NSMutableString?, resultSet frs: FMResultSet?) {
        let computeResultAsString = resultString != nil
        guard let frs = frs else { return }

        let valuesMap = frs.resultDictionary as? [String: Any] ?? [:]
        var resultStrings: [String] = []

        for i in 0..<frs.columnCount {
            autoreleasepool {
                let columnName = frs.columnName(for: i) ?? ""
                let value = valuesMap[columnName]

                let isSoupCol = (value is String) && (columnName == SOUP_COL || columnName.hasPrefix("\(SOUP_COL):"))

                if isSoupCol {
                    if computeResultAsString {
                        if let strValue = value as? String {
                            resultStrings.append(strValue)
                        } else {
                            resultStrings.append("null")
                        }
                    } else {
                        if let strValue = value as? String, let entry = SFJsonUtils.object(from: strValue) {
                            resultArray?.append(entry)
                        } else {
                            resultArray?.append(NSNull())
                        }
                    }
                } else {
                    if computeResultAsString {
                        if value is NSNull {
                            resultStrings.append("null")
                        } else if let numValue = value as? NSNumber {
                            resultStrings.append(numValue.stringValue)
                        } else if let strValue = value as? String {
                            if let escaped = escapeStringValueAndQuote(strValue) {
                                resultStrings.append(escaped)
                            } else {
                                resultStrings.append("null")
                            }
                        }
                    } else {
                        if let value = value {
                            resultArray?.append(value)
                        }
                    }
                }
            }
        }

        if computeResultAsString {
            resultString?.append("[")
            resultString?.append(resultStrings.joined(separator: ","))
            resultString?.append("]")
        }
    }

    func escapeStringValueAndQuote(_ raw: String) -> String? {
        let escaped = NSMutableString()
        escaped.append("\"")

        for i in 0..<raw.count {
            let index = raw.index(raw.startIndex, offsetBy: i)
            let c = raw[index]

            switch c {
            case "\\", "/", "\"":
                escaped.append("\\\(c)")
            case "\u{08}":
                escaped.append("\\b")
            case "\u{0C}":
                escaped.append("\\f")
            case "\n":
                escaped.append("\\n")
            case "\r":
                escaped.append("\\r")
            case "\t":
                escaped.append("\\t")
            default:
                if c.unicodeScalars.first!.value < 32 {
                    escaped.appendFormat("\\u%04x", c.unicodeScalars.first!.value)
                } else {
                    escaped.append(String(c))
                }
            }
        }
        escaped.append("\"")

        if !checkRawJson("[\(escaped)]", fromMethod: #function) {
            return nil
        } else {
            return escaped as String
        }
    }

    @objc public func retrieve(usingSoupEntryIds soupEntryIds: [NSNumber], fromSoupNamed soupName: String) -> [NSDictionary] {
        var result: [NSDictionary] = []
        var localError: NSError?
        _ = inDatabase({ db in
            result = self.retrieveEntries(soupEntryIds, fromSoup: soupName, with: db)
        }, error: &localError)
        return result
    }

    func retrieveEntries(_ soupEntryIds: [NSNumber], fromSoup soupName: String, with db: FMDatabase?) -> [NSDictionary] {
        var result: [NSDictionary] = []

        guard let soupTableName = tableName(forSoup: soupName, with: db) else {
            SmartStoreLogger.d(type(of: self), message: "Soup: '\(soupName)' does not exist")
            return result
        }

        let pred = idsInPredicate(soupEntryIds, idCol: ID_COL)
        let querySql = "SELECT \(SOUP_COL) FROM \(soupTableName) WHERE \(pred)"
        let frs = executeQueryThrows(querySql, with: db)

        while frs?.next() == true {
            autoreleasepool {
                if let rawJson = frs?.string(forColumn: SOUP_COL),
                   let entry = SFJsonUtils.object(from: rawJson) as? NSDictionary {
                    result.append(entry)
                }
            }
        }
        frs?.close()

        return result
    }

    @objc public func upsert(entries: [NSDictionary], forSoupNamed soupName: String) -> [NSDictionary] {
        return upsert(entries: entries, forSoupNamed: soupName, withExternalIdPath: SOUP_ENTRY_ID) ?? []
    }

    @objc public func upsert(entries: [NSDictionary], forSoupNamed soupName: String, withExternalIdPath externalIdPath: String) -> [NSDictionary]? {
        var localError: NSError?
        var result: [NSDictionary]?

        _ = inTransaction({ db, rollback in
            result = self.upsertEntries(entries, toSoup: soupName, withExternalIdPath: externalIdPath, error: &localError, with: db)
        }, error: &localError)

        return result
    }

    func upsertEntries(_ entries: [NSDictionary], toSoup soupName: String, withExternalIdPath externalIdPath: String?, error: inout NSError?, with db: FMDatabase?) -> [NSDictionary]? {
        var result: [NSDictionary]?
        let localExternalIdPath = externalIdPath ?? SOUP_ENTRY_ID

        if soupExists(soupName, with: db) {
            let indices = self.indices(forSoup: soupName, with: db)
            result = []
            var upsertSuccess = true

            for entry in entries {
                var localError: NSError?
                if let upsertedEntry = upsertOneEntry(entry, inSoup: soupName, indices: indices, externalIdPath: localExternalIdPath, error: &localError, with: db) {
                    result?.append(upsertedEntry)
                } else {
                    error = localError
                    upsertSuccess = false
                    break
                }
            }

            if !upsertSuccess {
                result?.removeAll()
            }
        }

        return result
    }

    func upsertOneEntry(_ entry: NSDictionary, inSoup soupName: String, indices: [SoupIndex], externalIdPath: String?, error: inout NSError?, with db: FMDatabase?) -> NSDictionary? {
        var result: NSDictionary?

        guard let soupTableName = tableName(forSoup: soupName, with: db) else {
            return nil
        }

        var soupEntryId: NSNumber?
        if let externalIdPath = externalIdPath {
            if externalIdPath == SOUP_ENTRY_ID {
                soupEntryId = entry[SOUP_ENTRY_ID] as? NSNumber
            } else {
                let fieldValue = SFJsonUtils.projectIntoJson(entry as! [String: Any], path: externalIdPath) as? String
                if fieldValue == nil {
                    error = NSError(domain: kSFSmartStoreErrorDomain,
                                  code: kSFSmartStoreExternalIdNilCode,
                                  userInfo: [NSLocalizedDescriptionKey: String(format: kSFSmartStoreExternalIdNilDescription, externalIdPath)])
                    return nil
                }

                soupEntryId = lookupSoupEntryId(forSoupName: soupName, soupTableName: soupTableName, forFieldPath: externalIdPath, fieldValue: fieldValue, error: &error, with: db)
                if let error = error {
                    let errorMsg = String(format: kSFSmartStoreExtIdLookupError, externalIdPath, fieldValue ?? "", error.localizedDescription)
                    SmartStoreLogger.d(type(of: self), message: errorMsg)
                    return nil
                }
            }
        }

        if let soupEntryId = soupEntryId {
            result = updateOneEntry(entry, withEntryId: soupEntryId, inSoupTable: soupTableName, indices: indices, with: db)
        } else {
            result = insertOneEntry(entry, inSoupTable: soupTableName, indices: indices, with: db)
        }

        return result
    }

    func insertOneEntry(_ entry: NSDictionary, inSoupTable soupTableName: String, indices: [SoupIndex], with db: FMDatabase?) -> NSDictionary? {
        let nowVal = currentTimeInMilliseconds()
        var newEntryId: NSNumber

        let frs = executeQueryThrows("SELECT seq FROM SQLITE_SEQUENCE WHERE name = ?", withArgumentsInArray: [soupTableName], with: db)
        if frs?.next() == true {
            newEntryId = NSNumber(value: 1 + (frs?.longLongInt(forColumnIndex: 0) ?? 0))
        } else {
            newEntryId = NSNumber(value: 1)
        }
        frs?.close()

        let mutableEntry = entry.mutableCopy() as! NSMutableDictionary
        mutableEntry.setValue(newEntryId, forKey: SOUP_ENTRY_ID)
        mutableEntry.setValue(nowVal, forKey: SOUP_LAST_MODIFIED_DATE)

        var values: [String: Any] = [
            CREATED_COL: nowVal,
            LAST_MODIFIED_COL: nowVal
        ]

        let rawJson = SFJsonUtils.jsonRepresentation(mutableEntry)
        values[SOUP_COL] = rawJson

        projectIndexedPaths(entry, values: &values, indices: indices, typeFilter: kValueExtractedToColumn)
        insertIntoTable(soupTableName, values: values, with: db)

        if SoupIndex.hasFts(indices) {
            var ftsValues: [String: Any] = [ROWID_COL: newEntryId]
            projectIndexedPaths(entry, values: &ftsValues, indices: indices, typeFilter: kValueExtractedToFtsColumn)
            insertIntoTable("\(soupTableName)_fts", values: ftsValues, with: db)
        }

        return mutableEntry
    }

    func updateOneEntry(_ entry: NSDictionary, withEntryId entryId: NSNumber, inSoupTable soupTableName: String, indices: [SoupIndex], with db: FMDatabase?) -> NSDictionary? {
        let nowVal = currentTimeInMilliseconds()
        var values: [String: Any] = [LAST_MODIFIED_COL: nowVal]

        projectIndexedPaths(entry, values: &values, indices: indices, typeFilter: kValueExtractedToColumn)

        let mutableEntry = entry.mutableCopy() as! NSMutableDictionary
        mutableEntry.setValue(nowVal, forKey: SOUP_LAST_MODIFIED_DATE)
        mutableEntry.setValue(entryId, forKey: SOUP_ENTRY_ID)

        let rawJson = SFJsonUtils.jsonRepresentation(mutableEntry)
        values[SOUP_COL] = rawJson

        updateTable(soupTableName, values: values, entryId: entryId, idCol: ID_COL, with: db)

        if SoupIndex.hasFts(indices) {
            var ftsValues: [String: Any] = [:]
            projectIndexedPaths(entry, values: &ftsValues, indices: indices, typeFilter: kValueExtractedToFtsColumn)
            updateTable("\(soupTableName)_fts", values: ftsValues, entryId: entryId, idCol: ROWID_COL, with: db)
        }

        return mutableEntry
    }

    public func lookupSoupEntryId(soupNamed soupName: String, fieldPath: String, fieldValue: String?) throws -> NSNumber? {
        var result: NSNumber?
        var localError: NSError?
        var innerError: NSError?
        _ = inDatabase({ db in
            guard let soupTableName = self.tableName(forSoup: soupName, with: db) else { return }
            result = self.lookupSoupEntryId(forSoupName: soupName, soupTableName: soupTableName, forFieldPath: fieldPath, fieldValue: fieldValue, error: &innerError, with: db)
            localError = innerError
        }, error: &localError)

        if let localError = localError {
            throw localError
        }
        return result
    }

    func lookupSoupEntryId(forSoupName soupName: String, soupTableName: String, forFieldPath fieldPath: String, fieldValue: String?, error: inout NSError?, with db: FMDatabase?) -> NSNumber? {
        guard !soupName.isEmpty, !soupTableName.isEmpty, !fieldPath.isEmpty else {
            return nil
        }

        guard let fieldPathColumnName = columnName(forPath: fieldPath, inSoup: soupName, with: db) else {
            error = NSError(domain: kSFSmartStoreErrorDomain,
                          code: kSFSmartStoreIndexNotDefinedCode,
                          userInfo: [NSLocalizedDescriptionKey: String(format: kSFSmartStoreIndexNotDefinedDescription, fieldPath)])
            return nil
        }

        let whereClause: String
        if let fieldValue = fieldValue {
            whereClause = "\(fieldPathColumnName) = ?"
        } else {
            whereClause = "\(fieldPathColumnName) IS NULL"
        }

        let rs = queryTable(soupTableName,
                           forColumns: [ID_COL],
                           orderBy: nil,
                           limit: nil,
                           whereClause: whereClause,
                           whereArgs: fieldValue != nil ? [fieldValue!] : nil,
                           with: db)

        var returnId: NSNumber?
        if rs?.next() == true {
            returnId = NSNumber(value: rs?.int(forColumn: ID_COL) ?? 0)
            if rs?.next() == true {
                let errorDesc = String(format: kSFSmartStoreTooManyEntriesDescription, fieldValue ?? "NULL", fieldPath)
                error = NSError(domain: kSFSmartStoreErrorDomain,
                              code: kSFSmartStoreTooManyEntriesCode,
                              userInfo: [NSLocalizedDescriptionKey: errorDesc])
                returnId = nil
            }
        }
        rs?.close()

        return returnId
    }

    @objc(removeEntries:fromSoup:error:)
    public func remove(entryIds: [NSNumber], forSoupNamed soupName: String) throws {
        var localError: NSError?
        _ = inTransaction({ db, rollback in
            self.removeEntries(entryIds, fromSoup: soupName, with: db)
        }, error: &localError)

        if let localError = localError {
            throw localError
        }
    }

    func removeEntries(_ soupEntryIds: [NSNumber], fromSoup soupName: String, with db: FMDatabase?) {
        if soupExists(soupName, with: db) {
            guard let soupTableName = tableName(forSoup: soupName, with: db) else { return }
            let deleteSql = "DELETE FROM \(soupTableName) WHERE \(idsInPredicate(soupEntryIds, idCol: ID_COL))"
            executeUpdateThrows(deleteSql, with: db)

            if hasFts(soupName, with: db) {
                let deleteFtsSql = "DELETE FROM \(soupTableName)_fts WHERE \(idsInPredicate(soupEntryIds, idCol: ROWID_COL))"
                executeUpdateThrows(deleteFtsSql, with: db)
            }
        }
    }

    @objc(removeEntriesByQuery:fromSoup:error:)
    public func removeEntries(usingQuerySpec querySpec: QuerySpec, forSoupNamed soupName: String) throws {
        var localError: NSError?
        _ = inTransaction({ db, rollback in
            self.removeEntriesByQuery(querySpec, fromSoup: soupName, with: db)
        }, error: &localError)

        if let localError = localError {
            throw localError
        }
    }

    func removeEntriesByQuery(_ querySpec: QuerySpec, fromSoup soupName: String, with db: FMDatabase?) {
        guard let soupTableName = tableName(forSoup: soupName, with: db) else { return }
        let querySql = convertSmartSql(querySpec.idsSmartSql, with: db) ?? ""
        let limitSql = "SELECT * FROM (\(querySql)) LIMIT \(querySpec.pageSize)"
        let args = querySpec.binds()

        let deleteSql = "DELETE FROM \(soupTableName) WHERE \(ID_COL) in (\(limitSql))"
        executeUpdateThrows(deleteSql, withArgumentsInArray: args, with: db)

        if hasFts(soupName, with: db) {
            let deleteFtsSql = "DELETE FROM \(soupTableName)_fts WHERE \(ROWID_COL) in (\(querySql))"
            executeUpdateThrows(deleteFtsSql, with: db)
        }
    }

    @objc public func clearSoup(_ soupName: String) {
        var localError: NSError?
        _ = inTransaction({ db, rollback in
            self.clearSoup(soupName, with: db)
        }, error: &localError)
    }

    func clearSoup(_ soupName: String, with db: FMDatabase?) {
        if soupExists(soupName, with: db) {
            guard let soupTableName = tableName(forSoup: soupName, with: db) else { return }
            let deleteSql = "DELETE FROM \(soupTableName)"
            executeUpdateThrows(deleteSql, with: db)

            if hasFts(soupName, with: db) {
                let deleteFtsSql = "DELETE FROM \(soupTableName)_fts"
                executeUpdateThrows(deleteFtsSql, with: db)
            }
        }
    }

    @objc public func removeSoup(_ soupName: String) {
        var localError: NSError?
        _ = inTransaction({ db, rollback in
            self.removeSoup(soupName, with: db)
        }, error: &localError)
    }

    func removeSoup(_ soupName: String, with db: FMDatabase?) {
        SmartStoreLogger.d(type(of: self), message: "removeSoup: \(soupName)")
        guard let soupTableName = tableName(forSoup: soupName, with: db) else { return }

        let dropSql = "DROP TABLE IF EXISTS \(soupTableName)"
        executeUpdateThrows(dropSql, with: db)

        if hasFts(soupName, with: db) {
            let dropFtsSql = "DROP TABLE IF EXISTS \(soupTableName)_fts"
            executeUpdateThrows(dropFtsSql, with: db)
        }

        let deleteIndexSql = "DELETE FROM \(SOUP_INDEX_MAP_TABLE) WHERE \(SOUP_NAME_COL)=\"\(soupName)\""
        executeUpdateThrows(deleteIndexSql, with: db)

        let deleteNameSql = "DELETE FROM \(SOUP_ATTRS_TABLE) WHERE \(SOUP_NAME_COL)=\"\(soupName)\""
        executeUpdateThrows(deleteNameSql, with: db)

        removeFromCache(soupName)
    }

    @objc public func removeAllSoups() {
        var localError: NSError?
        _ = inTransaction({ db, rollback in
            self.removeAllSoup(with: db)
        }, error: &localError)
    }

    func removeAllSoup(with db: FMDatabase?) {
        let soupTableNames = tableNamesForAllSoups(with: db)
        for soupTableName in soupTableNames {
            removeSoup(soupTableName, with: db)
        }
    }

    @objc public func databaseSize() -> UInt64 {
        var size: UInt64 = 0
        let dbPath = _dbMgr.fullDbFilePath(forStoreName: name)
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: dbPath)
            size = attributes[.size] as? UInt64 ?? 0
        } catch {
            // Ignore error
        }
        return size
    }

    @objc public func alterSoup(named soupName: String, indexSpecs: [SoupIndex], reIndexData: Bool) -> Bool {
        if soupExists(forName: soupName) {
            let operation = AlterSoupLongOperation(store: self, soupName: soupName, newIndexSpecs: indexSpecs, reIndexData: reIndexData)
            operation.run()
            return true
        } else {
            return false
        }
    }

    @objc public func reIndexSoup(named soupName: String, indexPaths: [String]) -> Bool {
        var result = false
        var localError: NSError?
        _ = inTransaction({ db, rollback in
            result = self.reIndexSoup(soupName, withIndexPaths: indexPaths, with: db)
        }, error: &localError)
        return result
    }

    func reIndexSoup(_ soupName: String, withIndexPaths indexPaths: [String], with db: FMDatabase?) -> Bool {
        if soupExists(soupName, with: db) {
            guard let soupTableName = tableName(forSoup: soupName, with: db) else { return false }
            let mapIndexSpecs = SoupIndex.map(forSoupIndexes: indices(forSoup: soupName, with: db))
            var indices: [SoupIndex] = []

            let queryCols = [ID_COL, SOUP_COL]
            var hasFtsIndex = false

            for indexPath in indexPaths {
                if let idx = mapIndexSpecs[indexPath] {
                    indices.append(idx)
                    if idx.indexType == kSoupIndexTypeFullText {
                        hasFtsIndex = true
                    }
                }
            }

            let frs = queryTable(soupTableName, forColumns: queryCols, orderBy: nil, limit: nil, whereClause: nil, whereArgs: nil, with: db)

            while frs?.next() == true {
                autoreleasepool {
                    let entryId = NSNumber(value: frs?.long(forColumn: ID_COL) ?? 0)
                    if let soupElt = frs?.string(forColumn: SOUP_COL),
                       let entry = SFJsonUtils.object(from: soupElt) as? NSDictionary {

                        var values: [String: Any] = [:]
                        projectIndexedPaths(entry, values: &values, indices: indices, typeFilter: kValueExtractedToColumn)
                        if !values.isEmpty {
                            updateTable(soupTableName, values: values, entryId: entryId, idCol: ID_COL, with: db)
                        }

                        if hasFtsIndex {
                            var ftsValues: [String: Any] = [:]
                            projectIndexedPaths(entry, values: &ftsValues, indices: indices, typeFilter: kValueExtractedToFtsColumn)
                            if !ftsValues.isEmpty {
                                updateTable("\(soupTableName)_fts", values: ftsValues, entryId: entryId, idCol: ROWID_COL, with: db)
                            }
                        }
                    }
                }
            }
            return true
        } else {
            return false
        }
    }

    // MARK: - SQLCipher Info Methods
    @objc public func runtimeSettings() -> [String] {
        return queryPragma("cipher_settings")
    }

    @objc public func compileOptions() -> [String] {
        return queryPragma("compile_options")
    }

    @objc public func versionOfSQLCipher() -> String {
        return queryPragma("cipher_version").joined()
    }

    @objc public func cipherProviderVersion() -> String {
        return queryPragma("cipher_provider_version").joined()
    }

    @objc public func cipherFIPSStatus() -> Bool {
        let status = queryPragma("cipher_fips_status").joined()
        return status == "1"
    }

    func queryPragma(_ pragma: String) -> [String] {
        var result: [String] = []

        _storeQueue.inDatabase { db in
            let rs = db.executeQuery("pragma \(pragma)", withArgumentsIn: [])
            while rs?.next() == true {
                if let value = rs?.string(forColumnIndex: 0) {
                    result.append(value)
                }
            }
            rs?.close()
        }

        return result
    }

    // MARK: - Private Helper Methods
    func projectIndexedPaths(_ entry: NSDictionary, values: inout [String: Any], indices: [SoupIndex], typeFilter: @escaping SFIndexSpecTypeFilterBlock) {
        for idx in indices {
            if !typeFilter(idx) {
                continue
            }

            var indexColVal = SFJsonUtils.projectIntoJson(entry as! [String: Any], path: idx.path)
            if indexColVal is NSDictionary || indexColVal is NSArray {
                indexColVal = SFJsonUtils.jsonRepresentation(indexColVal)
            }

            if let colName = idx.columnName {
                values[colName] = indexColVal ?? NSNull()
            }
        }
    }

    func idsInPredicate(_ ids: [NSNumber], idCol: String) -> String {
        let allIds = ids.map { $0.stringValue }.joined(separator: ",")
        return "\(idCol) IN (\(allIds))"
    }

    func tableNamesForAllSoups(with db: FMDatabase?) -> [String] {
        var result: [String] = []
        let sql = "SELECT \(SOUP_NAME_COL) FROM \(SOUP_ATTRS_TABLE)"
        let frs = executeQueryThrows(sql, with: db)

        while frs?.next() == true {
            if let tableName = frs?.string(forColumn: SOUP_NAME_COL) {
                result.append(tableName)
            }
        }
        frs?.close()

        return result
    }

    func tableName(bySoupId soupId: Int64) -> String {
        return "TABLE_\(soupId)"
    }

    func soupId(fromTableName tableName: String) -> NSNumber {
        let idString = tableName.replacingOccurrences(of: "TABLE_", with: "")
        return NSNumber(value: Int64(idString) ?? 0)
    }

    func hasFts(_ soupName: String, with db: FMDatabase?) -> Bool {
        let indices = self.indices(forSoup: soupName, with: db)
        return SoupIndex.hasFts(indices)
    }

    func upgradeRenameTableSoupNamesToSoupAttrs() {
        var localError: NSError?
        _ = inDatabase({ db in
            if let db = db, db.tableExists(SOUP_NAMES_TABLE) {
                let renameSql = "ALTER TABLE \(SOUP_NAMES_TABLE) RENAME TO \(SOUP_ATTRS_TABLE)"
                SmartStoreLogger.d(type(of: self), message: "renameSoupNamesTableSql: \(renameSql)")
                self.executeUpdateThrows(renameSql, with: db)
            }
        }, error: &localError)
    }

    @discardableResult
    func inDatabase(_ block: @escaping (FMDatabase?) -> Void, error: inout NSError?) -> Bool {
        var success = true
        _storeQueue.inDatabase { db in
            do {
                try self.tryCatch {
                    block(db)
                }
            } catch let caught as NSError {
                error = caught
                success = false
            } catch {
                success = false
            }
        }
        return success
    }

    @discardableResult
    func inTransaction(_ block: @escaping (FMDatabase?, UnsafeMutablePointer<ObjCBool>) -> Void, error: inout NSError?) -> Bool {
        var success = true
        _storeQueue.inTransaction { db, rollback in
            do {
                try self.tryCatch {
                    block(db, rollback)
                }
            } catch let caught as NSError {
                rollback.pointee = true
                error = caught
                success = false
            } catch {
                rollback.pointee = true
                success = false
            }
        }
        return success
    }

    func tryCatch(_ block: () throws -> Void) throws {
        // Note: Exception handling removed - Swift doesn't support NSException catching
        // in the same way Obj-C does. If exceptions occur, they'll be caught by the
        // uncaught exception handler at the app level.
        try block()
    }

    func error(forException exception: NSException) -> NSError {
        return NSError(domain: kSFSmartStoreErrorDomain,
                      code: kSFSmartStoreOtherErrorCode,
                      userInfo: [NSLocalizedDescriptionKey: exception.description])
    }
}
