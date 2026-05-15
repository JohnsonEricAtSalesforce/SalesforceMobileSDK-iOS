/*
 Copyright (c) 2021-present, salesforce.com, inc. All rights reserved.

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
@testable import SalesforceSDKCore
import SalesforceSDKCommon

final class ScreenLockManagerLegacyTests: XCTestCase {

    override func setUp() {
        super.setUp()
        _ = KeychainHelper.removeAll()
    }

    func testShouldNotLock() {
        XCTAssertNil(ScreenLockManagerInternal.shared.getTimeout(), "App should not lock by default.")
    }

    func testShouldLock() {
        let user0 = createNewUserAccount(0)
        ScreenLockManagerInternal.shared.storeMobilePolicy(userAccount: user0, hasMobilePolicy: true, lockTimeout: 15)
        XCTAssertEqual(ScreenLockManagerInternal.shared.getTimeout(), NSNumber(value: 15), "App should lock.")
    }

    func testShouldLockMultiuser() {
        let user0 = createNewUserAccount(0)
        ScreenLockManagerInternal.shared.storeMobilePolicy(userAccount: user0, hasMobilePolicy: true, lockTimeout: 1)
        let user1 = createNewUserAccount(1)
        ScreenLockManagerInternal.shared.storeMobilePolicy(userAccount: user1, hasMobilePolicy: false, lockTimeout: 0)
        XCTAssertEqual(ScreenLockManagerInternal.shared.getTimeout(), NSNumber(value: 1), "App should lock.")
    }

    func testShouldLockMultiuserDifferentTimeouts() {
        let user0 = createNewUserAccount(0)
        ScreenLockManagerInternal.shared.storeMobilePolicy(userAccount: user0, hasMobilePolicy: true, lockTimeout: 1)
        let user1 = createNewUserAccount(1)
        ScreenLockManagerInternal.shared.storeMobilePolicy(userAccount: user1, hasMobilePolicy: true, lockTimeout: 5)
        let user2 = createNewUserAccount(2)
        ScreenLockManagerInternal.shared.storeMobilePolicy(userAccount: user2, hasMobilePolicy: true, lockTimeout: 15)
        XCTAssertEqual(ScreenLockManagerInternal.shared.getTimeout(), NSNumber(value: 1), "App should lock with most restrictive timeout")
    }

    func testShouldLockMultiuserDifferentTimeoutsReverseOrder() {
        let user0 = createNewUserAccount(0)
        ScreenLockManagerInternal.shared.storeMobilePolicy(userAccount: user0, hasMobilePolicy: true, lockTimeout: 15)
        let user1 = createNewUserAccount(1)
        ScreenLockManagerInternal.shared.storeMobilePolicy(userAccount: user1, hasMobilePolicy: true, lockTimeout: 5)
        let user2 = createNewUserAccount(2)
        ScreenLockManagerInternal.shared.storeMobilePolicy(userAccount: user2, hasMobilePolicy: true, lockTimeout: 1)
        XCTAssertEqual(ScreenLockManagerInternal.shared.getTimeout(), NSNumber(value: 1), "App should lock with most restrictive timeout")
    }

    func testLogoutScreenLockUsers() {
        let user0 = createNewUserAccount(0)
        ScreenLockManagerInternal.shared.storeMobilePolicy(userAccount: user0, hasMobilePolicy: true, lockTimeout: 15)
        let user1 = createNewUserAccount(1)
        ScreenLockManagerInternal.shared.storeMobilePolicy(userAccount: user1, hasMobilePolicy: false, lockTimeout: 0)
        let user2 = createNewUserAccount(2)
        ScreenLockManagerInternal.shared.storeMobilePolicy(userAccount: user2, hasMobilePolicy: true, lockTimeout: 5)
        XCTAssertEqual(ScreenLockManagerInternal.shared.getTimeout(), NSNumber(value: 5), "App should lock.")

        ScreenLockManagerInternal.shared.logoutScreenLockUsers()
        XCTAssertNil(ScreenLockManagerInternal.shared.getTimeout(), "App not should lock.")
    }

    // MARK: - Helper

    private func createNewUserAccount(_ index: Int) -> UserAccount {
        let credentials = OAuthCredentials(identifier: "identifier-\(index)", clientId: "fakeClientIdForTesting", encrypted: true)
        let idDataDict = ["user_id": "\(index)"]
        let idData = IdentityData(jsonDict: idDataDict)
        let user = UserAccount(credentials: credentials)
        user.idData = idData
        return user
    }
}
