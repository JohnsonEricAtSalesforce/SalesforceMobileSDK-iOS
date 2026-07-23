# Phase 2 — Live-Org Regression Worklog (durable)

**Purpose:** the interactive worklist for completing Phase 2. We work through each regression one at a
time (root cause → fix → re-run vs oracle → un-gate the class → retire its ledger entry). Green = matches
oracle. Update the status column as we go. See also `.claude/live-org-skip-ledger.md` (gate) and memory
`project_phase2_live_org_findings.md`.

State when this began: HEAD `7eaeafa5a`, marker `b5d37d807` (Phase 1 complete). Live auth WORKS (unit 44
coordinator). Oracle = `.dev` clone @ `b155f785d`. Migration DD=ajvcdis, oracle DD=daxfbop. Fresh token
must be re-baked into the `.xctest` bundle via `build-for-testing` after refreshing `shared/test/test_credentials.json`.

## Summary table — Oracle vs Migration (before → after)

`before` = every scoped live-org test was SKIPPED (the ledger gate). `after` = executes now.

| # | Test / class | Oracle | Before | After | Verdict | Status |
|---|---|:--:|:--:|:--:|---|---|
| — | RestClientTests (23) | ✅ 23/23 | SKIP | ✅ 23/23 | ✅ clean, un-masked | READY TO UN-GATE |
| — | RestClientPublisherTests (4) | ✅ 4/4 | SKIP | ✅ 4/4 | ✅ clean, un-masked | READY TO UN-GATE |
| — | SalesforceRestAPITests · testRedirect | ❌ 401≠200 | SKIP | ❌ 401≠200 | ✅ BASELINE (both) | NO ACTION (document) |
| 1 | MobileSync — all live sync tests | 5 pass / 1 data-baseline | SKIP | 💥 all CRASH | ⚠️ PRODUCTION crash (SFSyncTask) | 🔧 IN PROGRESS |
| 2 | RestAPI · testCollectionCreateWithBadRecordAndAllOrNoneFalse | ✅ | SKIP | ❌ objectId ""≠nil | ⚠️ regression | PENDING |
| 3 | RestAPI · testCollectionCreateWithBadRecordAndAllOrNoneTrue | ✅ | SKIP | ❌ objectId ""≠nil | ⚠️ regression (twin of #2) | PENDING |
| 4 | RestAPI · testRefreshNotificationWithValidGetRequest | ✅ | SKIP | ❌ wait w/o expectations | ⚠️ regression | PENDING |
| 5 | RestAPI · testBlocks | ✅ | SKIP | ❌ "unexpected success" | ⚠️ regression | PENDING |
| 6 | RestAPI · testCreateQuerySearchDelete | ✅ | SKIP | ❌ search nil≠1 | ⚠️ regression (verify not SOSL-flake) | PENDING |
| 7 | SFSDKAuthUtilTests · testOpenIDToken | ✅ | SKIP | ❌ idToken nil | ⚠️ regression | PENDING |

## Chosen working order & rationale
1. **MobileSync SFSyncTask crash** — FIRST. It's PRODUCTION (not test), SEVERE (breaks every real sync
   up/down at runtime), has a crisp root cause + fix, and unblocks 5 of 6 MobileSync live tests at once.
   Highest severity × highest leverage.
2. **#2 + #3 together** — the two `testCollectionCreateWithBadRecord…` twins share one `objectId ""≠nil`
   signature → almost certainly one shared cause (CollectionResponse parsing / type-narrowing). Fix as a pair.
3. **#4 testRefreshNotificationWithValidGetRequest** — expectation(forNotification:) not registering; test
   body is byte-faithful, so suspect a bridged notification-name or userInfo-key constant.
4. **#5 testBlocks** — "unexpected success" (a describe response came back where an error was expected).
5. **#6 testCreateQuerySearchDelete** — re-confirm it's a true regression vs a SOSL index-settle timing flake
   (it took 53s). If timing, handle differently from a code regression.
6. **#7 testOpenIDToken** — id_token nil; org-config-sensitive, do last. NOTE: memory
   [[project_p02e_triage]] wrongly called this a baseline — oracle PASSES it → real regression; correct that memory.
- testRedirect = baseline, no code action (document as a known both-sides failure).

---

## FINDING #1 — MobileSync `SFSyncTask.updateSync` crashes on the `kSyncManagerUnchanged` sentinel (PRODUCTION)

**Severity: HIGH / production.** Not test-only (my earlier report was wrong — the crash backtrace lands in
production `MobileSync.framework`, not the test helper). This breaks **every real sync operation** in the
migrated SDK; it was hidden only because all live-org MobileSync tests were skip-gated.

### Crash backtrace (from xcresult .ips, EXC_BREAKPOINT/SIGTRAP)
```
libswiftCore   _assertionFailure(…)                         ← "Negative value is not representable"
MobileSync     SFSyncTask.updateSync(_:countSynched:)  @ SFSyncTask.swift:90
MobileSync     SFSyncTask.init(_:sync:updateBlock:)     @ SFSyncTask.swift:51
MobileSync     SFSyncUpTask.init(…)                     @ SFSyncUpTask.swift:34
MobileSync     SFMobileSyncSyncManager.runSync(…)       @ SFMobileSyncSyncManager.swift:354
MobileSyncTests … trySyncUp … testSyncUpWithLocallyCreatedRecordsWithoutOverwrite
```

