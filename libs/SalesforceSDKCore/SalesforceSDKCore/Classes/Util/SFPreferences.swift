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

// MARK: - Helper Functions

/// Creates a cache key for a user and scope
fileprivate func SFKeyForUserAndScope(_ user: UserAccount?, _ scope: UserAccount.AccountScope) -> String? {
    if scope == .global {
        return "global"
    }
    guard let user = user else { return nil }
    return SFKeyForUserIdAndScope(user.credentials.userId, user.credentials.organizationId, user.credentials.communityId, scope)
}

/// Creates a cache key for user ID, org ID, community ID and scope
fileprivate func SFKeyForUserIdAndScope(_ userId: String?, _ orgId: String?, _ communityId: String?, _ scope: UserAccount.AccountScope) -> String? {
    guard let userId = userId, let orgId = orgId else {
        return nil
    }

    let communityPart = communityId ?? "null"
    return "\(userId)_\(orgId)_\(communityPart)_\(scope.rawValue)"
}

/**
 Preferences class that handles scoped preferences.
 A scope binds the preferences to a specific user,
 org or community.
 */
@objc(SFPreferences)
public class SFPreferences: NSObject {

    private static let preferencesFileName = "Preferences.plist"
    private static var instances: [String: SFPreferences] = [:]
    private static let instancesLock = NSLock()

    private var attributes: NSMutableDictionary
    private let attributesLock = NSLock()

    /**
     Returns the path in which the preferences file exists
     */
    @objc
    public private(set) var path: String

    /**
     Returns the underlying dictionary representation
     */
    @objc
    public var dictionaryRepresentation: NSDictionary {
        attributesLock.lock()
        defer { attributesLock.unlock() }
        return attributes.copy() as! NSDictionary
    }

    public override init() {
        self.path = ""
        self.attributes = NSMutableDictionary()
        super.init()
    }

    private init(path: String) {
        self.path = path
        self.attributes = NSMutableDictionary()
        super.init()

        if let loadedAttributes = NSDictionary(contentsOfFile: path) {
            self.attributes.addEntries(from: loadedAttributes as! [AnyHashable: Any])
        }
    }

    /**
     Returns the global instance of the preferences (one per application)
     */
    @objc
    public static func globalPreferences() -> SFPreferences {
        return sharedPreferences(forScope: .global, user: nil)!
    }

    /**
     Returns the preferences instance related to the specified user's organization
     or nil if there is no specified user or scope.
     @param scope The scope to which the preferences apply: global, user's org, user's community, or user's account.
     @param user The account to which the preferences apply. Not used if scope is global.
     */
    @objc
    public static func sharedPreferences(forScope scope: UserAccount.AccountScope, user: UserAccount?) -> SFPreferences? {
        var prefs: SFPreferences?

        instancesLock.lock()
        defer { instancesLock.unlock() }

        guard let key = SFKeyForUserAndScope(user, scope) else {
            return nil
        }

        if let existingPrefs = instances[key] {
            return existingPrefs
        }

        guard let directory = SFDirectoryManager.sharedManager().directory(forUser: user, scope: scope, type: .libraryDirectory, components: nil) else {
            return nil
        }

        do {
            try SFDirectoryManager.ensureDirectoryExists(directory)
            let prefsPath = (directory as NSString).appendingPathComponent(preferencesFileName)
            prefs = SFPreferences(path: prefsPath)
            instances[key] = prefs
        } catch {
            SFSDKCoreLogger.e(SFPreferences.self, message: "Unable to create scoped directory \(directory): \(error)")
        }

        return prefs
    }

    /**
     Returns the preferences instance related to the current user's organization
     or nil if there is no current user.
     */
    @objc
    public static func currentOrgLevelPreferences() -> SFPreferences? {
        guard let user = UserAccountManager.shared.currentUserAccount else {
            return nil
        }
        return sharedPreferences(forScope: .org, user: user)
    }

    /**
     Returns the preferences instance related to the currrent user
     or nil if there is no current user.
     */
    @objc
    public static func currentUserAccountLevelPreferences() -> SFPreferences? {
        guard let user = UserAccountManager.shared.currentUserAccount else {
            return nil
        }
        return sharedPreferences(forScope: .user, user: user)
    }

    /**
     Returns the preferences instance related to the currrent user's community
     or nil if there is no current user.
     */
    @objc
    public static func currentCommunityLevelPreferences() -> SFPreferences? {
        guard let user = UserAccountManager.shared.currentUserAccount else {
            return nil
        }
        return sharedPreferences(forScope: .community, user: user)
    }

    /**
     Returns the preferences object for the given key.
     @param key The key of the requested object.
     */
    @objc
    public func object(forKey key: String) -> Any? {
        attributesLock.lock()
        defer { attributesLock.unlock() }
        return attributes[key]
    }

