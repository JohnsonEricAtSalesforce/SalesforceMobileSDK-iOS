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
import CryptoKit
import SalesforceSDKCommon
import SalesforceSDKCore
import FMDB

// MARK: - Public Constants

/// Container for SmartStore constants, exposed to Objective-C.
@objc(SFSmartStoreConstants)
@objcMembers
public class SmartStoreConstants: NSObject {
    /// The default store name used by the SFSmartStorePlugin: native code may choose to use separate stores.
    @objc(kDefaultSmartStoreName) public static let defaultStoreName: String = "defaultStore"

    /// The NSError domain for SmartStore errors.
    @objc(kSFSmartStoreErrorDomain) public static let errorDomain: String = "com.salesforce.smartstore.error"

    /// Notification for SmartStore JSON parsing errors.
    @objc(kSFSmartStoreJSONParseErrorNotification) public static let jsonParseErrorNotification: String = "SFSmartStoreJSONParseErrorNotification"

    /// The NSError exceptionName for errors loading external Soups.
    @objc(kSFSmartStoreErrorLoadExternalSoup) public static let externalSoupLoadingExceptionName: String = "com.salesforce.smartstore.LoadExternalSoupError"

    /// The label used to interact with the encryption key.
    @objc(kSFSmartStoreEncryptionKeyLabel) public static let encryptionKeyLabel: String = "com.salesforce.smartstore.encryption.keyLabel"

    /// The label used to interact with the encryption salt.
    @objc(kSFSmartStoreEncryptionSaltLabel) public static let encryptionSaltLabel: String = "com.salesforce.smartstore.encryption.saltLabel"

    /// Columns of a soup table
    @objc public static let idColumn: String = "id"
    @objc public static let createdColumn: String = "created"
    @objc public static let lastModifiedColumn: String = "lastModified"
    @objc public static let soupColumn: String = "soup"

    /// JSON fields added to soup element on insert/update
    @objc public static let soupEntryId: String = "_soupEntryId"
    @objc public static let lastModifiedDate: String = "_soupLastModifiedDate"

    /// ROWID column
    @objc public static let rowidColumn: String = "rowid"
}

// Top-level aliases for Swift callers
public let SmartStoreDefaultStoreName = SmartStoreConstants.defaultStoreName
public let SmartStoreErrorDomain = SmartStoreConstants.errorDomain
public let SmartStoreJSONParseErrorNotification = SmartStoreConstants.jsonParseErrorNotification
public let SmartStoreExternalSoupLoadingExceptionName = SmartStoreConstants.externalSoupLoadingExceptionName
public let SmartStoreEncryptionKeyLabel = SmartStoreConstants.encryptionKeyLabel
public let SmartStoreEncryptionSaltLabel = SmartStoreConstants.encryptionSaltLabel
public let SmartStoreIdColumn = SmartStoreConstants.idColumn
public let SmartStoreCreatedColumn = SmartStoreConstants.createdColumn
public let SmartStoreLastModifiedColumn = SmartStoreConstants.lastModifiedColumn
public let SmartStoreSoupColumn = SmartStoreConstants.soupColumn
public let SmartStoreSoupEntryId = SmartStoreConstants.soupEntryId
public let SmartStoreLastModifiedDate = SmartStoreConstants.lastModifiedDate
public let ROWID_COL = SmartStoreConstants.rowidColumn

// MARK: - Block Type Aliases

/// Block typedef for generating an encryption key.
public typealias EncryptionKeyGenerator = () -> Data?

/// Block typedef for generating a 16-byte hash for sharing data between multiple apps.
public typealias EncryptionSaltBlock = () -> String?

// MARK: - Internal Constants

private let kSFAppFeatureSmartStoreUser = "US"
private let kSFAppFeatureSmartStoreGlobal = "GS"
private let kSFSmartStoreJSONSerializationErrorNotification = "SFSmartStoreJSONSerializationErrorNotification"

private let kSFSmartStoreTooManyEntriesCode: Int = 1
private let kSFSmartStoreTooManyEntriesDescription = "Cannot update entry: the value '%@' for path '%@' does not represent a unique entry!"
private let kSFSmartStoreIndexNotDefinedCode: Int = 2
private let kSFSmartStoreIndexNotDefinedDescription = "No index column defined for field '%@'."
private let kSFSmartStoreExternalIdNilCode: Int = 3
private let kSFSmartStoreExternalIdNilDescription = "For upsert with external ID path '%@', value cannot be empty for any entries."
private let kSFSmartStoreExtIdLookupError = "There was an error retrieving the soup entry ID for path '%@' and value '%@': %@"
private let kSFSmartStoreWhereArgsNotSupportedCode: Int = 5
private let kSFSmartStoreWhereArgsNotSupportedDescription = "whereArgs can only be provided for smart queries"
private let kSFSmartStoreOtherErrorCode: Int = 999

private let kSFSmartStoreEncryptionSaltLength: UInt = 16

// Table to keep track of soup attributes
private let SOUP_NAMES_TABLE = "soup_names" // legacy, kept for backward compat
private let COLUMN_NAME_COL = "columnName"

// Columns of a soup fts table
let PATH_COL = "path"

// Columns of the soup index map table
let SOUP_NAME_COL = "soupName"
let COLUMN_TYPE_COL = "columnType"

// Table to keep track of soup attributes
let SOUP_ATTRS_TABLE = "soup_attrs"

// Table to keep track of soup's index specs
let SOUP_INDEX_MAP_TABLE = "soup_index_map"

// Columns of long operations status table
let TYPE_COL = "type"
let DETAILS_COL = "details"
let STATUS_COL = "status"

// Table to keep track of status of long operations in flight
let LONG_OPERATIONS_STATUS_TABLE = "long_operations_status"

// Explain support
private let EXPLAIN_SQL = "sql"
private let EXPLAIN_ARGS = "args"
private let EXPLAIN_ROWS = "rows"

// Caches count limit
private let CACHES_COUNT_LIMIT = 1024

// Buffer size when reading/writing bytes in memory
let kBufferSize: Int = 4096

// MARK: - FTS Extension Enum

@objc(SFSmartStoreFtsExtension)
public enum SmartStoreFtsExtension: UInt {
    case fts4 = 4
    case fts5 = 5
}

// MARK: - SmartStore

/// The primary on-device encrypted storage class. Manages soups (tables) with indexed fields.
@objc(SFSmartStore)
@objcMembers
public class SmartStore: NSObject {

    // MARK: - Static State

    private static var allSharedStores: [String: [String: SmartStore]] = [:]
    private static var allGlobalSharedStores: [String: SmartStore] = [:]
    private static var _encryptionKeyGenerator: EncryptionKeyGenerator?
    private static var _encryptionSaltBlock: EncryptionSaltBlock?
    private static var _jsonSerializationCheckEnabled: Bool = false
    private static var _postRawJsonOnError: Bool = false
    private static var _licenseKey: String?
    private static let storeLock = NSRecursiveLock()

    // MARK: - Static Initialization

    private static let initializeOnce: Void = {
        if _encryptionKeyGenerator == nil {
            _encryptionKeyGenerator = {
                do {
                    let symmetricKey = try KeyGenerator.encryptionKey(for: SmartStoreEncryptionKeyLabel)
                    let key: Data = symmetricKey.withUnsafeBytes { Data($0) }
                    return key
                } catch {
                    SmartStoreLogger.e(SmartStore.self, message: "Error getting encryption key: \(error.localizedDescription)")
                    return nil
                }
            }
        }

        if _encryptionSaltBlock == nil {
            _encryptionSaltBlock = {
                var salt: String?

                let existingSalt = KeychainHelper.read(service: SmartStoreEncryptionSaltLabel, account: nil).data
                if let existingSalt = existingSalt {
                    salt = (existingSalt as NSData).sfsdk_newHexStringFromBytes()
                } else if SFSDKDatasharingHelper.sharedInstance.appGroupEnabled {
                    let emptyData = Data(count: Int(kSFSmartStoreEncryptionSaltLength))
                    guard let saltData = (emptyData as NSData).sfsdk_randomData(ofLength: Int(kSFSmartStoreEncryptionSaltLength)) as Data? else { return nil }
                    let result = KeychainHelper.write(service: SmartStoreEncryptionSaltLabel, data: saltData, account: nil)
                    if result.success {
                        salt = (saltData as NSData).sfsdk_newHexStringFromBytes()
                    } else {
                        SmartStoreLogger.e(SmartStore.self, message: "Error writing salt to keychain: \(result.error?.localizedDescription ?? "unknown")")
                    }
                }
                return salt
            }
        }
    }()

    // MARK: - Instance Properties

    /// The name of this store.
    @objc(storeName)
    public private(set) var name: String

    /// Full path to the store database.
    @objc(storePath)
    public var path: String? {
        if name.isEmpty { return nil }
        return dbMgr.fullDbFilePath(forStoreName: name)
    }

    /// User for this store - nil for global stores.
    @objc(user)
    public var userAccount: UserAccount?

    /// Flag to cause explain plan to be captured for every query.
    @objc(captureExplainQueryPlan)
    public var capturesExplainQueryPlan: Bool = false

    /// Dictionary with results of last explain query plan.
    public var lastExplainQueryPlan: [String: Any]?

    /// FTS extension in use (FTS4 or FTS5).
    var ftsExtension: SmartStoreFtsExtension = .fts5

    /// Whether this is a global store.
    var isGlobal: Bool = false

    /// Database queue for serialized access.
    var storeQueue: FMDatabaseQueue?

    /// Database manager.
    var dbMgr: SmartStoreDatabaseManager

    // MARK: - Private Instance Properties

    private var dataProtectionKnownAvailable: Bool = false
    private var dataProtectAvailObserverToken: NSObjectProtocol?
    private var dataProtectUnavailObserverToken: NSObjectProtocol?

    private var soupNameToTableName = NSCache<NSString, NSString>()
    private var indexSpecsBySoup = NSCache<NSString, NSMutableArray>()
    private var smartSqlToSql: SmartSqlCache

    // MARK: - Class Properties

    /// All of the store names for the current user from this app.
    public class var allStoreNames: [String] {
        storeLock.lock()
        defer { storeLock.unlock() }
        return SmartStoreDatabaseManager.shared(forUser: UserAccountManager.shared.currentUserAccount)?.allStoreNames() ?? []
    }

