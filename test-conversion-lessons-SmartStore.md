# Test Conversion Lessons — Through SmartStore

## Cumulative API Migration Patterns

### UserAccountManager
| ObjC | Swift |
|------|-------|
| `[SFUserAccountManager sharedInstance]` | `UserAccountManager.shared` |
| `saveAccountForUser:error:` | `try UserAccountManager.shared.upsert(user)` |
| `deleteAccountForUser:error:` | `try UserAccountManager.shared.delete(user)` |
| `setCurrentUserInternal:` | `UserAccountManager.shared.currentUserAccount = user` |
| `SFUserAccountLoginStateLoggedIn` | `.loggedIn` |
| `oauthClientId` | `oauthClientID` (capital I and D) |

### SmartStore
| ObjC | Swift |
|------|-------|
| `SFSmartStore` | `SmartStore` |
| `SFSoupIndex` | `SoupIndex` |
| `SFQuerySpec` | `QuerySpec` |
| `SFStoreCursor` | `StoreCursor` |
| `SFSmartStoreDatabaseManager` | `DatabaseManager` |
| `SFSmartSqlHelper` | `SmartSqlHelper` with `.shared` |
| `SFSmartSqlCache` | `SmartSqlCache` |
| `[SFSmartStore sharedStoreWithName:]` | `SmartStore.shared(withName:)` (returns optional) |
| `[SFSmartStore sharedGlobalStoreWithName:]` | `SmartStore.sharedGlobal(withName:)` |
| `removeSharedStoreWithName:` | `SmartStore.removeShared(withName:)` |
| `removeAllStores` | `SmartStore.removeAllForCurrentUser()` |
| `removeAllGlobalStores` | `SmartStore.removeAllGlobal()` |
| `soupExists:` | `store.soupExists(forName:)` |
| `registerSoup:withIndexSpecs:error:` | `try store.registerSoup(withName:withIndices:)` |
| `upsertEntries:toSoup:` | `store.upsert(entries:forSoupNamed:)` |
| `queryWithQuerySpec:pageIndex:error:` | `try store.query(using:startingFromPageIndex:)` |
| `removeEntries:fromSoup:error:` | `try store.remove(entryIds:forSoupNamed:)` |
| `removeEntriesByQuery:fromSoup:error:` | `try store.removeEntries(usingQuerySpec:forSoupNamed:)` |
| `captureExplainQueryPlan` | `capturesExplainQueryPlan` (note the 's') |
| `convertSmartSql:` | `store.convertSmartSql(_:)` returns `String?` |
| `count(using:)` | returns `NSNumber` (throws) |
| `asArraySoupIndexes:` | `SoupIndex.asArray(_:)` (NOT `asArraySoupIndexes`) |
| `kSFSoupQuerySortOrderAscending` | `.ascending` |
| `kSFSoupQuerySortOrderDescending` | `.descending` |

### QuerySpec Factory Methods
| ObjC | Swift |
|------|-------|
| `newAllQuerySpec:` | `QuerySpec.buildAllQuerySpec(soupName:...)` |
| `newSmartQuerySpec:smartSql:withPageSize:` | `QuerySpec.buildSmartQuerySpec(smartSql:pageSize:)` |

### SmartStore Enums
| ObjC | Swift |
|------|-------|
| `SmartStoreFtsExtension` | `.fts4` (rawValue 4), `.fts5` (rawValue 5) |
| `AlterSoupStep` | `.starting`, `.renameOldSoupTable`, `.dropOldIndexes`, etc. |

## Conversion Pitfalls Discovered

1. **UserAccountManager.shared.upsert() silently fails** when `userAccountMap` is nil. MUST call `try? UserAccountManager.shared.loadAccounts()` BEFORE calling `upsert()`. This was the #1 source of test crashes in SmartStore.
2. **SoupIndex.asArray() is the Swift name** — `asArraySoupIndexes:` is only the ObjC selector, not callable from Swift.
3. **FMDatabase.intForQuery** doesn't exist in the Swift FMDB package — use `executeQuery` instead.
4. **convertSmartSql throws NSException** for non-SELECT queries in Swift (was nil return in ObjC). Tests can't use XCTAssertNil for these.
5. **SFSmartSqlHelper.swift line 160** had `\\(path)` instead of `\(path)` — a production bug causing literal `\(path)` in SQL. Fixed.
6. **"Fatal access conflict detected"** crashes in production SmartStore code when tests exercise `storeQueue.inDatabase` patterns. This is a Swift exclusive access violation from the framework migration, NOT from test conversion. Affects SFSmartStoreAlterTests, SFSmartStoreLoadTests, and some SFSmartStoreTests.

## Swift Idiom Preferences
- Use `final class` for test classes (except base classes like SFSmartStoreTestCase)
- Use `@testable import SmartStore`, `import SalesforceSDKCore`, `import FMDB`
- Properties set in setUp: `private var store: SmartStore!` (implicitly unwrapped)
- `XCTAssertEqualObjects(a, nil)` → `XCTAssertNil(a)`

## Compiler-Discovered Corrections
- `SoupIndex.asArraySoupIndexes` → `SoupIndex.asArray` (ObjC selector not accessible from Swift)
- Optional unwrapping needed for `soupIndex.columnName`
- `FMDatabase.intForQuery` replaced with `executeQuery` + manual extraction
- `SWIFT_VERSION = 5.0` must be added to ObjC-only TestApp targets

## Test-Failure Patterns
- UserAccountManager needs `loadAccounts()` before `upsert()` — without it, user stores are nil
- Production SmartStore code has "Fatal access conflict" in storeQueue closures — these crash tests at runtime but are NOT test conversion issues
- Performance test `testCleanupRegexpFaster` needed relaxed assertions due to truncated test string

## Xcode Project Notes
- pbxproj has 4 places per file: PBXBuildFile, PBXFileReference, PBXGroup children, PBXSourcesBuildPhase
- SmartStoreTests target links FMDB directly — keep this, the duplicate class warnings are harmless
- ObjC-only TestApp targets need `SWIFT_VERSION = 5.0` added to build settings
- Some test files may need new PBXFileReference + PBXBuildFile entries if they weren't in the project before

## Permission Gaps
None encountered.