    /**
     Sets the preference object for the given attribute key. Logs an SFLogLevelError if the key is not found.
     @param object Object to be set.
     @param key Key of object to be set.
     */
    @objc
    public func setObject(_ object: Any?, forKey key: String) {
        attributesLock.lock()
        defer { attributesLock.unlock() }

        do {
            if let object = object {
                attributes[key] = object
            } else {
                attributes.removeObject(forKey: key)
            }
        } catch {
            SFSDKCoreLogger.e(type(of: self), message: "Unable to set preference entry (key:\(key), object:\(String(describing: object))): \(error)")
        }
    }

    /**
     Removes the preference object for the given attribute key.
     @param key Key of object to be removed.
     */
    @objc
    public func removeObject(forKey key: String) {
        attributesLock.lock()
        defer { attributesLock.unlock() }
        attributes.removeObject(forKey: key)
    }

    /**
     Returns a YES if the key exits, otherwise NO.
     @param key The key to check the existance of.
     */
    @objc
    public func keyExists(_ key: String) -> Bool {
        attributesLock.lock()
        defer { attributesLock.unlock() }
        return attributes.value(forKey: key) != nil
    }

    /**
     Returns the Boolean preference value for the given key.
     @param key The key of the requested preference value.
     */
    @objc
    public func bool(forKey key: String) -> Bool {
        return (object(forKey: key) as? NSNumber)?.boolValue ?? false
    }

    /**
     Assigns the given Boolean preference value to the given key.
     @param value The Boolean value.
     @param key The key of the preference value to be edited.
     */
    @objc
    public func setBool(_ value: Bool, forKey key: String) {
        setObject(NSNumber(value: value), forKey: key)
    }

    /**
     Returns the integer preference value for the given key.
     @param key The key of the requested preference value.
     */
    @objc
    public func integer(forKey key: String) -> Int {
        return (object(forKey: key) as? NSNumber)?.intValue ?? 0
    }

    /**
     Assigns the given integer preference value to the given key.
     @param value The integer value.
     @param key The key of the preference value to be edited.
     */
    @objc
    public func setInteger(_ value: Int, forKey key: String) {
        setObject(NSNumber(value: value), forKey: key)
    }

    /**
     Returns the string preference value for the given key.
     @param key The key of the requested preference value.
     */
    @objc
    public func string(forKey key: String) -> String? {
        let value = object(forKey: key)
        if let number = value as? NSNumber {
            return number.stringValue
        } else if let string = value as? String {
            return string
        } else {
            return nil
        }
    }

    /**
     Saves the preferences to the disk
     */
    @objc
    public func synchronize() {
        attributesLock.lock()
        defer { attributesLock.unlock() }

        if !attributes.write(toFile: path, atomically: true) {
            SFSDKCoreLogger.e(type(of: self), message: "Unable to save preferences at \(path)")
        }
    }

    /**
     Remove all saved objects
     */
    @objc
    public func removeAllObjects() {
        attributesLock.lock()
        defer { attributesLock.unlock() }

        let manager = FileManager.default
        if manager.fileExists(atPath: path) {
            do {
                try manager.removeItem(atPath: path)
            } catch {
                SFSDKCoreLogger.e(type(of: self), message: "Unable to delete preferences at \(path), error \(error.localizedDescription)")
            }
        }
        attributes.removeAllObjects()
    }

    // MARK: - KVO Support

    @objc
    public override func setValue(_ value: Any?, forKey key: String) {
        setObject(value, forKey: key)
    }

    @objc
    public override func value(forKey key: String) -> Any? {
        return object(forKey: key)
    }

    // MARK: - Notification Handlers

    @objc
    private static func handleUserDidLogout(_ notification: Notification) {
        guard let user = notification.userInfo?[kSFNotificationUserInfoAccountKey] as? UserAccount else {
            return
        }

        instancesLock.lock()
        defer { instancesLock.unlock() }

        if user.credentials.communityId != nil {
            if let key = SFKeyForUserAndScope(user, .community) {
                instances.removeValue(forKey: key)
            }
        }

        if let key = SFKeyForUserAndScope(user, .user) {
            instances.removeValue(forKey: key)
        }
    }

    @objc
    private static func handleOrgDidLogout(_ notification: Notification) {
        guard let userInfo = notification.userInfo?[kSFNotificationUserInfoKey] as? SFNotificationUserInfo else {
            return
        }

        instancesLock.lock()
        defer { instancesLock.unlock() }

        if let key = SFKeyForUserIdAndScope(userInfo.accountIdentity.userId, userInfo.accountIdentity.orgId, userInfo.communityId, .org) {
            instances.removeValue(forKey: key)
        }
    }
}
