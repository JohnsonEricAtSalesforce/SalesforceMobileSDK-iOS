# Test Suite ObjC → Swift Conversion Plan

**Date:** 2026-05-17 (updated)
**Branch:** feature/objc-to-swift-test-migration
**Goal:** Convert all 98 Objective-C test files (.m) and 33 headers (.h) to idiomatic Swift
**Total files to convert:** 98 .m files (headers are consumed during conversion, not counted separately)
**Prerequisite:** The production ObjC → Swift conversion plan (`production-swift-conversion-plan.md`) must be complete before this plan runs. Production code is now Swift; test files must be converted to call the Swift production API.
**Audit goal:** Retain all original .m/.h test files on disk as unreferenced audit artifacts for post-conversion verification

---

## How to Execute This Plan

### First run
Provide this file to Claude with the instruction:

> "Execute the ObjC→Swift test conversion plan in test-swift-conversion-plan.md"

### Resuming after session termination
Provide this file to Claude with the instruction:

> "Resume the ObjC→Swift test conversion from the plan in test-swift-conversion-plan.md"

Claude should:
1. Read this plan to understand the approach and batch structure
2. Check the **Batch Progress Tracker** below to find the last completed batch
3. Read the most recent lessons-learned file(s) to load accumulated knowledge:
   - Latest **cumulative** lessons file: `test-conversion-lessons-LIBRARY.md` (for last completed library)
   - Latest **delta** file: `test-conversion-lessons-delta-LIBRARY.md` (for in-progress library, if any)
   - **Pattern registry**: `test-conversion-patterns.md` (machine-readable verified patterns — always read this)
   - **Production pattern registry**: `prod-conversion-patterns.md` (verified production API patterns — always read this as reference for how production API maps ObjC→Swift)
   - **Phase 5 variant:** If resuming mid-Phase 5, read all scout and track-specific delta files that exist (`test-conversion-lessons-delta-SalesforceSDKCore-scoutX.md` and `trackA.md` through `trackD.md`). Check which scouts/tracks have completed (all batches `[✓]`) vs. which are in-progress or not started.
4. If the orchestrator is restarting and the batch tracker shows all batches `[✓]` for the current library but no library boundary timestamp exists, re-run the **orchestrator verification checklist** before proceeding to the boundary.
5. Resume from the next incomplete batch (or next incomplete track, for Phase 5)

---

## Critical Context: This Plan Runs After Production Conversion

The production ObjC → Swift conversion has already been completed. This changes the test conversion fundamentally compared to the original plan:

### Production code is now Swift
- All production `.m` files have been converted to `.swift` and are compiled as Swift
- Original production `.m`/`.h` files remain on disk (retained for audit) but are **not in the Xcode project** — they cannot be imported
- Test files that previously used `#import "SFSmartStore.h"` must now use `@testable import SmartStore` (or `import SmartStore`)

### Bridging headers are obsolete
- `SalesforceSDKCoreTests-Bridging-Header.h` imports deleted production ObjC headers — it must be **removed**, not updated
- `MobileSyncTests-Bridging-Header.h` similarly imports ObjC headers that no longer exist in the project — it must be **removed**
- After removal, any ObjC test code that relied on bridging header imports must use Swift module imports instead

### The production pattern registry is an input
- `prod-conversion-patterns.md` contains verified ObjC→Swift API mappings discovered during the production conversion
- `prod-conversion-lessons-SalesforceSDKCore.md` (the final cumulative lessons file) contains rule addenda, pitfalls, and @objc interop patterns
- These are read-only inputs — the test plan does not modify production artifacts

### Tests adapt to production, not the reverse
- The converted production Swift code is the source of truth for API signatures
- When an ObjC test calls `[SFSmartStore sharedStoreWithName:]`, the Swift equivalent is whatever the production conversion produced — grep the production `.swift` file, don't guess
- Test failures after conversion indicate a test conversion bug, not a production bug. Fix the test.

### ObjC test files do not compile against current production code
- The existing ObjC test files reference deleted ObjC headers and pre-migration APIs. They are already broken.
- ObjC and Swift test files cannot coexist incrementally within a target — the ObjC files won't compile
- Compilation only happens at library boundaries, after ALL ObjC test files in a test target have been converted

---

## Autonomous Execution Model

### Orchestrator role definition
The orchestrator is the top-level Claude session. It manages workflow, spawns agents, and verifies work. It **never** performs conversion work itself.

