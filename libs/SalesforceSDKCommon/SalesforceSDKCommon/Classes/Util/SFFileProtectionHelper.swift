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

/// This helper class aims at providing a centralized place where NSFileProtection can be configured and retrieved.
@objc(SFFileProtectionHelper)
@objcMembers
public class SFFileProtectionHelper: NSObject {

    /// Shared instance
    @objc(sharedInstance)
    public static let shared = SFFileProtectionHelper()

    private var _pathsToFileProtection: [String: FileProtectionType] = [:]
    private let pathsToFileProtectionAccessQueue = DispatchQueue(
        label: "com.salesforce.fileProtectionHelper.pathsToFileProtection"
    )

    private var _defaultMode: FileProtectionType = .completeUntilFirstUserAuthentication

    private override init() {
        super.init()
    }

    /// Contains the default NSFileProtection mode to use if no protection is specified.
    /// By default, this property is NSFileProtectionCompleteUntilFirstUserAuthentication
    @objc
    public var defaultMode: FileProtectionType {
        get {
            return _defaultMode
        }
        set {
            _defaultMode = newValue
        }
    }

    /// A mapping of paths to custom file protection statuses
    @objc
    public var pathStatusMap: [String: FileProtectionType] {
        var result: [String: FileProtectionType] = [:]
        pathsToFileProtectionAccessQueue.sync {
            result = _pathsToFileProtection
        }
        return result
    }

    /// Helper method that will return the file protection for the specified file path.
    /// - Parameter path: The path for which to return the file protection
    /// - Returns: The file protection
    @objc(fileProtectionForPath:)
    public static func protection(for path: String) -> FileProtectionType {
        if let fileProtection = shared._pathsToFileProtection[path] {
            return fileProtection
        }
        return shared.defaultMode
    }

    /// Add a valid file protection attribute to a path
    /// - Parameters:
    ///   - fileProtection: Type of file protection to apply to the path
    ///   - path: The path for which to return the file protection
    @objc(addProtection:forPath:)
    public func addProtection(_ fileProtection: FileProtectionType, for path: String) {
        pathsToFileProtectionAccessQueue.sync {
            let validFileProtections: Set<FileProtectionType> = [
                .none,
                .complete,
                .completeUnlessOpen,
                .completeUntilFirstUserAuthentication
            ]

            if validFileProtections.contains(fileProtection) {
                _pathsToFileProtection[path] = fileProtection
            }
        }
    }
}
