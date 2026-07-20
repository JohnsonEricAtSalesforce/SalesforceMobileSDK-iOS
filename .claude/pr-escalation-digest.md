# PR Escalation Digest — upstream port (forcedotcom/dev → migration branch)

Running narrative of **escalation-class** changes in the 49-unit upstream port, for the eventual
PR-review handoff. One entry per escalation unit, appended as ported. Non-escalation units are NOT
listed here (see `.claude/upstream-sync-backlog.md` for the full per-unit ledger).

**Escalation categories** (per CLAUDE.md "Stop and Flag for Human Review"): OAuth/token/credential
handling · public API surface change/deprecation · login UI / account switching · SQLCipher /
encryption / keychain · build-system (pbxproj/xcconfig/podspec/CI) · dependency version bump ·
Localizable.strings (localization).

Pre-approved gates (still PR-flag, do NOT re-ask): SQLCipher #4096; Localizable.strings #4059/#4093/#4088.

---

## Ported (units 1–23)

- **Unit 2 · #4045 · `f604c8540` — NEW PUBLIC API + lock-UI.** Added public `SFSDKScreenLockUIConfiguration`
  (`icon`/`iconSize`) and a new `configuration` property on the `ScreenLockManager` protocol; threaded into
  `ScreenLockUIView`. New public API surface on the screen-lock (biometric/passcode) path. 2 new tests pass.

- **Unit 4 · #4050 · `7a20ddd56` — login / instant-login.** Moved the DEBUG `-creds` instant-login block into
  `initializeSDK(manager:)` so it runs on the subclass path; reworked `SFSDKTestRequestListener` waiting to a
  semaphore. Touches login bootstrap (DEBUG path only). Test-support/live path.

- **Unit 7 · #4057 · `8c61acba7` — OAuth credential constants (internal).** Renamed server credential keys
  `beacon_child_consumer_{key,secret}` → `auto_installed_app_org_consumer_{key,secret}` with legacy fallback in
  `updateCredentials`. Internal constant values only — NO public API signature change. 5 tests pass.

- **Unit 8 · #4059 · `bdeba0b3e` — OAuth diagnostic + Localizable.strings (L10n pre-approved).** New diagnostic
  branch in `SFOAuthCoordinator.handleResponse`: on `unsupported_grant_type` + `.lightning.` domain, re-wrap the
  error with a localized message. Added `lightningUrlCodeExchangeError` to en.lproj **Localizable.strings**. 5 new
  tests pass.

- **Unit 22 · #4074 · `25f2ca733` — OAuth / token refresh.** Refresh now targets the instance URL when available:
  `overrideDomainIfNeeded()` precedence changed to communityUrl > instanceUrl > domain (was communityId?communityUrl:domain).
  Refresh log now includes target host. Affects which host a token-refresh request is sent to. 6/6 tests pass.

- **Unit 23 · #4075 · `4d7e7588e` — PUBLIC API deprecation + push-notification targeting.** `deviceSalesforceId`
  now `@available(*, deprecated)` (deprecate MSDK 14.0, remove ≥15.0), backed by private storage. Behavior fix:
  push unregister/register now read/write the *passed* user's preferences (not always currentUser), and a missing
  device Salesforce ID is treated as no-op success. 50/50 tests pass.

---

## Ported (units 25+)

- **Unit 25 · #4077 · `269223600` — build-system (xcconfig/pbxproj).** Centralized `SWIFT_VERSION = 5.0`
  into `configuration/Common.xcconfig`; removed per-target duplicates from the projects whose xcconfig chain
  reaches Common, and fixed two stale `SWIFT_VERSION = 4.0` values (RestAPIExplorer + MobileSyncExplorer app).
  Touches all 7 project files (4 libs + 3 sample apps). **Reviewer note:** SDKCore/SmartStore/MobileSyncExplorer
  retain explicit per-target `SWIFT_VERSION = 5.0` (functionally identical to the centralized value; a deliberate
  cosmetic divergence from upstream to avoid corrupting the migration-divergent pbxproj — MobileSyncExplorer in
  particular has no Common xcconfig chain, so removal there would break it). Net: centralized source + zero `4.0`
  stragglers. All 4 lib schemes + RestAPIExplorer + MobileSyncExplorer build green.

