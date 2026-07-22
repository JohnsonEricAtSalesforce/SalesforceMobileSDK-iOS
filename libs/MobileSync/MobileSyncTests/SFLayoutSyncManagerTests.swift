/*
 SFLayoutSyncManagerTests.swift
 MobileSync

 Created by Bharath Hariharan on 5/22/18.

 Copyright (c) 2018-present, salesforce.com, inc. All rights reserved.

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

class SFLayoutSyncManagerTests: SyncManagerTestCase {

    private static let kMedium = "Medium"
    private static let kCompact = "Compact"
    private static let kEdit = "Edit"
    private static let kSoupName = "sfdcLayouts"
    private static let kQuery = "SELECT {%@:_soup} FROM {%@} WHERE {%@:Id} = '%@-%@-%@-%@-%@'"

    private var layoutSyncManager: SFLayoutSyncManager?

    override func setUp() {
        super.setUp()
        layoutSyncManager = SFLayoutSyncManager.sharedInstance()
    }

    override func tearDown() {
        SFMobileSyncSyncManager.removeSharedInstances()
        layoutSyncManager?.smartStore.removeAllSoups()
        SFLayoutSyncManager.reset()
        super.tearDown()
    }

    /// Test for fetching layout in cacheOnly mode.
    func testFetchLayoutInCacheOnlyMode() {
        let fetchLayoutServerFirst = expectation(description: "fetchLayoutServerFirst")
        layoutSyncManager?.fetchLayout(forObjectAPIName: kAccount, formFactor: Self.kMedium, layoutType: Self.kCompact, mode: Self.kEdit, recordTypeId: nil, syncMode: .serverFirst) { _, _, _, _, _, _ in
            fetchLayoutServerFirst.fulfill()
        }
        waitForExpectations(timeout: 30.0, handler: nil)

        var objectAPINameBlock: String?
        var formFactorBlock: String?
        var layoutTypeBlock: String?
        var modeBlock: String?
        var recordTypeIdBlock: String?
        var layoutBlock: SFLayout?

        let fetchLayoutCacheOnly = expectation(description: "fetchLayoutCacheOnly")
        layoutSyncManager?.fetchLayout(forObjectAPIName: kAccount, formFactor: Self.kMedium, layoutType: Self.kCompact, mode: Self.kEdit, recordTypeId: nil, syncMode: .cacheOnly) { objectAPIName, formFactor, layoutType, mode, recordTypeId, layout in
            objectAPINameBlock = objectAPIName
            formFactorBlock = formFactor
            layoutTypeBlock = layoutType
            modeBlock = mode
            recordTypeIdBlock = recordTypeId
            layoutBlock = layout
            fetchLayoutCacheOnly.fulfill()
        }
        waitForExpectations(timeout: 30.0, handler: nil)
        validateResult(objectAPIName: objectAPINameBlock, formFactor: formFactorBlock, layoutType: layoutTypeBlock, mode: modeBlock, recordTypeId: recordTypeIdBlock, layout: layoutBlock)
    }

    /// Test for fetching layout in cacheFirst mode with a hydrated cache.
    func testFetchLayoutInCacheFirstModeWithCacheData() {
        let fetchLayoutServerFirst = expectation(description: "fetchLayoutServerFirst")
        layoutSyncManager?.fetchLayout(forObjectAPIName: kAccount, formFactor: Self.kMedium, layoutType: Self.kCompact, mode: Self.kEdit, recordTypeId: nil, syncMode: .serverFirst) { _, _, _, _, _, _ in
            fetchLayoutServerFirst.fulfill()
        }
        waitForExpectations(timeout: 30.0, handler: nil)

        var objectAPINameBlock: String?
        var formFactorBlock: String?
        var layoutTypeBlock: String?
        var modeBlock: String?
        var recordTypeIdBlock: String?
        var layoutBlock: SFLayout?

        let fetchLayoutCacheFirst = expectation(description: "fetchLayoutCacheFirst")
        layoutSyncManager?.fetchLayout(forObjectAPIName: kAccount, formFactor: Self.kMedium, layoutType: Self.kCompact, mode: Self.kEdit, recordTypeId: nil, syncMode: .cacheFirst) { objectAPIName, formFactor, layoutType, mode, recordTypeId, layout in
            objectAPINameBlock = objectAPIName
            formFactorBlock = formFactor
            layoutTypeBlock = layoutType
            modeBlock = mode
            recordTypeIdBlock = recordTypeId
            layoutBlock = layout
            fetchLayoutCacheFirst.fulfill()
        }
        waitForExpectations(timeout: 30.0, handler: nil)
        validateResult(objectAPIName: objectAPINameBlock, formFactor: formFactorBlock, layoutType: layoutTypeBlock, mode: modeBlock, recordTypeId: recordTypeIdBlock, layout: layoutBlock)
    }

    /// Test for fetching layout in cacheFirst mode with an empty cache.
    func testFetchLayoutInCacheFirstModeWithoutCacheData() {
        var objectAPINameBlock: String?
        var formFactorBlock: String?
        var layoutTypeBlock: String?
        var modeBlock: String?
        var recordTypeIdBlock: String?
        var layoutBlock: SFLayout?

        let fetchLayoutCacheFirst = expectation(description: "fetchLayoutCacheFirst")
        layoutSyncManager?.fetchLayout(forObjectAPIName: kAccount, formFactor: Self.kMedium, layoutType: Self.kCompact, mode: Self.kEdit, recordTypeId: nil, syncMode: .cacheFirst) { objectAPIName, formFactor, layoutType, mode, recordTypeId, layout in
            objectAPINameBlock = objectAPIName
            formFactorBlock = formFactor
            layoutTypeBlock = layoutType
            modeBlock = mode
            recordTypeIdBlock = recordTypeId
            layoutBlock = layout
            fetchLayoutCacheFirst.fulfill()
        }
        waitForExpectations(timeout: 30.0, handler: nil)
        validateResult(objectAPIName: objectAPINameBlock, formFactor: formFactorBlock, layoutType: layoutTypeBlock, mode: modeBlock, recordTypeId: recordTypeIdBlock, layout: layoutBlock)
    }

    /// Test for fetching layout in serverFirst mode.
    func testFetchLayoutInServerFirstMode() {
        var objectAPINameBlock: String?
        var formFactorBlock: String?
        var layoutTypeBlock: String?
        var modeBlock: String?
        var recordTypeIdBlock: String?
        var layoutBlock: SFLayout?

        let fetchLayoutServerFirst = expectation(description: "fetchLayoutServerFirst")
        layoutSyncManager?.fetchLayout(forObjectAPIName: kAccount, formFactor: Self.kMedium, layoutType: Self.kCompact, mode: Self.kEdit, recordTypeId: nil, syncMode: .serverFirst) { objectAPIName, formFactor, layoutType, mode, recordTypeId, layout in
            objectAPINameBlock = objectAPIName
            formFactorBlock = formFactor
            layoutTypeBlock = layoutType
            modeBlock = mode
            recordTypeIdBlock = recordTypeId
            layoutBlock = layout
            fetchLayoutServerFirst.fulfill()
        }
        waitForExpectations(timeout: 30.0, handler: nil)
        validateResult(objectAPIName: objectAPINameBlock, formFactor: formFactorBlock, layoutType: layoutTypeBlock, mode: modeBlock, recordTypeId: recordTypeIdBlock, layout: layoutBlock)
    }

    /// Test for fetching layout multiple times and ensuring only 1 row is created.
    func testFetchLayoutMultipleTimes() {
        var objectAPINameBlock: String?
        var formFactorBlock: String?
        var layoutTypeBlock: String?
        var modeBlock: String?
        var recordTypeIdBlock: String?
        var layoutBlock: SFLayout?

        let fetchLayoutOne = expectation(description: "fetchLayoutOne")
        layoutSyncManager?.fetchLayout(forObjectAPIName: kAccount, formFactor: Self.kMedium, layoutType: Self.kCompact, mode: Self.kEdit, recordTypeId: nil, syncMode: .serverFirst) { objectAPIName, formFactor, layoutType, mode, recordTypeId, layout in
            objectAPINameBlock = objectAPIName
            formFactorBlock = formFactor
            layoutTypeBlock = layoutType
            modeBlock = mode
            recordTypeIdBlock = recordTypeId
            layoutBlock = layout
            fetchLayoutOne.fulfill()
        }
        waitForExpectations(timeout: 30.0, handler: nil)
        validateResult(objectAPIName: objectAPINameBlock, formFactor: formFactorBlock, layoutType: layoutTypeBlock, mode: modeBlock, recordTypeId: recordTypeIdBlock, layout: layoutBlock)

        let fetchLayoutTwo = expectation(description: "fetchLayoutTwo")
        layoutSyncManager?.fetchLayout(forObjectAPIName: kAccount, formFactor: Self.kMedium, layoutType: Self.kCompact, mode: Self.kEdit, recordTypeId: nil, syncMode: .serverFirst) { objectAPIName, formFactor, layoutType, mode, recordTypeId, layout in
            objectAPINameBlock = objectAPIName
            formFactorBlock = formFactor
            layoutTypeBlock = layoutType
            modeBlock = mode
            recordTypeIdBlock = recordTypeId
            layoutBlock = layout
            fetchLayoutTwo.fulfill()
        }
        waitForExpectations(timeout: 30.0, handler: nil)
        validateResult(objectAPIName: objectAPINameBlock, formFactor: formFactorBlock, layoutType: layoutTypeBlock, mode: modeBlock, recordTypeId: recordTypeIdBlock, layout: layoutBlock)

        // A nil recordTypeId is stored/fetched by production as an empty segment (recordTypeId ?? ""), so the
        // soup Id is "Account-Medium-Compact-Edit-". The ObjC oracle passed a real nil to stringWithFormat (→
        // "(null)") on BOTH the store and this query, so they matched; the Swift port storage uses "" instead,
        // and this query must match that. (Original port hardcoded the literal "nil" here → 0 rows.)
        let sql = String(format: Self.kQuery, Self.kSoupName, Self.kSoupName, Self.kSoupName, kAccount, Self.kMedium, Self.kCompact, Self.kEdit, "")
        guard let querySpec = QuerySpec.buildSmartQuerySpec(smartSql: sql, pageSize: 2),
              let smartStore = layoutSyncManager?.smartStore else {
            XCTFail("Failed to build query spec or get smart store")
            return
        }
        let numRows = (try? smartStore.count(using: querySpec))?.intValue ?? 0
        XCTAssertEqual(numRows, 1, "Number of rows should be 1")
    }

    // MARK: - Helper

    private func validateResult(objectAPIName: String?, formFactor: String?, layoutType: String?, mode: String?, recordTypeId: String?, layout: SFLayout?) {
        XCTAssertEqual(objectAPIName, kAccount, "Object types should match")
        XCTAssertEqual(formFactor, Self.kMedium, "Form factors should match")
        XCTAssertNotNil(layout, "Layout data should not be nil")
        XCTAssertEqual(layout?.layoutType, Self.kCompact, "Layout types should match")
        XCTAssertEqual(mode, Self.kEdit, "Modes should match")
        XCTAssertNotNil(layout?.rawData, "Layout raw data should not be nil")
        XCTAssertNotNil(layout?.sections, "Layout sections should not be nil")
        XCTAssertTrue((layout?.sections?.count ?? 0) > 0, "Number of layout sections should be 1 or more")
        XCTAssertNotNil(layout?.sections?[0].layoutRows, "Layout rows for a section should not be nil")
        XCTAssertTrue((layout?.sections?[0].layoutRows?.count ?? 0) > 0, "Number of layout rows for a section should be 1 or more")
        XCTAssertNotNil(layout?.sections?[0].layoutRows?[0].layoutItems, "Layout items for a row should not be nil")
        XCTAssertTrue((layout?.sections?[0].layoutRows?[0].layoutItems?.count ?? 0) > 0, "Number of layout items for a row should be 1 or more")

        guard let layoutItem = layout?.sections?[0].layoutRows?[0].layoutItems?[0] else {
            XCTFail("Layout item should exist")
            return
        }
        XCTAssertFalse(layoutItem.sortable, "Sortable should be false")
        XCTAssertTrue(layoutItem.editableForNew, "Editable should be true")
        XCTAssertTrue((layoutItem.layoutComponents?.count ?? 0) > 0, "Number of layout components for an item should be 1 or more")
        XCTAssertTrue((layoutItem.layoutComponents?[0].keys.count ?? 0) > 1, "Layout component fields should be 2 or more")
    }
}
