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
@testable import MobileSync

class SFSDKSyncsConfigTests: SyncManagerTestCase {

    private var sdkManager: MobileSyncSDKManager?

    // MARK: - Setup and Teardown

    override func setUp() {
        super.setUp()
        sdkManager = MobileSyncSDKManager()
    }

    override func tearDown() {
        super.tearDown()
        sdkManager = nil
    }

    // MARK: - Tests

    func testSetupGlobalSyncsFromDefaultConfig() {
        XCTAssertFalse(globalSyncManager.hasSyncWithName("globalSync1"))
        XCTAssertFalse(globalSyncManager.hasSyncWithName("globalSync2"))

        // Setting up syncs
        sdkManager?.setupGlobalSyncsFromDefaultConfig()

        // Checking smartstore
        XCTAssertTrue(globalSyncManager.hasSyncWithName("globalSync1"))
        XCTAssertTrue(globalSyncManager.hasSyncWithName("globalSync2"))

        // Checking first sync in details
        guard let actualSync1 = globalSyncManager.getSyncStatusByName("globalSync1") else {
            XCTFail("globalSync1 should exist")
            return
        }
        XCTAssertEqual(actualSync1.soupName, "accounts")
        checkStatus(actualSync1,
                    expectedType: .down,
                    expectedId: actualSync1.syncId,
                    expectedName: "globalSync1",
                    expectedTarget: SFSoqlSyncDownTarget.newSyncTarget("SELECT Id, Name, LastModifiedDate FROM Account"),
                    expectedOptions: SFSyncOptions.newSyncOptions(forSyncDown: .overwrite),
                    expectedStatus: .new,
                    expectedProgress: 0,
                    expectedTotalSize: -1)

        // Checking second sync in details
        guard let actualSync2 = globalSyncManager.getSyncStatusByName("globalSync2") else {
            XCTFail("globalSync2 should exist")
            return
        }
        XCTAssertEqual(actualSync2.soupName, "accounts")
        checkStatus(actualSync2,
                    expectedType: .up,
                    expectedId: actualSync2.syncId,
                    expectedName: "globalSync2",
                    expectedTarget: SFBatchSyncUpTarget(createFieldlist: ["Name"], updateFieldlist: nil),
                    expectedOptions: SFSyncOptions.newSyncOptions(forSyncUp: ["Id", "Name", "LastModifiedDate"], mergeMode: .leaveIfChanged),
                    expectedStatus: .new,
                    expectedProgress: 0,
                    expectedTotalSize: -1)
    }

    func testSetupUserSyncsFromDefaultConfig() {
        XCTAssertFalse(syncManager.hasSyncWithName("soqlSyncDown"))
        XCTAssertFalse(syncManager.hasSyncWithName("soslSyncDown"))
        XCTAssertFalse(syncManager.hasSyncWithName("mruSyncDown"))
        XCTAssertFalse(syncManager.hasSyncWithName("refreshSyncDown"))
        XCTAssertFalse(syncManager.hasSyncWithName("layoutSyncDown"))
        XCTAssertFalse(syncManager.hasSyncWithName("metadataSyncDown"))
        XCTAssertFalse(syncManager.hasSyncWithName("parentChildrenSyncDown"))
        XCTAssertFalse(syncManager.hasSyncWithName("noBatchSyncUp"))
        XCTAssertFalse(syncManager.hasSyncWithName("batchSyncUp"))
        XCTAssertFalse(syncManager.hasSyncWithName("parentChildrenSyncUp"))

        // Setting up syncs
        sdkManager?.setupUserSyncsFromDefaultConfig()

        // Checking smartstore
        XCTAssertTrue(syncManager.hasSyncWithName("soqlSyncDown"))
        XCTAssertTrue(syncManager.hasSyncWithName("soslSyncDown"))
        XCTAssertTrue(syncManager.hasSyncWithName("mruSyncDown"))
        XCTAssertTrue(syncManager.hasSyncWithName("refreshSyncDown"))
        XCTAssertTrue(syncManager.hasSyncWithName("layoutSyncDown"))
        XCTAssertTrue(syncManager.hasSyncWithName("metadataSyncDown"))
        XCTAssertTrue(syncManager.hasSyncWithName("parentChildrenSyncDown"))
        XCTAssertTrue(syncManager.hasSyncWithName("noBatchSyncUp"))
        XCTAssertTrue(syncManager.hasSyncWithName("batchSyncUp"))
        XCTAssertTrue(syncManager.hasSyncWithName("parentChildrenSyncUp"))
    }