- **Unit 26 · #4076 · `d3fbf593c` — build-system (test-app scene lifecycle).** Migrated `SalesforceSDKCoreTestApp`
  off the UIKit storyboard launch (AppDelegate + ViewController + `main.m` + `Main_iPhone/iPad.storyboard`) to a
  single SwiftUI `@main struct ... : App`. Info.plist storyboard keys replaced by `UIApplicationSceneManifest` +
  `UILaunchScreen`. **Reviewer note:** the migration branch had *already* partly Swiftified this test app (compiled
  `AppDelegate.swift`/`ViewController.swift` twins); this unit converges to upstream's end-state by removing those
  twins too, so there is exactly one `@main`. pbxproj edited surgically (UUID-set verified −13 net, plutil OK); no
  library production code touched. **Test-app target only — not shipped in any SDK framework.** TEST BUILD SUCCEEDED.

- **Unit 27 · #4082 · `6741d365b` — build-system (test-app scene lifecycle).** Same migration as unit 26, for the
  `MobileSyncTestApp` target: retired the UIKit storyboard launch (AppDelegate + ViewController + `main.m` + `Main` /
  `LaunchScreen` storyboards) in favor of a single SwiftUI `@main struct MobileSyncTestApp: App`; removed the
  migration's pre-existing Swift twins so there is exactly one `@main`. Info.plist storyboard keys →
  `UIApplicationSceneManifest` + `UILaunchScreen`. pbxproj surgical (UUID set −14, plutil OK). **Test-app target
  only — not shipped in any SDK framework.** MobileSync TEST BUILD SUCCEEDED.

- **Unit 28 · #4083 · `453232268` — build-system (test-app scene lifecycle).** Same migration as units 26/27, for the
  `SmartStoreTestApp` target: retired the UIKit storyboard launch (AppDelegate + ViewController + `main.m` + `Main` /
  `LaunchScreen` storyboards) in favor of a single SwiftUI `@main struct SmartStoreTestApp: App`; removed the
  migration's pre-existing Swift twins so there is exactly one `@main`. Info.plist storyboard keys →
  `UIApplicationSceneManifest` + `UILaunchScreen`. pbxproj surgical (UUID set −14, plutil OK). **Test-app target
  only — not shipped in any SDK framework.** SmartStore TEST BUILD SUCCEEDED.

- **Unit 29 · #4081 · `ec26a5666` — build-system (test-app scene lifecycle).** Last of the test-app cluster; same
  migration as units 26/27/28 for the `SalesforceAnalyticsTestApp` target. Retired the UIKit storyboard launch
  (AppDelegate + ViewController + `main.m` + `Main_iPad` / `Main_iPhone` storyboards) → single SwiftUI `@main struct
  SalesforceAnalyticsTestApp: App`; removed the migration's Swift twins so there is exactly one `@main`. Info.plist
  storyboard keys → `UIApplicationSceneManifest` + `UILaunchScreen`. pbxproj surgical (plutil OK). **Test-app target
  only — not shipped in any SDK framework.** SalesforceAnalytics TEST BUILD SUCCEEDED. Test-app cluster (units 26–29)
  complete.

- **Unit 30 · #4079 · `7d9a91bfa` — build-system / CI permissions.** Added `statuses: write` to the two
  Danger jobs' `permissions:` blocks in `.github/workflows/pr.yaml`, so Danger can post the required PR
  commit statuses. **Reviewer note:** CI-workflow permission grant only — no library or app code touched,
  nothing compiled. Our `pr.yaml` matched the upstream pre-image exactly, so the upstream post-image was
  applied verbatim. Escalation = CI-config (pre-approved in the Phase-0 batch; still PR-flagged here).

