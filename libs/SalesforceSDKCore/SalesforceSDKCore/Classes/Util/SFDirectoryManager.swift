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

/**
 Global directory manager that returns scoped directory. The scoping is enforced
 by taking into account the organizationId, the userId and the communityId.

 The general structure follows this general template:
 <NSSearchPathDirectory> <-- For example, NSCachesDirectory will return Library/Caches
    <bundleIdentifier>   <-- For example, com.salesforce.chatter
        <orgId>
            <userId>
                <internal> : internal community or base org
                [<communityId>]* : zero or more community specific folder
 */
@objc(SFDirectoryManager)
public class SFDirectoryManager: NSObject {

    @objc
    public static let defaultCommunityName = "internal"

    private static let defaultOrgName = "org"
    private static let sharedLibraryLocation = "Library"
    private static let filesSharedKey = "filesShared"
    private static let directoryManagerErrorDomain = "com.salesforce.mobilesdk.DirectoryManager.ErrorDomain"

    // Prefix of an org ID
    private static let orgPrefix = "00D"

    // Prefix of a user ID
    private static let userPrefix = "005"

    /**
     Returns the singleton of this manager
     */
    @objc
    public static func sharedManager() -> SFDirectoryManager {
        return shared
    }

    @objc
    public static let shared: SFDirectoryManager = {
        return SFDirectoryManager()
    }()

    private override init() {
        super.init()
        migrateFiles()
    }

    /**
     Ensures the specified directory exists on the disk.
     @param directory The directory to ensure exists.
     @param error The error on output or nil if no error is desired
     @return YES if the directory exists or has been successfully created, NO otherwise.
     */
    @objc
    public static func ensureDirectoryExists(_ directory: String?) throws {
        guard let directory = directory else {
            throw NSError(domain: SFDirectoryManager.directoryManagerErrorDomain, code: 101, userInfo: [NSLocalizedDescriptionKey: "Directory path is nil"])
        }

        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        let fileExists = fileManager.fileExists(atPath: directory, isDirectory: &isDirectory)

        if !fileExists {
            let attributes: [FileAttributeKey: Any] = [.protectionKey: SFFileProtectionHelper.protection(for: directory)]
            try fileManager.createDirectory(atPath: directory, withIntermediateDirectories: true, attributes: attributes)
        } else if fileExists && !isDirectory.boolValue {
            throw NSError(domain: SFDirectoryManager.directoryManagerErrorDomain, code: 100, userInfo: [NSLocalizedDescriptionKey: "File exists at path and is not a directory"])
        }
    }

    /**
     Ensure the specified string contains only characters that can be
     safely used to identify a path on the disk.
     @param candidate The string to be checked for compatibility.
     */
    @objc
    public static func safeStringForDiskRepresentation(_ candidate: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:@")
        return candidate.components(separatedBy: invalidCharacters).joined(separator: "_")
    }

    /**
     Returns the path to the directory type for the specified org, user and community.
     @param orgId The organization ID. If nil, this method returns the global directory type requested (eg Library/Caches)
     @param userId The user ID. If nil, this method returns the directory type requested, scoped at the org level (eg Library/Caches/<orgId>/)
     @param communityId The community ID. If nil, this method returns the directory type requested, scoped at the user level (eg Library/Caches/<orgId>/<userId>)
     @param type The type of directory to return (see NSSearchPathDirectory)
     @param components The additional path components to be added at the end of the directory (eg ['mybundle', 'common'])
     @return The path to the directory
     */
    @objc
    public func directory(forOrg orgId: String?, user userId: String?, community communityId: String?, type: FileManager.SearchPathDirectory, components: [String]?) -> String? {
        var directory: String?

        if SFSDKDatasharingHelper.shared.isAppGroupEnabled,
           let appGroupName = SFSDKDatasharingHelper.shared.appGroupName,
           let sharedURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName) {
            directory = sharedURL.path
            directory = (directory! as NSString).appendingPathComponent(appGroupName)
            if type == .libraryDirectory {
                directory = (directory! as NSString).appendingPathComponent(SFDirectoryManager.sharedLibraryLocation)
            }
        } else {
            let directories = NSSearchPathForDirectoriesInDomains(type, .userDomainMask, true)
            if !directories.isEmpty, let bundleIdentifier = Bundle.main.bundleIdentifier {
                directory = (directories[0] as NSString).appendingPathComponent(bundleIdentifier)
            }
        }

