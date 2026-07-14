# Upstream Sync Poller — Job Specification

> Canonical spec. Supersedes the earlier v1 (see *Changes from v1* at the end). Lives in `.claude/`
> alongside the artifacts it references (`upstream-sync-marker`, `upstream-sync-last-run`,
> `test-baseline*`).

## Context

This repository (`SalesforceMobileSDK-iOS`) underwent a major migration from Objective-C to Swift on the feature branch `feature/objc-to-swift-test-migration`. The migration converted production `.m`/`.h` files to `.swift` equivalents. Original ObjC files remain in the filesystem but are de-referenced from Xcode project files (not compiled).

Meanwhile, `origin/dev` continues to receive commits in the mixed ObjC/Swift codebase. Those commits cannot be merged or rebased — they must be **semantically translated** into the pure-Swift branch.

### Current State (as of 2026-06-08)

- **Feature branch:** `feature/objc-to-swift-test-migration` (48 commits ahead, 34 behind `origin/dev`)
- **Origin:** `https://github.com/JohnsonEricAtSalesforce/SalesforceMobileSDK-iOS.git`
- **Default branch:** `dev`
- **Migration strategy:** ObjC files de-referenced from `.xcodeproj` (not renamed to `.bak`); originals remain on disk at their original paths
- **Upstream commits touching libs/:** ~16 (mix of ObjC and Swift file changes)

**Last-known backlog classification (snapshot 2026-06-08 — STALE, regenerate via Steps 3–6).**
Kept only as a starting reference; the live figures come from running the poller, not from this table.

| Category | Count | Key items |
|---|---|---|
| A (pure Swift) | ~6 | BiometricAuthenticationManager changes, NativeLoginManagerTests |
| B (ObjC→Swift translation) | ~6 | SFUserAccount thread-safety, SFOAuthCoordinator my-domain, SFLoginViewController, SFUserAccountManager, SFLogger |
| C (build/config) | ~2 | Possible `.xcodeproj` changes from new files |
| D (new files) | ~3 | WelcomeDiscoveryLoginHostTests, new test helpers |
| F (non-libs) | ~17 | CI schedule, docs, RTR test config |

---

## Job Configuration

**Schedule:** Every 4 hours on weekdays  
**Cron:** `23 */4 * * 1-5` (minute 23 to avoid contention; offset from Android job at :17)  
**Durable:** Yes — persists across session restarts  
**Auto-expires:** 30 days — a deliberate safety fuse so a forgotten job cannot poll forever

**Two independent clocks (do not conflate):**
- *Durable* governs **how** the job is registered — it survives session/app restarts while active.
- *Auto-expires* governs **lifetime** — the scheduler silently drops the job when the fuse blows.

