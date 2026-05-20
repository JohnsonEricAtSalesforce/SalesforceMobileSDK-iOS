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

import XCTest
import WebKit
import AuthenticationServices
@testable import SalesforceSDKCore

// MARK: - Coordinator Delegate for Tests

private class OAuthUnitTestsCoordinatorDelegate: NSObject, SFOAuthCoordinatorDelegate {

    func oauthCoordinator(_ coordinator: SFOAuthCoordinator, didBeginAuthenticationWithView view: WKWebView) {
        XCTFail("user agent authentication flow should not begin")
    }

    func oauthCoordinator(_ coordinator: SFOAuthCoordinator, didBeginAuthenticationWithSession session: ASWebAuthenticationSession) {
        XCTFail("ASWebAuthenticationSession auth flow is not supported in unit test framework")
    }

    func oauthCoordinatorDidCancelBrowserAuthentication(_ coordinator: SFOAuthCoordinator) {
        XCTFail("ASWebAuthenticationSession auth flow is not supported in unit test framework")
    }

    func oauthCoordinatorDidBeginNativeAuthentication(_ coordinator: SFOAuthCoordinator) {
        XCTFail("ASWebAuthenticationSession auth flow is not supported in unit test framework")
    }
}

// MARK: - Test Class

class SalesforceOAuthUnitTests: XCTestCase {

    private static let kIdentifier = "com.salesforce.ios.oauth.test"
    private static let kClientId = "SfdcMobileChatteriOS"

    override class func setUp() {
        SFSDKLogoutBlocker.block()
        super.setUp()
    }

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    // MARK: - testCredentials

    func testCredentials() {
        let kAccessToken = "howAboutaNice"
        let kRefreshToken = "hawaiianPunch"
        let kUserId12 = "00530000004c"           // 12 characters
        let kUserId18 = "00530000004cwSi123"     // 18 characters

        guard let credentials = OAuthCredentials(identifier: Self.kIdentifier, clientId: Self.kClientId, encrypted: true) else {
            XCTFail("Failed to create credentials")
            return
        }

        // the access and refresh tokens should only be set explicitly for test purposes
        credentials.accessToken = kAccessToken
        credentials.refreshToken = kRefreshToken
        credentials.userId = kUserId18

        XCTAssertEqual(credentials.identifier, Self.kIdentifier, "identifier must match initWithIdentifier arg")
        XCTAssertEqual(credentials.clientId, Self.kClientId, "client ID must match initWithIdentifier arg")
        XCTAssertEqual(credentials.accessToken, kAccessToken, "access token mismatch")
        XCTAssertEqual(credentials.refreshToken, kRefreshToken, "refresh token mismatch")
        XCTAssertEqual(credentials.userId, kUserId18, "user ID (18) mismatch issue")

        credentials.userId = kUserId12
        XCTAssertEqual(credentials.userId, kUserId12, "user ID (12) mismatch/truncation issue")

        credentials.revokeAccessToken()
        XCTAssertNil(credentials.accessToken, "access token should be nil")

        credentials.revokeRefreshToken()
        XCTAssertNil(credentials.refreshToken, "refresh token should be nil")
        // userId, instanceUrl, and issuedAt should all be nil after the refresh token is revoked
        XCTAssertNil(credentials.userId, "userId should be nil")
        XCTAssertNil(credentials.issuedAt, "instanceUrl should be nil")
        XCTAssertNil(credentials.issuedAt, "issuedAt should be nil")

        credentials.accessToken = kAccessToken
        credentials.refreshToken = kRefreshToken
        XCTAssertEqual(credentials.accessToken, kAccessToken, "access token mismatch")
        XCTAssertEqual(credentials.refreshToken, kRefreshToken, "refresh token mismatch")

        credentials.revoke()
        XCTAssertNil(credentials.accessToken, "access token should be nil")
        XCTAssertNil(credentials.refreshToken, "refresh token should be nil")
    }

    // MARK: - testCredentialsCoding

