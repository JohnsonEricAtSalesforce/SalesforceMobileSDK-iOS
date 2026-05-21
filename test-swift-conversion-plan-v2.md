# Test Suite ObjC → Swift Conversion Plan (V2)

**Date:** 2026-05-21
**Branch:** `feature/objc-to-swift-test-migration` (branched from production conversion branch)
**Goal:** Convert all remaining ObjC test files to Swift
**Remaining files:** 27 test files + 12 test app scaffolding = 39 files total (down from original 98 — Phase 5 SDKCore already completed during production cleanup)
**Prerequisite:** Production conversion complete (all 201 production classes are Swift, full-stack BUILD SUCCEEDED)

---

## What's Already Done (from Production Cleanup)

During the production conversion cleanup (Item 6), the following test work was completed:
- **SalesforceSDKCore tests: 100% converted** — all 56 ObjC test files now have Swift equivalents, integrated into project, test target compiles and runs (200 tests, 98 in final stable pass)
- **SalesforceSDKCommon tests: 3 of 4 converted** — SafeMutable* tests converted in Item 4. Only `SFLoggerTests.m` remains.
- **Test app scaffolding:** SDKCore test app has ObjC scaffolding still compiled but functional

**This plan covers only the remaining unconverted test files in 4 libraries.**

---

## Key Differences from V1 Test Plan

| Aspect | V1 Test Plan | V2 Test Plan |
|--------|-------------|-------------|
| Total files | 98 | **27 test + 12 scaffolding = 39** |
| Phase 5 (SDKCore) | 56 files, 13 batches | **Already complete** |
| Parallel execution | Scout-then-parallel Phase 5 | **Sequential only** (no parallelism) |
| Operator gates | 1 (Phase 5 only) | **1 (after all phases)** |
| Boundary approach | Manual pbxproj edits | **Scripted via xcodeproj gem** (per V2 production plan) |
| Build verification | Incremental | **Clean DerivedData at every boundary** |
| NS_SWIFT_NAME handling | Grep production code | **Sed rename script + lookup table** (per V2 production plan) |

---

## Execution Model

Follows the V2 production plan execution model:
- **Sequential agents** (no parallelism)
- **Scripted pbxproj management** (use `scripts/update_project.rb`)
- **Clean DerivedData** at every boundary
- **No ObjC modifications** — all files converted to Swift (per operator rule)
- **Single operator gate** after all phases complete

### Agent scope
Same as V2 production plan. Agents convert, call pbxproj script, fix build errors. Orchestrator verifies and commits.

### Deferral protocol
Same as V2 production plan. If a test file hits an architectural blocker (>30min), defer it with `⚠️ DEFERRED` annotation.

---

## How to Resume After Session Termination

1. Read this plan for batch structure and rules
2. Check batch tracker for last `[✓]` batch
3. Read latest `test-conversion-lessons-delta-LIBRARY.md`
4. If all batches for a library are `[✓]` but no boundary timestamp: re-verify, then spawn boundary agent
5. Continue from next incomplete batch

---

## Pre-flight Validation

1. **Production build green** — all 5 schemes build from clean DerivedData
2. **Git clean** — no uncommitted changes
3. **Branch from production** — `git checkout feature/objc-to-swift-production-migration && git checkout -b feature/objc-to-swift-test-migration`
4. **Simulator valid** — `SIMULATOR_DEST="platform=iOS Simulator,name=iPhone 17 Pro Max,OS=latest"`
5. **Test credentials valid** — `test_credentials.json` has bare hostname for `test_login_domain` (e.g., `login.salesforce.com`, NOT `https://login.salesforce.com`) and valid refresh token. MobileSync integration tests (Phase 4) perform real HTTP requests — they will timeout without valid credentials and network access.
6. **Create scripts if missing:**
   - `scripts/update_project.rb` — pbxproj management (see V2 production plan, Preparation §2). If it doesn't exist, create it using the `xcodeproj` gem with `add_swift_file`, `remove_m_from_compile`, `tombstone_header`, `remove_header_from_phase` operations.
   - `scripts/rename_ns_swift_names.sh` — NS_SWIFT_NAME sed replacements (content defined in V2 production plan, Preparation §3 codebase-specific mappings table).
7. **Baseline tests** — run each scheme's tests, record pass/fail counts
8. **Verify SalesforceSDKCore tests pass** — 98 tests in final pass (confirms Phase 5 is done)

---

## Seed Conversion Rules

### Test-specific rules (1-11)
Same as V1 test plan rules 1-11 (imports, class structure, assertions, setUp/tearDown, etc.)

