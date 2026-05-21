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
@testable import MobileSync
@testable import SalesforceSDKCore

// Useful enum for trySyncUpsWithVariousChanges
private enum SyncUpChange: Int {
    case none
    case update
    case delete
}

class ParentChildrenSyncTests: SyncManagerTestCase {

    private var accountIdToFields: [String: [String: Any]] = [:]
    private var accountIdContactIdToFields: [String: [String: [String: Any]]] = [:]

    // MARK: - setUp/tearDown

    override func setUp() {
        super.setUp()
        createTestData()
    }

    override func tearDown() {
        deleteTestData()
        super.tearDown()
    }

    // MARK: - Tests

    /// Test getQuery for SFParentChildrenSyncDownTarget
    func testGetQuery() {
        let target = SFParentChildrenSyncDownTarget.newSyncTarget(
            parentInfo: SFParentInfo.new(withSObjectType: "Parent", soupName: "parentsSoup", idFieldName: "ParentId", modificationDateFieldName: "ParentModifiedDate"),
            parentFieldlist: ["ParentName", "Title"],
            parentSoqlFilter: "School = 'MIT'",
            childrenInfo: SFChildrenInfo.new(withSObjectType: "Child", sobjectTypePlural: "Children", soupName: "childrenSoup", parentIdFieldName: "parentId", idFieldName: "ChildId", modificationDateFieldName: "ChildLastModifiedDate"),
            childrenFieldlist: ["ChildName", "School"],
            relationshipType: .lookup)

        let expectedQuery = "select ParentName, Title, ParentId, ParentModifiedDate, (select ChildName, School, ChildId, ChildLastModifiedDate from Children) from Parent where School = 'MIT' order by ParentModifiedDate"
        XCTAssertEqual(target.getQueryToRun(), expectedQuery)

        // With default id and modification date fields
        let target2 = SFParentChildrenSyncDownTarget.newSyncTarget(
            parentInfo: SFParentInfo.new(withSObjectType: "Parent", soupName: "parentsSoup"),
            parentFieldlist: ["ParentName", "Title"],
            parentSoqlFilter: "School = 'MIT'",
            childrenInfo: SFChildrenInfo.new(withSObjectType: "Child", sobjectTypePlural: "Children", soupName: "childrenSoup", parentIdFieldName: "parentId"),
            childrenFieldlist: ["ChildName", "School"],
            relationshipType: .lookup)

        let expectedQuery2 = "select ParentName, Title, Id, LastModifiedDate, (select ChildName, School, Id, LastModifiedDate from Children) from Parent where School = 'MIT' order by LastModifiedDate"
        XCTAssertEqual(target2.getQueryToRun(), expectedQuery2)
    }

    /// Test query for reSync by calling getQuery with maxTimeStamp for SFParentChildrenSyncDownTarget
    func testGetQueryWithMaxTimeStamp() {
        let date = Date()
        let maxTimeStamp = Int64(date.timeIntervalSince1970)
        let dateStr = SFMobileSyncObjectUtils.getIsoString(fromMillis: maxTimeStamp) ?? ""

        let target = SFParentChildrenSyncDownTarget.newSyncTarget(
            parentInfo: SFParentInfo.new(withSObjectType: "Parent", soupName: "parentsSoup", idFieldName: "ParentId", modificationDateFieldName: "ParentModifiedDate"),
            parentFieldlist: ["ParentName", "Title"],
            parentSoqlFilter: "School = 'MIT'",
            childrenInfo: SFChildrenInfo.new(withSObjectType: "Child", sobjectTypePlural: "Children", soupName: "childrenSoup", parentIdFieldName: "parentId", idFieldName: "ChildId", modificationDateFieldName: "ChildLastModifiedDate"),
            childrenFieldlist: ["ChildName", "School"],
            relationshipType: .lookup)

        let expectedQuery = "select ParentName, Title, ParentId, ParentModifiedDate, (select ChildName, School, ChildId, ChildLastModifiedDate from Children where ChildLastModifiedDate > \(dateStr)) from Parent where ParentModifiedDate > \(dateStr) and School = 'MIT' order by ParentModifiedDate"
        XCTAssertEqual(target.getQueryToRun(maxTimeStamp), expectedQuery)

        // With default id and modification date fields
        let target2 = SFParentChildrenSyncDownTarget.newSyncTarget(
            parentInfo: SFParentInfo.new(withSObjectType: "Parent", soupName: "parentsSoup"),
            parentFieldlist: ["ParentName", "Title"],
            parentSoqlFilter: "School = 'MIT'",
            childrenInfo: SFChildrenInfo.new(withSObjectType: "Child", sobjectTypePlural: "Children", soupName: "childrenSoup", parentIdFieldName: "parentId"),
            childrenFieldlist: ["ChildName", "School"],
            relationshipType: .lookup)

        let expectedQuery2 = "select ParentName, Title, Id, LastModifiedDate, (select ChildName, School, Id, LastModifiedDate from Children where LastModifiedDate > \(dateStr)) from Parent where LastModifiedDate > \(dateStr) and School = 'MIT' order by LastModifiedDate"
        XCTAssertEqual(target2.getQueryToRun(maxTimeStamp), expectedQuery2)
    }

    /// Test getSoqlForRemoteIds for SFParentChildrenSyncDownTarget
    func testGetSoqlForRemoteIds() {
        let target = SFParentChildrenSyncDownTarget.newSyncTarget(
            parentInfo: SFParentInfo.new(withSObjectType: "Parent", soupName: "parentsSoup", idFieldName: "ParentId", modificationDateFieldName: "ParentModifiedDate"),
            parentFieldlist: ["ParentName", "Title"],
            parentSoqlFilter: "School = 'MIT'",
            childrenInfo: SFChildrenInfo.new(withSObjectType: "Child", sobjectTypePlural: "Children", soupName: "childrenSoup", parentIdFieldName: "ChildParentId", idFieldName: "ChildId", modificationDateFieldName: "ChildLastModifiedDate"),
            childrenFieldlist: ["ChildName", "School"],
            relationshipType: .lookup)

        let expectedQuery = "select ParentId from Parent where School = 'MIT'"
        XCTAssertEqual(target.getSoqlForRemoteIds(), expectedQuery)

        // With default id and modification date fields
        let target2 = SFParentChildrenSyncDownTarget.newSyncTarget(
            parentInfo: SFParentInfo.new(withSObjectType: "Parent", soupName: "parentsSoup"),
            parentFieldlist: ["ParentName", "Title"],
            parentSoqlFilter: "School = 'MIT'",
            childrenInfo: SFChildrenInfo.new(withSObjectType: "Child", sobjectTypePlural: "Children", soupName: "childrenSoup", parentIdFieldName: "parentId"),
            childrenFieldlist: ["ChildName", "School"],
            relationshipType: .lookup)

        let expectedQuery2 = "select Id from Parent where School = 'MIT'"
        XCTAssertEqual(target2.getSoqlForRemoteIds(), expectedQuery2)
    }

    /// Test getDirtyRecordIdsSql for SFParentChildrenSyncDownTarget
    func testGetDirtyRecordIdsSql() {
        let target = SFParentChildrenSyncDownTarget.newSyncTarget(
            parentInfo: SFParentInfo.new(withSObjectType: "Parent", soupName: "parentsSoup", idFieldName: "ParentId", modificationDateFieldName: "ParentModifiedDate"),
            parentFieldlist: ["ParentName", "Title"],
            parentSoqlFilter: "School = 'MIT'",
            childrenInfo: SFChildrenInfo.new(withSObjectType: "Child", sobjectTypePlural: "Children", soupName: "childrenSoup", parentIdFieldName: "ChildParentId", idFieldName: "ChildId", modificationDateFieldName: "ChildLastModifiedDate"),
            childrenFieldlist: ["ChildName", "School"],
            relationshipType: .lookup)

        let expectedQuery = "SELECT DISTINCT {parentsSoup:IdForQuery} FROM {parentsSoup} WHERE {parentsSoup:__local__} = 1 OR EXISTS (SELECT {childrenSoup:ChildId} FROM {childrenSoup} WHERE {childrenSoup:ChildParentId} = {parentsSoup:ParentId} AND {childrenSoup:__local__} = 1)"
        XCTAssertEqual(target.getDirtyRecordIdsSql("parentsSoup", idField: "IdForQuery"), expectedQuery)
    }

    /// Test getNonDirtyRecordIdsSql for SFParentChildrenSyncDownTarget
    func testGetNonDirtyRecordIdsSql() {
        let target = SFParentChildrenSyncDownTarget.newSyncTarget(
            parentInfo: SFParentInfo.new(withSObjectType: "Parent", soupName: "parentsSoup", idFieldName: "ParentId", modificationDateFieldName: "ParentModifiedDate"),
            parentFieldlist: ["ParentName", "Title"],
            parentSoqlFilter: "School = 'MIT'",
            childrenInfo: SFChildrenInfo.new(withSObjectType: "Child", sobjectTypePlural: "Children", soupName: "childrenSoup", parentIdFieldName: "ChildParentId", idFieldName: "ChildId", modificationDateFieldName: "ChildLastModifiedDate"),
            childrenFieldlist: ["ChildName", "School"],
            relationshipType: .lookup)

        let expectedQuery = "SELECT DISTINCT {parentsSoup:IdForQuery} FROM {parentsSoup} WHERE {parentsSoup:__local__} = 0 AND {parentsSoup:__sync_id__} = 123 AND NOT EXISTS (SELECT {childrenSoup:ChildId} FROM {childrenSoup} WHERE {childrenSoup:ChildParentId} = {parentsSoup:ParentId} AND {childrenSoup:__local__} = 1)"
        XCTAssertEqual(target.getNonDirtyRecordIdsSql("parentsSoup", idField: "IdForQuery", additionalPredicate: "AND {parentsSoup:__sync_id__} = 123"), expectedQuery)
    }

    /// Test getDirtyRecordIds and getNonDirtyRecordIds for SFParentChildrenSyncDownTarget when parent and/or all and/or some children are dirty
    func testGetDirtyAndNonDirtyRecordIds() {
        let accountNames: [String] = [
            createAccountName(),
            createAccountName(),
            createAccountName(),
            createAccountName(),
            createAccountName(),
            createAccountName()
        ]

        let result = createAccountsAndContactsLocally(accountNames, numberOfContactsPerAccount: 3)
        let accounts = result.accounts
        let accountIdToContacts = result.accountIdToContacts

        // All Accounts should be returned
        tryGetDirtyRecordIds(accounts)

        // No accounts should be returned
        tryGetNonDirtyRecordIds([])

        // Cleaning up:
        // accounts[0]: dirty account and dirty contacts
        // accounts[1]: clean account and dirty contacts
        // accounts[2]: dirty account and clean contacts
        // accounts[3]: clean account and clean contacts
        // accounts[4]: dirty account and some dirty contacts
        // accounts[5]: clean account and some dirty contacts

        cleanRecord(ACCOUNTS_SOUP, record: accounts[1])
        cleanRecords(CONTACTS_SOUP, records: accountIdToContacts[accounts[2][ID] as? String ?? ""] ?? [])
        cleanRecord(ACCOUNTS_SOUP, record: accounts[3])
        cleanRecords(CONTACTS_SOUP, records: accountIdToContacts[accounts[3][ID] as? String ?? ""] ?? [])
        cleanRecord(CONTACTS_SOUP, record: (accountIdToContacts[accounts[4][ID] as? String ?? ""] ?? [])[0])
        cleanRecord(ACCOUNTS_SOUP, record: accounts[5])
        cleanRecord(CONTACTS_SOUP, record: (accountIdToContacts[accounts[5][ID] as? String ?? ""] ?? [])[0])

        // Only clean account with clean contacts should not be returned
        tryGetDirtyRecordIds([accounts[0], accounts[1], accounts[2], accounts[4], accounts[5]])

        // Only clean account with clean contacts should be returned
        tryGetNonDirtyRecordIds([accounts[3]])
    }