These are not the same setting and they can both be true. The scheduler gives NO notice on expiry,
so "durable" does not mean "runs forever." This spec compensates with a **heartbeat + staleness
check** (see *Liveness* below): expiry becomes observable instead of silent. On expiry, re-activate
per *To Activate This Job* — treat re-activation as a standing operator task until the feature branch
is merged or abandoned. (Expiry was raised from 7→30 days so the fuse and the human review cadence
aren't fighting weekly.)

> **Why this section exists:** as of 2026-07-14 the job had been specified since 2026-06-08 but
> **never fired once** — no cron registered, no marker, `origin/dev` last fetched Jun 8 (~5 weeks
> stale). A dead poller and a quiet-but-healthy poller were indistinguishable. The liveness
> mechanism below is the fix for exactly that silent-death failure mode.

---

## What It Does Each Firing

1. **Fetch** — `git fetch origin` (silent unless error). Use `git fetch origin` (not `git fetch origin dev`): the bare-refspec form can leave `refs/remotes/origin/dev` unchanged on some git versions (updating only `FETCH_HEAD`), which would make every later `origin/dev` comparison read a stale ref. If a narrower fetch is required, use an explicit refspec — `git fetch origin dev:refs/remotes/origin/dev` — so the remote-tracking ref is guaranteed current.

2. **Heartbeat** — On every successful firing (whether or not new commits are found), write a liveness
   record to `.claude/upstream-sync-last-run`: an ISO-8601 UTC timestamp plus the `origin/dev` HEAD
   observed. This is the proof-of-life that makes silence verifiable rather than assumed. It is
   **distinct from the marker** and is written **autonomously** — it records *observation*, not
   *processed work*, so it does not touch the operator gate.
   ```bash
   printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(git rev-parse origin/dev)" \
     > .claude/upstream-sync-last-run
   ```

3. **Detect** — Compare `origin/dev` against a sync marker file (`.claude/upstream-sync-marker`) that stores the last-reviewed upstream commit hash. If no marker exists, uses `git merge-base HEAD origin/dev` as starting point.

4. **Inventory** — List new upstream non-merge commits touching `libs/`, build files, Podspecs, or test files since the marker.

5. **Group** — Identify logical change units by PR, using git topology (NOT "consecutive commits" — topological log order interleaves commits from different PRs, so position is not a reliable key). `origin/dev` lands work in three styles; the grouping is a deterministic two-pass over `MB..origin/dev` where `MB = git merge-base HEAD origin/dev`:

   **Pass A — true merge PRs (second-parent reachability).** For each merge commit `M`, the PR's commits are exactly the second-parent side: `git rev-list M^2 ^M^1`. This is set-based, so interleaving in log order doesn't matter. Label = merge subject (`Merge pull request #NNNN …`); net diff = `git diff M^1 M`.

   **Pass B — non-merge commits (subject PR-ref).** For every commit NOT already claimed by a Pass-A group, parse a trailing `(#\d+)` from the subject:
   - Squash-merge (has `(#NNNN)`) → its own single-commit group, label = subject.
   - Direct push (no `(#NNNN)`) → standalone commit.

   Present each group as a single unit with:
   - The PR title / merge subject as the group label
   - The net diff of the group (not individual commits)
   - The list of individual commit hashes for traceability

   ```bash
   MB=$(git merge-base HEAD origin/dev)
   # Pass A: PR groups from merge commits (members = PR side only, bounded to MB..origin/dev)
   for M in $(git rev-list --merges $MB..origin/dev); do
     echo "GROUP $(git log -1 --format='%s' $M)"
     git rev-list $M^2 ^$M^1                    # member commits (excludes mainline via ^M^1)
   done
   # Pass B: non-merge commits, keyed by (#NNNN) in subject; no ref → standalone
   git log --no-merges --format='%h %s' $MB..origin/dev
   ```

   **Grouping edge cases (handle explicitly, never silently drop):**
   - **Claimed-first:** a commit reachable from a Pass-A PR side is owned by that group; it does not also appear standalone in Pass B.
   - **Octopus merges** (>2 parents; none in the current backlog): union of the `^2 … ^N` sides.
   - **"Merge from master" commits** (e.g. `a2d6db8ae`, `725291236`): fold master→dev and can reach large unrelated history. `^M^1` bounds membership to the PR side within `MB..origin/dev`, so ancient master commits are not dragged in — verify these groups don't balloon.

6. **Classify** — Categorize each group (or standalone commit):

   | Cat | Criteria | Translation Effort |
   |-----|----------|--------------------|
   | **A** | Only touches `.swift` files present on both branches | Cherry-pick + build-verify (low) |
   | **B** | Touches `.m`/`.h` files that this branch has as `.swift` | Semantic translation (high) |
   | **C** | Build/config (`.xcodeproj`, Podspecs, `Package.swift`, CI) | Manual apply + verify (medium) |
   | **D** | Adds new files not on feature branch | Cherry-pick; new `.m`/`.h` → convert (medium) |
   | **F** | Non-libs (docs, CI, scripts, README) | Cherry-pick (low) |

   > Category **E** is intentionally unused (the letters are stable labels, not a contiguous
   > sequence — skipping E avoids renumbering existing categories if a new one is ever inserted).

7. **Ledger sync (merge, never clobber)** — Reconcile the grouped/classified units into the durable
   backlog ledger `.claude/upstream-sync-backlog.md` (see *Backlog Ledger* below). The poller:
   - **appends** any newly-appeared unit as a `pending` row (label, member hashes, category),
   - **refreshes** only the header line (marker floor, `origin/dev` HEAD, last-analyzed timestamp),
   - **flags** (`⚠ stale-ref`) any existing ledger member hash no longer reachable from `origin/dev`.

   It **never** edits a row whose status is not `pending`, and **never** touches Category-B detail
   blocks or the operator-owned columns (`Status`, `Port commit`, `Notes`). This mirrors the
   heartbeat/marker split: the poller may record *observation* (a unit exists) but not *judgment*
   (its analysis or disposition).

8. **Report** — Present a summary table to the operator:
   - Total new commits since last check, grouped into logical units
   - Breakdown by category with commit hashes and one-line descriptions
   - Highlight any Category B groups (requiring human-guided translation)
   - Running total of unprocessed backlog, and any `⚠ stale-ref` / ledger-vs-marker drift warnings

9. **No Action** — The poller NEVER modifies the working tree, commits, or cherry-picks. Its only
    disk writes are *observational*: the heartbeat (step 2) and the ledger skeleton merge (step 7,
    `pending` rows + header only). It never advances the marker, edits an analyzed/ported/deferred
    ledger row, or writes Category-B analysis. The operator invokes translation work separately.

---

## Translation Workflow (Category B — Semantic Translation)

This is the most accuracy-critical path. Each Category B group follows this procedure.

> **Persist Steps 1–2 to the ledger.** The intent and Swift-mapping produced below are the expensive,
> compaction-fragile analysis. Write them into the unit's Category-B detail block in
> `.claude/upstream-sync-backlog.md` and set its status to `analyzed` *before* touching code — so the
> reasoning survives a session boundary and the work can be picked up out of order.

### Step 1: Understand Intent

Read the upstream diff (the *net* diff for a group, not individual commits) and the commit/PR message. Identify:
- What behavior changed?
- Why? (commit message, PR description)
- What's the scope? (single method fix, new feature, refactor)

→ Record as the **Intent** line in the ledger detail block.

### Step 2: Locate in Swift

The Swift file is NOT a line-for-line mirror of the ObjC. The migration refactored names, extracted protocols, and reorganized code. For each semantic change:
- Identify the *concept* being changed (e.g., "thread-safety added to `encodeWithCoder`")
- Search the Swift file for where that concept lives (may be a different method name, different file location, or split across an extension)
- If the mapping is ambiguous, examine the git history of the Swift file to trace where the ObjC logic landed during migration

→ Record as the **Swift mapping** + **Files** lines in the ledger detail block. Mark the unit
`analyzed`. (When code work begins, move it to `in-progress`; after the gate passes, `ported` with
the port-commit hash.)

### Step 3: Apply Change in Swift

Apply the semantic change idiomatically in Swift:
- Use Swift concurrency patterns (not ObjC-style locks translated literally)
- Match the existing Swift code's style and conventions on the feature branch
- If the upstream change adds ObjC patterns that have no Swift equivalent (e.g., `@synchronized`), translate to the idiomatic Swift equivalent (`actor`, `OSAllocatedUnfairLock`, etc.)

### Step 4: Update ObjC Reference

Overwrite the de-referenced `.m`/`.h` file on disk with the upstream commit's current content. This file is not compiled but serves as the verification reference.

### Step 5: Verification Gate (mandatory)

All of the following must pass before the operator advances the sync marker:

```bash
# 1. Build the affected library.
#    Build-only needs a platform, not a booted device — use the name-free
#    generic destination so this can never break on a simulator rename.
xcodebuild build -workspace SalesforceMobileSDK.xcworkspace \
  -scheme <AffectedLibrary> \
  -sdk iphonesimulator \
  -destination "generic/platform=iOS Simulator" | tail -5

# 2. Run tests for the affected library.
#    Tests need a concrete simulator, so resolve the newest AVAILABLE iPhone sim
#    at runtime rather than hardcoding a model name (models change per Xcode release).
SIM_UDID=$(xcrun simctl list devices available --json \
  | jq -r '[.devices[][] | select(.isAvailable and (.name|test("^iPhone")))]
           | sort_by(.name)[-1].udid')
[ -z "$SIM_UDID" ] && { echo "GATE FAIL: no iPhone simulator available"; exit 1; }

#    Capture a result bundle so failing identifiers can be diffed against the baseline.
RB=$(mktemp -d)/gate.xcresult
xcodebuild test -workspace SalesforceMobileSDK.xcworkspace \
  -scheme <AffectedLibrary> \
  -sdk iphonesimulator \
  -destination "id=$SIM_UDID" \
  -resultBundlePath "$RB" | tail -20

# 3. Diff failing test identifiers against the recorded baseline (SET-based, not count-based).
#    Emit "Class/method" for every failed test case, then subtract the baseline set.
#    Any identifier that remains is a candidate REGRESSION → gate fails.
xcrun xcresulttool get test-results tests --path "$RB" 2>/dev/null \
  | jq -r '[.. | objects | select(.nodeType?=="Test Case" and .result?=="Failed")]
           | .[] | .name' | sed -E 's/\(\)$//' | sort -u > /tmp/gate-failed.txt
# Compare against the committed baseline ID list. NEW = failing now but NOT baselined:
comm -23 /tmp/gate-failed.txt \
  <(grep -vE '^\s*$' .claude/test-baseline-ids.txt | sort -u)
#   → non-empty output = GATE FAIL (regression). Empty = pass (subset of baseline).
#
# NOTE: xcresulttool's Test-Case ".name" emits the bare method (e.g. "testFoo"), while the
# baseline file stores "Class/method". Before first production use, pin the exact identifier
# form against one real run and normalize BOTH sides to match (add the class via the parent
# "Test Suite" node, or store bare method names in the baseline). The 2026-07-05 capture
# yielded bare method names; the baseline was written in Class/method form for disambiguation.

# 4. Operator confirms semantic equivalence
# (compare the ObjC diff against the Swift diff — both should express the same intent)
```

**The sync marker MUST NOT advance until all four pass.** Test verification is a **baseline
subset check**, NOT "all tests green": this suite has known, non-regression failures recorded in
`.claude/test-baseline.md`. The gate passes iff the set of failing identifiers is a **subset** of
that baseline. A failure whose identifier is **not** in the baseline is a candidate regression —
diagnose (pre-existing vs. introduced) before advancing the marker. **Fewer** failures than
baseline is a pass; shrink the baseline to match (it is a ratchet — see that file).

**Do not baseline your way to green.** Adding a newly-failing identifier to the baseline to pass
the gate is prohibited except by explicit operator decision with recorded rationale. As of the
2026-07-05 confirmation the SmartStore scheme has an **unresolved crash cluster** (setUp crashes in
`SFSmartSqlTests`/`SFMultipleSmartStoresTests`) that is deliberately *not* baselined — SmartStore
gate results are provisional until that is root-caused (tracker P0.2b). Re-confirm the baseline
whenever the toolchain changes.

**Device-independence note:** the exact simulator model is irrelevant to an ObjC↔Swift semantic-equivalence check — any available iPhone simulator is acceptable. Never hardcode a device *name* in this spec; it is an environment-specific, time-varying value. The empty-`SIM_UDID` guard must fail loud (a machine with zero simulators is a gate failure, never a silent green). **Dependency:** the resolver requires `jq` (present on the current review machine at `/usr/bin/jq`; install it in any fresh gate environment).

### Commit Format

```
Port: <original commit/PR message>

Upstream: <hash> (or <hash1>..<hashN> for groups)
Files translated: SFUserAccount.m→UserAccount.swift, ...
ObjC reference files updated to match upstream
Verified: build ✓, tests match baseline ✓ (0 new failures vs .claude/test-baseline.md; <N> expected failures unchanged; MobileSync integration skipped — CI-only)
```

The trailer must state the real posture, not a bare "tests ✓": how many known failures were
expected, that there were zero *new* ones, and what was skipped (never silently counted as green).

---

## Cherry-Pick Workflow (Categories A, D, F)

Even "low effort" cherry-picks can fail silently due to feature-branch refactors.

### Procedure

1. Attempt `git cherry-pick <hash>` (or `<hash1> <hash2> ...` for a group)
2. If conflict: resolve manually, understanding why the branches diverged at that point
3. **Build-verify** (mandatory for A and D, advisory for F):
   ```bash
   xcodebuild build -workspace SalesforceMobileSDK.xcworkspace \
     -scheme <AffectedLibrary> \
     -sdk iphonesimulator \
     -destination "generic/platform=iOS Simulator" | tail -5
   ```
4. For Category A: if the cherry-picked Swift file references methods/properties that were renamed during migration, fix the references before committing
5. For Category D (new `.m`/`.h` files): do NOT add to Xcode project. Convert to Swift immediately, add the `.swift` to the project, and rename the original to `.m.upstream` or leave de-referenced

---

## Build/Config Workflow (Category C)

### Xcode Project Files (`.pbxproj`)

Upstream commits may modify `.xcodeproj/project.pbxproj` files. The feature branch has extensively modified these to de-reference ObjC and add Swift. Cherry-picking `.pbxproj` changes will almost always conflict.

**Protocol:**
- Do NOT cherry-pick blindly
- Read the upstream diff to understand what was added/removed
- Apply the equivalent change manually to the feature branch's `.pbxproj`
- If a new `.m`/`.h` file was added upstream, it should NOT be referenced in the project (needs conversion first — treat as Category D)
- Build-verify after every `.pbxproj` change

### CocoaPods / Podspecs

If upstream modifies Podspec `source_files` patterns or `exclude_files`, verify that the feature branch's exclusion patterns still correctly hide the de-referenced ObjC files.

### Header Files (`.h`)

Unlike Android (where `.java.bak` has no compilation effect), iOS `.h` files can still be found by `#import` statements even if the `.m` is not in the Xcode project. If upstream modifies a `.h` file that this branch has converted:
- Update the `.h` file to match upstream (keeps the reference current)
- Apply the semantic change to the `.swift` file
- Verify no remaining `#import` of that header exists in compiled sources

---

## Rollback Procedure

If a ported commit introduces a regression discovered later:

1. **Identify** — find the `Port:` commit via `git log --grep="Port:"` or by the `Upstream: <hash>` trailer
2. **Revert** — `git revert <port-commit-hash>` (creates a new commit, preserves history)
3. **Restore ObjC reference** — check out the previous version of the de-referenced ObjC file: `git checkout <port-commit-hash>~1 -- path/to/File.m`
4. **Re-translate** — once the root cause is understood, redo the translation correctly as a new commit
5. **Never** force-push or rebase away a bad port — the history of what was attempted and why it failed is valuable

---

## Sync Marker

File: `.claude/upstream-sync-marker`  
Contents: single commit hash of the last upstream commit the operator has acknowledged/processed.

- Created on first run using `git merge-base HEAD origin/dev`
- Updated only when the operator explicitly marks commits as processed
- **Gate:** marker advances only after the verification gate passes for all commits/groups up to that point
- The poller reads it but never writes it automatically

**Marker is a linear floor, not the whole state.** The marker is a *scalar* — "everything at or
below this commit is fully done." It cannot express out-of-order progress (port an easy Cat-A now,
defer a hard Cat-B, skip a docs-only F). That ragged frontier lives in the **Backlog Ledger**
(below). Composition rule:

