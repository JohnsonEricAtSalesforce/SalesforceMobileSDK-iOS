# HANDOFF — ObjC→Swift Test Migration (iOS)

**READ THIS FIRST.** This is the top-of-funnel handoff for a new agent picking up this
directory. It states what is done, the current status, the remaining task list, and the
hard constraints. Deeper detail lives in the linked source-of-truth docs — do not
re-derive; read them.

Last updated: 2026-08-15. Prepared at session close for a fresh agent to continue.

---

## TL;DR — where we are

- **Project:** ObjC→Swift migration of the **iOS** Salesforce Mobile SDK (this is the iOS
  repo; there is NO Android work in this workspace — the Android repo is not checked out
  here and is only referenced in `CLAUDE.md` for cross-platform parity awareness).
- **Phase 0 + Phase 1 (porting): COMPLETE.** All 49 first-parent upstream units ported in
  strict order; sync marker landed on `b5d37d807` (forcedotcom/dev HEAD, the "done-floor").
- **Phase 2 (live-org test execution + oracle compare + fix to green): COMPLETE**
  (5/5 milestones). Live-org skip ledger CLOSED.
- **There is NO pending migration work.** Two items are surfaced FOR HUMAN PR REVIEW
  (flagged, deliberately not changed) — see "Awaiting human decision" below.

### Git state at handoff (verify these on resume)
- Last substantive commit: `fd7c21f07` (B1/B2 fixes). Chain: `b15e03e42` 6-test port →
  `1e090a7df` doc → `fd7c21f07` B1/B2 fixes → then doc-sync close-out commit(s) on top.
  HEAD is whatever the latest doc-sync commit is — verify live with `git log --oneline -3`.
- Branch: `feature/objc-to-swift-test-migration`
- Working tree: **clean** (all work committed) — verify with `git status`
- Remote: **0 ahead / 0 behind** `origin/feature/objc-to-swift-test-migration` — everything PUSHED
- Sync marker: `b5d37d807` present, NOT an ancestor of HEAD (expected — semantic re-impl) — **do not advance it**

---

## ✅ COMMITTED + PUSHED (2026-08-01) — 6-test port + B1/B2 fixes

**Two batches of work committed on `feature/objc-to-swift-test-migration`, both PUSHED to `origin`:**

1. **6-test port** — `b15e03e42` (+ doc follow-up `1e090a7df`). 5 latent oracle coverage-gap tests
   (ScreenLock `getTimeout()` aggregation) + `testMigrateRefreshTokenSetup`. Detail below.
2. **B1 + B2 escalation fixes** — operator + reviewer approved option (i) for B1 and the assertions-gated
   catchable-exception approach for B2. Both byte-faithful to the oracle:
   - **B1:** `SFUserAccountManager.swift` public `currentUserAccount` setter reverted to the bare synthesized
     setter (`willChange/_currentUser = newValue/didChange`) — no managed-account gate, no `LastUserIdentity`
     persistence. Gate/persistence still live in `setCurrentUserInternal(_:)` (internal login/switch paths +
     `TestSetupUtils` unchanged). Fixes `testNotEnabled` + `testShouldShowBackButton`.
   - **B2:** `SFRestAPI.swift` `send(...)` now raises a catchable `NSInternalInconsistencyException` gated to
     assertions-enabled builds (detected via the public `assert()` autoclosure side-effect — `#if DEBUG` is
     unusable, the framework target lacks DEBUG in SWIFT_ACTIVE_COMPILATION_CONDITIONS). Restored
     `testAssertionForUnauthenticatedClient` via the `SFSDKCatchException` bridge.
   - **Verify:** full SDKCore suite, freshly-erased sim + live token = **230 executed / 1 failure**; the sole
     failure is `testRedirect` (§D baseline, fails on the oracle too). The former B1 pair + restored B2 test
     all PASS. Tracked failures 3 → 1.
   - Both remain escalation-class (account switching / public REST) → flag in the PR, but are no longer open
     decisions. See `.claude/phase2-pr-escalation-summary.md` §B (both marked RESOLVED).