### Root cause
`kSyncManagerUnchanged` is a **-1 sentinel**:
- ObjC (oracle): `NSInteger const kSyncManagerUnchanged = -1;` and `updateSync:(NSUInteger)countSynched`.
  Call sites pass `kSyncManagerUnchanged` (an `NSInteger` `-1`) into an `NSUInteger` param → C implicitly
  converts `-1` → `NSUIntegerMax` (bit-pattern wrap, no trap). The guard `if (countSynched != kSyncManagerUnchanged)`
  promotes `-1` to `NSUIntegerMax` too, so `NSUIntegerMax != NSUIntegerMax` is **false** → progress calc skipped.
  Everything is internally consistent and never traps.
- Swift (migration): `public let kSyncManagerUnchanged: Int = -1` and `func updateSync(_ , countSynched: UInt)`.
  - `SFSyncTask.swift:67` and `:84`: `updateSync(sync, countSynched: UInt(kSyncManagerUnchanged))` →
    `UInt(-1)` is a **checked conversion that TRAPS** ("Negative value is not representable").
  - `SFSyncTask.swift:90`: `if countSynched != UInt(kSyncManagerUnchanged)` → evaluates `UInt(-1)`
    **unconditionally, on every call**, even the benign `updateSync(sync, countSynched: 0)` from `init` line 51.
- Net: the very first `updateSync` any sync makes (from `SFSyncTask.init` → line 51 → line 90) evaluates
  `UInt(-1)` and traps. So **all** sync-up/down runs crash the process. `SFSyncState` config CRUD tests
  (testAddFilterForResync, etc.) pass because they never construct an `SFSyncTask`.

`Swift's UInt(Int)` is a **trapping** initializer; ObjC's implicit `NSInteger→NSUInteger` is a **wrapping**
reinterpretation. The migration preserved the value `-1` and the type `UInt` but not the *conversion semantics*.

### Suggested resolutions (ranked)
**A — RECOMMENDED: bit-pattern reinterpret at the three sentinel sites (byte-faithful to ObjC, no API change).**
Keep the public constant `kSyncManagerUnchanged: Int = -1` (matches the exposed `extern NSInteger`), keep the
public `countSynched: UInt` param (matches ObjC `NSUInteger`). Replace `UInt(kSyncManagerUnchanged)` with
`UInt(bitPattern: kSyncManagerUnchanged)` at lines 67, 84, 90. `UInt(bitPattern: -1) == UInt.max`, exactly
reproducing the ObjC `NSUInteger` wrap, so the guard becomes `UInt.max != UInt.max` → false → identical
behavior. Cleanest form: a `private static let unchangedSentinel = UInt(bitPattern: kSyncManagerUnchanged)`
used at all three spots.
- Pros: preserves public API (`NSUInteger`/`Int` constant), byte-faithful runtime semantics, minimal.
- Cons: none material.

**B — Change `countSynched` param + comparison to `Int`.** Signature `updateSync(_ , countSynched: Int)`,
guard `countSynched != kSyncManagerUnchanged`, progress `Int(countSynched) * 100 / sync.totalSize`.
- Pros: the sentinel is conceptually a signed value; reads naturally.
- Cons: **changes the `@objc open` public API** from `NSUInteger` to `NSInteger` — a public-surface divergence
  from the oracle (escalation), and it ripples to `shouldStop`/`failSync`/subclasses. Rejected for compat.

**C — Redefine the sentinel as `UInt.max`.** Rejected: the public `.h` exposes `kSyncManagerUnchanged` as
`NSInteger`; the Swift twin must keep it `Int = -1` to match the published constant.

### Escalation
This is a **production MobileSync change** (sync engine). Not in the OAuth/SQLCipher/credential escalation
class, but any production change → **flag for human PR review**. It is also a genuine shipped-regression fix
(the migrated SDK cannot currently perform a sync), which strengthens the case to land it.

### Verification plan
Apply fix A → `build-for-testing` MobileSync → run the 6 live methods → expect the 5 oracle-passing tests to
PASS and `testCleanResyncGhostsForMRUTarget` to FAIL cleanly with `203 vs 200` (matching oracle's data-baseline,
no longer a crash). Then re-run the full MobileSync live suite for any further divergence.

### ▶ NEXT ACTION (on "Continue" after compact) — APPLY FIX A, operator-approved 2026-07-21
Exact edit to `libs/MobileSync/MobileSync/Classes/Manager/SFSyncTask.swift`:
1. Add near the constant / inside the class a single reused sentinel:
   `private static let unchangedSentinel = UInt(bitPattern: kSyncManagerUnchanged)`  (= UInt.max, wraps like ObjC)
2. Replace the 3 trapping call sites:
   - line 67  `updateSync(sync, countSynched: UInt(kSyncManagerUnchanged))` → `...countSynched: Self.unchangedSentinel)`
   - line 84  same replacement
   - line 90  `if countSynched != UInt(kSyncManagerUnchanged)` → `if countSynched != Self.unchangedSentinel`
   (Do NOT change the public `kSyncManagerUnchanged: Int = -1` constant or the `countSynched: UInt` param — keep API.)
Then: `build-for-testing` MobileSync (DD=ajvcdis, sim iPhone 17 id D40BDFBC-59B1-4726-9F65-2E331CEAFFEE) → run
the 6 live methods (SyncManagerTests testRefreshReSyncWithMultipleRoundTrips / testStopRestartMultipleSyncDowns /
testStopRestartSingleSyncDown / testCleanResyncGhostsForMRUTarget ; SyncUpTargetTests testSyncUpManyLocallyCreatedRecords /
testSyncUpWithLocallyUpdatedRemotelyDeletedRecordsWithoutOverwrite). PREREQ each live run: refresh
`shared/test/test_credentials.json` if stale then build-for-testing so the fresh token is baked into the .xctest bundle.
This is a PRODUCTION MobileSync change → flag for human PR review. Commit only when operator asks.

