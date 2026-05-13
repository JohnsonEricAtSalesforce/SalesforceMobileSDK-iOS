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
import UIKit

// MARK: - Constants
private let kUser_ACCESS_SCOPES = "accessScopes"
private let kUser_CREDENTIALS = "credentials"
private let kUser_ID_DATA = "idData"
private let kUser_CUSTOM_DATA = "customData"
private let kUser_ACCESS_RESTRICTIONS = "accessRestrictions"
private let kCredentialsUserIdPropName = "userId"
private let kCredentialsOrgIdPropName = "organizationId"
private let kUser_NOTIFICATION_TYPES = "notificationTypes"
private let kSyncQueue = "com.salesforce.mobilesdk.sfuseraccount.syncqueue"

// Note: Can't use @objc on top-level constants in Swift - Obj-C code should use the string directly
public let kUserAccountPhotoEncryptionKeyLabel = "com.salesforce.userAccount.photos.encryptionKey"

/// Class that represents an account. An account represents a user together with the current community it is logged in.
@objc(SFUserAccount)
public class UserAccount: NSObject, NSSecureCoding {

    // MARK: - Properties

    /// The access scopes for this user
    @objc public var accessScopes: Set<String>? {
        get {
            return syncQueue.sync { _accessScopes }
        }
        set {
            syncQueue.async(flags: .barrier) { self._accessScopes = newValue }
        }
    }
    private var _accessScopes: Set<String>?

    /// The unique identifier for this account.
    @objc public var accountIdentity: SFUserAccountIdentity {
        return syncQueue.sync { _accountIdentity }
    }
    private var _accountIdentity: SFUserAccountIdentity!

    /// The credentials associated with this user
    @objc public var credentials: OAuthCredentials {
        get {
            return syncQueue.sync { _credentials }
        }
        set {
            syncQueue.async(flags: .barrier) { self.setCredentialsInternal(newValue) }
        }
    }
    private var _credentials: OAuthCredentials!

    /// The notification types for this user
    @objc public var notificationTypes: [NotificationType]? {
        get { return _notificationTypes }
        set { _notificationTypes = newValue }
    }
    private var _notificationTypes: [NotificationType]?

    /// The identity data associated with this user
    @objc public var idData: IdentityData? {
        get {
            return syncQueue.sync { _idData }
        }
        set {
            syncQueue.async(flags: .barrier) {
                if newValue !== self._idData {
                    self._idData = newValue
                }
            }
        }
    }
    private var _idData: IdentityData?

    /// The user's photo. Usually store a thumbnail of the user. To set this property use `setPhoto:completion:`
    @objc public var photo: UIImage? {
        get {
            if _photo == nil {
                syncQueue.sync {
                    if let photoPath = photoPathInternal(nil), FileManager.default.fileExists(atPath: photoPath) {
                        if let decryptedPhoto = decryptPhoto(photoPath) {
                            _photo = decryptedPhoto
                        }
                    }
                }
            }
            return _photo
        }
    }
    private var _photo: UIImage?

    /// The access restriction associated with this user
    public var accessRestrictions: UserAccount.AccessRestriction = []

    /// Returns true if the user has an access token and, presumably, a valid session.
    @objc public var isSessionValid: Bool {
        return _credentials.accessToken != nil && _idData != nil
    }

    /// Indicates if this account was deleted.  Returns true if this account was deleted since being created.
    @objc public internal(set) var isUserDeleted: Bool = false

    /// Indicates this user's current login state.
    @objc public private(set) var loginState: SFUserAccountLoginState = .notLoggedIn

    // MARK: - Internal Properties

    internal var customData: NSMutableDictionary?

    // MARK: - Private Properties

    private let syncQueue: DispatchQueue
    private var observingCredentials = false

    // MARK: - NSSecureCoding

    @objc public static var supportsSecureCoding: Bool {
        return true
    }

    // MARK: - Initialization

    @objc public override convenience init() {
        self.init(credentials: OAuthCredentials(identifier: "", clientId: nil, encrypted: true))
    }

    @objc public init(credentials: OAuthCredentials) {
        self.syncQueue = DispatchQueue(label: kSyncQueue, attributes: .concurrent)
        super.init()
        setCredentialsInternal(credentials)
        self.loginState = credentials.refreshToken?.isEmpty == false ? .loggedIn : .notLoggedIn
        self._accountIdentity = SFUserAccountIdentity(userId: credentials.userId ?? "", orgId: credentials.organizationId ?? "")

        if loginState == .loggedIn {
            SFSDKAppFeatureMarkers.registerAppFeature(kSFAppFeatureOAuth)
        }
    }

