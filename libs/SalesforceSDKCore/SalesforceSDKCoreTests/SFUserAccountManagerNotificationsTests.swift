//
//  SFUserAccountManagerNotificationsTests.swift
//  SalesforceSDKCoreTests
//
//  Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.
//
//  Redistribution and use of this software in source and binary forms, with or without modification,
//  are permitted provided that the following conditions are met:
//  * Redistributions of source code must retain the above copyright notice, this list of conditions
//  and the following disclaimer.
//  * Redistributions in binary form must reproduce the above copyright notice, this list of
//  conditions and the following disclaimer in the documentation and/or other materials provided
//  with the distribution.
//  * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
//  endorse or promote products derived from this software without specific prior written
//  permission of salesforce.com, inc.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
//  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
//  FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
//  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
//  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
//  WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import XCTest
@testable import SalesforceSDKCore

private let kUserIdFormatString = "005R0000000Dsl%lu"
private let kOrgIdFormatString = "00D000000000062EA%lu"

class SFUserAccountManagerNotificationsTests: XCTestCase {

    private var origAccountPersister: (any SFUserAccountPersister)?
    private var user: UserAccount?
    private var origCurrentUser: UserAccount?
    private var uam: UserAccountManager?

    override func setUp() {
        super.setUp()
        uam = UserAccountManager.shared
        origAccountPersister = uam?.accountPersister
        origCurrentUser = uam?.currentUserAccount
        uam?.accountPersister = SFUserAccountPersisterEphemeral()
        user = createNewUser(1)
    }

    override func tearDown() {
        if let user = user {
            deleteUserAndVerify(user)
        }
        uam?.accountPersister = origAccountPersister
        UserAccountManager.shared.setCurrentUserInternal(origCurrentUser)
        super.tearDown()
    }

    func testCommunityIdNotificationPosted() {
        guard let user = user, let uam = uam else { return }
        let coordinator = SFOAuthCoordinator(credentials: user.credentials)
        let credentials: [String: Any] = [kSFOAuthCommunityId: "COMMUNITY_ID"]

        expectation(forNotification: .SFUserAccountManagerDidChangeUserData, object: nil) { notification in
            guard let changeValue = notification.userInfo?[SFUserAccountManagerUserChangeKey] as? UInt else { return false }
            let change = UserAccount.AccountDataChange(rawValue: changeValue)
            return change == .communityId
        }

        coordinator.updateCredentials(credentials)
        XCTAssertTrue(coordinator.credentials?.credentialsChangeSet != nil && (coordinator.credentials?.credentialsChangeSet?.count ?? 0) > 0, "There should be at least one change in credentials")
        XCTAssertTrue(coordinator.credentials?.hasPropertyValueChangedForKey("communityId") ?? false, "SFUserAccountManager should detect change to properties")
        if let creds = coordinator.credentials {
            _ = uam.applyCredentials(creds, withIdData: nil)
        }
        waitForExpectations(timeout: 10.0, handler: nil)
    }

    func testInstanceUrlChangeNotificationPosted() {
        guard let user = user, let uam = uam else { return }
        let coordinator = SFOAuthCoordinator(credentials: user.credentials)

        expectation(forNotification: .SFUserAccountManagerDidChangeUserData, object: nil) { notification in
            guard let changeValue = notification.userInfo?[SFUserAccountManagerUserChangeKey] as? UInt else { return false }
            let change = UserAccount.AccountDataChange(rawValue: changeValue)
            return change == .instanceURL
        }

        let credentials: [String: Any] = [kSFOAuthInstanceUrl: "https://new.instance.url"]
        coordinator.updateCredentials(credentials)
        XCTAssertTrue(coordinator.credentials?.credentialsChangeSet != nil && (coordinator.credentials?.credentialsChangeSet?.count ?? 0) > 0, "There should be at least one change in credentials")
        XCTAssertTrue(coordinator.credentials?.hasPropertyValueChangedForKey("instanceUrl") ?? false, "SFUserAccountManager should detect change to instanceUrl")
        if let creds = coordinator.credentials {
            _ = uam.applyCredentials(creds)
        }
        waitForExpectations(timeout: 10.0, handler: nil)
    }

    func testAccessTokenChangeNotificationPosted() {
        guard let user = user, let uam = uam else { return }
        let coordinator = SFOAuthCoordinator(credentials: user.credentials)

        expectation(forNotification: .SFUserAccountManagerDidChangeUserData, object: nil) { notification in
            guard let changeValue = notification.userInfo?[SFUserAccountManagerUserChangeKey] as? UInt else { return false }
            let change = UserAccount.AccountDataChange(rawValue: changeValue)
            return change == .accessToken
        }

        let credentials: [String: Any] = [kSFOAuthAccessToken: "new_access_token"]
        coordinator.updateCredentials(credentials)
        XCTAssertTrue(coordinator.credentials?.credentialsChangeSet != nil && (coordinator.credentials?.credentialsChangeSet?.count ?? 0) > 0, "There should be at least one change in credentials")
        XCTAssertTrue(coordinator.credentials?.hasPropertyValueChangedForKey("accessToken") ?? false, "SFUserAccountManager should detect change to accessToken")
        if let creds = coordinator.credentials {
            _ = uam.applyCredentials(creds)
        }
        waitForExpectations(timeout: 10.0, handler: nil)
    }