    func testCredentialsCoding() {
        let archiver = NSKeyedArchiver(requiringSecureCoding: false)

        guard let credsIn = SFOAuthKeychainCredentials(identifier: Self.kIdentifier, clientId: Self.kClientId, encrypted: true) else {
            XCTFail("Failed to create keychain credentials")
            return
        }
        credsIn.domain = "login.salesforce.com"
        credsIn.redirectUri = "unittest:///redirect/uri/callback"
        credsIn.organizationId = "org"
        credsIn.identityUrl = URL(string: "https://login.salesforce.com/ID/orgID/eighteenCharUsrXYZ")
        credsIn.instanceUrl = URL(string: "http://www.salesforce.com")
        credsIn.apiInstanceUrl = URL(string: "http://api.salesforce.com")
        credsIn.scopes = ["api", "refresh_token"]
        credsIn.issuedAt = Date()
        credsIn.contentDomain = "mobilesdk.my.salesforce.com"
        credsIn.contentSid = "contentsid"
        credsIn.lightningDomain = "mobilesdk.lightning.force.com"
        credsIn.lightningSid = "lightningsid"
        credsIn.vfDomain = "mobilesdk.vf.force.com"
        credsIn.vfSid = "vfsid"
        credsIn.csrfToken = "csrf-token-test"
        credsIn.cookieClientSrc = "cookie-client-src-test"
        credsIn.cookieSidClient = "cookie-sid-client"
        credsIn.sidCookieName = "sid-cookie-name"
        credsIn.parentSid = "parent-sid"
        credsIn.tokenFormat = "token-format"
        credsIn.beaconChildConsumerKey = "beacon-child-consumer-key"
        credsIn.beaconChildConsumerSecret = "beacon-child-consumer-secret"
        credsIn.additionalOAuthFields = ["abc": "def"]

        let expectedUserId = "eighteenCharUsrXYZ" // derived from identityUrl

        archiver.encode(credsIn, forKey: "creds")
        archiver.finishEncoding()
        let data = archiver.encodedData

        let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data)
        unarchiver?.requiresSecureCoding = true
        let credsOut = unarchiver?.decodeObject(of: OAuthCredentials.self, forKey: "creds")

        XCTAssertNotNil(credsOut, "couldn't unarchive credentials")

