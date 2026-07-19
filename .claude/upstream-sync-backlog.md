# Upstream Sync Backlog Ledger

Marker (done floor): `bac017113`  ·  forcedotcom/dev HEAD (target): `b5d37d807`  ·  **49 first-parent units / 129 commits behind**  ·  Re-seeded: 2026-07-19 (Phase 0 of the resume-porting plan).

> **Direction:** we port changes **FROM** `forcedotcom/dev` **INTO** our ObjC→Swift migration branch
> (`feature/objc-to-swift-test-migration`). Each unit is a *semantic re-implementation* against the current
> migrated Swift surface (NOT a cherry-pick).
>
> **Order:** strict upstream **first-parent order, oldest→newest** (operator: "we don't want to reorder the
> history"). Unlike the drained-12 pass (which reordered risk-ascending), this pass ports in exact upstream
> sequence. Marker advances as a contiguous prefix; frontier units stay in the ledger until the prefix reaches
> them.
>
> **Grouping:** first-parent walk of `bac017113..forcedotcom/dev` (top-level landings; excludes merged
> sub-history). Category by net first-parent diff footprint: **A** pure-Swift verbatim/near-verbatim · **B**
> ObjC→Swift semantic translation · **C** build/config/pbxproj/xcconfig · **D** new files/targets · **F**
> non-libs (CI, docs, skills, sample apps). Live progress bar = subject of lead task #9.

## Migration status
░░░░░░░░░░░░░░░░░░░░  0/49 units done (0%)   ·   libs-production-impacting: 0/21   ·   Phase 0 (analysis) in progress

| Bucket | Count | Notes |
|--------|-------|-------|
| libs-production-impacting | 21 | touch a compiled `libs/**` production source file |
| test/proj-only (libs)     | 15 | only `libs/**` test files, TestApps, or `.xcodeproj` |
| non-libs                  | 13 | CI, docs, skills, sample apps, SECURITY.md |
| **escalation-class**      | **~16** | see Escalation Summary below — flagged in PR narrative |
| flaky-stabilize           | 9 | re-baseline after each (test-behavior changes) |

## Units (strict upstream first-parent order — port oldest→newest)

| # | PR / unit | Commit | Cat | Escalation | Status | Notes |
|---|-----------|--------|-----|-----------|--------|-------|
| 1 | #4049 fix test-credentials login domain | 48366cbb7 | B | — | ⬜ pending | `SFSDKTestCredentialsData.m` (test-support). Test-scoped config, no product logic. |
| 2 | #4045 screen-lock customization | f604c8540 | A+C | ⚠ lock-UI | ⬜ pending | 4 ScreenLock `.swift` (already Swift) + `ScreenLockManagerTests.swift` + pbxproj. Cat-A verbatim where pre-image matches; passcode/lock-screen UI → flag. |
| 3 | SECURITY.md compliance | 11f6cb461 | F | — | ⬜ pending | repo-root `SECURITY.md` only. |
| 4 | #4050 fix instant login | 7a20ddd56 | B | ⚠ login | ⬜ pending | 2 libs prod files; login flow → flag. |
| 5 | #4052 signal semaphore in setReturnStatus: | 4ed3b2da3 | B | — | ⬜ pending | `SFSDKTestRequestListener` (test-support); all completion paths signal. |
| 6 | #4056 code-review skill | f6db7f4f4 | F | — | ⬜ pending | `.claude/skills/**` — non-product. |
| 7 | #4057 rename beacon child consumer keys | 8c61acba7 | B | ⚠ OAuth-const | ⬜ pending | `SFOAuthCredentials.m` + `SFSDKOAuthConstants.h` + 2 test `.m`. Constant rename in OAuth surface → note. |
| 8 | #4059 diag warning: OAuth code-exchange vs Lightning URL | bdeba0b3e | B | ⚠ OAuth + L10n(pre-appr) | ⬜ pending | `SFOAuthCoordinator.m`, constants, NEW `SFOAuthCoordinatorLightningURLTests.swift`, bridging-header, **Localizable.strings** (PRE-APPROVED). |
| 9 | #4058 doc: scope | e2c0d69f7 | F | — | ⬜ pending | docs only. |
| 10 | #4061 stabilize flaky testBootConfigPickerViewRendered | 985e2adce | A | flaky | ⬜ pending | 1 test file. Re-baseline after. |
| 11 | #4062 stabilize flaky testMissingLoginHint | 4c70ec9ef | A | flaky | ⬜ pending | 1 test file. Re-baseline after. |
| 12 | #4063 stabilize flaky testCAOpaque (UI) | 4ba0c943f | F | flaky | ⬜ pending | `.github/workflows` + AuthFlowTester UITests. Re-baseline after. |
| 13 | #4064 doc: scope | 08d39f43a | F | — | ⬜ pending | docs only. |
| 14 | #4065 skip CI on doc-only PRs | 84672d1eb | F | — | ⬜ pending | CI config. |
| 15 | #4071 stabilize flaky push-notif registration | f8291e901 | A | flaky | ⬜ pending | 2 test files. Re-baseline after. |
| 16 | #4066 stabilize flaky PushNotif foreground registration | 2a879dc7d | A | flaky | ⬜ pending | 1 test file. Re-baseline after. |
| 17 | #4073 fix closure-param mismatch PushNotifTests | 3965852bf | A | flaky | ⬜ pending | 1 test file (follow-up to #4066). Re-baseline after. |
| 18 | #4069 stabilize flaky RestClientPublisherTests | fd2a345e6 | A | flaky | ⬜ pending | 1 test file (live-gated class). Re-baseline after. |
| 19 | #4067 stabilize flaky testLoginViewControllerCustomizations | 366db6141 | A | flaky | ⬜ pending | 1 test file. Re-baseline after. |
| 20 | #4072 fix nil crash SFSDKBatchResponse haltOnError | ed5391fd1 | B | — | ⬜ pending | prod + test; batch-response nil guard. |
| 21 | #4070 stabilize flaky UI test testCAOpaque | 26a513347 | F | flaky | ⬜ pending | AuthFlowTester scene + UITests. Re-baseline after. |
| 22 | #4074 refresh uses instance URL | 25f2ca733 | B | ⚠ OAuth/refresh | ⬜ pending | `SFOAuthCredentials.m`, `SFSDKOAuth2.m`/`+Internal.h` + test `.m` + pbxproj. |
| 23 | #4075 fix push unregister wrong user | 4d7e7588e | A+B | — | ⬜ pending | `PushNotificationManager.swift`, `RemoteNotificationRegistering.swift` + tests. |
| 24 | #4053 stabilize flaky REST API + auth tests | 8319f9e93 | B | flaky + live-infra | ⬜ pending | **`TestSetupUtils.m`** (the live-gate infra) + `SFSDKAuthUtilTests.swift` + `SalesforceRestAPITests.m`. Watch interaction with our `authRefreshDidSucceed` divergence. Re-baseline after. |
| 25 | #4077 swift xcconfig | 269223600 | C | ⚠⚠ build-system | ⬜ pending | `configuration/Common.xcconfig` + **ALL 7 pbxproj** (4 libs + 3 sample). Structural; genuine pbxproj merge; build-verify every scheme. |
| 26 | #4076 app scene (SDKCore test app) | d3fbf593c | C+D | ⚠ build-system | ⬜ pending | SDKCoreTestApp scene migration; storyboards + Info.plist + pbxproj. Test-app only. |
| 27 | #4082 MobileSync test app | 6741d365b | D | ⚠ build-system | ⬜ pending | NEW `MobileSyncTestApp` target + pbxproj. |
| 28 | #4083 SmartStore test app | 453232268 | D | ⚠ build-system | ⬜ pending | NEW `SmartStoreTestApp` target + pbxproj. |
| 29 | #4081 Analytics test app | ec26a5666 | D | ⚠ build-system | ⬜ pending | NEW `SalesforceAnalyticsTestApp` target + pbxproj. |
| 30 | #4079 statuses write permission | 7d9a91bfa | F | — | ⬜ pending | CI workflow permission. |
| 31 | #4084 fix test failure | 7b6201360 | A | — | ⬜ pending | 1 test file. |
| 32 | #4078 fix Login-for-Admin + Welcome-Discovery incompatibility | 29439f0bb | B | ⚠⚠ login/OAuth | ⬜ pending | `SFLoginViewController.m`, `DomainDiscoveryCoordinator.swift`, `SFOAuthCoordinator.m`, `SFSDKAuthRequest.h`, `SFUserAccountManager.h/.m` + tests + bridging. |
| 33 | #4089 run all UI tests on AuthFlowTester change | 3379fb272 | F | — | ⬜ pending | CI config. |
| 34 | #4090 fix iOS18/macOS15 runner | 6a8a47717 | F | — | ⬜ pending | CI config. |
| 35 | #4086 feature flags per user | 99a173b58 | B | ⚠⚠ feature-flags + podspec + multi-lib | ⬜ pending | 23 files: **`SalesforceSDKCore.podspec`**, `SFMobileSyncSyncManager.m`, `SFSDKAppFeatureMarkers.*`, `SalesforceSDKManager.*`, `SFUserAccount.*`, `SFSmartStore.m` + tests + sample. Spans Core/MobileSync/SmartStore. |
| 36 | #4091 notification-types thread safety | 9de77c7e2 | B | ⚠ thread-safety | ⬜ pending | `SFUserAccount.m` + `SFUserAccountThreadSafetyTests.swift` + pbxproj. |
| 37 | #4092 iOS RTR feature flag | ab84f31bd | B | ⚠ feature-flag/OAuth | ⬜ pending | `SFSDKAppFeatureMarkers.*`, `SFOAuthSessionRefresher.m` + tests + sample. |
| 38 | #4094 OAuth error-code enum | 6993d6ba8 | B+D | ⚠ OAuth | ⬜ pending | `SFOAuthCoordinator.m`, NEW `SFOAuthErrorCode.swift`, `SFSDKOAuth2.h/.m`, constants + tests + pbxproj. |
| 39 | #4093 make advanced-auth default + deprecate forceAdvancedAuthentication | a2c4ee4d5 | B | ⚠⚠⚠ PUBLIC API + advanced-auth + L10n(pre-appr) | ⬜ pending | 24 files: `SalesforceSDKManager.*`, LoginHost VCs, `SFOAuthCoordinator.m`, `SFUserAccountManager.m` + tests + **Localizable.strings** + sample. PUBLIC-API deprecation + default behavior flip. |
| 40 | #4088 invalid login-host recovery | a2a271cca | B | ⚠ login-host + L10n(pre-appr) | ⬜ pending | `NewLoginHostView.swift`, `SFUserAccountManager.m` + tests + pbxproj + **Localizable.strings**. |
| 41 | #4095 token-exchange error tests | e4bdf6397 | A | — | ⬜ pending | 1 test `.swift` + pbxproj. |
| 42 | #4096 SQLCipher 4.17.0 | 303013dd7 | C | ⚠⚠ dependency bump (PRE-APPROVED gate) | ⬜ pending | `SmartStore.podspec`, `mobilesdk_pods.rb`, SmartStore pbxproj, MobileSyncExplorer pbxproj, `SFSmartStoreTests.m`, skill. SQLCipher 4.16→4.17. Gate PRE-APPROVED (Feedback #4). |
| 43 | #4098 fix nil-sceneId crash on advanced-auth browser callback | e4e838863 | B | ⚠ OAuth/scene | ⬜ pending | `SFOAuthCoordinator+Internal.h/.m`, `SFSDKAuthSession.m` + test. |
| 44 | #4087 token refresh coordinator | 6e0967833 | B+D | ⚠⚠⚠ OAuth/token (LIVE-AUTH UNBLOCKER) | ⬜ pending | 18 files: NEW `SFSDKTokenRefreshCoordinator.h/.m`, `SFOAuthErrorCode.swift`(via #4094), `SFOAuthSessionRefresher.*`, `SFIdentityCoordinator.m`, `SFRestAPI.m`, `UserAccountManager.swift`, `SFSDKOAuth2.m` + tests. **THIS unblocks the 51 SKIP-gated live-org tests → enables Phase 2.** |
| 45 | #4102 improve token-refresh error handling | 19d4436ab | B | ⚠ OAuth/token | ⬜ pending | `SFRestAPI.m`, `SFSDKOAuth2.h/.m` + tests + pbxproj. |
| 46 | #4105 fix iOS26 login-host classifier | b155f785d | B | ⚠ login-host | ⬜ pending | `SFOAuthCoordinator.m`, `SFSDKAuthErrorManager.m/+Internal.h` + test + pbxproj. |
| 47 | #4103 MobileSync docs | 5c31fb1eb | F | — | ⬜ pending | docs only. |
| 48 | #4111 push-notification docs | 5dd85627a | F | — | ⬜ pending | docs only. |
| 49 | #4112 parent-children sync fieldlist docs | b5d37d807 | F | — | ⬜ pending | docs only. **Marker → b5d37d807 when this lands.** |

## Escalation summary (up-front, Phase 0 — Feedback #1)

Requires PR-narrative flags; operator pre-approvals noted. **No new sign-off requested for pre-approved items.**

- **PUBLIC API:** #4093 (unit 39) — advanced-auth becomes default + `forceAdvancedAuthentication` deprecated. SDK-owner flag.
- **OAuth / token / credential:** #4059 (8), #4057 (7, const rename), #4074 (22, refresh), #4078 (32), #4092 (37), #4094 (38), #4098 (43), #4087 (44, coordinator), #4102 (45), #4105 (46, login-host classifier), #4088 (40, login-host recovery).
- **Login-UI / lock:** #4045 (2, screen-lock), #4050 (4, instant login), #4078 (32).
- **Feature-flags:** #4086 (35, per-user + podspec + multi-lib), #4092 (37).
- **Thread-safety:** #4091 (36).
- **Build-system (structural, Feedback #2):** #4077 (25, xcconfig + all pbxproj), #4076 (26, app-scene), #4082/#4083/#4081 (27/28/29, new test-app targets). Genuine pbxproj merges — build-verify each scheme.
- **Dependency bump:** #4096 (42, SQLCipher 4.17) — **gate PRE-APPROVED (Feedback #4)**; still PR-flag.
- **Localization (Localizable.strings) — PRE-APPROVED (Feedback #6):** #4059 (8), #4093 (39), #4088 (40). Still PR-flag.

## Live-org / Phase 2 note (Feedback #5 — ACCEPTED)

#4087 (unit **44**) is the token-refresh-coordinator that unblocks live auth. Per operator decision, we do NOT
pull it forward — history order is preserved. The 51 restored live-org tests (RestAPI 45 + SyncManager 3 +
SyncUpTarget 2) stay correctly SKIP-gated for units 1–43. Phase 2 (task #13) becomes actionable once unit 44
lands: remove the `TestSetupUtils.authRefreshDidSucceed` workaround, run the live-org tests + Task 10
oracle-compare, retire `.claude/live-org-skip-ledger.md`, marker → `b5d37d807` at unit 49. See
`.claude/live-org-skip-ledger.md` "REVALIDATION 2026-07-19".

## Re-baseline note (Feedback #3)

`.claude/test-baseline-ids.txt` was a stale 4-id/Jul-17 list. Re-derived at Phase 0 against current HEAD
(`5a9d30763`) before unit 1, and re-derived again after each of the 9 flaky-stabilize units (10,11,12,15,16,17,
18,19,21 — and #4053/unit 24) since those deliberately change test behavior. SmartStore gate stays provisional
(P0.2b); SDKCore gate settled per P0.2e.

---

## ARCHIVE — drained-12 pass (marker 6ed0ab40 → bac017113, completed 2026-07-18)

The previous 12-unit queue (upstream `6ed0ab408..bac017113`) is fully drained: 9 ported + 3 skipped, marker
advanced to `bac017113`, branch pushed. Units: ✅ #4043 #4042 #4041 #4044 #4040 #4046 #4039 #4047 #4035
(ported); ⏭ #4038 (buggy variadic not in migrated Swift surface — dropped-public-API flag raised),
master-merge×2 (empty net diff). Full per-unit detail (Cat-B intent + Swift mapping + port commits + the
#4039 backwards-premap correction + the #4041→#4044 ordering constraint + order-independence proof) is in git
history of this file at commits `8deff8bbc`/`d0480a667` and memory [[project_sync_job_review]]. That pass
reordered risk-ascending; THIS pass preserves strict upstream order per operator direction.
