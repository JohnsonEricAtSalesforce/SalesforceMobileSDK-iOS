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

private let kUserIdFormatString = "005R0000000Dsl%lu"
private let kOrgIdFormatString = "00D000000000062EA%lu"

private class TestUserAccountManagerDelegateSwift: NSObject, UserAccountManagerDelegate {
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

    func userAccountManager(accountManager: UserAccountManager, willSwitchFrom currentUserAccount: UserAccount, to anotherUserAccount: UserAccount?) {
        willSwitchOrigUserAccount = currentUserAccount
        willSwitchNewUserAccount = anotherUserAccount
    }

    func userAccountManager(accountManager: UserAccountManager, didSwitchFrom previousUserAccount: UserAccount, to currentUserAccount: UserAccount?) {
        didSwitchOrigUserAccount = previousUserAccount
        didSwitchNewUserAccount = currentUserAccount
    }
}

final class SFUserAccountManagerTestsSwift: XCTestCase {

    private var uam: UserAccountManager!
    private var authViewHandler: AuthViewHandler!
    private var config: SalesforceLoginViewControllerConfig!
    private var origLoginHost: String?
    private var origAccount: UserAccount?

    override class func setUp() {
        SFSDKLogoutBlocker.block()
        super.setUp()
    }

    override func setUp() {
        super.setUp()
        // Delete the content of the global library directory
        if let globalLibraryDirectory = SFDirectoryManager.sharedManager().globalDirectory(ofType: .libraryDirectory, components: nil) {
            try? FileManager.default.removeItem(atPath: globalLibraryDirectory)
        }
        uam = UserAccountManager.shared
        origLoginHost = uam.loginHost
        origAccount = UserAccountManager.shared.currentUserAccount
        // Ensure the user account manager doesn't contain any account
        if let userAccounts = UserAccountManager.shared.userAccounts() {
            for account in userAccounts {
                if account !== origAccount {
                    try? uam.delete(account)
                }
            }
        }
        uam.clearAllAccountState()
        UserAccountManager.shared.currentUserAccount = nil
        authViewHandler = UserAccountManager.shared.authViewHandler
        config = uam.loginViewControllerConfig
    }

    override func tearDown() {
        UserAccountManager.shared.authViewHandler = authViewHandler
        uam.loginViewControllerConfig = config
        uam.loginHost = origLoginHost
        UserAccountManager.shared.currentUserAccount = origAccount
        super.tearDown()
    }

    func testAccountIdentityEquality() {
        let accountIdentityMatrix: [String: [SFUserAccountIdentity]] = [
            "MatchGroup1": [
                SFUserAccountIdentity(userId: "UserID1", orgId: "OrgID1"),
                SFUserAccountIdentity(userId: "UserID1", orgId: "OrgID1")
            ],
            "MatchGroup2": [
                SFUserAccountIdentity(userId: "UserID2", orgId: "OrgID2"),
                SFUserAccountIdentity(userId: "UserID2", orgId: "OrgID2")
            ]
        ]

        let keys = Array(accountIdentityMatrix.keys)
        for i in 0..<keys.count {
            // Equality
            let equalIdentitiesArray = accountIdentityMatrix[keys[i]]!
            for j in 0..<equalIdentitiesArray.count {
                let obj1 = equalIdentitiesArray[j]
                for k in 0..<equalIdentitiesArray.count {
                    let obj2 = equalIdentitiesArray[k]
                    XCTAssertEqual(obj1, obj2, "Account identity '\(obj1)' and '\(obj2)' should be equal")
                }
            }

            // Inequality
            for j in 0..<equalIdentitiesArray.count {
                let obj1 = equalIdentitiesArray[j]
                for k in 0..<keys.count {
                    if k == i { continue }
                    let unequalIdentitiesArray = accountIdentityMatrix[keys[k]]!
                    for l in 0..<unequalIdentitiesArray.count {
                        let obj2 = unequalIdentitiesArray[l]
                        XCTAssertNotEqual(obj1, obj2, "Account identity '\(obj1)' and '\(obj2)' should NOT be equal")
                    }
                }
            }
        }
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
        let newCreds = OAuthCredentials(identifier: newCredentialsIdentifier, clientId: user.credentials.clientId ?? "", encrypted: true)
        newCreds.userId = "NewCredsUserId"
        newCreds.organizationId = "NewCredsOrgId"
        user.credentials = newCreds
        XCTAssertEqual(user.accountIdentity.userId, "NewCredsUserId", "User ID in new credentials not reflected in account identity.")
        XCTAssertEqual(user.accountIdentity.orgId, "NewCredsOrgId", "Org ID in new credentials not reflected in account identity.")
    }