### ✅ FIX A APPLIED 2026-07-21 — and EXTENDED (a second trap was hiding behind the first)
Applied the planned edit to `SFSyncTask.swift`:
- Added `private static let unchangedSentinel = UInt(bitPattern: kSyncManagerUnchanged)` (= UInt.max).
- Replaced the 3 `UInt(kSyncManagerUnchanged)` sites (lines ~72/89/95) with `Self.unchangedSentinel`.
- Public constant `kSyncManagerUnchanged: Int = -1` and the `countSynched: UInt` param UNCHANGED.

**First re-run surfaced a SECOND, distinct negative→unsigned trap** the sentinel fix alone didn't cover:
the progress arithmetic `Int(countSynched * 100 / UInt(sync.totalSize))`. A sync-down starts with
`SFMobileSyncSyncManager.swift:425` setting `sync.totalSize = -1` (unknown-size sentinel); the very first
`updateSync(sync, countSynched: 0)` from `SFSyncTask.init` passes the guard (0 ≠ sentinel) and then
evaluates `UInt(sync.totalSize)` = `UInt(-1)` → **traps**. The ObjC oracle computed the whole expression in
`NSUInteger` (`countSynched*100/sync.totalSize`), so `-1` wrapped to `NSUIntegerMax` and `0*100/max = 0` — no
trap. Same root cause (Swift traps where ObjC wraps), same idiom to fix:
`sync.progress = sync.totalSize == 0 ? 100 : Int(bitPattern: countSynched &* 100 / UInt(bitPattern: sync.totalSize))`
(bit-pattern reinterpret + wrapping multiply → byte-faithful to the ObjC NSUInteger math).

**Result after the extended fix:** the crash cascade is GONE. Confirmed decisively — even
`testStopRestartSingleSyncDown` (a MOCK `TestSyncDownTarget`, no live sync network) now runs test logic
instead of trapping in `SFSyncTask.init`. Fix A is a real, verified PRODUCTION regression fix (the migrated
SDK could not perform ANY sync before it). ✅ FINDING #1 CODE FIX = DONE.

### ⚠️ FINDING #1b — a SECOND blocker was hiding behind the crash: a 0%-CPU DEADLOCK in the sync path
With the trap gone, all 6 MobileSync live methods now progress into test logic but then **hang at 0% CPU**
(observed 8–19 min, killed manually). This was fully MASKED before Fix A because the `UInt(-1)` trap killed
the process inside `SFSyncTask.init` before any test body executed. Characterization:
- Reproduces even on `testStopRestartSingleSyncDown`, which uses a MOCK `TestSyncDownTarget` (no live network
  for the sync itself) → **NOT** a slow-org / live-network artifact. It's a genuine deadlock.
- Every test-side wait has a timeout and none logged "took too long": `SFSyncUpdateCallbackQueue.getNextSyncUpdate`
  = 10s run-loop spin (returns nil, never blocks); `SFSDKTestRequestListener.waitForCompletion` = 30s run-loop
  spin. So the freeze is NOT in the test harness waits — it's a lock/queue deadlock in the sync engine itself.
- `SFMobileSyncSyncManager.runSync` builds the `SFSyncTask` synchronously then dispatches `task.run()` on a
  serial `DispatchQueue` (`kSyncManagerQueueLabel`, mgr.swift:359). Prime suspect = a re-entrant `.sync` back
  onto that serial queue (or a SmartStore store-access hop) during `updateSync`/`sync.save(store)`, or the
  stop/restart path. Oracle (ObjC, same serial-queue design) does NOT deadlock → migration introduced the
  re-entrancy (a `queue.sync`/`await`/lock ported from a non-blocking ObjC dispatch, or an `objc_sync_*`
  mismatch). NEXT ROOT-CAUSE STEP: sample the wedged process (`sample <pid>` or lldb `bt all`) to get the
  blocked stack, or diff `SFMobileSyncSyncManager`/`SFSyncTask`/`SFSyncDownTask` dispatch against the oracle
  `.m` for a sync-onto-self.
- Non-fatal side note: the repeated `SyncManagerTestCase.swift:435` failures (`expectedOptions.fieldlist as?
  [String]` nil ≠ `sync.options?.fieldlist` `Optional([])`) are SOFT (test continues). The ObjC oracle does
  `XCTAssertEqualObjects(nil, @[])` which would ALSO fail, so this is very likely a pre-existing oracle-side
  baseline inside these tests, NOT the migration regression — confirm by running the same test on the oracle.
  Do not conflate with the deadlock.