    /// All of the global store names from this app.
    public class var allGlobalStoreNames: [String] {
        storeLock.lock()
        defer { storeLock.unlock() }
        return SmartStoreDatabaseManager.sharedGlobal().allStoreNames() ?? []
    }

    /// Block used to generate the encryption key.
    public class var encryptionKeyGenerator: EncryptionKeyGenerator? {
        return _encryptionKeyGenerator
    }

    /// Block used to generate the salt.
    public class var encryptionSaltBlock: EncryptionSaltBlock? {
        return _encryptionSaltBlock
    }

    /// Experimental flag to do additional checks when reading back soup entries.
    public class var jsonSerializationCheckEnabled: Bool {
        get { return _jsonSerializationCheckEnabled }
        set { _jsonSerializationCheckEnabled = newValue }
    }

    // MARK: - Initialization

    init?(name: String, user: UserAccount?, isGlobal: Bool = false) {
        _ = SmartStore.initializeOnce

        if user == nil && !isGlobal {
            SmartStoreLogger.w(SmartStore.self, message: "Cannot create SmartStore with name '\(name)': user is not configured, and isGlobal is not configured. Did you mean to call sharedGlobal(withName:)?")
            return nil
        }

        SmartStoreLogger.d(SmartStore.self, message: "initWithName: \(name), user: \(SmartStoreUtils.userKey(forUser: user) ?? "nil"), isGlobal: \(isGlobal)")

        self.name = name
        self.isGlobal = isGlobal
        self.userAccount = user

        if isGlobal {
            self.dbMgr = SmartStoreDatabaseManager.sharedGlobal()
            SFSDKAppFeatureMarkers.registerAppFeature(kSFAppFeatureSmartStoreGlobal)
        } else {
            self.dbMgr = SmartStoreDatabaseManager.shared(forUser: user) ?? SmartStoreDatabaseManager.sharedGlobal()
            SFSDKAppFeatureMarkers.registerAppFeature(kSFAppFeatureSmartStoreUser)
        }

        self.soupNameToTableName.countLimit = CACHES_COUNT_LIMIT
        self.indexSpecsBySoup.countLimit = CACHES_COUNT_LIMIT
        self.smartSqlToSql = SmartSqlCache(countLimit: CACHES_COUNT_LIMIT)

        super.init()

        // Setup listening for data protection available / unavailable
        dataProtectionKnownAvailable = false

        dataProtectAvailObserverToken = NotificationCenter.default.addObserver(
            forName: UIApplication.protectedDataDidBecomeAvailableNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            SmartStoreLogger.d(SmartStore.self, message: "SFSmartStore UIApplicationProtectedDataDidBecomeAvailable")
            self?.dataProtectionKnownAvailable = true
        }

        dataProtectUnavailObserverToken = NotificationCenter.default.addObserver(
            forName: UIApplication.protectedDataWillBecomeUnavailableNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            SmartStoreLogger.d(SmartStore.self, message: "SFSmartStore UIApplicationProtectedDataWillBecomeUnavailable")
            self?.dataProtectionKnownAvailable = false
        }

        if !dbMgr.persistentStoreExists(name) {
            if !firstTimeStoreDatabaseSetup() {
                return nil
            }
        } else {
            if !subsequentTimesStoreDatabaseSetup() {
                // If it couldn't be opened, it gets deleted
                // So we should try to set a new one up
                if !firstTimeStoreDatabaseSetup() {
                    return nil
                }
            }
        }
    }

    deinit {
        SmartStoreLogger.d(SmartStore.self, message: "dealloc store: '\(name)'")
        storeQueue?.close()

        if let token = dataProtectAvailObserverToken {
            NotificationCenter.default.removeObserver(token)
        }
        if let token = dataProtectUnavailObserverToken {
            NotificationCenter.default.removeObserver(token)
        }
    }

    // MARK: - Database Setup

    private func firstTimeStoreDatabaseSetup() -> Bool {
        var result = dbMgr.createStoreDir(name)
        result = result && openStoreDatabase() && createMetaTables()

        if result {
            storeQueue?.close()
            storeQueue = nil
            result = dbMgr.protectStoreDirIfNeeded(name, protection: .completeUntilFirstUserAuthentication)
        }

        result = result && openStoreDatabase()

        if !result {
            SmartStoreLogger.e(SmartStore.self, message: "Deleting store dir since we can't set it up properly: \(name)")
            dbMgr.removeStoreDir(name)
        }
        return result
    }

    private func subsequentTimesStoreDatabaseSetup() -> Bool {
        var result = dbMgr.protectStoreDirIfNeeded(name, protection: .completeUntilFirstUserAuthentication)
        result = result && openStoreDatabase()

        if !result {
            SmartStoreLogger.e(SmartStore.self, message: "Deleting store dir since we can't open it anymore: \(name)")
            dbMgr.removeStoreDir(name)
        }

        if result {
            try createLongOperationsStatusTable()
            resumeLongOperations()
            upgradeRenameTableSoupNamesToSoupAttrs()
        }

        return result
    }

    @discardableResult
    func openStoreDatabase() -> Bool {
        let salt = SmartStore._encryptionSaltBlock?()
        do {
            storeQueue = try dbMgr.openStoreQueue(withName: name, key: SmartStore.encKey() ?? "", salt: salt)
        } catch {
            SmartStoreLogger.e(SmartStore.self, message: "Error opening store '\(name)': \(error.localizedDescription)")
            storeQueue = nil
        }
        return storeQueue != nil
    }

    // MARK: - Shared Store Methods

    /// Returns a shared store instance with a particular name for the current user.
    @objc(sharedStoreWithName:)
    public class func shared(withName storeName: String) -> SmartStore? {
        storeLock.lock()
        defer { storeLock.unlock() }
        return shared(withName: storeName, forUserAccount: UserAccountManager.shared.currentUserAccount)
    }

    /// Returns a shared store instance with the given name for the given user.
    @objc(sharedStoreWithName:user:)
    public class func shared(withName storeName: String, forUserAccount user: UserAccount?) -> SmartStore? {
        storeLock.lock()
        defer { storeLock.unlock() }

        guard let user = user else {
            SmartStoreLogger.w(SmartStore.self, message: "Cannot create shared store with name '\(storeName)' for nil user. Did you mean to call sharedGlobal(withName:)?")
            return nil
        }

        guard let userKey = SmartStoreUtils.userKey(forUser: user) else {
            return nil
        }

        if allSharedStores[userKey] == nil {
            allSharedStores[userKey] = [:]
        }

        if let store = allSharedStores[userKey]?[storeName] {
            return store
        }

        if user.loginState != .loggedIn {
            SmartStoreLogger.w(SmartStore.self, message: "A user account must be in the UserAccountLoginStateLoggedIn state in order to create a store.")
            return nil
        }

        let store = SmartStore(name: storeName, user: user)
        if let store = store {
            allSharedStores[userKey]?[storeName] = store
        }

        let numUserStores = allSharedStores[userKey]?.count ?? 0
        SFSDKEventBuilderHelper.createAndStoreEvent("userSmartStoreInit", userAccount: user, className: NSStringFromClass(SmartStore.self), attributes: ["numUserStores": NSNumber(value: numUserStores)])

        return store
    }

    /// Returns a shared global store instance with the given name.
    @objc(sharedGlobalStoreWithName:)
    public class func sharedGlobal(withName storeName: String) -> SmartStore {
        storeLock.lock()
        defer { storeLock.unlock() }

        if let store = allGlobalSharedStores[storeName] {
            return store
        }

        let store = SmartStore(name: storeName, user: nil, isGlobal: true)
        if let store = store {
            allGlobalSharedStores[storeName] = store
        }

        let numGlobalStores = allGlobalSharedStores.count
        SFSDKEventBuilderHelper.createAndStoreEvent("globalSmartStoreInit", userAccount: nil, className: NSStringFromClass(SmartStore.self), attributes: ["numGlobalStores": NSNumber(value: numGlobalStores)])

        // Force unwrap safe: store created with isGlobal=true always succeeds unless db setup fails
        return store ?? SmartStore(name: storeName, user: nil, isGlobal: true)!
    }

    /// Removes a persistent shared store with the given name for the current user.
    @objc(removeSharedStoreWithName:)
    public class func removeShared(withName storeName: String) {
        storeLock.lock()
        defer { storeLock.unlock() }
        removeShared(withName: storeName, forUserAccount: UserAccountManager.shared.currentUserAccount)
    }

    /// Removes a persisted shared store with the given name for the given user.
    @objc(removeSharedStoreWithName:forUser:)
    public class func removeShared(withName storeName: String, forUserAccount user: UserAccount?) {
        storeLock.lock()
        defer { storeLock.unlock() }

        guard let user = user else {
            SmartStoreLogger.i(SmartStore.self, message: "Cannot remove store with name '\(storeName)' for nil user. Did you mean to call removeSharedGlobal(withName:)?")
            return
        }

        SmartStoreLogger.d(SmartStore.self, message: "removeSharedStoreWithName: \(storeName), user: \(user)")
        guard let userKey = SmartStoreUtils.userKey(forUser: user) else { return }

        if let existingStore = allSharedStores[userKey]?[storeName] {
            existingStore.storeQueue?.close()
            allSharedStores[userKey]?.removeValue(forKey: storeName)
        }
        SmartStoreDatabaseManager.shared(forUser: user)?.removeStoreDir(storeName)
    }

    /// Removes a persisted global store with the given name.
    @objc(removeSharedGlobalStoreWithName:)
    public class func removeSharedGlobal(withName storeName: String) {
        storeLock.lock()
        defer { storeLock.unlock() }

        SmartStoreLogger.d(SmartStore.self, message: "removeSharedGlobalStoreWithName: \(storeName)")
        if let existingStore = allGlobalSharedStores[storeName] {
            existingStore.storeQueue?.close()
            allGlobalSharedStores.removeValue(forKey: storeName)
        }
        SmartStoreDatabaseManager.sharedGlobal().removeStoreDir(storeName)
    }

    /// Removes all of the stores for the current user from this app.
    @objc(removeAllStores)
    public class func removeAllForCurrentUser() {
        storeLock.lock()
        defer { storeLock.unlock() }
        removeAll(forUserAccount: UserAccountManager.shared.currentUserAccount)
    }

    /// Removes all of the stores for the given user from this app.
    @objc(removeAllStoresForUser:)
    public class func removeAll(forUserAccount user: UserAccount?) {
        storeLock.lock()
        defer { storeLock.unlock() }

