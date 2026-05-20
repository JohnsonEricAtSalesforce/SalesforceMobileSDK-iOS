# Production ObjC → Swift Cleanup Plan

**Date:** 2026-05-19
**Branch:** `feature/objc-to-swift-production-migration`
**Prerequisite:** Production conversion complete (196/198 files). This plan addresses remaining gaps.

---

## Rule: No ObjC Modifications in Tests (effective 2026-05-20)

**From this point forward, no Objective-C test code shall be modified.** Any ObjC test file (`.m`) that blocks the test target from compiling must be **semantically converted to Swift** before proceeding. This applies to all remaining cleanup items.

Rationale: Modifying ObjC test code to match new Swift API names is wasted effort — the test files themselves are being converted. Converting them to Swift eliminates the interop issues entirely and produces the final-state code directly.

This rule means:
- Broken ObjC test `.m` files → convert to `.swift` (not fix ObjC selectors)
- ObjC test helpers/mocks → convert to Swift
- No `sed` fixes on `.m` test files
- Exclusion from compilation is acceptable as a temporary measure while conversion is in progress

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

### Item 5: Convert MobileSync ObjC Tests to Swift
**Priority:** Medium — tests don't compile for Phase 4 library
**Effort:** 4-6 hours
**Rule:** No ObjC modifications — convert blocking test .m files to Swift.

ObjC test files reference converted Swift classes with old selectors. Per the no-ObjC-modification rule, these must be converted:
- [ ] Convert `SyncManagerTestCase.m` → Swift (base class for all sync tests)
- [ ] Convert `SyncManagerTests.m` → Swift
- [ ] Convert `ParentChildrenSyncTests.m` → Swift
- [ ] Convert remaining ObjC test helpers to Swift
- [ ] Run full MobileSync test suite — target: 189 tests, 0 failures

**Success criteria:** `xcodebuild test -scheme MobileSync` passes with baseline results.

---

### Item 6: Convert SalesforceSDKCore ObjC Tests to Swift ⬅️ CURRENT PRIORITY
**Priority:** HIGH — blocks Item 3 verification
**Effort:** 6-10 hours
**Rule:** No ObjC modifications — convert blocking test .m files to Swift.
**Status:** Prefix header fixed, 42+ Swift test files already compile. ~13 ObjC .m test files block the target.

**Blocking ObjC test files (must be converted to Swift):**
- [ ] `SalesforceRestAPITests.m` (~600 lines — largest, integration tests)
- [ ] `SalesforceSDKManagerTests.m` + `SFTestSDKManagerFlow.m`
- [ ] `SFSDKErrorManagerTests.m`
- [ ] `SalesforceOAuthUnitTests.m` + `SalesforceOAuthUnitTestsCoordinatorDelegate.m`
- [ ] `SFOAuthCoordinatorTests.m` (ObjC version)
- [ ] `SFOAuthSessionRefresherTests.m`
- [ ] `SFOAuthCredentialsTests.m`
- [ ] `SFPreferencesTests.m`
- [ ] `SFEncryptionKeyTests.m`
- [ ] `SFCryptoStreamTestUtils.m` (test helper)
- [ ] `SFOAuthTestFlowCoordinatorDelegate.m` (test helper)

**Approach:**
1. Convert each .m → .swift (semantic conversion, same rules as production)
2. Remove .m from Compile Sources, add .swift
3. After each batch, verify test target compiles
4. Final: run full test suite — target: 625 pass, ≤6 pre-existing failures

**Success criteria:** Test target compiles cleanly. `CredentialsArchiveRoundTripTests` can execute.

---

### Item 7: Verify Full-Stack Build (All 5 Libraries + Sample App)
**Priority:** High
**Effort:** 30 minutes
**Status:** Production build verified clean. Full-stack (all schemes) not yet verified.

- [ ] Build all schemes sequentially: SDKCommon → Analytics → SmartStore → MobileSync → SDKCore → MobileSyncExplorer
- [ ] Verify zero errors across the full stack
- [ ] Document any remaining warnings

**Success criteria:** All 6 schemes build clean in one pass.

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
