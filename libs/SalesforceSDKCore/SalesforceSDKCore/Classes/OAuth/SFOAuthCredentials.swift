// Copyright (c) 2011-present, salesforce.com, inc. All rights reserved.
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

// MARK: - Constants

private let kSFOAuthArchiveVersion = "1.0.3"
private let kSFOAuthProtocolHttps = "https"
private let kSFOAuthDefaultDomain = "login.salesforce.com"
private let kSFOAuthClusterImplementationKey = "SFOAuthClusterImplementation"

// Keychain service constants
public let kSFOAuthServiceAccess = "com.salesforce.mobilesdk.oauth.access"
public let kSFOAuthServiceRefresh = "com.salesforce.mobilesdk.oauth.refresh"
public let kSFOAuthServiceLightningSid = "com.salesforce.mobilesdk.oauth.lightningSid"
public let kSFOAuthServiceVfSid = "com.salesforce.mobilesdk.oauth.vfSid"
public let kSFOAuthServiceContentSid = "com.salesforce.mobilesdk.oauth.contentSid"
public let kSFOAuthServiceCsrf = "com.salesforce.mobilesdk.oauth.csrf"
public let kSFOAuthServiceParentSid = "com.salesforce.mobilesdk.oauth.parentSid"
public let kSFOAuthServiceBeaconChildConsumerKey = "com.salesforce.mobilesdk.oauth.beaconChildConsumerKey"
public let kSFOAuthServiceBeaconChildConsumerSecret = "com.salesforce.mobilesdk.oauth.beaconChildConsumerSecret"

public let kSFOAuthServiceLegacyAccess = "com.salesforce.oauth.access"
public let kSFOAuthServiceLegacyRefresh = "com.salesforce.oauth.refresh"

// MARK: - StorageType Enum

@objc(SFOAuthCredentialsStorageType)
public enum OAuthCredentialsStorageType: Int {
    case none = -1
    case keychain = 0
}

// MARK: - OAuthCredentials

@objc(SFOAuthCredentials)
open class OAuthCredentials: NSObject, NSSecureCoding, NSCopying {

    // MARK: - Properties

    @objc public var `protocol`: String?
    @objc public var domain: String?
    @objc public var identifier: String
    @objc public var clientId: String?
    @objc public var redirectUri: String?
    @objc public var jwt: String?
    @objc public var refreshToken: String?
    @objc public var accessToken: String?
    // `dynamic` is required for KVO: UserAccount observes userId/organizationId to keep its
    // accountIdentity in sync (SFUserAccount addObserver/observeValue). In ObjC these were plain
    // @property (KVO-compliant); a Swift `@objc var` without `dynamic` does NOT emit KVO notifications,
    // which would leave accountIdentity stale (empty) after identityUrl/credentials updates.
    @objc public dynamic var organizationId: String?
    @objc public var instanceUrl: URL?
    @objc public var apiInstanceUrl: URL?
    @objc public var scopes: [String]?
    @objc public var communityId: String?
    @objc public var communityUrl: URL?
    @objc public var issuedAt: Date?
    @objc public var identityUrl: URL? {
        didSet {
            userId = nil
            organizationId = nil
            if let path = identityUrl?.path {
                let pathComps = path.components(separatedBy: "/")
                if pathComps.count < 2 {
                    SFSDKCoreLogger.d(type(of: self), message: "\(type(of: self)):setIdentityUrl: invalid identityUrl: \(String(describing: identityUrl))")
                    return
                }
                userId = pathComps[pathComps.count - 1]
                organizationId = pathComps[pathComps.count - 2]
            } else {
                SFSDKCoreLogger.d(type(of: self), message: "\(type(of: self)):setIdentityUrl: invalid or nil identityUrl: \(String(describing: identityUrl))")
            }
        }
    }
    @objc public dynamic var userId: String?  // `dynamic` required for KVO — see organizationId note above.
    @objc public private(set) var isEncrypted: Bool

    @objc public var additionalOAuthFields: NSDictionary?
    @objc public var challengeString: String?
    @objc public var authCode: String?

