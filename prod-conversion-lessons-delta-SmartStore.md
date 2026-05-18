# SmartStore Conversion Lessons Delta

## Batch 08: SFSmartStoreDatabaseManager + Internal.h

- `SFSmartStoreDatabaseManager+Internal.h` methods mapped to `internal` access on the Swift class.
- `@synchronized(self)` on class methods replaced with a private static `NSLock` (`managerLock`).
- `dispatch_once` global manager pattern simplified to a lazy static with lock protection.
- `NSError **` out-params converted to `throws`; the encrypt/unencrypt methods return the DB on success or throw on failure.
- `SFDirectoryManager.ensureDirectoryExists:error:` called via try/catch.
- `NSFileProtectionKey` attributes use `FileManager.setAttributes` with `.protectionKey`.
- `FMDatabaseQueue` init returns optional in Swift -- guarded with `guard let`.
- The `verifyDatabaseAccess` class method uses `@discardableResult` since callers sometimes only care about the throw, not the Bool.
- The fix-for-12-bug helper remains private; it's called internally before opening the queue.

## Batch 09: SFSmartSqlHelper, SFSmartSqlCache, SFAlterSoupLongOperation, SFSmartStoreInspectorViewController, SmartStoreSDKManager

### SFSmartSqlHelper
- Static regex compilation uses lazy `static let` closures (replacing `dispatch_once`).
- Singleton via `static let shared` (naturally dispatch_once in Swift).
- `NSRegularExpression` `rangeOfFirstMatchInString` and `replaceMatchesInString` work on `NSMutableString` -- kept as `NSMutableString` for the mutable SQL buffer.
- Character comparison at `position-1` for dot-qualification preserved using `NSString.character(at:)`.

### SFSmartSqlCache
- `NSCache<NSString, NSString>` retained for thread-safe caching.
- Keys tracked with a `Set<String>` protected by `NSLock` since NSCache eviction delegate fires on arbitrary threads.
- `NSCacheDelegate` `willEvictObject` receives the evicted *value*, not key -- note: original ObjC code had the same semantic mismatch (removing obj from keys set). Preserved as-is for fidelity.

### SFAlterSoupLongOperation
- Switch-case fallthrough pattern preserved with explicit `fallthrough` in Swift.
- Static constants for detail keys (`SOUP_NAME`, `SOUP_TABLE_NAME`, etc.) moved to file-private scope to avoid polluting the module namespace (they conflicted with `SFSmartStore.swift` internal constants).
- `rowId` typed as `Int64` to match `db.lastInsertRowId`.

### SFSmartStoreInspectorViewController
- UIKit class with heavy programmatic layout. All IBAction equivalents are `@objc` methods.
- UIPickerView delegate/datasource implemented on the VC itself.
- `UIColor` extension helpers (`salesforceBlueColor`, etc.) bridged via a private extension.
- `results` property observer triggers `reloadData` on main queue.
- The `SFQuerySpec.newSmartQuerySpec:withPageSize:` factory call replaced with `QuerySpec.buildSmartQuerySpec(smartSql:pageSize:)` matching the already-converted QuerySpec.swift API.

### SmartStoreSDKManager
- Subclasses `SalesforceSDKManager` (ObjC class from SalesforceSDKCore) -- Swift subclassing ObjC works cleanly.
- `@dynamic sharedManager` replaced by inheriting the superclass property.
- `kSFNotificationUserWillLogout` and `kSFNotificationUserInfoAccountKey` used directly from SalesforceSDKCore ObjC constants.
- `SFSDKDevAction` instantiation uses the Swift-visible initializer.
- `open class` used because MobileSyncSDKManager subclasses this.
