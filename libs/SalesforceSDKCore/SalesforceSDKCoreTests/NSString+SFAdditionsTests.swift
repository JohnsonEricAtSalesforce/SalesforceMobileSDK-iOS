// NSString+SFAdditionsTests.swift
// SalesforceSDKCoreTests
//
// Copyright (c) 2018-present, salesforce.com, inc. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause

import XCTest
@testable import SalesforceSDKCore

class NSStringSFAdditionsTests: XCTestCase {

    private let me = "me"
    private let otherMe = "ME"
    private let userAId15 = "005300000040EVc"
    private let userBId15 = "005300000040EvC"
    private let userAId18 = "005300000040EVcAAM"
    private let userBId18 = "005300000040EvCAAU"

    func testEntityId18() {
        XCTAssertEqual(userAId18, (userAId15 as NSString).sfsdk_entityId18())
        XCTAssertEqual(userBId18, (userBId15 as NSString).sfsdk_entityId18())
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
