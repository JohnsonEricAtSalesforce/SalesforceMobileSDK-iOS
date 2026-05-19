# Production ObjC → Swift Conversion Plan

**Date:** 2026-05-17
**Branch:** feature/objc-to-swift-production-migration
**Goal:** Convert all 198 production Objective-C files (.m) and 251 headers (.h) to idiomatic Swift
**Total files to convert:** 198 .m files — 185 library files + 13 sample app files (headers are consumed during conversion, not counted separately)
**Total ObjC lines:** ~39,130 lines across 198 .m files
**Existing Swift files:** 68 production .swift files already exist and must be preserved/integrated
**Audit goal:** Retain all original .m/.h files on disk as unreferenced audit artifacts for post-conversion verification

---

## How to Execute This Plan

### First run
Provide this file to Claude with the instruction:

> "Execute the ObjC→Swift production conversion plan in production-swift-conversion-plan.md"

### Resuming after session termination
Provide this file to Claude with the instruction:

> "Resume the ObjC→Swift production conversion from the plan in production-swift-conversion-plan.md"

Claude should:
1. Read this plan to understand the approach and batch structure
2. Check the **Batch Progress Tracker** below to find the last completed batch
3. Read the most recent lessons-learned file(s) to load accumulated knowledge:
   - Latest **cumulative** lessons file: `prod-conversion-lessons-LIBRARY.md` (for last completed library)
   - Latest **delta** file: `prod-conversion-lessons-delta-LIBRARY.md` (for in-progress library, if any)
   - **Pattern registry**: `prod-conversion-patterns.md` (machine-readable verified patterns — always read this)
   - **Phase 5 variant:** If resuming mid-Phase 5, read all scout and track-specific delta files that exist (`prod-conversion-lessons-delta-SalesforceSDKCore-scoutX.md` and `trackA.md` through `trackD.md`). Check which scouts/tracks have completed (all batches `[✓]`) vs. which are in-progress or not started.
4. If the orchestrator is restarting and the batch tracker shows all batches `[✓]` for the current library but no library boundary timestamp exists, re-run the **orchestrator verification checklist** before proceeding to the boundary.
5. Resume from the next incomplete batch (or next incomplete track, for Phase 5)

---

## Autonomous Execution Model

### Orchestrator role definition
The orchestrator is the top-level Claude session. It manages workflow, spawns agents, and verifies work. It **never** performs conversion work itself.

**The orchestrator DOES:**
- Run pre-flight validation (build, test, environment checks — these are verification, not conversion)
- Construct scope fences for each agent from the batch tracker
- Spawn sub-agents with complete prompts (plan context, lessons, scope fence, conflict map entries, **rule addenda**, **accuracy briefing**, **pattern registry**)
- Receive agent completion manifests
- Run the orchestrator verification checklist (mechanical file/scope/annotation checks)
- Record timestamps in the Execution Timing table
- Compute **accuracy briefing** from build/test results (arithmetic, not judgment) and include in next agent's prompt
- Include **rule addenda** (drafted by the boundary agent) in the next agent's prompt
- Include the **pattern registry** file in every agent's prompt materials
- Provide all track delta files to the Phase 5 boundary agent (the boundary agent merges them into the cumulative lessons file as part of its authoring work — the orchestrator does not author lessons content)
- Generate the operator review report (compiling data from agent manifests, verification results, and build/test output)
- Manage operator gates (present report, wait for decision, relay adjustments)
- Manage git commits at library boundaries

**The orchestrator DOES NOT:**
- Convert any ObjC file to Swift
- Fix build errors or test failures
- Edit `project.pbxproj`, podspecs, umbrella headers, or any source file
- Write or modify any `.swift` file
- Apply seed conversion rules, `@objc` annotations, or conflict map decisions
- Make judgment calls about conversion patterns — these belong to agents

**Bright line:** If a task requires reading an ObjC `.m` file and producing Swift code, it is agent work. If a task requires running a command and checking its output against an expected value, it is orchestrator work.

### Handoff protocol at each phase

The orchestrator and agents interact at three handoff points per library. The protocol is explicit so neither side drifts into the other's work.

**Handoff 1 — Orchestrator → Agent (start of phase):**
The orchestrator constructs a prompt containing:
- The agent's assigned batches (from the batch tracker)
- The scope fence (files to create, files to modify, files to not touch)
- The cumulative lessons file from the prior library (or nothing for Phase 1)
- The **pattern registry** (`prod-conversion-patterns.md`) — the agent greps this for verified patterns
- The **rule addenda** from prior phases (or nothing for Phase 1) — these override or extend seed rules
- The **accuracy briefing** from prior phases (or nothing for Phase 1) — focuses attention on high-risk patterns
- The conflict map entries relevant to this library
- The instruction to return a completion manifest when semantic conversion is done

The orchestrator spawns the agent and waits.

**Handoff 2 — Agent → Orchestrator → Agent (after semantic conversion, before library boundary):**
The agent completes all batch conversions and returns its completion manifest. It **pauses** — it does not start the library boundary work yet.

**Implementation note:** This is a single agent session with a manifest checkpoint. The agent returns from the `Agent` tool call with the manifest. The orchestrator inspects the result, runs verification via `Bash`, then sends a `SendMessage` to the same agent to resume. The agent retains its full conversion context when it resumes for the library boundary — this is critical for efficient build error repair.

The orchestrator:
1. Receives the manifest
2. Runs the verification checklist (see "Orchestrator verification checklist")
3. If checks pass → tells the agent to proceed to the library boundary (build, test, fix)
4. If checks fail → sends the specific failures back to the agent with instructions to fix **only** the verification issues (e.g., "batch 27 is missing SFOAuthCoordinator.swift — re-convert that file"). The agent fixes, returns an updated manifest, and the orchestrator re-verifies.

This ensures the orchestrator never fixes conversion issues itself — it identifies them and sends them back.

**Orchestrator restart recovery:** If the orchestrator session dies between receiving the manifest and telling the agent to proceed, the agent's work is on disk but verification hasn't been recorded. On restart: if the batch tracker shows all batches `[✓]` for the current library but no library boundary timestamp exists, the orchestrator re-runs the verification checklist before spawning a new agent for the boundary work (since the original agent session is lost).

**Handoff 3 — Agent → Orchestrator (after library boundary):**
The agent completes the library boundary (build, test, fix, lessons, self-review, commit) and returns its final report including:
- Build/test results
- The operator review report
- The cumulative lessons file

The orchestrator:
1. Compiles the operator review report (adding its own verification results section)
2. Presents the report at the operator gate
3. Waits for operator decision
4. On "proceed" — spawns the next phase's agent
5. On "adjust" — incorporates operator adjustments into the next agent's prompt
6. On "stop" — halts and reports to operator

### Phase 5 handoff (parallel tracks)

Phase 5 modifies the handoff protocol for parallel execution:

**Handoff 1 (parallel):** The orchestrator spawns 4 agents simultaneously, each with its own scope fence and track assignment. All 4 receive the same cumulative lessons from Phase 4.

**Handoff 2 (parallel, converging):** The orchestrator waits for all 4 agents to return their manifests. It then:
1. Runs the verification checklist for each track independently
2. Runs the cross-track isolation check (no file overlap between tracks)
3. If all pass → spawns a **single boundary agent** (see below) to handle the library boundary
4. If any fail → sends failures back to the specific track agent for repair

**Boundary agent for Phase 5:** Because the library boundary involves build error repair and test failure fixes (agent work, not orchestrator work), and because the 4 track agents each had only partial context, the orchestrator spawns a **fresh boundary agent** with:
- The merged delta notes from all 4 tracks
- The cumulative lessons from Phase 4
- The full conflict map for SalesforceSDKCore
- Instructions to perform only the library boundary steps (Loop 2 steps 1–18)
- A scope fence that includes `project.pbxproj`, podspec, umbrella header, and all converted `.swift` files (for build error repair)

This avoids the orchestrator doing boundary work itself and avoids asking a track agent to fix errors in files it didn't convert.

**Handoff 3 (Phase 5):** Same as the standard protocol — the boundary agent returns, the orchestrator compiles the report, presents at Operator Gate 5.

### Agent-per-library architecture (Phases 1–4)
For Phases 1–4, the orchestrator spawns one sub-agent per library phase, **sequentially**. The same agent handles both semantic conversion and the library boundary — but with a verification pause between the two.

**Semantic conversion phase (agent works autonomously):**
1. Reads this plan (batch structure, seed rules)
2. Reads the latest `prod-conversion-lessons-LIBRARY.md` (cumulative, for last completed library — if exists)
3. Reads `prod-conversion-lessons-delta-LIBRARY.md` for the in-progress library (if exists)
4. **Reads 2–3 existing Swift files** from the current library (or a sibling library if none exist) to calibrate idiom style
5. **Receives its scope fence** from the orchestrator (see "Agent scope fence" section)
6. **Records timestamp** in the Execution Timing table (`Phase N — conversion started`)
7. Converts all batches in its assigned library, following the **re-anchor step** before each batch (see Loop 1 step 0)
8. Appends delta notes to `prod-conversion-lessons-delta-LIBRARY.md` after each batch
9. **Returns its completion manifest** to the orchestrator and **pauses** (see "Agent completion manifest" section)

**Verification pause (orchestrator runs checks — see Handoff 2):**
The orchestrator runs the verification checklist. If checks pass, it tells the agent to continue. If checks fail, it sends specific issues back to the agent for repair.

**Library boundary phase (agent resumes after verification passes):**
10. **Records timestamp** (`Phase N — library boundary started`)
11. Performs all library boundary steps (Loop 2 steps 1–18): retains .m/.h, updates Xcode project, builds, fixes errors, runs tests, updates pattern registry, writes lessons + rule addenda, self-review, operator report, commit
12. **Records timestamp** (`Phase N — library boundary complete`)
13. Returns final report to orchestrator and **stops**

The orchestrator then presents the operator review report at the gate.

### Agent architecture for Phase 5 (scouts + parallel tracks + boundary agent)
Phase 5 uses a three-step structure: scout, parallel, boundary.

1. The orchestrator spawns **4 sequential scout agents** (one per track domain), each converting a single batch: 19, 26, 31, 39
2. The orchestrator collects scout discoveries, updates the pattern registry, drafts scout addenda
3. The orchestrator spawns **4 parallel track agents** (Tracks A–D), each with its own scope fence covering the remaining batches (20–25, 27–30, 32–38, 40–46). Each receives the scout addenda + updated registry.
4. Each track agent does semantic conversion only (steps 1–9 above) and returns a manifest
5. The orchestrator verifies all 4 manifests + cross-track isolation (see Handoff 2 parallel)
6. The orchestrator spawns a **fresh boundary agent** to handle the library boundary (see "Boundary agent for Phase 5" in the handoff protocol)
7. The boundary agent performs Loop 2 steps 1–18 and returns the final report

This avoids asking track agents to fix build errors in files they didn't convert, avoids the orchestrator doing conversion work itself, and ensures all tracks benefit from scout discoveries.

### Orchestrator workflow summary
At each phase, the orchestrator:
1. Constructs the scope fence for the agent(s) from the batch tracker
2. Spawns the agent(s) with complete prompts
3. Receives completion manifest(s)
4. Runs the **orchestrator verification checklist** (see below)
5. Tells the agent to proceed to the library boundary (Phases 1–4) or spawns a boundary agent (Phase 5)
6. Receives the library boundary results
7. Compiles the operator review report (adding verification results)
8. Presents at the operator gate and waits
9. On approval, records timestamps and spawns the next phase's agent

### Autonomous within libraries, gated between libraries
Batch-level conversion within a library runs **unattended** — all semantic conversion, delta notes, and progress tracking proceed without pause. This is ~95% of the working time.

**Operator review gates** occur at **5 points only** — one per library boundary, after the build+test pass completes and the lessons file is written. The operator reviews the report and decides: **proceed**, **adjust** (change strategy for next library), or **stop** (investigate a systemic issue).

Lessons files and progress tracker updates serve as **recovery checkpoints**. If a session is terminated mid-run, the plan can be resumed from the last completed batch.

### Agent scope fence
Each sub-agent receives an explicit scope fence in its prompt — a list of files it **may** create or modify and a list it **must not** touch. This prevents cross-batch contamination and protects existing Swift files.

The orchestrator constructs the scope fence from the batch tracker:

