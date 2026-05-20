//
//  SFEncryptionKeyTests.swift
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

class SFEncryptionKeyTests: XCTestCase {

    func testKeyEquality() {
        guard let keyData = "keyData".data(using: .utf8),
              let ivData = "ivData".data(using: .utf8),
              let otherKeyData = "otherKeyData".data(using: .utf8),
              let otherIvData = "otherIvData".data(using: .utf8) else {
            XCTFail("Failed to create test data")
            return
        }

        let key1 = SFEncryptionKey(data: keyData, initializationVector: ivData)
        let key2 = SFEncryptionKey(data: keyData, initializationVector: ivData)
        let key3 = SFEncryptionKey(data: otherKeyData, initializationVector: otherIvData)

        XCTAssertEqual(key1, key2, "Objects should be equal, with identical keys and iv's.")
        XCTAssertNotEqual(key1, key3, "Object with different keys and iv's should not be equal.")
    }

    func testKeyStringRepresentations() {
        guard let keyData = "keyData".data(using: .utf8),
              let ivData = "ivData".data(using: .utf8) else {
            XCTFail("Failed to create test data")
            return
        }

        let key1 = SFEncryptionKey(data: keyData, initializationVector: ivData)
        let key2 = SFEncryptionKey(data: keyData, initializationVector: ivData)

        XCTAssertEqual(key1.keyAsString, key2.keyAsString, "Key string representation should be the same.")
        XCTAssertEqual(key1.initializationVectorAsString, key2.initializationVectorAsString, "IV string representation should be the same.")
    }
}
