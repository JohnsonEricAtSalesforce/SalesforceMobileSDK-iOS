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

import Foundation
import CryptoKit
import SalesforceSDKCommon

// MARK: - Constants

public let kUserAccountEncryptionKeyLabel: String = "com.salesforce.userAccount.encryptionKey"
public let kUserAccountPlistFileName: String = "UserAccount.plist"

private let SFUserAccountManagerErrorDomain = "SFUserAccountManager"
private let SFUserAccountManagerCannotReadDecryptedArchive: UInt = 10001
private let SFUserAccountManagerCannotRetrieveUserData: UInt = 10003
private let SFUserAccountManagerCannotWriteUserData: UInt = 10004

// Prefixes for directory structure
private let kOrgPrefix = "00D"
private let kUserPrefix = "005"

/// Default implementation for persisting user accounts to disk (encrypted).
@objc(SFDefaultUserAccountPersister)
@objcMembers public class SFDefaultUserAccountPersister: NSObject, SFUserAccountPersister {

    // MARK: - SFUserAccountPersister Protocol

    @objc public func saveAccount(forUser userAccount: UserAccount) throws {
        let userAccountPlist = SFDefaultUserAccountPersister.userAccountPlistFile(for: userAccount)
        try saveUserAccount(userAccount, toFile: userAccountPlist)
    }

    @objc public func fetchAllAccounts(_ error: AutoreleasingUnsafeMutablePointer<NSError>) -> [UserAccountIdentity: UserAccount] {
        var userAccountMap = [UserAccountIdentity: UserAccount]()

        guard let rootDirectory = SFDirectoryManager.sharedManager.directory(forOrg: nil, user: nil, community: nil, type: .libraryDirectory, components: nil) else {
            return userAccountMap
        }
        let fm = FileManager.default

        guard fm.fileExists(atPath: rootDirectory) else {
            return userAccountMap
        }

        guard let rootContents = try? fm.contentsOfDirectory(atPath: rootDirectory) else {
            let reason = "Unable to enumerate the content at \(rootDirectory)"
            SFSDKCoreLogger.w(type(of: self), format: "%@", reason)
            error.pointee = NSError(domain: SFUserAccountManagerErrorDomain,
                          code: Int(SFUserAccountManagerCannotRetrieveUserData),
                          userInfo: [NSLocalizedDescriptionKey: reason])
            return userAccountMap
        }

        for rootContent in rootContents {
            guard rootContent.hasPrefix(kOrgPrefix) else { continue }
            let rootPath = (rootDirectory as NSString).appendingPathComponent(rootContent)

            guard let orgContents = try? fm.contentsOfDirectory(atPath: rootPath) else {
                SFSDKCoreLogger.d(type(of: self), format: "Unable to enumerate the content at %@", rootPath)
                continue
            }

            for orgContent in orgContents {
                guard orgContent.hasPrefix(kUserPrefix) else { continue }
                let orgPath = (rootPath as NSString).appendingPathComponent(orgContent)
                let userAccountPath = (orgPath as NSString).appendingPathComponent(kUserAccountPlistFileName)

                if fm.fileExists(atPath: userAccountPath) {
                    if let userAccount = try? loadUserAccount(fromFile: userAccountPath) {
                        userAccountMap[userAccount.accountIdentity] = userAccount
                    } else {
                        // Error logging will already have occurred. Remove corrupt file.
                        try? fm.removeItem(atPath: userAccountPath)
                    }
                } else {
                    SFSDKCoreLogger.d(type(of: self), format: "There is no user account file in this user directory: %@", orgPath)
                }
            }
        }
        return userAccountMap
    }

    @objc public func deleteAccount(forUser user: UserAccount) throws {
        let manager = FileManager.default
        guard let userDirectory = SFDirectoryManager.sharedManager.directory(forUser: user, scope: .user, type: .libraryDirectory, components: nil) else {
            let reason = "User folder for user '\(user.idData?.username ?? "")' does not exist on the filesystem"
            SFSDKCoreLogger.d(type(of: self), format: "%@", reason)
            throw NSError(domain: SFUserAccountManagerErrorDomain,
                          code: Int(SFUserAccountManagerCannotReadDecryptedArchive),
                          userInfo: [NSLocalizedDescriptionKey: reason])
        }

        if manager.fileExists(atPath: userDirectory) {
            do {
                try manager.removeItem(atPath: userDirectory)
            } catch {
                SFSDKCoreLogger.d(type(of: self), format: "Error removing the user folder for '%@': %@",
                                  user.idData?.username ?? "", error.localizedDescription)
                throw error
            }
        } else {
            let reason = "User folder for user '\(user.idData?.username ?? "")' does not exist on the filesystem"
            SFSDKCoreLogger.d(type(of: self), format: "%@", reason)
            throw NSError(domain: SFUserAccountManagerErrorDomain,
                          code: Int(SFUserAccountManagerCannotReadDecryptedArchive),
                          userInfo: [NSLocalizedDescriptionKey: reason])
        }
    }

    // MARK: - File Operations