> The marker may advance to commit **X** only when **every ledger unit at or below X is `ported` or
> `skipped`**. If a `deferred`/`pending` unit sits below a `ported` one, the marker stays put and the
> ledger carries the real state. **Do not force-advance the marker past a non-done unit** to make
> progress "look" linear — that discards the ledger's out-of-order truth.

The marker and the ledger never duplicate information: the marker records the contiguous-done
*prefix*; the ledger records every unit *not yet foldable into that prefix*.

### The three durable artifacts — never conflate

| File | Meaning | Who writes it | When |
|------|---------|---------------|------|
| `.claude/upstream-sync-marker` | last **processed** commit — linear done-floor | operator only, by hand | after verification gate |
| `.claude/upstream-sync-last-run` | last **observation** (poller ran) — heartbeat | poller, autonomously | every firing (step 2) |
| `.claude/upstream-sync-backlog.md` | **per-unit** status + Cat-B analysis — ragged frontier | poller (skeleton only) + operator (status/analysis) | step 7 merge / on work |

A healthy-but-idle poller advances `last-run` while `marker` stays put (nothing to process). A dead
poller advances neither. The ledger holds what the scalar marker can't: which units are done,
deferred, or mid-analysis, and *why*. Conflating any two would make idle look like progress, death
look like health, or a scalar stand in for a partial-order — the failures this design prevents.

