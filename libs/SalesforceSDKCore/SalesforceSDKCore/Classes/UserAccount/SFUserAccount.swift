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
import UIKit
import CryptoKit
import SalesforceSDKCommon

// MARK: - Login State Enum

/// Enumeration of the potential login states of the user account.
@objc(SFUserAccountLoginState)
public enum UserAccountLoginState: UInt {
    /// User account is not logged in.
    case notLoggedIn = 0
    /// User account is logged in.
    case loggedIn
    /// User account is in the process of logging out.
    case loggingOut
}

// MARK: - Constants

private let kUser_ACCESS_SCOPES = "accessScopes"
private let kUser_CREDENTIALS = "credentials"
private let kUser_ID_DATA = "idData"
private let kUser_CUSTOM_DATA = "customData"
private let kUser_ACCESS_RESTRICTIONS = "accessRestrictions"
private let kCredentialsUserIdPropName = "userId"
private let kCredentialsOrgIdPropName = "organizationId"
private let kUser_NOTIFICATION_TYPES = "notificationTypes"
private let kUser_FEATURE_FLAGS = "featureFlags"
private let kGlobalScopingKey = "-global-"

public let kUserAccountPhotoEncryptionKeyLabel: String = "com.salesforce.userAccount.photos.encryptionKey"

// MARK: - Free Functions

/// Returns a key that uniquely identifies the global scope.
public func SFKeyForGlobalScope() -> String {
    return SFKeyForUserIdAndScope(nil, nil, nil, .global) ?? ""
}

/// Returns a key that uniquely identifies the given user account for the specified scope.
public func SFKeyForUserAndScope(_ user: UserAccount?, _ scope: UserAccount.AccountScope) -> String? {
    return SFKeyForUserIdAndScope(user?.credentials.userId, user?.credentials.organizationId, user?.credentials.communityId, scope)
}

/// Returns a key that uniquely identifies a user/org/community for the given scope.
public func SFKeyForUserIdAndScope(_ userId: String?, _ orgId: String?, _ communityId: String?, _ scope: UserAccount.AccountScope) -> String? {
    let key: String
    switch scope {
    case .global:
        key = kGlobalScopingKey
    case .org:
        if let orgId = orgId {
            key = orgId
        } else {
            key = ""
        }
    case .user:
        if let orgId = orgId, let userId = userId {
            key = "\(orgId)-\(userId)"
        } else {
            key = ""
        }
    case .community:
        if let orgId = orgId, let userId = userId {
            key = "\(orgId)-\(userId)-\(communityId ?? "")"
        } else {
            key = ""
        }
    @unknown default:
        key = ""
    }
    return key
}

// MARK: - UserAccount

/// Class that represents an account. An account represents a user together with the current community it is logged in.
@objc(SFUserAccount)
@objcMembers open class UserAccount: NSObject, NSSecureCoding {

    // MARK: - Nested Enums

    /// The various scopes related to a user account.
    @objc(SFUserAccountScope)
    public enum AccountScope: UInt {
        /// Global scope (one per application)
        case global = 0
        /// Scope by organization
        case org
        /// Scope by user
        case user
        /// Scope by community
        case community
    }

    /// User account access restrictions.
    @objc(SFUserAccountAccessRestriction)
    public enum AccessRestriction: UInt {
        case none = 0
        case chatter = 1
        case rest = 2
        case other = 4
    }

    /// The various changes that can affect a user account's data.
    ///
    /// This is a bitmask (mirroring the original ObjC `NS_OPTIONS SFUserAccountDataChange`): a single
    /// change notification can report several simultaneous changes OR-combined together. It must be an
    /// `OptionSet`, not a plain `enum` — a `UInt`-raw enum can only represent one case, so a combined
    /// value such as `communityId | instanceURL | accessToken` (26) would fail `init(rawValue:)` and
    /// silently drop the notification. Bridged to ObjC/notification userInfo as the raw `UInt`.
    public struct AccountDataChange: OptionSet {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }

