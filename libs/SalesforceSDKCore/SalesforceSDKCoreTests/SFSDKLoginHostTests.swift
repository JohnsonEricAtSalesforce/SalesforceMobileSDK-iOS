//
//  SFSDKLoginHostTests.swift
//  SalesforceSDKCoreTests
//
//  Copyright (c) 2016-present, salesforce.com, inc. All rights reserved.
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

// Spy delegate to observe the change-login-options callback.
private class SFSDKLoginHostTestDelegate: NSObject, LoginHostDelegate {
    var didChangeLoginOptionsCalled = false
    func hostListViewControllerDidChangeLoginOptions(_ hostListViewController: LoginHostListViewController) {
        didChangeLoginOptionsCalled = true
    }
}

class SFSDKLoginHostTests: XCTestCase {

    private var productionUrl = "login.salesforce.com"
    private var sandboxUrl = "test.salesforce.com"
    private var doesNotExistUrl = "doesnotexist.salesforce.com"
    private var customName = "New"
    private var customUrl = "https://new.com"
    private var customName2 = "New2"
    private var customUrl2 = "https://new2.com"

    // Saved global state restored in tearDown so the forced-advanced-auth chrome tests below
    // (which toggle dev support, the web-auth fallback flag, and biometric lock) don't leak state.
    private var originalDevSupportEnabled = false
    private var originalShouldFallbackToWebAuthentication = false
    private var originalBiometricLocked = false
    private var originalIdpAppURIScheme: String?
    private var originalCurrentUser: UserAccount?

    override func setUp() {
        super.setUp()
        originalDevSupportEnabled = SalesforceSDKManager.shared.isDevSupportEnabled
        originalShouldFallbackToWebAuthentication = UserAccountManager.shared.shouldFallbackToWebAuthentication
        originalBiometricLocked = BiometricAuthenticationManagerInternal.shared.locked
        originalIdpAppURIScheme = UserAccountManager.shared.idpAppURIScheme
        originalCurrentUser = UserAccountManager.shared.currentUserAccount
    }

    override func tearDown() {
        let loginHostStorage = SFSDKLoginHostStorage.sharedInstance
        loginHostStorage.removeAllLoginHosts()

        SalesforceSDKManager.shared.isDevSupportEnabled = originalDevSupportEnabled
        UserAccountManager.shared.shouldFallbackToWebAuthentication = originalShouldFallbackToWebAuthentication
        BiometricAuthenticationManagerInternal.shared.locked = originalBiometricLocked
        UserAccountManager.shared.idpAppURIScheme = originalIdpAppURIScheme
        UserAccountManager.shared.setCurrentUserInternal(originalCurrentUser)
        UserAccountManager.shared.stopCurrentAuthentication(nil)
        super.tearDown()
    }

    func testLoginHost() {
        let name = "dummyname"
        let host = "dummyhost"
        let deletable = true

        var loginHost = SalesforceLoginHost.host(withName: name, host: host, deletable: deletable)

        XCTAssertEqual(host, loginHost.host, "\(host) Should be equal to \(loginHost.host)")
        XCTAssertEqual(name, loginHost.name, "\(name) Should be equal to \(loginHost.name)")
        XCTAssertEqual(deletable, loginHost.deletable, "\(deletable) Should be equal to \(loginHost.deletable)")

        // Only testing name to be empty as host can never be nil and deletable will always have a YES or NO value
        loginHost = SalesforceLoginHost.host(withName: "", host: host, deletable: deletable)
        XCTAssertNotNil(loginHost.name, "Name should not be nil")
    }

    func testSetupNavigationBar() {
        let loginViewController = SalesforceLoginViewController()
        // Test default values
        XCTAssertNotNil(loginViewController.navBarColor, "Nav bar color should not be nil")
        XCTAssertNotNil(loginViewController.navBarTintColor, "Nav bar tint color should not be nil")
        XCTAssertNil(loginViewController.navBarFont, "Nav bar font should be nil")
        XCTAssertTrue(loginViewController.showNavbar, "Show Nav bar should be set to yes by default")
        XCTAssertTrue(loginViewController.showSettingsIcon, "Show Settings Icon should be set to yes by default")
    }

    func testGetLoginHosts() {
        let loginHostStorage = SFSDKLoginHostStorage.sharedInstance
        var loginHost = loginHostStorage.loginHostForHostAddress(productionUrl)

        XCTAssertEqual("Production", loginHost?.name, "Production Should be equal to \(loginHost?.name ?? "")")
        XCTAssertEqual(productionUrl, loginHost?.host, "\(productionUrl) Should be equal to \(loginHost?.host ?? "")")

        loginHost = loginHostStorage.loginHostForHostAddress(sandboxUrl)

        XCTAssertEqual("Sandbox", loginHost?.name, "Sandbox Should be equal to \(loginHost?.name ?? "")")
        XCTAssertEqual(sandboxUrl, loginHost?.host, "\(sandboxUrl) Should be equal to \(loginHost?.host ?? "")")

        loginHost = loginHostStorage.loginHostForHostAddress(doesNotExistUrl)
        XCTAssertNil(loginHost, "Login host should be nil")
    }

