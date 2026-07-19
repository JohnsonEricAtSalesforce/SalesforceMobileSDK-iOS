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