    @objc public var lightningDomain: String?
    @objc public var lightningSid: String?
    @objc public var vfDomain: String?
    @objc public var vfSid: String?
    @objc public var contentDomain: String?
    @objc public var contentSid: String?
    @objc public var csrfToken: String?
    @objc public var cookieClientSrc: String?
    @objc public var cookieSidClient: String?
    @objc public var sidCookieName: String?
    @objc public var parentSid: String?
    @objc public var tokenFormat: String?
    @objc public var beaconChildConsumerKey: String?
    @objc public var beaconChildConsumerSecret: String?

    // MARK: - Credentials Change Tracking

    @objc public var credentialsChangeSet: NSMutableDictionary?

    // MARK: - Computed Properties

    @objc public var apiUrl: URL? {
        if let communityUrl = communityUrl {
            return communityUrl
        }
        return instanceUrl
    }

    // MARK: - NSSecureCoding

    @objc open class var supportsSecureCoding: Bool { true }

    // MARK: - Initialization (Factory)

    /// Factory initializer that returns the appropriate subclass based on storage type.
    /// Returns nil only if identifier is empty.
    /// Convenience initializer that defaults to keychain storage.
    /// Returns nil for base OAuthCredentials since keychain requires the subclass.
    /// Use `OAuthCredentials.credentials(identifier:clientId:encrypted:storageType:)` factory for keychain.
    @objc public convenience init?(identifier theIdentifier: String, clientId theClientId: String?, encrypted: Bool) {
        self.init(identifier: theIdentifier, clientId: theClientId, encrypted: encrypted, storageType: .keychain)
    }

    /// Factory method that creates keychain-backed credentials (default storage type).
    @objc public class func credentials(identifier theIdentifier: String, clientId theClientId: String?, encrypted: Bool) -> OAuthCredentials? {
        return credentials(identifier: theIdentifier, clientId: theClientId, encrypted: encrypted, storageType: .keychain)
    }

    /// Factory method that creates the appropriate credentials subclass based on storage type.
    /// This replaces the ObjC class-cluster pattern.
    @objc public class func credentials(identifier theIdentifier: String, clientId theClientId: String?, encrypted: Bool, storageType type: OAuthCredentialsStorageType) -> OAuthCredentials? {
        switch type {
        case .keychain:
            return OAuthKeychainCredentials(identifier: theIdentifier, clientId: theClientId, encrypted: encrypted, storageType: type)
        default:
            return OAuthCredentials(internalIdentifier: theIdentifier, clientId: theClientId, encrypted: encrypted)
        }
    }

    @objc public convenience init?(identifier theIdentifier: String, clientId theClientId: String?, encrypted: Bool, storageType type: OAuthCredentialsStorageType) {
        switch type {
        case .keychain:
            if Swift.type(of: self) == OAuthCredentials.self {
                // Base class can't become keychain subclass; use factory method or call OAuthKeychainCredentials directly
                return nil
            }
            self.init(internalIdentifier: theIdentifier, clientId: theClientId, encrypted: encrypted)
        default:
            self.init(internalIdentifier: theIdentifier, clientId: theClientId, encrypted: encrypted)
        }
    }

    /// No-arg initializer for backward compatibility (used by SFUserAccount as placeholder)
    @objc public convenience override init() {
        self.init(internalIdentifier: "", clientId: nil, encrypted: false)
    }

    /// Internal designated initializer used by subclass
    internal init(internalIdentifier theIdentifier: String, clientId theClientId: String?, encrypted: Bool) {
        self.identifier = theIdentifier
        self.clientId = theClientId
        self.domain = kSFOAuthDefaultDomain
        self.protocol = kSFOAuthProtocolHttps
        self.isEncrypted = encrypted
        self.credentialsChangeSet = NSMutableDictionary()
        super.init()
    }

    // MARK: - NSCoding