    deinit {
        if observingCredentials {
            _credentials.removeObserver(self, forKeyPath: kCredentialsUserIdPropName)
            _credentials.removeObserver(self, forKeyPath: kCredentialsOrgIdPropName)
        }
    }

    @objc public required init?(coder decoder: NSCoder) {
        self.syncQueue = DispatchQueue(label: kSyncQueue, attributes: .concurrent)
        super.init()

        self._accessScopes = decoder.decodeObject(of: [NSSet.self, NSString.self], forKey: kUser_ACCESS_SCOPES) as? Set<String>
        self._accountIdentity = SFUserAccountIdentity(userId: "", orgId: "")

        if let creds = decoder.decodeObject(of: OAuthCredentials.self, forKey: kUser_CREDENTIALS) {
            setCredentialsInternal(creds)
        }

        self._idData = decoder.decodeObject(of: SFIdentityData.self, forKey: kUser_ID_DATA)
        self.customData = decoder.decodeObject(of: [NSDictionary.self, NSArray.self, NSString.self, NSNumber.self, NSNull.self, NSURL.self, NSDate.self], forKey: kUser_CUSTOM_DATA) as? NSMutableDictionary
        self.accessRestrictions = UserAccount.AccessRestriction(rawValue: UInt(decoder.decodeInteger(forKey: kUser_ACCESS_RESTRICTIONS)))
        self.loginState = (_credentials.refreshToken?.isEmpty == false) ? .loggedIn : .notLoggedIn

        if loginState == .loggedIn {
            SFSDKAppFeatureMarkers.registerAppFeature(kSFAppFeatureOAuth)
        }

        self._notificationTypes = decoder.decodeObject(of: [NSArray.self, SFSDKNotificationType.self], forKey: kUser_NOTIFICATION_TYPES) as? [NotificationType]
    }

    @objc public func encode(with encoder: NSCoder) {
        encoder.encode(_accessScopes, forKey: kUser_ACCESS_SCOPES)
        encoder.encode(_credentials, forKey: kUser_CREDENTIALS)
        encoder.encode(_idData, forKey: kUser_ID_DATA)
        encoder.encode(customData, forKey: kUser_CUSTOM_DATA)
        encoder.encode(accessRestrictions.rawValue, forKey: kUser_ACCESS_RESTRICTIONS)
        encoder.encode(_notificationTypes, forKey: kUser_NOTIFICATION_TYPES)
    }

    // MARK: - Custom Data Management

    /// Set object in customData dictionary
    /// - Parameters:
    ///   - object: The object to store, must be one of the following: String, NSNumber, NSArray, NSDictionary, URL, NSNull, Date
    ///   - key: An NSCopying key to store the object at
    @objc public func setCustomDataObject(_ object: NSCoding, forKey key: NSCopying) {
        syncQueue.async(flags: .barrier) {
            if self.customData == nil {
                self.customData = NSMutableDictionary()
            }
            self.customData?.setObject(object, forKey: key)
        }
    }

    /// Remove a custom data object for a key
    /// - Parameter key: The key for the object to remove
    @objc public func removeCustomDataObject(forKey key: Any) {
        syncQueue.async(flags: .barrier) {
            if self.customData == nil {
                self.customData = NSMutableDictionary()
            }
            self.customData?.removeObject(forKey: key)
        }
    }

    /// Retrieve the object stored in the custom data dictionary
    /// - Parameter key: The key for the object to retrieve
    /// - Returns: The object for a particular key
    @objc public func customDataObject(forKey key: Any) -> Any? {
        return syncQueue.sync(flags: .barrier) {
            if self.customData == nil {
                self.customData = NSMutableDictionary()
            }
            return self.customData?.object(forKey: key)
        }
    }

    // MARK: - Photo Management

    private var userPhotoDirectory: String? {
        let communityId = _credentials.communityId ?? kDefaultCommunityName
        return SFDirectoryManager.sharedManager().directory(
            forOrg: _credentials.organizationId,
            user: _credentials.userId,
            community: communityId,
            type: .libraryDirectory,
            components: ["mobilesdk", "photos"]
        )
    }

    private func photoPathInternal(_ error: NSErrorPointer) -> String? {
        guard let photoDir = userPhotoDirectory else { return nil }
        try? SFDirectoryManager.ensureDirectoryExists(photoDir)
        return (photoDir as NSString).appendingPathComponent(SFDirectoryManager.safeStringForDiskRepresentation(_credentials.userId ?? ""))
    }

