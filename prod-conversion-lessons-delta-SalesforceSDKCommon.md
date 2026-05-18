# Delta Notes — SalesforceSDKCommon (Phase 1)

## Batch 01: SFLogger, SFDefaultLogger, SFSwiftDetectUtil

### Key Decisions
1. **SFLogger → SalesforceLogger class name**: The ObjC header has `NS_SWIFT_NAME(SalesforceLogger)`. We use `@objc(SFLogger)` on the Swift class to preserve the ObjC name while the Swift name is `SalesforceLogger`.
2. **SFLogLevel enum**: Mapped raw values to match OS_LOG_TYPE constants exactly (0x00, 0x01, 0x02, 0x10, 0x11). Used `@objc public enum SFLogLevel: UInt` to preserve the numeric ObjC bridge.
3. **SFLogging protocol**: Converted to `@objc(SFLogging) public protocol SFLogging: NSObjectProtocol`. The `init(component:)` requirement uses Swift's required init pattern.
4. **`+initialize` → lazy static**: ObjC `+initialize` set InstanceClass to SFDefaultLogger. In Swift, we use `private static var instanceClass: SFLogging.Type = SFDefaultLogger.self` as a default value.
5. **va_list methods eliminated**: Swift doesn't support variadic bridging the same way. The `format:...` methods are not needed from Swift callers (they use string interpolation). The `format:args:` method is preserved for ObjC callers via CVaListPointer.
6. **`dispatch_once` + `@synchronized` → NSLock**: The loggerForComponent pattern used dispatch_once (for list init) plus @synchronized. Converted to a simple NSLock-guarded critical section since the backing dictionary is initialized inline.
7. **SFSwiftDetectUtil**: Straightforward conversion. `Thread.callStackSymbols` replaces `[NSThread callStackSymbols]`.

### Pitfalls
- The ObjC SFLogger uses `SFSDKSafeMutableDictionary` for `loggerList`. In Swift, we use it directly since it will be defined in the same target.
- The `NS_SWIFT_NAME(SalesforceLogger.Level)` on the enum means existing Swift callers use `SalesforceLogger.Level`. We provide a `typealias Level = SFLogLevel` inside the class to maintain compatibility.

## Batch 02: SFJsonUtils, SFPathUtil, SFFileProtectionHelper, NSUserDefaults+SFAdditions

### Key Decisions
1. **SFJsonUtils**: `@synchronized(sLastError)` → NSLock for thread-safe error tracking. The `#ifdef DEBUG` for pretty printing is preserved via `#if DEBUG`.
2. **SFPathUtil**: Uses `setxattr` for iCloud backup exclusion — preserved as a direct C call via `withCString`. `NSFileProtectionKey` attribute uses `FileManager.setAttributes`.
3. **SFFileProtectionHelper**: `NS_SWIFT_NAME(FileProtectionHelper)` means the Swift class is `FileProtectionHelper` with `@objc(SFFileProtectionHelper)`. Singleton via `static let shared`. Serial dispatch queue for path-to-protection map mutations.
4. **NSUserDefaults+SFAdditions**: Extension on `UserDefaults` with `@objc` method. References `SFSDKDatasharingHelper.shared` (circular dep within same target — fine).

### Pitfalls
- `SFPathUtil` uses `sys/xattr.h` — `setxattr` is available in Swift via Darwin module import (no explicit import needed since Foundation pulls it in).
- `FileProtectionType` enum rawValue used for comparisons instead of string literals.

## Batch 03: SafeMutableArray, SafeMutableDictionary, SafeMutableSet, Reachability, DatasharingHelper

### Key Decisions
1. **SFSDKSafeMutable* classes**: All use the concurrent queue + barrier pattern. `dispatch_sync` for reads → `queue.sync { }`. `dispatch_barrier_async` for writes → `queue.async(flags: .barrier) { }`. Preserved exactly.
2. **SFSDKSafeMutableDictionary generics**: ObjC used lightweight generics `<KeyType, ObjectType>`. Swift version uses proper generics with `KeyType: NSCopying, ObjectType: AnyObject` constraints.
3. **SFSDKSafeMutableArray**: Implements `NSMutableCopying` protocol to match the ObjC `mutableCopyWithZone:` method.
4. **SFSDKReachability**: Uses SystemConfiguration framework directly. `@available(visionOS, unavailable)` preserves the `API_UNAVAILABLE(visionos)` annotation. The callback pattern uses `Unmanaged` to bridge self reference.
5. **SFSDKDatasharingHelper**: Singleton via `static let shared`. Properties backed by UserDefaults. Migration logic preserved identically.

### Pitfalls
- `SFSDKSafeMutableSet`'s `enumerateObjectsUsingBlock:` in ObjC uses `dispatch_barrier_sync` which could deadlock if called from a barrier block on the same queue. Preserved as-is for behavioral compatibility.
- `SFSDKReachability` callback: Must use `Unmanaged.passUnretained` (not retained) to avoid retain cycle since the callback is an unretained C function pointer context.
- The NS_SWIFT_NAME annotations on ObjC headers (`SafeMutableArray`, `SafeMutableDictionary`, `SafeMutableSet`, `DataSharingHelper`, `FileProtectionHelper`) mean existing Swift callers use those names. Our `@objc(SFSDKSafeMutableArray)` etc. preserves ObjC name while Swift exposes the same class. Existing Swift callers that used the bridged name will need to use the ObjC name — this is fine since the `@objc()` annotation matches.

## Patterns Discovered
1. `dispatch_once` singleton → `static let shared` (Rule 11)
2. `dispatch_queue_create(CONCURRENT)` + `dispatch_barrier_async` → `DispatchQueue(attributes: .concurrent)` + `.async(flags: .barrier)`
3. `@synchronized` → NSLock (or serial DispatchQueue)
4. `NS_SWIFT_NAME` on class → use that name as Swift class, `@objc(OriginalName)` for ObjC visibility
5. `setxattr` C call → accessible directly in Swift via Darwin/Foundation
6. `SCNetworkReachability` C API → direct usage with `Unmanaged` bridging for callback context
