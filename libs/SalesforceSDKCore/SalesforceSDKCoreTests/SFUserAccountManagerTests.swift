/*
 SFUserAccountManagerTests.swift
 SalesforceSDKCoreTests

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
import SalesforceSDKCommon

private let kUserIdFormatString = "005R0000000Dsl%lu"
private let kOrgIdFormatString = "00D000000000062EA%lu"

// MARK: - TestUserAccountManagerDelegate

private class TestUserAccountManagerDelegate: NSObject, UserAccountManagerDelegate {
    var willSwitchOrigUserAccount: UserAccount?
    var willSwitchNewUserAccount: UserAccount?
    var didSwitchOrigUserAccount: UserAccount?
    var didSwitchNewUserAccount: UserAccount?
    var willLoginCredentials: OAuthCredentials?
    var didLoginUserAccount: UserAccount?
    var error: NSError?

    override init() {
        super.init()
        UserAccountManager.shared.addDelegate(self)
    }

    deinit {
        UserAccountManager.shared.removeDelegate(self)
    }

    func userAccountManager(accountManager: UserAccountManager, didFailAuthenticationWith error: Error, info: SFOAuthInfo) -> Bool {
        self.error = error as NSError
        return false
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

// MARK: - SFUserAccountManagerTests

class SFUserAccountManagerTests: XCTestCase {

    private var uam: UserAccountManager {
        UserAccountManager.shared
    }
    private var authViewHandler: SFSDKAuthViewHandler?
    private var config: SalesforceLoginViewControllerConfig?
    private var origLoginHost: String?
    private var origAccount: UserAccount?

    override class func setUp() {
        SFSDKLogoutBlocker.block()
        super.setUp()
    }

    override func setUp() {
        super.setUp()
        if let globalLibraryDirectory = SFDirectoryManager.sharedManager.globalDirectory(ofType: .libraryDirectory, components: nil) {
            try? FileManager.default.removeItem(atPath: globalLibraryDirectory)
        }

        origLoginHost = uam.loginHost
        origAccount = UserAccountManager.shared.currentUserAccount

        let userAccounts = UserAccountManager.shared.userAccounts() ?? []
        for account in userAccounts {
            if account != origAccount {
                _ = uam.delete(account)
            }
        }
        uam.clearAllAccountState()
        UserAccountManager.shared.setCurrentUserInternal(nil)
        authViewHandler = UserAccountManager.shared.authViewHandler
        config = uam.loginViewControllerConfig
    }

    override func tearDown() {
        if let handler = authViewHandler {
            UserAccountManager.shared.authViewHandler = handler
        }
        if let cfg = config {
            uam.loginViewControllerConfig = cfg
        }
        uam.loginHost = origLoginHost ?? ""
        UserAccountManager.shared.currentUserAccount = origAccount
        UserAccountManager.shared.setCurrentUserInternal(origAccount)
        super.tearDown()
    }

    // MARK: - Tests

    func testAccountIdentityEquality() {
        let accountIdentityMatrix: [String: [UserAccountIdentity]] = [
            "MatchGroup1": [
                UserAccountIdentity(userId: "UserID1", orgId: "OrgID1"),
                UserAccountIdentity(userId: "UserID1", orgId: "OrgID1")
            ],
            "MatchGroup2": [
                UserAccountIdentity(userId: "UserID2", orgId: "OrgID2"),
                UserAccountIdentity(userId: "UserID2", orgId: "OrgID2")
            ]
        ]

        let keys = Array(accountIdentityMatrix.keys)
        for i in 0..<keys.count {
            let equalIdentitiesArray = accountIdentityMatrix[keys[i]] ?? []
            for j in 0..<equalIdentitiesArray.count {
                let obj1 = equalIdentitiesArray[j]
                for k in 0..<equalIdentitiesArray.count {
                    let obj2 = equalIdentitiesArray[k]
                    XCTAssertEqual(obj1, obj2, "Account identity '\(obj1)' and '\(obj2)' should be equal")
                }
            }

            for j in 0..<equalIdentitiesArray.count {
                let obj1 = equalIdentitiesArray[j]
                for k in 0..<keys.count {
                    if k == i { continue }
                    let unequalIdentitiesArray = accountIdentityMatrix[keys[k]] ?? []
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
        XCTAssertEqual(user.accountIdentity.userId, user.credentials.userId)
        XCTAssertEqual(user.accountIdentity.orgId, user.credentials.organizationId)

        user.credentials.userId = "NewUserId"
        user.credentials.organizationId = "NewOrgId"
        XCTAssertEqual(user.accountIdentity.userId, "NewUserId")
        XCTAssertEqual(user.accountIdentity.orgId, "NewOrgId")

        let newCredentialsIdentifier = "\(user.credentials.identifier)_1"
        guard let newCreds = OAuthCredentials.credentials(identifier: newCredentialsIdentifier, clientId: user.credentials.clientId, encrypted: true) else {
            XCTFail("Failed to create new credentials")
            return
        }
        newCreds.userId = "NewCredsUserId"
        newCreds.organizationId = "NewCredsOrgId"
        user.credentials = newCreds
        XCTAssertEqual(user.accountIdentity.userId, "NewCredsUserId")
        XCTAssertEqual(user.accountIdentity.orgId, "NewCredsOrgId")
    }

    func testSingleAccount() {
        XCTAssertEqual(uam.userIdentities()?.count ?? 0, 0, "There should be no accounts")

        let accounts = createAndVerifyUserAccounts(1)
        let user = accounts[0]

        guard let dirPath = SFDirectoryManager.sharedManager.directory(
            forOrg: user.credentials.organizationId,
            user: user.credentials.userId,
            community: nil,
            type: .libraryDirectory,
            components: nil
        ) else {
            XCTFail("Could not get directory path")
            return
        }
        let expectedLocation = dirPath.appending("/UserAccount.plist")

        XCTAssertEqual(expectedLocation, SFDefaultUserAccountPersister.userAccountPlistFile(for: user), "Mismatching user account paths")
        XCTAssertTrue(FileManager.default.fileExists(atPath: expectedLocation), "Unable to find new UserAccount.plist")

        let userId = String(format: kUserIdFormatString, 0)
        XCTAssertEqual(uam.userIdentities()?[0].userId, userId, "User ID doesn't match after reload")
        deleteUserAndVerify(user, userDir: expectedLocation)
    }

    func testMultipleAccounts() {
        XCTAssertEqual(uam.userIdentities()?.count ?? 0, 0, "There should be no accounts")

        let accounts = createAndVerifyUserAccounts(10)
        let fm = FileManager.default

        for index in 0..<10 {
            let orgId = String(format: kOrgIdFormatString, index)
            let userId = String(format: kUserIdFormatString, index)
            guard let dirPath = SFDirectoryManager.sharedManager.directory(forOrg: orgId, user: userId, community: nil, type: .libraryDirectory, components: nil) else {
                XCTFail("Could not get directory path for index \(index)")
                continue
            }
            let location = dirPath + "/UserAccount.plist"
            XCTAssertTrue(fm.fileExists(atPath: location), "Unable to find new UserAccount.plist at \(location)")
        }

        uam.clearAllAccountState()
        let loadResult = uam.loadAllUserAccounts()
        XCTAssertTrue(loadResult, "Accounts should have been loaded")

        var allTokens = Set<String>()
        let allIdentities = uam.userIdentities() ?? []
        for index in 0..<10 {
            if let user = uam.userAccount(for: allIdentities[index]),
               let token = user.credentials.accessToken {
                allTokens.insert(token)
            }
        }
        XCTAssertEqual(allTokens.count, 10, "Should not contain overlapping tokens")

        for index in 0..<10 {
            let orgId = String(format: kOrgIdFormatString, index)
            let userId = String(format: kUserIdFormatString, index)
            guard let location = SFDirectoryManager.sharedManager.directory(forOrg: orgId, user: userId, community: nil, type: .libraryDirectory, components: nil) else {
                XCTFail("Could not get directory path for index \(index)")
                continue
            }
            let accountIdentity = UserAccountIdentity(userId: userId, orgId: orgId)
            let userAccount = uam.userAccount(for: accountIdentity)
            XCTAssertNotNil(userAccount, "User account with User ID '\(userId)' and Org ID '\(orgId)' should exist.")
            XCTAssertTrue(fm.fileExists(atPath: location), "User directory should exist.")
            if let userAccount = userAccount {
                deleteUserAndVerify(userAccount, userDir: location)
            }
        }
        XCTAssertEqual(uam.userAccounts()?.count ?? 0, 0, "There should be 0 accounts after delete")
    }

    func testSwitchToUser() {
        let accounts = createAndVerifyUserAccounts(2)
        let origUser = accounts[0]
        let newUser = accounts[1]
        UserAccountManager.shared.setCurrentUserInternal(origUser)
        let acctDelegate = TestUserAccountManagerDelegate()
        uam.switchToUserAccount( newUser)
        XCTAssertEqual(acctDelegate.willSwitchOrigUserAccount, origUser)
        XCTAssertEqual(acctDelegate.willSwitchNewUserAccount, newUser)
        XCTAssertEqual(acctDelegate.didSwitchOrigUserAccount, origUser)
        XCTAssertEqual(acctDelegate.didSwitchNewUserAccount, newUser)
        XCTAssertEqual(uam.currentUserAccount, newUser)
    }

    func testSwitchToNewUserNoCurrentUser() {
        _ = createAndVerifyUserAccounts(1)
        UserAccountManager.shared.setCurrentUserInternal(nil)
        let switchExpectation = expectation(description: "testSwitchToNewUserWithCompletionErrorCase")
        var switchError: Error?
        uam.switchToNewUser { error, _ in
            switchError = error
            switchExpectation.fulfill()
        }
        waitForExpectations(timeout: 10.0)
        XCTAssertNotNil(switchError, "switchToNewUserWithCompletion should not be called without a current user")
    }

    func testLoginHostForSwitchToUser() {
        UserAccountManager.shared.nativeLoginEnabled = false
        let accounts = createAndVerifyUserAccounts(2)
        let origUser = accounts[0]
        uam.loginHost = "my.prev.domain"
        let newUser = accounts[1]
        let testDomain = "my.test.domain"
        newUser.credentials.domain = testDomain
        UserAccountManager.shared.setCurrentUserInternal(origUser)
        let acctDelegate = TestUserAccountManagerDelegate()
        XCTAssertNotEqual(uam.loginHost, testDomain)
        XCTAssertEqual(newUser.credentials.domain, testDomain)

        uam.switchToUserAccount( newUser)
        XCTAssertEqual(acctDelegate.didSwitchOrigUserAccount, origUser)
        XCTAssertEqual(acctDelegate.didSwitchNewUserAccount, newUser)
        XCTAssertEqual(uam.currentUserAccount, newUser)
        XCTAssertEqual(newUser.credentials.domain, testDomain)
        XCTAssertEqual(uam.loginHost, newUser.credentials.domain)
    }

    func testUserAccountManagerPersistentProperties() {
        let oldAdditionalOAuthParameterKeys = UserAccountManager.shared.additionalOAuthParameterKeys
        let addlKeys = ["A", "__B", "123", ""]
        UserAccountManager.shared.additionalOAuthParameterKeys = addlKeys
        XCTAssertNotNil(UserAccountManager.shared.additionalOAuthParameterKeys)
        XCTAssertEqual(UserAccountManager.shared.additionalOAuthParameterKeys.count, addlKeys.count)
        UserAccountManager.shared.additionalOAuthParameterKeys = oldAdditionalOAuthParameterKeys

        let oldAdditionalTokenRefreshParams = UserAccountManager.shared.additionalTokenRefreshParameters
        let addlRefreshParams: [String: String] = ["A": "A", "B": "B", "C": "C"]
        UserAccountManager.shared.additionalTokenRefreshParameters = addlRefreshParams
        XCTAssertNotNil(UserAccountManager.shared.additionalTokenRefreshParameters)
        XCTAssertEqual(UserAccountManager.shared.additionalTokenRefreshParameters.count, addlRefreshParams.count)
        UserAccountManager.shared.additionalTokenRefreshParameters = oldAdditionalTokenRefreshParams

        let oldLoginHost = UserAccountManager.shared.loginHost
        let newLoginHost = "https://sample.test"
        UserAccountManager.shared.loginHost = newLoginHost
        XCTAssertEqual(UserAccountManager.shared.loginHost, newLoginHost)
        UserAccountManager.shared.loginHost = oldLoginHost

        let oldOauthCompletionUrl = UserAccountManager.shared.oauthCompletionURL
        let newOauthCompletionUrl = "new://new.url"
        UserAccountManager.shared.oauthCompletionURL = newOauthCompletionUrl
        XCTAssertEqual(UserAccountManager.shared.oauthCompletionURL, newOauthCompletionUrl)
        UserAccountManager.shared.oauthCompletionURL = oldOauthCompletionUrl

        let oldOauthClientId = UserAccountManager.shared.oauthClientID
        let newOauthClientId = "NEW_OAUTH_CLIENT_ID"
        UserAccountManager.shared.oauthClientID = newOauthClientId
        XCTAssertEqual(UserAccountManager.shared.oauthClientID, newOauthClientId)
        UserAccountManager.shared.oauthClientID = oldOauthClientId

        let oldBrandLoginPath = UserAccountManager.shared.brandLoginPath
        let newBrandLoginPath = "NEW_BRAND"
        UserAccountManager.shared.brandLoginPath = newBrandLoginPath
        XCTAssertEqual(UserAccountManager.shared.brandLoginPath, newBrandLoginPath)
        UserAccountManager.shared.brandLoginPath = oldBrandLoginPath
    }

    func testLogin() {
        let credentials = populateAuthCredentials(from: type(of: self))
        let refreshExpectation = expectation(description: "refresh")
        UserAccountManager.shared.refreshCredentials(credentials) { _, _ in
            refreshExpectation.fulfill()
        } failure: { _, _ in
        }
        waitForExpectations(timeout: 20)
    }

    func testEntityId() {
        guard let userId = ("ABCDE12345ABCDE" as NSString).sfsdk_entityId18() else {
            XCTFail("sfsdk_entityId18 returned nil")
            return
        }
        let identity = UserAccountIdentity(userId: userId, orgId: "ABCDE12345ABCDE")
        XCTAssertNotNil(identity)
        XCTAssertEqual(userId.count, 18, "EntityId18 should be 18 characters")
        XCTAssertNotNil(identity.userId)
        XCTAssertNotNil(identity.orgId)
        XCTAssertEqual(identity.userId.count, 18, "userId should be set to EntityId 18 format")
    }

    func testAuthHandler() {
        let origAuthViewHandler = UserAccountManager.shared.authViewHandler
        let handlerExpectation = expectation(description: "testAuthHandler")
        let authViewHandler = SFSDKAuthViewHandler(displayBlock: { _ in
            handlerExpectation.fulfill()
        }, dismissBlock: {
            handlerExpectation.fulfill()
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

        let session = SFSDKAuthSession(with: request, credentials: nil)
        let coordinator = SFOAuthCoordinator(authSession: session)
        coordinator.delegate = UserAccountManager.shared
        coordinator.beginWebViewFlow()

        waitForExpectations(timeout: 20)
        UserAccountManager.shared.authViewHandler = origAuthViewHandler
    }

    func testLoginViewControllerCustomizations() {
        let loginConfig = SalesforceLoginViewControllerConfig()
        XCTAssertNotNil(loginConfig)
        XCTAssertNil(loginConfig.navBarFont)
        XCTAssertNotNil(loginConfig.navBarColor)
        XCTAssertTrue(loginConfig.showNavbar)
        XCTAssertTrue(loginConfig.showSettingsIcon)

        loginConfig.navBarColor = .red
        loginConfig.navBarFont = UIFont.systemFont(ofSize: 10.0)
        loginConfig.showNavbar = false
        loginConfig.showSettingsIcon = false

        var success = false
        let configExpectation = expectation(description: "testConfig")

        let authViewHandler = SFSDKAuthViewHandler(displayBlock: { holder in
            success = (UserAccountManager.shared.loginViewControllerConfig === holder.loginController.config)
            configExpectation.fulfill()
        }, dismissBlock: {
            configExpectation.fulfill()
        })
        UserAccountManager.shared.authViewHandler = authViewHandler

        XCTAssertEqual(loginConfig.navBarColor, .red)
        XCTAssertEqual(loginConfig.navBarFont, UIFont.systemFont(ofSize: 10.0))
        XCTAssertFalse(loginConfig.showNavbar)
        XCTAssertFalse(loginConfig.showSettingsIcon)

        let request = UserAccountManager.shared.defaultAuthRequest()
        request.oauthClientId = "DUMMY_ID"
        request.oauthCompletionUrl = "DUMMY_URL"
        request.loginHost = "login.salesforce.com"

        let session = SFSDKAuthSession(with: request, credentials: nil)
        let coordinator = SFOAuthCoordinator(authSession: session)
        coordinator.delegate = UserAccountManager.shared

        // Invoke the delegate directly — no WKWebView needed since this test only verifies
        // that loginViewControllerConfig propagates correctly to the presented controller.
        UserAccountManager.shared.oauthCoordinator(coordinator, didBeginAuthenticationWithView: coordinator.view)

        waitForExpectations(timeout: 20)
        XCTAssertTrue(success, "SFSDKLoginViewController config should have changed")
    }

    func testUserAccountEncoding() {
        let archiver = NSKeyedArchiver(requiringSecureCoding: true)

        guard let credentials = OAuthCredentials.credentials(identifier: "identifier-0", clientId: "fakeClientIdForTesting", encrypted: true) else {
            XCTFail("Failed to create credentials")
            return
        }
        credentials.identityUrl = URL(string: "https://test.salesforce.com/id/00DS0000000IDdtWAH/005S0000004y9JkCAF")

        let userIn = UserAccount(credentials: credentials)
        userIn.accessScopes = Set(["scope1", "scope2"])
        userIn.idData = sampleIdentityData()
        userIn.accessRestrictions = .chatter
        let customData: [String: Any] = [
            "string": "myString",
            "number": 5,
            "date": Date.now,
            "null": NSNull(),
            "array": ["one", "two"]
        ]
        userIn.setCustomDataObject(customData as NSDictionary, forKey: "allTheThings" as NSCopying)

        archiver.encode(userIn, forKey: "account")
        archiver.finishEncoding()
        let data = archiver.encodedData

        guard let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data) else {
            XCTFail("Could not create unarchiver")
            return
        }
        unarchiver.requiresSecureCoding = true
        let userOut = unarchiver.decodeObject(of: UserAccount.self, forKey: "account")

        XCTAssertNotNil(userOut, "couldn't unarchive user account")
        XCTAssertNotNil(userOut?.credentials, "couldn't unarchive credentials")
        XCTAssertNotNil(userOut?.idData, "couldn't unarchive idData")
        XCTAssertEqual(userIn.customDataObject(forKey: "allTheThings") as? NSDictionary, userOut?.customDataObject(forKey: "allTheThings") as? NSDictionary)
        XCTAssertEqual(userIn.accessScopes?.count, userOut?.accessScopes?.count)
        XCTAssertEqual(userIn.accessRestrictions, userOut?.accessRestrictions)
    }

    func test_givenPersistedFeatureFlags_whenEncodeAndDecode_thenFlagsRoundtrip() {
        guard let credentials = OAuthCredentials.credentials(identifier: "identifier-ff-roundtrip", clientId: "fakeClientIdForTesting", encrypted: false) else {
            XCTFail("Failed to create credentials")
            return
        }
        credentials.identityUrl = URL(string: "https://test.salesforce.com/id/00DS0000000IDdtWAH/005S0000004y9JkCAF")
        let userIn = UserAccount(credentials: credentials)
        userIn.persistedFeatureFlags = Set(["BW", "QR"])

        let archiver = NSKeyedArchiver(requiringSecureCoding: true)
        archiver.encode(userIn, forKey: "account")
        archiver.finishEncoding()
        let data = archiver.encodedData

        guard let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data) else {
            XCTFail("Could not create unarchiver")
            return
        }
        unarchiver.requiresSecureCoding = true
        let userOut = unarchiver.decodeObject(of: UserAccount.self, forKey: "account")

        XCTAssertNotNil(userOut, "Should unarchive successfully")
        XCTAssertEqual(userOut?.persistedFeatureFlags?.count, 2, "Should decode both feature flags")
        XCTAssertTrue(userOut?.persistedFeatureFlags?.contains("BW") ?? false, "BW flag should roundtrip")
        XCTAssertTrue(userOut?.persistedFeatureFlags?.contains("QR") ?? false, "QR flag should roundtrip")
    }

    func testMigrateRefreshAuthRequest() {
        let testConsumerKey = "TestConsumerKey123"
        let testRedirectURI = "testapp://oauth/callback"
        let configDict: [String: Any] = [
            "remoteAccessConsumerKey": testConsumerKey,
            "oauthRedirectURI": testRedirectURI,
            "oauthScopes": ["api", "refresh_token"]
        ]
        guard let appConfig = BootConfig(dict: configDict as NSDictionary) else {
            XCTFail("Failed to create BootConfig")
            return
        }

        let request = uam.migrateRefreshAuthRequest(appConfig)
        XCTAssertNotNil(request)
        XCTAssertEqual(request.oauthClientId, testConsumerKey)
        XCTAssertEqual(request.oauthCompletionUrl, testRedirectURI)
        XCTAssertEqual(request.loginHost, uam.loginHost)
        XCTAssertEqual(request.additionalOAuthParameterKeys, uam.additionalOAuthParameterKeys)
        XCTAssertNotNil(request.scene)
    }

    func testMigrateRefreshToken() {
        let testUser = createNewUser(index: 0)
        testUser.credentials.refreshToken = "oldRefreshToken123"
        uam.setCurrentUserInternal(testUser)

        let testConsumerKey = "NewConsumerKey456"
        let testRedirectURI = "newapp://oauth/callback"
        let configDict: [String: Any] = [
            "remoteAccessConsumerKey": testConsumerKey,
            "oauthRedirectURI": testRedirectURI,
            "oauthScopes": ["api", "refresh_token"]
        ]
        guard let appConfig = BootConfig(dict: configDict as NSDictionary) else {
            XCTFail("Failed to create BootConfig")
            return
        }

        var successCallbackInvoked = false
        var failureCallbackInvoked = false
        var capturedAuthInfo: SFOAuthInfo?
        var capturedUserAccount: UserAccount?
        var capturedError: NSError?

        uam.migrateRefreshToken(for: testUser, newAppConfig: appConfig, success: { authInfo, userAccount in
            successCallbackInvoked = true
            capturedAuthInfo = authInfo
            capturedUserAccount = userAccount
        }, failure: { authInfo, error in
            failureCallbackInvoked = true
            capturedError = error as NSError?
        })

        let allKeys = uam.authSessions.allKeys
        XCTAssertTrue(allKeys.count > 0, "Auth session should have been created")
        guard let sceneId = allKeys.first as? String,
              let authSession = uam.authSessions[sceneId] as? SFSDKAuthSession else {
            XCTFail("Could not get auth session")
            return
        }

        XCTAssertNotNil(authSession)
        XCTAssertTrue(authSession.isAuthenticating)
        XCTAssertNotNil(authSession.authSuccessCallback)
        XCTAssertNotNil(authSession.authFailureCallback)
        XCTAssertEqual(authSession.oauthRequest.oauthClientId, testConsumerKey)
        XCTAssertEqual(authSession.oauthRequest.oauthCompletionUrl, testRedirectURI)
        XCTAssertTrue(authSession.oauthCoordinator.delegate === uam)

        let testAuthInfo = SFOAuthInfo(authType: .refresh)
        let newUserAccount = createNewUser(index: 1)
        newUserAccount.credentials.refreshToken = "oldRefreshToken123"

        authSession.authSuccessCallback?(testAuthInfo, newUserAccount)
        XCTAssertTrue(successCallbackInvoked)
        XCTAssertTrue(capturedAuthInfo === testAuthInfo)
        XCTAssertTrue(capturedUserAccount === newUserAccount)
        XCTAssertFalse(failureCallbackInvoked)

        successCallbackInvoked = false
        capturedAuthInfo = nil
        capturedUserAccount = nil

        uam.authSessions.removeObject(forKey: sceneId)

        uam.migrateRefreshToken(for: testUser, newAppConfig: appConfig, success: { authInfo, userAccount in
            successCallbackInvoked = true
            capturedAuthInfo = authInfo
            capturedUserAccount = userAccount
        }, failure: { authInfo, error in
            failureCallbackInvoked = true
            capturedError = error as NSError?
        })

        guard let newSceneId = uam.authSessions.allKeys.first as? String,
              let newAuthSession = uam.authSessions[newSceneId] as? SFSDKAuthSession else {
            XCTFail("Could not get new auth session")
            return
        }

        let newUserAccountWithDifferentToken = createNewUser(index: 2)
        newUserAccountWithDifferentToken.credentials.refreshToken = "newRefreshToken789"

        newAuthSession.authSuccessCallback?(testAuthInfo, newUserAccountWithDifferentToken)
        XCTAssertTrue(successCallbackInvoked)
        XCTAssertTrue(capturedAuthInfo === testAuthInfo)
        XCTAssertTrue(capturedUserAccount === newUserAccountWithDifferentToken)

        failureCallbackInvoked = false
        successCallbackInvoked = false

        let testError = NSError(domain: "TestErrorDomain", code: 123, userInfo: ["message": "Test error"])
        newAuthSession.authFailureCallback?(testAuthInfo, testError)

        XCTAssertTrue(failureCallbackInvoked)
        XCTAssertEqual(capturedError, testError)
        XCTAssertFalse(successCallbackInvoked)

        uam.authSessions.removeObject(forKey: newSceneId)
    }

    func testNotifyLoginCompletion_PostsMigrateRefreshTokenNotification() {
        let testUser = createNewUser(index: 0)
        let authInfo = SFOAuthInfo(authType: .refreshTokenMigration)

        var notificationReceived = false
        var receivedUserInfo: [AnyHashable: Any]?

        let observer = NotificationCenter.default.addObserver(forName: .sfNotificationUserDidMigrateRefreshToken, object: uam, queue: nil) { notification in
            notificationReceived = true
            receivedUserInfo = notification.userInfo
        }

        uam.notifyLoginCompletion(testUser, authInfo: authInfo)

        XCTAssertTrue(notificationReceived, "Should have received .sfNotificationUserDidMigrateRefreshToken notification")
        XCTAssertNotNil(receivedUserInfo)
        XCTAssertTrue(receivedUserInfo?[kSFNotificationUserInfoAccountKey] as AnyObject === testUser)
        XCTAssertTrue(receivedUserInfo?[kSFNotificationUserInfoAuthTypeKey] as AnyObject === authInfo)

        NotificationCenter.default.removeObserver(observer)
    }

    // MARK: - Helper Methods

    private func createAndVerifyUserAccounts(_ numAccounts: Int) -> [UserAccount] {
        XCTAssertTrue(numAccounts > 0, "You must create at least one account.")
        var accounts = [UserAccount]()
        for index in 0..<numAccounts {
            let user = createNewUser(index: index)
            user.credentials.accessToken = "accesstoken-\(index)"
            XCTAssertNotNil(user.credentials)
            let success = UserAccountManager.shared.upsert(user)
            let error: NSError? = success ? nil : NSError(domain: "test", code: -1)
            XCTAssertNil(error, "Should be able to create user account")
            let userAccount = uam.userAccount(for: user.accountIdentity)
            XCTAssertEqual(userAccount?.accountIdentity.userId, String(format: kUserIdFormatString, index))
            XCTAssertEqual(userAccount?.accountIdentity.orgId, String(format: kOrgIdFormatString, index))
            accounts.append(user)
        }
        return accounts
    }

    private func createNewUser(index: Int) -> UserAccount {
        XCTAssertTrue(index < 10, "Supports only index up to 9")
        guard let credentials = OAuthCredentials.credentials(identifier: "identifier-\(index)", clientId: "fakeClientIdForTesting", encrypted: true) else {
            fatalError("Failed to create credentials for test user \(index)")
        }
        let user = UserAccount(credentials: credentials)
        let userId = String(format: kUserIdFormatString, index)
        let orgId = String(format: kOrgIdFormatString, index)
        user.credentials.identityUrl = URL(string: "https://login.salesforce.com/id/\(orgId)/\(userId)")
        return user
    }

    private func deleteUserAndVerify(_ user: UserAccount, userDir: String) {
        let identity = user.accountIdentity
        let deleteSuccess = uam.delete(user)
        XCTAssertTrue(deleteSuccess, "Error deleting account with User ID '\(identity.userId)' and Org ID '\(identity.orgId)'")
        XCTAssertFalse(FileManager.default.fileExists(atPath: userDir), "User directory should be removed.")
        let inMemoryAccount = uam.userAccount(for: identity)
        XCTAssertNil(inMemoryAccount, "deleteUser should have removed user account from the list of users.")
    }

    private func sampleIdentityData() -> SFIdentityData {
        let sampleIdDataDict: [String: Any] = [
            "mobile_phone": "+1 4155551234",
            "first_name": "Test",
            "mobile_phone_verified": true,
            "active": true,
            "utcOffset": -28800000,
            "username": "testuser@fake.salesforce.org",
            "last_modified_date": "2013-04-19T22:12:04.000+0000",
            "id": "https://test.salesforce.com/id/00DS0000000IDdtWAH/005S0000004y9JkCAF",
            "locale": "en_US",
            "urls": [
                "users": "https://cs1.salesforce.com/services/data/v{version}/chatter/users",
                "search": "https://cs1.salesforce.com/services/data/v{version}/search/",
                "metadata": "https://cs1.salesforce.com/services/Soap/m/{version}/00DS0000000IDdt",
                "query": "https://cs1.salesforce.com/services/data/v{version}/query/",
                "enterprise": "https://cs1.salesforce.com/services/Soap/c/{version}/00DS0000000IDdt",
                "profile": "https://cs1.salesforce.com/005S0000004y9JkCAF",
                "sobjects": "https://cs1.salesforce.com/services/data/v{version}/sobjects/",
                "groups": "https://cs1.salesforce.com/services/data/v{version}/chatter/groups",
                "rest": "https://cs1.salesforce.com/services/data/v{version}/",
                "feed_items": "https://cs1.salesforce.com/services/data/v{version}/chatter/feed-items",
                "recent": "https://cs1.salesforce.com/services/data/v{version}/recent/",
                "feeds": "https://cs1.salesforce.com/services/data/v{version}/chatter/feeds",
                "partner": "https://cs1.salesforce.com/services/Soap/u/{version}/00DS0000000IDdt"
            ],
            "addr_zip": "94105",
            "addr_country": "US",
            "asserted_user": true,
            "email_verified": true,
            "nick_name": "testuser1.3664094337872896E12",
            "user_id": "005S0000004y9JkCAF",
            "is_app_installed": true,
            "user_type": "STANDARD",
            "addr_street": "123 Test User Ln",
            "timezone": "America/Los_Angeles",
            "mobile_policy": [
                "pin_length": "4",
                "screen_lock": "10"
            ],
            "organization_id": "00DS0000000IDdtWAH",
            "addr_city": "Testville",
            "addr_state": "CA",
            "language": "en_US",
            "last_name": "User",
            "display_name": "Test User",
            "photos": [
                "thumbnail": "https://c.cs1.content.force.com/profilephoto/729S00000009ZdF/T",
                "picture": "https://c.cs1.content.force.com/profilephoto/729S00000009ZdF/F"
            ],
            "email": "testuser@salesforce.nonexistentemail",
            "custom_attributes": [
                "TestAttribute1": "TestVal1",
                "TestAttribute2": "TestVal2"
            ],
            "custom_permissions": [
                "CustomPerm1": "CustomVal1",
                "CustomPerm2": "CustomVal2"
            ],
            "status": [
                "body": NSNull(),
                "created_date": NSNull()
            ]
        ]
        return SFIdentityData(jsonDict: sampleIdDataDict)
    }

    private func populateAuthCredentials(from testClass: AnyClass) -> OAuthCredentials {
        guard let tokenPath = Bundle(for: testClass).path(forResource: "test_credentials", ofType: "json") else {
            fatalError("Test config file not found!")
        }
        let fm = FileManager.default
        guard let tokenJson = fm.contents(atPath: tokenPath),
              let jsonResponse = try? JSONSerialization.jsonObject(with: tokenJson) as? [String: Any] else {
            fatalError("Error parsing JSON from config file")
        }
        let credsData = SFSDKTestCredentialsData(dict: jsonResponse)

        precondition(credsData.refreshToken != "__INSERT_TOKEN_HERE__",
                     "You need to obtain credentials for your test org and replace test_credentials.json")

        UserAccountManager.shared.setCurrentUserInternal(nil)
        UserAccountManager.shared.oauthClientID = credsData.clientId
        UserAccountManager.shared.oauthCompletionURL = credsData.redirectUri
        UserAccountManager.shared.scopes = Set(["web", "api"])
        UserAccountManager.shared.loginHost = credsData.loginHost

        let credentials = TestSetupUtils.newClientCredentials()
        credentials.instanceUrl = URL(string: credsData.instanceUrl)
        credentials.identityUrl = URL(string: credsData.identityUrl)
        let communityUrlString = credsData.communityUrl
        if communityUrlString.count > 0 {
            credentials.communityUrl = URL(string: communityUrlString)
        }
        credentials.accessToken = credsData.accessToken
        credentials.refreshToken = credsData.refreshToken
        return credentials
    }
}
