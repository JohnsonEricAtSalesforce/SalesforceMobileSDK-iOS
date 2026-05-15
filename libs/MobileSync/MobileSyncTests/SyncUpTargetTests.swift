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
import SmartStore
import SalesforceSDKCore
import SalesforceSDKCommon
@testable import MobileSync

let COUNT_TEST_ACCOUNTS: UInt = 10

class SyncUpTargetTests: SyncManagerTestCase {

    var idToFields: NSMutableDictionary!

    override func tearDown() {
        deleteTestData()
        super.tearDown()
    }

    // MARK: - Tests

    /// Test that errors are captured on record during sync up
    func testSyncUpWithErrors() {
        // Setup soup
        createAccountsSoup()
        idToFields = NSMutableDictionary()

        // Build name too long
        var nameTooLong = ""
        for _ in 0..<256 { nameTooLong += "x" }

        // Create a few entries locally
        let goodNames = [createAccountName(), createAccountName(), createAccountName()]
        let badNames = [nameTooLong, ""]

        createAccountsLocally(goodNames)
        createAccountsLocally(badNames)

        // Sync up
        trySyncUp(5, mergeMode: .overwrite)

        // Check db for records with good names
        let idToFieldsGoodNames = getIdToFieldsByName(ACCOUNTS_SOUP, fieldNames: [NAME, DESCRIPTION], nameField: NAME, names: goodNames)
        checkDbStateFlags(Array(idToFieldsGoodNames.keys), soupName: ACCOUNTS_SOUP, expectedLocallyCreated: false, expectedLocallyUpdated: false, expectedLocallyDeleted: false)

        // Check db for records with bad names
        let idToFieldsBadNames = getIdToFieldsByName(ACCOUNTS_SOUP, fieldNames: [NAME, DESCRIPTION, syncTargetLastError], nameField: NAME, names: badNames)
        checkDbStateFlags(Array(idToFieldsBadNames.keys), soupName: ACCOUNTS_SOUP, expectedLocallyCreated: true, expectedLocallyUpdated: false, expectedLocallyDeleted: false)

        for fields in idToFieldsBadNames.values {
            guard let fieldsDict = fields as? [String: Any] else { continue }
            let name = fieldsDict[NAME] as? String ?? ""
            let lastError = fieldsDict[syncTargetLastError] as? String ?? ""
            if name == nameTooLong {
                XCTAssertTrue(lastError.contains("Account Name: data value too large"), "Name too large error expected")
                XCTAssertNotNil(SFJsonUtils.object(from: lastError), "Unable to parse error")
            } else if name == "" {
                XCTAssertTrue(lastError.contains("Required fields are missing: [Name]"), "Missing name error expected")
                XCTAssertNotNil(SFJsonUtils.object(from: lastError), "Unable to parse error")
            } else {
                XCTFail("Unexpected record found: \(name)")
            }
        }

        // Check server for records with good names
        checkServer(idToFieldsGoodNames)

        // Adding to idToFields so that they get deleted in tearDown
        idToFields.addEntries(from: idToFieldsGoodNames)
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

        // first sync down
        trySyncDown(.overwrite)

        // Sync up
        trySyncUp(0, mergeMode: .overwrite)

        // Check that db doesn't show entries as locally modified
        checkDbStateFlags(idToFields.allKeys as! [String], soupName: ACCOUNTS_SOUP, expectedLocallyCreated: false, expectedLocallyUpdated: false, expectedLocallyDeleted: false)

        // Check server
        checkServer(idToFields as! [String: Any])
    }

    /// Sync down the test accounts, modify a few, sync up, check smartstore and server afterwards
    func testSyncUpWithLocallyUpdatedRecords() {
        createTestData()

        // first sync down
        trySyncDown(.overwrite)

        // Make some local change
        let idToFieldsLocallyUpdated = makeSomeLocalChanges()

        // Sync up
        trySyncUp(idToFieldsLocallyUpdated.count, mergeMode: .overwrite)

        // Check that db doesn't show entries as locally modified anymore
        checkDbStateFlags(Array(idToFieldsLocallyUpdated.keys), soupName: ACCOUNTS_SOUP, expectedLocallyCreated: false, expectedLocallyUpdated: false, expectedLocallyDeleted: false)

        // Check server
        checkServer(idToFieldsLocallyUpdated)
    }

