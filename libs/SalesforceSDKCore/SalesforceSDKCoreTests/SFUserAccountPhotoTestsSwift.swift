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
@testable import SalesforceSDKCore

final class SFUserAccountPhotoTestsSwift: XCTestCase {

    func testPhotoWithCompletionBlock() {
        let user = createNewUser()
        setPhoto(user: user, photo: nil)
        XCTAssertNil(user.photo)

        let testPhoto = SFSDKResourceUtils.imageNamed("salesforce-logo")
        setPhoto(user: user, photo: testPhoto)
        XCTAssertEqual(user.photo, testPhoto)

        setPhoto(user: user, photo: nil)
        XCTAssertNil(user.photo)
    }

    func testPhotoWithoutCompletionBlock() {
        let user = createNewUser()
        user.setPhoto(nil, completion: nil)
        waitForBlockCondition({ user.photo == nil }, timeout: 2.0)
        XCTAssertNil(user.photo)

        let testPhoto = SFSDKResourceUtils.imageNamed("salesforce-logo")
        user.setPhoto(testPhoto, completion: nil)
        waitForBlockCondition({ user.photo === testPhoto }, timeout: 2.0)
        XCTAssertNotNil(user.photo)
    }

    // MARK: - Helpers

    private func setPhoto(user: SFUserAccount, photo: UIImage?) {
        let exp = expectation(description: "Photo set")
        user.setPhoto(photo) { error in
            exp.fulfill()
        }
        waitForExpectations(timeout: 2.0)
    }

    private func createNewUser() -> SFUserAccount {
        let userID = "005R0000000DslaIAC"
        let credentials = SFOAuthCredentials(identifier: "identifier-\(userID)", clientId: SFUserAccountManager.shared.oauthClientID, encrypted: true)
        let user = SFUserAccount(credentials: credentials)
        user.credentials.identityUrl = URL(string: "https://login.salesforce.com/id/00D000000000062EAA/\(userID)")
        return user
    }

    @discardableResult
    private func waitForBlockCondition(_ block: @escaping () -> Bool, timeout duration: TimeInterval) -> Bool {
        var blockCondition = block()
        if !blockCondition {
            let date = Date(timeIntervalSinceNow: duration)
            while date.timeIntervalSinceNow > 0 {
                if block() {
                    blockCondition = true
                    break
                }
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
            }
        }
        return blockCondition
    }
}