    func testSingleAccount() {
        // Ensure we start with a clean state
        let identities = uam.userIdentities() ?? []
        XCTAssertEqual(identities.count, 0, "There should be no accounts")

        // Create a single user
        let accounts = createAndVerifyUserAccounts(1)
        let user = accounts[0]
        // Check if the UserAccount.plist is stored at the right location
        var expectedLocation = SFDirectoryManager.sharedManager().directory(forOrg: user.credentials.organizationId, user: user.credentials.userId, community: nil, type: .libraryDirectory, components: nil) ?? ""
        expectedLocation = (expectedLocation as NSString).appendingPathComponent("UserAccount.plist")
        XCTAssertEqual(expectedLocation, DefaultUserAccountPersister.userAccountPlistFile(for: user), "Mismatching user account paths")
        let fm = FileManager.default
        XCTAssertTrue(fm.fileExists(atPath: expectedLocation), "Unable to find new UserAccount.plist")

        let userId = String(format: kUserIdFormatString, 0)
        let currentIdentities = uam.userIdentities() ?? []
        XCTAssertEqual(currentIdentities[0].userId, userId, "User ID doesn't match after reload")
        deleteUserAndVerify(user, userDir: expectedLocation)
    }

    func testMultipleAccounts() {
        // Ensure we start with a clean state
        let identities = uam.userIdentities() ?? []
        XCTAssertEqual(identities.count, 0, "There should be no accounts")

        // Create 10 users
        createAndVerifyUserAccounts(10)
        let fm = FileManager.default

        // Ensure all directories have been correctly created
        for index in 0..<10 {
            let orgId = String(format: kOrgIdFormatString, index)
            let userId = String(format: kUserIdFormatString, index)
            var location = SFDirectoryManager.sharedManager().directory(forOrg: orgId, user: userId, community: nil, type: .libraryDirectory, components: nil) ?? ""
            location = (location as NSString).appendingPathComponent("UserAccount.plist")
            XCTAssertTrue(fm.fileExists(atPath: location), "Unable to find new UserAccount.plist at \(location)")
        }

        // Remove and verify that allUserAccounts property implicitly loads the accounts from disk.
        uam.clearAllAccountState()
        try? uam.loadAccounts()
        // Now make sure each account has a different access token
        var allTokens = Set<String>()
        let allIdentities = uam.userIdentities() ?? []
        for index in 0..<10 {
            let user = uam.userAccount(for: allIdentities[index])
            if let token = user?.credentials.accessToken {
                allTokens.insert(token)
            }
        }
        XCTAssertEqual(allTokens.count, 10, "Should not contain overlapping tokens")

        // Remove each account and verify that its user folder is gone.
        for index in 0..<10 {
            let orgId = String(format: kOrgIdFormatString, index)
            let userId = String(format: kUserIdFormatString, index)
            let location = SFDirectoryManager.sharedManager().directory(forOrg: orgId, user: userId, community: nil, type: .libraryDirectory, components: nil) ?? ""
            let accountIdentity = SFUserAccountIdentity(userId: userId, orgId: orgId)
            let userAccount = uam.userAccount(for: accountIdentity)
            XCTAssertNotNil(userAccount, "User account with User ID '\(userId)' and Org ID '\(orgId)' should exist.")
            XCTAssertTrue(fm.fileExists(atPath: location), "User directory for User ID '\(userId)' and Org ID '\(orgId)' should exist.")
            deleteUserAndVerify(userAccount!, userDir: location)
        }
        let remainingAccounts = uam.userAccounts() ?? []
        XCTAssertEqual(remainingAccounts.count, 0, "There should be 0 accounts after delete")
    }

    func testSwitchToUser() {
        let accounts = createAndVerifyUserAccounts(2)
        let origUser = accounts[0]
        let newUser = accounts[1]
        UserAccountManager.shared.currentUserAccount = origUser
        let acctDelegate = TestUserAccountManagerDelegateSwift()
        uam.switchToUserAccount(newUser)
        XCTAssertTrue(acctDelegate.willSwitchOrigUserAccount === origUser, "origUser is not equal.")
        XCTAssertTrue(acctDelegate.willSwitchNewUserAccount === newUser, "New user should be the same as the argument to switchToUser.")
        XCTAssertTrue(acctDelegate.didSwitchOrigUserAccount === origUser, "origUser is not equal.")
        XCTAssertTrue(acctDelegate.didSwitchNewUserAccount === newUser, "New user should be the same as the argument to switchToUser.")
        XCTAssertTrue(uam.currentUserAccount === newUser, "The current user should be set to newUser.")
    }

