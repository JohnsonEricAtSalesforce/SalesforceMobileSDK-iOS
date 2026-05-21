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
import SalesforceSDKCore
import SmartStore
@testable import MobileSync

private let COUNT_TEST_ACCOUNTS: UInt = 10

/// Soql sync down target that pauses for a second at the beginning of the fetch
private class SlowSoqlSyncDownTarget: SFSoqlSyncDownTarget {

    class func newSlowSyncTarget(_ query: String) -> SlowSoqlSyncDownTarget {
        let syncTarget = SlowSoqlSyncDownTarget()
        syncTarget.query = query
        return syncTarget
    }

    override func startFetch(_ syncManager: SFMobileSyncSyncManager, maxTimeStamp: Int64, errorBlock: @escaping SFSyncDownTargetFetchErrorBlock, completeBlock: @escaping SFSyncDownTargetFetchCompleteBlock) {
        Thread.sleep(forTimeInterval: 1.0)
        super.startFetch(syncManager, maxTimeStamp: maxTimeStamp, errorBlock: errorBlock, completeBlock: completeBlock)
    }
}

class SyncManagerTests: SyncManagerTestCase {

    private var idToFields: [String: [String: Any]] = [:]

    // MARK: - setUp/tearDown

    override func tearDown() {
        deleteTestData()
        super.tearDown()
    }

    // MARK: - Tests

    /// Test query with "From_customer__c" field
    func testQueryWithFromFieldtoSOQLTarget() {
        let soqlQueryWithFromField = SFSDKSoqlBuilder.withFields("From_customer__c, Id").from(ACCOUNT_TYPE).limit(10).build() ?? ""
        let target = SFSoqlSyncDownTarget.newSyncTarget(soqlQueryWithFromField)
        target.getRemoteIds(syncManager, localIds: []) { error in
            XCTFail("Wrong query was generated.")
        } completeBlock: { _ in }
    }

    /// Test adding 'Id' and 'LastModifiedDate' to SOQL query, if they're missing
    func testAddMissingFieldstoSOQLTarget() {
        let soqlQueryWithSpecialFields = "select Id,LastModifiedDate,FirstName, LastName from Contact order by LastModifiedDate limit 100"
        let soqlQueryWithoutSpecialFields = "select FirstName, LastName from Contact limit 100"
        let target = SFSoqlSyncDownTarget.newSyncTarget(soqlQueryWithoutSpecialFields)
        let targetSoqlQuery = target.query
        XCTAssertEqual(soqlQueryWithSpecialFields, targetSoqlQuery, "SOQL query should contain Id and LastModifiedDate fields.")
    }

    /// Tests that request does not include batchSize header when no batch size was specified
    func testNoBatchSizeHeaderPresentByDefault() {
        let target = SFSoqlSyncDownTarget.newSyncTarget("SELECT Name FROM Account WHERE Name = 'James Bond'")
        let request = target.buildRequest(target.query)
        XCTAssertNil(request.customHeaders)
    }

    /// Tests that request does not include batchSize header when default batch size was specified
    func testNoBatchSizeHeaderPresentWithDefaultBatchSize() {
        let target = SFSoqlSyncDownTarget.newSyncTarget("SELECT Name FROM Account WHERE Name = 'James Bond'", maxBatchSize: 2000)
        let request = target.buildRequest(target.query)
        XCTAssertNil(request.customHeaders)
    }

    /// Tests that request does include batchSize header when non-default batch size was specified
    func testBatchSizeHeaderPresentWithNonDefaultBatchSize() {
        let target = SFSoqlSyncDownTarget.newSyncTarget("SELECT Name FROM Account WHERE Name = 'James Bond'", maxBatchSize: 200)
        let request = target.buildRequest(target.query)
        XCTAssertEqual("batchSize=200", request.customHeaders?["Sforce-Query-Options"] as? String)
    }

