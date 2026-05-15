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

private class TestUserAccountManagerPersisterDelegateSwift: NSObject, UserAccountManagerDelegate {
    var willSwitchOrigUserAccount: SFUserAccount?
    var willSwitchNewUserAccount: SFUserAccount?
    var didSwitchOrigUserAccount: SFUserAccount?
    var didSwitchNewUserAccount: SFUserAccount?

    override init() {
        super.init()
        SFUserAccountManager.shared.addDelegate(self)
    }

    deinit {
        SFUserAccountManager.shared.removeDelegate(self)
    }

    func userAccountManager(_ userAccountManager: SFUserAccountManager, willSwitch fromUser: SFUserAccount?, toUser: SFUserAccount?) {
        willSwitchOrigUserAccount = fromUser
        willSwitchNewUserAccount = toUser
    }

    func userAccountManager(_ userAccountManager: SFUserAccountManager, didSwitch fromUser: SFUserAccount?, toUser: SFUserAccount?) {
        didSwitchOrigUserAccount = fromUser
        didSwitchNewUserAccount = toUser
    }
}

final class SFUserAccountManagerPersisterTestsSwift: XCTestCase {

    private var origAccountPersister: SFUserAccountPersister!
    private var uam: SFUserAccountManager!
    private static var origAccount: SFUserAccount?

    override func setUp() {
        super.setUp()
        SFUserAccountManagerPersisterTestsSwift.origAccount = SFUserAccountManager.shared.currentUserAccount
        uam = SFUserAccountManager.shared
        origAccountPersister = uam.accountPersister
        uam.accountPersister = SFUserAccountPersisterEphemeral()
    }

    override func tearDown() {
        SFUserAccountManager.shared.accountPersister = origAccountPersister
        super.tearDown()
        SFUserAccountManager.shared.currentUserAccount = SFUserAccountManagerPersisterTestsSwift.origAccount
        SFUserAccountManager.shared.currentUserAccount = SFUserAccountManagerPersisterTestsSwift.origAccount
    }

    func testAccountIdentityUpdateFromCredentialsUpdate() {
        let accounts = createAndVerifyUserAccounts(1)
        let user = accounts[0]

        XCTAssertEqual(user.accountIdentity.userId, user.credentials.userId, "Account identity UserID and credentials User ID should be equal.")
        XCTAssertEqual(user.accountIdentity.orgId, user.credentials.organizationId, "Account identity OrgID and credentials Org ID should be equal.")

        // Changed credentials IDs.
        user.credentials.userId = "NewUserId"
        user.credentials.organizationId = "NewOrgId"
        XCTAssertEqual(user.accountIdentity.userId, "NewUserId", "Updated User ID in credentials not reflected in account identity.")
        XCTAssertEqual(user.accountIdentity.orgId, "NewOrgId", "Updated Org ID in credentials not reflected in account identity.")

        // Swap out credentials entirely.
        let newCredentialsIdentifier = "\(user.credentials.identifier)_1"
        let newCreds = SFOAuthCredentials(identifier: newCredentialsIdentifier, clientId: user.credentials.clientId!, encrypted: true)
        newCreds.userId = "NewCredsUserId"
        newCreds.organizationId = "NewCredsOrgId"
        user.credentials = newCreds
        XCTAssertEqual(user.accountIdentity.userId, "NewCredsUserId", "User ID in new credentials not reflected in account identity.")
        XCTAssertEqual(user.accountIdentity.orgId, "NewCredsOrgId", "Org ID in new credentials not reflected in account identity.")
    }

    func testSingleAccount() {
        uam.clearAllAccountState()
        // Ensure we start with a clean state
        XCTAssertEqual((uam.userIdentities() ?? []).count, 0, "There should be no accounts")

        // Create a single user
        let accounts = createAndVerifyUserAccounts(1)
        let user = accounts[0]
        XCTAssertEqual((uam.userIdentities() ?? []).count, 1, "There should be 1 account")

        let userId = String(format: kUserIdFormatString, 0)
        XCTAssertEqual(((uam.userIdentities() ?? [])[0] as! SFUserAccountIdentity).userId, userId, "User ID doesn't match after reload")
        deleteUserAndVerify(user)
        XCTAssertEqual((uam.userIdentities() ?? []).count, 0, "There should be 0 accounts after delete")
    }

    func testMultipleAccounts() {
        // Ensure we start with a clean state
        uam.clearAllAccountState()
        XCTAssertEqual((uam.userIdentities() ?? []).count, 0, "There should be no accounts")

        // Create 10 users
        createAndVerifyUserAccounts(10)
        XCTAssertEqual((uam.userAccounts() ?? []).count, 10, "There should be 10 accounts")

        // Now make sure each account has a different access token
        var allTokens = Set<String>()
        let allIdentities = (uam.userIdentities() ?? []) as! [SFUserAccountIdentity]
        for index in 0..<10 {
            let user = uam.userAccount(for: allIdentities[index])
            if let token = user?.credentials.accessToken {
                allTokens.insert(token)
            }
        }
        XCTAssertEqual(allTokens.count, 10, "Should not contain overlapping tokens")

        // Remove each account and verify
        for index in 0..<10 {
            let orgId = String(format: kOrgIdFormatString, index)
            let userId = String(format: kUserIdFormatString, index)
            let accountIdentity = SFUserAccountIdentity(userId: userId, orgId: orgId)
            let userAccount = uam.userAccount(for: accountIdentity)
            XCTAssertNotNil(userAccount, "User account with User ID '\(userId)' and Org ID '\(orgId)' should exist.")
            deleteUserAndVerify(userAccount!)
        }
        XCTAssertEqual((uam.userAccounts() ?? []).count, 0, "There should be 0 accounts after delete")
    }

