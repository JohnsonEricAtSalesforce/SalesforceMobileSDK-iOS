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

class SFSDKSyncsConfigTests: SyncManagerTestCase {

    var sdkManager: MobileSyncSDKManager!

    override func setUp() {
        super.setUp()
        SFSDKMobileSyncLogger.setLogLevel(.debug)
        sdkManager = MobileSyncSDKManager()
    }

    override func tearDown() {
        sdkManager = nil
        super.tearDown()
    }

    func testSetupGlobalSyncsFromDefaultConfig() {
        XCTAssertFalse(globalSyncManager.hasSync(forName: "globalSync1"))
        XCTAssertFalse(globalSyncManager.hasSync(forName: "globalSync2"))

        // Setting up syncs
        sdkManager.setupGlobalSyncsFromDefaultConfig()

        // Checking smartstore
        XCTAssertTrue(globalSyncManager.hasSync(forName: "globalSync1"))
        XCTAssertTrue(globalSyncManager.hasSync(forName: "globalSync2"))

        // Checking first sync in details
        let actualSync1 = globalSyncManager.syncStatus(forName: "globalSync1")!
        XCTAssertEqual(actualSync1.soupName, "accounts")
        checkStatus(actualSync1,
                    expectedType: .down,
                    expectedId: actualSync1.syncId,
                    expectedName: "globalSync1",
                    expectedTarget: SoqlSyncDownTarget.newSyncTarget("SELECT Id, Name, LastModifiedDate FROM Account"),
                    expectedOptions: SFSyncOptions.newSyncOptions(forSyncDown: .overwrite),
                    expectedStatus: .new,
                    expectedProgress: 0,
                    expectedTotalSize: -1)

        // Checking second sync in details
        let actualSync2 = globalSyncManager.syncStatus(forName: "globalSync2")!
        XCTAssertEqual(actualSync2.soupName, "accounts")
        checkStatus(actualSync2,
                    expectedType: .up,
                    expectedId: actualSync2.syncId,
                    expectedName: "globalSync2",
                    expectedTarget: BatchSyncUpTarget(createFieldlist: ["Name"], updateFieldlist: nil),
                    expectedOptions: SFSyncOptions.newSyncOptions(forSyncUp: ["Id", "Name", "LastModifiedDate"], mergeMode: .leaveIfChanged),
                    expectedStatus: .new,
                    expectedProgress: 0,
                    expectedTotalSize: -1)
    }

    func testSetupUserSyncsFromDefaultConfig() {
        XCTAssertFalse(syncManager.hasSync(forName: "soqlSyncDown"))
        XCTAssertFalse(syncManager.hasSync(forName: "soslSyncDown"))
        XCTAssertFalse(syncManager.hasSync(forName: "mruSyncDown"))
        XCTAssertFalse(syncManager.hasSync(forName: "refreshSyncDown"))
        XCTAssertFalse(syncManager.hasSync(forName: "layoutSyncDown"))
        XCTAssertFalse(syncManager.hasSync(forName: "metadataSyncDown"))
        XCTAssertFalse(syncManager.hasSync(forName: "parentChildrenSyncDown"))
        XCTAssertFalse(syncManager.hasSync(forName: "noBatchSyncUp"))
        XCTAssertFalse(syncManager.hasSync(forName: "batchSyncUp"))
        XCTAssertFalse(syncManager.hasSync(forName: "parentChildrenSyncUp"))

        // Setting up syncs
        sdkManager.setupUserSyncsFromDefaultConfig()

        // Checking smartstore
        XCTAssertTrue(syncManager.hasSync(forName: "soqlSyncDown"))
        XCTAssertTrue(syncManager.hasSync(forName: "soslSyncDown"))
        XCTAssertTrue(syncManager.hasSync(forName: "mruSyncDown"))
        XCTAssertTrue(syncManager.hasSync(forName: "refreshSyncDown"))
        XCTAssertTrue(syncManager.hasSync(forName: "layoutSyncDown"))
        XCTAssertTrue(syncManager.hasSync(forName: "metadataSyncDown"))
        XCTAssertTrue(syncManager.hasSync(forName: "parentChildrenSyncDown"))
        XCTAssertTrue(syncManager.hasSync(forName: "noBatchSyncUp"))
        XCTAssertTrue(syncManager.hasSync(forName: "batchSyncUp"))
        XCTAssertTrue(syncManager.hasSync(forName: "parentChildrenSyncUp"))
    }