**The orchestrator DOES:**
- Run pre-flight validation (build, test, environment checks — verification, not conversion)
- Construct scope fences for each agent from the batch tracker
- Spawn sub-agents with complete prompts (plan context, lessons, scope fence, conflict map entries, **rule addenda**, **accuracy briefing**, **pattern registries**)
- Receive agent completion manifests
- Run the orchestrator verification checklist (mechanical file/scope checks)
- Record timestamps in the Execution Timing table
- Compute **accuracy briefing** from build/test results (arithmetic, not judgment)
- Include **rule addenda** (drafted by the boundary agent) in the next agent's prompt
- Include both **pattern registries** (test + production) in every agent's prompt materials
- Provide all track delta files to the Phase 5 boundary agent
- Generate the operator review report
- Manage operator gates (present report, wait for decision, relay adjustments)
- Manage git commits at library boundaries

**The orchestrator DOES NOT:**
- Convert any ObjC file to Swift
- Fix build errors or test failures
- Edit `project.pbxproj`, podspecs, umbrella headers, or any source file
- Write or modify any `.swift` file
- Apply seed conversion rules or conflict map decisions
- Make judgment calls about conversion patterns — these belong to agents

**Bright line:** If a task requires reading an ObjC `.m` file and producing Swift code, it is agent work. If a task requires running a command and checking its output against an expected value, it is orchestrator work.

### Handoff protocol at each phase

Same three-point handoff as the production plan:

**Handoff 1 — Orchestrator → Agent:** Scope fence, cumulative lessons, pattern registries (both test and production), rule addenda, accuracy briefing, conflict map entries. Spawns agent.

**Handoff 2 — Agent → Orchestrator → Agent:** Agent returns completion manifest and pauses. This is a single agent session — the orchestrator uses `SendMessage` to resume the same agent after verification passes. The agent retains full context for build error repair. If verification fails, the orchestrator sends specific failures back to the agent. If the orchestrator session dies mid-verification, restart recovery re-runs the checklist before spawning a new boundary agent.

**Handoff 3 — Agent → Orchestrator:** Agent returns final report (build/test results, operator review report, cumulative lessons). Orchestrator presents at operator gate.

### Phase 5 handoff (parallel tracks)

Same scout-then-parallel model as the production plan. Phase 5 spawns 4 sequential scout agents (one per track domain), then 4 parallel track agents. A fresh boundary agent handles the library boundary.

### Agent-per-library architecture (Phases 1–4)
Same as production plan: one agent per library, verification pause between semantic conversion and boundary work.

### Agent architecture for Phase 5 (scouts + parallel tracks + boundary agent)
Same as production plan: 4 scouts → 4 parallel tracks → 1 boundary agent.

### Autonomous within libraries, gated at Phase 5
Phases 1–4 run **fully autonomous** (test code is lower-risk than production). An operator review gate occurs only at the **Phase 5 boundary** (SalesforceSDKCore — 56 files, the largest and most complex phase, with 30 existing Swift test files to integrate).

Lessons files and progress tracker updates serve as **recovery checkpoints**. If a session is terminated mid-run, the plan can be resumed from the last completed batch.

### Agent scope fence
Same structure as production plan. Each agent receives:
- Files it MUST create (one .swift per .m)
- Files it may MODIFY (plan file, delta notes, pattern registry)
- Files it must NOT modify (existing Swift test files listed as "Leave as-is" in conflict map, any production .swift file, any .m/.h file, any project.pbxproj/podspec)

### Agent completion manifest
Same structured manifest as production plan — files converted table, rules applied, files NOT touched, scope fence violations, delta notes, batch tracker updates, issues requiring attention.

### Orchestrator verification checklist
Same 11-check mechanical checklist as production plan: file existence, scope compliance, conflict map compliance, @objc spot check (where applicable), delta notes, manifest consistency. For Phase 5 parallel tracks, additionally verify zero file overlap between tracks.

### Operator review report (generated at Phase 5 boundary)

```
# Operator Review — Phase 5 (SalesforceSDKCore Tests)

## Orchestrator Verification Results
- All verification checks passed: yes/no
- File existence: N/N confirmed
- Scope fence violations: N (list, or "none")
- Cross-track overlap (Phase 5): none / (list)
- Issues found and resolved: (list, or "none")

## Conversion Scope
- ObjC test files converted: N
- Swift test files written: N
- Existing Swift test files in this library: 30
  - Left as-is (compiled without changes): N
  - Required updates: N (list)
- Naming conflicts resolved with Legacy suffix: 2 (ScreenLockManagerTests, SFOAuthCoordinatorTests)

## Build Results
- First-pass build errors: N
- Errors after repair: N (of 3 max attempts)
- Error categories: (list)

## Test Results
- Tests passed: N
- Tests failed: N
- Tests skipped/disabled: N
- New failures vs. baseline: N (list)
- Pre-existing failures (from baseline): N (list)
- Failure categories: (list)

## Self-Review Summary
- Conversion accuracy: N% first-pass
- Key lessons learned: (1–3 bullet points)

## Decision Required
- [ ] **Proceed** to post-conversion steps
- [ ] **Adjust** (describe changes)
- [ ] **Stop** (investigate)
```

