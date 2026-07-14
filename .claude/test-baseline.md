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

### `env-skip` — MobileSync integration (verified in CI only)

Per gate report: `SyncManagerTestCase` `class setUp()` blocks on `synchronousAuthRefresh()`;
the auth run-loop doesn't integrate with xcodebuild locally. Not counted as pass; deferred to CI.
(Lives in MobileSync scheme; listed here as part of the single baseline registry.)

---

## UNRESOLVED — NOT baselined (see tracker finding P0.2b)

The 2026-07-05 empirical run surfaced a **crash cluster** absent from the 2026-05-25 report:
~35 test cases in `SFSmartSqlTests` and `SFMultipleSmartStoresTests` fail because their
`setUp` crashes (`Crash: … at SFSmartSqlTests.createUserAccount()`,
`… at SFMultipleSmartStoresTests.setUpSmartStoreUser()`, plus "signal trap"). Because setUp
crashes, EVERY test in those classes cascades to failed — this is why the run showed 47 failures
vs. the report's 12.

These are **deliberately NOT in the baseline.** Root cause (environment drift since 2026-05-25
vs. a real regression on the branch) is unresolved. Until diagnosed, the SmartStore scheme cannot
produce a clean gate result; treat SmartStore gate runs as **provisional**. Do not baseline these
to make the gate green — that is exactly the laundering this file exists to prevent.

Captured crash-cluster classes (for triage, not for baselining):
- `SFSmartSqlTests/*` (setUp `createUserAccount()` crash — ~36 cases incl. testConvertSmartSql*, testSmartQuery*)
- `SFMultipleSmartStoresTests/*` (setUp `setUpSmartStoreUser()` crash — testGetGlobalStoreNames, testGetStoreWithStoreName, testGetUserStoreNames, testRemoveAllGlobalStores, testRemoveAllStores)

---

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