    @objc public required init?(coder: NSCoder) {
        let clusterClassName = coder.decodeObject(of: NSString.self, forKey: kSFOAuthClusterImplementationKey) as String? ?? ""

        let resolvedClassName: String
        if clusterClassName.isEmpty {
            // Legacy credentials without persisted implementation class default to keychain
            resolvedClassName = "SFOAuthKeychainCredentials"
        } else {
            resolvedClassName = clusterClassName
        }

        // Determine expected class
        let clusterClass: AnyClass = NSClassFromString(resolvedClassName) ?? OAuthCredentials.self

        // If this instance IS the correct class, decode properties
        guard Swift.type(of: self) == clusterClass else {
            // Wrong class - we need to create the correct one
            // This path is used by the base class to delegate to subclass
            self.identifier = ""
            self.isEncrypted = false
            super.init()
            return nil
        }

        // Decode all properties
        self.identifier = coder.decodeObject(of: NSString.self, forKey: "SFOAuthIdentifier") as String? ?? ""
        self.domain = coder.decodeObject(of: NSString.self, forKey: "SFOAuthDomain") as String?
        self.clientId = coder.decodeObject(of: NSString.self, forKey: "SFOAuthClientId") as String?
        self.redirectUri = coder.decodeObject(of: NSString.self, forKey: "SFOAuthRedirectUri") as String?
        self.organizationId = coder.decodeObject(of: NSString.self, forKey: "SFOAuthOrganizationId") as String?
        self.identityUrl = coder.decodeObject(of: NSURL.self, forKey: "SFOAuthIdentityUrl") as URL?
        self.instanceUrl = coder.decodeObject(of: NSURL.self, forKey: "SFOAuthInstanceUrl") as URL?
        self.apiInstanceUrl = coder.decodeObject(of: NSURL.self, forKey: "SFOAuthApiInstanceUrl") as URL?
        self.scopes = coder.decodeObject(of: [NSArray.self, NSString.self], forKey: "SFOAuthScopes") as? [String]
        self.communityId = coder.decodeObject(of: NSString.self, forKey: "SFOAuthCommunityId") as String?
        self.communityUrl = coder.decodeObject(of: NSURL.self, forKey: "SFOAuthCommunityUrl") as URL?
        self.issuedAt = coder.decodeObject(of: NSDate.self, forKey: "SFOAuthIssuedAt") as Date?
        self.additionalOAuthFields = coder.decodeObject(of: [NSDictionary.self, NSString.self], forKey: "SFOAuthAdditionalFields") as? NSDictionary

        let protocolVal = coder.decodeObject(of: NSString.self, forKey: "SFOAuthProtocol") as String?
        self.protocol = protocolVal ?? kSFOAuthProtocolHttps

        if let encryptedNumber = coder.decodeObject(of: NSNumber.self, forKey: "SFOAuthEncrypted") {
            self.isEncrypted = encryptedNumber.boolValue
        } else {
            self.isEncrypted = coder.decodeBool(forKey: "SFOAuthEncrypted")
        }

        self.lightningDomain = coder.decodeObject(of: NSString.self, forKey: "SFOAuthLightningDomain") as String?
        self.vfDomain = coder.decodeObject(of: NSString.self, forKey: "SFOAuthVFDomain") as String?
        self.contentDomain = coder.decodeObject(of: NSString.self, forKey: "SFOAuthContentDomain") as String?
        self.cookieClientSrc = coder.decodeObject(of: NSString.self, forKey: "SFOAuthClientSrc") as String?
        self.cookieSidClient = coder.decodeObject(of: NSString.self, forKey: "SFOAuthCookieSidClient") as String?
        self.sidCookieName = coder.decodeObject(of: NSString.self, forKey: "SFOAuthSidCookieName") as String?
        self.tokenFormat = coder.decodeObject(of: NSString.self, forKey: "SFOAuthTokenFormat") as String?

        self.credentialsChangeSet = NSMutableDictionary()

        super.init()

        // For base class (non-keychain), also decode tokens from archive (backward compat)
        if Swift.type(of: self) == OAuthCredentials.self {
            self.refreshToken = coder.decodeObject(of: NSString.self, forKey: "SFOAuthRefreshToken") as String?
            self.accessToken = coder.decodeObject(of: NSString.self, forKey: "SFOAuthAccessToken") as String?
            self.lightningSid = coder.decodeObject(of: NSString.self, forKey: "SFOAuthLightningSID") as String?
            self.vfSid = coder.decodeObject(of: NSString.self, forKey: "SFOAuthVFSID") as String?
            self.contentSid = coder.decodeObject(of: NSString.self, forKey: "SFOAuthContentSID") as String?
            self.csrfToken = coder.decodeObject(of: NSString.self, forKey: "SFOAuthCSRFToken") as String?
            self.parentSid = coder.decodeObject(of: NSString.self, forKey: "SFOAuthParentSID") as String?
            self.beaconChildConsumerKey = coder.decodeObject(of: NSString.self, forKey: "SFOAuthBeaconChildConsumerKey") as String?
            self.beaconChildConsumerSecret = coder.decodeObject(of: NSString.self, forKey: "SFOAuthBeaconChildConsumerSecret") as String?
        }
    }

