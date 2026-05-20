/*
 Copyright (c) 2015-present, salesforce.com, inc. All rights reserved.

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

// Needs to match what is defined in PushNotificationManager
private let kSFDeviceSalesforceId = "deviceSalesforceId"

class SFPushNotificationManagerTests: XCTestCase {

    private var manager: PushNotificationManager?
    private var user: UserAccount?
    private var origCurrentUser: UserAccount?

    override func setUp() {
        super.setUp()
        let mgr = PushNotificationManager()
        mgr.isSimulator = false
        mgr.deviceSalesforceId = "pretending-we-registered"
        guard let credentials = OAuthCredentials(identifier: "happy-user", clientId: UserAccountManager.shared.oauthClientID, encrypted: true) else {
            XCTFail("Failed to create credentials")
            return
        }
        let account = UserAccount(credentials: credentials)
        account.credentials.identityUrl = URL(string: "https://login.salesforce.com/id/00D000000000062EA0/005R0000000Dsl0")
        origCurrentUser = UserAccountManager.shared.currentUserAccount
        UserAccountManager.shared.setCurrentUserInternal(account)
        user = account
        manager = mgr
    }

    override func tearDown() {
        UserAccountManager.shared.setCurrentUserInternal(origCurrentUser)
        super.tearDown()
    }

    func testRegisterSalesforceNotifications_NoCurrentUser() {
        UserAccountManager.shared.setCurrentUserInternal(nil)
        let result = manager?.registerSalesforceNotifications(completionBlock: nil, failBlock: nil) ?? true
        XCTAssertFalse(result)
    }

    func testRegisterSalesforceNotifications_NoDeviceIdPref() {
        guard let user = user else { return }
        let pref = SFPreferences.sharedPreferences(forScope: .user, user: user)
        pref?.removeObject(forKey: kSFDeviceSalesforceId)
        let result = manager?.registerSalesforceNotifications(completionBlock: nil, failBlock: nil) ?? true
        XCTAssertFalse(result)
    }

    func testUnregisterSalesforceNotifications_NoCurrentUser() {
        UserAccountManager.shared.setCurrentUserInternal(nil)
        let result = manager?.unregisterSalesforceNotifications(completionBlock: nil) ?? true
        XCTAssertFalse(result)
    }

    func testUnregisterSalesforceNotifications_NoDeviceIdPref() {
        guard let user = user else { return }
        let pref = SFPreferences.sharedPreferences(forScope: .user, user: user)
        pref?.removeObject(forKey: kSFDeviceSalesforceId)
        let result = manager?.unregisterSalesforceNotifications(completionBlock: nil) ?? true
        XCTAssertFalse(result)
    }
}
