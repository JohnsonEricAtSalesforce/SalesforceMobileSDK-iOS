//
//  SFSDKSafeMutableSetTests.swift
//  SalesforceSDKCommon
//
//  Copyright (c) 2018-present, salesforce.com, inc. All rights reserved.
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
@testable import SalesforceSDKCommon

final class SFSDKSafeMutableSetTests: XCTestCase {

    func testReadWrites() {
        let set = SFSDKSafeMutableSet.set()
        set.add("Test1")
        set.add("Test2")
        set.add(NSNumber(value: 10))

        XCTAssertTrue(set.contains("Test1"))
        XCTAssertTrue(set.contains("Test2"))
        XCTAssertTrue(set.contains(NSNumber(value: 10)))
    }

    func testReadWriteDelete() {
        let set = SFSDKSafeMutableSet.set()
        set.add("Test1")
        set.add("Test2")
        XCTAssertTrue(set.contains("Test1"))
        XCTAssertTrue(set.contains("Test2"))
        set.remove("Test1")
        XCTAssertFalse(set.contains("Test1"))
        set.removeAllObjects()
        XCTAssertTrue(set.count == 0)
    }

    func testConcurrentWrites() {
        let inputs = ["Test1", "Test2", "Test3", "Test4", "Test5"]
        let set = SFSDKSafeMutableSet.set()
        let group = DispatchGroup()

        for input in inputs {
            group.enter()
            DispatchQueue.global(qos: .default).async {
                set.add(input)
                group.leave()
            }
        }

        group.wait()

        // Does the set have the right number of items?
        XCTAssertTrue(set.count == inputs.count)
        // Does the set have each of our items?
        for input in inputs {
            XCTAssertTrue(set.contains(input))
        }
    }

    func testConcurrentReadWrites() {
        let inputs = ["Test1", "Test2", "Test3", "Test4", "Test5"]
        let set = SFSDKSafeMutableSet.set()
        let group = DispatchGroup()

        for input in inputs {
            group.enter()
            DispatchQueue.global(qos: .default).async {
                set.add(input)
                group.leave()
            }
        }

        for _ in inputs {
            group.enter()
            DispatchQueue.global(qos: .default).async {
                _ = set.anyObject()
                group.leave()
            }
        }

        group.wait()

        // Does the set have the right number of items?
        XCTAssertTrue(set.count == inputs.count)
        // Does the set have each of our items?
        for input in inputs {
            XCTAssertTrue(set.contains(input))
        }
    }

    func testConcurrentReadsAndRemove() {
        let inputs = ["Test1", "Test2", "Test3", "Test4", "Test5"]
        let set = SFSDKSafeMutableSet.set()
        let group = DispatchGroup()

        for input in inputs {
            set.add(input)
        }

        XCTAssertEqual(set.count, inputs.count)

        for input in inputs {
            group.enter()
            DispatchQueue.global(qos: .default).async {
                set.remove(input)
                group.leave()
            }
        }

        for _ in inputs {
            group.enter()
            DispatchQueue.global(qos: .default).async {
                _ = set.anyObject()
                group.leave()
            }
        }

        group.wait()

        // Have all items been removed
        XCTAssertTrue(set.count == 0)
    }

    func testConcurrentReadsAndRemoveAll() {
        let inputs = ["Test1", "Test2", "Test3", "Test4", "Test5"]
        let set = SFSDKSafeMutableSet.set()
        let group = DispatchGroup()

        for input in inputs {
            set.add(input)
        }

        XCTAssertEqual(set.count, inputs.count)

        for _ in inputs {
            group.enter()
            DispatchQueue.global(qos: .utility).async {
                _ = set.anyObject()
                group.leave()
            }
        }

        group.enter()
        DispatchQueue.global(qos: .default).async {
            set.removeAllObjects()
            group.leave()
        }

        group.wait()

        // Have all items been removed
        XCTAssertTrue(set.count == 0)
    }
}
