/*
 Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.

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
@testable import SalesforceSDKCommon

class SFSDKSafeMutableDictionaryTests: XCTestCase {

    var testDictionary: SFSDKSafeMutableDictionary = SFSDKSafeMutableDictionary()
    var testKeys: [NSString] = []

    override func setUp() {
        super.setUp()
        testDictionary = SFSDKSafeMutableDictionary()
        testKeys = generateTestKeys()
        let objects = generateTestValues()
        for (idx, key) in testKeys.enumerated() {
            testDictionary.setObject(objects[idx], forKey: key)
        }
    }

    func testConcurrentReadWrites() {
        let overwriteValues = generateTestValues()
        let writeExpectation = expectation(description: "writeExpectation")
        let readExpectation = expectation(description: "readExpectation")

        DispatchQueue.global(qos: .userInitiated).async {
            self.performWrites(self.testDictionary, keys: self.testKeys, objects: overwriteValues)
            writeExpectation.fulfill()
        }

        DispatchQueue.global(qos: .userInitiated).async {
            self.performReads(self.testDictionary, keys: self.testKeys)
            readExpectation.fulfill()
        }

        waitForExpectations(timeout: 5.0) { error in
            if let error = error {
                print("Error occurred while waiting for expectations! Error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Helper Methods

    private func generateTestKeys() -> [NSString] {
        var keys: [NSString] = []
        keys.reserveCapacity(1000)
        for idx in 0..<1000 {
            keys.append(NSString(string: "\(idx)"))
        }
        return keys
    }

    private func generateTestValues() -> [NSNumber] {
        var values: [NSNumber] = []
        values.reserveCapacity(1000)
        for _ in 0..<1000 {
            values.append(NSNumber(value: arc4random_uniform(1000)))
        }
        return values
    }

    private func performWrites(_ dictionary: SFSDKSafeMutableDictionary, keys: [NSString], objects: [NSNumber]) {
        for (idx, key) in keys.enumerated() {
            dictionary.setObject(objects[idx], forKey: key)
        }
    }

    private func performReads(_ dictionary: SFSDKSafeMutableDictionary, keys: [NSString]) {
        for key in keys {
            _ = dictionary.object(forKey: key)
        }
    }
}
