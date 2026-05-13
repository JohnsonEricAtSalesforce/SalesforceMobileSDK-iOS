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
import FMDB
import SQLCipher
import SalesforceSDKCore
import SalesforceSDKCommon

/// The NSError domain for SmartStore database errors.
public let kSFSmartStoreDbErrorDomain = "com.salesforce.smartstore.db.error"

// NSError constants
private let kSFSmartStoreAttachNewDbErrorCode = 1
private let kSFSmartStoreAttachNewDbErrorDesc = "Failed to attach new DB for %@: %@"
private let kSFSmartStoreDbExportErrorCode = 2
private let kSFSmartStoreDbExportErrorDesc = "Failed to export contents of original DB: %@"
private let kSFSmartStoreDetachDbErrorCode = 3
private let kSFSmartStoreDetachDbErrorDesc = "Failed to detach the new DB: %@"
private let kSFSmartStoreDbBackupErrorCode = 4
private let kSFSmartStoreDbBackupErrorDesc = "Could not make a backup of store '%@': %@"
private let kSFSmartStoreReplaceDbErrorCode = 5
private let kSFSmartStoreReplaceDbErrorDesc = "Could not replace old DB with new DB: %@"
private let kSFSmartStoreVerifyDbErrorCode = 6
private let kSFSmartStoreVerifyDbErrorDesc = "Could not open database at path '%@' for verification: %@"
private let kSFSmartStoreVerifyReadDbErrorCode = 7
private let kSFSmartStoreVerifyReadDbErrorDesc = "Could not read from database at path '%@', for verification: %@"

private let kStoreDbFileName = "store.sqlite"
private let kStoresDirectory = "stores"

private var sDatabaseManagers: NSMutableDictionary = [:]

@objc(DatabaseManager)
public class DatabaseManager: NSObject {

    @objc public var user: SFUserAccount?
    @objc public var isGlobalManager: Bool = false

    // MARK: - Singleton initialization / management

    @objc(initializeDatabaseManager)
    public class func initializeDatabaseManager() {
        // Initialization happens at static var creation
    }

    /// Gets the shared instance of the database manager for the current user.
    @objc public class func sharedManager() -> DatabaseManager? {
        return sharedManager(for: UserAccountManager.shared.currentUserAccount)
    }

    /// Gets the shared instance of the database manager for the given user.
    /// - Parameter user: The user associated with the database manager.
    @objc public class func sharedManager(for user: SFUserAccount?) -> DatabaseManager? {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        guard let user = user else { return nil }

        let userKey = Utils.userKey(for: user)
        var mgr = sDatabaseManagers[userKey] as? DatabaseManager
        if mgr == nil {
            mgr = DatabaseManager(user: user)
            sDatabaseManagers[userKey] = mgr
        }
        return mgr
    }

    /// Gets the shared instance of the database manager of global stores.
    @objc public class func sharedGlobalManager() -> DatabaseManager {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        struct Static {
            static var globalManager: DatabaseManager = DatabaseManager(globalManager: ())
        }
        return Static.globalManager
    }

    /// Removes the shared database manager associated with the given user.
    /// - Parameter user: The user configured for the shared database manager.
    @objc public class func removeSharedManager(for user: SFUserAccount?) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        guard let user = user else { return }