    /// Tests if ghost records are cleaned locally for a SOQL target
    func testCleanResyncGhostsForSOQLTarget() {
        createAccountsSoup()

        // Creates 3 accounts on the server
        let accountIds = Array(createAccountsOnServer(3).keys)

        // Builds SOQL sync down target and performs initial sync
        let soql = "SELECT Id, Name FROM Account WHERE Id IN \(buildInClause(accountIds))"
        let syncId = NSNumber(value: trySyncDown(.leaveIfChanged, target: SFSoqlSyncDownTarget.newSyncTarget(soql), soupName: ACCOUNTS_SOUP, totalSize: UInt(accountIds.count), numberFetches: 1))
        checkDbExists(ACCOUNTS_SOUP, ids: accountIds, idField: "Id")

        // Deletes 1 account on the server and verifies the ghost record is cleared from the soup
        deleteAccounts(onServer: [accountIds[0]])
        let cleanResyncGhosts = expectation(description: "cleanResyncGhosts")
        try? syncManager.cleanResyncGhosts(forId: syncId) { syncStatus, _ in
            if syncStatus == .failed || syncStatus == .done {
                cleanResyncGhosts.fulfill()
            }
        }
        // Sync running check skipped - private API
        waitForExpectations(timeout: 30.0, handler: nil)
        checkDbDeleted(ACCOUNTS_SOUP, ids: [accountIds[0]], idField: "Id")
        // Sync not running check skipped - private API

        // Deletes the remaining accounts on the server
        deleteAccounts(onServer: accountIds)
    }

    /// Tests clean ghosts when soup is populated through more than one sync down
    func testCleanResyncGhostsWithMultipleSyncs() {
        createAccountsSoup()

        // Creates 6 accounts on the server
        let accountIds = Array(createAccountsOnServer(6).keys)
        let accountIdsFirstSubset = Array(accountIds[0..<3])  // id0, id1, id2
        let accountIdsSecondSubset = Array(accountIds[2..<6]) // id2, id3, id4, id5

        // Runs a first SOQL sync down target (bringing down id0, id1, id2)
        let firstSyncId = NSNumber(value: trySyncDown(.leaveIfChanged, target: SFSoqlSyncDownTarget.newSyncTarget("SELECT Id, Name FROM Account WHERE Id IN \(buildInClause(accountIdsFirstSubset))"), soupName: ACCOUNTS_SOUP, totalSize: UInt(accountIdsFirstSubset.count), numberFetches: 1))
        checkDbExists(ACCOUNTS_SOUP, ids: accountIdsFirstSubset, idField: "Id")
        checkDbSyncIdField(accountIdsFirstSubset, soupName: ACCOUNTS_SOUP, syncId: firstSyncId)

        // Runs a second SOQL sync down target (bringing down id2, id3, id4, id5)
        let secondSyncId = NSNumber(value: trySyncDown(.leaveIfChanged, target: SFSoqlSyncDownTarget.newSyncTarget("SELECT Id, Name FROM Account WHERE Id IN \(buildInClause(accountIdsSecondSubset))"), soupName: ACCOUNTS_SOUP, totalSize: UInt(accountIdsSecondSubset.count), numberFetches: 1))
        checkDbExists(ACCOUNTS_SOUP, ids: accountIdsSecondSubset, idField: "Id")
        checkDbSyncIdField(accountIdsSecondSubset, soupName: ACCOUNTS_SOUP, syncId: secondSyncId)

        // Deletes id0, id2, id5 on the server
        deleteAccounts(onServer: [accountIds[0], accountIds[2], accountIds[5]])

        // Cleaning ghosts of first sync (should only remove id0)
        let firstCleanExpectation = expectation(description: "firstCleanGhosts")
        try? syncManager.cleanResyncGhosts(forId: firstSyncId) { syncStatus, _ in
            if syncStatus == .failed || syncStatus == .done {
                firstCleanExpectation.fulfill()
            }
        }
        waitForExpectations(timeout: 30.0, handler: nil)
        checkDbExists(ACCOUNTS_SOUP, ids: [accountIds[1], accountIds[2], accountIds[3], accountIds[4], accountIds[5]], idField: "Id")
        checkDbDeleted(ACCOUNTS_SOUP, ids: [accountIds[0]], idField: "Id")

        // Cleaning ghosts of second sync (should remove id2 and id5)
        let secondCleanExpectation = expectation(description: "secondCleanGhosts")
        try? syncManager.cleanResyncGhosts(forId: secondSyncId) { syncStatus, _ in
            if syncStatus == .failed || syncStatus == .done {
                secondCleanExpectation.fulfill()
            }
        }
        waitForExpectations(timeout: 30.0, handler: nil)
        checkDbExists(ACCOUNTS_SOUP, ids: [accountIds[1], accountIds[3], accountIds[4]], idField: "Id")
        checkDbDeleted(ACCOUNTS_SOUP, ids: [accountIds[0], accountIds[2], accountIds[5]], idField: "Id")

        // Deletes the remaining accounts on the server
        deleteAccounts(onServer: [accountIds[1], accountIds[3], accountIds[4]])
    }

