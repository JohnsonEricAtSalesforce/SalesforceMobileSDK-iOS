/*
 CredentialsArchiveRoundTripTests.swift
 SalesforceSDKCoreTests

 Copyright (c) 2025-present, salesforce.com, inc. All rights reserved.

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
@testable import SalesforceSDKCore

/// Tests that OAuthCredentials can be archived (NSSecureCoding) and unarchived
/// with all non-token properties preserved. Tokens are intentionally NOT encoded for security.
class CredentialsArchiveRoundTripTests: XCTestCase {

    private static let kIdentifier = "com.salesforce.ios.archive.test"
    private static let kClientId = "TestConsumerKey_archive"

    override class func setUp() {
        super.setUp()
    }

    // MARK: - Test 1: StorageType .none round-trip preserves all non-token properties

    func test_givenCredentialsWithStorageTypeNone_whenArchivedAndUnarchived_thenAllNonTokenPropertiesPreserved() throws {
        let creds = try XCTUnwrap(
            OAuthCredentials.credentials(identifier: Self.kIdentifier, clientId: Self.kClientId, encrypted: false, storageType: .none),
            "Failed to create credentials with storageType .none"
        )

        // Set all archivable properties
        creds.domain = "test.salesforce.com"
        creds.redirectUri = "testapp://oauth/callback"
        creds.organizationId = "00D000000000001"
        creds.instanceUrl = URL(string: "https://na1.salesforce.com")
        creds.communityId = "0DB000000000001"
        creds.communityUrl = URL(string: "https://community.salesforce.com")
        creds.issuedAt = Date(timeIntervalSince1970: 1700000000)
        creds.identityUrl = URL(string: "https://login.salesforce.com/id/00D000000000001/005000000000001")
        creds.additionalOAuthFields = ["custom_key": "custom_value", "another_key": "another_value"] as NSDictionary
        creds.scopes = ["api", "refresh_token", "web"]
        creds.lightningDomain = "lightning.test.com"
        creds.vfDomain = "vf.test.com"
        creds.contentDomain = "content.test.com"
        creds.cookieClientSrc = "test-client-src"
        creds.cookieSidClient = "test-sid-client"
        creds.sidCookieName = "test-sid-cookie"
        creds.tokenFormat = "JWT"

        // Set tokens (these should NOT be encoded for storageType .none because the class is SFOAuthCredentials base)
        // Actually for storageType .none, tokens ARE stored in memory and ARE encoded (see encodeWithCoder:
        // does NOT encode tokens). Let's set them to verify they don't come back.
        creds.accessToken = "secret_access_token_12345"
        creds.refreshToken = "secret_refresh_token_67890"

        // Archive
        let data = try NSKeyedArchiver.archivedData(withRootObject: creds, requiringSecureCoding: true)
        XCTAssertFalse(data.isEmpty, "Archived data should not be empty")

        // Unarchive
        let restored = try XCTUnwrap(
            NSKeyedUnarchiver.unarchivedObject(ofClass: OAuthCredentials.self, from: data),
            "Failed to unarchive credentials"
        )

        // Verify all non-token properties
        XCTAssertEqual(restored.identifier, Self.kIdentifier)
        XCTAssertEqual(restored.clientId, Self.kClientId)
        XCTAssertEqual(restored.domain, "test.salesforce.com")
        XCTAssertEqual(restored.redirectUri, "testapp://oauth/callback")
        XCTAssertEqual(restored.organizationId, "00D000000000001")
        XCTAssertEqual(restored.instanceUrl, URL(string: "https://na1.salesforce.com"))
        XCTAssertEqual(restored.communityId, "0DB000000000001")
        XCTAssertEqual(restored.communityUrl, URL(string: "https://community.salesforce.com"))
        XCTAssertEqual(restored.issuedAt, Date(timeIntervalSince1970: 1700000000))
        XCTAssertEqual(restored.identityUrl, URL(string: "https://login.salesforce.com/id/00D000000000001/005000000000001"))
        XCTAssertEqual(restored.scopes as? [String], ["api", "refresh_token", "web"])
        XCTAssertEqual(restored.lightningDomain, "lightning.test.com")
        XCTAssertEqual(restored.vfDomain, "vf.test.com")
        XCTAssertEqual(restored.contentDomain, "content.test.com")
        XCTAssertEqual(restored.cookieClientSrc, "test-client-src")
        XCTAssertEqual(restored.cookieSidClient, "test-sid-client")
        XCTAssertEqual(restored.sidCookieName, "test-sid-cookie")
        XCTAssertEqual(restored.tokenFormat, "JWT")
        XCTAssertEqual(restored.isEncrypted, false)

        // Verify additionalOAuthFields round-trips
        let additionalFields = try XCTUnwrap(restored.additionalOAuthFields as? [String: String])
        XCTAssertEqual(additionalFields["custom_key"], "custom_value")
        XCTAssertEqual(additionalFields["another_key"], "another_value")

        // Tokens are NOT encoded by encodeWithCoder: so they should be nil after unarchive
        // HOWEVER: for the base class (storageType .none), initWithCoder: DOES decode tokens
        // (see line 123-134 in .m: "if [self isMemberOfClass:[SFOAuthCredentials class]]")
        // But encodeWithCoder does NOT encode them. So after round-trip they should be nil.
        XCTAssertNil(restored.accessToken, "Access token should NOT survive archive (not encoded)")
        XCTAssertNil(restored.refreshToken, "Refresh token should NOT survive archive (not encoded)")
    }

    // MARK: - Test 2: StorageType .keychain round-trip (OAuthKeychainCredentials)

    func test_givenCredentialsWithStorageTypeKeychain_whenArchivedAndUnarchived_thenNonTokenPropertiesPreserved() throws {
        let creds = try XCTUnwrap(
            OAuthCredentials.credentials(identifier: Self.kIdentifier + ".keychain", clientId: Self.kClientId, encrypted: true, storageType: .keychain),
            "Failed to create credentials with storageType .keychain"
        )

        // Verify we got the keychain subclass
        XCTAssertTrue(creds is OAuthKeychainCredentials, "Should be OAuthKeychainCredentials instance")

        creds.domain = "login.salesforce.com"
        creds.redirectUri = "myapp://auth/success"
        creds.organizationId = "00D000000000002"
        creds.instanceUrl = URL(string: "https://na2.salesforce.com")
        creds.communityId = "0DB000000000002"
        creds.communityUrl = URL(string: "https://community2.salesforce.com")
        creds.issuedAt = Date(timeIntervalSince1970: 1700001000)
        creds.identityUrl = URL(string: "https://login.salesforce.com/id/00D000000000002/005000000000002")
        creds.scopes = ["api", "web"]
        creds.lightningDomain = "lightning2.test.com"
        creds.vfDomain = "vf2.test.com"
        creds.contentDomain = "content2.test.com"
        creds.cookieClientSrc = "client-src-2"
        creds.cookieSidClient = "sid-client-2"
        creds.sidCookieName = "sid-cookie-2"
        creds.tokenFormat = "BEARER"

        // Archive
        let data = try NSKeyedArchiver.archivedData(withRootObject: creds, requiringSecureCoding: true)
        XCTAssertFalse(data.isEmpty)

        // Unarchive
        let restored = try XCTUnwrap(
            NSKeyedUnarchiver.unarchivedObject(ofClass: OAuthCredentials.self, from: data),
            "Failed to unarchive keychain credentials"
        )

        // Verify it's the right subclass
        XCTAssertTrue(restored is OAuthKeychainCredentials, "Restored should be OAuthKeychainCredentials")

        // Verify properties
        XCTAssertEqual(restored.identifier, Self.kIdentifier + ".keychain")
        XCTAssertEqual(restored.clientId, Self.kClientId)
        XCTAssertEqual(restored.domain, "login.salesforce.com")
        XCTAssertEqual(restored.redirectUri, "myapp://auth/success")
        XCTAssertEqual(restored.organizationId, "00D000000000002")
        XCTAssertEqual(restored.instanceUrl, URL(string: "https://na2.salesforce.com"))
        XCTAssertEqual(restored.communityId, "0DB000000000002")
        XCTAssertEqual(restored.communityUrl, URL(string: "https://community2.salesforce.com"))
        XCTAssertEqual(restored.issuedAt, Date(timeIntervalSince1970: 1700001000))
        XCTAssertEqual(restored.identityUrl, URL(string: "https://login.salesforce.com/id/00D000000000002/005000000000002"))
        XCTAssertEqual(restored.scopes as? [String], ["api", "web"])
        XCTAssertEqual(restored.isEncrypted, true)
        XCTAssertEqual(restored.lightningDomain, "lightning2.test.com")
        XCTAssertEqual(restored.vfDomain, "vf2.test.com")
        XCTAssertEqual(restored.contentDomain, "content2.test.com")
        XCTAssertEqual(restored.cookieClientSrc, "client-src-2")
        XCTAssertEqual(restored.cookieSidClient, "sid-client-2")
        XCTAssertEqual(restored.sidCookieName, "sid-cookie-2")
        XCTAssertEqual(restored.tokenFormat, "BEARER")
    }

    // MARK: - Test 3: additionalOAuthFields dict round-trips correctly

    func test_givenCredentialsWithAdditionalOAuthFields_whenArchivedAndUnarchived_thenFieldsPreserved() throws {
        let creds = try XCTUnwrap(
            OAuthCredentials.credentials(identifier: Self.kIdentifier + ".fields", clientId: Self.kClientId, encrypted: false, storageType: .none)
        )

        let fields: NSDictionary = [
            "custom_param_1": "value_1",
            "custom_param_2": "value_2",
            "custom_param_3": "value_3"
        ]
        creds.additionalOAuthFields = fields

        let data = try NSKeyedArchiver.archivedData(withRootObject: creds, requiringSecureCoding: true)
        let restored = try XCTUnwrap(NSKeyedUnarchiver.unarchivedObject(ofClass: OAuthCredentials.self, from: data))

        let restoredFields = try XCTUnwrap(restored.additionalOAuthFields)
        XCTAssertEqual(restoredFields, fields)
    }

    // MARK: - Test 4: nil properties don't crash during archive/unarchive

    func test_givenCredentialsWithNilProperties_whenArchivedAndUnarchived_thenDoesNotCrash() throws {
        let creds = try XCTUnwrap(
            OAuthCredentials.credentials(identifier: Self.kIdentifier + ".nil", clientId: nil, encrypted: false, storageType: .none)
        )

        // Leave most properties nil - just verify archive/unarchive doesn't crash
        let data = try NSKeyedArchiver.archivedData(withRootObject: creds, requiringSecureCoding: true)
        let restored = try XCTUnwrap(NSKeyedUnarchiver.unarchivedObject(ofClass: OAuthCredentials.self, from: data))

        XCTAssertEqual(restored.identifier, Self.kIdentifier + ".nil")
        XCTAssertNil(restored.clientId)
        XCTAssertNil(restored.redirectUri)
        XCTAssertNil(restored.organizationId)
        XCTAssertNil(restored.instanceUrl)
        XCTAssertNil(restored.communityId)
        XCTAssertNil(restored.communityUrl)
        XCTAssertNil(restored.issuedAt)
        XCTAssertNil(restored.identityUrl)
        XCTAssertNil(restored.additionalOAuthFields)
        XCTAssertNil(restored.scopes)
    }

    // MARK: - Test 5: Encrypted flag round-trips

    func test_givenEncryptedCredentials_whenArchivedAndUnarchived_thenEncryptedFlagPreserved() throws {
        let credsEncrypted = try XCTUnwrap(
            OAuthCredentials.credentials(identifier: Self.kIdentifier + ".enc", clientId: Self.kClientId, encrypted: true, storageType: .none)
        )
        XCTAssertTrue(credsEncrypted.isEncrypted)

        let data = try NSKeyedArchiver.archivedData(withRootObject: credsEncrypted, requiringSecureCoding: true)
        let restored = try XCTUnwrap(NSKeyedUnarchiver.unarchivedObject(ofClass: OAuthCredentials.self, from: data))
        XCTAssertTrue(restored.isEncrypted, "Encrypted flag should survive round-trip")
    }

    // MARK: - Test 6: Class-cluster key stored correctly (SFOAuthClusterImplementation)

    func test_givenKeychainCredentials_whenArchived_thenClusterKeyIsStoredCorrectly() throws {
        let creds = try XCTUnwrap(
            OAuthCredentials.credentials(identifier: Self.kIdentifier + ".cluster", clientId: Self.kClientId, encrypted: false, storageType: .keychain)
        )

        let data = try NSKeyedArchiver.archivedData(withRootObject: creds, requiringSecureCoding: true)

        // Unarchive using lower-level unarchiver to inspect the cluster key
        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
        unarchiver.requiresSecureCoding = true

        // We can verify the round-trip produces the correct class
        let restored = try XCTUnwrap(
            unarchiver.decodeObject(of: [OAuthCredentials.self, OAuthKeychainCredentials.self], forKey: NSKeyedArchiveRootObjectKey) as? OAuthCredentials
        )
        XCTAssertTrue(restored is OAuthKeychainCredentials, "Cluster key should restore as OAuthKeychainCredentials")
        unarchiver.finishDecoding()
    }

    // MARK: - Test 7: Write archive to /tmp for future Swift-implementation verification

    func test_givenFullyPopulatedCredentials_whenArchived_thenDataWrittenToTmpForVerification() throws {
        let creds = try XCTUnwrap(
            OAuthCredentials.credentials(identifier: Self.kIdentifier + ".export", clientId: Self.kClientId, encrypted: true, storageType: .none)
        )

        creds.domain = "test.salesforce.com"
        creds.redirectUri = "testapp://oauth/done"
        creds.organizationId = "00D000000000099"
        creds.instanceUrl = URL(string: "https://na99.salesforce.com")
        creds.communityId = "0DB000000000099"
        creds.communityUrl = URL(string: "https://community99.salesforce.com")
        creds.issuedAt = Date(timeIntervalSince1970: 1700099000)
        creds.identityUrl = URL(string: "https://login.salesforce.com/id/00D000000000099/005000000000099")
        creds.scopes = ["api", "refresh_token"]
        creds.additionalOAuthFields = ["export_key": "export_value"] as NSDictionary
        creds.lightningDomain = "lightning99.test.com"
        creds.vfDomain = "vf99.test.com"
        creds.contentDomain = "content99.test.com"
        creds.cookieClientSrc = "export-client-src"
        creds.cookieSidClient = "export-sid-client"
        creds.sidCookieName = "export-sid-cookie"
        creds.tokenFormat = "JWT"

        let data = try NSKeyedArchiver.archivedData(withRootObject: creds, requiringSecureCoding: true)

        // Write to /tmp for future Swift-implementation verification
        let outputPath = "/tmp/credentials_archive_objc.dat"
        try data.write(to: URL(fileURLWithPath: outputPath))

        // Verify the file exists and can be read back
        let readData = try Data(contentsOf: URL(fileURLWithPath: outputPath))
        let restored = try XCTUnwrap(NSKeyedUnarchiver.unarchivedObject(ofClass: OAuthCredentials.self, from: readData))
        XCTAssertEqual(restored.identifier, Self.kIdentifier + ".export")
        XCTAssertEqual(restored.domain, "test.salesforce.com")
        XCTAssertEqual(restored.organizationId, "00D000000000099")
    }
}
