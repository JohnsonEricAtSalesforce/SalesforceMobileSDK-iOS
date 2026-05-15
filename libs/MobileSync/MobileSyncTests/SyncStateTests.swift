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
@testable import MobileSync

private let DB_NAME = "testDb"

final class SyncStateTests: XCTestCase {

    var store: SmartStore!

    override func setUp() {
        super.setUp()
        store = SmartStore.sharedGlobal(withName: DB_NAME)
    }

    override func tearDown() {
        SmartStore.removeSharedGlobal(withName: DB_NAME)
        super.tearDown()
    }

    // MARK: - Tests

    /// Make sure syncs soup gets properly setup the first time around
    func testSetupSyncsSoupFirstTime() {
        SyncState.setupSyncsSoupIfNeeded(store)
        checkSyncsSoupIndexSpecs(store)
    }

    /// Make sure syncs soup gets properly setup when upgrading to 7.1
    func testSetupSyncsSoupUpgradeTo71() {
        // Manually syncs soup the pre 7.1 way
        let indexSpecs = [
            SoupIndex(path: "type", indexType: kSoupIndexTypeString, columnName: nil)!,
            SoupIndex(path: "name", indexType: kSoupIndexTypeString, columnName: nil)!
        ]
        try? store.registerSoup(withName: kSFSyncStateSyncsSoupName, withIndices: indexSpecs)

        // Fix syncs soup
        SyncState.setupSyncsSoupIfNeeded(store)

        // Check the soup
        checkSyncsSoupIndexSpecs(store)
    }

    /// Make sure syncs marked as running are "cleaned up" after restart
    func testCleanupSyncsSoupIfNeeded() {
        SyncState.setupSyncsSoupIfNeeded(store)

        // Create syncs - some in the running state
        createSyncChangeStatus("newSyncUp", isSyncUp: true, status: .new)
        createSyncChangeStatus("stoppedSyncUp", isSyncUp: true, status: .stopped)
        createSyncChangeStatus("runningSyncUp", isSyncUp: true, status: .running)
        createSyncChangeStatus("failedSyncUp", isSyncUp: true, status: .failed)
        createSyncChangeStatus("doneSyncUp", isSyncUp: true, status: .done)
        createSyncChangeStatus("newSyncDown", isSyncUp: false, status: .new)
        createSyncChangeStatus("stoppedSyncDown", isSyncUp: false, status: .stopped)
        createSyncChangeStatus("runningSyncDown", isSyncUp: false, status: .running)
        createSyncChangeStatus("failedSyncDown", isSyncUp: false, status: .failed)
        createSyncChangeStatus("doneSyncDown", isSyncUp: false, status: .done)

        // Cleanup syncs soup
        SyncState.cleanupSyncsSoupIfNeeded(store)

        // Check the syncs
        checkSyncsSoupIndexSpecs(store)
    }

    // MARK: - Helper methods

    private func createSyncChangeStatus(_ name: String, isSyncUp: Bool, status: SyncStatus) {
        var sync: SyncState?
        if isSyncUp {
            sync = SyncState.buildSyncUp(
                options: SFSyncOptions.newSyncOptions(forSyncUp: ["Name"]),
                target: SyncUpTarget.newFromDict([:]),
                soupName: "Accounts",
                name: name,
                store: store
            )
        } else {
            sync = SyncState.buildSyncDown(
                options: SFSyncOptions.newSyncOptions(forSyncDown: .leaveIfChanged),
                target: SoqlSyncDownTarget.newSyncTarget("SELECT Id, Name from Account"),
                soupName: "Accounts",
                name: name,
                store: store
            )
        }
        sync?.status = status
        sync?.save(store)
    }

    private func checkSyncStatus(_ name: String, expectedStatus: SyncStatus) {
        let sync = SyncState.byName(name, store: store)
        XCTAssertEqual(expectedStatus, sync?.status)
    }

    private func checkSyncsSoupIndexSpecs(_ store: SmartStore) {
        let indexSpecs = store.indices(forSoupNamed: kSFSyncStateSyncsSoupName)
        XCTAssertEqual(3, indexSpecs.count, "Wrong number of index specs")

        let expectedPaths = ["name", "type", "status"]
        for indexSpec in indexSpecs {
            XCTAssertTrue(expectedPaths.contains(indexSpec.path), "Wrong index spec path")
            XCTAssertEqual("json1", indexSpec.indexType, "Wrong index spec type")
        }
    }
}
