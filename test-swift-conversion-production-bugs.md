# Production Code Bugs Identified During ObjC→Swift Test Conversion

**Date:** 2026-05-14
**Context:** These bugs were discovered while converting 98 ObjC test files to Swift. They are all in production code that was migrated from ObjC to Swift in the bulk framework migration (commit `58a0af75d`). None of these bugs were introduced by the test conversion itself.

---

## Bug 1: SmartSqlHelper — Broken String Interpolation in SQL Generation

**Severity:** High — produces incorrect SQL at runtime
**Status:** Unfixed (fix was applied and then reverted)
**File:** `libs/SmartStore/SmartStore/Classes/SFSmartSqlHelper.swift:160`

### Description
When converting Smart SQL for non-indexed columns, the code generates `json_extract(soup, '$.\\(path)')` instead of `json_extract(soup, '$.\(path)')`. The double backslash `\\` escapes the backslash character, making `\(path)` a literal string instead of Swift string interpolation. This means any Smart SQL query referencing a non-indexed column produces the literal text `\(path)` in the SQL instead of the actual field path.

### Current code
```swift
columnName = "json_extract(soup, '$.\\(path)')"
```

### Correct code
```swift
columnName = "json_extract(soup, '$.\(path)')"
```

### How it was discovered
`SFSmartSqlTests.testConvertSmartSqlForNonIndexedColumns` — the test expected the interpolated path but got the literal `\(path)`.

### Impact
Any SmartStore query that references a non-indexed field via Smart SQL will produce incorrect results or errors. Queries on indexed fields are unaffected (they use a different code path at line 162).

---

## Bug 2: SmartStore — Swift Exclusive Access Violation in `inTransaction`/`inDatabase`

**Severity:** High — crashes at runtime, affects ~46 tests
**Status:** Unfixed — root cause identified, fix verified in analysis
**Files:**
- `libs/SmartStore/SmartStore/Classes/SFSmartStore.swift:1322-1337` (`inDatabase`)
- `libs/SmartStore/SmartStore/Classes/SFSmartStore.swift:1340-1357` (`inTransaction`)

### Description
The `inDatabase(_:error:)` and `inTransaction(_:error:)` methods take an `inout NSError?` parameter. Inside each method, an `@escaping` closure is passed to `_storeQueue.inDatabase`/`_storeQueue.inTransaction` (FMDatabaseQueue). That closure captures the `inout error` parameter to write to it in the `catch` block.

Swift's exclusivity enforcement sees this as overlapping access: the function holds an exclusive access to `error` for its entire scope, and the escaping closure also accesses `error`. Even though `FMDatabaseQueue` dispatches synchronously (so the accesses don't actually overlap in time), the closure is marked `@escaping`, which triggers the runtime exclusivity check.

### Original ObjC (correct — no access tracking on raw pointers)
```objc
- (BOOL)inTransaction:(void (^)(FMDatabase *, BOOL *))block
                error:(NSError* __autoreleasing *)error {
    __block BOOL success = YES;
    [self.storeQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        @try { block(db, rollback); }
        @catch (NSException *exception) {
            *rollback = YES;
            *error = [self errorForException:exception]; // raw pointer — no access check
            success = NO;
        }
    }];
    return success;
}
```

### Broken Swift migration
```swift
func inTransaction(_ block: @escaping (...) -> Void,
                   error: inout NSError?) -> Bool {       // ← inout triggers exclusivity
    var success = true
    _storeQueue.inTransaction { db, rollback in           // ← @escaping closure
        do {
            try self.tryCatch { block(db, rollback) }
        } catch let caught as NSError {
            rollback.pointee = true
            error = caught                                // ← CRASH: overlapping inout access
            success = false
        }
    }
    return success
}
```

### Crash stack (from `.ips` crash log)
```
swift::runtime::AccessSet::insert       ← exclusivity check fires
swift_beginAccess
closure #1 in SmartStore.upsert(...)                 [SFSmartStore.swift:836]
closure #1 in SmartStore.inTransaction(_:error:)     [SFSmartStore.swift:1345]
SmartStore.tryCatch(_:)                              [SFSmartStore.swift:1363]
closure #1 in SmartStore.inTransaction(_:error:)     [SFSmartStore.swift:1344]
-[FMDatabaseQueue beginTransaction:withBlock:]       [FMDatabaseQueue.m:230]
_dispatch_lane_barrier_sync_invoke_and_complete
SmartStore.inTransaction(_:error:)                   [SFSmartStore.swift:1342]
SmartStore.upsert(entries:forSoupNamed:...)           [SFSmartStore.swift:835]
```

### Affected tests (~46 crashes)
- `SFSmartStoreTests` — ~18 tests (all query/upsert/remove paths)
- `SFSmartStoreAlterTests` — 19 tests (all alter operations)
- `SFSmartStoreFullTextSearchTests` — all tests
- `SFSmartStoreFullTextSearchSpeedTests` — all tests
- `SFSmartStoreLoadTests` — all tests
- `SyncStateTests.testCleanupSyncsSoupIfNeeded` (MobileSync)