    /// Test saveRecordsToLocalStore
    func testSaveRecordsToLocalStore() {
        let numberAccounts: UInt = 4
        let numberContactsPerAccount: UInt = 3
        let syncId = NSNumber(value: 123)

        let accountAttributes: [String: Any] = [TYPE: ACCOUNT_TYPE]
        let contactAttributes: [String: Any] = [TYPE: CONTACT_TYPE]

        var accounts: [[String: Any]] = []
        var mapAccountContacts: [Int: [[String: Any]]] = [:]

        for i in 0..<numberAccounts {
            let account: [String: Any] = [ID: SFSyncTarget.createLocalId(), ATTRIBUTES: accountAttributes]
            var contacts: [[String: Any]] = []
            for _ in 0..<numberContactsPerAccount {
                contacts.append([ID: SFSyncTarget.createLocalId(), ATTRIBUTES: contactAttributes, ACCOUNT_ID: account[ID] as Any])
            }
            mapAccountContacts[Int(i)] = contacts
            accounts.append(account)
        }

        var records: [[String: Any]] = []
        for (i, account) in accounts.enumerated() {
            var record = account
            var contacts: [[String: Any]] = []
            for contact in mapAccountContacts[i] ?? [] {
                contacts.append(contact)
            }
            record[CONTACT_TYPE_PLURAL] = contacts
            records.append(record)
        }

        // Now calling saveRecordsToLocalStore
        let target = getAccountContactsSyncDownTarget()
        target.cleanAndSaveRecordsToLocalStore(syncManager: self.syncManager, soupName: ACCOUNTS_SOUP, records: records, syncId: syncId)

        // Checking accounts and contacts soup
        var accountIds: [String] = []
        for account in accounts {
            if let accountId = account[ID] as? String {
                accountIds.append(accountId)
            }
        }
        let accountsFromDb = queryWithInClause(ACCOUNTS_SOUP, fieldName: ID, values: accountIds, orderBy: SmartStoreConstants.soupEntryId)
        XCTAssertEqual(accountsFromDb.count, accounts.count, "Wrong number of accounts in db")

        for i in 0..<accountsFromDb.count {
            let account = accounts[i]
            let accountFromDb = accountsFromDb[i]

            XCTAssertEqual(accountFromDb[ID] as? String, account[ID] as? String)
            XCTAssertEqual((accountFromDb[ATTRIBUTES] as? [String: Any])?[TYPE] as? String, ACCOUNT_TYPE)
            XCTAssertEqual(accountFromDb[kSyncTargetLocal] as? Bool, false)
            XCTAssertEqual(accountFromDb[kSyncTargetLocallyCreated] as? Bool, false)
            XCTAssertEqual(accountFromDb[kSyncTargetLocallyUpdated] as? Bool, false)
            XCTAssertEqual(accountFromDb[kSyncTargetLocallyDeleted] as? Bool, false)
            XCTAssertEqual(accountFromDb[kSyncTargetSyncId] as? NSNumber, syncId)

            guard let accountIdValue = account[ID] as? String else { continue }
            let contactsFromDb = queryWithInClause(CONTACTS_SOUP, fieldName: ACCOUNT_ID, values: [accountIdValue], orderBy: SmartStoreConstants.soupEntryId)
            let contacts = mapAccountContacts[i] ?? []
            XCTAssertEqual(contactsFromDb.count, contacts.count, "Wrong number of contacts in db")

            for j in 0..<contactsFromDb.count {
                let contact = contacts[j]
                let contactFromDb = contactsFromDb[j]

                XCTAssertEqual(contactFromDb[ID] as? String, contact[ID] as? String)
                XCTAssertEqual((contactFromDb[ATTRIBUTES] as? [String: Any])?[TYPE] as? String, CONTACT_TYPE)
                XCTAssertEqual(contactFromDb[kSyncTargetLocal] as? Bool, false)
                XCTAssertEqual(contactFromDb[kSyncTargetLocallyCreated] as? Bool, false)
                XCTAssertEqual(contactFromDb[kSyncTargetLocallyUpdated] as? Bool, false)
                XCTAssertEqual(contactFromDb[kSyncTargetLocallyDeleted] as? Bool, false)
                XCTAssertEqual(contactFromDb[kSyncTargetSyncId] as? NSNumber, syncId)
                XCTAssertEqual(contactFromDb[ACCOUNT_ID] as? String, accountFromDb[ID] as? String)
            }
        }
    }

    /// Test getLatestModificationTimeStamp
    func testGetLatestModificationTimeStamp() {
        let numberAccounts: UInt = 4
        let numberContactsPerAccount: UInt = 3

        var timeStamps: [Int64] = []
        var timeStampStrs: [String] = []
        for i in 1..<5 {
            let millis = Int64(i) * 100000000
            timeStamps.append(millis)
            timeStampStrs.append(SFMobileSyncObjectUtils.getIsoString(fromMillis: millis) ?? "")
        }

        let accountAttributes: [String: Any] = [TYPE: ACCOUNT_TYPE]
        let contactAttributes: [String: Any] = [TYPE: CONTACT_TYPE]

        var accounts: [[String: Any]] = []
        var mapAccountContacts: [Int: [[String: Any]]] = [:]

        for i in 0..<Int(numberAccounts) {
            let account: [String: Any] = [
                ID: SFSyncTarget.createLocalId(),
                ATTRIBUTES: accountAttributes,
                "AccountTimeStamp1": timeStampStrs[i % timeStampStrs.count],
                "AccountTimeStamp2": timeStampStrs[0]
            ]
            var contacts: [[String: Any]] = []
            for j in 0..<Int(numberContactsPerAccount) {
                contacts.append([
                    ID: SFSyncTarget.createLocalId(),
                    ATTRIBUTES: contactAttributes,
                    ACCOUNT_ID: account[ID] as Any,
                    "ContactTimeStamp1": timeStampStrs[1],
                    "ContactTimeStamp2": timeStampStrs[j % timeStampStrs.count]
                ])
            }
            mapAccountContacts[i] = contacts
            accounts.append(account)
        }

        var records: [Any] = []
        for (i, account) in accounts.enumerated() {
            var record = account
            var contacts: [[String: Any]] = []
            for contact in mapAccountContacts[i] ?? [] {
                contacts.append(contact)
            }
            record[CONTACT_TYPE_PLURAL] = contacts
            records.append(record)
        }

        // Get max time stamps based on fields AccountTimeStamp1 / ContactTimeStamp1
        var target = getAccountContactsSyncDownTarget(accountModificationDateFieldName: "AccountTimeStamp1", contactModificationDateFieldName: "ContactTimeStamp1", parentSoqlFilter: nil)
        XCTAssertEqual(target.getLatestModificationTimeStamp(records), timeStamps[3])

        // Get max time stamps based on fields AccountTimeStamp1 / ContactTimeStamp2
        target = getAccountContactsSyncDownTarget(accountModificationDateFieldName: "AccountTimeStamp1", contactModificationDateFieldName: "ContactTimeStamp2", parentSoqlFilter: nil)
        XCTAssertEqual(target.getLatestModificationTimeStamp(records), timeStamps[3])

        // Get max time stamps based on fields AccountTimeStamp2 / ContactTimeStamp1
        target = getAccountContactsSyncDownTarget(accountModificationDateFieldName: "AccountTimeStamp2", contactModificationDateFieldName: "ContactTimeStamp1", parentSoqlFilter: nil)
        XCTAssertEqual(target.getLatestModificationTimeStamp(records), timeStamps[1])

        // Get max time stamps based on fields AccountTimeStamp2 / ContactTimeStamp2
        target = getAccountContactsSyncDownTarget(accountModificationDateFieldName: "AccountTimeStamp2", contactModificationDateFieldName: "ContactTimeStamp2", parentSoqlFilter: nil)
        XCTAssertEqual(target.getLatestModificationTimeStamp(records), timeStamps[2])
    }

    /// Sync down the test accounts and contacts, check smart store, check status during sync
    func testSyncDown() {
        let numberAccounts: UInt = 4
        let numberContactsPerAccount: UInt = 3

        createAccountsAndContactsOnServer(numberAccounts, numberContactsPerAccount: numberContactsPerAccount)

        let parentSoqlFilter = "\(ID) IN \(buildInClause(Array(accountIdToFields.keys)))"
        let target = getAccountContactsSyncDownTarget(parentSoqlFilter: parentSoqlFilter)

        trySyncDown(.overwrite, target: target, soupName: ACCOUNTS_SOUP, totalSize: UInt(numberAccounts), numberFetches: 1)

        checkDb(accountIdToFields, soupName: ACCOUNTS_SOUP)
        for accountId in accountIdToFields.keys {
            if let contactFields = accountIdContactIdToFields[accountId] {
                checkDb(contactFields, soupName: CONTACTS_SOUP)
            }
        }
    }

    /// Sync down the test accounts that do not have children contacts
    func testSyncDownNoChildren() {
        let numberAccounts: UInt = 4

        accountIdToFields = createAccountsOnServer(numberAccounts)

        let parentSoqlFilter = "\(ID) IN \(buildInClause(Array(accountIdToFields.keys)))"
        let target = getAccountContactsSyncDownTarget(parentSoqlFilter: parentSoqlFilter)

        trySyncDown(.overwrite, target: target, soupName: ACCOUNTS_SOUP, totalSize: UInt(numberAccounts), numberFetches: 1)

        checkDb(accountIdToFields, soupName: ACCOUNTS_SOUP)
    }