    @objc public func encode(with coder: NSCoder) {
        coder.encode(NSStringFromClass(Swift.type(of: self)), forKey: kSFOAuthClusterImplementationKey)
        coder.encode(identifier, forKey: "SFOAuthIdentifier")
        coder.encode(domain, forKey: "SFOAuthDomain")
        coder.encode(clientId, forKey: "SFOAuthClientId")
        coder.encode(redirectUri, forKey: "SFOAuthRedirectUri")
        coder.encode(organizationId, forKey: "SFOAuthOrganizationId")
        coder.encode(identityUrl, forKey: "SFOAuthIdentityUrl")
        coder.encode(instanceUrl, forKey: "SFOAuthInstanceUrl")
        coder.encode(apiInstanceUrl, forKey: "SFOAuthApiInstanceUrl")
        coder.encode(scopes, forKey: "SFOAuthScopes")
        coder.encode(communityId, forKey: "SFOAuthCommunityId")
        coder.encode(communityUrl, forKey: "SFOAuthCommunityUrl")
        coder.encode(issuedAt, forKey: "SFOAuthIssuedAt")
        coder.encode(self.protocol, forKey: "SFOAuthProtocol")
        coder.encode(lightningDomain, forKey: "SFOAuthLightningDomain")
        coder.encode(vfDomain, forKey: "SFOAuthVFDomain")
        coder.encode(contentDomain, forKey: "SFOAuthContentDomain")
        coder.encode(cookieClientSrc, forKey: "SFOAuthClientSrc")
        coder.encode(cookieSidClient, forKey: "SFOAuthCookieSidClient")
        coder.encode(sidCookieName, forKey: "SFOAuthSidCookieName")
        coder.encode(tokenFormat, forKey: "SFOAuthTokenFormat")
        coder.encode(kSFOAuthArchiveVersion, forKey: "SFOAuthArchiveVersion")
        coder.encode(NSNumber(value: isEncrypted), forKey: "SFOAuthEncrypted")
        coder.encode(additionalOAuthFields, forKey: "SFOAuthAdditionalFields")
        // Tokens are intentionally NOT encoded for security
    }

    // MARK: - NSCopying

    @objc public func copy(with zone: NSZone? = nil) -> Any {
        let copy: OAuthCredentials
        if Swift.type(of: self) == OAuthKeychainCredentials.self {
            copy = OAuthKeychainCredentials(internalIdentifier: identifier, clientId: clientId, encrypted: isEncrypted)
        } else {
            copy = OAuthCredentials(internalIdentifier: identifier, clientId: clientId, encrypted: isEncrypted)
        }

        copy.protocol = self.protocol
        copy.domain = self.domain
        copy.redirectUri = self.redirectUri
        copy.jwt = self.jwt
        copy.refreshToken = self.refreshToken
        copy.accessToken = self.accessToken
        copy.instanceUrl = self.instanceUrl
        copy.apiInstanceUrl = self.apiInstanceUrl
        copy.scopes = self.scopes
        copy.communityId = self.communityId
        copy.communityUrl = self.communityUrl
        copy.issuedAt = self.issuedAt

        // Set identityUrl first, then override orgId/userId (identityUrl setter derives them)
        copy.identityUrl = self.identityUrl
        copy.organizationId = self.organizationId
        copy.userId = self.userId
        copy.lightningDomain = self.lightningDomain
        copy.lightningSid = self.lightningSid
        copy.vfDomain = self.vfDomain
        copy.vfSid = self.vfSid
        copy.contentDomain = self.contentDomain
        copy.contentSid = self.contentSid
        copy.csrfToken = self.csrfToken
        copy.cookieClientSrc = self.cookieClientSrc
        copy.cookieSidClient = self.cookieSidClient
        copy.sidCookieName = self.sidCookieName
        copy.parentSid = self.parentSid
        copy.tokenFormat = self.tokenFormat
        copy.beaconChildConsumerKey = self.beaconChildConsumerKey
        copy.beaconChildConsumerSecret = self.beaconChildConsumerSecret
        copy.additionalOAuthFields = self.additionalOAuthFields?.copy() as? NSDictionary

        return copy
    }