        guard let user = user else {
            SmartStoreLogger.i(SmartStore.self, message: "Cannot remove all stores for nil user. Did you mean to call removeAllGlobal()?")
            return
        }

        if let mgr = SmartStoreDatabaseManager.shared(forUser: user) {
            let storeNames = mgr.allStoreNames() ?? []
            for storeName in storeNames {
                removeShared(withName: storeName, forUserAccount: user)
            }
            SmartStoreDatabaseManager.removeSharedManager(forUser: user)
        }
    }

    /// Removes all of the global stores from this app.
    @objc(removeAllGlobalStores)
    public class func removeAllGlobal() {
        storeLock.lock()
        defer { storeLock.unlock() }

        let storeNames = SmartStoreDatabaseManager.sharedGlobal().allStoreNames() ?? []
        for storeName in storeNames {
            removeSharedGlobal(withName: storeName)
        }
    }

    /// Clears all shared store objects from memory (persisted stores remain). FOR UNIT TESTING.
    class func clearSharedStoreMemoryState() {
        storeLock.lock()
        defer { storeLock.unlock() }
        allSharedStores.removeAll()
        allGlobalSharedStores.removeAll()
    }

    // MARK: - Encryption

    /// Sets a custom block for deriving the encryption key used to encrypt stores.
    @objc
    public class func setEncryptionKeyGenerator(_ newEncryptionKeyGenerator: @escaping EncryptionKeyGenerator) {
        _encryptionKeyGenerator = newEncryptionKeyGenerator
    }

    /// Sets a custom block for deriving the salt.
    class func setEncryptionSaltBlock(_ newEncryptionSaltBlock: @escaping EncryptionSaltBlock) {
        _encryptionSaltBlock = newEncryptionSaltBlock
    }

    class func encKey() -> String? {
        guard let generator = _encryptionKeyGenerator, let key = generator() else { return nil }
        return key.base64EncodedString()
    }

    class func salt() -> String? {
        return _encryptionSaltBlock?()
    }

    /// Set license key for SQLCipher.
    @objc
    public class func setLicenseKey(_ licenseKey: String) {
        _licenseKey = licenseKey
    }

    class var licenseKey: String? {
        return _licenseKey
    }

    // MARK: - Meta Tables

    @discardableResult
    private func createMetaTables() -> Bool {
        var error: NSError?
        inDatabase({ db in
            try self.createMetaTables(with: db)
        }, error: &error)
        return error == nil
    }

    private func createMetaTables(with db: FMDatabase) throws {
        let createSoupIndexTableSql = "CREATE TABLE IF NOT EXISTS \(SOUP_INDEX_MAP_TABLE) (\(SOUP_NAME_COL) TEXT, \(PATH_COL) TEXT, \(COLUMN_NAME_COL) TEXT, \(COLUMN_TYPE_COL) TEXT )"
        SmartStoreLogger.d(SmartStore.self, message: "createSoupIndexTableSql: \(createSoupIndexTableSql)")

        let createSoupNamesTableSql = "CREATE TABLE IF NOT EXISTS \(SOUP_ATTRS_TABLE) (\(SmartStoreIdColumn) INTEGER PRIMARY KEY AUTOINCREMENT, \(SOUP_NAME_COL) TEXT )"
        SmartStoreLogger.d(SmartStore.self, message: "createSoupNamesTableSql: \(createSoupNamesTableSql)")

        let createSoupNamesIndexSql = "CREATE INDEX \(SOUP_ATTRS_TABLE)_0 on \(SOUP_ATTRS_TABLE) ( \(SOUP_NAME_COL) )"
        SmartStoreLogger.d(SmartStore.self, message: "createSoupNamesIndexSql: \(createSoupNamesIndexSql)")

        try executeUpdateThrows(createSoupIndexTableSql, with: db)
        try executeUpdateThrows(createSoupNamesTableSql, with: db)
        try createLongOperationsStatusTable(with: db)
        try executeUpdateThrows(createSoupNamesIndexSql, with: db)
    }

    @discardableResult
    private func createLongOperationsStatusTable() -> Bool {
        var error: NSError?
        inDatabase({ db in
            try self.createLongOperationsStatusTable(with: db)
        }, error: &error)
        return error == nil
    }

    private func createLongOperationsStatusTable(with db: FMDatabase) throws {
        let sql = "CREATE TABLE IF NOT EXISTS \(LONG_OPERATIONS_STATUS_TABLE) (\(SmartStoreIdColumn) INTEGER PRIMARY KEY AUTOINCREMENT, \(TYPE_COL) TEXT, \(DETAILS_COL) TEXT, \(STATUS_COL) TEXT, \(SmartStoreCreatedColumn) INTEGER, \(SmartStoreLastModifiedColumn) INTEGER )"
        SmartStoreLogger.d(SmartStore.self, message: "createLongOperationsStatusTableSql: \(sql)")
        try executeUpdateThrows(sql, with: db)
    }

    // MARK: - Long Operations Recovery

    /// Complete long operations that were interrupted.
    @objc
    public func resumeLongOperations() {
        let longOperations = getLongOperations()
        for operation in longOperations {
            operation.run()
        }
    }

    func getLongOperations() -> [AlterSoupLongOperation] {
        var results: [AlterSoupLongOperation] = []
        inDatabase({ db in
            results = self.getLongOperations(with: db)
        }, error: nil)
        return results
    }

    private func getLongOperations(with db: FMDatabase) -> [AlterSoupLongOperation] {
        var longOperations: [AlterSoupLongOperation] = []

        let frs = queryTable(LONG_OPERATIONS_STATUS_TABLE, forColumns: [SmartStoreIdColumn, DETAILS_COL, STATUS_COL], orderBy: nil, limit: nil, whereClause: nil, whereArgs: nil, with: db)

        while frs?.next() == true {
            guard let frs = frs else { break }
            let rowId = frs.long(forColumn: SmartStoreIdColumn)
            let detailsString = frs.string(forColumn: DETAILS_COL) ?? "{}"
            let details = SFJsonUtils.object(fromJSONString: detailsString) as? [String: Any] ?? [:]
            let status = AlterSoupStep(rawValue: UInt(frs.int(forColumn: STATUS_COL))) ?? .renameOldSoupTable
            let longOperation = AlterSoupLongOperation(store: self, rowId: Int(rowId), details: details, status: status)
            longOperations.append(longOperation)
        }
        frs?.close()

        return longOperations
    }

    // MARK: - DB Helper Methods

    func executeQueryThrows(_ sql: String, with db: FMDatabase) throws -> FMResultSet? {
        guard let result = db.executeQuery(sql, withArgumentsIn: []) else {
            throw smartStoreError(message: "executeQuery [\(sql)] failed", db: db)
        }
        return result
    }

    func executeQueryThrows(_ sql: String, withArgumentsIn arguments: [Any]?, with db: FMDatabase) throws -> FMResultSet? {
        if capturesExplainQueryPlan {
            let explainSql = "EXPLAIN QUERY PLAN \(sql)"
            var lastPlan: [String: Any] = [:]
            lastPlan[EXPLAIN_SQL] = explainSql
            if let args = arguments, !args.isEmpty {
                lastPlan[EXPLAIN_ARGS] = args
            }
            var explainRows: [[String: Any]] = []

            if let frs = db.executeQuery(explainSql, withArgumentsIn: arguments ?? []) {
                while frs.next() {
                    var explainRow: [String: Any] = [:]
                    for i in 0..<frs.columnCount {
                        let colName = frs.columnName(for: i) ?? "\(i)"
                        explainRow[colName] = frs.string(forColumnIndex: i) ?? ""
                    }
                    explainRows.append(explainRow)
                }
                frs.close()
            }
            lastPlan[EXPLAIN_ROWS] = explainRows
            self.lastExplainQueryPlan = lastPlan
        }

        guard let result = db.executeQuery(sql, withArgumentsIn: arguments ?? []) else {
            throw smartStoreError(message: "executeQuery [\(sql)] failed", db: db)
        }
        return result
    }

    func executeUpdateThrows(_ sql: String, with db: FMDatabase) throws {
        if !db.executeUpdate(sql, withArgumentsIn: []) {
            throw smartStoreError(message: "executeUpdate [\(sql)] failed", db: db)
        }
    }

    func executeUpdateThrows(_ sql: String, withArgumentsIn arguments: [Any]?, with db: FMDatabase) throws {
        if !db.executeUpdate(sql, withArgumentsIn: arguments ?? []) {
            throw smartStoreError(message: "executeUpdate [\(sql)] failed", db: db)
        }
    }

    private func smartStoreError(message: String, db: FMDatabase) -> NSError {
        let reason = db.lastErrorMessage()
        SmartStoreLogger.e(SmartStore.self, message: "\(message): \(reason)")
        return NSError(domain: SmartStoreErrorDomain, code: kSFSmartStoreOtherErrorCode,
                       userInfo: [NSLocalizedDescriptionKey: "\(message): \(reason)"])
    }

    @discardableResult
    func inDatabase(_ block: @escaping (FMDatabase) throws -> Void, error: inout NSError?) -> Bool {
        var success = true
        storeQueue?.inDatabase { db in
            do {
                try block(db)
            } catch let caughtError as NSError {
                error = caughtError
                success = false
            } catch let otherError {
                error = NSError(domain: SmartStoreErrorDomain, code: kSFSmartStoreOtherErrorCode, userInfo: [NSLocalizedDescriptionKey: "\(otherError)"])
                success = false
            }
        }
        return success
    }

    // Overload accepting optional error pointer (matches ObjC pattern)
    @discardableResult
    func inDatabase(_ block: @escaping (FMDatabase) throws -> Void, error: UnsafeMutablePointer<NSError?>?) -> Bool {
        var success = true
        storeQueue?.inDatabase { db in
            do {
                try block(db)
            } catch let caughtError as NSError {
                if let errorPtr = error {
                    errorPtr.pointee = caughtError
                }
                success = false
            } catch let otherError {
                if let errorPtr = error {
                    errorPtr.pointee = NSError(domain: SmartStoreErrorDomain, code: kSFSmartStoreOtherErrorCode, userInfo: [NSLocalizedDescriptionKey: "\(otherError)"])
                }
                success = false
            }
        }
        return success
    }

