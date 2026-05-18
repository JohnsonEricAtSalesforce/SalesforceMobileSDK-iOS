/*
 Copyright (c) 2012-present, salesforce.com, inc. All rights reserved.

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
import SalesforceSDKCommon
import SalesforceSDKCore
import FMDB

// MARK: - Constants

/// The NSError domain for SmartStore database errors.
public let SmartStoreDbErrorDomain: String = "com.salesforce.smartstore.db.error"

private let kStoreDbFileName = "store.sqlite"
private let kStoresDirectory = "stores"

private let kSFSmartStoreAttachNewDbErrorCode: Int = 1
private let kSFSmartStoreAttachNewDbErrorDesc = "Failed to attach new DB for %@: %@"
private let kSFSmartStoreDbExportErrorCode: Int = 2
private let kSFSmartStoreDbExportErrorDesc = "Failed to export contents of original DB: %@"
private let kSFSmartStoreDetachDbErrorCode: Int = 3
private let kSFSmartStoreDetachDbErrorDesc = "Failed to detach the new DB: %@"
private let kSFSmartStoreDbBackupErrorCode: Int = 4
private let kSFSmartStoreDbBackupErrorDesc = "Could not make a backup of store '%@': %@"
private let kSFSmartStoreReplaceDbErrorCode: Int = 5
private let kSFSmartStoreReplaceDbErrorDesc = "Could not replace old DB with new DB: %@"
private let kSFSmartStoreVerifyDbErrorCode: Int = 6
private let kSFSmartStoreVerifyDbErrorDesc = "Could not open database at path '%@' for verification: %@"
private let kSFSmartStoreVerifyReadDbErrorCode: Int = 7
private let kSFSmartStoreVerifyReadDbErrorDesc = "Could not read from database at path '%@', for verification: %@"

// MARK: - SmartStoreDatabaseManager

/// Manages SmartStore SQLCipher databases.
@objc(SFSmartStoreDatabaseManager)
@objcMembers
public class SmartStoreDatabaseManager: NSObject {

    // MARK: - Static State

    private static var databaseManagers: [String: SmartStoreDatabaseManager] = [:]
    private static let managerLock = NSLock()
    private static var globalManager: SmartStoreDatabaseManager?

    // MARK: - Instance Properties

    internal var user: UserAccount?
    internal var isGlobalManager: Bool = false

    // MARK: - Singleton Management

    /// Gets the shared instance of the database manager for the current user.
    @objc(sharedManager)
    public class func shared() -> SmartStoreDatabaseManager? {
        return shared(forUser: UserAccountManager.shared.currentUserAccount)
    }

    /// Gets the shared instance of the database manager for the given user.
    @objc(sharedManagerForUser:)
    public class func shared(forUser user: UserAccount?) -> SmartStoreDatabaseManager? {
        managerLock.lock()
        defer { managerLock.unlock() }

        guard let user = user else { return nil }

        guard let userKey = SmartStoreUtils.userKey(forUser: user) else { return nil }

        if let existing = databaseManagers[userKey] {
            return existing
        }

        let mgr = SmartStoreDatabaseManager(user: user)
        databaseManagers[userKey] = mgr
        return mgr
    }

    /// Gets the shared instance of the database manager of global stores.
    @objc(sharedGlobalManager)
    public class func sharedGlobal() -> SmartStoreDatabaseManager {
        managerLock.lock()
        defer { managerLock.unlock() }

        if let existing = globalManager {
            return existing
        }
        let mgr = SmartStoreDatabaseManager(global: true)
        globalManager = mgr
        return mgr
    }

    /// Removes the shared database manager associated with the given user.
    @objc(removeSharedManagerForUser:)
    public class func removeSharedManager(forUser user: UserAccount?) {
        managerLock.lock()
        defer { managerLock.unlock() }

        guard let user = user else { return }
        guard let userKey = SmartStoreUtils.userKey(forUser: user) else { return }
        databaseManagers.removeValue(forKey: userKey)
    }

    // MARK: - Initialization

    private init(user: UserAccount) {
        self.user = user
        self.isGlobalManager = false
        super.init()
    }

    private init(global: Bool) {
        self.isGlobalManager = true
        super.init()
    }

    // MARK: - Database Management Methods

    /// Whether the store with the given name exists.
    @objc
    public func persistentStoreExists(_ storeName: String) -> Bool {
        guard let fullDbFilePath = fullDbFilePath(forStoreName: storeName) else { return false }
        return FileManager.default.fileExists(atPath: fullDbFilePath)
    }

    /// Creates or opens an existing store DB.
    @objc
    public func openStoreDatabase(withName storeName: String, key: String, salt: String?) throws -> FMDatabase {
        guard let fullDbFilePath = fullDbFilePath(forStoreName: storeName) else {
            throw NSError(domain: SmartStoreDbErrorDomain, code: kSFSmartStoreVerifyDbErrorCode,
                          userInfo: [NSLocalizedDescriptionKey: "Could not determine path for store '\(storeName)'"])
        }
        return try SmartStoreDatabaseManager.openDatabase(withPath: fullDbFilePath, key: key, salt: salt)
    }

    /// Creates or opens an existing store DB queue.
    @objc
    public func openStoreQueue(withName storeName: String, key: String, salt: String?) throws -> FMDatabaseQueue {
        fixFor12Bug(storeName: storeName, key: key, salt: salt)

        guard let fullDbFilePath = fullDbFilePath(forStoreName: storeName) else {
            throw NSError(domain: SmartStoreDbErrorDomain, code: kSFSmartStoreVerifyDbErrorCode,
                          userInfo: [NSLocalizedDescriptionKey: "Could not determine path for store '\(storeName)'"])
        }

        var openError: NSError?
        var success = true

        guard let queue = FMDatabaseQueue(path: fullDbFilePath) else {
            throw NSError(domain: SmartStoreDbErrorDomain, code: kSFSmartStoreVerifyDbErrorCode,
                          userInfo: [NSLocalizedDescriptionKey: "Could not create database queue for store '\(storeName)'"])
        }

        queue.inDatabase { db in
            do {
                let _ = try SmartStoreDatabaseManager.setKey(forDb: db, key: key, salt: salt)
                if !db.goodConnection {
                    success = false
                    openError = NSError(domain: SmartStoreDbErrorDomain, code: kSFSmartStoreVerifyDbErrorCode,
                                        userInfo: [NSLocalizedDescriptionKey: "SQLCipher not properly linked for store '\(storeName)'"])
                }
            } catch let error as NSError {
                success = false
                openError = error
            }
        }

        if let error = openError {
            throw error
        }

        if !success {
            throw NSError(domain: SmartStoreDbErrorDomain, code: kSFSmartStoreVerifyDbErrorCode,
                          userInfo: [NSLocalizedDescriptionKey: "Could not open store queue for '\(storeName)'"])
        }

        return queue
    }

    /// Encrypts an existing unencrypted database.
    @objc
    public func encryptDb(_ db: FMDatabase, name storeName: String, key: String, salt: String?) throws -> FMDatabase {
        return try encryptOrUnencryptDb(db, name: storeName, oldKey: "", newKey: key, salt: salt)
    }

    /// Encrypts an existing store at the given path.
    @objc
    public class func encryptDb(withStoreName storeName: String, storePath: String, key: String, salt: String?) throws {
        let db = try openDatabase(withPath: storePath, key: "", salt: salt)

        do {
            let resultDb = try encryptOrUnencryptDb(db, name: storeName, path: storePath, oldKey: "", newKey: key, salt: salt)
            resultDb.close()
        } catch {
            db.close()
            throw error
        }
    }

    /// Unencrypts an encrypted database, back to plaintext.
    @objc
    public func unencryptDb(_ db: FMDatabase, name storeName: String, oldKey: String, salt: String?) throws -> FMDatabase {
        return try encryptOrUnencryptDb(db, name: storeName, oldKey: oldKey, newKey: "", salt: salt)
    }

    /// Unencrypts an encrypted store, back to plaintext.
    @objc
    public class func unencryptDb(withStoreName storeName: String, storePath: String, key: String, salt: String?) throws {
        let db = try openDatabase(withPath: storePath, key: key, salt: salt)

        do {
            let resultDb = try encryptOrUnencryptDb(db, name: storeName, path: storePath, oldKey: key, newKey: "", salt: salt)
            resultDb.close()
        } catch {
            db.close()
            throw error
        }
    }

    // MARK: - Directory Management

    /// Creates the directory for the store on the filesystem.
    @objc
    @discardableResult
    public func createStoreDir(_ storeName: String) -> Bool {
        guard let storeDir = storeDirectory(forStoreName: storeName) else { return false }

        if FileManager.default.fileExists(atPath: storeDir) {
            return true
        }

        do {
            try SFDirectoryManager.ensureDirectoryExists(storeDir)
            return true
        } catch {
            SmartStoreLogger.e(SmartStoreDatabaseManager.self, message: "Couldn't create store dir for store: \(storeName) - error:\(error)")
            return false
        }
    }

    /// Sets filesystem protection on the store DB file, directory and ancestor directories.
    @nonobjc
    @discardableResult
    public func protectStoreDirIfNeeded(_ storeName: String, protection: FileProtectionType) -> Bool {
        guard let dbFilePath = fullDbFilePath(forStoreName: storeName) else { return false }
        return protectDir(dbFilePath, protection: protection.rawValue)
    }

    // Overload accepting raw string for backward compat with ObjC callers
    @objc(protectStoreDirIfNeeded:protection:)
    @discardableResult
    public func protectStoreDirIfNeeded(_ storeName: String, protection: String) -> Bool {
        guard let dbFilePath = fullDbFilePath(forStoreName: storeName) else { return false }
        return protectDir(dbFilePath, protection: protection)
    }

    /// Removes the store directory and all of its contents from the filesystem.
    @objc
    public func removeStoreDir(_ storeName: String) {
        guard let storeDir = storeDirectory(forStoreName: storeName) else { return }
        if FileManager.default.fileExists(atPath: storeDir) {
            try? FileManager.default.removeItem(atPath: storeDir)
        }
    }

    /// All of the store names associated with this application.
    @objc
    public func allStoreNames() -> [String]? {
        guard let rootDir = rootStoreDirectory() else { return nil }

        let storesDirNames: [String]
        do {
            storesDirNames = try FileManager.default.contentsOfDirectory(atPath: rootDir)
        } catch {
            SmartStoreLogger.d(SmartStoreDatabaseManager.self, message: "Warning: Problem retrieving all store names from the root stores folder: \(error.localizedDescription).")
            return nil
        }

        var result: [String] = []
        for storesDirName in storesDirNames {
            if persistentStoreExists(storesDirName) {
                result.append(storesDirName)
            }
        }
        return result
    }

    /// The full filesystem path to the database with the given store name.
    @objc
    public func fullDbFilePath(forStoreName storeName: String) -> String? {
        guard let storePath = storeDirectory(forStoreName: storeName) else { return nil }
        return (storePath as NSString).appendingPathComponent(kStoreDbFileName)
    }

    /// Verifies that the database contents for the given DB can be read.
    @objc
    public class func verifyDatabaseAccess(_ db: FMDatabase) throws {
        let rs = db.executeQuery("select name from sqlite_master where type='table'", withArgumentsIn: [])
        if rs == nil {
            let errorDesc = String(format: kSFSmartStoreVerifyReadDbErrorDesc, db.databasePath ?? "unknown", db.lastErrorMessage())
            throw NSError(domain: SmartStoreDbErrorDomain, code: kSFSmartStoreVerifyReadDbErrorCode,
                          userInfo: [NSLocalizedDescriptionKey: errorDesc])
        }
        rs?.close()
    }

    // MARK: - Internal Methods

    internal func storeDirectory(forStoreName storeName: String) -> String? {
        guard let storesDir = rootStoreDirectory() else { return nil }
        return (storesDir as NSString).appendingPathComponent(storeName)
    }

    internal func rootStoreDirectory() -> String? {
        if isGlobalManager {
            return SFDirectoryManager.shared().globalDirectory(ofType: .documentDirectory, components: [kStoresDirectory])
        } else if let user = user {
            return SFDirectoryManager.shared().directory(forUser: user, type: .documentDirectory, components: [kStoresDirectory])
        } else {
            return SFDirectoryManager.shared().globalDirectory(ofType: .documentDirectory, components: [kStoresDirectory])
        }
    }

    // MARK: - Private Methods

    /// Check for the 12.0/12.1.x bug where SQLCipher was not properly linked via CocoaPods.
    private func fixFor12Bug(storeName: String, key: String, salt: String?) {
        guard let fullDbFilePath = fullDbFilePath(forStoreName: storeName) else { return }

        var needEncrypting = false
        FMDatabaseQueue(path: fullDbFilePath)?.inDatabase { db in
            let logsErrors = db.logsErrors
            db.logsErrors = false
            do {
                try SmartStoreDatabaseManager.verifyDatabaseAccess(db)
                needEncrypting = true
            } catch {
                needEncrypting = false
            }
            db.logsErrors = logsErrors
        }

        if needEncrypting {
            try? SmartStoreDatabaseManager.encryptDb(withStoreName: storeName, storePath: fullDbFilePath, key: key, salt: salt)
        }
    }

    private func getDirProtection(_ dirPath: String) -> String? {
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: dirPath)
            return attrs[.protectionKey] as? String
        } catch {
            SmartStoreLogger.e(SmartStoreDatabaseManager.self, message: "Couldn't get protection of dir: \(dirPath) - error:\(error)")
            return nil
        }
    }

    @discardableResult
    private func protectDir(_ dirPath: String, protection: String) -> Bool {
        guard let currentProtection = getDirProtection(dirPath) else {
            // We don't own the dir, we are done
            return true
        }

        if dirPath == SFPathUtil.applicationDocumentDirectory() {
            return true
        }

        if currentProtection != protection {
            do {
                try FileManager.default.setAttributes([.protectionKey: protection], ofItemAtPath: dirPath)
                SmartStoreLogger.d(SmartStoreDatabaseManager.self, message: "Protecting dir: \(dirPath) with \(protection)")
            } catch {
                SmartStoreLogger.e(SmartStoreDatabaseManager.self, message: "Couldn't protect dir: \(dirPath) - error:\(error)")
                return false
            }
        }

        // Go to parent directory
        let parentDirPath = (dirPath as NSString).deletingLastPathComponent
        return protectDir(parentDirPath, protection: protection)
    }

    // MARK: - Database Open/Key Methods

    internal class func openDatabase(withPath dbPath: String, key: String, salt: String?) throws -> FMDatabase {
        let db = FMDatabase(path: dbPath)
        guard let result = try setKey(forDb: db, key: key, salt: salt) else {
            throw NSError(domain: SmartStoreDbErrorDomain, code: kSFSmartStoreVerifyDbErrorCode,
                          userInfo: [NSLocalizedDescriptionKey: "Could not open database at path '\(dbPath)'"])
        }
        return result
    }

    @discardableResult
    internal class func setKey(forDb db: FMDatabase, key: String, salt: String?) throws -> FMDatabase? {
        db.logsErrors = true
        db.crashOnErrors = false

        guard let unlockedDb = unlockDatabase(db, key: key, salt: salt) else {
            SmartStoreLogger.d(SmartStoreDatabaseManager.self, message: "Couldn't open store db at: \(db.databasePath ?? "nil") error: \(db.lastErrorMessage())")
            throw db.lastError()
        }

        return unlockedDb
    }

    private class func unlockDatabase(_ db: FMDatabase, key: String, salt: String?) -> FMDatabase? {
        guard db.open() else { return nil }

        if let licenseKey = SmartStore.licenseKey {
            db.executeQuery("PRAGMA cipher_license = '\(licenseKey)'", withArgumentsIn: [])?.close()
        }

        if !key.isEmpty {
            db.setKey(key)
        }

        // Using sqlcipher 2.x kdf iter because 3.x default (64000) and 4.x default (256000) are too slow
        db.executeQuery("PRAGMA kdf_iter = 4000", withArgumentsIn: [])?.close()

        if let salt = salt, !key.isEmpty {
            db.executeQuery("PRAGMA cipher_plaintext_header_size = 32", withArgumentsIn: [])?.close()
            let pragma = "PRAGMA cipher_salt = \"x'\(salt)'\""
            db.executeQuery(pragma, withArgumentsIn: [])?.close()
            db.executeQuery("PRAGMA journal_mode = WAL", withArgumentsIn: [])?.close()
        }

        var verifyError: NSError?
        var accessible = false
        do {
            try verifyDatabaseAccess(db)
            accessible = true
        } catch let error as NSError {
            verifyError = error
        }

        if accessible {
            return db
        } else {
            db.close()
            SmartStoreLogger.e(SmartStoreDatabaseManager.self, message: "Error reading the content of store '\(db.databasePath ?? "nil")': \(verifyError?.localizedDescription ?? "unknown")")
            return nil
        }
    }

    // MARK: - Encrypt/Unencrypt

    internal func encryptOrUnencryptDb(_ db: FMDatabase, name storeName: String, oldKey: String, newKey: String, salt: String?) throws -> FMDatabase {
        guard let storePath = fullDbFilePath(forStoreName: storeName) else {
            throw NSError(domain: SmartStoreDbErrorDomain, code: kSFSmartStoreVerifyDbErrorCode,
                          userInfo: [NSLocalizedDescriptionKey: "Could not determine path for store '\(storeName)'"])
        }
        return try SmartStoreDatabaseManager.encryptOrUnencryptDb(db, name: storeName, path: storePath, oldKey: oldKey, newKey: newKey, salt: salt)
    }

    internal class func encryptOrUnencryptDb(_ db: FMDatabase, name storeName: String, path storePath: String, oldKey: String, newKey: String, salt: String?) throws -> FMDatabase {
        let actualNewKey = newKey
        let escapedKey = actualNewKey.replacingOccurrences(of: "'", with: "''")
        let encDbPath = storePath + ".encrypted"

        let encrypting = !actualNewKey.isEmpty
        SmartStoreLogger.i(SmartStoreDatabaseManager.self, message: "DB for store '\(storeName)' is \(encrypting ? "unencrypted" : "encrypted"). \(encrypting ? "Encrypting" : "Unencrypting").")

        let manager = FileManager.default

        // Use sqlcipher_export() to move the data from the input DB over to the new one.
        let attachDbString = "ATTACH DATABASE '\(encDbPath)' AS encrypted KEY '\(escapedKey)'"
        let updateResult = db.executeUpdate(attachDbString, withArgumentsIn: [])
        if !updateResult {
            let errorDesc = String(format: kSFSmartStoreAttachNewDbErrorDesc,
                                   encrypting ? "encrypting" : "decrypting",
                                   db.lastErrorMessage())
            try? manager.removeItem(atPath: encDbPath)
            throw NSError(domain: SmartStoreDbErrorDomain, code: kSFSmartStoreAttachNewDbErrorCode,
                          userInfo: [NSLocalizedDescriptionKey: errorDesc])
        }

        db.executeQuery("PRAGMA encrypted.kdf_iter = 4000", withArgumentsIn: [])?.close()

        if let salt = salt {
            db.executeQuery("PRAGMA encrypted.cipher_plaintext_header_size = 32", withArgumentsIn: [])?.close()
            let pragma = "PRAGMA encrypted.cipher_salt = \"x'\(salt)'\""
            db.executeQuery(pragma, withArgumentsIn: [])?.close()
        }

        let rs = db.executeQuery("SELECT sqlcipher_export('encrypted')", withArgumentsIn: [])
        if rs == nil || !(rs?.next() ?? false) {
            rs?.close()
            let errorDesc = String(format: kSFSmartStoreDbExportErrorDesc, db.lastErrorMessage())
            try? manager.removeItem(atPath: encDbPath)
            throw NSError(domain: SmartStoreDbErrorDomain, code: kSFSmartStoreDbExportErrorCode,
                          userInfo: [NSLocalizedDescriptionKey: errorDesc])
        }
        rs?.close()

        let detachResult = db.executeUpdate("DETACH DATABASE encrypted", withArgumentsIn: [])
        if !detachResult {
            let errorDesc = String(format: kSFSmartStoreDetachDbErrorDesc, db.lastErrorMessage())
            try? manager.removeItem(atPath: encDbPath)
            throw NSError(domain: SmartStoreDbErrorDomain, code: kSFSmartStoreDetachDbErrorCode,
                          userInfo: [NSLocalizedDescriptionKey: errorDesc])
        }

        // Sanity check: verify that the new encrypted DB can be opened and read.
        do {
            let newlyEncryptedDb = try openDatabase(withPath: encDbPath, key: actualNewKey, salt: salt)
            do {
                try verifyDatabaseAccess(newlyEncryptedDb)
            } catch {
                newlyEncryptedDb.close()
                try? manager.removeItem(atPath: encDbPath)
                throw error
            }
            newlyEncryptedDb.close()
        } catch {
            let errorDesc = String(format: kSFSmartStoreVerifyDbErrorDesc, encDbPath, error.localizedDescription)
            try? manager.removeItem(atPath: encDbPath)
            throw NSError(domain: SmartStoreDbErrorDomain, code: kSFSmartStoreVerifyDbErrorCode,
                          userInfo: [NSLocalizedDescriptionKey: errorDesc])
        }

        // New database created and verified. Move it into place of the old one.
        db.close()
        let backupPath = storePath + ".bak"

        do {
            try manager.moveItem(atPath: storePath, toPath: backupPath)
        } catch {
            let errorDesc = String(format: kSFSmartStoreDbBackupErrorDesc, storeName, error.localizedDescription)
            try? manager.removeItem(atPath: encDbPath)
            // Try to re-open the original
            let _ = try? setKey(forDb: db, key: oldKey, salt: salt)
            throw NSError(domain: SmartStoreDbErrorDomain, code: kSFSmartStoreDbBackupErrorCode,
                          userInfo: [NSLocalizedDescriptionKey: errorDesc])
        }

        do {
            try manager.moveItem(atPath: encDbPath, toPath: storePath)
        } catch {
            let errorDesc = String(format: kSFSmartStoreReplaceDbErrorDesc, error.localizedDescription)
            try? manager.removeItem(atPath: encDbPath)
            try? manager.moveItem(atPath: backupPath, toPath: storePath)
            let _ = try? setKey(forDb: db, key: oldKey, salt: salt)
            throw NSError(domain: SmartStoreDbErrorDomain, code: kSFSmartStoreReplaceDbErrorCode,
                          userInfo: [NSLocalizedDescriptionKey: errorDesc])
        }

        if let encDb = try? openDatabase(withPath: storePath, key: actualNewKey, salt: salt) {
            try? manager.removeItem(atPath: backupPath)
            return encDb
        } else {
            try? manager.removeItem(atPath: storePath)
            try? manager.moveItem(atPath: backupPath, toPath: storePath)
            guard let fallbackDb = try? setKey(forDb: db, key: oldKey, salt: salt) else {
                throw NSError(domain: SmartStoreDbErrorDomain, code: kSFSmartStoreVerifyDbErrorCode,
                              userInfo: [NSLocalizedDescriptionKey: "Could not recover database for store '\(storeName)'"])
            }
            return fallbackDb
        }
    }
}