```
## Scope Fence — Phase N / Track X

### Files you MUST create (one .swift per .m)
- libs/LIBRARY/.../ClassName.swift  (from ClassName.m, batch NN)
- ...

### Files you may MODIFY (plan file, delta notes only)
- production-swift-conversion-plan.md  (batch tracker updates only)
- prod-conversion-lessons-delta-LIBRARY[-trackX].md  (append delta notes)

### Files you must NOT modify
- Any .swift file in libs/*/Extensions/
- Any .swift file listed as "Leave as-is" or "Pure Swift" in the conflict map
- Any .m or .h file (these are retained for audit — do not edit originals)
- Any file in batches not assigned to you
- Any project.pbxproj, podspec, or umbrella header (these are modified at the library boundary, not during batch conversion)
```

If an agent needs to modify a file outside its scope (e.g., discovers a dependency it can't resolve), it must **stop, document the issue in its delta notes, and report it in the completion manifest** rather than making the change.

### Agent completion manifest
Each sub-agent must return a **structured manifest** (not prose) when it completes. The orchestrator uses this for mechanical verification. Prose summaries are unreliable — the manifest is the contract.

```
# Agent Completion Manifest — Phase N [Track X] (LIBRARY)

## Files converted
| Batch | ObjC file | Swift file written | Lines (ObjC → Swift) | Conflict map consulted | Legacy suffix applied |
|-------|-----------|-------------------|---------------------|----------------------|----------------------|
| NN | ClassName.m | ClassName.swift | NNN → NNN | Yes/N/A | Yes/No |
| ... | ... | ... | ... | ... | ... |

## Rules applied
- Rule 14 (@objcMembers): Applied to N files
- Rule 19 (+initialize → static let): Applied to N files: (list)
- Rule 22 (Legacy suffix): Applied to N files: (list)
- Rule 23 (extensions left as-is): N extension files in scope, all untouched
- Rule 25 (pure-Swift untouched): N pure-Swift files in scope, all untouched

## Files NOT touched (per rules 23, 25)
- (list each existing Swift file that was in scope but correctly left alone)

## Scope fence violations
- None / (list any files modified outside scope, with justification)

## Delta notes
- File: prod-conversion-lessons-delta-LIBRARY[-trackX].md
- Batches covered: NN, NN+1, ...
- New patterns discovered: N
- Pitfalls encountered: N

## Batch tracker updates
- Batches marked [✓]: NN, NN+1, ...

## Issues requiring orchestrator attention
- None / (list any unresolved issues, files that couldn't be converted, or scope fence violations)
```

### Orchestrator verification checklist
After each sub-agent returns its manifest, the orchestrator runs these checks **before** proceeding to the library boundary build. These are mechanical — no judgment calls.

**Step 0 — Capture changed file list once:**
Run `git diff --name-only > /tmp/conversion_changed_files.txt` and reuse this file for all scope/conflict/extension checks below. This avoids running `git diff` multiple times.

**File existence (per manifest):**
1. For each row in the manifest's "Files converted" table, verify the `.swift` file exists on disk: `test -f libs/.../ClassName.swift`
2. Verify the file is non-empty: `wc -l libs/.../ClassName.swift` should be > 0

**Scope compliance (from changed file list):**
3. Verify every file in `/tmp/conversion_changed_files.txt` appears in the agent's scope fence (batch files, plan file, delta notes). Flag any file outside scope.
4. For parallel tracks (Phase 5): collect changed file lists from all 4 tracks and verify **zero overlap**. Any overlap is a cross-track contamination that must be resolved before the build.

**Conflict map compliance (from changed file list):**
5. For batches containing conflict-map files, verify the Legacy suffix was applied: `test -f libs/.../SFCompositeRequestHelperLegacy.swift`
6. Verify no "Leave as-is" extension file appears in the changed file list: `grep "Extensions/" /tmp/conversion_changed_files.txt` should be empty (or only contain changes explicitly documented in the manifest under "Scope fence violations")

**@objc coverage check:**
7. For **every** converted `.swift` file (not just a spot check), verify `@objcMembers` or `@objc` appears on the class declaration: `grep -rL "@objcMembers\|@objc" libs/LIBRARY/LIBRARY/Classes/**/*.swift` filtered to only converted files. Any file missing all `@objc` annotations is flagged. This is the highest-risk drift for a public SDK.

**Delta notes and tracker:**
8. Verify delta notes file exists and is non-empty: `wc -l prod-conversion-lessons-delta-LIBRARY[-trackX].md`
9. Verify batch tracker shows `[✓]` for all assigned batches: `grep "\[✓\]" production-swift-conversion-plan.md`

**Manifest consistency:**
10. Verify the count of "Files converted" rows matches the expected file count for the assigned batches
11. Verify "Scope fence violations" is either "None" or has a documented justification for each violation

If **any check fails**, the orchestrator must investigate before proceeding. It does not proceed to the library boundary build on a failed verification — it either asks the agent to fix the issue (if the agent session is still active) or flags it for the operator.

### Operator review report (generated at each library boundary)
After each library boundary's build+test cycle, the agent generates a concise report:

```
# Operator Review — Phase N (LIBRARY)

## Orchestrator Verification Results
- All verification checks passed: yes/no
- File existence: N/N confirmed
- Scope fence violations: N (list, or "none")
- Cross-track overlap (Phase 5 only): none / (list)
- @objc spot check: N/N files had correct annotations
- Issues found and resolved: (list, or "none")

## Conversion Scope
- ObjC files converted: N
- Swift files written: N
- Existing Swift extension files in this library: N
  - Left as-is (compiled without changes): N
  - Required updates after base class conversion: N (list files and what changed)
- Existing pure-Swift files in this library: N (all untouched)
- Naming conflicts resolved with Legacy suffix: N (list files)
- Language-forced changes (e.g., +initialize removal): N (list files)

## Build Results
- First-pass build errors: N
- Errors after repair: N (of 3 max attempts)
- Error categories: (list top categories)

## Test Results
- Tests passed: N
- Tests failed: N
- Tests skipped/disabled: N
- New failures vs. baseline: N (list — these are conversion regressions)
- Pre-existing failures (from baseline): N (list — not attributable to conversion)
- Failure categories: (list)

## Downstream Build Check
- Libraries checked: (list)
- Downstream build errors: N (0 = clean)

## Podspec Changes
- Changes made: (list exclude_files additions, source_files updates)
- Flagged for review: yes/no

## Security-Critical Files
- Files flagged for human review: (list — see escalation rules)

## Self-Review Summary
- Conversion accuracy: N% of files compiled without errors on first pass
- Key lessons learned: (1–3 bullet points)
- Recommended strategy adjustments for next library: (if any)

## Decision Required
- [ ] **Proceed** to Phase N+1
- [ ] **Adjust** — common adjustments:
  - Change `@objc` strategy (e.g., switch from `@objcMembers` to per-method `@objc`)
  - Add/modify seed rules based on patterns discovered
  - Reorder or split batches in the next phase
  - Add files to the security-critical review list
  - Update the conflict map if new overlaps were discovered
- [ ] **Stop** (investigate before continuing)
```

### Stopping conditions (immediate, within a library)
Claude stops **immediately** and reports to the operator — without waiting for the library boundary gate — if:
- An escalation threshold is hit (see below)
- An unrecoverable error is encountered (e.g., Xcode project corruption, missing source files)
- Permission prompts blocked autonomous operation

### Escalation thresholds
These thresholds detect systemic problems that aren't fixable by patching individual files. When hit, Claude **stops immediately**, writes all lessons learned so far, and reports to the operator.

**Build error thresholds:**
- **>20 build errors** after the first repair attempt → likely a wrong `@objc` strategy or fundamental type mapping error, not isolated issues. Stop and report the error categories.
- **>10 build errors of the same category** (e.g., "missing @objc", "type mismatch") after the first repair → systematic pattern that needs a strategy change, not file-by-file fixes.

**Test failure thresholds:**
- **>10 test failures** after the first repair attempt → likely a behavioral regression from the conversion approach, not individual bugs.
- **Any crash (SIGABRT, EXC_BAD_ACCESS)** in a test that passed before conversion → indicates a fundamental issue (nil dereference, missing initialization, wrong memory semantics). Stop after 1 repair attempt if the crash persists.

**Downstream build thresholds:**
- **Any downstream library build failure** → stop immediately. The fix must be made in the upstream library's conversion, not downstream. Report which symbols/types are failing and in which downstream library.

**Security-critical file escalation:**
The following files are **always flagged for operator review** in the library boundary report, even if they compile and tests pass. The operator review gate is the checkpoint — conversion does not pause during batch work, but these files are called out explicitly at the gate:
- `SFOAuthCoordinator.m` → `SFOAuthCoordinator.swift`
- `SFOAuthCredentials.m` → `SFOAuthCredentials.swift`
- `SFOAuthKeychainCredentials.m` → `SFOAuthKeychainCredentials.swift`
- `SFOAuthSessionRefresher.m` → `SFOAuthSessionRefresher.swift`
- `SFUserAccountManager.m` → `SFUserAccountManager.swift`
- `SFUserAccount.m` → `SFUserAccount.swift`
- `SFDefaultUserAccountPersister.m` → `SFDefaultUserAccountPersister.swift`
- `SFSDKCryptoUtils.m` → `SFSDKCryptoUtils.swift`
- `SFEncryptionKey.m` → `SFEncryptionKey.swift`
- `SFSDKPushNotificationDecryption.m` → `SFSDKPushNotificationDecryption.swift`
- `SFSDKAuthSession.m` → `SFSDKAuthSession.swift`
- `SFSDKAuthRequest.m` → `SFSDKAuthRequest.swift`
- `SFSDKOAuth2.m` → `SFSDKOAuth2.swift`

These files handle OAuth2 flows, token storage, credential handling, keychain access, and encryption — the CLAUDE.md escalation categories.

### Permission requirements
Before starting execution, ensure `.claude/settings.json` has permissions for:
- File read/write/edit across the repo
- Bash commands: `xcodebuild`, `find`, `grep`, `rm`, `git`, `ls`, `cat`, `wc`, `ruby`
- These should be configured via `/update-config` or `/fewer-permission-prompts` before the first run

### Permission gap tracking
During execution, Claude tracks every tool invocation that triggered a user permission prompt (i.e., was not in the allow list). At each status review point (delta notes and cumulative lessons files), Claude includes a **Permission Gaps** section listing:

- The exact tool call pattern that was prompted (e.g., `Bash(ruby *)`, `Bash(mv *)`)
- How many times it was prompted during this batch/build
- The recommended allow-list entry to add to `.claude/settings.json`

If any permission gaps are found, Claude:
1. Lists them in the status output
2. Requests the user approve adding them to `.claude/settings.json`
3. If running autonomously and the user is not present, writes the recommended additions to a file `prod-conversion-permission-gaps.md` and continues (the gaps will be surfaced at the next status review or session restart)

---

## Critical Context: Production Code Differences from Test Migration

This plan converts **production** ObjC — fundamentally different from the prior test-only migration:

### Public API surface
- Production files define the SDK's **public API**. Every `@interface`, `@protocol`, category, constant, and typedef in the `.h` files is potentially consumed by external developers.
- Swift conversions must preserve the Objective-C-visible API surface using `@objc`, `@objcMembers`, `@objc(ClassName)` annotations so that existing ObjC consumers (including the test targets) continue to compile.
- Umbrella headers (`SalesforceSDKCommon.h`, `SalesforceAnalytics.h`, `SmartStore.h`, `MobileSync.h`, `SalesforceSDKCore.h`) must be updated to reflect the new Swift module structure.

### Coexistence with existing Swift files
- 68 production `.swift` files already exist and must be preserved. Some are pure Swift additions; others are extensions on ObjC classes being converted.
- When converting an ObjC class that has a Swift extension file, the extension must be updated to reference the new Swift class (no more bridging needed).
- Name collisions between converted files and existing Swift files must be identified and resolved.

### Dependency ordering is critical
- Libraries depend on each other: `SalesforceSDKCommon` → `SalesforceAnalytics` → `SmartStore` → `MobileSync` → `SalesforceSDKCore`. Each upstream library must build successfully before downstream conversions begin.
- Within a library, base classes and protocols must be converted before their subclasses/conformers.

### ObjC/Swift interop within a library during conversion
- Unlike the test migration (where all ObjC tests were already broken), **production ObjC files currently compile and work together**.
- However, incremental conversion is still done semantically per batch, with builds only at library boundaries, because:
  - Mixed ObjC/Swift within a single target requires careful bridging header management
  - Partial conversion creates complex circular dependency risks between ObjC and Swift files
  - Library boundaries are the natural compilation unit

### Tests are the behavioral contract
- Existing tests (both ObjC and Swift) must continue to pass after each library conversion. Unlike the test migration where tests adapted to production, here production adapts its implementation while preserving the behavior that tests verify.
- Test failures indicate a conversion bug that must be fixed in the production Swift code.

---

## Original File Retention for Audit

### Goal
Every original `.m` and `.h` file is **kept on disk** alongside its Swift replacement, but **removed from the Xcode project** so it is not compiled. This creates a side-by-side audit trail: for any converted `.swift` file, the original ObjC source is in the same directory for comparison.

### Directory convention
Original files stay **in place** — same directory, same filename. They are simply de-referenced from `project.pbxproj`. Example after converting `SFSmartStore.m`:

```
libs/SmartStore/SmartStore/Classes/
  SFSmartStore.h          ← original header, on disk, NOT in Xcode project
  SFSmartStore.m          ← original implementation, on disk, NOT in Xcode project
  SFSmartStore.swift      ← converted Swift file, IN Xcode project
```

### Why retain in place (not move to an archive directory)
- **Trivial diffing:** `diff SFSmartStore.m SFSmartStore.swift` or any side-by-side tool works immediately — no path mapping needed.
- **Git history preserved:** `git log --follow SFSmartStore.m` still works since the file was never moved or renamed.
- **No directory structure to create or maintain:** No `_originals/` mirror tree that rots if paths change.
- **Easy bulk cleanup later:** When the audit is complete and originals are no longer needed, a single `find libs -name "*.m" -not -path "*Test*" -delete` (plus `.h`) removes them all.

### Implementation at library boundaries
At each library boundary, the Xcode project update step changes from "delete .m/.h files" to:
1. **Remove** `.m` and `.h` file references from `project.pbxproj` (both file reference and build phase membership)
2. **Do NOT delete** the `.m` and `.h` files from disk
3. **Add** the new `.swift` files to `project.pbxproj`
4. **Update** umbrella header as before

### CocoaPods `exclude_files` for retained originals
The podspecs use glob patterns like `'Classes/**/*.{h,m,swift}'` for `source_files`. Since original `.m`/`.h` files remain on disk in the same directories, CocoaPods would include them alongside the new `.swift` files, causing duplicate symbol errors. To prevent this, each podspec must add `exclude_files` patterns at the library boundary.

After all `.m`/`.h` references are removed from the Xcode project, add `exclude_files` to each podspec. The pattern must exclude the retained originals without excluding any `.h`/`.m` files that are still active (e.g., umbrella headers, any files intentionally kept in ObjC). Example for SmartStore:

```ruby
smartstore.exclude_files = 'libs/SmartStore/SmartStore/Classes/**/*.{h,m}'
```

**Per-podspec notes:**
- `SalesforceSDKCommon.podspec` — exclude `Classes/**/*.{h,m}`. Keep umbrella header reference (it's listed separately in `source_files`).
- `SalesforceAnalytics.podspec` — exclude `Classes/**/*.{h,m}`. **Also** add `*.swift` to the `source_files` glob (currently only `*.{h,m}` — see note below).
- `SmartStore.podspec` — exclude `Classes/**/*.{h,m}`.
- `MobileSync.podspec` — exclude `Classes/**/*.{h,m}`.
- `SalesforceSDKCore.podspec` — exclude `Classes/**/*.{h,m}`.

**SalesforceAnalytics podspec gap:** `SalesforceAnalytics.podspec` currently uses `source_files = 'Classes/**/*.{h,m}'` — it does not include `*.swift`. After conversion, the `source_files` pattern must be updated to include `*.swift`:
```ruby
sdkanalytics.source_files = 'libs/SalesforceAnalytics/SalesforceAnalytics/Classes/**/*.{h,m,swift}', ...
```

These are podspec changes and must be **flagged for operator review** per CLAUDE.md rules. They are included in the operator review report at each library boundary gate.

### .gitignore consideration
The retained `.m`/`.h` files will appear as untracked in `git status` after their Xcode project references are removed (they're already tracked, so they'll show as modified or unchanged). They **should be committed** to the branch so the audit trail is available to anyone who checks out the branch. They add no build cost since they're not referenced by any Xcode target, and the `exclude_files` in podspecs prevents CocoaPods from compiling them.

### Post-audit cleanup
After a future verification pass confirms all conversions are accurate, a cleanup step can:
1. Delete all unreferenced `.m`/`.h` production files
2. Remove the `exclude_files` entries from podspecs (no longer needed once the files are gone)
3. Commit the removal as a separate, clearly-labeled commit (e.g., "Remove original ObjC files after audit verification")

This separation keeps the conversion commit and the cleanup commit distinct, making it easy to revert the cleanup if any original source is needed again.

---

## Pre-flight Validation

Before starting batch 01, the orchestrator must verify the environment is in a known-good state. This prevents discovering a broken baseline hours into the conversion. Pre-flight is orchestrator work (verification, not conversion).

1. **Git working tree is clean** — `git status` shows no uncommitted changes (except this plan file and any lessons files from prior runs). If there are uncommitted changes, stop and ask the operator.
2. **Create the feature branch** — `git checkout -b feature/objc-to-swift-production-migration` (or verify it already exists and is checked out).
3. **Submodule dependencies are present** — verify `install.sh` has been run: `test -d libs/SalesforceSDKCommon/SalesforceSDKCommon && test -d external`. If missing, run `./install.sh` first.
4. **Simulator destination is valid** — determine a valid simulator destination: `xcrun simctl list devices available | grep -i iphone`. Record the destination string in the variable below, which is referenced by all build/test commands throughout this plan:
   ```
   SIMULATOR_DEST="platform=iOS Simulator,name=iPhone 17 Pro Max,OS=latest"
   ```
   Update this value during pre-flight if the device name or OS differs on this machine.
5. **All libraries build clean** — build each library scheme sequentially: SalesforceSDKCommon, SalesforceAnalytics, SmartStore, MobileSync, SalesforceSDKCore. Use `xcodebuild build -scheme SCHEME -destination "$SIMULATOR_DEST" CODE_SIGNING_ALLOWED=NO`. If any library doesn't build, the conversion cannot proceed — document and stop.
6. **Tests pass at baseline** — run tests for each library scheme to establish the green baseline. Record the test counts (pass/fail/skip) in the Baseline Test Results table. Any pre-existing test failures must be documented so they aren't attributed to the conversion.
7. **Permissions are configured** — verify `.claude/settings.json` has the required permissions (see "Permission requirements" section). Run a test `xcodebuild` command to confirm no permission prompt fires.

### Project paths reference
Each library has its own `.xcodeproj` containing the `project.pbxproj` that must be modified at library boundaries:
- `libs/SalesforceSDKCommon/SalesforceSDKCommon.xcodeproj/project.pbxproj`
- `libs/SalesforceAnalytics/SalesforceAnalytics.xcodeproj/project.pbxproj`
- `libs/SmartStore/SmartStore.xcodeproj/project.pbxproj`
- `libs/MobileSync/MobileSync.xcodeproj/project.pbxproj`
- `libs/SalesforceSDKCore/SalesforceSDKCore.xcodeproj/project.pbxproj`
- `native/SampleApps/MobileSyncExplorer/MobileSyncExplorer.xcodeproj/project.pbxproj` (Phase 6 only)

The boundary agent (or the library agent for Phases 1–4, or the Phase 6 agent) must modify only the `project.pbxproj` for the library/app being converted. These paths are included in the scope fence for boundary work.

Record the pre-flight results in the Execution Timing table as "Pre-flight validation complete" with a timestamp.

---

## Commit Strategy

Intermediate commits happen at each library boundary, after the operator approves at the gate. This provides safe rollback points per library and clean `git bisect` if issues surface later.

### Commit points
- **After pre-flight validation:** Commit the plan file and any configuration changes. Message: `"Add production ObjC→Swift conversion plan"`
- **Before each operator gate (after build+test pass):** Commit all changes for that library so the operator reviews committed state and a rollback point exists even if the session dies. Message format:
  ```
  Convert LIBRARY production ObjC to Swift (Phase N/5)

  - N files converted to Swift
  - Original .m/.h retained on disk for audit
  - Podspec exclude_files updated
  - N existing Swift extension files verified
  - [Language-forced changes: ...] (if any)
  - [Naming conflicts resolved: ...] (if any)
  ```
- **After post-conversion validation:** Final commit with clean build/test confirmation. Message: `"Verify clean build and full test pass after production ObjC→Swift conversion"`

### Rollback
If a library conversion needs to be reverted, `git revert` the single library commit. Because each library is a discrete commit, reverting one library doesn't affect the others — though downstream libraries may need rebuilding if they depended on the reverted library's Swift API.

---

## Approach: Incremental Semantic Conversion with Two Learning Loops

### Large file isolation rule
Files over 1,000 lines get their own batch or are paired with at most 1–2 small files. This prevents context window strain within sub-agents. The 4 large files isolated this way are:
- `SFUserAccountManager.m` (2,388 lines) — batch 35 (solo)
- `SFSmartStore.m` (2,066 lines) — batch 07 (solo)
- `SalesforceSDKManager.m` (1,081 lines) — batch 44 (+3 small files)
- `SFOAuthCoordinator.m` (1,057 lines) — batch 27 (+1 small file)

### Uncertain API verification rule
When converting a method and the correct Swift signature is ambiguous, **do not guess**. Instead:
1. Check the `.h` file for the public interface declaration
2. Check for existing Swift extensions that may already wrap or override the method
3. Run `grep -rn "methodName" libs/LIBRARY/ --include="*.swift"` to see how existing Swift code calls the method
4. Verify `@objc` compatibility requirements — will existing ObjC callers (tests, other ObjC files in downstream libraries) still work?

### @objc annotation strategy
- All public/open classes that were `@interface` in ObjC must be annotated `@objc` or `@objcMembers` to maintain compatibility with ObjC callers (tests, downstream ObjC code, external consumers)
- Use `@objc(OriginalObjCName)` when the Swift name would differ from the ObjC name
- Enums that were `NS_ENUM` must be `@objc enum`
- Constants that were `extern NSString *const` must be `@objc static let` or kept as module-level `let` with `@objc` as appropriate
- Categories (`+SFAdditions`, `+SFColors`, etc.) become Swift extensions with `@objc` methods

### Loop 1: Semantic batch learning (per batch)
Files are converted in batches of ~3–5 files. For each batch:

**Before converting (re-anchor step):**
0. **Re-read rules** — Before each batch, re-read the conflict map entries for files in this batch and the latest delta notes from prior batches in this library. For **batch 3+** within a library (or any batch within a Phase 5 track), also re-read: (a) the structural rules (1–13), (b) the `@objc` rules (14–18), (c) the language-forced change rules (19–21). For batches 1–2, these rules are already in recent context — re-read only the conflict map entries. Drift increases with context length; this step is the primary defense.

**Convert:**
1. **Read** each ObjC file (.h + .m pair) in the batch
2. **Check** for existing Swift extensions or related Swift files that interact with the ObjC class. Consult the **conflict map** for any file in a library with existing Swift files.
3. **Convert** semantically to idiomatic Swift, applying all known patterns. When uncertain about an API mapping, verify against existing Swift code and headers via grep before writing.
4. **Write** the .swift replacement file (do NOT delete the .m/.h yet — that happens at the library boundary). Only write files listed in the agent's **scope fence** (see below).

**Record:**
5. **Append** delta notes to `prod-conversion-lessons-delta-LIBRARY.md` (new patterns, pitfalls, permission gaps from this batch only)
6. **Update** this plan's Batch Progress Tracker (mark batch `[✓]`)
7. **Log** a status summary to the console:
   - Files converted, cumulative progress (N/185, N%)
   - Key observations from this batch
   - **Permission gaps:** list any tool calls that triggered permission prompts, with recommended allow-list entries
8. **Continue** immediately to the next batch — no pause

### Loop 2: Build, test, and learn (per library boundary)
After all batches in a library are semantically converted:

**Verification gate (orchestrator runs this — agent is paused):**
This is Handoff 2 from the handoff protocol. The agent has returned its completion manifest and is waiting.

0. **Orchestrator receives completion manifest** from the agent (or from all 4 track agents in Phase 5).
0a. **Orchestrator runs verification checklist** — file existence, scope compliance, conflict map compliance, extension files untouched, @objc spot check, delta notes exist, manifest consistency. See "Orchestrator verification checklist" section.
0b. **For Phase 5 parallel tracks:** additionally verify zero file overlap between tracks.
0c. If **any check fails** → the orchestrator sends the specific failures back to the agent (not fixing them itself — see "Orchestrator role definition"). The agent repairs, returns an updated manifest, and the orchestrator re-verifies.
0d. If all checks pass → the orchestrator tells the agent to proceed to step 1 (Phases 1–4), or spawns the boundary agent (Phase 5).

**Library boundary build (REVISED — single-library build model):**

> **Key revision (post-Phase 1):** Each library boundary builds and tests ONLY the library being converted. Downstream libraries are NOT built or fixed at this boundary. Downstream `#import` updates and subclass refactoring happen when each downstream library is converted in its own phase. This keeps scope fences clean and avoids touching unconverted libraries prematurely.

1. **Retain** all original .m/.h files on disk (do NOT delete — see "Original File Retention for Audit" section). Remove their references from `project.pbxproj` only.
2. **Update umbrella header** — remove ObjC imports for converted classes. Keep the umbrella header file (required for the module). Swift types are exposed via the auto-generated `-Swift.h`.
3. **Update Xcode project** (`project.pbxproj`) to remove .m/.h file references and build phase membership, and add .swift files.
4. **Fix upstream imports within THIS library** — replace `#import <UpstreamLib/ClassName.h>` with `@import UpstreamLib;` for any already-converted upstream library. This is part of converting THIS library — not touching downstream code.
5. **Update podspec** — add `exclude_files` to prevent CocoaPods from compiling retained originals.
6. **Build** the library target ONLY with `CODE_SIGNING_ALLOWED=NO`.
7. **Verify existing Swift extension files** in this library — fix minimally if they fail to compile.
8. **Assess build errors against escalation thresholds:**
   - If >20 errors after first repair → **stop immediately**
   - If >10 errors of the same category → **stop immediately**
   - Otherwise → **fix** compilation errors (up to 3 repair attempts)
9. **Run tests** for THIS library ONLY via `xcodebuild test`.
   - If >10 test failures after first repair → **stop immediately**
   - If any crash persists after 1 repair attempt → **stop immediately**
   - Otherwise → **fix** test failures (up to 3 attempts)
10. **Do NOT build or test downstream libraries.** Downstream will be fixed when those libraries are converted. Accept that intermediate commits may not build the full stack.
11. **Update pattern registry** — mark patterns Verified if they compiled.
12. **Write** cumulative lessons file.
13. **Draft rule addenda**.
14. **Self-review**.
15. **Update** Batch Progress Tracker.
16. **Generate operator review report** (no downstream build section needed).
17. **Flag security-critical files**.
18. **Commit**.
19. **Stop and wait for operator review**.

### Downstream integration model (replaces old step 8)

Instead of building downstream at each boundary, downstream effects are resolved naturally:

- **Phase N converts Library L.** It updates only L's project, builds only L, tests only L.
- **Phase N+1 converts Library M** (which depends on L). As part of M's semantic conversion, the agent also:
  - Replaces `#import <L/ClassName.h>` with `@import L;` in M's ObjC files being converted
  - Refactors any M classes that subclassed L classes (inheritance → composition, since Swift 6.3 `objc_subclassing_restricted` prevents ObjC subclassing of Swift classes)
  - These changes are part of M's conversion work, not a separate step
- **The final post-conversion validation** builds ALL libraries together and runs ALL tests. This is the integration gate.

### Phase 1 exception (already done)
Phase 1 (SalesforceSDKCommon) already fixed downstream imports for all 4 libraries and refactored the 4 Logger subclasses. This work is committed and passing. Future phases do NOT need to re-do this for SalesforceSDKCommon imports — they're already `@import SalesforceSDKCommon;`.

### `@synchronized` → `NSRecursiveLock` (NEW — Rule 33)
ObjC `@synchronized(obj)` is ALWAYS re-entrant — the same thread can acquire the lock multiple times without deadlocking. When converting to Swift, ALWAYS use `NSRecursiveLock` (not `NSLock`). `NSLock` will deadlock if any method that holds the lock calls another method that also acquires the same lock. This is extremely common in manager/singleton patterns where convenience methods call through to core methods.

### NSException preservation for ObjC callers (NEW — Rule 34)
When ObjC callers (especially tests) use `@try/@catch` or `XCTAssertThrows` to catch exceptions from a method, the Swift conversion must preserve that behavior. Two approaches:
1. **Preferred:** Keep `NSException(name:..., reason:...).raise()` in the Swift code. This works — ObjC callers can still catch it with `@try/@catch`. Swift callers cannot catch it with `do/catch`, but that's acceptable since Swift callers should use the `throws` variant.
2. **Alternative:** Provide both a throwing Swift method AND an ObjC-visible wrapper that raises NSException. Use when the method needs to be callable from both Swift (with try) and ObjC (with @try/@catch).

Do NOT silently convert `NSException.raise()` to `return nil` or `return []` — this changes behavior from "error" to "empty result", which breaks test assertions.

### ObjC generic classes — deferral rule (NEW — Rule 31)
ObjC classes using lightweight generics (`SFSDKSafeMutableDictionary<KeyType, ObjectType>`) cannot be converted to Swift `@objc` classes because Swift generics are not ObjC-representable. These files are **deferred** — their .swift conversion files exist on disk but are not compiled. They remain as ObjC until all their consumers are also Swift. The 3 deferred files from Phase 1:
- `SFSDKSafeMutableArray` (SalesforceSDKCommon)
- `SFSDKSafeMutableDictionary` (SalesforceSDKCommon)
- `SFSDKSafeMutableSet` (SalesforceSDKCommon)

### Swift 6.3 `objc_subclassing_restricted` — inheritance rule (NEW — Rule 32)
ALL Swift classes (including `open class`) get `__attribute__((objc_subclassing_restricted))` in the generated `-Swift.h`. ObjC code CANNOT subclass Swift classes. When converting a class that has ObjC subclasses:
- If the subclass is in the SAME library → convert both simultaneously
- If the subclass is in a DOWNSTREAM library → refactor to composition when that library is converted
- If the subclass is in EXTERNAL code (public API) → this is a BREAKING CHANGE; flag for operator review and consider keeping as ObjC

### Lessons-learned file strategy

Same two-level approach as the test migration:

**Within a library:** Each batch appends **delta-only** notes to `prod-conversion-lessons-delta-LIBRARY.md`.

**At library boundaries:** Claude writes a **cumulative lessons file** `prod-conversion-lessons-LIBRARY.md` that merges all deltas + build corrections + test-failure patterns.

**Cumulative lessons file format** (`prod-conversion-lessons-LIBRARY.md`):
```
# Production Conversion Lessons — Through LIBRARY

## Cumulative API Migration Patterns
(All known ObjC→Swift mappings, verified through this library)

## @objc Interop Patterns
(Patterns for maintaining ObjC compatibility — @objc annotations, NS_ENUM conversion, constant exposure, category→extension patterns)

## Conversion Pitfalls Discovered
(Patterns that look straightforward but have gotchas)

## Swift Idiom Preferences
(Patterns that produce cleaner Swift production code)

## Compiler-Discovered Corrections
(What semantic conversion got wrong, fixed during build passes)

## Test-Failure Patterns
(Behavioral regressions discovered during test execution — and how they were fixed in the production Swift code)

## Existing Swift Integration Notes
(How converted ObjC classes interact with pre-existing Swift files — extension merging, protocol adoption, etc.)

## Xcode Project Notes
(pbxproj editing patterns, target membership issues, umbrella header changes, etc.)

## Permission Gaps
(Cumulative list of tool calls that triggered prompts, with recommended allow-list entries)
```

**Delta scratch file format** (`prod-conversion-lessons-delta-LIBRARY.md`):
```
# Production Conversion Deltas — LIBRARY

## Batch NN
- New patterns discovered: ...
- Pitfalls encountered: ...
- Existing Swift conflicts: ...
- Permission gaps: ...

## Batch NN+1
- ...
```

### Pattern registry — machine-readable knowledge base

In addition to the prose lessons files, the plan maintains a **structured pattern registry**: `prod-conversion-patterns.md`. This is the "verified truth" — patterns confirmed by the compiler, not just guessed during semantic conversion. Agents grep this file when uncertain about a mapping.

**Format:**
```markdown
# Pattern Registry

| # | ObjC Pattern | Swift Pattern | Rule | Discovered | Verified | Notes |
|---|-------------|--------------|------|-----------|----------|-------|
| 1 | `dispatch_queue_create("name", DISPATCH_QUEUE_SERIAL)` | `DispatchQueue(label: "name")` | 26 | P1 B01 | P1 build | |
| 2 | `dispatch_barrier_async(queue, ^{ ... })` | `queue.async(flags: .barrier) { ... }` | 26 | P1 B03 | P1 build | |
| 3 | `NS_ASSUME_NONNULL` property with `nullable` | `var prop: Type?` | 5 | P3 B07 | P3 build | Only nullable properties get `?` inside nonnull block |
```

**When rows are added:**
- During semantic conversion: the agent adds rows with "Discovered" filled in but "Verified" blank (these are provisional)
- During library boundary build: the boundary agent marks rows as verified when the pattern compiles successfully, or corrects them and notes the correction
- The orchestrator includes the registry file in every agent's prompt materials

**How agents use it:**
- Before converting a pattern, `grep` the registry for the ObjC pattern
- If found with "Verified" → use that Swift pattern confidently
- If found without "Verified" → use it but note the uncertainty in delta notes
- If not found → apply seed rules, add a new provisional row

This replaces the "Cumulative API Migration Patterns" prose section in the lessons file with a greppable table. The lessons file retains prose for context, pitfalls, and narrative — the registry is for direct lookup.

### Rule injection — orchestrator augments agent prompts

After each library boundary, the orchestrator extracts concrete rule updates from the build corrections and test failures and injects them into the next agent's prompt as **rule addenda**. These are authoritative — the agent treats them as extensions to the seed rules, not prose to interpret.

**Format (included in the agent's spawn prompt):**
```
## Rule Addenda (from Phase 1–N build feedback)

### Corrections to seed rules
- Rule 5 correction: Properties typed as `id` in ObjC → `Any?` in Swift (not `AnyObject?`)
- Rule 14 correction: Category methods on Foundation classes (NSString, NSData, etc.)
  need per-method @objc, not @objcMembers — the class is Apple's, not ours

### New patterns (not in seed rules)
- `dispatch_once` → use `static let` (Swift guarantees one-time initialization)
- `__block` variable modifier → no Swift equivalent needed (Swift closures capture by reference for `var`)
- `@synchronized(self)` → `objc_sync_enter(self)` / `objc_sync_exit(self)` or use a lock
```

**Who writes rule addenda:**
- The boundary agent drafts them as part of the library boundary self-review (step 11 in Loop 2)
- The orchestrator reviews them mechanically (no judgment — just verifying they reference real build errors) and includes them in the next agent's prompt

**Lifecycle:**
- Rule addenda accumulate across phases. Phase 3's agent sees addenda from Phases 1–2. Phase 5's agents see addenda from Phases 1–4.
- If an addendum contradicts a seed rule, the addendum wins (it's compiler-verified; the seed rule was a pre-execution guess).

### Accuracy briefing — quantitative feedback per phase

After each library boundary, the orchestrator computes accuracy metrics and includes them in the next agent's prompt. This focuses agent attention on the highest-risk patterns.

**Format (included in the agent's spawn prompt):**
```
## Accuracy Briefing (Phases 1–N)

### First-pass compile accuracy
- Phase 1 (SalesforceSDKCommon): NN% (N errors in 12 files)
- Phase 2 (SalesforceAnalytics): NN% (N errors in 7 files)
- Phase 3 (SmartStore): NN% (N errors in 13 files)

### Top error categories (cumulative)
1. Missing @objc annotations: N occurrences across N phases
2. Optionality mismatch (nullable/nonnull): N occurrences
3. NSError→throws missing: N occurrences

### Action items for this phase
- HIGH RISK: Verify every `NSError **` parameter (rule 7) — caused N errors so far
- MEDIUM RISK: Check nullability blocks before setting optionality (rule 5) — caused N errors
- LOW RISK: @objc coverage is good (N% correct first-pass)
```

**Who computes this:**
- The orchestrator, from the build/test results already captured in the operator review reports. This is arithmetic, not judgment — orchestrator work.

### Plan self-review at library boundaries
After each library's build pass, test run, and lessons file are written, the agent performs a brief self-review:
- **Accuracy check:** What percentage of converted files had build errors? What percentage of tests failed? Which error categories dominated?
- **Efficiency check:** Were there patterns that could have been caught earlier? Are there patterns that should be added to the **pattern registry**?
- **@objc coverage:** Were there missing `@objc` annotations that caused downstream build failures?
- **Existing Swift integration:** Were there conflicts or redundancies with pre-existing Swift files?
- **Security-critical file review:** Were any security-critical files converted in this phase? If so, list them with a summary of what changed beyond mechanical translation (any logic restructuring, access control changes, or behavioral differences).
- **Escalation assessment:** Did any escalation thresholds fire? What was the root cause? Was it resolved or does it need operator attention?
- **Rule updates:** Draft **rule addenda** for the orchestrator to include in the next agent's prompt. Also update the **pattern registry** with any compiler-verified patterns.
- **Remaining work assessment:** Given what was learned, are the batch assignments for the next library still sensible? Should the operator consider adjusting before approving?

---

## Seed Conversion Rules

These rules apply to production ObjC → Swift conversion specifically.

### Structural rules
1. **Imports:** Replace `#import` / ObjC submodule imports with `import ModuleName`
2. **Class structure:** `@interface Foo : NSObject` → `class Foo: NSObject` with `@objcMembers` or `@objc` as needed
3. **Protocols:** `@protocol Foo <NSObject>` → `@objc protocol Foo`
4. **Categories:** `@interface Foo (Category)` → `extension Foo` with `@objc` on methods that need ObjC visibility
5. **Properties and nullability:** `@property (nonatomic, strong) Foo *bar` → `var bar: Foo`. Optionality rules:
   - Default to optional (`?`) unless the header uses `nonnull` annotation or the property is within a `NS_ASSUME_NONNULL_BEGIN`/`NS_ASSUME_NONNULL_END` block.
   - For properties in `NS_ASSUME_NONNULL` blocks, use non-optional unless the property has an explicit `nullable` annotation.
   - When in doubt, check how existing Swift code (extensions, tests) calls the property — if they use `!` or `?`, match that expectation.
6. **Methods:** `-/+ (ReturnType)methodName:(ParamType)param` → `func methodName(param: ParamType) -> ReturnType`
7. **Error parameters → throws:** Methods with `NSError **` out-parameters → Swift methods that `throws`. Example: `- (BOOL)doSomething:(NSError **)error` → `func doSomething() throws`. Check whether existing Swift extensions already call these methods with `try` to confirm the pattern. Common in SmartStore (`query:error:`) and MobileSync.
8. **Constants:** `extern NSString *const kFoo` → `@objc static let kFoo: String = "..."` or module-level `let`
9. **Enums:** `NS_ENUM(NSInteger, Foo)` → `@objc enum Foo: Int`; `NS_OPTIONS` → `struct Foo: OptionSet`
10. **Blocks and typedefs → Closures:** ObjC block syntax → Swift closure syntax with `@escaping` where needed. Block typedefs (`typedef void (^CompletionBlock)(BOOL success, NSError *error)`) → Swift `typealias CompletionBlock = (Bool, Error?) -> Void`.
11. **Singletons:** `+ (instancetype)sharedInstance` → `@objc static let shared = Foo()`
12. **Init patterns:** `- (instancetype)initWith...` → `init(...)` with appropriate failable (`init?`) where ObjC returned nil
13. **`#pragma mark` → `// MARK:`**: `#pragma mark - Section Name` → `// MARK: - Section Name`. Preserves code organization for reviewability of converted files.

### @objc compatibility rules
14. **Public classes** that were `@interface` in headers → `@objcMembers public class` (or `@objc public class` with per-method `@objc`)
15. **Internal classes** only used within the library → can omit `@objc` unless called from ObjC within the same target
16. **Delegate protocols** → `@objc protocol` to remain compatible with ObjC conformers
17. **NSNotification.Name constants** → preserve as `static let` on `NSNotification.Name` extension with `@objc`
18. **`+Internal.h` headers** → these define internal-only API. Convert to `internal` access, no `@objc` needed unless called from ObjC within the same target

### Language-forced changes (beyond mechanical translation)
Some ObjC patterns have no direct Swift equivalent and require structural changes. These are **not optional modernization** — they are forced by the language difference. Document each instance in the delta notes so reviewers can distinguish "language-forced change" from "conversion bug."

19. **`+initialize` methods:** Swift has no `+initialize`. Convert to lazy static initialization. Three files use this pattern:
   - `SFMobileSyncSyncManager.m` — initializes a static `syncMgrList` dictionary
   - `SFLayoutSyncManager.m` — initializes `syncMgrList` dictionary + `indexSpecs` array
   - `SFMetadataSyncManager.m` — initializes `syncMgrList` dictionary + `indexSpecs` array

   All three follow the same pattern: `if (self == [ClassName class]) { staticVar = [NSMutableDictionary new]; }`. Convert to:
   ```swift
   private static let syncMgrList = NSMutableDictionary()
   // or for type safety:
   private static var syncMgrList = [String: ClassName]()
   ```
   For `indexSpecs`, use a `static let` with the array literal. These are semantically equivalent — Swift `static let` is lazy and thread-safe by default, matching the one-time-initialization guarantee of `+initialize`.

   Flag these files in the Phase 4 (MobileSync) operator review report as language-forced changes.

20. **`+load` methods:** Swift has no `+load`. If any are found, they require an alternative initialization strategy (e.g., explicit registration during SDK setup). None were identified in the current codebase, but the agent should check each file during conversion.

21. **ObjC associated objects (`objc_setAssociatedObject`/`objc_getAssociatedObject`):** If encountered, keep as-is using Swift's ObjC interop (`objc_setAssociatedObject(self, &key, value, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)`). These are valid Swift but require an `import ObjectiveC` and a static key variable.

### Existing Swift integration rules
22. **Naming conflicts — use `Legacy` suffix:** If converting an ObjC file would produce a `.swift` filename or class name that conflicts with an existing Swift file, the converted ObjC file uses a `Legacy` suffix (e.g., `SFCompositeRequestHelper.m` → `SFCompositeRequestHelperLegacy.swift` with class name `SFCompositeRequestHelperLegacy`). The existing Swift file stays in place unchanged. See the **Pre-conversion conflict map** below for all known conflicts.
23. **Extension files — leave as-is:** Swift extensions of current ObjC types (e.g., `RestClient.swift` extends `SFRestAPI`, `SyncTarget.swift` extends `SyncTarget`) must **remain as separate files** and **not be merged** into the converted ObjC file's Swift output. After conversion, these extensions will reference the now-Swift class instead of the ObjC-bridged class — this should work automatically since the class name and module stay the same. Only update an extension file if it fails to compile after the base class conversion.
24. **Preserve file organization:** New Swift files should be placed in the same directory structure as the original ObjC files.
25. **Pure-Swift files — do not touch:** Existing Swift files that define entirely new classes (not conversions of ObjC classes) are left completely untouched. Examples: `BriefcaseSyncDownTarget.swift`, `PushNotificationManager.swift`, `KeyValueEncryptedFileStore.swift`, `WebSocketClient.swift`.

### Pre-conversion conflict map

This map identifies every existing Swift file and its relationship to ObjC files being converted. The agent must consult this before converting any file in the affected libraries.

**SmartStore:**
| Existing Swift file | Relationship to ObjC | Action |
|---|---|---|
| `SmartStore.swift` (Extensions/) | Extension on `SmartStore` class (Combine publishers, convenience methods) | Leave as-is. Extension will reference converted Swift class automatically. |

**MobileSync:**
| Existing Swift file | Relationship to ObjC | Action |
|---|---|---|
| `SyncTarget.swift` | Extension on `SyncTarget` and `SyncDownTarget` (adds Swift-specific methods) | Leave as-is. |
| `BatchSyncUpTarget.swift` | Extension on `BatchSyncUpTarget` | Leave as-is. |
| `CollectionSyncUpTarget.swift` | Defines `CollectionSyncUpTarget` subclass of `BatchSyncUpTarget` — **no ObjC counterpart** | Leave as-is. Pure Swift class. |
| `BriefcaseSyncDownTarget.swift` | Pure Swift class — **no ObjC counterpart** | Leave as-is. |
| `BriefcaseObjectInfo.swift` | Pure Swift class — **no ObjC counterpart** | Leave as-is. |
| `CompositeRequestHelper.swift` | Defines `CompositeRequestHelper`, `RecordResponse`, `RecordRequest` — **NAMING CONFLICT** with `SFCompositeRequestHelper.m` | **Convert ObjC to `SFCompositeRequestHelperLegacy.swift`** with `Legacy` class name. Existing Swift file stays. |
| `MobileSync.swift` (Extensions/) | Extension on `SyncManager` (Combine publishers, convenience methods) | Leave as-is. |

**SalesforceSDKCore:**
| Existing Swift file | Relationship to ObjC | Action |
|---|---|---|
| `RestClient.swift` (Extensions/) | Extension on `RestClient` (request builders) | Leave as-is. |
| `RestClient+Blocks.swift` (Extensions/) | Extension on `RestClient` (block-based API) | Leave as-is. |
| `RestClient+WebSocket.swift` (Extensions/) | Extension on `RestClient` (WebSocket support) | Leave as-is. |
| `UserAccountManager.swift` (Extensions/) | Extension on `UserAccountManager` (protocol conformance) | Leave as-is. |
| `URLRequest+RestRequest.swift` (Extensions/) | Extension on `URLRequest` | Leave as-is. Not related to ObjC conversion. |
| `URLSessionTask+RetryPolicy.swift` (Extensions/) | Extension on `URLSessionTask` | Leave as-is. Not related to ObjC conversion. |
| `Network+WebSocket.swift` (Extensions/) | Extension on `SFNetwork` | Leave as-is. |
| `PushNotificationManager+ActionableNotifications.swift` (Extensions/) | Extension on `PushNotificationManager` | Leave as-is. `PushNotificationManager` is already Swift. |
| `URLSessionWebSocketTask+WebSocketClient.swift` (Extensions/) | Extension on `URLSessionWebSocketTask` | Leave as-is. Not related to ObjC conversion. |
| `CryptoUtils.swift` (Security/) | Extension on `SFSDKCryptoUtils` (adds SecKey encrypt/decrypt) | Leave as-is. |
| `ColorExtension.swift` (Util/) | Extension on `UIColor` | Leave as-is. May overlap with `UIColor+SFColors.m` conversion — verify at boundary. |
| All other existing Swift files (54 total) | Pure Swift classes/structs — no ObjC counterparts | Leave as-is. |

**SalesforceSDKCommon:**
| Existing Swift file | Relationship to ObjC | Action |
|---|---|---|
| `KeychainHelper.swift`, `SecItemOperations.swift`, `GenericPasswordItemQuery.swift`, `KeychainItemManager.swift` (Keychain/) | Pure Swift — no ObjC counterparts | Leave as-is. |
| `SalesforceLogReceiver.swift`, `SalesforceLogReceiverFactory.swift` (Logger/) | Pure Swift — no ObjC counterparts | Leave as-is. |

### Library-specific rules
26. **SalesforceSDKCommon:** Foundation-level utilities. Heavy use of `dispatch_queue` → convert to `DispatchQueue` (not async/await — semantic conversion only). `SFSDKSafeMutable*` classes use `dispatch_barrier` patterns.
27. **SalesforceAnalytics:** Model + store + transform. Relatively self-contained. Uses `NSCoding`/`NSSecureCoding` → preserve with `@objc` and `NSCoding` conformance.
28. **SmartStore:** Heavy SQLCipher/FMDB interaction. `SFSmartStore.m` is 2,066 lines — the core of the library. Database access patterns must preserve thread safety. `SFSmartStore+Internal.h` defines internal-only API.
29. **MobileSync:** Sync targets use class hierarchies with factory patterns (`SFSyncTarget` → `SFSyncDownTarget` → `SFSoqlSyncDownTarget`). Preserve inheritance hierarchy. **Three files use `+initialize`** (`SFMobileSyncSyncManager`, `SFLayoutSyncManager`, `SFMetadataSyncManager`) — see rule 19 for the required workaround. Flag as language-forced changes at Operator Gate 4. **One naming conflict:** `SFCompositeRequestHelper.m` → convert as `SFCompositeRequestHelperLegacy.swift` (see conflict map).
30. **SalesforceSDKCore:** Largest library (116 .m files, 22K lines). OAuth, identity, REST, user accounts, IDP, login UI, push notifications. The `SFUserAccountManager.m` (2,388 lines) and `SFOAuthCoordinator.m` (1,057 lines) are security-critical — extra care required. 54 existing Swift files — most are extensions (leave as-is per rule 23) or pure Swift classes (do not touch per rule 25). See conflict map for details.

---

## Execution Timing

| Milestone | Timestamp | Wall-Clock Elapsed |
|-----------|-----------|-------------------|
| Plan execution started | 2026-05-17 17:00 MDT | |
| Pre-flight validation complete | 2026-05-17 18:15 MDT | ~1h15m |
| Baseline test results recorded | 2026-05-17 18:15 MDT | |
| Phase 1 (SalesforceSDKCommon) — conversion started | 2026-05-17 18:20 MDT | |
| Phase 1 — library boundary (build+test) started | 2026-05-17 18:30 MDT | |
| Phase 1 — library boundary complete | 2026-05-17 21:00 MDT | ~2.5h (incl. 2 retries) |
| 🔶 Operator Gate 1 — report generated, awaiting review | 2026-05-17 21:00 MDT | |
| 🔶 Operator Gate 1 — approved, proceeding | 2026-05-17 21:30 MDT | |
| Phase 2 (SalesforceAnalytics) — conversion started | 2026-05-17 21:30 MDT | |
| Phase 2 — library boundary (build+test) started | 2026-05-17 22:00 MDT | |
| Phase 2 — library boundary complete | 2026-05-17 22:15 MDT | ~15m |
| 🔶 Operator Gate 2 — report generated, awaiting review | 2026-05-17 22:15 MDT | |
| 🔶 Operator Gate 2 — approved, proceeding | 2026-05-17 22:20 MDT | |
| Phase 3 (SmartStore) — conversion started | 2026-05-17 22:20 MDT | |
| Phase 3 — library boundary (build+test) started | 2026-05-18 09:00 MDT | |
| Phase 3 — library boundary complete | 2026-05-18 14:30 MDT | ~5.5h (complex, 4 fix iterations) |
| 🔶 Operator Gate 3 — report generated, awaiting review | 2026-05-18 14:30 MDT | |
| 🔶 Operator Gate 3 — approved (with adjustments), proceeding | 2026-05-18 14:35 MDT | |
| Phase 4 (MobileSync) — conversion started | 2026-05-18 14:35 MDT | |
| Phase 4 — library boundary (build+test) started | 2026-05-18 15:00 MDT | |
| Phase 4 — library boundary complete (build only; tests blocked) | 2026-05-18 19:00 MDT | ~4h |
| 🔶 Operator Gate 4 — report generated, awaiting review | 2026-05-18 19:00 MDT | |
| 🔶 Operator Gate 4 — approved (tests deferred to test conversion), proceeding | 2026-05-18 19:10 MDT | |
| Phase 5 (SalesforceSDKCore) — conversion started | 2026-05-18 19:10 MDT | |
| Phase 5 — library boundary (build+test) started | 2026-05-19 10:00 MDT | |
| Phase 5 — library boundary complete (zero code errors) | 2026-05-19 16:00 MDT | ~6h (iterative fix cycles) |
| 🔶 Operator Gate 5 — skipped (operator-directed continuous execution) | 2026-05-19 16:00 MDT | |
| Phase 6 (MobileSyncExplorer) — conversion started | 2026-05-19 16:00 MDT | |
| Phase 6 — app boundary complete | 2026-05-19 16:30 MDT | ~30m |
| Post-conversion (clean build + full test run) started | — | Not performed (Xcode cache bug blocks full build) |
| Plan execution finished | 2026-05-19 16:30 MDT | |
| **Total wall-clock time** | | ~47h (2026-05-17 17:00 → 2026-05-19 16:30) |
| **Total operator wait time** | | ~30m (5 gate reviews) |

### Baseline Test Results (pre-flight)

| Library Scheme | Pass | Fail | Skip | Notes |
|----------------|------|------|------|-------|
| SalesforceSDKCommon | 40 | 0 | 0 | Clean |
| SalesforceAnalytics | 19 | 0 | 0 | Clean |
| SmartStore | 176 | 1 | 0 | Pre-existing: `testGetGlobalStoreNames` (expected failure) |
| MobileSync | 189 | 0 | 0 | Clean (with credentials) |
| SalesforceSDKCore | 625 | 6 | 0 | Pre-existing: `testFailedRequestRemovedFromQueue` + 5 expected failures |

Any pre-existing failures recorded here are **not attributable** to the conversion. The operator review report at each gate compares post-conversion test results against this baseline.

| Build/Test Command | Duration |
|--------------------|----------|
| Pre-flight baseline build | |
| Pre-flight baseline tests | |
| Phase 1 build | |
| Phase 1 test | |
| Phase 2 build | |
| Phase 2 test | |
| Phase 3 build | |
| Phase 3 test | |
| Phase 4 build | |
| Phase 4 test | |
| Phase 5 build | |
| Phase 5 test | |
| Phase 6 build (MobileSyncExplorer) | |
| Post-conversion clean build (all targets) | |
| Post-conversion full test run | |
| **Total build/test idle time** | |

## Unanticipated Issues Log

| # | Phase | Batch/Step | Issue | Resolution | Time Spent |
|---|-------|-----------|-------|------------|------------|
| 1 | 1 | Boundary | Swift 6.3 `objc_subclassing_restricted` on ALL Swift classes — ObjC cannot subclass any Swift class regardless of `open` access level | Downstream logger subclasses refactored to composition; added Rule 32 | ~2h |
| 2 | 1 | Batch 03 | ObjC lightweight generics (`SFSDKSafeMutableDictionary<K,V>`) cannot be `@objc` in Swift | 3 files deferred as ObjC; added Rule 31 | 30m |
| 3 | 1 | Boundary | Duplicate interface errors when both ObjC .h and Swift @objc(ClassName) exist in same module | Adopted Option B: remove .h from target, downstream uses `@import`; tombstone headers | ~1h |
| 4 | 3 | Boundary | NSLock deadlock (ObjC `@synchronized` is re-entrant; NSLock is not) | Changed to NSRecursiveLock everywhere; added Rule 33 | ~1h |
| 5 | 3 | Boundary | NSException.raise() in Swift bypasses ObjC @try/@catch in test harness | Converted to Swift `throws` with proper error propagation; added Rule 34 | ~2h |
| 6 | 4 | Boundary | ObjC test files can't compile against converted Swift classes (selector renames, subclassing, categories) | Operator deferred MobileSync test fixes to test conversion pass | ~2h investigation |
| 7 | 5 | Batch 35 | SFUserAccountManager.m (2,388 lines) exceeds agent session limits — connection drops before write | File deferred as ObjC; ObjC API calls updated to match new Swift-exposed names | ~3h attempts |
| 8 | 5 | Batch 28 | SFOAuthCredentials uses ObjC class-cluster pattern + NSSecureCoding backward compat | File deferred as ObjC with placeholder .swift | 30m |
| 9 | 5 | Boundary | Xcode `_AvailabilityInternal` module cache corruption prevents BUILD SUCCEEDED | System-level Xcode bug; zero code errors confirmed; requires Xcode restart/cache purge | Ongoing |
| 10 | 5 | Boundary | NS_SWIFT_NAME cascading renames: converted Swift code calls upstream APIs by ObjC names, but Swift module exposes renamed APIs | 100+ individual method/property renames across all converted files | ~8h cumulative |

---

## Batch Progress Tracker

198 production .m files across 48 batches.
5 library boundaries + 1 sample app boundary → 6 build passes.

Status key: `[ ]` = pending, `[→]` = in progress, `[✓]` = complete

### Phase 1: SalesforceSDKCommon (12 .m files → 3 batches, 1 build)
Existing Swift: 6 files (Keychain/, Logger/)

| Batch | Files | Lines | Status |
|-------|-------|-------|--------|
| 01 | `SFLogger.m` (352), `SFDefaultLogger.m`, `SFSwiftDetectUtil.m` | ~500 | [✓] |
| 02 | `SFJsonUtils.m`, `SFPathUtil.m`, `SFFileProtectionHelper.m`, `NSUserDefaults+SFAdditions.m` | ~400 | [✓] |
| 03 | `SFSDKSafeMutableArray.m` (231), `SFSDKSafeMutableDictionary.m`, `SFSDKSafeMutableSet.m` (183), `SFSDKReachability.m` (242), `SFSDKDatasharingHelper.m` | ~850 | [✓] ⚠️ SafeMutable{Array,Dictionary,Set} DEFERRED (ObjC generics) |

**Library boundary after batch 03:**
- Retain .m/.h originals on disk; remove from Xcode project only (keep umbrella header `SalesforceSDKCommon.h` — update it)
- Update Xcode project
- Build THIS library only: `xcodebuild build -scheme SalesforceSDKCommon -destination "$SIMULATOR_DEST" CODE_SIGNING_ALLOWED=NO`
- (Phase 1 exception: downstream imports were also updated — see revised boundary model)
- Test: `xcodebuild test -scheme SalesforceSDKCommon -destination "$SIMULATOR_DEST"`
- Lessons files: `prod-conversion-lessons-delta-SalesforceSDKCommon.md`, `prod-conversion-lessons-SalesforceSDKCommon.md`
- Security-critical files in this phase: none
- **🔶 OPERATOR GATE 1** — generate review report, stop, wait for proceed/adjust/stop decision

### Phase 2: SalesforceAnalytics (7 .m files → 2 batches, 1 build)
Existing Swift: 0 files

| Batch | Files | Lines | Status |
|-------|-------|-------|--------|
| 04 | `SFSDKInstrumentationEvent.m` (326), `SFSDKInstrumentationEventBuilder.m` (131), `SFSDKDeviceAppAttributes.m` | ~540 | [✓] |
| 05 | `SFSDKAnalyticsManager.m`, `SFSDKEventStoreManager.m` (232), `SFSDKAILTNTransform.m` (166), `SFSDKAnalyticsLogger.m` | ~520 | [✓] |

**Library boundary after batch 05:**
- Retain .m/.h originals on disk; remove from Xcode project only (keep/update umbrella header `SalesforceAnalytics.h`)
- Fix upstream imports: `#import <SalesforceSDKCommon/...>` → `@import SalesforceSDKCommon;` (already done in Phase 1 for most files)
- Update Xcode project
- Build THIS library only: `xcodebuild build -scheme SalesforceAnalytics -destination "$SIMULATOR_DEST" CODE_SIGNING_ALLOWED=NO`
- Test THIS library only: `xcodebuild test -scheme SalesforceAnalytics -destination "$SIMULATOR_DEST"`
- Lessons files
- Security-critical files in this phase: none
- **🔶 OPERATOR GATE 2** — generate review report, stop, wait for proceed/adjust/stop decision

### Phase 3: SmartStore (13 .m files → 4 batches, 1 build)
Existing Swift: 1 file (`SmartStore.swift` — extension)

| Batch | Files | Lines | Status |
|-------|-------|-------|--------|
| 06 | `SFSoupIndex.m`, `SFStoreCursor.m`, `SFSDKStoreConfig.m`, `SFSDKSmartStoreLogger.m` | ~450 | [✓] |
| 07 | `SFSmartStore.m` (2,066 lines — solo large file) | 2,066 | [✓] |
| 08 | `SFSmartStoreDatabaseManager.m` (571), `SFSmartStoreUtils.m`, `SFQuerySpec.m` (526) | ~1,200 | [✓] |
| 09 | `SFSmartSqlHelper.m`, `SFSmartSqlCache.m`, `SFAlterSoupLongOperation.m`, `SFSmartStoreInspectorViewController.m` (607), `SmartStoreSDKManager.m` | ~1,300 | [✓] |

**Library boundary after batch 09:**
- Retain .m/.h originals on disk; remove from Xcode project only (keep/update umbrella header `SmartStore.h`)
- Fix upstream imports: `#import <SalesforceSDKCommon/...>` and `#import <SalesforceAnalytics/...>` → `@import` (as needed)
- Verify existing `SmartStore.swift` extension compiles as-is (per rule 23 — do not merge)
- Update Xcode project
- Build THIS library only: `xcodebuild build -scheme SmartStore -destination "$SIMULATOR_DEST" CODE_SIGNING_ALLOWED=NO`
- Test THIS library only: `xcodebuild test -scheme SmartStore -destination "$SIMULATOR_DEST"`
- Lessons files
- Security-critical files in this phase: none (SmartStore encryption is SQLCipher-based, not in these ObjC files)
- **🔶 OPERATOR GATE 3** — generate review report, stop, wait for proceed/adjust/stop decision

### Phase 4: MobileSync (37 .m files → 9 batches, 1 build)
Existing Swift: 7 files (SyncTarget.swift, BatchSyncUpTarget.swift, CollectionSyncUpTarget.swift, BriefcaseSyncDownTarget.swift, BriefcaseObjectInfo.swift, CompositeRequestHelper.swift, MobileSync.swift)

**Note:** Several existing Swift files interact with ObjC classes being converted — see the **Pre-conversion conflict map** in the Seed Conversion Rules section. Key points: all existing Swift extension files (`SyncTarget.swift`, `BatchSyncUpTarget.swift`, `MobileSync.swift`) are left as-is; `CollectionSyncUpTarget.swift` and `BriefcaseSyncDownTarget.swift` are pure Swift with no ObjC counterpart; `CompositeRequestHelper.swift` is a **naming conflict** — the ObjC `SFCompositeRequestHelper.m` must be converted as `SFCompositeRequestHelperLegacy.swift`.

| Batch | Files | Lines | Status |
|-------|-------|-------|--------|
| 10 | `SFSyncTarget.m`, `SFSyncDownTarget.m`, `SFSyncUpTarget.m` (386) | ~700 | [✓] |
| 11 | `SFSoqlSyncDownTarget.m`, `SFSoslSyncDownTarget.m`, `SFMruSyncDownTarget.m`, `SFRefreshSyncDownTarget.m` | ~600 | [✓] |
| 12 | `SFLayoutSyncDownTarget.m`, `SFMetadataSyncDownTarget.m`, `SFBatchSyncUpTarget.m`, `SFAdvancedSyncUpTarget.m` | ~400 | [✓] |
| 13 | `SFParentChildrenSyncDownTarget.m`, `SFParentChildrenSyncUpTarget.m` (592) | ~900 | [✓] |
| 14 | `SFMobileSyncSyncManager.m` (552), `SFSyncTask.m`, `SFSyncDownTask.m`, `SFSyncUpTask.m` | ~1,000 | [✓] |
| 15 | `SFAdvancedSyncUpTask.m`, `SFCleanSyncGhostsTask.m`, `SFLayoutSyncManager.m`, `SFMetadataSyncManager.m`, `MobileSyncSDKManager.m` | ~600 | [✓] |
| 16 | `SFSyncState.m` (380), `SFSyncOptions.m`, `SFSDKSoqlMutator.m`, `SFSDKSoqlTokenizer.m`, `SFSDKSyncsConfig.m` | ~800 | [✓] |
| 17 | `SFChildrenInfo.m`, `SFParentInfo.m`, `SFParentChildrenSyncHelper.m`, `SFCompositeRequestHelper.m` (**→ Legacy suffix**, see conflict map), `SFMobileSyncNetworkUtils.m`, `SFMobileSyncObjectUtils.m` | ~600 | [✓] |
| 18 | `SFMobileSyncConstants.m`, `SFSDKMobileSyncLogger.m`, `SFObject.m`, `SFLayout.m`, `SFMetadata.m`, `SFMobileSyncPersistableObject.m` | ~600 | [✓] |

**Library boundary after batch 18:**
- Retain .m/.h originals on disk; remove from Xcode project only (keep/update umbrella header `MobileSync.h`)
- Fix upstream imports: `#import <SalesforceSDKCommon/...>`, `#import <SalesforceAnalytics/...>`, `#import <SmartStore/...>` → `@import` (as needed)
- Verify existing 7 Swift files compile as-is against converted base classes (per rule 23 — do not merge)
- Update Xcode project
- Build THIS library only: `xcodebuild build -scheme MobileSync -destination "$SIMULATOR_DEST" CODE_SIGNING_ALLOWED=NO`
- Test THIS library only: `xcodebuild test -scheme MobileSync -destination "$SIMULATOR_DEST"`
- Lessons files
- Language-forced changes in this phase: **3 files** with `+initialize` → static lazy init (`SFMobileSyncSyncManager`, `SFLayoutSyncManager`, `SFMetadataSyncManager`) — see rule 19
- Security-critical files in this phase: none
- **🔶 OPERATOR GATE 4** — generate review report (include language-forced change review), stop, wait for proceed/adjust/stop decision

### Phase 5: SalesforceSDKCore (116 .m files → 28 batches, 1 build)
Existing Swift: 54 files across Extensions/, OAuth/, Security/, PushNotification/, Login/, Storage/, RestAPI/, Common/, Views/, IDP/

**Note:** This library has 54 existing Swift files — see the **Pre-conversion conflict map** for the full inventory. Most are extensions on ObjC classes (leave as-is per rule 23) or pure Swift classes (do not touch per rule 25). No naming conflicts were identified in this library. The extensions (e.g., `RestClient.swift`, `UserAccountManager.swift`, `CryptoUtils.swift`) should compile against the converted Swift base classes without changes — verify at the library boundary.

#### Phase 5 parallel execution model

The 28 batches in Phase 5 are organized into 8 sub-phases that group into **4 parallel tracks** for semantic conversion. These tracks are functionally independent — no ObjC file in one track imports or references types from another track within SalesforceSDKCore (they all import from upstream libraries, which are already converted by this point).

| Track | Sub-phases | Batches | Files | Description |
|-------|-----------|---------|-------|-------------|
| A | 5a (Common) + 5b (Utilities) | 19–25 | 31 | Foundation categories, utilities, builders |
| B | 5c (Security) + 5d (OAuth/Identity) | 26–30 | 17 | Security-critical cluster |
| C | 5e (REST) + 5f (User Accounts) | 31–38 | 25 | REST API + user account management |
| D | 5g (IDP/Commands/URLs) + 5h (Login/Views/Manager) | 39–46 | 43 | IDP, URL handlers, login UI, views, SDK manager |

**How it works (scout-then-parallel):**

**Step 1 — Scout batches (sequential, 4 batches):**
Before launching parallel tracks, run one "scout batch" from each track domain sequentially. This surfaces domain-specific patterns that Phases 1–4 might not have encountered:
- Batch 19 (Track A scout — Foundation categories)
- Batch 26 (Track B scout — Security/crypto)
- Batch 31 (Track C scout — REST API)
- Batch 39 (Track D scout — IDP commands)

Each scout batch is run by a short-lived agent. After all 4 scouts complete, the orchestrator:
1. Collects delta notes from each scout
2. Updates the **pattern registry** with new provisional patterns
3. Drafts **scout addenda** — domain-specific rule updates discovered by the scouts
4. Includes scout addenda + updated registry in the parallel track agents' prompts

This costs ~4 sequential batches but gives all 4 parallel tracks the benefit of each domain's initial discoveries, preventing the same error from being repeated across tracks.

**Step 2 — Parallel track execution (4 tracks, remaining batches):**
1. The orchestrator constructs a **scope fence** for each track (listing exactly which files each track may create/modify — excluding the already-completed scout batch)
2. The orchestrator spawns 4 sub-agents in parallel, one per track — each receives its scope fence, the cumulative lessons from Phase 4, the **pattern registry** (with scout discoveries), the **rule addenda** (including scout addenda), the **accuracy briefing**, and the conflict map
3. Each agent reads the same cumulative lessons from Phase 4 (read-only, no conflict)
4. Each agent writes its own delta file: `prod-conversion-lessons-delta-SalesforceSDKCore-trackA.md`, etc.
5. Each agent converts its remaining batches sequentially within the track, following the **re-anchor step** before each batch
6. Each agent returns its **completion manifest** to the orchestrator when done
7. The orchestrator runs the **verification checklist** for each track, **plus** a cross-track isolation check:
   - Collect `git diff --name-only` per track
   - Verify zero overlap between tracks — any shared modified file is contamination
   - Verify no track modified files outside its scope fence
8. Only after all 4 tracks pass verification does the orchestrator spawn the **boundary agent** with all 4 delta files (+ scout deltas) for the **single, serial library boundary** (Xcode project update, build, test, etc.). The boundary agent merges all delta files into the cumulative lessons file.

**Constraints:**
- The library boundary (build, test, Xcode project, podspec, commit) is **always serial** — you can't partially build a library
- Scout batches eliminate the biggest parallelism weakness: parallel tracks previously couldn't share lessons at all. Now each track starts with domain-specific patterns from the scout phase.
- If any track hits an escalation threshold during semantic conversion (e.g., discovers an un-convertible pattern), it writes its delta notes and stops. The orchestrator waits for all tracks to complete before assessing.
- If any track fails the verification checklist, the orchestrator investigates before proceeding to the build — it does not start the build on unverified work.

**Expected speedup:** Phase 5 has 28 batches. Scout phase uses 4 batches sequentially. Remaining 24 batches run in 4 parallel tracks, limited by the longest track (~7 batches). Total: 4 + 7 = ~11 sequential-equivalent batches. This is roughly a **2.5x speedup on Phase 5 semantic work** (vs. 3x without scouts), translating to an estimated **1.8x speedup on total plan wall-clock time**. The small speedup reduction is paid back by fewer errors during the parallel phase.

**Fallback:** If the operator prefers serial execution (simpler, easier to debug), all 4 tracks can be run sequentially as sub-phases 5a–5h with no changes to the batch structure. The parallel model is the default but can be overridden at Operator Gate 4.

#### Sub-phase 5a: Common/Foundation utilities — **Track A**

| Batch | Files | Lines | Status |
|-------|-------|-------|--------|
| 19 | `NSData+SFAdditions.m`, `NSData+SFSDKUtils.m`, `NSDictionary+SFAdditions.m`, `NSString+SFAdditions.m` | ~500 | [✓] |
| 20 | `NSURL+SFAdditions.m`, `NSURLResponse+SFAdditions.m`, `NSURL+SFStringUtils.m`, `UIDevice+SFHardware.m`, `UIScreen+SFAdditions.m` | ~400 | [✓] |
| 21 | `SFFormatUtils.m`, `SFSDKAppConfig.m`, `SFSDKAppFeatureMarkers.m`, `SalesforceSDKCoreDefines.m`, `SFSDKSalesforceSDKUpgradeManager.m` | ~500 | [✓] |

#### Sub-phase 5b: Utilities — **Track A** (continued)

| Batch | Files | Lines | Status |
|-------|-------|-------|--------|
| 22 | `SFApplicationHelper.m`, `SFDirectoryManager.m`, `SFManagedPreferences.m`, `SFPreferences.m` | ~500 | [✓] |
| 23 | `SFSDKCoreLogger.m`, `SFSDKMacDetectUtil.m`, `SFSDKResourceUtils.m`, `SFSDKViewUtils.m`, `SFSDKWebUtils.m` | ~300 | [✓] |
| 24 | `UIColor+SFColors.m`, `SFSDKViewControllerConfig.m`, `SFSDKSoqlBuilder.m`, `SFSDKSoslBuilder.m`, `SFSDKSoslReturningBuilder.m` | ~500 | [✓] |
| 25 | `SFSDKAuthConfigUtil.m`, `SFSDKAuthHelper.m`, `SFSDKOAuth2.m` | ~500 | [✓] |

#### Sub-phase 5c: Security — **Track B**

| Batch | Files | Lines | Status |
|-------|-------|-------|--------|
| 26 | `SFEncryptionKey.m`, `SFSDKCryptoUtils.m`, `SFSDKPushNotificationDecryption.m`, `SFSDKPushNotificationError.m` | ~400 | [✓] |

#### Sub-phase 5d: OAuth and Identity — **Track B** (continued)

| Batch | Files | Lines | Status |
|-------|-------|-------|--------|
| 27 | `SFOAuthCoordinator.m` (1,057 lines — near-solo), `SFOAuthInfo.m` | ~1,150 | [✓] |
| 28 | `SFOAuthCredentials.m`, `SFOAuthKeychainCredentials.m`, `SFOAuthOrgAuthConfiguration.m`, `SFOAuthSessionRefresher.m` | ~700 | [✓] ⚠️ SFOAuthCredentials + SFOAuthKeychainCredentials DEFERRED (class-cluster) |
| 29 | `SFSDKAuthRequest.m`, `SFSDKAuthSession.m`, `SFSDKAuthViewHandler.m`, `SFSDKAuthRootController.m`, `SFSDKAuthPreferences.m` | ~400 | [✓] |
| 30 | `SFIdentityCoordinator.m`, `SFIdentityData.m` | ~600 | [✓] |

#### Sub-phase 5e: REST API — **Track C**

| Batch | Files | Lines | Status |
|-------|-------|-------|--------|
| 31 | `SFRestAPI.m` (863), `SFRestRequest.m` | ~1,200 | [✓] |
| 32 | `SFRestAPI+Files.m`, `SFRestAPI+Notifications.m`, `SFRestAPI+QueryBuilder.m`, `SFNetwork.m` | ~600 | [✓] |
| 33 | `SFSDKBatchRequest.m`, `SFSDKBatchResponse.m`, `SFSDKCompositeRequest.m`, `SFSDKCompositeResponse.m`, `SFSDKCollectionResponse.m` | ~400 | [✓] |
| 34 | `SFSDKEncryptedURLCache.m`, `SFSDKNullURLCache.m`, `SFSDKPrimingRecordsResponse.m`, `SFSObjectTree.m` | ~300 | [✓] |

#### Sub-phase 5f: User Accounts — **Track C** (continued)

| Batch | Files | Lines | Status |
|-------|-------|-------|--------|
| 35 | `SFUserAccountManager.m` (2,388 lines — solo large file) | 2,388 | [✓] ⚠️ DEFERRED (exceeds agent session limits; remains ObjC) |
| 36 | `SFUserAccount.m`, `SFUserAccountIdentity.m`, `SFDefaultUserAccountPersister.m` | ~600 | [✓] |
| 37 | `SFAuthErrorHandler.m`, `SFAuthErrorHandlerList.m`, `SFSDKAuthErrorManager.m` | ~300 | [✓] |
| 38 | `SFDefaultUserManagementViewController.m`, `SFDefaultUserManagementListViewController.m`, `SFDefaultUserManagementDetailViewController.m` | ~500 | [✓] |

#### Sub-phase 5g: IDP / Commands / URL Handlers — **Track D**

| Batch | Files | Lines | Status |
|-------|-------|-------|--------|
| 39 | `SFSDKAuthCommand.m`, `SFSDKAuthErrorCommand.m`, `SFSDKIDPAuthCodeLoginRequestCommand.m`, `SFSDKIDPLoginRequestCommand.m`, `SFSDKSPLoginRequestCommand.m`, `SFSDKSPLoginResponseCommand.m` | ~400 | [✓] |
| 40 | `SFSDKIDPAuthHelper.m`, `SFSDKIDPConstants.m`, `SFUserAccountManager+URLHandlers.m`, `UIFont+SFSDKIDP.m` | ~400 | [✓] |
| 41 | `SFSDKUserSelectionNavViewController.m`, `SFSDKUserSelectionTableViewController.m`, `SFSDKUITableViewCell.m`, `SFSDKLoginFlowSelectionViewController.m` | ~400 | [✓] |
| 42 | `SFSDKURLHandlerManager.m`, `SFSDKAdvancedAuthURLHandler.m`, `SFSDKIDPAuthCodeLoginRequestHandler.m`, `SFSDKIDPLoginRequestHandler.m`, `SFSDKIDPErrorHandler.m`, `SFSDKIDPRequestHandler.m`, `SFSDKSPLoginResponseHandler.m`, `SFSDKStartURLHandler.m` | ~500 | [✓] |

#### Sub-phase 5h: Login / Views / Analytics / Manager / Test utils — **Track D** (continued)

| Batch | Files | Lines | Status |
|-------|-------|-------|--------|
| 43 | `SFLoginViewController.m`, `SFSDKLoginViewControllerConfig.m`, `SFSDKLoginHost.m`, `SFSDKLoginHostListViewController.m`, `SFSDKLoginHostStorage.m`, `SFSDKTextFieldTableViewCell.m` | ~700 | [✓] |
| 44 | `SalesforceSDKManager.m` (1,081 — near-solo), `SFSDKAILTNPublisher.m`, `SFSDKEventBuilderHelper.m`, `SFSDKSalesforceAnalyticsManager.m` | ~1,400 | [✓] |
| 45 | `SFSDKAlertMessage.m`, `SFSDKAlertMessageBuilder.m`, `SFSDKAlertView.m`, `SFSDKNavigationController.m`, `SFSDKRootController.m`, `SFSDKViewController.m`, `SFSDKWindowContainer.m`, `SFSDKWindowManager.m` | ~600 | [✓] |
| 46 | `SFSDKTestCredentialsData.m` (Test util), `SFSDKTestRequestListener.m` (Test util), `TestSetupUtils.m` (Test util) | ~300 | [✓] |

**Library boundary after batch 46:**
- Retain .m/.h originals on disk; remove from Xcode project only (keep/update umbrella header `SalesforceSDKCore.h`)
- Fix upstream imports: `#import <SalesforceSDKCommon/...>`, `#import <SalesforceAnalytics/...>`, `#import <SmartStore/...>`, `#import <MobileSync/...>` → `@import` (as needed)
- Verify existing 54 Swift files compile as-is against converted base classes (per rule 23 — do not merge)
- Update Xcode project
- Build THIS library only: `xcodebuild build -scheme SalesforceSDKCore -destination "$SIMULATOR_DEST" CODE_SIGNING_ALLOWED=NO`
- Test THIS library only: `xcodebuild test -scheme SalesforceSDKCore -destination "$SIMULATOR_DEST"`
- Lessons files
- Security-critical files in this phase: **13 files** — `SFOAuthCoordinator`, `SFOAuthCredentials`, `SFOAuthKeychainCredentials`, `SFOAuthSessionRefresher`, `SFUserAccountManager`, `SFUserAccount`, `SFDefaultUserAccountPersister`, `SFSDKCryptoUtils`, `SFEncryptionKey`, `SFSDKPushNotificationDecryption`, `SFSDKAuthSession`, `SFSDKAuthRequest`, `SFSDKOAuth2`
- **🔶 OPERATOR GATE 5** — generate review report (with detailed security-critical file review), stop, wait for proceed/adjust/stop decision

### Phase 6: MobileSyncExplorer Sample App (13 .m files → 2 batches, 1 build)

This is the only sample app with ObjC code. It lives outside `libs/` in `native/SampleApps/MobileSyncExplorer/` and imports from all 5 SDK libraries. The other sample apps (AuthFlowTester, RestAPIExplorer) are already Swift.

Phase 6 runs **after Operator Gate 5** and is fully autonomous (no operator gate — it's a sample app, not a library). It uses the full cumulative lessons from Phases 1–5, the pattern registry, and all rule addenda. No parallel tracks needed — only 2 batches.

Existing Swift: 0 files

| Batch | Files | Lines | Status |
|-------|-------|-------|--------|
| 47 | `AppDelegate.m` (113), `main.m` (18), `SceneDelegate.m` (161), `InitialViewController.m` (69), `ActionsPopupController.m` (89), `ContactDetailViewController.m` (312), `ContactListViewController.m` (648) | ~1,410 | [✓] |
| 48 | `ContactSObjectData.m` (103), `ContactSObjectDataSpec.m` (60), `MobileSyncExplorerConfig.m` (52), `SObjectData.m` (101), `SObjectDataFieldSpec.m` (38), `SObjectDataManager.m` (203), `SObjectDataSpec.m` (112) | ~669 | [✓] |

**App boundary after batch 48:**
- Retain .m/.h originals on disk; remove from Xcode project only
- Update Xcode project: `native/SampleApps/MobileSyncExplorer/MobileSyncExplorer.xcodeproj/project.pbxproj`
- Build: `xcodebuild build -project native/SampleApps/MobileSyncExplorer/MobileSyncExplorer.xcodeproj -scheme MobileSyncExplorer -destination "$SIMULATOR_DEST" CODE_SIGNING_ALLOWED=NO`
- No test suite (sample app has no unit tests)
- Commit: `"Convert MobileSyncExplorer sample app ObjC to Swift (Phase 6)"`
- No operator gate — proceed directly to post-conversion steps

---

## Learning Flow Diagram

```
Batches 01–03 (semantic, autonomous)
  → deltas → prod-conversion-lessons-delta-SalesforceSDKCommon.md
  ↓
Library boundary: build + test + self-review → prod-conversion-lessons-SalesforceSDKCommon.md
  ↓
🔶 OPERATOR GATE 1 — review report → proceed / adjust / stop
  ↓
Batches 04–05 (semantic, autonomous)
  → deltas → prod-conversion-lessons-delta-SalesforceAnalytics.md
  ↓
Library boundary: build + test + self-review → prod-conversion-lessons-SalesforceAnalytics.md
  ↓
🔶 OPERATOR GATE 2 — review report → proceed / adjust / stop
  ↓
Batches 06–09 (semantic, autonomous)
  → deltas → prod-conversion-lessons-delta-SmartStore.md
  ↓
Library boundary: build + test + self-review → prod-conversion-lessons-SmartStore.md
  ↓
🔶 OPERATOR GATE 3 — review report → proceed / adjust / stop
  ↓
Batches 10–18 (semantic, autonomous)
  → deltas → prod-conversion-lessons-delta-MobileSync.md
  ↓
Library boundary: build + test + self-review → prod-conversion-lessons-MobileSync.md
  ↓
🔶 OPERATOR GATE 4 — review report → proceed / adjust / stop
  ↓
Phase 5 — scout-then-parallel:
  Scout batches (sequential): 19, 26, 31, 39 → scout addenda + pattern registry update
  ↓
  Parallel tracks (remaining batches):
    Track A (batches 20–25) → prod-conversion-lessons-delta-SalesforceSDKCore-trackA.md
    Track B (batches 27–30) → prod-conversion-lessons-delta-SalesforceSDKCore-trackB.md
    Track C (batches 32–38) → prod-conversion-lessons-delta-SalesforceSDKCore-trackC.md
    Track D (batches 40–46) → prod-conversion-lessons-delta-SalesforceSDKCore-trackD.md
  ↓ (all 4 tracks complete)
Merge all deltas → library boundary: build + test + self-review (+ security-critical file review)
  → prod-conversion-lessons-SalesforceSDKCore.md
  ↓
🔶 OPERATOR GATE 5 — review report (security focus) → proceed / adjust / stop
  ↓
Batches 47–48 (Phase 6 — MobileSyncExplorer sample app, autonomous)
  → prod-conversion-lessons-delta-MobileSyncExplorer.md
  ↓
App boundary: build (no tests) → commit
  ↓
Post-conversion: clean build all, full test run, commit, push
```

---

## Post-Conversion Steps

1. **Clean build all targets** sequentially with `CODE_SIGNING_ALLOWED=NO`
2. **Run all test suites** sequentially — compare results against the **Baseline Test Results** table from pre-flight. Any new failures are conversion regressions.
3. **Verify CocoaPods podspecs** still reference correct source files and `exclude_files` are in place
4. **Verify Swift Package Manager** Package.swift still works (if applicable)
5. **Verify audit artifacts** — confirm all original .m/.h files remain on disk and are NOT referenced in any `project.pbxproj`. Run: `find libs -name "*.m" -not -path "*Test*" | wc -l` (should equal 185 for libraries) and `find native/SampleApps/MobileSyncExplorer -name "*.m" | wc -l` (should equal 13 for sample app). Verify none appear in build phases.
6. **Final commit** — `"Verify clean build and full test pass after production ObjC→Swift conversion"` (see "Commit strategy" section)
7. **Push** to `feature/objc-to-swift-production-migration`
8. **(Future)** After a separate verification pass confirms conversion accuracy, remove original .m/.h files in a dedicated cleanup commit

---

## File Counts

| Phase | Library | ObjC .m Files | Existing .swift | Batches | Build Pass |
|-------|---------|--------------|-----------------|---------|------------|
| 1 | SalesforceSDKCommon | 12 | 6 | 3 (01–03) | After batch 03 |
| 2 | SalesforceAnalytics | 7 | 0 | 2 (04–05) | After batch 05 |
| 3 | SmartStore | 13 | 1 | 4 (06–09) | After batch 09 |
| 4 | MobileSync | 37 | 7 | 9 (10–18) | After batch 18 |
| 5 | SalesforceSDKCore | 116 | 54 | 28 (19–46) | After batch 46 |
| 6 | MobileSyncExplorer (sample app) | 13 | 0 | 2 (47–48) | After batch 48 |
| **Total** | | **198** | **68** | **48 batches** | **6 builds** |

## Lessons Files Summary

**Planned vs. Actual:**

| Type | Planned | Actual | Notes |
|------|---------|--------|-------|
| Cumulative (per library) | 5 | 1 | Only `prod-conversion-lessons-SalesforceAnalytics.md` created; others skipped due to agent session limits |
| Delta (Phases 1–4) | 4 | 4 | All created: SDKCommon, Analytics, SmartStore, MobileSync |
| Delta (Phase 5 scouts/tracks) | 8 | 0 | Phase 5 used serial sequential execution (not scout-then-parallel) due to agent stability |
| Delta (Phase 6) | 1 | 0 | Skipped (trivial sample app, no lessons worth recording) |
| Pattern registry | 1 | 1 | `prod-conversion-patterns.md` — 14 verified patterns |
| **Total** | **19** | **6** | Key lessons captured in Unanticipated Issues Log and memory files instead |

**Note:** Phase 5 did not use the planned scout-then-parallel model. Due to repeated agent connection timeouts, it was executed sequentially in smaller batch groups (3-5 batches per agent). The lessons that would have been in cumulative files are captured in the Unanticipated Issues Log above and in the project memory files.