    func testSwitchToNewUserNoCurrentUser() {
        createAndVerifyUserAccounts(1)
        UserAccountManager.shared.currentUserAccount = nil
        let switchExpectation = expectation(description: "testSwitchToNewUserWithCompletionErrorCase")
        var capturedError: Error? = nil
        uam.switchToNewUser { error, account in
            capturedError = error
            switchExpectation.fulfill()
        }
        waitForExpectations(timeout: 10.0, handler: nil)
        XCTAssertNotNil(capturedError, "switchToNewUserWithCompletion should not be called without a current user")
    }

    func testLoginHostForSwitchToUser() {
        let accounts = createAndVerifyUserAccounts(2)
        let origUser = accounts[0]
        uam.loginHost = "my.prev.domain"
        let newUser = accounts[1]
        let testDomain = "my.test.domain"
        newUser.credentials.setValue(testDomain, forKey: "domain")
        UserAccountManager.shared.currentUserAccount = origUser
        let acctDelegate = TestUserAccountManagerDelegateSwift()
        XCTAssertNotEqual(uam.loginHost, testDomain, "The domains should be different before the test.")
        XCTAssertEqual(newUser.credentials.domain, testDomain, "User domain should have been set in the credentials.")

        uam.switchToUserAccount(newUser)
        XCTAssertTrue(acctDelegate.didSwitchOrigUserAccount === origUser, "The user switched from is not the same user as expected.")
        XCTAssertTrue(acctDelegate.didSwitchNewUserAccount === newUser, "The user switched to is not the same user as expected.")
        XCTAssertTrue(uam.currentUserAccount === newUser, "The current user should be set to the new user.")
        XCTAssertEqual(newUser.credentials.domain, testDomain, "Switch user should not have changed users domain in credentials.")
        XCTAssertEqual(uam.loginHost, newUser.credentials.domain, "Switch user should set current login host to users domain.")
    }

    func testUserAccountManagerPersistentProperties() {
        let oldAdditionalOAuthParameterKeys = UserAccountManager.shared.additionalOAuthParameterKeys
        let addlKeys = ["A", "__B", "123", ""]
        UserAccountManager.shared.additionalOAuthParameterKeys = addlKeys
        XCTAssertNotNil(UserAccountManager.shared.additionalOAuthParameterKeys, "SFUserAccountManager additionalOAuthParameterKeys should not be nil")
        XCTAssertEqual(UserAccountManager.shared.additionalOAuthParameterKeys?.count, addlKeys.count, "SFUserAccountManager additionalOAuthParameterKeys count should match")
        UserAccountManager.shared.additionalOAuthParameterKeys = oldAdditionalOAuthParameterKeys

        let oldAdditionalTokenRefreshParams = UserAccountManager.shared.additionalTokenRefreshParameters
        let addlRefreshParams: [String: Any] = ["A": "A", "B": "B", "C": "C"]
        UserAccountManager.shared.additionalTokenRefreshParameters = addlRefreshParams
        XCTAssertNotNil(UserAccountManager.shared.additionalTokenRefreshParameters, "SFUserAccountManager additionalTokenRefreshParameters should not be nil")
        XCTAssertEqual(UserAccountManager.shared.additionalTokenRefreshParameters?.count, addlRefreshParams.count, "SFUserAccountManager additionalTokenRefreshParameters count should match")
        UserAccountManager.shared.additionalTokenRefreshParameters = oldAdditionalTokenRefreshParams

        let oldLoginHost = UserAccountManager.shared.loginHost
        let newLoginHost = "https://sample.test"
        UserAccountManager.shared.loginHost = newLoginHost
        XCTAssertEqual(UserAccountManager.shared.loginHost, newLoginHost, "SFUserAccountManager loginHost should be set correctly")
        UserAccountManager.shared.loginHost = oldLoginHost
        XCTAssertEqual(UserAccountManager.shared.loginHost, oldLoginHost, "SFUserAccountManager loginHost should be set back correctly")

        let oldOauthCompletionUrl = UserAccountManager.shared.oauthCompletionURL
        let newOauthCompletionUrl = "new://new.url"
        UserAccountManager.shared.oauthCompletionURL = newOauthCompletionUrl
        XCTAssertEqual(UserAccountManager.shared.oauthCompletionURL, newOauthCompletionUrl, "SFUserAccountManager oauthCompletionURL should be set correctly")
        UserAccountManager.shared.oauthCompletionURL = oldOauthCompletionUrl
        XCTAssertEqual(UserAccountManager.shared.oauthCompletionURL, oldOauthCompletionUrl, "SFUserAccountManager oauthCompletionURL should be set back correctly")

        let oldOauthClientId = UserAccountManager.shared.oauthClientID
        let newOauthClientId = "NEW_OAUTH_CLIENT_ID"
        UserAccountManager.shared.oauthClientID = newOauthClientId
        XCTAssertEqual(UserAccountManager.shared.oauthClientID, newOauthClientId, "SFUserAccountManager oAuthClientId should be set correctly")
        UserAccountManager.shared.oauthClientID = oldOauthClientId
        XCTAssertEqual(UserAccountManager.shared.oauthClientID, oldOauthClientId, "SFUserAccountManager oAuthClientId should be set back correctly")

        let oldBrandLoginPath = UserAccountManager.shared.brandLoginPath
        let newBrandLoginPath = "NEW_BRAND"
        UserAccountManager.shared.brandLoginPath = newBrandLoginPath
        XCTAssertEqual(UserAccountManager.shared.brandLoginPath, newBrandLoginPath, "SFUserAccountManager brandLoginPath should be set correctly")
        UserAccountManager.shared.brandLoginPath = oldBrandLoginPath
        XCTAssertEqual(UserAccountManager.shared.brandLoginPath, oldBrandLoginPath, "SFUserAccountManager brandLoginPath should be set back correctly")
    }