- **Unit 32 · #4078 · `29439f0bb` — login-UI + OAuth/credential + PUBLIC API deprecation.** Fixes the
  Login-for-Admin (LFA) × Welcome-Discovery incompatibility. **Behavior:** during phase 1 of Welcome
  Discovery (discovery host, no My Domain resolved yet) the "Login for Admin" settings entry is now hidden
  and the action is a no-op; in phase 2 (My Domain resolved) LFA records the resolved My Domain + login hint
  as **in-memory, LFA-scoped overrides** on the auth request and routes the browser session to that My Domain,
  while leaving the request's `loginHost` untouched (so Reload / Clear Cache / post-cancel restart still use
  the originally configured host). Overrides are cleared on browser-auth cancel. **New public API:** `+[SFLoginViewController
  shouldShowLoginForAdminForSession:]` (menu-visibility predicate) and a new stateless class method
  `DomainDiscoveryCoordinator.isDiscoveryDomain(_:)`. **Deprecation:** the two `DomainDiscoveryCoordinator`
  *instance* `isDiscoveryDomain` overloads are now `@available(*, deprecated)` (MSDK 14.0 → remove 15.0),
  delegating to the new class method. New `SFSDKAuthRequest` properties `loginAsAdminMyDomain` /
  `loginAsAdminLoginHint`. Touches SFLoginViewController, DomainDiscoveryCoordinator, SFOAuthCoordinator,
  SFSDKAuthRequest, SFUserAccountManager. **Reviewer note:** ObjC bridging-header category from upstream was
  intentionally omitted (target class is now Swift; the helper is reachable via `@testable`). 44/44 new+touched
  tests pass; no live-org dependency.

- **Unit 33 · #4089 · `3379fb272` — build-system / CI.** When a PR touches `native/SampleApps/AuthFlowTester/`,
  run the full AuthFlowTester UI test suite instead of the single fixed PR smoke test. Danger `TestOrchestrator.rb`
  now emits a `run_all_ui_tests` job output (true when any AuthFlowTester file is modified/added); `pr.yaml` threads
  that output into the reusable UI-test workflow call; `reusable-ui-test-workflow.yaml` gains a `run_all_ui_tests`
  boolean input that gates the fixed-`pr_test` step off and a new full-suite `xcodebuild test` step on (archive-logs
  condition widened to cover both step ids). **Reviewer note:** CI-config only — no library or app code touched,
  nothing compiled; all three files byte-match the upstream post-image. Escalation = CI-config (pre-approved in the
  Phase-0 batch; still PR-flagged here).

- **Unit 34 · #4090 · `6a8a47717` — build-system / CI.** Pins the iOS 18 / Xcode 16 CI matrix leg to the
  `macos-15` runner (the iOS 18 simulator is not available on `macos-latest`, which is now macOS 26). Adds
  `macos: macos-15` to the `ios: ^18 / xcode: ^16` matrix `include` and threads `macos: ${{ matrix.macos }}`
  into the reusable-workflow `with:` calls across three top-level workflows: `nightly.yaml` (test + build jobs),
  `pr.yaml` (ios-pr test + native-samples-pr build + ui-tests-pr), and `ui-test-nightly.yaml`. The three reusable
  workflows already declare a `macos` input, so no change was needed there. **Reviewer note:** CI-config only — no
  library or app code touched, nothing compiled; all three files byte-match the upstream post-image. Escalation =
  CI-config (pre-approved in the Phase-0 batch; still PR-flagged here).

- **Unit 35 · #4086 · `99a173b58` — feature-flags + login/OAuth + NEW PUBLIC API (multi-lib).** Introduces
  **per-user** SDK feature flags alongside the existing global set, spanning SalesforceSDKCore, SmartStore, and
  MobileSync. **New public API:** `SalesforceSDKManager.userAgent(qualifier:for:)` (`@objc userAgentString:forUser:`)
  — returns a User-Agent whose `ftr_` segment is the union of global + that user's per-user flags; and new
  `SFSDKAppFeatureMarkers` per-user methods (`registerAppFeature(_:forUser:)`, `unregisterAppFeature(_:forUser:)`,
  `appFeatures(forUser:)`, `loadPersistedFeatures(_:forUser:)`). **New public property:** `SFUserAccount.persistedFeatureFlags`
  (`Set<String>?`), persisted via NSSecureCoding so per-user flags survive relaunch. **OAuth/login behavior change:**
  `finalizeAuthCompletion` now *promotes* the transient global auth-method flags (BW = advanced-browser, WD =
  welcome-discovery, QR = QR-login) to the newly-known user account and clears the global flag, so one user's login
  method no longer bleeds into another user's User-Agent; bio-auth/screen-lock flags likewise recorded per-user.
  On startup `SalesforceSDKManager` hydrates each account's persisted flags into the in-memory per-user map.
  **Reviewer notes:** (1) `SalesforceSDKCore.podspec` was intentionally **not** modified — upstream's podspec hunk was
  a pure reordering of the auto-generated `public_header_files` list (header set byte-identical; file is generated by
  `update_podspec_headers.sh`), so there was no material change to port and the CLAUDE.md "don't touch podspecs"
  rule is preserved. (2) Per-user persistence routes through the migration's manager-level `upsert(_:)` (the migrated
  Swift surface exposes `saveAccount(forUser:)`/`deleteAccount(forUser:)` only on the persister protocol, not on the
  manager). All 3 lib schemes build green; 17 AppFeatureMarkers + 4 manager/UA tests pass (fixture-based). Escalation
  = feature-flags + OAuth/login + new public API — flag in PR.