    func testAddCustomServer() {
        let loginHostStorage = SFSDKLoginHostStorage.sharedInstance
        var loginHost = loginHostStorage.loginHostForHostAddress(productionUrl)

        XCTAssertEqual("Production", loginHost?.name, "Production Should be equal to \(loginHost?.name ?? "")")
        XCTAssertEqual(productionUrl, loginHost?.host, "\(productionUrl) Should be equal to \(loginHost?.host ?? "")")

        loginHostStorage.addLoginHost(SalesforceLoginHost.host(withName: customName, host: customUrl, deletable: true))

        loginHost = loginHostStorage.loginHostForHostAddress(customUrl)

        XCTAssertEqual(customName, loginHost?.name, "\(customName) Should be equal to \(loginHost?.name ?? "")")
        XCTAssertEqual(customUrl, loginHost?.host, "\(customUrl) Should be equal to \(loginHost?.host ?? "")")
    }

    func testAddMultipleCustomServers() {
        let loginHostStorage = SFSDKLoginHostStorage.sharedInstance
        XCTAssertEqual(2, Int(loginHostStorage.numberOfLoginHosts), "Number of login hosts should be equal to 2")

        loginHostStorage.addLoginHost(SalesforceLoginHost.host(withName: customName, host: customUrl, deletable: true))
        var loginHost = loginHostStorage.loginHostForHostAddress(customUrl)
        XCTAssertEqual(3, Int(loginHostStorage.numberOfLoginHosts), "Number of login hosts should be equal to 3")
        XCTAssertEqual(customName, loginHost?.name, "\(customName) Should be equal to \(loginHost?.name ?? "")")
        XCTAssertEqual(customUrl, loginHost?.host, "\(customUrl) Should be equal to \(loginHost?.host ?? "")")

        loginHostStorage.addLoginHost(SalesforceLoginHost.host(withName: customName2, host: customUrl2, deletable: true))
        loginHost = loginHostStorage.loginHostForHostAddress(customUrl2)
        XCTAssertEqual(4, Int(loginHostStorage.numberOfLoginHosts), "Number of login hosts should be equal to 4")
        XCTAssertEqual(customName2, loginHost?.name, "\(customName2) Should be equal to \(loginHost?.name ?? "")")
        XCTAssertEqual(customUrl2, loginHost?.host, "\(customUrl2) Should be equal to \(loginHost?.host ?? "")")
    }

    func testLoginHostListViewControllerCreatesUniqueInstances() {
        // This test verifies the fix for the swipe dismissal race condition crash.
        // Each call to createLoginHostListViewController should return a fresh instance,
        // preventing the "nested navigation controllers" error when rapidly opening/closing
        // the connection screen with swipe gestures.

        let loginViewController = SalesforceLoginViewController()

        // Create multiple instances
        let instance1 = loginViewController.createLoginHostListViewController()
        let instance2 = loginViewController.createLoginHostListViewController()
        let instance3 = loginViewController.createLoginHostListViewController()

        // Verify each call creates a unique instance (different memory addresses)
        XCTAssertNotNil(instance1, "First instance should not be nil")
        XCTAssertNotNil(instance2, "Second instance should not be nil")
        XCTAssertNotNil(instance3, "Third instance should not be nil")

        XCTAssertFalse(instance1 === instance2, "First and second instances should be different objects")
        XCTAssertFalse(instance2 === instance3, "Second and third instances should be different objects")
        XCTAssertFalse(instance1 === instance3, "First and third instances should be different objects")

        // Verify each instance is properly configured with config and delegate
        XCTAssertNotNil(instance1.config, "First instance should have config")
        XCTAssertNotNil(instance2.config, "Second instance should have config")
        XCTAssertNotNil(instance3.config, "Third instance should have config")

        XCTAssertTrue(instance1.delegate === loginViewController, "First instance delegate should be set to loginViewController")
        XCTAssertTrue(instance2.delegate === loginViewController, "Second instance delegate should be set to loginViewController")
        XCTAssertTrue(instance3.delegate === loginViewController, "Third instance delegate should be set to loginViewController")
    }

    // MARK: - Forced Advanced Auth Chrome