        if var directory = directory {
            if let orgId = orgId {
                directory = (directory as NSString).appendingPathComponent(SFDirectoryManager.safeStringForDiskRepresentation(orgId))
                if let userId = userId {
                    directory = (directory as NSString).appendingPathComponent(SFDirectoryManager.safeStringForDiskRepresentation(userId))
                    if let communityId = communityId {
                        directory = (directory as NSString).appendingPathComponent(SFDirectoryManager.safeStringForDiskRepresentation(communityId))
                    }
                }
            }

            if let components = components {
                for component in components {
                    directory = (directory as NSString).appendingPathComponent(component)
                }
            }

            return directory
        } else {
            return nil
        }
    }

    /**
     Returns the path to the directory type for the specified user and scope
     @param user The user account to use. If nil, the path returned corresponds to the global path type
     @param scope The scope to use
     @param type The type of directory to return (see NSSearchPathDirectory)
     @param components The additional path components to be added at the end of the directory (eg ['mybundle', 'common'])
     @return The path to the directory
     */
    @objc
    public func directory(forUser user: UserAccount?, scope: UserAccount.AccountScope, type: FileManager.SearchPathDirectory, components: [String]?) -> String? {
        if user?.credentials.organizationId == nil && scope != .global {
            return nil
        }

        switch scope {
        case .global:
            return directory(forOrg: nil, user: nil, community: nil, type: type, components: components)

        case .org:
            return directory(forOrg: user?.credentials.organizationId, user: nil, community: nil, type: type, components: components)

        case .user:
            return directory(forOrg: user?.credentials.organizationId, user: user?.credentials.userId, community: nil, type: type, components: components)

        case .community:
            // Note: if the user communityId is nil, we use the default (internal) name for it.
            return directory(forOrg: user?.credentials.organizationId, user: user?.credentials.userId, community: user?.credentials.communityId ?? SFDirectoryManager.defaultCommunityName, type: type, components: components)

        @unknown default:
            return nil
        }
    }

    /**
     Returns the path to the directory type for the specified user.
     @param account The user account to use. If nil, the path returned corresponds to the global path type
     @param type The type of directory to return (see NSSearchPathDirectory)
     @param components The additional path components to be added at the end of the directory (eg ['mybundle', 'common'])
     @return The path to the directory
     */
    @objc
    public func directory(forUser account: UserAccount?, type: FileManager.SearchPathDirectory, components: [String]?) -> String? {
        if let account = account {
            if account.credentials.organizationId == nil || account.credentials.userId == nil {
                SFSDKCoreLogger.w(SFDirectoryManager.self, message: "Credentials missing for user")
                return nil
            }
            // Note: if the user communityId is nil, we use the default (internal) name for it.
            return directory(forOrg: account.credentials.organizationId, user: account.credentials.userId, community: account.credentials.communityId ?? SFDirectoryManager.defaultCommunityName, type: type, components: components)
        } else {
            return globalDirectory(ofType: type, components: components)
        }
    }

    /**
     Returns the path to the directory type for the current user and current community.
     @param type The type of directory to return (see NSSearchPathDirectory)
     @param components The additional path components to be added at the end of the directory (eg ['mybundle', 'common'])
     @return The path to the directory
     */
    @objc
    public func directoryOfCurrentUser(forType type: FileManager.SearchPathDirectory, components: [String]?) -> String? {
        return directory(forUser: UserAccountManager.shared.currentUserAccount, type: type, components: components)
    }

    /**
     Returns the path to the global directory of the specified type. For example, NSCachesDirectory will
     return "Library/Caches/<bundleIdentifier>/"
     @param type The type of directory to return (see NSSearchPathDirectory)
     @param components The additional path components to be added at the end of the directory (eg ['mybundle', 'common'])
     @return The path to the directory
     */
    @objc
    public func globalDirectory(ofType type: FileManager.SearchPathDirectory, components: [String]?) -> String? {
        return directory(forOrg: nil, user: nil, community: nil, type: type, components: components)
    }

    // MARK: - File Migration Methods

    private func moveContentsOfDirectory(_ sourceDirectory: String, toDirectory destinationDirectory: String) {
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: sourceDirectory) else {
            return
        }

        do {
            try SFDirectoryManager.ensureDirectoryExists(destinationDirectory)

            let rootContents = try fileManager.contentsOfDirectory(atPath: sourceDirectory)

            for item in rootContents {
                let newFilePath = (destinationDirectory as NSString).appendingPathComponent(item)
                let oldFilePath = (sourceDirectory as NSString).appendingPathComponent(item)

                if !fileManager.fileExists(atPath: newFilePath) {
                    // File does not exist, copy it.
                    try fileManager.moveItem(atPath: oldFilePath, toPath: newFilePath)
                } else {
                    try? fileManager.removeItem(atPath: newFilePath)
                    try fileManager.moveItem(atPath: oldFilePath, toPath: newFilePath)
                }
            }
        } catch {
            SFSDKCoreLogger.e(type(of: self), message: "Could not move library directory contents: \(error)")
        }
    }

    private func migrateFiles() {
        let sharedDefaults = UserDefaults(suiteName: SFSDKDatasharingHelper.shared.appGroupName)
        let isGroupAccessEnabled = SFSDKDatasharingHelper.shared.isAppGroupEnabled
        let filesShared = sharedDefaults?.bool(forKey: SFDirectoryManager.filesSharedKey) ?? false

        let fileManager = FileManager.default
        var docDirectory: String?
        var libDirectory: String?

        let directories = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        let libDirectories = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)

        if !directories.isEmpty, let bundleIdentifier = Bundle.main.bundleIdentifier {
            docDirectory = (directories[0] as NSString).appendingPathComponent(bundleIdentifier)
        }

        if !libDirectories.isEmpty, let bundleIdentifier = Bundle.main.bundleIdentifier {
            libDirectory = (libDirectories[0] as NSString).appendingPathComponent(bundleIdentifier)
        }

        if isGroupAccessEnabled || filesShared {
            guard let appGroupName = SFSDKDatasharingHelper.shared.appGroupName,
                  let sharedURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupName) else {
                return
            }

            var sharedDirectory = sharedURL.path
            sharedDirectory = (sharedDirectory as NSString).appendingPathComponent(appGroupName)
            let sharedLibDirectory = (sharedDirectory as NSString).appendingPathComponent(SFDirectoryManager.sharedLibraryLocation)

            if isGroupAccessEnabled && !filesShared {
                // move files from Docs to the Shared & App Libs to Shared,Shared Library location
                if let libDirectory = libDirectory {
                    moveContentsOfDirectory(libDirectory, toDirectory: sharedLibDirectory)
                }
                if let docDirectory = docDirectory {
                    moveContentsOfDirectory(docDirectory, toDirectory: sharedDirectory)
                }
                sharedDefaults?.set(true, forKey: SFDirectoryManager.filesSharedKey)
            } else if !isGroupAccessEnabled && filesShared {
                // move files back from Shared Location to Library and the Docs
                if let libDirectory = libDirectory {
                    moveContentsOfDirectory(sharedLibDirectory, toDirectory: libDirectory)
                }
                if let docDirectory = docDirectory {
                    moveContentsOfDirectory(sharedDirectory, toDirectory: docDirectory)
                }
                sharedDefaults?.set(false, forKey: SFDirectoryManager.filesSharedKey)
            }
        }

        sharedDefaults?.synchronize()
    }

    // MARK: - Internal Methods

    // Starting in SDK 8.2, 18 character IDs are used instead of 15 character IDs.
    // This renames 15 character user ID directories to 18 characters.
    // TODO: Remove in Mobile SDK 10.0
    @objc
    public static func upgradeUserDirectories() {
        upgradeUserDirectory(.libraryDirectory)
        upgradeUserDirectory(.documentDirectory)
    }

    private static func upgradeUserDirectory(_ type: FileManager.SearchPathDirectory) {
        guard let rootDirectory = SFDirectoryManager.sharedManager().directory(forOrg: nil, user: nil, community: nil, type: type, components: nil) else {
            return
        }

        let fm = FileManager.default

        guard fm.fileExists(atPath: rootDirectory) else {
            return
        }

        do {
            let rootContents = try fm.contentsOfDirectory(atPath: rootDirectory)

            for rootContent in rootContents {
                if !rootContent.hasPrefix(orgPrefix) {
                    continue
                }

                let rootPath = (rootDirectory as NSString).appendingPathComponent(rootContent)
                let orgContents = try fm.contentsOfDirectory(atPath: rootPath)

                for orgContent in orgContents {
                    if orgContent.hasPrefix(userPrefix) && orgContent.count == 15 {
                        let orgPath = (rootPath as NSString).appendingPathComponent(orgContent)
                        let newDirectory = (orgContent as NSString).sfsdk_entityId18 ?? orgContent
                        let newPath = (rootPath as NSString).appendingPathComponent(newDirectory)

                        if !fm.fileExists(atPath: newPath) {
                            // File does not exist, copy it.
                            try fm.moveItem(atPath: orgPath, toPath: newPath)
                        } else {
                            try? fm.removeItem(atPath: newPath)
                            try fm.moveItem(atPath: orgPath, toPath: newPath)
                        }
                    }
                }
            }
        } catch {
            SFSDKCoreLogger.e(SFDirectoryManager.self, message: "Error during directory upgrade: \(error)")
        }
    }
}
