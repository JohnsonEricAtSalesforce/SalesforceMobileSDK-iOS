# Production ObjC → Swift Conversion Plan (V2)

**Date:** 2026-05-21
**Based on:** V1 retrospective (executed 2026-05-17 through 2026-05-21, 201 files, 4 days)
**Purpose:** Improved plan incorporating lessons learned from V1 execution
**Scope:** This is a **strategy overlay** on V1. The V1 batch tracker (`production-swift-conversion-plan.md`) remains the authoritative file-to-batch assignment. V2 improves the HOW (process, tooling, boundary steps) not the WHAT (which files, which order).
**Codebase:** Salesforce Mobile SDK for iOS — this plan carries forward codebase-specific knowledge from V1 (NS_SWIFT_NAME mappings, known interop issues, verified patterns).

---

## Key Differences from V1

| Aspect | V1 | V2 |
|--------|----|----|
| Interop discovery | During execution (caused ~15h rework) | **Phase 0 prototype** before planning |
| Large files (>1K lines) | Discovered limit by timing out | **Pre-split before conversion** |
| Header management | Iterative trial-and-error | **Tombstone-first at each boundary** |
| project.pbxproj edits | Manual agent edits (error-prone) | **Scripted via xcodeproj gem** |
| Build verification | Incremental (masked issues) | **Clean DerivedData at every boundary** |
| NS_SWIFT_NAME renames | Discovered during build (8h+ of fixes) | **Explicit grep-and-replace step** |
| Test conversion | Mixed into production (caused scope creep) | **Excluded — separate test plan** |
| Downstream build | Built all downstream at each boundary | **Build THIS library only** |

---

## Orchestrator / Agent Model (Condensed)

**Orchestrator** (top-level Claude session):
- Constructs scope fences and agent prompts from batch tracker
- Spawns sub-agents for semantic conversion and boundary work
- Runs verification (file existence, @objc check, scope compliance)
- Manages commits, timestamps, operator gates
- **Never** writes Swift code or edits project files directly

**Agents** (sub-agents spawned per batch or boundary):
- Perform semantic conversion (read .m/.h → write .swift)
- Call the pbxproj script (not manual edits)
- Fix build errors within their scope fence
- Return structured completion manifests

**Handoff:** Agent returns manifest → orchestrator verifies → tells agent to proceed to boundary (or sends back issues to fix). Same agent handles both conversion and boundary for Phases 1-4. Phase 5 uses multiple agents (smaller batch groups due to size).

**Recovery:** If session dies mid-batch, check batch tracker for last `[✓]`. Read latest delta notes. Continue from next incomplete batch. If session dies mid-boundary (all batches `[✓]` but no boundary timestamp), re-run verification checklist before spawning a new boundary agent.

For full orchestrator protocol details, see V1 plan sections "Autonomous Execution Model" through "Orchestrator verification checklist."

---

## Phase 0: Prototype Interop Issues (Before Planning)

**Goal:** Convert 1 representative file per library to discover Swift 6.x interop constraints before committing to the full conversion plan.

**Duration:** ~2 hours

**Actions:**
1. Pick 1 small-to-medium file per library (not a leaf utility — something with downstream callers)
2. Convert it fully to Swift: semantic translation, add to project, remove .m, tombstone .h
3. Build the library AND one downstream library
4. Document every issue encountered:
   - Does `objc_subclassing_restricted` affect this class? (Rule 32)
   - Do NS_SWIFT_NAME renames cascade to callers?
   - Does the header tombstone cause duplicate interface errors?
   - Are there ObjC generic types that can't be @objc?
   - Does the module map need updates?
5. **Keep the prototype** if it's clean and passing — it becomes the first converted file in its library's phase (reduces batch count by 1 per library). Commit it.
6. Use findings to set rules, estimate effort, and structure the real plan

**Why this saves time:** V1 discovered `objc_subclassing_restricted`, NS_SWIFT_NAME cascades, and header tombstoning requirements DURING execution — each causing multi-hour rework. A 2-hour prototype would have surfaced all three. Keeping the prototypes (rather than reverting) means the discovery work directly contributes to conversion progress.

