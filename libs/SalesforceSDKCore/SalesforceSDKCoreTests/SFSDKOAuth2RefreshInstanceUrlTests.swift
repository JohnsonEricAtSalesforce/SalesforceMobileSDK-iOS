/*
 Copyright (c) 2026-present, salesforce.com, inc. All rights reserved.

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

/**
 Tests for token refresh behavior that ensures instanceUrl is used when available,
 eliminating unnecessary login-pool redirects and improving performance for both
 Bearer and DPoP authentication flows.

 These tests validate the precedence logic: community URL first, then instanceUrl,
 then fallback to domain. They also confirm code exchange (first login) is unaffected.

 Ported from the upstream ObjC SFSDKOAuth2RefreshInstanceUrlTests.m against the
 migrated Swift surface (`@testable` access to `prepareBasicRequest`, which upstream
 exposed via SFSDKOAuth2+Internal.h).
 */
class SFSDKOAuth2RefreshInstanceUrlTests: XCTestCase {

    // MARK: - Unit Tests for overrideDomainIfNeeded

    /// overrideDomainIfNeeded returns instanceUrl when it is populated and communityId is nil.
    /// This is the happy path for refresh tokens after successful login.
    func test_givenInstanceUrlPopulated_whenOverrideDomainIfNeededCalled_thenReturnsInstanceUrl() throws {
        // Given: Credentials with instanceUrl populated (post-login state)
        let creds = try XCTUnwrap(OAuthCredentials.credentials(identifier: "test_refresh_instance", clientId: "test_client_id", encrypted: false, storageType: .none))

        // Simulate post-login state by updating credentials with token endpoint response
        creds.update([
            "access_token": "test-access-token",
            "refresh_token": "test-refresh-token",
            "instance_url": "https://mydomain.my.salesforce.com",
            "id": "https://id.salesforce.com/id/00Dxx0000000000/005xx000000000"
        ])

        // When: overrideDomainIfNeeded is called
        let result = creds.overrideDomainIfNeeded()

        // Then: Should return instanceUrl, not domain
        XCTAssertEqual(result.absoluteString, "https://mydomain.my.salesforce.com", "Expected instanceUrl to be used when populated")
        XCTAssertEqual(result.host, "mydomain.my.salesforce.com", "Expected instance URL host, not login pool domain")
    }

    /// overrideDomainIfNeeded falls back to domain when instanceUrl is nil. This simulates either
    /// code exchange (first login) or edge cases where instanceUrl is not yet populated.
    func test_givenInstanceUrlNil_whenOverrideDomainIfNeededCalled_thenReturnsDomain() throws {
        // Given: Credentials without instanceUrl (pre-login or code exchange state)
        let creds = try XCTUnwrap(OAuthCredentials.credentials(identifier: "test_fallback", clientId: "test_client_id", encrypted: false, storageType: .none))

        // Explicitly verify instanceUrl is nil (should be default state)
        XCTAssertNil(creds.instanceUrl, "instanceUrl should be nil in initial state")

        // When: overrideDomainIfNeeded is called
        let result = creds.overrideDomainIfNeeded()

        // Then: Should fall back to protocol://domain
        XCTAssertEqual(result.absoluteString, "https://login.salesforce.com", "Expected fallback to domain when instanceUrl is nil")
        XCTAssertEqual(result.host, "login.salesforce.com", "Expected login pool domain when instanceUrl is nil")
    }

    /// communityUrl takes precedence over instanceUrl when communityId is set. Community-based
    /// authentication has its own token endpoint and must not be changed by the instanceUrl logic.
    func test_givenCommunityIdSet_whenOverrideDomainIfNeededCalled_thenReturnsCommunityUrlRegardlessOfInstanceUrl() throws {
        // Given: Credentials with both communityUrl and instanceUrl populated
        let creds = try XCTUnwrap(OAuthCredentials.credentials(identifier: "test_community", clientId: "test_client_id", encrypted: false, storageType: .none))

        // Simulate community login by setting both community and instance URLs
        creds.update([
            "access_token": "test-access-token",
            "refresh_token": "test-refresh-token",
            "instance_url": "https://mydomain.my.salesforce.com",
            "sfdc_community_id": "0DB000000000001",
            "sfdc_community_url": "https://mycommunity.force.com",
            "id": "https://id.salesforce.com/id/00Dxx0000000000/005xx000000000"
        ])

        // When: overrideDomainIfNeeded is called
        let result = creds.overrideDomainIfNeeded()

        // Then: Should return communityUrl, not instanceUrl or domain
        XCTAssertEqual(result.absoluteString, "https://mycommunity.force.com", "Expected communityUrl to take precedence over instanceUrl")
        XCTAssertEqual(result.host, "mycommunity.force.com", "Expected community host, not instance or login pool")
    }

