//
//  SDKCommonNSDataTests.swift
//  SalesforceSDKCore
//
//  Copyright (c) 2014-present, salesforce.com, inc. All rights reserved.
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

class SDKCommonNSDataTests: XCTestCase {

    func testBase64UrlReplacements() {
        let beforeAfterStrings: [[String]] = [
            ["", ""],
            ["abcdefg", "abcdefg"],
            ["/////", "_____"],
            ["+++++", "-----"],
            ["=====", ""],
            ["///+++===", "___---"],
            ["===+++///", "===---___"],
            ["abc+//+def==", "abc-__-def"],
            ["a/b=c+d", "a_b=c-d"]
        ]

        let nilResult = NSData.sfsdk_replaceBase64Chars(forBase64UrlString: "")
        // Note: The Swift version takes a non-optional String; empty string test covers "nil-like" case
        XCTAssertEqual(nilResult, "", "Empty string in should give empty string out")

        for beforeAfterPair in beforeAfterStrings {
            let base64UrlReplace = NSData.sfsdk_replaceBase64Chars(forBase64UrlString: beforeAfterPair[0])
            XCTAssertEqual(base64UrlReplace, beforeAfterPair[1], "Strings don't match")
        }
    }

    func testSha256DataGeneration() {
        // We'll test that the same SHA256 hash gets generated for each piece of data
        var entriesArray: [(NSData, NSData)] = []
        for _ in 0..<100 {
            let randomData = randomDataOfRandomLength()
            guard let sha256Data = randomData.sfsdk_sha256Data() else {
                XCTFail("SHA256 generation failed")
                return
            }
            entriesArray.append((randomData, sha256Data))
        }

        for i in 0..<100 {
            let inData = entriesArray[i].0
            guard let sha256Data = inData.sfsdk_sha256Data() else {
                XCTFail("SHA256 generation failed on verification pass")
                return
            }
            XCTAssertEqual(sha256Data, entriesArray[i].1, "SHA256 value should be the same across generations")
        }
    }

    // MARK: - Private methods

    private func randomDataOfRandomLength() -> NSData {
        // Return an NSData object of a random length, up to 1KB.
        let dataLength = Int(arc4random() % 1024) + 1
        let data = NSMutableData(capacity: dataLength) ?? NSMutableData()
        for _ in 0..<dataLength {
            var byteVal = UInt8(arc4random() % 256)
            data.append(&byteVal, length: 1)
        }
        return data
    }
}