### ✅ FINDING #1b ROOT-CAUSED & FIXED 2026-07-21 (operator: "Root-cause the deadlock now")
Process sample (`sample <pid>`) of the wedged run gave the decisive two-thread deadlock:
- Main/test thread blocked in `SFSyncUpdateCallbackQueue.getFirst()` @ `SFSyncUpdateCallbackQueue.swift:104`
- Sync worker thread blocked in the `runSync` update callback @ `SFSyncUpdateCallbackQueue.swift:45`
Both on `objc_sync_enter(self.queue)` — where **`queue` is a Swift `Array` (VALUE TYPE)**. Passing a Swift
array to `objc_sync_enter` bridges it to a temporary `NSArray`, and an EMPTY Swift array bridges to a
**process-global shared-empty singleton**. Sequence: enter locks the empty-array singleton → `queue.append()`
mutates → `objc_sync_exit` bridges the now-NON-empty array to a *different* NSArray and releases THAT →
the singleton's lock is orphaned forever → every later thread that locks an empty array blocks permanently.
The ObjC original locked a stable `NSMutableArray` whose identity is invariant under mutation. **TEST-ONLY**
(`libs/MobileSync/MobileSyncTests/SFSyncUpdateCallbackQueue.swift`); production `SFMobileSyncSyncManager`
locks on `self` (stable class instance) — swept all prod `objc_sync_enter`, every one locks `self` = safe.
FIX: added `private let lock = NSLock()`; replaced all 5 `objc_sync_enter(self.queue)`/`exit` sites (4 append
closures + getFirst) with `lock.lock()/unlock()`. Result: `testStopRestartSingleSyncDown` went from 8-min hang
→ completes in 1.65s.

### ✅ FINDING #1c ROOT-CAUSED & FIXED 2026-07-21 — SFSyncOptions fieldlist nil-vs-[] (PRODUCTION)
With the deadlock gone, the remaining `SyncManagerTestCase.swift:435` failures (`expectedOptions.fieldlist as?
[String]` nil ≠ `Optional([])`) turned out to be a GENUINE migration regression, NOT an oracle baseline
(my earlier hedge was wrong — verified against the oracle `.m`). Oracle `SFSyncOptions.newFromDict:` passes
`dict[fieldlist]` STRAIGHT through to `newSyncOptionsForSyncUp:`; a sync-down never stores a fieldlist (see
`asDict`: `if (self.fieldlist)`), so on reload `dict[fieldlist]` is absent → ObjC `nil` → `fieldlist == nil`.
The migration's `new(fromDict:)` did `dict[kSFSyncOptionsFieldlist] as? [Any] ?? []`, coercing the MISSING key
to `[]` → `fieldlist == []` ≠ nil → assertion fails. FIX (`SFSyncOptions.swift` `new(fromDict:)`): build the
options directly and set `options.fieldlist = dict[kSFSyncOptionsFieldlist] as? [Any]` (no `?? []`), so a
missing key stays nil — byte-faithful to the archived representation. Swept prod consumers of
`sync.options?.fieldlist` (SFSyncUpTask/SFAdvancedSyncUpTask) — all already `?? []`-guard, so nil is safe;
sync-up always sets fieldlist via `newSyncOptions(forSyncUp:)`. **PRODUCTION change → PR-flag.** Result:
`testStopRestartSingleSyncDown` now PASSES (EXIT=0, 0 failures, 1.685s).

### ✅ FINDING #1d — countIdsPerSoql private (test-fidelity) + #1e SOQL Optional("…") [PROD], both FIXED 2026-07-21
Running all 6 scoped methods after A/B/C: 5 passed, only `testRefreshReSyncWithMultipleRoundTrips` failed
(205s). Two more root causes:
- **#1d (test-fidelity):** the oracle test does `target.countIdsPerSoql = 1` (and a sibling `= 2`) to force
  multiple SOQL round trips; the ObjC test re-declared the property via a class-extension. The migration made
  `countIdsPerSoql` `private`, so BOTH assignments were commented out (`// private - skip in Swift`) →
  `testRefreshSyncDownWithMultipleRoundTrips` and `testRefreshReSyncWithMultipleRoundTrips` silently ran the
  single-round-trip path. FIX: `SFRefreshSyncDownTarget.countIdsPerSoql` `private`→`internal` (NOT public — the
  `.h` never exposed it, so no public-API change), restored both test assignments. `testRefreshSyncDownWith…`
  → PASS immediately.
- **#1e (PRODUCTION bug, uncovered by #1d):** with round-trips forced on, the reSync failed with server
  `MALFORMED_QUERY: AND LastModifiedDate > Optional("2026-07-21T23:19:29.000+0000")`. `getIsoString(fromMillis:)`
  returns `String?`; THREE production sync-down targets interpolated it RAW into SOQL, injecting the literal
  `Optional("…")`: `SFRefreshSyncDownTarget.swift:236`, `SFSoqlSyncDownTarget.swift:216`,
  `SFParentChildrenSyncDownTarget.swift:215`. All are guarded by `maxTimeStamp > 0` (⇒ millis ≥ 0 ⇒ never nil),
  and the ObjC used a non-nil NSString, so FIX = `?? ""` at all three (oracle-faithful; the ported tests already
  used `?? ""`). This is a real shipped regression: **reSync / incremental sync-down was broken for refresh,
  SOQL, and parent-children targets** in the migrated SDK. `testRefreshReSyncWithMultipleRoundTrips` → PASS (7.7s).

