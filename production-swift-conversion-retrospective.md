# V1 Plan Retrospective — Production ObjC → Swift Conversion

**Date:** 2026-05-21
**Plan executed:** 2026-05-17 through 2026-05-21
**Result:** 100% production classes converted to Swift. Full-stack build verified.

---

## What went according to plan

1. **Dependency-ordered library phases** — Converting bottom-up (SDKCommon → Analytics → SmartStore → MobileSync → SDKCore) worked correctly. Each upstream library was stable before downstream conversion began.
2. **Batch structure** — The 48-batch breakdown was well-sized for agent context. Most batches completed within a single agent session.
3. **Operator gates** — The 5 gate review points caught real issues and allowed strategic adjustments (e.g., adopting single-library build model at Gate 1, deferring MobileSync tests at Gate 4).
4. **Original file retention** — Keeping .m/.h on disk for audit worked perfectly. Easy diffing, no cleanup pressure during conversion.
5. **Pattern registry** — The 14 verified patterns were reused across phases.
6. **Incremental commits** — One commit per library boundary enabled clean rollback points.
7. **Pre-flight validation** — Establishing the baseline (build + test counts) proved essential for measuring regressions.

---

## What didn't go according to plan

1. **Per-library build isolation was wrong** — The plan assumed each library could be built + tested independently. Reality: workspace builds all dependencies. Had to revise to "build THIS library only" model mid-Phase 1.
2. **Phase 5 parallel execution abandoned** — The scout-then-parallel model (4 tracks) was never used. Agent connection instability forced serial execution.
3. **Downstream build at each boundary removed** — Originally planned to build ALL downstream libraries after each phase. This was wasteful (touching downstream code during upstream conversion). Revised to single-library builds.
4. **Cumulative lessons files mostly skipped** — Only 1 of 5 written. Agent sessions ended before the documentation step.
5. **Test maintenance severely underestimated** — The plan assumed "fix test failures in production code." Reality: ObjC tests couldn't work with converted Swift classes AT ALL (NS_SWIFT_NAME renames every method name, objc_subclassing_restricted prevents test subclasses). Required full test file conversion.
6. **Large file handling not planned for** — Files >1,000 lines repeatedly timed out agents. No mitigation was in the original plan.
7. **NS_SWIFT_NAME cascading renames not anticipated** — The single largest time sink (~8h). Every converted Swift module re-exported types under renamed APIs, breaking all downstream callers.
8. **ObjC header tombstoning not in the plan** — The plan said "remove .h from Headers phase." Reality: you need to keep shim headers, manage module maps, prevent duplicate interface errors. This became a multi-day recurring issue.

---

## What went well (beyond the plan)

1. **Operator-directed adjustments** — The operator made 3 critical redirections: single-library build model, skip ObjC test fixes, no-ObjC-modification rule. Each saved significant time.
2. **Verification-first approach for security-critical files** — Writing the NSSecureCoding test BEFORE converting OAuthCredentials caught potential data-loss issues.
3. **Incremental commit discipline** — 34 commits with clear messages. Every piece of work was saved before the next began.
4. **Rule discovery** — Rules 31-34 (discovered during execution) were more impactful than most of the 30 seed rules planned in advance.

---

## What could have gone better

1. **Swift 6.3 interop research upfront** — The `objc_subclassing_restricted` and NS_SWIFT_NAME issues should have been prototyped before the plan was written. A 1-file proof-of-concept would have saved ~15h of boundary rework.
2. **Header management strategy** — Should have had "tombstone all headers immediately" as step 1 of each boundary, not discovered iteratively.
3. **Agent session limits** — Should have pre-split large files (>1,000 lines) into extension files before conversion, not discovered the limit by timing out 4 times.
4. **Test conversion should have been in the plan from the start** — The plan treated tests as "fix in production code." A V2 plan should include test conversion as a first-class phase.
5. **`project.pbxproj` management** — Every agent that touched the project file introduced subtle issues (wrong header visibility, missing files, duplicate entries). Should have used a dedicated tool/script, not manual agent edits.

---

## Key metrics

| Metric | Planned | Actual |
|--------|---------|--------|
| Files converted | 198 | 201 (3 discovered during cleanup) |
| Total wall-clock time | Not estimated | ~72h across 4 days |
| Operator gate reviews | 5 | 5 (3 full, 2 abbreviated) |
| Rules in seed set | 30 | 30 + 4 discovered (31-34) |
| Lessons files produced | 19 | 6 |
| Agent session failures (timeouts/drops) | 0 expected | ~10 |
| Unanticipated issues | 0 expected | 10 logged |
| Commits on feature branch | 6 planned (1/phase) | 35 actual |
| Phase 5 parallel tracks used | 4 | 0 (serial only) |
| Test files requiring conversion | 0 planned | ~56 actual (SDKCore + SafeMutable) |

---

## Recommendations for V2 Plan

### Rank 1: Prototype interop issues first
Before planning, convert 1 file per library as a proof-of-concept. Discover NS_SWIFT_NAME, subclassing, header management issues BEFORE committing to a full plan. ~2h upfront saves ~15h of surprises.

### Rank 2: Include test conversion as a dedicated phase
Don't treat test fixes as boundary cleanup. Add a dedicated phase for converting ObjC test files to Swift after production code is done. Budget: ~1h per 100 lines of test code.

### Rank 3: Pre-split large files before conversion
Any .m file >1,000 lines should be split into 2-3 extension files BEFORE conversion begins. This eliminates agent timeout issues and makes parallel work possible.

### Rank 4: Tombstone-first header strategy
At each library boundary, immediately tombstone ALL converted .h files (replace with -Swift.h forward or minimal shim). Don't iteratively discover which ones conflict. Budget 30min per library for header cleanup.

### Rank 5: Use a script for project.pbxproj modifications
Never have agents manually edit project.pbxproj. Use `xcodeproj` Ruby gem or a dedicated script that adds/removes files atomically. Agents introduce subtle issues (wrong visibility, missing entries, duplicate references).

### Rank 6: Build from clean DerivedData at every boundary
Incremental builds mask real issues. Every library boundary should delete DerivedData and build clean. This adds ~2min per boundary but catches module visibility issues immediately rather than hours later.

### Rank 7: Budget for NS_SWIFT_NAME renames as a separate step
After semantic conversion, before the build, run a grep pass that replaces all ObjC-style API calls with their NS_SWIFT_NAME equivalents. This is mechanical and can be partially automated.

### Rank 8: No ObjC test modifications from the start
Don't attempt to fix ObjC test files to match new Swift APIs. Convert them to Swift as part of the plan. This should be Rule 1, not a discovery on day 3.
