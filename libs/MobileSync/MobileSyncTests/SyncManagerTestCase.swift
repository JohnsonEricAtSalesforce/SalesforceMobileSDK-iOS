/*
 Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.

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
@testable import SmartStore
import SalesforceSDKCore
@testable import MobileSync

// Constants
let ACCOUNTS_SOUP = "accounts"
let ACCOUNT_TYPE = "Account"
let ID = "Id"
let NAME = "Name"
let DESCRIPTION = "Description"
let LAST_MODIFIED_DATE = "LastModifiedDate"
let ATTRIBUTES = "attributes"
let TYPE = "type"
let RECORDS = "records"
let CONTACT_TYPE = "Contact"
let LAST_NAME = "LastName"
let CONTACTS_SOUP = "contacts"
let ACCOUNT_ID = "AccountId"
let CONTACT_TYPE_PLURAL = "Contacts"
let TOTAL_SIZE_UNKNOWN: Int = -2
let REMOTELY_UPDATED = "_r_upd"
let LOCALLY_UPDATED = "_l_upd"

// Block type
typealias SFRecordMutatorBlock = (NSMutableDictionary) -> NSMutableDictionary

// Merge mode type alias for convenience in tests
typealias SyncMergeMode = SFSyncStateMergeMode

private var authException: NSException?

class SyncManagerTestCase: XCTestCase {

    var currentUser: UserAccount?
    var syncManager: SFMobileSyncSyncManager!
    var store: SmartStore!
    var globalSyncManager: SFMobileSyncSyncManager!
    var globalStore: SmartStore!

    override class func setUp() {
        super.setUp()
        do {
            // Log level managed by SalesforceLogger
            TestSetupUtils.populateAuthCredentials(fromConfigFileFor: self)
            TestSetupUtils.synchronousAuthRefresh()
            SmartStore.removeAllForCurrentUser()
            SmartStore.removeAllGlobal()
        } catch {
            // This shouldn't happen in Swift, but keep the pattern
        }
    }

    override func setUpWithError() throws {
        super.setUp()
        // Skip (do not crash the host) when the live-org auth refresh didn't complete. See
        // TestSetupUtils.authRefreshDidSucceed — the pre-token-refresh-coordinator flow hangs in the
        // sim even with a valid token; the old fatal assert aborted the whole run and masked later tests.
        // MobileSync sync tests all require a live sandbox org, so this class skips locally.
        try XCTSkipUnless(TestSetupUtils.authRefreshDidSucceed, "Live-org auth refresh unavailable (known pre-coordinator hang); skipping live MobileSync tests.")
        if let exception = authException {
            XCTFail("Setting up authentication failed: \(exception)")
        }
        RestClient.setIsTestRun(true)

        // User and managers setup
        currentUser = UserAccountManager.shared.currentUserAccount
        if let user = currentUser {
            syncManager = SFMobileSyncSyncManager.sharedInstance(forUserAccount: user)
            store = SmartStore.shared(withName: SmartStoreConstants.defaultStoreName, forUserAccount: user)
        }
        globalStore = SmartStore.sharedGlobal(withName: SmartStoreConstants.defaultStoreName)
        globalSyncManager = SFMobileSyncSyncManager.sharedInstance(store: globalStore)
    }

    override func tearDown() {
        // User and managers tear down
        deleteSyncs()
        deleteGlobalSyncs()
        if let user = currentUser {
            SFMobileSyncSyncManager.removeSharedInstance(user)
        }
        RestClient.sharedInstance.cleanup()
        RestClient.setIsTestRun(false)

        currentUser = nil
        syncManager = nil
        store = nil

        // Some test runs were failing, saying the run didn't complete. This seems to fix that.
        Thread.sleep(forTimeInterval: 0.1)
        super.tearDown()
    }

    // MARK: - Sync management

    func deleteSyncs() {
        store?.clearSoup(kSFSyncStateSyncsSoupName)
    }

    func deleteGlobalSyncs() {
        globalStore?.clearSoup(kSFSyncStateSyncsSoupName)
    }

    // MARK: - Record name generation

    func createRecordName(_ objectType: String) -> String {
        return "SyncTest_\(objectType)_\(UInt(Date().timeIntervalSince1970 * 1000))\(String(format: "%03d", arc4random_uniform(1000)))"
    }

    func createAccountName() -> String {
        return createRecordName(ACCOUNT_TYPE)
    }

    func createDescription(_ name: String) -> String {
        return "Description_\(name)"
    }

    func buildInClause(_ values: [String]) -> String {
        return "('" + values.joined(separator: "', '") + "')"
    }

    // MARK: - Local record creation

    func createAccountsLocally(_ names: [String]) -> [Any] {
        return createAccountsLocally(names, mutateBlock: nil)
    }

    func createAccountsLocally(_ names: [String], mutateBlock: SFRecordMutatorBlock?) -> [Any] {
        var createdAccounts: [[String: Any]] = []
        let attributes: [String: Any] = [TYPE: ACCOUNT_TYPE]
        for name in names {
            var account: NSMutableDictionary = NSMutableDictionary()
            let accountId = SFSyncTarget.createLocalId()
            account[ID] = accountId
            account[NAME] = name
            account[DESCRIPTION] = createDescription(name)
            account[ATTRIBUTES] = attributes
            account[kSyncTargetLocal] = true
            account[kSyncTargetLocallyCreated] = true
            account[kSyncTargetLocallyDeleted] = false
            account[kSyncTargetLocallyUpdated] = false
            if let block = mutateBlock {
                account = block(account)
            }
            createdAccounts.append(account as! [String: Any])
        }
        return store.upsert(entries: createdAccounts, forSoupNamed: ACCOUNTS_SOUP)
    }

    func createContacts(forAccountsLocally accountIds: [String], numberOfContactsPerAccounts numberOfContacts: Int) -> [Any] {
        var createdContacts: [[String: Any]] = []
        let attributes: [String: Any] = [TYPE: CONTACT_TYPE]
        for accountId in accountIds {
            for _ in 0..<numberOfContacts {
                var contact: [String: Any] = [:]
                let contactId = SFSyncTarget.createLocalId()
                contact[ID] = contactId
                contact[ACCOUNT_ID] = accountId
                contact[LAST_NAME] = createRecordName(CONTACT_TYPE)
                contact[ATTRIBUTES] = attributes
                contact[kSyncTargetLocal] = true
                contact[kSyncTargetLocallyCreated] = true
                contact[kSyncTargetLocallyDeleted] = false
                contact[kSyncTargetLocallyUpdated] = false
                createdContacts.append(contact)
            }
        }
        return store.upsert(entries: createdContacts, forSoupNamed: CONTACTS_SOUP)
    }

    // MARK: - Soup creation/deletion

    func createAccountsSoup() {
        let indexSpecs: [SoupIndex] = [
            SoupIndex(path: ID, indexType: kSoupIndexTypeString, columnName: nil),
            SoupIndex(path: NAME, indexType: kSoupIndexTypeString, columnName: nil),
            SoupIndex(path: DESCRIPTION, indexType: kSoupIndexTypeFullText, columnName: nil),
            SoupIndex(path: kSyncTargetLocal, indexType: kSoupIndexTypeString, columnName: nil),
            SoupIndex(path: kSyncTargetSyncId, indexType: kSoupIndexTypeInteger, columnName: nil)
        ].compactMap { $0 }
        try? store.registerSoup(withName: ACCOUNTS_SOUP, withIndices: indexSpecs)
    }

    func dropAccountsSoup() {
        store.removeSoup(ACCOUNTS_SOUP)
    }

    func createContactsSoup() {
        let indexSpecs: [SoupIndex] = [
            SoupIndex(path: ID, indexType: kSoupIndexTypeString, columnName: nil),
            SoupIndex(path: LAST_NAME, indexType: kSoupIndexTypeString, columnName: nil),
            SoupIndex(path: ACCOUNT_ID, indexType: kSoupIndexTypeString, columnName: nil),
            SoupIndex(path: kSyncTargetLocal, indexType: kSoupIndexTypeString, columnName: nil),
            SoupIndex(path: kSyncTargetSyncId, indexType: kSoupIndexTypeInteger, columnName: nil)
        ].compactMap { $0 }
        try? store.registerSoup(withName: CONTACTS_SOUP, withIndices: indexSpecs)
    }

    func dropContactsSoup() {
        store.removeSoup(CONTACTS_SOUP)
    }

    // MARK: - Server operations

    func deleteRecords(onServer ids: [String], objectType: String) {
        let maxIdsPerSlice = 200
        let countIds = ids.count
        let countSlices = Int(ceil(Double(countIds) / Double(maxIdsPerSlice)))

        for slice in 0..<countSlices {
            let sliceStartIndex = slice * maxIdsPerSlice
            let sliceEndIndex = min(countIds, (slice + 1) * maxIdsPerSlice)
            let idsToDelete = Array(ids[sliceStartIndex..<sliceEndIndex])
            let request = RestClient.sharedInstance.requestForCollectionDelete(true, objectIds: idsToDelete, apiVersion: nil)
            _ = sendSyncRequest(request)
        }
    }

    @discardableResult
    func sendSyncRequest(_ request: RestRequest) -> [String: Any]? {
        return sendSyncRequest(request, ignoreNotFound: false)
    }

    @discardableResult
    func sendSyncRequest(_ request: RestRequest, ignoreNotFound: Bool) -> [String: Any]? {
        let listener = SFSDKTestRequestListener()
        let failBlock: RestRequestFailBlock = { response, error, rawResponse in
            listener.lastError = error as NSError?
            listener.returnStatus = kTestRequestStatusDidFail
        }
        let completeBlock: RestResponseBlock = { data, rawResponse in
            listener.dataResponse = data
            listener.returnStatus = kTestRequestStatusDidLoad
        }
        RestClient.sharedInstance.send(request, failureBlock: failBlock, successBlock: completeBlock)
        listener.waitForCompletion()
        if let error = listener.lastError,
           (error as NSError).code != 404 || !ignoreNotFound {
            XCTFail("Rest call \(request) failed with error \(error)")
        }
        return listener.dataResponse as? [String: Any]
    }

    // MARK: - Record creation on server

    func buildFieldsMapForRecords(_ count: UInt, objectType: String, additionalFields: [String: Any]?) -> [[String: Any]] {
        var listFields: [[String: Any]] = []
        for _ in 0..<count {
            let name = createRecordName(objectType)
            var fields: [String: Any] = [:]

            if let additional = additionalFields {
                fields.merge(additional) { _, new in new }
            }

            if objectType == ACCOUNT_TYPE {
                fields[NAME] = name
                fields[DESCRIPTION] = createDescription(name)
            } else if objectType == CONTACT_TYPE {
                fields[LAST_NAME] = name
            }

            listFields.append(fields)
        }
        return listFields
    }

    @discardableResult
    func createAccountsOnServer(_ count: UInt) -> [String: [String: Any]] {
        return createRecordsOnServerReturnFields(count, objectType: ACCOUNT_TYPE, additionalFields: nil)
    }

    @discardableResult
    func createRecords(onServer count: UInt, objectType: String) -> [String: String]? {
        let idToFields = createRecordsOnServerReturnFields(count, objectType: objectType, additionalFields: nil)
        var idToNames: [String: String] = [:]
        for (recordId, fields) in idToFields {
            let nameField = (objectType == CONTACT_TYPE) ? LAST_NAME : NAME
            if let name = fields[nameField] as? String {
                idToNames[recordId] = name
            }
        }
        return idToNames
    }

    func createRecordsOnServerReturnFields(_ count: UInt, objectType: String, additionalFields: [String: Any]?) -> [String: [String: Any]] {
        let listFields = buildFieldsMapForRecords(count, objectType: objectType, additionalFields: additionalFields)
        var requests: [RestRequest] = []
        for i in 0..<Int(count) {
            requests.append(RestClient.sharedInstance.requestForCreate(withObjectType: objectType, fields: listFields[i], apiVersion: SFRestDefaultAPIVersion))
        }

        var idToFields: [String: [String: Any]] = [:]
        if let batchResponse = sendSyncRequest(RestClient.sharedInstance.batchRequest(requests, haltOnError: false, apiVersion: SFRestDefaultAPIVersion)) {
            if let results = batchResponse["results"] as? [[String: Any]] {
                for i in 0..<results.count {
                    let result = results[i]
                    XCTAssertEqual(201, result["statusCode"] as? Int, "Status code should be HTTP_CREATED")
                    if let resultBody = result["result"] as? [String: Any],
                       let recordId = resultBody["id"] as? String {
                        idToFields[recordId] = listFields[i]
                    }
                }
            }
        }
        return idToFields
    }

    // MARK: - Sync down

    @discardableResult
    func trySyncDown(_ mergeMode: SFSyncStateMergeMode, target: SFSyncDownTarget, soupName: String, totalSize: UInt, numberFetches: UInt) -> NSInteger {
        // Creates sync
        let options = SFSyncOptions.newSyncOptions(forSyncDown: mergeMode)
        guard let sync = SFSyncState.newSyncDown(withOptions: options, target: target, soupName: soupName, name: nil, store: store) else {
            XCTFail("Failed to create sync down")
            return -1
        }
        let syncId = sync.syncId
        checkStatus(sync, expectedType: .down, expectedId: syncId, expectedTarget: target, expectedOptions: options, expectedStatus: .new, expectedProgress: 0, expectedTotalSize: -1)

        // Runs sync
        let queue = SFSyncUpdateCallbackQueue()
        queue.runSync(sync, syncManager: syncManager)

        // Checks status updates
        checkStatus(queue.getNextSyncUpdate(), expectedType: .down, expectedId: syncId, expectedTarget: target, expectedOptions: options, expectedStatus: .running, expectedProgress: 0, expectedTotalSize: -1)
        if Int(totalSize) != TOTAL_SIZE_UNKNOWN {
            for i in 0..<Int(numberFetches) {
                checkStatus(queue.getNextSyncUpdate(), expectedType: .down, expectedId: syncId, expectedTarget: target, expectedOptions: options, expectedStatus: .running, expectedProgress: i * 100 / Int(numberFetches), expectedTotalSize: Int(totalSize))
            }
            checkStatus(queue.getNextSyncUpdate(), expectedType: .down, expectedId: syncId, expectedTarget: target, expectedOptions: options, expectedStatus: .done, expectedProgress: 100, expectedTotalSize: Int(totalSize))
        } else {
            checkStatus(queue.getNextSyncUpdate(), expectedType: .down, expectedId: syncId, expectedTarget: target, expectedOptions: options, expectedStatus: .running, expectedProgress: 0)
            checkStatus(queue.getNextSyncUpdate(), expectedType: .down, expectedId: syncId, expectedTarget: target, expectedOptions: options, expectedStatus: .done, expectedProgress: 100)
        }
        return syncId
    }

    // MARK: - Status checking

    func checkStatus(_ sync: SFSyncState?, expectedType: SFSyncStateSyncType, expectedId: Int, expectedTarget: SFSyncTarget?, expectedOptions: SFSyncOptions?, expectedStatus: SFSyncStateStatus, expectedProgress: Int) {
        checkStatus(sync, expectedType: expectedType, expectedId: expectedId, expectedName: nil, expectedTarget: expectedTarget, expectedOptions: expectedOptions, expectedStatus: expectedStatus, expectedProgress: expectedProgress, expectedTotalSize: TOTAL_SIZE_UNKNOWN)
    }

    func checkStatus(_ sync: SFSyncState?, expectedType: SFSyncStateSyncType, expectedId: Int, expectedTarget: SFSyncTarget?, expectedOptions: SFSyncOptions?, expectedStatus: SFSyncStateStatus, expectedProgress: Int, expectedTotalSize: Int) {
        checkStatus(sync, expectedType: expectedType, expectedId: expectedId, expectedName: nil, expectedTarget: expectedTarget, expectedOptions: expectedOptions, expectedStatus: expectedStatus, expectedProgress: expectedProgress, expectedTotalSize: expectedTotalSize)
    }

    func checkStatus(_ sync: SFSyncState?, expectedType: SFSyncStateSyncType, expectedId: Int, expectedName: String?, expectedTarget: SFSyncTarget?, expectedOptions: SFSyncOptions?, expectedStatus: SFSyncStateStatus, expectedProgress: Int, expectedTotalSize: Int) {
        XCTAssertNotNil(sync)
        guard let sync = sync else { return }

        XCTAssertEqual(expectedType, sync.type)
        XCTAssertEqual(expectedId, sync.syncId)
        XCTAssertEqual(expectedStatus, sync.status)
        XCTAssertEqual(expectedProgress, sync.progress)
        if expectedTotalSize != TOTAL_SIZE_UNKNOWN {
            XCTAssertEqual(expectedTotalSize, sync.totalSize)
        }
        if let expectedTarget = expectedTarget {
            XCTAssertNotNil(sync.target)
            if expectedType == .down {
                XCTAssertTrue(sync.target is SFSyncDownTarget)
                let expectedQueryType = (expectedTarget as? SFSyncDownTarget)?.queryType ?? .custom
                XCTAssertEqual(expectedQueryType, (sync.target as? SFSyncDownTarget)?.queryType)
                if expectedQueryType == .soql {
                    XCTAssertTrue(sync.target is SFSoqlSyncDownTarget)
                    XCTAssertEqual((expectedTarget as? SFSoqlSyncDownTarget)?.query, (sync.target as? SFSoqlSyncDownTarget)?.query)
                } else if expectedQueryType == .sosl {
                    XCTAssertTrue(sync.target is SFSoslSyncDownTarget)
                    XCTAssertEqual((expectedTarget as? SFSoslSyncDownTarget)?.query, (sync.target as? SFSoslSyncDownTarget)?.query)
                } else if expectedQueryType == .mru {
                    XCTAssertTrue(sync.target is SFMruSyncDownTarget)
                    XCTAssertEqual((expectedTarget as? SFMruSyncDownTarget)?.objectType, (sync.target as? SFMruSyncDownTarget)?.objectType)
                    XCTAssertEqual((expectedTarget as? SFMruSyncDownTarget)?.fieldlist as? [String], (sync.target as? SFMruSyncDownTarget)?.fieldlist as? [String])
                } else if expectedQueryType == .refresh {
                    XCTAssertTrue(sync.target is SFRefreshSyncDownTarget)
                    XCTAssertEqual((expectedTarget as? SFRefreshSyncDownTarget)?.objectType, (sync.target as? SFRefreshSyncDownTarget)?.objectType)
                    XCTAssertEqual((expectedTarget as? SFRefreshSyncDownTarget)?.soupName, (sync.target as? SFRefreshSyncDownTarget)?.soupName)
                    XCTAssertEqual((expectedTarget as? SFRefreshSyncDownTarget)?.fieldlist as? [String], (sync.target as? SFRefreshSyncDownTarget)?.fieldlist as? [String])
                } else if expectedQueryType == .metadata {
                    XCTAssertTrue(sync.target is SFMetadataSyncDownTarget)
                    XCTAssertEqual((expectedTarget as? SFMetadataSyncDownTarget)?.objectType, (sync.target as? SFMetadataSyncDownTarget)?.objectType)
                } else if expectedQueryType == .layout {
                    XCTAssertTrue(sync.target is SFLayoutSyncDownTarget)
                    XCTAssertEqual((expectedTarget as? SFLayoutSyncDownTarget)?.objectAPIName, (sync.target as? SFLayoutSyncDownTarget)?.objectAPIName)
                    XCTAssertEqual((expectedTarget as? SFLayoutSyncDownTarget)?.layoutType, (sync.target as? SFLayoutSyncDownTarget)?.layoutType)
                } else if expectedQueryType == .briefcase {
                    XCTAssertTrue(sync.target is BriefcaseSyncDownTarget)
                } else if expectedQueryType == .custom {
                    XCTAssertTrue(sync.target is SFSyncDownTarget)
                }
            } else {
                if sync.target is SFBatchSyncUpTarget {
                    XCTAssertTrue(sync.target is SFBatchSyncUpTarget)
                }
                // Following applies to all sync up targets
                XCTAssertTrue(sync.target is SFSyncUpTarget)
                XCTAssertEqual((expectedTarget as? SFSyncUpTarget)?.createFieldlist as? [String], (sync.target as? SFSyncUpTarget)?.createFieldlist as? [String])
                XCTAssertEqual((expectedTarget as? SFSyncUpTarget)?.updateFieldlist as? [String], (sync.target as? SFSyncUpTarget)?.updateFieldlist as? [String])
                XCTAssertEqual((expectedTarget as? SFSyncUpTarget)?.externalIdFieldName, (sync.target as? SFSyncUpTarget)?.externalIdFieldName)
            }
        } else {
            XCTAssertNil(sync.target)
        }
        if let expectedOptions = expectedOptions {
            XCTAssertNotNil(sync.options)
            XCTAssertEqual(expectedOptions.mergeMode, sync.options?.mergeMode)
            XCTAssertEqual(expectedOptions.fieldlist as? [String], sync.options?.fieldlist as? [String])
        } else {
            XCTAssertNil(sync.options)
        }
        if sync.status != .new {
            XCTAssertTrue(sync.startTime > 0)
        }
        if sync.status == .done || sync.status == .failed {
            XCTAssertTrue(sync.endTime > 0)
            XCTAssertTrue(sync.endTime > sync.startTime)
        }
    }

    // MARK: - Database checks

    func checkDbExists(_ soupName: String, ids: [String], idField: String) {
        let smartSql = "SELECT {\(soupName):_soup} FROM {\(soupName)} WHERE {\(soupName):\(idField)} IN \(buildInClause(ids))"
        guard let query = QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: UInt(ids.count)) else { return }
        let rowsFromDb = (try? store.query(using: query, startingFromPageIndex: 0)) ?? []
        XCTAssertEqual(ids.count, rowsFromDb.count, "All records should have been returned from smartstore")
    }

    func checkDb(_ expectedIdToFields: [String: [String: Any]], soupName: String) {
        let idsClause = buildInClause(Array(expectedIdToFields.keys))
        let smartSql = "SELECT {\(soupName):_soup} FROM {\(soupName)} WHERE {\(soupName):Id} IN \(idsClause)"
        guard let query = QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: UInt(expectedIdToFields.count)) else { return }
        let rows = (try? store.query(using: query, startingFromPageIndex: 0)) ?? []
        XCTAssertEqual(expectedIdToFields.count, rows.count)
        for row in rows {
            guard let rowArray = row as? [Any],
                  let recordFromDb = rowArray[0] as? [String: Any],
                  let recordId = recordFromDb[ID] as? String,
                  let expectedFields = expectedIdToFields[recordId] else { continue }
            for fieldName in expectedFields.keys {
                let expected = expectedFields[fieldName]
                let actual = recordFromDb[fieldName]
                if let expectedStr = expected as? String {
                    XCTAssertEqual(expectedStr, actual as? String)
                } else if expected is NSNull {
                    XCTAssertTrue(actual == nil || actual is NSNull)
                } else {
                    XCTAssertEqual(expected as? NSObject, actual as? NSObject)
                }
            }
        }
    }

    func checkDbStateFlags(_ ids: [String], soupName: String, expectedLocallyCreated: Bool, expectedLocallyUpdated: Bool, expectedLocallyDeleted: Bool) {
        let expectedDirty = expectedLocallyCreated || expectedLocallyUpdated || expectedLocallyDeleted
        let idsClause = buildInClause(ids)
        let smartSql = "SELECT {\(soupName):_soup} FROM {\(soupName)} WHERE {\(soupName):Id} IN \(idsClause)"
        guard let query = QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: UInt(ids.count)) else { return }
        let rows = (try? store.query(using: query, startingFromPageIndex: 0)) ?? []
        XCTAssertEqual(ids.count, rows.count)
        for row in rows {
            guard let rowArray = row as? [Any],
                  let recordFromDb = rowArray[0] as? [String: Any] else { continue }
            XCTAssertEqual(expectedDirty, (recordFromDb[kSyncTargetLocal] as? Bool) ?? (recordFromDb[kSyncTargetLocal] as? NSNumber)?.boolValue ?? false)
            XCTAssertEqual(expectedLocallyCreated, (recordFromDb[kSyncTargetLocallyCreated] as? Bool) ?? (recordFromDb[kSyncTargetLocallyCreated] as? NSNumber)?.boolValue ?? false)
            XCTAssertEqual(expectedLocallyUpdated, (recordFromDb[kSyncTargetLocallyUpdated] as? Bool) ?? (recordFromDb[kSyncTargetLocallyUpdated] as? NSNumber)?.boolValue ?? false)
            XCTAssertEqual(expectedLocallyDeleted, (recordFromDb[kSyncTargetLocallyDeleted] as? Bool) ?? (recordFromDb[kSyncTargetLocallyDeleted] as? NSNumber)?.boolValue ?? false)
            if let recordId = recordFromDb[ID] as? String {
                let isLocalId = SFSyncTarget.isLocalId(recordId)
                XCTAssertEqual(expectedLocallyCreated, isLocalId)
            }
            // Last error field should be empty for a clean record
            if !expectedDirty {
                let lastError = recordFromDb[kSyncTargetLastError] as? String ?? ""
                XCTAssertTrue(lastError.isEmpty, "Last error should be empty")
            }
        }
    }

    func checkDbSyncIdField(_ ids: [String], soupName: String, syncId: NSNumber) {
        let idsClause = buildInClause(ids)
        let smartSql = "SELECT {\(soupName):_soup} FROM {\(soupName)} WHERE {\(soupName):Id} IN \(idsClause)"
        guard let query = QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: UInt(ids.count)) else { return }
        let rows = (try? store.query(using: query, startingFromPageIndex: 0)) ?? []
        XCTAssertEqual(ids.count, rows.count)
        for row in rows {
            guard let rowArray = row as? [Any],
                  let recordFromDb = rowArray[0] as? [String: Any] else { continue }
            XCTAssertEqual(syncId, recordFromDb[kSyncTargetSyncId] as? NSNumber)
        }
    }

    func checkDbLastErrorField(_ ids: [String], soupName: String, lastErrorSubString: String) {
        let idsClause = buildInClause(ids)
        let smartSql = "SELECT {\(soupName):_soup} FROM {\(soupName)} WHERE {\(soupName):Id} IN \(idsClause)"
        guard let query = QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: UInt(ids.count)) else { return }
        let rows = (try? store.query(using: query, startingFromPageIndex: 0)) ?? []
        XCTAssertEqual(ids.count, rows.count)
        for row in rows {
            guard let rowArray = row as? [Any],
                  let recordFromDb = rowArray[0] as? [String: Any] else { continue }
            if let lastErrorInDb = recordFromDb[kSyncTargetLastError] as? String {
                XCTAssertTrue(lastErrorInDb.contains(lastErrorSubString))
            } else {
                XCTFail("Last error field should not be nil")
            }
        }
    }

    // MARK: - Local changes

    func makeSomeLocalChanges(_ idToFields: [String: [String: Any]], soupName: String) -> [String: [String: Any]] {
        let allIds = Array(idToFields.keys).sorted()
        return makeSomeLocalChanges(idToFields, soupName: soupName, idsToUpdate: [allIds[0], allIds[2]])
    }

    func makeSomeLocalChanges(_ idToFields: [String: [String: Any]], soupName: String, idsToUpdate: [String]) -> [String: [String: Any]] {
        let idToFieldsLocallyUpdated = prepareSomeChanges(idToFields, idsToUpdate: idsToUpdate, suffix: "_updated")
        updateRecordsLocally(idToFieldsLocallyUpdated, soupName: soupName)
        return idToFieldsLocallyUpdated
    }

    func prepareSomeChanges(_ idToFields: [String: [String: Any]], idsToUpdate: [String], suffix: String) -> [String: [String: Any]] {
        var idToFieldsUpdated: [String: [String: Any]] = [:]
        for idToUpdate in idsToUpdate {
            if let fields = idToFields[idToUpdate] {
                idToFieldsUpdated[idToUpdate] = updateFields(fields, suffix: suffix)
            }
        }
        return idToFieldsUpdated
    }

    private func updateFields(_ fields: [String: Any], suffix: String) -> [String: Any] {
        let fieldNamesUpdatable = [NAME, DESCRIPTION, LAST_NAME]
        var updatedFields: [String: Any] = [:]
        for fieldName in fields.keys {
            if fieldNamesUpdatable.contains(fieldName), let value = fields[fieldName] as? String {
                updatedFields[fieldName] = "\(value)\(suffix)"
            }
        }
        return updatedFields
    }

    func updateRecordsLocally(_ idToFieldsLocallyUpdated: [String: [String: Any]], soupName: String) {
        for (recordId, updatedFields) in idToFieldsLocallyUpdated {
            guard let soupEntryId = try? store.lookupSoupEntryId(soupNamed: soupName, fieldPath: ID, fieldValue: recordId) else { continue }
            let matchingRecords = store.retrieve(usingSoupEntryIds: [soupEntryId], fromSoupNamed: soupName)
            guard let firstRecord = matchingRecords.first as? [String: Any] else { continue }
            var record = NSMutableDictionary(dictionary: firstRecord)
            for (fieldName, value) in updatedFields {
                record[fieldName] = value
            }
            record[kSyncTargetLocal] = true
            record[kSyncTargetLocallyCreated] = false
            record[kSyncTargetLocallyUpdated] = true
            record[kSyncTargetLocallyDeleted] = false
            _ = _ = store.upsert(entries: [record as! [String: Any]], forSoupNamed: soupName)
        }
    }

    // MARK: - Remote changes

    func makeSomeRemoteChanges(_ idToFields: [String: [String: Any]], objectType: String) -> [String: [String: Any]] {
        let allIds = Array(idToFields.keys).sorted()
        let idsToUpdate = [allIds[0], allIds[2]]
        return makeSomeRemoteChanges(idToFields, objectType: objectType, idsToUpdate: idsToUpdate)
    }

    func makeSomeRemoteChanges(_ idToFields: [String: [String: Any]], objectType: String, idsToUpdate: [String]) -> [String: [String: Any]] {
        let idToFieldsRemotelyUpdated = prepareSomeChanges(idToFields, idsToUpdate: idsToUpdate, suffix: "_remotely_updated")
        updateRecordsOnServer(idToFieldsRemotelyUpdated, objectType: objectType)
        return idToFieldsRemotelyUpdated
    }

    func updateRecordsOnServer(_ idToFieldsUpdated: [String: [String: Any]], objectType: String) {
        // Sleep before doing remote changes
        Thread.sleep(forTimeInterval: 1.0) // time stamp precision is in seconds
        for (recordId, fields) in idToFieldsUpdated {
            let request = RestClient.sharedInstance.requestForUpdate(withObjectType: objectType, objectId: recordId, fields: fields, apiVersion: SFRestDefaultAPIVersion)
            sendSyncRequest(request)
        }
    }

    func checkDbDeleted(_ soupName: String, ids: [String], idField: String) {
        let smartSql = "SELECT {\(soupName):_soup} FROM {\(soupName)} WHERE {\(soupName):\(idField)} IN \(buildInClause(ids))"
        guard let query = QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: UInt(ids.count)) else { return }
        let rowsFromDb = (try? store.query(using: query, startingFromPageIndex: 0)) ?? []
        XCTAssertEqual(0, rowsFromDb.count, "No records should have been returned from smartstore")
    }

    // MARK: - Sync up

    func trySyncUp(_ numberChanges: Int, target: SFSyncUpTarget, mergeMode: SFSyncStateMergeMode) {
        let defaultOptions = SFSyncOptions.newSyncOptions(forSyncUp: [NAME, DESCRIPTION], mergeMode: mergeMode)
        trySyncUp(numberChanges, actualChanges: numberChanges, target: target, options: defaultOptions, completionStatus: .done)
    }

    func trySyncUp(_ numberChanges: Int, actualChanges: Int, target: SFSyncUpTarget, options: SFSyncOptions, completionStatus: SFSyncStateStatus) {
        // Creates sync
        guard let sync = SFSyncState.newSyncUp(withOptions: options, target: target, soupName: ACCOUNTS_SOUP, name: nil, store: store) else {
            XCTFail("Failed to create sync up")
            return
        }
        let syncId = sync.syncId
        checkStatus(sync, expectedType: .up, expectedId: syncId, expectedTarget: target, expectedOptions: options, expectedStatus: .new, expectedProgress: 0, expectedTotalSize: -1)

        // Runs sync
        let queue = SFSyncUpdateCallbackQueue()
        queue.runSync(sync, syncManager: syncManager)

        // Checks status updates
        checkStatus(queue.getNextSyncUpdate(), expectedType: .up, expectedId: syncId, expectedTarget: target, expectedOptions: options, expectedStatus: .running, expectedProgress: 0, expectedTotalSize: -1)
        if actualChanges > 0 {
            checkStatus(queue.getNextSyncUpdate(), expectedType: .up, expectedId: syncId, expectedTarget: target, expectedOptions: options, expectedStatus: .running, expectedProgress: 0, expectedTotalSize: numberChanges)
            for i in 1..<actualChanges {
                checkStatus(queue.getNextSyncUpdate(), expectedType: .up, expectedId: syncId, expectedTarget: target, expectedOptions: options, expectedStatus: .running, expectedProgress: i * 100 / numberChanges, expectedTotalSize: numberChanges)
            }
        }
        if completionStatus == .done {
            checkStatus(queue.getNextSyncUpdate(), expectedType: .up, expectedId: syncId, expectedTarget: target, expectedOptions: options, expectedStatus: completionStatus, expectedProgress: 100, expectedTotalSize: numberChanges)
        } else if completionStatus == .failed {
            let expectedProgress = (actualChanges - 1) * 100 / numberChanges
            checkStatus(queue.getNextSyncUpdate(), expectedType: .up, expectedId: syncId, expectedTarget: target, expectedOptions: options, expectedStatus: completionStatus, expectedProgress: expectedProgress, expectedTotalSize: numberChanges)
        } else {
            XCTFail("completionStatus value '\(completionStatus.rawValue)' not currently supported.")
        }
    }

    // MARK: - Query helpers

    func getIdToFieldsByName(_ soupName: String, fieldNames: [String], nameField: String, names: [String]) -> [String: [String: Any]] {
        let namesClause = buildInClause(names)
        let smartSql = "SELECT {\(soupName):_soup} FROM {\(soupName)} WHERE {\(soupName):\(nameField)} IN \(namesClause)"
        guard let query = QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: UInt(names.count)) else { return [:] }
        let rows = (try? store.query(using: query, startingFromPageIndex: 0)) ?? []
        var idToFields: [String: [String: Any]] = [:]
        for row in rows {
            guard let rowArray = row as? [Any],
                  let soupElt = rowArray[0] as? [String: Any],
                  let recordId = soupElt[ID] as? String else { continue }
            var fields: [String: Any] = [:]
            for fieldName in fieldNames {
                fields[fieldName] = soupElt[fieldName]
            }
            idToFields[recordId] = fields
        }
        return idToFields
    }

    // MARK: - Server checks

    func checkServer(_ idToFields: [String: [String: Any]], objectType: String) {
        let idsClause = buildInClause(Array(idToFields.keys))
        let allValues = Array(idToFields.values)
        guard let firstFields = allValues.first else { return }
        let fieldNames = Array(firstFields.keys)
        let soql = "SELECT \(ID), \(fieldNames.joined(separator: ",")) FROM \(objectType) WHERE Id IN \(idsClause)"
        let request = RestClient.sharedInstance.requestForQuery(soql, apiVersion: SFRestDefaultAPIVersion)
        guard let response = sendSyncRequest(request),
              let records = response[RECORDS] as? [[String: Any]] else { return }
        XCTAssertEqual(idToFields.count, records.count)
        for record in records {
            guard let recordId = record[ID] as? String,
                  let expectedFields = idToFields[recordId] else { continue }
            for fieldName in expectedFields.keys {
                let expectedValue = expectedFields[fieldName]
                let actualValue = record[fieldName]
                if let expectedStr = expectedValue as? String {
                    XCTAssertEqual(expectedStr, actualValue as? String, "Wrong value for field \(fieldName) on record \(recordId)")
                } else if expectedValue is NSNull {
                    XCTAssertTrue(actualValue == nil || actualValue is NSNull, "Wrong value for field \(fieldName) on record \(recordId)")
                } else {
                    XCTAssertEqual(expectedValue as? NSObject, actualValue as? NSObject, "Wrong value for field \(fieldName) on record \(recordId)")
                }
            }
        }
    }

    func updateRecordOnServer(_ fields: [String: Any], idToUpdate: String, objectType: String) -> [String: [String: Any]] {
        var idToFieldsRemotelyUpdated: [String: [String: Any]] = [:]
        let updatedFields = updateFields(fields, suffix: REMOTELY_UPDATED)
        idToFieldsRemotelyUpdated[idToUpdate] = updatedFields
        updateRecordsOnServer(idToFieldsRemotelyUpdated, objectType: objectType)
        return idToFieldsRemotelyUpdated
    }

    func updateRecordLocally(_ fields: [String: Any], idToUpdate: String, soupName: String) -> [String: [String: Any]] {
        return updateRecordLocally(fields, idToUpdate: idToUpdate, soupName: soupName, suffix: LOCALLY_UPDATED)
    }

    func updateRecordLocally(_ fields: [String: Any], idToUpdate: String, soupName: String, suffix: String) -> [String: [String: Any]] {
        var idToFieldsLocallyUpdated: [String: [String: Any]] = [:]
        let updatedFields = updateFields(fields, suffix: suffix)
        idToFieldsLocallyUpdated[idToUpdate] = updatedFields
        updateRecordsLocally(idToFieldsLocallyUpdated, soupName: soupName)
        return idToFieldsLocallyUpdated
    }

    func deleteRecordsLocally(_ ids: [String], soupName: String) {
        var deletedRecords: [[String: Any]] = []
        for idToDelete in ids {
            let query = QuerySpec.buildExactQuerySpec(soupName: soupName, path: ID, matchKey: idToDelete, orderPath: ID, order: .ascending, pageSize: 1)
            guard let results = try? store.query(using: query, startingFromPageIndex: 0),
                  let firstRow = results.first as? [String: Any] else { continue }
            var record = firstRow
            record[kSyncTargetLocal] = true
            record[kSyncTargetLocallyDeleted] = true
            deletedRecords.append(record)
        }
        store.upsert(entries: deletedRecords, forSoupNamed: soupName)
    }

    func checkServerDeleted(_ ids: [String], objectType: String) {
        let soql = "SELECT \(ID) FROM \(objectType) WHERE \(ID) IN \(buildInClause(ids))"
        let request = RestClient.sharedInstance.requestForQuery(soql, apiVersion: SFRestDefaultAPIVersion)
        guard let response = sendSyncRequest(request),
              let records = response["records"] as? [[String: Any]] else { return }
        XCTAssertEqual(records.count, 0, "No accounts should have been returned from server")
    }

    func checkDbRelationships(childrenIds: [String], expectedParentId: String, soupName: String, idFieldName: String, parentIdFieldName: String) {
        let smartSql = "SELECT {\(soupName):_soup} FROM {\(soupName)} WHERE {\(soupName):\(idFieldName)} IN \(buildInClause(childrenIds))"
        guard let smartStoreQuery = QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: UInt(childrenIds.count)) else { return }
        let rows = (try? syncManager.store.query(using: smartStoreQuery, startingFromPageIndex: 0)) ?? []
        XCTAssertEqual(rows.count, childrenIds.count, "All records should have been returned from smartstore")
        for row in rows {
            guard let rowArray = row as? [Any],
                  let childRecord = rowArray[0] as? [String: Any] else { continue }
            XCTAssertEqual(childRecord[parentIdFieldName] as? String, expectedParentId, "Wrong parent id")
        }
    }

    // MARK: - Convenience methods

    func deleteAccountsLocally(_ ids: [String]) {
        deleteRecordsLocally(ids, soupName: ACCOUNTS_SOUP)
    }

    func updateAccountsOnServer(_ idToFieldsUpdated: [String: [String: Any]]) {
        updateRecordsOnServer(idToFieldsUpdated, objectType: ACCOUNT_TYPE)
    }

    func deleteAccounts(onServer ids: [String]) {
        deleteRecords(onServer: ids, objectType: ACCOUNT_TYPE)
    }

    @nonobjc func deleteRecordsOnServer(_ ids: [String], objectType: String) {
        deleteRecords(onServer: ids, objectType: objectType)
    }

    @nonobjc func createAccounts(onServer count: UInt) -> [String: String]? {
        return createRecords(onServer: count, objectType: ACCOUNT_TYPE)
    }

    // MARK: - Helpers used by BriefcaseSyncDownTests

    func cleanRecordsOnServer() throws {
        // Subclasses can override
    }

}