## ✅ MOBILESYNC PHASE 2 RESULT — all 6 scoped live methods now GREEN (were: all crash)
| Test | Before Fix A | After all fixes | vs Oracle |
|---|:--:|:--:|---|
| testCleanResyncGhostsForMRUTarget | 💥 crash | ✅ PASS (3.4s) | oracle had data-pollution fail; migration clean |
| testStopRestartMultipleSyncDowns | 💥 crash | ✅ PASS (2.0s) | match |
| testStopRestartSingleSyncDown | 💥 crash | ✅ PASS (1.7s) | match |
| testSyncUpManyLocallyCreatedRecords | 💥 crash | ✅ PASS (158s) | match |
| testSyncUpWithLocallyUpdatedRemotelyDeletedRecordsWithoutOverwrite | 💥 crash | ✅ PASS (4.5s) | match |
| testRefreshReSyncWithMultipleRoundTrips | 💥 crash | ✅ PASS (7.7s) | match (after #1d+#1e) |

**FIVE fixes total for MobileSync Phase 2:**
- (A) `SFSyncTask.swift` — `UInt(-1)` trap (2 sites) + progress-arith trap. **PROD.**
- (B) `SFSyncUpdateCallbackQueue.swift` — value-type-array `objc_sync` deadlock. **TEST-ONLY.**
- (C) `SFSyncOptions.swift` — fieldlist missing-key → `[]` instead of nil. **PROD.**
- (D) `SFRefreshSyncDownTarget.swift` countIdsPerSoql `private`→`internal` + 2 restored test assignments. **TEST-FIDELITY (+ narrow internal visibility).**
- (E) 3 sync-down targets — raw `Optional("…")` in reSync SOQL. **PROD (shipped reSync regression).**

Escalation: A, C, E are PRODUCTION MobileSync (sync engine) → PR-flag. D touches production visibility
(private→internal, not public) → note in PR. B + the test edits are test-only.

**NEXT:** (1) run the FULL MobileSync live suite (all 7 gated classes) to catch any other masked failures now
that the crash is gone; (2) un-gate MobileSync classes matching oracle + retire their ledger entries; (3) move
to the SDKCore regressions #2–#7. Commit only when operator asks. Nothing committed yet.

## ⚠️ FULL MOBILESYNC SUITE RUN 2026-07-21 — the crash was masking a MUCH larger failure surface
Ran the entire MobileSync test target (all gated classes) after fixes A–E. Result: **190 passed / 50 failed**.
The 6 originally-scoped tests are all green, but lifting the crash mask exposed ~50 more failures across the
suite. This is the same "hidden failure" hazard the ledger exists to surface. Breakdown:
- **39 failures in `ParentChildrenSyncTests`** — an entire class was masked. Includes **14 hard traps**:
  `SyncManagerTestCase.swift:206 Fatal error: Unexpectedly found nil while implicitly unwrapping` — `store`
  (an IUO `SmartStore!`) is nil. Root cause not yet nailed: base `setUpWithError()` populates `store` only
  `if let user = currentUser`; the 14 trapping tests appear to hit a run where `currentUser` was nil (live-auth
  cascade / per-test setUp ordering). ParentChildren overrides plain `setUp()` → `createTestData()` (matches
  oracle structure, so not itself the divergence). NEEDS: isolate one ParentChildren test, confirm store-nil
  cause (auth vs ordering), compare vs oracle (oracle runs this class clean per Phase-2 findings).
- **✅ `testAddFilterForResync`** (SyncManagerTests, pure UNIT test) — FIXED: the test built its EXPECTED query
  with `dateStr = getIsoString(...)` (no `?? ""`), so it embedded `Optional("…")` and only matched the OLD
  buggy production output. After prod fix (E) unwraps, the test expectation must too → added `?? ""` at
  SyncManagerTests.swift:539. Re-ran in isolation: PASS (0.14s). (7th MobileSync test fixed.)
- **Remaining non-ParentChildren failures to triage vs oracle:** SyncManagerTests
  `testCleanResyncGhostsForRefreshTarget`, `testCleanResyncGhostsWithMultipleSyncs`, `testFetchLayoutMultipleTimes`;
  SFLayoutSyncManagerTests `testFetchLayoutMultipleTimes`; SyncUpTargetTests `testSyncUpWithNoType`. Each needs
  individual root-cause + oracle compare (regression vs oracle-baseline).

**DECISION POINT (reported to operator):** the operator's explicit ask ("root-cause the deadlock now") is DONE
— all 6 scoped methods green + 2 bonus PROD bugs fixed. The full-suite run reveals ~43 more failures (mostly
one masked class). Fixing all of them is a large scope expansion beyond the 6 scoped tests. Awaiting direction:
(a) continue and fix the whole MobileSync suite to green, (b) fix just the ParentChildren store-nil trap cluster
(likely one shared cause) then reassess, or (c) bank the 7 fixes + this inventory and pivot to SDKCore #2–#7.
**OPERATOR CHOSE (a): drive the whole MobileSync suite to green, commit+push per logical fix.**

## ✅ PARENTCHILDRENSYNCTESTS → 60/60 GREEN 2026-07-21 (was 39 fails in isolation)
Isolation diagnosis first settled the store-nil question: `testGetQuery` PASSES solo (store non-nil, auth OK),
and the whole class run in isolation had **0 store-nil traps** — so the 14 `SyncManagerTestCase.swift:206`
IUO traps are CROSS-CLASS contamination (a different earlier class leaves currentUser nil in full-suite), NOT a
ParentChildren setUp defect. In isolation the class still had 39 real failures = two more PRODUCTION regressions:

### ✅ FINDING #2 — parent-children sync-UP fully broken: `Optional("…")` in children SmartSQL (PRODUCTION) — FIXED, commit c20930fe1
All 39 fails were sync-UP (sync-down passed). Live log showed the children-lookup query as
`{accounts:Id} IN ('Optional(local_731264390)')` → matched zero children → advanced sync-up pushed nothing →
records stayed dirty (checkDbStateFlags false≠true). Root cause: `SFParentChildrenSyncHelper.getMutableChildren`
(line 116) and `SFParentChildrenSyncUpTarget.deleteChildren` call site (line 305) boxed a Swift Optional into
`[Any]` via `dict[key] as Any` / `record[idField] as Any`; `getQueryForChildren` interpolated it raw. Oracle
passes the raw unboxed id via ObjC `parent[key]`. Same Optional("…") class as Fix E, now in SmartSQL. Fix:
guard-unwrap at both call sites + defensive `unwrapForSql()` backstop in getQueryForChildren. Result: 39→3 fails.
**PROD sync-engine → PR-flag.**

### ✅ FINDING #3 — cleanResyncGhosts deletes NON-ghost records: NSMutableOrderedSet.array frozen-vs-live (PRODUCTION) — FIXED, commit aae35c2d1
Remaining 3 fails were `testCleanResyncGhostsForParentChildren{Target,WithMultipleSyncs}` — BOTH PASS on oracle
(built + ran oracle to classify: genuine regression, NOT a data-pollution baseline like the MRU sibling). Root
cause in BASE `SFSyncDownTarget.cleanGhosts` (affects ALL sync-down targets): oracle captured
`[localIds array]` BEFORE `removeObjectsInArray:` but that returns a LIVE-backed proxy reflecting the removal;
Swift `localIds.array` is a FROZEN snapshot, so the migration deleted the PRE-removal set = every non-dirty
local record incl. still-remote ones. Fix: snapshot ghost ids AFTER `removeObjects(in:)`, delete/return that.
This base fix ALSO fixed 2 of the scattered task-#16 fails: SyncManagerTests
testCleanResyncGhostsForRefreshTarget + testCleanResyncGhostsWithMultipleSyncs. **PROD sync-engine → PR-flag.**

**ParentChildrenSyncTests full class: 60 tests, 0 failures (228s).** Remaining scattered MobileSync fails:
SyncManagerTests.testFetchLayoutMultipleTimes, SFLayoutSyncManagerTests.testFetchLayoutMultipleTimes,
SyncUpTargetTests.testSyncUpWithNoType. NEXT: those 3, then a FULL-SUITE MobileSync run (also resolves the
14 cross-class store-nil traps question — likely gone once all classes pass, or needs a setUp-order fix).

## ✅ SCATTERED FAILS FIXED 2026-07-21 — commit 181386e4e (2 fixes) + cleanGhosts base fix already covered 2
- **testCleanResyncGhostsForRefreshTarget + testCleanResyncGhostsWithMultipleSyncs (SyncManagerTests)**: FIXED
  by the FINDING #3 base cleanGhosts fix (aae35c2d1) — no separate change needed.
- **NOTE:** `SyncManagerTests/testFetchLayoutMultipleTimes` does NOT exist (only SFLayoutSyncManagerTests has it);
  the earlier inventory double-counted. Real layout test is SFLayoutSyncManagerTests.testFetchLayoutMultipleTimes.
- **FINDING #4 — testSyncUpWithNoType (PRODUCTION):** no-type record → nil objectType. Oracle passed nil to
  requestForCreateWithObjectType: → path `/sobjects/(null)` → 404 (a modeled error). Migration coerced nil→""
  → `/sobjects/` → 405 METHOD_NOT_ALLOWED (unmodeled). FIX: SFSyncUpTarget.createOnServer coerces empty→"null"
  (same convention as RecordRequest.asRestRequest) → `/sobjects/null` → 404 like oracle. PROD → PR-flag.
- **FINDING #5 — testFetchLayoutMultipleTimes (TEST-ONLY):** production stores/fetches nil recordTypeId as ""
  (recordTypeId ?? ""), Id = "Account-Medium-Compact-Edit-". Oracle test passed real nil to stringWithFormat
  (→ "(null)") matching oracle's "(null)" storage; Swift port hardcoded literal "nil" in the count query →
  "...-Edit-nil" → 0 rows ≠ 1. Production self-consistent (validateResult passes) → pure test/query mismatch.
  FIX: query with "" to match production storage. TEST-ONLY.

Both verified vs live org (testSyncUpWithNoType now 404 like oracle). NEXT: FULL-SUITE MobileSync run to confirm
total + resolve the 14 cross-class store-nil traps question. All individually-identified fails are now GREEN.

## ✅ FULL-SUITE MobileSync RUN #1 2026-07-21 — 202 tests / 0 failures, BUT 14 latent store-nil host-crashes
Full `-only-testing:MobileSyncTests` finished **202 tests, 0 failures (595s)** — every individually-fixed test
green in-suite. HOWEVER the log showed **14 `SyncManagerTestCase.swift:206` Fatal-error IUO traps** clustered at
19:45–19:47 (early in the run). Each SIGTRAP killed the test host; xcodebuild auto-restarted and the RETRY
passed → final tally green but a latent flaky crash was being retry-masked (the exact abort/mask hazard the
SDKCore authRefreshDidSucceed work exists to prevent).

### ✅ FINDING #6 — base setUp leaves IUO `store` nil on transient nil currentUser → subclass host-crash (TEST-ONLY) — FIXED, commit be37d24eb
`SyncManagerTestCase.setUpWithError` assigned the IUO `store: SmartStore!` only inside `if let user =
currentUser`; subclasses (ParentChildren etc.) force-unwrap `store` from their own `setUp()` (createTestData →
createAccountsSoup → store.registerSoup @ line 206). When `UserAccountManager.currentUserAccount` is transiently
nil early in a full-suite run (auth-cascade timing), store stays nil → subclass traps → host dies → retry masks.
Oracle assigned store unconditionally & tolerated nil messaging, but migrated Swift APIs can't
(sharedInstance(forUserAccount:) needs non-nil user; SmartStore.shared(withName:forUserAccount:) returns nil for
nil user) → no store to run against when currentUser nil anyway. FIX: `XCTSkipUnless(currentUser != nil && store
!= nil)` in setUpWithError. TEST-ONLY.

### ⚠️→✅ FINDING #6 FOLLOW-UP — XCTSkip in setUpWithError does NOT stop a subclass's plain setUp() — FIXED, commit 8f9c0c545
Verify run #2 STILL trapped (now at line 219, same createAccountsSoup — line moved with the added comment).
XCTest invokes ParentChildrenSyncTests's separately-overridden plain `setUp()` EVEN WHEN `setUpWithError()` threw
XCTSkip, and that setUp() calls `createTestData()` → `createAccountsSoup()` → force-unwrap nil `store` → host
SIGTRAP again. FIX: guard `createTestData()` behind `store != nil` in ParentChildrenSyncTests.setUp() (test is
being skipped anyway when store is nil → nothing to set up).

### ✅ FINDING #6 ROBUST FIX — cross-class, guarded at base + Briefcase super chaining — commit 5751605ca
Verify run #3 STILL trapped at line 219 — the crash was CROSS-CLASS (not just ParentChildren), so per-subclass
guarding was whack-a-mole. Root: several subclass setUp()/setUpWithError() overrides reach the base soup helpers
(createAccountsSoup etc.) during the transient auth-cascade nil window, and those helpers force-unwrapped the IUO
`store`. Also BriefcaseSyncDownTests.setUpWithError() chained `super.setUp()` (XCTestCase no-op) instead of
`super.setUpWithError()`, bypassing BOTH the base store assignment AND the skip guard, then hit server+soups on a
nil store. ROBUST SINGLE-POINT FIX: (a) base createAccountsSoup/createContactsSoup/dropAccountsSoup/
dropContactsSoup guard on non-nil store (guard-let / optional-chaining); (b) Briefcase → `try
super.setUpWithError()` + XCTSkipUnless(store != nil). Verify run #4 IN PROGRESS (expect 0 fatal traps).

**Phase-2 MobileSync fix inventory so far (all commits pushed to fork feature/objc-to-swift-test-migration):**
- c6045477e batch 1 (7 fixes A–E)
- c20930fe1 FINDING #2 parent-children sync-up Optional("…") in children SmartSQL [PROD]
- aae35c2d1 FINDING #3 cleanResyncGhosts frozen-array deletes non-ghosts [PROD]
- 181386e4e FINDING #4 no-type sync-up 404 [PROD] + FINDING #5 layout count query [TEST]
- be37d24eb + 8f9c0c545 + 5751605ca FINDING #6 store-nil host-crash hardening [TEST-ONLY]
- 74567e3e7 BriefcaseSyncDownTests skip-gated [TEST-ONLY, live-org config baseline]

## ✅✅ MOBILESYNC SUITE GREEN — verify run #4 = 234 tests, 0 fatal traps, 0 host restarts (2026-07-21)
Run #4 (after the base soup guards + Briefcase super-chain fix): **0 fatal traps, 0 restarts** (was 14 traps
retry-masked). Only failures were the 7 BriefcaseSyncDownTests, freshly unmasked by the super-chain fix.
Classified vs oracle: the unmigrated .dev @ b155f785d fails all 7 IDENTICALLY (byte-for-byte: status 2≠3,
progress 0≠100, totalSize 24≠0, records 12≠0) → **live-org CONFIG BASELINE** (Briefcase/Priming feature not
provisioned in the shared test org), NOT a migration regression. Skip-gated (74567e3e7) with a documented
XCTSkip; class now skips cleanly (7 skipped / 0 failures). **The MobileSync suite is now GREEN: every test
passes or cleanly skips, no failures, no crashes, no host restarts.**

