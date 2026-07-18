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

**5 genuine findings (ranked):**
| # | Sev | Class.method (library) | Loss |
|---|-----|------------------------|------|
| 1 | HIGH | `SFSDKSafeMutableArrayTests.testConcurrentReadsAndRemoveAll` (Common) | Per-element `XCTAssertNotNil(array[idx])` inside the concurrent-enumeration block dropped (2→1 asserts); now only checks final `count == 0`. Element-by-element concurrent-read safety no longer verified. |
| 2 | MED | `SFLoggerTests.testLoggerInstance` (Common) | Dropped `isKindOfClass:[TestLoggingImpl class]` type assertion (3→2); no longer confirms logger impl class. |
| 3 | MED | `SalesforceOAuthUnitTests.testCoordinatorDefaultInstantiation` (SDKCore) | 3 coordinator-property checks → 1 (`XCTAssertNotNil(coordinator)`). |
| 4 | MED | `SFSmartSqlTests.testNonSmartQueryUsingWhereArgs` (SmartStore) | Query-argument validation reduced (3→1). |
| 5 | LOW | `SFSmartStoreTests.testSmartStoreIsRecreatedWhenKeyIsLost` (SmartStore) | `try? store.registerSoup(...)` in helpers swallows some error cases (6→3). |

**Clean (no loss):** SalesforceAnalytics (EventStoreManager, InstrumentationEventBuilder); Common
(SafeMutableDictionary/Set); SDKCore non-live (SFOAuthCredentials, SFPushNotificationManager,
SFUserAccountManager, SFSDKURLCache, SFNetwork, SFEncryptionKey, SFSDKCryptoUtils, +15 more); SmartStore
(AlterTests [after helper accounting], SmartSqlCache, QuerySpec, StoreConfig, MultipleSmartStores).

**Status:** findings recorded for operator triage. These are NOT part of the dropped-method restore (they're
surviving-method weakenings). Recommend fixing #1 (HIGH, concurrency safety) before resuming the port queue;
#2–#5 are lower priority. **Deferred to operator** — not auto-fixing, since restoring assertions could
surface pre-existing failures that need their own oracle triage.
