# Test Baseline — Upstream Sync Verification Gate

**Purpose:** Authoritative set of *known, non-regression* test failures. The sync-job
verification gate (see `.claude/upstream-sync-job.md` Step 5) passes only if the failing-test
identifiers after a port are a **subset** of this set. Any failure whose identifier is NOT
listed here is a candidate regression → **GATE FAIL**, diagnose before advancing the marker.

**This is a shrinking ratchet.** Entries may be *removed* when fixed (P1 FTS work) or when CI
gains coverage. Entries may be *added* only by explicit operator decision with recorded rationale
— never silently, to avoid laundering a new regression into "expected."

**Baseline is keyed on identifiers, not counts.** A count-based gate ("≤N failures") is fooled
when composition changes (one new break + one coincidental pass = same count). Match the *set*.

---

## SmartStore

### `assertion-bug` — FTS AlterTests (P1 follow-up: fix assertion logic)

Confirmed empirically 2026-07-05 (SmartStore scheme). 6 test methods; each runs under both FTS4
and FTS5 configs, so ~12 *executions* fail — this reconciles the 2026-05-25 gate report's
"12 expected failures" vs. "6 FTS tests" wording (both correct, counted differently).
Failure signature: `XCTAssertEqual failed … Wrong columns actual: TABLE__…` in `SFSmartStoreAlterTests.swift`.

- `SFSmartStoreAlterTests/testAlterSoupTypeChangeFullTextToJSON1`
- `SFSmartStoreAlterTests/testAlterSoupTypeChangeFullTextToString`
- `SFSmartStoreAlterTests/testAlterSoupTypeChangeJSON1ToFullText`
- `SFSmartStoreAlterTests/testAlterSoupTypeChangeStringToFullText`
- `SFSmartStoreAlterTests/testAlterSoupWithFullTextIndexesFromFts4ToFts5`
- `SFSmartStoreAlterTests/testAlterSoupWithFullTextIndexesToGetIndexesOnCreatedAndLastModified`

### `pre-existing-nonflaky` — 2 failures unmasked by the P0.2b fix (operator-approved 2026-07-14)

When the P0.2b setUp crash was fixed (see below), these two tests — previously hidden behind the
crash — began executing and failing. They are NOT credentials-related and NOT caused by the fix;
the crash was masking them. Added to the baseline by explicit operator decision with rationale:

- `SFMultipleSmartStoresTests/testGetGlobalStoreNames` — asserts exactly 3 global stores
  (`XCTAssertTrue(array.count == 3)`); fails on global-store test-isolation/ordering sensitivity, not
  on the code under test. Candidate for a follow-up test-isolation fix.
- `SFSmartSqlTests/testCleanupRegexpFaster` — a **performance/timing** assertion
  (`newRegexp × 500 < oldRegexp` and `< 25ms`); inherently load-sensitive (violates the project's
  "no timing-based tests" standard). Candidate to rewrite or remove. NOTE: being timing-based it may
  intermittently PASS — a shrinking-ratchet pass (fewer failures than baseline) is still a gate PASS.

### `env-skip` — MobileSync integration (verified in CI only)

Per gate report: `SyncManagerTestCase` `class setUp()` blocks on `synchronousAuthRefresh()`;
the auth run-loop doesn't integrate with xcodebuild locally. Not counted as pass; deferred to CI.
(Lives in MobileSync scheme; listed here as part of the single baseline registry.)

---

## ✅ RESOLVED 2026-07-14 (tracker finding P0.2b) — SmartStore setUp crash cluster

The 2026-07-05 run showed ~35 setUp crashes in `SFSmartSqlTests.createUserAccount()` and
`SFMultipleSmartStoresTests.setUpSmartStoreUser()` (47 total failures). **Root cause = the
`OAuthCredentials(identifier:clientId:encrypted:)!` convenience-init-returns-nil bug** (class-cluster
design: keychain storage requires the `OAuthKeychainCredentials` subclass; the base convenience init
returns nil by design). The prior fix `f11e4754f` patched `SFSmartStoreTestCase.swift` but MISSED
these two files.