### Escalation thresholds
Same graduated thresholds as production plan:
- **>20 build errors** after first repair → stop, likely systemic
- **>10 same-category errors** after first repair → stop, strategy problem
- **>10 test failures** after first repair → stop, behavioral regression
- **Any crash** (SIGABRT, EXC_BAD_ACCESS) persisting after 1 repair → stop

### Stopping conditions
Claude stops immediately if an escalation threshold is hit, an unrecoverable error occurs, or permission prompts block operation.

### Permission requirements
Same as production plan plus `ruby` for project file manipulation:
- File read/write/edit across the repo
- Bash commands: `xcodebuild`, `find`, `grep`, `rm`, `git`, `ls`, `cat`, `wc`, `ruby`

---

## Original File Retention for Audit

Same approach as production plan: original `.m`/`.h` test files are **kept on disk** but **removed from the Xcode project**. This enables side-by-side audit of each converted test file against its original.

Implementation at library boundaries:
1. Remove `.m` and `.h` file references from `project.pbxproj`
2. Do NOT delete the files from disk
3. Add new `.swift` files to `project.pbxproj`
4. Remove bridging headers (SalesforceSDKCore, MobileSync) from project — delete the bridging header files since they import non-existent ObjC production headers

---

## Pre-flight Validation

Before starting batch 01, the orchestrator must verify the environment is in a known-good state. Pre-flight is orchestrator work.

1. **Production library conversion is complete** — verify that `production-swift-conversion-plan.md` shows all 5 library operator gates approved (Phases 1–5, batches 01–46 all `[✓]`). Phase 6 (MobileSyncExplorer sample app) is not required — it doesn't affect the SDK libraries that tests import. If any library gate is not approved, stop — this plan cannot run until the library conversion is done.
2. **Production builds are green** — build all 5 library schemes to confirm the production Swift code compiles: `xcodebuild build -scheme SCHEME -destination "$SIMULATOR_DEST" CODE_SIGNING_ALLOWED=NO`. If any fail, stop.
3. **Git working tree is clean** — `git status` shows no uncommitted changes except plan files. If there are uncommitted changes, stop and ask the operator.
4. **Create the feature branch from the production branch** — the test branch must be based on the completed production conversion, not on `dev` before it. Use: `git checkout feature/objc-to-swift-production-migration && git checkout -b feature/objc-to-swift-test-migration` (or verify it already exists and includes the production conversion commits).
5. **Simulator destination is valid** — `xcrun simctl list devices available | grep -i iphone`. Record:
   ```
   SIMULATOR_DEST="platform=iOS Simulator,name=iPhone 17 Pro Max,OS=latest"
   ```
6. **Tests pass at baseline** — run tests for each library scheme. Record counts in Baseline Test Results table. Any pre-existing failures are documented (not attributed to test conversion).
7. **Production artifacts available** — verify `prod-conversion-patterns.md` and `prod-conversion-lessons-SalesforceSDKCore.md` exist and are non-empty. These are read-only inputs.
8. **Permissions are configured** — verify `.claude/settings.json` has required permissions.

### Project paths reference
Each library's test target is in the same `.xcodeproj`:
- `libs/SalesforceSDKCommon/SalesforceSDKCommon.xcodeproj/project.pbxproj`
- `libs/SalesforceAnalytics/SalesforceAnalytics.xcodeproj/project.pbxproj`
- `libs/SmartStore/SmartStore.xcodeproj/project.pbxproj`
- `libs/MobileSync/MobileSync.xcodeproj/project.pbxproj`
- `libs/SalesforceSDKCore/SalesforceSDKCore.xcodeproj/project.pbxproj`

---

## Commit Strategy

Same approach as production plan:
- **After pre-flight:** Commit plan file. Message: `"Add test ObjC→Swift conversion plan"`
- **After each library boundary:** Commit all changes. Message: `"Convert LIBRARY test ObjC to Swift (Phase N/5)"`
- **After post-conversion:** Final commit. Message: `"Verify clean build and full test pass after test ObjC→Swift conversion"`

---

## Approach: Incremental Semantic Conversion with Two Learning Loops

### Large file isolation rule
Files over 1,000 lines get their own batch:
- `SalesforceRestAPITests.m` (3,211 lines) — batch 15 (solo)
- `ParentChildrenSyncTests.m` (2,057 lines) — batch 10 (+1 small file)
- `SFSmartStoreTests.m` (1,431 lines) — batch 04 (+1 small file)
- `SyncManagerTests.m` (1,247 lines) — batch 08 (+1 small file)
- `SalesforceSDKManagerTests.m` (1,123 lines) — batch 16 (+1 small file)

