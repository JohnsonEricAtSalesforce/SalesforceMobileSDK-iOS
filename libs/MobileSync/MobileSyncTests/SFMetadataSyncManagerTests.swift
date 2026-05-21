/*
 SFMetadataSyncManagerTests.swift
 MobileSync

 Created by Bharath Hariharan on 5/24/18.

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

class SFMetadataSyncManagerTests: SyncManagerTestCase {

    private static let kAccountKeyPrefix = "001"
    private static let kSoupName = "sfdcMetadata"
    private static let kQuery = "SELECT {%@:_soup} FROM {%@} WHERE {%@:Id} = '%@'"

    private var metadataSyncManager: SFMetadataSyncManager?

    override func setUp() {
        super.setUp()
        metadataSyncManager = SFMetadataSyncManager.sharedInstance()
    }

    override func tearDown() {
        SFMobileSyncSyncManager.removeSharedInstances()
        metadataSyncManager?.smartStore.removeAllSoups()
        SFMetadataSyncManager.reset()
        super.tearDown()
    }

    /// Test for fetching metadata in cacheOnly mode.
    func testFetchMetadataInCacheOnlyMode() {
        let fetchMetadataServerFirst = expectation(description: "fetchMetadataServerFirst")
        metadataSyncManager?.fetchMetadata(forObject: kAccount, mode: .serverFirst) { _ in
            fetchMetadataServerFirst.fulfill()
        }
        waitForExpectations(timeout: 30.0, handler: nil)

        var metadataResult: SFMetadata?
        let fetchMetadataCacheOnly = expectation(description: "fetchMetadataCacheOnly")
        metadataSyncManager?.fetchMetadata(forObject: kAccount, mode: .cacheOnly) { metadata in
            metadataResult = metadata
            fetchMetadataCacheOnly.fulfill()
        }
        waitForExpectations(timeout: 30.0, handler: nil)
        validateResult(metadataResult)
    }

    /// Test for fetching metadata in cacheFirst mode with a hydrated cache.
    func testFetchMetadataInCacheFirstModeWithCacheData() {
        let fetchMetadataServerFirst = expectation(description: "fetchMetadataServerFirst")
        metadataSyncManager?.fetchMetadata(forObject: kAccount, mode: .serverFirst) { _ in
            fetchMetadataServerFirst.fulfill()
        }
        waitForExpectations(timeout: 30.0, handler: nil)

        var metadataResult: SFMetadata?
        let fetchMetadataCacheFirst = expectation(description: "fetchMetadataCacheFirst")
        metadataSyncManager?.fetchMetadata(forObject: kAccount, mode: .cacheFirst) { metadata in
            metadataResult = metadata
            fetchMetadataCacheFirst.fulfill()
        }
        waitForExpectations(timeout: 30.0, handler: nil)
        validateResult(metadataResult)
    }

    /// Test for fetching metadata in cacheFirst mode with an empty cache.
    func testFetchMetadataInCacheFirstModeWithoutCacheData() {
        var metadataResult: SFMetadata?
        let fetchMetadataCacheFirst = expectation(description: "fetchMetadataCacheFirst")
        metadataSyncManager?.fetchMetadata(forObject: kAccount, mode: .cacheFirst) { metadata in
            metadataResult = metadata
            fetchMetadataCacheFirst.fulfill()
        }
        waitForExpectations(timeout: 30.0, handler: nil)
        validateResult(metadataResult)
    }

    /// Test for fetching metadata in serverFirst mode.
    func testFetchMetadataInServerFirstMode() {
        var metadataResult: SFMetadata?
        let fetchMetadataServerFirst = expectation(description: "fetchMetadataServerFirst")
        metadataSyncManager?.fetchMetadata(forObject: kAccount, mode: .serverFirst) { metadata in
            metadataResult = metadata
            fetchMetadataServerFirst.fulfill()
        }
        waitForExpectations(timeout: 30.0, handler: nil)
        validateResult(metadataResult)
    }

    /// Test for fetching metadata multiple times and ensuring only 1 row is created.
    func testFetchMetadataMultipleTimes() {
        var metadataResult: SFMetadata?
        let fetchMetadataOne = expectation(description: "fetchMetadataOne")
        metadataSyncManager?.fetchMetadata(forObject: kAccount, mode: .serverFirst) { metadata in
            metadataResult = metadata
            fetchMetadataOne.fulfill()
        }
        waitForExpectations(timeout: 30.0, handler: nil)
        validateResult(metadataResult)

        let fetchMetadataTwo = expectation(description: "fetchMetadataTwo")
        metadataSyncManager?.fetchMetadata(forObject: kAccount, mode: .serverFirst) { metadata in
            metadataResult = metadata
            fetchMetadataTwo.fulfill()
        }
        waitForExpectations(timeout: 30.0, handler: nil)
        validateResult(metadataResult)

        let sql = String(format: Self.kQuery, Self.kSoupName, Self.kSoupName, Self.kSoupName, kAccount)
        guard let querySpec = QuerySpec.buildSmartQuerySpec(smartSql: sql, pageSize: 2),
              let smartStore = metadataSyncManager?.smartStore else {
            XCTFail("Failed to build query spec or get smart store")
            return
        }
        let numRows = (try? smartStore.count(using: querySpec))?.intValue ?? 0
        XCTAssertEqual(numRows, 1, "Number of rows should be 1")
    }

    // MARK: - Helper

    private func validateResult(_ metadata: SFMetadata?) {
        XCTAssertNotNil(metadata, "Metadata should not be nil")
        XCTAssertEqual(metadata?.name, kAccount, "Object types should match")
        XCTAssertNotNil(metadata?.rawData, "Metadata raw data should not be nil")
        XCTAssertTrue(metadata?.compactLayoutable ?? false, "Object should be compact layoutable")
        XCTAssertTrue(metadata?.createable ?? false, "Object should be createable")
        XCTAssertNotNil(metadata?.childRelationships, "Child relationships should not be nil")
        XCTAssertNotNil(metadata?.fields, "Fields should not be nil")
        XCTAssertNotNil(metadata?.urls, "URLs should not be nil")
        XCTAssertTrue(metadata?.searchable ?? false, "Object should be searchable")
        XCTAssertEqual(metadata?.keyPrefix, Self.kAccountKeyPrefix, "Object key prefixes should match")
        XCTAssertEqual(metadata?.label, kAccount, "Object labels should match")
    }
}
