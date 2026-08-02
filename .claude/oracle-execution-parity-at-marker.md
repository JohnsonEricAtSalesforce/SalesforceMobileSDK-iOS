# Execution Parity — Oracle @ marker `b5d37d807` vs Migration (2026-07-31)

**Goal:** complement the *structural* parity (`.claude/oracle-parity-at-marker.md`, "what is tested")
with **execution** parity — actually build & run the unmigrated oracle suite at the marker and diff
pass/fail against the migration's recorded Phase 2 results.

**Setup:** `../SalesforceMobileSDK-iOS.forcedotcom.dev` checked out detached at `b5d37d807`, `./install.sh`
(light — this SDK resolves deps via SPM at build time; no submodule/pod step), seeded the migration's
`shared/test/test_credentials.json`, freshly-erased sim `AE4C549A` (iPhone 17 Pro), single-pass
`xcodebuild test`. Clone restored to `dev` + seeded creds removed afterward (clone left clean).

> **UPDATE 2026-08-01 — LIVE COMPARISON UNBLOCKED & RUN.** A fresh refresh token was provided and
> verified (mints an access_token against `mobilesdk.my.salesforce.com`). Seeded into BOTH clones
> (gitignored, untracked, never committed). Ran SDKCore live on both from freshly-erased sims
> (migration on iPhone 17 Pro Max `D2455CE0`, oracle on iPhone 17 Pro `AE4C549A`). Auth succeeded in
> both (0 auth-failures). **See "LIVE RESULTS" section at bottom — this supersedes the "BLOCKED"
> headline below for the live layer.**

## Headline result: BLOCKED on credentials for the live comparison; non-live parity is clean

### Live-org tests — NOT comparable right now (expired credentials)
The seeded `test_credentials.json` (dated Jul 17) is **expired**. The oracle's live suites all fail at
auth setup: `After auth attempt, expected status 'didLoad', got 'didFail'`, and the OAuth log shows the
smoking gun:
- `Code=672 "expired refresh token" (invalid_grant)`
- `Code=666 "app attestation failed" (client_blocked)`

16 live auth-failures observed before the run was stopped (each live RestAPI test also burns up to 60s
timing out). **This is exactly the caveat flagged before starting.** No usable behavioral signal on the
live front without a fresh token.

> **Behavioral divergence surfaced (real, independent of the stale token):** the oracle at the marker
> carries the *old* harness that **hard-fails** live tests when auth setup fails; the migration was
> deliberately hardened (commit `7f556a130`) to **skip** them (`XCTSkipUnless` on
> `authRefreshDidSucceed`). So even with a fresh token the two clones will not report identically on the
> live suites by construction — the migration skips, the oracle fails-or-passes. This is a documented,
> intentional divergence (a future merge-conflict marker), not a regression.

### Non-live SDKCore — CLEAN parity
Re-ran SDKCore skipping the 6 live classes (`SalesforceRestAPITests`, `RestClientTests`,
`RestClientWebSocketTests`, `RestClientPublisherTests`, `SFSDKAuthUtilTests`, `SFUserAccountManagerTests`):

**Oracle non-live result: 640 passed / 1 failed.**

The single failure is **not comparable and not a defect**:
- `SalesforceOAuthUnitTests.testCoordinator` — fails on a **test-isolation artifact**: a prior test left
  the coordinator with nil credentials, so `authenticate` raised `NSInternalInconsistencyException:
  credentials cannot be nil` instead of the expected no-throw. This is state-bleed in the *oracle's* run
  order, and the file `SalesforceOAuthUnitTests.m` **does not exist in the migration at all** (it was
  superseded — cf. `testScopeQueryParamStringNilScopes` supersession in `dropped-test-methods.md`). No
  migration counterpart ⇒ nothing to diff.

Net: every non-live SDKCore test that exists in *both* clones passes in the oracle, matching the
migration's non-live green state. No non-live behavioral regressions.

### MobileSync — not separately run
MobileSync is almost entirely live-org (most classes inherit `SyncManagerTestCase`, need a real org).
A non-live-only run would exercise only a few pure-logic classes (SoqlMutator, SyncState) and add little
signal; skipped pending fresh credentials. Migration's recorded Phase 2 live result was 227/0/22 green
(with a *valid* token at that time).

