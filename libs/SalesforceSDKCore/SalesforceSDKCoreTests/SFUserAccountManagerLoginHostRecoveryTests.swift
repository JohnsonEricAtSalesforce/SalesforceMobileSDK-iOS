/*
 Copyright (c) 2026-present, salesforce.com, inc. All rights reserved.

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
import ObjectiveC
@testable import SalesforceSDKCore

private let kBogusHost = "bogus.example.com"
private let kBogusLabel = "Bogus Test Host"
private let kBuiltInProductionHost = "login.salesforce.com"

// File-static counter so the swizzled instance method (which runs as if on UserAccountManager,
// not on the test case) can record that it was hit. Reset in setUp.
private var gRestartAuthenticationCallCount: UInt = 0

final class SFUserAccountManagerLoginHostRecoveryTests: XCTestCase {

    private var origLoginHost: String?
    private var origPreviousLoginHost: String?
    private var origAlertDisplayBlock: ((AlertMessage, SFSDKWindowContainer) -> Void)?

    // Isolate the host-recovery decision logic from the real OAuth restart pipeline.
    //
    // The error-handler block under test ends with `restartAuthentication(session)`, which calls
    // `stopAuthentication`, dismisses any presented auth view controller asynchronously, then
    // re-enters `authenticateWithRequest:`. With a minimal stub SFSDKAuthRequest, none of that has
    // a real coordinator/view controller to act on, but it still mutates global UserAccountManager
    // state (authSessions[...]isAuthenticating, etc.) on a background dispatch — which can race the
    // `loginHost`/storage assertions these tests make right after `actionOneCompletion` fires.
    //
    // To make the recovery tests assert *only* on the synchronous decision (which host to fall back
    // to, whether the failing host was removed), we exchange `restartAuthentication:` with a no-op
    // for the duration of each test and restore it in tearDown. The handler still runs end-to-end
    // (recovery + storage cleanup), but the OAuth restart side-effect becomes a deterministic no-op.
    private func swapRestartAuthentication() {
        guard let original = class_getInstanceMethod(UserAccountManager.self, #selector(UserAccountManager.restartAuthentication(_:))),
              let replacement = class_getInstanceMethod(SFUserAccountManagerLoginHostRecoveryTests.self, #selector(SFUserAccountManagerLoginHostRecoveryTests.dummy_restartAuthentication(_:))) else {
            return
        }
        method_exchangeImplementations(original, replacement)
    }

    // Intentional no-op except for counting invocations. See -swapRestartAuthentication for rationale.
    // Counted via a file-static so tests can assert whether the recovery branch fired.
    @objc func dummy_restartAuthentication(_ session: SFSDKAuthSession) {
        gRestartAuthenticationCallCount += 1
    }

    override func setUp() {
        super.setUp()

        let mgr = UserAccountManager.shared
        origLoginHost = mgr.loginHost
        origPreviousLoginHost = mgr.previousLoginHost
        origAlertDisplayBlock = mgr.alertDisplayBlock

        swapRestartAuthentication()
        gRestartAuthenticationCallCount = 0

        // Ensure fixture host is present and deletable for each test.
        let storage = SFSDKLoginHostStorage.sharedInstance
        if storage.loginHostForHostAddress(kBogusHost) == nil {
            storage.addLoginHost(SalesforceLoginHost.host(withName: kBogusLabel, host: kBogusHost, deletable: true))
        }
    }

    override func tearDown() {
        // method_exchangeImplementations is symmetric — calling it again restores the originals.
        swapRestartAuthentication()

        let mgr = UserAccountManager.shared
        if let origLoginHost {
            mgr.loginHost = origLoginHost
        }
        mgr.previousLoginHost = origPreviousLoginHost
        if let origAlertDisplayBlock {
            mgr.alertDisplayBlock = origAlertDisplayBlock
        }

        let storage = SFSDKLoginHostStorage.sharedInstance
        removeHostIfPresent(kBogusHost, from: storage)

        super.tearDown()
    }

    // MARK: - Helpers

    private func removeHostIfPresent(_ hostAddress: String, from storage: SFSDKLoginHostStorage) {
        for i in 0..<storage.numberOfLoginHosts {
            if storage.loginHost(at: i).host == hostAddress {
                storage.removeLoginHost(at: i)
                return
            }
        }
    }

    private func makeAuthSession(forLoginHost loginHost: String) -> SFSDKAuthSession {
        let request = SFSDKAuthRequest()
        request.loginHost = loginHost
        request.oauthClientId = "test-client-id"
        request.oauthCompletionUrl = "test://callback"
        request.scopes = ["api"]
        // The migrated `showErrorAlert(...)` skips presentation when `scene` is nil, so give the
        // request the running test app's active window scene (as LoginForAdminTests does). Without
        // this the alertDisplayBlock is never invoked and the completion never runs.
        request.scene = UIApplication.shared.connectedScenes.first
        return SFSDKAuthSession(with: request, credentials: nil)
    }

    /// Strong "host is unusable" signal — the URL itself is malformed at the URL-loading layer.
    /// This class of error is reliably under our control (not produced by network conditions),
    /// so the gate auto-removes deletable hosts on it.
    private func makeStrongBadHostError() -> NSError {
        return NSError(domain: NSURLErrorDomain, code: NSURLErrorBadURL, userInfo: nil)
    }

    /// Ambiguous signal — timeout. Could be transient (flaky Wi-Fi). The gate must NOT
    /// auto-remove on this, even when the host is otherwise deletable.
    private func makeAmbiguousHostError() -> NSError {
        return NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: [
            "_kCFStreamErrorCodeKey": -2103,
            "_kCFStreamErrorDomainKey": 4
        ])
    }

    /// Ambiguous signal — DNS lookup failure. Despite the name, captive portals (hotel /
    /// airport / coffee-shop Wi-Fi) routinely hijack DNS and return this for valid enterprise
    /// hosts. The gate must NOT auto-remove on this — otherwise a user opening the app for
    /// the first time behind a captive portal would lose their custom org host permanently.
    private func makeDNSLookupFailedError() -> NSError {
        return NSError(domain: NSURLErrorDomain, code: NSURLErrorDNSLookupFailed, userInfo: [
            "_kCFStreamErrorCodeKey": -72000,
            "_kCFStreamErrorDomainKey": 12
        ])
    }

    /// Drives the error handler block and waits until the alert OK completion has run.
    /// Replaces alertDisplayBlock with a fake that immediately fires actionOneCompletion,
    /// so we never present a real alert and the recovery logic runs deterministically.
    private func fireHandlerBlock(forSession session: SFSDKAuthSession, withError error: NSError) {
        let mgr = UserAccountManager.shared
        let completionRan = expectation(description: "alertCompletionRan")
        mgr.alertDisplayBlock = { message, _ in
            if let actionOneCompletion = message.actionOneCompletion {
                actionOneCompletion()
            }
            completionRan.fulfill()
        }
        mgr.errorManager?.hostConnectionErrorHandlerBlock?(error, session, [:])
        wait(for: [completionRan], timeout: 5.0)
    }

    private func fireHandlerBlock(forSession session: SFSDKAuthSession) {
        fireHandlerBlock(forSession: session, withError: makeStrongBadHostError())
    }

    // MARK: - Tests

    func test_givenHostChange_when_didChangeLoginHostCalled_then_previousLoginHostIsPriorHost() {
        let mgr = UserAccountManager.shared
        let seedHost = "seed.my.salesforce.com"
        mgr.loginHost = seedHost
        mgr.previousLoginHost = nil

        let newHost = SalesforceLoginHost.host(withName: kBogusLabel, host: kBogusHost, deletable: true)
        mgr.hostListViewController(LoginHostListViewController(), didChange: newHost)

        XCTAssertEqual(mgr.previousLoginHost, seedHost)
        XCTAssertEqual(mgr.loginHost, kBogusHost)
    }

    func test_givenPreviousHostInStorage_when_handlerCompletionRuns_then_loginHostRestoredToPrevious() {
        let mgr = UserAccountManager.shared
        // Production host is built-in (deletable=NO) and always present in storage.
        mgr.previousLoginHost = kBuiltInProductionHost
        mgr.loginHost = kBogusHost

        let session = makeAuthSession(forLoginHost: kBogusHost)
        fireHandlerBlock(forSession: session)

        XCTAssertEqual(mgr.loginHost, kBuiltInProductionHost)
    }

    func test_givenPreviousHostNil_when_handlerCompletionRuns_then_loginHostFallsBackToIndex0() {
        let mgr = UserAccountManager.shared
        mgr.previousLoginHost = nil
        mgr.loginHost = kBogusHost

        let session = makeAuthSession(forLoginHost: kBogusHost)
        let expectedHost = SFSDKLoginHostStorage.sharedInstance.loginHost(at: 0).host
        fireHandlerBlock(forSession: session)

        XCTAssertEqual(mgr.loginHost, expectedHost)
    }

    func test_givenPreviousHostNotInStorage_when_handlerCompletionRuns_then_loginHostFallsBackToIndex0() {
        let mgr = UserAccountManager.shared
        mgr.previousLoginHost = "ghost.no.longer.in.storage.com"
        mgr.loginHost = kBogusHost

        let session = makeAuthSession(forLoginHost: kBogusHost)
        let expectedHost = SFSDKLoginHostStorage.sharedInstance.loginHost(at: 0).host
        fireHandlerBlock(forSession: session)

        XCTAssertEqual(mgr.loginHost, expectedHost)
    }

    func test_givenDeletableFailingHostAndStrongBadHostSignal_when_handlerCompletionRuns_then_failingHostRemovedFromStorage() {
        let mgr = UserAccountManager.shared
        mgr.previousLoginHost = kBuiltInProductionHost
        mgr.loginHost = kBogusHost

        let storage = SFSDKLoginHostStorage.sharedInstance
        XCTAssertNotNil(storage.loginHostForHostAddress(kBogusHost),
                        "Precondition: fixture deletable host should be in storage before firing the handler.")

        let session = makeAuthSession(forLoginHost: kBogusHost)
        fireHandlerBlock(forSession: session, withError: makeStrongBadHostError())

        XCTAssertNil(storage.loginHostForHostAddress(kBogusHost))
    }

    func test_givenDeletableFailingHostAndAmbiguousSignal_when_handlerCompletionRuns_then_failingHostKeptInStorage() {
        let mgr = UserAccountManager.shared
        mgr.previousLoginHost = kBuiltInProductionHost
        mgr.loginHost = kBogusHost

        let storage = SFSDKLoginHostStorage.sharedInstance
        XCTAssertNotNil(storage.loginHostForHostAddress(kBogusHost),
                        "Precondition: fixture deletable host should be in storage before firing the handler.")

        let session = makeAuthSession(forLoginHost: kBogusHost)
        fireHandlerBlock(forSession: session, withError: makeAmbiguousHostError())

        XCTAssertNotNil(storage.loginHostForHostAddress(kBogusHost),
                        "Deletable hosts must not be auto-removed on ambiguous (likely transient) errors.")
        // Recovery should still happen.
        XCTAssertEqual(mgr.loginHost, kBuiltInProductionHost)
    }

    // Captive-portal regression: hotel / airport / coffee-shop Wi-Fi routinely hijacks DNS
    // and returns NSURLErrorDNSLookupFailed for perfectly valid enterprise hosts. Classifying
    // DNS errors as a strong "host is unusable" signal would silently delete a user's custom
    // org the first time they open the app behind a captive portal — they'd lose the host
    // permanently with no recovery path. DNS errors must be treated as ambiguous.
    func test_givenDeletableFailingHostAndDNSLookupFailed_when_handlerCompletionRuns_then_failingHostKeptInStorage() {
        let mgr = UserAccountManager.shared
        mgr.previousLoginHost = kBuiltInProductionHost
        mgr.loginHost = kBogusHost

        let storage = SFSDKLoginHostStorage.sharedInstance
        XCTAssertNotNil(storage.loginHostForHostAddress(kBogusHost),
                        "Precondition: fixture deletable host should be in storage before firing the handler.")

        let session = makeAuthSession(forLoginHost: kBogusHost)
        fireHandlerBlock(forSession: session, withError: makeDNSLookupFailedError())

        XCTAssertNotNil(storage.loginHostForHostAddress(kBogusHost),
                        "DNS errors must not auto-remove hosts — captive portals routinely hijack DNS for valid hosts.")
        // Recovery to the previous host should still happen.
        XCTAssertEqual(mgr.loginHost, kBuiltInProductionHost)
    }

    // The recovery path explicitly guards against `numberOfLoginHosts == 0` before calling
    // `loginHost(at: 0)`. Without that guard, an empty storage list would raise NSRangeException.
    // Empty storage is plausible in two real cases: (1) the only entry was the failing host and was
    // just auto-removed by the strong-bad-host gate, or (2) MDM `onlyShowAuthorizedHosts` is enabled
    // with an empty authorized list. This test drains storage and asserts the handler logs + bails
    // rather than crashing, and leaves `loginHost` untouched (no recovery target available).
    func test_givenEmptyStorage_when_handlerCompletionRuns_then_noRangeExceptionAndNoHostAssignment() {
        let mgr = UserAccountManager.shared
        mgr.previousLoginHost = nil // Force the fallback path (else branch) into the storage lookup.
        mgr.loginHost = kBogusHost

        let storage = SFSDKLoginHostStorage.sharedInstance

        // SFSDKLoginHostStorage's public API can't actually empty the list: removeAllLoginHosts
        // intentionally preserves the built-in production/sandbox entries unless MDM
        // `onlyShowAuthorizedHosts` is set. To exercise the guard without standing up a fake
        // managed-preferences singleton, snapshot the internal `loginHostList` array, swap in an
        // empty array for this test, and restore on the way out.
        let snapshot = storage.loginHostList
        storage.loginHostList = []
        XCTAssertEqual(storage.numberOfLoginHosts, 0, "Precondition: storage must be empty.")

        let session = makeAuthSession(forLoginHost: kBogusHost)

        // Firing must NOT raise NSRangeException. In Swift, an out-of-range index is a fatal trap
        // rather than a catchable NSException, so the empty-storage guard is what keeps this test
        // (and the app) from crashing.
        fireHandlerBlock(forSession: session, withError: makeStrongBadHostError())

        // With no recovery host available, the handler must hit the `else` branch and skip the
        // restart entirely. We can't usefully assert on mgr.loginHost here — its getter (in
        // SFSDKAuthPreferences -loginHost) re-validates against storage and synthesizes a fallback
        // when the persisted value isn't found, so a read can't distinguish "handler didn't assign"
        // from "getter resolved to bundle default". The reliable signal is whether
        // restartAuthentication: was invoked: zero means the empty-storage guard bailed cleanly.
        XCTAssertEqual(gRestartAuthenticationCallCount, 0,
                       "With empty storage and no previousLoginHost, the handler must skip restartAuthentication: (recoveryHost stays nil).")

        // Restore the original list so subsequent tests (and the persisted singleton) are unaffected.
        storage.loginHostList = snapshot
    }

    func test_givenNonDeletableFailingHost_when_handlerCompletionRuns_then_failingHostKeptInStorage() {
        let mgr = UserAccountManager.shared
        // Failing host is the built-in production host, which is non-deletable.
        mgr.previousLoginHost = kBogusHost
        mgr.loginHost = kBuiltInProductionHost

        let storage = SFSDKLoginHostStorage.sharedInstance
        XCTAssertNotNil(storage.loginHostForHostAddress(kBuiltInProductionHost),
                        "Precondition: built-in production host should be in storage.")

        let session = makeAuthSession(forLoginHost: kBuiltInProductionHost)
        fireHandlerBlock(forSession: session)

        XCTAssertNotNil(storage.loginHostForHostAddress(kBuiltInProductionHost),
                        "Non-deletable hosts must never be auto-removed by the handler.")
    }
}
