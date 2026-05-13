# SalesforceMobileSDK-iOS Full Build Issue Report

**Date:** 2026-05-13
**Destination:** macOS (Mac Catalyst, arm64)
**Configuration:** Debug
**Branch:** dev

---

## Build Results Summary

| # | Scheme | Result | Error Count | Category |
|---|--------|--------|-------------|----------|
| 1 | SalesforceSDKCommon | BUILD SUCCEEDED | 0 | Framework |
| 2 | SalesforceAnalytics | BUILD SUCCEEDED | 0 | Framework |
| 3 | SalesforceSDKCore | BUILD SUCCEEDED | 0 | Framework |
| 4 | SmartStore | BUILD SUCCEEDED | 0 | Framework |
| 5 | MobileSync | BUILD SUCCEEDED | 0 (3 fixed) | Framework |
| 6 | MobileSyncExplorerCommon | **BUILD FAILED** | **10** | Sample App |
| 7 | RestAPIExplorer | **BUILD FAILED** | **1** | Sample App |
| 8 | MobileSyncExplorer | N/A (iOS only) | — | Sample App |
| 9 | AuthFlowTester | N/A (iOS only) | — | Sample App |
| 10 | SalesforceSDKCommonTestApp | N/A (iOS only) | — | Test App |
| 11 | SalesforceAnalyticsTestApp | N/A (iOS only) | — | Test App |
| 12 | SalesforceSDKCoreTestApp | N/A (iOS only) | — | Test App |
| 13 | SmartStoreTestApp | **BUILD FAILED** | **1** | Test App |
| 14 | MobileSyncTestApp | **BUILD FAILED** | **1** | Test App |

**All 5 framework targets build successfully.** Remaining failures are in sample/test apps.

---

## RESOLVED — MobileSync Framework (3 errors fixed)

All in `libs/MobileSync/MobileSync/Classes/Manager/SFSyncUpTask.swift`.

| # | Error | Fix |
|---|-------|-----|
| 1 | Immutable inout (line 96) | Removed `inout` from `resumeSyncUpOneEntry` param; removed `&` from call sites |
| 2 | Immutable inout (line 106) | Same fix as #1 |
| 3 | Optional unwrap (line 158) | Added `guard let self` in `completeBlockCreate` closure |

---

## RESOLVED — MobileSyncExplorerCommon (10+ errors fixed)

ObjC sample app updated for Swift-migrated APIs across MobileSync, SmartStore, and SalesforceSDKCore.

### Files modified

**Sample app files:**
- `SObjectDataSpec.m` — replaced `kSyncTargetLocal` → `@"__local__"`, `kSoupIndexTypeString` → `@"string"`
- `ContactSObjectData.m` — replaced `kLastModifiedDate` → `@"LastModifiedDate"`
- `SObjectDataManager.h` — replaced `SFSyncSyncManagerUpdateBlock` typedef → explicit block type
- `SObjectDataManager.m` — comprehensive API updates:
  - `[SFUserAccountManager sharedInstance].currentUser` → `[SFUserAccountManager shared].currentUserAccount`
  - `[SFMobileSyncSyncManager sharedInstance:]` → `[SFMobileSyncSyncManager sharedInstanceForUserAccount:]`
  - `[MobileSyncSDKManager sharedManager]` → `[MobileSyncSDKManager shared]`
  - `[SFSmartStore sharedStoreWithName:]` → `[SFSmartStore sharedWithName:]`
  - `upsertEntries:toSoup:` → `upsertWithEntries:forSoupNamed:`
  - `queryWithQuerySpec:pageIndex:error:` → `queryUsing:startingFromPageIndex:error:`
  - `kSFSoupQuerySortOrderAscending/Descending` → `SFSoupQuerySortOrderAscending/Descending`
  - `[SFSDKMobileSyncLogger log:level:format:]` → `[SFSDKMobileSyncLogger d/e:message:]`
  - `kSyncTargetLocal/LocallyCreated/Updated/Deleted` → string literals
  - Added `@import MobileSync` and `@import SalesforceSDKCommon`

