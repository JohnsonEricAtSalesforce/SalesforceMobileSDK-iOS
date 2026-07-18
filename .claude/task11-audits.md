# Task 11 — Pre-Port Due-Diligence Audits (2026-07-17)

Three audits requested before resuming the upstream port queue, to ensure the migration preserved test
*fidelity* (not just file/method presence). Status below.

---

## Audit 2 — SmartStore FTS4-vs-FTS5 double-run parameterization  ✅ PRESERVED

**Concern:** SmartStore historically runs each full-text-search test twice — once with the FTS4 SQLite
extension and once with FTS5 — to guard both engines. A migration that collapsed the pair would silently
halve FTS coverage.

**Method:** Python method-set diff (avoids the aisuite `rg` digit-mangling gotcha) of migration `.swift` vs
oracle `.m`.

**Findings:**
- `SFSmartStoreFullTextSearchTests`: migration **24** test methods = **12 Fts4 + 12 Fts5**; oracle identical
  (24 = 12 + 12). Dropped: **none**. Added: **none**. Helper calls: 12 `.fts4` + 13 `.fts5` (the extra
  `.fts5` is a `setupSoup(.fts5)`, not a test).
- `SFSmartStoreAlterTests`: the single FTS-alter test is present as `testAlterSoupWithFullTextIndexesFromFts4ToFts5`
  (migration capital `With`) vs oracle lowercase `with` — the previously-identified **case-only rename**, NOT
  a drop. This is the −1 "SmartStore false positive" in the drop diff.

**Verdict:** FTS4/FTS5 parameterization fully intact. No action.

---

## Audit 3 — Live-org skip ledger  ✅ DONE

Delivered as `.claude/live-org-skip-ledger.md` — an explicit list of the test classes that compile and count
as "present" but SKIP at runtime (live-org auth hangs pre-coordinator). Covers 4 SDKCore classes + 7
MobileSync classes (all `SyncManagerTestCase` subclasses), the 51 restored-but-not-running dropped methods,
and the 1 documented-blocked `testAssertionForUnauthenticatedClient` (needs an ObjC exception-catcher bridge).

**Verdict:** honest not-actually-running inventory now exists; any gate reporting these as "passing" must
annotate SKIPPED.

---

## Audit 1 — Assertion fidelity within surviving migrated methods  ✅ DONE (5 findings)

**Concern:** methods that survived the migration by name but had their assertions **weakened or swallowed**
during the ObjC→Swift port. The subtlest hidden-failure class: the test runs and passes but verifies less.

**Method:** per-method oracle-vs-migration assertion count/kind comparison across the NON-live deterministic
classes in SalesforceSDKCommon, SalesforceAnalytics, SalesforceSDKCore (non-live), SmartStore (~50 classes).

**Key negative result (important):** an initial scan flagged ~30 SmartStore methods with "100% assertion
drops" — on inspection these are **legitimate helper refactors**, NOT fidelity loss. The migration moved the
assertions into reusable helpers (`tryAllQuery`/`tryRangeQuery`/`alterSoupHelper` →
`runQueryCheckResultsAndExplainPlan` → `assertSameJSONArray` + `checkExplainQueryPlan`). Logic preserved.
Verdict: no action; the "drops" are counting artifacts of the delegation pattern.

**Findings — re-verified by hand against the oracle (subagent ranking corrected in 2 places):**
| # | Sev (verified) | Class.method (library) | Verified assessment |
|---|-----|------------------------|------|
| 3 | **HIGH** (was MED) | `SalesforceOAuthUnitTests.testCoordinatorDefaultInstantiation` (SDKCore) | **Worst of the set.** Migration DROPPED BOTH behavioral assertions — oracle had `XCTAssertThrows([coordinator authenticate])` and `XCTAssertThrows([coordinator authenticateWithCredentials:nil])`; the Swift version replaced them with a *comment* ("…causes a precondition failure. We verify…") and asserts only `XCTAssertNotNil(coordinator)`. The nil-credentials-throws contract is entirely unverified now. Restoring needs the nil-cred authenticate to actually throw catchably in Swift (may need an XCTAssertThrows-equivalent / precondition harness). |
| 1 | MED (was HIGH) | `SFSDKSafeMutableArrayTests.testConcurrentReadsAndRemoveAll` (Common) | Migration STILL performs the concurrent read (`_ = array.object(atIndexedSubscript: idx)` inside the enumerate+async block — so the thread-safety access IS still exercised) but discards the result instead of `XCTAssertNotNil(array[idx])`. Only the returned-value nil-check is lost; the race is still driven. Downgraded HIGH→MED: the concurrency exercise remains, only the per-element value-assert is gone. Also present in the Set/Dictionary variants. |
| 2 | MED | `SFLoggerTests.testLoggerInstance` (Common) | Confirmed. Dropped `isKindOfClass:[TestLoggingImpl class]` impl-class assertion; also switched accessor (`TestLogger.sharedInstance` → `SalesforceLogger.logger(forComponent:)`). No longer confirms the injected logger impl type. |
| 5 | LOW | `SFSmartStoreTests.testSmartStoreIsRecreatedWhenKeyIsLost` (SmartStore) | Confirmed minor. Uses `try?`/helper paths that don't assert every setup step's success (oracle asserted more intermediate states). Core behavior (soup exists after reopen; soup gone after key drop) still asserted. |
| 4 | **NOT A LOSS** (was MED) | `SFSmartSqlTests.testNonSmartQueryUsingWhereArgs` (SmartStore) | **Cleared.** The `3→1` count was a false positive: the migration uses the Swift `throws` idiom — `XCTFail` if no throw + asserts the SAME error message in `catch`. Oracle's nil-result + non-nil-error checks are subsumed by "it threw." Faithful adaptation, no action. |

