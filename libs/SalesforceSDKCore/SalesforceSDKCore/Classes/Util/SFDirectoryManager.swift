// Copyright (c) 2012-present, salesforce.com, inc. All rights reserved.
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
import SalesforceSDKCommon

/// Global directory manager that returns scoped directories. The scoping is enforced
/// by taking into account the organizationId, the userId, and the communityId.
@objc(SFDirectoryManager)
@objcMembers public class SFDirectoryManager: NSObject {

    @objc public static let defaultCommunityName = "internal"

    private static let kDefaultOrgName = "org"
    private static let kSharedLibraryLocation = "Library"
    private static let kFilesSharedKey = "filesShared"
    private static let kDirectoryManagerErrorDomain = "com.salesforce.mobilesdk.DirectoryManager.ErrorDomain"

    // Prefix of an org ID
    private static let kOrgPrefix = "00D"
    // Prefix of a user ID
    private static let kUserPrefix = "005"

    @objc public static let sharedManager: SFDirectoryManager = {
        let manager = SFDirectoryManager()
        return manager
    }()

    override init() {
        super.init()
        migrateFiles()
    }

    // MARK: - Public Methods

    @objc @discardableResult public class func ensureDirectoryExists(_ directory: String?, error: NSErrorPointer) -> Bool {
        guard let directory = directory else { return false }
        let manager = FileManager.default
        var isDirectory: ObjCBool = false
        let fileExists = manager.fileExists(atPath: directory, isDirectory: &isDirectory)
        if !fileExists {
            do {
                try manager.createDirectory(atPath: directory, withIntermediateDirectories: true, attributes: [.protectionKey: FileProtectionHelper.protection(for: directory)])
                return true
            } catch let createError {
                error?.pointee = createError as NSError
                return false
            }
        } else if fileExists && !isDirectory.boolValue {
            error?.pointee = NSError(domain: SFDirectoryManager.kDirectoryManagerErrorDomain, code: 100, userInfo: [NSLocalizedDescriptionKey: "File exists at path and is not a directory"])
            return false
        } else {
            return true
        }
    }

    @objc public class func safeStringForDiskRepresentation(_ candidate: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:@")
        return candidate.components(separatedBy: invalidCharacters).joined(separator: "_")
    }

    @objc public func directory(forOrg orgId: String?, user userId: String?, community communityId: String?, type: FileManager.SearchPathDirectory, components: [String]?) -> String? {
        var directory: String?

        if SFSDKDatasharingHelper.sharedInstance.appGroupEnabled, let appGroupName = SFSDKDatasharingHelper.sharedInstance.appGroupName {
            if let sharedURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName) {
                directory = sharedURL.path
                directory = (directory as NSString?)?.appendingPathComponent(appGroupName)
                if type == .libraryDirectory {
                    directory = (directory as NSString?)?.appendingPathComponent(SFDirectoryManager.kSharedLibraryLocation)
                }
            }
        } else {
            let directories = NSSearchPathForDirectoriesInDomains(type, .userDomainMask, true)
            if directories.count > 0 {
                if let bundleId = Bundle.main.bundleIdentifier {
                    directory = (directories[0] as NSString).appendingPathComponent(bundleId)
                }
            }
        }

        guard var dir = directory else { return nil }

        if let orgId = orgId {
            dir = (dir as NSString).appendingPathComponent(SFDirectoryManager.safeStringForDiskRepresentation(orgId))
            if let userId = userId {
                dir = (dir as NSString).appendingPathComponent(SFDirectoryManager.safeStringForDiskRepresentation(userId))
                if let communityId = communityId {
                    dir = (dir as NSString).appendingPathComponent(SFDirectoryManager.safeStringForDiskRepresentation(communityId))
                }
            }
        }

        if let components = components {
            for component in components {
                dir = (dir as NSString).appendingPathComponent(component)
            }
        }

