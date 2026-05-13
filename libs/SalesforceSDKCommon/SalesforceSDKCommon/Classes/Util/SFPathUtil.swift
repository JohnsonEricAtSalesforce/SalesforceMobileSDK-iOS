/*
 Copyright (c) 2015-present, salesforce.com, inc. All rights reserved.

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

/// This is a utility class that helps to create sub folder under either Documents directory or cache directory.
/// Any folder or file created by SFPathUtil will be marked with NSFileProtectionCompleteUntilFirstUserAuthentication
/// attribute and also excluded from iCloud backup
@objc(SFPathUtil)
@objcMembers
public class SFPathUtil: NSObject {

    /// Returns application's document directory
    @objc
    public static func applicationDocumentDirectory() -> String {
        return NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).last ?? ""
    }

    /// Returns application's cache directory
    @objc
    public static func applicationCacheDirectory() -> String {
        return NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).last ?? ""
    }

    /// Returns the absolute path for library folder
    @objc
    public static func applicationLibraryDirectory() -> String {
        return NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).last ?? ""
    }

    /// Returns the absolute path for a directory/folder located in the apps document directory.
    ///
    /// It also ensures this sub-directory exists, applies NSFileProtectionCompleteUntilFirstUserAuthentication protection attributes
    /// and also mark file to be not backup by iCloud
    /// Folder created will be protected by NSFileProtectionCompleteUntilFirstUserAuthentication.
    ///
    /// - Parameter folder: Folder to create under Document directory
    @objc(absolutePathForDocumentFolder:)
    public static func absolutePath(forDocumentFolder folder: String) -> String {
        return absolutePath(forDocumentFolder: folder, fileProtection: nil)
    }

    /// Returns the absolute path for a directory/folder located in the apps document directory
    ///
    /// It also ensures this sub-directory exists, applies NSFileProtectionCompleteUntilFirstUserAuthentication protection attributes
    /// and also mark file to be not backup by iCloud
    ///
    /// - Parameters:
    ///   - folder: Folder to create under Document directory
    ///   - fileProtection: File protection string. If nil, NSFileProtectionCompleteUntilFirstUserAuthentication will be used
    @objc(absolutePathForDocumentFolder:fileProtection:)
    public static func absolutePath(forDocumentFolder folder: String, fileProtection: FileProtectionType?) -> String {
        let rootPath = applicationDocumentDirectory()
        let path = (rootPath as NSString).appendingPathComponent(folder)
        createFileItem(ifNotExist: path, skipBackup: true, fileProtection: fileProtection)
        return path
    }

    /// Returns the absolute path for a directory/folder located in the apps document directory
    ///
    /// It also ensures this sub-directory exists, applies file protection attributes
    /// and also mark file to be not backup by iCloud
    /// Folder created will be protected by NSFileProtectionCompleteUntilFirstUserAuthentication
    ///
    /// - Parameter folder: Folder to create under Cache directory
    @objc(absolutePathForCacheFolder:)
    public static func absolutePath(forCacheFolder folder: String) -> String {
        return absolutePath(forCacheFolder: folder, fileProtection: nil)
    }

    /// Returns the absolute path for a directory/folder located in the apps document directory
    ///
    /// It also ensures this sub-directory exists, applies file protection attributes
    /// and also mark file to be not backup by iCloud
    /// - Parameters:
    ///   - folder: Folder to create under Cache directory
    ///   - fileProtection: File protection string. If nil, NSFileProtectionCompleteUntilFirstUserAuthentication will be used
    @objc(absolutePathForCacheFolder:fileProtection:)
    public static func absolutePath(forCacheFolder folder: String, fileProtection: FileProtectionType?) -> String {
        let rootPath = applicationCacheDirectory()
        let path = (rootPath as NSString).appendingPathComponent(folder)
        createFileItem(ifNotExist: path, skipBackup: true, fileProtection: fileProtection)
        return path
    }

    /// Returns the absolute path for library folder
    ///
    /// It also ensures this sub-directory exists, applies file protection attributes
    /// and also mark file to be not backup by iCloud
    /// Folder created will be protected by NSFileProtectionCompleteUntilFirstUserAuthentication
    ///
    /// - Parameter folder: Folder to create under Library directory
    @objc(absolutePathForLibraryFolder:)
    public static func absolutePath(forLibraryFolder folder: String) -> String {
        return absolutePath(forLibraryFolder: folder, fileProtection: nil)
    }

    /// Returns the absolute path for library folder
    ///
    /// It also ensures this sub-directory exists, applies file protection attributes
    /// and also mark file to be not backup by iCloud
    /// - Parameters:
    ///   - folder: Folder to create under Library directory
    ///   - fileProtection: File protection string. If nil, NSFileProtectionCompleteUntilFirstUserAuthentication will be used
    @objc(absolutePathForLibraryFolder:fileProtection:)
    public static func absolutePath(forLibraryFolder folder: String, fileProtection: FileProtectionType?) -> String {
        let rootPath = applicationLibraryDirectory()
        let path = (rootPath as NSString).appendingPathComponent(folder)
        createFileItem(ifNotExist: path, skipBackup: true, fileProtection: fileProtection)
        return path
    }

    /// Creates the file at the specified path if it doesn't exist
    /// - Parameters:
    ///   - path: The path where the file should be created
    ///   - skipBackup: YES if the file should be marked to not be backed up with iCloud
    @objc(createFileItemIfNotExist:skipBackup:)
    public static func createFileItem(ifNotExist path: String, skipBackup: Bool) {
        createFileItem(ifNotExist: path, skipBackup: skipBackup, fileProtection: nil)
    }

    /// Add iOS file protection to the specified file path and also mark DO NOT back up by iCloud if notbackupFlag is true
    /// The file or path that is passed in must already exist
    ///
    /// - Parameters:
    ///   - filePath: Path to file or folder
    ///   - notbackupFlag: Set to YES if need to mark as do not back up by iCloud
    @objc(secureFilePath:markAsNotBackup:)
    public static func secureFilePath(_ filePath: String, markAsNotBackup notbackupFlag: Bool) {
        secureFilePath(filePath, markAsNotBackup: notbackupFlag, fileProtection: nil)
    }

    /// Add iOS file protection to the specified file path and also mark DO NOT back up by iCloud if notbackupFlag is true
    /// The file or path that is passed in must already exist
    ///
    /// - Parameters:
    ///   - filePath: Path to file or folder
    ///   - notbackupFlag: Set to YES if need to mark as do not back up by iCloud
    ///   - fileProtection: File protection string. If nil, NSFileProtectionCompleteUntilFirstUserAuthentication will be used
    @objc(secureFilePath:markAsNotBackup:fileProtection:)
    public static func secureFilePath(_ filePath: String, markAsNotBackup notbackupFlag: Bool, fileProtection: FileProtectionType?) {
        let protection = fileProtection ?? SFFileProtectionHelper.protection(for: filePath)
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: filePath) else {
            return
        }

        do {
            if let attrs = try? fileManager.attributesOfItem(atPath: filePath),
               let currentProtection = attrs[.protectionKey] as? FileProtectionType,
               currentProtection != protection {
                try fileManager.setAttributes([.protectionKey: protection], ofItemAtPath: filePath)
            } else if (try? fileManager.attributesOfItem(atPath: filePath)) != nil {
                try fileManager.setAttributes([.protectionKey: protection], ofItemAtPath: filePath)
            }
        } catch {
            // Silently ignore errors as per original implementation
        }

        if notbackupFlag {
            addSkipBackupAttribute(to: filePath)
        }
    }

    /// Add DO NOT back up flag to the file resource specified by the file path
    ///
    /// - Parameters:
    ///   - filePath: file path
    ///   - recursive: If filePath points to a directory, set to YES to recursively apply skip backup attribute to all files under the directory including sub-directory under the directory
    ///   - fileProtection: File protection string. If nil, NSFileProtectionCompleteUntilFirstUserAuthentication will be used
    @objc(secureFileAtPath:recursive:fileProtection:)
    public static func secureFile(atPath filePath: String, recursive: Bool, fileProtection: FileProtectionType?) {
        guard !filePath.isEmpty else {
            return
        }

        secureFilePath(filePath, markAsNotBackup: true, fileProtection: fileProtection)

        guard recursive else {
            return
        }

        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(atPath: filePath, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return
        }

        if let directoryContents = try? fileManager.contentsOfDirectory(atPath: filePath) {
            for item in directoryContents {
                let fileFullPath = (filePath as NSString).appendingPathComponent(item)
                secureFile(atPath: fileFullPath, recursive: recursive, fileProtection: fileProtection)
            }
        }
    }

    // MARK: - Private Methods

    private static func createFileItem(ifNotExist path: String, skipBackup: Bool, fileProtection: FileProtectionType?) {
        guard !path.isEmpty else {
            return
        }

        let protection = fileProtection ?? SFFileProtectionHelper.protection(for: path)
        let fileManager = FileManager.default

        if !fileManager.fileExists(atPath: path) {
            try? fileManager.createDirectory(
                atPath: path,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: protection]
            )
        } else {
            // Update attributes
            try? fileManager.setAttributes(
                [.protectionKey: protection],
                ofItemAtPath: path
            )
        }

        if skipBackup {
            addSkipBackupAttribute(to: path)
        }
    }

    private static func addSkipBackupAttribute(to filePath: String) {
        // Apply flag to prevent from iCloud backup
        var value: UInt8 = 1
        setxattr(
            (filePath as NSString).fileSystemRepresentation,
            "com.apple.MobileBackup",
            &value,
            1,
            0,
            0
        )
    }
}