    /// Sync down the test accounts and contacts, make some local changes,
    /// then sync down again with merge mode LEAVE_IF_CHANGED then sync down with merge mode OVERWRITE
    func testSyncDownWithoutOverwrite() {
        let numberAccounts: UInt = 4
        let numberContactsPerAccount: UInt = 3

        createAccountsAndContactsOnServer(numberAccounts, numberContactsPerAccount: numberContactsPerAccount)

        let parentSoqlFilter = "\(ID) IN \(buildInClause(Array(accountIdToFields.keys)))"
        let target = getAccountContactsSyncDownTarget(parentSoqlFilter: parentSoqlFilter)

        trySyncDown(.overwrite, target: target, soupName: ACCOUNTS_SOUP, totalSize: UInt(numberAccounts), numberFetches: 1)

        // Make some local changes
        let accountIds = Array(accountIdToFields.keys)
        let accountIdUpdated = accountIds[0]
        let accountIdToFieldsUpdated = makeSomeLocalChanges(accountIdToFields, soupName: ACCOUNTS_SOUP, idsToUpdate: [accountIdUpdated])
        let contactIdToFieldsUpdated = makeSomeLocalChanges(accountIdContactIdToFields[accountIdUpdated] ?? [:], soupName: CONTACTS_SOUP)
        let otherAccountId = accountIds[1]
        let otherContactIdToFieldsUpdated = makeSomeLocalChanges(accountIdContactIdToFields[otherAccountId] ?? [:], soupName: CONTACTS_SOUP)

        // Sync down again with LEAVE_IF_CHANGED
        trySyncDown(.leaveIfChanged, target: target, soupName: ACCOUNTS_SOUP, totalSize: UInt(numberAccounts), numberFetches: 1)

        // Check db
        var accountIdToFieldsExpected = accountIdToFields
        for (key, value) in accountIdToFieldsUpdated {
            accountIdToFieldsExpected[key] = value
        }
        checkDb(accountIdToFieldsExpected, soupName: ACCOUNTS_SOUP)

        for accountId in accountIdToFields.keys {
            if accountId == accountIdUpdated {
                checkDbStateFlags([accountId], soupName: ACCOUNTS_SOUP, expectedLocallyCreated: false, expectedLocallyUpdated: true, expectedLocallyDeleted: false)
                checkDb(contactIdToFieldsUpdated, soupName: CONTACTS_SOUP)
                checkDbStateFlags(Array(contactIdToFieldsUpdated.keys), soupName: CONTACTS_SOUP, expectedLocallyCreated: false, expectedLocallyUpdated: true, expectedLocallyDeleted: false)
            } else if accountId == otherAccountId {
                checkDbStateFlags([accountId], soupName: ACCOUNTS_SOUP, expectedLocallyCreated: false, expectedLocallyUpdated: false, expectedLocallyDeleted: false)
                checkDb(contactIdToFieldsUpdated, soupName: CONTACTS_SOUP)
                checkDbStateFlags(Array(otherContactIdToFieldsUpdated.keys), soupName: CONTACTS_SOUP, expectedLocallyCreated: false, expectedLocallyUpdated: true, expectedLocallyDeleted: false)
            } else {
                checkDbStateFlags([accountId], soupName: ACCOUNTS_SOUP, expectedLocallyCreated: false, expectedLocallyUpdated: false, expectedLocallyDeleted: false)
                if let contactFields = accountIdContactIdToFields[accountId] {
                    checkDb(contactFields, soupName: CONTACTS_SOUP)
                    checkDbStateFlags(Array(contactFields.keys), soupName: CONTACTS_SOUP, expectedLocallyCreated: false, expectedLocallyUpdated: false, expectedLocallyDeleted: false)
                }
            }
        }

        // Sync down again with OVERWRITE
        trySyncDown(.overwrite, target: target, soupName: ACCOUNTS_SOUP, totalSize: UInt(numberAccounts), numberFetches: 1)

        // Check db - all local changes should have been written over
        checkDb(accountIdToFields, soupName: ACCOUNTS_SOUP)
        checkDbStateFlags(Array(accountIdToFields.keys), soupName: ACCOUNTS_SOUP, expectedLocallyCreated: false, expectedLocallyUpdated: false, expectedLocallyDeleted: false)

        for accountId in accountIdToFields.keys {
            if let contactFields = accountIdContactIdToFields[accountId] {
                checkDb(contactFields, soupName: CONTACTS_SOUP)
                checkDbStateFlags(Array(contactFields.keys), soupName: CONTACTS_SOUP, expectedLocallyCreated: false, expectedLocallyUpdated: false, expectedLocallyDeleted: false)
            }
        }
    }

    /// Sync down the test accounts and contacts, modify accounts, re-sync
    func testReSyncWithUpdatedParents() {
        let numberAccounts: UInt = 4
        let numberContactsPerAccount: UInt = 3

        createAccountsAndContactsOnServer(numberAccounts, numberContactsPerAccount: numberContactsPerAccount)

        let parentSoqlFilter = "\(ID) IN \(buildInClause(Array(accountIdToFields.keys)))"
        let target = getAccountContactsSyncDownTarget(parentSoqlFilter: parentSoqlFilter)
        let syncId = NSNumber(value: trySyncDown(.overwrite, target: target, soupName: ACCOUNTS_SOUP, totalSize: UInt(numberAccounts), numberFetches: 1))

        let sync = self.syncManager.getSyncStatus(syncId)
        let options = sync?.options
        let maxTimeStamp = sync?.maxTimeStamp ?? 0
        XCTAssertTrue(maxTimeStamp > 0, "Wrong time stamp")

        // Make some remote change to accounts
        let idToFieldsUpdated = makeSomeRemoteChanges(accountIdToFields, objectType: ACCOUNT_TYPE)

        // Call reSync
        let queue = SFSyncUpdateCallbackQueue()
        _ = queue.runReSync(syncId, syncManager: self.syncManager)

        // Check status updates
        checkStatus(queue.getNextSyncUpdate(), expectedType: .down, expectedId: Int(truncating: syncId), expectedTarget: target, expectedOptions: options, expectedStatus: .running, expectedProgress: 0, expectedTotalSize: -1)
        checkStatus(queue.getNextSyncUpdate(), expectedType: .down, expectedId: Int(truncating: syncId), expectedTarget: target, expectedOptions: options, expectedStatus: .running, expectedProgress: 0, expectedTotalSize: Int(idToFieldsUpdated.count))
        checkStatus(queue.getNextSyncUpdate(), expectedType: .down, expectedId: Int(truncating: syncId), expectedTarget: target, expectedOptions: options, expectedStatus: .done, expectedProgress: 100, expectedTotalSize: Int(idToFieldsUpdated.count))

        // Check db
        checkDb(idToFieldsUpdated, soupName: ACCOUNTS_SOUP)

        // Check sync time stamp
        XCTAssertTrue((self.syncManager.getSyncStatus(syncId)?.maxTimeStamp ?? 0) > maxTimeStamp)
    }

    /// Sync down the test accounts and contacts, modify contacts, re-sync
    func testReSyncWithUpdatedChildren() {
        let numberAccounts: UInt = 4
        let numberContactsPerAccount: UInt = 3

        createAccountsAndContactsOnServer(numberAccounts, numberContactsPerAccount: numberContactsPerAccount)

        let parentSoqlFilter = "\(ID) IN \(buildInClause(Array(accountIdToFields.keys)))"
        let target = getAccountContactsSyncDownTarget(parentSoqlFilter: parentSoqlFilter)
        let syncId = NSNumber(value: trySyncDown(.overwrite, target: target, soupName: ACCOUNTS_SOUP, totalSize: UInt(numberAccounts), numberFetches: 1))

        let sync = self.syncManager.getSyncStatus(syncId)
        let options = sync?.options
        let maxTimeStamp = sync?.maxTimeStamp ?? 0
        XCTAssertTrue(maxTimeStamp > 0, "Wrong time stamp")

        // Make some remote changes
        let accountIds = Array(accountIdToFields.keys)
        let accountId = accountIds[0]
        let accountIdToFieldsUpdated = makeSomeRemoteChanges(accountIdToFields, objectType: ACCOUNT_TYPE, idsToUpdate: [accountId])
        let contactIdToFieldsUpdated = makeSomeRemoteChanges(accountIdContactIdToFields[accountId] ?? [:], objectType: CONTACT_TYPE)
        let otherAccountId = accountIds[1]
        _ = makeSomeRemoteChanges(accountIdContactIdToFields[otherAccountId] ?? [:], objectType: CONTACT_TYPE)

        // Call reSync
        let queue = SFSyncUpdateCallbackQueue()
        _ = queue.runReSync(syncId, syncManager: self.syncManager)

        // Check status updates
        checkStatus(queue.getNextSyncUpdate(), expectedType: .down, expectedId: Int(truncating: syncId), expectedTarget: target, expectedOptions: options, expectedStatus: .running, expectedProgress: 0, expectedTotalSize: -1)
        checkStatus(queue.getNextSyncUpdate(), expectedType: .down, expectedId: Int(truncating: syncId), expectedTarget: target, expectedOptions: options, expectedStatus: .running, expectedProgress: 0, expectedTotalSize: Int(accountIdToFieldsUpdated.count))
        checkStatus(queue.getNextSyncUpdate(), expectedType: .down, expectedId: Int(truncating: syncId), expectedTarget: target, expectedOptions: options, expectedStatus: .done, expectedProgress: 100, expectedTotalSize: Int(accountIdToFieldsUpdated.count))

        // Check db
        checkDb(accountIdToFieldsUpdated, soupName: ACCOUNTS_SOUP)
        checkDb(contactIdToFieldsUpdated, soupName: CONTACTS_SOUP)
        if let otherContactFields = accountIdContactIdToFields[otherAccountId] {
            checkDb(otherContactFields, soupName: CONTACTS_SOUP)
        }

        // Check sync time stamp
        XCTAssertTrue((self.syncManager.getSyncStatus(syncId)?.maxTimeStamp ?? 0) > maxTimeStamp)
    }

    /// Sync down the test accounts and contacts, delete account from server - run cleanResyncGhosts
    func testCleanResyncGhostsForParentChildrenTarget() {
        let numberAccounts: UInt = 4
        let numberContactsPerAccount: UInt = 3

        createAccountsAndContactsOnServer(numberAccounts, numberContactsPerAccount: numberContactsPerAccount)

        let parentSoqlFilter = "\(ID) IN \(buildInClause(Array(accountIdToFields.keys)))"
        let target = getAccountContactsSyncDownTarget(parentSoqlFilter: parentSoqlFilter)
        let syncId = NSNumber(value: trySyncDown(.overwrite, target: target, soupName: ACCOUNTS_SOUP, totalSize: UInt(numberAccounts), numberFetches: 1))

        // Delete 1 account on server
        let accountIdDeleted = Array(accountIdToFields.keys)[0]
        deleteRecordsOnServer([accountIdDeleted], objectType: ACCOUNT_TYPE)

        let cleanExp = expectation(description: "cleanResyncGhosts")
        try? self.syncManager.cleanResyncGhosts(forId: syncId) { syncStatus, _ in
            if syncStatus == .failed || syncStatus == .done {
                cleanExp.fulfill()
            }
        }
        waitForExpectations(timeout: 30.0, handler: nil)

        // Check
        var accountIdToFieldsLeft = accountIdToFields
        accountIdToFieldsLeft.removeValue(forKey: accountIdDeleted)
        checkDb(accountIdToFieldsLeft, soupName: ACCOUNTS_SOUP)
        checkDbDeleted(ACCOUNTS_SOUP, ids: [accountIdDeleted], idField: ID)

        for accountId in accountIdContactIdToFields.keys {
            if accountId == accountIdDeleted {
                checkDbDeleted(CONTACTS_SOUP, ids: Array(accountIdContactIdToFields[accountId]?.keys ?? [:].keys), idField: ID)
            } else {
                if let contactFields = accountIdContactIdToFields[accountId] {
                    checkDb(contactFields, soupName: CONTACTS_SOUP)
                }
            }
        }
    }