    @discardableResult
    func inTransaction(_ block: @escaping (FMDatabase, UnsafeMutablePointer<ObjCBool>) throws -> Void, error: UnsafeMutablePointer<NSError?>?) -> Bool {
        var success = true
        storeQueue?.inTransaction { db, rollback in
            do {
                try block(db, rollback)
            } catch let caughtError as NSError {
                rollback.pointee = true
                if let errorPtr = error {
                    errorPtr.pointee = caughtError
                }
                success = false
            } catch let otherError {
                rollback.pointee = true
                if let errorPtr = error {
                    errorPtr.pointee = NSError(domain: SmartStoreErrorDomain, code: kSFSmartStoreOtherErrorCode, userInfo: [NSLocalizedDescriptionKey: "\(otherError)"])
                }
                success = false
            }
        }
        return success
    }

    // MARK: - Utility Methods

    /// Return all soup names.
    @objc
    public func allSoupNames() -> [String] {
        var result: [String] = []
        inDatabase({ db in
            result = try self.allSoupNames(with: db)
        }, error: nil)
        return result
    }

    func allSoupNames(with db: FMDatabase) throws -> [String] {
        var soupNames: [String] = []
        let frs = try executeQueryThrows("SELECT \(SOUP_NAME_COL) FROM \(SOUP_ATTRS_TABLE)", with: db)
        while frs?.next() == true {
            if let name = frs?.string(forColumnIndex: 0) {
                soupNames.append(name)
            }
        }
        frs?.close()
        return soupNames
    }

    func currentTimeInMilliseconds() -> NSNumber {
        let rawTime = floor(1000.0 * Date().timeIntervalSince1970)
        return NSNumber(value: rawTime)
    }

    /// Creates a date object from the last modified date column value.
    @objc(dateFromLastModifiedValue:)
    public class func date(lastModifiedValue: NSNumber) -> Date {
        let lastModifiedSecs = lastModifiedValue.doubleValue / 1000.0
        return Date(timeIntervalSince1970: lastModifiedSecs)
    }

    /// Returns true if file data protection is active.
    @objc
    public func isFileDataProtectionActive() -> Bool {
        return dataProtectionKnownAvailable
    }

    /// Return database file size.
    @objc(getDatabaseSize)
    public func databaseSize() -> UInt64 {
        guard let dbPath = dbMgr.fullDbFilePath(forStoreName: name) else { return 0 }
        let attrs = try? FileManager.default.attributesOfItem(atPath: dbPath)
        return attrs?[.size] as? UInt64 ?? 0
    }

    // MARK: - JSON Checking

    func checkRawJson(_ rawJson: String, fromMethod: String) -> Bool {
        if SmartStore._jsonSerializationCheckEnabled && SFJsonUtils.object(fromJSONString: rawJson) == nil {
            SmartStoreLogger.e(SmartStore.self, message: "Error parsing JSON in SmartStore in \(fromMethod)")
            SmartStore.buildEventOnJsonParseError(forUser: userAccount, fromMethod: fromMethod, rawJson: rawJson)
            return false
        }
        return true
    }

    private class func buildEventOnJsonParseError(forUser user: UserAccount?, fromMethod: String, rawJson: String) {
        var attributes: [String: Any] = [:]
        attributes["errorCode"] = NSNumber(value: SFJsonUtils.lastError()?.code ?? 0)
        attributes["errorMessage"] = SFJsonUtils.lastError()?.localizedDescription ?? ""
        attributes["fromMethod"] = fromMethod
        SFSDKEventBuilderHelper.createAndStoreEvent("SmartStoreJSONParseError", userAccount: user, className: NSStringFromClass(SmartStore.self), attributes: attributes)

        var info = attributes
        if _postRawJsonOnError { info["rawJson"] = rawJson }
        NotificationCenter.default.post(name: Notification.Name(SmartStoreJSONParseErrorNotification), object: SmartStore.self, userInfo: info)
    }

    private class func buildEventOnJsonSerializationError(forUser user: UserAccount?, fromMethod: String, error: Error) {
        var attributes: [String: Any] = [:]
        attributes["errorCode"] = NSNumber(value: (error as NSError).code)
        attributes["errorMessage"] = error.localizedDescription
        attributes["fromMethod"] = fromMethod
        SFSDKEventBuilderHelper.createAndStoreEvent("SmartStoreJSONSerializationError", userAccount: user, className: NSStringFromClass(SmartStore.self), attributes: attributes)

        NotificationCenter.default.post(name: Notification.Name(SmartStoreJSONParseErrorNotification), object: SmartStore.self, userInfo: attributes)
    }

    class func stringFromInputStream(_ inputStream: InputStream) -> String? {
        var buffer = [UInt8](repeating: 0, count: kBufferSize)
        var content = Data()
        inputStream.open()
        while true {
            let len = inputStream.read(&buffer, maxLength: kBufferSize)
            if len <= 0 { break }
            content.append(buffer, count: len)
        }
        inputStream.close()
        return String(data: content, encoding: .utf8)
    }

    // MARK: - Data Access Utility Methods

    func insertIntoTable(_ tableName: String, values map: [String: Any], with db: FMDatabase) throws {
        var fieldNames = ""
        var fieldValueMarkers = ""
        var binds: [Any] = []
        var fieldCount = 0

        for (key, value) in map {
            if fieldCount > 0 {
                fieldNames += ",\(key)"
                fieldValueMarkers += ",?"
            } else {
                fieldNames += key
                fieldValueMarkers += "?"
            }
            binds.append(value)
            fieldCount += 1
        }

        let insertSql = "INSERT INTO \(tableName) (\(fieldNames)) VALUES (\(fieldValueMarkers))"
        try executeUpdateThrows(insertSql, withArgumentsIn: binds, with: db)
    }

    func updateTable(_ tableName: String, values map: [String: Any], entryId: NSNumber, idCol: String, with db: FMDatabase) throws {
        assert(entryId.intValue != 0 || idCol == SmartStoreIdColumn, "Entry ID must have a value.")

        var fieldEntries = ""
        var binds: [Any] = []
        var fieldCount = 0

        for (key, value) in map {
            if fieldCount > 0 {
                fieldEntries += ", "
            }
            fieldEntries += "\(key) = ?"
            binds.append(value)
            fieldCount += 1
        }
        binds.append(entryId)

        let updateSql = "UPDATE \(tableName) SET \(fieldEntries) WHERE \(idCol) = ?"
        try executeUpdateThrows(updateSql, withArgumentsIn: binds, with: db)
    }

    func columnName(forPath path: String, inSoup soupName: String, with db: FMDatabase) throws -> String? {
        var result: String?
        let indexSpecs = try indices(forSoup: soupName, with: db)
        for indexSpec in indexSpecs {
            if indexSpec.path == path {
                result = indexSpec.columnName
            }
        }

        if result == nil {
            SmartStoreLogger.d(SmartStore.self, message: "Unknown index path '\(path)' in soup '\(soupName)' ")
        }
        return result
    }

    func hasIndex(forPath path: String, inSoup soupName: String, with db: FMDatabase) throws -> Bool {
        let indexSpecs = try indices(forSoup: soupName, with: db)
        for indexSpec in indexSpecs {
            if indexSpec.path == path {
                return true
            }
        }
        return false
    }

    func convertSmartSql(_ smartSql: String) -> String? {
        var result: String?
        inDatabase({ db in
            result = self.convertSmartSql(smartSql, with: db)
        }, error: nil)
        return result
    }

    func convertSmartSql(_ smartSql: String, with db: FMDatabase) -> String? {
        SmartStoreLogger.v(SmartStore.self, message: "convertSmartSql:\(smartSql)")
        if let cachedSql = smartSqlToSql.sql(forSmartSql: smartSql) {
            if cachedSql == "null" {
                SmartStoreLogger.v(SmartStore.self, message: "convertSmartSql:found NULL in cache")
                return nil
            }
            return cachedSql
        }

        let sql = SmartSqlHelper.shared.convertSmartSql(smartSql, with: self, db: db)

        if sql == nil {
            SmartStoreLogger.v(SmartStore.self, message: "convertSmartSql:putting NULL in cache")
            smartSqlToSql.setSql("null", forSmartSql: smartSql)
        } else {
            SmartStoreLogger.v(SmartStore.self, message: "convertSmartSql:putting \(sql ?? "") in cache")
            smartSqlToSql.setSql(sql ?? "", forSmartSql: smartSql)
        }

        return sql
    }

    @objc(queryTable:forColumns:orderBy:limit:whereClause:whereArgs:withDb:)
    func queryTable(_ table: String, forColumns columns: [String]?, orderBy: String?, limit: String?, whereClause: String?, whereArgs: [Any]?, with db: FMDatabase) -> FMResultSet? {
        var columnsStr = columns?.joined(separator: ",") ?? ""
        if columnsStr.isEmpty { columnsStr = "*" }

        let orderByStr = orderBy != nil ? "ORDER BY \(orderBy ?? "")" : ""
        let selectionStr = whereClause != nil ? "WHERE \(whereClause ?? "")" : ""
        let limitStr = limit != nil ? "LIMIT \(limit ?? "")" : ""

        let sql = "SELECT \(columnsStr) FROM \(table) \(selectionStr) \(orderByStr) \(limitStr)"
        return try? executeQueryThrows(sql, withArgumentsIn: whereArgs, with: db)
    }

    // MARK: - Soup Manipulation Methods

    @objc(tableNameForSoup:withDb:)
    func tableNameForSoup(_ soupName: String, with db: FMDatabase) -> String? {
        if let cached = soupNameToTableName.object(forKey: soupName as NSString) {
            return cached as String
        }

        let sql = "SELECT \(SmartStoreIdColumn) FROM \(SOUP_ATTRS_TABLE) WHERE \(SOUP_NAME_COL) = ?"
        let frs = try? executeQueryThrows(sql, withArgumentsIn: [soupName], with: db)
        if frs?.next() == true {
            let colIdx = frs?.columnIndex(forName: SmartStoreIdColumn) ?? 0
            let soupId = frs?.long(forColumnIndex: colIdx) ?? 0
            let soupTableName = tableNameBySoupId(Int64(soupId))

            soupNameToTableName.setObject(soupTableName as NSString, forKey: soupName as NSString)
            frs?.close()
            return soupTableName
        } else {
            SmartStoreLogger.d(SmartStore.self, message: "No table for: '\(soupName)'")
        }
        frs?.close()
        return nil
    }

