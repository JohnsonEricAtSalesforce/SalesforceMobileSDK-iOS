/*
 Copyright (c) 2020-present, salesforce.com, inc. All rights reserved.

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

final class SFUserIdUpgradeTestsSwift: XCTestCase {

    private let userId15 = "005B0000005WYRK"
    private let userId18 = "005B0000005WYRKIA4"
    private let orgId = "00DB0000000ToZ3MAK"
    private let communityId = "COMMUNITYID"

    override func setUp() {
        super.setUp()
        let fm = FileManager.default
        if let libraryDirectoryOrg = SFDirectoryManager.sharedManager().directory(forOrg: orgId, user: nil, community: nil, type: .libraryDirectory, components: nil) {
            try? fm.removeItem(atPath: libraryDirectoryOrg)
        }
        if let documentDirectoryOrg = SFDirectoryManager.sharedManager().directory(forOrg: orgId, user: nil, community: nil, type: .documentDirectory, components: nil) {
            try? fm.removeItem(atPath: documentDirectoryOrg)
        }
    }

    func testDirectories() {
        // Create directories based on 15 character user ID
        let libraryDirectory15 = SFDirectoryManager.sharedManager().directory(forOrg: orgId, user: userId15, community: communityId, type: .libraryDirectory, components: nil) ?? ""
        try? SFDirectoryManager.ensureDirectoryExists(libraryDirectory15)

        let documentDirectory15 = SFDirectoryManager.sharedManager().directory(forOrg: orgId, user: userId15, community: communityId, type: .documentDirectory, components: nil) ?? ""
        try? SFDirectoryManager.ensureDirectoryExists(documentDirectory15)

        // Upgrade everything to 18 characters
        SFDirectoryManager.upgradeUserDirectories()

        let fm = FileManager.default
        let libraryDirectory18 = libraryDirectory15.replacingOccurrences(of: userId15, with: userId18)
        XCTAssertFalse(fm.fileExists(atPath: libraryDirectory15))
        XCTAssertTrue(fm.fileExists(atPath: libraryDirectory18))

        let documentDirectory18 = documentDirectory15.replacingOccurrences(of: userId15, with: userId18)
        XCTAssertFalse(fm.fileExists(atPath: documentDirectory15))
        XCTAssertTrue(fm.fileExists(atPath: documentDirectory18))
    }
}