### Uncertain API verification rule
When converting a test method call and the correct Swift equivalent is ambiguous, **do not guess**. Instead:
1. **Grep the converted production Swift code** — `grep -rn "methodName" libs/LIBRARY/LIBRARY/Classes/ --include="*.swift"` to find the actual signature
2. Check the **production pattern registry** (`prod-conversion-patterns.md`) for verified mappings
3. Check the **test pattern registry** (`test-conversion-patterns.md`) for test-specific patterns
4. If still ambiguous, check how existing Swift test files call the same method

### Loop 1: Semantic batch learning (per batch)
For each batch:

**Before converting (re-anchor step):**
0. Re-read the conflict map entries for files in this batch and the latest delta notes. For **batch 3+** within a library (or any batch in a Phase 5 track), also re-read the structural rules and import rules.

**Convert:**
1. Read each ObjC file (.h + .m pair)
2. Check for existing Swift test files that test the same class — consult the conflict map
3. **Grep the converted production Swift code** to find current method signatures (do not rely on the seed rule mapping table alone — the production conversion is the source of truth)
4. Convert semantically to idiomatic Swift. Only write files listed in the scope fence.

**Record:**
5. Append delta notes to `test-conversion-lessons-delta-LIBRARY.md`
6. Update Batch Progress Tracker (mark `[✓]`)
7. Log status summary
8. Continue to next batch

### Loop 2: Build, test, and learn (per library boundary)

**Verification gate (orchestrator):**
0. Orchestrator receives manifest, runs verification checklist. If fails, sends back to agent.

**Library boundary build:**
1. Retain original .m/.h on disk; remove from `project.pbxproj`
2. Remove bridging headers (MobileSync, SalesforceSDKCore) if present in this library
3. Update Xcode project — remove .m/.h references, add .swift files
4. Build the test target: `xcodebuild build -scheme LIBRARYTestApp -destination "$SIMULATOR_DEST" CODE_SIGNING_ALLOWED=NO`
5. Assess build errors against escalation thresholds
6. Verify existing Swift test files compile as-is (per conflict map)
7. Run tests: `xcodebuild test -scheme LIBRARY -destination "$SIMULATOR_DEST"`
8. Assess test failures against escalation thresholds. Fix test conversion bugs (tests adapt to production, never the reverse).
9. Update pattern registry — mark provisional patterns as verified
10. Write cumulative lessons file
11. Draft rule addenda for next phase
12. Perform plan self-review
13. Update Batch Progress Tracker
14. Generate operator review report (Phase 5 only — Phases 1–4 are fully autonomous)
15. Commit the library conversion
16. Continue to next library (Phases 1–4) or stop for operator review (Phase 5)

### Pattern registry
Same structure as production plan: `test-conversion-patterns.md` with ObjC pattern → Swift pattern → rule → discovered → verified columns. Agents also read the production pattern registry (`prod-conversion-patterns.md`) for API mappings.

### Rule injection and accuracy briefing
Same as production plan: rule addenda accumulate across phases, accuracy briefing focuses attention on high-risk patterns.

### Plan self-review at library boundaries
Same checklist as production plan: accuracy check, efficiency check, rule updates, pattern registry updates. Draft rule addenda for next phase.

---

## Seed Conversion Rules

### Structural rules
1. **Imports:** Replace `#import` with `@testable import ModuleName` (for the library under test) and `import XCTest`
2. **Class structure:** `@interface Foo : XCTestCase` → `class Foo: XCTestCase`
3. **Test methods:** `- (void)testFoo` → `func testFoo()`; async tests → `func testFoo() async throws`
4. **setUp/tearDown:** `override func setUp()` / `override func tearDown()` or async variants
5. **Assertions:** `XCTAssertTrue`, `XCTAssertEqual`, etc. — nearly identical syntax, drop semicolons
6. **Properties:** `@property` → `var`/`let` with appropriate types and optionality
7. **Blocks → Closures:** ObjC block syntax → Swift closure syntax
8. **NSError → throws:** Test helper methods with `NSError **` → `throws`
9. **Nullability → Optionality:** Default optional unless `nonnull`/`NS_ASSUME_NONNULL`
10. **Typedefs:** Block typedefs → Swift `typealias`
11. **`#pragma mark` → `// MARK:`**

### Production API reference rules
12. **Do not use static mapping tables.** The production code has been converted to Swift — grep the actual `.swift` files for current signatures. The production pattern registry (`prod-conversion-patterns.md`) has verified mappings.
13. **Module imports replace header imports.** `#import "SFSmartStore.h"` → `@testable import SmartStore`. `#import <SalesforceSDKCore/SalesforceSDKCore.h>` → `@testable import SalesforceSDKCore`.
14. **Bridging headers are removed.** Any test code that relied on bridging header imports must use Swift module imports. `#import "SFSDKAuthRequest.h"` in a bridging header → `@testable import SalesforceSDKCore` in the Swift test file.

