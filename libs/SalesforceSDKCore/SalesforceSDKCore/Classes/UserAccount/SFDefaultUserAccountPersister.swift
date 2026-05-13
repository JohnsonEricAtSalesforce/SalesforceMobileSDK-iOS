/*
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

import Foundation
import SalesforceSDKCommon

// Name of the individual file containing the archived SFUserAccount class
public let kUserAccountPlistFileName = "UserAccount.plist"

// Label for encryption key for user account persistence.
public let kUserAccountEncryptionKeyLabel = "com.salesforce.userAccount.encryptionKey"

// Prefix constants
private let kOrgPrefix = "00D"
private let kUserPrefix = "005"

// Error domain and codes
private let SFUserAccountManagerErrorDomain = "SFUserAccountManager"
private let SFUserAccountManagerCannotReadDecryptedArchive: Int = 10001
private let SFUserAccountManagerCannotRetrieveUserData: Int = 10003
private let SFUserAccountManagerCannotWriteUserData: Int = 10004

@objc(SFDefaultUserAccountPersister)
public class DefaultUserAccountPersister: NSObject, UserAccountPersister {

    // MARK: - SFUserAccountPersister

    // Note: Cannot be @objc because throwing methods returning Bool are not supported
    @discardableResult
    public func saveAccount(for userAccount: UserAccount) throws -> Bool {
        let userAccountPlist = DefaultUserAccountPersister.userAccountPlistFile(for: userAccount)
        try self.save(userAccount: userAccount, toFile: userAccountPlist)
        return true
    }

    public func fetchAllAccounts() throws -> [UserAccountIdentity: UserAccount] {
        var userAccountMap = [UserAccountIdentity: UserAccount]()

        // Get the root directory, usually ~/Library/<appBundleId>/
        guard let rootDirectory = SFDirectoryManager.sharedManager().directory(forOrg: nil, user: nil, community: nil, type: .libraryDirectory, components: nil) else {
            return userAccountMap
        }
        let fm = FileManager.default
        if fm.fileExists(atPath: rootDirectory) {
            // Now iterate over the org and then user directories to load
            // each individual user account file.
            // ~/Library/<appBundleId>/<orgId>/<userId>/UserAccount.plist
            let rootContents = try fm.contentsOfDirectory(atPath: rootDirectory)

            for rootContent in rootContents {
                // Ignore content that doesn't represent the OrgID-based folder structure of user account persistence.
                if !rootContent.hasPrefix(kOrgPrefix) {
                    continue
                }
                let rootPath = (rootDirectory as NSString).appendingPathComponent(rootContent)

                // Fetch the content of the org directory
                guard let orgContents = try? fm.contentsOfDirectory(atPath: rootPath) else {
                    continue
                }

                for orgContent in orgContents {
                    // Ignore content that doesn't represent the UserID-based folder structure of user account persistence.
                    if !orgContent.hasPrefix(kUserPrefix) {
                        continue
                    }
                    let orgPath = (rootPath as NSString).appendingPathComponent(orgContent)

                    // Now let's try to load the user account file in there
                    let userAccountPath = (orgPath as NSString).appendingPathComponent(kUserAccountPlistFileName)
                    if fm.fileExists(atPath: userAccountPath) {
                        if let userAccount = try? self.loadUserAccount(fromFile: userAccountPath) {
                            userAccountMap[userAccount.accountIdentity] = userAccount
                        } else {
                            // Error logging will already have occurred.  Make sure account file data is removed.
                            try? fm.removeItem(atPath: userAccountPath)
                        }
                    } else {
                        SFSDKCoreLogger.d(type(of: self), message: "There is no user account file in this user directory: \(orgPath)")
                    }
                }
            }
        }
        return userAccountMap
    }

    // Note: Cannot be @objc because throwing methods returning Bool are not supported
    @discardableResult
    public func deleteAccount(for user: UserAccount) throws -> Bool {
        let manager = FileManager.default
        let userDirectory = SFDirectoryManager.sharedManager().directory(forUser: user, scope: .user, type: .libraryDirectory, components: nil)

        if manager.fileExists(atPath: userDirectory ?? "") {
            try manager.removeItem(atPath: userDirectory ?? "")
            return true
        } else {
            let reason = "User folder for user '\(user.idData?.username ?? "unknown")' does not exist on the filesystem"
            SFSDKCoreLogger.d(type(of: self), message: reason)
            throw NSError(domain: SFUserAccountManagerErrorDomain,
                          code: SFUserAccountManagerCannotReadDecryptedArchive,
                          userInfo: [NSLocalizedDescriptionKey: reason])
        }
    }

    // MARK: - Public Methods

    /** Loads a user account from a specified file
     - Parameter filePath: The file to load the user account from
     - Returns: The user account
     - Throws: An error if the method fails
     */
    // Note: Cannot be @objc because throwing methods returning Bool are not supported
    @discardableResult
    public func loadUserAccount(fromFile filePath: String, account: AutoreleasingUnsafeMutablePointer<UserAccount?>?) throws -> Bool {
        let userAccount = try self.loadUserAccount(fromFile: filePath)
        account?.pointee = userAccount
        return true
    }

    /** Updates/Saves a user account to a specified filePath
     * - Parameter userAccount: The user account to save
     * - Parameter filePath: The file to save the user account to
     * - Throws: An error if the method fails
     */
    @objc(saveUserAccount:toFile:error:)
    public func save(userAccount: UserAccount, toFile filePath: String) throws {
        guard filePath.count > 0 else {
            let reason = "File path cannot be empty. Could not save the user account to file."
            SFSDKCoreLogger.w(type(of: self), message: reason)
            throw NSError(domain: SFUserAccountManagerErrorDomain,
                          code: SFUserAccountManagerCannotWriteUserData,
                          userInfo: [NSLocalizedDescriptionKey: reason])
        }

        // Serialize the user account data.
        let archiveData = try NSKeyedArchiver.archivedData(withRootObject: userAccount, requiringSecureCoding: true)

        // Encrypt the data.
        guard let encryptionKey = try? SFSDKKeyGenerator.encryptionKey(for: kUserAccountEncryptionKeyLabel),
              let encryptedArchiveData = try? SFSDKEncryptor.encrypt(data: archiveData, using: encryptionKey) else {
            let reason = "User account data could not be encrypted. \(filePath)"
            SFSDKCoreLogger.w(type(of: self), message: reason)
            throw NSError(domain: SFUserAccountManagerErrorDomain,
                          code: SFUserAccountManagerCannotWriteUserData,
                          userInfo: [NSLocalizedDescriptionKey: reason])
        }

        // Save it atomically.
        try encryptedArchiveData.write(to: URL(fileURLWithPath: filePath), options: [.atomic])

        // Let's add the file protection now
        let fileProtection = SFFileProtectionHelper.protection(for: filePath)
        try FileManager.default.setAttributes([.protectionKey: fileProtection], ofItemAtPath: filePath)
    }

    /**
     Returns the path of the user account plist file for the specified user
     - Parameter user: The user
     - Returns: The path to the user account plist of the specified user
     */
    @objc(userAccountPlistFileForUser:)
    public static func userAccountPlistFile(for user: UserAccount) -> String {
        let directory = SFDirectoryManager.sharedManager().directory(forOrg: user.credentials.organizationId, user: user.credentials.userId, community: nil, type: .libraryDirectory, components: nil)
        try? SFDirectoryManager.ensureDirectoryExists(directory)
        return (directory! as NSString).appendingPathComponent(kUserAccountPlistFileName)
    }

    // MARK: - Private Methods

    /** Loads a user account from a specified file
     - Parameter filePath: The file to load the user account from
     - Returns: The user account
     - Throws: An error if the method fails
     */
    private func loadUserAccount(fromFile filePath: String) throws -> UserAccount {
        let manager = FileManager.default
        var reason = "User account data could not be decrypted. Can't load account."

        guard let encryptedUserAccountData = manager.contents(atPath: filePath) else {
            reason = "Could not retrieve user account data from '\(filePath)'"
            SFSDKCoreLogger.d(type(of: self), message: reason)
            throw NSError(domain: SFUserAccountManagerErrorDomain,
                          code: SFUserAccountManagerCannotRetrieveUserData,
                          userInfo: [NSLocalizedDescriptionKey: reason])
        }

        guard let encryptionKey = try? SFSDKKeyGenerator.encryptionKey(for: kUserAccountEncryptionKeyLabel),
              let decryptedArchiveData = try? SFSDKEncryptor.decrypt(data: encryptedUserAccountData, using: encryptionKey) else {
            SFSDKCoreLogger.w(type(of: self), message: reason)
            throw NSError(domain: SFUserAccountManagerErrorDomain,
                          code: SFUserAccountManagerCannotRetrieveUserData,
                          userInfo: [NSLocalizedDescriptionKey: reason])
        }

        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: decryptedArchiveData)
        unarchiver.requiresSecureCoding = true
        guard let decryptedAccount = unarchiver.decodeObject(of: UserAccount.self, forKey: NSKeyedArchiveRootObjectKey) else {
            throw NSError(domain: SFUserAccountManagerErrorDomain,
                          code: SFUserAccountManagerCannotReadDecryptedArchive,
                          userInfo: [NSLocalizedDescriptionKey: reason])
        }
        unarchiver.finishDecoding()

        return decryptedAccount
    }
}
