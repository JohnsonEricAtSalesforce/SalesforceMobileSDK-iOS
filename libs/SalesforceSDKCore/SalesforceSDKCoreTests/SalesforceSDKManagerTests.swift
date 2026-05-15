/*
 Copyright (c) 2014-present, salesforce.com, inc. All rights reserved.

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

private let kTestAppName = "OverridenAppName"

final class SalesforceSDKManagerTests: XCTestCase {

    private var origConnectedAppId: String?
    private var origConnectedAppCallbackUri: String?
    private var origAuthScopes: Set<String>?
    private var origAuthenticateAtLaunch: Bool = true
    private var origCurrentUser: UserAccount?
    private var origSdkManagerFlow: SalesforceSDKManagerFlow?
    private var currentSdkManagerFlow: SFTestSDKManagerFlow!
    private var origAppName: String?
    private var origBrandLoginPath: String?

    override func setUp() {
        super.setUp()
        setupSdkManagerState()
    }

    override func tearDown() {
        restoreOrigSdkManagerState()
        super.tearDown()
    }

    // MARK: - App Name Tests

    func testOverrideAiltnAppNameBeforeSDKManagerInit() {
        SalesforceManager.analyticsAppName = kTestAppName
        createTestAppIdentity()
        compareAiltnAppNames(kTestAppName)
    }

    func testOverrideAiltnAppNameAfterSDKManagerInit() {
        createTestAppIdentity()
        SalesforceManager.analyticsAppName = kTestAppName
        compareAiltnAppNames(kTestAppName)
    }

    func testDefaultAiltnAppName() {
        createTestAppIdentity()
        let appName = Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String ?? ""
        compareAiltnAppNames(appName)
    }

    func testOverrideAppNameBeforeSDKManagerInit() {
        SalesforceManager.appName = kTestAppName
        createTestAppIdentity()
        compareAppNames(kTestAppName)
    }

    func testOverrideAppNameAfterSDKManagerInit() {
        createTestAppIdentity()
        SalesforceManager.appName = kTestAppName
        compareAppNames(kTestAppName)
    }

    func testDefaultAppName() {
        createTestAppIdentity()
        let appName = Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String ?? ""
        compareAppNames(appName)
    }

    func testUserSwitching() {
        SalesforceManager.shared.appConfig?.shouldAuthenticate = false
        createTestAppIdentity()
        let userAccountManager = UserAccountManager.shared
        XCTAssertNil(userAccountManager.currentUserAccount, "Current user should be nil.")
        userAccountManager.currentUserAccount = createUserAccount()
        XCTAssertNotNil(userAccountManager.currentUserAccount, "Current user should not be nil.")
        let userTo = createUserAccount()
        let userFrom = userAccountManager.currentUserAccount
        currentSdkManagerFlow.setUpUserSwitchState(from: userFrom, to: userTo) { fromUser, toUser, before in
            let beforeAfterString = before ? " in willSwitchuser " : " in didSwitchuser "
            XCTAssertEqual(fromUser, userFrom, "Switch from user is different than expected \(beforeAfterString)")
            XCTAssertEqual(toUser, userTo, "Switch to user is different than expected \(beforeAfterString)")
            if !before {
                XCTAssertEqual(toUser, userAccountManager.currentUserAccount, "Switch to user should change current user")
            }
        }
        userAccountManager.switchToUserAccount(userTo)
        currentSdkManagerFlow.clearUserSwitchState()
    }

    func testPasteboard() {
        let pasteboardName = UIPasteboard.general.name.rawValue
        XCTAssertEqual(pasteboardName, "com.apple.UIKit.pboard.general", "Pasteboard name doesn't match")
    }

    // MARK: - Snapshot Tests

    func testUsesSnapshot() {
        var creationViewControllerCalled = false
        SalesforceManager.shared.useSnapshotView = true
        SalesforceManager.shared.snapshotViewControllerCreationAction = {
            creationViewControllerCalled = true
            return nil
        }
        let scene = UIApplication.shared.connectedScenes.first
        NotificationCenter.default.post(name: UIScene.didEnterBackgroundNotification, object: scene)
        XCTAssertTrue(creationViewControllerCalled, "Did not call the snapshot view controller creation block upon scene backgrounding, when use snapshot is set to YES.")
    }

    func testDoNotUseSnapshot() {
        var creationViewControllerCalled = false
        SalesforceManager.shared.useSnapshotView = false
        SalesforceManager.shared.snapshotViewControllerCreationAction = {
            creationViewControllerCalled = true
            return nil
        }
        let scene = UIApplication.shared.connectedScenes.first
        NotificationCenter.default.post(name: UIScene.didEnterBackgroundNotification, object: scene)
        XCTAssertFalse(creationViewControllerCalled, "Did call the snapshot view controller creation block upon scene backgrounding, when use snapshot is set to NO.")
    }

    func testSnapshotRespondsToStateEvents() {
        var presentOnBackground = false
        var dismissOnDidBecomeActive = false
        let fakeView = UIView()
        SalesforceManager.shared.useSnapshotView = true
        SalesforceManager.shared.snapshotPresentationAction = { snapshotViewController in
            presentOnBackground = true
            fakeView.addSubview(snapshotViewController.view)
        }
        SalesforceManager.shared.snapshotDismissalAction = { _ in
            dismissOnDidBecomeActive = true
        }
        let scene = UIApplication.shared.connectedScenes.first
        NotificationCenter.default.post(name: UIScene.didEnterBackgroundNotification, object: scene)
        XCTAssertTrue(presentOnBackground, "Did not respond to scene background.")
        NotificationCenter.default.post(name: UIScene.didActivateNotification, object: scene)
        XCTAssertTrue(dismissOnDidBecomeActive, "Did not respond to app did become active.")
    }

    func testSnapshotPresentationDismissalBlocksAtomicRule() {
        var presentationBlockCalled = false
        var dismissalBlockCalled = false
        SalesforceManager.shared.useSnapshotView = true
        SalesforceManager.shared.snapshotPresentationAction = { _ in
            presentationBlockCalled = true
        }
        SalesforceManager.shared.snapshotDismissalAction = nil
        let scene = UIApplication.shared.connectedScenes.first
        NotificationCenter.default.post(name: UIScene.didEnterBackgroundNotification, object: scene)
        XCTAssertFalse(presentationBlockCalled || dismissalBlockCalled, "Called a presentation/dismissal block without both blocks being set.")

        // Test inverse
        SalesforceManager.shared.snapshotPresentationAction = nil
        SalesforceManager.shared.snapshotDismissalAction = { _ in
            dismissalBlockCalled = true
        }
        NotificationCenter.default.post(name: UIScene.didEnterBackgroundNotification, object: scene)
        XCTAssertFalse(presentationBlockCalled || dismissalBlockCalled, "Called a presentation/dismissal block without both blocks being set.")
    }

    func testDefaultSnapshotViewControllerIsProvided() {
        var defaultViewControllerOnPresentation: UIViewController?
        var defaultViewControllerOnDismissal: UIViewController?
        SalesforceManager.shared.useSnapshotView = true
        SalesforceManager.shared.snapshotViewControllerCreationAction = nil
        SalesforceManager.shared.snapshotPresentationAction = { snapshotViewController in
            defaultViewControllerOnPresentation = snapshotViewController
        }
        SalesforceManager.shared.snapshotDismissalAction = { snapshotViewController in
            defaultViewControllerOnDismissal = snapshotViewController
        }
        let scene = UIApplication.shared.connectedScenes.first
        NotificationCenter.default.post(name: UIScene.didEnterBackgroundNotification, object: scene)
        XCTAssertTrue(defaultViewControllerOnPresentation is UIViewController, "Did not provide a valid default snapshot view controller.")

        let fakeView = UIView()
        fakeView.addSubview(defaultViewControllerOnPresentation!.view)
        NotificationCenter.default.post(name: UIScene.didActivateNotification, object: scene)
        XCTAssertEqual(defaultViewControllerOnPresentation, defaultViewControllerOnDismissal, "Default snapshot view controller on dismissal is different than the one provided on presentation!")
    }

    func testCustomSnapshotViewControllerIsUsed() {
        let customSnapshot = UIViewController()
        var snapshotOnPresentation: UIViewController?
        var snapshotOnDismissal: UIViewController?
        SalesforceManager.shared.useSnapshotView = true
        SalesforceManager.shared.snapshotViewControllerCreationAction = {
            return customSnapshot
        }
        SalesforceManager.shared.snapshotPresentationAction = { snapshotViewController in
            snapshotOnPresentation = snapshotViewController
        }
        SalesforceManager.shared.snapshotDismissalAction = { snapshotViewController in
            snapshotOnDismissal = snapshotViewController
        }

        let scene = UIApplication.shared.connectedScenes.first
        NotificationCenter.default.post(name: UIScene.didEnterBackgroundNotification, object: scene)
        XCTAssertEqual(customSnapshot, snapshotOnPresentation, "Custom snapshot view controller was not used on presentation!")

        let fakeView = UIView()
        fakeView.addSubview(customSnapshot.view)
        NotificationCenter.default.post(name: UIScene.didActivateNotification, object: scene)
        XCTAssertEqual(customSnapshot, snapshotOnDismissal, "Custom snapshot view controller was not used on dismissal!")
    }

    // MARK: - Process Pool Tests

    @MainActor
    func testProcessPoolIsNil() {
        XCTAssertNil(SFSDKWebViewStateManager.sharedProcessPool)
    }

    // MARK: - Brand Login Tests

    func testBrandedLoginPath() {
        let brandPath = "/BRAND/"
        SalesforceManager.shared.brandLoginPath = brandPath
        XCTAssertEqual(brandPath, SalesforceManager.shared.brandLoginPath)
    }

    func testBrandedLoginPathInAuthManager() {
        let brandPath = "/BRAND/"
        SalesforceManager.shared.brandLoginPath = brandPath
        XCTAssertEqual(brandPath, UserAccountManager.shared.brandLoginPath)
    }

    func testBrandedLoginPathInAuthManagerAndAuthorizeEndpoint() {
        let brandPath = "/BRAND/SUB-BRAND/"
        createTestAppIdentity()
        let credentials = OAuthCredentials(identifier: "TESTBRAND", clientId: "TESTBRAND", encrypted: false)
        credentials.setValue("TESTBRAND", forKey: "domain")
        credentials.redirectUri = "TESTBRAND_URI"

        let coordinator = SFOAuthCoordinator(credentials: credentials)
        coordinator.brandLoginPath = brandPath
        let brandedURL = coordinator.generateApprovalUrlString()

        XCTAssertNotNil(brandedURL)
        // Should not have a trailing slash
        XCTAssertFalse(brandedURL.contains(brandPath))
        // Should have brand without trailing slash
        let brandPathWithoutTrailingSlash = String(brandPath.dropLast())
        XCTAssertTrue(brandedURL.contains(brandPathWithoutTrailingSlash))
    }

    func testAuthenticationFlags() {
        createTestAppIdentity()
        let credentials = OAuthCredentials(identifier: "testAuthenticationFlags", clientId: "test", encrypted: false)
        credentials.setValue("test", forKey: "domain")
        credentials.redirectUri = "test"

        // Web server enabled
        SalesforceManager.shared.useWebServerAuthentication = true
        let coordinator = SFOAuthCoordinator(credentials: credentials)
        let delegate = SFOAuthTestFlowCoordinatorDelegate()
        coordinator.delegate = delegate
        var approvalUrl = coordinator.generateApprovalUrlString()
        XCTAssertTrue(approvalUrl.contains("response_type=code"))
        coordinator.authenticate()
        XCTAssertEqual(coordinator.authInfo.authType, .webServer)
        coordinator.stopAuthentication()

        // Web server disabled
        SalesforceManager.shared.useWebServerAuthentication = false
        approvalUrl = coordinator.generateApprovalUrlString()
        XCTAssertTrue(approvalUrl.contains("response_type=hybrid_token"))
        coordinator.authenticate()
        XCTAssertEqual(coordinator.authInfo.authType, .userAgent)
        coordinator.stopAuthentication()

        // Hybrid disabled, web server enabled
        SalesforceManager.shared.useHybridAuthentication = false
        SalesforceManager.shared.useWebServerAuthentication = true
        approvalUrl = coordinator.generateApprovalUrlString()
        XCTAssertTrue(approvalUrl.contains("response_type=code"))
        coordinator.authenticate()
        XCTAssertEqual(coordinator.authInfo.authType, .webServer)
        coordinator.stopAuthentication()

        // Both disabled
        SalesforceManager.shared.useHybridAuthentication = false
        SalesforceManager.shared.useWebServerAuthentication = false
        approvalUrl = coordinator.generateApprovalUrlString()
        XCTAssertTrue(approvalUrl.contains("response_type=token"))
        coordinator.authenticate()
        XCTAssertEqual(coordinator.authInfo.authType, .userAgent)
    }

    // MARK: - Display Name Tests

    func testDefaultDisplayName() {
        let bundleName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
        let bundleDisplayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        let matchName = bundleDisplayName ?? bundleName ?? ""
        SalesforceManager.shared.appDisplayName = ""
        XCTAssertEqual(matchName, SalesforceManager.shared.appDisplayName, "App names should match")
    }

    func testSetDisplayName() {
        let appDisplayNameValue = "unique sdk name"
        SalesforceManager.shared.appDisplayName = appDisplayNameValue
        XCTAssertEqual(appDisplayNameValue, SalesforceManager.shared.appDisplayName, "App names should match")
    }

    // MARK: - Dev Actions Tests

    func testGetDevActionsAlwaysShowsDevInfo() {
        createTestAppIdentity()
        let regularVC = UIViewController()
        let actions = SalesforceManager.shared.devActionsList(presentedViewController:regularVC)
        XCTAssertGreaterThan(actions.count, 0, "Should have at least one action")
        XCTAssertEqual(actions[0].name, "Show dev info", "First action should always be dev info")
    }

    func testGetDevActionsShowsLoginOptionsOnLoginViewController() {
        createTestAppIdentity()
        let loginVC = SFLoginViewController()
        let actions = SalesforceManager.shared.devActionsList(presentedViewController:loginVC)
        let hasLoginOptions = actions.contains { $0.name == "Login Options" }
        XCTAssertTrue(hasLoginOptions, "Should show Login Options when on login view controller")
    }

    func testGetDevActionsDoesNotShowLoginOptionsOnRegularViewController() {
        createTestAppIdentity()
        let regularVC = UIViewController()
        let actions = SalesforceManager.shared.devActionsList(presentedViewController:regularVC)
        let hasLoginOptions = actions.contains { $0.name == "Login Options" }
        XCTAssertFalse(hasLoginOptions, "Should not show Login Options on regular view controller")
    }

    func testGetDevActionsShowsLogoutWhenUserLoggedIn() {
        createTestAppIdentity()
        let user = createUserAccount()
        UserAccountManager.shared.currentUserAccount = user
        let regularVC = UIViewController()
        let actions = SalesforceManager.shared.devActionsList(presentedViewController:regularVC)
        let hasLogout = actions.contains { $0.name == "Logout" }
        XCTAssertTrue(hasLogout, "Should show Logout when user is logged in and not on login screen")
        UserAccountManager.shared.currentUserAccount = nil
    }

    func testGetDevActionsDoesNotShowLogoutOnLoginViewController() {
        createTestAppIdentity()
        let user = createUserAccount()
        UserAccountManager.shared.currentUserAccount = user
        let loginVC = SFLoginViewController()
        let actions = SalesforceManager.shared.devActionsList(presentedViewController:loginVC)
        let hasLogout = actions.contains { $0.name == "Logout" }
        XCTAssertFalse(hasLogout, "Should not show Logout when on login view controller")
        UserAccountManager.shared.currentUserAccount = nil
    }

    func testGetDevActionsDoesNotShowLogoutWhenNoUser() {
        createTestAppIdentity()
        UserAccountManager.shared.currentUserAccount = nil
        let regularVC = UIViewController()
        let actions = SalesforceManager.shared.devActionsList(presentedViewController:regularVC)
        let hasLogout = actions.contains { $0.name == "Logout" }
        XCTAssertFalse(hasLogout, "Should not show Logout when no user is logged in")
    }

    // MARK: - Dev Support Infos Tests

    func testGetDevSupportInfosReturnsArray() {
        createTestAppIdentity()
        let infos = SalesforceManager.shared.devSupportInfoList()
        XCTAssertNotNil(infos, "Dev support infos should not be nil")
        XCTAssertGreaterThan(infos.count, 0, "Should have at least some info entries")
    }

    func testGetDevSupportInfosContainsSDKVersion() {
        createTestAppIdentity()
        let infos = SalesforceManager.shared.devSupportInfoList()
        let hasSDKVersion = findKeyValueInInfos(infos, key: "SDK Version")
        XCTAssertTrue(hasSDKVersion, "Dev support infos should contain SDK Version")
    }

    func testGetDevSupportInfosContainsAppType() {
        createTestAppIdentity()
        let infos = SalesforceManager.shared.devSupportInfoList()
        let hasAppType = findKeyValueInInfos(infos, key: "App Type")
        XCTAssertTrue(hasAppType, "Dev support infos should contain App Type")
    }

    func testGetDevSupportInfosContainsUserInfoWhenLoggedIn() {
        createTestAppIdentity()
        let user = createUserAccount()
        UserAccountManager.shared.currentUserAccount = user
        let infos = SalesforceManager.shared.devSupportInfoList()
        let hasUsername = findKeyValueInInfos(infos, key: "Username")
        XCTAssertTrue(hasUsername, "Dev support infos should contain Username when logged in")
        UserAccountManager.shared.currentUserAccount = nil
    }

    func testGetDevSupportInfosDoesNotContainUserInfoWhenNotLoggedIn() {
        createTestAppIdentity()
        UserAccountManager.shared.currentUserAccount = nil
        let infos = SalesforceManager.shared.devSupportInfoList()
        let hasCurrentUserSection = infos.contains("section:Current User")
        XCTAssertFalse(hasCurrentUserSection, "Dev support infos should not contain Current User section when not logged in")
    }

    func testGetDevSupportInfosContainsAuthConfigSection() {
        createTestAppIdentity()
        let infos = SalesforceManager.shared.devSupportInfoList()
        let hasAuthConfigSection = infos.contains("section:Auth Config")
        XCTAssertTrue(hasAuthConfigSection, "Dev support infos should contain Auth Config section")
    }

    func testGetDevSupportInfosContainsBootconfigSection() {
        createTestAppIdentity()
        let infos = SalesforceManager.shared.devSupportInfoList()
        let hasBootconfigSection = infos.contains("section:Bootconfig")
        XCTAssertTrue(hasBootconfigSection, "Dev support infos should contain Bootconfig section")
    }

    func testGetDevSupportInfosContainsUserAgentString() {
        createTestAppIdentity()
        let infos = SalesforceManager.shared.devSupportInfoList()
        let hasUserAgent = findKeyValueInInfos(infos, key: "User Agent")
        XCTAssertTrue(hasUserAgent, "Dev support infos should contain User Agent")
    }

    // MARK: - Runtime App Config Tests

    func testAppConfigForLoginHostReturnsDefaultWhenBlockNotSet() {
        SalesforceManager.shared.appConfigRuntimeSelectorBlock = nil
        let defaultConfig = SalesforceManager.shared.appConfig

        let expectation1 = self.expectation(description: "Callback should be called with default config")
        SalesforceManager.shared.bootConfig(forLoginHost: nil) { config in
            XCTAssertEqual(config, defaultConfig, "Should return default appConfig when no selector block is set")
            expectation1.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        let expectation2 = self.expectation(description: "Callback should be called with default config 2")
        SalesforceManager.shared.bootConfig(forLoginHost: "https://test.salesforce.com") { config in
            XCTAssertEqual(config, defaultConfig, "Should return default appConfig when no selector block is set, regardless of loginHost")
            expectation2.fulfill()
        }
        waitForExpectations(timeout: 1.0)
    }

    func testAppConfigForLoginHostReturnsDefaultWhenBlockReturnsNil() {
        var blockWasCalled = false
        let defaultConfig = SalesforceManager.shared.appConfig

        SalesforceManager.shared.appConfigRuntimeSelectorBlock = { _, callback in
            blockWasCalled = true
            callback(nil)
        }

        let expectation = self.expectation(description: "Callback should be called")
        SalesforceManager.shared.bootConfig(forLoginHost: "https://test.salesforce.com") { config in
            XCTAssertTrue(blockWasCalled, "Block should have been called")
            XCTAssertEqual(config, defaultConfig, "Should return default appConfig when block returns nil")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
    }

    // MARK: - Private Helpers

    private func createTestAppIdentity() {
        SalesforceManager.shared.appConfig?.remoteAccessConsumerKey = "test_connected_app_id"
        SalesforceManager.shared.appConfig?.oauthRedirectURI = "test_connected_app_callback_uri"
        SalesforceManager.shared.appConfig?.oauthScopes = Set(["web", "api"])
        UserAccountManager.shared.oauthClientID = "test_connected_app_id"
    }

    @discardableResult
    private func createUserAccount() -> UserAccount {
        let userIdentifier = arc4random()
        let credentials = OAuthCredentials(identifier: "identifier-\(userIdentifier)", clientId: UserAccountManager.shared.oauthClientID ?? "", encrypted: true)
        let user = UserAccount(credentials: credentials)
        let userId = "user_\(userIdentifier)"
        let orgId = "org_\(userIdentifier)"
        user.credentials.identityUrl = URL(string: "https://login.salesforce.com/id/\(orgId)/\(userId)")

        user.credentials.redirectUri = "testapp://auth/callback"
        user.credentials.instanceUrl = URL(string: "https://test.salesforce.com")
        user.credentials.accessToken = "test_access_token"
        user.credentials.scopes = ["api", "web", "refresh_token"]

        let idDataDict: [String: Any] = [
            "user_id": userId,
            "organization_id": orgId,
            "username": "testuser_\(userIdentifier)@example.com",
            "email": "testuser_\(userIdentifier)@example.com",
            "first_name": "Test",
            "last_name": "User\(userIdentifier)"
        ]
        user.idData = SFIdentityData(jsonDict: idDataDict)

        _ = user.transitionToLoginState(.loggedIn)
        do {
            try? UserAccountManager.shared.loadAccounts()
            _ = try UserAccountManager.shared.upsert(user)
        } catch {
            XCTFail("Should be able to create user account: \(error)")
        }
        return user
    }

    private func setupSdkManagerState() {
        currentSdkManagerFlow = SFTestSDKManagerFlow()
        origSdkManagerFlow = SalesforceManager.shared.sdkManagerFlow
        SalesforceManager.shared.sdkManagerFlow = currentSdkManagerFlow
        origConnectedAppId = SalesforceManager.shared.appConfig?.remoteAccessConsumerKey
        SalesforceManager.shared.appConfig?.remoteAccessConsumerKey = ""
        origConnectedAppCallbackUri = SalesforceManager.shared.appConfig?.oauthRedirectURI
        SalesforceManager.shared.appConfig?.oauthRedirectURI = ""
        origAuthScopes = SalesforceManager.shared.appConfig?.oauthScopes
        SalesforceManager.shared.appConfig?.oauthScopes = Set()
        origAuthenticateAtLaunch = SalesforceManager.shared.appConfig?.shouldAuthenticate ?? true
        SalesforceManager.shared.appConfig?.shouldAuthenticate = true
        origCurrentUser = UserAccountManager.shared.currentUserAccount
        UserAccountManager.shared.currentUserAccount = nil
        origAppName = SalesforceManager.analyticsAppName
        origBrandLoginPath = SalesforceManager.shared.brandLoginPath
    }

    private func restoreOrigSdkManagerState() {
        SalesforceManager.shared.sdkManagerFlow = origSdkManagerFlow
        SalesforceManager.shared.appConfig?.remoteAccessConsumerKey = origConnectedAppId ?? ""
        SalesforceManager.shared.appConfig?.oauthRedirectURI = origConnectedAppCallbackUri ?? ""
        SalesforceManager.shared.appConfig?.oauthScopes = origAuthScopes ?? Set()
        SalesforceManager.shared.appConfig?.shouldAuthenticate = origAuthenticateAtLaunch
        UserAccountManager.shared.currentUserAccount = origCurrentUser
        SalesforceManager.analyticsAppName = origAppName ?? ""
        SalesforceManager.shared.brandLoginPath = origBrandLoginPath
    }

    private func compareAiltnAppNames(_ expectedAppName: String) {
        let prevCurrentUser = UserAccountManager.shared.currentUserAccount
        UserAccountManager.shared.currentUserAccount = createUserAccount()
        let analyticsManager = SFSDKSalesforceAnalyticsManager.sharedInstance(user: UserAccountManager.shared.currentUserAccount!)
        XCTAssertNotNil(analyticsManager, "SFSDKSalesforceAnalyticsManager instance should not be nil")
        let deviceAttributes = analyticsManager?.analyticsManager.deviceAttributes
        XCTAssertNotNil(deviceAttributes, "SFSDKDeviceAppAttributes instance should not be nil")
        XCTAssertEqual(deviceAttributes?.appName, expectedAppName, "App names should match")
        SFSDKSalesforceAnalyticsManager.removeSharedInstance(user: UserAccountManager.shared.currentUserAccount!)
        try? UserAccountManager.shared.delete(UserAccountManager.shared.currentUserAccount!)
        UserAccountManager.shared.currentUserAccount = prevCurrentUser
    }

    private func compareAppNames(_ expectedAppName: String) {
        let userAgent = SalesforceManager.shared.userAgentString("")
        XCTAssertTrue(userAgent.contains(expectedAppName), "App names should match")
    }

    private func findKeyValueInInfos(_ infos: [String], key: String) -> Bool {
        for i in 0..<(infos.count - 1) {
            let item = infos[i]
            if !item.hasPrefix("section:") && item == key {
                if i + 1 < infos.count && !infos[i + 1].hasPrefix("section:") {
                    return true
                }
            }
        }
        return false
    }
}
