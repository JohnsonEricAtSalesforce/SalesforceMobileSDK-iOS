# MobileSync Conversion Lessons (Batches 10-14)

## Batch 10: Base Target Classes
- `SFSyncTarget.swift`: Root of target hierarchy. Used `open class` since subclassed extensively. Constants (`kSyncTargetLocal` etc.) kept as top-level `@objc` lets since they are referenced from ObjC. `@synchronized` blocks in the ObjC were replaced with standard Swift patterns.
- `SFSyncDownTarget.swift`: `ABSTRACT_METHOD` macro converted to `NSException.raise()` in method bodies. Completion block typedefs defined at module level for reuse. Query type enum maps 1:1 to ObjC `NS_ENUM`.
- `SFSyncUpTarget.swift`: `SFRecordModDate` helper class kept as standalone `@objcMembers public class`. Private `lastError` state managed internally. `fetchLastModifiedDate` kept as private method (was not in public header).

## Batch 11: SyncDown Subclasses
- `SFSoqlSyncDownTarget.swift`: `kSFRestSOQLDefaultBatchSize` referenced from SalesforceSDKCore. `SFSDKSoqlMutator` used via optional chaining since Swift init may return nil. Recursive block pattern (fetchBlockRecurse) preserved using optional closure capture.
- `SFSoslSyncDownTarget.swift`: Simple target - query property made `private(set)` to match readonly in header.
- `SFMruSyncDownTarget.swift`: `SFSDKSoqlBuilder` used for query construction. `pluck` helper kept as private method.
- `SFRefreshSyncDownTarget.swift`: Complex paging logic with `page` counter. Preserved exact behavior of the ObjC for counting and paging through SmartStore.

## Batch 12: Layout/Metadata/Batch/Advanced
- `SFLayoutSyncDownTarget.swift`: Local constant `kSFSyncTargetObjectType_Layout` used to avoid clash with same-named constant in other files.
- `SFMetadataSyncDownTarget.swift`: Similar pattern - local constant disambiguation.
- `SFBatchSyncUpTarget.swift`: Conforms to `SFAdvancedSyncUpTarget` protocol. `SFCompositeRequestHelper` used via existing Swift class. `maxBatchSize` capped at API limit (25).
- `SFAdvancedSyncUpTarget.swift`: Converted from `@protocol` to `@objc protocol`. Required property `maxBatchSize` and method `syncUpRecords`.

## Batch 13: Parent-Children Targets
- `SFParentChildrenSyncDownTarget.swift`: Subclasses `SFSoqlSyncDownTarget` (open class). Complex nested SOQL construction preserved. `cleanGhosts` calls super then handles children ghosts in completion.
- `SFParentChildrenSyncUpTarget.swift`: Largest file (592 lines ObjC). Composite request pattern with re-run logic. `doesNotRecognizeSelector` replaced with `NSException.raise()`. Local typedef `SFFetchLastModifiedDatesCompleteBlock` kept private.

## Batch 14: Sync Manager + Tasks
- `SFMobileSyncSyncManager.swift`: `+initialize` → `private static var syncMgrList`. `@synchronized([SFMobileSyncSyncManager class])` → `NSRecursiveLock` (Rule 33). Singleton dictionary management preserved. `handleUserWillLogout` registered via NotificationCenter.
- `SFSyncTask.swift`: Abstract base with `runSync` raising NSException. Event creation preserved via `SFSDKEventBuilderHelper`.
- `SFSyncDownTask.swift`: Recursive fetch block pattern preserved for sync down pagination.
- `SFSyncUpTask.swift`: Complex retry logic (update→create on 404) preserved exactly.

## Batch 15: Manager Classes (Advanced Task, Ghosts, Layout/Metadata Sync, MobileSyncSDKManager)
- `SFAdvancedSyncUpTask.swift`: Overrides `runSync` (not `syncUp`) because parent's `syncUp` is private in Swift. Batch-oriented processing: collects records up to `maxBatchSize` then calls `syncUpRecords` on the advanced target.
- `SFCleanSyncGhostsTask.swift`: Lightweight task that overrides `updateSync` to no-op. Completion via `completionStatusBlock` rather than update block. Event creation for analytics preserved.
- `SFLayoutSyncManager.swift`: `+initialize` → `private static var syncMgrList` + `private static let indexSpecs` (Rule 19). `@synchronized` → `NSRecursiveLock`. Soup-backed cache with server-fallback pattern.
- `SFMetadataSyncManager.swift`: Mirror of LayoutSyncManager pattern. Same Rule 19 + Rule 33 treatment.
- `MobileSyncSDKManager.swift`: Subclasses `SmartStoreSDKManager`. `@dynamic sharedManager` → computed property override. Syncs config loading via `SFSDKSyncsConfig`.