**Framework file:**
- `SFMobileSyncSyncManager.swift` — added `@objc(reSyncByName:onUpdate:error:)` and `@objc(reSyncById:onUpdate:error:)` wrapper methods to expose `reSync` to ObjC (the Swift `throws -> Optional` signatures can't be directly `@objc`)

---

## RESOLVED — SmartStoreTestApp & MobileSyncTestApp (signing only)

With `CODE_SIGNING_ALLOWED=NO`, both build successfully — no code errors.

## RESOLVED — RestAPIExplorer (all errors fixed, builds with CODE_SIGNING_ALLOWED=NO)

**Files modified:**
- `bootconfig.plist` — restored (was deleted but still referenced by project)
- `IDPLoginViewController.swift` — submodule imports → `import SalesforceSDKCore`; optional unwrap on `imageNamed`
- `IDPLoginNavViewController.swift` — submodule import → `import SalesforceSDKCore`
- `InitialViewController.swift` — submodule import; `salesforceSystemBackground` → `salesforceSystemBackgroundColor`
- `SceneDelegate.swift` — `registerBlock(forCurrentUserChangeNotifications:)` → `registerBlockForCurrentUserChangeNotifications(_:)`
- `AppDelegate.swift` — `SalesforceLogger` → `SFLogger`/`SFLogLevel`; `bootConfig?.remoteAccessConsumerKey` → `UserAccountManager.shared.oauthClientID`
- `RootViewController.swift` — comprehensive API migration:
  - Added `import SalesforceSDKCommon`
  - `idData.firstName` → `idData?.firstName` (now optional)
  - `UIColor.salesforceLabel` → `salesforceLabelColor`
  - `SFJsonUtils.object(fromJSONString:)` → `object(from:)`
  - `SFSDKWindowManager.shared()` → `.shared`
  - `SalesforceLogger` → `SFLogger`
  - `RestRequest(method:path:queryParams:)` init made public with defaults
  - 15+ `RestClient.request(for...)` calls updated to new method names

**Framework file modified:**
- `SFRestRequest.swift` — changed `internal init` to `public init` with default parameters

## NOT BUILDABLE — iOS-only targets (no Mac Catalyst)

These targets don't support Mac Catalyst and require the iOS platform SDK (not installed):
- MobileSyncExplorer, AuthFlowTester
- SalesforceSDKCommonTestApp, SalesforceAnalyticsTestApp, SalesforceSDKCoreTestApp

## Current Build Status Summary

| # | Scheme | Result | Notes |
|---|--------|--------|-------|
| 1 | SalesforceSDKCommon | BUILD SUCCEEDED | |
| 2 | SalesforceAnalytics | BUILD SUCCEEDED | |
| 3 | SalesforceSDKCore | BUILD SUCCEEDED | |
| 4 | SmartStore | BUILD SUCCEEDED | |
| 5 | MobileSync | BUILD SUCCEEDED | Fixed |
| 6 | MobileSyncExplorerCommon | BUILD SUCCEEDED | Fixed |
| 7 | SmartStoreTestApp | BUILD SUCCEEDED | With CODE_SIGNING_ALLOWED=NO |
| 8 | MobileSyncTestApp | BUILD SUCCEEDED | With CODE_SIGNING_ALLOWED=NO |
| 9 | RestAPIExplorer | BUILD SUCCEEDED | Fixed (with CODE_SIGNING_ALLOWED=NO) |
| 10 | MobileSyncExplorer | N/A | iOS only |
| 11 | AuthFlowTester | N/A | iOS only |
| 12 | SalesforceSDKCommonTestApp | N/A | iOS only |
| 13 | SalesforceAnalyticsTestApp | N/A | iOS only |
| 14 | SalesforceSDKCoreTestApp | N/A | iOS only |