    func testSoqlSyncDownFromConfig() {
        sdkManager.setupUserSyncsFromDefaultConfig()

        let sync = syncManager.syncStatus(forName: "soqlSyncDown")!
        XCTAssertEqual(sync.soupName, "accounts")
        checkStatus(sync,
                    expectedType: .down,
                    expectedId: sync.syncId,
                    expectedName: "soqlSyncDown",
                    expectedTarget: SoqlSyncDownTarget.newSyncTarget("SELECT Id, Name, LastModifiedDate FROM Account"),
                    expectedOptions: SFSyncOptions.newSyncOptions(forSyncDown: .overwrite),
                    expectedStatus: .new,
                    expectedProgress: 0,
                    expectedTotalSize: -1)
    }

    func testSoqlSyncDownWithBatchSizeFromConfig() {
        sdkManager.setupUserSyncsFromDefaultConfig()

        let sync = syncManager.syncStatus(forName: "soqlSyncDownWithBatchSize")!
        XCTAssertEqual(sync.soupName, "accounts")
        checkStatus(sync,
                    expectedType: .down,
                    expectedId: sync.syncId,
                    expectedName: "soqlSyncDown",
                    expectedTarget: SoqlSyncDownTarget.newSyncTarget("SELECT Id, Name, LastModifiedDate FROM Account", maxBatchSize: 200),
                    expectedOptions: SFSyncOptions.newSyncOptions(forSyncDown: .overwrite),
                    expectedStatus: .new,
                    expectedProgress: 0,
                    expectedTotalSize: -1)
    }

    func testSoslSyncDownFromConfig() {
        sdkManager.setupUserSyncsFromDefaultConfig()

        let sync = syncManager.syncStatus(forName: "soslSyncDown")!
        XCTAssertEqual(sync.soupName, "accounts")
        checkStatus(sync,
                    expectedType: .down,
                    expectedId: sync.syncId,
                    expectedName: "soslSyncDown",
                    expectedTarget: SoslSyncDownTarget.newSyncTarget("FIND {Joe} IN NAME FIELDS RETURNING Account"),
                    expectedOptions: SFSyncOptions.newSyncOptions(forSyncDown: .leaveIfChanged),
                    expectedStatus: .new,
                    expectedProgress: 0,
                    expectedTotalSize: -1)
    }

    func testMruSyncDownFromConfig() {
        sdkManager.setupUserSyncsFromDefaultConfig()

        let sync = syncManager.syncStatus(forName: "mruSyncDown")!
        XCTAssertEqual(sync.soupName, "accounts")
        checkStatus(sync,
                    expectedType: .down,
                    expectedId: sync.syncId,
                    expectedName: "mruSyncDown",
                    expectedTarget: MruSyncDownTarget.newSyncTarget("Account", fieldlist: ["Name", "Description"]),
                    expectedOptions: SFSyncOptions.newSyncOptions(forSyncDown: .overwrite),
                    expectedStatus: .new,
                    expectedProgress: 0,
                    expectedTotalSize: -1)
    }

    func testRefreshSyncDownFromConfig() {
        sdkManager.setupUserSyncsFromDefaultConfig()

        let sync = syncManager.syncStatus(forName: "refreshSyncDown")!
        XCTAssertEqual(sync.soupName, "accounts")
        checkStatus(sync,
                    expectedType: .down,
                    expectedId: sync.syncId,
                    expectedName: "refreshSyncDown",
                    expectedTarget: RefreshSyncDownTarget.newSyncTarget("accounts", objectType: "Account", fieldlist: ["Name", "Description"]),
                    expectedOptions: SFSyncOptions.newSyncOptions(forSyncDown: .leaveIfChanged),
                    expectedStatus: .new,
                    expectedProgress: 0,
                    expectedTotalSize: -1)
    }

    func testLayoutSyncDownFromConfig() {
        sdkManager.setupUserSyncsFromDefaultConfig()

        let sync = syncManager.syncStatus(forName: "layoutSyncDown")!
        XCTAssertEqual(sync.soupName, "accounts")
        checkStatus(sync,
                    expectedType: .down,
                    expectedId: sync.syncId,
                    expectedName: "layoutSyncDown",
                    expectedTarget: LayoutSyncDownTarget.newSyncTarget("Account", formFactor: "Medium", layoutType: "Compact", mode: "Edit", recordTypeId: nil),
                    expectedOptions: SFSyncOptions.newSyncOptions(forSyncDown: .overwrite),
                    expectedStatus: .new,
                    expectedProgress: 0,
                    expectedTotalSize: -1)
    }