---

## Backlog Ledger

File: `.claude/upstream-sync-backlog.md`

**Why it exists.** The backlog is high-volume and the expensive part is per-unit: mapping a squashed
or merged PR to a single logical contribution, and — for Category B — working out *what* changed,
*why*, and *where it lands* in the refactored Swift. That analysis is non-deterministic human
judgment. Without a durable home it is produced in the session report and **lost on compaction**,
forcing a costly re-derivation from raw diffs every time. The ledger makes the analysis a durable
artifact and lets work proceed **out of order** without losing track of it — which the scalar marker
cannot do.

**Recommended flow: analyze the whole backlog first, then work it.** Do one analysis pass that
groups + classifies + writes Category-B intent for the *entire* current backlog into the ledger
(expensive, done once, durable). Then process units off the ledger in any order, updating status as
you go. Do not begin porting before the ledger is populated — that is the pre-work this question was
about.

### Format (Markdown — git-diffable, operator-editable)

```markdown
# Upstream Sync Backlog Ledger

Marker (done floor): <hash>  ·  origin/dev HEAD: <hash>  ·  Last analyzed: <ISO-8601 UTC>

| PR / unit | Members | Cat | Status | Port commit | Notes |
|-----------|---------|-----|--------|-------------|-------|
| #4041 biometric opt-in | e6fcb9be9…00153e341 (5) | B | ported | <hash> | see detail |
| #4042 SFUserAccount thread-safety | bac017113 (squash) | B | analyzed | — | see detail |
| #4046 don't add my domain | 245954246 (1) | B | deferred | — | blocked: needs my-domain org |
| #4047 nightly schedules | 97ab8b544 (1) | F | skipped | — | CI-only, no libs/ impact |

## Category-B detail

### #4042 — SFUserAccount thread-safety in encodeWithCoder
- **Intent:** upstream guarded ivar reads in encodeWithCoder to fix a race.
- **Swift mapping:** UserAccount.swift uses synthesized Codable (no encodeWithCoder). Race maps to
  concurrent `credentials`/`idData` access → guard with existing OSAllocatedUnfairLock, NOT a
  literal @synchronized translation.
- **Files:** SFUserAccount.m → UserAccount.swift (+ ObjC reference update)
- **Open questions:** confirm idData isn't already lock-protected elsewhere.
```

