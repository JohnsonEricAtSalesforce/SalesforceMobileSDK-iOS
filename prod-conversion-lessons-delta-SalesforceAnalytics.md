# Delta Lessons — SalesforceAnalytics vs SalesforceSDKCommon (Phase 2 vs Phase 1)

## New Discoveries in Phase 2

1. **SWIFT_VERSION must be set explicitly** — SalesforceSDKCommon already had it; SalesforceAnalytics did not. Every library target needs this on first Swift file addition.

2. **Enum case @objc naming** — New pattern not seen in Phase 1. Original ObjC enums used non-standard case names (no type prefix). Required per-case `@objc(Name)` annotations.

3. **ObjC test bridging** — Phase 1 had no ObjC tests consuming the Swift code (tests were self-contained). Phase 2 revealed that ObjC tests must use `@import Framework;` instead of header imports.

4. **Optional safety at ObjC boundary** — Phase 1 didn't have tests that intentionally pass nil. Phase 2 revealed that Swift must use optionals where ObjC callers may pass nil despite nonnull annotations.

5. **Variadic method @objc incompatibility** — Not encountered in Phase 1. Format-string methods with `CVarArg...` cannot be `@objc`. Must provide parallel non-variadic overloads.

## Confirmed from Phase 1

- xcodeproj gem works reliably for bulk project file manipulation
- `@objcMembers` on class exposes all public members to ObjC
- Umbrella header reduces to just Foundation import
- Podspec `source_files` + `exclude_files` pattern works correctly

## Process Improvements

- Check for SWIFT_VERSION early (before first build attempt)
- After build succeeds, immediately run tests — ObjC consumer compatibility errors only surface at test-compile time
- Search test files for framework header imports proactively
