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

## UNRESOLVED — NOT baselined (tracker finding P0.2d) — SalesforceSDKCore migration-artifact crashes

Distinct from the (now-fixed) credentials cluster. Root-caused 2026-07-14: **three independent
migration artifacts** where a Swift construct crashes on input the ObjC original tolerated. All are
production-Swift bugs (not test bugs) introduced by the ObjC→Swift migration, provable by: the ObjC
`.m` reference tolerates the same input, and the tests are byte-equivalent to their passing `.m`
originals.

**Sub-cause A — `SFSDKAuthCommand.requestURL()` empty-string asserts (DOMINANT, ~22 crashes).**
`SFSDKAuthCommand.swift:47-50` asserts `scheme`/`path`/`version`/`command` are non-empty. In Swift
these properties default to `""`; `path` is never set by the SP/IDP command subclasses (and `path`
is NOT even used to build the URL — line 52 uses scheme/host/version/command only). ObjC defaulted
them to `nil`, and `[nil sfsdk_isEmptyOrWhitespaceAndNewlines]` returns `NO`, so `NSAssert(NO==false)`
= `NSAssert(true)` PASSED. Swift `"".isEmpty == true` → `assert(false)` → CRASH. The migration
translated `nil`-tolerant ObjC asserts into empty-string-fatal Swift asserts.
- Fix candidate: remove the `path` assert (it is dead — `path` is unused in `requestURL()`), OR relax
  the asserts to match ObjC nil-tolerance. Do NOT "fix" by making tests set a dummy path — that hides
  a real production behavior change (fresh command now crashes where it used to build a URL).
- Tests hit: `SFSDKURLHandlerManagerTest` (×7), `SFSDKIDPLoginRequestCommandTest`,
  `SFSDKAuthRequestCommandTest`, `SFSDKIDPAuthCodeLoginRequestCommandTest`,
  `SFSDKSPLoginResponseCommandTest`, `SalesforceOAuthUnitTests`.

**Sub-cause B — `SFSDKEncryptedURLCache` unimplemented designated initializer (~6 crashes).**
Fatal: "Use of unimplemented initializer 'init(memoryCapacity:diskCapacity:diskPath:)'". The ObjC
class implemented `initWithMemoryCapacity:diskCapacity:directoryURL:` forwarding to `super`; the Swift
migration replaced it with a `cacheDirectory:` convenience init that calls `self.init()` and does NOT
override URLCache's designated initializers. When `URLSession`/`URLCache.shared` instantiates the
cache via the standard `init(memoryCapacity:diskCapacity:diskPath:)`, Swift traps.
- Fix candidate: override the real URLCache designated initializer(s) forwarding to `super`, matching
  the ObjC surface. Production bug (affects any consumer setting an encrypted shared cache).
- Tests hit: `SFSDKUrlCacheTests` (testRestCalls, testSettingCacheTypes, testNilURL).

**Sub-cause C — `SFRestAPIDataTaskRaceTests` index-out-of-range (~4 crashes, likely TEST-only).**
`ContiguousArrayBuffer:692` via `DeferredURLProtocol.pendingProtocols[index]` (line 71). A test-harness
race: `deliverResponse(at:)` indexes the pending-protocols array before the protocol has registered.
This is the ONE sub-cause that looks like a test-infra bug, not a production migration artifact.
- Fix candidate: guard the index / wait for registration in the test harness.

**Deliberately NOT baselined** (would be laundering; A/B are real production regressions that must be
FIXED, not accepted). The cascade inflates the reported set to ~71; the true root-crash set is the
~11 classes above. Full SDKCore gate remains provisional until A + B (production) are fixed; C is
test-only. All three are separate from the credentials fix.

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