        let userKey = Utils.userKey(for: user)
        if let mgr = sDatabaseManagers[userKey] as? DatabaseManager {
            sDatabaseManagers.removeObject(forKey: userKey)
        }
    }

    private init(user: SFUserAccount) {
        self.user = user
        self.isGlobalManager = false
        super.init()
    }

    private init(globalManager: ()) {
        self.isGlobalManager = true
        super.init()
    }

    // MARK: - Database management methods

    /// Whether the store with the given name exists.
    /// - Parameter storeName: The name of the store to query.
    /// - Returns: YES if the store exists, NO otherwise.
    @objc public func persistentStoreExists(_ storeName: String) -> Bool {
        let fullDbFilePath = fullDbFilePath(forStoreName: storeName)
        let manager = FileManager.default
        return manager.fileExists(atPath: fullDbFilePath)
    }

    /// Creates or opens an existing store DB.
    /// - Parameters:
    ///   - storeName: The name of the store to create or open.
    ///   - key: The encryption key associated with the store.
    ///   - salt: String used when the database header is stored in plain text for Shared mode.
    ///   - error: Returned if there's an error with the process.
    /// - Returns: The FMDatabase instance representing the DB, or nil if the create/open failed.
    @objc public func openStoreDatabase(withName storeName: String, key: String?, salt: String?, error: NSErrorPointer) -> FMDatabase? {
        let fullDbFilePath = fullDbFilePath(forStoreName: storeName)
        return DatabaseManager.openDatabase(withPath: fullDbFilePath, key: key, salt: salt, error: error)
    }

    // If you created your database with an app based on Mobile SDK 12.0 or 12.1.x using cocoapod
    // Then SQLCipher was not properly linked
    // This method checks for that situation and encrypt the database if needed
    private func fixFor12Bug(_ storeName: String, key: String?, salt: String?) {
        let fullDbFilePath = fullDbFilePath(forStoreName: storeName)

        var needEncrypting = false
        let queue = FMDatabaseQueue(path: fullDbFilePath)
        queue?.inDatabase { db in
            // In the normal case, the db will not be readable - we don't want to be logging any errors
            let logsErrors = db.logsErrors
            db.logsErrors = false
            needEncrypting = DatabaseManager.verifyDatabaseAccess(db, error: nil)
            db.logsErrors = logsErrors
        }

        if needEncrypting {
            _ = DatabaseManager.encryptDb(withStoreName: storeName, storePath: fullDbFilePath, key: key, salt: salt, error: nil)
        }
    }

    /// Creates or opens an existing store DB.
    /// - Parameters:
    ///   - storeName: The name of the store to create or open.
    ///   - key: The encryption key associated with the store.
    ///   - salt: String used when the database header is stored in plain text for Shared mode.
    ///   - error: Returned if there's an error with the process.
    /// - Returns: The FMDatabaseQueue instance to access the DB, or nil if the create/open failed.
    @objc public func openStoreQueue(withName storeName: String, key: String?, salt: String?, error: NSErrorPointer) -> FMDatabaseQueue? {
        fixFor12Bug(storeName, key: key, salt: salt)

        var result = true
        let fullDbFilePath = fullDbFilePath(forStoreName: storeName)
        let queue = FMDatabaseQueue(path: fullDbFilePath)
        queue?.inDatabase { db in
            result = (DatabaseManager.setKey(for: db, key: key, salt: salt, error: error) != nil)
            result = result && db.goodConnection // make sure SQLCipher is properly linked
        }
        return result ? queue : nil
    }

    @objc public class func openDatabase(withPath dbPath: String, key: String?, salt: String?, error: NSErrorPointer) -> FMDatabase? {
        let db = FMDatabase(path: dbPath)
        return setKey(for: db, key: key, salt: salt, error: error)
    }

    @objc public class func setKey(for db: FMDatabase?, key: String?, salt: String?, error: NSErrorPointer) -> FMDatabase? {
        guard let db = db else { return nil }

        db.logsErrors = true
        db.crashOnErrors = false

        let unlockedDb = unlockDatabase(db, key: key, salt: salt)

        if unlockedDb == nil {
            SmartStoreLogger.d(self, message: "Couldn't open store db at: \(db.databasePath) error: \(db.lastErrorMessage())")
            if error != nil {
                error?.pointee = db.lastError() as NSError
            }
        }

        return unlockedDb
    }

    @objc public class func unlockDatabase(_ db: FMDatabase, key: String?, salt: String?) -> FMDatabase? {
        if db.open() {
            if let licenseKey = SmartStore.licenseKey {
                _ = db.executeQuery("PRAGMA cipher_license = '\(licenseKey)'", withArgumentsIn: [])?.close()
            }

            if let key = key {
                db.setKey(key)
            }

            // Using sqlcipher 2.x kdf iter because 3.x default (64000) and 4.x default (256000) are too slow
            _ = db.executeQuery("PRAGMA kdf_iter = 4000", withArgumentsIn: [])?.close()

            // No longer doing pragma cipher_migrate - so a jump from Mobile SDK 7.0 (last version using 3.x) to Mobile SDK 10.0 won't work
            // Motivation: https://github.com/forcedotcom/SalesforceMobileSDK-iOS/pull/3463#issuecomment-1006844543

            if let salt = salt, let key = key, !key.isEmpty {
                _ = db.executeQuery("PRAGMA cipher_plaintext_header_size = 32", withArgumentsIn: [])?.close()
                let pragma = "PRAGMA cipher_salt = \"x'\(salt)'\""
                _ = db.executeQuery(pragma, withArgumentsIn: [])?.close()
                _ = db.executeQuery("PRAGMA journal_mode = WAL", withArgumentsIn: [])?.close()
            }
        }

        var verifyError: NSError?
        let accessible = verifyDatabaseAccess(db, error: &verifyError)
        if accessible {
            return db
        } else {
            db.close()
            SmartStoreLogger.e(self, message: "Error reading the content of store '\(db.databasePath ?? "")'")
            return nil
        }
    }

    /// Encrypts an existing unencrypted database.
    /// - Parameters:
    ///   - db: The DB to encrypt.
    ///   - storeName: The name of the store representing the DB.
    ///   - key: The encryption key to be used for encrypting the database.
    ///   - salt: String used when the database header is stored in plain text for Shared mode.
    ///   - error: Returned if there's an error with encrypting the data.
    /// - Returns: The newly-encrypted DB, or the original DB if the encryption fails at any point in the process.
    @objc public func encryptDb(_ db: FMDatabase, name storeName: String, key: String?, salt: String?, error: NSErrorPointer) -> FMDatabase? {
        return encryptOrUnencryptDb(db, name: storeName, oldKey: "", newKey: key, salt: salt, error: error)
    }

    /// Encrypts an existing store
    /// - Parameters:
    ///   - storeName: The name of the store representing the DB.
    ///   - storePath: The path specifying the store location.
    ///   - key: The encryption key to be used for encrypting the database.
    ///   - salt: String used when the database header is stored in plain text for Shared mode.
    ///   - error: Returned if there's an error with encrypting the data.
    /// - Returns: YES if the encryption was successful, or NO if the encryption fails at any point in the process.
    @objc public class func encryptDb(withStoreName storeName: String, storePath: String, key: String?, salt: String?, error: NSErrorPointer) -> Bool {
        var openDbError: NSError?
        guard let db = openDatabase(withPath: storePath, key: "", salt: salt, error: &openDbError) else {
            if let openDbError = openDbError, error != nil {
                error?.pointee = openDbError
            }
            return false
        }

        var encryptDbError: NSError?
        let encryptedDb = encryptOrUnencryptDb(db, name: storeName, path: storePath, oldKey: "", newKey: key, salt: salt, error: &encryptDbError)

        if let encryptDbError = encryptDbError {
            encryptedDb?.close()
            if error != nil {
                error?.pointee = encryptDbError
            }
            return false
        }

        encryptedDb?.close()
        return true
    }

    /// Unencrypts an encrypted database, back to plaintext.
    /// - Parameters:
    ///   - db: The database to unencrypt.
    ///   - storeName: The name of the store associated with the DB.
    ///   - oldKey: The original encryption key of the database.
    ///   - salt: String used when the database header is stored in plain text for Shared mode.
    ///   - error: Returned if there's an error during the process.
    /// - Returns: The unencrypted database, or the original encrypted database if the process fails at any point.
    @objc public func unencryptDb(_ db: FMDatabase, name storeName: String, oldKey: String?, salt: String?, error: NSErrorPointer) -> FMDatabase? {
        return encryptOrUnencryptDb(db, name: storeName, oldKey: oldKey, newKey: "", salt: salt, error: error)
    }

    /// Unencrypts an encrypted store, back to plaintext.
    /// - Parameters:
    ///   - storeName: The name of the store associated with the DB.
    ///   - storePath: The path specifying the store location.
    ///   - key: The original encryption key of the database.
    ///   - salt: String used when the database header is stored in plain text for Shared mode.
    ///   - error: Returned if there's an error during the process.
    /// - Returns: YES if the existing store was successfully unencrypted, or NO if the process fails at any point.
    @objc public class func unencryptDb(withStoreName storeName: String, storePath: String, key: String?, salt: String?, error: NSErrorPointer) -> Bool {
        var openDbError: NSError?
        guard let db = openDatabase(withPath: storePath, key: key, salt: salt, error: &openDbError) else {
            if let openDbError = openDbError, error != nil {
                error?.pointee = openDbError
            }
            return false
        }

        var encryptDbError: NSError?
        let unencryptedDb = encryptOrUnencryptDb(db, name: storeName, path: storePath, oldKey: key, newKey: "", salt: salt, error: &encryptDbError)

        if let encryptDbError = encryptDbError {
            unencryptedDb?.close()
            if error != nil {
                error?.pointee = encryptDbError
            }
            return false
        }

        unencryptedDb?.close()
        return true
    }

    private func encryptOrUnencryptDb(_ db: FMDatabase?, name storeName: String, oldKey: String?, newKey: String?, salt: String?, error: NSErrorPointer) -> FMDatabase? {
        let storePath = fullDbFilePath(forStoreName: storeName)
        return DatabaseManager.encryptOrUnencryptDb(db, name: storeName, path: storePath, oldKey: oldKey, newKey: newKey, salt: salt, error: error)
    }

    @objc public class func encryptOrUnencryptDb(_ db: FMDatabase?, name storeName: String, path storePath: String, oldKey: String?, newKey: String?, salt: String?, error: NSErrorPointer) -> FMDatabase? {
        guard let db = db else { return nil }

        let actualNewKey = newKey ?? ""
        let escapedKey = actualNewKey.replacingOccurrences(of: "'", with: "''")
        let encDbPath = storePath + ".encrypted"

        let encrypting = !actualNewKey.isEmpty
        SmartStoreLogger.i(self, message: "DB for store '\(storeName)' is \(encrypting ? "unencrypted" : "encrypted"). \(encrypting ? "Encrypting" : "Unencrypting").")
        let manager = FileManager.default

        // Use sqlcipher_export() to move the data from the input DB over to the new one.
        let attachDbString = "ATTACH DATABASE '\(encDbPath)' AS encrypted KEY '\(escapedKey)'"
        var updateResult = db.executeUpdate(attachDbString, withArgumentsIn: [])
        if !updateResult {
            let errorDesc = String(format: kSFSmartStoreAttachNewDbErrorDesc, encrypting ? "encrypting" : "decrypting", db.lastErrorMessage() ?? "")
            if error != nil {
                error?.pointee = NSError(domain: kSFSmartStoreDbErrorDomain, code: kSFSmartStoreAttachNewDbErrorCode, userInfo: [NSLocalizedDescriptionKey: errorDesc])
            }
            try? manager.removeItem(atPath: encDbPath)
            return db
        }

        _ = db.executeQuery("PRAGMA encrypted.kdf_iter = 4000", withArgumentsIn: [])?.close()

        // Use sqlcipher_export() to move the data from the input DB over to the new one.
        if let salt = salt {
            _ = db.executeQuery("PRAGMA encrypted.cipher_plaintext_header_size = 32", withArgumentsIn: [])?.close()
            let pragma = "PRAGMA encrypted.cipher_salt = \"x'\(salt)'\""
            _ = db.executeQuery(pragma, withArgumentsIn: [])?.close()
        }

        let rs = db.executeQuery("SELECT sqlcipher_export('encrypted')", withArgumentsIn: [])
        if rs == nil || !(rs?.next() ?? false) {
            rs?.close()
            if error != nil {
                let errorDesc = String(format: kSFSmartStoreDbExportErrorDesc, db.lastErrorMessage() ?? "")
                error?.pointee = NSError(domain: kSFSmartStoreDbErrorDomain, code: kSFSmartStoreDbExportErrorCode, userInfo: [NSLocalizedDescriptionKey: errorDesc])
            }
            try? manager.removeItem(atPath: encDbPath)
            return db
        }
        rs?.close()

        updateResult = db.executeUpdate("DETACH DATABASE encrypted", withArgumentsIn: [])
        if !updateResult {
            let errorDesc = String(format: kSFSmartStoreDetachDbErrorDesc, db.lastErrorMessage() ?? "")
            if error != nil {
                error?.pointee = NSError(domain: kSFSmartStoreDbErrorDomain, code: kSFSmartStoreDetachDbErrorCode, userInfo: [NSLocalizedDescriptionKey: errorDesc])
            }
            try? manager.removeItem(atPath: encDbPath)
            return db
        }

        // As a sanity check, verify that the new encrypted DB can be opened and read.
        var openNewlyEncryptedDbError: NSError?
        guard let newlyEncryptedDb = openDatabase(withPath: encDbPath, key: actualNewKey, salt: salt, error: &openNewlyEncryptedDbError) else {
            if error != nil {
                let errorDesc = String(format: kSFSmartStoreVerifyDbErrorDesc, encDbPath, openNewlyEncryptedDbError?.localizedDescription ?? "")
                error?.pointee = NSError(domain: kSFSmartStoreDbErrorDomain, code: kSFSmartStoreVerifyDbErrorCode, userInfo: [NSLocalizedDescriptionKey: errorDesc])
            }
            try? manager.removeItem(atPath: encDbPath)
            return db
        }

        var verifyError: NSError?
        if !verifyDatabaseAccess(newlyEncryptedDb, error: &verifyError) {
            if error != nil {
                error?.pointee = verifyError
            }
            newlyEncryptedDb.close()
            try? manager.removeItem(atPath: encDbPath)
            return db
        }
        newlyEncryptedDb.close()

        // New database created and verified.  Move it into place of the old one.
        db.close()
        let backupPath = storePath + ".bak"

        var fileOpError: NSError?
        var fileOpSuccess = false
        do {
            try manager.moveItem(atPath: storePath, toPath: backupPath)
            fileOpSuccess = true
        } catch let error1 as NSError {
            fileOpError = error1
            fileOpSuccess = false
        }

        if !fileOpSuccess {
            if error != nil {
                let errorDesc = String(format: kSFSmartStoreDbBackupErrorDesc, storeName, fileOpError?.localizedDescription ?? "")
                error?.pointee = NSError(domain: kSFSmartStoreDbErrorDomain, code: kSFSmartStoreDbBackupErrorCode, userInfo: [NSLocalizedDescriptionKey: errorDesc])
            }
            try? manager.removeItem(atPath: encDbPath)
            return setKey(for: db, key: oldKey, salt: salt, error: nil)
        }

        do {
            try manager.moveItem(atPath: encDbPath, toPath: storePath)
            fileOpSuccess = true
        } catch let error1 as NSError {
            fileOpError = error1
            fileOpSuccess = false
        }

        if !fileOpSuccess {
            if error != nil {
                let errorDesc = String(format: kSFSmartStoreReplaceDbErrorDesc, fileOpError?.localizedDescription ?? "")
                error?.pointee = NSError(domain: kSFSmartStoreDbErrorDomain, code: kSFSmartStoreReplaceDbErrorCode, userInfo: [NSLocalizedDescriptionKey: errorDesc])
            }
            try? manager.removeItem(atPath: encDbPath)
            try? manager.moveItem(atPath: backupPath, toPath: storePath)
            return setKey(for: db, key: oldKey, salt: salt, error: nil)
        }

        if let encDb = openDatabase(withPath: storePath, key: actualNewKey, salt: salt, error: nil) {
            try? manager.removeItem(atPath: backupPath)
            return encDb
        } else {
            try? manager.removeItem(atPath: storePath)
            try? manager.moveItem(atPath: backupPath, toPath: storePath)
            return setKey(for: db, key: oldKey, salt: salt, error: nil)
        }
    }

    @objc public class func verifyDatabaseAccess(_ db: FMDatabase?, error: NSErrorPointer) -> Bool {
        guard let db = db else { return false }

        let rs = db.executeQuery("select name from sqlite_master where type='table'", withArgumentsIn: [])
        if rs == nil {
            // May not be results, but rs should never be nil coming back.
            if error != nil {
                let errorDesc = String(format: kSFSmartStoreVerifyReadDbErrorDesc, db.databasePath ?? "", db.lastErrorMessage() ?? "")
                error?.pointee = NSError(domain: kSFSmartStoreDbErrorDomain, code: kSFSmartStoreVerifyReadDbErrorCode, userInfo: [NSLocalizedDescriptionKey: errorDesc])
            }
            return false
        }

        return true
    }

    // MARK: - Utilities

    /// Creates the directory for the store, on the filesystem.
    /// - Parameter storeName: The name of the store to be created.
    /// - Returns: YES if the call completed with no errors, NO otherwise.
    @objc public func createStoreDir(_ storeName: String) -> Bool {
        var result = true
        let storeDir = storeDirectory(forStoreName: storeName)
        let manager = FileManager.default
        if !manager.fileExists(atPath: storeDir) {
            // This store has not yet been created; create it.
            do {
                try SFDirectoryManager.ensureDirectoryExists(storeDir)
                result = true
            } catch let err as NSError {
                SmartStoreLogger.e(type(of: self), message: "Couldn't create store dir for store: \(storeName) - error:\(err)")
                result = false
            }
        } else {
            return true
        }
        return result
    }

    private func getDirProtection(_ dirPath: String) -> String? {
        var error: NSError?
        let manager = FileManager.default
        do {
            let attr = try manager.attributesOfItem(atPath: dirPath)
            let result = attr[.protectionKey] as? String
            return result
        } catch let error1 as NSError {
            error = error1
            SmartStoreLogger.e(type(of: self), message: "Couldn't get protection of dir: \(dirPath) - error:\(error?.localizedDescription ?? "")")
            return nil
        }
    }

    private func protectDir(_ dirPath: String, protection: String) -> Bool {
        let currentProtection = getDirProtection(dirPath)
        if currentProtection == nil || dirPath == SFPathUtil.applicationDocumentDirectory() {
            // We don't own the dir, we are done
            return true
        } else {
            // Change protection if not the one desired
            if currentProtection != protection {
                var error: NSError?
                let attr: [FileAttributeKey: Any] = [.protectionKey: protection]
                let manager = FileManager.default
                var result = false
                do {
                    try manager.setAttributes(attr, ofItemAtPath: dirPath)
                    result = true
                } catch let error1 as NSError {
                    error = error1
                    result = false
                }

                if let error = error, !result {
                    SmartStoreLogger.e(type(of: self), message: "Couldn't protect dir: \(dirPath) - error:\(error)")
                    return false
                } else {
                    SmartStoreLogger.d(type(of: self), message: "Protecting dir: \(dirPath) with \(protection)")
                }
            }
            // Go to parent directory
            let parentDirPath = (dirPath as NSString).deletingLastPathComponent
            return protectDir(parentDirPath, protection: protection)
        }
    }

    /// Sets filesystem protection on the store DB file, directory and ancestor directories.
    /// - Parameters:
    ///   - storeName: The store associated with the protection.
    ///   - protection: The file system protection desired.
    /// - Returns: YES if the call completes without errors, NO otherwise.
    @objc public func protectStoreDirIfNeeded(_ storeName: String, protection: String) -> Bool {
        let dbFilePath = fullDbFilePath(forStoreName: storeName)
        return protectDir(dbFilePath, protection: protection)
    }

    /// Removes the store directory and all of its contents from the filesystem.
    /// - Parameter storeName: The store associated with the request.
    @objc public func removeStoreDir(_ storeName: String) {
        let storeDir = storeDirectory(forStoreName: storeName)
        let manager = FileManager.default
        if manager.fileExists(atPath: storeDir) {
            try? manager.removeItem(atPath: storeDir)
        }
    }

    /// The full filesystem path to the database with the given store name.
    /// - Parameter storeName: The name of the store (excluding paths).
    /// - Returns: Full filesystem path for the store DB file.
    @objc public func fullDbFilePath(forStoreName storeName: String) -> String {
        let storePath = storeDirectory(forStoreName: storeName)
        let fullDbFilePath = (storePath as NSString).appendingPathComponent(kStoreDbFileName)
        return fullDbFilePath
    }

    private func storeDirectory(forStoreName storeName: String) -> String {
        let storesDir = rootStoreDirectory()
        let result = (storesDir as NSString).appendingPathComponent(storeName)
        return result
    }

    private func rootStoreDirectory() -> String {
        let rootStoreDir: String?
        if user == nil || isGlobalManager {
            rootStoreDir = SFDirectoryManager.shared.globalDirectory(ofType: .documentDirectory, components: [kStoresDirectory])
        } else {
            rootStoreDir = SFDirectoryManager.shared.directory(forUser: user, type: .documentDirectory, components: [kStoresDirectory])
        }
        return rootStoreDir ?? ""
    }

    /// All of the store names associated with this application.
    /// - Returns: Array of store names
    @objc public func allStoreNames() -> [String]? {
        let rootDir = rootStoreDirectory()
        var getStoresError: NSError?
        let manager = FileManager.default
        var storesDirNames: [String]?
        do {
            storesDirNames = try manager.contentsOfDirectory(atPath: rootDir)
        } catch let error as NSError {
            getStoresError = error
        }

        if let getStoresError = getStoresError {
            SmartStoreLogger.d(type(of: self), message: "Warning: Problem retrieving all store names from the root stores folder: \(getStoresError.localizedDescription).")
            return nil
        }

        var allStoreNames: [String] = []
        if let storesDirNames = storesDirNames {
            for storesDirName in storesDirNames {
                if persistentStoreExists(storesDirName) {
                    allStoreNames.append(storesDirName)
                }
            }
        }
        return allStoreNames
    }
}