**Note:** Phase 0 is the ONE exception to the single-library boundary model. Prototypes intentionally build ONE downstream library to discover cascade effects. After Phase 0, all subsequent boundaries build THIS library only. Phase 0 does NOT require the pbxproj script or sed rename script — it uses manual edits (acceptable for 1 file per library). The scripts are created during Preparation (after Phase 0, before Phase 1).

**If Phase 0 reveals a showstopper** (e.g., module structure fundamentally incompatible with Swift, entire class hierarchy un-convertible): STOP. Present findings to operator. The plan may need architectural restructuring before proceeding. Phase 0 exists to catch these before committing 40+ hours of work.

---

## Execution Model (Revised)

### Single-library boundary model
Each library boundary builds and tests ONLY the library being converted. Downstream libraries are NOT built or fixed at this boundary. Downstream effects are resolved when that downstream library is converted in its own phase.

### No ObjC test modifications
Any ObjC test file that fails to compile against converted Swift classes is **left alone**. Test conversion is handled in a separate, dedicated test conversion plan (see `test-swift-conversion-plan.md`). Production conversion never touches test code.

### Agent scope
- Agents perform semantic conversion (read .m/.h → write .swift)
- Agents perform boundary integration (project file, build, fix errors)
- The orchestrator verifies, commits, and manages gates
- **No agent manually edits project.pbxproj** — use the pbxproj script (see below)

### Deferral protocol
If a file hits Rule 31 (generics), Rule 32 (subclassing), or any other architectural blocker that requires >30min of non-standard work:
1. **Defer it** — do not spend time on workarounds during the batch
2. Mark the batch `[✓]` with a `⚠️ DEFERRED` annotation in the tracker
3. Document the reason in delta notes
4. Continue to the next batch
5. Deferred files are addressed in a dedicated cleanup pass after all non-deferred files are done

This prevents one difficult file from blocking an entire phase. V1 deferred 6 files during execution — all were resolved in cleanup with targeted approaches.

---

## Pre-Conversion Preparation

### 1. Plan multi-agent conversion for large files
Before conversion begins, identify all .m files >1,000 lines that will need the split-agent approach:

```bash
find libs -name "*.m" -not -path "*Test*" -exec sh -c 'lines=$(wc -l < "$1"); [ $lines -gt 1000 ] && echo "$lines $1"' _ {} \; | sort -rn
```

For each file >1,000 lines:
- Identify `#pragma mark` sections as logical split points
- Do NOT pre-split in ObjC (category files add complexity). Instead, plan the conversion as multiple Swift extension files:
  - Agent 1 converts lines 1-800 → writes `ClassName.swift` (class declaration + properties + init)
  - Agent 2 converts lines 800-1600 → writes `ClassName+Section.swift` (extension)
  - Agent 3 converts remaining → writes `ClassName+Section2.swift` (extension)
  - Consolidate into a single file after all agents complete (optional — extensions in same file are valid Swift)

This eliminates agent session timeout issues (each agent reads ~1,000 lines, writes ~700) without requiring pre-conversion ObjC restructuring.

**Consolidation rule:** After all agents complete, consolidate into a single file only if the total is <2,000 lines. Files >2,000 lines are better left as extensions (one class + multiple extension files). The Swift compiler handles them identically — it's purely an organizational choice.

**V1 evidence:** SFUserAccountManager (2,388 lines) timed out 4 agents before the 3-agent split approach succeeded.

### 2. Create pbxproj management script
Create a Ruby script using the `xcodeproj` gem that provides these operations:
- `add_swift_file(target, path)` — adds file reference + compile source
- `remove_m_from_compile(target, filename)` — removes .m from compile sources
- `tombstone_header(target, filename)` — moves header from Public to Project visibility
- `remove_header_from_phase(target, filename)` — removes from Headers build phase entirely