        public static let unknown = AccountDataChange(rawValue: 1)
        public static let communityId = AccountDataChange(rawValue: 2)
        public static let idData = AccountDataChange(rawValue: 4)
        public static let instanceURL = AccountDataChange(rawValue: 8)
        public static let accessToken = AccountDataChange(rawValue: 16)
    }

    /// The various changes that can affect a user account.
    @objc(SFUserAccountChange)
    public enum AccountChange: UInt {
        case unknown = 1
        case newUser = 2
        case currentUser = 4
    }

    // MARK: - NSSecureCoding

    public static var supportsSecureCoding: Bool { true }

    // MARK: - Private state

    private let syncQueue = DispatchQueue(label: "com.salesforce.mobilesdk.sfuseraccount.syncqueue", attributes: .concurrent)
    private var _observingCredentials = false
    private var _credentials: OAuthCredentials
    private var _accountIdentity: UserAccountIdentity
    private var _accessScopes: Set<String>?
    private var _idData: SFIdentityData?
    private var _photo: UIImage?
    private var _customData: NSMutableDictionary?
    private var _notificationTypes: [NotificationType]?

    // MARK: - Public Properties

    /// The access scopes for this user.
    @objc public var accessScopes: Set<String>? {
        get {
            var result: Set<String>?
            syncQueue.sync { result = _accessScopes }
            return result
        }
        set {
            syncQueue.async(flags: .barrier) { self._accessScopes = newValue }
        }
    }

    /// The unique identifier for this account.
    @objc public var accountIdentity: UserAccountIdentity {
        var result: UserAccountIdentity?
        syncQueue.sync { result = _accountIdentity }
        return result ?? UserAccountIdentity(userId: "", orgId: "")
    }

    /// The credentials associated with this user.
    @objc public var credentials: OAuthCredentials {
        get {
            var result: OAuthCredentials?
            syncQueue.sync { result = _credentials }
            return result ?? OAuthCredentials()
        }
        set {
            syncQueue.async(flags: .barrier) {
                self.setCredentialsInternal(newValue)
            }
        }
    }

    /// The notification types for this user.
    @objc public var notificationTypes: [NotificationType]? {
        get {
            var result: [NotificationType]?
            syncQueue.sync { result = _notificationTypes }
            return result
        }
        set {
            syncQueue.async(flags: .barrier) { self._notificationTypes = newValue?.map { $0 } }
        }
    }

    /// Feature flags persisted for this user (e.g. BW, QR). Populated from SFSDKAppFeatureMarkers.
    @objc public var persistedFeatureFlags: Set<String>?

    /// The identity data associated with this user.
    @objc public var idData: SFIdentityData? {
        get {
            var result: SFIdentityData?
            syncQueue.sync { result = _idData }
            return result
        }
        set {
            syncQueue.async(flags: .barrier) {
                if newValue !== self._idData {
                    self._idData = newValue
                }
            }
        }
    }

    /// The user's photo. Usually stores a thumbnail of the user. To set this property use `setPhoto(_:completion:)`.
    @objc public private(set) var photo: UIImage? {
        get {
            if _photo == nil {
                syncQueue.sync {
                    guard let photoPath = self.photoPathInternal() else { return }
                    let manager = FileManager.default
                    if manager.fileExists(atPath: photoPath) {
                        if let decrypted = self.decryptPhoto(at: photoPath) {
                            self._photo = decrypted
                        }
                    }
                }
            }
            return _photo
        }
        set {
            _photo = newValue
        }
    }

    /// The access restriction associated with this user.
    @objc public var accessRestrictions: AccessRestriction = .none

    /// Returns YES if the user has an access token and, presumably, a valid session.
    @objc public var isSessionValid: Bool {
        return _credentials.accessToken != nil && _idData != nil
    }

    /// Indicates if this account was deleted.
    @objc public internal(set) var isUserDeleted: Bool = false

    /// Indicates this user's current login state.
    @objc public private(set) var loginState: UserAccountLoginState = .notLoggedIn

    // MARK: - Initialization

    @objc public convenience override init() {
        self.init(credentials: OAuthCredentials())
    }

    /// Initialize with OAuthCredentials credentials.
    @objc public init(credentials: OAuthCredentials) {
        // Initialize `_credentials` to a throwaway placeholder (a *distinct* object) rather than the
        // real credentials. `setCredentialsInternal` only registers its KVO observers when the incoming
        // credentials differ from `_credentials` (by identity). The ObjC original left `_credentials`
        // nil here so the guard passed; assigning the real object up front (as the migration did) made
        // the guard fail and the observer was never registered, leaving `accountIdentity` stale.
        _credentials = OAuthCredentials()
        _observingCredentials = false
        _accountIdentity = UserAccountIdentity(userId: credentials.userId ?? "", orgId: credentials.organizationId ?? "")
        super.init()
        setCredentialsInternal(credentials)
        loginState = (credentials.refreshToken?.count ?? 0) > 0 ? .loggedIn : .notLoggedIn
        _accountIdentity = UserAccountIdentity(userId: _credentials.userId ?? "", orgId: _credentials.organizationId ?? "")
        if loginState == .loggedIn {
            SFSDKAppFeatureMarkers.registerAppFeature(kSFAppFeatureOAuth)
        }
    }

    // MARK: - NSSecureCoding

    public required init?(coder decoder: NSCoder) {
        _credentials = OAuthCredentials()
        _accountIdentity = UserAccountIdentity(userId: "", orgId: "")
        _observingCredentials = false
        super.init()

        _accessScopes = decoder.decodeObject(of: [NSSet.self, NSString.self], forKey: kUser_ACCESS_SCOPES) as? Set<String>
        _accountIdentity = UserAccountIdentity(userId: "", orgId: "")

        if let creds = decoder.decodeObject(of: OAuthCredentials.self, forKey: kUser_CREDENTIALS) {
            setCredentialsInternal(creds)
        }

        _idData = decoder.decodeObject(of: SFIdentityData.self, forKey: kUser_ID_DATA)

        let allowedClasses: [AnyClass] = [NSDictionary.self, NSArray.self, NSString.self, NSNumber.self, NSNull.self, NSURL.self, NSDate.self]
        _customData = (decoder.decodeObject(of: allowedClasses, forKey: kUser_CUSTOM_DATA) as? NSDictionary)?.mutableCopy() as? NSMutableDictionary

        accessRestrictions = AccessRestriction(rawValue: UInt(decoder.decodeInteger(forKey: kUser_ACCESS_RESTRICTIONS))) ?? .none

        loginState = (_credentials.refreshToken?.count ?? 0) > 0 ? .loggedIn : .notLoggedIn
        if loginState == .loggedIn {
            SFSDKAppFeatureMarkers.registerAppFeature(kSFAppFeatureOAuth)
        }

        let notifClasses: [AnyClass] = [NSArray.self, NotificationType.self]
        _notificationTypes = decoder.decodeObject(of: notifClasses, forKey: kUser_NOTIFICATION_TYPES) as? [NotificationType]

        persistedFeatureFlags = decoder.decodeObject(of: [NSSet.self, NSString.self], forKey: kUser_FEATURE_FLAGS) as? Set<String>
    }

    public func encode(with encoder: NSCoder) {
        // Read the ivars under syncQueue so any pending barrier writes (setAccessScopes,
        // setIdData, setCustomDataObject:forKey:, ...) complete before they're encoded.
        // Without this, encoding immediately after a setter can capture stale (nil/empty)
        // values — the race fixed upstream in #4042. accessRestrictions is a plain stored
        // property (no queue accessor), so reading it here does not re-enter syncQueue.
        syncQueue.sync {
            encoder.encode(_accessScopes, forKey: kUser_ACCESS_SCOPES)
            encoder.encode(_credentials, forKey: kUser_CREDENTIALS)
            encoder.encode(_idData, forKey: kUser_ID_DATA)
            encoder.encode(_customData, forKey: kUser_CUSTOM_DATA)
            encoder.encode(Int(accessRestrictions.rawValue), forKey: kUser_ACCESS_RESTRICTIONS)
            encoder.encode(_notificationTypes, forKey: kUser_NOTIFICATION_TYPES)
            encoder.encode(persistedFeatureFlags, forKey: kUser_FEATURE_FLAGS)
        }
    }

    deinit {
        if _observingCredentials {
            _credentials.removeObserver(self, forKeyPath: kCredentialsUserIdPropName)
            _credentials.removeObserver(self, forKeyPath: kCredentialsOrgIdPropName)
        }
    }

    // MARK: - Custom Data

    /// Set object in customData dictionary.
    @objc public func setCustomDataObject(_ object: NSCoding, forKey key: NSCopying) {
        syncQueue.async(flags: .barrier) {
            if self._customData == nil {
                self._customData = NSMutableDictionary()
            }
            self._customData?.setObject(object, forKey: key)
        }
    }

    /// Remove a custom data object for a key.
    @objc public func removeCustomDataObject(forKey key: Any) {
        syncQueue.async(flags: .barrier) {
            if self._customData == nil {
                self._customData = NSMutableDictionary()
            }
            self._customData?.removeObject(forKey: key)
        }
    }

    /// Retrieve the object stored in the custom data dictionary.
    @objc public func customDataObject(forKey key: Any) -> Any? {
        var result: Any?
        syncQueue.sync(flags: .barrier) {
            if self._customData == nil {
                self._customData = NSMutableDictionary()
            }
            result = self._customData?.object(forKey: key)
        }
        return result
    }

    // MARK: - Photo

    /// Sets the user's photo.
    @objc public func setPhoto(_ photo: UIImage?, completion: ((Error?) -> Void)?) {
        syncQueue.async(flags: .barrier) {
            var error: NSError?
            guard let photoPath = self.photoPathInternal(error: &error) else {
                SFSDKCoreLogger.e(type(of: self), format: "Unable to retrieve the photo path: %@", error?.localizedDescription ?? "unknown")
                completion?(error)
                return
            }

            let fm = FileManager.default
            if fm.fileExists(atPath: photoPath) {
                do {
                    try fm.removeItem(atPath: photoPath)
                } catch let removeError {
                    SFSDKCoreLogger.e(type(of: self), format: "Unable to remove previous photo from disk: %@", removeError.localizedDescription)
                }
            }

            if let photo = photo {
                guard let data = photo.pngData() else {
                    completion?(nil)
                    return
                }
                var storeError: NSError?
                if !self.storeEncryptedPhoto(data, path: photoPath, error: &storeError) {
                    completion?(storeError)
                    return
                }
            }

            self.willChangeValue(forKey: "photo")
            self._photo = photo
            self.didChangeValue(forKey: "photo")

            completion?(nil)
        }
    }

    // MARK: - Login State Transition

    /// Attempts to transition from the current login state to the new login state.
    @objc @discardableResult public func transitionToLoginState(_ newLoginState: UserAccountLoginState) -> Bool {
        var transitionSucceeded = false
        syncQueue.sync(flags: .barrier) {
            switch newLoginState {
            case .loggedIn:
                transitionSucceeded = (self.loginState == .notLoggedIn || self.loginState == .loggedIn)
            case .notLoggedIn:
                transitionSucceeded = (self.loginState == .notLoggedIn || self.loginState == .loggingOut)
            case .loggingOut:
                transitionSucceeded = (self.loginState == .loggedIn)
            @unknown default:
                transitionSucceeded = false
            }
            if transitionSucceeded {
                self.loginState = newLoginState
            } else {
                SFSDKCoreLogger.w(type(of: self), format: "Invalid login state transition from '%@' to '%@'. No action taken.",
                                  Self.loginStateDescription(from: self.loginState),
                                  Self.loginStateDescription(from: newLoginState))
            }
        }
        return transitionSucceeded
    }

    // MARK: - Description

    open override var description: String {
        var theUserName = "*****"
        var theFullName = "*****"

        #if DEBUG
        theUserName = _idData?.username ?? ""
        theFullName = "\(_idData?.firstName ?? "") \(_idData?.lastName ?? "")"
        #endif

        return "<SFUserAccount username=\(theUserName) fullName=\(theFullName) accessScopes=\(String(describing: _accessScopes)) credentials=\(_credentials)>"
    }

    // MARK: - KVO

    open override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        guard let obj = object as? OAuthCredentials,
              obj === _credentials,
              let keyPath = keyPath,
              (keyPath == kCredentialsUserIdPropName || keyPath == kCredentialsOrgIdPropName),
              let change = change else {
            return
        }

        let oldValue = change[.oldKey]
        let newValue = change[.newKey]
        let oldKey = (oldValue is NSNull) ? nil : oldValue as? String
        let newKey = (newValue is NSNull) ? nil : newValue as? String

        if keyPath == kCredentialsUserIdPropName {
            _accountIdentity.userId = newKey ?? ""
        } else if keyPath == kCredentialsOrgIdPropName {
            _accountIdentity.orgId = newKey ?? ""
        }
    }

    // MARK: - Private

    private func setCredentialsInternal(_ credentials: OAuthCredentials) {
        let currentCredentials = _credentials
        if credentials !== currentCredentials {
            if _observingCredentials {
                currentCredentials.removeObserver(self, forKeyPath: kCredentialsUserIdPropName)
                currentCredentials.removeObserver(self, forKeyPath: kCredentialsOrgIdPropName)
                _observingCredentials = false
            }
            credentials.addObserver(self, forKeyPath: kCredentialsUserIdPropName, options: [.old, .new], context: nil)
            credentials.addObserver(self, forKeyPath: kCredentialsOrgIdPropName, options: [.old, .new], context: nil)
            _observingCredentials = true
            _credentials = credentials
            _accountIdentity.userId = credentials.userId ?? ""
            _accountIdentity.orgId = credentials.organizationId ?? ""
        }
    }

    private var userPhotoDirectory: String? {
        return SFDirectoryManager.sharedManager.directory(forOrg: _credentials.organizationId, user: _credentials.userId, community: _credentials.communityId ?? SFDirectoryManager.defaultCommunityName, type: .libraryDirectory, components: ["mobilesdk", "photos"])
    }

    private func photoPathInternal(error: inout NSError?) -> String? {
        guard let photoDir = userPhotoDirectory else { return nil }
        SFDirectoryManager.ensureDirectoryExists(photoDir, error: &error)
        guard let userId = _credentials.userId else { return nil }
        return (photoDir as NSString).appendingPathComponent(SFDirectoryManager.safeStringForDiskRepresentation(userId))
    }

    private func photoPathInternal() -> String? {
        var error: NSError?
        return photoPathInternal(error: &error)
    }

    private func storeEncryptedPhoto(_ photoData: Data, path photoPath: String, error: inout NSError?) -> Bool {
        guard let encryptedData = encryptPhoto(photoData) else {
            let errorMessage = "User photo data could not be encrypted."
            SFSDKCoreLogger.e(type(of: self), format: "%@", errorMessage)
            error = NSError(domain: kSFSDKUserAccountManagerErrorDomain, code: Int(SFSDKUserAccountManagerErrorCode.cannotEncrypt.rawValue), userInfo: [NSLocalizedDescriptionKey: errorMessage])
            return false
        }

        do {
            try encryptedData.write(to: URL(fileURLWithPath: photoPath), options: .atomic)
        } catch let writeError as NSError {
            SFSDKCoreLogger.e(type(of: self), format: "Unable to write photo to disk: %@", writeError.localizedDescription)
            error = writeError
            return false
        }
        return true
    }

    private func decryptPhoto(at photoPath: String) -> UIImage? {
        guard let data = FileManager.default.contents(atPath: photoPath) else { return nil }
        guard let encryptionKey = try? KeyGenerator.encryptionKey(for: kUserAccountPhotoEncryptionKeyLabel) as SymmetricKey else { return nil }
        guard let decryptedData = try? Encryptor.decrypt(data: data, using: encryptionKey) else { return nil }
        return UIImage(data: decryptedData)
    }

    private func encryptPhoto(_ data: Data) -> Data? {
        guard let encryptionKey = try? KeyGenerator.encryptionKey(for: kUserAccountPhotoEncryptionKeyLabel) as SymmetricKey else { return nil }
        return try? Encryptor.encrypt(data: data, using: encryptionKey)
    }

    private class func loginStateDescription(from loginState: UserAccountLoginState) -> String {
        switch loginState {
        case .loggedIn:
            return "SFUserAccountLoginStateLoggedIn"
        case .loggingOut:
            return "SFUserAccountLoginStateLoggingOut"
        case .notLoggedIn:
            return "SFUserAccountLoginStateNotLoggedIn"
        @unknown default:
            return "Unknown login state (code: \(loginState.rawValue))"
        }
    }
}
