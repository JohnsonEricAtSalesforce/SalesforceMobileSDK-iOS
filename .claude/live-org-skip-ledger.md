# Live-Org Skip Ledger — tests that DO NOT actually run locally (2026-07-17)

**Purpose (Task 11, item 3):** an explicit, honest list of test classes/methods that compile and are counted
as "present" but **do not execute** in the local/CI simulator run, so their green status is a SKIP, not a
PASS. This exists so future port work (and the upstream-sync gate) never mistakes "skipped" for "verified."

## Why these skip
All live-org tests authenticate against a real Salesforce org in `class func setUp()` via
`TestSetupUtils.synchronousAuthRefresh()`. The pre-token-refresh-coordinator OAuth refresh flow **hangs** in
the sim test host even with a curl-verified-valid token (see memory [[live-auth-abort-harden-2026-07-17]] /
tracker P0.2h). The hardening fix records `TestSetupUtils.authRefreshDidSucceed` instead of asserting, and
each live class does `try XCTSkipUnless(TestSetupUtils.authRefreshDidSucceed, ...)` in `setUpWithError` — so
these classes **cleanly SKIP** instead of aborting the run. They will execute only once the upstream token
refresh coordinator port lands (unblocking live auth). The merge-base oracle ALSO hangs live auth, so these
are "compare-when-live" on both sides.

## Live-org SKIP-gated classes

### SalesforceSDKCore (gate: `XCTSkipUnless(TestSetupUtils.authRefreshDidSucceed)` in each class)
- `RestClientPublisherTests`
- `RestClientTests`  ← class is `RestClientTests` (plural); the file is named `RestClientTest.swift` (singular). Also `RestClientWebSocketTests` lives in the same file. `-only-testing` filters must use the class name, not the file name.
- `SFSDKAuthUtilTests`
- `SalesforceRestAPITests`  ← includes the 45 restored dropped methods (2026-07-17) + `testAssertionForUnauthenticatedClient` (see below)

### MobileSync (gate: `XCTSkipUnless(TestSetupUtils.authRefreshDidSucceed)` in `SyncManagerTestCase.setUpWithError`, inherited by all subclasses)
- `SyncManagerTests`  ← includes the 3 restored dropped methods (2026-07-17)
- `SyncUpTargetTests`  ← includes the 2 restored dropped methods (2026-07-17)
- `SFSDKSyncsConfigTests`
- `SFLayoutSyncManagerTests`
- `BriefcaseSyncDownTests`
- `SFMetadataSyncManagerTests`
- `ParentChildrenSyncTests`

## Restored-but-not-running (recovered on paper, 2026-07-17)
The 51 dropped live-org methods restored under Task 9 all land in the classes above and therefore **SKIP**
until live auth works. Their oracle-comparison (Task 10) is deferred to when live auth is available; the
oracle hangs the same flow, so neither side runs them today. They are restored so the coverage EXISTS in
source and will execute the moment the coordinator port unblocks auth — closing the "hidden failure" gap the
operator flagged (a future REST/sync port can no longer pass green against absent tests).

## Documented-blocked (cannot run even with live auth, without new infra)
- `SalesforceRestAPITests.testAssertionForUnauthenticatedClient` — asserts an ObjC `NSException` is raised
  when the unauthenticated global `RestClient` makes an authenticated request. Swift can't catch ObjC
  `NSException` natively and this repo has no exception-catching bridge. The orphaned (non-compiled) `.m`
  claims to "preserve" it, but that file has no build-phase Sources entry. Restoring requires an ObjC
  exception-catcher test utility (future work). Left intentionally unrestored.

## How to retire entries here
When the token-refresh-coordinator upstream port lands and live auth succeeds in-sim, re-run each class
WITHOUT the skip and reconcile against the oracle per Task 10; move passing classes off this ledger. Until
then, any gate that reports these as "passing" must annotate them as SKIPPED.

---

## REVALIDATION 2026-07-19 — deferrals re-checked against current state (static/source; not a fresh live run)

Operator asked whether the deferred test items are now unblocked "now that we'd caught up on the porting
that deferral was based on." Traced the actual unblocker and its position in history:

