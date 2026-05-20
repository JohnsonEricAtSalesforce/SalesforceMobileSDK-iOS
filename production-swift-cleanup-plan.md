# Production ObjC → Swift Cleanup Plan

**Date:** 2026-05-19
**Branch:** `feature/objc-to-swift-production-migration`
**Prerequisite:** Production conversion complete (196/198 files). This plan addresses remaining gaps.

---

## Cleanup Items (ordered by priority)

### Item 1: Resolve Xcode `_AvailabilityInternal` Module Cache Bug ✅ RESOLVED
**Priority:** Blocking — prevents BUILD SUCCEEDED on SalesforceSDKCore
**Effort:** 15 minutes

**Resolution:** The issue was two-fold:
1. Xcode module cache corruption (cleared with `rm -rf ~/Library/Developer/Xcode/DerivedData`)
2. Missing `#import <SalesforceSDKCore/SFSDKURLHandler.h>` in umbrella header — lost during commit squash

Fix: Re-added `SFSDKURLHandler.h` and `SFUserAccountManager+Internal.h` to `SalesforceSDKCore.h`.

**Result:** `xcodebuild build -scheme SalesforceSDKCore` → **BUILD SUCCEEDED** ✅

---

### Item 2: Convert Deferred File — SFUserAccountManager.m (2,388 lines) — IN PROGRESS
**Priority:** High — largest remaining ObjC file, security-critical
**Effort:** 2-4 hours (manual or split-agent approach)

**Progress:**
- [x] Split the conversion into 3 parts (properties+init, auth methods, account management)
- [x] Convert each part via separate agent (718 + 1,080 + 963 lines)
- [x] Consolidate into single file (2,761 lines)
- [x] Remove SFUserAccountManager.m from Compile Sources
- [x] Tombstone SFUserAccountManager.h
- [ ] **Fix 80 internal compilation errors** (NS_SWIFT_NAME renames, optional unwrapping — same mechanical pattern as Phase 5 boundary fixes)
- [ ] BUILD SUCCEEDED

**Status:** File is converted and in project. Needs one more fix agent pass for the 80 API-rename errors.

---

### Item 3: Convert Deferred Files — SFOAuthCredentials + SFOAuthKeychainCredentials
**Priority:** Medium — security-critical but architecturally complex
**Effort:** 3-5 hours

These use the ObjC class-cluster pattern (init dispatches to subclass) and NSSecureCoding with backward-compatible archive keys. Conversion risk: existing archived credentials on user devices must still deserialize.

**Actions:**
- [ ] Verify: does the class-cluster pattern matter if both classes are converted together? (If SFOAuthKeychainCredentials is always the concrete class, the cluster dispatch can become a factory method)
- [ ] Convert SFOAuthCredentials.m → Swift, preserving NSSecureCoding exactly
- [ ] Convert SFOAuthKeychainCredentials.m → Swift as subclass
- [ ] Test: archive credentials with ObjC version, unarchive with Swift version (binary compat)
- [ ] Remove from Compile Sources, tombstone headers

**Success criteria:** Both files are Swift. NSSecureCoding round-trip works. BUILD SUCCEEDED.

---

### Item 4: Convert Deferred Files — SFSDKSafeMutable{Array,Dictionary,Set}
**Priority:** Low — these work fine as ObjC; conversion is optional
**Effort:** 1-2 hours

ObjC lightweight generics can't be represented in Swift @objc classes. Options:
- [ ] Option A: Convert to Swift using `Any` (lose type safety at ObjC boundary but gain Swift internals)
- [ ] Option B: Keep as ObjC permanently (they're utility classes, small, stable)
- [ ] Option C: Replace usages with Swift-native concurrent collections (DispatchQueue + Dictionary/Array/Set) — requires updating all callers

**Success criteria:** Either converted to Swift or explicitly marked as permanent ObjC with rationale documented.

---

### Item 5: Fix MobileSync Test Compilation (ObjC tests → @import + selector updates)
**Priority:** Medium — tests don't compile for Phase 4 library
**Effort:** 2-3 hours

ObjC test files use old selectors and subclass converted Swift classes. Requires:
- [ ] Replace all `#import <MobileSync/Header.h>` with `@import MobileSync;` in test files
- [ ] Convert remaining ObjC test subclasses to Swift (TestSoqlSyncDownTarget, etc.)
- [ ] Update selector calls to match new Swift-exposed API names
- [ ] Run full MobileSync test suite — target: 189 tests, 0 failures

**Success criteria:** `xcodebuild test -scheme MobileSync` passes with baseline results.

---

### Item 6: Fix SalesforceSDKCore Test Compilation
**Priority:** Medium — tests don't compile for Phase 5 library
**Effort:** 3-5 hours

Similar to MobileSync but larger scope (631 tests). The ObjC test files need:
- [ ] `@import SalesforceSDKCore;` replacing individual header imports
- [ ] Test classes that subclass converted Swift classes → refactor to composition or convert to Swift
- [ ] Selector renames matching new Swift-exposed API
- [ ] Run full test suite — target: 625 pass, ≤6 pre-existing failures

**Success criteria:** `xcodebuild test -scheme SalesforceSDKCore` passes with baseline results.

---

### Item 7: Verify Full-Stack Build (All 5 Libraries + Sample App)
**Priority:** High (after Items 1-2)
**Effort:** 30 minutes

Once the Xcode cache bug is resolved and SFUserAccountManager is converted:
- [ ] Build all schemes sequentially: SDKCommon → Analytics → SmartStore → MobileSync → SDKCore → MobileSyncExplorer
- [ ] Verify zero errors across the full stack
- [ ] Document any remaining warnings

**Success criteria:** All 6 schemes build clean in one pass.

---

### Item 8: Remove Original .m/.h Audit Artifacts (Future — after verification)
**Priority:** Deferred — not part of this cleanup
**Effort:** 1 hour

Per the plan, original files are removed in a separate commit after verification confirms accuracy:
- [ ] `find libs -name "*.m" -not -path "*Test*" -delete`
- [ ] `find libs -name "*.h" -not -path "*Test*"` — remove converted headers (keep active ones)
- [ ] Remove `exclude_files` from podspecs
- [ ] Commit: "Remove original ObjC files after audit verification"

**Not to be done until Items 1-7 are complete and operator confirms.**

---

## Execution Order

```
Item 1 (Xcode cache) ──→ Item 7 (full-stack build verify)
         │
         ├──→ Item 2 (SFUserAccountManager)
         │         │
         │         └──→ Item 7 (re-verify)
         │
         ├──→ Item 3 (SFOAuthCredentials) ──→ Item 7
         │
         ├──→ Item 5 (MobileSync tests)
         │
         ├──→ Item 6 (SDKCore tests)
         │
         └──→ Item 4 (SafeMutable* — optional)

Item 8 (artifact removal) ──→ only after all above pass
```

Items 2-6 can be done in parallel. Item 7 should be re-run after each of Items 2-3.

---

## Notes

- Items 5-6 (test fixes) are the same work pattern as Phases 1-3 test fixes — mechanical but time-consuming
- Item 3 (OAuthCredentials) is the highest-risk item due to NSSecureCoding backward compat
- Item 4 is optional — the SafeMutable* classes work fine as ObjC indefinitely
- This cleanup can be done incrementally across multiple sessions
