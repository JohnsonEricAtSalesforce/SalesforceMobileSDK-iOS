/*
 SalesforceSDKManagerTests.swift
 SalesforceSDKCoreTests

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

class SalesforceSDKManagerTests: XCTestCase {

    private var origConnectedAppId: String?
    private var origConnectedAppCallbackUri: String?
    private var origAuthScopes: Set<String>?
    private var origAuthenticateAtLaunch: Bool = true
    private var origCurrentUser: UserAccount?
    private var origSdkManagerFlow: (any SalesforceSDKManagerFlow)?
    private var currentSdkManagerFlow: SFTestSDKManagerFlow?
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

    // MARK: - AILTN App Name Tests

    func testOverrideAiltnAppNameBeforeSDKManagerInit() {
        SalesforceSDKManager.setAiltnAppName(kTestAppName)
        createTestAppIdentity()
        compareAiltnAppNames(kTestAppName)
    }

    func testOverrideAiltnAppNameAfterSDKManagerInit() {
        createTestAppIdentity()
        SalesforceSDKManager.setAiltnAppName(kTestAppName)
        compareAiltnAppNames(kTestAppName)
    }

    func testDefaultAiltnAppName() {
        createTestAppIdentity()
        let appName = Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String ?? ""
        compareAiltnAppNames(appName)
    }

    func testOverrideInvalidAiltnAppName() {
        createTestAppIdentity()
        SalesforceSDKManager.setAiltnAppName(nil)
        let appName = Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String ?? ""
        compareAiltnAppNames(appName)
    }

    // MARK: - App Name Tests

    func testOverrideAppNameBeforeSDKManagerInit() {
        SalesforceSDKManager.setAppName(kTestAppName)
        createTestAppIdentity()
        compareAppNames(kTestAppName)
    }

    func testOverrideAppNameAfterSDKManagerInit() {
        createTestAppIdentity()
        SalesforceSDKManager.setAppName(kTestAppName)
        compareAppNames(kTestAppName)
    }

    func testDefaultAppName() {
        createTestAppIdentity()
        let appName = Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String ?? ""
        compareAppNames(appName)
    }

    // MARK: - User Switching

    func testUserSwitching() {
        SalesforceSDKManager.shared.appConfig?.shouldAuthenticateOnFirstLaunch = false
        createTestAppIdentity()
        let userAccountManager = UserAccountManager.shared
        XCTAssertNil(userAccountManager.currentUserAccount, "Current user should be nil.")
        userAccountManager.setCurrentUserInternal(createUserAccount())
        XCTAssertNotNil(userAccountManager.currentUserAccount, "Current user should not be nil.")
        let userTo = createUserAccount()
        let userFrom = userAccountManager.currentUserAccount

        currentSdkManagerFlow?.setUpUserSwitchState(userAccountManager.currentUserAccount, toUser: userTo) { fromUser, toUser, before in
            let beforeAfterString = before ? " in willSwitchuser " : " in didSwitchuser "
            XCTAssertEqual(fromUser, userFrom, "Switch from user is different than expected \(beforeAfterString)")
            XCTAssertEqual(toUser, userTo, "Switch to user is different than expected \(beforeAfterString)")
            if !before {
                XCTAssertEqual(toUser, userAccountManager.currentUserAccount, "Switch to user should change current user")
            }
        }
        userAccountManager.switchToUserAccount(userTo)
        currentSdkManagerFlow?.clearUserSwitchState()
    }

    // MARK: - Pasteboard

    func testPasteboard() {
        let pasteboardName = UIPasteboard.general.name.rawValue
        XCTAssertEqual(pasteboardName, "com.apple.UIKit.pboard.general", "Pasteboard name doesn't match")
    }

    // MARK: - Snapshot Tests

    func testUsesSnapshot() {
        var creationViewControllerCalled = false
        SalesforceSDKManager.shared.useSnapshotView = true
        SalesforceSDKManager.shared.snapshotViewControllerCreationAction = {
            creationViewControllerCalled = true
            return nil
        }
        let scene = UIApplication.shared.connectedScenes.first
        NotificationCenter.default.post(name: UIScene.didEnterBackgroundNotification, object: scene)
        XCTAssertTrue(creationViewControllerCalled, "Did not call the snapshot view controller creation block upon scene backgrounding.")
    }

    func testDoNotUseSnapshot() {
        var creationViewControllerCalled = false
        SalesforceSDKManager.shared.useSnapshotView = false
        SalesforceSDKManager.shared.snapshotViewControllerCreationAction = {
            creationViewControllerCalled = true
            return nil
        }
        let scene = UIApplication.shared.connectedScenes.first
        NotificationCenter.default.post(name: UIScene.didEnterBackgroundNotification, object: scene)
        XCTAssertFalse(creationViewControllerCalled, "Did call the snapshot view controller creation block when use snapshot is set to NO.")
    }

    func testSnapshotRespondsToStateEvents() {
        var presentOnBackground = false
        var dismissOnDidBecomeActive = false
        let fakeView = UIView()
        SalesforceSDKManager.shared.useSnapshotView = true
        SalesforceSDKManager.shared.snapshotPresentationAction = { snapshotVC in
            presentOnBackground = true
            fakeView.addSubview(snapshotVC.view)
        }
        SalesforceSDKManager.shared.snapshotDismissalAction = { _ in
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
        SalesforceSDKManager.shared.useSnapshotView = true
        SalesforceSDKManager.shared.snapshotPresentationAction = { _ in
            presentationBlockCalled = true
        }
        SalesforceSDKManager.shared.snapshotDismissalAction = nil
        let scene = UIApplication.shared.connectedScenes.first
        NotificationCenter.default.post(name: UIScene.didEnterBackgroundNotification, object: scene)
        XCTAssertFalse(presentationBlockCalled || dismissalBlockCalled, "Called a presentation/dismissal block without both blocks being set.")

        SalesforceSDKManager.shared.snapshotPresentationAction = nil
        SalesforceSDKManager.shared.snapshotDismissalAction = { _ in
            dismissalBlockCalled = true
        }
        NotificationCenter.default.post(name: UIScene.didEnterBackgroundNotification, object: scene)
        XCTAssertFalse(presentationBlockCalled || dismissalBlockCalled, "Called a presentation/dismissal block without both blocks being set.")
    }

    func testDefaultSnapshotViewControllerIsProvided() {
        var defaultViewControllerOnPresentation: UIViewController?
        var defaultViewControllerOnDismissal: UIViewController?
        SalesforceSDKManager.shared.useSnapshotView = true
        SalesforceSDKManager.shared.snapshotViewControllerCreationAction = nil
        SalesforceSDKManager.shared.snapshotPresentationAction = { snapshotVC in
            defaultViewControllerOnPresentation = snapshotVC
        }
        SalesforceSDKManager.shared.snapshotDismissalAction = { snapshotVC in
            defaultViewControllerOnDismissal = snapshotVC
        }
        let scene = UIApplication.shared.connectedScenes.first
        NotificationCenter.default.post(name: UIScene.didEnterBackgroundNotification, object: scene)
        XCTAssertTrue(defaultViewControllerOnPresentation is UIViewController, "Did not provide a valid default snapshot view controller.")

        let fakeView = UIView()
        if let vc = defaultViewControllerOnPresentation {
            fakeView.addSubview(vc.view)
        }
        NotificationCenter.default.post(name: UIScene.didActivateNotification, object: scene)
        XCTAssertEqual(defaultViewControllerOnPresentation, defaultViewControllerOnDismissal, "Default snapshot view controller on dismissal is different than the one provided on presentation!")
    }

    func testDefaultSnapshotViewControllerIsProvidedWhenCustomViewControllerReturnsNil() {
        var defaultViewController: UIViewController?
        SalesforceSDKManager.shared.useSnapshotView = true
        SalesforceSDKManager.shared.snapshotViewControllerCreationAction = { nil }
        SalesforceSDKManager.shared.snapshotPresentationAction = { snapshotVC in
            defaultViewController = snapshotVC
        }
        SalesforceSDKManager.shared.snapshotDismissalAction = { _ in }
        let scene = UIApplication.shared.connectedScenes.first
        NotificationCenter.default.post(name: UIScene.didEnterBackgroundNotification, object: scene)
        XCTAssertTrue(defaultViewController is UIViewController, "Did not provide a valid default snapshot view controller.")
    }

    func testCustomSnapshotViewControllerIsUsed() {
        let customSnapshot = UIViewController()
        var snapshotOnPresentation: UIViewController?
        var snapshotOnDismissal: UIViewController?
        SalesforceSDKManager.shared.useSnapshotView = true
        SalesforceSDKManager.shared.snapshotViewControllerCreationAction = { customSnapshot }
        SalesforceSDKManager.shared.snapshotPresentationAction = { snapshotVC in
            snapshotOnPresentation = snapshotVC
        }
        SalesforceSDKManager.shared.snapshotDismissalAction = { snapshotVC in
            snapshotOnDismissal = snapshotVC
        }
        let scene = UIApplication.shared.connectedScenes.first
        NotificationCenter.default.post(name: UIScene.didEnterBackgroundNotification, object: scene)
        XCTAssertEqual(customSnapshot, snapshotOnPresentation, "Custom snapshot view controller was not used on presentation!")

        let fakeView = UIView()
        fakeView.addSubview(customSnapshot.view)
        NotificationCenter.default.post(name: UIScene.didActivateNotification, object: scene)
        XCTAssertEqual(customSnapshot, snapshotOnDismissal, "Custom snapshot view controller was not used on dismissal!")
    }

    // MARK: - Native Login Manager

    func testNativeLoginManager() {
        let consumerKey = "1234"
        let redirect = "ftest/redirect"
        let loginUrl = "https://salesforce.com/some/test/url"
        let view = UIViewController()
        let loginManager = SalesforceSDKManager.shared.useNativeLogin(
            withConsumerKey: consumerKey,
            callbackUrl: redirect,
            communityUrl: loginUrl,
            nativeLoginViewController: view,
            scene: nil
        ) as? SFNativeLoginManagerInternal

        XCTAssertEqual(consumerKey, loginManager?.clientId)
        XCTAssertEqual(redirect, loginManager?.redirectUri)
        XCTAssertEqual(loginUrl, loginManager?.loginUrl)
        XCTAssertEqual(view, SalesforceSDKManager.shared.nativeLoginViewControllers?.object(forKey: kSFDefaultNativeLoginViewControllerKey as NSString) as? UIViewController)
        XCTAssertNotNil(SalesforceSDKManager.shared.nativeLoginManager)
        XCTAssertTrue(UserAccountManager.shared.nativeLoginEnabled)
    }

    // MARK: - Branded Login Path

    func testBrandedLoginPath() {
        let brandPath = "/BRAND/"
        SalesforceSDKManager.shared.brandLoginPath = brandPath
        XCTAssertEqual(brandPath, SalesforceSDKManager.shared.brandLoginPath)
    }

    func testBrandedLoginPathInAuthManager() {
        let brandPath = "/BRAND/"
        SalesforceSDKManager.shared.brandLoginPath = brandPath
        XCTAssertEqual(brandPath, UserAccountManager.shared.brandLoginPath)
    }

    func testBrandedLoginPathInAuthManagerAndAuthorizeEndpoint() {
        let brandPath = "/BRAND/SUB-BRAND/"
        createTestAppIdentity()
        let credentials = OAuthCredentials(identifier: "TESTBRAND", clientId: "TESTBRAND", encrypted: false)
        credentials.domain = "TESTBRAND"
        credentials.redirectUri = "TESTBRAND_URI"

        let coordinator = SFOAuthCoordinator(credentials: credentials)
        coordinator.brandLoginPath = brandPath
        let brandedURL = coordinator.generateApprovalUrlString()

        XCTAssertNotNil(brandedURL)
        XCTAssertFalse(brandedURL.contains(brandPath))
        XCTAssertTrue(brandedURL.contains(String(brandPath.dropLast())))
    }

    // MARK: - Authentication Flags

    func testAuthenticationFlags() {
        createTestAppIdentity()
        let credentials = OAuthCredentials(identifier: "testAuthenticationFlags", clientId: "test", encrypted: false)
        credentials.domain = "test"
        credentials.redirectUri = "test"

        // Web server enabled
        SalesforceSDKManager.shared.useWebServerAuthentication = true
        var coordinator = SFOAuthCoordinator(credentials: credentials)
        let delegate = SFOAuthTestFlowCoordinatorDelegate()
        coordinator.delegate = delegate
        var approvalUrl = coordinator.generateApprovalUrlString()
        XCTAssertTrue(approvalUrl.contains("response_type=code"))
        coordinator.authenticate()
        XCTAssertEqual(SFOAuthTypeWebServer, coordinator.authInfo.authType)
        coordinator.stopAuthentication()

        // Web server disabled
        SalesforceSDKManager.shared.useWebServerAuthentication = false
        approvalUrl = coordinator.generateApprovalUrlString()
        XCTAssertTrue(approvalUrl.contains("response_type=hybrid_token"))
        coordinator.authenticate()
        XCTAssertEqual(SFOAuthTypeUserAgent, coordinator.authInfo.authType)
        coordinator.stopAuthentication()

        // Hybrid disabled, web server enabled
        SalesforceSDKManager.shared.useHybridAuthentication = false
        SalesforceSDKManager.shared.useWebServerAuthentication = true
        approvalUrl = coordinator.generateApprovalUrlString()
        XCTAssertTrue(approvalUrl.contains("response_type=code"))
        coordinator.authenticate()
        XCTAssertEqual(SFOAuthTypeWebServer, coordinator.authInfo.authType)
        coordinator.stopAuthentication()

        // Hybrid disabled, web server disabled
        SalesforceSDKManager.shared.useHybridAuthentication = false
        SalesforceSDKManager.shared.useWebServerAuthentication = false
        approvalUrl = coordinator.generateApprovalUrlString()
        XCTAssertTrue(approvalUrl.contains("response_type=token"))
        coordinator.authenticate()
        XCTAssertEqual(SFOAuthTypeUserAgent, coordinator.authInfo.authType)
    }

    // MARK: - Display Name Tests

    func testDefaultDisplayName() {
        SalesforceSDKManager.shared.appDisplayName = nil
        let bundleName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
        let bundleDisplayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        let matchName = bundleDisplayName ?? bundleName ?? ""
        XCTAssertEqual(matchName, SalesforceSDKManager.shared.appDisplayName, "App names should match")
    }

    func testSetDisplayName() {
        let appDisplayName = "unique sdk name"
        SalesforceSDKManager.shared.appDisplayName = appDisplayName
        XCTAssertEqual(appDisplayName, SalesforceSDKManager.shared.appDisplayName, "App names should match")
    }

    // MARK: - Runtime Selected App Config Tests

    func testAppConfigForLoginHostReturnsDefaultWhenBlockNotSet() {
        SalesforceSDKManager.shared.appConfigRuntimeSelectorBlock = nil
        let defaultConfig = SalesforceSDKManager.shared.appConfig

        verifyAppConfig(forLoginHost: nil, description: "Callback should be called with default config") { config in
            XCTAssertEqual(config, defaultConfig, "Should return default appConfig when no selector block is set")
        }

        verifyAppConfig(forLoginHost: "https://test.salesforce.com", description: "Callback should be called with default config") { config in
            XCTAssertEqual(config, defaultConfig, "Should return default appConfig when no selector block is set, regardless of loginHost")
        }
    }

    func testAppConfigForLoginHostWithDifferentLoginHosts() {
        let loginHost1 = "https://login.salesforce.com"
        let loginHost2 = "https://test.salesforce.com"

        let config1 = SFSDKAppConfig(dict: [
            "remoteAccessConsumerKey": "clientId1",
            "oauthRedirectURI": "app1://oauth/done",
            "shouldAuthenticate": true
        ])
        let config2 = SFSDKAppConfig(dict: [
            "remoteAccessConsumerKey": "clientId2",
            "oauthRedirectURI": "app2://oauth/done",
            "shouldAuthenticate": true
        ])
        let defaultConfig = SalesforceSDKManager.shared.appConfig

        SalesforceSDKManager.shared.appConfigRuntimeSelectorBlock = { loginHost, callback in
            if loginHost == loginHost1 {
                callback(config1)
            } else if loginHost == loginHost2 {
                callback(config2)
            } else {
                callback(nil)
            }
        }

        verifyAppConfig(forLoginHost: loginHost1, description: "First callback") { result in
            XCTAssertNotNil(result)
            XCTAssertEqual(result, config1)
            XCTAssertEqual(result?.remoteAccessConsumerKey, "clientId1")
        }

        verifyAppConfig(forLoginHost: loginHost2, description: "Second callback") { result in
            XCTAssertNotNil(result)
            XCTAssertEqual(result, config2)
            XCTAssertEqual(result?.remoteAccessConsumerKey, "clientId2")
        }

        verifyAppConfig(forLoginHost: nil, description: "Callback with nil") { config in
            XCTAssertEqual(config, defaultConfig, "Should return default appConfig when nil loginHost is passed")
        }
    }

    func testAppConfigForLoginHostReturnsDefaultWhenBlockReturnsNil() {
        var blockWasCalled = false
        let defaultConfig = SalesforceSDKManager.shared.appConfig

        SalesforceSDKManager.shared.appConfigRuntimeSelectorBlock = { _, callback in
            blockWasCalled = true
            callback(nil)
        }

        verifyAppConfig(forLoginHost: "https://test.salesforce.com", description: "Callback should be called") { config in
            XCTAssertTrue(blockWasCalled)
            XCTAssertEqual(config, defaultConfig, "Should return default appConfig when block returns nil")
        }
    }

    // MARK: - Dev Actions Tests

    func testGetDevActionsAlwaysShowsDevInfo() {
        createTestAppIdentity()
        let regularVC = UIViewController()
        let actions = SalesforceSDKManager.shared.getDevActions(regularVC)
        XCTAssertGreaterThan(actions.count, 0, "Should have at least one action")
        XCTAssertEqual(actions[0].name, "Show dev info", "First action should always be dev info")
    }

    func testGetDevActionsShowsLoginOptionsOnLoginViewController() {
        createTestAppIdentity()
        let loginVC = SFLoginViewController()
        let actions = SalesforceSDKManager.shared.getDevActions(loginVC)
        let hasLoginOptions = actions.contains { $0.name == "Login Options" }
        XCTAssertTrue(hasLoginOptions, "Should show Login Options when on login view controller")
    }

    func testGetDevActionsDoesNotShowLoginOptionsOnRegularViewController() {
        createTestAppIdentity()
        let regularVC = UIViewController()
        let actions = SalesforceSDKManager.shared.getDevActions(regularVC)
        let hasLoginOptions = actions.contains { $0.name == "Login Options" }
        XCTAssertFalse(hasLoginOptions, "Should not show Login Options on regular view controller")
    }

    func testGetDevActionsShowsLogoutWhenUserLoggedIn() {
        createTestAppIdentity()
        let user = createUserAccount()
        UserAccountManager.shared.setCurrentUserInternal(user)
        let regularVC = UIViewController()
        let actions = SalesforceSDKManager.shared.getDevActions(regularVC)
        let hasLogout = actions.contains { $0.name == "Logout" }
        XCTAssertTrue(hasLogout, "Should show Logout when user is logged in and not on login screen")
        UserAccountManager.shared.setCurrentUserInternal(nil)
    }

    func testGetDevActionsDoesNotShowLogoutOnLoginViewController() {
        createTestAppIdentity()
        let user = createUserAccount()
        UserAccountManager.shared.setCurrentUserInternal(user)
        let loginVC = SFLoginViewController()
        let actions = SalesforceSDKManager.shared.getDevActions(loginVC)
        let hasLogout = actions.contains { $0.name == "Logout" }
        XCTAssertFalse(hasLogout, "Should not show Logout when on login view controller")
        UserAccountManager.shared.setCurrentUserInternal(nil)
    }

    func testGetDevActionsDoesNotShowLogoutWhenNoUser() {
        createTestAppIdentity()
        UserAccountManager.shared.setCurrentUserInternal(nil)
        let regularVC = UIViewController()
        let actions = SalesforceSDKManager.shared.getDevActions(regularVC)
        let hasLogout = actions.contains { $0.name == "Logout" }
        XCTAssertFalse(hasLogout, "Should not show Logout when no user is logged in")
    }

    func testGetDevActionsShowsSwitchUserWhenUserLoggedIn() {
        createTestAppIdentity()
        let user = createUserAccount()
        UserAccountManager.shared.setCurrentUserInternal(user)
        let regularVC = UIViewController()
        let actions = SalesforceSDKManager.shared.getDevActions(regularVC)
        let hasSwitchUser = actions.contains { $0.name == "Switch user" }
        XCTAssertTrue(hasSwitchUser, "Should show Switch user when user is logged in and not on login screen")
        UserAccountManager.shared.setCurrentUserInternal(nil)
    }

    func testGetDevActionsDoesNotShowSwitchUserOnLoginViewController() {
        createTestAppIdentity()
        let user = createUserAccount()
        UserAccountManager.shared.setCurrentUserInternal(user)
        let loginVC = SFLoginViewController()
        let actions = SalesforceSDKManager.shared.getDevActions(loginVC)
        let hasSwitchUser = actions.contains { $0.name == "Switch user" }
        XCTAssertFalse(hasSwitchUser, "Should not show Switch user when on login view controller")
        UserAccountManager.shared.setCurrentUserInternal(nil)
    }

    // MARK: - Dev Support Infos Tests

    func testGetDevSupportInfosReturnsArray() {
        createTestAppIdentity()
        let infos = SalesforceSDKManager.shared.getDevSupportInfos()
        XCTAssertNotNil(infos)
        XCTAssertGreaterThan(infos.count, 0, "Should have at least some info entries")
    }

    func testGetDevSupportInfosContainsSDKVersion() {
        createTestAppIdentity()
        let infos = SalesforceSDKManager.shared.getDevSupportInfos()
        let hasSDKVersion = infos.enumerated().contains { idx, item in
            !item.hasPrefix("section:") && item == "SDK Version" && idx + 1 < infos.count && !infos[idx + 1].hasPrefix("section:")
        }
        XCTAssertTrue(hasSDKVersion, "Dev support infos should contain SDK Version")
    }

    func testGetDevSupportInfosContainsAppType() {
        createTestAppIdentity()
        let infos = SalesforceSDKManager.shared.getDevSupportInfos()
        let hasAppType = infos.enumerated().contains { idx, item in
            !item.hasPrefix("section:") && item == "App Type" && idx + 1 < infos.count && !infos[idx + 1].hasPrefix("section:")
        }
        XCTAssertTrue(hasAppType, "Dev support infos should contain App Type")
    }

    func testGetDevSupportInfosContainsUserInfoWhenLoggedIn() {
        createTestAppIdentity()
        let user = createUserAccount()
        UserAccountManager.shared.setCurrentUserInternal(user)
        let infos = SalesforceSDKManager.shared.getDevSupportInfos()
        let hasCurrentUser = infos.enumerated().contains { idx, item in
            !item.hasPrefix("section:") && item == "Username" && idx + 1 < infos.count && !infos[idx + 1].hasPrefix("section:")
        }
        XCTAssertTrue(hasCurrentUser, "Dev support infos should contain Username when logged in")
        UserAccountManager.shared.setCurrentUserInternal(nil)
    }

    func testGetDevSupportInfosDoesNotContainUserInfoWhenNotLoggedIn() {
        createTestAppIdentity()
        UserAccountManager.shared.setCurrentUserInternal(nil)
        let infos = SalesforceSDKManager.shared.getDevSupportInfos()
        let hasCurrentUserSection = infos.contains { $0 == "section:Current User" }
        XCTAssertFalse(hasCurrentUserSection, "Dev support infos should not contain Current User section when not logged in")
    }

    func testGetDevSupportInfosContainsAuthConfigSection() {
        createTestAppIdentity()
        let infos = SalesforceSDKManager.shared.getDevSupportInfos()
        let hasAuthConfigSection = infos.contains { $0 == "section:Auth Config" }
        XCTAssertTrue(hasAuthConfigSection, "Dev support infos should contain Auth Config section")
    }

    func testGetDevSupportInfosAuthConfigContainsExpectedFields() {
        createTestAppIdentity()
        let infos = SalesforceSDKManager.shared.getDevSupportInfos()
        let expectedFields = [
            "Use Web Server Authentication",
            "Use Hybrid Authentication",
            "Browser Login Enabled",
            "IDP Enabled",
            "Identity Provider"
        ]
        for field in expectedFields {
            let hasField = infos.enumerated().contains { idx, item in
                guard !item.hasPrefix("section:"), item == field, idx + 1 < infos.count, !infos[idx + 1].hasPrefix("section:") else { return false }
                let value = infos[idx + 1]
                return value == "YES" || value == "NO"
            }
            XCTAssertTrue(hasField, "Auth Config should contain field: \(field)")
        }
    }

    func testGetDevSupportInfosContainsBootconfigSection() {
        createTestAppIdentity()
        let infos = SalesforceSDKManager.shared.getDevSupportInfos()
        let hasBootconfigSection = infos.contains { $0 == "section:Bootconfig" }
        XCTAssertTrue(hasBootconfigSection, "Dev support infos should contain Bootconfig section")
    }

    func testGetDevSupportInfosCurrentUserSectionContainsAllCredentialFields() {
        createTestAppIdentity()
        let user = createUserAccount()
        UserAccountManager.shared.setCurrentUserInternal(user)
        let infos = SalesforceSDKManager.shared.getDevSupportInfos()
        let expectedFields = [
            "Username", "Consumer Key", "Redirect URI", "Scopes",
            "Instance URL", "Token format", "Access Token Expiration", "Beacon Child Consumer Key"
        ]
        for field in expectedFields {
            let hasField = infos.enumerated().contains { idx, item in
                !item.hasPrefix("section:") && item == field && idx + 1 < infos.count && !infos[idx + 1].hasPrefix("section:")
            }
            XCTAssertTrue(hasField, "Current User should contain field: \(field)")
        }
        UserAccountManager.shared.setCurrentUserInternal(nil)
    }

    func testGetDevSupportInfosCurrentUserCredentialsHaveCorrectValues() {
        createTestAppIdentity()
        let user = createUserAccount()
        UserAccountManager.shared.setCurrentUserInternal(user)
        let infos = SalesforceSDKManager.shared.getDevSupportInfos()
        for i in 0..<(infos.count - 1) {
            let item = infos[i]
            if !item.hasPrefix("section:") {
                let value = infos[i + 1]
                if item == "Redirect URI" {
                    XCTAssertEqual(value, "testapp://auth/callback")
                } else if item == "Instance URL" {
                    XCTAssertEqual(value, "https://test.salesforce.com")
                } else if item == "Token format" {
                    XCTAssertTrue(value == "jwt" || value == "opaque", "Token format should be jwt or opaque")
                }
            }
        }
        UserAccountManager.shared.setCurrentUserInternal(nil)
    }

    func testGetDevSupportInfosContainsUserAgentString() {
        createTestAppIdentity()
        let infos = SalesforceSDKManager.shared.getDevSupportInfos()
        let hasUserAgent = infos.enumerated().contains { idx, item in
            !item.hasPrefix("section:") && item == "User Agent" && idx + 1 < infos.count && !infos[idx + 1].hasPrefix("section:") && infos[idx + 1].count > 0
        }
        XCTAssertTrue(hasUserAgent, "Dev support infos should contain User Agent")
    }

    func testGetDevSupportInfosContainsAuthenticatedUsersWhenUsersExist() {
        createTestAppIdentity()
        _ = createUserAccount()
        let infos = SalesforceSDKManager.shared.getDevSupportInfos()
        let hasAuthenticatedUsers = infos.enumerated().contains { idx, item in
            !item.hasPrefix("section:") && item == "Authenticated Users" && idx + 1 < infos.count && !infos[idx + 1].hasPrefix("section:")
        }
        XCTAssertTrue(hasAuthenticatedUsers, "Dev support infos should contain Authenticated Users when users exist")
        UserAccountManager.shared.setCurrentUserInternal(nil)
    }

    func testGetDevSupportInfosSectionsAreProperlyStructured() {
        createTestAppIdentity()
        let user = createUserAccount()
        UserAccountManager.shared.setCurrentUserInternal(user)
        let infos = SalesforceSDKManager.shared.getDevSupportInfos()
        for i in 0..<infos.count {
            let item = infos[i]
            if item.hasPrefix("section:") {
                if i + 2 < infos.count {
                    let nextItem = infos[i + 1]
                    if !nextItem.hasPrefix("section:") {
                        XCTAssertTrue(true, "Section \(item) has at least one key-value pair")
                    }
                }
            }
        }
        UserAccountManager.shared.setCurrentUserInternal(nil)
    }

    // MARK: - Private Helpers

    private func createTestAppIdentity() {
        SalesforceSDKManager.shared.appConfig?.remoteAccessConsumerKey = "test_connected_app_id"
        SalesforceSDKManager.shared.appConfig?.oauthRedirectURI = "test_connected_app_callback_uri"
        SalesforceSDKManager.shared.appConfig?.oauthScopes = Set(["web", "api"])
        UserAccountManager.shared.oauthClientId = "test_connected_app_id"
    }

    private func createUserAccount() -> UserAccount {
        let userIdentifier = arc4random()
        let credentials = OAuthCredentials(
            identifier: "identifier-\(userIdentifier)",
            clientId: UserAccountManager.shared.oauthClientId,
            encrypted: true
        )
        let user = UserAccount(credentials: credentials)
        let userId = "user_\(userIdentifier)"
        let orgId = "org_\(userIdentifier)"
        user.credentials.identityUrl = URL(string: "https://login.salesforce.com/id/\(orgId)/\(userId)")
        user.credentials.redirectUri = "testapp://auth/callback"
        user.credentials.instanceUrl = URL(string: "https://test.salesforce.com")
        user.credentials.tokenFormat = nil
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
        user.transitionToLoginState(.loggedIn)

        var error: NSError?
        UserAccountManager.shared.saveAccount(forUser: user, error: &error)
        XCTAssertNil(error, "Should be able to create user account")
        return user
    }

    private func setupSdkManagerState() {
        currentSdkManagerFlow = SFTestSDKManagerFlow()
        origSdkManagerFlow = SalesforceSDKManager.shared.sdkManagerFlow
        SalesforceSDKManager.shared.sdkManagerFlow = currentSdkManagerFlow
        origConnectedAppId = SalesforceSDKManager.shared.appConfig?.remoteAccessConsumerKey
        SalesforceSDKManager.shared.appConfig?.remoteAccessConsumerKey = ""
        origConnectedAppCallbackUri = SalesforceSDKManager.shared.appConfig?.oauthRedirectURI
        SalesforceSDKManager.shared.appConfig?.oauthRedirectURI = ""
        origAuthScopes = SalesforceSDKManager.shared.appConfig?.oauthScopes
        SalesforceSDKManager.shared.appConfig?.oauthScopes = Set()
        origAuthenticateAtLaunch = SalesforceSDKManager.shared.appConfig?.shouldAuthenticateOnFirstLaunch ?? true
        SalesforceSDKManager.shared.appConfig?.shouldAuthenticateOnFirstLaunch = true
        origCurrentUser = UserAccountManager.shared.currentUserAccount
        UserAccountManager.shared.setCurrentUserInternal(nil)
        origAppName = SalesforceSDKManager.ailtnAppName
        origBrandLoginPath = SalesforceSDKManager.shared.brandLoginPath
    }

    private func restoreOrigSdkManagerState() {
        SalesforceSDKManager.shared.sdkManagerFlow = origSdkManagerFlow
        SalesforceSDKManager.shared.appConfig?.remoteAccessConsumerKey = origConnectedAppId ?? ""
        SalesforceSDKManager.shared.appConfig?.oauthRedirectURI = origConnectedAppCallbackUri ?? ""
        SalesforceSDKManager.shared.appConfig?.oauthScopes = origAuthScopes ?? Set()
        SalesforceSDKManager.shared.appConfig?.shouldAuthenticateOnFirstLaunch = origAuthenticateAtLaunch
        UserAccountManager.shared.setCurrentUserInternal(origCurrentUser)
        SalesforceSDKManager.ailtnAppName = origAppName ?? ""
        SalesforceSDKManager.shared.brandLoginPath = origBrandLoginPath ?? ""
    }

    private func compareAiltnAppNames(_ expectedAppName: String) {
        let prevCurrentUser = UserAccountManager.shared.currentUserAccount
        UserAccountManager.shared.setCurrentUserInternal(createUserAccount())
        guard let currentUser = UserAccountManager.shared.currentUserAccount else { return }
        let analyticsManager = SFSDKSalesforceAnalyticsManager.sharedInstance(with: currentUser)
        XCTAssertNotNil(analyticsManager)
        let deviceAttributes = analyticsManager?.analyticsManager.deviceAttributes
        XCTAssertNotNil(deviceAttributes)
        XCTAssertEqual(deviceAttributes?.appName, expectedAppName, "App names should match")
        SFSDKSalesforceAnalyticsManager.removeSharedInstance(with: currentUser)
        try? UserAccountManager.shared.delete(forUser: currentUser)
        UserAccountManager.shared.setCurrentUserInternal(prevCurrentUser)
    }

    private func compareAppNames(_ expectedAppName: String) {
        let userAgent = SalesforceSDKManager.shared.userAgentString("")
        XCTAssertTrue(userAgent.contains(expectedAppName), "App names should match")
    }

    private func verifyAppConfig(forLoginHost loginHost: String?, description: String, assertions: @escaping (SFSDKAppConfig?) -> Void) {
        let exp = expectation(description: description)
        SalesforceSDKManager.shared.appConfig(forLoginHost: loginHost) { config in
            assertions(config)
            exp.fulfill()
        }
        waitForExpectations(timeout: 1.0)
    }
}
