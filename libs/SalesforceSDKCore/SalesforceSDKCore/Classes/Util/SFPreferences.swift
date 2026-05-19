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

/// Preferences class that handles scoped preferences.
/// A scope binds the preferences to a specific user, org, or community.
@objc(SFPreferences)
@objcMembers public class SFPreferences: NSObject {

    private static let kPreferencesFileName = "Preferences.plist"
    private static var instances = NSMutableDictionary()
    private static let lock = NSRecursiveLock()
    private static var observersRegistered = false

    private var attributes: NSMutableDictionary

    /// Returns the path in which the preferences file exists.
    @objc public private(set) var path: String

    /// Returns the underlying dictionary representation.
    @objc public var dictionaryRepresentation: NSDictionary {
        SFPreferences.lock.lock()
        defer { SFPreferences.lock.unlock() }
        return attributes.copy() as? NSDictionary ?? NSDictionary()
    }

    // MARK: - Initialization

    @objc public class func initialize_once() {
        guard !observersRegistered else { return }
        observersRegistered = true
        NotificationCenter.default.addObserver(self, selector: #selector(handleUserDidLogout(_:)), name: UserAccountManager.didLogoutUser, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleOrgDidLogout(_:)), name: UserAccountManager.didLogoutOrg, object: nil)
    }

    private init(path: String) {
        self.path = path
        self.attributes = NSMutableDictionary()
        super.init()

        if let loadedAttributes = NSDictionary(contentsOfFile: path) {
            self.attributes.addEntries(from: loadedAttributes as? [AnyHashable: Any] ?? [:])
        }
    }

    // MARK: - Factory Methods

    @objc public class func sharedPreferences(forScope scope: UserAccount.AccountScope, user: UserAccount?) -> SFPreferences? {
        initialize_once()
        var prefs: SFPreferences?
        lock.lock()
        defer { lock.unlock() }

        if let key = SFKeyForUserAndScope(user, scope) {
            prefs = instances[key] as? SFPreferences
            if prefs == nil {
                if let resolvedUser = user, let directory = SFDirectoryManager.sharedManager.directory(forUser: resolvedUser, scope: scope, type: .libraryDirectory, components: nil) {
                    var error: NSError?
                    if SFDirectoryManager.ensureDirectoryExists(directory, error: &error) {
                        let filePath = (directory as NSString).appendingPathComponent(kPreferencesFileName)
                        prefs = SFPreferences(path: filePath)
                        instances[key] = prefs
                    } else {
                        SFSDKCoreLogger.e(SFPreferences.self, message: "Unable to create scoped directory \(directory): \(String(describing: error))")
                    }
                }
            }
        }
        return prefs
    }

    @objc public class func globalPreferences() -> SFPreferences? {
        return sharedPreferences(forScope: .global, user: nil)
    }

    @objc public class func currentOrgLevelPreferences() -> SFPreferences? {
        guard let user = UserAccountManager.shared.currentUserAccount else { return nil }
        return sharedPreferences(forScope: .org, user: user)
    }

    @objc public class func currentUserLevelPreferences() -> SFPreferences? {
        guard let user = UserAccountManager.shared.currentUserAccount else { return nil }
        return sharedPreferences(forScope: .user, user: user)
    }

    @objc public class func currentCommunityLevelPreferences() -> SFPreferences? {
        guard let user = UserAccountManager.shared.currentUserAccount else { return nil }
        return sharedPreferences(forScope: .community, user: user)
    }

    // MARK: - Accessors

    @objc public func keyExists(_ key: String) -> Bool {
        SFPreferences.lock.lock()
        defer { SFPreferences.lock.unlock() }
        return attributes.value(forKey: key) != nil
    }

    @objc public func object(forKey key: String) -> Any? {
        SFPreferences.lock.lock()
        defer { SFPreferences.lock.unlock() }
        return attributes[key]
    }

    @objc public func setObject(_ object: Any, forKey key: String) {
        SFPreferences.lock.lock()
        defer { SFPreferences.lock.unlock() }
        do {
            attributes[key] = object
        }
    }

    @objc public func removeObject(forKey key: String) {
        SFPreferences.lock.lock()
        defer { SFPreferences.lock.unlock() }
        attributes.removeObject(forKey: key)
    }

    @objc public func bool(forKey key: String) -> Bool {
        return (object(forKey: key) as? NSNumber)?.boolValue ?? false
    }

    @objc public func setBool(_ value: Bool, forKey key: String) {
        setObject(NSNumber(value: value), forKey: key)
    }

    @objc public func integer(forKey key: String) -> Int {
        return (object(forKey: key) as? NSNumber)?.intValue ?? 0
    }

    @objc public func setInteger(_ value: Int, forKey key: String) {
        setObject(NSNumber(value: value), forKey: key)
    }

    @objc public func string(forKey key: String) -> String? {
        let value = object(forKey: key)
        if let number = value as? NSNumber {
            return number.stringValue
        } else if let str = value as? String {
            return str
        }
        return nil
    }

    @objc public override func setValue(_ value: Any?, forKey key: String) {
        if let value = value {
            setObject(value, forKey: key)
        }
    }

    @objc public override func value(forKey key: String) -> Any? {
        return object(forKey: key)
    }

    // MARK: - Persistence

    @objc public func synchronize() {
        SFPreferences.lock.lock()
        defer { SFPreferences.lock.unlock() }
        if !attributes.write(toFile: path, atomically: true) {
            SFSDKCoreLogger.e(SFPreferences.self, message: "Unable to save preferences at \(path)")
        }
    }

    @objc public func removeAllObjects() {
        SFPreferences.lock.lock()
        defer { SFPreferences.lock.unlock() }
        let manager = FileManager.default
        if manager.fileExists(atPath: path) {
            do {
                try manager.removeItem(atPath: path)
            } catch {
                SFSDKCoreLogger.e(SFPreferences.self, message: "Unable to delete preferences at \(path), error \(error.localizedDescription)")
            }
        }
        attributes.removeAllObjects()
    }

    // MARK: - Notification Handlers

    @objc private class func handleUserDidLogout(_ notification: Notification) {
        guard let user = (notification as NSNotification).userInfo?[UserAccountManager.userInfoAccountKey] as? UserAccount else { return }

        lock.lock()
        defer { lock.unlock() }

        if user.credentials.communityId != nil {
            if let key = SFKeyForUserAndScope(user, .community) {
                instances.removeObject(forKey: key)
            }
        }
        if let key = SFKeyForUserAndScope(user, .user) {
            instances.removeObject(forKey: key)
        }
    }

    @objc private class func handleOrgDidLogout(_ notification: Notification) {
        guard let userInfo = (notification as NSNotification).userInfo?[UserAccountManager.userInfoSfUserInfoKey] as? UserAccountManager.NotificationUserInfo else { return }

        lock.lock()
        defer { lock.unlock() }

        if let key = SFKeyForUserIdAndScope(userInfo.accountIdentity.userId, userInfo.accountIdentity.orgId, userInfo.communityId, .org) {
            instances.removeObject(forKey: key)
        }
    }
}