        return dir
    }

    @objc public func directory(forUser user: UserAccount, scope: UserAccount.AccountScope, type: FileManager.SearchPathDirectory, components: [String]?) -> String? {
        if user.credentials.organizationId == nil && scope != .global {
            return nil
        }

        switch scope {
        case .global:
            return directory(forOrg: nil, user: nil, community: nil, type: type, components: components)
        case .org:
            return directory(forOrg: user.credentials.organizationId, user: nil, community: nil, type: type, components: components)
        case .user:
            return directory(forOrg: user.credentials.organizationId, user: user.credentials.userId, community: nil, type: type, components: components)
        case .community:
            let communityId = user.credentials.communityId ?? SFDirectoryManager.defaultCommunityName
            return directory(forOrg: user.credentials.organizationId, user: user.credentials.userId, community: communityId, type: type, components: components)
        @unknown default:
            return nil
        }
    }

    @objc public func directory(forUser account: UserAccount?, type: FileManager.SearchPathDirectory, components: [String]?) -> String? {
        if let user = account {
            guard user.credentials.organizationId != nil, user.credentials.userId != nil else {
                SFSDKCoreLogger.w(SFDirectoryManager.self, message: "Credentials missing for user")
                return nil
            }
            let communityId = user.credentials.communityId ?? SFDirectoryManager.defaultCommunityName
            return directory(forOrg: user.credentials.organizationId, user: user.credentials.userId, community: communityId, type: type, components: components)
        } else {
            return globalDirectory(ofType: type, components: components)
        }
    }

    @objc public func directoryOfCurrentUser(forType type: FileManager.SearchPathDirectory, components: [String]?) -> String? {
        return directory(forUser: UserAccountManager.shared.currentUserAccount, type: type, components: components)
    }

    @objc public func globalDirectory(ofType type: FileManager.SearchPathDirectory, components: [String]?) -> String? {
        return directory(forOrg: nil, user: nil, community: nil, type: type, components: components)
    }

    // MARK: - File Migration

    private func moveContents(ofDirectory sourceDirectory: String?, toDirectory destinationDirectory: String?) {
        let fileManager = FileManager.default
        guard let sourceDirectory = sourceDirectory, fileManager.fileExists(atPath: sourceDirectory) else { return }
        guard let destinationDirectory = destinationDirectory else { return }

        SFDirectoryManager.ensureDirectoryExists(destinationDirectory, error: nil)

        do {
            let rootContents = try fileManager.contentsOfDirectory(atPath: sourceDirectory)
            for item in rootContents {
                let newFilePath = (destinationDirectory as NSString).appendingPathComponent(item)
                let oldFilePath = (sourceDirectory as NSString).appendingPathComponent(item)
                if !fileManager.fileExists(atPath: newFilePath) {
                    do {
                        try fileManager.moveItem(atPath: oldFilePath, toPath: newFilePath)
                    } catch {
                        SFSDKCoreLogger.e(SFDirectoryManager.self, message: "Could not move library directory contents to a shared location for app group access: \(error)")
                    }
                } else {
                    try? fileManager.removeItem(atPath: newFilePath)
                    try? fileManager.moveItem(atPath: oldFilePath, toPath: newFilePath)
                }
            }
        } catch {
            SFSDKCoreLogger.d(SFDirectoryManager.self, message: "Unable to enumerate the content at \(sourceDirectory): \(error)")
        }
    }

    private func migrateFiles() {
        let sharedDefaults = UserDefaults(suiteName: SFSDKDatasharingHelper.sharedInstance.appGroupName)
        let isGroupAccessEnabled = SFSDKDatasharingHelper.sharedInstance.appGroupEnabled
        let filesShared = sharedDefaults?.bool(forKey: SFDirectoryManager.kFilesSharedKey) ?? false

        let fileManager = FileManager.default
        var docDirectory: String?
        var libDirectory: String?

        let docDirectories = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        let libDirectories = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)

        if docDirectories.count > 0, let bundleId = Bundle.main.bundleIdentifier {
            docDirectory = (docDirectories[0] as NSString).appendingPathComponent(bundleId)
        }

        if libDirectories.count > 0, let bundleId = Bundle.main.bundleIdentifier {
            libDirectory = (libDirectories[0] as NSString).appendingPathComponent(bundleId)
        }

        if isGroupAccessEnabled || filesShared, let appGroupName = SFSDKDatasharingHelper.sharedInstance.appGroupName {
            if let sharedURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupName) {
                var sharedDirectory = sharedURL.path
                sharedDirectory = (sharedDirectory as NSString).appendingPathComponent(appGroupName)
                let sharedLibDirectory = (sharedDirectory as NSString).appendingPathComponent(SFDirectoryManager.kSharedLibraryLocation)

                if isGroupAccessEnabled && !filesShared {
                    moveContents(ofDirectory: libDirectory, toDirectory: sharedLibDirectory)
                    moveContents(ofDirectory: docDirectory, toDirectory: sharedDirectory)
                    sharedDefaults?.set(true, forKey: SFDirectoryManager.kFilesSharedKey)
                } else if !isGroupAccessEnabled && filesShared {
                    moveContents(ofDirectory: sharedLibDirectory, toDirectory: libDirectory)
                    moveContents(ofDirectory: sharedDirectory, toDirectory: docDirectory)
                    sharedDefaults?.set(false, forKey: SFDirectoryManager.kFilesSharedKey)
                }
            }
        }

        sharedDefaults?.synchronize()
    }

    // MARK: - User Directory Upgrade

    @objc public class func upgradeUserDirectories() {
        upgradeUserDirectory(.libraryDirectory)
        upgradeUserDirectory(.documentDirectory)
    }

    private class func upgradeUserDirectory(_ type: FileManager.SearchPathDirectory) {
        guard let rootDirectory = SFDirectoryManager.sharedManager.directory(forOrg: nil, user: nil, community: nil, type: type, components: nil) else { return }
        let fm = FileManager.default

        guard fm.fileExists(atPath: rootDirectory) else { return }

        do {
            let rootContents = try fm.contentsOfDirectory(atPath: rootDirectory)
            for rootContent in rootContents {
                guard rootContent.hasPrefix(kOrgPrefix) else { continue }
                let rootPath = (rootDirectory as NSString).appendingPathComponent(rootContent)

                do {
                    let orgContents = try fm.contentsOfDirectory(atPath: rootPath)
                    for orgContent in orgContents {
                        if orgContent.hasPrefix(kUserPrefix) && orgContent.count == 15 {
                            let orgPath = (rootPath as NSString).appendingPathComponent(orgContent)
                            guard let newDirectory = (orgContent as NSString).sfsdk_entityId18() else { continue }
                            let newPath = (rootPath as NSString).appendingPathComponent(newDirectory)
                            if !fm.fileExists(atPath: newPath) {
                                do {
                                    try fm.moveItem(atPath: orgPath, toPath: newPath)
                                } catch {
                                    SFSDKCoreLogger.e(SFDirectoryManager.self, message: "Existing Files does not exist, Error moving \(orgPath) to \(newPath): \(error)")
                                }
                            } else {
                                do {
                                    try fm.removeItem(atPath: newPath)
                                } catch {
                                    SFSDKCoreLogger.e(SFDirectoryManager.self, message: "Existing Files exist, Error removing \(orgPath) to \(newPath): \(error)")
                                }
                                do {
                                    try fm.moveItem(atPath: orgPath, toPath: newPath)
                                } catch {
                                    SFSDKCoreLogger.e(SFDirectoryManager.self, message: "Error moving \(orgPath) to \(newPath) after removing existing files: \(error)")
                                }
                            }
                        }
                    }
                } catch {
                    SFSDKCoreLogger.d(SFDirectoryManager.self, message: "Error retreiving contents of \(rootPath): \(error)")
                }
            }
        } catch {
            SFSDKCoreLogger.d(SFDirectoryManager.self, message: "Error retreiving contents of \(rootDirectory): \(error)")
        }
    }
}