Agents call this script instead of editing pbxproj directly. This prevents:
- Wrong header visibility (Public vs Project vs Private)
- Duplicate entries
- Missing file references
- Corrupted pbxproj structure

### 3. Create NS_SWIFT_NAME lookup table + sed template
Before conversion, generate a mapping of all NS_SWIFT_NAME annotations in the codebase:

```bash
grep -rn "NS_SWIFT_NAME" libs/ --include="*.h" | sed 's/.*NS_SWIFT_NAME(\(.*\)).*/\1/'
```

This produces a table like:
| ObjC Name | Swift Name |
|-----------|-----------|
| SFUserAccountManager | UserAccountManager |
| SFRestAPI | RestClient |
| SFUserAccount | UserAccount |
| SFDirectoryManager (sharedManager) | SFDirectoryManager.sharedManager |
| ...| ... |

**Codebase-specific mappings (from V1 execution):**
| ObjC Call | Swift Equivalent |
|-----------|-----------------|
| `SFUserAccountManager.sharedInstance()` | `UserAccountManager.shared` |
| `SFRestAPI.sharedInstance()` | `RestClient.sharedInstance` |
| `SFRestAPI.sharedInstance(for:)` | `RestClient.restClient(for:)` |
| `SFSDKWindowManager.sharedManager` | `SFSDKWindowManager.shared` |
| `SFSDKDatasharingHelper.sharedInstance()` | `SFSDKDatasharingHelper.sharedInstance` (property) |
| `SFDirectoryManager.shared()` | `SFDirectoryManager.sharedManager` |
| `SFFileProtectionHelper.fileProtection(forPath:)` | `FileProtectionHelper.protection(for:)` |
| `SFSDKKeyGenerator` | `KeyGenerator` |
| `SFSDKEncryptor` | `Encryptor` |

**Automation mechanism:** Generate a sed script from the table:
```bash
# scripts/rename_ns_swift_names.sh
sed -i '' 's/SFUserAccountManager\.sharedInstance()/UserAccountManager.shared/g' "$1"
sed -i '' 's/SFRestAPI\.sharedInstance()/RestClient.sharedInstance/g' "$1"
# ... (one line per mapping)
```

Agents receive both the table (in their prompt for context) AND run the sed script on each converted .swift file as the first step of the NS_SWIFT_NAME rename pass.

**Caveat:** The sed script does global string replacement and will produce false positives on partial matches (inside strings, comments, or partial identifiers). This is acceptable — the script handles ~80% of renames. The clean build (Step 5) catches false positives (which manifest as type errors on the mis-renamed identifiers). Agents fix remaining issues in Step 6.

---

## Seed Conversion Rules (Revised from V1)

All V1 rules (1-30) apply, plus the following corrections/additions discovered during V1 execution:

### Rule 31: ObjC generic classes use non-generic @objc
ObjC classes with lightweight generics (`SFSDKSafeMutableDictionary<K,V>`) → convert to non-generic `@objc` class with `Any` values. Swift generics cannot be `@objc`.

### Rule 32: ObjC cannot subclass Swift classes
ALL Swift classes get `objc_subclassing_restricted` in Swift 6.x. Any ObjC class that subclasses a converted class must be converted simultaneously or refactored to composition.

### Rule 33: `@synchronized` → `NSRecursiveLock`
ObjC `@synchronized` is always re-entrant. `NSLock` will deadlock on re-entrant calls. Always use `NSRecursiveLock`.

### Rule 34: Keep `NSException.raise()` for ObjC callers
When ObjC callers use `@try/@catch`, the Swift conversion must preserve `NSException.raise()` behavior. Do NOT silently convert to `return nil`/`return []`.

### Rule 35: setValue(nil, forKey:) not NSNull()
When using KVC to set an optional property to nil, use `setValue(nil, forKey:)`. Never use `setValue(NSNull(), forKey:)` — NSNull is an object that will crash when the property is later used as its expected type.

---

## Library Boundary Steps (Revised)

At each library boundary, after semantic conversion is complete:

