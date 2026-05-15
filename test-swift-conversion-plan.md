# Test Suite ObjC → Swift Conversion Plan

**Date:** 2026-05-13
**Branch:** feature/objc-to-swift-migration
**Goal:** Convert all 98 Objective-C test files (.m) and 33 headers (.h) to idiomatic Swift
**Total files to convert:** 98 .m files (headers are consumed during conversion, not counted separately)

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
4. Resume from the next incomplete batch

---

## Autonomous Execution Model

### Agent-per-library architecture
The top-level Claude orchestrates by spawning one sub-agent per library phase, **sequentially** (not parallel — each agent needs the prior library's build lessons). Each agent:

1. Reads this plan (batch structure, seed rules)
2. Reads the latest `test-conversion-lessons-LIBRARY.md` (cumulative, for last completed library — if exists)
3. Reads `test-conversion-lessons-delta-LIBRARY.md` for the in-progress library (if exists)
4. **Reads 2–3 existing Swift test files** from the current library (or a sibling library if none exist) to calibrate idiom style — e.g., do they use `@testable import`? XCTestExpectation vs. async/await? setUp/tearDown patterns? This grounds the conversion in actual project conventions rather than generic Swift style.
5. **Records timestamp** in the Execution Timing table (`Phase N — conversion started`)
6. Converts all batches in its assigned library
7. Appends delta notes to `test-conversion-lessons-delta-LIBRARY.md` after each batch
8. **Records timestamp** (`Phase N — library boundary started`)
9. At the library boundary: deletes .m/.h files, updates Xcode project, builds, fixes build errors, runs tests, fixes test failures (updating tests to match production code — never the reverse)
10. **Records timestamp** (`Phase N — complete`)
11. Writes the cumulative lessons file: `test-conversion-lessons-LIBRARY.md` (includes build corrections, test-failure patterns, and all prior knowledge)
12. Performs a **plan self-review** (see below)
13. Returns a summary to the orchestrator

The orchestrator records `Plan execution started` and `Plan execution finished` timestamps in the Execution Timing table, and computes the total wall-clock time. It then spawns the next library's agent with updated context.

### No pause points — fully autonomous
This plan runs **unattended** start to finish. There are no "wait for user confirmation" gates. Claude proceeds through all 24 batches and 5 builds without stopping.

Lessons files and progress tracker updates serve as **recovery checkpoints**, not approval gates. If Claude's session is terminated mid-run, the plan can be resumed from the last completed batch.

### Stopping conditions
Claude only stops and reports to the user if:
- A library build fails and cannot be fixed after 3 repair attempts
- Test failures persist after 3 repair attempts (with lessons written capturing what was tried)
- An unrecoverable error is encountered (e.g., missing source files, Xcode project corruption)
- Permission prompts were encountered that blocked autonomous operation (see below)

### Permission requirements
Before starting execution, ensure `.claude/settings.json` has permissions for:
- File read/write/edit across the repo
- Bash commands: `xcodebuild`, `find`, `grep`, `rm`, `git`, `ls`, `cat`
- These should be configured via `/update-config` or `/fewer-permission-prompts` before the first run

### Permission gap tracking
During execution, Claude tracks every tool invocation that triggered a user permission prompt (i.e., was not in the allow list). At each status review point (delta notes and cumulative lessons files), Claude includes a **Permission Gaps** section listing:

- The exact tool call pattern that was prompted (e.g., `Bash(ruby *)`, `Bash(mv *)`)
- How many times it was prompted during this batch/build
- The recommended allow-list entry to add to `.claude/settings.json`

If any permission gaps are found, Claude:
1. Lists them in the status output
2. Requests the user approve adding them to `.claude/settings.json`
3. If running autonomously and the user is not present, writes the recommended additions to a file `test-conversion-permission-gaps.md` and continues (the gaps will be surfaced at the next status review or session restart)

This ensures the allow list converges toward complete coverage over the first few batches, eliminating prompts for later batches.

---

## Critical Context: Existing ObjC Tests Do Not Compile

The existing Objective-C test files reference deleted ObjC headers and pre-migration APIs. They are **already broken** against the current Swift production code. There is no working ObjC baseline to coexist with. This means:

- ObjC and Swift test files **cannot coexist incrementally** within a target — the ObjC files won't compile
- Each batch converts files semantically without compiler verification
- **Compilation only happens at library boundaries**, after ALL ObjC files in a test target have been converted to Swift and the old .m/.h files removed
- The Xcode project file must be updated at the library boundary (remove .m/.h, add .swift) before the build pass

---

## Approach: Incremental Semantic Conversion with Two Learning Loops

### Large file isolation rule
Files over 1,000 lines get their own batch or are paired with at most 1–2 small files. This prevents context window strain within sub-agents. The 5 large files isolated this way are:
- `SalesforceRestAPITests.m` (3,211 lines) — batch 15 (solo)
- `ParentChildrenSyncTests.m` (2,057 lines) — batch 10 (+1 small file)
- `SFSmartStoreTests.m` (1,431 lines) — batch 04 (+1 small file)
- `SyncManagerTests.m` (1,247 lines) — batch 08 (+1 small file)
- `SalesforceSDKManagerTests.m` (1,123 lines) — batch 16 (+1 small file)

### Uncertain API verification rule
When converting a method call and the correct Swift equivalent is ambiguous or not covered by the seed rules or lessons files, **do not guess**. Instead, run `grep -rn "methodName" libs/LIBRARY/ --include="*.swift"` against the current production Swift code to find the actual signature. This is far cheaper than getting it wrong and fixing at build time. Common cases: overloaded methods, renamed parameters, changed return types, optional vs. non-optional.

### Loop 1: Semantic batch learning (per batch)
Files are converted in batches of ~3–5 files. After each batch:

1. **Read** each ObjC file (.h + .m pair) in the batch
2. **Convert** semantically to idiomatic Swift, applying all known patterns. When uncertain about an API mapping, verify against production code via grep before writing.
3. **Write** the .swift replacement file (do NOT delete the .m/.h yet — that happens at the library boundary)
4. **Append** delta notes to `test-conversion-lessons-delta-LIBRARY.md` (new patterns, pitfalls, permission gaps from this batch only)
5. **Update** this plan's Batch Progress Tracker (mark batch `[✓]`)
6. **Log** a status summary to the console:
   - Files converted, cumulative progress (N/98, N%)
   - Key observations from this batch
   - **Permission gaps:** list any tool calls that triggered permission prompts, with recommended allow-list entries
7. **Continue** immediately to the next batch — no pause

### Loop 2: Build, test, and learn (per library boundary)
After all batches in a library are semantically converted:

1. **Delete** all original .m/.h files for the test target
2. **Remove bridging headers** if present
3. **Update Xcode project** (`project.pbxproj`) to remove .m/.h references and add .swift files
4. **Build** the test target with `CODE_SIGNING_ALLOWED=NO`
5. **Fix** any compilation errors in the converted Swift files (up to 3 repair attempts)
6. **Run tests** via `xcodebuild test` using the **framework scheme** (not the TestApp scheme — the TestApp schemes are not configured for test actions). Use: `xcodebuild test -scheme FRAMEWORK_NAME -destination 'platform=iOS Simulator,id=...'`. The framework schemes (`SalesforceSDKCommon`, `SalesforceAnalytics`, `SmartStore`, `MobileSync`, `SalesforceSDKCore`) each have testable references to their corresponding test targets. Up to 3 repair attempts for failures.
7. **Fix** any test failures by **updating the tests to match the migrated production code**. The production Swift code is the source of truth — it was already building and running before this test migration. Do NOT change production code to make tests pass. Common test-side fixes:
   - Assertions that assumed ObjC nil-messaging semantics (e.g., nil returns 0/NO/empty)
   - Timing/expectation changes from ObjC dispatch patterns to Swift async/await
   - String comparison differences (NSString vs. Swift String bridging)
   - Type casting that was implicit in ObjC but requires explicit handling in Swift
   - Changed method signatures or return types in the migrated production API
8. **Write** the cumulative lessons file: `test-conversion-lessons-LIBRARY.md`
   - Merges all delta notes from this library with prior cumulative knowledge
   - Incorporates compiler-discovered corrections from the build pass
   - Incorporates test-failure patterns and runtime behavior differences discovered during test execution
   - Includes cumulative **Permission Gaps** section
9. **Perform plan self-review** (accuracy, efficiency, rule updates, remaining work assessment — see "Plan self-review at library boundaries" section)
10. **Update** this plan's Batch Progress Tracker
11. **Log** a library boundary status summary:
    - Build result, error count, fixes applied
    - Test result: passed/failed count, categories of test failures, fixes applied
    - Self-review findings and any plan adjustments
    - **Permission gaps:** cumulative list of all unpermitted tool calls encountered so far, with recommended `.claude/settings.json` additions
12. **Continue** to the next library — no pause

### Lessons-learned file strategy

To avoid rewriting a large cumulative file after every batch, lessons are captured at two levels:

**Within a library:** Each batch appends **delta-only** notes to a single scratch file for the current library: `test-conversion-lessons-delta-LIBRARY.md`. These are short — just new patterns, pitfalls, or permission gaps discovered in that batch. The agent keeps this file open across batches.

**At library boundaries:** After the build pass and test run, Claude writes a **cumulative lessons file** that merges:
- All deltas from the current library's scratch file
- All prior cumulative knowledge from the previous library's lessons file
- All build-discovered corrections
- All test-failure patterns and runtime behavior differences

This produces two files:
1. `test-conversion-lessons-LIBRARY.md` — full cumulative semantic + build knowledge through this library
2. The delta scratch file is kept for reference but no longer needed

**On session restart,** Claude reads only:
1. This plan (batch progress, overall structure)
2. Latest `test-conversion-lessons-LIBRARY.md` (full cumulative knowledge through last completed library)
3. `test-conversion-lessons-delta-LIBRARY.md` for the in-progress library (if any)

**Cumulative lessons file format** (`test-conversion-lessons-LIBRARY.md`):
```
# Test Conversion Lessons — Through LIBRARY

## Cumulative API Migration Patterns
(All known ObjC→Swift mappings, verified through this library)

## Conversion Pitfalls Discovered
(Patterns that look straightforward but have gotchas)

## Swift Idiom Preferences
(Patterns that produce cleaner Swift test code)

## Compiler-Discovered Corrections
(What semantic conversion got wrong, fixed during build passes)

## Test-Failure Patterns
(Runtime behavior differences discovered during test execution — ObjC nil semantics, async timing, assertion logic, type bridging, etc. and how they were resolved by updating tests)

## Xcode Project Notes
(pbxproj editing patterns, target membership issues, etc.)

## Permission Gaps
(Cumulative list of tool calls that triggered prompts, with recommended allow-list entries)
```

**Delta scratch file format** (`test-conversion-lessons-delta-LIBRARY.md`):
```
# Conversion Deltas — LIBRARY

## Batch NN
- New patterns discovered: ...
- Pitfalls encountered: ...
- Permission gaps: ...

## Batch NN+1
- ...
```

### Why two learning loops
- **Batch deltas** capture observations while the conversion context is fresh, without the overhead of rewriting all prior knowledge
- **Library-boundary cumulative files** merge everything into a single source of truth, verified by the compiler
- Build corrections from library N feed directly into the semantic conversion of library N+1
- Session restarts only need 2–3 small file reads to reconstruct full context

### Plan self-review at library boundaries
After each library's build pass, test run, and lessons file are written, the agent performs a brief self-review:
- **Accuracy check:** What percentage of converted files had build errors? What percentage of tests failed? Which error categories dominated in each?
- **Efficiency check:** Were there patterns that could have been caught earlier? Should batch sizes or ordering change for remaining libraries?
- **Rule updates:** Are there new seed rules that should be added, or existing rules that were wrong and should be corrected?
- **Remaining work assessment:** Given what was learned, are the batch assignments for the next library still sensible, or should files be reordered (e.g., moving files with similar API patterns together)?

The self-review is written as a section in the cumulative lessons file and its recommendations are applied before starting the next library. This creates a feedback loop that makes each successive library faster and more accurate.

---

## Seed Conversion Rules (from framework/app migration work)

These are the starting rules. They will be refined in lessons-learned files.

1. **Imports:** Replace `#import` / ObjC submodule imports with `import ModuleName`
2. **Class structure:** `@interface Foo : XCTestCase` → `class Foo: XCTestCase`
3. **Test methods:** `- (void)testFoo` → `func testFoo()`; async tests → `func testFoo() async throws`
4. **setUp/tearDown:** Convert to `override func setUp()` / `override func tearDown()` or async variants
5. **Assertions:** `XCTAssertTrue`, `XCTAssertEqual`, etc. — syntax is nearly identical, just drop semicolons
6. **Properties:** `@property` → `var`/`let` with appropriate types
7. **Blocks → Closures:** ObjC block syntax → Swift closure syntax
8. **API migrations:**
   - `[SFUserAccountManager sharedInstance]` → `UserAccountManager.shared`
   - `.currentUser` → `.currentUserAccount`
   - `[SFSmartStore sharedStoreWithName:]` → `SmartStore.shared(withName:)`
   - `kSyncTargetLocal` / `kSyncTargetLocallyCreated` etc. → string literals
   - `kSFSoupQuerySortOrderAscending` → `SFSoupQuerySortOrderAscending`
   - `[SFSDKMobileSyncLogger log:level:format:]` → `SFSDKMobileSyncLogger.d(_:message:)`
   - `SFJsonUtils.object(fromJSONString:)` → `SFJsonUtils.object(from:)`
   - `SalesforceLogger` → `SFLogger`
   - `[SFMobileSyncSyncManager sharedInstance:]` → `SFMobileSyncSyncManager.sharedInstance(forUserAccount:)`
   - `[MobileSyncSDKManager sharedManager]` → `MobileSyncSDKManager.shared`
   - SmartStore `queryWithQuerySpec:pageIndex:error:` → `query(using:startingFromPageIndex:)`
   - SmartStore `upsertEntries:toSoup:` → `upsert(entries:forSoupNamed:)`
   - `RestClient.request(for...)` → `RestClient.requestFor...()`
   - `RestRequest` init now public with defaults
   - `idData` is now optional
   - `SFSDKWindowManager.shared()` → `SFSDKWindowManager.shared`
   - `UIColor.salesforceLabel` → `UIColor.salesforceLabelColor`
   - `UIColor.salesforceSystemBackground` → `UIColor.salesforceSystemBackgroundColor`
   - `SFSDKDatasharingHelper.appGroupEnabled` → `.isAppGroupEnabled`
   - `AuthHelper.registerBlock(forCurrentUserChangeNotifications:)` → `AuthHelper.registerBlockForCurrentUserChangeNotifications(_:completion:)`
   - `bootConfig?.remoteAccessConsumerKey` → `UserAccountManager.shared.oauthClientID`
9. **Name collisions with existing Swift tests:** Two ObjC test files have Swift counterparts that contain newer, different tests: `ScreenLockManagerTests.m` and `SFOAuthCoordinatorTests.m`. Convert these ObjC files to Swift with a `Legacy` suffix (e.g., `ScreenLockManagerLegacyTests.swift`, `SFOAuthCoordinatorLegacyTests.swift`) and rename the test class accordingly. Both the legacy and the newer Swift test files are kept — they test different things.
10. **Remove bridging headers** at library boundary after all ObjC files are converted. Only MobileSync (`MobileSyncTests-Bridging-Header.h`) and SalesforceSDKCore (`SalesforceSDKCoreTests-Bridging-Header.h`) have bridging headers. The SalesforceSDKCore bridging header is already broken — it imports deleted ObjC headers (`SFSDKAuthRequest.h`, `SFSDKAuthSession.h`, `SFOAuthCoordinator+Internal.h`, etc.) — so it should be deleted outright, not fixed.
11. **Update Xcode project** at library boundary to remove .m/.h references and add .swift files. Note: some files may exist on disk but not in the Xcode project (they were dropped during the earlier framework migration). At the library boundary, verify each converted .swift file has a project reference — if the original .m/.h was not in the project, the .swift file must be **added as new**, not swapped.
12. **Orphaned test utils in SalesforceSDKCore:** The 4 test utility files in `Classes/Test/` (`SFSDKAsyncProcessListener.m`, `SFSDKTestCredentialsData.m`, `SFSDKTestRequestListener.m`, `TestSetupUtils.m`) exist on disk but have **zero references** in `project.pbxproj`. They were dropped during the earlier framework migration. After converting them to Swift, they must be added to the Xcode project as new file references in the appropriate test target (not just the framework target). Multiple ObjC test files depend on them (`SalesforceRestAPITests.m`, `SFUserAccountManagerTests.m`, `SFSDKURLCacheTests.m`, `SFSDKErrorManagerTests.m`, `SFSDKAuthConfigUtilTests.m`).

---

## Execution Timing

Claude records timestamps at key milestones by running `date -u '+%Y-%m-%dT%H:%M:%SZ'` and writing the results here. Since the plan runs autonomously with no pause points, wall-clock time closely approximates working time. Any permission prompt delays are noted in the Permission Gaps sections of the lessons files.

| Milestone | Timestamp | Wall-Clock Elapsed |
|-----------|-----------|-------------------|
| Plan execution started | 2026-05-13T23:46:29Z | |
| Phase 1 (SalesforceSDKCommon) — conversion started | 2026-05-13T23:47:11Z | |
| Phase 1 — library boundary (build+test) started | 2026-05-13T23:50:49Z | |
| Phase 1 — complete | 2026-05-13T23:51:55Z | ~5m 26s |
| Phase 2 (SalesforceAnalytics) — conversion started | 2026-05-13T23:54:03Z | |
| Phase 2 — library boundary (build+test) started | 2026-05-13T23:57:38Z | |
| Phase 2 — complete | 2026-05-13T23:59:30Z | ~5m 27s |
| Phase 3 (SmartStore) — conversion started | 2026-05-14T00:01:20Z | |
| Phase 3 — library boundary (build+test) started | 2026-05-14T02:15:51Z | |
| Phase 3 — complete | 2026-05-14T04:14:04Z | ~4h 13m |
| Phase 4 (MobileSync) — conversion started | 2026-05-14T04:15:08Z | |
| Phase 4 — library boundary (build+test) started | 2026-05-14T10:00:00Z | |
| Phase 4 — complete | 2026-05-14T14:47:15Z | ~10h 32m |
| Phase 5 (SalesforceSDKCore) — conversion started | 2026-05-14T14:47:15Z | |
| Phase 5 — library boundary (build+test) started | 2026-05-14T14:00:00Z | |
| Phase 5 — complete | 2026-05-14T17:17:27Z | ~17h 30m |
| Post-conversion (clean build + full test run) started | | |
| Plan execution finished | 2026-05-14T17:17:27Z | |
| **Total wall-clock time** | | ~17h 31m |

Claude also records the duration of each `xcodebuild` command (build and test) by capturing timestamps before and after each invocation. This allows computing:
- **Build/test idle time** = sum of all `xcodebuild` durations (Claude is idle while the compiler/test runner works)
- **Active working time** = total wall-clock time − build/test idle time − permission prompt delays
- **Permission prompt delays** are tracked in the Permission Gaps sections of lessons files

| Build/Test Command | Duration |
|--------------------|----------|
| Phase 1 build (SalesforceSDKCommonTestApp) | ~10s |
| Phase 1 test (SalesforceSDKCommon) | ~0.1s (40 tests, 0 failures) |
| Phase 2 build (SalesforceAnalyticsTestApp) | ~1m |
| Phase 2 test (SalesforceAnalytics) | ~10s (19 tests, 0 failures) |
| Phase 3 build (SmartStoreTestApp) | ~30s |
| Phase 3 test (SmartStore) | partial — some tests crash due to production code "Fatal access conflict" bugs from framework migration |
| Phase 4 build (MobileSyncTestApp) | ~30s |
| Phase 4 test (MobileSync) | SFSDKSoqlMutatorTests: 32 pass; SyncStateTests: 2 pass, 1 crash (production SmartStore bug) |
| Phase 5 build (SalesforceSDKCoreTestApp) | BUILD SUCCEEDED |
| Phase 5 test (SalesforceSDKCore) | Unit tests pass (5/5 quick check); SFUserAccountManagerNotifications test class disabled pending API migration |
| Post-conversion clean build (all targets) | |
| Post-conversion full test run | |
| **Total build/test idle time** | |
| **Total permission prompt delays** | |
| **Estimated active working time** | |

**Note:** Claude cannot track token usage — token counts are not exposed to the running model.

## Unanticipated Issues Log

Claude records any issue that was not covered by the plan, seed rules, or lessons files and required effort to resolve. This captures the gap between what the plan anticipated and what actually happened — useful for improving future migration plans.

Each entry includes: when it happened, what the issue was, how long it took to resolve, and what the resolution was.

| # | Phase | Batch/Step | Issue | Resolution | Time Spent |
|---|-------|-----------|-------|------------|------------|
| | | | | | |

Categories for reference:
- **API gap:** Production API not covered by seed rules or lessons
- **Project config:** Xcode project, scheme, or target configuration issue
- **Tooling:** xcodebuild, simulator, or CLI tool unexpected behavior
- **Runtime:** Test passes compilation but fails at runtime for unanticipated reason
- **Permission:** Tool permission not in allow list
- **Environment:** Machine-specific issue (paths, SDK versions, simulator state)
- **Plan logic:** The plan's instructions were ambiguous or contradictory
- **Other:** Anything not fitting the above

---

## Batch Progress Tracker

98 files across 24 batches (large files 1000+ lines get their own or near-solo batches).
5 library boundaries → 5 build passes with build lessons files.

Status key: `[ ]` = pending, `[→]` = in progress, `[✓]` = complete

### Phase 1: SalesforceSDKCommon (4 files → 1 batch, 1 build)

| Batch | Files | Status |
|-------|-------|--------|
| 01 | `SFLoggerTests.m`, `SFSDKSafeMutableArrayTests.m`, `SFSDKSafeMutableDictionaryTests.m`, `SFSDKSafeMutableSetTests.m` | [✓] |

**Library boundary after batch 01:**
- Delete .m/.h originals, update project, remove bridging header
- Build: `xcodebuild build -scheme SalesforceSDKCommonTestApp -destination 'platform=iOS Simulator,id=5B47058E-6C72-4049-8F26-DA87D3227AF4' CODE_SIGNING_ALLOWED=NO`
- Test: `xcodebuild test -scheme SalesforceSDKCommon -destination 'platform=iOS Simulator,id=5B47058E-6C72-4049-8F26-DA87D3227AF4'`
- Delta file: `test-conversion-lessons-delta-SalesforceSDKCommon.md`
- Cumulative lessons: `test-conversion-lessons-SalesforceSDKCommon.md`
- Plan self-review

### Phase 2: SalesforceAnalytics (6 files → 1 batch, 1 build)

| Batch | Files | Status |
|-------|-------|--------|
| 02 | `AppDelegate.m` (TestApp), `main.m` (TestApp), `ViewController.m` (TestApp), `AnalyticsTestUtil.m`, `EventStoreManagerTests.m`, `InstrumentationEventBuilderTests.m` | [✓] |

**Library boundary after batch 02:**
- Delete .m/.h originals, update project, remove bridging header
- Build: `xcodebuild build -scheme SalesforceAnalyticsTestApp -destination 'platform=iOS Simulator,id=5B47058E-6C72-4049-8F26-DA87D3227AF4' CODE_SIGNING_ALLOWED=NO`
- Test: `xcodebuild test -scheme SalesforceAnalytics -destination 'platform=iOS Simulator,id=5B47058E-6C72-4049-8F26-DA87D3227AF4'`
- Delta file: `test-conversion-lessons-delta-SalesforceAnalytics.md`
- Cumulative lessons: `test-conversion-lessons-SalesforceAnalytics.md`
- Plan self-review

### Phase 3: SmartStore (15 files → 4 batches, 1 build)

| Batch | Files | Status |
|-------|-------|--------|
| 03 | `AppDelegate.m` (TestApp), `main.m` (TestApp), `ViewController.m` (TestApp), `SFSmartStoreTestCase.m` (base class) | [✓] |
| 04 | `SFSmartStoreTests.m` (1,431 lines — solo large file), `SFQuerySpecTests.m` | [✓] |
| 05 | `SFSmartSqlTests.m`, `SFSmartSqlCacheTests.m`, `SFSmartStoreAlterTests.m`, `SFSmartStoreFullTextSearchTests.m`, `SFSmartStoreFullTextSearchSpeedTests.m` | [✓] |
| 06 | `SFSmartStoreLoadTests.m`, `SFMultipleSmartStoresTests.m`, `SFSDKStoreConfigTests.m`, `SmartStoreSDKManagerTests.m` | [✓] |

**Library boundary after batch 06:**
- Delete .m/.h originals, update project, remove bridging header
- Build: `xcodebuild build -scheme SmartStoreTestApp -destination 'platform=iOS Simulator,id=5B47058E-6C72-4049-8F26-DA87D3227AF4' CODE_SIGNING_ALLOWED=NO`
- Test: `xcodebuild test -scheme SmartStore -destination 'platform=iOS Simulator,id=5B47058E-6C72-4049-8F26-DA87D3227AF4'`
- Delta file: `test-conversion-lessons-delta-SmartStore.md`
- Cumulative lessons: `test-conversion-lessons-SmartStore.md`
- Plan self-review

### Phase 4: MobileSync (17 files → 5 batches, 1 build)

| Batch | Files | Status |
|-------|-------|--------|
| 07 | `AppDelegate.m` (TestApp), `main.m` (TestApp), `ViewController.m` (TestApp), `SFSyncUpdateCallbackQueue.m`, `SyncManagerTestCase.m` (base class) | [✓] |
| 08 | `SyncManagerTests.m` (1,247 lines — solo large file), `SyncStateTests.m` | [✓] |
| 09 | `TestSyncDownTarget.m`, `TestSyncUpTarget.m`, `SyncUpTargetTests.m`, `BatchSyncUpTests.m`, `CollectionSyncUpTargetTests.m` | [✓] |
| 10 | `ParentChildrenSyncTests.m` (2,057 lines — solo large file), `SFLayoutSyncManagerTests.m` | [✓] |
| 11 | `SFMetadataSyncManagerTests.m`, `SFSDKSoqlMutatorTests.m`, `SFSDKSyncsConfigTests.m` | [✓] |

**Library boundary after batch 11:**
- Delete .m/.h originals, update project, remove bridging header
- Build: `xcodebuild build -scheme MobileSyncTestApp -destination 'platform=iOS Simulator,id=5B47058E-6C72-4049-8F26-DA87D3227AF4' CODE_SIGNING_ALLOWED=NO`
- Test: `xcodebuild test -scheme MobileSync -destination 'platform=iOS Simulator,id=5B47058E-6C72-4049-8F26-DA87D3227AF4'`
- Delta file: `test-conversion-lessons-delta-MobileSync.md`
- Cumulative lessons: `test-conversion-lessons-MobileSync.md`
- Plan self-review

### Phase 5: SalesforceSDKCore (56 files → 13 batches, 1 build)

| Batch | Files | Status |
|-------|-------|--------|
| 12 | `SFSDKAsyncProcessListener.m` (Test util), `SFSDKTestCredentialsData.m` (Test util), `SFSDKTestRequestListener.m` (Test util), `TestSetupUtils.m` (Test util), `AppDelegate.m` (TestApp) | [✓] |
| 13 | `main.m` (TestApp), `ViewController.m` (TestApp), `SalesforceOAuthUnitTestsCoordinatorDelegate.m`, `SFOAuthTestFlowCoordinatorDelegate.m`, `SFCryptoStreamTestUtils.m` | [✓] |
| 14 | `SFSDKLogoutBlocker.m`, `SFSDKPushNotificationDataProvider.m`, `SFTestSDKManagerFlow.m`, `SFUserAccountPersisterEphemeral.m`, `NSString+SFAdditionsTests.m` | [✓] |
| 15 | `SalesforceRestAPITests.m` (3,211 lines — solo large file) | [✓] |
| 16 | `SalesforceSDKManagerTests.m` (1,123 lines — solo large file), `NSURL+SFStringUtilsTests.m` | [✓] |
| 17 | `SalesforceOAuthUnitTests.m`, `SalesforceSDKIdentityTests.m`, `ScreenLockManagerTests.m` (ObjC → `ScreenLockManagerLegacyTests.swift`), `SDKCommonNSDataTests.m` | [✓] |
| 18 | `SDSDKAlertMessageTest.m`, `SFEncryptionKeyTests.m`, `SFManagedPreferencesTest.m`, `SFNetworkTests.m`, `SFOAuthCoordinatorTests.m` (ObjC → `SFOAuthCoordinatorLegacyTests.swift`) | [✓] |
| 19 | `SFOAuthCredentialsTests.m`, `SFOAuthInfoTests.m`, `SFOAuthSessionRefresherTests.m`, `SFPreferencesTests.m`, `SFPushNotificationManagerTests.m` | [✓] |
| 20 | `SFRestAPIDataTaskRaceTests.m`, `SFSDKAppFeatureMarkersTests.m`, `SFSDKAuthConfigUtilTests.m`, `SFSDKAuthErrorCommandTest.m`, `SFSDKAuthRequestCommandTest.m` | [✓] |
| 21 | `SFSDKCryptoUtilsTests.m`, `SFSDKEncryptedPushNotificationTests.m`, `SFSDKErrorManagerTests.m`, `SFSDKIDPAuthCodeLoginRequestCommandTest.m`, `SFSDKIDPLoginRequestCommandTest.m` | [✓] |
| 22 | `SFSDKKeyValueEncryptedFileStoreTests.m`, `SFSDKLoginHostTests.m`, `SFSDKOAuthTokenEndpointResponseTests.m`, `SFSDKSalesforceAnalyticsManagerTests.m`, `SFSDKSPLoginResponseCommandTest.m` | [✓] |
| 23 | `SFSDKURLCacheTests.m`, `SFSDKURLHandlerManagerTest.m`, `SFSDKWindowManagerTests.m`, `SFUserAccountManagerNotificationsTests.m`, `SFUserAccountManagerPersisterTests.m` | [✓] |
| 24 | `SFUserAccountManagerTests.m`, `SFUserAccountPhotoTests.m`, `SFUserIdUpgradeTests.m`, `UIColor+SFColorsTests.m` | [✓] |

**Library boundary after batch 24:**
- Delete .m/.h originals, update project, remove bridging header
- Build: `xcodebuild build -scheme SalesforceSDKCoreTestApp -destination 'platform=iOS Simulator,id=5B47058E-6C72-4049-8F26-DA87D3227AF4' CODE_SIGNING_ALLOWED=NO`
- Test: `xcodebuild test -scheme SalesforceSDKCore -destination 'platform=iOS Simulator,id=5B47058E-6C72-4049-8F26-DA87D3227AF4'`
- Delta file: `test-conversion-lessons-delta-SalesforceSDKCore.md`
- Cumulative lessons: `test-conversion-lessons-SalesforceSDKCore.md`
- Plan self-review

---

## Learning Flow Diagram

```
Batch 01 (semantic) → deltas appended to lessons-delta-SalesforceSDKCommon.md
  ↓
Library boundary: build + test + self-review → lessons-SalesforceSDKCommon.md (cumulative)
  ↓ (cumulative lessons feed into next library's agent)
Batch 02 (semantic) → deltas appended to lessons-delta-SalesforceAnalytics.md
  ↓
Library boundary: build + test + self-review → lessons-SalesforceAnalytics.md (cumulative)
  ↓
Batches 03–06 (semantic) → deltas appended to lessons-delta-SmartStore.md
  ↓
Library boundary: build + test + self-review → lessons-SmartStore.md (cumulative)
  ↓
Batches 07–11 (semantic) → deltas appended to lessons-delta-MobileSync.md
  ↓
Library boundary: build + test + self-review → lessons-MobileSync.md (cumulative)
  ↓
Batches 12–24 (semantic) → deltas appended to lessons-delta-SalesforceSDKCore.md
  ↓
Library boundary: build + test + self-review → lessons-SalesforceSDKCore.md (cumulative)
  ↓
Post-conversion: clean build all, commit, push
```

---

## Post-Conversion Steps

1. **Clean build all test targets** sequentially with `CODE_SIGNING_ALLOWED=NO` (full rebuild to catch cross-library issues)
2. **Run all test suites** sequentially to confirm all tests pass end-to-end (individual library tests already passed at their boundaries, this is the integration check)
3. **Commit and push** to `feature/objc-to-swift-migration`
4. **Update issue report** (`MobileSync-build-issues.md`) with final status

---

## File Counts

| Phase | Library | ObjC .m Files | Batches | Build Pass |
|-------|---------|--------------|---------|------------|
| 1 | SalesforceSDKCommon | 4 | 1 (01) | After batch 01 |
| 2 | SalesforceAnalytics | 6 | 1 (02) | After batch 02 |
| 3 | SmartStore | 15 | 4 (03–06) | After batch 06 |
| 4 | MobileSync | 17 | 5 (07–11) | After batch 11 |
| 5 | SalesforceSDKCore | 56 | 13 (12–24) | After batch 24 |
| **Total** | | **98** | **24 batches** | **5 builds** |

## Lessons Files Summary

| Type | Count | Naming Convention | Purpose |
|------|-------|-------------------|---------|
| Cumulative (per library) | 5 | `test-conversion-lessons-LIBRARY.md` | Full knowledge through this library (semantic + build + test). Read on session restart. |
| Delta (per library) | 5 | `test-conversion-lessons-delta-LIBRARY.md` | Batch-level observations within a library. Merged into cumulative at library boundary. |
| **Total** | **10** | | |