    func testSoqlSyncDownFromConfig() {
        sdkManager?.setupUserSyncsFromDefaultConfig()

        guard let sync = syncManager.getSyncStatusByName("soqlSyncDown") else {
            XCTFail("soqlSyncDown should exist")
            return
        }
        XCTAssertEqual(sync.soupName, "accounts")
        checkStatus(sync,
                    expectedType: .down,
                    expectedId: sync.syncId,
                    expectedName: "soqlSyncDown",
                    expectedTarget: SFSoqlSyncDownTarget.newSyncTarget("SELECT Id, Name, LastModifiedDate FROM Account"),
                    expectedOptions: SFSyncOptions.newSyncOptions(forSyncDown: .overwrite),
                    expectedStatus: .new,
                    expectedProgress: 0,
                    expectedTotalSize: -1)
    }

    func testSoqlSyncDownWithBatchSizeFromConfig() {
        sdkManager?.setupUserSyncsFromDefaultConfig()

        guard let sync = syncManager.getSyncStatusByName("soqlSyncDownWithBatchSize") else {
            XCTFail("soqlSyncDownWithBatchSize should exist")
            return
        }
        XCTAssertEqual(sync.soupName, "accounts")
        checkStatus(sync,
                    expectedType: .down,
                    expectedId: sync.syncId,
                    expectedName: "soqlSyncDown",
                    expectedTarget: SFSoqlSyncDownTarget.newSyncTarget("SELECT Id, Name, LastModifiedDate FROM Account", maxBatchSize: 200),
                    expectedOptions: SFSyncOptions.newSyncOptions(forSyncDown: .overwrite),
                    expectedStatus: .new,
                    expectedProgress: 0,
                    expectedTotalSize: -1)
    }

    func testSoslSyncDownFromConfig() {
        sdkManager?.setupUserSyncsFromDefaultConfig()

        guard let sync = syncManager.getSyncStatusByName("soslSyncDown") else {
            XCTFail("soslSyncDown should exist")
            return
        }
        XCTAssertEqual(sync.soupName, "accounts")
        checkStatus(sync,
                    expectedType: .down,
                    expectedId: sync.syncId,
                    expectedName: "soslSyncDown",
                    expectedTarget: SFSoslSyncDownTarget.newSyncTarget("FIND {Joe} IN NAME FIELDS RETURNING Account"),
                    expectedOptions: SFSyncOptions.newSyncOptions(forSyncDown: .leaveIfChanged),
                    expectedStatus: .new,
                    expectedProgress: 0,
                    expectedTotalSize: -1)
    }

    func testMruSyncDownFromConfig() {
        sdkManager?.setupUserSyncsFromDefaultConfig()

        guard let sync = syncManager.getSyncStatusByName("mruSyncDown") else {
            XCTFail("mruSyncDown should exist")
            return
        }
        XCTAssertEqual(sync.soupName, "accounts")
        checkStatus(sync,
                    expectedType: .down,
                    expectedId: sync.syncId,
                    expectedName: "mruSyncDown",
                    expectedTarget: SFMruSyncDownTarget.newSyncTarget("Account", fieldlist: ["Name", "Description"]),
                    expectedOptions: SFSyncOptions.newSyncOptions(forSyncDown: .overwrite),
                    expectedStatus: .new,
                    expectedProgress: 0,
                    expectedTotalSize: -1)
    }