    func testLogin() {
        let credentials = populateAuthCredentialsFromConfigFile(for: type(of: self))
        let refreshExpectation = expectation(description: "refresh")
        var user: UserAccount? = nil
        _ = UserAccountManager.shared.refresh(credentials: credentials) { result in
            switch result {
            case .success(let (userAccount, _)):
                user = userAccount
            case .failure:
                break
            }
            refreshExpectation.fulfill()
        }
        waitForExpectations(timeout: 20)
        _ = user
    }

    func testEntityId() {
        let userId = "ABCDE12345ABCDE".sfsdk_entityId18!
        let identity = SFUserAccountIdentity(userId: userId, orgId: "ABCDE12345ABCDE")
        XCTAssertNotNil(identity)
        XCTAssertEqual(userId.count, 18, "EntityId18 should be 18 characters")
        XCTAssertNotNil(identity.userId, "userId should not be nil")
        XCTAssertNotNil(identity.orgId, "orgId should not be nil")
        XCTAssertEqual(identity.userId.count, 18, "userId should be set to EntityId 18 format")
    }

    func testAuthHandler() {
        let origAuthViewHandler = UserAccountManager.shared.authViewHandler
        let exp = expectation(description: "testAuthHandler")
        let authViewHandler = AuthViewHandler(displayBlock: { holder in
            exp.fulfill()
        }, dismissBlock: {
            exp.fulfill()
        })
        UserAccountManager.shared.authViewHandler = authViewHandler
        XCTAssertNotNil(authViewHandler)
        XCTAssertNotNil(authViewHandler.authViewDismissBlock)
        XCTAssertNotNil(authViewHandler.authViewDisplayBlock)
        XCTAssertTrue(UserAccountManager.shared.authViewHandler === authViewHandler)
        let request = UserAccountManager.shared.defaultAuthRequest()
        request.oauthClientId = "DUMMY_ID"
        request.oauthCompletionUrl = "DUMMY_URL"
        request.loginHost = "login.salesforce.com"

        let session = AuthSession(with: request, credentials: nil)
        let coordinator = SFOAuthCoordinator(authSession: session)
        coordinator.delegate = UserAccountManager.shared
        coordinator.beginWebViewFlow()

        waitForExpectations(timeout: 20)

        UserAccountManager.shared.authViewHandler = origAuthViewHandler
    }