    /// Tests if ghost records are cleaned locally for a MRU target
    func testCleanResyncGhostsForMRUTarget() {
        createAccountsSoup()

        let request = RestClient.sharedInstance.requestForMetadata(withObjectType: ACCOUNT_TYPE, apiVersion: SFRestDefaultAPIVersion)
        let existingAccounts = sendSyncRequest(request)?[kRecentItems] as? [[String: Any]] ?? []

        // Creates 3 accounts on the server
        var accountIds = Array(createAccountsOnServer(3).keys)
        for account in existingAccounts {
            if let accountId = account[ID] as? String {
                accountIds.append(accountId)
            }
        }

        // Builds MRU sync down target and performs initial sync
        let syncId = NSNumber(value: trySyncDown(.leaveIfChanged, target: SFMruSyncDownTarget.newSyncTarget(ACCOUNT_TYPE, fieldlist: [ID, NAME, DESCRIPTION]), soupName: ACCOUNTS_SOUP, totalSize: UInt(accountIds.count), numberFetches: 1))
        checkDbExists(ACCOUNTS_SOUP, ids: accountIds, idField: "Id")

        // Deletes 1 account on the server and verifies the ghost record is cleared from the soup
        deleteAccounts(onServer: [accountIds[0]])
        let cleanResyncGhosts = expectation(description: "cleanResyncGhosts")
        try? syncManager.cleanResyncGhosts(forId: syncId) { syncStatus, _ in
            if syncStatus == .failed || syncStatus == .done {
                cleanResyncGhosts.fulfill()
            }
        }
        waitForExpectations(timeout: 30.0, handler: nil)
        checkDbDeleted(ACCOUNTS_SOUP, ids: [accountIds[0]], idField: "Id")

        // Deletes the remaining accounts on the server
        deleteAccounts(onServer: accountIds)
    }

    /// Tests if ghost records are cleaned locally for a SOSL target
    func testCleanResyncGhostsForSOSLTarget() {
        createAccountsSoup()

        // Creates 1 account on the server
        let accountIdToFields = createAccountsOnServer(1)
        Thread.sleep(forTimeInterval: 1) // give server a second to settle

        let accountIds = Array(accountIdToFields.keys)
        var accountNames: [String] = []
        for fields in accountIdToFields.values {
            if let name = fields[NAME] as? String {
                accountNames.append(name)
            }
        }

        // Builds SOSL sync down target and performs initial sync
        let searchQuery = accountNames.joined(separator: " OR ")
        let soslBuilder = SFSDKSoslBuilder.withSearchTerm(searchQuery)
        let returningBuilder = SFSDKSoslReturningBuilder.withObjectName(ACCOUNT_TYPE)
        returningBuilder.fields("Id, Name, Description")
        let sosl = soslBuilder.returning(returningBuilder).searchGroup("NAME FIELDS").build() ?? ""
        let syncId = NSNumber(value: trySyncDown(.leaveIfChanged, target: SFSoslSyncDownTarget.newSyncTarget(sosl), soupName: ACCOUNTS_SOUP, totalSize: UInt(accountIds.count), numberFetches: 1))
        checkDbExists(ACCOUNTS_SOUP, ids: accountIds, idField: "Id")

        // Deletes 1 account on the server and verifies the ghost record is cleared from the soup
        deleteAccounts(onServer: [accountIds[0]])
        Thread.sleep(forTimeInterval: 1) // give server a second to settle

        let cleanResyncGhosts = expectation(description: "cleanResyncGhosts")
        try? syncManager.cleanResyncGhosts(forId: syncId) { syncStatus, _ in
            if syncStatus == .failed || syncStatus == .done {
                cleanResyncGhosts.fulfill()
            }
        }
        waitForExpectations(timeout: 30.0, handler: nil)
        checkDbDeleted(ACCOUNTS_SOUP, ids: [accountIds[0]], idField: "Id")

        // Deletes the remaining accounts on the server
        deleteAccounts(onServer: accountIds)
    }

