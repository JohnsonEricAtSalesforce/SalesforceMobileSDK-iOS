import XCTest
import WebKit
import AuthenticationServices
@testable import SalesforceSDKCore

class SFOAuthCoordinatorTests: XCTestCase {
    func testDecidePolicyForNavigationAction_DomainDiscoveryCallback() {
        // Given
        let expectedLoginHint = "testuser@example.com"
        let mockDomain = "mydomain.example.com"
        let callbackURLString = "sfdc://discocallback?my_domain=\(mockDomain.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)&login_hint=\(expectedLoginHint.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)"
        guard let callbackURL = URL(string: callbackURLString) else {
            XCTFail("Failed to create callback URL")
            return
        }
        let mockNavigationAction = MockNavigationAction(url: callbackURL)
        let coordinator = SFOAuthCoordinator()
        coordinator.delegate = self
        let credentials = OAuthCredentials.credentials(identifier: "test",
                                                       clientId: "client",
                                                       encrypted: false)
        credentials?.testDomain = "foo.bar.com/discovery"
        credentials?.testRedirectURI = "sfdc://callback"
        coordinator.credentials = credentials
        
        // When
        coordinator.authenticate(withCredentials: credentials!)
        
        // Then
        var didCallDecisionHandlerPolicy: WKNavigationActionPolicy = .allow
        coordinator.webView(WKWebView(), decidePolicyFor: mockNavigationAction, decisionHandler: { policy in
            didCallDecisionHandlerPolicy = policy
        })
        
        // Assert
        XCTAssertEqual(didCallDecisionHandlerPolicy, .cancel)
        XCTAssertEqual(coordinator.testLoginHint, expectedLoginHint)
        XCTAssertEqual(coordinator.credentials?.domain, mockDomain)
    }

    /// #4039: the default for `showAuthWindowWhileLoading` was flipped NO -> YES (the auth window
    /// is now shown while the webview loads). This asserts against the internal backing
    /// (`showAuthWindowWhileLoadingInternal`) — the same storage the deprecated public property
    /// wraps and that the coordinator's load callbacks read — so the test itself does not trip the
    /// deprecation warning on the public property.
    func test_givenFreshUserAccountManager_whenReadingShowAuthWindowWhileLoading_thenDefaultsToTrue() {
        let manager = UserAccountManager.shared
        let original = manager.showAuthWindowWhileLoadingInternal
        defer { manager.showAuthWindowWhileLoadingInternal = original }

        // New default is true (was false before #4039).
        XCTAssertTrue(manager.showAuthWindowWhileLoadingInternal, "showAuthWindowWhileLoading should default to true as of #4039.")

        // The backing is read/write (the public property is a functional wrapper over it).
        manager.showAuthWindowWhileLoadingInternal = false
        XCTAssertFalse(manager.showAuthWindowWhileLoadingInternal)
        manager.showAuthWindowWhileLoadingInternal = true
        XCTAssertTrue(manager.showAuthWindowWhileLoadingInternal)
    }

    // MARK: - #4098: nil-sceneId crash on advanced-auth browser callback for pre-scene logins

    // Helper to build an auth request with the minimum fields the session initializer needs.
    private func makeAuthRequest() -> SFSDKAuthRequest {
        let authRequest = SFSDKAuthRequest()
        authRequest.oauthClientId = "testClientId"
        authRequest.oauthCompletionUrl = "testapp://callback"
        authRequest.loginHost = "login.salesforce.com"
        return authRequest
    }

    // Helper to build a coordinator whose browser-callback options we can inspect.
    private func browserFlowCoordinator() -> SFOAuthCoordinator {
        let authSession = SFSDKAuthSession(with: makeAuthRequest(), credentials: nil)
        return SFOAuthCoordinator(authSession: authSession)
    }

