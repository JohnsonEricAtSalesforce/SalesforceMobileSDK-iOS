# Test Conversion Lessons — Through SalesforceSDKCommon

## Cumulative API Migration Patterns

### SFLogger
| ObjC | Swift |
|------|-------|
| `[SFLogger loggerForComponent:name]` | `SFLogger.logger(forComponent: name)` |
| `[SFLogger setInstanceClass:cls]` | `SFLogger.setInstanceClass(cls)` |
| `[SFLogger clearAllComponents]` | `SFLogger.clearAllComponents()` (internal, needs @testable) |
| `TestLogger.logLevel` (class) | `SFLogger.logLevel` (static property) |
| `logger.logLevel` (instance) | `logger.level` (instance property) |
| `[logger d:cls format:fmt, args]` | `logger.d(cls, format: fmt, args...)` |
| `[logger i:cls format:fmt, args]` | `logger.i(cls, format: fmt, args...)` |
| `[logger e:cls format:fmt, args]` | `logger.e(cls, format: fmt, args...)` |
| `[logger f:cls format:fmt, args]` | `logger.f(cls, format: fmt, args...)` |
| `SFLogLevelDebug` | `.debug` |
| `SFLogLevelInfo` | `.info` |
| `SFLogLevelError` | `.error` |
| `SFLogLevelFault` | `.fault` |
| `SFLogLevelDefault` | `.default` |

### SFSDKSafeMutableArray
| ObjC | Swift |
|------|-------|
| `[SFSDKSafeMutableArray array]` | `SFSDKSafeMutableArray.array()` |
| `[SFSDKSafeMutableArray arrayWithCapacity:n]` | `SFSDKSafeMutableArray(capacity: n)` |
| `[array addObject:obj]` | `array.add(obj)` |
| `[array addObjectsFromArray:arr]` | `array.addObjects(from: arr)` |
| `[array insertObject:obj atIndex:i]` | `array.insert(obj, at: i)` |
| `[array insertObjects:objs atIndexes:idxs]` | `array.insert(objs, at: indexSet)` |
| `[array removeObject:obj]` | `array.remove(obj)` |
| `[array removeLastObject]` | `array.removeLastObject()` |
| `[array removeAllObjects]` | `array.removeAllObjects()` |
| `[array removeObjectIdenticalTo:obj]` | `array.removeObjectIdentical(to: obj)` |
| `[array containsObject:obj]` | `array.contains(obj)` |
| `array[idx]` | `array[idx]` (returns `Any?`) |
| `[array count]` / `array.count` | `array.count` |
| `[array enumerateObjectsUsingBlock:]` | `array.enumerateObjects { obj, idx, stop in }` |

### SFSDKSafeMutableDictionary
| ObjC | Swift |
|------|-------|
| `[[SFSDKSafeMutableDictionary alloc] init]` | `SFSDKSafeMutableDictionary<K, V>()` |
| `[dict setObject:obj forKey:key]` | `dict.setObject(obj, forKey: key)` |
| `[dict objectForKey:key]` | `dict.object(forKey: key)` |
| `[dict removeObjectForKey:key]` | `dict.removeObject(key)` |
| `[dict removeAllObjects]` | `dict.removeAllObjects()` |

### SFSDKSafeMutableSet
| ObjC | Swift |
|------|-------|
| `[SFSDKSafeMutableSet set]` | `SFSDKSafeMutableSet.set()` |
| `[set addObject:obj]` | `set.add(obj)` |
| `[set removeObject:obj]` | `set.remove(obj)` |
| `[set removeAllObjects]` | `set.removeAllObjects()` |
| `[set containsObject:obj]` | `set.contains(obj)` |
| `[set anyObject]` | `set.anyObject()` |
| `[set count]` / `set.count` | `set.count` |

### General Patterns
| ObjC | Swift |
|------|-------|
| `@import XCTest` | `import XCTest` |
| `#import "Foo.h"` | (not needed, use @testable import) |
| `@testable @import Module` | `@testable import Module` |
| `dispatch_group_create()` | `DispatchGroup()` |
| `dispatch_group_async(g, q, ^{})` | `group.enter(); queue.async { ...; group.leave() }` |
| `dispatch_group_wait(g, FOREVER)` | `group.wait()` |
| `dispatch_get_global_queue(PRI, 0)` | `DispatchQueue.global(qos: .default)` |
| `NSMakeRange(loc, len)` | `IndexSet(integersIn: loc..<loc+len)` |
| `[NSNumber numberWithInt:n]` | `NSNumber(value: n)` |
| `arc4random_uniform(n)` | `arc4random_uniform(n)` (same) |

## Conversion Pitfalls Discovered
1. **SFLogger private init**: Cannot subclass SFLogger in Swift tests. Use `SFLogger.logger(forComponent:)` directly with custom `SFLogging` implementation via `setInstanceClass`.
2. **Instance vs class property naming**: ObjC `logLevel` on both instance and class maps to `level` (instance) vs `logLevel` (class) in Swift.
3. **Array subscript returns optional**: `SFSDKSafeMutableArray[idx]` returns `Any?` in Swift, requires optional handling.
4. **Generic type parameters**: `SFSDKSafeMutableDictionary` requires explicit `<KeyType, ObjectType>` in Swift.
5. **dispatch_group pattern**: ObjC `dispatch_group_async` combines enter+leave implicitly; Swift requires explicit `group.enter()`/`group.leave()` or a different pattern.

## Swift Idiom Preferences
- Use `final class` for test classes (matches existing project style)
- Use `@testable import SalesforceSDKCommon` (not module-qualified)
- Use `XCTestExpectation` + `wait(for:timeout:)` for async tests
- Use `NotificationCenter.default.addObserver(forName:)` returning token, then remove explicitly
- Prefer `for input in inputs` over `inputs.enumerated().forEach`
- Use trailing closure syntax for dispatch blocks

## Compiler-Discovered Corrections
None required. All 4 files compiled successfully on first attempt.

## Test-Failure Patterns
None. All 20 converted tests passed on first run.

## Xcode Project Notes
- pbxproj file is at: `libs/SalesforceSDKCommon/SalesforceSDKCommon.xcodeproj/project.pbxproj`
- Each .m file has 3 references to update: PBXBuildFile, PBXFileReference, PBXGroup children
- Each .m file in Sources build phase has a separate reference (PBXBuildFile "X in Sources")
- No bridging header needed (already empty string in build settings)
- Scheme for testing: `SalesforceSDKCommon` (runs against SalesforceSDKCommonTestApp host)
- Build/test uses `-project` flag since this is a standalone .xcodeproj, not workspace-level

## Permission Gaps
None encountered. All operations completed without issue.