### Status vocabulary (small on purpose; every non-obvious state carries a one-line reason)

`pending` → `analyzed` → `in-progress` → `ported` (gate passed) · `deferred` (understood, waiting —
reason required) · `skipped` (no action needed — reason required).

### Write authority (mirrors marker/heartbeat)

- **Poller (step 7, autonomous):** append new units as `pending`; refresh the header line; flag
  `⚠ stale-ref` on member hashes no longer reachable from `origin/dev`. **Merge, never clobber** —
  it never edits a non-`pending` row and never touches a Category-B detail block.
- **Operator (on work):** all status transitions, port-commit hashes, reasons, and Category-B
  analysis. In-session analysis (often Claude-assisted) is **written here** so it survives compaction.

### Invariants & edge cases

- **Ledger↔marker drift check:** everything at/below the marker must be `ported`/`skipped` in the
  ledger. The poller warns on violation; it does not auto-fix.
- **Deferred-below-ported:** legal and expected. The marker simply cannot pass the deferred unit
  until it resolves. This is the ragged frontier working as designed — do not "fix" it.
- **Vanished member hash** (upstream history rewrite, e.g. a "Merge from master"): poller marks the
  unit `⚠ stale-ref` and preserves its analysis for operator review rather than dropping it.

---

## Liveness (heartbeat + staleness check)