Sync marker `b5d37d807` unchanged. Nothing else pending unless the operator directs it.

The section below is retained as the record of what the 6-test-port commit contained.

---

### What this session did
1. **Static parity re-analysis** of migration test suite vs the unmigrated oracle **at the marker
   `b5d37d807`** (correct baseline; NOT the old merge-base `6ed0ab408`, NOT the `.dev` clone
   `b155f785d` which is 8 behind). Result: near-total parity — 1203/1206 methods compiled; 11 real
   SDKCore drops (4 superseded, 1 = B2 blocked, **6 actionable**). Doc: `.claude/oracle-parity-at-marker.md`.
   (Caught + fixed my own parser bug: migration uses non-hex/variable-length synthetic pbxproj UUIDs.)
2. **Execution parity** — built & ran the oracle @ marker vs the migration, both schemes, from
   freshly-erased sims, with a **fresh live token** (operator-provided 2026-08-01, verified working).
   Result: **no new migration regressions.** SDKCore: oracle 803/1 vs migration 792/3 — the 1 shared
   failure `testRedirect` = baseline; the 2 extra migration failures are the **B1** `currentUserAccount`
   setter divergence, now PROVEN by live A/B (oracle passes both, migration fails both, identical erased
   sims + same token). MobileSync: migration 227/0/7 green; oracle's only failures are all
   `BriefcaseSyncDownTests` (org-side Briefcase rules absent) which the migration correctly SKIPS →
   migration is strictly MORE robust. Doc: `.claude/oracle-execution-parity-at-marker.md`.
3. **Ported the 6 actionable coverage gaps** (operator: "Port them now"). ALL 6 pass; full-suite
   regression gate clean.

### Uncommitted changes to commit on "Continue"
- **`libs/SalesforceSDKCore/SalesforceSDKCoreTests/ScreenLockManagerTests.swift`** (+49): 5 `getTimeout()`
  multi-user aggregation tests (`testShouldNotLock`, `testShouldLockMultiuser`,
  `testShouldLockMultiuserDifferentTimeouts`, `…ReverseOrder`, `testLogoutScreenLockUsers`) merged into
  the existing compiled class; added `KeychainHelper.removeAll()` to `setUp` for oracle-matching isolation.
- **`libs/SalesforceSDKCore/SalesforceSDKCoreTests/SFOAuthCoordinatorTests.swift`** (+62):
  `testMigrateRefreshTokenSetup` ported; waits on the failure callback directly (NOT the oracle's
  `dispatch_after(1s)` — no-sleeps standard).
- **`.claude/oracle-parity-at-marker.md`** + **`.claude/oracle-execution-parity-at-marker.md`** (new docs).
- NO pbxproj change (merged into already-compiled `.swift`). NO credential file in git (gitignored,
  verified). Both ports are test-only, but touch escalation-class surfaces (multi-user account state;
  OAuth token path) → **call out in PR**.

### Verification already done (evidence, don't redo unless suspicious)
- SDKCore `build-for-testing`: **TEST BUILD SUCCEEDED**.
- Targeted run of the 2 classes: **14/14 pass** (all 6 new included).
- Full SDKCore suite, erased sim, live token: **798 pass / 3 fail / 1 skip** — the 3 fails are EXACTLY
  the pre-existing baselines (`testRedirect` + B1 pair `testNotEnabled`/`testShouldShowBackButton`);
  passed rose 792→798 (+6 = the ports). **No new failures.**

### On "Continue" — commit steps
1. `git add` the 2 source files + the 2 new `.claude` docs (NOT `shared/test/test_credentials.json` —
   gitignored; never stage it).
2. Commit to the fork feature branch `feature/objc-to-swift-test-migration` with an escalation-flagged
   message (test-only additions; multi-user + OAuth surfaces flagged for PR). Do NOT commit to `dev`.
   Do NOT advance the sync marker. Push only if operator says so (they said commit; confirm push).
3. Attribution/commit-format per global memory conventions.