    func testLoginViewControllerCustomizations() {
        let config = SalesforceLoginViewControllerConfig()

        // test defaults
        XCTAssertNotNil(config)
        XCTAssertNil(config.navigationBarFont)
        XCTAssertNotNil(config.navigationBarColor)
        XCTAssertTrue(config.showNavbar)
        XCTAssertTrue(config.showSettingsIcon)

        config.navigationBarColor = .red
        config.navigationBarFont = UIFont.systemFont(ofSize: 10.0)
        config.showNavbar = false
        config.showSettingsIcon = false
        var success = false
        let exp = expectation(description: "testConfig")

        let authViewHandler = AuthViewHandler(displayBlock: { holder in
            success = UserAccountManager.shared.loginViewControllerConfig === holder.loginController?.config
            exp.fulfill()
        }, dismissBlock: {
            exp.fulfill()
        })
        UserAccountManager.shared.authViewHandler = authViewHandler

        XCTAssertTrue(config.navigationBarColor === UIColor.red, "SFSDKLoginViewController config nav bar color should have changed")
        XCTAssertTrue(config.navigationBarFont === UIFont.systemFont(ofSize: 10.0), "SFSDKLoginViewController config nav bar font should have changed")
        XCTAssertFalse(config.showNavbar, "SFSDKLoginViewController nav bar should have been disabled")
        XCTAssertFalse(config.showSettingsIcon, "SFSDKLoginViewController nav bar settings icon should have been disabled")
        let request = UserAccountManager.shared.defaultAuthRequest()
        request.oauthClientId = "DUMMY_ID"
        request.oauthCompletionUrl = "DUMMY_URL"
        request.loginHost = "login.salesforce.com"

        let session = AuthSession(with: request, credentials: nil)
        let coordinator = SFOAuthCoordinator(authSession: session)
        coordinator.delegate = UserAccountManager.shared
        coordinator.beginWebViewFlow()

        waitForExpectations(timeout: 20)
        XCTAssertTrue(success, "SFSDKLoginViewController config should have changed")
    }

    // MARK: - Helper methods

    @discardableResult
    private func createAndVerifyUserAccounts(_ numAccounts: Int) -> [UserAccount] {
        XCTAssertTrue(numAccounts > 0, "You must create at least one account.")
        var accounts = [UserAccount]()
        for index in 0..<numAccounts {
            let user = createNewUserWithIndex(UInt(index))
            user.credentials.accessToken = "accesstoken-\(index)"
            XCTAssertNotNil(user.credentials, "User credentials shouldn't be nil")
            do {
                try UserAccountManager.shared.upsert(user)
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

    private func createNewUserWithIndex(_ index: UInt) -> UserAccount {
        XCTAssertTrue(index < 10, "Supports only index up to 9")
        let credentials = OAuthCredentials(identifier: "identifier-\(index)", clientId: "fakeClientIdForTesting", encrypted: true)
        let user = UserAccount(credentials: credentials)
        let userId = String(format: kUserIdFormatString, index)
        let orgId = String(format: kOrgIdFormatString, index)
        user.credentials.identityUrl = URL(string: "https://login.salesforce.com/id/\(orgId)/\(userId)")
        return user
    }

    private func deleteUserAndVerify(_ user: UserAccount, userDir: String) {
        let identity = user.accountIdentity
        var deleteAccountError: Error?
        do {
            try uam.delete(user)
        } catch {
            deleteAccountError = error
        }
        XCTAssertNil(deleteAccountError, "Error deleting account with User ID '\(identity.userId ?? "")' and Org ID '\(identity.orgId ?? "")': \(String(describing: deleteAccountError))")
        let fm = FileManager.default
        XCTAssertFalse(fm.fileExists(atPath: userDir), "User directory for User ID '\(identity.userId ?? "")' and Org ID '\(identity.orgId ?? "")' should be removed.")
        let inMemoryAccount = uam.userAccount(for: identity)
        XCTAssertNil(inMemoryAccount, "deleteUser should have removed user account with User ID '\(identity.userId ?? "")' and OrgID '\(identity.orgId ?? "")' from the list of users.")
    }

    private func populateAuthCredentialsFromConfigFile(for testClass: AnyClass) -> OAuthCredentials {
        let tokenPath = Bundle(for: testClass).path(forResource: "test_credentials", ofType: "json")!
        let tokenJson = FileManager.default.contents(atPath: tokenPath)!
        let jsonResponse = try! JSONSerialization.jsonObject(with: tokenJson) as! [String: Any]
        let credsData = SFSDKTestCredentialsData(dict: jsonResponse)

        UserAccountManager.shared.currentUserAccount = nil
        UserAccountManager.shared.oauthClientID = credsData.clientId
        UserAccountManager.shared.oauthCompletionURL = credsData.redirectUri
        UserAccountManager.shared.scopes = Set(["web", "api"])
        UserAccountManager.shared.loginHost = credsData.loginHost

        let credentials = TestSetupUtils.newClientCredentials()
        credentials.instanceUrl = URL(string: credsData.instanceUrl)
        credentials.identityUrl = URL(string: credsData.identityUrl)
        let communityUrlString = credsData.communityUrl
        if !communityUrlString.isEmpty {
            credentials.communityUrl = URL(string: communityUrlString)
        }
        credentials.accessToken = credsData.accessToken
        credentials.refreshToken = credsData.refreshToken
        return credentials
    }
}
