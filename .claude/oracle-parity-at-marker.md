# Test-Suite Parity — Migration vs Oracle @ Marker `b5d37d807` (2026-07-31)

**Question (operator):** How does the migration's test suite compare to forcedotcom's
*unmigrated* version of the repo (the "oracle")?

**Oracle chosen:** the unmigrated forcedotcom tree **at the sync marker `b5d37d807`** — the exact
upstream state the migration claims parity with. Extracted via `git archive b5d37d807` from the
`../SalesforceMobileSDK-iOS.forcedotcom.dev` clone into a temp dir (non-destructive). NOTE: this is
the correct baseline, *not* the `.dev` clone `b155f785d` (that is 8 commits behind the marker) nor the
old merge-base `6ed0ab408` the prior `dropped-test-methods.md` used.

**Method:** per-library method-name **union diff**. Migration side counts a `test…` method only if its
file is in a **PBXSourcesBuildPhase** (compiled) — orphaned `.m` files with a file-reference but no
Sources entry do NOT count. Script: `/tmp/method_diff_marker.py` (re-runnable).

> Analysis-integrity note: two parser bugs were found and fixed before trusting results — (1) the
> migration uses **non-hex, variable-length synthetic UUIDs** (`4FAUTHFLOW…`, `4FDEVINFO…`) that a
> `[0-9A-F]{24}` regex silently dropped, producing 16 false "dropped" positives; (2) fixed by reading
> the `/* NAME in Sources */` comments inside each Sources phase directly. Do not trust an earlier
> count that lists DevInfo/AuthFlowTypes/DiscoveryResultEditor/LoginOptions/SFOAuthErrorCode as dropped
> — those are present AND compiled.

## Bottom line

Near-complete parity. Of 1,206 oracle test methods, the migration compiles all but **12**, and
adds 8 net-new. Breakdown:

| Library            | Oracle | Migration (compiled) | Dropped | Added |
|--------------------|:------:|:--------------------:|:-------:|:-----:|
| MobileSync         |  185   |         185          |    0    |   0   |
| SalesforceAnalytics|   19   |          19          |    0    |   0   |
| SalesforceSDKCommon|   33   |          33          |    0    |   0   |
| SalesforceSDKCore  |  789   |         786          |   11    |   8   |
| SmartStore         |  180   |         180          |   1*    |   1*  |
| **Total**          |**1206**|      **1203**        | **12**  | **8** |

\* SmartStore's 1/1 is the **case-only rename** `testAlterSoupwithFullTextIndexesFromFts4ToFts5` (oracle,
lowercase `with`) → `…WithFullText…` (migration, capital `W`). Same test, present + compiled. **NOT a
real drop.** So the real dropped count is **11**, all in SalesforceSDKCore.

## The 11 real SDKCore drops — classification

### Already-documented as SUPERSEDED (4) — closed in `dropped-test-methods.md`, still valid
- `SalesforceOAuthUnitTests.testScopeQueryParamStringNilScopes` — param narrowed `NSArray*`→`[String]`;
  literal nil unrepresentable from Swift; empty-scope sibling covers the same branch.
- `SFSDKEncryptedPushNotificationTests.testValidateUserInfo` — target method made `private`; happy path
  covered by surviving `testNotificationTransform`.
- `SFPushNotificationManagerTests.testRegisterSalesforceNotifications_NoUserCredentials` — scenario gone
  (`UserAccount.credentials` now non-optional); superseded by `_NoCurrentUser`.
- `SFPushNotificationManagerTests.testUnregisterSalesforceNotifications_NoUserCredentials` — same.

### Already-documented as BLOCKED (1) — escalation item B2, awaiting human sign-off
- `SalesforceRestAPITests.testAssertionForUnauthenticatedClient` — faithful restore needs
  `SFRestAPI.swift` `assert(...)` → catchable `NSException`. Bridge (`SFSDKCatchException`) now exists,
  but the prod change is escalation-class (public REST path) → deferred. See
  `phase2-pr-escalation-summary.md §B2`.

