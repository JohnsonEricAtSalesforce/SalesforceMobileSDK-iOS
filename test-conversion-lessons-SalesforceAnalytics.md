# Cumulative Test Conversion Lessons - Through Phase 2 (SalesforceAnalytics)

## Phase 1 Lessons (SalesforceSDKCommon)
- Use `final class` for test classes
- Use `@testable import ModuleName`
- `dispatch_group_async` -> explicit `group.enter()/leave()` pattern
- `NSMakeRange(loc, len)` -> `IndexSet(integersIn: loc..<loc+len)`
- `[NSNumber numberWithInt:n]` -> `NSNumber(value: n)`
- pbxproj has 3 references per .m file: PBXBuildFile, PBXFileReference, PBXGroup children
- No bridging headers needed for these test targets
- Each library has its own .xcodeproj at `libs/LIBRARY/LIBRARY.xcodeproj/project.pbxproj`

## Phase 2 Lessons (SalesforceAnalytics)

### API Mappings
- `self.storeManager.loggingEnabled` (ObjC) -> `storeManager.isLoggingEnabled` (Swift property)
- `SchemaTypeError` -> `SFASchemaType.error`
- `EventTypeSystem` -> `SFAEventType.system`
- `ErrorTypeWarn` -> `SFAErrorType.warn`
- `buildEventWithBuilderBlock:analyticsManager:` -> `buildEvent(withBuilderBlock:analyticsManager:)`
- Builder `startTime` is `Int`, not `double`/`NSTimeInterval`
- `storeEvent:` -> `storeEvent(_:)` (takes optional)
- `fetchAllEvents` returns `[SFSDKInstrumentationEvent]?` (optional array)
- `deleteEvent:` returns `@discardableResult Bool`
- `DataEncryptorBlock` / `DataDecryptorBlock` typealiases for `(Data?) -> Data?`

### pbxproj Critical Lessons
- CRITICAL: When replacing PBXBuildFile entries, MUST ALSO update PBXSourcesBuildPhase `files` arrays
- There are actually 4 places per source file:
  1. PBXBuildFile section (build file entry)
  2. PBXFileReference section (file ref entry)
  3. PBXGroup children (group membership)
  4. PBXSourcesBuildPhase files (which build file IDs to compile)
- First attempt had stale IDs in PBXSourcesBuildPhase causing 0 test discovery

### Test App Patterns
- `@main` on AppDelegate replaces both `main.m` and `AppDelegate.h`
- No separate `main.swift` needed with `@main` attribute
- Remove Supporting Files group entry for main.m

### Testing Patterns
- Swift non-optional parameters prevent testing nil-param scenarios directly
- `Double.nan` produces invalid JSON, useful for testing JSON validation paths
- `SFSDKInstrumentationEvent` conforms to NSCopying: `event?.copy() as? SFSDKInstrumentationEvent`
- Identity check: `===` operator (reference equality) vs `==` (value equality via isEqual)
- ObjC `XCTAssertEqualObjects(a, nil)` -> Swift `XCTAssertNil(a)`
- ObjC `XCTAssertTrue(a != nil)` -> Swift `XCTAssertNotNil(a)`

## General Patterns (Both Phases)
- Always use `final class` for XCTestCase subclasses
- Always use `@testable import ModuleName`
- Properties should be `private var` with `!` (implicitly unwrapped) when set in setUp
- ObjC `static NSString * const` -> Swift `private let` at file scope
- String format: `[NSString stringWithFormat:]` -> `String(format:)`
- `NSSearchPathForDirectoriesInDomains` works the same in Swift
- `(path as NSString).appendingPathComponent()` for path manipulation
- CharacterSet for string filtering works identically