    func testMetadataSyncDownFromConfig() {
        sdkManager.setupUserSyncsFromDefaultConfig()

        let sync = syncManager.syncStatus(forName: "metadataSyncDown")!
        XCTAssertEqual(sync.soupName, "accounts")
        checkStatus(sync,
                    expectedType: .down,
                    expectedId: sync.syncId,
                    expectedName: "metadataSyncDown",
                    expectedTarget: MetadataSyncDownTarget.newSyncTarget("Account"),
                    expectedOptions: SFSyncOptions.newSyncOptions(forSyncDown: .leaveIfChanged),
                    expectedStatus: .new,
                    expectedProgress: 0,
                    expectedTotalSize: -1)
    }

    func testParentChildrenSyncDownFromConfig() {
        sdkManager.setupUserSyncsFromDefaultConfig()

        let sync = syncManager.syncStatus(forName: "parentChildrenSyncDown")!
        XCTAssertEqual(sync.soupName, "accounts")
        checkStatus(sync,
                    expectedType: .down,
                    expectedId: sync.syncId,
                    expectedName: "parentChildrenSyncDown",
                    expectedTarget: ParentChildrenSyncDownTarget.newSyncTarget(
                        withParentInfo: SFParentInfo.new(sobjectType: "Account", soupName: "accounts", idFieldName: "IdX", modificationDateFieldName: "LastModifiedDateX"),
                        parentFieldlist: ["IdX", "Name", "Description"],
                        parentSoqlFilter: "NameX like 'James%'",
                        childrenInfo: SFChildrenInfo.new(sobjectType: "Contact", sobjectTypePlural: "Contacts", soupName: "contacts", parentIdFieldName: "AccountId", idFieldName: "IdY", modificationDateFieldName: "LastModifiedDateY"),
                        childrenFieldlist: ["LastName", "AccountId"],
                        relationshipType: .masterDetail),
                    expectedOptions: SFSyncOptions.newSyncOptions(forSyncDown: .overwrite),
                    expectedStatus: .new,
                    expectedProgress: 0,
                    expectedTotalSize: -1)
    }

    func testNoBatchSyncUpFromConfig() {
        sdkManager.setupUserSyncsFromDefaultConfig()

        let sync = syncManager.syncStatus(forName: "noBatchSyncUp")!
        XCTAssertEqual(sync.soupName, "accounts")
        checkStatus(sync,
                    expectedType: .up,
                    expectedId: sync.syncId,
                    expectedName: "noBatchSyncUp",
                    expectedTarget: SyncUpTarget(createFieldlist: ["Name"], updateFieldlist: ["Description"]),
                    expectedOptions: SFSyncOptions.newSyncOptions(forSyncUp: [], mergeMode: .leaveIfChanged),
                    expectedStatus: .new,
                    expectedProgress: 0,
                    expectedTotalSize: -1)
    }

    func testBatchSyncUpFromConfig() {
        sdkManager.setupUserSyncsFromDefaultConfig()

        let sync = syncManager.syncStatus(forName: "batchSyncUp")!
        XCTAssertEqual(sync.soupName, "accounts")
        let expectedTarget = BatchSyncUpTarget(createFieldlist: nil, updateFieldlist: nil)
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
        sdkManager.setupUserSyncsFromDefaultConfig()

        let sync = syncManager.syncStatus(forName: "parentChildrenSyncUp")!
        XCTAssertEqual(sync.soupName, "accounts")
        checkStatus(sync,
                    expectedType: .up,
                    expectedId: sync.syncId,
                    expectedName: "parentChildrenSyncUp",
                    expectedTarget: ParentChildrenSyncUpTarget.newSyncTarget(
                        withParentInfo: SFParentInfo.new(sobjectType: "Account", soupName: "accounts", idFieldName: "IdX", modificationDateFieldName: "LastModifiedDateX", externalIdFieldName: "ExternalIdX"),
                        parentCreateFieldlist: ["IdX", "Name", "Description"],
                        parentUpdateFieldlist: ["Name", "Description"],
                        childrenInfo: SFChildrenInfo.new(sobjectType: "Contact", sobjectTypePlural: "Contacts", soupName: "contacts", parentIdFieldName: "AccountId", idFieldName: "IdY", modificationDateFieldName: "LastModifiedDateY", externalIdFieldName: "ExternalIdY"),
                        childrenCreateFieldlist: ["LastName", "AccountId"],
                        childrenUpdateFieldlist: ["FirstName", "AccountId"],
                        relationshipType: .masterDetail),
                    expectedOptions: SFSyncOptions.newSyncOptions(forSyncUp: [], mergeMode: .leaveIfChanged),
                    expectedStatus: .new,
                    expectedProgress: 0,
                    expectedTotalSize: -1)
    }

    func testBriefcaseSyncDownFromConfig() {
        sdkManager.setupUserSyncsFromDefaultConfig()
        let sync = syncManager.syncStatus(forName: "briefcaseSyncDown")!

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