    /// Sync down the test accounts, modify a few, sync up specifying update field list, check smartstore and server afterwards
    func testSyncUpWithUpdateFieldList() {
        createTestData()
        trySyncDown(.overwrite)

        let idToFieldsLocallyUpdated = makeSomeLocalChanges()

        // Sync up with update field list including only name
        let target = buildSyncUpTarget(createFieldlist: nil, updateFieldlist: [NAME])
        trySyncUp(idToFieldsLocallyUpdated.count, target: target, mergeMode: .overwrite)

        checkDbStateFlags(Array(idToFieldsLocallyUpdated.keys), soupName: ACCOUNTS_SOUP, expectedLocallyCreated: false, expectedLocallyUpdated: false, expectedLocallyDeleted: false)

        // Check server - make sure only name was updated
        var idToFieldsExpectedOnServer: [String: Any] = [:]
        for recordId in idToFieldsLocallyUpdated.keys {
            let localFields = idToFieldsLocallyUpdated[recordId] as! [String: Any]
            let origFields = idToFields[recordId] as! [String: Any]
            idToFieldsExpectedOnServer[recordId] = [NAME: localFields[NAME]!, DESCRIPTION: origFields[DESCRIPTION]!]
        }
        checkServer(idToFieldsExpectedOnServer)
    }

    /// Create accounts locally, sync up specifying create field list, check smartstore and server afterwards
    func testSyncUpWithCreateFieldList() {
        createTestData()

        let names = [createAccountName(), createAccountName(), createAccountName()]
        createAccountsLocally(names)

        // Sync up with create field list including only name
        let target = buildSyncUpTarget(createFieldlist: [NAME], updateFieldlist: nil)
        trySyncUp(names.count, target: target, mergeMode: .overwrite)

        let idToFieldsCreated = getIdToFieldsByName(ACCOUNTS_SOUP, fieldNames: [NAME, DESCRIPTION], nameField: NAME, names: names)
        checkDbStateFlags(Array(idToFieldsCreated.keys), soupName: ACCOUNTS_SOUP, expectedLocallyCreated: false, expectedLocallyUpdated: false, expectedLocallyDeleted: false)

        // Check server - make sure only name was set
        var idToFieldsExpectedOnServer: [String: Any] = [:]
        for recordId in idToFieldsCreated.keys {
            let fields = idToFieldsCreated[recordId] as! [String: Any]
            idToFieldsExpectedOnServer[recordId] = [NAME: fields[NAME]!, DESCRIPTION: NSNull()]
        }
        checkServer(idToFieldsExpectedOnServer, byNames: names)

        idToFields.addEntries(from: idToFieldsCreated)
    }

    /// Sync down the test accounts, modify a few, create accounts locally, sync up specifying different create and update field list
    func testSyncUpWithCreateAndUpdateFieldList() {
        createTestData()
        trySyncDown(.overwrite)

        let idToFieldsLocallyUpdated = makeSomeLocalChanges()
        var namesOfUpdated: [String] = []
        for recordId in idToFieldsLocallyUpdated.keys {
            let fields = idToFieldsLocallyUpdated[recordId] as! [String: Any]
            namesOfUpdated.append(fields[NAME] as! String)
        }

        let namesOfCreated = [createAccountName(), createAccountName(), createAccountName()]
        createAccountsLocally(namesOfCreated)

        let target = buildSyncUpTarget(createFieldlist: [NAME], updateFieldlist: [DESCRIPTION])
        trySyncUp(namesOfUpdated.count + namesOfCreated.count, target: target, mergeMode: .overwrite)

        let idToFieldsCreated = getIdToFieldsByName(ACCOUNTS_SOUP, fieldNames: [NAME, DESCRIPTION], nameField: NAME, names: namesOfCreated)
        checkDbStateFlags(Array(idToFieldsCreated.keys), soupName: ACCOUNTS_SOUP, expectedLocallyCreated: false, expectedLocallyUpdated: false, expectedLocallyDeleted: false)

        XCTAssertEqual(namesOfCreated.count, idToFieldsCreated.count)

        var idToFieldsExpectedOnServer: [String: Any] = [:]
        for recordId in idToFieldsLocallyUpdated.keys {
            let origFields = idToFields[recordId] as! [String: Any]
            let localFields = idToFieldsLocallyUpdated[recordId] as! [String: Any]
            idToFieldsExpectedOnServer[recordId] = [NAME: origFields[NAME]!, DESCRIPTION: localFields[DESCRIPTION]!]
        }
        for recordId in idToFieldsCreated.keys {
            let fields = idToFieldsCreated[recordId] as! [String: Any]
            idToFieldsExpectedOnServer[recordId] = [NAME: fields[NAME]!, DESCRIPTION: NSNull()]
        }

        let allNames = namesOfCreated + namesOfUpdated
        XCTAssertEqual(allNames.count, idToFieldsExpectedOnServer.count)
        checkServer(idToFieldsExpectedOnServer)

        idToFields.addEntries(from: idToFieldsCreated)
    }

