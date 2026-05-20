/*
 Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.

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

private let kUserIdFormatString = "005R0000000Dsl%lu"
private let kOrgIdFormatString = "00D000000000062EA%lu"

class TestUserAccountManagerPersisterDelegate: NSObject, UserAccountManagerDelegate {

    var willSwitchOrigUserAccount: UserAccount?
    var willSwitchNewUserAccount: UserAccount?
    var didSwitchOrigUserAccount: UserAccount?
    var didSwitchNewUserAccount: UserAccount?

    override init() {
        super.init()
        UserAccountManager.shared.addDelegate(self)
    }

    deinit {
        UserAccountManager.shared.removeDelegate(self)
    }

    func userAccountManager(accountManager: UserAccountManager, willSwitchFrom currentUser: UserAccount, to newUser: UserAccount?) {
        willSwitchOrigUserAccount = currentUser
        willSwitchNewUserAccount = newUser
    }

    func userAccountManager(accountManager: UserAccountManager, didSwitchFrom previousUser: UserAccount, to currentUser: UserAccount?) {
        didSwitchOrigUserAccount = previousUser
        didSwitchNewUserAccount = currentUser
    }
}

class SFUserAccountManagerPersisterTests: XCTestCase {

    private static var origAccount: UserAccount?
    private var uam: UserAccountManager = UserAccountManager.shared
    private var origAccountPersister: (any SFUserAccountPersister)?

    override func setUp() {
        super.setUp()
        SFUserAccountManagerPersisterTests.origAccount = UserAccountManager.shared.currentUserAccount
        uam = UserAccountManager.shared
        origAccountPersister = uam.accountPersister
        uam.setAccountPersisterInternal(SFUserAccountPersisterEphemeral())
    }

    override func tearDown() {
        UserAccountManager.shared.setAccountPersisterInternal(origAccountPersister)
        super.tearDown()
        UserAccountManager.shared.currentUserAccount = SFUserAccountManagerPersisterTests.origAccount
        UserAccountManager.shared.setCurrentUserInternal(SFUserAccountManagerPersisterTests.origAccount)
    }

    func testAccountIdentityUpdateFromCredentialsUpdate() {
        let accounts = createAndVerifyUserAccounts(1)
        let user = accounts[0]

        XCTAssertEqual(user.accountIdentity.userId, user.credentials.userId, "Account identity UserID and credentials User ID should be equal.")
        XCTAssertEqual(user.accountIdentity.orgId, user.credentials.organizationId, "Account identity UserID and credentials User ID should be equal.")

        // Changed credentials IDs.
        user.credentials.userId = "NewUserId"
        user.credentials.organizationId = "NewOrgId"
        XCTAssertEqual(user.accountIdentity.userId, "NewUserId", "Updated User ID in credentials not reflected in account identity.")
        XCTAssertEqual(user.accountIdentity.orgId, "NewOrgId", "Updated Org ID in credentials not reflected in account identity.")

        // Swap out credentials entirely.
        let newCredentialsIdentifier = "\(user.credentials.identifier ?? "")_1"
        guard let newCreds = OAuthCredentials.credentials(identifier: newCredentialsIdentifier, clientId: user.credentials.clientId, encrypted: true) else {
            XCTFail("Failed to create new credentials")
            return
        }
        newCreds.userId = "NewCredsUserId"
        newCreds.organizationId = "NewCredsOrgId"
        user.credentials = newCreds
        XCTAssertEqual(user.accountIdentity.userId, "NewCredsUserId", "User ID in new credentials not reflected in account identity.")
        XCTAssertEqual(user.accountIdentity.orgId, "NewCredsOrgId", "Org ID in new credentials not reflected in account identity.")
    }

    func testSingleAccount() {
        uam.clearAllAccountState()
        // Ensure we start with a clean state
        XCTAssertTrue((uam.userIdentities()?.count ?? 0) == 0, "There should be no accounts")

        // Create a single user
        let accounts = createAndVerifyUserAccounts(1)
        let user = accounts[0]
        XCTAssertTrue((uam.userIdentities()?.count ?? 0) == 1, "There should be 1 account")

        let userId = String(format: kUserIdFormatString, 0)
        XCTAssertEqual(uam.userIdentities()?[0].userId, userId, "User ID doesn't match after reload")
        deleteUserAndVerify(user)
        XCTAssertTrue((uam.userIdentities()?.count ?? 0) == 0, "There should be 0 accounts after delete")
    }

    func testMultipleAccounts() {
        // Ensure we start with a clean state
        uam.clearAllAccountState()
        XCTAssertEqual(uam.userIdentities()?.count ?? 0, 0, "There should be no accounts")

        // Create 10 users
        createAndVerifyUserAccounts(10)
        XCTAssertEqual(uam.userAccounts()?.count ?? 0, 10, "There should be 10 accounts")

        // Now make sure each account has a different access token to ensure
        // they are not overlapping in the keychain.
        var allTokens = Set<String>()
        guard let allIdentities = uam.userIdentities() else {
            XCTFail("No identities found")
            return
        }
        for index in 0..<10 {
            guard let user = uam.userAccount(for: allIdentities[index]) else { continue }
            if let token = user.credentials.accessToken {
                allTokens.insert(token)
            }
        }
        XCTAssertEqual(allTokens.count, 10, "Should not contain overlapping tokens")

        // Remove each account and verify that its user folder is gone.
        for index in 0..<10 {
            let orgId = String(format: kOrgIdFormatString, index)
            let userId = String(format: kUserIdFormatString, index)

            let accountIdentity = UserAccountIdentity(userId: userId, orgId: orgId)
            let userAccount = uam.userAccount(for: accountIdentity)
            XCTAssertNotNil(userAccount, "User account with User ID '\(userId)' and Org ID '\(orgId)' should exist.")
            if let userAccount = userAccount {
                deleteUserAndVerify(userAccount)
            }
        }
        XCTAssertEqual(uam.userAccounts()?.count ?? 0, 0, "There should be 0 accounts after delete")
    }

    func testSwitchToUser() {
        let accounts = createAndVerifyUserAccounts(2)
        let origUser = accounts[0]
        let newUser = accounts[1]
        UserAccountManager.shared.setCurrentUserInternal(origUser)
        let acctDelegate = TestUserAccountManagerPersisterDelegate()
        uam.switchToUserAccount(newUser)
        XCTAssertEqual(acctDelegate.willSwitchOrigUserAccount, origUser, "origUser is not equal.")
        XCTAssertEqual(acctDelegate.willSwitchNewUserAccount, newUser, "New user should be the same as the argument to switchToUser.")
        XCTAssertEqual(acctDelegate.didSwitchOrigUserAccount, origUser, "origUser is not equal.")
        XCTAssertEqual(acctDelegate.didSwitchNewUserAccount, newUser, "New user should be the same as the argument to switchToUser.")
        XCTAssertEqual(uam.currentUserAccount, newUser, "The current user should be set to newUser.")
        deleteUserAndVerify(origUser)
        deleteUserAndVerify(newUser)
        XCTAssertEqual(uam.userAccounts()?.count ?? 0, 0, "There should be 0 accounts after delete")
    }

    func testSwitchToSameUser() {
        let newUser = createAndVerifyUserAccounts(1)[0]
        UserAccountManager.shared.setCurrentUserInternal(newUser)
        let acctDelegate = TestUserAccountManagerPersisterDelegate()
        uam.switchToUserAccount(newUser)
        XCTAssertNil(acctDelegate.willSwitchOrigUserAccount, "No switchToUser action should be taken for same accounts.")
        XCTAssertNil(acctDelegate.willSwitchNewUserAccount, "No switchToUser action should be taken for same accounts.")
        XCTAssertNil(acctDelegate.didSwitchOrigUserAccount, "No switchToUser action should be taken for same accounts.")
        XCTAssertNil(acctDelegate.didSwitchNewUserAccount, "No switchToUser action should be taken for same accounts.")

        // Should create a new user with the same identity (but won't persist it).
        let newUserSameIdentity = createNewUser(withIndex: 0)
        uam.switchToUserAccount(newUserSameIdentity)
        XCTAssertNil(acctDelegate.willSwitchOrigUserAccount, "No switchToUser action should be taken for accounts with same identity.")
        XCTAssertNil(acctDelegate.willSwitchNewUserAccount, "No switchToUser action should be taken for accounts with same identity.")
        XCTAssertNil(acctDelegate.didSwitchOrigUserAccount, "No switchToUser action should be taken for accounts with same identity.")
        XCTAssertNil(acctDelegate.didSwitchNewUserAccount, "No switchToUser action should be taken for accounts with same identity.")

        deleteUserAndVerify(newUser)
        XCTAssertEqual(uam.userAccounts()?.count ?? 0, 0, "There should be 0 accounts after delete")
    }

    // MARK: - Helper methods

    @discardableResult
    private func createAndVerifyUserAccounts(_ numAccounts: Int) -> [UserAccount] {
        XCTAssertTrue(numAccounts > 0, "You must create at least one account.")
        var accounts = [UserAccount]()
        for index in 0..<numAccounts {
            let user = createNewUser(withIndex: index)
            user.credentials.accessToken = "accesstoken-\(index)"
            XCTAssertNotNil(user.credentials, "User credentials shouldn't be nil")
            XCTAssertTrue(uam.upsert(user), "Should be able to create user account")
            // Note: we always use index 0 because of the way the allUserIds are sorted out
            let userAccount = uam.userAccount(for: user.accountIdentity)
            XCTAssertEqual(userAccount?.accountIdentity.userId, String(format: kUserIdFormatString, index), "User ID doesn't match")
            XCTAssertEqual(userAccount?.accountIdentity.orgId, String(format: kOrgIdFormatString, index), "Org ID doesn't match")
            accounts.append(user)
        }
        return accounts
    }

    private func createNewUser(withIndex index: Int) -> UserAccount {
        XCTAssertTrue(index < 10, "Supports only index up to 9")
        guard let credentials = OAuthCredentials.credentials(identifier: "identifier-\(index)", clientId: UserAccountManager.shared.oauthClientID, encrypted: true) else {
            fatalError("Failed to create credentials")
        }
        let user = UserAccount(credentials: credentials)
        let userId = String(format: kUserIdFormatString, index)
        let orgId = String(format: kOrgIdFormatString, index)
        user.credentials.identityUrl = URL(string: "https://login.salesforce.com/id/\(orgId)/\(userId)")
        return user
    }

    private func deleteUserAndVerify(_ user: UserAccount) {
        let identity = user.accountIdentity
        let success = uam.delete(user)
        XCTAssertTrue(success, "Error deleting account with User ID '\(identity.userId ?? "")' and Org ID '\(identity.orgId ?? "")'")
        let inMemoryAccount = uam.userAccount(for: identity)
        XCTAssertNil(inMemoryAccount, "deleteUser should have removed user account with User ID '\(identity.userId ?? "")' and OrgID '\(identity.orgId ?? "")' from the list of users.")
    }
}