    // MARK: - Public Methods

    @objc public func revoke() {
        revokeAccessToken()
        revokeRefreshToken()
    }

    @objc public func revokeAccessToken() {
        guard !identifier.isEmpty else {
            NSException(name: .internalInconsistencyException, reason: "identifier cannot be nil or empty", userInfo: nil).raise()
            return
        }
        SFSDKCoreLogger.d(type(of: self), message: "\(type(of: self)):revokeAccessToken: access token revoked")
        accessToken = nil
    }

    @objc public func revokeRefreshToken() {
        guard !identifier.isEmpty else {
            NSException(name: .internalInconsistencyException, reason: "identifier cannot be nil or empty", userInfo: nil).raise()
            return
        }
        SFSDKCoreLogger.d(type(of: self), message: "\(type(of: self)):revokeRefreshToken: refresh token revoked. Cleared identityUrl, instanceUrl, issuedAt fields")
        refreshToken = nil
        instanceUrl = nil
        apiInstanceUrl = nil
        scopes = nil
        communityId = nil
        communityUrl = nil
        issuedAt = nil
        identityUrl = nil
        lightningDomain = nil
        lightningSid = nil
        vfDomain = nil
        vfSid = nil
        contentDomain = nil
        contentSid = nil
        csrfToken = nil
        cookieClientSrc = nil
        cookieSidClient = nil
        sidCookieName = nil
        parentSid = nil
        tokenFormat = nil
        beaconChildConsumerKey = nil
        beaconChildConsumerSecret = nil
    }

    @objc public func setPropertyForKey(_ propertyName: String, withValue newValue: Any?) {
        let oldValue = self.value(forKey: propertyName)
        if let newValue = newValue {
            if let oldNS = oldValue as? NSObject, let newNS = newValue as? NSObject {
                if !newNS.isEqual(oldNS) {
                    credentialsChangeSet?.setValue([oldNS, newNS], forKey: propertyName)
                }
            } else if oldValue == nil {
                credentialsChangeSet?.setValue([NSNull(), newValue], forKey: propertyName)
            }
        }
        self.setValue(newValue, forKey: propertyName)
    }

    @objc public func resetCredentialsChangeSet() {
        credentialsChangeSet?.removeAllObjects()
    }

    @objc public func hasPropertyValueChangedForKey(_ key: String?) -> Bool {
        guard let key = key else { return false }
        return credentialsChangeSet?.object(forKey: key) != nil
    }

    @objc public func overrideDomainIfNeeded() -> URL {
        let domainStr = communityId != nil ? communityUrl?.absoluteString ?? domain : domain
        let protocolHost: String
        if communityId != nil {
            protocolHost = domainStr ?? ""
        } else {
            protocolHost = "\(self.protocol ?? kSFOAuthProtocolHttps)://\(domainStr ?? "")"
        }
        // Force unwrap is safe here because the protocol+domain combination always forms a valid URL
        return URL(string: protocolHost) ?? URL(string: "\(kSFOAuthProtocolHttps)://\(kSFOAuthDefaultDomain)")!
    }

    /// Update credentials from parameters dictionary.
    /// Called from Swift as `credentials.update(params)` and from ObjC as `[credentials updateCredentials:params]`.
    @objc(updateCredentials:)
    public func update(_ params: [AnyHashable: Any]) {
        // Convert to [String: Any]
        var stringParams: [String: Any] = [:]
        for (key, value) in params {
            if let stringKey = key as? String {
                stringParams[stringKey] = value
            }
        }
        updateCredentialsInternal(stringParams)
    }