### Step 1: Tombstone ALL converted headers (FIRST)
For every .h file whose class is now in Swift:
- Replace content with just `#import <LibraryName/LibraryName-Swift.h>` (if not in umbrella header chain)
- Or reduce to forward declarations + extern constants only (if in umbrella chain)
- Do this for ALL headers at once — don't iteratively discover conflicts
- **Also update the umbrella header** (`LibraryName.h`) — remove `#import` lines for all tombstoned headers. The umbrella header should only import headers that are still active ObjC (constants files, variadic category headers, deferred files).

### Step 2: Run pbxproj script
```bash
ruby scripts/update_project.rb \
  --target LibraryName \
  --remove-m file1.m file2.m ... \
  --add-swift file1.swift file2.swift ... \
  --tombstone-headers file1.h file2.h ...
```

### Step 3: Update podspec
Update the library's `.podspec` at repo root:
- Add `*.swift` to `source_files` glob (if not already present)
- Add `exclude_files` for retained .m/.h originals (prevents CocoaPods from compiling both)
- Remove any `public_header_files` entries for tombstoned headers
- Flag for operator review (per CLAUDE.md rules)

### Step 4: NS_SWIFT_NAME rename pass
Run the sed rename script on all newly converted .swift files:
```bash
for f in libs/LibraryName/LibraryName/Classes/**/*.swift; do
  bash scripts/rename_ns_swift_names.sh "$f"
done
```

Then manually verify any remaining ObjC-style calls the script missed (the build in Step 5 will catch them).

### Step 5: Clean build
```bash
rm -rf ~/Library/Developer/Xcode/DerivedData
xcodebuild build -workspace SalesforceMobileSDK.xcworkspace \
  -scheme LibraryName \
  -destination "$SIMULATOR_DEST" \
  CODE_SIGNING_ALLOWED=NO
```

Always build from clean DerivedData. Incremental builds mask module visibility issues.

### Step 6: Fix remaining errors (up to 3 attempts)
Escalation thresholds (adjusted for rename pass):
- If >20 errors remain AFTER the NS_SWIFT_NAME rename pass (Step 4): this indicates a systemic issue beyond renames — **stop and investigate**.
- If >10 errors of the same category after first repair: **stop** — likely a wrong rule or missing pattern.
- Otherwise: fix iteratively (up to 3 attempts).

### Step 7: Commit
One commit per library boundary. Include the pbxproj changes, tombstoned headers, podspec, renamed files, and any build fixes.

---

## Phase Structure

Same dependency order as V1:
1. SalesforceSDKCommon
2. SalesforceAnalytics
3. SmartStore
4. MobileSync
5. SalesforceSDKCore (116 files — run in groups of 3-5 batches per agent, sequentially. No parallel execution — V1 proved agent connection instability makes parallelism unreliable. Budget 6-8 agent sessions for semantic conversion, plus 1-2 for boundary.)
6. MobileSyncExplorer (sample app)

**No Phase 7 for tests.** Test conversion is handled by a separate plan (`test-swift-conversion-plan.md`).

### Operator gates
Same 5 gates as V1 (one per library boundary). Report format same as V1. Decision: proceed / adjust / stop.

### Large files requiring multi-agent split (this codebase)
These 4 files exceed 1,000 lines and must use the split approach from Preparation Step 1:
- `SFUserAccountManager.m` (2,388 lines) — 3 agents: properties/init, auth/delegates, accounts/switching
- `SFSmartStore.m` (2,066 lines) — 3 agents: CRUD/query, database management, SQL helpers
- `SalesforceSDKManager.m` (1,081 lines) — 2 agents: lifecycle/init, dev support/analytics
- `SFOAuthCoordinator.m` (1,057 lines) — 2 agents: auth flow, token endpoint/delegate callbacks

---

## How to Resume After Session Termination

