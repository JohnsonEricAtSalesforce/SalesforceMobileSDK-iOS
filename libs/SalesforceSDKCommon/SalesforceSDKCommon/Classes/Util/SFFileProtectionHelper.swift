/*
 SFFileProtectionHelper.swift
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

/// Centralized helper for configuring and retrieving NSFileProtection attributes.
@objc(SFFileProtectionHelper)
@objcMembers
public class FileProtectionHelper: NSObject {

    // MARK: - Singleton

    /// Returns the shared instance.
    @objc public static let shared = FileProtectionHelper()

    // MARK: - Properties

    /// Contains the default NSFileProtection mode. Defaults to NSFileProtectionCompleteUntilFirstUserAuthentication.
    @objc public var defaultMode: String = FileProtectionType.completeUntilFirstUserAuthentication.rawValue

    /// A mapping of paths to custom file protection statuses.
    @objc public private(set) var pathStatusMap: NSDictionary = NSDictionary()

    private let accessQueue = DispatchQueue(label: "com.salesforce.fileProtectionHelper.pathsToFileProtection")

    // MARK: - Initializer

    private override init() {
        super.init()
    }

    // MARK: - Class Methods

    /// Returns the file protection for the specified path.
    @objc(fileProtectionForPath:)
    public class func protection(for path: String) -> String {
        if let fileProtection = shared.pathStatusMap[path] as? String {
            return fileProtection
        }
        return shared.defaultMode
    }

    // MARK: - Instance Methods

    /// Adds a valid file protection attribute for a path.
    @objc public func addProtection(_ fileProtection: String, for path: String) {
        accessQueue.sync {
            let validFileProtections: Set<String> = [
                FileProtectionType.none.rawValue,
                FileProtectionType.complete.rawValue,
                FileProtectionType.completeUnlessOpen.rawValue,
                FileProtectionType.completeUntilFirstUserAuthentication.rawValue
            ]
            guard validFileProtections.contains(fileProtection) else { return }

            let dict = NSMutableDictionary(dictionary: self.pathStatusMap)
            dict[path] = fileProtection
            self.pathStatusMap = dict.copy() as? NSDictionary ?? NSDictionary()
        }
    }
}