    func testSwitchToUser() {
        let accounts = createAndVerifyUserAccounts(2)
        let origUser = accounts[0]
        let newUser = accounts[1]
        SFUserAccountManager.shared.currentUserAccount = origUser
        let acctDelegate = TestUserAccountManagerPersisterDelegateSwift()
        uam.switchToUserAccount( newUser)
        XCTAssertTrue(acctDelegate.willSwitchOrigUserAccount === origUser, "origUser is not equal.")
        XCTAssertTrue(acctDelegate.willSwitchNewUserAccount === newUser, "New user should be the same as the argument to switchToUser.")
        XCTAssertTrue(acctDelegate.didSwitchOrigUserAccount === origUser, "origUser is not equal.")
        XCTAssertTrue(acctDelegate.didSwitchNewUserAccount === newUser, "New user should be the same as the argument to switchToUser.")
        XCTAssertTrue(uam.currentUserAccount === newUser, "The current user should be set to newUser.")
        deleteUserAndVerify(origUser)
        deleteUserAndVerify(newUser)
        XCTAssertEqual((uam.userAccounts() ?? []).count, 0, "There should be 0 accounts after delete")
    }

    func testSwitchToSameUser() {
        let newUser = createAndVerifyUserAccounts(1)[0]
        SFUserAccountManager.shared.currentUserAccount = newUser
        let acctDelegate = TestUserAccountManagerPersisterDelegateSwift()
        uam.switchToUserAccount( newUser)
        XCTAssertNil(acctDelegate.willSwitchOrigUserAccount, "No switchToUser action should be taken for same accounts.")
        XCTAssertNil(acctDelegate.willSwitchNewUserAccount, "No switchToUser action should be taken for same accounts.")
        XCTAssertNil(acctDelegate.didSwitchOrigUserAccount, "No switchToUser action should be taken for same accounts.")
        XCTAssertNil(acctDelegate.didSwitchNewUserAccount, "No switchToUser action should be taken for same accounts.")

        // Should create a new user with the same identity (but won't persist it).
        let newUserSameIdentity = createNewUserWithIndex(0)
        uam.switchToUserAccount( newUserSameIdentity)
        XCTAssertNil(acctDelegate.willSwitchOrigUserAccount, "No switchToUser action should be taken for accounts with same identity.")
        XCTAssertNil(acctDelegate.willSwitchNewUserAccount, "No switchToUser action should be taken for accounts with same identity.")
        XCTAssertNil(acctDelegate.didSwitchOrigUserAccount, "No switchToUser action should be taken for accounts with same identity.")
        XCTAssertNil(acctDelegate.didSwitchNewUserAccount, "No switchToUser action should be taken for accounts with same identity.")

        deleteUserAndVerify(newUser)
        XCTAssertEqual((uam.userAccounts() ?? []).count, 0, "There should be 0 accounts after delete")
    }

    // MARK: - Helper methods

    @discardableResult
    private func createAndVerifyUserAccounts(_ numAccounts: Int) -> [SFUserAccount] {
        XCTAssertTrue(numAccounts > 0, "You must create at least one account.")
        var accounts = [SFUserAccount]()
        for index in 0..<numAccounts {
            let user = createNewUserWithIndex(UInt(index))
            user.credentials.accessToken = "accesstoken-\(index)"
            XCTAssertNotNil(user.credentials, "User credentials shouldn't be nil")
            do {
                try SFUserAccountManager.shared.upsert(user)
            } catch {
                XCTFail("Should be able to create user account: \(error)")
            }
            let userAccount = uam.userAccount(for: user.accountIdentity)
            XCTAssertEqual(userAccount?.accountIdentity.userId, String(format: kUserIdFormatString, index), "User ID doesn't match")
            XCTAssertEqual(userAccount?.accountIdentity.orgId, String(format: kOrgIdFormatString, index), "Org ID doesn't match")
            accounts.append(user)
        }
        return accounts
    }

    private func createNewUserWithIndex(_ index: UInt) -> SFUserAccount {
        XCTAssertTrue(index < 10, "Supports only index up to 9")
        let credentials = SFOAuthCredentials(identifier: "identifier-\(index)", clientId: SFUserAccountManager.shared.oauthClientID ?? "", encrypted: true)
        let user = SFUserAccount(credentials: credentials)
        let userId = String(format: kUserIdFormatString, index)
        let orgId = String(format: kOrgIdFormatString, index)
        user.credentials.identityUrl = URL(string: "https://login.salesforce.com/id/\(orgId)/\(userId)")
        return user
    }

    private func deleteUserAndVerify(_ user: SFUserAccount) {
        let identity = user.accountIdentity
        var deleteAccountError: Error?
        do {
            try uam.delete(user)
        } catch {
            deleteAccountError = error
        }
        XCTAssertNil(deleteAccountError, "Error deleting account with User ID '\(identity.userId ?? "")' and Org ID '\(identity.orgId ?? "")': \(String(describing: deleteAccountError))")
        let inMemoryAccount = uam.userAccount(for: identity)
        XCTAssertNil(inMemoryAccount, "deleteUser should have removed user account with User ID '\(identity.userId ?? "")' and OrgID '\(identity.orgId ?? "")' from the list of users.")
    }
}
