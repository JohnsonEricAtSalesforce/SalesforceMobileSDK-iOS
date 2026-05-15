# SmartStore Test Conversion Delta Lessons

## Batch 03 (TestApp + Base Class)
- `@main` on `AppDelegate` replaces both `main.m` and `AppDelegate.h`
- `SFSmartStoreTestCase` is a base class (not `final class`) - subclasses inherit from it
- `[SFUserAccountManager sharedInstance]` -> `UserAccountManager.shared`
- `saveAccountForUser:error:` -> `try UserAccountManager.shared.upsert(user)`
- `deleteAccountForUser:error:` -> `try UserAccountManager.shared.delete(user)`
- `setCurrentUserInternal:` is private -> use `UserAccountManager.shared.currentUserAccount = user`
- `SFUserAccountLoginStateLoggedIn` -> `.loggedIn`
- `oauthClientId` -> `oauthClientID` (capital I and D)
- `SFSoupIndex` class is now `SoupIndex` in Swift
- `kValueExtractedToColumn` and `kValueExtractedToFtsColumn` are closures of type `(SoupIndex) -> Bool`
- `SFJsonUtils.projectIntoJson(_:path:)` takes `[String: Any]` not `NSDictionary`

## Batch 04 (SFSmartStoreTests + SFQuerySpecTests)
- `SFQuerySpec` class is now `QuerySpec` in Swift
- Factory methods: `newAllQuerySpec:` -> `QuerySpec.buildAllQuerySpec(soupName:...)`
- `kSFSoupQuerySortOrderAscending` -> `.ascending`, `kSFSoupQuerySortOrderDescending` -> `.descending`
- `[store soupExists:name]` -> `store.soupExists(forName: name)`
- `[store registerSoup:name withIndexSpecs:specs error:&error]` -> `try store.registerSoup(withName: name, withIndices: specs)`
- `[store upsertEntries:entries toSoup:name]` -> `store.upsert(entries: entries, forSoupNamed: name)`
- `[store queryWithQuerySpec:spec pageIndex:0 error:nil]` -> `try store.query(using: spec, startingFromPageIndex: 0)`
- `[store removeEntries:ids fromSoup:name error:&error]` -> `try store.remove(entryIds: ids, forSoupNamed: name)`
- `[store removeEntriesByQuery:spec fromSoup:name error:&error]` -> `try store.removeEntries(usingQuerySpec: spec, forSoupNamed: name)`
- `captureExplainQueryPlan` -> `capturesExplainQueryPlan` (note the 's')
- `SFSmartStore.shared(withName:)` returns optional
- `SmartStore.removeShared(withName:)` and `SmartStore.removeSharedGlobal(withName:)`
- `SmartStore.clearSharedStoreMemoryState()` 
- `SFStoreCursor` -> `StoreCursor`
- `StoreCursor.getDataSerialized(_:)` throws
- `SFSmartStoreDatabaseManager` -> `DatabaseManager`
- `DatabaseManager.sharedManager()` returns optional, `DatabaseManager.sharedGlobalManager()` is non-optional
- `SmartStore.string(from:)` for InputStream reading
- `SmartStore.jsonSerializationCheckEnabled` is a class property
- `kSFSmartStoreJSONParseErrorNotification` is a string constant
- `qualifyMatchKey(_:field:)` - field parameter is non-optional String (use "" for nil)
- `[SFQuerySpec newSmartQuerySpec:smartSql withPageSize:n]` -> `QuerySpec.buildSmartQuerySpec(smartSql:pageSize:)`
- `QuerySpec(querySpec:targetSoupName:)` is the dictionary initializer (failable)

## Batch 05 (SFSmartSqlTests + SFSmartSqlCacheTests)
- `SFSmartSqlHelper` -> `SmartSqlHelper` with `.shared` static property
- `[store convertSmartSql:]` -> `store.convertSmartSql(_:)` returns `String?`
- `SFSmartSqlCache` -> `SmartSqlCache`
- `SmartSqlCache(countLimit:)` initializer
- `cache.setSql(_:forSmartSql:)` and `cache.sql(forSmartSql:)` (returns String?)
- `cache.removeEntries(forSoup:)` 
- `SmartStore.shared(withName:forUserAccount:)` for user-specific stores
- `store.count(using:)` returns `NSNumber` (throws)
- `store.query(using:startingFromPageIndex:whereArgs:)` for where args variant

## Remaining API Mappings (for Batch 05-06 completion)
- `SFAlterSoupLongOperation` -> likely `AlterSoupLongOperation` 
- `SFAlterSoupStep` enum values
- `[store alterSoup:withIndexSpecs:reIndexData:]` 
- `[store getLongOperations]`
- `[store resumeLongOperations]`
- `[store queryTable:forColumns:orderBy:limit:whereClause:whereArgs:withDb:]`
- `SmartStoreFtsExtension` enum: `.fts4`, `.fts5`
- `store.ftsExtension` property
- `SmartStoreSDKManager` class
- `SFSDKStoreConfig` -> `StoreConfig`
