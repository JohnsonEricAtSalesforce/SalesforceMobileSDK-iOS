/*
 Copyright (c) 2016-present, salesforce.com, inc. All rights reserved.

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

class SFMultipleSmartStoresTests: SFSmartStoreTestCase {

    private var smartStoreUser: UserAccount!

    override func setUp() {
        super.setUp()
        SmartStoreLogger.setLogLevel(.debug)
        smartStoreUser = setUpSmartStoreUser()
        setupGlobalStores()
        setupUserStores()
    }

    override func tearDown() {
        tearDownSmartStoreUser(smartStoreUser)
        super.tearDown()
    }

    private func setupGlobalStores() {
        _ = SmartStore.sharedGlobal(withName: "GLBLDB1")
        _ = SmartStore.sharedGlobal(withName: "GLBLDB2")
        _ = SmartStore.sharedGlobal(withName: "GLBLDB3")
    }

    private func setupUserStores() {
        _ = SmartStore.shared(withName: "USRDB1")
        _ = SmartStore.shared(withName: "USRDB2")
        _ = SmartStore.shared(withName: "USRDB3")
    }

    func testGetGlobalStoreNames() {
        let array = SmartStore.allGlobalStoreNames
        XCTAssertTrue(array.count == 3, "GetAllGlobalStoreNames call failed")
    }

    func testGetUserStoreNames() {
        let array = SmartStore.allStoreNames
        XCTAssertTrue(array.count == 3, "testGetUserStoreNames call failed")
    }

    func testRemoveAllStores() {
        SmartStore.removeAllForCurrentUser()
        let array = SmartStore.allStoreNames
        XCTAssertTrue(array.count == 0, "testRemoveAllStores call failed")
    }

    func testRemoveAllGlobalStores() {
        SmartStore.removeAllGlobal()
        let array = SmartStore.allGlobalStoreNames
        XCTAssertTrue(array.count == 0, "testRemoveAllGlobalStores call failed")
    }

    func testGetStoreWithStoreName() {
        let smartStore = SmartStore.shared(withName: "USRDB1")
        XCTAssertTrue(smartStore != nil, "testGetStoreWithStoreName call failed")
    }

    override func setUpSmartStoreUser() -> UserAccount {
        let userIdentifier = arc4random()
        let credentials = OAuthCredentials(identifier: "identifier-\(userIdentifier)", clientId: UserAccountManager.shared.oauthClientID, encrypted: true)
        let user = UserAccount(credentials: credentials)
        let userId = "user_\(userIdentifier)"
        let orgId = "org_\(userIdentifier)"
        user.credentials.identityUrl = URL(string: "https://login.salesforce.com/id/\(orgId)/\(userId)")
        _ = user.transitionToLoginState(.loggedIn)
        try? UserAccountManager.shared.loadAccounts()
        try? UserAccountManager.shared.upsert(user)
        UserAccountManager.shared.currentUserAccount = user
        return user
    }

    override func tearDownSmartStoreUser(_ user: UserAccount) {
        SmartStore.removeAllGlobal()
        SmartStore.removeAllForCurrentUser()
        try? UserAccountManager.shared.delete(user)
        UserAccountManager.shared.currentUserAccount = nil
    }
}
