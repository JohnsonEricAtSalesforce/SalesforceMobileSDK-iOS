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
@testable import MobileSync

class BatchSyncUpTargetTests: SyncUpTargetTests {

    // MARK: - Tests

    func testMaxBatchSizeExceedingLimit() {
        let target = BatchSyncUpTarget(createFieldlist: nil, updateFieldlist: nil, maxBatchSize: 26)
        XCTAssertEqual(target.maxBatchSize, 25, "Max batch size should be 25")
    }

    func testMaxBatchSizeExceedingLimitInDict() {
        let targetDict: [String: Any] = [kSFSyncTargetiOSImplKey: "SFBatchSyncUpTarget", "maxBatchSize": 26]
        let target = BatchSyncUpTarget(dict: targetDict)
        XCTAssertEqual(target.maxBatchSize, 25, "Max batch size should be 25")
    }

    func testConstructors() {
        var target = BatchSyncUpTarget()
        XCTAssertNil(target.createFieldlist, "Wrong createFieldlist")
        XCTAssertNil(target.updateFieldlist, "Wrong updateFieldlist")
        XCTAssertEqual(target.maxBatchSize, 25, "Max batch size should be 25")

        target = BatchSyncUpTarget(createFieldlist: ["Name"], updateFieldlist: ["Name", "Description"])
        XCTAssertEqual(target.createFieldlist?.count, 1, "Wrong createFieldlist")
        XCTAssertEqual(target.createFieldlist?[0], "Name", "Wrong createFieldlist")
        XCTAssertEqual(target.updateFieldlist?.count, 2, "Wrong updateFieldlist")
        XCTAssertEqual(target.updateFieldlist?[0], "Name", "Wrong updateFieldlist")
        XCTAssertEqual(target.updateFieldlist?[1], "Description", "Wrong updateFieldlist")
        XCTAssertEqual(target.maxBatchSize, 25, "Max batch size should be 25")

        target = BatchSyncUpTarget(createFieldlist: ["Name"], updateFieldlist: ["Name", "Description"], maxBatchSize: 12)
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
            kSFSyncTargetiOSImplKey: "SFBatchSyncUpTarget"
        ]
        let target = BatchSyncUpTarget(dict: targetDict)

        XCTAssertEqual(target.createFieldlist?.count, 1, "Wrong createFieldlist")
        XCTAssertEqual(target.createFieldlist?[0], "Name", "Wrong createFieldlist")
        XCTAssertEqual(target.updateFieldlist?.count, 2, "Wrong updateFieldlist")
        XCTAssertEqual(target.updateFieldlist?[0], "Name", "Wrong updateFieldlist")
        XCTAssertEqual(target.updateFieldlist?[1], "Description", "Wrong updateFieldlist")
        XCTAssertEqual(target.maxBatchSize, 12, "Max batch size should be 12")
    }

    func testFactoryMethodWithDictWithOptionalFields() {
        let targetDict: [String: Any] = [kSFSyncTargetiOSImplKey: "SFBatchSyncUpTarget"]
        let target = BatchSyncUpTarget(dict: targetDict)

        XCTAssertNil(target.createFieldlist, "Wrong createFieldlist")
        XCTAssertNil(target.updateFieldlist, "Wrong updateFieldlist")
        XCTAssertEqual(target.maxBatchSize, 25, "Max batch size should be 25")
    }

    func testAsDict() {
        let target = BatchSyncUpTarget(createFieldlist: ["Name"], updateFieldlist: ["Name", "Description"], maxBatchSize: 12)
        let actualTargetDict = target.asDict()

        XCTAssertEqual(actualTargetDict[kSFSyncTargetiOSImplKey] as? String, "SFBatchSyncUpTarget", "Wrong ios impl")
        XCTAssertEqual(actualTargetDict[kSFSyncTargetIdFieldNameKey] as? String, kId, "Wrong id field name")
        XCTAssertEqual(actualTargetDict[kSFSyncTargetModificationDateFieldNameKey] as? String, kLastModifiedDate, "Wrong modification date field name")
        XCTAssertEqual((actualTargetDict["createFieldlist"] as? [String])?.count, 1, "Wrong createFieldlist")
        XCTAssertEqual((actualTargetDict["createFieldlist"] as? [String])?[0], "Name", "Wrong createFieldlist")
        XCTAssertEqual((actualTargetDict["updateFieldlist"] as? [String])?.count, 2, "Wrong updateFieldlist")
        XCTAssertEqual((actualTargetDict["updateFieldlist"] as? [String])?[0], "Name", "Wrong updateFieldlist")
        XCTAssertEqual((actualTargetDict["updateFieldlist"] as? [String])?[1], "Description", "Wrong updateFieldlist")
        XCTAssertEqual(actualTargetDict["maxBatchSize"] as? Int, 12, "Wrong max batch size")
    }

    // MARK: - THE methods responsible for building sync up targets used in all the tests

    override func buildSyncUpTarget(createFieldlist: [String]?, updateFieldlist: [String]?) -> SyncUpTarget {
        return BatchSyncUpTarget(createFieldlist: createFieldlist, updateFieldlist: updateFieldlist)
    }
}
