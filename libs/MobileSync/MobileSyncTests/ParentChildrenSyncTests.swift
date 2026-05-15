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

private let SOUP_ENTRY_ID = "_soupEntryId"

enum SyncUpChange: Int {
    case none
    case update
    case delete
}

class ParentChildrenSyncTests: SyncManagerTestCase {

    var accountIdToFieldsMap: NSMutableDictionary!
    var accountIdContactIdToFieldsMap: NSMutableDictionary!

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
        var target = ParentChildrenSyncDownTarget.newSyncTarget(
            withParentInfo: SFParentInfo.new(sobjectType: "Parent", soupName: "parentsSoup", idFieldName: "ParentId", modificationDateFieldName: "ParentModifiedDate"),
            parentFieldlist: ["ParentName", "Title"],
            parentSoqlFilter: "School = 'MIT'",
            childrenInfo: SFChildrenInfo.new(sobjectType: "Child", sobjectTypePlural: "Children", soupName: "childrenSoup", parentIdFieldName: "parentId", idFieldName: "ChildId", modificationDateFieldName: "ChildLastModifiedDate"),
            childrenFieldlist: ["ChildName", "School"],
            relationshipType: .lookup)

        var expectedQuery = "select ParentName, Title, ParentId, ParentModifiedDate, (select ChildName, School, ChildId, ChildLastModifiedDate from Children) from Parent where School = 'MIT' order by ParentModifiedDate"
        XCTAssertEqual(target.getQueryToRun(), expectedQuery)

        // With default id and modification date fields
        target = ParentChildrenSyncDownTarget.newSyncTarget(
            withParentInfo: SFParentInfo.new(sobjectType: "Parent", soupName: "parentsSoup"),
            parentFieldlist: ["ParentName", "Title"],
            parentSoqlFilter: "School = 'MIT'",
            childrenInfo: SFChildrenInfo.new(sobjectType: "Child", sobjectTypePlural: "Children", soupName: "childrenSoup", parentIdFieldName: "parentId"),
            childrenFieldlist: ["ChildName", "School"],
            relationshipType: .lookup)