**Verified severity order:** #3 (HIGH, real coverage gap — nil-cred throw unverified) > #1, #2 (MED) > #5 (LOW). #4 is not a finding.

---

## #3 ROOT CAUSE + FIX PLAN — Option B approved (2026-07-18), production+test, ESCALATION-GATED (OAuth)

**Not a test-only issue — there's a production migration artifact underneath.** The oracle's ObjC `NSAssert`
compiles to a catchable `NSException`, which `XCTAssertThrows` verifies. The migration replaced it with a
private shim `SFOAuthCoordinator.swift:960` `private func NSAssert(_ condition: @autoclosure ()->Bool, _ message: String) { assert(condition(), message) }`
— Swift `assert` **`abort()`s the process in debug (uncatchable, would kill the test host — same abort-masking
class as P0.2h) and is COMPILED OUT in release**. So the migrated `authenticate()` / `authenticate(withCredentials:)`
nil/empty-credentials guard changed contract from "raises a catchable exception" to "hard-trap (debug) / no-op
(release)". That's a behavior divergence from the oracle on a public OAuth entry point, not just a weaker test.

**Guards in migrated `authenticate()` (SFOAuthCoordinator.swift:172-177):** credentials != nil; clientId
non-empty; identifier non-empty; domain non-empty; delegate != nil. Oracle .m had the same 5 NSAsserts
(SFOAuthCoordinator.m:130-134). `authenticate(withCredentials:)` (line 261) assigns creds then calls
`authenticate()`. Other NSAssert sites in the migrated coordinator (JWT ~line for jwt.length, mydomain
discovery domain/clientId/redirectUri) share the SAME shim — decide whether the fix touches only the shim
(fixes all sites) or just the authenticate guards.

**Option B (APPROVED) plan — DO NOT START until compact is done and we resume:**
1. Make the nil/empty-credential guard raise a **catchable** failure faithful to the oracle. Cleanest: change
   the private `NSAssert` shim to raise an `NSException` (ObjC-catchable, matches oracle semantics) instead of
   Swift `assert` — OR add explicit `NSException.raise(...)` in the authenticate guards. Prefer the shim change
   only if all its call sites should be catchable-raising (verify each site's intent first; some may legitimately
   want a fatal precondition). Confirm behavior parity vs oracle at merge-base `6ed0ab408` (/tmp/oracle-base).
2. Restore the test `testCoordinatorDefaultInstantiation` to assert `XCTAssertThrows`/`XCTAssertThrowsError`
   on `authenticate()` and `authenticate(withCredentials: nil-equivalent)` — matching the oracle's 3 asserts
   (notNil + 2 throws). Note: Swift can't pass literal `nil` to the non-optional `authenticate(withCredentials:)`
   param; use the `authenticate()`-with-unset-credentials path or an ObjC-bridged throw catcher (there is NO
   exception-catch bridge in the repo yet — same blocker as testAssertionForUnauthenticatedClient; may need to
   add one, or use XCTAssertThrowsError against an NSException-raising path reachable from Swift).
3. **ESCALATION**: this changes OAuth-coordinator production behavior (public API) → per CLAUDE.md must stay
   operator-approved (it is, Option B) and flagged for human review in the eventual PR. Build BOTH schemes green
   + verify the guard now raises catchably in a focused run. Consider whether release-build no-op behavior is
   acceptable or the guard should be a real runtime check (NSException) that survives release optimization.
4. Deliberate oracle divergence note: if we intentionally differ, mark it (like the P0.2h marker) so a future
   merge surfaces it.
**Risk to watch:** an uncatchable trap or a release-stripped guard reintroduces the abort/masking failure mode;
the whole point is a CATCHABLE raise. Also: raising on release changes prod behavior for real callers — confirm
no legitimate caller depends on the current silent no-op.

