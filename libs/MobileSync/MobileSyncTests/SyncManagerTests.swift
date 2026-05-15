/*
 Copyright (c) 2015-present, salesforce.com, inc. All rights reserved.

 Redistribution and use of this software in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright notice, this list of conditions
 and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of
 conditions and the following disclaimer in the documentation and/or other materials provided
 with the distribution.
 * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
 endorse or promote products derived from this software without specific prior written
 permission of salesforce.com, inc.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
 FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
 WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import XCTest
import SmartStore
import SalesforceSDKCore
@testable import MobileSync

private let kCountTestAccounts: UInt = 10

/// Soql sync down target that pauses for a second at the beginning of the fetch
class SlowSoqlSyncDownTarget: SoqlSyncDownTarget {
    override class func newSyncTarget(_ query: String) -> SlowSoqlSyncDownTarget {
        let syncTarget = SlowSoqlSyncDownTarget()
        syncTarget.query = query
        return syncTarget
    }

    override func startFetch(syncManager: SFMobileSyncSyncManager, maxTimeStamp: Int64, onFail errorBlock: @escaping SyncDownErrorBlock, onComplete completeBlock: @escaping SyncDownCompletionBlock) {
        Thread.sleep(forTimeInterval: 1.0)
        super.startFetch(syncManager: syncManager, maxTimeStamp: maxTimeStamp, onFail: errorBlock, onComplete: completeBlock)
    }
}

final class SyncManagerTests: SyncManagerTestCase {

    var idToFields: [String: Any] = [:]

    // MARK: - setUp/tearDown

    override func tearDown() {
        deleteTestData()
        super.tearDown()
    }

    // MARK: - Tests

    /// Test query with "From_customer__c" field
    func testQueryWithFromFieldtoSOQLTarget() {
        let soqlQueryWithFromField = SFSDKSoqlBuilder.with(fields: "From_customer__c, Id").from(ACCOUNT_TYPE).limit(10).build() ?? ""
        let target = SoqlSyncDownTarget.newSyncTarget(soqlQueryWithFromField)
        target.getRemoteIds(syncManager: syncManager, localIds: [], errorBlock: { error in
            NSLog("%@", error?.localizedDescription ?? "Unknown error")
            XCTFail("Wrong query was generated.")
        }, completeBlock: { _ in })
    }

    /// Test adding 'Id' and 'LastModifiedDate' to SOQL query, if they're missing.
    func testAddMissingFieldstoSOQLTarget() {
        let soqlQueryWithSpecialFields = "select Id,LastModifiedDate,FirstName, LastName from Contact order by LastModifiedDate limit 100"
        let soqlQueryWithoutSpecialFields = "select FirstName, LastName from Contact limit 100"
        let target = SoqlSyncDownTarget.newSyncTarget(soqlQueryWithoutSpecialFields)
        XCTAssertEqual(soqlQueryWithSpecialFields, target.query, "SOQL query should contain Id and LastModifiedDate fields.")
    }

    /// Tests that request does not include batchSize header when no batch size was specified
    func testNoBatchSizeHeaderPresentByDefault() {
        let target = SoqlSyncDownTarget.newSyncTarget("SELECT Name FROM Account WHERE Name = 'James Bond'")
        let request = target.buildRequest(target.query)
        XCTAssertNil(request.customHeaders)
    }

    /// Tests that request does not include batchSize header when default batch size was specified
    func testNoBatchSizeHeaderPresentWithDefaultBatchSize() {
        let target = SoqlSyncDownTarget.newSyncTarget("SELECT Name FROM Account WHERE Name = 'James Bond'", maxBatchSize: 2000)
        let request = target.buildRequest(target.query)
        XCTAssertNil(request.customHeaders)
    }

    /// Tests that request does include batchSize header when non-default batch size was specified
    func testBatchSizeHeaderPresentWithNonDefaultBatchSize() {
        let target = SoqlSyncDownTarget.newSyncTarget("SELECT Name FROM Account WHERE Name = 'James Bond'", maxBatchSize: 200)
        let request = target.buildRequest(target.query)
        XCTAssertEqual("batchSize=200", request.customHeaders?["Sforce-Query-Options"] as? String)
    }

    /// Tests if ghost records are cleaned locally for a SOQL target.
    func testCleanResyncGhostsForSOQLTarget() {
        createAccountsSoup()

        // Creates 3 accounts on the server.
        guard let accounts = createAccounts(onServer: 3) as? [String: Any] else { return }
        let accountIds = Array(accounts.keys)

        // Builds SOQL sync down target and performs initial sync.
        let soql = "SELECT Id, Name FROM Account WHERE Id IN \(buildInClause(accountIds))"
        let syncId = NSNumber(value: trySyncDown(.leaveIfChanged, target: SoqlSyncDownTarget.newSyncTarget(soql), soupName: ACCOUNTS_SOUP, totalSize: UInt(accountIds.count), numberFetches: 1))
        checkDbExists(ACCOUNTS_SOUP, ids: accountIds, idField: "Id")

        // Deletes 1 account on the server and verifies the ghost record is cleared from the soup.
        deleteAccounts(onServer: [accountIds[0]])
        let cleanResyncGhosts = expectation(description: "cleanResyncGhosts")
        try? syncManager.cleanResyncGhosts(forId: syncId) { syncStatus, numRecords in
            if syncStatus == .failed || syncStatus == .done {
                cleanResyncGhosts.fulfill()
            }
        }
        waitForExpectations(timeout: 30.0)
        checkDbDeleted(ACCOUNTS_SOUP, ids: [accountIds[0]], idField: "Id")

        // Deletes the remaining accounts on the server.
        deleteAccounts(onServer: accountIds)
    }

    /// Tests clean ghosts when soup is populated through more than one sync down
    func testCleanResyncGhostsWithMultipleSyncs() {
        createAccountsSoup()

        // Creates 6 accounts on the server.
        guard let accounts = createAccounts(onServer: 6) as? [String: Any] else { return }
        let accountIds = Array(accounts.keys)
        let accountIdsFirstSubset = Array(accountIds[0..<3])
        let accountIdsSecondSubset = Array(accountIds[2..<6])

        // Runs a first SOQL sync down target
        let firstSyncId = NSNumber(value: trySyncDown(.leaveIfChanged, target: SoqlSyncDownTarget.newSyncTarget("SELECT Id, Name FROM Account WHERE Id IN \(buildInClause(accountIdsFirstSubset))"), soupName: ACCOUNTS_SOUP, totalSize: UInt(accountIdsFirstSubset.count), numberFetches: 1))
        checkDbExists(ACCOUNTS_SOUP, ids: accountIdsFirstSubset, idField: "Id")
        checkDbSyncIdField(accountIdsFirstSubset, soupName: ACCOUNTS_SOUP, syncId: firstSyncId)

        // Runs a second SOQL sync down target
        let secondSyncId = NSNumber(value: trySyncDown(.leaveIfChanged, target: SoqlSyncDownTarget.newSyncTarget("SELECT Id, Name FROM Account WHERE Id IN \(buildInClause(accountIdsSecondSubset))"), soupName: ACCOUNTS_SOUP, totalSize: UInt(accountIdsSecondSubset.count), numberFetches: 1))
        checkDbExists(ACCOUNTS_SOUP, ids: accountIdsSecondSubset, idField: "Id")
        checkDbSyncIdField(accountIdsSecondSubset, soupName: ACCOUNTS_SOUP, syncId: secondSyncId)

        // Deletes id0, id2, id5 on the server
        deleteAccounts(onServer: [accountIds[0], accountIds[2], accountIds[5]])

        // Cleaning ghosts of first sync (should only remove id0)
        let firstCleanExpectation = expectation(description: "firstCleanGhosts")
        try? syncManager.cleanResyncGhosts(forId: firstSyncId) { syncStatus, _ in
            if syncStatus == .failed || syncStatus == .done { firstCleanExpectation.fulfill() }
        }
        waitForExpectations(timeout: 30.0)
        checkDbExists(ACCOUNTS_SOUP, ids: [accountIds[1], accountIds[2], accountIds[3], accountIds[4], accountIds[5]], idField: "Id")
        checkDbDeleted(ACCOUNTS_SOUP, ids: [accountIds[0]], idField: "Id")

        // Cleaning ghosts of second sync (should remove id2 and id5)
        let secondCleanExpectation = expectation(description: "secondCleanGhosts")
        try? syncManager.cleanResyncGhosts(forId: secondSyncId) { syncStatus, _ in
            if syncStatus == .failed || syncStatus == .done { secondCleanExpectation.fulfill() }
        }
        waitForExpectations(timeout: 30.0)
        checkDbExists(ACCOUNTS_SOUP, ids: [accountIds[1], accountIds[3], accountIds[4]], idField: "Id")
        checkDbDeleted(ACCOUNTS_SOUP, ids: [accountIds[0], accountIds[2], accountIds[5]], idField: "Id")

        // Deletes the remaining accounts on the server.
        deleteAccounts(onServer: [accountIds[1], accountIds[3], accountIds[4]])
    }

    /// Test instantiation of sync manager from various sharedInstance methods.
    func testSyncManagerSharedInstanceMethods() {
        let mgr1 = SFMobileSyncSyncManager.sharedInstance(forUserAccount: currentUser)
        let store1 = SmartStore.shared(withName: kDefaultSmartStoreName)!
        let mgr2 = SFMobileSyncSyncManager.sharedInstance(store: store1)
        let mgr3 = SFMobileSyncSyncManager.sharedInstance(named: kDefaultSmartStoreName, forUserAccount: currentUser)
        XCTAssertEqual(mgr1, mgr2, "Sync managers should be the same.")
        XCTAssertEqual(mgr1, mgr3, "Sync managers should be the same.")
        let storeName2 = "AnotherStore"
        let mgr4 = SFMobileSyncSyncManager.sharedInstance(forUserAccount: currentUser)
        let store2 = SmartStore.shared(withName: storeName2)!
        let mgr5 = SFMobileSyncSyncManager.sharedInstance(store: store2)
        let mgr6 = SFMobileSyncSyncManager.sharedInstance(named: storeName2, forUserAccount: currentUser)
        XCTAssertEqual(mgr1, mgr4, "Sync managers should be the same.")
        XCTAssertNotEqual(mgr4, mgr5, "Sync managers should not be the same.")
        XCTAssertNotEqual(mgr4, mgr6, "Sync managers should not be the same.")
        XCTAssertEqual(mgr5, mgr6, "Sync managers should be the same.")
        SmartStore.removeShared(withName: storeName2, forUserAccount: currentUser)
    }

    /// getSyncStatus should return null for invalid sync id
    func testGetSyncStatusForInvalidSyncId() {
        let sync = syncManager.syncStatus(forId: NSNumber(value: -1))
        XCTAssertNil(sync, "Sync status should be nil")
    }

    /// Sync down the test accounts, check smart store, check status during sync
    func testSyncDown() {
        createTestData()
        trySyncDown(.overwrite)
        checkDb(idToFields)
    }

    /// Sync down the test accounts, make some local changes, sync down again with merge mode LEAVE_IF_CHANGED then sync down with merge mode OVERWRITE
    func testSyncDownWithoutOverwrite() {
        createTestData()
        trySyncDown(.overwrite)
        let idToFieldsLocallyUpdated = makeSomeLocalChanges()
        trySyncDown(.leaveIfChanged)
        var idToFieldsExpected = idToFields
        for (key, value) in idToFieldsLocallyUpdated {
            idToFieldsExpected[key] = value
        }
        checkDb(idToFieldsExpected)
        trySyncDown(.overwrite)
        checkDb(idToFields)
    }

    /// Test for sync down with metadata target.
    func testSyncDownForMetadataTarget() {
        let indexSpecs = [SoupIndex(path: "Id", indexType: kSoupIndexTypeString, columnName: nil)!]
        try? store.registerSoup(withName: ACCOUNTS_SOUP, withIndices: indexSpecs)
        trySyncDown(.overwrite, target: MetadataSyncDownTarget.newSyncTarget(ACCOUNT_TYPE), soupName: ACCOUNTS_SOUP, totalSize: 1, numberFetches: 1)
        let smartSql = "SELECT {accounts:_soup} FROM {accounts}"
        guard let querySpec = QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: 1) else { return }
        let rows = (try? store.query(using: querySpec, startingFromPageIndex: 0)) ?? []
        XCTAssertEqual(rows.count, 1, "Number of rows should be 1")
        guard let row = rows.first as? [Any], let metadata = row[0] as? [String: Any] else { return }
        XCTAssertNotNil(metadata, "Metadata should not be nil")
        XCTAssertEqual(metadata["keyPrefix"] as? String, "001", "Key prefix should be 001")
        XCTAssertEqual(metadata["label"] as? String, ACCOUNT_TYPE, "Label should be Account")
    }

    /// Test for sync down with layout target.
    func testSyncDownForLayoutTarget() {
        let indexSpecs = [SoupIndex(path: "Id", indexType: kSoupIndexTypeString, columnName: nil)!]
        try? store.registerSoup(withName: ACCOUNTS_SOUP, withIndices: indexSpecs)
        trySyncDown(.overwrite, target: LayoutSyncDownTarget.newSyncTarget(ACCOUNT_TYPE, formFactor: "Medium", layoutType: "Compact", mode: "Edit", recordTypeId: nil), soupName: ACCOUNTS_SOUP, totalSize: 1, numberFetches: 1)
        let smartSql = "SELECT {accounts:_soup} FROM {accounts}"
        guard let querySpec = QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: 1) else { return }
        let rows = (try? store.query(using: querySpec, startingFromPageIndex: 0)) ?? []
        XCTAssertEqual(rows.count, 1, "Number of rows should be 1")
        guard let row = rows.first as? [Any], let layout = row[0] as? [String: Any] else { return }
        XCTAssertNotNil(layout, "Layout should not be nil")
        XCTAssertEqual(layout["layoutType"] as? String, "Compact", "Layout type should be Compact")
        XCTAssertEqual(layout["mode"] as? String, "Edit", "Mode should be Edit")
    }

    /// Sync down the test accounts, modify a few on the server, re-sync, make sure only the updated ones are downloaded
    func testReSync() {
        createTestData()
        let syncId = NSNumber(value: trySyncDown(.overwrite))
        let sync = syncManager.syncStatus(forId: syncId)
        let target = sync?.target as? SyncDownTarget
        let options = sync?.options
        let maxTimeStamp = sync!.maxTimeStamp
        XCTAssertTrue(maxTimeStamp > 0)
        let idToFieldsUpdated = makeSomeRemoteChanges()
        let queue = SFSyncUpdateCallbackQueue()
        let _ = queue.runReSync(syncId, syncManager: syncManager)
        checkStatus(queue.getNextSyncUpdate(), expectedType: .down, expectedId: syncId.intValue, expectedTarget: target, expectedOptions: options, expectedStatus: .running, expectedProgress: 0, expectedTotalSize: -1)
        checkStatus(queue.getNextSyncUpdate(), expectedType: .down, expectedId: syncId.intValue, expectedTarget: target, expectedOptions: options, expectedStatus: .running, expectedProgress: 0, expectedTotalSize: idToFieldsUpdated.count)
        checkStatus(queue.getNextSyncUpdate(), expectedType: .down, expectedId: syncId.intValue, expectedTarget: target, expectedOptions: options, expectedStatus: .done, expectedProgress: 100, expectedTotalSize: idToFieldsUpdated.count)
        checkDb(idToFieldsUpdated)
        XCTAssertTrue(syncManager.syncStatus(forId: syncId)!.maxTimeStamp > maxTimeStamp)
    }

    /// Test sync up of updated records with custom target
    func testCustomSyncUpWithLocallyUpdatedRecords() {
        createTestData()
        trySyncDown(.overwrite)
        let idToFieldsLocallyUpdated = makeSomeLocalChanges()
        let customTarget = TestSyncUpTarget(remoteModDateCompare: .remoteModDateSameAsLocal, sendRemoteModError: false, sendSyncUpError: false)
        trySyncUp(idToFieldsLocallyUpdated.count, target: customTarget, mergeMode: .overwrite)
        checkDbStateFlags(Array(idToFieldsLocallyUpdated.keys), soupName: ACCOUNTS_SOUP, expectedLocallyCreated: false, expectedLocallyUpdated: false, expectedLocallyDeleted: false)
    }

    /// Test custom sync up with locally updated records with merge mode LEAVE_IF_CHANGED
    func testCustomSyncUpWithLocallyUpdatedRecordsWithoutOverwrite() {
        createTestData()
        trySyncDown(.leaveIfChanged)
        let idToFieldsLocallyUpdated = makeSomeLocalChanges()
        let ids = Array(idToFieldsLocallyUpdated.keys)
        let customTarget = TestSyncUpTarget(remoteModDateCompare: .remoteModDateGreaterThanLocal, sendRemoteModError: false, sendSyncUpError: false)
        trySyncUp(ids.count, target: customTarget, mergeMode: .leaveIfChanged)
        checkDbStateFlags(ids, soupName: ACCOUNTS_SOUP, expectedLocallyCreated: false, expectedLocallyUpdated: true, expectedLocallyDeleted: false)
    }

    /// Test custom sync up with locally created records
    func testCustomSyncUpWithLocallyCreatedRecords() {
        createTestData()
        let names = [createAccountName(), createAccountName(), createAccountName()]
        createAccountsLocally(names)
        let customTarget = TestSyncUpTarget(remoteModDateCompare: .remoteModDateSameAsLocal, sendRemoteModError: false, sendSyncUpError: false)
        trySyncUp(3, target: customTarget, mergeMode: .overwrite)
        let idToFieldsCreated = getIdToFieldsByName(ACCOUNTS_SOUP, fieldNames: [NAME, DESCRIPTION], nameField: NAME, names: names)
        checkDbStateFlags(Array(idToFieldsCreated.keys), soupName: ACCOUNTS_SOUP, expectedLocallyCreated: false, expectedLocallyUpdated: false, expectedLocallyDeleted: false)
    }

    /// Test custom sync up with locally deleted records
    func testCustomSyncUpWithLocallyDeletedRecords() {
        createTestData()
        trySyncDown(.overwrite)
        let allIds = Array(idToFields.keys)
        let idsLocallyDeleted = [allIds[0], allIds[1], allIds[2]]
        deleteAccountsLocally(idsLocallyDeleted)
        let customTarget = TestSyncUpTarget(remoteModDateCompare: .remoteModDateSameAsLocal, sendRemoteModError: false, sendSyncUpError: false)
        trySyncUp(3, target: customTarget, mergeMode: .overwrite)
        let idsClause = buildInClause(idsLocallyDeleted)
        let smartSql = "SELECT {accounts:_soup} FROM {accounts} WHERE {accounts:Id} IN \(idsClause)"
        guard let query = QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: UInt(idsLocallyDeleted.count)) else { return }
        let rows = (try? store.query(using: query, startingFromPageIndex: 0)) ?? []
        XCTAssertEqual(0, rows.count)
    }

    /// Test custom sync up target with locally deleted records with merge mode LEAVE_IF_CHANGED
    func testCustomSyncUpWithLocallyDeletedRecordsWithoutOverwrite() {
        createTestData()
        trySyncDown(.leaveIfChanged)
        let allIds = Array(idToFields.keys)
        let idsLocallyDeleted = [allIds[0], allIds[1], allIds[2]]
        deleteAccountsLocally(idsLocallyDeleted)
        let customTarget = TestSyncUpTarget(remoteModDateCompare: .remoteModDateGreaterThanLocal, sendRemoteModError: false, sendSyncUpError: false)
        trySyncUp(3, target: customTarget, mergeMode: .leaveIfChanged)
        checkDbStateFlags(idsLocallyDeleted, soupName: ACCOUNTS_SOUP, expectedLocallyCreated: false, expectedLocallyUpdated: false, expectedLocallyDeleted: true)
    }

    /// Tests the flow for a failure determining modification date.
    func testCustomSyncUpWithFetchModificationDateFailure() {
        createTestData()
        trySyncDown(.leaveIfChanged)
        let idsToLocallyUpdated = makeSomeLocalChanges()
        let customTarget = TestSyncUpTarget(remoteModDateCompare: .remoteModDateGreaterThanLocal, sendRemoteModError: true, sendSyncUpError: false)
        trySyncUp(idsToLocallyUpdated.count, target: customTarget, mergeMode: .leaveIfChanged)
    }

    /// Tests the flow for a failure syncing up the data.
    func testCustomSyncUpWithSyncUpFailure() {
        createTestData()
        trySyncDown(.leaveIfChanged)
        let idToLocallyUpdated = makeSomeLocalChanges()
        let customTarget = TestSyncUpTarget(remoteModDateCompare: .remoteModDateSameAsLocal, sendRemoteModError: false, sendSyncUpError: true)
        let options = SFSyncOptions.newSyncOptions(forSyncUp: [NAME, DESCRIPTION], mergeMode: .overwrite)
        trySyncUp(idToLocallyUpdated.count, actualChanges: 1, target: customTarget, options: options, completionStatus: .failed)
    }

    /// Test addFilterForReSync with various queries
    func testAddFilterForResync() {
        let isoDateFormatter = DateFormatter()
        isoDateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        let baseDateStr = "2015-02-05T13:12:03.956-0800"
        let date = isoDateFormatter.date(from: baseDateStr)!
        let dateLong = Int64(date.timeIntervalSince1970 * 1000.0)
        let dateStr = FormatUtils.getIsoStringFromMillis(dateLong)!

        let originalBasicQuery = "select Id from Account"
        let originalLimitQuery = "select Id from Account limit 100"
        let originalNameQuery = "select Id from Account where Name = 'John'"
        let originalNameLimitQuery = "select Id from Account where Name = 'John' limit 100"
        let originalBasicQueryUpper = "SELECT Id FROM Account"
        let originalLimitQueryUpper = "SELECT Id FROM Account LIMIT 100"
        let originalNameQueryUpper = "SELECT Id FROM Account WHERE Name = 'John'"
        let originalNameLimitQueryUpper = "SELECT Id FROM Account WHERE Name = 'John' LIMIT 100"

        for modDateFieldName in ["LastModifiedDate", "CustomModDate"] {
            let basicQuery = "select Id from Account where \(modDateFieldName) > \(dateStr)"
            let limitQuery = "select Id from Account where \(modDateFieldName) > \(dateStr) limit 100"
            let nameQuery = "select Id from Account where \(modDateFieldName) > \(dateStr) and Name = 'John'"
            let nameLimitQuery = "select Id from Account where \(modDateFieldName) > \(dateStr) and Name = 'John' limit 100"
            let basicQueryUpper = "select Id from Account where \(modDateFieldName) > \(dateStr)"
            let limitQueryUpper = "select Id from Account where \(modDateFieldName) > \(dateStr) limit 100"
            let nameQueryUpper = "select Id from Account where \(modDateFieldName) > \(dateStr) and Name = 'John'"
            let nameLimitQueryUpper = "select Id from Account where \(modDateFieldName) > \(dateStr) and Name = 'John' limit 100"

            XCTAssertEqual(basicQuery, SoqlSyncDownTarget.addFilterForReSync(originalBasicQuery, modDateFieldName: modDateFieldName, maxTimeStamp: dateLong))
            XCTAssertEqual(limitQuery, SoqlSyncDownTarget.addFilterForReSync(originalLimitQuery, modDateFieldName: modDateFieldName, maxTimeStamp: dateLong))
            XCTAssertEqual(nameQuery, SoqlSyncDownTarget.addFilterForReSync(originalNameQuery, modDateFieldName: modDateFieldName, maxTimeStamp: dateLong))
            XCTAssertEqual(nameLimitQuery, SoqlSyncDownTarget.addFilterForReSync(originalNameLimitQuery, modDateFieldName: modDateFieldName, maxTimeStamp: dateLong))
            XCTAssertEqual(basicQueryUpper, SoqlSyncDownTarget.addFilterForReSync(originalBasicQueryUpper, modDateFieldName: modDateFieldName, maxTimeStamp: dateLong))
            XCTAssertEqual(limitQueryUpper, SoqlSyncDownTarget.addFilterForReSync(originalLimitQueryUpper, modDateFieldName: modDateFieldName, maxTimeStamp: dateLong))
            XCTAssertEqual(nameQueryUpper, SoqlSyncDownTarget.addFilterForReSync(originalNameQueryUpper, modDateFieldName: modDateFieldName, maxTimeStamp: dateLong))
            XCTAssertEqual(nameLimitQueryUpper, SoqlSyncDownTarget.addFilterForReSync(originalNameLimitQueryUpper, modDateFieldName: modDateFieldName, maxTimeStamp: dateLong))
        }
    }

    /// Create sync down, get it by id, delete it by id, make sure it's gone
    func testCreateGetDeleteSyncDownById() {
        let sync = SyncState.buildSyncDown(options: SFSyncOptions.newSyncOptions(forSyncDown: .leaveIfChanged), target: SoqlSyncDownTarget.newSyncTarget("SELECT Id, Name from Account"), soupName: ACCOUNTS_SOUP, name: nil, store: store)!
        let syncId = NSNumber(value: sync.syncId)
        let fetchedSync = SyncState.byId(syncId, store: store)
        checkStatus(fetchedSync, expectedType: sync.type, expectedId: sync.syncId, expectedName: nil, expectedTarget: sync.target, expectedOptions: sync.options, expectedStatus: sync.status, expectedProgress: sync.progress, expectedTotalSize: sync.totalSize)
        SyncState.delete(syncId: syncId, store: store)
        XCTAssertNil(SyncState.byId(syncId, store: store), "Sync should be gone")
    }

    /// Create sync down with a name, get it by name, delete it by name, make sure it's gone
    func testCreateGetDeleteSyncDownByName() {
        let syncName = "MyNamedSyncDown"
        let sync = SyncState.buildSyncDown(options: SFSyncOptions.newSyncOptions(forSyncDown: .leaveIfChanged), target: SoqlSyncDownTarget.newSyncTarget("SELECT Id, Name from Account"), soupName: ACCOUNTS_SOUP, name: syncName, store: store)!
        let syncId = NSNumber(value: sync.syncId)
        let fetchedSync = SyncState.byName(syncName, store: store)
        checkStatus(fetchedSync, expectedType: sync.type, expectedId: sync.syncId, expectedName: syncName, expectedTarget: sync.target, expectedOptions: sync.options, expectedStatus: sync.status, expectedProgress: sync.progress, expectedTotalSize: sync.totalSize)
        SyncState.delete(syncName: syncName, store: store)
        XCTAssertNil(SyncState.byId(syncId, store: store), "Sync should be gone")
        XCTAssertNil(SyncState.byName(syncName, store: store), "Sync should be gone")
    }

    /// Create sync up, get it by id, delete it by id, make sure it's gone
    func testCreateGetDeleteSyncUpById() {
        let sync = SyncState.buildSyncUp(options: SFSyncOptions.newSyncOptions(forSyncDown: .leaveIfChanged), target: SyncUpTarget(), soupName: ACCOUNTS_SOUP, name: nil, store: store)!
        let syncId = NSNumber(value: sync.syncId)
        let fetchedSync = SyncState.byId(syncId, store: store)
        checkStatus(fetchedSync, expectedType: sync.type, expectedId: sync.syncId, expectedName: nil, expectedTarget: sync.target, expectedOptions: sync.options, expectedStatus: sync.status, expectedProgress: sync.progress, expectedTotalSize: sync.totalSize)
        SyncState.delete(syncId: syncId, store: store)
        XCTAssertNil(SyncState.byId(syncId, store: store), "Sync should be gone")
    }

    /// Create sync up with a name, get it by name, delete it by name, make sure it's gone
    func testCreateGetDeleteSyncUpByName() {
        let syncName = "MyNamedSyncUp"
        let sync = SyncState.buildSyncUp(options: SFSyncOptions.newSyncOptions(forSyncDown: .leaveIfChanged), target: SyncUpTarget(), soupName: ACCOUNTS_SOUP, name: syncName, store: store)!
        let syncId = NSNumber(value: sync.syncId)
        let fetchedSync = SyncState.byName(syncName, store: store)
        checkStatus(fetchedSync, expectedType: sync.type, expectedId: sync.syncId, expectedName: syncName, expectedTarget: sync.target, expectedOptions: sync.options, expectedStatus: sync.status, expectedProgress: sync.progress, expectedTotalSize: sync.totalSize)
        SyncState.delete(syncName: syncName, store: store)
        XCTAssertNil(SyncState.byId(syncId, store: store), "Sync should be gone")
        XCTAssertNil(SyncState.byName(syncName, store: store), "Sync should be gone")
    }

    /// Create sync with a name, make sure a new sync down with the same name cannot be created
    func testCreateSyncDownWithExistingName() {
        let syncName = "MyNamedSync"
        let _ = SyncState.buildSyncUp(options: SFSyncOptions.newSyncOptions(forSyncDown: .leaveIfChanged), target: SyncUpTarget(), soupName: ACCOUNTS_SOUP, name: syncName, store: store)
        let secondSync = SyncState.buildSyncDown(options: SFSyncOptions.newSyncOptions(forSyncDown: .leaveIfChanged), target: SoqlSyncDownTarget.newSyncTarget("SELECT Id, Name from Account"), soupName: ACCOUNTS_SOUP, name: syncName, store: store)
        XCTAssertNil(secondSync, "sync should nil")
        SyncState.delete(syncName: syncName, store: store)
        XCTAssertNil(SyncState.byName(syncName, store: store), "Sync should be gone")
    }

    /// Create sync with a name, make sure a new sync up with the same name cannot be created
    func testCreateSyncUpWithExistingName() {
        let syncName = "MyNamedSync"
        let _ = SyncState.buildSyncDown(options: SFSyncOptions.newSyncOptions(forSyncDown: .leaveIfChanged), target: SoqlSyncDownTarget.newSyncTarget("SELECT Id, Name from Account"), soupName: ACCOUNTS_SOUP, name: syncName, store: store)
        let secondSync = SyncState.buildSyncUp(options: SFSyncOptions.newSyncOptions(forSyncDown: .leaveIfChanged), target: SyncUpTarget(), soupName: ACCOUNTS_SOUP, name: syncName, store: store)
        XCTAssertNil(secondSync, "sync should nil")
        SyncState.delete(syncName: syncName, store: store)
        XCTAssertNil(SyncState.byName(syncName, store: store), "Sync should be gone")
    }

    /// Run sync down using TestSyncDownTarget
    func testCustomSyncDownTarget() {
        createAccountsSoup()
        let numberOfRecords: UInt = 30
        let target = TestSyncDownTarget(prefix: "test", numberOfRecords: numberOfRecords, numberOfRecordsPerPage: 10, sleepPerFetch: 0)
        let syncId = trySyncDown(.leaveIfChanged, target: target, soupName: ACCOUNTS_SOUP, totalSize: numberOfRecords, numberFetches: 3)
        let sync = syncManager.syncStatus(forId: NSNumber(value: syncId))
        XCTAssertEqual(target.dateForPositionAsMillis(numberOfRecords - 1), sync!.maxTimeStamp, "Wrong timestamp")
        checkDbForAfterTestSyncDown(target, soupName: ACCOUNTS_SOUP, expectedNumberOfRecords: numberOfRecords)
    }

    // MARK: - Helper methods

    private func checkSyncState(_ syncId: NSNumber, expectedTimeStamp: Int64, expectedStatus: SyncStatus) {
        let sync = syncManager.syncStatus(forId: syncId)
        XCTAssertEqual(expectedTimeStamp, sync?.maxTimeStamp ?? 0, "Wrong time stamp")
        XCTAssertEqual(expectedStatus, sync?.status, "Wrong status")
    }

    private func stopSyncManager(_ sleepDuration: TimeInterval) {
        XCTAssertFalse(syncManager.isStopped())
        XCTAssertFalse(syncManager.isStopping())
        syncManager.stop()
        if sleepDuration > 0 {
            XCTAssertTrue(syncManager.isStopping())
            Thread.sleep(forTimeInterval: sleepDuration)
        }
        XCTAssertFalse(syncManager.isStopping())
        XCTAssertTrue(syncManager.isStopped())
    }

    private func checkDbForAfterTestSyncDown(_ target: TestSyncDownTarget, soupName: String, expectedNumberOfRecords: UInt) {
        let smartSql = "SELECT {\(soupName):\(kId)} from {\(soupName)} where {\(soupName):\(kId)} like '\(target.prefix)%' order by {\(soupName):\(kId)}"
        guard let query = QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: 1000) else { return }
        let result = (try? store.query(using: query, startingFromPageIndex: 0)) ?? []
        XCTAssertEqual(Int(expectedNumberOfRecords), result.count, "Wrong number of records")
        for i in 0..<Int(expectedNumberOfRecords) {
            if let row = result[i] as? [Any] {
                XCTAssertEqual(target.idForPosition(UInt(i)), row[0] as? String, "Wrong id")
            }
        }
    }

    @discardableResult
    private func trySyncDown(_ mergeMode: SyncMergeMode) -> Int {
        let idsClause = buildInClause(Array(idToFields.keys))
        let soql = "SELECT Id, Name, Description, LastModifiedDate FROM Account WHERE Id IN \(idsClause)"
        let target = SoqlSyncDownTarget.newSyncTarget(soql)
        return trySyncDown(mergeMode, target: target, soupName: ACCOUNTS_SOUP, totalSize: UInt(idToFields.count), numberFetches: 1)
    }

    private func checkDb(_ dict: [String: Any]) {
        checkDb(dict, soupName: ACCOUNTS_SOUP)
    }

    private func createTestData() {
        createAccountsSoup()
        if let accounts = createAccounts(onServer: kCountTestAccounts) as? [String: Any] {
            idToFields = accounts
        }
    }

    private func deleteTestData() {
        deleteAccounts(onServer: Array(idToFields.keys))
        dropAccountsSoup()
        deleteSyncs()
        idToFields = [:]
    }

    private func makeSomeLocalChanges() -> [String: Any] {
        return makeSomeLocalChanges(idToFields, soupName: ACCOUNTS_SOUP)
    }

    private func makeSomeRemoteChanges() -> [String: Any] {
        return makeSomeRemoteChanges(idToFields, objectType: ACCOUNT_TYPE)
    }
}