> **UPDATE 2026-08-01 — ALL 6 PORTED (operator: "Port them now").** The 6 gaps below were
> restored to compiled Swift and pass. (1) The 5 ScreenLock `getTimeout()` aggregation tests merged
> into the existing `ScreenLockManagerTests.swift` (with `KeychainHelper.removeAll()` added to `setUp`
> for the oracle's isolation); (2) `testMigrateRefreshTokenSetup` ported into
> `SFOAuthCoordinatorTests.swift`, waiting on the failure callback directly instead of the oracle's
> `dispatch_after(1s)` (no-sleeps standard). SDKCore `build-for-testing` ✓; targeted run = **14/14
> pass** incl. all 6 new. Full-suite regression gate: see `oracle-execution-parity-at-marker.md`. Both
> still carry escalation flags (account-switching + OAuth) for PR sign-off.

### ⚠ NEW FINDINGS — 6 real coverage gaps NOT in any prior doc (this pass surfaced them)
These were **missed by the earlier merge-base analysis** even though both introducing commits are
ancestors of that merge-base. Production API for all 6 still exists in the migration → genuinely
uncovered behavior, not superseded.

**`ScreenLockManagerTests` — 5 dropped (multi-user screen-lock policy):**
- `testShouldNotLock` — no timeout ⇒ no lock by default.
- `testShouldLockMultiuser` — aggregates policy across 2 users (one with policy, one without).
- `testShouldLockMultiuserDifferentTimeouts` — 3 users ⇒ **most-restrictive** timeout wins.
- `testShouldLockMultiuserDifferentTimeoutsReverseOrder` — same, order-independence.
- `testLogoutScreenLockUsers` — `logoutScreenLockUsers` clears the aggregate timeout.

  Provenance: introduced by `86266067e "Add privacy manifests"` (2023). Migration's
  `ScreenLockManagerTests.swift` contains only the **2 new** tests from ported unit #4045
  (`testDefaultConfiguration`, `testSettingScreenLockManagerConfiguration`); the singular
  `testShouldLock` landed in `BiometricAuthenticationManagerTests.swift`, but these **5 multi-user
  variants have no compiled home anywhere**. Prod APIs `storeMobilePolicy(...)`, `getTimeout()`,
  `logoutScreenLockUsers()` all still exist.
  **Escalation-class:** multi-user / account-switching behavior.

**`SFOAuthCoordinatorTests.testMigrateRefreshTokenSetup` — 1 dropped:**
  Verifies `migrateRefreshToken(_:)` sets `authInfo.authType = .refreshTokenMigration`, leaves
  `initialRequestLoaded == false`, and fires the failure callback when the user isn't logged in.
  Provenance: `f212fe7c6 "Additional tests for better coverage"` (2025-11). Prod method
  `SFOAuthCoordinator.migrateRefreshToken(_:)` still exists; **no Swift test covers it.**
  **Escalation-class:** OAuth / token-refresh path.

## Net-new migration tests (8, all SDKCore) — additive, not divergence
7× `CredentialsArchiveRoundTripTests` (`test_given…Archived…`) + 1×
`test_givenFreshUserAccountManager_whenReadingShowAuthWindowWhileLoading_thenDefaultsToTrue`.
These are migration-added coverage; no oracle counterpart. Not a concern.

## Recommendation
The 5 ScreenLock multi-user tests + `testMigrateRefreshTokenSetup` are the only **actionable new
findings**: real, currently-untested production behavior on escalation-class paths (account
switching + OAuth token migration). Porting them is a faithful ObjC→Swift restore against APIs that
still exist — but both land in escalation-class territory, so surface for human decision rather than
auto-porting. The other 5 drops are correctly closed (4 superseded, 1 = B2 blocked).
