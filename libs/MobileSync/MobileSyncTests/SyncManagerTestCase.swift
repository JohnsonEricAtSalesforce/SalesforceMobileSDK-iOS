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
import SmartStore
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

class SyncManagerTestCase: XCTestCase {

    var currentUser: UserAccount!
    var syncManager: SFMobileSyncSyncManager!
    var store: SmartStore!
    var globalSyncManager: SFMobileSyncSyncManager!
    var globalStore: SmartStore!

    private static var authException: NSException?

    override class func setUp() {
        super.setUp()
        do {
            SFSDKMobileSyncLogger.setLogLevel(.debug)
            TestSetupUtils.populateAuthCredentialsFromConfigFile(for: self)
            TestSetupUtils.synchronousAuthRefresh()
            SmartStore.removeAllForCurrentUser()
            SmartStore.removeAllGlobal()
        } catch {
            SFSDKMobileSyncLogger.d(self, message: "Populating auth from config failed: \(error)")
        }
    }

    override func setUp() {
        super.setUp()
        if let exception = SyncManagerTestCase.authException {
            XCTFail("Setting up authentication failed: \(exception)")
        }

        // User and managers setup
        currentUser = UserAccountManager.shared.currentUserAccount
        syncManager = SFMobileSyncSyncManager.sharedInstance(forUserAccount: currentUser)
        store = SmartStore.shared(withName: kDefaultSmartStoreName, forUserAccount: currentUser)
        globalStore = SmartStore.sharedGlobal(withName: kDefaultSmartStoreName)
        globalSyncManager = SFMobileSyncSyncManager.sharedInstance(store: globalStore!)
    }

    override func tearDown() {
        // User and managers tear down
        deleteSyncs()
        deleteGlobalSyncs()
        SFMobileSyncSyncManager.removeSharedInstance(currentUser)
        RestClient.shared.cleanup()

        currentUser = nil
        syncManager = nil
        store = nil

        // Some test runs were failing, saying the run didn't complete. This seems to fix that.
        Thread.sleep(forTimeInterval: 0.1)
        super.tearDown()
    }

    // MARK: - Sync Management

    func deleteSyncs() {
        store?.clearSoup(kSFSyncStateSyncsSoupName)
    }

    func deleteGlobalSyncs() {
        globalStore?.clearSoup(kSFSyncStateSyncsSoupName)
    }

    // MARK: - Record Name Generation