    // MARK: - Integration Tests with SFSDKOAuth2.prepareBasicRequest

    /// When instanceUrl is populated, prepareBasicRequest builds a token endpoint URL whose host
    /// is the instanceUrl host (not the login pool). Exercises the full request-construction path
    /// the production refresh flow uses.
    func test_givenInstanceUrlPopulated_whenPrepareBasicRequestCalled_thenRequestURLUsesInstanceUrlHost() throws {
        let creds = try XCTUnwrap(OAuthCredentials.credentials(identifier: "test_refresh_integration", clientId: "test_client_id", encrypted: false, storageType: .none))

        creds.update([
            "access_token": "test-access-token",
            "refresh_token": "test-refresh-token",
            "instance_url": "https://mydomain.my.salesforce.com",
            "id": "https://id.salesforce.com/id/00Dxx0000000000/005xx000000000"
        ])

        let endpointReq = SFSDKOAuthTokenEndpointRequest()
        endpointReq.clientID = creds.clientId ?? ""
        endpointReq.refreshToken = creds.refreshToken ?? ""
        endpointReq.redirectURI = creds.redirectUri ?? "test://callback"
        endpointReq.serverURL = creds.overrideDomainIfNeeded()

        let request = SFSDKOAuth2().prepareBasicRequest(endpointReq)

        XCTAssertNotNil(request.url, "prepareBasicRequest should produce a URL")
        XCTAssertEqual(request.url?.host, "mydomain.my.salesforce.com", "Refresh request should target instanceUrl.host to avoid redirect")
        XCTAssertEqual(request.url?.path, "/services/oauth2/token", "Token endpoint path should be appended correctly")
    }

    /// When instanceUrl is nil, prepareBasicRequest falls back to domain. Validates backward
    /// compatibility with pre-existing behavior.
    func test_givenInstanceUrlNil_whenPrepareBasicRequestCalled_thenRequestURLUsesDomainHost() throws {
        let creds = try XCTUnwrap(OAuthCredentials.credentials(identifier: "test_refresh_fallback", clientId: "test_client_id", encrypted: false, storageType: .none))

        creds.update(["refresh_token": "test-refresh-token"])

        XCTAssertNil(creds.instanceUrl, "instanceUrl should be nil for this test")

        let endpointReq = SFSDKOAuthTokenEndpointRequest()
        endpointReq.clientID = creds.clientId ?? ""
        endpointReq.refreshToken = creds.refreshToken ?? ""
        endpointReq.redirectURI = "test://callback"
        endpointReq.serverURL = creds.overrideDomainIfNeeded()

        let request = SFSDKOAuth2().prepareBasicRequest(endpointReq)

        XCTAssertNotNil(request.url, "prepareBasicRequest should produce a URL")
        XCTAssertEqual(request.url?.host, "login.salesforce.com", "Refresh request should fall back to domain when instanceUrl is nil")
        XCTAssertEqual(request.url?.path, "/services/oauth2/token", "Token endpoint path should be appended correctly")
    }

    /// Code exchange (first login) continues to target domain, not instanceUrl. At code exchange
    /// time, instanceUrl is not yet known, so the SDK must target the login pool. Validates that the
    /// fix does not break code exchange.
    func test_givenInstanceUrlNil_whenPrepareBasicRequestCalledForCodeExchange_thenRequestURLUsesDomainHost() throws {
        let creds = try XCTUnwrap(OAuthCredentials.credentials(identifier: "test_code_exchange", clientId: "test_client_id", encrypted: false, storageType: .none))

        XCTAssertNil(creds.instanceUrl, "instanceUrl must be nil during code exchange")
        XCTAssertNil(creds.refreshToken, "refreshToken must be nil during code exchange")

        let endpointReq = SFSDKOAuthTokenEndpointRequest()
        endpointReq.clientID = creds.clientId ?? ""
        endpointReq.approvalCode = "test_approval_code"
        endpointReq.codeVerifier = "test_code_verifier"
        endpointReq.redirectURI = "test://callback"
        endpointReq.serverURL = creds.overrideDomainIfNeeded()

        let request = SFSDKOAuth2().prepareBasicRequest(endpointReq)

        XCTAssertNotNil(request.url, "prepareBasicRequest should produce a URL")
        XCTAssertEqual(request.url?.host, "login.salesforce.com", "Code exchange must target domain since instanceUrl is not yet known")
        XCTAssertEqual(request.url?.path, "/services/oauth2/token", "Token endpoint path should be appended correctly")
    }
}
