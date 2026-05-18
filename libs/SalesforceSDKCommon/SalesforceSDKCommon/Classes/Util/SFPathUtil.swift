/*
 SFPathUtil.swift
 SalesforceSDKCommon

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

/// Utility class that helps create sub-folders under Documents, Cache, or Library directories.
/// Any folder or file created by SFPathUtil will be marked with file protection attributes
/// and excluded from iCloud backup.
@objc(SFPathUtil)
@objcMembers
public class SFPathUtil: NSObject {

    // MARK: - Directory Accessors

    /// Returns the application's Document directory.
    @objc public class func applicationDocumentDirectory() -> String {
        return NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).last ?? ""
    }

    /// Returns the application's Cache directory.
    @objc public class func applicationCacheDirectory() -> String {
        return NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).last ?? ""
    }

    /// Returns the application's Library directory.
    @objc public class func applicationLibraryDirectory() -> String {
        return NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).last ?? ""
    }

    // MARK: - Absolute Path Methods

    /// Returns the absolute path for a folder under the Documents directory.
    /// Ensures the sub-directory exists, applies file protection, and marks as not backed up.
    @objc public class func absolutePathForDocumentFolder(_ folder: String) -> String {
        return absolutePathForDocumentFolder(folder, fileProtection: nil)
    }

    /// Returns the absolute path for a folder under the Documents directory with custom file protection.
    @objc public class func absolutePathForDocumentFolder(_ folder: String, fileProtection: String?) -> String {
        let rootPath = applicationDocumentDirectory()
        let path = (rootPath as NSString).appendingPathComponent(folder)
        createFileItemIfNotExist(path, skipBackup: true, fileProtection: fileProtection)
        return path
    }

    /// Returns the absolute path for a folder under the Cache directory.
    /// Ensures the sub-directory exists, applies file protection, and marks as not backed up.
    @objc public class func absolutePathForCacheFolder(_ folder: String) -> String {
        return absolutePathForCacheFolder(folder, fileProtection: nil)
    }

    /// Returns the absolute path for a folder under the Cache directory with custom file protection.
    @objc public class func absolutePathForCacheFolder(_ folder: String, fileProtection: String?) -> String {
        let rootPath = applicationCacheDirectory()
        let path = (rootPath as NSString).appendingPathComponent(folder)
        createFileItemIfNotExist(path, skipBackup: true, fileProtection: fileProtection)
        return path
    }

    /// Returns the absolute path for a folder under the Library directory.
    /// Ensures the sub-directory exists, applies file protection, and marks as not backed up.
    @objc public class func absolutePathForLibraryFolder(_ folder: String) -> String {
        return absolutePathForLibraryFolder(folder, fileProtection: nil)
    }

    /// Returns the absolute path for a folder under the Library directory with custom file protection.
    @objc public class func absolutePathForLibraryFolder(_ folder: String, fileProtection: String?) -> String {
        let rootPath = applicationLibraryDirectory()
        let path = (rootPath as NSString).appendingPathComponent(folder)
        createFileItemIfNotExist(path, skipBackup: true, fileProtection: fileProtection)
        return path
    }

    // MARK: - File Creation

    /// Creates the directory at the specified path if it doesn't exist.
    @objc public class func createFileItemIfNotExist(_ path: String, skipBackup: Bool) {
        createFileItemIfNotExist(path, skipBackup: skipBackup, fileProtection: nil)
    }

    private class func createFileItemIfNotExist(_ path: String, skipBackup: Bool, fileProtection: String?) {
        let protection = fileProtection ?? FileProtectionHelper.protection(for: path)
        let fileManager = FileManager.default

        if !fileManager.fileExists(atPath: path) {
            try? fileManager.createDirectory(
                atPath: path,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: protection]
            )
        } else {
            try? fileManager.setAttributes(
                [.protectionKey: protection],
                ofItemAtPath: path
            )
        }

        if skipBackup {
            addSkipBackupAttribute(to: path)
        }
    }

    // MARK: - Security

    /// Adds file protection and optionally marks the path as not backed up by iCloud.
    @objc public class func secureFilePath(_ filePath: String, markAsNotBackup notbackupFlag: Bool) {
        secureFilePath(filePath, markAsNotBackup: notbackupFlag, fileProtection: nil)
    }

    /// Adds file protection with a custom protection level and optionally marks as not backed up.
    @objc public class func secureFilePath(_ filePath: String, markAsNotBackup notbackupFlag: Bool, fileProtection: String?) {
        let protection = fileProtection ?? FileProtectionHelper.protection(for: filePath)
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: filePath) else { return }

        if let attrs = try? fileManager.attributesOfItem(atPath: filePath),
           let currentProtection = attrs[.protectionKey] as? String,
           currentProtection != protection {
            try? fileManager.setAttributes(
                [.protectionKey: protection],
                ofItemAtPath: filePath
            )
        }

        if notbackupFlag {
            addSkipBackupAttribute(to: filePath)
        }
    }

    /// Secures the file at the path, optionally recursing into directories.
    @objc public class func secureFileAtPath(_ filePath: String, recursive: Bool, fileProtection: String?) {
        secureFilePath(filePath, markAsNotBackup: true, fileProtection: fileProtection)

        if recursive {
            let fileManager = FileManager.default
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: filePath, isDirectory: &isDirectory), isDirectory.boolValue {
                if let directoryContents = try? fileManager.contentsOfDirectory(atPath: filePath) {
                    for item in directoryContents {
                        let fileFullPath = (filePath as NSString).appendingPathComponent(item)
                        secureFileAtPath(fileFullPath, recursive: recursive, fileProtection: fileProtection)
                    }
                }
            }
        }
    }

    // MARK: - Private Helpers

    private class func addSkipBackupAttribute(to filePath: String) {
        var b: UInt8 = 1
        filePath.withCString { cPath in
            setxattr(cPath, "com.apple.MobileBackup", &b, 1, 0, 0)
        }
    }
}