### Production API reference rules (12-14)
Same as V1 — grep production .swift files, use module imports, no bridging headers.

### Additional rules from production V2:
- **Rule 33:** `@synchronized` → `NSRecursiveLock`
- **Rule 35:** `setValue(nil, forKey:)` not `NSNull()`
- **Use the NS_SWIFT_NAME sed script** for test files that reference production APIs by ObjC names

### Conflict map updates (from current state):
- **SalesforceSDKCore:** No conflicts — all conversions done. `ScreenLockManagerTests.swift` and `SFOAuthCoordinatorTests.swift` already exist (no Legacy suffix needed — the ObjC originals are excluded from compilation).
- **SmartStore:** `SmartStoreTests.swift` exists — leave as-is. New test conversions use different class names.
- **MobileSync:** `BriefcaseSyncDownTests.swift` exists — leave as-is. Plus `TestSyncDownTarget.swift` and `TestSyncUpTarget.swift` already exist (converted during production cleanup).

---

## Phase Structure (Revised)

### Phase 0: TestApp Scaffolding (all libraries, 12 files)
All test host apps have identical ObjC boilerplate (`main.m`, `AppDelegate.m`, `ViewController.m`). Convert all 12 in one pass — they're ~30 lines each with identical patterns.

| Batch | Files | Status |
|-------|-------|--------|
| 01 | All 12 TestApp scaffolding files: Analytics (3), SmartStore (3), MobileSync (3), SDKCore (3) | [ ] |

**Boundary:** Update all 4 project.pbxproj files. Build all test apps. Commit once.

### Phase 1: SalesforceSDKCommon (1 file)
| Batch | Files | Status |
|-------|-------|--------|
| 02 | `SFLoggerTests.m` | [ ] |

**Boundary:** Remove .m from project, build + test. Baseline: 40 tests, 0 failures.

### Phase 2: SalesforceAnalytics (3 test files)
| Batch | Files | Status |
|-------|-------|--------|
| 03 | `AnalyticsTestUtil.m`, `EventStoreManagerTests.m`, `InstrumentationEventBuilderTests.m` | [ ] |

**Boundary:** Remove .m from project, build + test. Baseline: 19 tests, 0 failures.

### Phase 3: SmartStore (12 test files)
| Batch | Files | Status |
|-------|-------|--------|
| 04 | `SFSmartStoreTestCase.m` (base class), `SFQuerySpecTests.m` | [ ] |
| 05 | `SFSmartStoreTests.m` (1,431 lines — split approach: 2 agents) | [ ] |
| 06 | `SFSmartSqlTests.m`, `SFSmartSqlCacheTests.m`, `SFSmartStoreAlterTests.m` | [ ] |
| 07 | `SFSmartStoreFullTextSearchTests.m`, `SFSmartStoreFullTextSearchSpeedTests.m`, `SFSmartStoreLoadTests.m` | [ ] |
| 08 | `SFMultipleSmartStoresTests.m`, `SFSDKStoreConfigTests.m`, `SmartStoreSDKManagerTests.m` | [ ] |

**Boundary:** Remove .m from project, verify `SmartStoreTests.swift` compiles, build + test. Baseline: 177 tests, 1 expected failure. Budget 5-6h (includes 1,431-line split and potential SQLCipher/FMDB interop issues similar to production Phase 3).

### Phase 4: MobileSync (11 test files)
| Batch | Files | Status |
|-------|-------|--------|
| 09 | `SyncManagerTestCase.m` (base class), `SyncStateTests.m` | [ ] |
| 10 | `SyncManagerTests.m` (1,247 lines — split approach: 2 agents) | [ ] |
| 11 | `SyncUpTargetTests.m`, `BatchSyncUpTests.m`, `CollectionSyncUpTargetTests.m` | [ ] |
| 12 | `ParentChildrenSyncTests.m` (2,057 lines — split approach: 3 agents) | [ ] |
| 13 | `SFLayoutSyncManagerTests.m`, `SFMetadataSyncManagerTests.m`, `SFSDKSoqlMutatorTests.m`, `SFSDKSyncsConfigTests.m` | [ ] |

**Boundary:** Remove .m from project, remove `MobileSyncTests-Bridging-Header.h`, verify `BriefcaseSyncDownTests.swift` + `TestSyncDownTarget.swift` + `TestSyncUpTarget.swift` compile, build + test. Baseline: 189 tests, 0 failures. **Note:** MobileSync tests include integration tests that hit a live Salesforce org. Ensure network access and valid credentials. Tests that timeout (>30s per test) likely indicate an expired refresh token — regenerate before debugging.

