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
@testable import SalesforceSDKCommon

class SFSDKSafeMutableSetTests: XCTestCase {

    func testReadWrites() {
        let set = SFSDKSafeMutableSet.set()
        set.addObject("Test1")
        set.addObject("Test2")
        set.addObject(NSNumber(value: 10))

        XCTAssertTrue(set.containsObject("Test1"))
        XCTAssertTrue(set.containsObject("Test2"))
        XCTAssertTrue(set.containsObject(NSNumber(value: 10)))
    }

    func testReadWriteDelete() {
        let set = SFSDKSafeMutableSet.set()
        set.addObject("Test1")
        set.addObject("Test2")
        XCTAssertTrue(set.containsObject("Test1"))
        XCTAssertTrue(set.containsObject("Test2"))
        set.removeObject("Test1")
        XCTAssertFalse(set.containsObject("Test1"))
        set.removeAllObjects()
        XCTAssertTrue(set.count == 0)
    }

    func testConcurrentWrites() {
        let inputs: [Any] = ["Test1", "Test2", "Test3", "Test4", "Test5"]

        let set = SFSDKSafeMutableSet.set()
        let group = DispatchGroup()

        for i in 0..<inputs.count {
            group.enter()
            DispatchQueue.global().async {
                set.addObject(inputs[i])
                group.leave()
            }
        }

        group.wait()

        // Does the set have the right number of items?
        XCTAssertTrue(set.count == inputs.count)
        // Does the set have each of our items?
        for i in 0..<inputs.count {
            XCTAssertTrue(set.containsObject(inputs[i]))
        }
    }

    func testConcurrentReadWrites() {
        let inputs: [Any] = ["Test1", "Test2", "Test3", "Test4", "Test5"]

        let set = SFSDKSafeMutableSet.set()
        let group = DispatchGroup()

        for i in 0..<inputs.count {
            group.enter()
            DispatchQueue.global().async {
                set.addObject(inputs[i])
                group.leave()
            }
        }

        for _ in 0..<inputs.count {
            group.enter()
            DispatchQueue.global().async {
                _ = set.anyObject()
                group.leave()
            }
        }

        group.wait()
        // Does the set have the right number of items?
        XCTAssertTrue(set.count == inputs.count)
        // Does the set have each of our items?
        for i in 0..<inputs.count {
            XCTAssertTrue(set.containsObject(inputs[i]))
        }
    }

    func testConcurrentReadsAndRemove() {
        let inputs: [Any] = ["Test1", "Test2", "Test3", "Test4", "Test5"]

        let set = SFSDKSafeMutableSet.set()
        let group = DispatchGroup()

        for i in 0..<inputs.count {
            set.addObject(inputs[i])
        }

        XCTAssertEqual(set.count, inputs.count)
        for i in 0..<inputs.count {
            group.enter()
            DispatchQueue.global().async {
                set.removeObject(inputs[i])
                group.leave()
            }
        }

        for _ in 0..<inputs.count {
            group.enter()
            DispatchQueue.global().async {
                _ = set.anyObject()
                group.leave()
            }
        }

        group.wait()
        // Have all items been removed
        XCTAssertTrue(set.count == 0)
    }

    func testConcurrentReadsAndRemoveAll() {
        let inputs: [Any] = ["Test1", "Test2", "Test3", "Test4", "Test5"]

        let set = SFSDKSafeMutableSet.set()
        let group = DispatchGroup()

        for i in 0..<inputs.count {
            set.addObject(inputs[i])
        }

        XCTAssertEqual(set.count, inputs.count)
        for _ in 0..<inputs.count {
            group.enter()
            DispatchQueue.global(qos: .background).async {
                _ = set.anyObject()
                group.leave()
            }
        }

        group.enter()
        DispatchQueue.global().async {
            set.removeAllObjects()
            group.leave()
        }

        group.wait()
        // Have all items been removed
        XCTAssertTrue(set.count == 0)
    }
}