    /// Sync down the test accounts, modify a few, sync up with merge mode LEAVE_IF_CHANGED
    func testSyncUpWithLocallyUpdatedRecordsWithoutOverwrite() {
        createTestData()
        trySyncDown(.leaveIfChanged)

        let idToFieldsLocallyUpdated = makeSomeLocalChanges()
        let ids = Array(idToFieldsLocallyUpdated.keys)

        var idToFieldsRemotelyUpdated: [String: Any] = [:]
        for accountId in ids {
            let origFields = idToFields[accountId] as! [String: Any]
            let updatedName = "\(origFields[NAME] as! String)_updated_again"
            let updatedDescription = "\(origFields[DESCRIPTION] as! String)_updated_again"
            idToFieldsRemotelyUpdated[accountId] = [NAME: updatedName, DESCRIPTION: updatedDescription]
        }
        updateAccountsOnServer(idToFieldsRemotelyUpdated)

        trySyncUp(idToFieldsLocallyUpdated.count, mergeMode: .leaveIfChanged)

        checkDbStateFlags(ids, soupName: ACCOUNTS_SOUP, expectedLocallyCreated: false, expectedLocallyUpdated: true, expectedLocallyDeleted: false)
        checkServer(idToFieldsRemotelyUpdated)
    }

    /// Create accounts locally, sync up with merge mode OVERWRITE
    func testSyncUpWithLocallyCreatedRecords() {
        trySyncUpWithLocallyCreatedRecords(.overwrite)
    }

    /// Create accounts locally, sync up with merge mode LEAVE_IF_CHANGED
    func testSyncUpWithLocallyCreatedRecordsWithoutOverwrite() {
        trySyncUpWithLocallyCreatedRecords(.leaveIfChanged)
    }