**Clean (no loss):** SalesforceAnalytics (EventStoreManager, InstrumentationEventBuilder); Common
(SafeMutableDictionary/Set); SDKCore non-live (SFOAuthCredentials, SFPushNotificationManager,
SFUserAccountManager, SFSDKURLCache, SFNetwork, SFEncryptionKey, SFSDKCryptoUtils, +15 more); SmartStore
(AlterTests [after helper accounting], SmartSqlCache, QuerySpec, StoreConfig, MultipleSmartStores).

**Status:** findings recorded for operator triage. These are surviving-method weakenings (NOT part of the
dropped-method restore). 4 genuine (1 HIGH #3, 2 MED #1/#2, 1 LOW #5); #4 cleared. **Deferred to operator** —
not auto-fixing, since restoring these assertions (esp. #3's nil-cred throw) could surface pre-existing
failures that need their own oracle triage, and none block the port queue (they weaken coverage, they don't
hide dropped tests — that risk is closed by the restore). Recommend fixing #3 before the port queue touches
OAuth-coordinator code; #1/#2/#5 opportunistically.

---

## ✅ ALL FOUR FIDELITY FINDINGS FIXED (2026-07-18) — operator: "Fix #1,2,5 and 3 now."

Each fix is faithful to the oracle and was individually **built + run green** (per-scheme, verified by me — not a subagent claim). Test/production classification per finding:

| # | Fix | Files | Test or Prod | Verified |
|---|-----|-------|--------------|----------|
| 1 | Restored the in-race assertion. Migrated `object(atIndexedSubscript:)` returns non-optional `Any` (NSNull() sentinel), so `XCTAssertNotNil` would warn "never nil" (= a bug per CLAUDE.md) → asserted `XCTAssertFalse(… is NSNull)`, faithful to oracle intent. Set variant already faithful (oracle Set had no in-block assert either); only Array touched. | `SFSDKSafeMutableArrayTests.swift` | **test-only** | pass (0.300s) |
| 2 | Restored impl-type assertion. Facade held `loggingImpl` `private` → added `internal var underlyingLoggerImpl` (test-visible via `@testable`, NOT public API) + `XCTAssertTrue(logger.underlyingLoggerImpl is TestLoggingImpl)`. | `SFLogger.swift` (prod, internal accessor) + `SFLoggerTests.swift` | **test-only** (internal accessor, no public surface change) | pass |
| 5 | Restored the intermediate setup assert the migration's `if let` skipped: oracle `@finally` unconditionally restores+asserts the key → added `XCTAssertNotNil(originalKey, …)` so the restore path is always exercised. | `SFSmartStoreTests.swift` | **test-only** | pass (0.269s) |
| 3 | **PRODUCTION + test, ESCALATION-GATED (OAuth) — flag in PR.** Changed the private `NSAssert` shim (SFOAuthCoordinator.swift:960) from Swift `assert()` (uncatchable abort in debug / compiled-out in release) to raise a catchable `NSException(.internalInconsistencyException)` — faithful to the oracle ObjC `NSAssert` at ALL its call sites (all were `NSAssert`). Added a header-only `static inline SFSDKCatchException()` ObjC catch bridge to the existing `SalesforceSDKCoreTests-Bridging-Header.h` (NO new file / NO xcodeproj change). Restored `testCoordinatorDefaultInstantiation` to assert `authenticate()` raises (caught via the bridge). Oracle's 2nd assert (`authenticateWithCredentials:nil`) is now unrepresentable — migrated param is non-optional `OAuthCredentials`, nil prevented at compile time. | `SFOAuthCoordinator.swift` (prod shim) + `SalesforceSDKCoreTests-Bridging-Header.h` + `SalesforceOAuthUnitTests.swift` | **PROD + test** | pass (0.002s, throw now genuinely exercised) |

**Build gate:** SalesforceSDKCore, SmartStore, SalesforceSDKCommon all `build-for-testing` GREEN (verified by me).
**Env note:** SmartStore single-test `test-without-building` crashed at bootstrap with `Library not loaded: @rpath/SQLCipher.framework/SQLCipher` — a **stale-DerivedData artifact** (SQLCipher.framework was pruned as "stale" and not re-copied), reproduced on an UNTOUCHED control test, NOT caused by the edit. A full `test` (rebuilds/copies SQLCipher) resolved it; #5 then passed.
**#3 escalation reminder:** production OAuth public-behavior change — must be flagged for human review in the eventual PR (operator pre-approved Option B). Shim change is shared by JWT + mydomain-discovery guards too; all were oracle `NSAssert`, so catchable-raise is faithful across all sites. Deliberate divergence from the (buggy) migrated behavior back toward oracle — mark for future merge awareness.