    func testRefreshSyncDownFromConfig() {
        sdkManager?.setupUserSyncsFromDefaultConfig()

        guard let sync = syncManager.getSyncStatusByName("refreshSyncDown") else {
            XCTFail("refreshSyncDown should exist")
            return
        }
        XCTAssertEqual(sync.soupName, "accounts")
        checkStatus(sync,
                    expectedType: .down,
                    expectedId: sync.syncId,
                    expectedName: "refreshSyncDown",
                    expectedTarget: SFRefreshSyncDownTarget.newSyncTarget("accounts", objectType: "Account", fieldlist: ["Name", "Description"]),
                    expectedOptions: SFSyncOptions.newSyncOptions(forSyncDown: .leaveIfChanged),
                    expectedStatus: .new,
                    expectedProgress: 0,
                    expectedTotalSize: -1)
    }

    func testLayoutSyncDownFromConfig() {
        sdkManager?.setupUserSyncsFromDefaultConfig()

        guard let sync = syncManager.getSyncStatusByName("layoutSyncDown") else {
            XCTFail("layoutSyncDown should exist")
            return
        }
        XCTAssertEqual(sync.soupName, "accounts")
        checkStatus(sync,
                    expectedType: .down,
                    expectedId: sync.syncId,
                    expectedName: "layoutSyncDown",
                    expectedTarget: SFLayoutSyncDownTarget.newSyncTarget("Account", formFactor: "Medium", layoutType: "Compact", mode: "Edit", recordTypeId: nil),
                    expectedOptions: SFSyncOptions.newSyncOptions(forSyncDown: .overwrite),
                    expectedStatus: .new,
                    expectedProgress: 0,
                    expectedTotalSize: -1)
    }

    func testMetadataSyncDownFromConfig() {
        sdkManager?.setupUserSyncsFromDefaultConfig()

        guard let sync = syncManager.getSyncStatusByName("metadataSyncDown") else {
            XCTFail("metadataSyncDown should exist")
            return
        }
        XCTAssertEqual(sync.soupName, "accounts")
        checkStatus(sync,
                    expectedType: .down,
                    expectedId: sync.syncId,
                    expectedName: "metadataSyncDown",
                    expectedTarget: SFMetadataSyncDownTarget.newSyncTarget("Account"),
                    expectedOptions: SFSyncOptions.newSyncOptions(forSyncDown: .leaveIfChanged),
                    expectedStatus: .new,
                    expectedProgress: 0,
                    expectedTotalSize: -1)
    }

    func testParentChildrenSyncDownFromConfig() {
        sdkManager?.setupUserSyncsFromDefaultConfig()

        guard let sync = syncManager.getSyncStatusByName("parentChildrenSyncDown") else {
            XCTFail("parentChildrenSyncDown should exist")
            return
        }
        XCTAssertEqual(sync.soupName, "accounts")
        checkStatus(sync,
                    expectedType: .down,
                    expectedId: sync.syncId,
                    expectedName: "parentChildrenSyncDown",
                    expectedTarget: SFParentChildrenSyncDownTarget.newSyncTarget(
                        parentInfo: SFParentInfo.new(withSObjectType: "Account", soupName: "accounts", idFieldName: "IdX", modificationDateFieldName: "LastModifiedDateX"),
                        parentFieldlist: ["IdX", "Name", "Description"],
                        parentSoqlFilter: "NameX like 'James%'",
                        childrenInfo: SFChildrenInfo.new(withSObjectType: "Contact", sobjectTypePlural: "Contacts", soupName: "contacts", parentIdFieldName: "AccountId", idFieldName: "IdY", modificationDateFieldName: "LastModifiedDateY"),
                        childrenFieldlist: ["LastName", "AccountId"],
                        relationshipType: .masterDetail),
                    expectedOptions: SFSyncOptions.newSyncOptions(forSyncDown: .overwrite),
                    expectedStatus: .new,
                    expectedProgress: 0,
                    expectedTotalSize: -1)
    }

    func testNoBatchSyncUpFromConfig() {
        sdkManager?.setupUserSyncsFromDefaultConfig()

        guard let sync = syncManager.getSyncStatusByName("noBatchSyncUp") else {
            XCTFail("noBatchSyncUp should exist")
            return
        }
        XCTAssertEqual(sync.soupName, "accounts")
        checkStatus(sync,
                    expectedType: .up,
                    expectedId: sync.syncId,
                    expectedName: "noBatchSyncUp",
                    expectedTarget: SFSyncUpTarget(createFieldlist: ["Name"], updateFieldlist: ["Description"]),
                    expectedOptions: SFSyncOptions.newSyncOptions(forSyncUp: [], mergeMode: .leaveIfChanged),
                    expectedStatus: .new,
                    expectedProgress: 0,
                    expectedTotalSize: -1)
    }