    /// Test instantiation of sync manager from various sharedInstance methods
    func testSyncManagerSharedInstanceMethods() {
        guard let user = currentUser else { return }
        let mgr1 = SFMobileSyncSyncManager.sharedInstance(forUserAccount: user)
        let store1 = SmartStore.shared(withName: SmartStoreConstants.defaultStoreName)
        let mgr2 = SFMobileSyncSyncManager.sharedInstance(store: store1!)
        let mgr3 = SFMobileSyncSyncManager.sharedInstanceForUser(user, storeName: SmartStoreConstants.defaultStoreName)
        XCTAssertEqual(mgr1, mgr2, "Sync managers should be the same.")
        XCTAssertEqual(mgr1, mgr3, "Sync managers should be the same.")
        let storeName2 = "AnotherStore"
        let mgr4 = SFMobileSyncSyncManager.sharedInstance(forUserAccount: user)
        let store2 = SmartStore.shared(withName: storeName2)
        let mgr5 = SFMobileSyncSyncManager.sharedInstance(store: store2!)
        let mgr6 = SFMobileSyncSyncManager.sharedInstanceForUser(user, storeName: storeName2)
        XCTAssertEqual(mgr1, mgr4, "Sync managers should be the same.")
        XCTAssertNotEqual(mgr4, mgr5, "Sync managers should not be the same.")
        XCTAssertNotEqual(mgr4, mgr6, "Sync managers should not be the same.")
        XCTAssertEqual(mgr5, mgr6, "Sync managers should be the same.")

        SmartStore.removeShared(withName: storeName2, forUserAccount: user)
    }

    /// getSyncStatus should return null for invalid sync id
    func testGetSyncStatusForInvalidSyncId() {
        let sync = syncManager.getSyncStatus(NSNumber(value: -1))
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

        // Make some local change
        let idToFieldsLocallyUpdated = makeSomeLocalChanges()

        // sync down again with MergeMode.LEAVE_IF_CHANGED
        trySyncDown(.leaveIfChanged)

        // Check db
        var idToFieldsExpected = idToFields
        for (key, value) in idToFieldsLocallyUpdated { idToFieldsExpected[key] = value }
        checkDb(idToFieldsExpected)

        // sync down again with MergeMode.OVERWRITE
        trySyncDown(.overwrite)
        checkDb(idToFields)
    }

