# Pattern Registry

| # | ObjC Pattern | Swift Pattern | Rule | Discovered | Verified | Notes |
|---|-------------|--------------|------|-----------|----------|-------|
| 1 | `dispatch_once` singleton | `static let shared = Foo()` | 11 | Batch 01 | Provisional | FileProtectionHelper, DatasharingHelper, SalesforceLogger |
| 2 | `dispatch_queue_create(CONCURRENT)` + `dispatch_barrier_async` | `DispatchQueue(attributes: .concurrent)` + `.async(flags: .barrier)` | 26 | Batch 03 | Provisional | SafeMutableArray, SafeMutableDictionary, SafeMutableSet |
| 3 | `@synchronized(obj)` | `NSLock` lock/unlock with defer | - | Batch 01 | Provisional | SFJsonUtils, SalesforceLogger |
| 4 | `NS_SWIFT_NAME(SwiftName)` on `@interface` | Swift class name = SwiftName, `@objc(ObjCName)` | - | Batch 01 | Provisional | SalesforceLogger, FileProtectionHelper, DataSharingHelper |
| 5 | `setxattr` iCloud backup exclusion | Direct C call via `withCString` closure | - | Batch 02 | Provisional | SFPathUtil |
| 6 | `SCNetworkReachability` callback with `void* info` | `Unmanaged.passUnretained(self).toOpaque()` + `fromOpaque` | - | Batch 03 | Provisional | SFSDKReachability |
| 7 | `NS_ENUM(NSUInteger, Foo)` with custom raw values | `@objc public enum Foo: UInt` with explicit case values | 9 | Batch 01 | Verified | SFLogLevel, SFASchemaType, SFAEventType, SFAErrorType |
| 8 | `+initialize` setting class var | Inline default value on static property | - | Batch 01 | Provisional | SalesforceLogger.instanceClass |
| 9 | `NS_ENUM` with non-prefixed case names | `@objc(CaseName)` on each Swift enum case | - | Batch 04 | Verified | SFASchemaType, SFAEventType, SFAErrorType |
| 10 | `@property (getter=isX) BOOL x` | `var x: Bool` (keep property name, not getter name) | - | Batch 04 | Verified | SFSDKEventStoreManager.loggingEnabled |
| 11 | ObjC test `#import <Framework/Header.h>` | `@import Framework;` after Swift conversion | - | Batch 04 | Verified | EventStoreManagerTests, InstrumentationEventBuilderTests |
| 12 | `NS_FORMAT_FUNCTION` varargs | Swift-only variadic (no `@objc`), plus `@objc` message overload | - | Batch 04 | Verified | SFSDKAnalyticsLogger format vs message methods |
| 13 | ObjC nil-passing via suppressed nonnull warning | Parameter must be `Type?` in Swift | - | Batch 04 | Verified | SFSDKAnalyticsManager.deviceAttributes |
| 14 | `NSSecureCoding` / `NSCoding` conformance | Protocol conformance with `required init(coder:)` and `encode(with:)` | 15 | Batch 04 | Verified | SFSDKInstrumentationEvent, SFSDKDeviceAppAttributes |
