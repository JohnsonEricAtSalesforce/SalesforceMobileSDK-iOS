# Production Conversion Lessons — SalesforceAnalytics (Phase 2)

## Patterns Verified by Compiler

1. **@objc enum case naming**: When Swift `@objc` enums are exposed to ObjC, case names are auto-prefixed with the enum type name (e.g., `SFASchemaType.error` becomes `SFASchemaTypeError`). To preserve original ObjC enum constant names that don't follow this pattern, use `@objc(OriginalName)` on each case individually.

2. **@objcMembers + class = full ObjC visibility**: The `@objcMembers` annotation at class level correctly exposes all public properties and methods to ObjC without per-member annotation.

3. **Module import from ObjC tests**: When production code moves to Swift, ObjC test files must replace `#import <Framework/Header.h>` with `@import Framework;` to pick up Swift-generated headers.

4. **SWIFT_VERSION required**: Pure-ObjC projects that gain Swift files for the first time need `SWIFT_VERSION = 5.0` in build settings (target-level, all configs).

5. **Variadic parameters incompatible with @objc**: Swift variadic methods (`_ args: CVarArg...`) cannot be marked `@objc`. Provide separate non-variadic overloads for ObjC callers (e.g., `message:` variants alongside `format:` variants).

6. **Top-level `let` cannot be @objc**: Swift top-level constants (`public let kFoo`) cannot carry `@objc`. If ObjC visibility is needed, wrap in a class or use `@_cdecl`. For constants only used from Swift, just remove `@objc`.

7. **Bool property naming**: ObjC `@property (getter=isX) BOOL x` maps to Swift `var x: Bool`. The original ObjC tests access via dot notation on the property name (`manager.loggingEnabled`), so the Swift property must use the same name (not `isLoggingEnabled`).

8. **Optional parameters for nil-passing ObjC tests**: When ObjC tests intentionally pass `nil` for a parameter (using `#pragma clang diagnostic ignored "-Wnonnull"`), the Swift parameter type must be optional (`Type?`). Otherwise Swift will crash on nil receipt through the ObjC bridge.

## Pitfalls from Build Errors

1. **SFSDKReachability API mismatch**: The conversion used `.forInternetConnection()` (a static member access pattern) but the actual Swift API is `SFSDKReachability.reachabilityForInternetConnection()` (a class method). Always verify upstream API names against the actual Swift source, not the ObjC headers.

2. **Discardable result warning**: `startNotifier()` returns `Bool` without `@discardableResult`. Use `_ = reachability.startNotifier()` to suppress the unused result warning.

3. **Private vs public property name collision**: When translating ObjC properties with custom getters (e.g., `@property (getter=isLoggingEnabled) BOOL loggingEnabled`), avoid creating both a public `isLoggingEnabled` and a private `loggingEnabled` in Swift. Rename the private computed property (e.g., `effectiveLoggingEnabled`) to avoid collision.

## Rule Addenda for Phase 3+

- **Rule: Enum Case @objc Names**: For all `NS_ENUM` conversions, check the original ObjC case names. If they don't match the Swift auto-generated pattern (`TypeName` + `CaseName`), add explicit `@objc(OriginalCaseName)` to each case.

- **Rule: Test File Imports**: After converting production code, update all ObjC test files that import framework headers to use `@import Framework;` instead.

- **Rule: Null-Safety at ObjC Boundary**: Any parameter that existing ObjC tests pass as nil (even via suppressed warnings) must be declared optional in Swift. Check test files for `#pragma clang diagnostic ignored "-Wnonnull"` patterns.

- **Rule: SWIFT_VERSION**: Always set `SWIFT_VERSION = 5.0` in target build settings for all configurations (Debug + Release) of all targets (framework, test app, tests).

- **Rule: Verify Upstream APIs**: After conversion, grep for all calls to other libraries (SalesforceSDKCommon, etc.) and verify the method names match the actual Swift APIs, not assumed ObjC-to-Swift bridging names.