    /// Create accounts locally, delete them locally, sync up with merge mode LEAVE_IF_CHANGED
    func testSyncUpWithLocallyCreatedAndDeletedRecords() {
        createTestData()

        let names = [createAccountName(), createAccountName(), createAccountName()]
        createAccountsLocally(names)
        let idToFieldsCreated = getIdToFieldsByName(ACCOUNTS_SOUP, fieldNames: [NAME, DESCRIPTION], nameField: NAME, names: names)

        let allIds = Array(idToFieldsCreated.keys)
        let idsLocallyDeleted = [allIds[0], allIds[1], allIds[2]]
        deleteAccountsLocally(idsLocallyDeleted)

        trySyncUp(3, mergeMode: .leaveIfChanged)

        // Check that db doesn't contain those entries anymore
        let idsClause = buildInClause(idsLocallyDeleted)
        let smartSql = "SELECT {accounts:_soup} FROM {accounts} WHERE {accounts:Id} IN \(idsClause)"
        let query = QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: UInt(idsLocallyDeleted.count))!
        let rows = (try? store.query(using: query, startingFromPageIndex: 0)) ?? []
        XCTAssertEqual(0, rows.count)
    }

    /// Sync down the test accounts, delete a few, sync up, check smartstore and server afterwards
    func testSyncUpWithLocallyDeletedRecords() {
        createTestData()
        trySyncDown(.overwrite)

        let allIds = idToFields.allKeys as! [String]
        let idsLocallyDeleted = [allIds[0], allIds[1], allIds[2]]
        deleteAccountsLocally(idsLocallyDeleted)

        trySyncUp(3, mergeMode: .overwrite)

        let idsClause = buildInClause(idsLocallyDeleted)
        let smartSql = "SELECT {accounts:_soup} FROM {accounts} WHERE {accounts:Id} IN \(idsClause)"
        let query = QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: UInt(idsLocallyDeleted.count))!
        let rows = (try? store.query(using: query, startingFromPageIndex: 0)) ?? []
        XCTAssertEqual(0, rows.count)

        let soql = "SELECT Id, Name FROM Account WHERE Id IN \(idsClause)"
        let request = RestClient.shared.requestForQuery(soql, apiVersion: nil)
        let response = sendSyncRequest(request)
        let records = response?[RECORDS] as? [Any] ?? []
        XCTAssertEqual(0, records.count)
    }

    /// Sync down the test accounts, delete account on server, update same account locally, sync up
    func testSyncUpWithLocallyUpdatedRemotelyDeletedRecords() {
        createTestData()
        trySyncDown(.overwrite)

        let idToFieldsLocallyUpdated = makeSomeLocalChanges()
        var names: [String] = []
        for fields in idToFieldsLocallyUpdated.values {
            let f = fields as! [String: Any]
            names.append(f[NAME] as! String)
        }

        let remotelyDeletedId = Array(idToFieldsLocallyUpdated.keys)[0]
        deleteAccounts(onServer: [remotelyDeletedId])

        let locallyUpdatedRemotelyDeletedName = (idToFieldsLocallyUpdated[remotelyDeletedId] as! [String: Any])[NAME] as! String

        trySyncUp(names.count, mergeMode: .overwrite)

        let namesClause = buildInClause(names)
        let smartSql = "SELECT {accounts:_soup} FROM {accounts} WHERE {accounts:Name} IN \(namesClause)"
        let query = QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: UInt(names.count))!
        let rows = (try? store.query(using: query, startingFromPageIndex: 0)) ?? []
        var idToFieldsUpdated: [String: Any] = [:]
        for row in rows {
            guard let rowArray = row as? [Any],
                  let account = rowArray[0] as? [String: Any] else { continue }
            let accountId = account[ID] as! String
            let accountName = account[NAME] as! String
            idToFieldsUpdated[accountId] = [NAME: accountName, DESCRIPTION: account[DESCRIPTION] as Any]
            XCTAssertEqual(false, account[syncTargetLocal] as? Bool)
            XCTAssertEqual(false, account[syncTargetLocallyCreated] as? Bool)
            XCTAssertEqual(false, account[syncTargetLocallyUpdated] as? Bool)
            XCTAssertEqual(false, account[syncTargetLocallyDeleted] as? Bool)

            if accountName == locallyUpdatedRemotelyDeletedName {
                XCTAssertNil(idToFields[accountId])
            } else {
                XCTAssertNotNil(idToFields[accountId])
            }
        }

        checkServer(idToFieldsUpdated, byNames: names)
        idToFields.addEntries(from: idToFieldsUpdated)
    }

    /// Sync down the test accounts, delete account on server, update same account locally, sync up with LEAVE_IF_CHANGED
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
        let query = QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: UInt(ids.count))!
        let rows = (try? store.query(using: query, startingFromPageIndex: 0)) ?? []
        for row in rows {
            guard let rowArray = row as? [Any],
                  let account = rowArray[0] as? [String: Any] else { continue }
            if (account[ID] as? String) == remotelyDeletedId {
                XCTAssertEqual(true, account[syncTargetLocal] as? Bool)
                XCTAssertEqual(false, account[syncTargetLocallyCreated] as? Bool)
                XCTAssertEqual(true, account[syncTargetLocallyUpdated] as? Bool)
                XCTAssertEqual(false, account[syncTargetLocallyDeleted] as? Bool)
            } else {
                XCTAssertEqual(false, account[syncTargetLocal] as? Bool)
                XCTAssertEqual(false, account[syncTargetLocallyCreated] as? Bool)
                XCTAssertEqual(false, account[syncTargetLocallyUpdated] as? Bool)
                XCTAssertEqual(false, account[syncTargetLocallyDeleted] as? Bool)
            }
        }

        let soql = "SELECT Id, Name, Description FROM Account WHERE Id IN \(idsClause)"
        let request = RestClient.shared.requestForQuery(soql, apiVersion: nil)
        let response = sendSyncRequest(request)
        let records = response?[RECORDS] as? [[String: Any]] ?? []
        var idsOnServer: [String] = []
        for record in records {
            let recordId = record[ID] as! String
            idsOnServer.append(recordId)
            let localFields = idToFieldsLocallyUpdated[recordId] as! [String: Any]
            XCTAssertEqual(localFields[NAME] as? String, record[NAME] as? String)
            XCTAssertEqual(localFields[DESCRIPTION] as? String, record[DESCRIPTION] as? String)
        }
        XCTAssertFalse(idsOnServer.contains(remotelyDeletedId))
        XCTAssertEqual(ids.count - 1, idsOnServer.count)
    }

    /// Sync down the test accounts, delete account on server, delete same account locally, sync up
    func testSyncUpWithLocallyDeletedRemotelyDeletedRecords() {
        createTestData()
        trySyncDown(.overwrite)

        let locallyAndRemotelyDeletedId = (idToFields.allKeys as! [String])[0]
        deleteAccountsLocally([locallyAndRemotelyDeletedId])
        deleteAccounts(onServer: [locallyAndRemotelyDeletedId])

        trySyncUp(1, mergeMode: .overwrite)

        let idsClause = buildInClause([locallyAndRemotelyDeletedId])
        let smartSql = "SELECT {accounts:_soup} FROM {accounts} WHERE {accounts:Id} IN \(idsClause)"
        let query = QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: 1)!
        let rows = (try? store.query(using: query, startingFromPageIndex: 0)) ?? []
        XCTAssertEqual(0, rows.count)

        let soql = "SELECT Id, Name FROM Account WHERE Id IN \(idsClause)"
        let request = RestClient.shared.requestForQuery(soql, apiVersion: nil)
        let response = sendSyncRequest(request)
        let records = response?[RECORDS] as? [Any] ?? []
        XCTAssertEqual(0, records.count)
    }

    /// Sync down the test accounts, delete a few, sync up with merge mode LEAVE_IF_CHANGED
    func testSyncUpWithLocallyDeletedRecordsWithoutOverwrite() {
        createTestData()
        trySyncDown(.leaveIfChanged)

        let allIds = idToFields.allKeys as! [String]
        let idsLocallyDeleted = [allIds[0], allIds[1], allIds[2]]
        deleteAccountsLocally(idsLocallyDeleted)

        var idToFieldsRemotelyUpdated: [String: Any] = [:]
        for accountId in idsLocallyDeleted {
            let origFields = idToFields[accountId] as! [String: Any]
            let updatedName = "\(origFields[NAME] as! String)_updated_again"
            let updatedDescription = "\(origFields[DESCRIPTION] as! String)_updated_again"
            idToFieldsRemotelyUpdated[accountId] = [NAME: updatedName, DESCRIPTION: updatedDescription]
        }
        updateAccountsOnServer(idToFieldsRemotelyUpdated)

        trySyncUp(3, mergeMode: .leaveIfChanged)

        checkDbStateFlags(idsLocallyDeleted, soupName: ACCOUNTS_SOUP, expectedLocallyCreated: false, expectedLocallyUpdated: false, expectedLocallyDeleted: true)
        checkServer(idToFieldsRemotelyUpdated)
    }

    /// Create accounts locally but with external id field populated, sync up with external id field name provided
    func testSyncUpWithExternalId() {
        let externalIdFieldName = "Id"
        createTestData()

        let name1 = createAccountName()
        let name2 = createAccountName()
        let name3 = createAccountName()

        let allIds = idToFields.allKeys as! [String]
        let id1 = allIds[0]
        let id2 = allIds[1]

        let localAccounts = createAccountsLocally([name1, name2, name3])!
        var localRecord1 = NSMutableDictionary(dictionary: localAccounts[0] as! NSDictionary)
        var localRecord2 = NSMutableDictionary(dictionary: localAccounts[1] as! NSDictionary)
        var localRecord3 = NSMutableDictionary(dictionary: localAccounts[2] as! NSDictionary)

        localRecord1[externalIdFieldName] = id1
        localRecord2[externalIdFieldName] = id2
        localRecord3[externalIdFieldName] = nil
        store.upsert(entries: [localRecord1, localRecord2, localRecord3], forSoupNamed: ACCOUNTS_SOUP)

        let options = SFSyncOptions.newSyncOptions(forSyncUp: [NAME])
        trySyncUp(3, options: options, externalIdFieldName: externalIdFieldName)

        let id3 = Array(getIdToFieldsByName(ACCOUNTS_SOUP, fieldNames: [], nameField: NAME, names: [name3]).keys)[0]

        var expectedDbIdFields: [String: Any] = [:]
        expectedDbIdFields[id1] = [NAME: name1, DESCRIPTION: (localRecord1[DESCRIPTION] as Any)]
        expectedDbIdFields[id2] = [NAME: name2, DESCRIPTION: (localRecord2[DESCRIPTION] as Any)]
        expectedDbIdFields[id3] = [NAME: name3, DESCRIPTION: (localRecord3[DESCRIPTION] as Any)]

        checkDbStateFlags(Array(expectedDbIdFields.keys), soupName: ACCOUNTS_SOUP, expectedLocallyCreated: false, expectedLocallyUpdated: false, expectedLocallyDeleted: false)
        checkDb(expectedDbIdFields, soupName: ACCOUNTS_SOUP)

        var expectedServerIdToFields: [String: Any] = [:]
        expectedServerIdToFields[id1] = [NAME: name1, DESCRIPTION: (idToFields[id1] as! [String: Any])[DESCRIPTION]!]
        expectedServerIdToFields[id2] = [NAME: name2, DESCRIPTION: (idToFields[id2] as! [String: Any])[DESCRIPTION]!]
        expectedServerIdToFields[id3] = [NAME: name3, DESCRIPTION: NSNull()]

        checkServer(expectedServerIdToFields)
        idToFields.addEntries(from: expectedServerIdToFields)
    }

    func testSyncUpManyLocallyCreatedRecords() {
        trySyncUpWithLocallyCreatedRecords(.overwrite, countRecords: 500)
    }

    // MARK: - Helper methods

    func trySyncUpBadTypeOrNoType(noType: Bool) {
        createAccountsSoup()
        idToFields = NSMutableDictionary()

        let namesGoodRecords = [createAccountName(), createAccountName(), createAccountName()]
        let namesBadRecords = [createAccountName(), createAccountName()]

        createAccountsLocally(namesGoodRecords)
        createAccountsLocally(namesBadRecords, mutateBlock: { record in
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

        let idToFieldsBadNames = getIdToFieldsByName(ACCOUNTS_SOUP, fieldNames: [NAME, DESCRIPTION, syncTargetLastError], nameField: NAME, names: namesBadRecords)
        checkDbStateFlags(Array(idToFieldsBadNames.keys), soupName: ACCOUNTS_SOUP, expectedLocallyCreated: true, expectedLocallyUpdated: false, expectedLocallyDeleted: false)

        XCTAssertEqual(idToFieldsBadNames.count, namesBadRecords.count)
        for fields in idToFieldsBadNames.values {
            guard let fieldsDict = fields as? [String: Any] else { continue }
            let name = fieldsDict[NAME] as? String ?? ""
            let lastError = fieldsDict[syncTargetLastError] as? String ?? ""
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
        idToFields.addEntries(from: idToFieldsGoodNames)
    }

    func trySyncUpWithLocallyCreatedRecords(_ syncUpMergeMode: SyncMergeMode) {
        trySyncUpWithLocallyCreatedRecords(syncUpMergeMode, countRecords: 3)
    }

    func trySyncUpWithLocallyCreatedRecords(_ syncUpMergeMode: SyncMergeMode, countRecords: Int) {
        createTestData()

        var names: [String] = []
        for _ in 0..<countRecords {
            names.append(createAccountName())
        }
        createAccountsLocally(names)

        trySyncUp(countRecords, mergeMode: syncUpMergeMode)

        let idToFieldsCreated = getIdToFieldsByName(ACCOUNTS_SOUP, fieldNames: [NAME, DESCRIPTION], nameField: NAME, names: names)
        checkDbStateFlags(Array(idToFieldsCreated.keys), soupName: ACCOUNTS_SOUP, expectedLocallyCreated: false, expectedLocallyUpdated: false, expectedLocallyDeleted: false)

        checkServer(idToFieldsCreated)
        idToFields.addEntries(from: idToFieldsCreated)
    }

    func trySyncUp(_ numberChanges: Int, mergeMode: SyncMergeMode) {
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

    func checkServer(_ idToFieldsToCheck: [String: Any]) {
        checkServer(idToFieldsToCheck, objectType: ACCOUNT_TYPE)
    }

    func checkServer(_ idToFieldsToCheck: [String: Any], byNames names: [String]) {
        let namesClause = buildInClause(names)
        let soql = "SELECT Id, Name, Description FROM Account WHERE Name IN \(namesClause)"
        let request = RestClient.shared.requestForQuery(soql, apiVersion: nil)
        let response = sendSyncRequest(request)
        let records = response?[RECORDS] as? [[String: Any]] ?? []
        XCTAssertEqual(names.count, records.count)
        for record in records {
            let accountId = record[ID] as! String
            if let expectedFields = idToFieldsToCheck[accountId] as? [String: Any] {
                for fieldName in expectedFields.keys {
                    if expectedFields[fieldName] is NSNull {
                        XCTAssertTrue(record[fieldName] == nil || record[fieldName] is NSNull, "Field \(fieldName) should be null")
                    } else {
                        XCTAssertEqual(expectedFields[fieldName] as? String, record[fieldName] as? String)
                    }
                }
            }
        }
    }

    func createTestData() {
        createAccountsSoup()
        idToFields = NSMutableDictionary(dictionary: createAccounts(onServer: COUNT_TEST_ACCOUNTS) ?? [:])
    }

    func deleteTestData() {
        if let ids = idToFields?.allKeys as? [String] {
            deleteAccounts(onServer: ids)
        }
        dropAccountsSoup()
        deleteSyncs()
        idToFields = nil
    }

    func makeSomeLocalChanges() -> [String: Any] {
        return makeSomeLocalChanges(idToFields as! [String: Any], soupName: ACCOUNTS_SOUP)
    }

    func makeSomeRemoteChangesHelper() -> [String: Any] {
        return makeSomeRemoteChanges(idToFields as! [String: Any], objectType: ACCOUNT_TYPE)
    }

    @discardableResult
    func trySyncDown(_ mergeMode: SyncMergeMode) -> Int {
        let idsClause = buildInClause(idToFields.allKeys as! [String])
        let soql = "SELECT Id, Name, Description, LastModifiedDate FROM Account WHERE Id IN \(idsClause)"
        let target = SoqlSyncDownTarget.newSyncTarget(soql)
        return trySyncDown(mergeMode, target: target, soupName: ACCOUNTS_SOUP, totalSize: UInt(idToFields.count), numberFetches: 1)
    }

    @nonobjc func updateAccountsOnServer(_ idToFieldsUpdated: [String: Any]) {
        updateRecordsOnServer(idToFieldsUpdated, objectType: ACCOUNT_TYPE)
    }

    // MARK: - THE methods responsible for building sync up targets used in all the tests

    func buildSyncUpTarget() -> SyncUpTarget {
        return buildSyncUpTarget(createFieldlist: nil, updateFieldlist: nil)
    }

    func buildSyncUpTarget(createFieldlist: [String]?, updateFieldlist: [String]?) -> SyncUpTarget {
        return SyncUpTarget(createFieldlist: createFieldlist, updateFieldlist: updateFieldlist)
    }
}