    // A session created before any UIScene connects must still expose a non-nil sceneId, otherwise the
    // advanced-auth browser callback crashes and the session is dropped from the authSessions store.
    func test_givenNoConnectedScene_whenAuthSessionCreated_thenSceneIdIsNonNilWithUnscopedPrefix() {
        let authRequest = makeAuthRequest()
        XCTAssertNil(authRequest.scene, "Precondition: no scene connected yet")

        let authSession = SFSDKAuthSession(with: authRequest, credentials: nil)

        XCTAssertFalse(authSession.sceneId.isEmpty, "sceneId must be non-empty so the advanced-auth callback options dictionary is safe to build and the session is stored under a valid key")
        XCTAssertTrue(authSession.sceneId.hasPrefix(SFSDKAuthSession.unscopedSceneIdPrefix), "A scene-less session should get the synthesized unscoped scene id, got: \(authSession.sceneId)")
    }

    // Two scene-less sessions must get distinct sceneIds so they cannot collide on a single authSessions[]
    // key, and each sceneId must be stable for the session's lifetime.
    func test_givenTwoNoSceneAuthSessions_whenCreated_thenSceneIdsAreDistinctAndStable() {
        let session1 = SFSDKAuthSession(with: makeAuthRequest(), credentials: nil)
        let session2 = SFSDKAuthSession(with: makeAuthRequest(), credentials: nil)

        XCTAssertFalse(session1.sceneId.isEmpty)
        XCTAssertFalse(session2.sceneId.isEmpty)
        XCTAssertNotEqual(session1.sceneId, session2.sceneId, "Two scene-less sessions must get distinct scene ids so they cannot collide on a single authSessions[] key")
        // Frozen for the session's lifetime: reading again yields the same value.
        XCTAssertEqual(session1.sceneId, session1.sceneId, "sceneId must be stable for the session's lifetime")
    }

    // When a scene is connected, the advanced-auth browser callback must key its options dictionary by
    // the scene id so the URL handler routes the response to the originating scene.
    func test_givenSceneId_whenBuildingBrowserCallbackOptions_thenOptionsAreKeyedBySceneId() {
        let coordinator = browserFlowCoordinator()

        let options = coordinator.browserCallbackOptions(forSceneId: "scene-42")

        XCTAssertEqual(options[UserAccountManager.IDPSceneKey] as? String, "scene-42", "A non-nil sceneId must be carried under IDPSceneKey so the callback routes to the originating scene")
        XCTAssertEqual(options.count, 1, "Only the scene id key should be present")
    }

    // When no scene id is available (e.g. login started before a UIScene connected, or the weak
    // authSession deallocated before the callback), the options must be an empty dictionary rather than
    // crashing on a nil insert; the URL handler then falls back to the default scene.
    func test_givenNilSceneId_whenBuildingBrowserCallbackOptions_thenOptionsAreEmptyAndDoNotCrash() {
        let coordinator = browserFlowCoordinator()

        let options = coordinator.browserCallbackOptions(forSceneId: nil)

        XCTAssertEqual(options.count, 0, "A nil sceneId must yield an empty options dictionary so nil is never inserted and the handler falls back to the default scene")
    }
}

// MARK: - SFOAuthCoordinatorDelegate conformance for tests
extension SFOAuthCoordinatorTests: SFOAuthCoordinatorDelegate {
    func oauthCoordinator(_ coordinator: SFOAuthCoordinator, didBeginAuthenticationWithView view: WKWebView) {}
    func oauthCoordinator(_ coordinator: SFOAuthCoordinator, didBeginAuthenticationWithSession session: ASWebAuthenticationSession) {}
    func oauthCoordinatorDidBeginNativeAuthentication(_ coordinator: SFOAuthCoordinator) {}
    func oauthCoordinatorDidCancelBrowserAuthentication(_ coordinator: SFOAuthCoordinator) {}
}

// MARK: - Test-only extension for SFOAuthCredentials to set domain
@testable import SalesforceSDKCore

extension OAuthCredentials {
    var testDomain: String? {
        get { return self.domain }
        set { self.setValue(newValue, forKey: "domain") }
    }
    
    var testRedirectURI: String? {
        get { return self.redirectUri }
        set { self.setValue(newValue, forKey: "redirectUri") }
    }
}

// MARK: - Test-only extension for SFOAuthCoordinator to get loginHint
extension SFOAuthCoordinator {
    var testLoginHint: String? {
        get { self.value(forKey: "loginHint") as? String }
        set { self.setValue(newValue, forKey: "loginHint") }
    }
}