    // viewDidLoad: with the flag off, the gear is absent and Cancel (not the back button) is the
    // left item, matching the pre-existing behavior for the transient "Choose Connection" sub-sheet.
    func test_givenChromeFlagOff_whenViewLoads_thenNoGearAndCancelShown() {
        let vc = LoginHostListViewController(style: .plain)
        vc.presentedAsLoginScreen = false
        SalesforceSDKManager.shared.isDevSupportEnabled = true

        vc.loadViewIfNeeded()

        XCTAssertNil(vc.loginOptionsButton(), "Gear should be nil when the chrome flag is off")
        XCTAssertNil(vc.navigationItem.leftBarButtonItem?.accessibilityIdentifier,
                     "Left item should be the system Cancel button (no back-button identifier) when the chrome flag is off")
        XCTAssertNotNil(vc.navigationItem.leftBarButtonItem, "Cancel button should be shown when the chrome flag is off and Cancel is not hidden")
    }

    // viewDidLoad: with the flag on and dev support on, the gear is added to the right bar items.
    func test_givenChromeFlagOnAndDevSupportOn_whenViewLoads_thenGearShownInRightItems() {
        let vc = LoginHostListViewController(style: .plain)
        vc.presentedAsLoginScreen = true
        SalesforceSDKManager.shared.isDevSupportEnabled = true

        vc.loadViewIfNeeded()

        let gear = vc.loginOptionsButton()
        XCTAssertNotNil(gear, "Gear should be created when the chrome flag and dev support are on")
        XCTAssertEqual(gear?.accessibilityIdentifier, "settings", "Gear should carry the 'settings' accessibility identifier")

        let gearInRightItems = (vc.navigationItem.rightBarButtonItems ?? []).contains { $0.accessibilityIdentifier == "settings" }
        XCTAssertTrue(gearInRightItems, "Right bar items should include the gear when the chrome flag and dev support are on")
    }

    // loginOptionsButton returns nil when dev support is off even though the chrome flag is on.
    func test_givenChromeFlagOnAndDevSupportOff_whenLoginOptionsButton_thenNil() {
        let vc = LoginHostListViewController(style: .plain)
        vc.presentedAsLoginScreen = true
        SalesforceSDKManager.shared.isDevSupportEnabled = false

        XCTAssertNil(vc.loginOptionsButton(), "Gear should be nil when dev support is disabled")
    }

    // shouldShowBackButton returns NO when the app is biometric-locked, regardless of other state.
    func test_givenBiometricLocked_whenShouldShowBackButton_thenNo() {
        BiometricAuthenticationManagerInternal.shared.locked = true
        UserAccountManager.shared.shouldFallbackToWebAuthentication = true // would otherwise be YES

        let vc = LoginHostListViewController(style: .plain)

        XCTAssertFalse(vc.shouldShowBackButton(), "Back button must be hidden while the app is biometric-locked")
    }

    // shouldShowBackButton returns YES when a web-auth fallback flow is in progress.
    func test_givenWebAuthFallback_whenShouldShowBackButton_thenYes() {
        BiometricAuthenticationManagerInternal.shared.locked = false
        UserAccountManager.shared.shouldFallbackToWebAuthentication = true

        let vc = LoginHostListViewController(style: .plain)

        XCTAssertTrue(vc.shouldShowBackButton(), "Back button should show while a web-auth fallback flow is in progress")
    }

    // shouldShowBackButton falls through to the account-based decision when the app is unlocked and
    // no idp / web-auth fallback flow is in progress. With no logged-in user in the test environment,
    // there is nothing to return to, so the back button should not show.
    func test_givenUnlockedNoFlowNoAccount_whenShouldShowBackButton_thenNo() {
        BiometricAuthenticationManagerInternal.shared.locked = false
        UserAccountManager.shared.shouldFallbackToWebAuthentication = false
        // Establish the "no account to return to" precondition explicitly. The shared
        // UserAccountManager is keychain-backed and can carry a currentUser left by other
        // tests (or a prior run); clear it so the account-based branch is exercised deterministically.
        // The original value is restored in tearDown.
        UserAccountManager.shared.setCurrentUserInternal(nil)

        let vc = LoginHostListViewController(style: .plain)

        // idp is disabled by default in the test environment; with no current user the account-based
        // branch returns NO.
        XCTAssertFalse(UserAccountManager.shared.isIDPEnabled, "Test precondition: idp should be disabled")
        XCTAssertNil(UserAccountManager.shared.currentUserAccount, "Test precondition: there should be no current user")
        XCTAssertFalse(vc.shouldShowBackButton(), "Back button should not show when unlocked with no flow and no account to return to")
    }

