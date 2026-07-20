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

## Pending escalation units (upcoming — port in order)

- **25 · #4077 — build-system:** Common.xcconfig + ALL 7 pbxproj (4 libs + 3 sample). Genuine multi-scheme merge.
- **26–29 · #4076/#4082/#4083/#4081 — build-system:** SDKCore test-app scene migration + 4 new test-app targets + pbxproj.
- **32 · #4078 — login/OAuth:** Login-for-Admin + Welcome-Discovery incompatibility fix (SFLoginViewController, DomainDiscoveryCoordinator, SFOAuthCoordinator, SFUserAccountManager).
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
