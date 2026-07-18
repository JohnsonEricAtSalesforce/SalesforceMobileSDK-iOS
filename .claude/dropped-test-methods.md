# Dropped Test Methods — Migration vs Merge-Base Oracle (2026-07-17)

**Origin:** Operator asked whether we have comparable testability to the oracle before resuming the
upstream port queue. Due-diligence sweep (file parity ✅, compile parity ✅) then a **per-method** diff
found tests present in the oracle but absent from the compiled Swift target — the exact "hidden failure"
risk the operator flagged.

**Oracle:** merge-base `6ed0ab408` at `/tmp/oracle-base`. **Method used:** Python direct-file diff
(`/tmp/method_diff.py`) computing, per library, oracle-method-union vs. migration-compiled-swift-union
(library-wide union catches cross-file moves). Confirmed NOT renames via reverse diff (migration-only
methods): SDKCore's only 7 migration-only methods are the new `CredentialsArchiveRoundTripTests`
`test_given…` set; Commons/Analytics/MobileSync have ZERO migration-only methods.

## Second-pass corrections (why the net-count method was insufficient)
- **Net-count diff (per-class count delta) missed 3 drops** in classes that *gained* methods, masking
  the loss: `SFPushNotificationManagerTests` (−2, net 0) and one more surfaced only by the union diff.
- **Case-sensitivity false positive (+1):** `SFSmartStoreAlterTests.testAlterSoupwithFullTextIndexesFromFts4ToFts5`
  (oracle lowercase `with`) → migration `…FromFts4ToFts5` **uppercase `With`**. Same test, present + compiled.
  **NOT dropped.**
- Final tally: **50 confirmed dropped** (was estimated 53).

## CONFIRMED DROPPED — 50 methods

### SalesforceSDKCore — 50 total... wait, per-lib below

### SalesforceSDKCore (46 + 2 + 1 + 1 = 50)
**`SalesforceRestAPITests` — 46** (LIVE-ORG class, currently `XCTSkipUnless`-gated; doubly masked):
testAssertionForUnauthenticatedClient, testBatchWithBatchRequest, testBatchWithBatchRequestResponse,
testBlockUpdate, testBlocks, testBlocksCancel, testBlocksTimeout,
testCollectionCreateWithBadRecordAndAllOrNoneFalse, testCollectionCreateWithBadRecordAndAllOrNoneTrue,
testCollectionUpdate, testCollectionUpsertExistingRecords, testCollectionUpsertNewRecords,
testCustomSalesforceEndpoint, testEscapingWithSOQLQuery, testFailedRequestRemovedFromQueue,
testFileSharesWithUserCommunity, testFilesInUsersGroupsWithCommunity,
testGetLayoutWithObjectAPINameWithoutLayoutType, testGetLayoutWithObjectAPINameWithoutMode,
testGetLayoutWithObjectAPINameWithoutRecordTypeId, testNoTrailingQuestionMarkForEmptyParams,
testOwnedFilesListWithCommunity, testOwnedFilesListWithCommunityWithHeaders,
testParsePrimingRecordsResponse, testParsePrimingRecordsResponseFromServer,
testRefreshNotificationWithValidGetRequest, testRequestForInvokeNotificationActionWithVersion,
testRequestForNotificationTypesWithVersion, testRequestWithCompositeRequest,
testRequestWithCompositeRequestResponse, testRestUrlForNetworkServiceType, testSOQLQueryWithBatchSize,
testSOQLWithNewLine, testSalesforceFullUrlPath, testUpdateNotificationRequestPath,
testUpdateNotificationsRequestContent, testUpdateWithIfUnmodifiedSince, testUploadBatchDetailsDeleteFiles,
testUploadBatchDetailsDeleteFilesCommunity, testUploadDetailsDeleteFile,
testUploadDetailsDeleteFileWithCommunity, testUploadDownloadDeleteFileWithCommunity,
testUploadOwnedFilesDelete, testUploadProfilePhoto, testUploadProfilePhotoCommunity,
testUploadShareFileSharesSharedFilesUnshareDelete

**`SFPushNotificationManagerTests` — 2** (net-zero-masked):
testRegisterSalesforceNotifications_NoUserCredentials, testUnregisterSalesforceNotifications_NoUserCredentials

**`SFSDKEncryptedPushNotificationTests` — 1:** testValidateUserInfo

**`SalesforceOAuthUnitTests` — 1:** testScopeQueryParamStringNilScopes

### MobileSync (5)
**`SyncManagerTests` — 3** (LIVE-ORG, `SyncManagerTestCase` skip-gated):
testRefreshReSyncWithMultipleRoundTrips, testStopRestartMultipleSyncDowns, testStopRestartSingleSyncDown

**`SyncUpTargetTests` — 2** (LIVE-ORG):
testSyncUpManyLocallyCreatedRecords, testSyncUpWithLocallyUpdatedRemotelyDeletedRecordsWithoutOverwrite

### SalesforceSDKCommon / SalesforceAnalytics / SmartStore
**0 dropped.** (SmartStore's apparent −1 was the case-only rename above.)

## Why this matters for the port queue
The dropped tests concentrate in **REST client (batch/collection/composite/file/priming/notifications),
OAuth scope, and sync-up/sync-down** — the exact surface the parked upstream port queue (#4042 / #4041→#4044,
REST/sync commits) will modify. Resuming porting without them = regressions in those APIs pass green.
Aggravator: 46 of 50 are in live-org classes already skipped, so they're masked twice.

## Plan (operator-approved: restore all, verify, audit, hold porting)
1. ✅ Second-pass verification (this file). 2. Restore 50 methods `.m`→`.swift` byte-faithful.
3. Oracle-compare each restored class (fail-at-oracle=baseline; pass-oracle/fail-migration=regression→fix).
4. Remaining audits: assertion-fidelity, FTS4/5 parameterization, live-org skip ledger.
5. THEN resume port queue.
