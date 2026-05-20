//
//  UIColor+SFColorsTests.swift
//  SalesforceSDKCore
//
//  Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.
//
//  Redistribution and use of this software in source and binary forms, with or without modification,
//  are permitted provided that the following conditions are met:
//  * Redistributions of source code must retain the above copyright notice, this list of conditions
//  and the following disclaimer.
//  * Redistributions in binary form must reproduce the above copyright notice, this list of
//  conditions and the following disclaimer in the documentation and/or other materials provided
//  with the distribution.
//  * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
//  endorse or promote products derived from this software without specific prior written
//  permission of salesforce.com, inc.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
//  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
//  FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
//  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
//  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
//  WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import XCTest
@testable import SalesforceSDKCore
import UIKit

class UIColor_SFColorsTests: XCTestCase {

    private func hexString(from color: UIColor) -> String {
        guard let components = color.cgColor.components, components.count >= 3 else {
            return ""
        }
        let r = UInt8(components[0] * 255)
        let g = UInt8(components[1] * 255)
        let b = UInt8(components[2] * 255)
        return String(format: "%02X%02X%02X", r, g, b)
    }

    func testColorWithShortHandHexAndPoundPrefix() {
        let color = UIColor.sfsdk_colorFromHexValue("#abc")
        XCTAssertNotNil(color)
        guard let color = color else { return }
        XCTAssertEqual(hexString(from: color).lowercased(), "aabbcc", "Hex strings do not match color generated!")
    }

    func testColorWithShortHandHexNoPoundPrefix() {
        let color = UIColor.sfsdk_colorFromHexValue("abc")
        XCTAssertNotNil(color)
        guard let color = color else { return }
        XCTAssertEqual(hexString(from: color).lowercased(), "aabbcc", "Hex strings do not match color generated!")
    }

    func testColorWithPoundPrefix() {
        let color = UIColor.sfsdk_colorFromHexValue("#aabbcc")
        XCTAssertNotNil(color)
        guard let color = color else { return }
        XCTAssertEqual(hexString(from: color).lowercased(), "aabbcc", "Hex strings do not match color generated!")
    }

    func testColorWithNoPoundPrefix() {
        let color = UIColor.sfsdk_colorFromHexValue("aabbcc")
        XCTAssertNotNil(color)
        guard let color = color else { return }
        XCTAssertEqual(hexString(from: color).lowercased(), "aabbcc", "Hex strings do not match color generated!")
    }

    func testInvalidShorthand() {
        let color = UIColor.sfsdk_colorFromHexValue("ab")
        XCTAssertNil(color, "Color must be nil for invalid hex representation!")
    }

    func testInvalidShorthandWithPoundPrefix() {
        let color = UIColor.sfsdk_colorFromHexValue("#ab")
        XCTAssertNil(color, "Color must be nil for invalid hex representation!")
    }

    func testEmptyHexString() {
        let color = UIColor.sfsdk_colorFromHexValue("")
        XCTAssertNil(color, "Color must be nil for empty hex representation!")
    }

    func testNilHexString() {
        let color = UIColor.sfsdk_colorFromHexValue(nil)
        XCTAssertNil(color, "Color must be nil for nil hex representation!")
    }
}