    func testBatchSyncUpFromConfig() {
        sdkManager?.setupUserSyncsFromDefaultConfig()

        guard let sync = syncManager.getSyncStatusByName("batchSyncUp") else {
            XCTFail("batchSyncUp should exist")
            return
        }
        XCTAssertEqual(sync.soupName, "accounts")
        let expectedTarget = SFBatchSyncUpTarget(createFieldlist: nil, updateFieldlist: nil)
        expectedTarget.idFieldName = "IdX"
        expectedTarget.modificationDateFieldName = "LastModifiedDateX"
        expectedTarget.externalIdFieldName = "ExternalIdX"
        checkStatus(sync,
                    expectedType: .up,
                    expectedId: sync.syncId,
                    expectedName: "batchSyncUp",
                    expectedTarget: expectedTarget,
                    expectedOptions: SFSyncOptions.newSyncOptions(forSyncUp: ["Name", "Description"], mergeMode: .overwrite),
                    expectedStatus: .new,
                    expectedProgress: 0,
                    expectedTotalSize: -1)
    }

    func testParentChildrenSyncUpFromConfig() {
        sdkManager?.setupUserSyncsFromDefaultConfig()

        guard let sync = syncManager.getSyncStatusByName("parentChildrenSyncUp") else {
            XCTFail("parentChildrenSyncUp should exist")
            return
        }
        XCTAssertEqual(sync.soupName, "accounts")
        checkStatus(sync,
                    expectedType: .up,
                    expectedId: sync.syncId,
                    expectedName: "parentChildrenSyncUp",
                    expectedTarget: SFParentChildrenSyncUpTarget.newSyncTarget(
                        parentInfo: SFParentInfo.new(withSObjectType: "Account", soupName: "accounts", idFieldName: "IdX", modificationDateFieldName: "LastModifiedDateX", externalIdFieldName: "ExternalIdX"),
                        parentCreateFieldlist: ["IdX", "Name", "Description"],
                        parentUpdateFieldlist: ["Name", "Description"],
                        childrenInfo: SFChildrenInfo.new(withSObjectType: "Contact", sobjectTypePlural: "Contacts", soupName: "contacts", parentIdFieldName: "AccountId", idFieldName: "IdY", modificationDateFieldName: "LastModifiedDateY", externalIdFieldName: "ExternalIdY"),
                        childrenCreateFieldlist: ["LastName", "AccountId"],
                        childrenUpdateFieldlist: ["FirstName", "AccountId"],
                        relationshipType: .masterDetail),
                    expectedOptions: SFSyncOptions.newSyncOptions(forSyncUp: [], mergeMode: .leaveIfChanged),
                    expectedStatus: .new,
                    expectedProgress: 0,
                    expectedTotalSize: -1)
    }

    func testBriefcaseSyncDownFromConfig() {
        sdkManager?.setupUserSyncsFromDefaultConfig()

        guard let sync = syncManager.getSyncStatusByName("briefcaseSyncDown") else {
            XCTFail("briefcaseSyncDown should exist")
            return
        }
        checkStatus(sync,
                    expectedType: .down,
                    expectedId: sync.syncId,
                    expectedName: "briefcaseSyncDown",
                    expectedTarget: BriefcaseSyncDownTarget(infos: [
                        BriefcaseObjectInfo(soupName: "accounts", sobjectType: "Account", fieldlist: ["Name", "Description"], idFieldName: nil, modificationDateFieldName: nil),
                        BriefcaseObjectInfo(soupName: "contacts", sobjectType: "Contact", fieldlist: ["FirstName"], idFieldName: "IdX", modificationDateFieldName: "LastModifiedDateX")
                    ]),
                    expectedOptions: SFSyncOptions.newSyncOptions(forSyncDown: .overwrite),
                    expectedStatus: .new,
                    expectedProgress: 0,
                    expectedTotalSize: -1)
    }
}