    private func tableNameBySoupId(_ soupId: Int64) -> String {
        return "TABLE_\(soupId)"
    }

    func soupIdFromTableName(_ tableName: String) -> NSNumber {
        let idStr = tableName.replacingOccurrences(of: "TABLE_", with: "")
        return NSNumber(value: Int64(idStr) ?? 0)
    }

    func tableNamesForAllSoups(with db: FMDatabase) throws -> [String] {
        var result: [String] = []
        let sql = "SELECT \(SOUP_NAME_COL) FROM \(SOUP_ATTRS_TABLE)"
        let frs = try executeQueryThrows(sql, with: db)
        while frs?.next() == true {
            if let tableName = frs?.string(forColumn: SOUP_NAME_COL) {
                result.append(tableName)
            }
        }
        frs?.close()
        return result
    }

    /// Returns indices for the given soup.
    @objc(indicesForSoup:)
    public func indices(forSoupNamed soupName: String) -> [SoupIndex] {
        var result: [SoupIndex] = []
        inDatabase({ db in
            result = try self.indices(forSoup: soupName, with: db)
        }, error: nil)
        return result
    }

    func indices(forSoup soupName: String, with db: FMDatabase) throws -> [SoupIndex] {
        if let cached = indexSpecsBySoup.object(forKey: soupName as NSString) {
            return cached as? [SoupIndex] ?? []
        }

        var result: [SoupIndex] = []
        let querySql = "SELECT \(PATH_COL),\(COLUMN_NAME_COL),\(COLUMN_TYPE_COL) FROM \(SOUP_INDEX_MAP_TABLE) WHERE \(SOUP_NAME_COL) = ?"
        SmartStoreLogger.d(SmartStore.self, message: "indices sql: \(querySql)")
        let frs = try executeQueryThrows(querySql, withArgumentsIn: [soupName], with: db)
        while frs?.next() == true {
            let path = frs?.string(forColumn: PATH_COL) ?? ""
            let columnName = frs?.string(forColumn: COLUMN_NAME_COL) ?? ""
            let type = frs?.string(forColumn: COLUMN_TYPE_COL) ?? ""
            if let spec = SoupIndex(path: path, indexType: type, columnName: columnName) {
                result.append(spec)
            }
        }
        frs?.close()

        let mutableResult = NSMutableArray(array: result)
        indexSpecsBySoup.setObject(mutableResult, forKey: soupName as NSString)

        if result.isEmpty {
            SmartStoreLogger.d(SmartStore.self, message: "no indices for '\(soupName)'")
        }
        return result
    }

    /// Returns YES if a soup with the given name already exists.
    @objc(soupExists:)
    public func soupExists(forName soupName: String) -> Bool {
        var result = false
        inDatabase({ db in
            result = self.soupExists(soupName, with: db)
        }, error: nil)
        return result
    }

    // Convenience: match Swift callers using soupExists without the forName label
    @nonobjc
    public func soupExists(_ soupName: String) -> Bool {
        return soupExists(forName: soupName)
    }

    func soupExists(_ soupName: String, with db: FMDatabase) -> Bool {
        guard let soupTableName = tableNameForSoup(soupName, with: db) else { return false }
        return db.tableExists(soupTableName)
    }

    private func insertIntoSoupIndexMap(_ soupIndexMapInserts: [[String: Any]], with db: FMDatabase) throws {
        for map in soupIndexMapInserts {
            try insertIntoTable(SOUP_INDEX_MAP_TABLE, values: map, with: db)
        }
    }

    private func registerNewSoup(withName soupName: String, with db: FMDatabase) throws -> String? {
        let soupMapValues: [String: Any] = [SOUP_NAME_COL: soupName]
        try insertIntoTable(SOUP_ATTRS_TABLE, values: soupMapValues, with: db)
        let soupTableName = tableNameBySoupId(db.lastInsertRowId)
        if soupTableName.isEmpty {
            SmartStoreLogger.d(SmartStore.self, message: "couldn't properly register soupName: '\(soupName)' ")
        }
        return soupTableName
    }

    /// Creates a new soup or confirms the existence of an existing soup.
    @objc(registerSoup:withIndexSpecs:error:)
    public func registerSoup(withName soupName: String, withIndices indexSpecs: [SoupIndex]) throws {
        var localError: NSError?
        inTransaction({ db, rollback in
            try self.registerSoup(withName: soupName, indexSpecs: indexSpecs, soupTableName: nil, with: db)
        }, error: &localError)

        if let error = localError {
            throw error
        }
    }

    func registerSoup(withName soupName: String, indexSpecs: [Any], soupTableName: String?, with db: FMDatabase) throws {
        guard !soupName.isEmpty else {
            throw NSError(domain: SmartStoreErrorDomain, code: kSFSmartStoreOtherErrorCode, userInfo: [NSLocalizedDescriptionKey: "Bogus soupName: \(soupName)"])
        }
        guard !indexSpecs.isEmpty else {
            throw NSError(domain: SmartStoreErrorDomain, code: kSFSmartStoreOtherErrorCode, userInfo: [NSLocalizedDescriptionKey: "Bogus indexSpecs"])
        }

        // If soup with same name already exists, just return
        if soupExists(soupName, with: db) {
            return
        }

        let specs: [SoupIndex] = indexSpecs.compactMap { item in
            if let idx = item as? SoupIndex { return idx }
            if let dict = item as? [String: Any] { return SoupIndex(dictionary: dict) }
            return nil
        }

        let soupUsesJSON1 = SoupIndex.hasJSON1(specs)

        var actualSoupTableName = soupTableName
        if actualSoupTableName == nil {
            actualSoupTableName = try registerNewSoup(withName: soupName, with: db)
        }
        guard let tableName = actualSoupTableName else { return }

        var soupIndexMapInserts: [[String: Any]] = []
        var createIndexStmts: [String] = []
        var createTableStmt = "CREATE TABLE IF NOT EXISTS \(tableName) ("
        createTableStmt += "\(SmartStoreIdColumn) INTEGER PRIMARY KEY AUTOINCREMENT"
        createTableStmt += ", \(SmartStoreSoupColumn) TEXT"
        createTableStmt += ", \(SmartStoreCreatedColumn) INTEGER"
        createTableStmt += ", \(SmartStoreLastModifiedColumn) INTEGER"

        var columnsForFts: [String] = []

        // Indexes on created and lastModified
        let createIndexFormat = "CREATE INDEX IF NOT EXISTS %@_%@_idx ON %@ ( %@ )"
        for col in [SmartStoreCreatedColumn, SmartStoreLastModifiedColumn] {
            createIndexStmts.append(String(format: createIndexFormat, tableName, col, tableName, col))
        }

        for i in 0..<specs.count {
            let indexSpec = specs[i]

            var columnName = "\(tableName)_\(i)"
            if kValueIndexedWithJSONExtract(indexSpec) {
                columnName = "json_extract(soup, '$.\(indexSpec.path)')"
            }
            if kValueExtractedToColumn(indexSpec) {
                if let columnType = indexSpec.columnType {
                    createTableStmt += ", \(columnName) \(columnType) "
                }
            }

            // for fts
            if indexSpec.indexType == kSoupIndexTypeFullText {
                columnsForFts.append(columnName)
            }

            // for inserting into meta mapping table
            var values: [String: Any] = [:]
            values[SOUP_NAME_COL] = soupName
            values[PATH_COL] = indexSpec.path
            values[COLUMN_NAME_COL] = columnName
            values[COLUMN_TYPE_COL] = indexSpec.indexType
            soupIndexMapInserts.append(values)

            // for creating an index on the soup table
            createIndexStmts.append(String(format: createIndexFormat, tableName, "\(i)", tableName, columnName))
        }

        createTableStmt += ")"
        SmartStoreLogger.d(SmartStore.self, message: "createTableStmt: \(createTableStmt)")

        // fts
        var createFtsStmt = ""
        if !columnsForFts.isEmpty {
            createFtsStmt = "CREATE VIRTUAL TABLE \(tableName)_fts USING fts\(ftsExtension.rawValue)(\(columnsForFts.joined(separator: ",")))"
            SmartStoreLogger.d(SmartStore.self, message: "createFtsStmt: \(createFtsStmt)")
        }

        // create the main soup table
        try executeUpdateThrows(createTableStmt, with: db)

        // fts
        if !columnsForFts.isEmpty {
            try executeUpdateThrows(createFtsStmt, with: db)
        }

        // create indices for this soup
        for createIndexStmt in createIndexStmts {
            SmartStoreLogger.d(SmartStore.self, message: "createIndexStmt: \(createIndexStmt)")
            try executeUpdateThrows(createIndexStmt, with: db)
        }
        try insertIntoSoupIndexMap(soupIndexMapInserts, with: db)

        // Log analytics event
        var features: [String] = []
        if soupUsesJSON1 { features.append("JSON1") }
        if SoupIndex.hasFts(specs) { features.append("FTS") }
        let attributes: [String: Any] = ["features": features]
        SFSDKEventBuilderHelper.createAndStoreEvent("registerSoup", userAccount: userAccount, className: NSStringFromClass(SmartStore.self), attributes: attributes)
    }

    /// Remove soup completely from the store.
    @objc
    public func removeSoup(_ soupName: String) {
        inTransaction({ db, rollback in
            try self.removeSoup(soupName, with: db)
        }, error: nil)
    }

    func removeSoup(_ soupName: String, with db: FMDatabase) throws {
        SmartStoreLogger.d(SmartStore.self, message: "removeSoup: \(soupName)")
        guard let soupTableName = tableNameForSoup(soupName, with: db) else { return }

        let dropSql = "DROP TABLE IF EXISTS \(soupTableName)"
        try executeUpdateThrows(dropSql, with: db)

        // fts
        if try hasFts(soupName, with: db) {
            let dropFtsSql = "DROP TABLE IF EXISTS \(soupTableName)_fts"
            try executeUpdateThrows(dropFtsSql, with: db)
        }

        let deleteIndexSql = "DELETE FROM \(SOUP_INDEX_MAP_TABLE) WHERE \(SOUP_NAME_COL)=\"\(soupName)\""
        try executeUpdateThrows(deleteIndexSql, with: db)
        let deleteNameSql = "DELETE FROM \(SOUP_ATTRS_TABLE) WHERE \(SOUP_NAME_COL)=\"\(soupName)\""
        try executeUpdateThrows(deleteNameSql, with: db)

        removeFromCache(soupName)
    }

