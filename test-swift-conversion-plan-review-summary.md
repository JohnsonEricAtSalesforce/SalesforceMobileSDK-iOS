# Test Conversion Plan Review Summary

**Date:** 2026-05-21
**Participants:** Operator (Eric Johnson) + Claude (orchestrator/reviewer)
**Input:** V1 test conversion plan (`test-swift-conversion-plan.md`, 632 lines, written 2026-05-17)
**Output:** V2 test conversion plan (`test-swift-conversion-plan-v2.md`, 234 lines)

---

## Context

The test conversion plan was written before the production conversion executed. By the time we reviewed it (2026-05-21), the landscape had changed dramatically:

- Production conversion was 100% complete (all 201 classes Swift)
- 56 of 98 test files (all of SalesforceSDKCore) were already converted during production cleanup (Item 6)
- 3 SafeMutable* test files were converted during Item 4
- V2 production plan established new tooling and process standards (scripted pbxproj, sed rename, clean builds, no parallelism)
- An operator rule was in effect: no ObjC test modifications — convert to Swift instead

---

## Key Findings from Review

### The plan was 60% obsolete
- Phase 5 (SDKCore, 56 files, 13 batches) was entirely complete — the largest phase had already been done
- Total remaining work: 27 test files + 12 scaffolding = 39 files (not 98)
- The parallel execution model (scout-then-parallel) had been proven unreliable in V1 and abandoned

### The plan referenced tooling that doesn't exist
- `scripts/update_project.rb` (pbxproj management) — designed but never created
- `scripts/rename_ns_swift_names.sh` (sed rename script) — content defined in V2 production plan but never materialized as a file
- Both need creation during pre-flight

### The plan didn't account for V1 lessons
- No clean DerivedData builds
- No escalation adjustments for base class cascades
- No mention of the NSNull/KVC bug pattern (Rule 35)
- No awareness that MobileSync integration tests require live credentials

---

## Decisions Made During Review

### Structural changes (operator selected "All 8" refinements twice):

**Round 1 — from initial review:**
1. Audit already-converted files → removed from batch tracker
2. Remove parallelism → sequential only
3. Incorporate V2 production lessons → scripted pbxproj, clean builds, sed rename
4. Mark Phase 1 SDKCommon as nearly complete (1 file remaining)
5. Consolidate TestApp scaffolding into single Phase 0
6. Note SDKCore excluded files need fix passes (not reconversion)
7. Add commit strategy section
8. Buffer SmartStore/MobileSync timeline estimates

**Round 2 — from second review:**
1. Add resume/recovery instructions
2. Acknowledge missing scripts — create in pre-flight
3. MobileSync live credentials warning at Phase 4 boundary
4. Combined script creation into pre-flight step 6
5. All scaffolding → Phase 0 (one batch, one commit, 12 files)
6. SDKCore excluded files documented as post-gate fix pass
7. Commit message format defined
8. Timeline buffered (5-6h SmartStore, 6-7h MobileSync)

### Policy additions (operator-directed):

**Base class cascade handling:**
If >20 errors at boundary all trace to a single base class conversion (SFSmartStoreTestCase, SyncManagerTestCase), treat as one root-cause issue — fix the base class first, then reassess.

**Production code fix relaxation:**
If a test failure reveals a genuine production CONVERSION BUG (verified by comparing .swift against retained .m), production code may be fixed. All such changes logged in `test-conversion-production-fixes.md` and presented to operator at the gate for review.

---

## Final V2 Test Plan Structure

| Phase | Library | Files | Estimate |
|-------|---------|-------|----------|
| 0 | All (scaffolding) | 12 | 1h |
| 1 | SalesforceSDKCommon | 1 | 30m |
| 2 | SalesforceAnalytics | 3 | 1h |
| 3 | SmartStore | 12 | 5-6h |
| 4 | MobileSync | 11 | 6-7h |
| 5 | SalesforceSDKCore | Already done | — |
| — | SDKCore fix pass | 2 (excluded files) | 1-2h |
| — | Post-conversion | — | 1h |
| **Total** | | **39 + 2 fixes** | **~17-19h** |

---

## Next Steps

The V2 test conversion plan is committed and ready for execution. The operator will provide the instruction to begin when ready.