- **Unit 36 · #4091 · `9de77c7e2` — thread-safety.** Guards the last unsynchronized `SFUserAccount`
  accessor. `notificationTypes` now reads under a serialized queue and writes via a barrier, taking a
  defensive snapshot copy of the assigned array — closing a read/write data race (concurrent readers could
  observe a torn array; a set racing an in-flight encode could crash). Ported into the compiled twin
  **SFUserAccount.swift** using the file's existing `syncQueue.sync` (get) / `syncQueue.async(flags: .barrier)`
  (set) idiom already used by `accessScopes`/`credentials` (upstream ObjC used `dispatch_sync` /
  `dispatch_barrier_async` on `_syncQueue`); de-ref `SFUserAccount.m` ref-synced to the post-image verbatim.
  New byte-faithful test `SFUserAccountThreadSafetyTests.swift` (4 tests: concurrent read/write stress,
  snapshot isolation, assigned-value-after-drain, encode-under-contention) added and wired additively into
  the SDKCore test target pbxproj. **Reviewer note:** one test-only line adapted to the migration's
  class-cluster→factory change — `OAuthCredentials(identifier:clientId:encrypted:)!` (returns nil for the
  base class under `.keychain`) → `OAuthCredentials.credentials(identifier:…)!` (builds the
  `OAuthKeychainCredentials` subclass); production behavior unchanged. SDKCore builds green (0 new warnings);
  all 4 tests pass (fixture-based). Escalation = thread-safety / concurrency on a user-account accessor —
  flag in PR.

- **Unit 37 · #4092 · `ab84f31bd` — feature-flag + OAuth/token-refresh.** Adds the iOS Refresh-Token-Rotation
  (RTR) feature flag `RT`. During a successful session refresh, `SFOAuthSessionRefresher` now compares the
  refresh token returned by the server against the pre-refresh token; if it changed (server rotated the refresh
  token), the `RT` app-feature marker is registered **per-user** for the account that owns those credentials, so
  the user's User-Agent advertises RTR. New global constant `kSFAppFeatureRTR = "RT"` in `SFSDKAppFeatureMarkers`.
  Ported into the compiled Swift twins (SFSDKAppFeatureMarkers.swift, SFOAuthSessionRefresher.swift); de-ref
  `.h`/`.m` ref-synced. **Reviewer notes:** (1) production behavior is exactly upstream's — the flag is only set
  when the token actually rotates, never on an unchanged token (both cases covered by new tests). (2) Tests ported
  to the migrated surface: the new refresher tests use an in-test `SFSDKOAuthProtocol` stub swapped in via the
  `UserAccountManager.shared.authClient` factory var, the internal `SFSDKOAuthTokenEndpointResponse(dictionary:parseAdditionalFields:)`
  initializer (`@testable`), and `upsert(_:)`/`delete(_:)` for account save/delete (upstream used
  `saveAccountForUser:`/`deleteAccountForUser:`, which live only on the persister in the migrated surface). No
  live-org dependency. SDKCore builds green (0 new warnings); 22 tests pass (2 new RTR refresher tests + 1 new
  per-user RTR marker test). Escalation = feature-flag + OAuth token-refresh path — flag in PR.