The scheduler gives no notice when a job expires or dies, and the poller is silent on healthy-idle
firings (see *Silent Behavior*). Without a separate liveness signal, "quiet" and "dead" are
indistinguishable — the exact gap that let this job sit un-activated for ~5 weeks. The heartbeat
(step 2) makes silence *verifiable*.

**Staleness check** — run at session start on this repo, or any time you want to confirm the poller
is alive. A dead poller cannot report its own death, so this check lives with the operator/session,
not inside the poller:

```bash
LR=$(head -1 .claude/upstream-sync-last-run 2>/dev/null)
if [ -z "$LR" ]; then
  echo "STALE: poller has NEVER run (no heartbeat) — activate it (see 'To Activate This Job')."
else
  echo "Last poll: $LR"
  echo "  Healthy if within ~2 poll intervals (~8h on weekdays). Older ⇒ poller likely expired/dead;"
  echo "  re-activate. Absent heartbeat is NOT healthy silence — it means it never ran."
fi
```

**Absent heartbeat ≠ healthy silence.** Healthy silence still writes a fresh `last-run`; a missing or
stale `last-run` means the poller is not running. This check is wired into session-resume via project
memory so a new session on this repo surfaces a dead poller without the operator having to remember.

---

## Operator Commands (manual, not part of the cron)