    /// Tests clean ghosts when soup is populated through more than one sync down
    func testCleanResyncGhostsForParentChildrenWithMultipleSyncs() {
        let numberAccounts: UInt = 6
        let numberContactsPerAccount: UInt = 3

        createAccountsAndContactsOnServer(numberAccounts, numberContactsPerAccount: numberContactsPerAccount)

        let accountIds = Array(accountIdContactIdToFields.keys)
        let accountIdsFirstSubset = Array(accountIds[0..<3])
        let accountIdsSecondSubset = Array(accountIds[2..<6])

        // First sync down
        let firstTarget = getAccountContactsSyncDownTarget(parentSoqlFilter: "\(ID) IN \(buildInClause(accountIdsFirstSubset))")
        let firstSyncId = NSNumber(value: trySyncDown(.overwrite, target: firstTarget, soupName: ACCOUNTS_SOUP, totalSize: UInt(accountIdsFirstSubset.count), numberFetches: 1))
        checkDbExists(ACCOUNTS_SOUP, ids: accountIdsFirstSubset, idField: "Id")
        checkDbSyncIdField(accountIdsFirstSubset, soupName: ACCOUNTS_SOUP, syncId: firstSyncId)

        // Second sync down
        let secondTarget = getAccountContactsSyncDownTarget(parentSoqlFilter: "\(ID) IN \(buildInClause(accountIdsSecondSubset))")
        let secondSyncId = NSNumber(value: trySyncDown(.overwrite, target: secondTarget, soupName: ACCOUNTS_SOUP, totalSize: UInt(accountIdsSecondSubset.count), numberFetches: 1))
        checkDbExists(ACCOUNTS_SOUP, ids: accountIdsSecondSubset, idField: "Id")
        checkDbSyncIdField(accountIdsSecondSubset, soupName: ACCOUNTS_SOUP, syncId: secondSyncId)

        // Delete id0, id2, id5 on server
        deleteRecordsOnServer([accountIds[0], accountIds[2], accountIds[5]], objectType: ACCOUNT_TYPE)

        // Cleaning ghosts of first sync (should only remove id0)
        let firstCleanExp = expectation(description: "firstCleanGhosts")
        try? self.syncManager.cleanResyncGhosts(forId: firstSyncId) { syncStatus, _ in
            if syncStatus == .failed || syncStatus == .done {
                firstCleanExp.fulfill()
            }
        }
        waitForExpectations(timeout: 30.0, handler: nil)
        checkDbExists(ACCOUNTS_SOUP, ids: [accountIds[1], accountIds[2], accountIds[3], accountIds[4], accountIds[5]], idField: "Id")
        checkDbDeleted(ACCOUNTS_SOUP, ids: [accountIds[0]], idField: "Id")
        for accountId in accountIdContactIdToFields.keys {
            if accountId == accountIds[0] {
                checkDbDeleted(CONTACTS_SOUP, ids: Array(accountIdContactIdToFields[accountId]?.keys ?? [:].keys), idField: ID)
            } else {
                if let contactFields = accountIdContactIdToFields[accountId] {
                    checkDb(contactFields, soupName: CONTACTS_SOUP)
                }
            }
        }

        // Cleaning ghosts of second sync (should remove id2 and id5)
        let secondCleanExp = expectation(description: "secondCleanGhosts")
        try? self.syncManager.cleanResyncGhosts(forId: secondSyncId) { syncStatus, _ in
            if syncStatus == .failed || syncStatus == .done {
                secondCleanExp.fulfill()
            }
        }
        waitForExpectations(timeout: 30.0, handler: nil)
        checkDbExists(ACCOUNTS_SOUP, ids: [accountIds[1], accountIds[3], accountIds[4]], idField: "Id")
        checkDbDeleted(ACCOUNTS_SOUP, ids: [accountIds[0], accountIds[2], accountIds[5]], idField: "Id")
        for accountId in accountIdContactIdToFields.keys {
            if accountId == accountIds[0] || accountId == accountIds[2] || accountId == accountIds[5] {
                checkDbDeleted(CONTACTS_SOUP, ids: Array(accountIdContactIdToFields[accountId]?.keys ?? [:].keys), idField: ID)
            } else {
                if let contactFields = accountIdContactIdToFields[accountId] {
                    checkDb(contactFields, soupName: CONTACTS_SOUP)
                }
            }
        }
    }

    /// Create accounts and contacts locally, sync up with merge mode OVERWRITE
    func testSyncUpWithLocallyCreatedRecords() {
        trySyncUpWithLocallyCreatedRecords(.overwrite)
    }

    /// Create accounts and contacts locally, sync up with merge mode LEAVE_IF_CHANGED
    func testSyncUpWithLocallyCreatedRecordsWithoutOverwrite() {
        trySyncUpWithLocallyCreatedRecords(.leaveIfChanged)
    }

    /// Create contacts on server, sync down, create accounts locally, update contacts to be associated, run sync up
    func testSyncUpWithLocallyCreatedParentRecords() {
        let contactIdToName = createRecords(onServer: 6, objectType: CONTACT_TYPE) ?? [:]

        let soql = "SELECT Id, LastName, LastModifiedDate FROM Contact WHERE Id IN \(buildInClause(Array(contactIdToName.keys)))"
        let contactSyncDownTarget = SFSoqlSyncDownTarget.newSyncTarget(soql)
        trySyncDown(.overwrite, target: contactSyncDownTarget, soupName: CONTACTS_SOUP, totalSize: UInt(contactIdToName.count), numberFetches: 1)

        let accountNames = [createAccountName(), createAccountName()]
        let localAccounts = createAccountsLocally(accountNames)

        var accountNameToServerId: [String: String] = [:]
        for localAccount in localAccounts as! [[String: Any]] {
            if let name = localAccount[NAME] as? String, let accountId = localAccount[ID] as? String {
                accountNameToServerId[name] = accountId
            }
        }

        var contactIdToAccountName: [String: String] = [:]
        var idToFieldsLocallyUpdated: [String: [String: Any]] = [:]
        var i = 0
        for contactId in contactIdToName.keys {
            var fieldsLocallyUpdated: [String: Any] = [:]
            let accountName = accountNames[i % accountNames.count]
            fieldsLocallyUpdated[ACCOUNT_ID] = accountNameToServerId[accountName]
            idToFieldsLocallyUpdated[contactId] = fieldsLocallyUpdated
            contactIdToAccountName[contactId] = accountName
            i += 1
        }
        updateRecordsLocally(idToFieldsLocallyUpdated, soupName: CONTACTS_SOUP)

        // Sync up
        let target = getAccountContactsSyncUpTarget()
        trySyncUp(accountNames.count, target: target, mergeMode: .overwrite)

        // Check accounts
        let accountIdToFieldsCreated = getIdToFieldsByName(ACCOUNTS_SOUP, fieldNames: [NAME, DESCRIPTION], nameField: NAME, names: accountNames)
        checkDbStateFlags(Array(accountIdToFieldsCreated.keys), soupName: ACCOUNTS_SOUP, expectedLocallyCreated: false, expectedLocallyUpdated: false, expectedLocallyDeleted: false)

        for accountId in accountIdToFieldsCreated.keys {
            if let name = accountIdToFieldsCreated[accountId]?[NAME] as? String {
                accountNameToServerId[name] = accountId
            }
        }

        checkServer(accountIdToFieldsCreated, objectType: ACCOUNT_TYPE)

        // Check contacts
        let contactIdToFieldsUpdated = getIdToFieldsByName(CONTACTS_SOUP, fieldNames: [LAST_NAME, ACCOUNT_ID], nameField: LAST_NAME, names: Array(contactIdToName.values))
        checkDbStateFlags(Array(contactIdToFieldsUpdated.keys), soupName: CONTACTS_SOUP, expectedLocallyCreated: false, expectedLocallyUpdated: false, expectedLocallyDeleted: false)

        for contactId in contactIdToFieldsUpdated.keys {
            if let accountName = contactIdToAccountName[contactId] {
                XCTAssertEqual(contactIdToFieldsUpdated[contactId]?[ACCOUNT_ID] as? String, accountNameToServerId[accountName])
            }
        }

        checkServer(contactIdToFieldsUpdated, objectType: CONTACT_TYPE)

        // Cleanup
        deleteRecordsOnServer(Array(accountIdToFieldsCreated.keys), objectType: ACCOUNT_TYPE)
        deleteRecordsOnServer(Array(contactIdToFieldsUpdated.keys), objectType: CONTACT_TYPE)
    }

    /// Create accounts on server, sync down, create contacts locally, sync up
    func testSyncUpWithLocallyCreatedChildrenRecords() {
        let accountIdToName = createRecords(onServer: 2, objectType: ACCOUNT_TYPE) ?? [:]
        let accountNames = Array(accountIdToName.values)

        let soql = "SELECT Id, Name, LastModifiedDate FROM Account WHERE Id IN \(buildInClause(Array(accountIdToName.keys)))"
        let accountSyncDownTarget = SFSoqlSyncDownTarget.newSyncTarget(soql)
        trySyncDown(.overwrite, target: accountSyncDownTarget, soupName: ACCOUNTS_SOUP, totalSize: UInt(accountIdToName.count), numberFetches: 1)

        let accountIdToFieldsCreated = getIdToFieldsByName(ACCOUNTS_SOUP, fieldNames: [NAME], nameField: NAME, names: accountNames)
        let contactsForAccountsLocally = createContactsForAccountLocally(3, accountIds: Array(accountIdToFieldsCreated.keys))
        var contactNames: [String] = []
        for contacts in contactsForAccountsLocally.values {
            for contact in contacts {
                if let lastName = contact[LAST_NAME] as? String {
                    contactNames.append(lastName)
                }
            }
        }

        // Sync up
        let target = getAccountContactsSyncUpTarget()
        trySyncUp(accountNames.count, target: target, mergeMode: .overwrite)

        // Check contacts
        let contactIdToFieldsCreated = getIdToFieldsByName(CONTACTS_SOUP, fieldNames: [LAST_NAME, ACCOUNT_ID], nameField: LAST_NAME, names: contactNames)
        checkDbStateFlags(Array(contactIdToFieldsCreated.keys), soupName: CONTACTS_SOUP, expectedLocallyCreated: false, expectedLocallyUpdated: false, expectedLocallyDeleted: false)

        checkServer(contactIdToFieldsCreated, objectType: CONTACT_TYPE)

        // Cleanup
        deleteRecordsOnServer(Array(accountIdToFieldsCreated.keys), objectType: ACCOUNT_TYPE)
        deleteRecordsOnServer(Array(contactIdToFieldsCreated.keys), objectType: CONTACT_TYPE)
    }

    /// Create account on server, sync down, remotely delete, create contacts locally, sync up
    func testSyncUpWithLocallyCreatedChildrenRemotelyDeletedParent() {
        let accountIdToName = createRecords(onServer: 1, objectType: ACCOUNT_TYPE) ?? [:]
        let accountId = Array(accountIdToName.keys)[0]
        let accountName = accountIdToName[accountId] ?? ""

        let soql = "SELECT Id, Name, LastModifiedDate FROM Account WHERE Id = '\(accountId)'"
        let accountSyncDownTarget = SFSoqlSyncDownTarget.newSyncTarget(soql)
        trySyncDown(.overwrite, target: accountSyncDownTarget, soupName: ACCOUNTS_SOUP, totalSize: 1, numberFetches: 1)

        let contactsForAccountsLocally = createContactsForAccountLocally(3, accountIds: [accountId])
        var contactNames: [String] = []
        for contacts in contactsForAccountsLocally.values {
            for contact in contacts {
                if let lastName = contact[LAST_NAME] as? String {
                    contactNames.append(lastName)
                }
            }
        }

        // Delete account remotely
        deleteRecordsOnServer([accountId], objectType: ACCOUNT_TYPE)

        // Sync up
        let target = getAccountContactsSyncUpTarget()
        trySyncUp(1, target: target, mergeMode: .overwrite)

        // Make sure account got recreated
        let newAccountId = checkRecordRecreated(accountId, fields: [NAME: accountName], nameField: NAME, soupName: ACCOUNTS_SOUP, objectType: ACCOUNT_TYPE, parentId: nil, parentIdField: nil)

        // Check contacts
        let contactIdToFieldsCreated = getIdToFieldsByName(CONTACTS_SOUP, fieldNames: [LAST_NAME, ACCOUNT_ID], nameField: LAST_NAME, names: contactNames)
        checkDbStateFlags(Array(contactIdToFieldsCreated.keys), soupName: CONTACTS_SOUP, expectedLocallyCreated: false, expectedLocallyUpdated: false, expectedLocallyDeleted: false)

        checkServer(contactIdToFieldsCreated, objectType: CONTACT_TYPE)

        for contactId in contactIdToFieldsCreated.keys {
            XCTAssertEqual(contactIdToFieldsCreated[contactId]?[ACCOUNT_ID] as? String, newAccountId)
        }

        // Cleanup
        deleteRecordsOnServer([newAccountId], objectType: ACCOUNT_TYPE)
        deleteRecordsOnServer(Array(contactIdToFieldsCreated.keys), objectType: CONTACT_TYPE)
    }

    // MARK: - Sync up with various changes tests

