# Test Conversion Delta Notes — SalesforceSDKCommon

## Files Converted
1. SFLoggerTests.m -> SFLoggerTests.swift
2. SFSDKSafeMutableArrayTests.m -> SFSDKSafeMutableArrayTests.swift
3. SFSDKSafeMutableDictionaryTests.m -> SFSDKSafeMutableDictionaryTests.swift
4. SFSDKSafeMutableSetTests.m -> SFSDKSafeMutableSetTests.swift

## Key Conversion Decisions

### SFLoggerTests
- ObjC test used a `TestLogger` subclass of `SFLogger` with a custom `sharedInstance`. Since Swift `SFLogger` has a private initializer making subclassing impossible, we use `SFLogger.logger(forComponent:)` directly instead.
- The ObjC `logger.logLevel` instance property maps to `logger.level` in Swift (the instance property is named `level`).
- The class-level `SFLogger.logLevel` static property remains `SFLogger.logLevel`.
- `TestLoggingImpl` (custom `SFLogging` conformance) was simplified — no need for `@dynamic` or manual synthesis.
- Variadic ObjC `[logger d:cls format:@"...", arg]` maps to Swift `logger.d(cls, format: "...", arg)` (non-@objc variadic method).
- `SFLogger.clearAllComponents()` is `internal` and accessible via `@testable import`.
- Notification observer pattern changed from ObjC block-based `addObserverForName:` to Swift `addObserver(forName:)` with explicit removal.

### SFSDKSafeMutableArrayTests
- `[SFSDKSafeMutableArray array]` -> `SFSDKSafeMutableArray.array()`
- `[array addObject:]` -> `array.add(_:)`
- `[array removeObject:]` -> `array.remove(_:)`
- `[array containsObject:]` -> `array.contains(_:)`
- `array[idx]` subscript returns `Any?` in Swift (optional).
- `[array enumerateObjectsUsingBlock:]` -> `array.enumerateObjects { obj, idx, stop in }`
- `[array insertObjects:atIndexes:]` -> `array.insert(_:at:)` with `IndexSet`
- `[array removeObjectIdenticalTo:]` -> `array.removeObjectIdentical(to:)`
- `dispatch_group_t` + `dispatch_group_async` -> `DispatchGroup` + `group.enter()/leave()` pattern

### SFSDKSafeMutableDictionaryTests
- Generic type: `SFSDKSafeMutableDictionary<NSString, NSNumber>` requires explicit type parameters
- `[dict setObject:forKey:]` -> `dict.setObject(_:forKey:)`
- `[dict objectForKey:]` -> `dict.object(forKey:)`

### SFSDKSafeMutableSetTests
- `[SFSDKSafeMutableSet set]` -> `SFSDKSafeMutableSet.set()`
- `[set addObject:]` -> `set.add(_:)`
- `[set removeObject:]` -> `set.remove(_:)`
- `[set containsObject:]` -> `set.contains(_:)`
- `[set anyObject]` -> `set.anyObject()`

## No Compilation Errors
All 4 files compiled successfully on first attempt.

## No Test Failures
All 40 tests (including 20 from our converted files) passed on first attempt.