After reviewing a report, the operator would:

| Command | Category | Verification Required | Ledger effect |
|---------|----------|----------------------|---------------|
| Analyze backlog into ledger | all | — | seed intent/mapping; set units `pending`→`analyzed` |
| Translate group `<hashes>` | B | Build + tests + operator eyeball | `analyzed`→`in-progress`→`ported` (+ port hash) |
| Cherry-pick `<hashes>` | A, F | Build (A mandatory, F advisory) | →`ported` (+ port hash) |
| Apply config change from `<hash>` | C | Build mandatory | →`ported` (+ port hash) |
| Convert and port new files from `<hash>` | D | Build + tests | →`ported` (+ port hash) |
| Defer / skip a unit | any | — | →`deferred`/`skipped` (reason required) |
| Advance sync marker to `<hash>` | — | All ledger units at/below `<hash>` are `ported`/`skipped` | marker moves; ledger unchanged |

The operator may also:
- Ask Claude to show the ObjC diff and Swift diff side-by-side for a Category B translation (verification aid)
- Ask Claude to identify where a specific ObjC change maps in the Swift codebase (Step 2 assistance)
- Revert a bad port per the rollback procedure above (also flip the ledger unit back to `analyzed`)

---

## Silent Behavior

If `origin/dev` has no new commits since the marker, the poller outputs one line:
> "Upstream sync: no new commits since `<marker-hash>` (last checked <timestamp>)"