    /// Test for sync down with metadata target
    func testSyncDownForMetadataTarget() {
        let indexSpecs: [SoupIndex] = [
            SoupIndex(path: "Id", indexType: kSoupIndexTypeString, columnName: nil)
        ].compactMap { $0 }
        try? store.registerSoup(withName: ACCOUNTS_SOUP, withIndices: indexSpecs)
        trySyncDown(.overwrite, target: SFMetadataSyncDownTarget.newSyncTarget(ACCOUNT_TYPE), soupName: ACCOUNTS_SOUP, totalSize: 1, numberFetches: 1)
        let smartSql = "SELECT {accounts:_soup} FROM {accounts}"
        guard let querySpec = QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: 1) else { return }
        let rows = (try? store.query(using: querySpec, startingFromPageIndex: 0)) ?? []
        XCTAssertEqual(rows.count, 1, "Number of rows should be 1")
        guard let rowArray = rows[0] as? [Any], let metadata = rowArray[0] as? [String: Any] else { return }
        XCTAssertNotNil(metadata, "Metadata should not be nil")
        XCTAssertEqual(metadata["keyPrefix"] as? String, "001", "Key prefix should be 001")
        XCTAssertEqual(metadata["label"] as? String, ACCOUNT_TYPE, "Label should be Account")
    }

    /// Test for sync down with layout target
    func testSyncDownForLayoutTarget() {
        let indexSpecs: [SoupIndex] = [
            SoupIndex(path: "Id", indexType: kSoupIndexTypeString, columnName: nil)
        ].compactMap { $0 }
        try? store.registerSoup(withName: ACCOUNTS_SOUP, withIndices: indexSpecs)
        trySyncDown(.overwrite, target: SFLayoutSyncDownTarget.newSyncTarget(ACCOUNT_TYPE, formFactor: "Medium", layoutType: "Compact", mode: "Edit", recordTypeId: nil), soupName: ACCOUNTS_SOUP, totalSize: 1, numberFetches: 1)
        let smartSql = "SELECT {accounts:_soup} FROM {accounts}"
        guard let querySpec = QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: 1) else { return }
        let rows = (try? store.query(using: querySpec, startingFromPageIndex: 0)) ?? []
        XCTAssertEqual(rows.count, 1, "Number of rows should be 1")
        guard let rowArray = rows[0] as? [Any], let layout = rowArray[0] as? [String: Any] else { return }
        XCTAssertNotNil(layout, "Layout should not be nil")
        XCTAssertEqual(layout["layoutType"] as? String, "Compact", "Layout type should be Compact")
        XCTAssertEqual(layout["mode"] as? String, "Edit", "Mode should be Edit")
    }

    /// Sync down the test accounts, modify a few on the server, re-sync, make sure only the updated ones are downloaded
    func testReSync() {
        createTestData()

        let syncId = NSNumber(value: trySyncDown(.overwrite))

        // Check sync time stamp
        guard let sync = syncManager.getSyncStatus(syncId) else { return }
        let target = sync.target as? SFSyncDownTarget
        let options = sync.options
        let maxTimeStamp = sync.maxTimeStamp
        XCTAssertTrue(maxTimeStamp > 0)

        // Make some remote changes
        let idToFieldsUpdated = makeSomeRemoteChanges()

        // Call reSync
        let queue = SFSyncUpdateCallbackQueue()
        _ = queue.runReSync(syncId, syncManager: syncManager)

        // Check status updates
        checkStatus(queue.getNextSyncUpdate(), expectedType: .down, expectedId: syncId.intValue, expectedTarget: target, expectedOptions: options, expectedStatus: .running, expectedProgress: 0, expectedTotalSize: -1)
        checkStatus(queue.getNextSyncUpdate(), expectedType: .down, expectedId: syncId.intValue, expectedTarget: target, expectedOptions: options, expectedStatus: .running, expectedProgress: 0, expectedTotalSize: idToFieldsUpdated.count)
        checkStatus(queue.getNextSyncUpdate(), expectedType: .down, expectedId: syncId.intValue, expectedTarget: target, expectedOptions: options, expectedStatus: .done, expectedProgress: 100, expectedTotalSize: idToFieldsUpdated.count)

        // Check db
        checkDb(idToFieldsUpdated)

        // Check sync time stamp
        XCTAssertTrue(syncManager.getSyncStatus(syncId)?.maxTimeStamp ?? 0 > maxTimeStamp)
    }

    /// Tests refresh-sync-down
    func testRefreshSyncDown() {
        createTestData()

        // Adding soup elements with just ids to soup
        for accountId in idToFields.keys {
            _ = store.upsert(entries: [[ID: accountId]] as! [[String: Any]], forSoupNamed: ACCOUNTS_SOUP)
        }

        // Running a refresh-sync-down for soup
        let target = SFRefreshSyncDownTarget.newSyncTarget(ACCOUNTS_SOUP, objectType: ACCOUNT_TYPE, fieldlist: [ID, NAME, DESCRIPTION])
        trySyncDown(.overwrite, target: target, soupName: ACCOUNTS_SOUP, totalSize: UInt(idToFields.count), numberFetches: 1)
        checkDb(idToFields)
    }

    /// Tests refresh-sync-down when there are more records than can be enumerated in one soql call
    func testRefreshSyncDownWithMultipleRoundTrips() {
        createTestData()

        for accountId in idToFields.keys {
            _ = store.upsert(entries: [[ID: accountId]] as! [[String: Any]], forSoupNamed: ACCOUNTS_SOUP)
        }

        let target = SFRefreshSyncDownTarget.newSyncTarget(ACCOUNTS_SOUP, objectType: ACCOUNT_TYPE, fieldlist: [ID, NAME, DESCRIPTION])
        // target.countIdsPerSoql = 2 // private - skip in Swift
        trySyncDown(.overwrite, target: target, soupName: ACCOUNTS_SOUP, totalSize: UInt(idToFields.count), numberFetches: UInt(idToFields.count / 2))
        checkDb(idToFields)
    }

    /// Tests if ghost records are cleaned locally for a refresh target
    func testCleanResyncGhostsForRefreshTarget() {
        createTestData()

        // Adding soup elements with just ids to soup
        let accountIds = Array(idToFields.keys)
        for accountId in accountIds {
            _ = store.upsert(entries: [[ID: accountId]] as! [[String: Any]], forSoupNamed: ACCOUNTS_SOUP)
        }

        // Running a refresh-sync-down for soup
        let target = SFRefreshSyncDownTarget.newSyncTarget(ACCOUNTS_SOUP, objectType: ACCOUNT_TYPE, fieldlist: [ID, NAME, DESCRIPTION])
        let syncId = NSNumber(value: trySyncDown(.overwrite, target: target, soupName: ACCOUNTS_SOUP, totalSize: UInt(idToFields.count), numberFetches: 1))

        // Deletes 1 account on the server
        let idDeleted = accountIds[0]
        deleteAccounts(onServer: [idDeleted])
        let cleanResyncGhosts = expectation(description: "cleanResyncGhosts")
        try? syncManager.cleanResyncGhosts(forId: syncId) { syncStatus, _ in
            if syncStatus == .failed || syncStatus == .done {
                cleanResyncGhosts.fulfill()
            }
        }
        waitForExpectations(timeout: 30.0, handler: nil)

        // Map of id to names expected to be found in db
        var idToFieldsLeft = idToFields
        idToFieldsLeft.removeValue(forKey: idDeleted)

        // Make sure the soup doesn't contain the record deleted on the server anymore
        checkDb(idToFieldsLeft)
        checkDbDeleted(ACCOUNTS_SOUP, ids: [idDeleted], idField: "Id")
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
        _ = createAccountsLocally(names)

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

    /// Tests the flow for a failure determining modification date
    func testCustomSyncUpWithFetchModificationDateFailure() {
        createTestData()
        trySyncDown(.leaveIfChanged)

        let idsToLocallyUpdated = makeSomeLocalChanges()

        let customTarget = TestSyncUpTarget(remoteModDateCompare: .remoteModDateGreaterThanLocal, sendRemoteModError: true, sendSyncUpError: false)
        trySyncUp(idsToLocallyUpdated.count, target: customTarget, mergeMode: .leaveIfChanged)
    }

    /// Tests the flow for a failure syncing up the data
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
        guard let date = isoDateFormatter.date(from: baseDateStr) else { return }
        let dateLong = Int64(date.timeIntervalSince1970 * 1000.0)
        let dateStr = SFMobileSyncObjectUtils.getIsoString(fromMillis: dateLong)

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

            XCTAssertEqual(basicQuery, SFSoqlSyncDownTarget.addFilterForReSync(originalBasicQuery, modDateFieldName: modDateFieldName, maxTimeStamp: dateLong))
            XCTAssertEqual(limitQuery, SFSoqlSyncDownTarget.addFilterForReSync(originalLimitQuery, modDateFieldName: modDateFieldName, maxTimeStamp: dateLong))
            XCTAssertEqual(nameQuery, SFSoqlSyncDownTarget.addFilterForReSync(originalNameQuery, modDateFieldName: modDateFieldName, maxTimeStamp: dateLong))
            XCTAssertEqual(nameLimitQuery, SFSoqlSyncDownTarget.addFilterForReSync(originalNameLimitQuery, modDateFieldName: modDateFieldName, maxTimeStamp: dateLong))
            XCTAssertEqual(basicQueryUpper, SFSoqlSyncDownTarget.addFilterForReSync(originalBasicQueryUpper, modDateFieldName: modDateFieldName, maxTimeStamp: dateLong))
            XCTAssertEqual(limitQueryUpper, SFSoqlSyncDownTarget.addFilterForReSync(originalLimitQueryUpper, modDateFieldName: modDateFieldName, maxTimeStamp: dateLong))
            XCTAssertEqual(nameQueryUpper, SFSoqlSyncDownTarget.addFilterForReSync(originalNameQueryUpper, modDateFieldName: modDateFieldName, maxTimeStamp: dateLong))
            XCTAssertEqual(nameLimitQueryUpper, SFSoqlSyncDownTarget.addFilterForReSync(originalNameLimitQueryUpper, modDateFieldName: modDateFieldName, maxTimeStamp: dateLong))
        }
    }

    /// Test that doing resync while corresponding sync is running fails
    func testReSyncRunningSync() {
        createTestData()

        let idsClause = buildInClause(Array(idToFields.keys))
        let soql = "SELECT Id, Name, LastModifiedDate FROM Account WHERE Id IN \(idsClause)"
        let target = SlowSoqlSyncDownTarget.newSlowSyncTarget(soql)
        let options = SFSyncOptions.newSyncOptions(forSyncDown: .leaveIfChanged)
        guard let sync = SFSyncState.newSyncDown(withOptions: options, target: target, soupName: ACCOUNTS_SOUP, name: nil, store: store) else { return }
        let syncId = NSNumber(value: sync.syncId)

        // Run sync -- will freeze during fetch
        let queue = SFSyncUpdateCallbackQueue()
        queue.runSync(sync, syncManager: syncManager)

        // Wait for sync to be running
        _ = queue.getNextSyncUpdate()

        // Calling reSync -- expect nil
        XCTAssertNil(try? syncManager.reSync(id: syncId, onUpdate: { _ in }))

        // Wait for sync to complete successfully
        while queue.getNextSyncUpdate()?.status != .done {}

        // Calling reSync again -- should return the SFSyncState
        XCTAssertEqual(sync.syncId, queue.runReSync(syncId, syncManager: syncManager)?.syncId)

        // Waiting for reSync to complete successfully
        while queue.getNextSyncUpdate()?.status != .done {}
    }

    /// Create sync down, get it by id, delete it by id, make sure it's gone
    func testCreateGetDeleteSyncDownById() {
        guard let sync = SFSyncState.newSyncDown(withOptions: SFSyncOptions.newSyncOptions(forSyncDown: .leaveIfChanged), target: SFSoqlSyncDownTarget.newSyncTarget("SELECT Id, Name from Account"), soupName: ACCOUNTS_SOUP, name: nil, store: store) else { return }
        let syncId = NSNumber(value: sync.syncId)
        let fetchedSync = SFSyncState.by(id: syncId, store: store)
        checkStatus(fetchedSync, expectedType: sync.type, expectedId: sync.syncId, expectedName: nil, expectedTarget: sync.target, expectedOptions: sync.options, expectedStatus: sync.status, expectedProgress: sync.progress, expectedTotalSize: sync.totalSize)
        SFSyncState.delete(byId: syncId, store: store)
        XCTAssertNil(SFSyncState.by(id: syncId, store: store), "Sync should be gone")
    }

    /// Create sync down with a name, get it by name, delete it by name, make sure it's gone
    func testCreateGetDeleteSyncDownByName() {
        let syncName = "MyNamedSyncDown"
        guard let sync = SFSyncState.newSyncDown(withOptions: SFSyncOptions.newSyncOptions(forSyncDown: .leaveIfChanged), target: SFSoqlSyncDownTarget.newSyncTarget("SELECT Id, Name from Account"), soupName: ACCOUNTS_SOUP, name: syncName, store: store) else { return }
        let syncId = NSNumber(value: sync.syncId)
        let fetchedSync = SFSyncState.by(name: syncName, store: store)
        checkStatus(fetchedSync, expectedType: sync.type, expectedId: sync.syncId, expectedName: syncName, expectedTarget: sync.target, expectedOptions: sync.options, expectedStatus: sync.status, expectedProgress: sync.progress, expectedTotalSize: sync.totalSize)
        SFSyncState.delete(byName: syncName, store: store)
        XCTAssertNil(SFSyncState.by(id: syncId, store: store), "Sync should be gone")
        XCTAssertNil(SFSyncState.by(name: syncName, store: store), "Sync should be gone")
    }

    /// Create sync up, get it by id, delete it by id, make sure it's gone
    func testCreateGetDeleteSyncUpById() {
        guard let sync = SFSyncState.newSyncUp(withOptions: SFSyncOptions.newSyncOptions(forSyncDown: .leaveIfChanged), target: SFSyncUpTarget(), soupName: ACCOUNTS_SOUP, name: nil, store: store) else { return }
        let syncId = NSNumber(value: sync.syncId)
        let fetchedSync = SFSyncState.by(id: syncId, store: store)
        checkStatus(fetchedSync, expectedType: sync.type, expectedId: sync.syncId, expectedName: nil, expectedTarget: sync.target, expectedOptions: sync.options, expectedStatus: sync.status, expectedProgress: sync.progress, expectedTotalSize: sync.totalSize)
        SFSyncState.delete(byId: syncId, store: store)
        XCTAssertNil(SFSyncState.by(id: syncId, store: store), "Sync should be gone")
    }

    /// Create sync up with a name, get it by name, delete it by name, make sure it's gone
    func testCreateGetDeleteSyncUpByName() {
        let syncName = "MyNamedSyncUp"
        guard let sync = SFSyncState.newSyncUp(withOptions: SFSyncOptions.newSyncOptions(forSyncDown: .leaveIfChanged), target: SFSyncUpTarget(), soupName: ACCOUNTS_SOUP, name: syncName, store: store) else { return }
        let syncId = NSNumber(value: sync.syncId)
        let fetchedSync = SFSyncState.by(name: syncName, store: store)
        checkStatus(fetchedSync, expectedType: sync.type, expectedId: sync.syncId, expectedName: syncName, expectedTarget: sync.target, expectedOptions: sync.options, expectedStatus: sync.status, expectedProgress: sync.progress, expectedTotalSize: sync.totalSize)
        SFSyncState.delete(byName: syncName, store: store)
        XCTAssertNil(SFSyncState.by(id: syncId, store: store), "Sync should be gone")
        XCTAssertNil(SFSyncState.by(name: syncName, store: store), "Sync should be gone")
    }

    /// Create sync with a name, make sure a new sync down with the same name cannot be created
    func testCreateSyncDownWithExistingName() {
        let syncName = "MyNamedSync"
        _ = SFSyncState.newSyncUp(withOptions: SFSyncOptions.newSyncOptions(forSyncDown: .leaveIfChanged), target: SFSyncUpTarget(), soupName: ACCOUNTS_SOUP, name: syncName, store: store)
        let secondSync = SFSyncState.newSyncDown(withOptions: SFSyncOptions.newSyncOptions(forSyncDown: .leaveIfChanged), target: SFSoqlSyncDownTarget.newSyncTarget("SELECT Id, Name from Account"), soupName: ACCOUNTS_SOUP, name: syncName, store: store)
        XCTAssertNil(secondSync, "sync should nil")
        SFSyncState.delete(byName: syncName, store: store)
        XCTAssertNil(SFSyncState.by(name: syncName, store: store), "Sync should be gone")
    }

    /// Create sync with a name, make sure a new sync up with the same name cannot be created
    func testCreateSyncUpWithExistingName() {
        let syncName = "MyNamedSync"
        _ = SFSyncState.newSyncDown(withOptions: SFSyncOptions.newSyncOptions(forSyncDown: .leaveIfChanged), target: SFSoqlSyncDownTarget.newSyncTarget("SELECT Id, Name from Account"), soupName: ACCOUNTS_SOUP, name: syncName, store: store)
        let secondSync = SFSyncState.newSyncUp(withOptions: SFSyncOptions.newSyncOptions(forSyncDown: .leaveIfChanged), target: SFSyncUpTarget(), soupName: ACCOUNTS_SOUP, name: syncName, store: store)
        XCTAssertNil(secondSync, "sync should nil")
        SFSyncState.delete(byName: syncName, store: store)
        XCTAssertNil(SFSyncState.by(name: syncName, store: store), "Sync should be gone")
    }

    /// Run sync down using TestSyncDownTarget
    func testCustomSyncDownTarget() {
        createAccountsSoup()
        let numberOfRecords: UInt = 30
        let target = TestSyncDownTarget(prefix: "test", numberOfRecords: numberOfRecords, numberOfRecordsPerPage: 10, sleepPerFetch: 0)
        let syncId = trySyncDown(.leaveIfChanged, target: target, soupName: ACCOUNTS_SOUP, totalSize: numberOfRecords, numberFetches: 3)

        // Check sync time stamp
        let sync = syncManager.getSyncStatus(NSNumber(value: syncId))
        XCTAssertEqual(target.dateForPositionAsMillis(numberOfRecords - 1), sync?.maxTimeStamp ?? 0, "Wrong timestamp")

        // Check db
        checkDbForAfterTestSyncDown(target, soupName: ACCOUNTS_SOUP, expectedNumberOfRecords: numberOfRecords)
    }

    // MARK: - Helper methods

    private func checkSyncState(_ syncId: NSNumber, expectedTimeStamp: Int64, expectedStatus: SFSyncStateStatus) {
        let sync = syncManager.getSyncStatus(syncId)
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
            guard let row = result[i] as? [Any] else { continue }
            XCTAssertEqual(target.idForPosition(UInt(i)), row[0] as? String, "Wrong id")
        }
    }

    @discardableResult
    private func trySyncDown(_ mergeMode: SFSyncStateMergeMode) -> NSInteger {
        let idsClause = buildInClause(Array(idToFields.keys))
        let soql = "SELECT Id, Name, Description, LastModifiedDate FROM Account WHERE Id IN \(idsClause)"
        let target = SFSoqlSyncDownTarget.newSyncTarget(soql)
        return trySyncDown(mergeMode, target: target, soupName: ACCOUNTS_SOUP, totalSize: UInt(idToFields.count), numberFetches: 1)
    }

    private func checkDb(_ dict: [String: [String: Any]]) {
        checkDb(dict, soupName: ACCOUNTS_SOUP)
    }

    private func createTestData() {
        createAccountsSoup()
        idToFields = createAccountsOnServer(COUNT_TEST_ACCOUNTS)
    }

    private func deleteTestData() {
        deleteAccounts(onServer: Array(idToFields.keys))
        dropAccountsSoup()
        deleteSyncs()
        idToFields = [:]
    }

    private func makeSomeLocalChanges() -> [String: [String: Any]] {
        return makeSomeLocalChanges(idToFields, soupName: ACCOUNTS_SOUP)
    }

    private func makeSomeRemoteChanges() -> [String: [String: Any]] {
        return makeSomeRemoteChanges(idToFields, objectType: ACCOUNT_TYPE)
    }
}