- **The live-auth unblocker is upstream `997c4e09a` "Add token refresh coordinator" (PR #4087, dated
  2026-06-26).** Verified: it is **NOT** an ancestor of our drained marker `bac017113` — it was never in
  the 12-unit queue we drained. It **is** in the current `origin/dev` (`b155f785d`), i.e. it sits inside
  the **fresh 121-commit backlog** (46 first-parent units). **Conclusion: the porting is NOT caught up to
  the commit the deferral was based on** — the 51 restored live-org tests remain correctly SKIP-gated.
  Production footprint of the port (from the `.dev` oracle diff `997c4e09a^..8f597c962`): ~15 modified
  production files + 3 NEW (`SFSDKTokenRefreshCoordinator.h/.m`, `SFOAuthErrorCode.swift`); all
  ESCALATION-class (OAuth/token/credential). It is effectively the first big unit of the fresh backlog.

- **`testAssertionForUnauthenticatedClient` — infra blocker REMOVED, class-gate blocker REMAINS.** The
  ObjC exception-catch bridge `SFSDKCatchException()` now EXISTS (added 2026-07-18 for fidelity fix #3, in
  `SalesforceSDKCoreTests-Bridging-Header.h`). That was the sole reason this test was "documented-blocked."
  BUT it still lives inside `SalesforceRestAPITests`, whose class-level `XCTSkipUnless(authRefreshDidSucceed)`
  skips every method. Since the test targets the *unauthenticated* global client (no live org needed), it
  is the ONE deferred item that could run today IF relocated to a non-live-gated test class. Small, low-risk.