**Fix (2026-07-14):** swapped both sites to the factory
`OAuthCredentials.credentials(identifier:clientId:encrypted:)`. Verified: SmartStore run went
**47 failures / ~35 crashes → 14 failures / 0 crashes**. The 14 = 12 baselined FTS executions + the
2 `pre-existing-nonflaky` failures now listed in the baseline above. **SmartStore gate is now clean**
(subset of baseline). See tracker P0.2b.

---

## ◐ PARTIALLY RESOLVED 2026-07-14 (tracker finding P0.2c) — SalesforceSDKCore credentials crash cluster

The 2026-07-14 SalesforceSDKCore run (during the #4043 gate) surfaced a large crash cluster.
**The credentials portion — same `OAuthCredentials(...)!` root cause as P0.2b — is now FIXED:** all 10
SDKCore test-helper sites swapped to the `.credentials(...)` factory (2026-07-14). The
credentials-driven crashes are gone (`SFUserAccountManagerTests:649`, `SFUserAccountPhotoTests:71`,
`SalesforceRestAPITests:1147`, `BiometricAuthenticationManagerTests:187`, `NativeLoginManagerTests:129`
no longer crash).

**A DISTINCT second cluster remains → see P0.2d below.** SalesforceSDKCore gate stays **provisional**
until P0.2d is resolved. Until then a port is verifiable against SDKCore only by *scoped* evidence:
build ✓ + the tests nearest the change pass + no failure touches the changed code (how #4043 was
accepted).

## UNRESOLVED — NOT baselined (tracker finding P0.2d) — SalesforceSDKCore assert() crash cluster

Distinct from the (now-fixed) credentials cluster. After the P0.2c credentials fix, the SDKCore run
still shows crashes from **debug `assert()` failures in production Swift** when tests construct
command/URL/cache objects with empty scheme/path:
- `SFSDKAuthCommand.swift:48` — `assert(!path.sfsdk_isEmptyOrWhitespaceAndNewlines(), "Path cannot be nil")` (dominant, ×22)
- `SFOAuthCoordinator.swift:961` (NSAssert helper) ×4 · `SFSDKEncryptedURLCache.swift:37` ×6
- `ContiguousArrayBuffer.swift:692` (index-out-of-range) ×4

Concentrated in these test classes (crash → cascade fans out to ~71 reported failures, but the true
crashing set is ~11 classes): `SFSDKURLHandlerManagerTest` (×7), `SFSDKUrlCacheTests` (×3),
`SFSDKIDPLoginRequestCommandTest`, `SFSDKAuthRequestCommandTest`, `SFSDKIDPAuthCodeLoginRequestCommandTest`,
`SFSDKSPLoginResponseCommandTest`, `SalesforceOAuthUnitTests`, `SFRestAPIDataTaskRaceTests`,
`PushNotificationManagerTests`, `SFUserAccountManagerPersisterTests`, `BiometricAuthenticationManagerTests`
(a different site, `:85`, not the credentials one).

**Deliberately NOT baselined** (would be laundering, and the cascade makes the set unstable). Root
cause is likely test setup passing empty scheme/path into command objects (or an `assert` that should
be a graceful nil-return / precondition documented for tests). Needs a separate investigation pass —
NOT the credentials fix. Full SDKCore gate remains provisional.

## Provenance

| Field | Value |
|-------|-------|
| Last confirmed | 2026-07-05 (SmartStore scheme, empirical run) |
| Simulator | runtime-resolved iPhone (name-agnostic per P0.1) |
| Run totals | 177 executed / 130 passed / 47 failed / 0 skipped |
| Baseline (assertion-bug) | 6 FTS methods (~12 executions) |
| Quarantined (not baselined) | ~35 setUp-crash cases → P0.2b |
| Not run locally | MobileSync integration (env-skip) |

> Re-confirm this baseline whenever the toolchain (Xcode/simulator/runtime) changes — a device
> first-booted for a fresh run can shift environment-sensitive behavior.