NEXT (Phase 2 milestone 4): SDKCore regressions #2–#7 vs oracle (testOpenIDToken, testBlocks,
testCollectionCreateWithBadRecord False/True, testCreateQuerySearchDelete, testRefreshNotificationWithValidGetRequest).
Then un-gate/retire the ledger (milestones 3+5).

## ✅✅ SDKCORE REGRESSIONS #2–#7 RESOLVED — 2026-07-22 (Phase 2 milestone 4, task #18)
All 7 flagged SDKCore live-org "regressions" root-caused vs oracle (.dev @ b155f785d) with
byte-level request/response instrumentation on BOTH clones. Result: 6 run + 1 skip, 0 failures.
Commits (all pushed to fork feature/objc-to-swift-test-migration):

- `271836232` **#7 testOpenIDToken** [TEST skip-gate] — NOT a regression. Server returns NO id_token
  (test-org connected app lacks openid scope); oracle's real derived idToken is genuinely nil
  (instrumented `isNil=1`). Oracle only "passes" via an ObjC→Swift nullability bridging quirk: its
  un-annotated ObjC completion `void(^)(NSString *)` bridges to a Swift NON-optional `String`; ObjC
  nil becomes a non-optional String secretly holding nil, and assigning into `var idToken: String?`
  re-wraps as `.some` → XCTAssertNotNil passes against a nil. Migration's `(String?)->Void` propagates
  the real nil → faithfully fails. Skip-gated (live-org config baseline, like Briefcase). **Corrects
  the earlier reclassification — original p02e triage (baseline) was RIGHT.**