- **The 4 assertion-fidelity findings (#1/#2/#3-HIGH/#5) are already FIXED** (2026-07-18, verified green) —
  no longer deferred. See `.claude/task11-audits.md` "ALL FOUR FIDELITY FINDINGS FIXED."

**Net:** parity-with-oracle for the deferred tests = (a) port #4087 (large, ESCALATION) to make the 51
live-org tests execute + oracle-compare (Task 10), and optionally (b) relocate the one unauth test now.
Both are folded into the resume-porting plan; #4087 is a fresh-backlog unit, not a drained-queue leftover.

---

## LIVE EXECUTION + ORACLE COMPARE — 2026-07-20 (Phase 2, unit 44 landed → auth WORKS)

**#4087 token-refresh coordinator is now ported (Phase 1 unit 44).** Ran the scoped live-org classes
against a fresh operator token. **Live auth now completes** (`authRefreshDidSucceed` flips true; token is
reusable — 121+ refreshes in one run). The whole premise of this ledger (pre-coordinator hang) is resolved.
Oracle for compare = `.dev` clone @ `b155f785d` (has coordinator, runs live auth). Full detail:
`$CLAUDE_JOB_DIR/tmp/phase2-findings.md` (job 3073ad5d). Operator decision 2026-07-20: **REPORT ONLY, fix
nothing yet.** So NO code changed; ledger stays in force. Findings:

### SDKCore (migration ran, oracle compared)
- ✅ **RestClientTests 23/23 PASS**, **RestClientPublisherTests 4/4 PASS** — match oracle. These 2 classes
  (27 tests) are CLEAN and could be un-gated first when fix work resumes. NOTE ledger name bug: it says
  `RestClientTest`; the real class is **`RestClientTests`** (plural) — an `-only-testing` filter on the
  singular silently matches nothing.
- ✅ **SalesforceRestAPITests.testRedirect** = genuine BASELINE (401≠200 in BOTH oracle and migration).
- ⚠️ **7 DETERMINISTIC REGRESSIONS** (pass in oracle, fail in migration, re-confirmed in isolation):
  `SFSDKAuthUtilTests.testOpenIDToken` (memory P0.2e WRONGLY called this a baseline — oracle PASSES it),
  `SalesforceRestAPITests.testBlocks`, `testCollectionCreateWithBadRecordAndAllOrNoneFalse`,
  `…AllOrNoneTrue` (objectId `""`≠nil — type-narrowing smell), `testCreateQuerySearchDelete` (search nil≠1),
  `testRefreshNotificationWithValidGetRequest` (expectation(forNotification:) not registering; body is
  byte-faithful to the .m). Signatures lean test-port-fidelity, not necessarily prod regressions — each
  needs individual diagnosis.

### MobileSync (migration CRASHES; oracle compared)
- 💥 **Systemic test-only crash**: every live MobileSync test dies with `Fatal error: Negative value is not
  representable` — a Swift `UInt(negative)`/`Int(negative)` trap in a shared `SyncManagerTestCase` helper.
  ObjC oracle (`NSUInteger`) silently WRAPS → never crashed. Crash cascades (host restart loop) → poisons
  the whole suite → this is the SAME masking hazard we've fought (benign assert-fail becomes a whole-run abort).
- Trigger = `testCleanResyncGhostsForMRUTarget`, whose `203 vs 200` size mismatch is an **oracle-baseline
  data-pollution** issue (leftover accounts; FAILS in oracle too). Migration amplifies it into a fatal trap.
- The other 5 live methods (`testRefreshReSyncWithMultipleRoundTrips`, `testStopRestartMultipleSyncDowns`,
  `testStopRestartSingleSyncDown`, restored `testSyncUpManyLocallyCreatedRecords`, restored
  `testSyncUpWithLocallyUpdatedRemotelyDeletedRecordsWithoutOverwrite`) **PASS in oracle** but crash in
  migration (poisoned host). Fix the numeric-conversion trap (test-only) → their real pass/fail becomes readable.

### Retirement status
Ledger is NOT retired. Retire per-class as each matches oracle. Ready-now candidates (clean): RestClientTests,
RestClientPublisherTests. Blocked pending fixes: the 7 SDKCore regressions + the MobileSync crash.
Credential mechanic learned: `test_credentials.json` is a build-phase COPY → baked into the `.xctest` bundle;
refresh the file THEN `build-for-testing` (test-without-building uses the baked copy).

---

## MobileSync SUITE DRIVEN TO GREEN — 2026-07-21 (Phase 2, task #14)

Full `-only-testing:MobileSyncTests` run after the Phase-2 fixes: **0 failures, 0 fatal traps, 0 host
restarts** (was 234 tests / 43 failures + 14 latent store-nil host-crashes that xcodebuild retry-masked).

Fixes landed (all pushed to fork `feature/objc-to-swift-test-migration`):
- **c6045477e** batch 1 (7 fixes A–E: UInt(-1) trap, callback-queue deadlock, SFSyncOptions fieldlist,
  countIdsPerSoql visibility, reSync SOQL Optional("…")).
- **c20930fe1** [PROD] parent-children sync-UP was fully broken — `dict[key] as Any` boxed a Swift Optional
  into the children-lookup SmartSQL → `IN ('Optional(local_…)')` → 0 children → nothing pushed → records
  stayed dirty. Fixed at both call sites + defensive unwrapForSql() in getQueryForChildren.
- **aae35c2d1** [PROD] cleanResyncGhosts deleted NON-ghost records for ALL sync-down targets — Swift
  `NSMutableOrderedSet.array` is a frozen snapshot, but the code captured it BEFORE removeObjects(in:) (the
  ObjC oracle's `[localIds array]` was a live proxy). Snapshot ghost ids AFTER removal.
- **181386e4e** [PROD] no-type sync-up hit `/sobjects/` → 405; coerce empty objectType→"null" → 404 like
  oracle. [TEST] layout idempotency count query used literal "nil"; production stores "" → query with "".
- **be37d24eb / 8f9c0c545 / 5751605ca / 74567e3e7** [TEST-ONLY isolation hardening] store-nil host-crash:
  base setUp left IUO `store` nil on transient auth-cascade nil currentUser; subclasses force-unwrapped it in
  their own setUp → SIGTRAP killed the host (retry-masked). Guarded base soup helpers + skip guard + fixed
  Briefcase super-chaining.

### BriefcaseSyncDownTests — LIVE-ORG CONFIG BASELINE (skip-gated, NOT a regression)
All 7 BriefcaseSyncDownTests fail IDENTICALLY on the unmigrated oracle (.dev @ b155f785d): byte-for-byte
`sync status 2≠3`, `progress 0≠100`, `totalSize 24≠0`, `records 12≠0`. Cause: Briefcase / Priming Records is
an org feature that must be provisioned; the shared test org doesn't have it enabled, so every
BriefcaseSyncDownTarget sync-down returns totalSize 0 / no records. NOT a migration regression. This class
had never actually run before (its setUpWithError chained `super.setUp()` instead of
`super.setUpWithError()`, silently bypassing setUp); fixing that chaining unmasked the baseline. Skip-gated
with a documented XCTSkip (commit 74567e3e7) until the org is provisioned for Briefcase.

### MobileSync retirement status
The systemic UInt(negative) crash + all identified sync-engine regressions are FIXED; the MobileSync live
classes now pass or skip cleanly against the oracle. MobileSync side of the ledger is ready to retire (the
XCTSkipUnless(authRefreshDidSucceed) gates remain as the live-auth guard, which is correct — they skip only
when no live org is available). NEXT: SDKCore regressions #2–#7, then full ledger retirement.

## SDKCORE REGRESSIONS #2–#7 RESOLVED — 2026-07-22 (Phase 2 milestone 4)
All 7 flagged SDKCore live-org regressions resolved (6 pass + 1 documented skip, 0 failures).
See `.claude/phase2-regression-worklog.md` "SDKCORE REGRESSIONS #2–#7 RESOLVED" for full root-cause
detail + commit hashes. Summary:
- testOpenIDToken (271836232): skip-gated — live-org config baseline (no openid scope); oracle only
  passed via an ObjC→Swift non-nullable bridging quirk masking a genuine nil. NOT a regression.
- testCollectionCreateWithBadRecordAndAllOrNoneFalse/True (a88baa778): PROD public-API fix —
  restored SFSDKCollectionSubResponse.objectId to optional (String?), matching oracle's nullable
  NSString*. Escalation: public API surface → PR-flag.
- testRefreshNotificationWithValidGetRequest (bee3d8179): scoped sendSyncRequest wait (test fidelity).
- testBlocks (3177f3980): pass literal "(null)" objectType for metadata/describe (test fidelity).
- testCreateQuerySearchDelete (3177f3980): SOSL-escape the search term (test fidelity).
- testRedirect: confirmed baseline (401≠200 both clones), unchanged.

RestClientTests 23/23 + RestClientPublisherTests 4/4 already clean (documented 2026-07-20). The
SDKCore live-org test surface is now GREEN (modulo the documented testOpenIDToken + Briefcase config
baselines). NEXT: retire the MobileSync + SDKCore ledger classes per-class (task #17), then close
Phase 2 (task #19).

## PER-CLASS RETIREMENT — 2026-07-22 (Phase 2 milestone 3, task #17)
Full per-class live-auth verification against the shared test org (both schemes rebuilt + run;
oracle `.dev @ b155f785d`). RETIRED = the class runs live, matches oracle, and its only non-passes are
documented config baselines (clean XCTSkip) — the `XCTSkipUnless(authRefreshDidSucceed)` live-auth guard
STAYS on every class (correct: it skips only when no live org is available, e.g. credential-less CI).

**The full-class verify caught 2 failures the #18 method-targeted run had missed** (both fixed in commit
2df73b842) — evidence that per-class re-runs are worth doing before retiring:
- [PROD] `SFRestAPI+QueryBuilder.soqlQuery` used `Array(Set(fields))` → non-deterministic SOQL field order
  (Swift Set per-process randomized hash seed). `testSOQL` flipped pass↔fail between two runs. Fixed with
  order-preserving dedup. ESCALATION: public REST query-builder output → PR-flag.
- [TEST] `testUploadDownloadDeleteFileWithCommunity` — oracle's delete-by-sObject assertion was a vacuous
  unsigned-`NSUInteger` `.location >= 0` tautology; the Swift port made it a real check that correctly
  failed (delete-by-sObject URL is not community-scoped). Assert the true state.

### SDKCore — RETIRED (4 classes)
- `RestClientTests` — green (note: class is plural; file is `RestClientTest.swift`; `RestClientWebSocketTests` shares the file).
- `RestClientPublisherTests` — green.
- `SFSDKAuthUtilTests` — green; `testOpenIDToken` clean-skips (no-openid-scope config baseline).
- `SalesforceRestAPITests` — green modulo `testRedirect` (documented both-sides 401≠200 baseline).

### MobileSync — RETIRED (7 classes)
Full run 2026-07-22: `** TEST SUCCEEDED **`, 141 passed / 0 failed / 0 crash.
- `SyncManagerTests`, `SyncUpTargetTests`, `ParentChildrenSyncTests`, `SFSDKSyncsConfigTests`,
  `SFLayoutSyncManagerTests`, `SFMetadataSyncManagerTests` — all green.
- `BriefcaseSyncDownTests` — green; 7 methods clean-skip (Briefcase/Priming not provisioned = config baseline).

### Retirement environment note
`build-for-testing` + `test-without-building` can leave the SPM package framework (`SQLCipher.framework`)
unassembled in the products dir → `dyld: Library not loaded @rpath/SQLCipher.framework` at launch, and a
"Busy (Application failed preflight checks)" launch denial if the sim is contended by a prior run. Fix:
run a single-pass `xcodebuild test` (build+test together) and serialize sim execution across schemes.

Remaining before full ledger retirement (task #19): `testAssertionForUnauthenticatedClient`
(documented-blocked — needs ObjC-exception catch bridge; a bridge now exists but the test's class live-gate
would need relocation) is the only outstanding non-retired item. All other ledger classes are RETIRED.
