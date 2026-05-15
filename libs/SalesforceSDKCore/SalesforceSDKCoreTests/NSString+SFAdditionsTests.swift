/*
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
@testable import SalesforceSDKCore

final class NSString_SFAdditionsTests: XCTestCase {

    private let me = "me"
    private let otherMe = "ME"

    private let userAId15 = "005300000040EVc"
    private let userBId15 = "005300000040EvC"

    private let userAId18 = "005300000040EVcAAM"
    private let userBId18 = "005300000040EvCAAU"

    // MARK: - Tests

    func testEntityId18() {
        XCTAssertEqual(userAId18, (userAId15 as NSString).sfsdk_entityId18)
        XCTAssertEqual(userBId18, (userBId15 as NSString).sfsdk_entityId18)
    }

    func testIsEqualToEntityId() {
        XCTAssertTrue(("" as NSString).sfsdk_isEqual(toEntityId: ""))
        XCTAssertTrue((me as NSString).sfsdk_isEqual(toEntityId: me))
        XCTAssertTrue((me as NSString).sfsdk_isEqual(toEntityId: otherMe))
        XCTAssertTrue((otherMe as NSString).sfsdk_isEqual(toEntityId: me))

        XCTAssertTrue((userAId15 as NSString).sfsdk_isEqual(toEntityId: userAId15))
        XCTAssertTrue((userAId15 as NSString).sfsdk_isEqual(toEntityId: userAId18))
        XCTAssertTrue((userAId18 as NSString).sfsdk_isEqual(toEntityId: userAId15))
        XCTAssertTrue((userAId18 as NSString).sfsdk_isEqual(toEntityId: userAId18))

        XCTAssertTrue((userBId15 as NSString).sfsdk_isEqual(toEntityId: userBId15))
        XCTAssertTrue((userBId15 as NSString).sfsdk_isEqual(toEntityId: userBId18))
        XCTAssertTrue((userBId18 as NSString).sfsdk_isEqual(toEntityId: userBId15))
        XCTAssertTrue((userBId18 as NSString).sfsdk_isEqual(toEntityId: userBId18))

        XCTAssertFalse((userAId15 as NSString).sfsdk_isEqual(toEntityId: ""))
        XCTAssertFalse((userAId15 as NSString).sfsdk_isEqual(toEntityId: me))
        XCTAssertFalse((userAId15 as NSString).sfsdk_isEqual(toEntityId: otherMe))
        XCTAssertFalse((userAId15 as NSString).sfsdk_isEqual(toEntityId: userBId15))
        XCTAssertFalse((userAId15 as NSString).sfsdk_isEqual(toEntityId: userBId18))

        XCTAssertFalse(("" as NSString).sfsdk_isEqual(toEntityId: userAId15))
        XCTAssertFalse((me as NSString).sfsdk_isEqual(toEntityId: userAId15))
        XCTAssertFalse((otherMe as NSString).sfsdk_isEqual(toEntityId: userAId15))
        XCTAssertFalse((userBId15 as NSString).sfsdk_isEqual(toEntityId: userAId15))
        XCTAssertFalse((userBId18 as NSString).sfsdk_isEqual(toEntityId: userAId15))
    }

    func testUnescapeXMLCharacter() {
        XCTAssertEqual(NSString.sfsdk_unescapeXMLCharacter("O&quot;Maley"), "O\"Maley")
        XCTAssertEqual(NSString.sfsdk_unescapeXMLCharacter("O&#62;Maley"), "O>Maley")
        XCTAssertEqual(NSString.sfsdk_unescapeXMLCharacter("O&gt;Maley"), "O>Maley")
        XCTAssertEqual(NSString.sfsdk_unescapeXMLCharacter("O&#60;Maley"), "O<Maley")
        XCTAssertEqual(NSString.sfsdk_unescapeXMLCharacter("O&lt;Maley"), "O<Maley")
        XCTAssertEqual(NSString.sfsdk_unescapeXMLCharacter("O&#39;Maley"), "O'Maley")
    }
}