- `a88baa778` **#4/#5 testCollectionCreateWithBadRecordAndAllOrNoneFalse/True** [PROD public-API] —
  genuine regression. Migration narrowed public `SFSDKCollectionSubResponse.objectId` from oracle's
  nullable `NSString*` (`_objectId = dict[@"id"]`) to non-optional `String=""` (`?? ""`), so a failed
  sub-record reported "" not nil → `XCTAssertNil` always failed. Fix: `objectId: String?` +
  `dict["id"] as? String`. Also fixes a latent MobileSync bug (parseIdsFromResponses filtered
  `objectId != nil` then force-unwrapped — the "" default would slip an empty id through). 9 test
  `.objectId.hasPrefix` sites → `.objectId?.hasPrefix(...) == true`. SDKCore+MobileSync build; PR-flag.
- `bee3d8179` **#6 testRefreshNotificationWithValidGetRequest** [TEST fidelity] — shared sendSyncRequest
  used the GLOBAL `waitForExpectations(timeout:)` (drains ALL pending expectations) instead of the
  oracle's SCOPED `[self waitForExpectations:@[expectation] ...]`; it consumed the test's notification
  expectation early → "call made to wait without any expectations having been set". Fix: `wait(for:[exp])`.
- `3177f3980` **#2 testBlocks + #1 testCreateQuerySearchDelete** [TEST fidelity] —
  (#2) 'should-fail' block: oracle passes nil objectType → `/sobjects/(null)` → 404; port substituted
  valid `kContact` so metadata/describe (no objectId) SUCCEEDED → tripped unexpected-success. Fix: pass
  literal "(null)". (#1) SOSL `Find {UUID-with-hyphens}` → server MALFORMED_SEARCH (bare '-' is a SOSL
  operator), deterministic on BOTH clones; oracle performs the search but NEVER asserts its count (its
  comment warns the term may need SOSL escaping), the port ADDED the assertion. Fix: backslash-escape
  SOSL reserved chars (new escapeSoslTerm helper) → well-formed, returns 1 match in ~3s (no flake).

Verified together: 6 pass + 1 skip, 0 failures, no cross-contamination (16.8s). `testRedirect`
remains a confirmed baseline (401≠200 on both). NEXT: milestone 3 (un-gate/retire MobileSync ledger,
task #17) + milestone 5 (retire full ledger, close Phase 2, task #19).

## PER-CLASS LEDGER RETIREMENT — 2026-07-22 (Phase 2 milestone 3, task #17)
Full per-class live-auth verification (both schemes, single-pass `xcodebuild test`, oracle `.dev @ b155f785d`).
RETIRED = runs live + matches oracle + only documented config baselines remain as clean XCTSkip. The
`XCTSkipUnless(authRefreshDidSucceed)` live-auth guard STAYS on every class (skips only when no live org).

**Full-class verify caught 2 failures the #18 method-targeted run missed → both fixed (commit 2df73b842):**
- `2df73b842` **[PROD] SFRestAPI+QueryBuilder.soqlQuery** — `Array(Set(fields))` gave NON-deterministic SOQL
  field order (Swift Set per-process randomized hash seed); `testSOQL` flipped pass↔fail across two runs and
  real callers got unpredictable ordering. Fix: order-preserving dedup (`filter { seen.insert($0).inserted }`).
  ESCALATION: public REST query-builder output changes → PR-flag.
- `2df73b842` **[TEST] testUploadDownloadDeleteFileWithCommunity** — oracle's delete-by-sObject assertion was a
  vacuous tautology (`NSRange.location >= 0` on unsigned NSUInteger is always true); the straightforward Swift
  port made it a real `range(of:) != nil` check that correctly failed (delete-by-sObject URL isn't
  community-scoped). Fix: assert the true state (`XCTAssertNil`), matching the oracle's effective behavior.

KEY LESSON (reinforced): method-targeted `-only-testing` runs can hide (a) order/seed-dependent
non-determinism that only manifests across a full class run, and (b) failures in methods outside the
targeted set. Always re-run the WHOLE class before declaring it retired.

### RETIRED classes
- SDKCore (4): RestClientTests, RestClientPublisherTests, SFSDKAuthUtilTests (testOpenIDToken clean-skip),
  SalesforceRestAPITests (green modulo testRedirect = documented both-sides 401≠200 baseline).
- MobileSync (7): SyncManagerTests, SyncUpTargetTests, ParentChildrenSyncTests, SFSDKSyncsConfigTests,
  SFLayoutSyncManagerTests, SFMetadataSyncManagerTests, BriefcaseSyncDownTests (7 clean-skips = config baseline).
  Full MobileSync run: ** TEST SUCCEEDED **, 141 passed / 0 fail / 0 crash.

### Outstanding for task #19 (full ledger retirement)
Only `testAssertionForUnauthenticatedClient` remains documented-blocked (needs ObjC-exception catch bridge +
class live-gate relocation). Everything else RETIRED. Marker stays b5d37d807.

ENV NOTE: `build-for-testing`+`test-without-building` can leave SQLCipher.framework unassembled →
`dyld: Library not loaded @rpath/SQLCipher.framework`; and a contended sim gives "Busy / Application failed
preflight checks". Fix: single-pass `xcodebuild test`, serialize sim execution across schemes.