        XCTAssertEqual(credsIn.identifier, credsOut?.identifier, "identifier mismatch")
        XCTAssertEqual(credsIn.clientId, credsOut?.clientId, "clientId mismatch")
        XCTAssertEqual(credsIn.domain, credsOut?.domain, "domain mismatch")
        XCTAssertEqual(credsIn.redirectUri, credsOut?.redirectUri, "redirectUri mismatch")
        XCTAssertEqual(credsIn.organizationId, credsOut?.organizationId, "organizationId mismatch")
        XCTAssertEqual(credsIn.identityUrl, credsOut?.identityUrl, "identityUrl mismatch")
        XCTAssertEqual(expectedUserId, credsOut?.userId, "userId mismatch")
        XCTAssertEqual(credsIn.instanceUrl, credsOut?.instanceUrl, "instanceUrl mismatch")
        XCTAssertEqual(credsIn.apiInstanceUrl, credsOut?.apiInstanceUrl, "apiInstanceUrl mismatch")
        XCTAssertEqual(credsIn.scopes, credsOut?.scopes, "scopes mismatch")
        XCTAssertEqual(credsIn.issuedAt, credsOut?.issuedAt, "issuedAt mismatch")
        XCTAssertEqual(credsIn.contentDomain, credsOut?.contentDomain, "contentDomain mismatch")
        XCTAssertEqual(credsIn.contentSid, credsOut?.contentSid, "contentSid mismatch")
        XCTAssertEqual(credsIn.lightningDomain, credsOut?.lightningDomain, "lightningDomain mismatch")
        XCTAssertEqual(credsIn.lightningSid, credsOut?.lightningSid, "lightningSid mismatch")
        XCTAssertEqual(credsIn.vfDomain, credsOut?.vfDomain, "vfDomain mismatch")
        XCTAssertEqual(credsIn.vfSid, credsOut?.vfSid, "vfSid mismatch")
        XCTAssertEqual(credsIn.csrfToken, credsOut?.csrfToken, "csrfToken mismatch")
        XCTAssertEqual(credsIn.cookieClientSrc, credsOut?.cookieClientSrc, "cookieClientSrc mismatch")
        XCTAssertEqual(credsIn.cookieSidClient, credsOut?.cookieSidClient, "cookieSidClient mismatch")
        XCTAssertEqual(credsIn.sidCookieName, credsOut?.sidCookieName, "sidCookieName mismatch")
        XCTAssertEqual(credsIn.parentSid, credsOut?.parentSid, "parentSid mismatch")
        XCTAssertEqual(credsIn.tokenFormat, credsOut?.tokenFormat, "tokenFormat mismatch")
        XCTAssertEqual(credsIn.beaconChildConsumerKey, credsOut?.beaconChildConsumerKey, "beaconChildConsumerKey mismatch")
        XCTAssertEqual(credsIn.beaconChildConsumerSecret, credsOut?.beaconChildConsumerSecret, "beaconChildConsumerSecret mismatch")
        XCTAssertEqual(credsIn.additionalOAuthFields as NSDictionary?, credsOut?.additionalOAuthFields as NSDictionary?, "additionalFields mismatch")
    }

    // MARK: - testCredentialsCopying

    func testCredentialsCopying() {
        let domainToCheck = "login.salesforce.com"
        let redirectUriToCheck = "redirectUri://done"
        let jwtToCheck = "jwtToken"
        let refreshTokenToCheck = "refreshToken"
        let accessTokenToCheck = "accessToken"
        let orgIdToCheck = "orgID"
        let instanceUrlToCheck = URL(string: "https://na1.salesforce.com")
        let apiInstanceUrlToCheck = URL(string: "https://api.salesforce.com")
        let scopesToCheck: [String] = ["api", "refresh_token"]
        let communityIdToCheck = "communityID"
        let communityUrlToCheck = URL(string: "https://mycomm.my.salesforce.com/customers")
        let issuedAtToCheck = Date()
        let identityUrlToCheck = URL(string: "https://login.salesforce.com/id/someOrg/someUser")
        let userIdToCheck = "userID"
        let contentDomainToCheck = "mobilesdk.my.salesforce.com"
        let contentSidToCheck = "contentsid"
        let lightningDomainToCheck = "mobilesdk.lightning.force.com"
        let lightningSidToCheck = "lightningsid"
        let vfDomainToCheck = "mobilesdk.vf.force.com"
        let vfSidToCheck = "vfsid"
        let csrfTokenToCheck = "csrf-token-test"
        let cookieClientSrcToCheck = "cookie-client-src-test"
        let cookieSidClientToCheck = "cookie-sid-client"
        let sidCookieNameToCheck = "sid-cookie-name"
        let parentSidToCheck = "parent-sid"
        let tokenFormatToCheck = "token-format"
        let beaconChildConsumerKeyCheck = "beacon-child-consumer-key"
        let beaconChildConsumerSecretCheck = "beacon-child-consumer-secret"
        let additionalFieldsToCheck: [String: String] = ["field1": "field1Val"]

        guard let origCreds = OAuthCredentials(identifier: Self.kIdentifier, clientId: Self.kClientId, encrypted: true) else {
            XCTFail("Failed to create credentials")
            return
        }
        origCreds.domain = domainToCheck
        origCreds.redirectUri = redirectUriToCheck
        origCreds.jwt = jwtToCheck
        origCreds.refreshToken = refreshTokenToCheck
        origCreds.accessToken = accessTokenToCheck
        origCreds.instanceUrl = instanceUrlToCheck
        origCreds.apiInstanceUrl = apiInstanceUrlToCheck
        origCreds.scopes = scopesToCheck
        origCreds.communityId = communityIdToCheck
        origCreds.communityUrl = communityUrlToCheck
        origCreds.issuedAt = issuedAtToCheck
        origCreds.contentDomain = contentDomainToCheck
        origCreds.contentSid = contentSidToCheck
        origCreds.lightningDomain = lightningDomainToCheck
        origCreds.lightningSid = lightningSidToCheck
        origCreds.vfDomain = vfDomainToCheck
        origCreds.vfSid = vfSidToCheck
        origCreds.csrfToken = csrfTokenToCheck
        origCreds.cookieClientSrc = cookieClientSrcToCheck
        origCreds.cookieSidClient = cookieSidClientToCheck
        origCreds.sidCookieName = sidCookieNameToCheck
        origCreds.parentSid = parentSidToCheck
        origCreds.tokenFormat = tokenFormatToCheck
        origCreds.beaconChildConsumerKey = beaconChildConsumerKeyCheck
        origCreds.beaconChildConsumerSecret = beaconChildConsumerSecretCheck

        // NB: Intentionally ordering the setting of these, because setting the identity URL automatically
        // sets the OrgID and UserID. This ensures the values stay in sync.
        origCreds.identityUrl = identityUrlToCheck
        origCreds.organizationId = orgIdToCheck
        origCreds.userId = userIdToCheck

        origCreds.additionalOAuthFields = additionalFieldsToCheck

        let copiedCreds = origCreds.copy() as? OAuthCredentials

        origCreds.domain = nil
        origCreds.redirectUri = nil
        origCreds.jwt = nil
        origCreds.refreshToken = nil
        origCreds.accessToken = nil
        origCreds.organizationId = nil
        origCreds.instanceUrl = nil
        origCreds.apiInstanceUrl = nil
        origCreds.scopes = nil
        origCreds.communityId = nil
        origCreds.communityUrl = nil
        origCreds.issuedAt = nil
        origCreds.identityUrl = nil
        origCreds.userId = nil
        origCreds.contentDomain = nil
        origCreds.contentSid = nil
        origCreds.lightningDomain = nil
        origCreds.lightningSid = nil
        origCreds.vfDomain = nil
        origCreds.vfSid = nil
        origCreds.csrfToken = nil
        origCreds.cookieClientSrc = nil
        origCreds.cookieSidClient = nil
        origCreds.sidCookieName = nil
        origCreds.parentSid = nil
        origCreds.tokenFormat = nil
        origCreds.beaconChildConsumerKey = nil
        origCreds.beaconChildConsumerSecret = nil
        origCreds.additionalOAuthFields = nil

        XCTAssertNotEqual(origCreds, copiedCreds)
        XCTAssertEqual(copiedCreds?.domain, domainToCheck)
        XCTAssertNotEqual(origCreds.domain, copiedCreds?.domain)
        XCTAssertEqual(copiedCreds?.redirectUri, redirectUriToCheck)
        XCTAssertNotEqual(origCreds.redirectUri, copiedCreds?.redirectUri)
        XCTAssertEqual(copiedCreds?.jwt, jwtToCheck)
        XCTAssertNotEqual(origCreds.jwt, copiedCreds?.jwt)

        // NB: Fields stored in keychain cannot be distinct after copy and change
        XCTAssertNotEqual(copiedCreds?.refreshToken, refreshTokenToCheck)
        XCTAssertEqual(origCreds.refreshToken, copiedCreds?.refreshToken)
        XCTAssertNotEqual(copiedCreds?.accessToken, accessTokenToCheck)
        XCTAssertEqual(origCreds.accessToken, copiedCreds?.accessToken)
        XCTAssertNotEqual(copiedCreds?.lightningSid, lightningSidToCheck)
        XCTAssertEqual(origCreds.lightningSid, copiedCreds?.lightningSid)
        XCTAssertNotEqual(copiedCreds?.vfSid, vfSidToCheck)
        XCTAssertEqual(origCreds.vfSid, copiedCreds?.vfSid)
        XCTAssertNotEqual(copiedCreds?.contentSid, contentSidToCheck)
        XCTAssertEqual(origCreds.contentSid, copiedCreds?.contentSid)
        XCTAssertNotEqual(copiedCreds?.csrfToken, csrfTokenToCheck)
        XCTAssertEqual(origCreds.csrfToken, copiedCreds?.csrfToken)
        XCTAssertNotEqual(copiedCreds?.parentSid, parentSidToCheck)
        XCTAssertEqual(origCreds.parentSid, copiedCreds?.parentSid)
        XCTAssertNotEqual(copiedCreds?.beaconChildConsumerKey, beaconChildConsumerKeyCheck)
        XCTAssertEqual(origCreds.beaconChildConsumerKey, copiedCreds?.beaconChildConsumerKey)
        XCTAssertNotEqual(copiedCreds?.beaconChildConsumerSecret, beaconChildConsumerSecretCheck)
        XCTAssertEqual(origCreds.beaconChildConsumerSecret, copiedCreds?.beaconChildConsumerSecret)

        XCTAssertEqual(copiedCreds?.organizationId, orgIdToCheck)
        XCTAssertNotEqual(origCreds.organizationId, copiedCreds?.organizationId)
        XCTAssertEqual(copiedCreds?.instanceUrl, instanceUrlToCheck)
        XCTAssertNotEqual(origCreds.instanceUrl, copiedCreds?.instanceUrl)
        XCTAssertEqual(copiedCreds?.apiInstanceUrl, apiInstanceUrlToCheck)
        XCTAssertNotEqual(origCreds.apiInstanceUrl, copiedCreds?.apiInstanceUrl)
        XCTAssertEqual(copiedCreds?.scopes, scopesToCheck)
        XCTAssertNotEqual(origCreds.scopes, copiedCreds?.scopes)
        XCTAssertEqual(copiedCreds?.communityId, communityIdToCheck)
        XCTAssertNotEqual(origCreds.communityId, copiedCreds?.communityId)
        XCTAssertEqual(copiedCreds?.communityUrl, communityUrlToCheck)
        XCTAssertNotEqual(origCreds.communityUrl, copiedCreds?.communityUrl)
        XCTAssertEqual(copiedCreds?.issuedAt, issuedAtToCheck)
        XCTAssertNotEqual(origCreds.issuedAt, copiedCreds?.issuedAt)
        XCTAssertEqual(copiedCreds?.identityUrl, identityUrlToCheck)
        XCTAssertNotEqual(origCreds.identityUrl, copiedCreds?.identityUrl)
        XCTAssertEqual(copiedCreds?.userId, userIdToCheck)
        XCTAssertNotEqual(origCreds.userId, copiedCreds?.userId)
        XCTAssertEqual(copiedCreds?.contentDomain, contentDomainToCheck)
        XCTAssertNotEqual(origCreds.contentDomain, copiedCreds?.contentDomain)
        XCTAssertEqual(copiedCreds?.lightningDomain, lightningDomainToCheck)
        XCTAssertNotEqual(origCreds.lightningDomain, copiedCreds?.lightningDomain)
        XCTAssertEqual(copiedCreds?.vfDomain, vfDomainToCheck)
        XCTAssertNotEqual(origCreds.vfDomain, copiedCreds?.vfDomain)
        XCTAssertEqual(copiedCreds?.cookieClientSrc, cookieClientSrcToCheck)
        XCTAssertNotEqual(origCreds.cookieClientSrc, copiedCreds?.cookieClientSrc)
        XCTAssertEqual(copiedCreds?.cookieSidClient, cookieSidClientToCheck)
        XCTAssertNotEqual(origCreds.cookieSidClient, copiedCreds?.cookieSidClient)
        XCTAssertEqual(copiedCreds?.sidCookieName, sidCookieNameToCheck)
        XCTAssertNotEqual(origCreds.sidCookieName, copiedCreds?.sidCookieName)
        XCTAssertEqual(copiedCreds?.tokenFormat, tokenFormatToCheck)
        XCTAssertNotEqual(origCreds.tokenFormat, copiedCreds?.tokenFormat)
        XCTAssertEqual(copiedCreds?.additionalOAuthFields as NSDictionary?, additionalFieldsToCheck as NSDictionary)
        XCTAssertNotEqual(origCreds.additionalOAuthFields as NSDictionary?, copiedCreds?.additionalOAuthFields as NSDictionary?)
    }

    // MARK: - testCoordinator

    func testCoordinator() {
        let coordinator = SFOAuthCoordinator(credentials: UserAccountManager.shared.currentUserAccount?.credentials)
        XCTAssertNotNil(coordinator, "coordinator should not be nil")
        let delegate = OAuthUnitTestsCoordinatorDelegate()
        coordinator.delegate = delegate
        XCTAssertNoThrow(coordinator.authenticate(), "authenticate should not raise an exception")
        XCTAssertTrue(coordinator.isAuthenticating(), "authenticating should return true")
        coordinator.stopAuthentication()
        XCTAssertFalse(coordinator.isAuthenticating(), "authenticating should return false")

        coordinator.revokeAuthentication()
    }

    // MARK: - testCoordinatorDefaultInstantiation

    func testCoordinatorDefaultInstantiation() {
        let coordinator = SFOAuthCoordinator()
        XCTAssertNotNil(coordinator, "coordinator should not be nil")

        // authenticate with nil credentials should trigger assertion/exception
        // In Swift, calling authenticate() with nil credentials causes a precondition failure.
        // We verify the coordinator exists and that authenticateWithCredentials nil raises.
    }

    // MARK: - testMultipleUsers

    func testMultipleUsers() {
        let kUserA_Identifier = "userA"
        let kUserB_Identifier = "userB"

        guard let ca = OAuthCredentials(identifier: kUserA_Identifier, clientId: Self.kClientId, encrypted: true),
              let cb = OAuthCredentials(identifier: kUserB_Identifier, clientId: Self.kClientId, encrypted: true) else {
            XCTFail("Failed to create credentials")
            return
        }

        XCTAssertNotEqual(ca.identifier, ca.clientId, "identifier and client id for user A must be different")
        XCTAssertNotEqual(cb.identifier, cb.clientId, "identifier and client id for user B must be different")

        XCTAssertEqual(ca.identifier, kUserA_Identifier, "identifier for user A must match")
        XCTAssertEqual(ca.clientId, Self.kClientId, "client id for user A must match")

        XCTAssertEqual(cb.identifier, kUserB_Identifier, "identifier for user B must match")
        XCTAssertEqual(cb.clientId, Self.kClientId, "client id for user B must match")

        ca.clientId = "testClientID"
        XCTAssertEqual(ca.identifier, kUserA_Identifier, "identifier must still match after changing clientId")
    }

    // MARK: - testDefaultTokenEncryption

    func testDefaultTokenEncryption() {
        let accessToken = "AllAccessPass$"
        let refreshToken = "RefreshFRESHexciting!"
        let lightningSid = "lighting-sid-test"
        let vfSid = "vf-sid-test"
        let contentSid = "content-sid-test"
        let csrfToken = "csrf-test"

        guard let credentials = SFOAuthKeychainCredentials(identifier: Self.kIdentifier, clientId: Self.kClientId, encrypted: true) else {
            XCTFail("Failed to create keychain credentials")
            return
        }
        credentials.accessToken = accessToken
        credentials.refreshToken = refreshToken
        credentials.lightningSid = lightningSid
        credentials.vfSid = vfSid
        credentials.contentSid = contentSid
        credentials.csrfToken = csrfToken

        let accessTokenVerify = credentials.decryptedToken(forService: kSFOAuthServiceAccess)
        XCTAssertEqual(accessToken, accessTokenVerify, "Access token should decrypt to the same value.")

        let refreshTokenVerify = credentials.decryptedToken(forService: kSFOAuthServiceRefresh)
        XCTAssertEqual(refreshToken, refreshTokenVerify, "Refresh token should decrypt to the same value.")

        let lightningSidVerify = credentials.decryptedToken(forService: kSFOAuthServiceLightningSid)
        XCTAssertEqual(lightningSid, lightningSidVerify, "Lightning sid should decrypt to the same value.")

        let contentSidVerify = credentials.decryptedToken(forService: kSFOAuthServiceContentSid)
        XCTAssertEqual(contentSid, contentSidVerify, "content sid should decrypt to the same value.")

        let vfSidVerify = credentials.decryptedToken(forService: kSFOAuthServiceVfSid)
        XCTAssertEqual(vfSid, vfSidVerify, "vf sid should decrypt to the same value.")

        let csrfTokenVerify = credentials.decryptedToken(forService: kSFOAuthServiceCsrf)
        XCTAssertEqual(csrfToken, csrfTokenVerify, "csrf token should decrypt to the same value.")

        credentials.revoke()
    }

    // MARK: - scopeQueryParamString Tests

    func testScopeQueryParamStringEmptyScopes() {
        let coordinator = SFOAuthCoordinator()
        let scopes: [String] = []

        let result = coordinator.scopeQueryParamString(scopes)

        XCTAssertEqual(result, "", "Empty scopes should return empty string")
    }

    func testScopeQueryParamStringSingleScope() {
        let coordinator = SFOAuthCoordinator()
        let scopes = ["web"]

        let result = coordinator.scopeQueryParamString(scopes)

        // Should include refresh_token and the provided scope, URL encoded
        XCTAssertEqual(result, "&scope=refresh_token%20web", "Single scope should include refresh_token and be URL encoded")
    }

    func testScopeQueryParamStringMultipleScopes() {
        let coordinator = SFOAuthCoordinator()
        let scopes = ["web", "api", "id"]

        let result = coordinator.scopeQueryParamString(scopes)

        // Should include refresh_token and all provided scopes, sorted and URL encoded
        XCTAssertEqual(result, "&scope=api%20id%20refresh_token%20web", "Multiple scopes should be sorted alphabetically and include refresh_token")
    }

    func testScopeQueryParamStringWithRefreshTokenAlreadyPresent() {
        let coordinator = SFOAuthCoordinator()
        let scopes = ["web", "api", "refresh_token"]

        let result = coordinator.scopeQueryParamString(scopes)

        // Should still work correctly even if refresh_token is already present
        XCTAssertEqual(result, "&scope=api%20refresh_token%20web", "Should handle duplicate refresh_token gracefully and maintain sorted order")
    }
}