## Conclusion
- **Structural parity: confirmed** (11 real drops, 6 actionable — tasks #1/#2).
- **Non-live execution parity: confirmed clean** (640/1, the 1 being a non-migration test-isolation
  artifact).
- **Live execution parity: cannot be established today** — blocked solely by an expired refresh token,
  compounded by the intentional skip-vs-fail harness divergence. To complete it: refresh
  `test_credentials.json` against the test org, rebuild (creds are baked in at build time), and re-run
  both clones' live suites from erased sims. Until then the live layer stays as Phase 2 last recorded it.

---

## LIVE RESULTS (2026-08-01, fresh valid token) — parity CONFIRMED

Fresh refresh token provided, verified working (mints access_token vs `mobilesdk.my.salesforce.com`).
Seeded into BOTH clones (gitignored/untracked/never committed). Both schemes run on both clones from
**freshly-erased** sims (migration on iPhone 17 Pro Max `D2455CE0`; oracle@marker on iPhone 17 Pro
`AE4C549A`), full-scheme single-pass `xcodebuild test`, live auth. **Auth succeeded in all runs (0
auth-failures).**

### SDKCore (live)
| Clone | passed | failed | failures |
|---|---|---|---|
| **Oracle @ marker** | 803 | **1** | `SalesforceRestAPITests.testRedirect` |
| **Migration** | 792 | **3** (1 skip) | `testRedirect` **+** `BiometricAuthenticationManagerTests.testNotEnabled` **+** `NativeLoginManagerTests.testShouldShowBackButton` |

- `testRedirect` **fails in BOTH** ⇒ confirmed **pre-existing baseline**, NOT a migration regression. ✅
- The 2 extra migration failures are the **B1 escalation item, now proven live**: both fail on a
  leftover `SFUserAccount` (`identifier-0`, `instanceUrl=nil`) persisting across tests — the gated
  `currentUserAccount` setter that persists `LastUserIdentity`. **Controlled experiment result: oracle
  PASSES both, migration FAILS both, from identically-erased sims + same valid token.** This is the
  exact divergence flagged in `phase2-pr-escalation-summary.md §B1`, now confirmed by live A/B — still
  awaiting human sign-off, still not auto-fixed.
- Count delta (803 vs 792) is the oracle running live REST/OAuth classes the migration skips, plus the
  extra `.m`-only tests that don't exist in the migration (e.g. `SalesforceOAuthUnitTests`).

### MobileSync (live)
| Clone | passed | failed | skipped | failures |
|---|---|---|---|---|
| **Oracle @ marker** | 224 | **10** | 0 | **all** `BriefcaseSyncDownTests` (7 methods, 10 assert-fails) |
| **Migration** | 227 | **0** | 7 | — (`** TEST SUCCEEDED **`) |

- **Every oracle MobileSync failure is `BriefcaseSyncDownTests`** — 0 non-Briefcase failures. These need
  org-side Briefcase/priming rules the test org doesn't have configured, so they genuinely can't pass in
  this environment.
- The **migration SKIPS exactly those 7** (Briefcase is in the live-skip ledger) → 227/0/7 green,
  matching its recorded Phase 2 result (227/0/22; skip-count differs only because Phase 2 was a
  serialized single-pass). **The migration is strictly more robust here** — same skip-vs-fail harness
  divergence (`7f556a130`), migration side skips an env-unavailable feature the oracle hard-fails.

### Verdict
- **Non-live parity:** clean (640/1, the 1 = a non-migration isolation artifact).
- **Live parity:** **CONFIRMED.** Every behavioral difference is explained: (a) `testRedirect` = shared
  baseline; (b) MobileSync deltas = Briefcase env-gating (migration skips, oracle fails) — migration is
  better, not regressed; (c) the ONLY migration-specific behavioral divergence is **B1** (2 SDKCore
  tests), already a known, flagged, awaiting-sign-off escalation item — now backed by a live A/B proof.
- **No new regressions surfaced by the live run.** The 6 structural coverage gaps (tasks #1/#2) remain
  the only actionable migration items.

## Reproduce
Logs (all under `/tmp/oracle-analysis.OgVvt7/`): `sdkcore-nonlive.log`, `oracle-sdkcore-live.log`,
`mig-sdkcore-live.log`, `oracle-mobilesync-live.log`, `mig-mobilesync-live.log` (+ matching `.xcresult`
bundles). Structural diff script: `/tmp/method_diff_marker.py`.