### Language-forced changes
15. **`+initialize`:** Same as production rule 19 — convert to `static let`/`static var`
16. **`+load`:** Same as production rule 20
17. **ObjC associated objects:** Same as production rule 21

### Existing Swift test file rules
18. **Naming conflicts — use `Legacy` suffix.** Two known conflicts: `ScreenLockManagerTests.m` → `ScreenLockManagerLegacyTests.swift`, `SFOAuthCoordinatorTests.m` → `SFOAuthCoordinatorLegacyTests.swift`. Both existing Swift files stay.
19. **Existing Swift test files — leave as-is.** Do not modify or merge. See conflict map.
20. **Pure-Swift test files — do not touch.** Files like `BootconfigTests.swift`, `RestClientPublisherTests.swift` are left untouched.
21. **Mock/utility Swift files — do not touch.** `MockNavigationAction.swift`, `MockRestClient.swift` are left untouched.

### Pre-conversion conflict map

**SalesforceSDKCommon:**
| Existing Swift test file | Action |
|---|---|
| `KeychainHelperTests.swift` | Leave as-is. Pure Swift test. |
| `SecItemOperationsTests.swift` | Leave as-is. Pure Swift test. |
| `ContentView.swift` (TestApp) | Leave as-is. TestApp is already Swift. |
| `SalesforceSDKCommonTestApp.swift` (TestApp) | Leave as-is. TestApp is already Swift. |

**SalesforceAnalytics:** No existing Swift test files.

**SmartStore:**
| Existing Swift test file | Action |
|---|---|
| `SmartStoreTests.swift` | Leave as-is. Tests different functionality than ObjC `SFSmartStoreTests.m`. |

**MobileSync:**
| Existing Swift test file | Action |
|---|---|
| `BriefcaseSyncDownTests.swift` | Leave as-is. Pure Swift test, no ObjC counterpart. |

**SalesforceSDKCore:**
| Existing Swift test file | Action |
|---|---|
| `ScreenLockManagerTests.swift` | Leave as-is. **NAMING CONFLICT** — ObjC `ScreenLockManagerTests.m` → `ScreenLockManagerLegacyTests.swift` |
| `SFOAuthCoordinatorTests.swift` | Leave as-is. **NAMING CONFLICT** — ObjC `SFOAuthCoordinatorTests.m` → `SFOAuthCoordinatorLegacyTests.swift` |
| `MockNavigationAction.swift` (Mocks/) | Leave as-is. Mock utility. |
| `MockRestClient.swift` (Mocks/) | Leave as-is. Mock utility. |
| All other 26 Swift test files | Leave as-is. Pure Swift tests, no ObjC counterparts. |