    /// Sets the user's photo.
    /// - Parameters:
    ///   - photo: The user photo, usually the thumbnail of the user.
    ///   - completion: Optional callback block invoked when the photo has been set. If not set, an error is returned.
    @objc public func setPhoto(_ photo: UIImage?, completion: ((Error?) -> Void)?) {
        syncQueue.async(flags: .barrier) {
            var error: NSError?
            guard let photoPath = self.photoPathInternal(&error) else {
                SFSDKCoreLogger.e(type(of: self), message: "Unable to retrieve the photo path: \(error?.localizedDescription ?? "")")
                completion?(error)
                return
            }

            let fm = FileManager.default
            if fm.fileExists(atPath: photoPath) {
                do {
                    try fm.removeItem(atPath: photoPath)
                } catch let removeError as NSError {
                    SFSDKCoreLogger.e(type(of: self), message: "Unable to remove previous photo from disk: \(removeError.localizedDescription)")
                }
            }

            if let photo = photo {
                if let data = photo.pngData() {
                    if !self.storeEncryptedPhoto(data, path: photoPath, error: &error) {
                        completion?(error)
                        return
                    }
                }
            }

            self.willChangeValue(forKey: "photo")
            self._photo = photo
            self.didChangeValue(forKey: "photo")

            completion?(nil)
        }
    }

    private func storeEncryptedPhoto(_ photoData: Data, path photoPath: String, error: inout NSError?) -> Bool {
        guard let encryptedData = encryptPhoto(photoData) else {
            let errorMessage = "User photo data could not be encrypted."
            SFSDKCoreLogger.e(type(of: self), message: errorMessage)
            error = NSError(domain: kSFSDKUserAccountManagerErrorDomain,
                           code: 1001,
                           userInfo: [NSLocalizedDescriptionKey: errorMessage])
            return false
        }

        do {
            try encryptedData.write(to: URL(fileURLWithPath: photoPath), options: .atomic)
            return true
        } catch let writeError as NSError {
            SFSDKCoreLogger.e(type(of: self), message: "Unable to write photo to disk: \(writeError.localizedDescription)")
            error = writeError
            return false
        }
    }

    private func decryptPhoto(_ photoPath: String) -> UIImage? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: photoPath)),
              let encryptionKey = try? SFSDKKeyGenerator.encryptionKey(for: kUserAccountPhotoEncryptionKeyLabel),
              let decryptedData = try? SFSDKEncryptor.decrypt(data: data, using: encryptionKey) else {
            return nil
        }
        return UIImage(data: decryptedData)
    }

    private func encryptPhoto(_ data: Data) -> Data? {
        guard let encryptionKey = try? SFSDKKeyGenerator.encryptionKey(for: kUserAccountPhotoEncryptionKeyLabel),
              let encryptedData = try? SFSDKEncryptor.encrypt(data: data, using: encryptionKey) else {
            return nil
        }
        return encryptedData
    }

    // MARK: - Login State Management

    @objc @discardableResult
    public func transitionToLoginState(_ newLoginState: SFUserAccountLoginState) -> Bool {
        return syncQueue.sync(flags: .barrier) {
            let transitionSucceeded: Bool
            switch newLoginState {
            case .loggedIn:
                transitionSucceeded = (loginState == .notLoggedIn || loginState == .loggedIn)
            case .notLoggedIn:
                transitionSucceeded = (loginState == .notLoggedIn || loginState == .loggingOut)
            case .loggingOut:
                transitionSucceeded = (loginState == .loggedIn)
            @unknown default:
                transitionSucceeded = false
            }

            if transitionSucceeded {
                self.loginState = newLoginState
            } else {
                SFSDKCoreLogger.w(type(of: self), message: "\(#function) Invalid login state transition from '\(Self.loginStateDescription(from: loginState))' to '\(Self.loginStateDescription(from: newLoginState))'. No action taken.")
            }
            return transitionSucceeded
        }
    }

    @objc public class func loginStateDescription(from loginState: SFUserAccountLoginState) -> String {
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

    // MARK: - Credentials Management

    private func setCredentialsInternal(_ credentials: OAuthCredentials) {
        let currentCredentials = _credentials
        let accIdentity = _accountIdentity

        if credentials !== currentCredentials {
            if observingCredentials {
                currentCredentials?.removeObserver(self, forKeyPath: kCredentialsUserIdPropName)
                currentCredentials?.removeObserver(self, forKeyPath: kCredentialsOrgIdPropName)
                observingCredentials = false
            }

            credentials.addObserver(self, forKeyPath: kCredentialsUserIdPropName, options: [.old, .new], context: nil)
            credentials.addObserver(self, forKeyPath: kCredentialsOrgIdPropName, options: [.old, .new], context: nil)
            observingCredentials = true

            _credentials = credentials
            if let accIdentity = accIdentity {
                accIdentity.userId = credentials.userId ?? ""
                accIdentity.orgId = credentials.organizationId ?? ""
            }
        }
    }

    // MARK: - KVO

    public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        guard let keyPath = keyPath,
              let object = object as? OAuthCredentials,
              object === _credentials,
              (keyPath == kCredentialsUserIdPropName || keyPath == kCredentialsOrgIdPropName) else {
            return
        }

        var oldKey = change?[.oldKey] as? String
        var newKey = change?[.newKey] as? String

        if oldKey == nil || (oldKey as? NSNull) != nil {
            oldKey = nil
        }
        if newKey == nil || (newKey as? NSNull) != nil {
            newKey = nil
        }

        if keyPath == kCredentialsUserIdPropName {
            _accountIdentity.userId = newKey ?? ""
        } else if keyPath == kCredentialsOrgIdPropName {
            _accountIdentity.orgId = newKey ?? ""
        }
    }

    // MARK: - Description

    public override var description: String {
        var theUserName = "*****"
        var theFullName = "*****"

        #if DEBUG
        theUserName = _idData?.username ?? ""
        theFullName = "\(_idData?.firstName ?? "") \(_idData?.lastName ?? "")"
        #endif

        return "<SFUserAccount username=\(theUserName) fullName=\(theFullName) accessScopes=\(_accessScopes?.description ?? "nil") credentials=\(_credentials?.description ?? "nil")>"
    }

    /// The account scope enumeration
    /// This mirrors the Objective-C SFUserAccountScope enum for Swift compatibility
    @objc public enum AccountScope: UInt, @unchecked Sendable {
        case global = 0
        case org
        case user
        case community
    }

    /// The access restrictions option set
    /// This mirrors the Objective-C SFUserAccountAccessRestriction options
    public struct AccessRestriction: OptionSet, @unchecked Sendable {
        public let rawValue: UInt

        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        public static let none = AccessRestriction([])
        public static let chatter = AccessRestriction(rawValue: 1 << 0)
        public static let rest = AccessRestriction(rawValue: 1 << 1)
        public static let other = AccessRestriction(rawValue: 1 << 2)
    }
}

