/*
 Copyright (c) 2011-present, salesforce.com, inc. All rights reserved.

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

// MARK: - Constants

private let kSFOAuthArchiveVersion = "1.0.3"
private let kSFOAuthAccessGroup = "com.salesforce.oauth"
private let kSFOAuthProtocolHttps = "https"

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

private let kSFOAuthDefaultDomain = "login.salesforce.com"
private let kSFOAuthClusterImplementationKey = "SFOAuthClusterImplementation"

public func SFOAuthInvalidIdentifierException() -> NSException {
    return NSException(
        name: NSExceptionName.internalInconsistencyException,
        reason: "identifier cannot be nil or empty",
        userInfo: nil
    )
}

// MARK: - Storage Type

/**
 OAuth credential storage type
 */
@objc(SFOAuthCredentialsStorageType)
public enum OAuthCredentialsStorageType: Int {
    /**
     No storage or persistence of OAuth credentials will be attempted
     */
    case none = -1
    /**
     OAuth credentials will be stored securely within the keychain.
     */
    case keychain
}

// MARK: - Encryption Type

@objc(SFOAuthCredsEncryptionType)
public enum OAuthCredsEncryptionType: UInt {
    case notSet
    case mac
    case idForVendor
    case baseAppId
    case keyStore
}

// MARK: - OAuth Credentials

/** Object representing an individual user account's logon credentials.

 This object represents information about a user account necessary to authenticate and
 reauthenticate against Salesforce.com servers using OAuth2. It includes information such as
 the user's account ID, the protocol to use, and any session or refresh tokens assigned
 by the server.

 The secure information contained in this object is persisted securely within the
 device's Keychain, and is accessed by using the `identifier` property.

 Instances of this object are used to begin the authentication process, by supplying
 it to an `SFOAuthCoordinator` instance which conducts the authentication workflow.

 The credentials stored in this object include:

 - Consumer key and secret

 - Request token and secret

 - Access token and secret

 @see SFOAuthCoordinator
 */
@objc(SFOAuthCredentials)
open class OAuthCredentials: NSObject, NSSecureCoding, NSCopying {

    // MARK: - Private Storage

    private var _identifier: String
    private var _clientId: String?
    private var _protocol: String?
    private var _domain: String?
    private var _identityUrl: URL?
    private var _organizationId: String?
    private var _userId: String?
    private let _encrypted: Bool

    internal var credentialsChangeSet: NSMutableDictionary

    // MARK: - Public Properties

    /** Protocol scheme for authenticating this account.
     */
    @objc open private(set) var `protocol`: String? {
        get { return _protocol }
        set { _protocol = newValue }
    }

    /** Logon host domain name.

     The domain used to initiate a user login, for example _login.salesforce.com_
     or _test.salesforce.com_. The default is _login.salesforce.com_.
     */
    @objc open private(set) var domain: String? {
        get { return _domain }
        set { _domain = newValue }
    }

    /** Credential identifier used to uniquely identify this credential in the keychain.

     @warning This property is used by many underlying internal functions of this class and therefore must not be set to a
     `nil` or empty value prior to accessing properties or methods identified in the documentation regarding this prohibition.
     @warning This property must not be modified while authenticating.
     */
    @objc open private(set) var identifier: String {
        get {
            return _identifier
        }
        set {
            objc_sync_enter(self)
            defer { objc_sync_exit(self) }
            if newValue != _identifier {
                _identifier = newValue
            }
        }
    }

    /** Client consumer key.

     Identifies the client for remote authentication.

     @warning This property must not be `nil` or empty when authentication is initiated or an exception will be raised.
     @warning This property must not be modified while authenticating.
     */
    @objc open private(set) var clientId: String? {
        get {
            objc_sync_enter(self)
            defer { objc_sync_exit(self) }
            return _clientId
        }
        set {
            objc_sync_enter(self)
            defer { objc_sync_exit(self) }
            if newValue != _clientId {
                _clientId = newValue
            }
        }
    }

    /** Callback URL to load at the end of the authentication process.

     This must match the callback URL in the Remote Access object exactly, or authentication will fail.
     */
    @objc open var redirectUri: String?

