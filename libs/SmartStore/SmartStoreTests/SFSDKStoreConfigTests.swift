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
import SalesforceSDKCore

class SFSDKStoreConfigTests: SFSmartStoreTestCase {

    private var smartStoreUser: UserAccount!
    private var store: SmartStore!
    private var globalStore: SmartStore!
    private var sdkManager: SmartStoreSDKManager!

    override func setUp() {
        super.setUp()
        SmartStoreLogger.setLogLevel(.debug)
        sdkManager = SmartStoreSDKManager()
        smartStoreUser = setUpSmartStoreUser()
        store = SmartStore.shared(withName: kDefaultSmartStoreName)
        globalStore = SmartStore.sharedGlobal(withName: kDefaultSmartStoreName)
    }

    override func tearDown() {
        SmartStore.removeShared(withName: kDefaultSmartStoreName)
        SmartStore.removeSharedGlobal(withName: kDefaultSmartStoreName)
        tearDownSmartStoreUser(smartStoreUser)
        super.tearDown()

        smartStoreUser = nil
        store = nil
        globalStore = nil
        sdkManager = nil
    }

    // MARK: - tests

    func testSetupGlobalStoreFromDefaultConfig() {
        XCTAssertFalse(globalStore.soupExists(forName: "globalSoup1"))
        XCTAssertFalse(globalStore.soupExists(forName: "globalSoup2"))

        // Setting up soup
        sdkManager.setupGlobalStoreFromDefaultConfig()

        // Checking smartstore
        XCTAssertTrue(globalStore.soupExists(forName: "globalSoup1"))
        XCTAssertTrue(globalStore.soupExists(forName: "globalSoup2"))

        let actualSoupNames = globalStore.allSoupNames()
        XCTAssertEqual(actualSoupNames.count, 2)
        XCTAssertTrue(actualSoupNames.contains("globalSoup1"))
        XCTAssertTrue(actualSoupNames.contains("globalSoup2"))

        // Checking first soup in details
        var indexSpecs = globalStore.indices(forSoupNamed: "globalSoup1")
        XCTAssertEqual(indexSpecs.count, 5)
        checkSoupIndex(indexSpecs[0], expectedPath: "stringField1", expectedType: kSoupIndexTypeString, expectedColumnName: "TABLE_1_0")
        checkSoupIndex(indexSpecs[1], expectedPath: "integerField1", expectedType: kSoupIndexTypeInteger, expectedColumnName: "TABLE_1_1")
        checkSoupIndex(indexSpecs[2], expectedPath: "floatingField1", expectedType: kSoupIndexTypeFloating, expectedColumnName: "TABLE_1_2")
        checkSoupIndex(indexSpecs[3], expectedPath: "json1Field1", expectedType: kSoupIndexTypeJSON1, expectedColumnName: "json_extract(soup, '$.json1Field1')")
        checkSoupIndex(indexSpecs[4], expectedPath: "ftsField1", expectedType: kSoupIndexTypeFullText, expectedColumnName: "TABLE_1_4")

        // Checking second soup in details
        indexSpecs = globalStore.indices(forSoupNamed: "globalSoup2")
        XCTAssertEqual(indexSpecs.count, 5)
        checkSoupIndex(indexSpecs[0], expectedPath: "stringField2", expectedType: kSoupIndexTypeString, expectedColumnName: "TABLE_2_0")
        checkSoupIndex(indexSpecs[1], expectedPath: "integerField2", expectedType: kSoupIndexTypeInteger, expectedColumnName: "TABLE_2_1")
        checkSoupIndex(indexSpecs[2], expectedPath: "floatingField2", expectedType: kSoupIndexTypeFloating, expectedColumnName: "TABLE_2_2")
        checkSoupIndex(indexSpecs[3], expectedPath: "json1Field2", expectedType: kSoupIndexTypeJSON1, expectedColumnName: "json_extract(soup, '$.json1Field2')")
        checkSoupIndex(indexSpecs[4], expectedPath: "ftsField2", expectedType: kSoupIndexTypeFullText, expectedColumnName: "TABLE_2_4")
    }

    func testSetupUserStoreFromDefaultConfig() {
        XCTAssertFalse(store.soupExists(forName: "userSoup1"))
        XCTAssertFalse(store.soupExists(forName: "userSoup2"))

        // Setting up soup
        sdkManager.setupUserStoreFromDefaultConfig()

        // Checking smartstore
        XCTAssertTrue(store.soupExists(forName: "userSoup1"))
        XCTAssertTrue(store.soupExists(forName: "userSoup2"))

        let actualSoupNames = store.allSoupNames()
        XCTAssertEqual(actualSoupNames.count, 2)
        XCTAssertTrue(actualSoupNames.contains("userSoup1"))
        XCTAssertTrue(actualSoupNames.contains("userSoup2"))

        // Checking first soup in details
        var indexSpecs = store.indices(forSoupNamed: "userSoup1")
        XCTAssertEqual(indexSpecs.count, 5)
        checkSoupIndex(indexSpecs[0], expectedPath: "stringField1", expectedType: kSoupIndexTypeString, expectedColumnName: "TABLE_1_0")
        checkSoupIndex(indexSpecs[1], expectedPath: "integerField1", expectedType: kSoupIndexTypeInteger, expectedColumnName: "TABLE_1_1")
        checkSoupIndex(indexSpecs[2], expectedPath: "floatingField1", expectedType: kSoupIndexTypeFloating, expectedColumnName: "TABLE_1_2")
        checkSoupIndex(indexSpecs[3], expectedPath: "json1Field1", expectedType: kSoupIndexTypeJSON1, expectedColumnName: "json_extract(soup, '$.json1Field1')")
        checkSoupIndex(indexSpecs[4], expectedPath: "ftsField1", expectedType: kSoupIndexTypeFullText, expectedColumnName: "TABLE_1_4")

        // Checking second soup in details
        indexSpecs = store.indices(forSoupNamed: "userSoup2")
        XCTAssertEqual(indexSpecs.count, 5)
        checkSoupIndex(indexSpecs[0], expectedPath: "stringField2", expectedType: kSoupIndexTypeString, expectedColumnName: "TABLE_2_0")
        checkSoupIndex(indexSpecs[1], expectedPath: "integerField2", expectedType: kSoupIndexTypeInteger, expectedColumnName: "TABLE_2_1")
        checkSoupIndex(indexSpecs[2], expectedPath: "floatingField2", expectedType: kSoupIndexTypeFloating, expectedColumnName: "TABLE_2_2")
        checkSoupIndex(indexSpecs[3], expectedPath: "json1Field2", expectedType: kSoupIndexTypeJSON1, expectedColumnName: "json_extract(soup, '$.json1Field2')")
        checkSoupIndex(indexSpecs[4], expectedPath: "ftsField2", expectedType: kSoupIndexTypeFullText, expectedColumnName: "TABLE_2_4")
    }
}