### Orphaned test utils in SalesforceSDKCore
The 4 test utility files in `Classes/Test/` (`SFSDKAsyncProcessListener.m`, `SFSDKTestCredentialsData.m`, `SFSDKTestRequestListener.m`, `TestSetupUtils.m`) were converted to Swift by the production plan (they're in the production source tree). If the production conversion handled them, they are already Swift and don't need re-conversion here. If they were excluded from the production plan, they must be converted here and added to the test target in the Xcode project. **Check during pre-flight** whether these files are already Swift.

---

## Execution Timing

| Milestone | Timestamp | Wall-Clock Elapsed |
|-----------|-----------|-------------------|
| Plan execution started | | |
| Pre-flight validation complete | | |
| Baseline test results recorded | | |
| Phase 1 (SalesforceSDKCommon) — conversion started | | |
| Phase 1 — library boundary complete | | |
| Phase 2 (SalesforceAnalytics) — conversion started | | |
| Phase 2 — library boundary complete | | |
| Phase 3 (SmartStore) — conversion started | | |
| Phase 3 — library boundary complete | | |
| Phase 4 (MobileSync) — conversion started | | |
| Phase 4 — library boundary complete | | |
| Phase 5 (SalesforceSDKCore) — conversion started | | |
| Phase 5 — library boundary complete | | |
| 🔶 Operator Gate — report generated, awaiting review | | |
| 🔶 Operator Gate — approved, proceeding | | |
| Post-conversion (clean build + full test run) started | | |
| Plan execution finished | | |
| **Total wall-clock time** | | |
| **Total operator wait time** | | |

### Baseline Test Results (pre-flight)

| Library Scheme | Pass | Fail | Skip | Notes |
|----------------|------|------|------|-------|
| SalesforceSDKCommon | | | | |
| SalesforceAnalytics | | | | |
| SmartStore | | | | |
| MobileSync | | | | |
| SalesforceSDKCore | | | | |

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
| Post-conversion clean build | |
| Post-conversion full test run | |
| **Total build/test idle time** | |

## Unanticipated Issues Log

| # | Phase | Batch/Step | Issue | Resolution | Time Spent |
|---|-------|-----------|-------|------------|------------|
| | | | | | |

---

## Batch Progress Tracker

98 files across 24 batches (large files 1000+ lines get their own or near-solo batches).
5 library boundaries → 5 build passes with lessons files.

Status key: `[ ]` = pending, `[→]` = in progress, `[✓]` = complete

### Phase 1: SalesforceSDKCommon (4 files → 1 batch, 1 build)
Existing Swift tests: 2 files (KeychainHelperTests, SecItemOperationsTests). TestApp is already Swift.

| Batch | Files | Status |
|-------|-------|--------|
| 01 | `SFLoggerTests.m`, `SFSDKSafeMutableArrayTests.m`, `SFSDKSafeMutableDictionaryTests.m`, `SFSDKSafeMutableSetTests.m` | [ ] |

**Library boundary after batch 01:**
- Retain .m/.h originals on disk; remove from Xcode project only
- Update Xcode project
- Build: `xcodebuild build -scheme SalesforceSDKCommonTestApp -destination "$SIMULATOR_DEST" CODE_SIGNING_ALLOWED=NO`
- Test: `xcodebuild test -scheme SalesforceSDKCommon -destination "$SIMULATOR_DEST"`
- Lessons files: `test-conversion-lessons-delta-SalesforceSDKCommon.md`, `test-conversion-lessons-SalesforceSDKCommon.md`

### Phase 2: SalesforceAnalytics (6 files → 1 batch, 1 build)
Existing Swift tests: 0 files

| Batch | Files | Status |
|-------|-------|--------|
| 02 | `AppDelegate.m` (TestApp), `main.m` (TestApp), `ViewController.m` (TestApp), `AnalyticsTestUtil.m`, `EventStoreManagerTests.m`, `InstrumentationEventBuilderTests.m` | [ ] |

**Library boundary after batch 02:**
- Retain .m/.h originals on disk; remove from Xcode project only
- Update Xcode project
- Build: `xcodebuild build -scheme SalesforceAnalyticsTestApp -destination "$SIMULATOR_DEST" CODE_SIGNING_ALLOWED=NO`
- Test: `xcodebuild test -scheme SalesforceAnalytics -destination "$SIMULATOR_DEST"`
- Lessons files

### Phase 3: SmartStore (15 files → 4 batches, 1 build)
Existing Swift tests: 1 file (SmartStoreTests.swift)

| Batch | Files | Status |
|-------|-------|--------|
| 03 | `AppDelegate.m` (TestApp), `main.m` (TestApp), `ViewController.m` (TestApp), `SFSmartStoreTestCase.m` (base class) | [ ] |
| 04 | `SFSmartStoreTests.m` (1,431 lines — solo large file), `SFQuerySpecTests.m` | [ ] |
| 05 | `SFSmartSqlTests.m`, `SFSmartSqlCacheTests.m`, `SFSmartStoreAlterTests.m`, `SFSmartStoreFullTextSearchTests.m`, `SFSmartStoreFullTextSearchSpeedTests.m` | [ ] |
| 06 | `SFSmartStoreLoadTests.m`, `SFMultipleSmartStoresTests.m`, `SFSDKStoreConfigTests.m`, `SmartStoreSDKManagerTests.m` | [ ] |

**Library boundary after batch 06:**
- Retain .m/.h originals on disk; remove from Xcode project only
- Verify existing `SmartStoreTests.swift` compiles as-is (per conflict map)
- Update Xcode project
- Build: `xcodebuild build -scheme SmartStoreTestApp -destination "$SIMULATOR_DEST" CODE_SIGNING_ALLOWED=NO`
- Test: `xcodebuild test -scheme SmartStore -destination "$SIMULATOR_DEST"`
- Lessons files

### Phase 4: MobileSync (17 files → 5 batches, 1 build)
Existing Swift tests: 1 file (BriefcaseSyncDownTests.swift)

| Batch | Files | Status |
|-------|-------|--------|
| 07 | `AppDelegate.m` (TestApp), `main.m` (TestApp), `ViewController.m` (TestApp), `SFSyncUpdateCallbackQueue.m`, `SyncManagerTestCase.m` (base class) | [ ] |
| 08 | `SyncManagerTests.m` (1,247 lines — solo large file), `SyncStateTests.m` | [ ] |
| 09 | `TestSyncDownTarget.m`, `TestSyncUpTarget.m`, `SyncUpTargetTests.m`, `BatchSyncUpTests.m`, `CollectionSyncUpTargetTests.m` | [ ] |
| 10 | `ParentChildrenSyncTests.m` (2,057 lines — solo large file), `SFLayoutSyncManagerTests.m` | [ ] |
| 11 | `SFMetadataSyncManagerTests.m`, `SFSDKSoqlMutatorTests.m`, `SFSDKSyncsConfigTests.m` | [ ] |

**Library boundary after batch 11:**
- Retain .m/.h originals on disk; remove from Xcode project only
- Remove `MobileSyncTests-Bridging-Header.h` from project
- Verify existing `BriefcaseSyncDownTests.swift` compiles as-is
- Update Xcode project
- Build: `xcodebuild build -scheme MobileSyncTestApp -destination "$SIMULATOR_DEST" CODE_SIGNING_ALLOWED=NO`
- Test: `xcodebuild test -scheme MobileSync -destination "$SIMULATOR_DEST"`
- Lessons files

### Phase 5: SalesforceSDKCore (56 files → 13 batches, 1 build)
Existing Swift tests: 30 files (see conflict map). 2 naming conflicts (Legacy suffix).

#### Phase 5 parallel execution model

13 batches organized into 4 parallel tracks with scout-then-parallel execution.

| Track | Batches | Files | Description |
|-------|---------|-------|-------------|
| A | 12–14 | 15 | Test utils, TestApp, delegates, helpers |
| B | 15–16 | 3 | Large test files (SalesforceRestAPITests, SalesforceSDKManagerTests) |
| C | 17–20 | 19 | OAuth, identity, security, credentials tests |
| D | 21–24 | 19 | IDP commands, URL handlers, user accounts, UI tests |

**Scout batches (sequential):** 12, 15, 17, 21 (one from each track)
**Parallel batches:** 13–14, 16, 18–20, 22–24

| Batch | Files | Status |
|-------|-------|--------|
| 12 | `SFSDKAsyncProcessListener.m` (Test util), `SFSDKTestCredentialsData.m` (Test util), `SFSDKTestRequestListener.m` (Test util), `TestSetupUtils.m` (Test util), `AppDelegate.m` (TestApp) — **Track A** | [ ] |
| 13 | `main.m` (TestApp), `ViewController.m` (TestApp), `SalesforceOAuthUnitTestsCoordinatorDelegate.m`, `SFOAuthTestFlowCoordinatorDelegate.m`, `SFCryptoStreamTestUtils.m` — **Track A** | [ ] |
| 14 | `SFSDKLogoutBlocker.m`, `SFSDKPushNotificationDataProvider.m`, `SFTestSDKManagerFlow.m`, `SFUserAccountPersisterEphemeral.m`, `NSString+SFAdditionsTests.m` — **Track A** | [ ] |
| 15 | `SalesforceRestAPITests.m` (3,211 lines — solo) — **Track B** | [ ] |
| 16 | `SalesforceSDKManagerTests.m` (1,123 lines), `NSURL+SFStringUtilsTests.m` — **Track B** | [ ] |
| 17 | `SalesforceOAuthUnitTests.m`, `SalesforceSDKIdentityTests.m`, `ScreenLockManagerTests.m` (**→ Legacy suffix**), `SDKCommonNSDataTests.m` — **Track C** | [ ] |
| 18 | `SDSDKAlertMessageTest.m`, `SFEncryptionKeyTests.m`, `SFManagedPreferencesTest.m`, `SFNetworkTests.m`, `SFOAuthCoordinatorTests.m` (**→ Legacy suffix**) — **Track C** | [ ] |
| 19 | `SFOAuthCredentialsTests.m`, `SFOAuthInfoTests.m`, `SFOAuthSessionRefresherTests.m`, `SFPreferencesTests.m`, `SFPushNotificationManagerTests.m` — **Track C** | [ ] |
| 20 | `SFRestAPIDataTaskRaceTests.m`, `SFSDKAppFeatureMarkersTests.m`, `SFSDKAuthConfigUtilTests.m`, `SFSDKAuthErrorCommandTest.m`, `SFSDKAuthRequestCommandTest.m` — **Track C** | [ ] |
| 21 | `SFSDKCryptoUtilsTests.m`, `SFSDKEncryptedPushNotificationTests.m`, `SFSDKErrorManagerTests.m`, `SFSDKIDPAuthCodeLoginRequestCommandTest.m`, `SFSDKIDPLoginRequestCommandTest.m` — **Track D** | [ ] |
| 22 | `SFSDKKeyValueEncryptedFileStoreTests.m`, `SFSDKLoginHostTests.m`, `SFSDKOAuthTokenEndpointResponseTests.m`, `SFSDKSalesforceAnalyticsManagerTests.m`, `SFSDKSPLoginResponseCommandTest.m` — **Track D** | [ ] |
| 23 | `SFSDKURLCacheTests.m`, `SFSDKURLHandlerManagerTest.m`, `SFSDKWindowManagerTests.m`, `SFUserAccountManagerNotificationsTests.m`, `SFUserAccountManagerPersisterTests.m` — **Track D** | [ ] |
| 24 | `SFUserAccountManagerTests.m`, `SFUserAccountPhotoTests.m`, `SFUserIdUpgradeTests.m`, `UIColor+SFColorsTests.m` — **Track D** | [ ] |

**Library boundary after batch 24:**
- Retain .m/.h originals on disk; remove from Xcode project only
- Remove `SalesforceSDKCoreTests-Bridging-Header.h` from project
- Verify existing 30 Swift test files compile as-is (per conflict map)
- Update Xcode project
- Build: `xcodebuild build -scheme SalesforceSDKCoreTestApp -destination "$SIMULATOR_DEST" CODE_SIGNING_ALLOWED=NO`
- Test: `xcodebuild test -scheme SalesforceSDKCore -destination "$SIMULATOR_DEST"`
- Lessons files
- **🔶 OPERATOR GATE** — generate review report, stop, wait for proceed/adjust/stop decision

---

## Learning Flow Diagram

```
Batches 01 (semantic, autonomous)
  → deltas → test-conversion-lessons-delta-SalesforceSDKCommon.md
  ↓
Library boundary: build + test + self-review → test-conversion-lessons-SalesforceSDKCommon.md
  ↓ (cumulative lessons feed into next phase)
Batch 02 (semantic, autonomous)
  → deltas → test-conversion-lessons-delta-SalesforceAnalytics.md
  ↓
Library boundary: build + test + self-review → test-conversion-lessons-SalesforceAnalytics.md
  ↓
Batches 03–06 (semantic, autonomous)
  → deltas → test-conversion-lessons-delta-SmartStore.md
  ↓
Library boundary: build + test + self-review → test-conversion-lessons-SmartStore.md
  ↓
Batches 07–11 (semantic, autonomous)
  → deltas → test-conversion-lessons-delta-MobileSync.md
  ↓
Library boundary: build + test + self-review → test-conversion-lessons-MobileSync.md
  ↓
Phase 5 — scout-then-parallel:
  Scout batches (sequential): 12, 15, 17, 21 → scout addenda + registry update
  ↓
  Parallel tracks (remaining batches):
    Track A (13–14) → test-conversion-lessons-delta-SalesforceSDKCore-trackA.md
    Track B (16) → test-conversion-lessons-delta-SalesforceSDKCore-trackB.md
    Track C (18–20) → test-conversion-lessons-delta-SalesforceSDKCore-trackC.md
    Track D (22–24) → test-conversion-lessons-delta-SalesforceSDKCore-trackD.md
  ↓ (all tracks complete)
Merge deltas → library boundary: build + test + self-review
  → test-conversion-lessons-SalesforceSDKCore.md
  ↓
🔶 OPERATOR GATE — review report → proceed / adjust / stop
  ↓
Post-conversion: clean build all, full test run, commit
```

---

## Post-Conversion Steps

1. **Clean build all test targets** sequentially with `CODE_SIGNING_ALLOWED=NO`
2. **Run all test suites** — compare against Baseline Test Results. Any new failures are conversion regressions.
3. **Verify audit artifacts** — `find libs -path "*Test*" -name "*.m" | wc -l` (should equal 98) and verify none appear in build phases.
4. **Final commit** — `"Verify clean build and full test pass after test ObjC→Swift conversion"`
5. **Push** to `feature/objc-to-swift-test-migration`
6. **(Future)** Remove original .m/.h test files in a dedicated cleanup commit after audit verification

---

## File Counts

| Phase | Library | ObjC .m Files | Existing Swift Tests | Batches | Build Pass |
|-------|---------|--------------|---------------------|---------|------------|
| 1 | SalesforceSDKCommon | 4 | 2 | 1 (01) | After batch 01 |
| 2 | SalesforceAnalytics | 6 | 0 | 1 (02) | After batch 02 |
| 3 | SmartStore | 15 | 1 | 4 (03–06) | After batch 06 |
| 4 | MobileSync | 17 | 1 | 5 (07–11) | After batch 11 |
| 5 | SalesforceSDKCore | 56 | 30 | 13 (12–24) | After batch 24 |
| **Total** | | **98** | **34** | **24 batches** | **5 builds** |

## Lessons Files Summary

| Type | Count | Naming Convention | Purpose |
|------|-------|-------------------|---------|
| Cumulative (per library) | 5 | `test-conversion-lessons-LIBRARY.md` | Full knowledge through this library (includes rule addenda) |
| Delta (Phases 1–4) | 4 | `test-conversion-lessons-delta-LIBRARY.md` | Batch-level observations |
| Delta (Phase 5 scouts) | 4 | `test-conversion-lessons-delta-SalesforceSDKCore-scoutX.md` | Scout batch observations |
| Delta (Phase 5 tracks) | 4 | `test-conversion-lessons-delta-SalesforceSDKCore-trackX.md` | Per-track observations |
| Pattern registry (test) | 1 | `test-conversion-patterns.md` | Test-specific verified patterns |
| Pattern registry (production, read-only) | 1 | `prod-conversion-patterns.md` | Production API mappings (input) |
| **Total** | **19** | | |