## Batch 16: Model/State/Options + SOQL Utilities
- `SFSyncState.swift`: Large model class (~380 lines). All enums converted to `@objc` enums matching `NS_ENUM` values. Custom `status` setter tracks start/end time transitions. `NSCopying` via `fromDict(asDict())`. `SOUP_ENTRY_ID` global from SmartStore used for dict serialization.
- `SFSyncOptions.swift`: Simple model with factory methods. `mergeMode` delegates to `SFSyncState` for string conversion.
- `SFSDKSoqlMutator.swift`: String parsing/manipulation class. `@discardableResult` on mutation methods for fluent API. `SFSDKSoqlBuilder` interaction preserved.
- `SFSDKSoqlTokenizer.swift`: Character-by-character tokenizer. State machine (inWhiteSpace/inQuotes/depth) preserved exactly. Post-processing combines "order"+"by"/"group"+"by" tokens.
- `SFSDKSyncsConfig.swift`: JSON config loader. `SFSDKResourceUtils.loadConfig` used. Creates syncs via `SFMobileSyncSyncManager`.

## Batch 17: Parent/Children Utilities + Network/Object Utils
- `SFParentInfo.swift`: Base info object with factory methods. Preserved typo in constant name (`kSFParentInfoModifificationDateFieldName`) for ObjC compat.
- `SFChildrenInfo.swift`: Subclasses `SFParentInfo`. Adds `sobjectTypePlural` and `parentIdFieldName`.
- `SFParentChildrenSyncHelper.swift`: Static utility. Complex Smart SQL construction for dirty/non-dirty record queries. `saveRecordTrees` separates parent from children by `sobjectTypePlural` key.
- `SFCompositeRequestHelperLegacy.swift`: Stub class with `@objc(SFCompositeRequestHelper)` per Rule 22. Existing `CompositeRequestHelper.swift` already carries that name via its own `@objc` - this file provides the legacy typedef only.
- `SFMobileSyncNetworkUtils.swift`: Thin wrapper over `SFRestAPI` that sets MobileSync user agent.
- `SFMobileSyncObjectUtils.swift`: Subclass of `SFFormatUtils`. `formatValue` handles NSNull, "<null>", NSNumber, and responds-to-stringValue.

## Batch 18: Constants/Logger + Model Objects
- `SFMobileSyncConstants.swift`: All `extern NSString *const` → `@objc public let`. `SFSDKFetchMode` enum (cacheOnly/cacheFirst/serverFirst) defined here.
- `SFSDKMobileSyncLogger.swift`: Component logger forwarding to `SFLogger.logger(forComponent:)`. Both class and instance methods for ObjC/Swift callers.
- `SFObject.swift`: Subclasses `SFMobileSyncPersistableObject`, conforms to `NSCoding`. Uses `setObjectType()` internal method. `hash`/`isEqual` preserved.
- `SFLayout.swift`: Multi-class file (SFLayout, SFLayoutSection, SFRow, SFItem). Factory method `from(_:)` pattern. All classes `@objcMembers`.
- `SFMetadata.swift`: 28 boolean properties parsed from JSON. All use `(data[key] as? NSNumber)?.boolValue ?? false` pattern to avoid force unwraps.
- `SFMobileSyncPersistableObject.swift`: Base model with `rawData` and `objectType`. Internal `setObjectType()` for subclass use since `objectType` is `private(set)`.

## Key Decisions
1. All base classes use `open class` since they are subclassed.
2. `@objc(ClassName)` annotation used on all classes for ObjC interop.
3. Block typedefs kept at module level for reuse across files.
4. No force unwraps anywhere - all optionals handled safely.
5. `@synchronized` → `objc_sync_enter/exit` for the SyncManager (lightweight pattern matching ObjC behavior), `NSRecursiveLock` for class-level lock.
6. Existing Swift files (`SyncTarget.swift`, `BatchSyncUpTarget.swift`, `CollectionSyncUpTarget.swift`, etc.) NOT modified per Rule 23/25.
7. `SFMobileSyncPersistableObject` uses `internal func setObjectType()` so subclasses within the module can mutate `objectType` without exposing a public setter.
8. `SFCompositeRequestHelperLegacy.swift` is a minimal stub - the real `CompositeRequestHelper.swift` already carries `@objc(SFCompositeRequestHelper)` annotation.