    /** JWT.

     JWT code used in the client breeze link flow.
     @warning This property must not be modified while authenticating.
     @warning This property should be set to nil after authentication.
     */
    @objc open var jwt: String?

    /** Token used to refresh the user's session.

     This property is set by the `SFOAuthCoordinator` after authentication has successfully completed.

     @warning The setter for this property is exposed publicly only for unit tests. Client code should use the revoke methods instead.
     @exception NSInternalInconsistencyException If this property is accessed when the identifier property is `nil`.
     */
    @objc open var refreshToken: String?

    /** The access token for the user's session.

     This property is set by the `SFOAuthCoordinator` after authentication has successfully completed.

     @warning The setter for this property is exposed publicly only for unit tests. Client code should use the revoke methods instead.
     @exception NSInternalInconsistencyException If accessed while the identifier property is `nil`.
     */
    @objc open var accessToken: String?

    @objc open var lightningDomain: String?
    @objc open var lightningSid: String?
    @objc open var vfDomain: String?
    @objc open var vfSid: String?
    @objc open var contentDomain: String?
    @objc open var contentSid: String?
    @objc open var csrfToken: String?
    @objc open var cookieClientSrc: String?
    @objc open var cookieSidClient: String?
    @objc open var sidCookieName: String?
    @objc open var parentSid: String?
    @objc open var tokenFormat: String?
    @objc open var beaconChildConsumerKey: String?
    @objc open var beaconChildConsumerSecret: String?

    /** A readonly convenience property returning the Salesforce Organization ID provided in the path component of the identityUrl.

     This property is available after authentication has successfully completed.

     @exception NSInternalInconsistencyException If accessed while the identifier property is `nil`.
     */
    @objc open internal(set) var organizationId: String? {
        get { return _organizationId }
        set { _organizationId = newValue }
    }

    /** The URL of the server instance for this session. This URL always refers to the base organization
     instance, even if the user has logged through a community-based login flow.
     See `community_id` and `community_url`.

     This is the URL that client requests should be made to after authentication completes.
     This property is set by the `SFOAuthCoordinator` after authentication has successfully completed.
     */
    @objc open var instanceUrl: URL?

    /** The URL of the  SFAP  server instance for this session.

     This is the URL that client SFAP requests should be made to after authentication completes.
     This property is set by the `SFOAuthCoordinator` after authentication has successfully completed.
     This URL is only defined when sfap_api scope is used.
     */
    @objc open var apiInstanceUrl: URL?

    /** The OAuth scopes granted for this session.

     This property contains the list of OAuth scopes that were granted during authentication.
     This property is set by the `SFOAuthCoordinator` after authentication has successfully completed.
     */
    @objc open var scopes: [String]?

    /** The community ID the user choose to log into. This usually happens when the user
     logs into the app using a community-based login page

     Note: this property is nil of the user logs into the internal community or into an org that doesn't have communities.
     */
    @objc open var communityId: String?

    /** The community-base URL the user choose to log into. This usually happens when the user
     logs into the app using a community-based login page

     Note: this property is nil if the user logs into the internal community or into an org that doesn't have communities.
     */
    @objc open var communityUrl: URL?

    /** The timestamp when the session access token was issued.

     This property is set by the `SFOAuthCoordinator` after authentication has successfully completed.
     */
    @objc open var issuedAt: Date?

    /** The identity URL for the user returned as part of a successful authentication response.
     The format of the URL is: _https://login.salesforce.com/ID/orgID/userID_ where orgId is the ID of the Salesforce organization
     that the user belongs to, and userID is the Salesforce user ID.

     This property is set by the `SFOAuthCoordinator` after authentication has successfully completed.
     */
    @objc open var identityUrl: URL? {
        get { return _identityUrl }
        set {
            if newValue != _identityUrl {
                _identityUrl = newValue
                _userId = nil
                _organizationId = nil
                if let path = _identityUrl?.path {
                    let pathComps = path.components(separatedBy: "/")
                    if pathComps.count < 2 {
                        SFSDKCoreLogger.d(type(of: self), message: "\(type(of: self)):setIdentityUrl: invalid identityUrl: \(String(describing: _identityUrl))")
                        return
                    }
                    self.userId = pathComps[pathComps.count - 1]
                    self.organizationId = pathComps[pathComps.count - 2]
                } else {
                    SFSDKCoreLogger.d(type(of: self), message: "\(type(of: self)):setIdentityUrl: invalid or nil identityUrl: \(String(describing: _identityUrl))")
                }
            }
        }
    }