        expectedQuery = "select ParentName, Title, Id, LastModifiedDate, (select ChildName, School, Id, LastModifiedDate from Children) from Parent where School = 'MIT' order by LastModifiedDate"
        XCTAssertEqual(target.getQueryToRun(), expectedQuery)
    }

    /// Test query for reSync by calling getQuery with maxTimeStamp for SFParentChildrenSyncDownTarget
    func testGetQueryWithMaxTimeStamp() {
        let date = Date()
        let maxTimeStamp = Int64(date.timeIntervalSince1970)
        let dateStr = FormatUtils.getIsoStringFromMillis(maxTimeStamp) ?? ""

        var target = ParentChildrenSyncDownTarget.newSyncTarget(
            withParentInfo: SFParentInfo.new(sobjectType: "Parent", soupName: "parentsSoup", idFieldName: "ParentId", modificationDateFieldName: "ParentModifiedDate"),
            parentFieldlist: ["ParentName", "Title"],
            parentSoqlFilter: "School = 'MIT'",
            childrenInfo: SFChildrenInfo.new(sobjectType: "Child", sobjectTypePlural: "Children", soupName: "childrenSoup", parentIdFieldName: "parentId", idFieldName: "ChildId", modificationDateFieldName: "ChildLastModifiedDate"),
            childrenFieldlist: ["ChildName", "School"],
            relationshipType: .lookup)

        var expectedQuery = "select ParentName, Title, ParentId, ParentModifiedDate, (select ChildName, School, ChildId, ChildLastModifiedDate from Children where ChildLastModifiedDate > \(dateStr)) from Parent where ParentModifiedDate > \(dateStr) and School = 'MIT' order by ParentModifiedDate"
        XCTAssertEqual(target.getQueryToRun(maxTimeStamp), expectedQuery)

        // With default id and modification date fields
        target = ParentChildrenSyncDownTarget.newSyncTarget(
            withParentInfo: SFParentInfo.new(sobjectType: "Parent", soupName: "parentsSoup"),
            parentFieldlist: ["ParentName", "Title"],
            parentSoqlFilter: "School = 'MIT'",
            childrenInfo: SFChildrenInfo.new(sobjectType: "Child", sobjectTypePlural: "Children", soupName: "childrenSoup", parentIdFieldName: "parentId"),
            childrenFieldlist: ["ChildName", "School"],
            relationshipType: .lookup)

        expectedQuery = "select ParentName, Title, Id, LastModifiedDate, (select ChildName, School, Id, LastModifiedDate from Children where LastModifiedDate > \(dateStr)) from Parent where LastModifiedDate > \(dateStr) and School = 'MIT' order by LastModifiedDate"
        XCTAssertEqual(target.getQueryToRun(maxTimeStamp), expectedQuery)
    }

    /// Test getSoqlForRemoteIds for SFParentChildrenSyncDownTarget
    func testGetSoqlForRemoteIds() {
        var target = ParentChildrenSyncDownTarget.newSyncTarget(
            withParentInfo: SFParentInfo.new(sobjectType: "Parent", soupName: "parentsSoup", idFieldName: "ParentId", modificationDateFieldName: "ParentModifiedDate"),
            parentFieldlist: ["ParentName", "Title"],
            parentSoqlFilter: "School = 'MIT'",
            childrenInfo: SFChildrenInfo.new(sobjectType: "Child", sobjectTypePlural: "Children", soupName: "childrenSoup", parentIdFieldName: "ChildParentId", idFieldName: "ChildId", modificationDateFieldName: "ChildLastModifiedDate"),
            childrenFieldlist: ["ChildName", "School"],
            relationshipType: .lookup)

        var expectedQuery = "select ParentId from Parent where School = 'MIT'"
        XCTAssertEqual(target.getSoqlForRemoteIds(), expectedQuery)

        // With default id and modification date fields
        target = ParentChildrenSyncDownTarget.newSyncTarget(
            withParentInfo: SFParentInfo.new(sobjectType: "Parent", soupName: "parentsSoup"),
            parentFieldlist: ["ParentName", "Title"],
            parentSoqlFilter: "School = 'MIT'",
            childrenInfo: SFChildrenInfo.new(sobjectType: "Child", sobjectTypePlural: "Children", soupName: "childrenSoup", parentIdFieldName: "parentId"),
            childrenFieldlist: ["ChildName", "School"],
            relationshipType: .lookup)

        expectedQuery = "select Id from Parent where School = 'MIT'"
        XCTAssertEqual(target.getSoqlForRemoteIds(), expectedQuery)
    }

    /// Test testGetDirtyRecordIdsSql for SFParentChildrenSyncDownTarget
    func testGetDirtyRecordIdsSql() {
        let target = ParentChildrenSyncDownTarget.newSyncTarget(
            withParentInfo: SFParentInfo.new(sobjectType: "Parent", soupName: "parentsSoup", idFieldName: "ParentId", modificationDateFieldName: "ParentModifiedDate"),
            parentFieldlist: ["ParentName", "Title"],
            parentSoqlFilter: "School = 'MIT'",
            childrenInfo: SFChildrenInfo.new(sobjectType: "Child", sobjectTypePlural: "Children", soupName: "childrenSoup", parentIdFieldName: "ChildParentId", idFieldName: "ChildId", modificationDateFieldName: "ChildLastModifiedDate"),
            childrenFieldlist: ["ChildName", "School"],
            relationshipType: .lookup)

        let expectedQuery = "SELECT DISTINCT {parentsSoup:IdForQuery} FROM {parentsSoup} WHERE {parentsSoup:__local__} = 1 OR EXISTS (SELECT {childrenSoup:ChildId} FROM {childrenSoup} WHERE {childrenSoup:ChildParentId} = {parentsSoup:ParentId} AND {childrenSoup:__local__} = 1)"
        XCTAssertEqual(target.getDirtyRecordIdsSql("parentsSoup", idField: "IdForQuery"), expectedQuery)
    }

    /// Test testGetNonDirtyRecordIdsSql for SFParentChildrenSyncDownTarget
    func testGetNonDirtyRecordIdsSql() {
        let target = ParentChildrenSyncDownTarget.newSyncTarget(
            withParentInfo: SFParentInfo.new(sobjectType: "Parent", soupName: "parentsSoup", idFieldName: "ParentId", modificationDateFieldName: "ParentModifiedDate"),
            parentFieldlist: ["ParentName", "Title"],
            parentSoqlFilter: "School = 'MIT'",
            childrenInfo: SFChildrenInfo.new(sobjectType: "Child", sobjectTypePlural: "Children", soupName: "childrenSoup", parentIdFieldName: "ChildParentId", idFieldName: "ChildId", modificationDateFieldName: "ChildLastModifiedDate"),
            childrenFieldlist: ["ChildName", "School"],
            relationshipType: .lookup)

        let expectedQuery = "SELECT DISTINCT {parentsSoup:IdForQuery} FROM {parentsSoup} WHERE {parentsSoup:__local__} = 0 AND {parentsSoup:__sync_id__} = 123 AND NOT EXISTS (SELECT {childrenSoup:ChildId} FROM {childrenSoup} WHERE {childrenSoup:ChildParentId} = {parentsSoup:ParentId} AND {childrenSoup:__local__} = 1)"
        XCTAssertEqual(target.getNonDirtyRecordIdsSql(soupName: "parentsSoup", idField: "IdForQuery", additionalPredicate: "AND {parentsSoup:__sync_id__} = 123"), expectedQuery)
    }

    /// Test getDirtyRecordIds and getNonDirtyRecordIds for SFParentChildrenSyncDownTarget
    func testGetDirtyAndNonDirtyRecordIds() {
        let accountNames = [createAccountName(), createAccountName(), createAccountName(), createAccountName(), createAccountName(), createAccountName()]

        let mapAccountToContacts = createAccountsAndContactsLocally(accountNames, numberOfContactsPerAccount: 3)
        let accounts = mapAccountToContacts.keys.map { $0 }

        tryGetDirtyRecordIds(accounts)
        tryGetNonDirtyRecordIds([])

        // Cleaning up
        cleanRecord(ACCOUNTS_SOUP, record: accounts[1])
        cleanRecords(CONTACTS_SOUP, records: mapAccountToContacts[accounts[2]]!)
        cleanRecord(ACCOUNTS_SOUP, record: accounts[3])
        cleanRecords(CONTACTS_SOUP, records: mapAccountToContacts[accounts[3]]!)
        cleanRecord(CONTACTS_SOUP, record: mapAccountToContacts[accounts[4]]![0])
        cleanRecord(ACCOUNTS_SOUP, record: accounts[5])
        cleanRecord(CONTACTS_SOUP, record: mapAccountToContacts[accounts[5]]![0])

        tryGetDirtyRecordIds([accounts[0], accounts[1], accounts[2], accounts[4], accounts[5]])
        tryGetNonDirtyRecordIds([accounts[3]])
    }

    /// Sync down the test accounts and contacts, check smart store, check status during sync
    func testSyncDown() {
        let numberAccounts: UInt = 4
        let numberContactsPerAccount: UInt = 3

        createAccountsAndContactsOnServer(numberAccounts, numberContactsPerAccount: numberContactsPerAccount)

        let parentSoqlFilter = "\(ID) IN \(buildInClause(accountIdToFieldsMap.allKeys as! [String]))"
        let target = getAccountContactsSyncDownTarget(parentSoqlFilter: parentSoqlFilter)

        trySyncDown(.overwrite, target: target, soupName: ACCOUNTS_SOUP, totalSize: numberAccounts, numberFetches: 1)

        checkDb(accountIdToFieldsMap as! [String: Any], soupName: ACCOUNTS_SOUP)
        for accountId in accountIdToFieldsMap.allKeys as! [String] {
            checkDb(accountIdContactIdToFieldsMap[accountId] as! [String: Any], soupName: CONTACTS_SOUP)
        }
    }

    /// Sync down the test accounts that do not have children contacts
    func testSyncDownNoChildren() {
        let numberAccounts: UInt = 4
        accountIdToFieldsMap = NSMutableDictionary(dictionary: createAccounts(onServer: numberAccounts) ?? [:])

        let parentSoqlFilter = "\(ID) IN \(buildInClause(accountIdToFieldsMap.allKeys as! [String]))"
        let target = getAccountContactsSyncDownTarget(parentSoqlFilter: parentSoqlFilter)

        trySyncDown(.overwrite, target: target, soupName: ACCOUNTS_SOUP, totalSize: numberAccounts, numberFetches: 1)
        checkDb(accountIdToFieldsMap as! [String: Any], soupName: ACCOUNTS_SOUP)
    }

    /// Create accounts and contacts locally, sync up with merge mode OVERWRITE
    func testSyncUpWithLocallyCreatedRecords() {
        trySyncUpWithLocallyCreatedRecords(.overwrite)
    }

    /// Create accounts and contacts locally, sync up with merge mode LEAVE_IF_CHANGED
    func testSyncUpWithLocallyCreatedRecordsWithoutOverwrite() {
        trySyncUpWithLocallyCreatedRecords(.leaveIfChanged)
    }

    // MARK: - Sync up with various changes tests

    func testSyncUpLocallyUpdatedChild() {
        trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .none, remoteChangeForAccount: .none, localChangeForContact: .update, remoteChangeForContact: .none)
    }

    func testSyncUpLocallyUpdatedChildRemotelyUpdatedChild() {
        trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .none, remoteChangeForAccount: .none, localChangeForContact: .update, remoteChangeForContact: .update)
    }

    func testSyncUpLocallyUpdatedChildRemotelyDeletedChild() {
        trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .none, remoteChangeForAccount: .none, localChangeForContact: .update, remoteChangeForContact: .delete)
    }

    func testSyncUpLocallyDeletedChild() {
        trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .none, remoteChangeForAccount: .none, localChangeForContact: .delete, remoteChangeForContact: .none)
    }

    func testSyncUpLocallyDeletedChildRemotelyUpdatedChild() {
        trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .none, remoteChangeForAccount: .none, localChangeForContact: .delete, remoteChangeForContact: .update)
    }

    func testSyncUpLocallyDeletedChildRemotelyDeletedChild() {
        trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .none, remoteChangeForAccount: .none, localChangeForContact: .delete, remoteChangeForContact: .delete)
    }

    func testSyncUpLocallyUpdatedParent() {
        trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .update, remoteChangeForAccount: .none, localChangeForContact: .none, remoteChangeForContact: .none)
    }

    func testSyncUpLocallyUpdatedParentRemotelyUpdatedParent() {
        trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .update, remoteChangeForAccount: .update, localChangeForContact: .none, remoteChangeForContact: .none)
    }

    func testSyncUpLocallyUpdatedParentRemotelyDeletedParent() {
        trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .update, remoteChangeForAccount: .delete, localChangeForContact: .none, remoteChangeForContact: .none)
    }

    func testSyncUpLocallyUpdatedParentUpdatedChild() {
        trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .update, remoteChangeForAccount: .none, localChangeForContact: .update, remoteChangeForContact: .none)
    }

    func testSyncUpLocallyUpdatedParentUpdatedChildRemotelyUpdatedChild() {
        trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .update, remoteChangeForAccount: .none, localChangeForContact: .update, remoteChangeForContact: .update)
    }

    func testSyncUpLocallyUpdatedParentUpdatedChildRemotelyDeletedChild() {
        trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .update, remoteChangeForAccount: .none, localChangeForContact: .update, remoteChangeForContact: .delete)
    }

    func testSyncUpLocallyUpdatedParentUpdatedChildRemotelyUpdatedParent() {
        trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .update, remoteChangeForAccount: .update, localChangeForContact: .update, remoteChangeForContact: .none)
    }

    func testSyncUpLocallyUpdatedParentUpdatedChildRemotelyUpdatedParentUpdatedChild() {
        trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .update, remoteChangeForAccount: .update, localChangeForContact: .update, remoteChangeForContact: .update)
    }

    func testSyncUpLocallyUpdatedParentUpdatedChildRemotelyUpdatedParentDeletedChild() {
        trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .update, remoteChangeForAccount: .update, localChangeForContact: .update, remoteChangeForContact: .delete)
    }

    func testSyncUpLocallyUpdatedParentUpdatedChildRemotelyDeletedParent() {
        trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .update, remoteChangeForAccount: .delete, localChangeForContact: .update, remoteChangeForContact: .none)
    }

    func testSyncUpLocallyUpdatedParentDeletedChild() {
        trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .update, remoteChangeForAccount: .none, localChangeForContact: .delete, remoteChangeForContact: .none)
    }

    func testSyncUpLocallyUpdatedParentDeletedChildRemotelyUpdatedChild() {
        trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .update, remoteChangeForAccount: .none, localChangeForContact: .delete, remoteChangeForContact: .update)
    }

    func testSyncUpLocallyUpdatedParentDeletedChildRemotelyDeletedChild() {
        trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .update, remoteChangeForAccount: .none, localChangeForContact: .delete, remoteChangeForContact: .delete)
    }

    func testSyncUpLocallyUpdatedParentDeletedChildRemotelyUpdatedParent() {
        trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .update, remoteChangeForAccount: .update, localChangeForContact: .delete, remoteChangeForContact: .none)
    }

    func testSyncUpLocallyUpdatedParentDeletedChildRemotelyUpdatedParentUpdatedChild() {
        trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .update, remoteChangeForAccount: .update, localChangeForContact: .delete, remoteChangeForContact: .update)
    }

    func testSyncUpLocallyUpdatedParentDeletedChildRemotelyUpdatedParentDeletedChild() {
        trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .update, remoteChangeForAccount: .update, localChangeForContact: .delete, remoteChangeForContact: .delete)
    }

    func testSyncUpLocallyUpdatedParentDeletedChildRemotelyDeletedParent() {
        trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .update, remoteChangeForAccount: .delete, localChangeForContact: .delete, remoteChangeForContact: .none)
    }

    func testSyncUpLocallyDeletedParent() {
        trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .delete, remoteChangeForAccount: .none, localChangeForContact: .none, remoteChangeForContact: .none)
    }

    func testSyncUpLocallyDeletedParentRemotelyUpdatedParent() {
        trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .delete, remoteChangeForAccount: .update, localChangeForContact: .none, remoteChangeForContact: .none)
    }

    func testSyncUpLocallyDeletedParentRemotelyDeletedParent() {
        trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .delete, remoteChangeForAccount: .delete, localChangeForContact: .none, remoteChangeForContact: .none)
    }

    func testSyncUpLocallyDeletedParentUpdatedChild() {
        trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .delete, remoteChangeForAccount: .none, localChangeForContact: .update, remoteChangeForContact: .none)
    }

    func testSyncUpLocallyDeletedParentUpdatedChildRemotelyUpdatedParent() {
        trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .delete, remoteChangeForAccount: .update, localChangeForContact: .update, remoteChangeForContact: .none)
    }

    func testSyncUpLocallyDeletedParentUpdatedChildRemotelyDeletedParent() {
        trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .delete, remoteChangeForAccount: .delete, localChangeForContact: .update, remoteChangeForContact: .none)
    }

    func testSyncUpLocallyDeletedParentDeletedChild() {
        trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .delete, remoteChangeForAccount: .none, localChangeForContact: .delete, remoteChangeForContact: .none)
    }

    func testSyncUpLocallyDeletedParentDeletedChildRemotelyUpdatedParent() {
        trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .delete, remoteChangeForAccount: .update, localChangeForContact: .delete, remoteChangeForContact: .none)
    }

    func testSyncUpLocallyDeletedParentDeletedChildRemotelyDeletedParent() {
        trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 2, localChangeForAccount: .delete, remoteChangeForAccount: .delete, localChangeForContact: .delete, remoteChangeForContact: .none)
    }

    func testSyncUpLocallyUpdatedParentNoChildren() {
        trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 0, localChangeForAccount: .update, remoteChangeForAccount: .none, localChangeForContact: .none, remoteChangeForContact: .none)
    }

    func testSyncUpLocallyUpdatedParentRemotelyUpdatedParentNoChildren() {
        trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 0, localChangeForAccount: .update, remoteChangeForAccount: .update, localChangeForContact: .none, remoteChangeForContact: .none)
    }

    func testSyncUpLocallyUpdatedParentRemotelyDeletedParentNoChildren() {
        trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 0, localChangeForAccount: .update, remoteChangeForAccount: .delete, localChangeForContact: .none, remoteChangeForContact: .none)
    }

    func testSyncUpLocallyDeletedParentNoChildren() {
        trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 0, localChangeForAccount: .delete, remoteChangeForAccount: .none, localChangeForContact: .none, remoteChangeForContact: .none)
    }

    func testSyncUpLocallyDeletedParentRemotelyUpdatedParentNoChildren() {
        trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 0, localChangeForAccount: .delete, remoteChangeForAccount: .update, localChangeForContact: .none, remoteChangeForContact: .none)
    }

    func testSyncUpLocallyDeletedParentRemotelyDeletedParentNoChildren() {
        trySyncUpsWithVariousChanges(numberAccounts: 2, numberContactsPerAccount: 0, localChangeForAccount: .delete, remoteChangeForAccount: .delete, localChangeForContact: .none, remoteChangeForContact: .none)
    }

    // MARK: - Helper methods

    private func createTestData() {
        createAccountsSoup()
        createContactsSoup()
    }

    private func deleteTestData() {
        dropAccountsSoup()
        dropContactsSoup()

        if let accountIds = accountIdToFieldsMap?.allKeys as? [String] {
            deleteRecords(onServer: accountIds, objectType: ACCOUNT_TYPE)
            accountIdToFieldsMap = nil
        }

        if let map = accountIdContactIdToFieldsMap {
            for accountId in map.allKeys as! [String] {
                if let contactIdToFields = map[accountId] as? [String: Any] {
                    deleteRecords(onServer: Array(contactIdToFields.keys), objectType: CONTACT_TYPE)
                }
            }
            accountIdContactIdToFieldsMap = nil
        }
    }

    private func createAccountsAndContactsLocally(_ names: [String], numberOfContactsPerAccount: Int) -> [NSDictionary: [NSDictionary]] {
        var accounts: [NSDictionary] = []
        var accountIds: [String] = []
        let attributes: NSDictionary = [TYPE: ACCOUNT_TYPE]
        for name in names {
            let account: NSDictionary = [
                ID: SyncTarget.createLocalId(),
                NAME: name,
                DESCRIPTION: "Description_\(name)",
                ATTRIBUTES: attributes,
                syncTargetLocal: true,
                syncTargetLocallyCreated: true,
                syncTargetLocallyUpdated: false,
                syncTargetLocallyDeleted: false
            ]
            accounts.append(account)
            accountIds.append(account[ID] as! String)
        }
        let createdAccounts = store.upsert(entries: accounts, forSoupNamed: ACCOUNTS_SOUP)

        let accountIdsToContacts = createContactsForAccountLocally(numberOfContactsPerAccount, accountIds: accountIds)
        var accountToContacts: [NSDictionary: [NSDictionary]] = [:]
        for createdAccount in createdAccounts {
            let ca = createdAccount as! NSDictionary
            accountToContacts[ca] = accountIdsToContacts[ca[ID] as! String]
        }
        return accountToContacts
    }

    private func createContactsForAccountLocally(_ numberOfContactsPerAccount: Int, accountIds: [String]) -> [String: [NSDictionary]] {
        var accountIdsToContacts: [String: [NSDictionary]] = [:]
        let attributes: NSDictionary = [TYPE: ACCOUNT_TYPE]
        for accountId in accountIds {
            var contacts: [NSDictionary] = []
            for _ in 0..<numberOfContactsPerAccount {
                let contact: NSDictionary = [
                    ID: SyncTarget.createLocalId(),
                    LAST_NAME: createRecordName(CONTACT_TYPE),
                    ATTRIBUTES: attributes,
                    ACCOUNT_ID: accountId,
                    syncTargetLocal: true,
                    syncTargetLocallyCreated: true,
                    syncTargetLocallyUpdated: false,
                    syncTargetLocallyDeleted: false
                ]
                contacts.append(contact)
            }
            accountIdsToContacts[accountId] = store.upsert(entries: contacts, forSoupNamed: CONTACTS_SOUP) as? [NSDictionary]
        }
        return accountIdsToContacts
    }

    private func tryGetDirtyRecordIds(_ expectedRecords: [NSDictionary]) {
        let target = getAccountContactsSyncDownTarget()
        let dirtyRecordIds = target.getDirtyRecordIds(syncManager, soupName: ACCOUNTS_SOUP, idField: ID)
        XCTAssertEqual(dirtyRecordIds.count, expectedRecords.count)
        for expectedRecord in expectedRecords {
            XCTAssertTrue(dirtyRecordIds.contains(expectedRecord[ID] as! String))
        }
    }

    private func tryGetNonDirtyRecordIds(_ expectedRecords: [NSDictionary]) {
        let target = getAccountContactsSyncDownTarget()
        let nonDirtyRecordIds = target.getNonDirtyRecordIds(syncManager: syncManager, soupName: ACCOUNTS_SOUP, idField: ID, additionalPredicate: "")
        XCTAssertEqual(nonDirtyRecordIds.count, expectedRecords.count)
        for expectedRecord in expectedRecords {
            XCTAssertTrue(nonDirtyRecordIds.contains(expectedRecord[ID] as! String))
        }
    }

    private func cleanRecords(_ soupName: String, records: [NSDictionary]) {
        var cleanedRecords: [NSDictionary] = []
        for record in records {
            let mutableRecord = NSMutableDictionary(dictionary: record)
            mutableRecord[syncTargetLocal] = false
            mutableRecord[syncTargetLocallyCreated] = false
            mutableRecord[syncTargetLocallyUpdated] = false
            mutableRecord[syncTargetLocallyDeleted] = false
            cleanedRecords.append(mutableRecord)
        }
        store.upsert(entries: cleanedRecords, forSoupNamed: soupName)
    }

    private func cleanRecord(_ soupName: String, record: NSDictionary) {
        cleanRecords(soupName, records: [record])
    }

    private func getAccountContactsSyncDownTarget() -> ParentChildrenSyncDownTarget {
        return getAccountContactsSyncDownTarget(parentSoqlFilter: "")
    }

    private func getAccountContactsSyncDownTarget(parentSoqlFilter: String) -> ParentChildrenSyncDownTarget {
        return ParentChildrenSyncDownTarget.newSyncTarget(
            withParentInfo: SFParentInfo.new(sobjectType: ACCOUNT_TYPE, soupName: ACCOUNTS_SOUP, idFieldName: ID, modificationDateFieldName: LAST_MODIFIED_DATE),
            parentFieldlist: [ID, NAME, DESCRIPTION],
            parentSoqlFilter: parentSoqlFilter,
            childrenInfo: SFChildrenInfo.new(sobjectType: CONTACT_TYPE, sobjectTypePlural: CONTACT_TYPE_PLURAL, soupName: CONTACTS_SOUP, parentIdFieldName: ACCOUNT_ID, idFieldName: ID, modificationDateFieldName: LAST_MODIFIED_DATE),
            childrenFieldlist: [LAST_NAME, ACCOUNT_ID],
            relationshipType: .masterDetail)
    }

    private func getAccountContactsSyncUpTarget() -> ParentChildrenSyncUpTarget {
        return ParentChildrenSyncUpTarget.newSyncTarget(
            withParentInfo: SFParentInfo.new(sobjectType: ACCOUNT_TYPE, soupName: ACCOUNTS_SOUP, idFieldName: ID, modificationDateFieldName: LAST_MODIFIED_DATE, externalIdFieldName: nil),
            parentCreateFieldlist: [ID, NAME, DESCRIPTION],
            parentUpdateFieldlist: [NAME, DESCRIPTION],
            childrenInfo: SFChildrenInfo.new(sobjectType: CONTACT_TYPE, sobjectTypePlural: CONTACT_TYPE_PLURAL, soupName: CONTACTS_SOUP, parentIdFieldName: ACCOUNT_ID, idFieldName: ID, modificationDateFieldName: LAST_MODIFIED_DATE, externalIdFieldName: nil),
            childrenCreateFieldlist: [LAST_NAME, ACCOUNT_ID],
            childrenUpdateFieldlist: [LAST_NAME, ACCOUNT_ID],
            relationshipType: .masterDetail)
    }

    private func createAccountsAndContactsOnServer(_ numberAccounts: UInt, numberContactsPerAccount: UInt) {
        accountIdToFieldsMap = NSMutableDictionary()
        accountIdContactIdToFieldsMap = NSMutableDictionary()

        var refIdToFields: [String: [String: Any]] = [:]
        var accountTrees: [SObjectTree] = []
        let listAccountFields = buildFieldsMapForRecords(numberAccounts, objectType: ACCOUNT_TYPE, additionalFields: nil)

        for i in 0..<Int(numberAccounts) {
            let listContactFields = buildFieldsMapForRecords(numberContactsPerAccount, objectType: CONTACT_TYPE, additionalFields: nil)
            let refIdAccount = "refAccount_\(i)"
            let accountFields = listAccountFields[i]
            refIdToFields[refIdAccount] = accountFields

            var contactTrees: [SObjectTree] = []
            for j in 0..<Int(numberContactsPerAccount) {
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

        let request = RestClient.shared.requestForSObjectTree(ACCOUNT_TYPE, objectTrees: accountTrees, apiVersion: nil)
        guard let response = sendSyncRequest(request) else { return }

        var refIdToId: [String: String] = [:]
        if let results = response["results"] as? [[String: Any]] {
            for result in results {
                if let refId = result["referenceId"] as? String, let recordId = result["id"] as? String {
                    refIdToId[refId] = recordId
                }
            }
        }

        for refId in refIdToId.keys {
            let fields = refIdToFields[refId]!
            let parts = refId.components(separatedBy: "__")
            let accountId = refIdToId[parts[0]]!
            let contactId: String? = parts.count > 1 ? refIdToId[refId] : nil

            if contactId == nil {
                accountIdToFieldsMap[accountId] = fields
            } else {
                if accountIdContactIdToFieldsMap[accountId] == nil {
                    accountIdContactIdToFieldsMap[accountId] = NSMutableDictionary()
                }
                (accountIdContactIdToFieldsMap[accountId] as! NSMutableDictionary)[contactId!] = fields
            }
        }
    }

    private func trySyncUpWithLocallyCreatedRecords(_ mergeMode: SyncMergeMode) {
        let numberContactsPerAccount = 3
        let accountNames = [createAccountName(), createAccountName(), createAccountName(), createAccountName(), createAccountName()]
        let mapAccountToContacts = createAccountsAndContactsLocally(accountNames, numberOfContactsPerAccount: numberContactsPerAccount)
        var contactNames: [String] = []
        for contacts in mapAccountToContacts.values {
            for contact in contacts {
                contactNames.append(contact[LAST_NAME] as! String)
            }
        }

        let target = getAccountContactsSyncUpTarget()
        trySyncUp(accountNames.count, target: target, mergeMode: mergeMode)

        let accountIdToFieldsCreated = getIdToFieldsByName(ACCOUNTS_SOUP, fieldNames: [NAME, DESCRIPTION], nameField: NAME, names: accountNames)
        checkDbStateFlags(Array(accountIdToFieldsCreated.keys), soupName: ACCOUNTS_SOUP, expectedLocallyCreated: false, expectedLocallyUpdated: false, expectedLocallyDeleted: false)
        checkServer(accountIdToFieldsCreated, objectType: ACCOUNT_TYPE)

        let contactIdToFieldsCreated = getIdToFieldsByName(CONTACTS_SOUP, fieldNames: [LAST_NAME, ACCOUNT_ID], nameField: LAST_NAME, names: contactNames)
        checkDbStateFlags(Array(contactIdToFieldsCreated.keys), soupName: CONTACTS_SOUP, expectedLocallyCreated: false, expectedLocallyUpdated: false, expectedLocallyDeleted: false)
        checkServer(contactIdToFieldsCreated, objectType: CONTACT_TYPE)

        deleteRecords(onServer: Array(accountIdToFieldsCreated.keys), objectType: ACCOUNT_TYPE)
        deleteRecords(onServer: Array(contactIdToFieldsCreated.keys), objectType: CONTACT_TYPE)
    }

    // MARK: - trySyncUpsWithVariousChanges

    private func trySyncUpsWithVariousChanges(numberAccounts: UInt, numberContactsPerAccount: UInt, localChangeForAccount: SyncUpChange, remoteChangeForAccount: SyncUpChange, localChangeForContact: SyncUpChange, remoteChangeForContact: SyncUpChange) {

        createAccountsAndContactsOnServer(numberAccounts, numberContactsPerAccount: numberContactsPerAccount)

        let parentSoqlFilter = "\(ID) IN \(buildInClause(accountIdToFieldsMap.allKeys as! [String]))"
        let syncDownTarget = getAccountContactsSyncDownTarget(parentSoqlFilter: parentSoqlFilter)
        trySyncDown(.overwrite, target: syncDownTarget, soupName: ACCOUNTS_SOUP, totalSize: numberAccounts, numberFetches: 1)

        let accountIds = accountIdToFieldsMap.allKeys as! [String]
        let accountId = accountIds[0]
        let accountFields = accountIdToFieldsMap[accountId] as! [String: Any]

        let contactIdsOfAccount: [String]? = numberContactsPerAccount > 0 ? (accountIdContactIdToFieldsMap[accountId] as? NSDictionary)?.allKeys as? [String] : nil
        let contactId: String? = contactIdsOfAccount?[0]
        let otherContactId: String? = contactIdsOfAccount?[1]
        let contactFields: [String: Any]? = contactId != nil ? (accountIdContactIdToFieldsMap[accountId] as? NSDictionary)?[contactId!] as? [String: Any] : nil

        let syncUpTarget = getAccountContactsSyncUpTarget()

        // Apply localChangeForAccount
        var localUpdatesAccount: [String: Any]?
        switch localChangeForAccount {
        case .none: break
        case .update:
            localUpdatesAccount = updateRecordLocally(accountFields, idToUpdate: accountId, soupName: ACCOUNTS_SOUP)
        case .delete:
            deleteRecordsLocally([accountId], soupName: ACCOUNTS_SOUP)
        }

        // Apply localChangeForContact
        var localUpdatesContact: [String: Any]?
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
        var remoteUpdatesAccount: [String: Any]?
        switch remoteChangeForAccount {
        case .none: break
        case .update:
            remoteUpdatesAccount = updateRecordOnServer(accountFields, idToUpdate: accountId, objectType: ACCOUNT_TYPE)
        case .delete:
            deleteRecords(onServer: [accountId], objectType: ACCOUNT_TYPE)
        }

        // Apply remoteChangeForContact
        var remoteUpdatesContact: [String: Any]?
        if let cId = contactId, let cFields = contactFields {
            switch remoteChangeForContact {
            case .none: break
            case .update:
                remoteUpdatesContact = updateRecordOnServer(cFields, idToUpdate: cId, objectType: CONTACT_TYPE)
            case .delete:
                deleteRecords(onServer: [cId], objectType: CONTACT_TYPE)
            }
        }

        // Sync up
        if (remoteChangeForAccount == .none || (remoteChangeForAccount == .delete && localChangeForAccount == .delete))
            && (remoteChangeForContact == .none || (remoteChangeForContact == .delete && localChangeForContact == .delete)) {
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

    private func checkDbAndServerAfterBlockedSyncUp(accountId: String, contactId: String?, localChangeForAccount: SyncUpChange, remoteChangeForAccount: SyncUpChange, localChangeForContact: SyncUpChange, remoteChangeForContact: SyncUpChange, localUpdatesAccount: [String: Any]?, remoteUpdatesAccount: [String: Any]?, localUpdatesContact: [String: Any]?, remoteUpdatesContact: [String: Any]?) {
        if localChangeForAccount == .update, let la = localUpdatesAccount {
            checkDb(la, soupName: ACCOUNTS_SOUP)
        }
        checkDbStateFlags([accountId], soupName: ACCOUNTS_SOUP, expectedLocallyCreated: false, expectedLocallyUpdated: localChangeForAccount == .update, expectedLocallyDeleted: localChangeForAccount == .delete)

        switch remoteChangeForAccount {
        case .none: break
        case .update:
            if let ra = remoteUpdatesAccount { checkServer(ra, objectType: ACCOUNT_TYPE) }
        case .delete:
            checkServerDeleted([accountId], objectType: ACCOUNT_TYPE)
        }

        if let cId = contactId {
            let contactIdsOfAccounts = ((accountIdContactIdToFieldsMap[accountId] as? NSDictionary)?.allKeys as? [String]) ?? []
            if localChangeForContact == .update, let lc = localUpdatesContact {
                checkDb(lc, soupName: CONTACTS_SOUP)
            }
            checkDbStateFlags([cId], soupName: CONTACTS_SOUP, expectedLocallyCreated: false, expectedLocallyUpdated: localChangeForContact == .update, expectedLocallyDeleted: localChangeForContact == .delete)
            checkDbRelationships(withChildrenIds: contactIdsOfAccounts, expectedParentId: accountId, soupName: CONTACTS_SOUP, idFieldName: ID, parentIdFieldName: ACCOUNT_ID)

            if remoteChangeForAccount == .delete {
                checkServerDeleted(contactIdsOfAccounts, objectType: CONTACT_TYPE)
            } else {
                switch remoteChangeForContact {
                case .none: break
                case .update:
                    if let rc = remoteUpdatesContact { checkServer(rc, objectType: CONTACT_TYPE) }
                case .delete:
                    checkServerDeleted([cId], objectType: CONTACT_TYPE)
                }
            }
        }
    }

    private func checkDbAndServerAfterCompletedSyncUp(accountId: String, contactId: String?, otherContactId: String?, localChangeForAccount: SyncUpChange, remoteChangeForAccount: SyncUpChange, localChangeForContact: SyncUpChange, remoteChangeForContact: SyncUpChange, localUpdatesAccount: [String: Any]?, localUpdatesContact: [String: Any]?) {

        var newAccountId: String?
        var newContactId: String?
        var newOtherContactId: String?

        switch localChangeForAccount {
        case .none:
            checkRecordAfterSync(accountId, fields: accountIdToFieldsMap[accountId] as! [String: Any], soupName: ACCOUNTS_SOUP, objectType: ACCOUNT_TYPE, parentId: nil, parentIdField: nil)
        case .update:
            if remoteChangeForAccount == .delete {
                newAccountId = checkRecordRecreated(accountId, fields: (localUpdatesAccount?[accountId] as? [String: Any]) ?? [:], nameField: NAME, soupName: ACCOUNTS_SOUP, objectType: ACCOUNT_TYPE, parentId: nil, parentIdField: nil)
            } else {
                checkRecordAfterSync(accountId, fields: (localUpdatesAccount?[accountId] as? [String: Any]) ?? [:], soupName: ACCOUNTS_SOUP, objectType: ACCOUNT_TYPE, parentId: nil, parentIdField: nil)
            }
        case .delete:
            checkDeletedRecordAfterSync(accountId, soupName: ACCOUNTS_SOUP, objectType: ACCOUNT_TYPE)
        }

        if let cId = contactId {
            if localChangeForAccount == .delete {
                let contactIdsOfAccount = ((accountIdContactIdToFieldsMap[accountId] as? NSDictionary)?.allKeys as? [String]) ?? []
                checkDbDeleted(CONTACTS_SOUP, ids: contactIdsOfAccount, idField: ID)
                checkServerDeleted(contactIdsOfAccount, objectType: CONTACT_TYPE)
            } else {
                switch localChangeForContact {
                case .none:
                    let origContactFields = (accountIdContactIdToFieldsMap[accountId] as? NSDictionary)?[cId] as? [String: Any] ?? [:]
                    if remoteChangeForAccount == .delete || remoteChangeForContact == .delete {
                        newContactId = checkRecordRecreated(cId, fields: origContactFields, nameField: LAST_NAME, soupName: CONTACTS_SOUP, objectType: CONTACT_TYPE, parentId: newAccountId ?? accountId, parentIdField: ACCOUNT_ID)
                    } else {
                        checkRecordAfterSync(cId, fields: origContactFields, soupName: CONTACTS_SOUP, objectType: CONTACT_TYPE, parentId: accountId, parentIdField: ACCOUNT_ID)
                    }
                case .update:
                    let localContactFields = (localUpdatesContact?[cId] as? [String: Any]) ?? [:]
                    if remoteChangeForAccount == .delete || remoteChangeForContact == .delete {
                        newContactId = checkRecordRecreated(cId, fields: localContactFields, nameField: LAST_NAME, soupName: CONTACTS_SOUP, objectType: CONTACT_TYPE, parentId: newAccountId ?? accountId, parentIdField: ACCOUNT_ID)
                    } else {
                        checkRecordAfterSync(cId, fields: localContactFields, soupName: CONTACTS_SOUP, objectType: CONTACT_TYPE, parentId: accountId, parentIdField: ACCOUNT_ID)
                    }
                case .delete:
                    checkDeletedRecordAfterSync(cId, soupName: CONTACTS_SOUP, objectType: CONTACT_TYPE)
                }

                if remoteChangeForAccount == .delete, let oCId = otherContactId {
                    let otherFields = (accountIdContactIdToFieldsMap[accountId] as? NSDictionary)?[oCId] as? [String: Any] ?? [:]
                    newOtherContactId = checkRecordRecreated(oCId, fields: otherFields, nameField: LAST_NAME, soupName: CONTACTS_SOUP, objectType: CONTACT_TYPE, parentId: newAccountId!, parentIdField: ACCOUNT_ID)
                }
            }
        }

        if let id = newAccountId { deleteRecords(onServer: [id], objectType: ACCOUNT_TYPE) }
        if let id = newContactId { deleteRecords(onServer: [id], objectType: CONTACT_TYPE) }
        if let id = newOtherContactId { deleteRecords(onServer: [id], objectType: CONTACT_TYPE) }
    }

    @discardableResult
    private func checkRecordRecreated(_ recordId: String, fields: [String: Any], nameField: String, soupName: String, objectType: String, parentId: String?, parentIdField: String?) -> String {
        let updatedName = fields[nameField] as! String
        let newIdToFields = getIdToFieldsByName(soupName, fieldNames: [nameField], nameField: nameField, names: [updatedName])
        let newRecordId = Array(newIdToFields.keys)[0]

        XCTAssertNotEqual(newRecordId, recordId, "Record should have new id")
        checkDbDeleted(soupName, ids: [recordId], idField: ID)
        checkServerDeleted([recordId], objectType: objectType)
        checkRecordAfterSync(newRecordId, fields: newIdToFields[newRecordId] as! [String: Any], soupName: soupName, objectType: objectType, parentId: parentId, parentIdField: parentIdField)

        return newRecordId
    }

    private func checkRecordAfterSync(_ recordId: String, fields: [String: Any], soupName: String, objectType: String, parentId: String?, parentIdField: String?) {
        checkDbStateFlags([recordId], soupName: soupName, expectedLocallyCreated: false, expectedLocallyUpdated: false, expectedLocallyDeleted: false)

        var fieldsCopy = fields
        if let pId = parentId, let pField = parentIdField {
            fieldsCopy[pField] = pId
        }
        let idToFieldsCheck: [String: Any] = [recordId: fieldsCopy]
        checkDb(idToFieldsCheck, soupName: soupName)
        checkServer(idToFieldsCheck, objectType: objectType)
    }

    private func checkDeletedRecordAfterSync(_ recordId: String, soupName: String, objectType: String) {
        checkDbDeleted(soupName, ids: [recordId], idField: ID)
        checkServerDeleted([recordId], objectType: objectType)
    }
}