### Environment note for any re-run
- Fresh live token is in BOTH clones' `shared/test/test_credentials.json` (gitignored). Oracle clone
  `../SalesforceMobileSDK-iOS.forcedotcom.dev` was restored to `dev` (@ `0af97e7b4`) + its seeded creds
  removed; only the migration clone retains the working creds file. Analysis logs (if still present):
  `/tmp/oracle-analysis.OgVvt7/`.

---

## What is DONE

### Phase 1 — porting (COMPLETE)
All 49 upstream first-parent units semantically re-implemented (NOT cherry-picked/merged)
in strict upstream order. Because it was semantic re-impl, `b5d37d807` is legitimately NOT
a git ancestor of HEAD — that is expected, not a defect. Full per-unit detail:
`.claude/upstream-sync-backlog.md` (source of truth) + `.claude/pr-escalation-digest.md`.

### Phase 2 — live-org execution, oracle compare, fix to green (COMPLETE, 5/5)
Executed the previously-skipped live-org suites (unblocked by unit 44's token-refresh
coordinator), oracle-compared against the unmigrated `.dev` clone (@ `b155f785d`), and
drove both schemes green. Final full-suite verification from a **freshly-erased** sim
(AE4C549A, iPhone 17 Pro), single-pass `xcodebuild test`, serialized schemes, live auth:
- **MobileSync:** `** TEST SUCCEEDED **`, 227 passed / 0 failed / 22 skipped.
- **SalesforceSDKCore:** 224 tests, green modulo the documented `testRedirect` baseline
  and the one flagged production regression (B1 below).

Milestones (all committed + pushed):
- MobileSync suite driven to green (sync-engine correctness fixes A3–A6, isolation
  hardening). See ledger + worklog.
- SDKCore regressions #2–#7 resolved (public-API `objectId` optionality A1, order-preserving
  `soqlQuery` dedup A2, test-fidelity fixes).