    /// Remove all soups from the store.
    @objc
    public func removeAllSoups() {
        inTransaction({ db, rollback in
            try self.removeAllSoups(with: db)
        }, error: nil)
    }

    func removeFromCache(_ soupName: String) {
        indexSpecsBySoup.removeObject(forKey: soupName as NSString)
        soupNameToTableName.removeObject(forKey: soupName as NSString)
        smartSqlToSql.removeEntries(forSoup: soupName)
    }

    private func removeAllSoups(with db: FMDatabase) throws {
        let soupTableNames = try tableNamesForAllSoups(with: db)
        for soupTableName in soupTableNames {
            try removeSoup(soupTableName, with: db)
        }
    }

    // MARK: - Lookup

    /// Look up the ID for an entry in a soup.
    @objc(lookupSoupEntryIdForSoupName:forFieldPath:fieldValue:error:)
    public func lookupSoupEntryId(soupNamed soupName: String, fieldPath: String, fieldValue: String) throws -> NSNumber {
        var result: NSNumber?
        var lookupError: NSError?
        inDatabase({ db in
            guard let soupTableName = self.tableNameForSoup(soupName, with: db) else { return }
            do {
                result = try self.lookupSoupEntryId(soupName: soupName, soupTableName: soupTableName, fieldPath: fieldPath, fieldValue: fieldValue, with: db)
            } catch let error as NSError {
                lookupError = error
            }
        }, error: nil)
        if let error = lookupError { throw error }
        return result ?? NSNumber(value: 0)
    }

    private func lookupSoupEntryId(soupName: String, soupTableName: String, fieldPath: String, fieldValue: String?, with db: FMDatabase) throws -> NSNumber? {
        assert(!soupName.isEmpty, "Soup name must have a value.")
        assert(!soupTableName.isEmpty, "Soup table name must have a value.")
        assert(!fieldPath.isEmpty, "Field path must have a value.")

        guard let fieldPathColumnName = try columnName(forPath: fieldPath, inSoup: soupName, with: db) else {
            let errorDesc = String(format: kSFSmartStoreIndexNotDefinedDescription, fieldPath)
            throw NSError(domain: SmartStoreErrorDomain, code: kSFSmartStoreIndexNotDefinedCode, userInfo: [NSLocalizedDescriptionKey: errorDesc])
        }

        let whereClause: String
        let whereArgs: [Any]?
        if let fieldValue = fieldValue {
            whereClause = "\(fieldPathColumnName) = ?"
            whereArgs = [fieldValue]
        } else {
            whereClause = "\(fieldPathColumnName) IS NULL"
            whereArgs = nil
        }

        let rs = queryTable(soupTableName, forColumns: [SmartStoreIdColumn], orderBy: nil, limit: nil, whereClause: whereClause, whereArgs: whereArgs, with: db)
        var returnId: NSNumber?
        if rs?.next() == true {
            returnId = NSNumber(value: rs?.int(forColumn: SmartStoreIdColumn) ?? 0)
            if rs?.next() == true {
                // Shouldn't be more than one value; that's an error.
                let errorDesc = String(format: kSFSmartStoreTooManyEntriesDescription, fieldValue ?? "NULL", fieldPath)
                rs?.close()
                throw NSError(domain: SmartStoreErrorDomain, code: kSFSmartStoreTooManyEntriesCode, userInfo: [NSLocalizedDescriptionKey: errorDesc])
            }
        }
        rs?.close()
        return returnId
    }

    // MARK: - Query

    /// Get the number of entries that would be returned with the given query spec.
    @objc(countWithQuerySpec:error:)
    public func count(using querySpec: QuerySpec) throws -> NSNumber {
        var result: UInt = 0
        var queryError: NSError?
        inDatabase({ db in
            result = try self.count(using: querySpec, with: db)
        }, error: &queryError)
        if let error = queryError { throw error }
        return NSNumber(value: result)
    }

    func count(using querySpec: QuerySpec, with db: FMDatabase) throws -> UInt {
        SmartStoreLogger.d(SmartStore.self, message: "countWithQuerySpec: \nquerySpec:\(querySpec) \n")
        var result: UInt = 0

        guard let countSql = convertSmartSql(querySpec.countSmartSql, with: db) else {
            throw NSError(domain: SmartStoreErrorDomain, code: kSFSmartStoreOtherErrorCode, userInfo: [NSLocalizedDescriptionKey: "Invalid smart sql: \(querySpec.countSmartSql)"])
        }
        SmartStoreLogger.d(SmartStore.self, message: "countWithQuerySpec: countSql:\(countSql) \n")

        let args = querySpec.bindsForQuerySpec()
        let frs = try executeQueryThrows(countSql, withArgumentsIn: args as? [Any], with: db)
        if frs?.next() == true {
            result = UInt(frs?.int(forColumnIndex: 0) ?? 0)
        }
        frs?.close()
        return result
    }

    /// Search for entries matching the given query spec.
    @objc(queryWithQuerySpec:pageIndex:error:)
    public func query(using querySpec: QuerySpec, startingFromPageIndex pageIndex: UInt) throws -> [Any] {
        return try query(using: querySpec, startingFromPageIndex: pageIndex, whereArgs: nil)
    }

    /// Search for entries matching the given query spec with optional "where args".
    @objc(queryWithQuerySpec:pageIndex:whereArgs:error:)
    public func query(using querySpec: QuerySpec, startingFromPageIndex pageIndex: UInt, whereArgs: [Any]?) throws -> [Any] {
        if whereArgs != nil && querySpec.queryType != .smart {
            throw NSError(domain: SmartStoreErrorDomain, code: kSFSmartStoreWhereArgsNotSupportedCode, userInfo: [NSLocalizedDescriptionKey: kSFSmartStoreWhereArgsNotSupportedDescription])
        }

        var resultArray: [Any] = []
        var queryError: NSError?
        let succ = inDatabase({ db in
            resultArray = try self.runQuery(querySpec: querySpec, pageIndex: pageIndex, whereArgs: whereArgs, with: db)
        }, error: &queryError)

        if let error = queryError { throw error }
        if !succ { return [] }
        return resultArray
    }

    /// Search for entries matching the given query spec without deserializing any JSON.
    @objc(queryAsString:querySpec:pageIndex:error:)
    public func queryAsString(_ resultString: NSMutableString, querySpec: QuerySpec, pageIndex: UInt) throws {
        var queryError: NSError?
        inDatabase({ db in
            try self.runQueryAsString(resultString, querySpec: querySpec, pageIndex: pageIndex, whereArgs: nil, with: db)
        }, error: &queryError)
        if let error = queryError { throw error }
    }

    private func runQuery(querySpec: QuerySpec, pageIndex: UInt, whereArgs: [Any]?, with db: FMDatabase) throws -> [Any] {
        // Page
        let offsetRows = querySpec.pageSize * pageIndex
        let numberRows = querySpec.pageSize
        let limit = "\(offsetRows),\(numberRows)"

        // SQL
        guard let sql = convertSmartSql(querySpec.smartSql, with: db) else {
            throw NSError(domain: SmartStoreErrorDomain, code: kSFSmartStoreOtherErrorCode, userInfo: [NSLocalizedDescriptionKey: "Invalid smart sql: \(querySpec.smartSql)"])
        }
        let limitSql = "SELECT * FROM (\(sql)) LIMIT \(limit)"

        // Args
        let args: [Any]? = querySpec.queryType != .smart ? querySpec.bindsForQuerySpec() as? [Any] : whereArgs

        // Executing query
        guard let frs = try executeQueryThrows(limitSql, withArgumentsIn: args, with: db) else { return [] }
        var resultArray: [Any] = []

        while frs.next() {
            autoreleasepool {
                if querySpec.queryType == .smart || querySpec.selectPaths != nil {
                    var rowData: [Any] = []
                    getDataFromRow(&rowData, resultSet: frs)
                    if !rowData.isEmpty {
                        resultArray.append(rowData)
                    }
                } else {
                    let columnName = frs.columnName(for: 0)
                    if columnName == SmartStoreSoupColumn {
                        if let rawJson = frs.string(forColumnIndex: 0),
                           let entry = SFJsonUtils.object(fromJSONString: rawJson) {
                            resultArray.append(entry)
                        }
                    }
                }
            }
        }
        frs.close()
        return resultArray
    }

    private func runQueryAsString(_ resultString: NSMutableString, querySpec: QuerySpec, pageIndex: UInt, whereArgs: [Any]?, with db: FMDatabase) throws {
        // Page
        let offsetRows = querySpec.pageSize * pageIndex
        let numberRows = querySpec.pageSize
        let limit = "\(offsetRows),\(numberRows)"

        // SQL
        guard let sql = convertSmartSql(querySpec.smartSql, with: db) else {
            throw NSError(domain: SmartStoreErrorDomain, code: kSFSmartStoreOtherErrorCode, userInfo: [NSLocalizedDescriptionKey: "Invalid smart sql: \(querySpec.smartSql)"])
        }
        let limitSql = "SELECT * FROM (\(sql)) LIMIT \(limit)"

        // Args
        let args: [Any]? = querySpec.queryType != .smart ? querySpec.bindsForQuerySpec() as? [Any] : whereArgs

        // Executing query
        guard let frs = try executeQueryThrows(limitSql, withArgumentsIn: args, with: db) else {
            resultString.append("[]")
            return
        }
        var resultStrings: [String] = []

        while frs.next() {
            autoreleasepool {
                if querySpec.queryType == .smart || querySpec.selectPaths != nil {
                    var rowStr = ""
                    getDataFromRowAsString(&rowStr, resultSet: frs)
                    if !rowStr.isEmpty {
                        resultStrings.append(rowStr)
                    }
                } else {
                    let columnName = frs.columnName(for: 0)
                    if columnName == SmartStoreSoupColumn {
                        if let rawJson = frs.string(forColumnIndex: 0) {
                            resultStrings.append(rawJson)
                        }
                    }
                }
            }
        }
        frs.close()

        resultString.append("[")
        resultString.append(resultStrings.joined(separator: ","))
        resultString.append("]")
    }