    func testMultipleChangesNotificationPosted() {
        guard let user = user, let uam = uam else { return }
        let coordinator = SFOAuthCoordinator(credentials: user.credentials)
        let expectedChange: UInt = UserAccount.AccountDataChange.communityId.rawValue | UserAccount.AccountDataChange.instanceURL.rawValue | UserAccount.AccountDataChange.accessToken.rawValue

        expectation(forNotification: .SFUserAccountManagerDidChangeUserData, object: nil) { notification in
            guard let changeValue = notification.userInfo?[SFUserAccountManagerUserChangeKey] as? UInt else { return false }
            return (changeValue & expectedChange) == expectedChange
        }

        let credentials: [String: Any] = [
            kSFOAuthCommunityId: "COMMUNITY_ID_1",
            kSFOAuthAccessToken: "new_access_token_1",
            kSFOAuthInstanceUrl: "https://new.instance.url1"
        ]
        coordinator.updateCredentials(credentials)
        XCTAssertTrue(coordinator.credentials?.credentialsChangeSet != nil && (coordinator.credentials?.credentialsChangeSet?.count ?? 0) > 0, "There should be at least one change in credentials")
        XCTAssertTrue(coordinator.credentials?.hasPropertyValueChangedForKey("accessToken") ?? false, "SFUserAccountManager should detect change to accessToken")
        XCTAssertTrue(coordinator.credentials?.hasPropertyValueChangedForKey("communityId") ?? false, "SFUserAccountManager should detect change to communityId")
        XCTAssertTrue(coordinator.credentials?.hasPropertyValueChangedForKey("instanceUrl") ?? false, "SFUserAccountManager should detect change to instanceUrl")
        if let creds = coordinator.credentials {
            _ = uam.applyCredentials(creds)
        }
        waitForExpectations(timeout: 10.0, handler: nil)
    }

    func testNewUserChangeNotificationPosted() {
        guard let user = user, let uam = uam else { return }

        expectation(forNotification: .SFUserAccountManagerDidChangeUser, object: nil) { _ in
            return true
        }

        let newUserCredentials = OAuthCredentials()
        newUserCredentials.userId = String(format: kUserIdFormatString, 2)
        newUserCredentials.organizationId = user.credentials.organizationId
        newUserCredentials.instanceUrl = URL(string: "http://a.new.url")
        newUserCredentials.communityId = "NEW_COMMUNITY_ID"
        let coordinator = SFOAuthCoordinator(credentials: newUserCredentials)
        let credentials: [String: Any] = [kSFOAuthAccessToken: "new_access_token_1"]
        coordinator.updateCredentials(credentials)
        if let creds = coordinator.credentials {
            _ = uam.applyCredentials(creds)
        }
        waitForExpectations(timeout: 10.0, handler: nil)
    }

    // MARK: - Helper methods

    private func createNewUser(_ index: UInt) -> UserAccount {
        guard let credentials = OAuthCredentials.credentials(identifier: "identifier-\(index)", clientId: "fakeClientIdForTesting", encrypted: true) else {
            fatalError("Failed to create credentials")
        }
        credentials.accessToken = nil
        credentials.refreshToken = nil
        credentials.instanceUrl = nil
        let user = UserAccount(credentials: credentials)
        let userId = String(format: kUserIdFormatString, index)
        let orgId = String(format: kOrgIdFormatString, index)
        credentials.communityId = orgId
        credentials.userId = userId
        user.credentials.identityUrl = URL(string: "https://login.salesforce.com/id/\(orgId)/\(userId)")
        let success = uam?.upsert(user) ?? false
        XCTAssertTrue(success, "User Should have been created for Notifications Test")
        return user
    }

    private func deleteUserAndVerify(_ user: UserAccount) {
        let identity = user.accountIdentity
        let success = uam?.delete(user) ?? false
        XCTAssertTrue(success, "Error deleting account with User ID '\(identity.userId ?? "")' and Org ID '\(identity.orgId ?? "")'")
        let inMemoryAccount = uam?.userAccount(for: identity)
        XCTAssertNil(inMemoryAccount, "deleteUser should have removed user account with User ID '\(identity.userId ?? "")' and OrgID '\(identity.orgId ?? "")' from the list of users.")
    }
}
