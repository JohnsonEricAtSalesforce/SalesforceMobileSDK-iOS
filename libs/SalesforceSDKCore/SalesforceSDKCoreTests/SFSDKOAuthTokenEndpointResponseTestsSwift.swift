/*
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

final class SFSDKOAuthTokenEndpointResponseTestsSwift: XCTestCase {

    func testInitWithDictionary() {
        // Prepare dictionary simulating response from token end point
        var params: [String: String] = [:]
        params["access_token"] = "test-auth-token"
        params["refresh_token"] = "test-refresh-token"
        params["instance_url"] = "https://instance.salesforce.com"
        params["api_instance_url"] = "https://api.salesforce.com"
        params["scope"] = "api refresh_token"
        params["id"] = "https://id.salesforce.com"
        params["sfdc_community_id"] = "test-community-id"
        params["sfdc_community_url"] = "https://community.salesforce.com"
        params["lightning_domain"] = "test-lightning-domain"
        params["lightning_sid"] = "test-lightning-sid"
        params["visualforce_domain"] = "test-vf-domain"
        params["visualforce_sid"] = "test-vf-sid"
        params["content_domain"] = "test-content-domain"
        params["content_sid"] = "test-content-sid"
        params["csrf_token"] = "test-csrf-token"
        params["cookie-clientSrc"] = "test-cookie-client-src"
        params["cookie-sid_Client"] = "test-cookie-sid-client"
        params["sidCookieName"] = "test-sid-cookie-name"
        params["parent_sid"] = "test-parent-sid"
        params["token_format"] = "test-token-format"
        params["beacon_child_consumer_key"] = "test-beacon-child-consumer-key"
        params["beacon_child_consumer_secret"] = "test-beacon-child-consumer-secret"

        // Additional fields
        let additionalFields = ["additional-1", "additional-2"]
        for field in additionalFields {
            params[field] = "test-\(field)"
        }

        // Create SFSDKOAuthTokenEndpointResponse with initWithDictionary
        let response = SFSDKOAuthTokenEndpointResponse(dictionary: params, parseAdditionalFields: additionalFields)

        // Check regular fields
        XCTAssertEqual(response.accessToken, "test-auth-token")
        XCTAssertEqual(response.refreshToken, "test-refresh-token")
        XCTAssertEqual(response.instanceUrl?.absoluteString, "https://instance.salesforce.com")
        XCTAssertEqual(response.apiInstanceUrl?.absoluteString, "https://api.salesforce.com")
        XCTAssertEqual(response.scopes, ["api", "refresh_token"])
        XCTAssertEqual(response.identityUrl?.absoluteString, "https://id.salesforce.com")
        XCTAssertEqual(response.communityId, "test-community-id")
        XCTAssertEqual(response.communityUrl?.absoluteString, "https://community.salesforce.com")
        XCTAssertEqual(response.lightningDomain, "test-lightning-domain")
        XCTAssertEqual(response.lightningSid, "test-lightning-sid")
        XCTAssertEqual(response.vfDomain, "test-vf-domain")
        XCTAssertEqual(response.vfSid, "test-vf-sid")
        XCTAssertEqual(response.contentDomain, "test-content-domain")
        XCTAssertEqual(response.contentSid, "test-content-sid")
        XCTAssertEqual(response.csrfToken, "test-csrf-token")
        XCTAssertEqual(response.cookieClientSrc, "test-cookie-client-src")
        XCTAssertEqual(response.cookieSidClient, "test-cookie-sid-client")
        XCTAssertEqual(response.sidCookieName, "test-sid-cookie-name")
        XCTAssertEqual(response.parentSid, "test-parent-sid")
        XCTAssertEqual(response.tokenFormat, "test-token-format")
        XCTAssertEqual(response.beaconChildConsumerKey, "test-beacon-child-consumer-key")
        XCTAssertEqual(response.beaconChildConsumerSecret, "test-beacon-child-consumer-secret")

        // Check additional fields
        for field in additionalFields {
            let value = "test-\(field)"
            XCTAssertEqual(response.additionalOAuthFields?[field] as? String, value)
        }
    }
}