    /// Swift-only convenience overload accepting typed dictionary
    public func updateCredentials(_ params: [String: Any]) {
        updateCredentialsInternal(params)
    }

    private func updateCredentialsInternal(_ params: [String: Any]) {
        if let accessTokenVal = params["access_token"] as? String {
            setPropertyForKey("accessToken", withValue: accessTokenVal)
        }
        if let issuedAtVal = params["issued_at"] as? String {
            let unixTimeInSecs = (Double(issuedAtVal) ?? 0) / 1000.0
            issuedAt = Date(timeIntervalSince1970: unixTimeInSecs)
        }
        if let instanceUrlStr = params["instance_url"] as? String {
            setPropertyForKey("instanceUrl", withValue: URL(string: instanceUrlStr))
        }
        if let apiInstanceUrlStr = params["api_instance_url"] as? String {
            setPropertyForKey("apiInstanceUrl", withValue: URL(string: apiInstanceUrlStr))
        }
        if let scopeStr = params["scope"] as? String {
            let scopesArray = scopeStr.components(separatedBy: " ")
            setPropertyForKey("scopes", withValue: scopesArray)
        }
        if let idStr = params["id"] as? String {
            setPropertyForKey("identityUrl", withValue: URL(string: idStr))
        }
        if let communityIdVal = params["sfdc_community_id"] as? String {
            setPropertyForKey("communityId", withValue: communityIdVal)
        }
        if let communityUrlStr = params["sfdc_community_url"] as? String {
            setPropertyForKey("communityUrl", withValue: URL(string: communityUrlStr))
        }
        if let refreshTokenVal = params["refresh_token"] as? String {
            setPropertyForKey("refreshToken", withValue: refreshTokenVal)
        }
        if let val = params["lightning_domain"] as? String { lightningDomain = val }
        if let val = params["lightning_sid"] as? String { lightningSid = val }
        if let val = params["visualforce_domain"] as? String { vfDomain = val }
        if let val = params["visualforce_sid"] as? String { vfSid = val }
        if let val = params["content_domain"] as? String { contentDomain = val }
        if let val = params["content_sid"] as? String { contentSid = val }
        if let val = params["csrf_token"] as? String { csrfToken = val }
        if let val = params["cookie-clientSrc"] as? String { cookieClientSrc = val }
        if let val = params["cookie-sid_Client"] as? String { cookieSidClient = val }
        if let val = params["sidCookieName"] as? String { sidCookieName = val }
        if let val = params["parent_sid"] as? String { parentSid = val }
        if let val = params["token_format"] as? String { tokenFormat = val }
        if let val = params["beacon_child_consumer_key"] as? String { beaconChildConsumerKey = val }
        if let val = params["beacon_child_consumer_secret"] as? String { beaconChildConsumerSecret = val }
    }

    /// Returns the oauth client id to use for refresh.
    /// In the case of beacon app, the beacon child consumer key returned during login should be used.
    @objc public func getClientIdForRefresh() -> String? {
        if let beaconKey = beaconChildConsumerKey, !beaconKey.isEmpty {
            return beaconKey
        }
        return clientId
    }

    // MARK: - Description

    open override var description: String {
        return "<\(NSStringFromClass(Swift.type(of: self))): \(Unmanaged.passUnretained(self).toOpaque()), identifier=\"\(identifier)\" clientId=\"\(clientId ?? "")\" domain=\"\(domain ?? "")\" identityUrl=\"\(String(describing: identityUrl))\" instanceUrl=\"\(String(describing: instanceUrl))\" apiInstanceUrl=\"\(String(describing: apiInstanceUrl))\" communityId=\"\(communityId ?? "")\" communityUrl=\"\(String(describing: communityUrl))\" scopes=\"\(String(describing: scopes))\" issuedAt=\"\(String(describing: issuedAt))\" organizationId=\"\(organizationId ?? "")\" protocol=\"\(self.protocol ?? "")\" redirectUri=\"\(redirectUri ?? "")\">"
    }
}

// MARK: - Exception helper (for ObjC callers)

public func SFOAuthInvalidIdentifierException() -> NSException? {
    return NSException(name: .internalInconsistencyException, reason: "identifier cannot be nil or empty", userInfo: nil)
}