    @objc func createRecordName(_ objectType: String) -> String {
        let timestamp = UInt64(Date().timeIntervalSince1970 * 1000)
        let random = arc4random_uniform(1000)
        return "SyncTest_\(objectType)_\(timestamp)\(String(format: "%03d", random))"
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

    // MARK: - Local Record Creation

    @objc func createAccountsLocally(_ names: [String]) -> [Any]? {
        return createAccountsLocally(names, mutateBlock: nil)
    }

    @objc func createAccountsLocally(_ names: [String], mutateBlock: SFRecordMutatorBlock?) -> [Any]? {
        var createdAccounts: [NSDictionary] = []
        let attributes: NSDictionary = [TYPE: ACCOUNT_TYPE]
        for name in names {
            let account = NSMutableDictionary()
            account[ID] = SyncTarget.createLocalId()
            account[NAME] = name
            account[DESCRIPTION] = createDescription(name)
            account[ATTRIBUTES] = attributes
            account[syncTargetLocal] = true
            account[syncTargetLocallyCreated] = true
            account[syncTargetLocallyDeleted] = false
            account[syncTargetLocallyUpdated] = false
            if let mutateBlock = mutateBlock {
                createdAccounts.append(mutateBlock(account))
            } else {
                createdAccounts.append(account)
            }
        }
        return store.upsert(entries: createdAccounts, forSoupNamed: ACCOUNTS_SOUP)
    }

    @objc func createContacts(forAccountsLocally accountIds: [String], numberOfContactsPerAccounts numberOfContacts: Int) -> [Any]? {
        var createdContacts: [NSDictionary] = []
        let attributes: NSDictionary = [TYPE: CONTACT_TYPE]
        for accountId in accountIds {
            for _ in 0..<numberOfContacts {
                let contact = NSMutableDictionary()
                contact[ID] = SyncTarget.createLocalId()
                contact[ACCOUNT_ID] = accountId
                contact[LAST_NAME] = createRecordName(CONTACT_TYPE)
                contact[ATTRIBUTES] = attributes
                contact[syncTargetLocal] = true
                contact[syncTargetLocallyCreated] = true
                contact[syncTargetLocallyDeleted] = false
                contact[syncTargetLocallyUpdated] = false
                createdContacts.append(contact)
            }
        }
        return store.upsert(entries: createdContacts, forSoupNamed: CONTACTS_SOUP)
    }

    // MARK: - Soup Management

    func createAccountsSoup() {
        let indexSpecs = [
            SoupIndex(path: ID, indexType: kSoupIndexTypeString, columnName: nil)!,
            SoupIndex(path: NAME, indexType: kSoupIndexTypeString, columnName: nil)!,
            SoupIndex(path: DESCRIPTION, indexType: kSoupIndexTypeFullText, columnName: nil)!,
            SoupIndex(path: syncTargetLocal, indexType: kSoupIndexTypeString, columnName: nil)!,
            SoupIndex(path: syncTargetSyncId, indexType: kSoupIndexTypeInteger, columnName: nil)!
        ]
        try? store.registerSoup(withName: ACCOUNTS_SOUP, withIndices: indexSpecs)
    }

    func dropAccountsSoup() {
        store?.removeSoup(ACCOUNTS_SOUP)
    }

    func createContactsSoup() {
        let indexSpecs = [
            SoupIndex(path: ID, indexType: kSoupIndexTypeString, columnName: nil)!,
            SoupIndex(path: LAST_NAME, indexType: kSoupIndexTypeString, columnName: nil)!,
            SoupIndex(path: ACCOUNT_ID, indexType: kSoupIndexTypeString, columnName: nil)!,
            SoupIndex(path: syncTargetLocal, indexType: kSoupIndexTypeString, columnName: nil)!,
            SoupIndex(path: syncTargetSyncId, indexType: kSoupIndexTypeInteger, columnName: nil)!
        ]
        try? store.registerSoup(withName: CONTACTS_SOUP, withIndices: indexSpecs)
    }

    func dropContactsSoup() {
        store?.removeSoup(CONTACTS_SOUP)
    }

    // MARK: - Server Operations

    func deleteRecords(onServer ids: [String], objectType: String) {
        let maxIdsPerSlice: Int = 200
        let countIds = ids.count
        let countSlices = Int(ceil(Double(countIds) / Double(maxIdsPerSlice)))

        for slice in 0..<countSlices {
            let sliceStartIndex = slice * maxIdsPerSlice
            let sliceEndIndex = min(countIds, (slice + 1) * maxIdsPerSlice)
            let idsToDelete = Array(ids[sliceStartIndex..<sliceEndIndex])
            let request = RestClient.shared.requestForCollectionDelete(true, objectIds: idsToDelete, apiVersion: nil)
            let _ = sendSyncRequest(request)
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
        let completeBlock: RestResponseBlock = { response, rawResponse in
            listener.dataResponse = response
            listener.returnStatus = kTestRequestStatusDidLoad
        }
        RestClient.shared.send(request, failureBlock: failBlock, successBlock: completeBlock)
        listener.waitForCompletion()
        if let lastError = listener.lastError,
           (lastError.code != 404 || !ignoreNotFound) {
            XCTFail("Rest call \(request) failed with error \(lastError)")
        }
        return listener.dataResponse as? [String: Any]
    }

    // MARK: - Record Creation on Server

    func buildFieldsMapForRecords(_ count: UInt, objectType: String, additionalFields: [String: Any]?) -> [[String: Any]] {
        var listFields: [[String: Any]] = []
        for _ in 0..<count {
            let name = createRecordName(objectType)
            var fields: [String: Any] = [:]

            if let additionalFields = additionalFields {
                fields.merge(additionalFields) { _, new in new }
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

    @objc func createAccounts(onServer count: UInt) -> [String: Any]? {
        return createRecordsOnServerReturnFields(count, objectType: ACCOUNT_TYPE, additionalFields: nil)
    }

    @objc func createRecords(onServer count: UInt, objectType: String) -> [String: String]? {
        guard let idToFields = createRecordsOnServerReturnFields(count, objectType: objectType, additionalFields: nil) else {
            return nil
        }
        var idToNames: [String: String] = [:]
        for recordId in idToFields.keys {
            let fields = idToFields[recordId] as? [String: Any]
            let nameField = (objectType == CONTACT_TYPE) ? LAST_NAME : NAME
            if let name = fields?[nameField] as? String {
                idToNames[recordId] = name
            }
        }
        return idToNames
    }

    func createRecordsOnServerReturnFields(_ count: UInt, objectType: String, additionalFields: [String: Any]?) -> [String: Any]? {
        let listFields = buildFieldsMapForRecords(count, objectType: objectType, additionalFields: additionalFields)
        var requests: [RestRequest] = []
        for i in 0..<Int(count) {
            requests.append(RestClient.shared.requestForCreate(withObjectType: objectType, fields: listFields[i], apiVersion: nil))
        }

        var idToFields: [String: Any] = [:]
        guard let batchResponse = sendSyncRequest(RestClient.shared.batchRequest(requests, haltOnError: false, apiVersion: nil)),
              let results = batchResponse["results"] as? [[String: Any]] else {
            return nil
        }

        for i in 0..<results.count {
            let result = results[i]
            XCTAssertEqual(201, result["statusCode"] as? Int, "Status code should be HTTP_CREATED")
            if let resultBody = result["result"] as? [String: Any],
               let recordId = resultBody["id"] as? String {
                idToFields[recordId] = listFields[i]
            }
        }
        return idToFields
    }

    // MARK: - Sync Down

    @discardableResult
    func trySyncDown(_ mergeMode: SyncMergeMode, target: SyncDownTarget, soupName: String, totalSize: UInt, numberFetches: UInt) -> Int {
        // Creates sync
        let options = SFSyncOptions.newSyncOptions(forSyncDown: mergeMode)
        guard let sync = SyncState.buildSyncDown(options: options, target: target, soupName: soupName, name: nil, store: store) else {
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
        if totalSize != UInt(TOTAL_SIZE_UNKNOWN) {
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

    // MARK: - Status Checking

    func checkStatus(_ sync: SyncState?, expectedType: SyncType, expectedId: Int, expectedTarget: SyncTarget?, expectedOptions: SFSyncOptions?, expectedStatus: SyncStatus, expectedProgress: Int, expectedTotalSize: Int) {
        checkStatus(sync, expectedType: expectedType, expectedId: expectedId, expectedName: nil, expectedTarget: expectedTarget, expectedOptions: expectedOptions, expectedStatus: expectedStatus, expectedProgress: expectedProgress, expectedTotalSize: expectedTotalSize)
    }

    func checkStatus(_ sync: SyncState?, expectedType: SyncType, expectedId: Int, expectedTarget: SyncTarget?, expectedOptions: SFSyncOptions?, expectedStatus: SyncStatus, expectedProgress: Int) {
        checkStatus(sync, expectedType: expectedType, expectedId: expectedId, expectedName: nil, expectedTarget: expectedTarget, expectedOptions: expectedOptions, expectedStatus: expectedStatus, expectedProgress: expectedProgress, expectedTotalSize: TOTAL_SIZE_UNKNOWN)
    }

    func checkStatus(_ sync: SyncState?, expectedType: SyncType, expectedId: Int, expectedName: String?, expectedTarget: SyncTarget?, expectedOptions: SFSyncOptions?, expectedStatus: SyncStatus, expectedProgress: Int, expectedTotalSize: Int) {
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
                XCTAssertTrue(sync.target is SyncDownTarget)
                let expectedQueryType = (expectedTarget as! SyncDownTarget).queryType
                XCTAssertEqual(expectedQueryType, (sync.target as! SyncDownTarget).queryType)

                switch expectedQueryType {
                case .soql:
                    XCTAssertTrue(sync.target is SoqlSyncDownTarget)
                    XCTAssertEqual((expectedTarget as! SoqlSyncDownTarget).query, (sync.target as! SoqlSyncDownTarget).query)
                case .sosl:
                    XCTAssertTrue(sync.target is SoslSyncDownTarget)
                    XCTAssertEqual((expectedTarget as! SoslSyncDownTarget).query, (sync.target as! SoslSyncDownTarget).query)
                case .mru:
                    XCTAssertTrue(sync.target is MruSyncDownTarget)
                    XCTAssertEqual((expectedTarget as! MruSyncDownTarget).objectType, (sync.target as! MruSyncDownTarget).objectType)
                    XCTAssertEqual((expectedTarget as! MruSyncDownTarget).fieldlist as? [String], (sync.target as! MruSyncDownTarget).fieldlist as? [String])
                case .refresh:
                    XCTAssertTrue(sync.target is RefreshSyncDownTarget)
                    XCTAssertEqual((expectedTarget as! RefreshSyncDownTarget).objectType, (sync.target as! RefreshSyncDownTarget).objectType)
                    XCTAssertEqual((expectedTarget as! RefreshSyncDownTarget).soupName, (sync.target as! RefreshSyncDownTarget).soupName)
                    XCTAssertEqual((expectedTarget as! RefreshSyncDownTarget).fieldlist, (sync.target as! RefreshSyncDownTarget).fieldlist)
                case .metadata:
                    XCTAssertTrue(sync.target is MetadataSyncDownTarget)
                    XCTAssertEqual((expectedTarget as! MetadataSyncDownTarget).objectType, (sync.target as! MetadataSyncDownTarget).objectType)
                case .layout:
                    XCTAssertTrue(sync.target is LayoutSyncDownTarget)
                    XCTAssertEqual((expectedTarget as! LayoutSyncDownTarget).objectAPIName, (sync.target as! LayoutSyncDownTarget).objectAPIName)
                    XCTAssertEqual((expectedTarget as! LayoutSyncDownTarget).layoutType, (sync.target as! LayoutSyncDownTarget).layoutType)
                case .parentChildren:
                    XCTAssertTrue(sync.target is ParentChildrenSyncDownTarget)
                    let expectedTyped = expectedTarget as! ParentChildrenSyncDownTarget
                    let actualTyped = sync.target as! ParentChildrenSyncDownTarget
                    checkParentInfo(actualTyped.parentInfo, expectedParentInfo: expectedTyped.parentInfo)
                    checkChildrenInfo(actualTyped.childrenInfo, expectedChildrenInfo: expectedTyped.childrenInfo)
                    XCTAssertEqual(expectedTyped.relationshipType, actualTyped.relationshipType)
                    XCTAssertEqual(expectedTyped.parentFieldlist, actualTyped.parentFieldlist)
                    XCTAssertEqual(expectedTyped.childrenFieldlist, actualTyped.childrenFieldlist)
                    XCTAssertEqual(expectedTyped.parentSoqlFilter, actualTyped.parentSoqlFilter)
                case .briefcase:
                    XCTAssertTrue(sync.target is BriefcaseSyncDownTarget)
                    let expectedTyped = expectedTarget as! BriefcaseSyncDownTarget
                    let actualTyped = sync.target as! BriefcaseSyncDownTarget
                    checkBriefcaseInfo(actualTyped.infosMap, expectedBriefcaseInfo: expectedTyped.infosMap)
                case .custom:
                    XCTAssertTrue(sync.target is SyncDownTarget)
                @unknown default:
                    break
                }
            } else {
                if sync.target is BatchSyncUpTarget {
                    XCTAssertTrue(sync.target is BatchSyncUpTarget)
                } else if sync.target is ParentChildrenSyncUpTarget {
                    XCTAssertTrue(sync.target is ParentChildrenSyncUpTarget)
                    let expectedTyped = expectedTarget as! ParentChildrenSyncUpTarget
                    let actualTyped = sync.target as! ParentChildrenSyncUpTarget
                    checkParentInfo(actualTyped.parentInfo, expectedParentInfo: expectedTyped.parentInfo)
                    checkChildrenInfo(actualTyped.childrenInfo, expectedChildrenInfo: expectedTyped.childrenInfo)
                    XCTAssertEqual(expectedTyped.relationshipType, actualTyped.relationshipType)
                    XCTAssertEqual(expectedTyped.createFieldlist, actualTyped.createFieldlist)
                    XCTAssertEqual(expectedTyped.updateFieldlist, actualTyped.updateFieldlist)
                    XCTAssertEqual(expectedTyped.childrenCreateFieldlist, actualTyped.childrenCreateFieldlist)
                    XCTAssertEqual(expectedTyped.childrenUpdateFieldlist, actualTyped.childrenUpdateFieldlist)
                }

                // Following applies to all sync up targets
                XCTAssertTrue(sync.target is SyncUpTarget)
                XCTAssertEqual((expectedTarget as! SyncUpTarget).createFieldlist, (sync.target as! SyncUpTarget).createFieldlist)
                XCTAssertEqual((expectedTarget as! SyncUpTarget).updateFieldlist, (sync.target as! SyncUpTarget).updateFieldlist)
                XCTAssertEqual((expectedTarget as! SyncUpTarget).externalIdFieldName, (sync.target as! SyncUpTarget).externalIdFieldName)
            }
        } else {
            XCTAssertNil(sync.target)
        }

        if let expectedOptions = expectedOptions {
            XCTAssertNotNil(sync.options)
            XCTAssertEqual(expectedOptions.mergeMode, sync.options?.mergeMode)
            XCTAssertEqual(expectedOptions.fieldlist, sync.options?.fieldlist)
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

    func checkParentInfo(_ parentInfo: SFParentInfo, expectedParentInfo: SFParentInfo) {
        XCTAssertEqual(expectedParentInfo.idFieldName, parentInfo.idFieldName)
        XCTAssertEqual(expectedParentInfo.modificationDateFieldName, parentInfo.modificationDateFieldName)
        XCTAssertEqual(expectedParentInfo.sobjectType, parentInfo.sobjectType)
        XCTAssertEqual(expectedParentInfo.soupName, parentInfo.soupName)
    }

    func checkChildrenInfo(_ childrenInfo: SFChildrenInfo, expectedChildrenInfo: SFChildrenInfo) {
        checkParentInfo(childrenInfo, expectedParentInfo: expectedChildrenInfo)
        XCTAssertEqual(expectedChildrenInfo.parentIdFieldName, childrenInfo.parentIdFieldName)
        XCTAssertEqual(expectedChildrenInfo.sobjectTypePlural, childrenInfo.sobjectTypePlural)
    }

    func checkBriefcaseInfo(_ briefcaseInfo: [String: BriefcaseObjectInfo], expectedBriefcaseInfo: [String: BriefcaseObjectInfo]) {
        XCTAssertTrue(briefcaseInfo.count > 0)
        XCTAssertEqual(briefcaseInfo.count, expectedBriefcaseInfo.count)

        for name in briefcaseInfo.keys {
            let info = briefcaseInfo[name]!
            let expectedInfo = expectedBriefcaseInfo[name]!
            XCTAssertEqual(expectedInfo.soupName, info.soupName)
            XCTAssertEqual(expectedInfo.sobjectType, info.sobjectType)
            XCTAssertEqual(expectedInfo.idFieldName, info.idFieldName)
            XCTAssertEqual(expectedInfo.modificationDateFieldName, info.modificationDateFieldName)
            XCTAssertEqual(expectedInfo.fieldlist, info.fieldlist)
        }
    }

    // MARK: - Database Checks

    func checkDbExists(_ soupName: String, ids: [String], idField: String) {
        let smartSql = "SELECT {\(soupName):_soup} FROM {\(soupName)} WHERE {\(soupName):\(idField)} IN \(buildInClause(ids))"
        guard let query = QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: UInt(ids.count)) else { return }
        let rowsFromDb = (try? store.query(using: query, startingFromPageIndex: 0)) ?? []
        XCTAssertEqual(ids.count, rowsFromDb.count, "All records should have been returned from smartstore")
    }

    func checkDb(_ expectedIdToFields: [String: Any], soupName: String) {
        let idsClause = buildInClause(Array(expectedIdToFields.keys))
        let smartSql = "SELECT {\(soupName):_soup} FROM {\(soupName)} WHERE {\(soupName):Id} IN \(idsClause)"
        guard let query = QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: UInt(expectedIdToFields.count)) else { return }
        let rows = (try? store.query(using: query, startingFromPageIndex: 0)) ?? []
        XCTAssertEqual(expectedIdToFields.count, rows.count)
        for row in rows {
            guard let rowArray = row as? [Any],
                  let recordFromDb = rowArray[0] as? [String: Any],
                  let recordId = recordFromDb[ID] as? String,
                  let expectedFields = expectedIdToFields[recordId] as? [String: Any] else { continue }
            for fieldName in expectedFields.keys {
                XCTAssertEqual(expectedFields[fieldName] as? String, recordFromDb[fieldName] as? String)
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
            XCTAssertEqual(expectedDirty, (recordFromDb[syncTargetLocal] as? Bool) ?? false)
            XCTAssertEqual(expectedLocallyCreated, (recordFromDb[syncTargetLocallyCreated] as? Bool) ?? false)
            XCTAssertEqual(expectedLocallyUpdated, (recordFromDb[syncTargetLocallyUpdated] as? Bool) ?? false)
            XCTAssertEqual(expectedLocallyDeleted, (recordFromDb[syncTargetLocallyDeleted] as? Bool) ?? false)
            if let recordId = recordFromDb[ID] as? String {
                let isLocalId = SyncTarget.isLocalId(recordId)
                XCTAssertEqual(expectedLocallyCreated, isLocalId)
            }

            // Last error field should be empty for a clean record
            if !expectedDirty {
                let lastError = recordFromDb[syncTargetLastError] as? String ?? ""
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
            XCTAssertEqual(syncId, recordFromDb[syncTargetSyncId] as? NSNumber)
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
            let lastErrorInDb = recordFromDb[syncTargetLastError] as? String ?? ""
            XCTAssertTrue(lastErrorInDb.contains(lastErrorSubString))
        }
    }

    func checkDbDeleted(_ soupName: String, ids: [String], idField: String) {
        let smartSql = "SELECT {\(soupName):_soup} FROM {\(soupName)} WHERE {\(soupName):\(idField)} IN \(buildInClause(ids))"
        guard let query = QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: UInt(ids.count)) else { return }
        let rowsFromDb = (try? store.query(using: query, startingFromPageIndex: 0)) ?? []
        XCTAssertEqual(0, rowsFromDb.count, "No records should have been returned from smartstore")
    }

    // MARK: - Local Changes

    func makeSomeLocalChanges(_ idToFields: [String: Any], soupName: String) -> [String: Any] {
        let allIds = Array(idToFields.keys).sorted()
        return makeSomeLocalChanges(idToFields, soupName: soupName, idsToUpdate: [allIds[0], allIds[2]])
    }

    func makeSomeLocalChanges(_ idToFields: [String: Any], soupName: String, idsToUpdate: [String]) -> [String: Any] {
        let idToFieldsLocallyUpdated = prepareSomeChanges(idToFields, idsToUpdate: idsToUpdate, suffix: "_updated")
        updateRecordsLocally(idToFieldsLocallyUpdated, soupName: soupName)
        return idToFieldsLocallyUpdated
    }

    func prepareSomeChanges(_ idToFields: [String: Any], idsToUpdate: [String], suffix: String) -> [String: Any] {
        var idToFieldsUpdated: [String: Any] = [:]
        for idToUpdate in idsToUpdate {
            if let fields = idToFields[idToUpdate] as? [String: Any] {
                idToFieldsUpdated[idToUpdate] = updateFields(fields, suffix: suffix)
            }
        }
        return idToFieldsUpdated
    }

    func updateFields(_ fields: [String: Any], suffix: String) -> [String: Any] {
        let fieldNamesUpdatable = [NAME, DESCRIPTION, LAST_NAME]
        var updatedFields: [String: Any] = [:]
        for fieldName in fields.keys {
            if fieldNamesUpdatable.contains(fieldName) {
                if let value = fields[fieldName] as? String {
                    updatedFields[fieldName] = value + suffix
                }
            }
        }
        return updatedFields
    }

    func updateRecordsLocally(_ idToFieldsLocallyUpdated: [String: Any], soupName: String) {
        for recordId in idToFieldsLocallyUpdated.keys {
            guard let updatedFields = idToFieldsLocallyUpdated[recordId] as? [String: Any] else { continue }
            guard let soupEntryId = try? store.lookupSoupEntryId(soupNamed: soupName, fieldPath: ID, fieldValue: recordId) else { continue }
            let matchingRecords = store.retrieve(usingSoupEntryIds: [soupEntryId], fromSoupNamed: soupName)
            guard let record = matchingRecords.first as? [String: Any] else { continue }
            var mutableRecord = record
            for fieldName in updatedFields.keys {
                mutableRecord[fieldName] = updatedFields[fieldName]
            }
            mutableRecord[syncTargetLocal] = true
            mutableRecord[syncTargetLocallyCreated] = false
            mutableRecord[syncTargetLocallyUpdated] = true
            mutableRecord[syncTargetLocallyDeleted] = false
            store.upsert(entries: [mutableRecord as NSDictionary], forSoupNamed: soupName)
        }
    }

    // MARK: - Remote Changes

    func makeSomeRemoteChanges(_ idToFields: [String: Any], objectType: String) -> [String: Any] {
        let allIds = Array(idToFields.keys).sorted()
        let idsToUpdate = [allIds[0], allIds[2]]
        return makeSomeRemoteChanges(idToFields, objectType: objectType, idsToUpdate: idsToUpdate)
    }

    func makeSomeRemoteChanges(_ idToFields: [String: Any], objectType: String, idsToUpdate: [String]) -> [String: Any] {
        let idToFieldsRemotelyUpdated = prepareSomeChanges(idToFields, idsToUpdate: idsToUpdate, suffix: "_remotely_updated")
        updateRecordsOnServer(idToFieldsRemotelyUpdated, objectType: objectType)
        return idToFieldsRemotelyUpdated
    }

    func updateRecordsOnServer(_ idToFieldsUpdated: [String: Any], objectType: String) {
        // Sleep before doing remote changes
        Thread.sleep(forTimeInterval: 1.0) // time stamp precision is in seconds
        for accountId in idToFieldsUpdated.keys {
            guard let fields = idToFieldsUpdated[accountId] as? [String: Any] else { continue }
            let request = RestClient.shared.requestForUpdate(withObjectType: objectType, objectId: accountId, fields: fields, apiVersion: nil)
            sendSyncRequest(request)
        }
    }

    // MARK: - Sync Up

    func trySyncUp(_ numberChanges: Int, target: SyncUpTarget, mergeMode: SyncMergeMode) {
        let defaultOptions = SFSyncOptions.newSyncOptions(forSyncUp: [NAME, DESCRIPTION], mergeMode: mergeMode)
        trySyncUp(numberChanges, actualChanges: numberChanges, target: target, options: defaultOptions, completionStatus: .done)
    }

    func trySyncUp(_ numberChanges: Int, actualChanges actualNumberChanges: Int, target: SyncUpTarget, options: SFSyncOptions, completionStatus: SyncStatus) {
        // Creates sync
        guard let sync = SyncState.buildSyncUp(options: options, target: target, soupName: ACCOUNTS_SOUP, name: nil, store: store) else {
            XCTFail("Failed to create sync up")
            return
        }
        let syncId = sync.syncId
        checkStatus(sync, expectedType: .up, expectedId: syncId, expectedTarget: target, expectedOptions: options, expectedStatus: .new, expectedProgress: 0, expectedTotalSize: -1)

        // Runs sync
        let queue = SFSyncUpdateCallbackQueue()
        let syncUpStart = Date()
        queue.runSync(sync, syncManager: syncManager)

        // Checks status updates
        checkStatus(queue.getNextSyncUpdate(), expectedType: .up, expectedId: syncId, expectedTarget: target, expectedOptions: options, expectedStatus: .running, expectedProgress: 0, expectedTotalSize: -1)
        if actualNumberChanges > 0 {
            checkStatus(queue.getNextSyncUpdate(), expectedType: .up, expectedId: syncId, expectedTarget: target, expectedOptions: options, expectedStatus: .running, expectedProgress: 0, expectedTotalSize: numberChanges)
            for i in 1..<actualNumberChanges {
                checkStatus(queue.getNextSyncUpdate(), expectedType: .up, expectedId: syncId, expectedTarget: target, expectedOptions: options, expectedStatus: .running, expectedProgress: i * 100 / numberChanges, expectedTotalSize: numberChanges)
            }
        }
        if completionStatus == .done {
            checkStatus(queue.getNextSyncUpdate(), expectedType: .up, expectedId: syncId, expectedTarget: target, expectedOptions: options, expectedStatus: completionStatus, expectedProgress: 100, expectedTotalSize: numberChanges)
        } else if completionStatus == .failed {
            let expectedProgress = (actualNumberChanges - 1) * 100 / numberChanges
            checkStatus(queue.getNextSyncUpdate(), expectedType: .up, expectedId: syncId, expectedTarget: target, expectedOptions: options, expectedStatus: completionStatus, expectedProgress: expectedProgress, expectedTotalSize: numberChanges)
        } else {
            XCTFail("completionStatus value '\(completionStatus.rawValue)' not currently supported.")
        }
        let syncUpEnd = Date()
        let executionTime = syncUpEnd.timeIntervalSince(syncUpStart)
        NSLog("Sync up executionTime = %f s", executionTime)
    }

    // MARK: - Query Helpers

    func getIdToFieldsByName(_ soupName: String, fieldNames: [String], nameField: String, names: [String]) -> [String: Any] {
        let namesClause = buildInClause(names)
        let smartSql = "SELECT {\(soupName):_soup} FROM {\(soupName)} WHERE {\(soupName):\(nameField)} IN \(namesClause)"
        guard let query = QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: UInt(names.count)) else { return [:] }
        let rows = (try? store.query(using: query, startingFromPageIndex: 0)) ?? []
        var idToFields: [String: Any] = [:]
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

    // MARK: - Server Checks

    func checkServer(_ idToFields: [String: Any], objectType: String) {
        let idsClause = buildInClause(Array(idToFields.keys))
        guard let firstFields = idToFields[idToFields.keys.first!] as? [String: Any] else { return }
        let fieldNames = Array(firstFields.keys)
        let soql = "SELECT \(ID), \(fieldNames.joined(separator: ",")) FROM \(objectType) WHERE Id IN \(idsClause)"
        let request = RestClient.shared.requestForQuery(soql, apiVersion: nil)
        guard let response = sendSyncRequest(request),
              let records = response[RECORDS] as? [[String: Any]] else { return }
        XCTAssertEqual(idToFields.count, records.count)
        for record in records {
            guard let recordId = record[ID] as? String,
                  let expectedFields = idToFields[recordId] as? [String: Any] else { continue }
            for fieldName in expectedFields.keys {
                XCTAssertEqual(expectedFields[fieldName] as? String, record[fieldName] as? String, "Wrong value for field \(fieldName) on record \(recordId)")
            }
        }
    }

    func updateRecordOnServer(_ fields: [String: Any], idToUpdate: String, objectType: String) -> [String: Any] {
        var idToFieldsRemotelyUpdated: [String: Any] = [:]
        let updatedFields = updateFields(fields, suffix: REMOTELY_UPDATED)
        idToFieldsRemotelyUpdated[idToUpdate] = updatedFields
        updateRecordsOnServer(idToFieldsRemotelyUpdated, objectType: objectType)
        return idToFieldsRemotelyUpdated
    }

    func updateRecordLocally(_ fields: [String: Any], idToUpdate: String, soupName: String) -> [String: Any] {
        return updateRecordLocally(fields, idToUpdate: idToUpdate, soupName: soupName, suffix: LOCALLY_UPDATED)
    }

    func updateRecordLocally(_ fields: [String: Any], idToUpdate: String, soupName: String, suffix: String) -> [String: Any] {
        var idToFieldsLocallyUpdated: [String: Any] = [:]
        let updatedFields = updateFields(fields, suffix: suffix)
        idToFieldsLocallyUpdated[idToUpdate] = updatedFields
        updateRecordsLocally(idToFieldsLocallyUpdated, soupName: soupName)
        return idToFieldsLocallyUpdated
    }

    func deleteRecordsLocally(_ ids: [String], soupName: String) {
        var deletedRecords: [NSDictionary] = []
        for idToDelete in ids {
            let query = QuerySpec.buildExactQuerySpec(soupName: soupName, path: ID, matchKey: idToDelete, orderPath: ID, order: .ascending, pageSize: 1)
            guard let results = try? store.query(using: query, startingFromPageIndex: 0) as? [[Any]],
                  let record = results.first?.first as? [String: Any] else { continue }
            var mutableRecord = record
            mutableRecord[syncTargetLocal] = true
            mutableRecord[syncTargetLocallyDeleted] = true
            deletedRecords.append(mutableRecord as NSDictionary)
        }
        store.upsert(entries: deletedRecords, forSoupNamed: soupName)
    }

    func checkServerDeleted(_ ids: [String], objectType: String) {
        let soql = "SELECT \(ID) FROM \(objectType) WHERE \(ID) IN \(buildInClause(ids))"
        let request = RestClient.shared.requestForQuery(soql, apiVersion: nil)
        guard let response = sendSyncRequest(request),
              let records = response["records"] as? [Any] else { return }
        XCTAssertEqual(0, records.count, "No accounts should have been returned from server")
    }

    func checkDbRelationships(withChildrenIds childrenIds: [String], expectedParentId: String, soupName: String, idFieldName: String, parentIdFieldName: String) {
        let smartSql = "SELECT {\(soupName):_soup} FROM {\(soupName)} WHERE {\(soupName):\(idFieldName)} IN \(buildInClause(childrenIds))"
        guard let query = QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: UInt(childrenIds.count)) else { return }
        let rows = (try? syncManager.store.query(using: query, startingFromPageIndex: 0)) ?? []
        XCTAssertEqual(rows.count, childrenIds.count, "All records should have been returned from smartstore")
        for row in rows {
            guard let rowArray = row as? [Any],
                  let childRecord = rowArray[0] as? [String: Any] else { continue }
            XCTAssertEqual(childRecord[parentIdFieldName] as? String, expectedParentId, "Wrong parent id")
        }
    }

    // MARK: - Convenience Account Methods

    func deleteAccountsLocally(_ ids: [String]) {
        deleteRecordsLocally(ids, soupName: ACCOUNTS_SOUP)
    }

    func updateAccounts(onServer idToFieldsUpdated: [String: Any]) {
        updateRecordsOnServer(idToFieldsUpdated, objectType: ACCOUNT_TYPE)
    }

    func deleteAccounts(onServer ids: [String]) {
        deleteRecords(onServer: ids, objectType: ACCOUNT_TYPE)
    }
}
