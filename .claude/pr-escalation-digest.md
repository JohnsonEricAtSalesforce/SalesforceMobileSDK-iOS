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

## Pending escalation units (upcoming — port in order)
- **35 · #4086 — feature-flags + podspec + multi-lib:** per-user feature flags across Core/MobileSync/SmartStore + SalesforceSDKCore.podspec.
- **36 · #4091 — thread-safety:** notification-types thread safety on SFUserAccount.
- **37 · #4092 — feature-flag/OAuth:** iOS RTR feature flag (SFOAuthSessionRefresher).
- **38 · #4094 — OAuth:** OAuth error-code enum (new SFOAuthErrorCode.swift, SFSDKOAuth2, SFOAuthCoordinator).
- **39 · #4093 — PUBLIC API + advanced-auth default flip + L10n(pre-appr):** make advanced-auth the default & deprecate `forceAdvancedAuthentication`; 24 files incl. Localizable.strings.
- **40 · #4088 — login-host + L10n(pre-appr):** invalid login-host recovery; Localizable.strings.
- **42 · #4096 — dependency bump (gate PRE-APPROVED):** SQLCipher 4.16 → 4.17 (SmartStore.podspec, mobilesdk_pods.rb).
- **43 · #4098 — OAuth/scene:** nil-sceneId crash fix on advanced-auth browser callback.
- **44 · #4087 — OAuth/token (LIVE-AUTH UNBLOCKER):** token-refresh coordinator; 18 files. Unblocks Phase 2.
- **45 · #4102 — OAuth/token:** improve token-refresh error handling.
- **46 · #4105 — login-host:** iOS26 login-host classifier fix.