/// The login state enumeration
/// This represents the various login states for a user account
@objc public enum SFUserAccountLoginState: UInt, @unchecked Sendable {
    case notLoggedIn = 0
    case loggedIn
    case loggingOut
}

// MARK: - Global Functions

private let kGlobalScopingKey = "-global-"

/// Function that returns a key for scope SFUserAccountScopeGlobal
/// - Returns: a key identifying this scope for the specified scope
/// Note: Cannot use @objc on top-level functions in Swift - Obj-C code should use the string value directly
public func SFKeyForGlobalScope() -> String {
    return SFKeyForUserIdAndScope(nil, nil, nil, .global)
}

/// Function that returns a key that uniquely identifies this user account for the given scope.
/// Note that if you use SFUserAccountScopeGlobal, the same key will be returned regardless of the user account.
/// - Parameters:
///   - user: The user
///   - scope: The scope
/// - Returns: a key identifying this user account for the specified scope
/// Note: Cannot use @objc on top-level functions in Swift - Obj-C code should use the string value directly
public func SFKeyForUserAndScope(_ user: UserAccount?, _ scope: UserAccount.AccountScope) -> String {
    return SFKeyForUserIdAndScope(user?.credentials.userId, user?.credentials.organizationId, user?.credentials.communityId, scope)
}

/// Function that returns a key that uniquely identifies this user, org & community for the given scope.
/// Note that if you use SFUserAccountScopeGlobal, the same key will be returned regardless of the user account.
/// - Parameters:
///   - userId: The user identifier
///   - orgId: The org identifier
///   - communityId: The community id identifier
///   - scope: The scope
/// - Returns: a key identifying this user account for the specified scope
/// Note: Cannot use @objc on top-level functions in Swift - Obj-C code should use the string value directly
public func SFKeyForUserIdAndScope(_ userId: String?, _ orgId: String?, _ communityId: String?, _ scope: UserAccount.AccountScope) -> String {
    var key = ""

    switch scope {
    case .global:
        key = kGlobalScopingKey
    case .org:
        if let orgId = orgId {
            key = orgId
        }
    case .user:
        if let orgId = orgId, let userId = userId {
            key = "\(orgId)-\(userId)"
        }
    case .community:
        if let orgId = orgId, let userId = userId {
            key = "\(orgId)-\(userId)-\(communityId ?? "")"
        }
    @unknown default:
        break
    }

    return key
}
