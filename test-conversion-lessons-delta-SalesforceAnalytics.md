# Delta Lessons - SalesforceAnalytics (Phase 2)

## New API Mappings Discovered
- `self.storeManager.loggingEnabled` in ObjC -> `storeManager.isLoggingEnabled` in Swift (property name difference)
- `SchemaTypeError` -> `SFASchemaType.error` (enum is `SFASchemaType`, not `SchemaType`)
- `EventTypeSystem` -> `SFAEventType.system` (enum is `SFAEventType`, not `EventType`)
- `ErrorTypeWarn` -> `SFAErrorType.warn` (enum is `SFAErrorType`, not `ErrorType`)
- `buildEventWithBuilderBlock:analyticsManager:` -> `buildEvent(withBuilderBlock:analyticsManager:)`
- Builder `startTime` is `Int`, not `double`/`NSTimeInterval`
- `storeEvent:` -> `storeEvent(_:)` (takes optional)
- `fetchAllEvents` returns `[SFSDKInstrumentationEvent]?` (optional array)
- `deleteEvent:` returns `Bool` (discardable result)
- `NSNull` key invalid JSON test -> `Double.nan` value invalid JSON (equivalent behavior)
- `DataEncryptorBlock` / `DataDecryptorBlock` are typealiases for `(Data?) -> Data?`

## pbxproj Lessons
- CRITICAL: When replacing PBXBuildFile entries with new IDs, you must ALSO update the PBXSourcesBuildPhase `files` array that references those build file IDs. The build file section and the sources phase both need updating.
- The first build used stale IDs in PBXSourcesBuildPhase which caused 0 test discovery.

## Test App Patterns
- `@main` on AppDelegate replaces both `main.m` and the `AppDelegate.h` header
- No separate `main.swift` file needed when using `@main` attribute
- Remove the Supporting Files group entry for main.m when converting to Swift

## Testing Observations
- Test for missing device app attributes cannot be directly replicated in Swift since `SFSDKAnalyticsManager.init` requires a non-optional `deviceAttributes` parameter - adapted test to verify positive case
- `Double.nan` produces invalid JSON (JSONSerialization.isValidJSONObject returns false), equivalent to NSNull-as-key behavior in ObjC
- `SFSDKInstrumentationEvent` conforms to NSCopying; use `event?.copy() as? SFSDKInstrumentationEvent`
- Identity comparison for objects: `===` instead of `XCTAssertNotEqual` with pointer semantics