    func testSyncUpLocallyUpdatedChild() { trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .none, remoteChangeForAccount: .none, localChangeForContact: .update, remoteChangeForContact: .none) }
    func testSyncUpLocallyUpdatedChildRemotelyUpdatedChild() { trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .none, remoteChangeForAccount: .none, localChangeForContact: .update, remoteChangeForContact: .update) }
    func testSyncUpLocallyUpdatedChildRemotelyDeletedChild() { trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .none, remoteChangeForAccount: .none, localChangeForContact: .update, remoteChangeForContact: .delete) }
    func testSyncUpLocallyDeletedChild() { trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .none, remoteChangeForAccount: .none, localChangeForContact: .delete, remoteChangeForContact: .none) }
    func testSyncUpLocallyDeletedChildRemotelyUpdatedChild() { trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .none, remoteChangeForAccount: .none, localChangeForContact: .delete, remoteChangeForContact: .update) }
    func testSyncUpLocallyDeletedChildRemotelyDeletedChild() { trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .none, remoteChangeForAccount: .none, localChangeForContact: .delete, remoteChangeForContact: .delete) }
    func testSyncUpLocallyUpdatedParent() { trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .update, remoteChangeForAccount: .none, localChangeForContact: .none, remoteChangeForContact: .none) }
    func testSyncUpLocallyUpdatedParentRemotelyUpdatedParent() { trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .update, remoteChangeForAccount: .update, localChangeForContact: .none, remoteChangeForContact: .none) }
    func testSyncUpLocallyUpdatedParentRemotelyDeletedParent() { trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .update, remoteChangeForAccount: .delete, localChangeForContact: .none, remoteChangeForContact: .none) }
    func testSyncUpLocallyUpdatedParentUpdatedChild() { trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .update, remoteChangeForAccount: .none, localChangeForContact: .update, remoteChangeForContact: .none) }
    func testSyncUpLocallyUpdatedParentUpdatedChildRemotelyUpdatedChild() { trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .update, remoteChangeForAccount: .none, localChangeForContact: .update, remoteChangeForContact: .update) }
    func testSyncUpLocallyUpdatedParentUpdatedChildRemotelyDeletedChild() { trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .update, remoteChangeForAccount: .none, localChangeForContact: .update, remoteChangeForContact: .delete) }
    func testSyncUpLocallyUpdatedParentUpdatedChildRemotelyUpdatedParent() { trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .update, remoteChangeForAccount: .update, localChangeForContact: .update, remoteChangeForContact: .none) }
    func testSyncUpLocallyUpdatedParentUpdatedChildRemotelyUpdatedParentUpdatedChild() { trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .update, remoteChangeForAccount: .update, localChangeForContact: .update, remoteChangeForContact: .update) }
    func testSyncUpLocallyUpdatedParentUpdatedChildRemotelyUpdatedParentDeletedChild() { trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .update, remoteChangeForAccount: .update, localChangeForContact: .update, remoteChangeForContact: .delete) }
    func testSyncUpLocallyUpdatedParentUpdatedChildRemotelyDeletedParent() { trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .update, remoteChangeForAccount: .delete, localChangeForContact: .update, remoteChangeForContact: .none) }
    func testSyncUpLocallyUpdatedParentDeletedChild() { trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .update, remoteChangeForAccount: .none, localChangeForContact: .delete, remoteChangeForContact: .none) }
    func testSyncUpLocallyUpdatedParentDeletedChildRemotelyUpdatedChild() { trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .update, remoteChangeForAccount: .none, localChangeForContact: .delete, remoteChangeForContact: .update) }
    func testSyncUpLocallyUpdatedParentDeletedChildRemotelyDeletedChild() { trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .update, remoteChangeForAccount: .none, localChangeForContact: .delete, remoteChangeForContact: .delete) }
    func testSyncUpLocallyUpdatedParentDeletedChildRemotelyUpdatedParent() { trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .update, remoteChangeForAccount: .update, localChangeForContact: .delete, remoteChangeForContact: .none) }
    func testSyncUpLocallyUpdatedParentDeletedChildRemotelyUpdatedParentUpdatedChild() { trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .update, remoteChangeForAccount: .update, localChangeForContact: .delete, remoteChangeForContact: .update) }
    func testSyncUpLocallyUpdatedParentDeletedChildRemotelyUpdatedParentDeletedChild() { trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .update, remoteChangeForAccount: .update, localChangeForContact: .delete, remoteChangeForContact: .delete) }
    func testSyncUpLocallyUpdatedParentDeletedChildRemotelyDeletedParent() { trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .update, remoteChangeForAccount: .delete, localChangeForContact: .delete, remoteChangeForContact: .none) }
    func testSyncUpLocallyDeletedParent() { trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .delete, remoteChangeForAccount: .none, localChangeForContact: .none, remoteChangeForContact: .none) }
    func testSyncUpLocallyDeletedParentRemotelyUpdatedParent() { trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .delete, remoteChangeForAccount: .update, localChangeForContact: .none, remoteChangeForContact: .none) }
    func testSyncUpLocallyDeletedParentRemotelyDeletedParent() { trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .delete, remoteChangeForAccount: .delete, localChangeForContact: .none, remoteChangeForContact: .none) }
    func testSyncUpLocallyDeletedParentUpdatedChild() { trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .delete, remoteChangeForAccount: .none, localChangeForContact: .update, remoteChangeForContact: .none) }
    func testSyncUpLocallyDeletedParentUpdatedChildRemotelyUpdatedParent() { trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .delete, remoteChangeForAccount: .update, localChangeForContact: .update, remoteChangeForContact: .none) }
    func testSyncUpLocallyDeletedParentUpdatedChildRemotelyDeletedParent() { trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .delete, remoteChangeForAccount: .delete, localChangeForContact: .update, remoteChangeForContact: .none) }
    func testSyncUpLocallyDeletedParentDeletedChild() { trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .delete, remoteChangeForAccount: .none, localChangeForContact: .delete, remoteChangeForContact: .none) }
    func testSyncUpLocallyDeletedParentDeletedChildRemotelyUpdatedParent() { trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .delete, remoteChangeForAccount: .update, localChangeForContact: .delete, remoteChangeForContact: .none) }
    func testSyncUpLocallyDeletedParentDeletedChildRemotelyDeletedParent() { trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .delete, remoteChangeForAccount: .delete, localChangeForContact: .delete, remoteChangeForContact: .none) }
    func testSyncUpLocallyUpdatedParentNoChildren() { trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 0, localChangeForAccount: .update, remoteChangeForAccount: .none, localChangeForContact: .none, remoteChangeForContact: .none) }
    func testSyncUpLocallyUpdatedParentRemotelyUpdatedParentNoChildren() { trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 0, localChangeForAccount: .update, remoteChangeForAccount: .update, localChangeForContact: .none, remoteChangeForContact: .none) }
    func testSyncUpLocallyUpdatedParentRemotelyDeletedParentNoChildren() { trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 0, localChangeForAccount: .update, remoteChangeForAccount: .delete, localChangeForContact: .none, remoteChangeForContact: .none) }
    func testSyncUpLocallyDeletedParentNoChildren() { trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 0, localChangeForAccount: .delete, remoteChangeForAccount: .none, localChangeForContact: .none, remoteChangeForContact: .none) }
    func testSyncUpLocallyDeletedParentRemotelyUpdatedParentNoChildren() { trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 0, localChangeForAccount: .delete, remoteChangeForAccount: .update, localChangeForContact: .none, remoteChangeForContact: .none) }
    func testSyncUpLocallyDeletedParentRemotelyDeletedParentNoChildren() { trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 0, localChangeForAccount: .delete, remoteChangeForAccount: .delete, localChangeForContact: .none, remoteChangeForContact: .none) }

    /// Create accounts and contacts on server, sync down, update some with bad names, sync up, check errors
    func testSyncUpWithErrors() {
        createAccountsAndContactsOnServer(3, numberContactsPerAccount: 3)

        let syncTarget = getAccountContactsSyncDownTarget(parentSoqlFilter: "Id IN \(buildInClause(Array(accountIdContactIdToFields.keys)))")
        trySyncDown(.overwrite, target: syncTarget, soupName: ACCOUNTS_SOUP, totalSize: 3, numberFetches: 1)

        let accountIds = Array(accountIdToFields.keys)
        let account1Id = accountIds[0]
        let contactIdsOfAccount1 = Array((accountIdContactIdToFields[account1Id] ?? [:]).keys)
        let contact11Id = contactIdsOfAccount1[0]
        let contact12Id = contactIdsOfAccount1[1]

        let account2Id = accountIds[1]
        let contactIdsOfAccount2 = Array((accountIdContactIdToFields[account2Id] ?? [:]).keys)
        let contact21Id = contactIdsOfAccount2[0]
        let contact22Id = contactIdsOfAccount2[1]

        // Build long suffix
        var suffixTooLong = ""
        for _ in 0..<255 { suffixTooLong += "x" }

        // Updating with valid values
        let updatedAccount1Fields = updateRecordLocally(accountIdToFields[account1Id] ?? [:], idToUpdate: account1Id, soupName: ACCOUNTS_SOUP)[account1Id] ?? [:]
        let updatedContact11Fields = updateRecordLocally(accountIdContactIdToFields[account1Id]?[contact11Id] ?? [:], idToUpdate: contact11Id, soupName: CONTACTS_SOUP)[contact11Id] ?? [:]
        let updatedContact21Fields = updateRecordLocally(accountIdContactIdToFields[account2Id]?[contact22Id] ?? [:], idToUpdate: contact21Id, soupName: CONTACTS_SOUP)[contact21Id] ?? [:]

        // Updating with invalid values
        _ = updateRecordLocally(accountIdToFields[account2Id] ?? [:], idToUpdate: account2Id, soupName: ACCOUNTS_SOUP, suffix: suffixTooLong)
        _ = updateRecordLocally(accountIdContactIdToFields[account1Id]?[contact12Id] ?? [:], idToUpdate: contact12Id, soupName: CONTACTS_SOUP, suffix: suffixTooLong)
        _ = updateRecordLocally(accountIdContactIdToFields[account2Id]?[contact22Id] ?? [:], idToUpdate: contact22Id, soupName: CONTACTS_SOUP, suffix: suffixTooLong)

        // Sync up
        trySyncUp(2, target: getAccountContactsSyncUpTarget(), mergeMode: .overwrite)

        // Check valid records in db
        checkDbStateFlags([account1Id], soupName: ACCOUNTS_SOUP, expectedLocallyCreated: false, expectedLocallyUpdated: false, expectedLocallyDeleted: false)
        checkDbStateFlags([contact11Id, contact21Id], soupName: CONTACTS_SOUP, expectedLocallyCreated: false, expectedLocallyUpdated: false, expectedLocallyDeleted: false)

        // Check invalid records in db
        checkDbStateFlags([account2Id], soupName: ACCOUNTS_SOUP, expectedLocallyCreated: false, expectedLocallyUpdated: true, expectedLocallyDeleted: false)
        checkDbStateFlags([contact12Id, contact22Id], soupName: CONTACTS_SOUP, expectedLocallyCreated: false, expectedLocallyUpdated: true, expectedLocallyDeleted: false)

        // Should have populated last error fields
        checkDbLastErrorField([account2Id], soupName: ACCOUNTS_SOUP, lastErrorSubString: "Account Name: data value too large")
        checkDbLastErrorField([contact12Id, contact22Id], soupName: CONTACTS_SOUP, lastErrorSubString: "Last Name: data value too large")

        // Check server
        var accountIdToFieldsExpectedOnServer: [String: [String: Any]] = [:]
        for id in accountIds {
            if id == account1Id {
                accountIdToFieldsExpectedOnServer[id] = updatedAccount1Fields
            } else {
                accountIdToFieldsExpectedOnServer[id] = accountIdToFields[id]
            }
        }
        checkServer(accountIdToFieldsExpectedOnServer, objectType: ACCOUNT_TYPE)

        var contactIdToFieldsExpectedOnServer: [String: [String: Any]] = [:]
        for id in accountIds {
            guard let contactIdToFields = accountIdContactIdToFields[id] else { continue }
            for cid in contactIdToFields.keys {
                if cid == contact11Id {
                    contactIdToFieldsExpectedOnServer[cid] = updatedContact11Fields
                } else if cid == contact21Id {
                    contactIdToFieldsExpectedOnServer[cid] = updatedContact21Fields
                } else {
                    contactIdToFieldsExpectedOnServer[cid] = contactIdToFields[cid]
                }
            }
        }
        checkServer(contactIdToFieldsExpectedOnServer, objectType: CONTACT_TYPE)
    }

    /// Sync up with external id
    func testParentChildrenSyncUpWithExternalId() {
        let externalIdFieldName = "Id"

        createAccountsAndContactsOnServer(3, numberContactsPerAccount: 1)

        let accountIds = Array(accountIdToFields.keys)
        let accountId0 = accountIds[0]
        let accountId1 = accountIds[1]
        let accountId2 = accountIds[2]

        let originalAccountName2 = accountIdToFields[accountId2]?[NAME] as? String ?? ""

        let contactId0 = Array((accountIdContactIdToFields[accountId0] ?? [:]).keys)[0]
        let contactId1 = Array((accountIdContactIdToFields[accountId1] ?? [:]).keys)[0]
        let contactId2 = Array((accountIdContactIdToFields[accountId2] ?? [:]).keys)[0]

        let originalContactName0 = accountIdContactIdToFields[accountId0]?[contactId0]?[LAST_NAME] as? String ?? ""

        // Create accounts and contacts locally
        let localResult = createAccountsAndContactsLocally([createAccountName(), createAccountName(), createAccountName()], numberOfContactsPerAccount: 1)
        var localAccounts = localResult.accounts
        var localContacts: [[String: Any]] = []
        for account in localAccounts {
            if let accountId = account[ID] as? String,
               let contacts = localResult.accountIdToContacts[accountId],
               let first = contacts.first {
                localContacts.append(first)
            }
        }

        let accountName0 = localAccounts[0][NAME] as? String ?? ""
        let accountName1 = localAccounts[1][NAME] as? String ?? ""
        let accountName2 = localAccounts[2][NAME] as? String ?? ""

        let contactName0 = localContacts[0][LAST_NAME] as? String ?? ""
        let contactName1 = localContacts[1][LAST_NAME] as? String ?? ""
        let contactName2 = localContacts[2][LAST_NAME] as? String ?? ""

        // Update Id field to match existing id for account 0 and 1
        localAccounts[0][externalIdFieldName] = accountId0
        localAccounts[1][externalIdFieldName] = accountId1
        _ = store.upsert(entries: localAccounts as! [[String: Any]], forSoupNamed: ACCOUNTS_SOUP)

        // Update Id field to match existing id for contact 1 and 2
        localContacts[0][ACCOUNT_ID] = accountId0
        localContacts[1][externalIdFieldName] = contactId1
        localContacts[1][ACCOUNT_ID] = accountId1
        localContacts[2][externalIdFieldName] = contactId2
        _ = store.upsert(entries: localContacts as! [[String: Any]], forSoupNamed: CONTACTS_SOUP)

        // Sync up
        trySyncUp(3,
                  target: getAccountContactsSyncUpTarget(accountModificationDateFieldName: LAST_MODIFIED_DATE,
                                                        contactModificationDateFieldName: LAST_MODIFIED_DATE,
                                                        accountExternalIdFieldName: externalIdFieldName,
                                                        contactExternalIdFieldName: externalIdFieldName),
                  mergeMode: .overwrite)

        // Getting id for third account upserted
        let newAccountId = Array(getIdToFieldsByName(ACCOUNTS_SOUP, fieldNames: [], nameField: NAME, names: [accountName2]).keys)[0]

        // Getting id for first contact upserted
        let newContactId = Array(getIdToFieldsByName(CONTACTS_SOUP, fieldNames: [], nameField: LAST_NAME, names: [contactName0]).keys)[0]

        // Expected accounts
        var expectedAccountsDbIdToFields: [String: [String: Any]] = [:]
        expectedAccountsDbIdToFields[accountId0] = [NAME: accountName0]
        expectedAccountsDbIdToFields[accountId1] = [NAME: accountName1]
        expectedAccountsDbIdToFields[newAccountId] = [NAME: accountName2]

        checkDbStateFlags(Array(expectedAccountsDbIdToFields.keys), soupName: ACCOUNTS_SOUP, expectedLocallyCreated: false, expectedLocallyUpdated: false, expectedLocallyDeleted: false)
        checkDb(expectedAccountsDbIdToFields, soupName: ACCOUNTS_SOUP)

        // Expected contacts
        var expectedContactsDbIdToFields: [String: [String: Any]] = [:]
        expectedContactsDbIdToFields[newContactId] = [LAST_NAME: contactName0]
        expectedContactsDbIdToFields[contactId1] = [LAST_NAME: contactName1]
        expectedContactsDbIdToFields[contactId2] = [LAST_NAME: contactName2]

        checkDbStateFlags(Array(expectedContactsDbIdToFields.keys), soupName: CONTACTS_SOUP, expectedLocallyCreated: false, expectedLocallyUpdated: false, expectedLocallyDeleted: false)
        checkDb(expectedContactsDbIdToFields, soupName: CONTACTS_SOUP)

        // Expected accounts on server
        var expectedAccountsServerIdToFields: [String: [String: Any]] = [:]
        expectedAccountsServerIdToFields[accountId0] = [NAME: accountName0]
        expectedAccountsServerIdToFields[accountId1] = [NAME: accountName1]
        expectedAccountsServerIdToFields[accountId2] = [NAME: originalAccountName2]
        expectedAccountsServerIdToFields[newAccountId] = [NAME: accountName2]

        checkServer(expectedAccountsServerIdToFields, objectType: ACCOUNT_TYPE)

        // Expected contacts on server
        var expectedContactsServerIdToFields: [String: [String: Any]] = [:]
        expectedContactsServerIdToFields[newContactId] = [LAST_NAME: contactName0]
        expectedContactsServerIdToFields[contactId0] = [LAST_NAME: originalContactName0]
        expectedContactsServerIdToFields[contactId1] = [LAST_NAME: contactName1]
        expectedContactsServerIdToFields[contactId2] = [LAST_NAME: contactName2]

        checkServer(expectedContactsServerIdToFields, objectType: CONTACT_TYPE)

        // Cleanup
        deleteRecordsOnServer([newAccountId], objectType: ACCOUNT_TYPE)
        deleteRecordsOnServer([newContactId], objectType: CONTACT_TYPE)
    }

    // MARK: - Helper methods

    private func createTestData() {
        createAccountsSoup()
        createContactsSoup()
    }

    private func deleteTestData() {
        dropAccountsSoup()
        dropContactsSoup()

        if !accountIdToFields.isEmpty {
            deleteRecordsOnServer(Array(accountIdToFields.keys), objectType: ACCOUNT_TYPE)
            accountIdToFields = [:]
        }

        if !accountIdContactIdToFields.isEmpty {
            for accountId in accountIdContactIdToFields.keys {
                if let contactIdToFields = accountIdContactIdToFields[accountId] {
                    deleteRecordsOnServer(Array(contactIdToFields.keys), objectType: CONTACT_TYPE)
                }
            }
            accountIdContactIdToFields = [:]
        }
    }

    /// Returns (createdAccounts, accountIdToContacts) where createdAccounts is the array of created account dicts
    /// and accountIdToContacts maps accountId -> array of contact dicts
    private func createAccountsAndContactsLocally(_ names: [String], numberOfContactsPerAccount: UInt) -> (accounts: [[String: Any]], accountIdToContacts: [String: [[String: Any]]]) {
        var accounts: [[String: Any]] = []
        var accountIds: [String] = []
        let attributes: [String: Any] = [TYPE: ACCOUNT_TYPE]
        for name in names {
            let account: [String: Any] = [
                ID: SFSyncTarget.createLocalId(),
                NAME: name,
                DESCRIPTION: [DESCRIPTION, name].joined(separator: "_"),
                ATTRIBUTES: attributes,
                kSyncTargetLocal: true,
                kSyncTargetLocallyCreated: true,
                kSyncTargetLocallyUpdated: false,
                kSyncTargetLocallyDeleted: false
            ]
            accounts.append(account)
            if let accountId = account[ID] as? String {
                accountIds.append(accountId)
            }
        }
        let createdAccounts = store.upsert(entries: accounts, forSoupNamed: ACCOUNTS_SOUP)

        let accountIdsToContacts = createContactsForAccountLocally(numberOfContactsPerAccount, accountIds: accountIds)
        return (accounts: createdAccounts, accountIdToContacts: accountIdsToContacts)
    }

    private func createContactsForAccountLocally(_ numberOfContactsPerAccount: UInt, accountIds: [String]) -> [String: [[String: Any]]] {
        var accountIdsToContacts: [String: [[String: Any]]] = [:]
        let attributes: [String: Any] = [TYPE: ACCOUNT_TYPE]
        for accountId in accountIds {
            var contacts: [[String: Any]] = []
            for _ in 0..<numberOfContactsPerAccount {
                let contact: [String: Any] = [
                    ID: SFSyncTarget.createLocalId(),
                    LAST_NAME: createRecordName(CONTACT_TYPE),
                    ATTRIBUTES: attributes,
                    ACCOUNT_ID: accountId,
                    kSyncTargetLocal: true,
                    kSyncTargetLocallyCreated: true,
                    kSyncTargetLocallyUpdated: false,
                    kSyncTargetLocallyDeleted: false
                ]
                contacts.append(contact)
            }
            accountIdsToContacts[accountId] = store.upsert(entries: contacts, forSoupNamed: CONTACTS_SOUP)
        }
        return accountIdsToContacts
    }

    private func tryGetDirtyRecordIds(_ expectedRecords: [[String: Any]]) {
        let target = getAccountContactsSyncDownTarget()
        let dirtyRecordIds = target.getDirtyRecordIds(self.syncManager, soupName: ACCOUNTS_SOUP, idField: ID)
        XCTAssertEqual(dirtyRecordIds.count, expectedRecords.count)
        for expectedRecord in expectedRecords {
            if let recordId = expectedRecord[ID] as? String {
                XCTAssertTrue(dirtyRecordIds.contains(recordId))
            }
        }
    }

    private func tryGetNonDirtyRecordIds(_ expectedRecords: [[String: Any]]) {
        let target = getAccountContactsSyncDownTarget()
        let nonDirtyRecordIds = target.getNonDirtyRecordIds(self.syncManager, soupName: ACCOUNTS_SOUP, idField: ID, additionalPredicate: "")
        XCTAssertEqual(nonDirtyRecordIds.count, expectedRecords.count)
        for expectedRecord in expectedRecords {
            if let recordId = expectedRecord[ID] as? String {
                XCTAssertTrue(nonDirtyRecordIds.contains(recordId))
            }
        }
    }

    private func cleanRecords(_ soupName: String, records: [[String: Any]]) {
        var cleanRecords: [[String: Any]] = []
        for record in records {
            var mutableRecord = record
            mutableRecord[kSyncTargetLocal] = false
            mutableRecord[kSyncTargetLocallyCreated] = false
            mutableRecord[kSyncTargetLocallyUpdated] = false
            mutableRecord[kSyncTargetLocallyDeleted] = false
            cleanRecords.append(mutableRecord)
        }
        _ = store.upsert(entries: cleanRecords as! [[String: Any]], forSoupNamed: soupName)
    }

    private func cleanRecord(_ soupName: String, record: [String: Any]) {
        cleanRecords(soupName, records: [record])
    }

    private func getAccountContactsSyncDownTarget() -> SFParentChildrenSyncDownTarget {
        return getAccountContactsSyncDownTarget(parentSoqlFilter: "")
    }

    private func getAccountContactsSyncDownTarget(parentSoqlFilter: String) -> SFParentChildrenSyncDownTarget {
        return getAccountContactsSyncDownTarget(accountModificationDateFieldName: LAST_MODIFIED_DATE, contactModificationDateFieldName: LAST_MODIFIED_DATE, parentSoqlFilter: parentSoqlFilter)
    }

    private func getAccountContactsSyncDownTarget(accountModificationDateFieldName: String, contactModificationDateFieldName: String, parentSoqlFilter: String?) -> SFParentChildrenSyncDownTarget {
        return SFParentChildrenSyncDownTarget.newSyncTarget(
            parentInfo: SFParentInfo.new(withSObjectType: ACCOUNT_TYPE, soupName: ACCOUNTS_SOUP, idFieldName: ID, modificationDateFieldName: accountModificationDateFieldName),
            parentFieldlist: [ID, NAME, DESCRIPTION],
            parentSoqlFilter: parentSoqlFilter ?? "",
            childrenInfo: SFChildrenInfo.new(withSObjectType: CONTACT_TYPE, sobjectTypePlural: CONTACT_TYPE_PLURAL, soupName: CONTACTS_SOUP, parentIdFieldName: ACCOUNT_ID, idFieldName: ID, modificationDateFieldName: contactModificationDateFieldName),
            childrenFieldlist: [LAST_NAME, ACCOUNT_ID],
            relationshipType: .masterDetail)
    }

    private func queryWithInClause(_ soupName: String, fieldName: String, values: [String], orderBy: String?) -> [[String: Any]] {
        let orderClause = orderBy != nil ? " ORDER BY {\(soupName):\(orderBy ?? "")} ASC" : ""
        let sql = "SELECT {\(soupName):_soup} FROM {\(soupName)} WHERE {\(soupName):\(fieldName)} IN \(buildInClause(values))\(orderClause)"

        guard let querySpec = QuerySpec.buildSmartQuerySpec(smartSql: sql, pageSize: UInt(INT_MAX)) else { return [] }
        guard let rows = try? store.query(using: querySpec, startingFromPageIndex: 0) as? [[Any]] else { return [] }
        var result: [[String: Any]] = []
        for row in rows {
            if let dict = row.first as? [String: Any] {
                result.append(dict)
            }
        }
        return result
    }

    private func createAccountsAndContactsOnServer(_ numberAccounts: UInt, numberContactsPerAccount: UInt) {
        accountIdToFields = [:]
        accountIdContactIdToFields = [:]

        var refIdToFields: [String: [String: Any]] = [:]
        var accountTrees: [SObjectTree] = []
        let listAccountFields = buildFieldsMapForRecords(numberAccounts, objectType: ACCOUNT_TYPE, additionalFields: nil)

        for i in 0..<listAccountFields.count {
            let listContactFields = buildFieldsMapForRecords(numberContactsPerAccount, objectType: CONTACT_TYPE, additionalFields: nil)

            let refIdAccount = "refAccount_\(i)"
            let accountFields = listAccountFields[i]
            refIdToFields[refIdAccount] = accountFields

            var contactTrees: [SObjectTree] = []
            for j in 0..<listContactFields.count {
                let refIdContact = "\(refIdAccount)__refContact_\(j)"
                let contactFields = listContactFields[j]
                refIdToFields[refIdContact] = contactFields
                if let tree = SObjectTree(objectType: CONTACT_TYPE, objectTypePlural: CONTACT_TYPE_PLURAL, referenceId: refIdContact, fields: contactFields, childrenTrees: nil) {
                    contactTrees.append(tree)
                }
            }
            if let tree = SObjectTree(objectType: ACCOUNT_TYPE, objectTypePlural: nil, referenceId: refIdAccount, fields: accountFields, childrenTrees: contactTrees) {
                accountTrees.append(tree)
            }
        }

        let request = RestClient.sharedInstance.requestForSObjectTree(ACCOUNT_TYPE, objectTrees: accountTrees, apiVersion: nil)

        // Send request
        guard let response = sendSyncRequest(request) else {
            XCTFail("Failed to get response for SObject tree request")
            return
        }

        // Parse response
        var refIdToId: [String: String] = [:]
        if let results = response["results"] as? [[String: Any]] {
            for result in results {
                if let refId = result["referenceId"] as? String, let id = result["id"] as? String {
                    refIdToId[refId] = id
                }
            }
        }

        // Populate accountIdToFields and accountIdContactIdToFields
        for refId in refIdToId.keys {
            guard let fields = refIdToFields[refId] else { continue }
            let parts = refId.components(separatedBy: "__")
            guard let accountId = refIdToId[parts[0]] else { continue }
            let contactId: String? = parts.count > 1 ? refIdToId[refId] : nil

            if contactId == nil {
                accountIdToFields[accountId] = fields
            } else {
                if accountIdContactIdToFields[accountId] == nil {
                    accountIdContactIdToFields[accountId] = [:]
                }
                accountIdContactIdToFields[accountId]?[contactId ?? ""] = fields
            }
        }
    }

    /// Helper for various sync up tests
    private func trySyncUpsWithVariousChanges(numberAccounts: UInt, numberContactsPerAccount: UInt, localChangeForAccount: SyncUpChange, remoteChangeForAccount: SyncUpChange, localChangeForContact: SyncUpChange, remoteChangeForContact: SyncUpChange) {
        // Creating test accounts and contacts on server
        createAccountsAndContactsOnServer(numberAccounts, numberContactsPerAccount: numberContactsPerAccount)

        // Sync down
        let parentSoqlFilter = "\(ID) IN \(buildInClause(Array(accountIdToFields.keys)))"
        let syncDownTarget = getAccountContactsSyncDownTarget(parentSoqlFilter: parentSoqlFilter)
        trySyncDown(.overwrite, target: syncDownTarget, soupName: ACCOUNTS_SOUP, totalSize: UInt(numberAccounts), numberFetches: 1)

        // Pick an account and contact
        let accountIds = Array(accountIdToFields.keys)
        let accountId = accountIds[0]
        let accountFields = accountIdToFields[accountId] ?? [:]

        let contactIdsOfAccount: [String]? = numberContactsPerAccount > 0 ? Array((accountIdContactIdToFields[accountId] ?? [:]).keys) : nil
        let contactId: String? = contactIdsOfAccount?.first
        let otherContactId: String? = contactIdsOfAccount != nil && contactIdsOfAccount!.count > 1 ? contactIdsOfAccount![1] : nil
        let contactFields: [String: Any]? = contactId != nil ? accountIdContactIdToFields[accountId]?[contactId ?? ""] : nil

        // Build sync up target
        let syncUpTarget = getAccountContactsSyncUpTarget()

        // Apply localChangeForAccount
        var localUpdatesAccount: [String: [String: Any]]?
        switch localChangeForAccount {
        case .none: break
        case .update:
            localUpdatesAccount = updateRecordLocally(accountFields, idToUpdate: accountId, soupName: ACCOUNTS_SOUP)
        case .delete:
            deleteRecordsLocally([accountId], soupName: ACCOUNTS_SOUP)
        }

        // Apply localChangeForContact
        var localUpdatesContact: [String: [String: Any]]?
        if let cId = contactId, let cFields = contactFields {
            switch localChangeForContact {
            case .none: break
            case .update:
                localUpdatesContact = updateRecordLocally(cFields, idToUpdate: cId, soupName: CONTACTS_SOUP)
            case .delete:
                deleteRecordsLocally([cId], soupName: CONTACTS_SOUP)
            }
        }

        // Apply remoteChangeForAccount
        var remoteUpdatesAccount: [String: [String: Any]]?
        switch remoteChangeForAccount {
        case .none: break
        case .update:
            remoteUpdatesAccount = updateRecordOnServer(accountFields, idToUpdate: accountId, objectType: ACCOUNT_TYPE)
        case .delete:
            deleteRecordsOnServer([accountId], objectType: ACCOUNT_TYPE)
        }

        // Apply remoteChangeForContact
        var remoteUpdatesContact: [String: [String: Any]]?
        if let cId = contactId, let cFields = contactFields {
            switch remoteChangeForContact {
            case .none: break
            case .update:
                remoteUpdatesContact = updateRecordOnServer(cFields, idToUpdate: cId, objectType: CONTACT_TYPE)
            case .delete:
                deleteRecordsOnServer([cId], objectType: CONTACT_TYPE)
            }
        }

        // Sync up
        let leaveIfChangedWillSucceed = (remoteChangeForAccount == .none || (remoteChangeForAccount == .delete && localChangeForAccount == .delete))
            && (remoteChangeForContact == .none || (remoteChangeForContact == .delete && localChangeForContact == .delete))

        if leaveIfChangedWillSucceed {
            trySyncUp(1, target: syncUpTarget, mergeMode: .leaveIfChanged)
            checkDbAndServerAfterCompletedSyncUp(accountId: accountId, contactId: contactId, otherContactId: otherContactId, localChangeForAccount: localChangeForAccount, remoteChangeForAccount: remoteChangeForAccount, localChangeForContact: localChangeForContact, remoteChangeForContact: remoteChangeForContact, localUpdatesAccount: localUpdatesAccount, localUpdatesContact: localUpdatesContact)
            trySyncUp(0, target: syncUpTarget, mergeMode: .overwrite)
        } else {
            trySyncUp(1, target: syncUpTarget, mergeMode: .leaveIfChanged)
            checkDbAndServerAfterBlockedSyncUp(accountId: accountId, contactId: contactId, localChangeForAccount: localChangeForAccount, remoteChangeForAccount: remoteChangeForAccount, localChangeForContact: localChangeForContact, remoteChangeForContact: remoteChangeForContact, localUpdatesAccount: localUpdatesAccount, remoteUpdatesAccount: remoteUpdatesAccount, localUpdatesContact: localUpdatesContact, remoteUpdatesContact: remoteUpdatesContact)
            trySyncUp(1, target: syncUpTarget, mergeMode: .overwrite)
            checkDbAndServerAfterCompletedSyncUp(accountId: accountId, contactId: contactId, otherContactId: otherContactId, localChangeForAccount: localChangeForAccount, remoteChangeForAccount: remoteChangeForAccount, localChangeForContact: localChangeForContact, remoteChangeForContact: remoteChangeForContact, localUpdatesAccount: localUpdatesAccount, localUpdatesContact: localUpdatesContact)
        }
    }

    private func checkDbAndServerAfterBlockedSyncUp(accountId: String, contactId: String?, localChangeForAccount: SyncUpChange, remoteChangeForAccount: SyncUpChange, localChangeForContact: SyncUpChange, remoteChangeForContact: SyncUpChange, localUpdatesAccount: [String: [String: Any]]?, remoteUpdatesAccount: [String: [String: Any]]?, localUpdatesContact: [String: [String: Any]]?, remoteUpdatesContact: [String: [String: Any]]?) {
        // Check parent
        if localChangeForAccount == .update, let updates = localUpdatesAccount {
            checkDb(updates, soupName: ACCOUNTS_SOUP)
        }
        checkDbStateFlags([accountId], soupName: ACCOUNTS_SOUP, expectedLocallyCreated: false, expectedLocallyUpdated: localChangeForAccount == .update, expectedLocallyDeleted: localChangeForAccount == .delete)

        switch remoteChangeForAccount {
        case .none: break
        case .update:
            if let updates = remoteUpdatesAccount { checkServer(updates, objectType: ACCOUNT_TYPE) }
        case .delete:
            checkServerDeleted([accountId], objectType: ACCOUNT_TYPE)
        }

        // Check children if any
        if let cId = contactId {
            let contactIdsOfAccounts = Array((accountIdContactIdToFields[accountId] ?? [:]).keys)

            if localChangeForContact == .update, let updates = localUpdatesContact {
                checkDb(updates, soupName: CONTACTS_SOUP)
            }
            checkDbStateFlags([cId], soupName: CONTACTS_SOUP, expectedLocallyCreated: false, expectedLocallyUpdated: localChangeForContact == .update, expectedLocallyDeleted: localChangeForContact == .delete)
            checkDbRelationships(childrenIds: contactIdsOfAccounts, expectedParentId: accountId, soupName: CONTACTS_SOUP, idFieldName: ID, parentIdFieldName: ACCOUNT_ID)

            if remoteChangeForAccount == .delete {
                checkServerDeleted(contactIdsOfAccounts, objectType: CONTACT_TYPE)
            } else {
                switch remoteChangeForContact {
                case .none: break
                case .update:
                    if let updates = remoteUpdatesContact { checkServer(updates, objectType: CONTACT_TYPE) }
                case .delete:
                    checkServerDeleted([cId], objectType: CONTACT_TYPE)
                }
            }
        }
    }

    private func checkDbAndServerAfterCompletedSyncUp(accountId: String, contactId: String?, otherContactId: String?, localChangeForAccount: SyncUpChange, remoteChangeForAccount: SyncUpChange, localChangeForContact: SyncUpChange, remoteChangeForContact: SyncUpChange, localUpdatesAccount: [String: [String: Any]]?, localUpdatesContact: [String: [String: Any]]?) {
        var newAccountId: String?
        var newContactId: String?
        var newOtherContactId: String?

        // Check parent
        switch localChangeForAccount {
        case .none:
            checkRecordAfterSync(accountId, fields: accountIdToFields[accountId] ?? [:], soupName: ACCOUNTS_SOUP, objectType: ACCOUNT_TYPE, parentId: nil, parentIdField: nil)
        case .update:
            if remoteChangeForAccount == .delete {
                newAccountId = checkRecordRecreated(accountId, fields: localUpdatesAccount?[accountId] ?? [:], nameField: NAME, soupName: ACCOUNTS_SOUP, objectType: ACCOUNT_TYPE, parentId: nil, parentIdField: nil)
            } else {
                checkRecordAfterSync(accountId, fields: localUpdatesAccount?[accountId] ?? [:], soupName: ACCOUNTS_SOUP, objectType: ACCOUNT_TYPE, parentId: nil, parentIdField: nil)
            }
        case .delete:
            checkDeletedRecordAfterSync(accountId, soupName: ACCOUNTS_SOUP, objectType: ACCOUNT_TYPE)
        }

        // Check children if any
        if let cId = contactId {
            if localChangeForAccount == .delete {
                let contactIdsOfAccount = Array((accountIdContactIdToFields[accountId] ?? [:]).keys)
                checkDbDeleted(CONTACTS_SOUP, ids: contactIdsOfAccount, idField: ID)
                checkServerDeleted(contactIdsOfAccount, objectType: CONTACT_TYPE)
            } else {
                switch localChangeForContact {
                case .none:
                    if remoteChangeForAccount == .delete || remoteChangeForContact == .delete {
                        newContactId = checkRecordRecreated(cId, fields: accountIdContactIdToFields[accountId]?[cId] ?? [:], nameField: LAST_NAME, soupName: CONTACTS_SOUP, objectType: CONTACT_TYPE, parentId: newAccountId ?? accountId, parentIdField: ACCOUNT_ID)
                    } else {
                        checkRecordAfterSync(cId, fields: accountIdContactIdToFields[accountId]?[cId] ?? [:], soupName: CONTACTS_SOUP, objectType: CONTACT_TYPE, parentId: accountId, parentIdField: ACCOUNT_ID)
                    }
                case .update:
                    if remoteChangeForAccount == .delete || remoteChangeForContact == .delete {
                        newContactId = checkRecordRecreated(cId, fields: localUpdatesContact?[cId] ?? [:], nameField: LAST_NAME, soupName: CONTACTS_SOUP, objectType: CONTACT_TYPE, parentId: newAccountId ?? accountId, parentIdField: ACCOUNT_ID)
                    } else {
                        checkRecordAfterSync(cId, fields: localUpdatesContact?[cId] ?? [:], soupName: CONTACTS_SOUP, objectType: CONTACT_TYPE, parentId: accountId, parentIdField: ACCOUNT_ID)
                    }
                case .delete:
                    checkDeletedRecordAfterSync(cId, soupName: CONTACTS_SOUP, objectType: CONTACT_TYPE)
                }

                if remoteChangeForAccount == .delete, let otherId = otherContactId {
                    newOtherContactId = checkRecordRecreated(otherId, fields: accountIdContactIdToFields[accountId]?[otherId] ?? [:], nameField: LAST_NAME, soupName: CONTACTS_SOUP, objectType: CONTACT_TYPE, parentId: newAccountId ?? "", parentIdField: ACCOUNT_ID)
                }
            }
        }

        // Cleaning "recreated" records
        if let id = newAccountId { deleteRecordsOnServer([id], objectType: ACCOUNT_TYPE) }
        if let id = newContactId { deleteRecordsOnServer([id], objectType: CONTACT_TYPE) }
        if let id = newOtherContactId { deleteRecordsOnServer([id], objectType: CONTACT_TYPE) }
    }

    @discardableResult
    private func checkRecordRecreated(_ recordId: String, fields: [String: Any], nameField: String, soupName: String, objectType: String, parentId: String?, parentIdField: String?) -> String {
        guard let updatedName = fields[nameField] as? String else {
            XCTFail("Name field should exist")
            return ""
        }
        let newIdToFields = getIdToFieldsByName(soupName, fieldNames: [nameField], nameField: nameField, names: [updatedName])
        guard let newRecordId = newIdToFields.keys.first else {
            XCTFail("Should find recreated record")
            return ""
        }

        XCTAssertNotEqual(newRecordId, recordId, "Record should have new id")

        checkDbDeleted(soupName, ids: [recordId], idField: ID)
        checkServerDeleted([recordId], objectType: objectType)

        checkRecordAfterSync(newRecordId, fields: newIdToFields[newRecordId] ?? [:], soupName: soupName, objectType: objectType, parentId: parentId, parentIdField: parentIdField)

        return newRecordId
    }

    private func checkRecordAfterSync(_ recordId: String, fields: [String: Any], soupName: String, objectType: String, parentId: String?, parentIdField: String?) {
        checkDbStateFlags([recordId], soupName: soupName, expectedLocallyCreated: false, expectedLocallyUpdated: false, expectedLocallyDeleted: false)

        var fieldsCopy = fields
        if let parentId = parentId, let parentIdField = parentIdField {
            fieldsCopy[parentIdField] = parentId
        }
        var idToFields: [String: [String: Any]] = [:]
        idToFields[recordId] = fieldsCopy

        checkDb(idToFields, soupName: soupName)
        checkServer(idToFields, objectType: objectType)
    }

    private func checkDeletedRecordAfterSync(_ recordId: String, soupName: String, objectType: String) {
        checkDbDeleted(soupName, ids: [recordId], idField: ID)
        checkServerDeleted([recordId], objectType: objectType)
    }

    /// Helper method for testSyncUpWithLocallyCreatedRecords
    private func trySyncUpWithLocallyCreatedRecords(_ mergeMode: SFSyncStateMergeMode) {
        let numberContactsPerAccount: UInt = 3

        let accountNames = [
            createAccountName(),
            createAccountName(),
            createAccountName(),
            createAccountName(),
            createAccountName()
        ]

        let locallyCreatedResult = createAccountsAndContactsLocally(accountNames, numberOfContactsPerAccount: numberContactsPerAccount)
        var contactNames: [String] = []
        for contacts in locallyCreatedResult.accountIdToContacts.values {
            for contact in contacts {
                if let lastName = contact[LAST_NAME] as? String {
                    contactNames.append(lastName)
                }
            }
        }

        // Sync up
        let target = getAccountContactsSyncUpTarget()
        trySyncUp(accountNames.count, target: target, mergeMode: mergeMode)

        // Check accounts
        let accountIdToFieldsCreated = getIdToFieldsByName(ACCOUNTS_SOUP, fieldNames: [NAME, DESCRIPTION], nameField: NAME, names: accountNames)
        checkDbStateFlags(Array(accountIdToFieldsCreated.keys), soupName: ACCOUNTS_SOUP, expectedLocallyCreated: false, expectedLocallyUpdated: false, expectedLocallyDeleted: false)
        checkServer(accountIdToFieldsCreated, objectType: ACCOUNT_TYPE)

        // Check contacts
        let contactIdToFieldsCreated = getIdToFieldsByName(CONTACTS_SOUP, fieldNames: [LAST_NAME, ACCOUNT_ID], nameField: LAST_NAME, names: contactNames)
        checkDbStateFlags(Array(contactIdToFieldsCreated.keys), soupName: CONTACTS_SOUP, expectedLocallyCreated: false, expectedLocallyUpdated: false, expectedLocallyDeleted: false)
        checkServer(contactIdToFieldsCreated, objectType: CONTACT_TYPE)

        // Cleanup
        deleteRecordsOnServer(Array(accountIdToFieldsCreated.keys), objectType: ACCOUNT_TYPE)
        deleteRecordsOnServer(Array(contactIdToFieldsCreated.keys), objectType: CONTACT_TYPE)
    }

    private func getAccountContactsSyncUpTarget() -> SFParentChildrenSyncUpTarget {
        return getAccountContactsSyncUpTarget(accountModificationDateFieldName: LAST_MODIFIED_DATE, contactModificationDateFieldName: LAST_MODIFIED_DATE, accountExternalIdFieldName: nil, contactExternalIdFieldName: nil)
    }

    private func getAccountContactsSyncUpTarget(accountModificationDateFieldName: String, contactModificationDateFieldName: String, accountExternalIdFieldName: String?, contactExternalIdFieldName: String?) -> SFParentChildrenSyncUpTarget {
        return SFParentChildrenSyncUpTarget.newSyncTarget(
            parentInfo: SFParentInfo.new(withSObjectType: ACCOUNT_TYPE, soupName: ACCOUNTS_SOUP, idFieldName: ID, modificationDateFieldName: accountModificationDateFieldName, externalIdFieldName: accountExternalIdFieldName),
            parentCreateFieldlist: [ID, NAME, DESCRIPTION],
            parentUpdateFieldlist: [NAME, DESCRIPTION],
            childrenInfo: SFChildrenInfo.new(withSObjectType: CONTACT_TYPE, sobjectTypePlural: CONTACT_TYPE_PLURAL, soupName: CONTACTS_SOUP, parentIdFieldName: ACCOUNT_ID, idFieldName: ID, modificationDateFieldName: contactModificationDateFieldName, externalIdFieldName: contactExternalIdFieldName),
            childrenCreateFieldlist: [LAST_NAME, ACCOUNT_ID],
            childrenUpdateFieldlist: [LAST_NAME, ACCOUNT_ID],
            relationshipType: .masterDetail)
    }
}
