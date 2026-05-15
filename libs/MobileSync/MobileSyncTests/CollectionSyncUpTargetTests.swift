/*
 Copyright (c) 2022-present, salesforce.com, inc. All rights reserved.

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

class CollectionSyncUpTargetTests: SyncUpTargetTests {

    // MARK: - Tests

    func testMaxBatchSizeExceedingLimit() {
        let target = CollectionSyncUpTarget(createFieldlist: nil, updateFieldlist: nil, maxBatchSize: 201)
        XCTAssertEqual(target.maxBatchSize, 200, "Max batch size should be 200")
    }

    func testMaxBatchSizeExceedingLimitInDict() {
        let targetDict: [String: Any] = [kSFSyncTargetiOSImplKey: "SFCollectionSyncUpTarget", "maxBatchSize": 201]
        let target = CollectionSyncUpTarget(dict: targetDict)
        XCTAssertEqual(target.maxBatchSize, 200, "Max batch size should be 200")
    }

    func testConstructors() {
        var target = CollectionSyncUpTarget()
        XCTAssertNil(target.createFieldlist, "Wrong createFieldlist")
        XCTAssertNil(target.updateFieldlist, "Wrong updateFieldlist")
        XCTAssertEqual(target.maxBatchSize, 200, "Max batch size should be 200")

        target = CollectionSyncUpTarget(createFieldlist: ["Name"], updateFieldlist: ["Name", "Description"])
        XCTAssertEqual(target.createFieldlist?.count, 1, "Wrong createFieldlist")
        XCTAssertEqual(target.createFieldlist?[0], "Name", "Wrong createFieldlist")
        XCTAssertEqual(target.updateFieldlist?.count, 2, "Wrong updateFieldlist")
        XCTAssertEqual(target.updateFieldlist?[0], "Name", "Wrong updateFieldlist")
        XCTAssertEqual(target.updateFieldlist?[1], "Description", "Wrong updateFieldlist")
        XCTAssertEqual(target.maxBatchSize, 200, "Max batch size should be 200")

        target = CollectionSyncUpTarget(createFieldlist: ["Name"], updateFieldlist: ["Name", "Description"], maxBatchSize: 12)
        XCTAssertEqual(target.createFieldlist?.count, 1, "Wrong createFieldlist")
        XCTAssertEqual(target.createFieldlist?[0], "Name", "Wrong createFieldlist")
        XCTAssertEqual(target.updateFieldlist?.count, 2, "Wrong updateFieldlist")
        XCTAssertEqual(target.updateFieldlist?[0], "Name", "Wrong updateFieldlist")
        XCTAssertEqual(target.updateFieldlist?[1], "Description", "Wrong updateFieldlist")
        XCTAssertEqual(target.maxBatchSize, 12, "Max batch size should be 12")
    }

    func testFactoryMethodWithDict() {
        let targetDict: [String: Any] = [
            "createFieldlist": ["Name"],
            "updateFieldlist": ["Name", "Description"],
            "maxBatchSize": 12,
            kSFSyncTargetiOSImplKey: "SFCollectionSyncUpTarget"
        ]
        let target = CollectionSyncUpTarget(dict: targetDict)

        XCTAssertEqual(target.createFieldlist?.count, 1, "Wrong createFieldlist")
        XCTAssertEqual(target.createFieldlist?[0], "Name", "Wrong createFieldlist")
        XCTAssertEqual(target.updateFieldlist?.count, 2, "Wrong updateFieldlist")
        XCTAssertEqual(target.updateFieldlist?[0], "Name", "Wrong updateFieldlist")
        XCTAssertEqual(target.updateFieldlist?[1], "Description", "Wrong updateFieldlist")
        XCTAssertEqual(target.maxBatchSize, 12, "Max batch size should be 12")
    }

    func testFactoryMethodWithDictWithOptionalFields() {
        let targetDict: [String: Any] = [kSFSyncTargetiOSImplKey: "SFCollectionSyncUpTarget"]
        let target = CollectionSyncUpTarget(dict: targetDict)

        XCTAssertNil(target.createFieldlist, "Wrong createFieldlist")
        XCTAssertNil(target.updateFieldlist, "Wrong updateFieldlist")
        XCTAssertEqual(target.maxBatchSize, 200, "Max batch size should be 200")
    }

    func testAsDict() {
        let target = CollectionSyncUpTarget(createFieldlist: ["Name"], updateFieldlist: ["Name", "Description"], maxBatchSize: 12)
        let actualTargetDict = target.asDict()

        XCTAssertEqual(actualTargetDict[kSFSyncTargetiOSImplKey] as? String, "SFCollectionSyncUpTarget", "Wrong ios impl")
        XCTAssertEqual(actualTargetDict[kSFSyncTargetIdFieldNameKey] as? String, kId, "Wrong id field name")
        XCTAssertEqual(actualTargetDict[kSFSyncTargetModificationDateFieldNameKey] as? String, kLastModifiedDate, "Wrong modification date field name")
        XCTAssertEqual((actualTargetDict["createFieldlist"] as? [String])?.count, 1, "Wrong createFieldlist")
        XCTAssertEqual((actualTargetDict["createFieldlist"] as? [String])?[0], "Name", "Wrong createFieldlist")
        XCTAssertEqual((actualTargetDict["updateFieldlist"] as? [String])?.count, 2, "Wrong updateFieldlist")
        XCTAssertEqual((actualTargetDict["updateFieldlist"] as? [String])?[0], "Name", "Wrong updateFieldlist")
        XCTAssertEqual((actualTargetDict["updateFieldlist"] as? [String])?[1], "Description", "Wrong updateFieldlist")
        XCTAssertEqual(actualTargetDict["maxBatchSize"] as? Int, 12, "Wrong max batch size")
    }

    /// Test serialization and deserialization of SFSyncUpTargets to and from NSDictionary objects.
    func testSyncUpTargetSerialization() {
        // Basic sync up target should be the base class
        let basicSyncUpTarget = SyncUpTarget()
        XCTAssertTrue(type(of: basicSyncUpTarget) == SyncUpTarget.self, "Class should be SyncUpTarget")
        XCTAssertEqual(basicSyncUpTarget.targetType, .standard, "Sync up target type is incorrect.")

        // Default sync up target should be the CollectionSyncUpTarget
        let defaultSyncUpTarget = SyncUpTarget.newFromDict([:])
        XCTAssertTrue(type(of: defaultSyncUpTarget!) == CollectionSyncUpTarget.self, "Default class should be CollectionSyncUpTarget")
        XCTAssertEqual(defaultSyncUpTarget!.targetType, .standard, "Sync up target type is incorrect.")

        // Another way of getting the default sync up target
        let options = SFSyncOptions.newSyncOptions(forSyncUp: [NAME, DESCRIPTION], mergeMode: .overwrite)
        let syncUpState = SyncState.buildSyncUp(options: options, soupName: ACCOUNTS_SOUP, store: store)
        XCTAssertTrue(type(of: syncUpState!.target!) == CollectionSyncUpTarget.self, "Default sync up target should be CollectionSyncUpTarget")

        // Explicit rest sync up target type creates CollectionSyncUpTarget
        let restDict: [String: Any] = [kSFSyncTargetTypeKey: "rest"]
        let restTarget = SyncUpTarget.newFromDict(restDict)
        XCTAssertTrue(type(of: restTarget!) == CollectionSyncUpTarget.self, "Rest class should be CollectionSyncUpTarget")
        XCTAssertEqual(restTarget!.targetType, .standard, "Sync up target type is incorrect.")

        // Custom sync up target
        let customTarget = TestSyncUpTarget()
        let customDict = customTarget.asDict()
        XCTAssertEqual(customDict[kSFSyncTargetiOSImplKey] as? String, NSStringFromClass(TestSyncUpTarget.self), "Custom class is incorrect.")
        let customTargetFromDict = SyncUpTarget.newFromDict(customDict)
        XCTAssertTrue(type(of: customTargetFromDict!) == TestSyncUpTarget.self, "Custom class is incorrect.")
    }

    // MARK: - THE methods responsible for building sync up targets used in all the tests

    override func buildSyncUpTarget(createFieldlist: [String]?, updateFieldlist: [String]?) -> SyncUpTarget {
        return CollectionSyncUpTarget(createFieldlist: createFieldlist, updateFieldlist: updateFieldlist)
    }
}