### Phase 5: SalesforceSDKCore — ALREADY COMPLETE
No work needed. All 56 ObjC test files converted during production cleanup (Item 6).

**Note:** `SFUserAccountManagerTests.swift` and `SalesforceRestAPITests.swift` are in the project but have known API mismatches (assertions that don't match converted production behavior). These need fix passes — not reconversion — and require live credentials to verify. Handle after operator gate, before post-conversion.

---

## Commit Strategy

- **After pre-flight:** `"Add test ObjC→Swift conversion plan (V2)"`
- **After Phase 0 (scaffolding):** `"Convert all TestApp scaffolding to Swift (Phase 0)"`
- **After each library boundary:** `"Convert LIBRARY test ObjC to Swift (Phase N)"` — include .swift files, project.pbxproj, bridging header removals
- **After post-conversion:** `"Verify clean build and full test pass after test ObjC→Swift conversion"`
- Do NOT commit `test_credentials.json` (gitignored)

---

## Library Boundary Steps

Same as V2 production plan, adapted for test targets:

1. **Tombstone/remove test .m/.h from project** (use pbxproj script)
2. **Add .swift test files** to project (use pbxproj script)
3. **Remove bridging header** (if applicable — MobileSync, SDKCore)
4. **Clean build:** `rm -rf ~/Library/Developer/Xcode/DerivedData && xcodebuild build -scheme LIBRARYTestApp ...`
5. **Fix errors** (up to 3 attempts, escalation thresholds below)
6. **Run tests:** `xcodebuild test -scheme LIBRARY ...`
7. **Compare against baseline** — any new failures are conversion regressions
8. **Commit**

### Escalation thresholds (adjusted for base class cascades)
- If >20 errors AND they all trace to a single base class conversion (`SFSmartStoreTestCase`, `SyncManagerTestCase`): treat as a single root-cause issue. Fix the base class first, rebuild, then assess remaining errors independently.
- If >20 errors from diverse sources after first repair: **stop** — systemic issue.
- If >10 same-category errors after first repair: **stop** — strategy problem.

### Test-to-production adaptation rule (with relaxation)
**Default:** Tests adapt to production code. Fix test assertions and API calls to match the converted Swift production API. Never modify production code to make a test pass.

**Exception:** If a test failure reveals a genuine **production conversion bug** (verified by comparing the converted .swift file against the original .m file retained on disk), the production code MAY be fixed. Requirements:
1. The comparison must clearly show the Swift code behaves differently from the original ObjC
2. The fix must restore the original ObjC behavior, not change it
3. **Every production code change must be logged** in a `test-conversion-production-fixes.md` report
4. The report is presented to the operator at the operator gate with: file changed, what was wrong, what the ObjC original did, what the fix restores
5. The operator reviews all production changes before approving the gate

---

## Large Files Requiring Multi-Agent Split

| File | Lines | Agents | Split Strategy |
|------|-------|--------|---------------|
| `SFSmartStoreTests.m` | 1,431 | 2 | CRUD/query tests + index/registration tests |
| `SyncManagerTests.m` | 1,247 | 2 | Sync down tests + sync up tests |
| `ParentChildrenSyncTests.m` | 2,057 | 3 | Parent tests, children tests, combined tests |

---

## Estimated Timeline

| Phase | Files | Estimate |
|-------|-------|----------|
| Pre-flight + script creation | — | 1h |
| Phase 0 (all scaffolding) | 12 | 1h |
| Phase 1 (SDKCommon) | 1 | 30m |
| Phase 2 (Analytics) | 3 | 1h |
| Phase 3 (SmartStore) | 12 | 5-6h (includes 1,431-line split, potential SQLCipher issues) |
| Phase 4 (MobileSync) | 11 | 6-7h (includes 2,057-line split, live integration tests) |
| SDKCore fix pass (2 excluded files) | 2 | 1-2h (requires live credentials) |
| Post-conversion | — | 1h |
| **Total** | **39 + 2 fixes** | **~17-19h** |

---

## Definition of Done

1. All batches `[✓]` in tracker
2. All 5 test schemes build from clean DerivedData
3. All test suites run with results matching or exceeding baseline
4. No deferred files remain
5. No ObjC test .m files in any Compile Sources build phase

---

## Operator Gate

Single gate after Phase 4 boundary (the last phase with real conversion work). Report includes:
- Total tests converted
- Pass/fail vs baseline for all 5 libraries
- Any behavioral regressions discovered
- Decision: proceed to post-conversion / adjust / stop