    /** The community URL, if present. The instance URL, otherwise.
     */
    @objc open var apiUrl: URL? {
        if let communityUrl = self.communityUrl {
            return communityUrl
        }
        return self.instanceUrl
    }

    /** A readonly convenience property returning the first 15 characters of the Salesforce User ID provided in the final path
     component of the identityUrl.

     This property is available after authentication has successfully completed.
     */
    @objc open internal(set) var userId: String? {
        get { return _userId }
        set {
            if let newValue = newValue, newValue != _userId {
                _userId = newValue
            }
        }
    }

    /**
     Determines if sensitive data such as the `refreshToken` and `accessToken` are encrypted
     */
    @objc open var isEncrypted: Bool {
        return _encrypted
    }

    /**
     A dictionary containing key-value pairs for any of the keys provided via the additionalOAuthParameterKeys property of SFUserAccountManager.
     If a key does not match a value in the parsed response, then it will not exist in the dictionary.
     */
    @objc open var additionalOAuthFields: NSDictionary?

    @objc open var challengeString: String?

    @objc open var authCode: String?

    // MARK: - NSSecureCoding

    @objc public static var supportsSecureCoding: Bool {
        return true
    }

    // MARK: - Initialization

    /** Initializes an authentication credential object with the given identifier and client ID.

     The identifier uniquely identifies the credentials object within the device's secure keychain.
     The client ID identifies the client for remote authentication.

     @param theIdentifier An identifier for this credential instance.
     @param theClientId The client ID (also known as consumer key) to be used for the OAuth session.
     @param encrypted Determines if the sensitive data like refreshToken and accessToken should be encrypted
     @return An initialized authentication credential object.
     */
    @objc public convenience init(identifier theIdentifier: String, clientId theClientId: String?, encrypted: Bool) {
        self.init(identifier: theIdentifier, clientId: theClientId, encrypted: encrypted, storageType: .keychain)
    }

    /** Initializes an authentication credential object with the given identifier and client ID. This is the designated initializer.

     If <code>type</code> is set to <code>SFOAuthCredentialsStorageTypeKeychain</code>, the given identifier uniquely identifies the credentials object within that keychain.
     The client ID identifies the client for remote authentication.

     @param theIdentifier An identifier for this credential instance.
     @param theClientId The client ID (also known as consumer key) to be used for the OAuth session.
     @param encrypted Determines if the sensitive data like refreshToken and accessToken should be encrypted
     @param type Indicates whether the OAuth credentials are stored in the keychain
     @return An initialized authentication credential object.
     */
    @objc public required init(identifier theIdentifier: String, clientId theClientId: String?, encrypted: Bool, storageType: OAuthCredentialsStorageType) {
        let targetClass: AnyClass
        switch storageType {
        case .none:
            targetClass = NSClassFromString("SFOAuthCredentials") ?? OAuthCredentials.self
        case .keychain:
            targetClass = NSClassFromString("SFOAuthKeychainCredentials") ?? OAuthCredentials.self
        }

        self._identifier = theIdentifier
        self._clientId = theClientId
        self._domain = kSFOAuthDefaultDomain
        self._protocol = kSFOAuthProtocolHttps
        self._encrypted = encrypted
        self.credentialsChangeSet = NSMutableDictionary()

        super.init()

        // Handle class cluster pattern
        if Swift.type(of: self) != targetClass {
            // Return instance of target class instead
            // Note: In Swift, we can't easily replicate Obj-C's dynamic class instantiation
            // This is handled by subclasses overriding init
        }
        _ = targetClass // Silence unused variable warning
    }

    // MARK: - NSCoding