### Recommended fix
Replace the `inout` capture with a local variable in both methods. Copy the error out after the synchronous dispatch completes:

```swift
func inTransaction(_ block: @escaping (FMDatabase?, UnsafeMutablePointer<ObjCBool>) -> Void,
                   error: inout NSError?) -> Bool {
    var success = true
    var localError: NSError?                              // ← local, not captured inout
    _storeQueue.inTransaction { db, rollback in
        do {
            try self.tryCatch { block(db, rollback) }
        } catch let caught as NSError {
            rollback.pointee = true
            localError = caught                           // ← writes to local
            success = false
        } catch {
            rollback.pointee = true
            success = false
        }
    }
    error = localError                                    // ← copy out after dispatch returns
    return success
}
```

Apply the same pattern to `inDatabase(_:error:)`. This preserves semantics (the dispatch is synchronous, so `localError` is set before the copy-out) while eliminating the overlapping `inout` access that triggers Swift's exclusivity check.

---

## Bug 3: ParentChildrenSyncDownTarget / SyncUpTarget — Private Properties Inaccessible to Tests

**Severity:** Medium — blocks test coverage
**Status:** Fix was applied during conversion, currently in working tree (uncommitted)
**Files:**
- `libs/MobileSync/MobileSync/Classes/Target/SFParentChildrenSyncDownTarget.swift:32-37`
- `libs/MobileSync/MobileSync/Classes/Target/SFParentChildrenSyncUpTarget.swift:36-40`

### Description
Several properties on `SFParentChildrenSyncDownTarget` and `SFParentChildrenSyncUpTarget` are declared `private` but need to be `internal` (the Swift default) for `@testable import` to grant test access. In ObjC, the tests accessed these through private header interface declarations (`@interface SFParentChildrenSyncDownTarget ()`).

`@testable import` only elevates `internal` to `public` — it does not grant access to `private` members.

### SFParentChildrenSyncDownTarget (6 properties)
```swift
// Current (private — tests can't access):
private var parentInfo: ParentInfo
private var parentFieldlist: [String]
private var parentSoqlFilter: String?
private var childrenInfo: ChildrenInfo
private var childrenFieldlist: [String]
private var relationshipType: ParentChildrenRelationshipType

// Should be (internal — default access):
var parentInfo: ParentInfo
var parentFieldlist: [String]
var parentSoqlFilter: String?
var childrenInfo: ChildrenInfo
var childrenFieldlist: [String]
var relationshipType: ParentChildrenRelationshipType
```

### SFParentChildrenSyncUpTarget (5 properties)
```swift
// Current:
private var parentInfo: ParentInfo
private var childrenInfo: ChildrenInfo
private var childrenCreateFieldlist: [String]?
private var childrenUpdateFieldlist: [String]?
private var relationshipType: ParentChildrenRelationshipType

// Should be:
var parentInfo: ParentInfo
var childrenInfo: ChildrenInfo
var childrenCreateFieldlist: [String]?
var childrenUpdateFieldlist: [String]?
var relationshipType: ParentChildrenRelationshipType
```

### How it was discovered
`SFSDKSyncsConfigTests` and `ParentChildrenSyncTests` compare target properties after round-tripping through config. Compilation fails because `@testable import MobileSync` cannot access `private` members.

---

## Bug 4: UserAccountManager.upsert() — Silent No-Op When userAccountMap Is Nil

**Severity:** Medium — silent data loss; particularly dangerous for test authors
**Status:** Unfixed (workaround in tests: call `loadAccounts()` first)
**File:** `libs/SalesforceSDKCore/SalesforceSDKCore/Classes/UserAccount/SFUserAccountManager.swift:650-669`

### Description
`UserAccountManager.shared.upsert(_:)` uses optional chaining on `userAccountMap` (line 657, 662). When `userAccountMap` is `nil` (which it is until `loadAccounts()` is called), every operation is a no-op:
- `userAccountMap?.removeObject(forKey:)` — no-op
- `userAccountMap?[key] = value` — no-op
- `userAccountMap?.count ?? 0` — evaluates to 0

The method returns `true` (from `accountPersister.saveAccount()`) even though the in-memory map was not updated. Subsequent calls to `currentUserAccount = user` then fail with "Cannot set the currentUser. Add the account to the SFAccountManager before making this call." because `userAccount(for:)` searches `userAccountMap` which is still nil.

### Current code (line 654-662)
```swift
let oldCount = userAccountMap?.count ?? 0          // Always 0 when nil
userAccountMap?.removeObject(forKey: ...)           // No-op when nil
let success = try accountPersister.saveAccount(for: userAccount)  // Succeeds
if success {
    userAccountMap?[userAccount.accountIdentity] = userAccount    // No-op when nil
}
return success  // Returns true despite map not being updated
```

