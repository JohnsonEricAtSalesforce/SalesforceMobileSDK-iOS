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

import XCTest
@testable import SalesforceSDKCore

class SalesforceSDKIdentityTests: XCTestCase {

    /// Tests that identity data can be successfully processed
    func testProcessIdentityData() {
        let identityResponse = """
        {"id":"https://login.salesforce.com/id/some-org-id/some-user-id","asserted_user":true,"user_id":"some-user-id","organization_id":"some-org-id","username":"user@example.com","nick_name":"nickname","display_name":"Example User","email":"user@example.com","email_verified":true,"first_name":"Example","last_name":"User","timezone":"America/Los_Angeles","photos":{"picture":"https://example.com/profilephoto/full","thumbnail":"https://example.com/profilephoto/thumb"},"addr_street":null,"addr_city":null,"addr_state":null,"addr_country":null,"addr_zip":null,"mobile_phone":null,"mobile_phone_verified":false,"is_lightning_login_user":false,"status":{"created_date":null,"body":null},"urls":{"enterprise":"https://example.my.salesforce.com/services/Soap/c/some-version/some-org-id","metadata":"https://example.my.salesforce.com/services/Soap/m/some-version/some-org-id","partner":"https://example.my.salesforce.com/services/Soap/u/some-version/some-org-id","rest":"https://example.my.salesforce.com/services/data/vsome-version/","sobjects":"https://example.my.salesforce.com/services/data/vsome-version/sobjects/","search":"https://example.my.salesforce.com/services/data/vsome-version/search/","query":"https://example.my.salesforce.com/services/data/vsome-version/query/","recent":"https://example.my.salesforce.com/services/data/vsome-version/recent/","tooling_soap":"https://example.my.salesforce.com/services/Soap/T/some-version/some-org-id","tooling_rest":"https://example.my.salesforce.com/services/data/vsome-version/tooling/","profile":"https://example.my.salesforce.com/some-user-id","feeds":"https://example.my.salesforce.com/services/data/vsome-version/chatter/feeds","groups":"https://example.my.salesforce.com/services/data/vsome-version/chatter/groups","users":"https://example.my.salesforce.com/services/data/vsome-version/chatter/users","feed_items":"https://example.my.salesforce.com/services/data/vsome-version/chatter/feed-items","feed_elements":"https://example.my.salesforce.com/services/data/vsome-version/chatter/feed-elements","custom_domain":"https://example.my.salesforce.com"},"active":true,"user_type":"STANDARD","language":"en_US","locale":"en_US","utcOffset":-28800000,"last_modified_date":"2024-12-23T18:40:50Z"}
        """

        let credentials = OAuthCredentials(identifier: "test", clientId: "test", encrypted: false)
        let coordinator = SFIdentityCoordinator(credentials: credentials)
        let identityResponseData = identityResponse.data(using: .utf8)
        coordinator.processResponse(identityResponseData)
        guard let idData = coordinator.idData else {
            XCTFail("idData should not be nil")
            return
        }

        // Basic identity fields
        XCTAssertEqual(idData.idUrl, URL(string: "https://login.salesforce.com/id/some-org-id/some-user-id"), "idUrl should match")
        XCTAssertTrue(idData.assertedUser, "assertedUser should be true")
        XCTAssertEqual(idData.userId, "some-user-id", "userId should match")
        XCTAssertEqual(idData.orgId, "some-org-id", "orgId should match")

        // User information
        XCTAssertEqual(idData.username, "user@example.com", "username should match")
        XCTAssertEqual(idData.nickname, "nickname", "nickname should match")
        XCTAssertEqual(idData.displayName, "Example User", "displayName should match")
        XCTAssertEqual(idData.email, "user@example.com", "email should match")
        XCTAssertEqual(idData.firstName, "Example", "firstName should match")
        XCTAssertEqual(idData.lastName, "User", "lastName should match")

        // Photos (URL properties)
        XCTAssertEqual(idData.pictureUrl, URL(string: "https://example.com/profilephoto/full"), "pictureUrl should match")
        XCTAssertEqual(idData.thumbnailUrl, URL(string: "https://example.com/profilephoto/thumb"), "thumbnailUrl should match")

        // SOAP URLs
        XCTAssertEqual(idData.enterpriseSoapUrl, "https://example.my.salesforce.com/services/Soap/c/some-version/some-org-id", "enterpriseSoapUrl should match")
        XCTAssertEqual(idData.metadataSoapUrl, "https://example.my.salesforce.com/services/Soap/m/some-version/some-org-id", "metadataSoapUrl should match")
        XCTAssertEqual(idData.partnerSoapUrl, "https://example.my.salesforce.com/services/Soap/u/some-version/some-org-id", "partnerSoapUrl should match")

        // REST URLs
        XCTAssertEqual(idData.restUrl, "https://example.my.salesforce.com/services/data/vsome-version/", "restUrl should match")
        XCTAssertEqual(idData.restSObjectsUrl, "https://example.my.salesforce.com/services/data/vsome-version/sobjects/", "restSObjectsUrl should match")
        XCTAssertEqual(idData.restSearchUrl, "https://example.my.salesforce.com/services/data/vsome-version/search/", "restSearchUrl should match")
        XCTAssertEqual(idData.restQueryUrl, "https://example.my.salesforce.com/services/data/vsome-version/query/", "restQueryUrl should match")
        XCTAssertEqual(idData.restRecentUrl, "https://example.my.salesforce.com/services/data/vsome-version/recent/", "restRecentUrl should match")

        // Profile and Chatter URLs
        XCTAssertEqual(idData.profileUrl, URL(string: "https://example.my.salesforce.com/some-user-id"), "profileUrl should match (URL)")
        XCTAssertEqual(idData.chatterFeedsUrl, "https://example.my.salesforce.com/services/data/vsome-version/chatter/feeds", "chatterFeedsUrl should match")
        XCTAssertEqual(idData.chatterGroupsUrl, "https://example.my.salesforce.com/services/data/vsome-version/chatter/groups", "chatterGroupsUrl should match")
        XCTAssertEqual(idData.chatterUsersUrl, "https://example.my.salesforce.com/services/data/vsome-version/chatter/users", "chatterUsersUrl should match")
        XCTAssertEqual(idData.chatterFeedItemsUrl, "https://example.my.salesforce.com/services/data/vsome-version/chatter/feed-items", "chatterFeedItemsUrl should match")

        // User status and preferences
        XCTAssertTrue(idData.isActive, "isActive should be true")
        XCTAssertEqual(idData.userType, "STANDARD", "userType should match")
        XCTAssertEqual(idData.language, "en_US", "language should match")
        XCTAssertEqual(idData.locale, "en_US", "locale should match")
        XCTAssertEqual(idData.utcOffset, -28800000, "utcOffset should match")

        // Date parsing
        XCTAssertNotNil(idData.lastModifiedDate, "lastModifiedDate should not be nil")
    }
}