    private func getDataFromRow(_ resultArray: inout [Any], resultSet frs: FMResultSet) {
        let valuesMap = frs.resultDictionary ?? [:]

        for i in 0..<frs.columnCount {
            autoreleasepool {
                let columnName = frs.columnName(for: i) ?? ""
                let value = valuesMap[columnName]

                let isSoupCol = (value is String) &&
                    (columnName == SmartStoreSoupColumn || columnName.hasPrefix("\(SmartStoreSoupColumn):"))

                if isSoupCol {
                    if let strVal = value as? String, let entry = SFJsonUtils.object(fromJSONString: strVal) {
                        resultArray.append(entry)
                    } else {
                        resultArray.append(NSNull())
                    }
                } else {
                    resultArray.append(value ?? NSNull())
                }
            }
        }
    }

    private func getDataFromRowAsString(_ resultString: inout String, resultSet frs: FMResultSet) {
        let valuesMap = frs.resultDictionary ?? [:]
        var resultStrings: [String] = []

        for i in 0..<frs.columnCount {
            autoreleasepool {
                let columnName = frs.columnName(for: i) ?? ""
                let value = valuesMap[columnName]

                let isSoupCol = (value is String) &&
                    (columnName == SmartStoreSoupColumn || columnName.hasPrefix("\(SmartStoreSoupColumn):"))

                if isSoupCol {
                    if let strVal = value as? String {
                        resultStrings.append(strVal)
                    } else {
                        resultStrings.append("null")
                    }
                } else {
                    if value is NSNull || value == nil {
                        resultStrings.append("null")
                    } else if let numVal = value as? NSNumber {
                        resultStrings.append(numVal.stringValue)
                    } else if let strVal = value as? String {
                        if let escaped = escapeStringValueAndQuote(strVal) {
                            resultStrings.append(escaped)
                        } else {
                            resultStrings.append("null")
                        }
                    }
                }
            }
        }

        resultString = "[\(resultStrings.joined(separator: ","))]"
    }

    private func escapeStringValueAndQuote(_ raw: String) -> String? {
        var escaped = "\""
        for c in raw.unicodeScalars {
            switch c {
            case "\\":
                escaped += "\\\\"
            case "/":
                escaped += "\\/"
            case "\"":
                escaped += "\\\""
            case "\u{08}": // backspace
                escaped += "\\b"
            case "\u{0C}": // form feed
                escaped += "\\f"
            case "\n":
                escaped += "\\n"
            case "\r":
                escaped += "\\r"
            case "\t":
                escaped += "\\t"
            default:
                if c.value < 0x20 {
                    escaped += String(format: "\\u%04x", c.value)
                } else {
                    escaped += String(c)
                }
            }
        }
        escaped += "\""

        if !checkRawJson("[\(escaped)]", fromMethod: #function) {
            return nil
        }
        return escaped
    }

    private func idsInPredicate(_ ids: [Any], idCol: String) -> String {
        let allIds = ids.map { "\($0)" }.joined(separator: ",")
        return "\(idCol) IN (\(allIds)) "
    }

    func allSoupEntryIds(_ soupTableName: String, with db: FMDatabase) -> [NSNumber] {
        var soupEntryIds: [NSNumber] = []
        let idsResultSet = queryTable(soupTableName, forColumns: [SmartStoreIdColumn], orderBy: nil, limit: nil, whereClause: nil, whereArgs: nil, with: db)
        while idsResultSet?.next() == true {
            soupEntryIds.append(NSNumber(value: idsResultSet?.long(forColumn: SmartStoreIdColumn) ?? 0))
        }
        idsResultSet?.close()
        return soupEntryIds
    }

    // MARK: - Retrieve Entries

    /// Search soup for entries exactly matching the soup entry IDs.
    @objc(retrieveEntries:fromSoup:)
    public func retrieve(usingSoupEntryIds soupEntryIds: [NSNumber], fromSoupNamed soupName: String) -> [[String: Any]] {
        var result: [[String: Any]] = []
        inDatabase({ db in
            result = try self.retrieveEntries(soupEntryIds, fromSoup: soupName, with: db)
        }, error: nil)
        return result
    }

    func retrieveEntries(_ soupEntryIds: [Any], fromSoup soupName: String, with db: FMDatabase) throws -> [[String: Any]] {
        var result: [[String: Any]] = []
        guard let soupTableName = tableNameForSoup(soupName, with: db) else {
            SmartStoreLogger.d(SmartStore.self, message: "Soup: '\(soupName)' does not exist")
            return result
        }

        let pred = idsInPredicate(soupEntryIds, idCol: SmartStoreIdColumn)
        let querySql = "SELECT \(SmartStoreSoupColumn) FROM \(soupTableName) WHERE \(pred)"
        let frs = try executeQueryThrows(querySql, with: db)
        while frs?.next() == true {
            autoreleasepool {
                if let rawJson = frs?.string(forColumn: SmartStoreSoupColumn),
                   let entry = SFJsonUtils.object(fromJSONString: rawJson) as? [String: Any] {
                    result.append(entry)
                }
            }
        }
        frs?.close()
        return result
    }

    // MARK: - Insert/Update/Upsert

    private func insertOneEntry(_ entry: [String: Any], inSoupTable soupTableName: String, indices: [SoupIndex], with db: FMDatabase) throws -> [String: Any] {
        let nowVal = currentTimeInMilliseconds()
        var newEntryId: NSNumber

        // Get next id
        let frs = try executeQueryThrows("SELECT seq FROM SQLITE_SEQUENCE WHERE name = ?", withArgumentsIn: [soupTableName], with: db)
        if frs?.next() == true {
            newEntryId = NSNumber(value: 1 + (frs?.longLongInt(forColumnIndex: 0) ?? 0))
        } else {
            newEntryId = NSNumber(value: 1)
        }
        frs?.close()

        // Clone entry and insert new SOUP_ENTRY_ID
        var mutableEntry = entry
        mutableEntry[SmartStoreSoupEntryId] = newEntryId
        mutableEntry[SmartStoreLastModifiedDate] = nowVal

        var values: [String: Any] = [
            SmartStoreCreatedColumn: nowVal,
            SmartStoreLastModifiedColumn: nowVal
        ]

        // Now update the SOUP_COL (raw json) for the soup entry
        let rawJson = SFJsonUtils.jsonRepresentation(mutableEntry)
        values[SmartStoreSoupColumn] = rawJson

        // Build up the set of index column values for this new row
        projectIndexedPaths(mutableEntry, values: &values, indices: indices, typeFilter: kValueExtractedToColumn)
        try insertIntoTable(soupTableName, values: values, with: db)

        // fts
        if SoupIndex.hasFts(indices) {
            var ftsValues: [String: Any] = [ROWID_COL: newEntryId]
            projectIndexedPaths(mutableEntry, values: &ftsValues, indices: indices, typeFilter: kValueExtractedToFtsColumn)
            try insertIntoTable("\(soupTableName)_fts", values: ftsValues, with: db)
        }

        return mutableEntry
    }

    private func updateOneEntry(_ entry: [String: Any], withEntryId entryId: NSNumber, inSoupTable soupTableName: String, indices: [SoupIndex], with db: FMDatabase) throws -> [String: Any] {
        let nowVal = currentTimeInMilliseconds()
        var values: [String: Any] = [SmartStoreLastModifiedColumn: nowVal]

        // Build up the set of index column values for this row
        projectIndexedPaths(entry, values: &values, indices: indices, typeFilter: kValueExtractedToColumn)

        // Clone entry and modify timestamps
        var mutableEntry = entry
        mutableEntry[SmartStoreLastModifiedDate] = nowVal
        mutableEntry[SmartStoreSoupEntryId] = entryId

        let rawJson = SFJsonUtils.jsonRepresentation(mutableEntry)
        values[SmartStoreSoupColumn] = rawJson

        try updateTable(soupTableName, values: values, entryId: entryId, idCol: SmartStoreIdColumn, with: db)

        // fts
        if SoupIndex.hasFts(indices) {
            var ftsValues: [String: Any] = [:]
            projectIndexedPaths(entry, values: &ftsValues, indices: indices, typeFilter: kValueExtractedToFtsColumn)
            try updateTable("\(soupTableName)_fts", values: ftsValues, entryId: entryId, idCol: ROWID_COL, with: db)
        }

        return mutableEntry
    }

    private func upsertOneEntry(_ entry: [String: Any], inSoup soupName: String, indices: [SoupIndex], externalIdPath: String?, with db: FMDatabase) throws -> [String: Any]? {
        let soupTableName = tableNameForSoup(soupName, with: db)
        guard let tableName = soupTableName else { return nil }

        var soupEntryId: NSNumber?
        if let externalIdPath = externalIdPath {
            if externalIdPath == SmartStoreSoupEntryId {
                soupEntryId = entry[SmartStoreSoupEntryId] as? NSNumber
            } else {
                guard let fieldValue = SFJsonUtils.project(intoJson: entry, path: externalIdPath) as? String else {
                    let errorDescription = String(format: kSFSmartStoreExternalIdNilDescription, externalIdPath)
                    throw NSError(domain: SmartStoreErrorDomain, code: kSFSmartStoreExternalIdNilCode, userInfo: [NSLocalizedDescriptionKey: errorDescription])
                }

                soupEntryId = try lookupSoupEntryId(soupName: soupName, soupTableName: tableName, fieldPath: externalIdPath, fieldValue: fieldValue, with: db)
            }
        }

        if let entryId = soupEntryId {
            return try updateOneEntry(entry, withEntryId: entryId, inSoupTable: tableName, indices: indices, with: db)
        } else {
            return try insertOneEntry(entry, inSoupTable: tableName, indices: indices, with: db)
        }
    }

    /// Insert/update entries to the soup using internal soup entry ID.
    @objc(upsertEntries:toSoup:)
    public func upsert(entries: [[String: Any]], forSoupNamed soupName: String) -> [[String: Any]] {
        let result = try? upsert(entries: entries as [Any], forSoupNamed: soupName, withExternalIdPath: SmartStoreSoupEntryId)
        return (result as? [[String: Any]]) ?? []
    }

    /// Insert/update entries to the soup using specified external ID path.
    @objc(upsertEntries:toSoup:withExternalIdPath:error:)
    public func upsert(entries: [Any], forSoupNamed soupName: String, withExternalIdPath externalIdPath: String) throws -> [Any] {
        var result: [Any]?
        var upsertError: NSError?
        inTransaction({ db, rollback in
            do {
                result = try self.upsertEntries(entries, toSoup: soupName, withExternalIdPath: externalIdPath, with: db)
            } catch let error as NSError {
                upsertError = error
                rollback.pointee = true
            }
        }, error: &upsertError)
        if let error = upsertError { throw error }
        return result ?? []
    }