### Potential fixes
1. **Lazy initialization:** Initialize `userAccountMap` in `upsert()` if nil: `if userAccountMap == nil { userAccountMap = NSMutableDictionary() }`
2. **Guard clause:** Throw or return false if `userAccountMap` is nil
3. **Auto-load:** Call `loadAccounts()` internally if map is nil

Option 1 is simplest and matches the pattern in `loadAccounts()` (line 494-495).

### How it was discovered
Every SmartStore and MobileSync test that creates a user account via `setUpSmartStoreUser()` → `upsert(user)` → `currentUserAccount = user` failed silently. The user store returned nil, causing force-unwrap crashes. Adding `try? UserAccountManager.shared.loadAccounts()` before `upsert()` was the workaround applied to all test setUp methods.

In ObjC this was not an issue because the ObjC test used `saveAccountForUser:error:` (which went through the persister) followed by `setCurrentUserInternal:` (which directly set the ivar without checking the map).

---

## Bug 5: SFUserAccountManager Notification API — Swift Migration Incomplete

**Severity:** Low — tests disabled, no production impact confirmed
**Status:** Unfixed — `SFUserAccountManagerNotificationsTestsSwift` disabled
**File:** `libs/SalesforceSDKCore/SalesforceSDKCore/Classes/UserAccount/SFUserAccountManager.swift`

### Description
The ObjC test `SFUserAccountManagerNotificationsTests` tested notification posting for user lifecycle events (login, logout, switch, credential changes). The Swift migration renamed or restructured several notification-related APIs:
- `kSFNotificationUserDidLogout` → unclear Swift equivalent
- `SFUserAccountManagerDidChangeUserDataNotification` → not found
- `applyCredentials:` method → removed or renamed
- `saveAccount(forUser:error:)` → `upsert(_:)` (different semantics)

The test class was converted but could not be made to compile due to the depth of API changes. It was disabled (empty class body with TODO).

### How it was discovered
Compilation of `SFUserAccountManagerNotificationsTestsSwift.swift` produced 33+ errors referencing missing members, renamed notifications, and changed method signatures. After multiple fix attempts, the test was disabled rather than investing further time in what appeared to be deeply refactored notification infrastructure.

### Impact
The notification behavior for user account lifecycle events is untested in the Swift test suite. If notifications were inadvertently dropped or renamed during the framework migration, there is no test coverage to catch it.

---

## Bug 6: SmartStore.string(from:) — Double Read Drops Every Other Buffer

**Severity:** High — silently corrupts data read from InputStreams
**Status:** Fixed
**File:** `libs/SmartStore/SmartStore/Classes/SFSmartStore+Internal.swift:500-513`

### Description
`SmartStore.string(from inputStream: InputStream)` calls `inputStream.read()` twice per loop iteration — once in the `while` condition (result discarded) and once in the body (result kept). This drops every other buffer-load of data, silently corrupting the output string.

### Original ObjC (correct — from commit `7f23866f5`)
```objc
// libs/SmartStore/SmartStore/Classes/SFSmartStore.m:782-797
+ (NSString*) stringFromInputStream:(NSInputStream*)inputStream {
    uint8_t buffer[kBufferSize];
    NSInteger len;
    NSMutableData* content = [NSMutableData new];
    [inputStream open];
    while ((len = [inputStream read:buffer maxLength:sizeof(buffer)]) > 0) {
        [content appendBytes:buffer length:len];
    }
    [inputStream close];
    return [[NSString alloc] initWithData:content encoding:NSUTF8StringEncoding];
}
```

The ObjC idiom `while ((len = [stream read:...]) > 0)` performs one read per iteration, assigning the result to `len` in the condition.

### Broken Swift migration (commit `58a0af75d`)
```swift
while inputStream.read(&buffer, maxLength: buffer.count) > 0 {   // Read #1: result discarded
    len = inputStream.read(&buffer, maxLength: buffer.count)      // Read #2: overwrites buffer
    if len > 0 {
        content.append(buffer, length: len)                       // Only Read #2 is kept
    }
}
```

Swift has no assignment-in-condition syntax, so the migrator split the single read into two calls. The first read's data is lost.

### Fixed Swift
```swift
var len = inputStream.read(&buffer, maxLength: buffer.count)
while len > 0 {
    content.append(buffer, length: len)
    len = inputStream.read(&buffer, maxLength: buffer.count)
}
```

### How it was discovered
`SFSmartStoreTests.testReadMultiByteCharacterAroundBufferBoundary` — builds a string with a 4-byte UTF-8 character (`U+1D11E`) straddling the 4096-byte buffer boundary, reads it through `SmartStore.string(from:)`, and compares. The double-read corruption produced a mismatched string.

### Impact
Any SmartStore operation that reads soup data from an InputStream (e.g., large JSON blobs stored as external files) silently loses half the data. This affects data integrity for any soup entry whose serialized JSON exceeds 4096 bytes.