- Per-class ledger retirement (task #17), then full-suite close-out (task #19).
- Ledger CLOSED; PR escalation summary written.

---

## B1 / B2 — FIXED 2026-08-15 (operator + reviewer approved; still flag in PR)

Per `CLAUDE.md` escalation rules (account switching, OAuth/credential, public API, sync
engine, localization, build system → STOP and flag). Full write-up + RESOLUTION notes:
`.claude/phase2-pr-escalation-summary.md` §B (both marked RESOLVED).

Both were production regressions vs the oracle; operator + reviewer approved byte-faithful
fixes, now committed in `fd7c21f07` and pushed. They REMAIN escalation-class (account
switching / public REST path) → **still call out in the PR** — but they are no longer open
decisions, and a fresh agent should NOT re-open or re-implement them.

- **B1 — `currentUserAccount` public setter (account switching / public API). FIXED.**
  `SFUserAccountManager.swift` public setter reverted to the bare synthesized form
  (`willChange` / `_currentUser = newValue` / `didChange`) — no managed-account gate, no
  `LastUserIdentity` persistence, matching the oracle's `@synthesize currentUser`. The gate +
  persistence still live in `setCurrentUserInternal(_:)`/`…Full(_:)`, which the internal
  login/switch paths + `TestSetupUtils` call directly (unchanged). Fixed `testNotEnabled` +
  `testShouldShowBackButton`.

- **B2 — `testAssertionForUnauthenticatedClient` (public REST send path). FIXED.**
  `SFRestAPI.swift` `send(...)` replaced the uncatchable Swift `assert()` with a catchable
  `NSInternalInconsistencyException`, gated to assertions-enabled builds (detected at runtime
  via the public `assert()` autoclosure side-effect — `#if DEBUG` is unusable: the framework
  target lacks `DEBUG` in `SWIFT_ACTIVE_COMPILATION_CONDITIONS`). Mirrors `NSAssert` (no-op in
  release → zero release delta). Test restored via the `SFSDKCatchException` bridge.

**Verify (already done):** full SDKCore suite, freshly-erased sim + live token =
**230 executed / 1 failure**; the sole failure is `testRedirect` (§D baseline, fails on the
oracle too). Former B1 pair + restored B2 test all PASS. Tracked failures 3 → 1.

---

## Remaining task list

- **Phase 2 / migration work: NONE pending.** Do not re-port, re-run retirement, or advance
  the marker. B1/B2 are FIXED (above) — do not re-open.
- **Human PR review** of the escalation set in `.claude/phase2-pr-escalation-summary.md`
  (§A committed prod changes, §B1/§B2 now-RESOLVED prod fixes, §C Phase-1 porting escalations,
  §D confirmed baselines). This is a human step — the agent's role is to answer questions.
- **Optional future work** (only if operator asks): chase forcedotcom/dev if it has moved
  past `b5d37d807` (re-run Phase 0 grouping from the marker) — forcedotcom is a moving
  target, a fresh backlog on re-fetch is expected/fine.

---

## Hard constraints (persist across sessions)

- **Never commit** `shared/test/test_credentials.json` or `ui_test_config.json` (gitignored).
  No hardcoded secrets/PII/tokens in source or tests. Never log refresh tokens/PII/full
  request-response bodies.
- **Escalation-class changes** (OAuth/token/credential, account switching, public API, sync
  engine, localization, build system) → STOP and flag for human PR review, do not auto-change.
- **Commit + push only to** the fork feature branch
  `origin/feature/objc-to-swift-test-migration`. Never `dev`. This is not a PR/merge.
- **Never advance the sync marker** `b5d37d807`.
- No new ObjC files; no force unwraps in production Swift.
- Confirm before irreversible destructive actions.
- Use `$CLAUDE_JOB_DIR/tmp` for temp files (not `/tmp` — parallel bg jobs share it).
- **Poller stays OFF** (operator decision 2026-07-19). Do not re-propose.
- Auto-compact is OFF. A bare "Continue" at resume = RECONTEXTUALIZE first (this file +
  memory + the source-of-truth docs; verify git state above), then report status — there is
  no pending Phase 2 work, so await operator direction.

### Testing environment gotchas
- Use single-pass `xcodebuild test` (build+test together) and serialize the sim across
  schemes. `build-for-testing` + `test-without-building` can leave `SQLCipher.framework`
  unassembled (dyld @rpath fail) or hit a "Busy/preflight" launch denial on a contended sim.
- SDKCore migration + oracle test hosts share bundle id `SalesforceSDKCoreTestApp` → they
  share the sim keychain + NSUserDefaults. Classify regression-vs-baseline only from a
  freshly-**erased** sim per clone (`xcrun simctl erase`).
- `test_credentials.json` is a build-phase COPY resource → baked into the `.xctest` bundle
  at build time. Refresh the file THEN `build-for-testing` (test-without-building uses the
  baked copy).
- Live oracle = the sibling `../SalesforceMobileSDK-iOS.dev` clone @ `b155f785d` (has the
  token-refresh coordinator, runs live auth). Merge-base predates it and hangs live auth.

---

## Source-of-truth docs (read for detail, in priority order)

1. `.claude/phase2-regression-worklog.md` — **SOURCE OF TRUTH** for all Phase 2 findings,
   root causes, commit hashes, full-suite verify.
2. `.claude/live-org-skip-ledger.md` — the (now CLOSED) live-org skip ledger, with the full
   execution + retirement + close-out history.
3. `.claude/phase2-pr-escalation-summary.md` — the one-place human PR sign-off list.
4. `.claude/upstream-sync-backlog.md` — Phase 1 per-unit porting detail (source of truth).
5. `.claude/pr-escalation-digest.md` — porting-era escalation digest.
6. `.claude/task11-audits.md`, `.claude/dropped-test-methods.md`, `.claude/test-baseline.md`
   — supporting audits (dropped-method restoration, assertion-fidelity, baselines).
7. Durable memory index:
   `~/.claude/projects/-Users-johnson-eric-Salesforce-Repositories-SalesforceMobileSDK-iOS-Migration-Pass-2/memory/MEMORY.md`
   — one-line pointers to per-topic memory files (Phase 1 complete, Phase 2 complete, etc.).