    @objc(upsertEntries:toSoup:withExternalIdPath:error:withDb:)
    func upsertEntries(_ entries: [Any], toSoup soupName: String, withExternalIdPath externalIdPath: String?, with db: FMDatabase) throws -> [Any] {
        let localExternalIdPath = externalIdPath ?? SmartStoreSoupEntryId

        guard soupExists(soupName, with: db) else { return [] }

        let indices = try indices(forSoup: soupName, with: db)
        var result: [Any] = []

        for item in entries {
            guard let entry = item as? [String: Any] else { continue }
            let upsertedEntry = try upsertOneEntry(entry, inSoup: soupName, indices: indices, externalIdPath: localExternalIdPath, with: db)
            if let upsertedEntry = upsertedEntry {
                result.append(upsertedEntry)
            } else {
                return []
            }
        }

        return result
    }

    // MARK: - Remove Entries

    /// Remove soup entries exactly matching the soup entry IDs (convenience, no error).
    @objc(removeEntries:fromSoup:)
    public func removeEntries(_ entryIds: [Any], fromSoup soupName: String) {
        try? remove(entryIds: entryIds.compactMap { $0 as? NSNumber }, forSoupNamed: soupName)
    }

    /// Remove soup entries exactly matching the soup entry IDs.
    @objc(removeEntries:fromSoup:error:)
    public func remove(entryIds: [NSNumber], forSoupNamed soupName: String) throws {
        var removeError: NSError?
        inTransaction({ db, rollback in
            try self.removeEntries(entryIds, fromSoup: soupName, with: db)
        }, error: &removeError)
        if let error = removeError { throw error }
    }

    func removeEntries(_ soupEntryIds: [Any], fromSoup soupName: String, with db: FMDatabase) throws {
        guard soupExists(soupName, with: db) else { return }
        guard let soupTableName = tableNameForSoup(soupName, with: db) else { return }

        let deleteSql = "DELETE FROM \(soupTableName) WHERE \(idsInPredicate(soupEntryIds, idCol: SmartStoreIdColumn))"
        try executeUpdateThrows(deleteSql, with: db)

        // fts
        if try hasFts(soupName, with: db) {
            let deleteFtsSql = "DELETE FROM \(soupTableName)_fts WHERE \(idsInPredicate(soupEntryIds, idCol: ROWID_COL))"
            try executeUpdateThrows(deleteFtsSql, with: db)
        }
    }

    /// Remove soup entries returned by the given query spec.
    @objc(removeEntriesByQuery:fromSoup:error:)
    public func removeEntries(usingQuerySpec querySpec: QuerySpec, forSoupNamed soupName: String) throws {
        var removeError: NSError?
        inTransaction({ db, rollback in
            try self.removeEntriesByQuery(querySpec, fromSoup: soupName, with: db)
        }, error: &removeError)
        if let error = removeError { throw error }
    }

    func removeEntriesByQuery(_ querySpec: QuerySpec, fromSoup soupName: String, with db: FMDatabase) throws {
        guard let soupTableName = tableNameForSoup(soupName, with: db) else { return }
        guard let querySql = convertSmartSql(querySpec.idsSmartSql, with: db) else { return }
        let limitSql = "SELECT * FROM (\(querySql)) LIMIT \(querySpec.pageSize)"
        let args = querySpec.bindsForQuerySpec() as? [Any]

        let deleteSql = "DELETE FROM \(soupTableName) WHERE \(SmartStoreIdColumn) in (\(limitSql))"
        try executeUpdateThrows(deleteSql, withArgumentsIn: args, with: db)

        // fts
        if try hasFts(soupName, with: db) {
            let deleteFtsSql = "DELETE FROM \(soupTableName)_fts WHERE \(ROWID_COL) in (\(querySql))"
            try executeUpdateThrows(deleteFtsSql, with: db)
        }
    }

    /// Remove all elements from soup.
    @objc
    public func clearSoup(_ soupName: String) {
        inTransaction({ db, rollback in
            try self.clearSoup(soupName, with: db)
        }, error: nil)
    }

    func clearSoup(_ soupName: String, with db: FMDatabase) throws {
        guard soupExists(soupName, with: db) else { return }
        guard let soupTableName = tableNameForSoup(soupName, with: db) else { return }
        let deleteSql = "DELETE FROM \(soupTableName)"
        try executeUpdateThrows(deleteSql, with: db)

        // fts
        if try hasFts(soupName, with: db) {
            let deleteFtsSql = "DELETE FROM \(soupTableName)_fts"
            try executeUpdateThrows(deleteFtsSql, with: db)
        }
    }

    // MARK: - Alter/ReIndex

    /// Alter soup indexes.
    @objc(alterSoup:withIndexSpecs:reIndexData:)
    public func alterSoup(named soupName: String, indexSpecs: [SoupIndex], reIndexData: Bool) -> Bool {
        if soupExists(forName: soupName) {
            let operation = AlterSoupLongOperation(store: self, soupName: soupName, newIndexSpecs: indexSpecs, reIndexData: reIndexData)
            operation.run()
            return true
        }
        return false
    }

    /// Reindex a soup.
    @objc(reIndexSoup:withIndexPaths:)
    public func reIndexSoup(named soupName: String, indexPaths: [String]) -> Bool {
        var result = false
        inTransaction({ db, rollback in
            result = try self.reIndexSoup(soupName, withIndexPaths: indexPaths, with: db)
        }, error: nil)
        return result
    }

    func reIndexSoup(_ soupName: String, withIndexPaths indexPaths: [String], with db: FMDatabase) throws -> Bool {
        guard soupExists(soupName, with: db) else { return false }
        guard let soupTableName = tableNameForSoup(soupName, with: db) else { return false }

        let mapIndexSpecs = SoupIndex.map(forSoupIndexes: try indices(forSoup: soupName, with: db))
        var indicesToReindex: [SoupIndex] = []
        var hasFts = false

        for indexPath in indexPaths {
            if let idx = mapIndexSpecs[indexPath] {
                indicesToReindex.append(idx)
                if idx.indexType == kSoupIndexTypeFullText {
                    hasFts = true
                }
            }
        }

        let queryCols = [SmartStoreIdColumn, SmartStoreSoupColumn]
        let frs = queryTable(soupTableName, forColumns: queryCols, orderBy: nil, limit: nil, whereClause: nil, whereArgs: nil, with: db)

        while frs?.next() == true {
            try autoreleasepool {
                let entryId = NSNumber(value: frs?.long(forColumn: SmartStoreIdColumn) ?? 0)
                let soupElt = frs?.string(forColumn: SmartStoreSoupColumn) ?? ""
                guard let entry = SFJsonUtils.object(fromJSONString: soupElt) as? [String: Any] else { return }

                var values: [String: Any] = [:]
                projectIndexedPaths(entry, values: &values, indices: indicesToReindex, typeFilter: kValueExtractedToColumn)
                if !values.isEmpty {
                    try updateTable(soupTableName, values: values, entryId: entryId, idCol: SmartStoreIdColumn, with: db)
                }
                // fts
                if hasFts {
                    var ftsValues: [String: Any] = [:]
                    projectIndexedPaths(entry, values: &ftsValues, indices: indicesToReindex, typeFilter: kValueExtractedToFtsColumn)
                    if !ftsValues.isEmpty {
                        try updateTable("\(soupTableName)_fts", values: ftsValues, entryId: entryId, idCol: ROWID_COL, with: db)
                    }
                }
            }
        }
        frs?.close()
        return true
    }

    func hasFts(_ soupName: String, with db: FMDatabase) throws -> Bool {
        let indices = try self.indices(forSoup: soupName, with: db)
        return SoupIndex.hasFts(indices)
    }

    // MARK: - Misc

    private func projectIndexedPaths(_ entry: [String: Any], values: inout [String: Any], indices: [SoupIndex], typeFilter: @convention(block) (SoupIndex) -> Bool) {
        for idx in indices {
            if !typeFilter(idx) { continue }

            var indexColVal: Any? = SFJsonUtils.project(intoJson: entry, path: idx.path)
            // values for non-leaf nodes are json-ized
            if indexColVal is [String: Any] || indexColVal is [Any] {
                indexColVal = SFJsonUtils.jsonRepresentation(indexColVal, options: [])
            }

            let colName = idx.columnName
            values[colName] = indexColVal ?? NSNull()
        }
    }

    // MARK: - Compatibility Methods

    private func upgradeRenameTableSoupNamesToSoupAttrs() {
        inDatabase({ db in
            if db.tableExists(SOUP_NAMES_TABLE) {
                let renameSql = "ALTER TABLE \(SOUP_NAMES_TABLE) RENAME TO \(SOUP_ATTRS_TABLE)"
                SmartStoreLogger.d(SmartStore.self, message: "renameSoupNamesTableSql: \(renameSql)")
                try self.executeUpdateThrows(renameSql, with: db)
            }
        }, error: nil)
    }

    // MARK: - SQLCipher Info Methods

    /// Return SQLCipher runtime settings.
    @objc(getRuntimeSettings)
    public func runtimeSettings() -> [Any] {
        return queryPragma("cipher_settings")
    }

    /// Return SQLCipher compile options.
    @objc(getCompileOptions)
    public func compileOptions() -> [Any] {
        return queryPragma("compile_options")
    }

    /// Return SQLCipher version.
    @objc(getSQLCipherVersion)
    public func versionOfSQLCipher() -> String {
        return queryPragma("cipher_version").joined(separator: "")
    }

    /// Return SQLCipher provider version.
    @objc(getCipherProviderVersion)
    public func cipherProviderVersion() -> String {
        return queryPragma("cipher_provider_version").joined(separator: "")
    }

    /// Return SQLCipher FIPS status.
    @objc(getCipherFIPSStatus)
    public func cipherFIPSStatus() -> Bool {
        let status = queryPragma("cipher_fips_status").joined(separator: "")
        return status == "1"
    }

    private func queryPragma(_ pragma: String) -> [String] {
        var result: [String] = []
        storeQueue?.inDatabase { db in
            if let rs = db.executeQuery("pragma \(pragma)", withArgumentsIn: []) {
                while rs.next() {
                    result.append(rs.string(forColumnIndex: 0) ?? "")
                }
                rs.close()
            }
        }
        return result
    }
}

