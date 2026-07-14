# Upstream Sync Job — Self-Review Tracker

**Purpose:** Track resolution of the ranked self-review findings against the upstream sync poller spec (now canonical at `.claude/upstream-sync-job.md`; was `upstream-sync-job-v2.md` at repo root before the P2.5 consolidation). We work through these iteratively, together. Update the Status column as each item is proposed → approved → applied.

**Review date:** 2026-07-05
**Reviewed spec:** `.claude/upstream-sync-job.md` (canonical, post-consolidation; was v2 at repo root + superseded v1 — merged 2026-07-14 per P2.5)
**Live-repo facts at review time:** branch 48 ahead / 34 behind `origin/dev`; last fetch `Jun 8 15:27:58 2026` (frozen ~4 weeks); CronList empty; no `.claude/upstream-sync-marker`.

**Status legend:** ☐ open · ◐ proposed (awaiting operator approval) · ⧗ approved, applying · ☑ done · ✗ won't-fix (with reason)

---

## Findings (ranked)

| # | Sev | Title | Status | Notes |
|---|-----|-------|--------|-------|
| P0.1 | P0 | Simulator name wrong — spec hardcodes `iPhone 16`; machine only has iPhone 17 family. Gate commands fail immediately. | ☑ done | Applied 2026-07-05: builds → `generic/platform=iOS Simulator`; tests → runtime `simctl`+`jq` UDID resolver w/ fail-loud guard. All 3 occurrences in v2 fixed. |
| P0.2 | P0 | Gate says "tests ✓" but ignores documented baseline (16 expected failures + MobileSync integration untestable locally). Operator blocked on pre-existing red forever. Gate must be "no *new* failures vs. baseline." | ☑ done | Applied 2026-07-14: gate rewritten to SET-based subset check vs. `.claude/test-baseline-ids.txt`; new `.claude/test-baseline.md` registry (shrinking ratchet, anti-laundering); honest trailer. Empirical run reconciled 12-vs-6 (6 methods × FTS4/FTS5). |
| P0.2b | P0 | **NEW (found during P0.2 empirical run).** SmartStore run 2026-07-05 = 177/130/47; ~35 of 47 are setUp CRASHES in `SFSmartSqlTests.createUserAccount()` / `SFMultipleSmartStoresTests.setUpSmartStoreUser()`. | ☑ done | **RESOLVED 2026-07-14.** Root cause was NOT env-drift — it was the `OAuthCredentials(...)!` convenience-init bug (`f11e4754f` missed these 2 files). Swapped both to `.credentials(...)` factory. SmartStore: 47 fails/~35 crashes → **14 fails / 0 crashes**. 2 newly-unmasked non-crash failures (testGetGlobalStoreNames, testCleanupRegexpFaster) baselined w/ rationale. SmartStore gate now clean. |
| P0.2c | P0 | **NEW (found during #4043 gate, 2026-07-14).** SalesforceSDKCore crash cluster; credentials portion = same `OAuthCredentials(...)!` bug as P0.2b. | ◐ partial | **Credentials portion FIXED 2026-07-14** (10 SDKCore test-helper sites → `.credentials(...)` factory; those crashes gone). A DISTINCT assert() cluster remains → split out as **P0.2d**. SDKCore gate still provisional until P0.2d. |
| P0.2d | P0 | **NEW (found during P0.2c fix, 2026-07-14).** Distinct from credentials: debug `assert()` failures in production Swift (`SFSDKAuthCommand.swift:48` "Path cannot be nil" ×22, `SFOAuthCoordinator:961`, `SFSDKEncryptedURLCache:37`) when tests build command/URL/cache objects with empty scheme/path. Concentrated in `SFSDKURLHandlerManagerTest`, `SFSDKUrlCacheTests`, IDP command tests. NOT baselined → SDKCore gate provisional. | ☐ open | Needs separate investigation (likely test setup passing empty scheme/path, or an assert that should be a graceful precondition). NOT a credentials issue. See `.claude/test-baseline.md` P0.2d block. |
| P1.3 | P1 | PR-grouping heuristic only handles true merge commits; misses squash-merges (`… (#4042)` in subject, no merge parent). Must also parse `(#\d+)` from subject. | ☑ done | Applied 2026-07-14: Step 4 rewritten as deterministic 2-pass — Pass A `git rev-list M^2 ^M^1` (topology, interleave-immune), Pass B `(#NNNN)` subject parse; claimed-first + octopus + master-merge edge cases documented. Verified live (#4041=5 commits, #4046=1, tip squash #4042). |
| P1.5 | P1 | Analysis not durable before work begins: scalar marker can't track out-of-order progress, and the expensive Cat-B intent/Swift-mapping analysis evaporates on compaction. Raised by operator (high-volume backlog, costly per-unit commit→contribution mapping). | ☑ done | Applied 2026-07-14: new `.claude/upstream-sync-backlog.md` ledger — per-unit status vocab + persisted Cat-B detail blocks; marker reframed as linear done-floor + composition rule (advance only when units ≤X are ported/skipped); poller step 7 merge-not-clobber (operator chose); Cat-B workflow writes analysis to ledger; activation seeds ledger + "analyze whole backlog first" pre-work. Changes-from-v1 row #8. |
| P1.5a | P1 | Operator-reviewable display: ledger should *show* migration status of the history at a glance, not just hold data. Raised by operator. | ☑ done | Applied 2026-07-14: ledger format is now a dashboard — header + *Migration status* rollup (glyph counts + 20-cell progress bar, filled = ported+skipped, plus separate libs/-impacting fraction) + Units table + Cat-B detail. Rollup is a derived projection of the table (regenerate, never hand-edit divergently; mismatch = lint fail); poller regenerates it in step 7; activation seeds an empty rollup. Format chosen by operator (dashboard over mapping-table/kanban). |
| P1.4 | P1 | No heartbeat/liveness signal + 7-day auto-expiry contradicts "durable". This is the failure that already happened (job never activated, nothing surfaced the gap for ~5wk). Need last-run timestamp + staleness check + renewal guidance. | ☑ done | Applied 2026-07-14: two-clock model; heartbeat `.claude/upstream-sync-last-run` every firing (step 2); session-resume staleness check (wired into memory); 30-day fuse + re-activation ritual; on-activation bootstrap of marker+heartbeat. Confirmed live: no cron, no marker, no heartbeat — job never ran. |
| P2.5 | P2 | Two competing spec files (v1 `.claude/`, v2 root) both untracked, both disagree. Consolidate to one in `.claude/`, delete the other, commit it. | ☑ done | Applied 2026-07-14: canonical v2 → `.claude/upstream-sync-job.md`; root v2 deleted; v1's stale backlog table preserved (marked stale) in Context; self-ref + test-baseline.md + tracker refs updated. **Not yet git-committed** (all still untracked) — commit is operator-gated. |
| P2.6 | P2 | Category letters skip "E" (A/B/C/D/F). Cosmetic; renumber or note E intentionally unused. | ☑ done | Applied 2026-07-14: note added under classify table — E intentionally unused (stable labels, not contiguous). |
| P2.7 | P2 | `git fetch origin dev` may only move FETCH_HEAD on older git; be explicit that fetch must update the `origin/dev` remote-tracking ref. | ☑ done | Applied 2026-07-14: step 1 now uses `git fetch origin` (+ explicit `origin dev:refs/remotes/origin/dev` refspec fallback) with rationale. |

## Keep as-is (validated good — do not regress)
- Poller never mutates tree; report-only, human-gated marker advance (right call for public SDK).
- Step 2 "Locate in Swift" refuses line-for-line-mirror fallacy.
- Rollback via `git revert`, never force-push (matches audit-retention philosophy).
- Commit trailer format (`Upstream: <hash>`, `Files translated:`) makes rollback grep work.

---

## P0.1 — Proposed solution (2026-07-05)

**Problem restated:** The spec's mandatory verification gate hardcodes `-destination "platform=iOS Simulator,name=iPhone 16"`. No iPhone 16 exists on this machine (only iPhone 17 / 17 Pro / 17 Pro Max / 17e). Every build/test command in the gate fails with "Unable to find a device matching…" before any real verification runs. Hardcoding *any* specific device name just moves the same breakage to the next Xcode/runtime bump.

**Root cause:** A device *name* is an environment-specific, time-varying identifier baked into a durable spec. The spec should not name a device at all where it doesn't have to, and where it must run tests, it should resolve the device dynamically at runtime.

**Two-part fix (matched to what each command actually needs):**

1. **Build-only steps → name-free generic destination.** Building a scheme needs a platform, not a booted device:
   ```bash
   xcodebuild build -workspace SalesforceMobileSDK.xcworkspace \
     -scheme <AffectedLibrary> -sdk iphonesimulator \
     -destination "generic/platform=iOS Simulator" | tail -5
   ```
   This can never drift on a device rename — there is no device name to be wrong.

2. **Test steps → resolve a real simulator UDID at runtime.** Tests need a concrete simulator, so pick one that exists instead of guessing a name. Prepend a resolver and pass the UDID:
   ```bash
   # Resolve newest available iPhone simulator (name-agnostic, future-proof)
   SIM_UDID=$(xcrun simctl list devices available --json \
     | jq -r '[.devices[][] | select(.isAvailable and (.name|test("^iPhone")))]
              | sort_by(.name)[-1].udid')
   [ -z "$SIM_UDID" ] && { echo "No iPhone simulator available"; exit 1; }

   xcodebuild test -workspace SalesforceMobileSDK.xcworkspace \
     -scheme <AffectedLibrary> -sdk iphonesimulator \
     -destination "id=$SIM_UDID" | tail -20
   ```
   Verified on this machine: resolver returns a valid UDID; `jq` is present at `/usr/bin/jq`.

**Why not just swap `iPhone 16` → `iPhone 17 Pro Max`?** It repeats the original mistake one Xcode release later, and it's the value already scattered through other memories — a rename in one place, stale everywhere else. Dynamic resolution removes the class of bug, not this instance.

**Guardrails to add to the spec alongside the commands:**
- State the assumption explicitly: "Gate assumes any available iPhone simulator; the exact model is irrelevant to the ObjC↔Swift semantic-equivalence check."
- Keep the `[ -z "$SIM_UDID" ]` guard so a machine with zero simulators fails loud, not silent-green.
- Note `jq` as a gate dependency (present in this env; document it so a fresh env installs it).

**Scope:** edits `upstream-sync-job-v2.md` gate commands (lines ~96–111) and the v1 build-verification block if we keep it. Pure documentation change — no working-tree/build-system impact, so not operator-escalation-gated on its own; but per our iterative agreement, I'll apply only after you approve.