    // With the chrome flag on and shouldShowBackButton true, viewDidLoad installs the back button
    // as the left item (an image-only button, i.e. not the system Cancel button which has a title).
    func test_givenChromeFlagOnAndBackButtonEligible_whenViewLoads_thenBackButtonIsLeftItem() {
        BiometricAuthenticationManagerInternal.shared.locked = false
        UserAccountManager.shared.shouldFallbackToWebAuthentication = true

        let vc = LoginHostListViewController(style: .plain)
        vc.presentedAsLoginScreen = true

        vc.loadViewIfNeeded()

        let leftItem = vc.navigationItem.leftBarButtonItem
        XCTAssertNotNil(leftItem, "A left bar button item should be installed")
        XCTAssertNotNil(leftItem?.image, "The back button should be image-based")
        XCTAssertEqual(leftItem?.action, NSSelectorFromString("backToPreviousHost:"), "The left item should be the back button targeting backToPreviousHost:")
    }

    // createBackButton produces an image-based button wired to backToPreviousHost:.
    func test_whenCreateBackButton_thenImageButtonTargetsBackAction() {
        let vc = LoginHostListViewController(style: .plain)

        let backButton = vc.createBackButton()

        XCTAssertNotNil(backButton, "createBackButton should return a bar button item")
        XCTAssertNotNil(backButton.image, "Back button should have an image")
        XCTAssertEqual(backButton.action, NSSelectorFromString("backToPreviousHost:"), "Back button should target backToPreviousHost:")
    }

    // backToPreviousHost: routes to handleBackButtonAction, which stops the current authentication.
    // With no active auth session, no web-auth fallback, and no idp, this is a safe no-op that
    // returns cleanly.
    func test_whenBackToPreviousHost_thenHandlesWithoutCrashing() {
        UserAccountManager.shared.shouldFallbackToWebAuthentication = false
        let vc = LoginHostListViewController(style: .plain)
        vc.loadViewIfNeeded()

        XCTAssertNoThrow(vc.perform(NSSelectorFromString("backToPreviousHost:"), with: nil),
                         "Tapping back should stop authentication and dismiss without throwing")
    }

    // handleBackButtonAction consumes the web-auth fallback flag (sets it to NO) so the next login
    // attempt returns to the fallback surface instead of re-launching the browser.
    func test_givenWebAuthFallback_whenHandleBackButtonAction_thenFallbackConsumed() {
        UserAccountManager.shared.shouldFallbackToWebAuthentication = true
        let vc = LoginHostListViewController(style: .plain)
        vc.loadViewIfNeeded()

        vc.handleBackButtonAction()

        XCTAssertFalse(UserAccountManager.shared.shouldFallbackToWebAuthentication,
                       "handleBackButtonAction should consume the web-auth fallback flag")
    }

    // shouldShowBackButton returns YES via the idp branch when an idp app URI scheme is configured,
    // even without a logged-in account to return to.
    func test_givenIdpEnabled_whenShouldShowBackButton_thenYes() {
        BiometricAuthenticationManagerInternal.shared.locked = false
        UserAccountManager.shared.shouldFallbackToWebAuthentication = false
        UserAccountManager.shared.idpAppURIScheme = "testidp"
        XCTAssertTrue(UserAccountManager.shared.isIDPEnabled, "Test precondition: idp should be enabled")

        let vc = LoginHostListViewController(style: .plain)

        XCTAssertTrue(vc.shouldShowBackButton(), "Back button should show when an idp flow is enabled")
    }

    // handleBackButtonAction takes the idp branch (dismisses the presented view controller rather than
    // the whole auth window) when an idp app URI scheme is configured. With no active auth session this
    // is a safe no-op that returns cleanly.
    func test_givenIdpEnabled_whenHandleBackButtonAction_thenHandlesWithoutCrashing() {
        UserAccountManager.shared.shouldFallbackToWebAuthentication = false
        UserAccountManager.shared.idpAppURIScheme = "testidp"
        XCTAssertTrue(UserAccountManager.shared.isIDPEnabled, "Test precondition: idp should be enabled")

        let vc = LoginHostListViewController(style: .plain)
        vc.loadViewIfNeeded()

        XCTAssertNoThrow(vc.handleBackButtonAction(), "Back button in the idp path should dismiss without throwing")
    }

    // delegateDidChangeLoginOptions forwards to the delegate when it implements the optional method.
    func test_givenDelegate_whenDelegateDidChangeLoginOptions_thenDelegateNotified() {
        let vc = LoginHostListViewController(style: .plain)
        let spy = SFSDKLoginHostTestDelegate()
        vc.delegate = spy

        vc.delegate?.hostListViewControllerDidChangeLoginOptions?(vc)

        XCTAssertTrue(spy.didChangeLoginOptionsCalled, "Delegate should be notified when login options change")
    }

    // delegateDidChangeLoginOptions is a safe no-op when no delegate is set.
    func test_givenNoDelegate_whenDelegateDidChangeLoginOptions_thenNoCrash() {
        let vc = LoginHostListViewController(style: .plain)
        vc.delegate = nil

        XCTAssertNoThrow(vc.delegate?.hostListViewControllerDidChangeLoginOptions?(vc), "Should not throw when no delegate is set")
    }
}
