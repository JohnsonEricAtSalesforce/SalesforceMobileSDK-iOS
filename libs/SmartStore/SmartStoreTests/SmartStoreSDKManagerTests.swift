/*
 Copyright (c) 2025-present, salesforce.com, inc. All rights reserved.

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

class SmartStoreSDKManagerTests: SFSmartStoreTestCase {

    func testGetDevSupportInfosContainsSmartStoreSection() {
        let manager = SmartStoreSDKManager()

        let devInfos = manager.devSupportInfoList()

        var foundSmartStoreSection = false
        for item in devInfos {
            if item == "section:SmartStore" {
                foundSmartStoreSection = true
                break
            }
        }

        XCTAssertTrue(foundSmartStoreSection, "Dev support infos should contain 'section:SmartStore'")
    }

    func testGetDevSupportInfosContainsSQLCipherVersion() {
        let manager = SmartStoreSDKManager()

        let devInfos = manager.devSupportInfoList()

        var foundVersionLabel = false
        var foundVersionValue = false

        for i in 0..<(devInfos.count - 1) {
            if devInfos[i] == "SQLCipher version" {
                foundVersionLabel = true
                let version = devInfos[i + 1]
                foundVersionValue = !version.isEmpty
                break
            }
        }

        XCTAssertTrue(foundVersionLabel, "Dev support infos should contain 'SQLCipher version' label")
        XCTAssertTrue(foundVersionValue, "Dev support infos should contain SQLCipher version value")
    }

    func testGetDevSupportInfosContainsCompileOptions() {
        let manager = SmartStoreSDKManager()

        let devInfos = manager.devSupportInfoList()

        var foundCompileOptions = false

        for i in 0..<(devInfos.count - 1) {
            if devInfos[i] == "SQLCipher Compile Options" {
                foundCompileOptions = true
                XCTAssertTrue(i + 1 < devInfos.count, "Compile options label should be followed by a value")
                break
            }
        }

        XCTAssertTrue(foundCompileOptions, "Dev support infos should contain 'SQLCipher Compile Options'")
    }

    func testGetDevSupportInfosContainsRuntimeSettings() {
        let manager = SmartStoreSDKManager()

        let devInfos = manager.devSupportInfoList()

        var foundRuntimeSettings = false

        for i in 0..<(devInfos.count - 1) {
            if devInfos[i] == "SQLCipher Runtime Settings" {
                foundRuntimeSettings = true
                XCTAssertTrue(i + 1 < devInfos.count, "Runtime settings label should be followed by a value")
                break
            }
        }

        XCTAssertTrue(foundRuntimeSettings, "Dev support infos should contain 'SQLCipher Runtime Settings'")
    }

    func testGetDevSupportInfosWithGlobalStores() {
        let manager = SmartStoreSDKManager()

        // Create a global store to ensure we have something to report
        let globalStore = SmartStore.sharedGlobal(withName: "testGlobalStore")
        XCTAssertNotNil(globalStore, "Should be able to create global store")

        let devInfos = manager.devSupportInfoList()

        // Find the Global SmartStores entry
        var foundGlobalStores = false
        var globalStoresValue: String?

        for i in 0..<(devInfos.count - 1) {
            if devInfos[i] == "Global SmartStores" {
                foundGlobalStores = true
                globalStoresValue = devInfos[i + 1]
                break
            }
        }

        XCTAssertTrue(foundGlobalStores, "Should find Global SmartStores entry")
        XCTAssertNotNil(globalStoresValue, "Global SmartStores value should not be nil")
        XCTAssertTrue(globalStoresValue?.contains("testGlobalStore") == true,
                     "Global SmartStores should include our test store (found: \(globalStoresValue ?? ""))")

        // Clean up
        SmartStore.removeSharedGlobal(withName: "testGlobalStore")
    }

    func testGetDevSupportInfosWithUserStore() {
        let manager = SmartStoreSDKManager()

        // Set up a test user
        let testUser = setUpSmartStoreUser()

        // Create a user store
        let userStore = SmartStore.shared(withName: "testUserStore", forUserAccount: testUser)
        XCTAssertNotNil(userStore, "Should be able to create user store")

        let devInfos = manager.devSupportInfoList()

        // Find the User SmartStores entry
        var foundUserStores = false
        var userStoresValue: String?

        for i in 0..<(devInfos.count - 1) {
            if devInfos[i] == "User SmartStores" {
                foundUserStores = true
                userStoresValue = devInfos[i + 1]
                break
            }
        }

        XCTAssertTrue(foundUserStores, "Should find User SmartStores entry")
        XCTAssertNotNil(userStoresValue, "User SmartStores value should not be nil")

        // Clean up
        SmartStore.removeShared(withName: "testUserStore", forUserAccount: testUser)
        tearDownSmartStoreUser(testUser)
    }

    func testGetDevActionsIncludesInspectSmartStore() {
        let manager = SmartStoreSDKManager()
        let vc = UIViewController()

        let devActions = manager.devActionsList(presentedViewController: vc)

        var foundInspectAction = false
        for action in devActions {
            if action.name == "Inspect SmartStore" {
                foundInspectAction = true
                break
            }
        }

        XCTAssertTrue(foundInspectAction, "Dev actions should include 'Inspect SmartStore' action")
    }
}