And does NOT interrupt workflow. **Even on this silent path it still writes the heartbeat**
(step 2) — silence is only safe because `last-run` is refreshed, so the staleness check can tell
healthy-idle from dead. A silent poll that skips the heartbeat is a bug.

---

## Relationship to Android Sync Job

An identical job runs against the Android repository (`SalesforceMobileSDK-Android.Migration-Pass.2`) with:
- Cron at minute :17 (this job at :23)
- `.java.bak` rename strategy instead of ObjC de-reference
- Same classification categories and PR grouping
- Same sync marker and verification gate mechanisms
- Gradle build verification instead of Xcode

Both jobs report independently. Cross-platform feature parity (e.g., "attestation flow added to Android — does iOS need it too?") is the operator's responsibility, not the poller's.

---

## To Activate This Job

In a Claude Code session in this repository, run:

```
Create a durable cron job per .claude/upstream-sync-job.md
```

The session will create the CronCreate with:
- `cron: "23 */4 * * 1-5"`
- `durable: true`
- `expiresInDays: 30` (the safety fuse — see *Job Configuration*)
- Prompt text that implements the fetch/heartbeat/detect/inventory/group/classify/ledger/report workflow described above

**On-activation bootstrap (all three artifacts, so a fresh job is distinguishable from a never-activated one):**
```bash
git fetch origin
git merge-base HEAD origin/dev > .claude/upstream-sync-marker      # last processed = merge-base
printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(git rev-parse origin/dev)" \
  > .claude/upstream-sync-last-run                                  # initial heartbeat
# Seed an empty ledger header; the first firing (step 7) populates pending rows.
{ echo "# Upstream Sync Backlog Ledger"; echo; \
  printf 'Marker (done floor): %s  ·  origin/dev HEAD: %s  ·  Last analyzed: %s\n' \
    "$(cat .claude/upstream-sync-marker)" "$(git rev-parse origin/dev)" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"; \
} > .claude/upstream-sync-backlog.md
```
Without this, a just-activated poller and a dead one both look identical until the first firing
(up to 4h later). Bootstrapping removes that ambiguity window.

**Then, before porting any work:** run one analysis pass to populate the ledger with intent +
Swift-mapping for the whole backlog (see *Backlog Ledger → Recommended flow*).

> **Re-activation is expected.** With a 30-day fuse, re-run this activation roughly monthly until the
> feature branch merges or is abandoned. The session-resume staleness check will flag when it lapses.

---

## Changes from v1

| # | Issue | Resolution |
|---|-------|------------|
| 1 | Vague verification step | Added explicit verification gate (build + tests + operator eyeball) |
| 2 | Per-commit inefficiency | Added PR grouping pass; translate net diff of groups |
| 3 | Structural divergence unaddressed | Added Step 2 (Locate in Swift) with intent-based mapping |
| 4 | No mandatory test pass | Gate marker advancement on green build + tests |
| 5 | Category A too optimistic | Cherry-picks now require build-verify; renamed-reference check |
| 6 | No rollback procedure | Added full revert + re-translate protocol |
| 7 | Silent death (durable vs. 7-day expiry contradiction; no liveness) | Two-clock model; heartbeat `last-run` written every firing; session-resume staleness check; 30-day fuse + documented re-activation; on-activation bootstrap of marker+heartbeat |
| 8 | Analysis not durable; scalar marker can't track out-of-order work | Added `.claude/upstream-sync-backlog.md` ledger — per-unit status + persisted Cat-B intent/mapping (survives compaction); marker reframed as linear done-floor above which the ledger holds the ragged frontier; poller merges skeleton (never clobbers analysis); analyze-whole-backlog-first as pre-work |