- **Unit 38 · #4094 · `6993d6ba8` — OAuth error handling.** Introduces a typed `SFOAuthErrorCode` enum
  (45 server error values + `.unknown`, with `from(_:)` parser and `wireValue` mapping) to replace fragile
  string comparisons against the OAuth token-endpoint `error` field. `SFSDKOAuthTokenEndpointErrorResponse`
  gains an `errorCode` property (typed enum in Swift, `NSInteger` from ObjC); `SFOAuthCoordinator`'s
  Lightning-URL diagnostic now branches on `errorCode == .unsupportedGrantType` instead of a raw string
  compare. The legacy `kSFOAuthErrorType*` string constants are marked `__deprecated_msg("Use SFOAuthErrorCode
  enum instead")` but retained (no removal). **Reviewer notes:** (1) no behavior change — the enum parses the
  same wire strings the string constants held; the 45-value round-trip and the Lightning-URL diagnostic paths
  are covered by tests. (2) The migrated `SFSDKOAuth2.swift` already carried its own Swift error-type constants
  and `errorWithType` mapping, so upstream's ObjC inline-literal churn is cosmetic for the compiled path; the
  material change ported is the enum + `errorCode` property. New `SFOAuthErrorCode.swift` added verbatim and the
  2 new/changed test files wired into the SDKCore target. No live-org dependency. SDKCore builds green (0 new
  warnings); 13 tests pass. Escalation = OAuth error-handling surface — flag in PR.