1. Read this plan (V2 strategy) + V1 plan's batch tracker for file assignments
2. Check the batch tracker for the last `[✓]` batch
3. Read the latest `prod-conversion-lessons-delta-LIBRARY.md` and `prod-conversion-patterns.md`
4. If all batches for a library are `[✓]` but no boundary timestamp: re-run verification, then spawn boundary agent
5. Continue from next incomplete batch

**Key context to reload:**
- The NS_SWIFT_NAME lookup table (in this plan's Preparation section)
- Rules 31-35 (in this plan's Seed Conversion Rules section)
- The V1 pattern registry (`prod-conversion-patterns.md`) — all 14 patterns are pre-verified from V1 execution and should be applied with confidence on this codebase

---

## Estimated Timeline (Codebase-Specific, Based on V1 Actuals)

| Phase | V1 Actual | V2 Estimate | Savings From |
|-------|-----------|-------------|--------------|
| Phase 0 (prototype) | N/A | 2h | New — prevents ~15h rework |
| Preparation (split, script, table) | N/A | 3h | New — prevents ongoing issues |
| Phase 1 (SDKCommon) | 3h | 1.5h | No downstream build, tombstone-first |
| Phase 2 (Analytics) | 1h | 45m | Already efficient in V1 |
| Phase 3 (SmartStore) | 8h | 4h | Pre-split SFSmartStore.m, clean builds catch issues early |
| Phase 4 (MobileSync) | 6h | 3h | No test fixes, NS_SWIFT_NAME pre-pass |
| Phase 5 (SDKCore) | 20h+ | 12h | Pre-split UAM/OAuthCoord, scripted pbxproj, rename pass |
| Phase 6 (Sample app) | 30m | 30m | Same |
| Post-conversion | 2h | 1h | Clean build already done per-boundary |
| **Total** | **~45h** | **~28h** | **~38% reduction** |

These estimates are specific to the Salesforce Mobile SDK iOS codebase. The V1-discovered interop issues, NS_SWIFT_NAME mappings, and verified patterns are carried forward — eliminating the discovery overhead that dominated V1.

---

## Definition of Done

The plan is **complete** when:
1. All batches in the tracker are marked `[✓]` (with or without `⚠️ DEFERRED` annotations)
2. All 5 library schemes + MobileSyncExplorer build from clean DerivedData in one sequential pass
3. No deferred files remain unresolved (all resolved in cleanup or explicitly accepted as permanent ObjC)
4. The cleanup plan (`production-swift-cleanup-plan.md`) has no open items blocking production build

**Test coverage is NOT part of this definition** — it belongs to the test conversion plan.

---

## What This Plan Does NOT Cover

- **Test conversion** — Handled by `test-swift-conversion-plan.md` (same directory). Converts ObjC test files to Swift after production code is stable.
- **Audit artifact removal** — Handled by `production-swift-cleanup-plan.md` (Item 8). Removes original .m/.h files from disk after full verification.
- **CocoaPods/SPM verification** — Spot-checked during build (podspec updated at each boundary), but formal end-to-end `pod lib lint` validation is a separate step.

---

## Quick Reference (from V1)

### Orchestrator verification checklist (run after each agent manifest)
1. For each file in manifest's "Files converted" table: verify .swift exists on disk and is non-empty
2. Verify every changed file is within the agent's scope fence
3. For conflict-map files: verify Legacy suffix applied where required
4. For EVERY converted .swift file: verify `@objcMembers` or `@objc` appears on class declaration
5. Verify delta notes file exists and is non-empty
6. Verify batch tracker shows `[✓]` for all assigned batches
7. Verify manifest file count matches expected batch count

### Operator review report template
```
## Conversion Scope
- ObjC files converted: N
- Swift files written: N
- Deferred: N (list)

## Build Results
- First-pass errors: N
- After repair: N
- Error categories: (list)

## Podspec Changes
- (list)

## Security-Critical Files
- (list, or "none")

## Self-Review Summary
- Key patterns discovered this phase: (1-2 bullets)
- Recommended adjustments for next phase: (if any)

## Decision Required
- [ ] Proceed
- [ ] Adjust
- [ ] Stop
```