    @objc required public init?(coder: NSCoder) {
        let clusterClassName = coder.decodeObject(of: NSString.self, forKey: kSFOAuthClusterImplementationKey) as String? ?? "SFOAuthKeychainCredentials"
        self.credentialsChangeSet = NSMutableDictionary()

        let clusterClass = NSClassFromString(clusterClassName) ?? type(of: self)

        // Initialize properties
        self._identifier = coder.decodeObject(of: NSString.self, forKey: "SFOAuthIdentifier") as String? ?? ""
        self._domain = coder.decodeObject(of: NSString.self, forKey: "SFOAuthDomain") as String?
        self._clientId = coder.decodeObject(of: NSString.self, forKey: "SFOAuthClientId") as String?
        self.redirectUri = coder.decodeObject(of: NSString.self, forKey: "SFOAuthRedirectUri") as String?
        self._organizationId = coder.decodeObject(of: NSString.self, forKey: "SFOAuthOrganizationId") as String?
        self._identityUrl = coder.decodeObject(of: NSURL.self, forKey: "SFOAuthIdentityUrl") as URL?
        self.instanceUrl = coder.decodeObject(of: NSURL.self, forKey: "SFOAuthInstanceUrl") as URL?
        self.apiInstanceUrl = coder.decodeObject(of: NSURL.self, forKey: "SFOAuthApiInstanceUrl") as URL?

        let scopesClasses: [AnyClass] = [NSArray.self, NSString.self]
        self.scopes = coder.decodeObject(of: scopesClasses, forKey: "SFOAuthScopes") as? [String]

        self.communityId = coder.decodeObject(of: NSString.self, forKey: "SFOAuthCommunityId") as String?
        self.communityUrl = coder.decodeObject(of: NSURL.self, forKey: "SFOAuthCommunityUrl") as URL?
        self.issuedAt = coder.decodeObject(of: NSDate.self, forKey: "SFOAuthIssuedAt") as Date?

        let fieldsClasses: [AnyClass] = [NSDictionary.self, NSString.self]
        self.additionalOAuthFields = coder.decodeObject(of: fieldsClasses, forKey: "SFOAuthAdditionalFields") as? NSDictionary

        let protocolVal = coder.decodeObject(of: NSString.self, forKey: "SFOAuthProtocol") as String?
        self._protocol = protocolVal ?? kSFOAuthProtocolHttps

        let encryptedBool = coder.decodeObject(of: NSNumber.self, forKey: "SFOAuthEncrypted") as? Bool
        self._encrypted = encryptedBool ?? coder.decodeBool(forKey: "SFOAuthEncrypted")

        self.lightningDomain = coder.decodeObject(of: NSString.self, forKey: "SFOAuthLightningDomain") as String?
        self.vfDomain = coder.decodeObject(of: NSString.self, forKey: "SFOAuthVFDomain") as String?
        self.contentDomain = coder.decodeObject(of: NSString.self, forKey: "SFOAuthContentDomain") as String?
        self.cookieClientSrc = coder.decodeObject(of: NSString.self, forKey: "SFOAuthClientSrc") as String?
        self.cookieSidClient = coder.decodeObject(of: NSString.self, forKey: "SFOAuthCookieSidClient") as String?
        self.sidCookieName = coder.decodeObject(of: NSString.self, forKey: "SFOAuthSidCookieName") as String?
        self.tokenFormat = coder.decodeObject(of: NSString.self, forKey: "SFOAuthTokenFormat") as String?

        // Only decode tokens if this is the base class (not keychain-backed)
        if type(of: self) == OAuthCredentials.self {
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

        super.init()

        // Handle class cluster
        if type(of: self) != clusterClass {
            return nil // Subclass will handle this
        }
    }

    @objc open func encode(with coder: NSCoder) {
        coder.encode(NSStringFromClass(type(of: self)), forKey: kSFOAuthClusterImplementationKey)
        coder.encode(self.identifier, forKey: "SFOAuthIdentifier")
        coder.encode(self.domain, forKey: "SFOAuthDomain")
        coder.encode(self.clientId, forKey: "SFOAuthClientId")
        coder.encode(self.redirectUri, forKey: "SFOAuthRedirectUri")
        coder.encode(self.organizationId, forKey: "SFOAuthOrganizationId")
        coder.encode(self.identityUrl, forKey: "SFOAuthIdentityUrl")
        coder.encode(self.instanceUrl, forKey: "SFOAuthInstanceUrl")
        coder.encode(self.apiInstanceUrl, forKey: "SFOAuthApiInstanceUrl")
        coder.encode(self.scopes, forKey: "SFOAuthScopes")
        coder.encode(self.communityId, forKey: "SFOAuthCommunityId")
        coder.encode(self.communityUrl, forKey: "SFOAuthCommunityUrl")
        coder.encode(self.issuedAt, forKey: "SFOAuthIssuedAt")
        coder.encode(self.protocol, forKey: "SFOAuthProtocol")
        coder.encode(self.lightningDomain, forKey: "SFOAuthLightningDomain")
        coder.encode(self.vfDomain, forKey: "SFOAuthVFDomain")
        coder.encode(self.contentDomain, forKey: "SFOAuthContentDomain")
        coder.encode(self.cookieClientSrc, forKey: "SFOAuthClientSrc")
        coder.encode(self.cookieSidClient, forKey: "SFOAuthCookieSidClient")
        coder.encode(self.sidCookieName, forKey: "SFOAuthSidCookieName")
        coder.encode(self.tokenFormat, forKey: "SFOAuthTokenFormat")
        coder.encode(kSFOAuthArchiveVersion, forKey: "SFOAuthArchiveVersion")
        coder.encode(NSNumber(value: self.isEncrypted), forKey: "SFOAuthEncrypted")
        coder.encode(self.additionalOAuthFields, forKey: "SFOAuthAdditionalFields")
    }

    // MARK: - NSCopying

    @objc open func copy(with zone: NSZone? = nil) -> Any {
        // Infer storage type from current class type
        let storageType: OAuthCredentialsStorageType = (self is OAuthKeychainCredentials) ? .keychain : .none
        let copyCreds = type(of: self).init(identifier: self.identifier, clientId: self.clientId, encrypted: self.isEncrypted, storageType: storageType)
        copyCreds.protocol = self.protocol
        copyCreds.domain = self.domain
        copyCreds.redirectUri = self.redirectUri
        copyCreds.jwt = self.jwt
        copyCreds.refreshToken = self.refreshToken
        copyCreds.accessToken = self.accessToken
        copyCreds.instanceUrl = self.instanceUrl
        copyCreds.apiInstanceUrl = self.apiInstanceUrl
        copyCreds.scopes = self.scopes
        copyCreds.communityId = self.communityId
        copyCreds.communityUrl = self.communityUrl
        copyCreds.issuedAt = self.issuedAt

        // NB: Intentionally ordering the copying of these, because setting the identity URL automatically
        // sets the OrgID and UserID.  This ensures the values stay in sync.
        copyCreds.identityUrl = self.identityUrl
        copyCreds.organizationId = self.organizationId
        copyCreds.userId = self.userId
        copyCreds.lightningDomain = self.lightningDomain
        copyCreds.lightningSid = self.lightningSid
        copyCreds.vfDomain = self.vfDomain
        copyCreds.vfSid = self.vfSid
        copyCreds.contentDomain = self.contentDomain
        copyCreds.contentSid = self.contentSid
        copyCreds.csrfToken = self.csrfToken
        copyCreds.cookieClientSrc = self.cookieClientSrc
        copyCreds.cookieSidClient = self.cookieSidClient
        copyCreds.sidCookieName = self.sidCookieName
        copyCreds.parentSid = self.parentSid
        copyCreds.tokenFormat = self.tokenFormat
        copyCreds.beaconChildConsumerKey = self.beaconChildConsumerKey
        copyCreds.beaconChildConsumerSecret = self.beaconChildConsumerSecret
        copyCreds.additionalOAuthFields = self.additionalOAuthFields?.copy() as? NSDictionary
        return copyCreds
    }

    // MARK: - Public Methods

    @objc open override var description: String {
        let parts = [
            "<\(type(of: self)): \(Unmanaged.passUnretained(self).toOpaque())",
            "identifier=\"\(identifier)\"",
            "clientId=\"\(clientId ?? "")\"",
            "domain=\"\(domain ?? "")\"",
            "identityUrl=\"\(String(describing: identityUrl))\"",
            "instanceUrl=\"\(String(describing: instanceUrl))\"",
            "apiInstanceUrl=\"\(String(describing: apiInstanceUrl))\"",
            "communityId=\"\(String(describing: communityId))\"",
            "communityUrl=\"\(String(describing: communityUrl))\"",
            "scopes=\"\(String(describing: scopes))\"",
            "issuedAt=\"\(String(describing: issuedAt))\"",
            "organizationId=\"\(String(describing: organizationId))\"",
            "protocol=\"\(String(describing: `protocol`))\"",
            "redirectUri=\"\(String(describing: redirectUri))\">"
        ]
        return parts.joined(separator: " ")
    }

    /** Revoke the OAuth access and refresh tokens.

     @warning Calling this method when the identifier property is `nil` will raise an NSInternalInconsistencyException.
     */
    @objc open func revoke() {
        revokeAccessToken()
        revokeRefreshToken()
    }

    /** Revoke the OAuth access token.

     @exception NSInternalInconsistencyException If called when the identifier property is `nil`.
     */
    @objc open func revokeAccessToken() {
        guard !identifier.isEmpty else {
            NSException.raise(NSExceptionName.internalInconsistencyException, format: "identifier cannot be nil or empty", arguments: getVaList([]))
            return
        }
        SFSDKCoreLogger.d(type(of: self), message: "\(type(of: self)):revokeAccessToken: access token revoked")
        self.accessToken = nil
    }

    /** Revoke the OAuth refresh token.

     @exception NSInternalInconsistencyException If called while the identifier property is `nil`.
     */
    @objc open func revokeRefreshToken() {
        guard !identifier.isEmpty else {
            NSException.raise(NSExceptionName.internalInconsistencyException, format: "identifier cannot be nil or empty", arguments: getVaList([]))
            return
        }
        SFSDKCoreLogger.d(type(of: self), message: "\(type(of: self)):revokeRefreshToken: refresh token revoked. Cleared identityUrl, instanceUrl, issuedAt fields")
        self.refreshToken = nil
        self.instanceUrl = nil
        self.apiInstanceUrl = nil
        self.scopes = nil
        self.communityId = nil
        self.communityUrl = nil
        self.issuedAt = nil
        self.identityUrl = nil
        self.lightningDomain = nil
        self.lightningSid = nil
        self.vfDomain = nil
        self.vfSid = nil
        self.contentDomain = nil
        self.contentSid = nil
        self.csrfToken = nil
        self.cookieClientSrc = nil
        self.cookieSidClient = nil
        self.sidCookieName = nil
        self.parentSid = nil
        self.tokenFormat = nil
        self.beaconChildConsumerKey = nil
        self.beaconChildConsumerSecret = nil
    }

    @objc open func overrideDomainIfNeeded() -> URL? {
        let domain = self.communityId != nil ? self.communityUrl?.absoluteString : self.domain
        let protocolHost = self.communityId != nil ? domain : "\(self.protocol ?? "")://\(domain ?? "")"
        return URL(string: protocolHost ?? "")
    }

    /** Update the credentials using the provided oauth parameters.
     This method only update the following parameters:
     - accessToken
     - issuedAt
     - instanceUrl
     - apiInstanceUrl
     - scopes
     - identityUrl
     - communityId
     - communityUrl
     - refreshToken
     - lightningDomain
     - lightningSid
     - vfDomain
     - vfSid
     - contentDomain
     - contentSid
     - csrfToken
     - cookieClientSrc
     - cookieSidClient
     - sidCookieName
     - parentSid
     - tokenFormat
     - beaconChildConsumerKey
     - beaconChildConsumerSecret
     */
    @objc open func updateCredentials(_ params: [String: Any]) {
        // Note: These constants would normally come from SFSDKOAuthConstants.h
        // For now, using string literals. In production, import the constants file.

        if let accessToken = params["access_token"] as? String {
            setProperty(forKey: "accessToken", withValue: accessToken)
        }
        if let issuedAt = params["issued_at"] as? String {
            self.issuedAt = SFSDKOAuth2.timestampStringToDate(issuedAt)
        }
        if let instanceUrl = params["instance_url"] as? String {
            setProperty(forKey: "instanceUrl", withValue: URL(string: instanceUrl))
        }
        if let apiInstanceUrl = params["api_instance_url"] as? String {
            setProperty(forKey: "apiInstanceUrl", withValue: URL(string: apiInstanceUrl))
        }
        if let scope = params["scope"] as? String {
            let scopesArray = scope.components(separatedBy: " ")
            setProperty(forKey: "scopes", withValue: scopesArray)
        }
        if let id = params["id"] as? String {
            setProperty(forKey: "identityUrl", withValue: URL(string: id))
        }
        if let communityId = params["sfdc_community_id"] as? String {
            setProperty(forKey: "communityId", withValue: communityId)
        }
        if let communityUrl = params["sfdc_community_url"] as? String {
            setProperty(forKey: "communityUrl", withValue: URL(string: communityUrl))
        }
        if let refreshToken = params["refresh_token"] as? String {
            setProperty(forKey: "refreshToken", withValue: refreshToken)
        }
        if let lightningDomain = params["lightning_domain"] as? String {
            self.lightningDomain = lightningDomain
        }
        if let lightningSid = params["lightning_sid"] as? String {
            self.lightningSid = lightningSid
        }
        if let vfDomain = params["visualforce_domain"] as? String {
            self.vfDomain = vfDomain
        }
        if let vfSid = params["visualforce_sid"] as? String {
            self.vfSid = vfSid
        }
        if let contentDomain = params["content_domain"] as? String {
            self.contentDomain = contentDomain
        }
        if let contentSid = params["content_sid"] as? String {
            self.contentSid = contentSid
        }
        if let csrfToken = params["csrf_token"] as? String {
            self.csrfToken = csrfToken
        }
        if let cookieClientSrc = params["cookie-clientSrc"] as? String {
            self.cookieClientSrc = cookieClientSrc
        }
        if let cookieSidClient = params["cookie-sid_Client"] as? String {
            self.cookieSidClient = cookieSidClient
        }
        if let sidCookieName = params["sidCookieName"] as? String {
            self.sidCookieName = sidCookieName
        }
        if let parentSid = params["parent_sid"] as? String {
            self.parentSid = parentSid
        }
        if let tokenFormat = params["token_format"] as? String {
            self.tokenFormat = tokenFormat
        }
        if let beaconChildConsumerKey = params["beacon_child_consumer_key"] as? String {
            self.beaconChildConsumerKey = beaconChildConsumerKey
        }
        if let beaconChildConsumerSecret = params["beacon_child_consumer_secret"] as? String {
            self.beaconChildConsumerSecret = beaconChildConsumerSecret
        }
    }

    /** Returns the oauth client id to use for refresh
     In the case of beacon app, the beacon child consumer key returned during login should be used instead of the configured consumer key
     */
    @objc open func getClientIdForRefresh() -> String? {
        if let beaconKey = self.beaconChildConsumerKey, !beaconKey.isEmpty {
            return beaconKey
        }
        return self.clientId
    }

    // MARK: - Internal Methods

    @objc open func setProperty(forKey propertyName: String, withValue newValue: Any?) {
        let oldValue = self.value(forKey: propertyName)
        if let newValue = newValue {
            if let oldValue = oldValue, !(newValue as AnyObject).isEqual(oldValue) {
                objc_sync_enter(credentialsChangeSet)
                credentialsChangeSet[propertyName] = [oldValue, newValue]
                objc_sync_exit(credentialsChangeSet)
            } else if oldValue == nil {
                objc_sync_enter(credentialsChangeSet)
                credentialsChangeSet[propertyName] = [NSNull(), newValue]
                objc_sync_exit(credentialsChangeSet)
            }
        }
        self.setValue(newValue, forKey: propertyName)
    }

    @objc open func resetCredentialsChangeSet() {
        objc_sync_enter(credentialsChangeSet)
        credentialsChangeSet.removeAllObjects()
        objc_sync_exit(credentialsChangeSet)
    }

    @objc open func hasPropertyValueChanged(forKey key: String) -> Bool {
        return credentialsChangeSet.object(forKey: key) != nil
    }
}

// MARK: - SFSDKOAuth2 Helper (Placeholder)

// This would normally be imported from SFSDKOAuth2.swift
// For compilation purposes, adding a minimal implementation
private extension SFSDKOAuth2 {
    static func timestampStringToDate(_ timestamp: String) -> Date? {
        guard let timeInterval = TimeInterval(timestamp) else { return nil }
        return Date(timeIntervalSince1970: timeInterval / 1000.0)
    }
}