- **Unit 39 · #4093 · `a2c4ee4d5` — PUBLIC API deprecation + advanced-auth default flip + login-UI + L10n.**
  Makes browser-based **Advanced Authentication the default for interactive login** (previously used only when
  the server's My Domain auth-config opted in), and **deprecates** the public toggle that gated it.
  **New default behavior:** on a standard login server (login/test.salesforce.com), first-time interactive login
  now launches the native browser (ASWebAuthenticationSession) instead of the in-app WKWebView. A Frontdoor Bridge
  login override still suppresses it; refresh-token, JWT, native-login, and shared-session (My Domain) paths are
  unchanged. Security invariant preserved and test-locked: forced Advanced Auth **always** builds the OAuth Web
  Server flow (`response_type=code` + PKCE), never the implicit/`response_type=token` flow, regardless of
  `useWebServerAuthentication`. **Public API deprecation:** `SalesforceManager.forceAdvancedAuthentication`
  (`@objc`, deprecate MSDK 14.0 → remove 15.0, `@available(*, deprecated)`), backed by a non-deprecated internal
  accessor (`forceAdvancedAuthenticationInternal`, default `true`) so internal SDK reads/writes stay warning-free —
  the Swift equivalent of upstream's `sdk_forceAdvancedAuthentication`, mirroring the migration's existing
  `showAuthWindowWhileLoading` precedent. **Login-UI:** in the forced-advanced-auth path (where SFLoginViewController
  is never created), the login-host list becomes a standalone login screen (`presentedAsLoginScreen`) that surfaces
  the back button and the dev-only gear / "Login Options" menu formerly owned by SFLoginViewController; new
  `LoginHostDelegate.hostListViewControllerDidChangeLoginOptions` restarts auth so changed options take effect.
  **L10n:** new `LOGIN_OPTIONS_FORCE_ADVANCED_AUTH` string (en.lproj, **pre-approved gate**). **Reviewer notes:**
  (1) all changes land in the compiled Swift twins (SalesforceSDKManager/SFOAuthCoordinator/SFSDKLoginHostListViewController/
  SFUserAccountManager); de-ref `.m`/`.h` ref-synced (verbatim where matched, surgical otherwise); four migration
  tombstone/stub headers have no compiled region (documented in the ledger). (2) Three `SFOAuthCoordinator` helpers
  (`beginNativeBrowserFlow`, `approvalURL`, `brandedAuthorizeURL`) were relaxed `private`→`internal` for `@testable`
  test access — mirroring upstream's ObjC test category and the migration's already-`internal` `beginWebViewFlow`/
  `generateApprovalUrlString`; **no new public API**. (3) Two ObjC test files ported to their Swift twins; all
  deprecated-property-touching test code is `@available(*, deprecated)`-guarded → zero deprecation warnings.
  SDKCore/SmartStore/MobileSync build green (0 new warnings in diff); 135 SDKCore tests across the 5 touched classes
  pass (25 new). Escalation = public-API deprecation + advanced-auth default behavior flip + login-UI + L10n — flag in PR.

- **Unit 40 · #4088 · `a2a271cca` — login-host input validation + failure recovery + L10n.**
  Two related behavior changes to custom-login-host handling. **(1) Input validation (Add Login Host screen):**
  `NewLoginHostView.save(...)` now rejects a host that is empty, lacks a `.`, contains whitespace, or does not
  parse as `https://<host>`, showing an inline red per-field error (`LOGIN_INVALID_HOST`) instead of saving a
  bogus host; the error clears as the user edits. **(2) Connection-failure recovery (`hostConnectionErrorHandlerBlock`):**
  when auth against the current host fails, the SDK now (a) captures the *previous* login host on every user-initiated
  host change (`previousLoginHost`) and recovers to it (falling back to storage index 0, guarded against empty
  storage to avoid a range trap), and (b) **auto-removes the failing host from storage only on a strong "host is
  unusable" signal** — an OAuth invalid-URL (`kSFOAuthErrorInvalidURL`) or a URL-layer error
  (`NSURLErrorBadURL`/`UnsupportedURL`/`AppTransportSecurityRequiresSecureConnection`). **Captive-portal safety
  invariant (test-locked):** ambiguous errors — DNS lookup failure, timeout, connection-lost — must NOT remove the
  host, because hotel/airport/coffee-shop Wi-Fi routinely hijacks DNS for valid enterprise hosts; deleting on those
  would permanently strip a user's custom org the first time they open the app behind a captive portal. Non-deletable
  built-in hosts are never removed. **L10n:** new `LOGIN_INVALID_HOST` string (en.lproj, **pre-approved gate**).
  **Reviewer notes:** (1) All production changes land in the compiled Swift twins (`NewLoginHostView.swift`,
  `SFUserAccountManager.swift`); `previousLoginHost` is an `internal` Swift property (upstream declared it in the ObjC
  `+Internal.h`, which is a dead header region in the migration — no compiled consumer — but was ref-synced verbatim
  for clean future merges). (2) `SFSDKLoginHostStorage.loginHostList` was relaxed `private`→`internal` for `@testable`
  test access (empty-storage snapshot/restore) — mirrors the ObjC test's KVC reach into the private ivar; **no new
  public API**. (3) The new ObjC test file `SFUserAccountManagerLoginHostRecoveryTests.m` was ported to a Swift twin
  (no new ObjC), preserving the `method_exchangeImplementations` swizzle of `restartAuthentication:` and adding a real
  `UIScene` to the request (the migrated `showErrorAlert` skips presentation on a nil scene). SDKCore/SmartStore/
  MobileSync build green (0 new warnings in diff); 19 SDKCore tests pass (10 validation + 9 recovery). Escalation =
  login-UI + login-host failure-recovery behavior + L10n — flag in PR.

### Unit 42 · #4096 — SQLCipher 4.16.0 → 4.17.0 (dependency bump, gate PRE-APPROVED)
**Escalation class: dependency version bump (SQLCipher / SmartStore encryption stack).** Gate was PRE-APPROVED
(Feedback #4) — no re-ask — but per policy every SQLCipher/dependency change is flagged for PR review.
**What changed:** SQLCipher `4.16.0 → 4.17.0` (bundled SQLite `3.53.1 → 3.53.3` at runtime), a mechanical version bump
across the four dependency-declaration sites — `SmartStore.podspec` (CocoaPods), `mobilesdk_pods.rb` (consuming-app
Podfile helper), and the two SPM `XCRemoteSwiftPackageReference` pins (`SmartStore.xcodeproj`, `MobileSyncExplorer.xcodeproj`,
`kind = exactVersion`) — plus the version-assertion tests and the maintenance skill doc.
**Reviewer notes:** (1) No API changes in the SQLCipher 4.17 bump for our usage — SmartStore + MobileSync (top of the
dependency chain) both build clean and the SQLCipher-linked encryption path is unchanged. (2) The version assertions live
in the **compiled Swift twin** `SFSmartStoreTests.swift` (`testSqliteVersion` → `3.53.3`, `testSqlCipherVersion` →
`4.17.0 community`); the de-referenced ObjC `SFSmartStoreTests.m` (0-in-Sources) was ref-synced verbatim for clean future
merges. (3) `SKILL.md` update is byte-identical to upstream (`SQLLite`→`SQLite` typo + a template-placeholder assertion).
(4) The version swap required a one-time full DerivedData Build-dir wipe (stale precompiled `sqlite3.h` module) — a local
build-cache artifact, not a code issue. SmartStore/MobileSync TEST BUILD green; 3 version tests pass (runtime-confirmed
`4.17.0 community` / SQLite `3.53.3`). **Escalation = SQLCipher dependency bump — flag in PR (pre-approved).**

### Unit 43 · #4098 — nil-sceneId crash on advanced-auth browser callback (OAuth/scene)
**Escalation class: OAuth advanced-authentication flow / scene routing.** No public API change; behavior fix in the
native-browser (`ASWebAuthenticationSession`) login path.
**The bug:** when advanced-auth login starts before any `UIScene` has connected (cold launch, extension-driven login) —
or the weak `authSession` deallocates before the browser callback fires — the callback built its URL-handler options
dictionary as `@{kSFIDPSceneIdKey : sceneId}` with a nil `sceneId`, crashing on the nil insert and dropping the session.
**The fix (2 parts):** (1) `SFSDKAuthSession` synthesizes a unique per-session scene id (`com.salesforce.mobilesdk.unscopedAuthSession-<UUID>`)
when no scene is connected, so every session gets its own `authSessions[]` key; (2) `SFOAuthCoordinator.browserCallbackOptions(forSceneId:)`
omits the key entirely when the id is nil, letting the URL handler fall back to the default scene.
**Reviewer notes:** (1) All production changes land in the compiled Swift twins (`SFSDKAuthSession.swift`,
`SFOAuthCoordinator.swift`); the de-referenced `.m` files were ref-synced byte-faithful for clean future merges;
`SFOAuthCoordinator+Internal.h` is a migration tombstone (no class-ext body) so the helper decl lives on the Swift class
as `internal` (visible to `@testable`, no new public API). (2) **Migration-specific extra:** the migrated `sceneId` was a
non-optional `String` defaulting to `""`, so it never *crashed* — but it had a latent **collision** bug (all scene-less
sessions shared the empty-string key). This port fixes that collision too, matching upstream's per-session-unique intent.
(3) The 4 new tests were both ref-synced into the de-ref `SFOAuthCoordinatorTests.m` (verbatim) and ported to the compiled
Swift twin. SDKCore/SmartStore/MobileSync build green (0 new warnings — 2 pre-existing unrelated warnings confirmed
unchanged); 6 SFOAuthCoordinatorTests pass. **Escalation = OAuth advanced-auth/scene callback behavior — flag in PR.**

### Unit 44 · #4087 — centralized token-refresh coordinator (OAuth/token + public-API deprecation) — LIVE-AUTH UNBLOCKER
**Escalation class: OAuth/token-refresh control flow + public-API deprecation of `SFOAuthSessionRefresher`.** This is the
biggest unit in the queue (18 upstream files) and the gate that unblocks Phase 2.
**What it does:** introduces `SFSDKTokenRefreshCoordinator` — a process-wide singleton that coalesces concurrent
token-refresh requests per credential (keyed by `credentials.identifier`) so at most one refresh is in-flight at a time.
This fixes the double-spend race with single-use (rotating) refresh tokens, where concurrent refreshes would invalidate
each other's tokens. Callbacks are delivered on the main queue; the in-flight refresh is wrapped in a background task.
**Reviewer notes:**
1. **No new ObjC.** Upstream added `SFSDKTokenRefreshCoordinator.h/.m`; the migration rule forbids new ObjC, so it is
   ported as a NEW `@objc` Swift class (`SFSDKTokenRefreshCoordinator.swift`) wired into the framework target. The new
   test file (`SFSDKTokenRefreshCoordinatorTests.m`, +602) is ported to Swift (`SFSDKTokenRefreshCoordinatorTests.swift`,
   11 tests). Both wired to pbxproj additively (`plutil -lint` OK).
2. **Behavior lives in the compiled Swift twins.** `SFRestAPI.swift` collapses three coordination flags
   (`sessionRefreshInProgress` / `pendingRequestsBeingProcessed` / `oauthSessionRefresher`) into a single
   `refreshCycleActive` and routes refresh through the coordinator; `cleanup()` now delivers a "User logged out" REST
   error to every pending request and nils-then-cancels their data tasks (was a bare `removeAllObjects`).
   `SFIdentityCoordinator` / `SFUserAccountManager.refreshCredentials` route through the coordinator;
   `UserAccountManager` gains an `async` `refresh(credentials:)`; `SFSDKOAuth2` drops three redundant main-queue
   completion hops; `SFSDKTestRequestListener` switches semaphore→run-loop-spin (a blocking semaphore-wait on the main
   thread would deadlock now that the coordinator delivers on main); `WebSocketClient`'s `TokenRefreshCoordinator` actor
   is renamed `WebSocketReconnectCoordinator` (it only gates reconnection; token dedup moved to the process coordinator).
3. **Public-API deprecation of `SFOAuthSessionRefresher` (14.0 → 15.0).** Upstream marks the class + its init +
   `refreshSessionWithCompletion:error:` deprecated (they bypass the centralized coordinator). Carried into the Swift twin
   via `@available(*, deprecated)` on the public init and `refreshSession(withCompletion:error:)` that external consumers
   call, plus **non-deprecated internal seams** (`init(internalCredentials:)` / `refreshSessionInternal(...)`) that the
   coordinator, the ported tests, and the test mock use — so the SDK's own code paths stay warning-free ("warnings are
   bugs"). Mirrors the unit-39 `forceAdvancedAuthenticationInternal` precedent. (Upstream expresses this with the ObjC
   `SFSDK_DEPRECATED` macro on `SFOAuthSessionRefresher.h`, which is a migration tombstone with no compiled home.)
4. **De-ref mirrors:** the non-compiled `.m`/`.h` mirrors (`SFRestAPI.m`, `SFIdentityCoordinator.m`, `SFSDKOAuth2.m`,
   `SFSDKTestRequestListener.m`, `SFOAuthSessionRefresher.m`, and the two test `.m`) were ref-synced to the upstream
   post-image on top of the migrated pre-image (retaining the migration's `@import`/`-Swift.h` deltas + the deprecation
   `SFSDK_USE_DEPRECATED_BEGIN/END` wraps). Tombstone headers (`SFOAuthSessionRefresher.h/+Internal.h`,
   `SFIdentityCoordinator+Internal.h`) skipped; `SFUserAccountManager.m` had nothing to sync (method lives in the twin).
**Gate:** SDKCore / SmartStore / MobileSync `build-for-testing` all GREEN, 0 new warnings (2 pre-existing unrelated
warnings confirmed unchanged); 22 targeted tests pass (11 coordinator + 7 data-task-race + 4 refresher). Live-org
auth-util end-to-end tests remain `XCTSkip`-gated pending Phase 2. **Escalation = OAuth/token-refresh + public-API
deprecation — flag in PR.**

### Unit 45 · #4102 — improve token-refresh error handling (OAuth/token + new public SFLogoutReason case)
Adds **App Attestation** classification to the REST token-refresh replay path. When a token refresh fails with an
OAuth-domain error, `SFRestAPI.swift replayRequest` now classifies the failure via the typed
`SFOAuthErrorCode.from(error.userInfo[kSFOAuthError])` and branches through a shared `triggerLogout` closure:
`.invalidGrant → logout(.tokenExpired)` (unchanged), `.appAttestationFailed → logout(.appAttestationFailed)` (NEW —
permanent client block), `.appAttestationFailedRetry → log only, no logout` (NEW — transient, client should retry).
This replaces the previous single `error.code == kSFOAuthErrorInvalidGrant` check. **Public-surface change:** a new
`SFLogoutReason` enum case `SFLogoutReasonAppAttestationFailed` is added to `SFSDKOAuth2.h` (ObjC enum bridged to
Swift; wire string `"app_attestation_failed"`). Because `SFLogoutReason` is a public ObjC-visible enum, adding a case
is an additive public-API change — **flag in PR** (matches upstream #4102 exactly; no case reordering, appended at end).
De-ref `.m` mirrors ref-synced (SFRestAPI.m +22/-7 byte-matches upstream, SFSDKOAuth2.m +2). Prereq typed error codes
already landed in units 38/41. New ObjC test file ported to a **Swift twin** (`SFRestAPIReplayRequestTests.swift`, 3
tests) per the no-new-ObjC rule; +2 verbatim tests in `SFSDKOAuth2TokenExchangeErrorTests.swift`.
**Gate:** SDKCore / SmartStore / MobileSync `build-for-testing` all GREEN, 0 new warnings (5 pre-existing SFRestAPI.swift
warnings confirmed outside the diff); 14 targeted tests pass (3 replay + 9 token-exchange), regression re-run of 11
coordinator + 7 data-task-race all green (determinism confirmed ×2). **Escalation = OAuth/token-refresh error handling
+ new public SFLogoutReason enum case — flag in PR.**

## Pending escalation units (upcoming — port in order)
- **46 · #4105 — login-host:** iOS26 login-host classifier fix.