    /// Loads a user account from a specified file.
    @objc public func loadUserAccount(fromFile filePath: String) throws -> UserAccount {
        let fm = FileManager.default
        guard let encryptedUserAccountData = fm.contents(atPath: filePath) else {
            let reason = "Could not retrieve user account data from '\(filePath)'"
            SFSDKCoreLogger.d(type(of: self), format: "%@", reason)
            throw NSError(domain: SFUserAccountManagerErrorDomain,
                          code: Int(SFUserAccountManagerCannotRetrieveUserData),
                          userInfo: [NSLocalizedDescriptionKey: reason])
        }

        guard let encryptionKey = try? KeyGenerator.encryptionKey(for: kUserAccountEncryptionKeyLabel) as SymmetricKey,
              let decryptedArchiveData = try? Encryptor.decrypt(data: encryptedUserAccountData, using: encryptionKey) else {
            let reason = "User account data could not be decrypted. Can't load account."
            SFSDKCoreLogger.w(type(of: self), format: "%@", reason)
            throw NSError(domain: SFUserAccountManagerErrorDomain,
                          code: Int(SFUserAccountManagerCannotRetrieveUserData),
                          userInfo: [NSLocalizedDescriptionKey: reason])
        }

        let unarchiver: NSKeyedUnarchiver
        do {
            unarchiver = try NSKeyedUnarchiver(forReadingFrom: decryptedArchiveData)
        } catch {
            let reason = "User account data could not be decrypted. Can't load account."
            throw NSError(domain: SFUserAccountManagerErrorDomain,
                          code: Int(SFUserAccountManagerCannotReadDecryptedArchive),
                          userInfo: [NSLocalizedDescriptionKey: reason])
        }

        unarchiver.requiresSecureCoding = true
        guard let decryptedAccount = unarchiver.decodeObject(of: UserAccount.self, forKey: NSKeyedArchiveRootObjectKey) else {
            unarchiver.finishDecoding()
            let reason = "User account data could not be decrypted. Can't load account."
            throw NSError(domain: SFUserAccountManagerErrorDomain,
                          code: Int(SFUserAccountManagerCannotReadDecryptedArchive),
                          userInfo: [NSLocalizedDescriptionKey: reason])
        }
        unarchiver.finishDecoding()
        return decryptedAccount
    }

    /// Updates/Saves a user account to a specified filePath.
    @objc public func saveUserAccount(_ userAccount: UserAccount, toFile filePath: String) throws {
        guard filePath.count > 0 else {
            let reason = "File path cannot be empty. Could not save the user account to file."
            SFSDKCoreLogger.w(type(of: self), format: "%@", reason)
            throw NSError(domain: SFUserAccountManagerErrorDomain,
                          code: Int(SFUserAccountManagerCannotWriteUserData),
                          userInfo: [NSLocalizedDescriptionKey: reason])
        }

        // Serialize the user account data.
        guard let archiveData = try? NSKeyedArchiver.archivedData(withRootObject: userAccount, requiringSecureCoding: true) else {
            let reason = "Could not archive user account data to save it. \(filePath)"
            SFSDKCoreLogger.w(type(of: self), format: "%@", reason)
            throw NSError(domain: SFUserAccountManagerErrorDomain,
                          code: Int(SFUserAccountManagerCannotWriteUserData),
                          userInfo: [NSLocalizedDescriptionKey: reason])
        }

        // Encrypt the data.
        guard let encryptionKey = try? KeyGenerator.encryptionKey(for: kUserAccountEncryptionKeyLabel) as SymmetricKey,
              let encryptedArchiveData = try? Encryptor.encrypt(data: archiveData, using: encryptionKey) else {
            let reason = "User account data could not be encrypted. \(filePath)"
            SFSDKCoreLogger.w(type(of: self), format: "%@", reason)
            throw NSError(domain: SFUserAccountManagerErrorDomain,
                          code: Int(SFUserAccountManagerCannotWriteUserData),
                          userInfo: [NSLocalizedDescriptionKey: reason])
        }

        // Save it atomically.
        let saveSuccess = (encryptedArchiveData as NSData).write(toFile: filePath, atomically: true)
        guard saveSuccess else {
            let reason = "Could not create user account data file at path. \(filePath)"
            SFSDKCoreLogger.w(type(of: self), format: "%@", reason)
            throw NSError(domain: SFUserAccountManagerErrorDomain,
                          code: Int(SFUserAccountManagerCannotWriteUserData),
                          userInfo: [NSLocalizedDescriptionKey: reason])
        }

        // Add file protection.
        let fileProtection = FileProtectionHelper.protection(for: filePath)
        try? FileManager.default.setAttributes([.protectionKey: fileProtection], ofItemAtPath: filePath)
    }

    // MARK: - Class Methods

    /// Returns the path of the user account plist file for the specified user.
    @objc public class func userAccountPlistFile(for user: UserAccount) -> String {
        guard let directory = SFDirectoryManager.sharedManager.directory(forOrg: user.credentials.organizationId, user: user.credentials.userId, community: nil, type: .libraryDirectory, components: nil) else {
            return kUserAccountPlistFileName
        }
        SFDirectoryManager.ensureDirectoryExists(directory, error: nil)
        return (directory as NSString).appendingPathComponent(kUserAccountPlistFileName)
    }

    /// Returns the path of the user account plist file for the specified user identity.
    @objc public class func userAccountPlistFile(forUserId userAccountIdentity: UserAccountIdentity) -> String {
        guard let directory = SFDirectoryManager.sharedManager.directory(forOrg: userAccountIdentity.orgId, user: userAccountIdentity.userId, community: nil, type: .libraryDirectory, components: nil) else {
            return kUserAccountPlistFileName
        }
        SFDirectoryManager.ensureDirectoryExists(directory, error: nil)
        return (directory as NSString).appendingPathComponent(kUserAccountPlistFileName)
    }
}
