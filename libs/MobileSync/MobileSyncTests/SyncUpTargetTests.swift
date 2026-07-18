/*
 Copyright (c) 2019-present, salesforce.com, inc. All rights reserved.

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
import SalesforceSDKCommon
import SmartStore
@testable import MobileSync

private let COUNT_TEST_ACCOUNTS: UInt = 10

class SyncUpTargetTests: SyncManagerTestCase {

    var idToFields: [String: [String: Any]] = [:]

    // MARK: - setUp/tearDown

    override func tearDown() {
        deleteTestData()
        super.tearDown()
    }

    // MARK: - Tests

    /// Test that errors are captured on record during sync up
    func testSyncUpWithErrors() {
        createAccountsSoup()
        idToFields = [:]

        // Build name too long
        var nameTooLong = ""
        for _ in 0..<256 { nameTooLong.append("x") }

        let goodNames = [createAccountName(), createAccountName(), createAccountName()]
        let badNames = [nameTooLong, ""]

        _ = createAccountsLocally(goodNames)
        _ = createAccountsLocally(badNames)

        // Sync up
        trySyncUp(5, mergeMode: .overwrite)

        // Check db for records with good names
        let idToFieldsGoodNames = getIdToFieldsByName(ACCOUNTS_SOUP, fieldNames: [NAME, DESCRIPTION], nameField: NAME, names: goodNames)
        checkDbStateFlags(Array(idToFieldsGoodNames.keys), soupName: ACCOUNTS_SOUP, expectedLocallyCreated: false, expectedLocallyUpdated: false, expectedLocallyDeleted: false)

        // Check db for records with bad names
        let idToFieldsBadNames = getIdToFieldsByName(ACCOUNTS_SOUP, fieldNames: [NAME, DESCRIPTION, kSyncTargetLastError], nameField: NAME, names: badNames)
        checkDbStateFlags(Array(idToFieldsBadNames.keys), soupName: ACCOUNTS_SOUP, expectedLocallyCreated: true, expectedLocallyUpdated: false, expectedLocallyDeleted: false)

        for fields in idToFieldsBadNames.values {
            let name = fields[NAME] as? String ?? ""
            let lastError = fields[kSyncTargetLastError] as? String ?? ""
            if name == nameTooLong {
                XCTAssertTrue(lastError.contains("Account Name: data value too large"), "Name too large error expected")
                XCTAssertNotNil(SFJsonUtils.object(fromJSONString: lastError), "Unable to parse error")
            } else if name.isEmpty {
                XCTAssertTrue(lastError.contains("Required fields are missing: [Name]"), "Missing name error expected")
                XCTAssertNotNil(SFJsonUtils.object(fromJSONString: lastError), "Unable to parse error")
            } else {
                XCTFail("Unexpected record found: \(name)")
            }
        }

        // Check server for records with good names
        checkServer(idToFieldsGoodNames)

        // Adding to idToFields so that they get deleted in tearDown
        for (key, value) in idToFieldsGoodNames { idToFields[key] = value }
    }

    /// Sync up records missing sobject type
    func testSyncUpWithNoType() {
        trySyncUpBadTypeOrNoType(noType: true)
    }

    /// Sync up records using bad sobject type
    func testSyncUpWithBadType() {
        trySyncUpBadTypeOrNoType(noType: false)
    }

    /// Sync down the test accounts, modify none, sync up, check smartstore and server afterwards
    func testSyncUpWithNoLocalUpdates() {
        createTestData()
        trySyncDown(.overwrite)
        trySyncUp(0, mergeMode: .overwrite)
        checkDbStateFlags(Array(idToFields.keys), soupName: ACCOUNTS_SOUP, expectedLocallyCreated: false, expectedLocallyUpdated: false, expectedLocallyDeleted: false)
        checkServer(idToFields)
    }

    /// Sync down the test accounts, modify a few, sync up, check smartstore and server afterwards
    func testSyncUpWithLocallyUpdatedRecords() {
        createTestData()
        trySyncDown(.overwrite)
        let idToFieldsLocallyUpdated = makeSomeLocalChanges()
        trySyncUp(idToFieldsLocallyUpdated.count, mergeMode: .overwrite)
        checkDbStateFlags(Array(idToFieldsLocallyUpdated.keys), soupName: ACCOUNTS_SOUP, expectedLocallyCreated: false, expectedLocallyUpdated: false, expectedLocallyDeleted: false)
        checkServer(idToFieldsLocallyUpdated)
    }

    /// Sync down the test accounts, modify a few, sync up specifying update field list
    func testSyncUpWithUpdateFieldList() {
        createTestData()
        trySyncDown(.overwrite)
        let idToFieldsLocallyUpdated = makeSomeLocalChanges()

        let target = buildSyncUpTarget(createFieldlist: nil, updateFieldlist: [NAME])
        trySyncUp(idToFieldsLocallyUpdated.count, target: target, mergeMode: .overwrite)
        checkDbStateFlags(Array(idToFieldsLocallyUpdated.keys), soupName: ACCOUNTS_SOUP, expectedLocallyCreated: false, expectedLocallyUpdated: false, expectedLocallyDeleted: false)

        // Check server - make sure only name was updated
        var idToFieldsExpectedOnServer: [String: [String: Any]] = [:]
        for recordId in idToFieldsLocallyUpdated.keys {
            idToFieldsExpectedOnServer[recordId] = [NAME: idToFieldsLocallyUpdated[recordId]?[NAME] as Any, DESCRIPTION: idToFields[recordId]?[DESCRIPTION] as Any]
        }
        checkServer(idToFieldsExpectedOnServer)
    }

    /// Create accounts locally, sync up specifying create field list
    func testSyncUpWithCreateFieldList() {
        createTestData()
        let names = [createAccountName(), createAccountName(), createAccountName()]
        _ = createAccountsLocally(names)

        let target = buildSyncUpTarget(createFieldlist: [NAME], updateFieldlist: nil)
        trySyncUp(names.count, target: target, mergeMode: .overwrite)

        let idToFieldsCreated = getIdToFieldsByName(ACCOUNTS_SOUP, fieldNames: [NAME, DESCRIPTION], nameField: NAME, names: names)
        checkDbStateFlags(Array(idToFieldsCreated.keys), soupName: ACCOUNTS_SOUP, expectedLocallyCreated: false, expectedLocallyUpdated: false, expectedLocallyDeleted: false)

        // Check server - make sure only name was set
        var idToFieldsExpectedOnServer: [String: [String: Any]] = [:]
        for recordId in idToFieldsCreated.keys {
            idToFieldsExpectedOnServer[recordId] = [NAME: idToFieldsCreated[recordId]?[NAME] as Any, DESCRIPTION: NSNull()]
        }
        checkServer(idToFieldsExpectedOnServer, byNames: names)

        for (key, value) in idToFieldsCreated { idToFields[key] = value }
    }

    /// Sync down the test accounts, modify a few, create accounts locally, sync up specifying different create and update field list
    func testSyncUpWithCreateAndUpdateFieldList() {
        createTestData()
        trySyncDown(.overwrite)

        let idToFieldsLocallyUpdated = makeSomeLocalChanges()
        var namesOfUpdated: [String] = []
        for fields in idToFieldsLocallyUpdated.values {
            if let name = fields[NAME] as? String { namesOfUpdated.append(name) }
        }

        let namesOfCreated = [createAccountName(), createAccountName(), createAccountName()]
        _ = createAccountsLocally(namesOfCreated)

        let target = buildSyncUpTarget(createFieldlist: [NAME], updateFieldlist: [DESCRIPTION])
        trySyncUp(namesOfUpdated.count + namesOfCreated.count, target: target, mergeMode: .overwrite)

        let idToFieldsCreated = getIdToFieldsByName(ACCOUNTS_SOUP, fieldNames: [NAME, DESCRIPTION], nameField: NAME, names: namesOfCreated)
        checkDbStateFlags(Array(idToFieldsCreated.keys), soupName: ACCOUNTS_SOUP, expectedLocallyCreated: false, expectedLocallyUpdated: false, expectedLocallyDeleted: false)
        XCTAssertEqual(namesOfCreated.count, idToFieldsCreated.count)

        var idToFieldsExpectedOnServer: [String: [String: Any]] = [:]
        for recordId in idToFieldsLocallyUpdated.keys {
            idToFieldsExpectedOnServer[recordId] = [NAME: idToFields[recordId]?[NAME] as Any, DESCRIPTION: idToFieldsLocallyUpdated[recordId]?[DESCRIPTION] as Any]
        }
        for recordId in idToFieldsCreated.keys {
            idToFieldsExpectedOnServer[recordId] = [NAME: idToFieldsCreated[recordId]?[NAME] as Any, DESCRIPTION: NSNull()]
        }

        let allNames = namesOfCreated + namesOfUpdated
        XCTAssertEqual(allNames.count, idToFieldsExpectedOnServer.count)
        checkServer(idToFieldsExpectedOnServer)

        for (key, value) in idToFieldsCreated { idToFields[key] = value }
    }

    /// Sync down the test accounts, modify a few, sync up with merge mode LEAVE_IF_CHANGED
    func testSyncUpWithLocallyUpdatedRecordsWithoutOverwrite() {
        createTestData()
        trySyncDown(.leaveIfChanged)

        let idToFieldsLocallyUpdated = makeSomeLocalChanges()
        let ids = Array(idToFieldsLocallyUpdated.keys)

        // Update entries on server
        var idToFieldsRemotelyUpdated: [String: [String: Any]] = [:]
        for accountId in ids {
            let updatedName = "\(idToFields[accountId]?[NAME] as? String ?? "")_updated_again"
            let updatedDescription = "\(idToFields[accountId]?[DESCRIPTION] as? String ?? "")_updated_again"
            idToFieldsRemotelyUpdated[accountId] = [NAME: updatedName, DESCRIPTION: updatedDescription]
        }
        updateAccountsOnServer(idToFieldsRemotelyUpdated)

        trySyncUp(idToFieldsLocallyUpdated.count, mergeMode: .leaveIfChanged)
        checkDbStateFlags(ids, soupName: ACCOUNTS_SOUP, expectedLocallyCreated: false, expectedLocallyUpdated: true, expectedLocallyDeleted: false)
        checkServer(idToFieldsRemotelyUpdated)
    }

    /// Create accounts locally, sync up with merge mode SFSyncStateMergeModeOverwrite
    func testSyncUpWithLocallyCreatedRecords() {
        trySyncUpWithLocallyCreatedRecords(.overwrite)
    }

    /// Create accounts locally, sync up with merge mode SFSyncStateMergeModeLeaveIfChanged
    func testSyncUpWithLocallyCreatedRecordsWithoutOverwrite() {
        trySyncUpWithLocallyCreatedRecords(.leaveIfChanged)
    }

    /// Create accounts locally, delete them locally, sync up
    func testSyncUpWithLocallyCreatedAndDeletedRecords() {
        createTestData()
        let names = [createAccountName(), createAccountName(), createAccountName()]
        _ = createAccountsLocally(names)
        let idToFieldsCreated = getIdToFieldsByName(ACCOUNTS_SOUP, fieldNames: [NAME, DESCRIPTION], nameField: NAME, names: names)

        let allIds = Array(idToFieldsCreated.keys)
        let idsLocallyDeleted = [allIds[0], allIds[1], allIds[2]]
        deleteAccountsLocally(idsLocallyDeleted)

        trySyncUp(3, mergeMode: .leaveIfChanged)

        let idsClause = buildInClause(idsLocallyDeleted)
        let smartSql = "SELECT {accounts:_soup} FROM {accounts} WHERE {accounts:Id} IN \(idsClause)"
        guard let query = QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: UInt(idsLocallyDeleted.count)) else { return }
        let rows = (try? store.query(using: query, startingFromPageIndex: 0)) ?? []
        XCTAssertEqual(0, rows.count)
    }

    /// Sync down the test accounts, delete a few, sync up
    func testSyncUpWithLocallyDeletedRecords() {
        createTestData()
        trySyncDown(.overwrite)

        let allIds = Array(idToFields.keys)
        let idsLocallyDeleted = [allIds[0], allIds[1], allIds[2]]
        deleteAccountsLocally(idsLocallyDeleted)

        trySyncUp(3, mergeMode: .overwrite)

        let idsClause = buildInClause(idsLocallyDeleted)
        let smartSql = "SELECT {accounts:_soup} FROM {accounts} WHERE {accounts:Id} IN \(idsClause)"
        guard let query = QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: UInt(idsLocallyDeleted.count)) else { return }
        let rows = (try? store.query(using: query, startingFromPageIndex: 0)) ?? []
        XCTAssertEqual(0, rows.count)

        // Check server
        let soql = "SELECT Id, Name FROM Account WHERE Id IN \(idsClause)"
        let request = RestClient.sharedInstance.requestForQuery(soql, apiVersion: SFRestDefaultAPIVersion)
        guard let records = sendSyncRequest(request)?[RECORDS] as? [[String: Any]] else { return }
        XCTAssertEqual(0, records.count)
    }

    /// Sync down the test accounts, delete account on server, update same account locally, sync up
    func testSyncUpWithLocallyUpdatedRemotelyDeletedRecords() {
        createTestData()
        trySyncDown(.overwrite)

        let idToFieldsLocallyUpdated = makeSomeLocalChanges()
        var names: [String] = []
        for fields in idToFieldsLocallyUpdated.values {
            if let name = fields[NAME] as? String { names.append(name) }
        }

        let remotelyDeletedId = Array(idToFieldsLocallyUpdated.keys)[0]
        deleteAccounts(onServer: [remotelyDeletedId])

        let locallyUpdatedRemotelyDeletedName = idToFieldsLocallyUpdated[remotelyDeletedId]?[NAME] as? String

        trySyncUp(names.count, mergeMode: .overwrite)

        let namesClause = buildInClause(names)
        let smartSql = "SELECT {accounts:_soup} FROM {accounts} WHERE {accounts:Name} IN \(namesClause)"
        guard let query = QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: UInt(names.count)) else { return }
        let rows = (try? store.query(using: query, startingFromPageIndex: 0)) ?? []
        var idToFieldsUpdated: [String: [String: Any]] = [:]
        for row in rows {
            guard let rowArray = row as? [Any], let account = rowArray[0] as? [String: Any] else { continue }
            let accountId = account[ID] as? String ?? ""
            let accountName = account[NAME] as? String ?? ""
            idToFieldsUpdated[accountId] = [NAME: accountName, DESCRIPTION: account[DESCRIPTION] as Any]
            XCTAssertEqual(false, account[kSyncTargetLocal] as? Bool)
            XCTAssertEqual(false, account[kSyncTargetLocallyCreated] as? Bool)
            XCTAssertEqual(false, account[kSyncTargetLocallyUpdated] as? Bool)
            XCTAssertEqual(false, account[kSyncTargetLocallyDeleted] as? Bool)

            if accountName == locallyUpdatedRemotelyDeletedName {
                XCTAssertNil(idToFields[accountId])
            } else {
                XCTAssertNotNil(idToFields[accountId])
            }
        }

        checkServer(idToFieldsUpdated, byNames: names)
        for (key, value) in idToFieldsUpdated { idToFields[key] = value }
    }

    /// Sync down the test accounts, delete account on server, update same account locally, sync up with merge mode LEAVE_IF_CHANGED, check smartstore and server afterwards
    func testSyncUpWithLocallyUpdatedRemotelyDeletedRecordsWithoutOverwrite() {
        createTestData()
        trySyncDown(.overwrite)

        let idToFieldsLocallyUpdated = makeSomeLocalChanges()
        let ids = Array(idToFieldsLocallyUpdated.keys)

        let remotelyDeletedId = ids[0]
        deleteAccounts(onServer: [remotelyDeletedId])

        trySyncUp(ids.count, mergeMode: .leaveIfChanged)

        let idsClause = buildInClause(ids)
        let smartSql = "SELECT {accounts:_soup} FROM {accounts} WHERE {accounts:Id} IN \(idsClause)"
        guard let query = QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: UInt(ids.count)) else { return }
        let rows = (try? store.query(using: query, startingFromPageIndex: 0)) ?? []
        for row in rows {
            guard let rowArray = row as? [Any], let account = rowArray[0] as? [String: Any] else { continue }
            let accountId = account[ID] as? String ?? ""
            if accountId == remotelyDeletedId {
                XCTAssertEqual(true, account[kSyncTargetLocal] as? Bool)
                XCTAssertEqual(false, account[kSyncTargetLocallyCreated] as? Bool)
                XCTAssertEqual(true, account[kSyncTargetLocallyUpdated] as? Bool)
                XCTAssertEqual(false, account[kSyncTargetLocallyDeleted] as? Bool)
            } else {
                XCTAssertEqual(false, account[kSyncTargetLocal] as? Bool)
                XCTAssertEqual(false, account[kSyncTargetLocallyCreated] as? Bool)
                XCTAssertEqual(false, account[kSyncTargetLocallyUpdated] as? Bool)
                XCTAssertEqual(false, account[kSyncTargetLocallyDeleted] as? Bool)
            }
        }

        let soql = "SELECT Id, Name, Description FROM Account WHERE Id IN \(idsClause)"
        let request = RestClient.sharedInstance.requestForQuery(soql, apiVersion: SFRestDefaultAPIVersion)
        guard let records = sendSyncRequest(request)?[RECORDS] as? [[String: Any]] else { return }
        var idsOnServer: [String] = []
        for record in records {
            let recordId = record[ID] as? String ?? ""
            idsOnServer.append(recordId)
            if let expectedFields = idToFieldsLocallyUpdated[recordId] {
                XCTAssertEqual(expectedFields[NAME] as? String, record[NAME] as? String)
                XCTAssertEqual(expectedFields[DESCRIPTION] as? String, record[DESCRIPTION] as? String)
            }
        }
        XCTAssertFalse(idsOnServer.contains(remotelyDeletedId))
        XCTAssertEqual(ids.count - 1, idsOnServer.count)
    }

    /// Sync down the test accounts, delete account on server, delete same account locally, sync up
    func testSyncUpWithLocallyDeletedRemotelyDeletedRecords() {
        createTestData()
        trySyncDown(.overwrite)

        let locallyAndRemotelyDeletedId = Array(idToFields.keys)[0]
        deleteAccountsLocally([locallyAndRemotelyDeletedId])
        deleteAccounts(onServer: [locallyAndRemotelyDeletedId])

        trySyncUp(1, mergeMode: .overwrite)

        let idsClause = buildInClause([locallyAndRemotelyDeletedId])
        let smartSql = "SELECT {accounts:_soup} FROM {accounts} WHERE {accounts:Id} IN \(idsClause)"
        guard let query = QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: 1) else { return }
        let rows = (try? store.query(using: query, startingFromPageIndex: 0)) ?? []
        XCTAssertEqual(0, rows.count)

        let soql = "SELECT Id, Name FROM Account WHERE Id IN \(idsClause)"
        let request = RestClient.sharedInstance.requestForQuery(soql, apiVersion: SFRestDefaultAPIVersion)
        guard let records = sendSyncRequest(request)?[RECORDS] as? [[String: Any]] else { return }
        XCTAssertEqual(0, records.count)
    }

    /// Sync down the test accounts, delete a few, sync up with merge mode LEAVE_IF_CHANGED
    func testSyncUpWithLocallyDeletedRecordsWithoutOverwrite() {
        createTestData()
        trySyncDown(.leaveIfChanged)

        let allIds = Array(idToFields.keys)
        let idsLocallyDeleted = [allIds[0], allIds[1], allIds[2]]
        deleteAccountsLocally(idsLocallyDeleted)

        var idToFieldsRemotelyUpdated: [String: [String: Any]] = [:]
        for accountId in idsLocallyDeleted {
            let updatedName = "\(idToFields[accountId]?[NAME] as? String ?? "")_updated_again"
            let updatedDescription = "\(idToFields[accountId]?[DESCRIPTION] as? String ?? "")_updated_again"
            idToFieldsRemotelyUpdated[accountId] = [NAME: updatedName, DESCRIPTION: updatedDescription]
        }
        updateAccountsOnServer(idToFieldsRemotelyUpdated)

        trySyncUp(3, mergeMode: .leaveIfChanged)
        checkDbStateFlags(idsLocallyDeleted, soupName: ACCOUNTS_SOUP, expectedLocallyCreated: false, expectedLocallyUpdated: false, expectedLocallyDeleted: true)
        checkServer(idToFieldsRemotelyUpdated)
    }

    /// Sync up many locally created records
    func testSyncUpManyLocallyCreatedRecords() {
        trySyncUpWithLocallyCreatedRecords(.overwrite, countRecords: 500)
    }

    /// Create accounts locally but with external id field populated, sync up with external id field name provided
    func testSyncUpWithExternalId() {
        let externalIdFieldName = "Id"
        createTestData()

        let name1 = createAccountName()
        let name2 = createAccountName()
        let name3 = createAccountName()

        let allIds = Array(idToFields.keys)
        let id1 = allIds[0]
        let id2 = allIds[1]

        let localAccounts = createAccountsLocally([name1, name2, name3]) as? [[String: Any]] ?? []
        var localRecord1 = NSMutableDictionary(dictionary: localAccounts[0])
        var localRecord2 = NSMutableDictionary(dictionary: localAccounts[1])
        var localRecord3 = NSMutableDictionary(dictionary: localAccounts[2])

        localRecord1[externalIdFieldName] = id1
        localRecord2[externalIdFieldName] = id2
        localRecord3[externalIdFieldName] = nil
        _ = store.upsert(entries: [localRecord1 as! [String: Any], localRecord2 as! [String: Any], localRecord3 as! [String: Any]], forSoupNamed: ACCOUNTS_SOUP)

        let options = SFSyncOptions.newSyncOptions(forSyncUp: [NAME])
        trySyncUp(3, options: options, externalIdFieldName: externalIdFieldName)

        let id3 = Array(getIdToFieldsByName(ACCOUNTS_SOUP, fieldNames: [], nameField: NAME, names: [name3]).keys)[0]

        var expectedDbIdFields: [String: [String: Any]] = [:]
        expectedDbIdFields[id1] = [NAME: name1, DESCRIPTION: localRecord1[DESCRIPTION] as Any]
        expectedDbIdFields[id2] = [NAME: name2, DESCRIPTION: localRecord2[DESCRIPTION] as Any]
        expectedDbIdFields[id3] = [NAME: name3, DESCRIPTION: localRecord3[DESCRIPTION] as Any]

        checkDbStateFlags(Array(expectedDbIdFields.keys), soupName: ACCOUNTS_SOUP, expectedLocallyCreated: false, expectedLocallyUpdated: false, expectedLocallyDeleted: false)
        checkDb(expectedDbIdFields, soupName: ACCOUNTS_SOUP)

        var expectedServerIdToFields: [String: [String: Any]] = [:]
        expectedServerIdToFields[id1] = [NAME: name1, DESCRIPTION: idToFields[id1]?[DESCRIPTION] as Any]
        expectedServerIdToFields[id2] = [NAME: name2, DESCRIPTION: idToFields[id2]?[DESCRIPTION] as Any]
        expectedServerIdToFields[id3] = [NAME: name3, DESCRIPTION: NSNull()]

        checkServer(expectedServerIdToFields)
        for (key, value) in expectedServerIdToFields { idToFields[key] = value }
    }

    // MARK: - Helper methods

    private func trySyncUpBadTypeOrNoType(noType: Bool) {
        createAccountsSoup()
        idToFields = [:]

        let namesGoodRecords = [createAccountName(), createAccountName(), createAccountName()]
        let namesBadRecords = [createAccountName(), createAccountName()]

        _ = createAccountsLocally(namesGoodRecords)
        _ = createAccountsLocally(namesBadRecords, mutateBlock: { record in
            if noType {
                record.removeObject(forKey: ATTRIBUTES)
            } else {
                let attributes = NSMutableDictionary()
                attributes[TYPE] = "badType"
                record[ATTRIBUTES] = attributes
            }
            return record
        })

        trySyncUp(5, mergeMode: .overwrite)

        let idToFieldsGoodNames = getIdToFieldsByName(ACCOUNTS_SOUP, fieldNames: [NAME, DESCRIPTION], nameField: NAME, names: namesGoodRecords)
        checkDbStateFlags(Array(idToFieldsGoodNames.keys), soupName: ACCOUNTS_SOUP, expectedLocallyCreated: false, expectedLocallyUpdated: false, expectedLocallyDeleted: false)

        let idToFieldsBadNames = getIdToFieldsByName(ACCOUNTS_SOUP, fieldNames: [NAME, DESCRIPTION, kSyncTargetLastError], nameField: NAME, names: namesBadRecords)
        checkDbStateFlags(Array(idToFieldsBadNames.keys), soupName: ACCOUNTS_SOUP, expectedLocallyCreated: true, expectedLocallyUpdated: false, expectedLocallyDeleted: false)

        XCTAssertEqual(idToFieldsBadNames.count, namesBadRecords.count)
        for fields in idToFieldsBadNames.values {
            let name = fields[NAME] as? String ?? ""
            let lastError = fields[kSyncTargetLastError] as? String ?? ""
            if namesBadRecords.contains(name) {
                let hasExpectedError = lastError.contains("The requested resource does not exist")
                    || lastError.contains("sObject type 'badType' is not supported")
                    || lastError.contains("sObject type 'null' is not supported")
                    || lastError.contains("Nested object for polymorphic foreign key must have an attributes field before any other fields")
                XCTAssertTrue(hasExpectedError, "Wrong error: \(lastError)")
            } else {
                XCTFail("Unexpected record found: \(name)")
            }
        }

        checkServer(idToFieldsGoodNames)
        for (key, value) in idToFieldsGoodNames { idToFields[key] = value }
    }

    private func trySyncUpWithLocallyCreatedRecords(_ syncUpMergeMode: SFSyncStateMergeMode, countRecords: UInt = 3) {
        createTestData()

        var names: [String] = []
        for _ in 0..<countRecords {
            names.append(createAccountName())
        }
        _ = createAccountsLocally(names)

        trySyncUp(Int(countRecords), mergeMode: syncUpMergeMode)

        let idToFieldsCreated = getIdToFieldsByName(ACCOUNTS_SOUP, fieldNames: [NAME, DESCRIPTION], nameField: NAME, names: names)
        checkDbStateFlags(Array(idToFieldsCreated.keys), soupName: ACCOUNTS_SOUP, expectedLocallyCreated: false, expectedLocallyUpdated: false, expectedLocallyDeleted: false)
        checkServer(idToFieldsCreated)
        for (key, value) in idToFieldsCreated { idToFields[key] = value }
    }

    func trySyncUp(_ numberChanges: Int, mergeMode: SFSyncStateMergeMode) {
        let defaultOptions = SFSyncOptions.newSyncOptions(forSyncUp: [NAME, DESCRIPTION], mergeMode: mergeMode)
        trySyncUp(numberChanges, options: defaultOptions)
    }

    func trySyncUp(_ numberChanges: Int, options: SFSyncOptions) {
        trySyncUp(numberChanges, options: options, externalIdFieldName: nil)
    }

    func trySyncUp(_ numberChanges: Int, options: SFSyncOptions, externalIdFieldName: String?) {
        let defaultTarget = buildSyncUpTarget()
        defaultTarget.externalIdFieldName = externalIdFieldName
        trySyncUp(numberChanges, actualChanges: numberChanges, target: defaultTarget, options: options, completionStatus: .done)
    }

    func checkServer(_ idToFieldsToCheck: [String: [String: Any]]) {
        checkServer(idToFieldsToCheck, objectType: ACCOUNT_TYPE)
    }

    func checkServer(_ idToFieldsToCheck: [String: [String: Any]], byNames names: [String]) {
        let namesClause = buildInClause(names)
        let soql = "SELECT Id, Name, Description FROM Account WHERE Name IN \(namesClause)"
        let request = RestClient.sharedInstance.requestForQuery(soql, apiVersion: SFRestDefaultAPIVersion)
        guard let records = sendSyncRequest(request)?[RECORDS] as? [[String: Any]] else { return }
        XCTAssertEqual(names.count, records.count)
        for record in records {
            let accountId = record[ID] as? String ?? ""
            if let expectedFields = idToFieldsToCheck[accountId] {
                for fieldName in expectedFields.keys {
                    let expected = expectedFields[fieldName]
                    let actual = record[fieldName]
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
    }

    func createTestData() {
        createAccountsSoup()
        idToFields = createAccountsOnServer(COUNT_TEST_ACCOUNTS)
    }

    func deleteTestData() {
        deleteAccounts(onServer: Array(idToFields.keys))
        dropAccountsSoup()
        deleteSyncs()
        idToFields = [:]
    }

    func makeSomeLocalChanges() -> [String: [String: Any]] {
        return makeSomeLocalChanges(idToFields, soupName: ACCOUNTS_SOUP)
    }

    func makeSomeRemoteChanges() -> [String: [String: Any]] {
        return makeSomeRemoteChanges(idToFields, objectType: ACCOUNT_TYPE)
    }

    @discardableResult
    func trySyncDown(_ mergeMode: SFSyncStateMergeMode) -> NSInteger {
        let idsClause = buildInClause(Array(idToFields.keys))
        let soql = "SELECT Id, Name, Description, LastModifiedDate FROM Account WHERE Id IN \(idsClause)"
        let target = SFSoqlSyncDownTarget.newSyncTarget(soql)
        return trySyncDown(mergeMode, target: target, soupName: ACCOUNTS_SOUP, totalSize: UInt(idToFields.count), numberFetches: 1)
    }

    // MARK: - THE methods responsible for building sync up targets used in all the tests

    func buildSyncUpTarget() -> SFSyncUpTarget {
        return buildSyncUpTarget(createFieldlist: nil, updateFieldlist: nil)
    }

    func buildSyncUpTarget(createFieldlist: [String]?, updateFieldlist: [String]?) -> SFSyncUpTarget {
        return SFSyncUpTarget(createFieldlist: createFieldlist, updateFieldlist: updateFieldlist)
    }
}
