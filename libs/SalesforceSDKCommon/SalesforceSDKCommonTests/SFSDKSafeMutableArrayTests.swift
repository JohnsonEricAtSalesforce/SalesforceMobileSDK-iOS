//
//  SFSDKSafeMutableArrayTests.swift
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

final class SFSDKSafeMutableArrayTests: XCTestCase {

    func testReadWrites() {
        let array = SFSDKSafeMutableArray.array()
        let obj1 = "Test1"
        let obj2 = "Test2"

        array.add(obj1)
        array.add(obj2)
        array.add(NSNumber(value: 10))

        XCTAssertTrue(array.contains(obj1))
        XCTAssertTrue(array.contains(obj2))
        XCTAssertEqual((array[0] as AnyObject).description, obj1)
        XCTAssertEqual((array[1] as AnyObject).description, obj2)
        XCTAssertEqual((array[2] as? NSNumber)?.intValue, 10)
    }

    func testReadWriteDelete() {
        let array = SFSDKSafeMutableArray(capacity: 3)
        array.insert("Test2", at: 0)
        array.insert("Test1", at: 1)

        XCTAssertEqual((array[0] as AnyObject).description, "Test2")
        XCTAssertEqual((array[1] as AnyObject).description, "Test1")
        array.remove("Test2")
        XCTAssertEqual((array[0] as AnyObject).description, "Test1")
        array.removeAllObjects()
        XCTAssertTrue(array.count == 0)
    }

    func testConcurrentWrites() {
        let inputs: [Any] = ["Test1", "Test2", "Test3", "Test4", "Test5"]
        let array = SFSDKSafeMutableArray.array()
        let group = DispatchGroup()

        group.enter()
        DispatchQueue.global(qos: .default).async {
            array.addObjects(from: inputs)
            group.leave()
        }

        group.wait()

        // Does the array have the right number of items?
        XCTAssertTrue(array.count == inputs.count)
        // Does the array have each of our items?
        array.enumerateObjects { obj, idx, _ in
            XCTAssertTrue((inputs as NSArray).contains(obj))
            XCTAssertEqual(inputs[idx] as? String, obj as? String)
        }
    }

    func testConcurrentReadWrites() {
        let inputs: [Any] = ["Test1", "Test2", "Test3", "Test4", "Test5"]
        let array = SFSDKSafeMutableArray.array()
        let group = DispatchGroup()

        for input in inputs {
            array.add(input)
        }

        array.enumerateObjects { _, idx, _ in
            group.enter()
            DispatchQueue.global(qos: .default).async {
                XCTAssertNotNil(array[idx])
                group.leave()
            }
        }

        group.wait()

        // Does the array have the right number of items?
        XCTAssertTrue(array.count == inputs.count)
        // Does the array have each of our items?
        array.enumerateObjects { obj, idx, _ in
            XCTAssertTrue((inputs as NSArray).contains(obj))
            XCTAssertEqual(inputs[idx] as? String, obj as? String)
        }
    }

    func testConcurrentReadsAndRemove() {
        let inputs: [Any] = ["Test1", "Test2", "Test3", "Test4", "Test5"]
        let array = SFSDKSafeMutableArray.array()
        let group = DispatchGroup()

        for input in inputs {
            array.add(input)
        }

        XCTAssertEqual(array.count, inputs.count)

        array.enumerateObjects { _, _, _ in
            group.enter()
            DispatchQueue.global(qos: .default).async {
                array.removeLastObject()
                group.leave()
            }
        }

        group.wait()

        // Have all items been removed
        XCTAssertTrue(array.count == 0)
    }

    func testConcurrentReadsAndRemoveAll() {
        let inputs: [Any] = ["Test1", "Test2", "Test3", "Test4", "Test5"]
        let array = SFSDKSafeMutableArray.array()
        let group = DispatchGroup()

        for input in inputs {
            array.add(input)
        }

        array.enumerateObjects { _, idx, _ in
            group.enter()
            DispatchQueue.global(qos: .default).async {
                if idx < array.count {
                    XCTAssertNotNil(array[idx])
                }
                group.leave()
            }
        }

        group.enter()
        DispatchQueue.global(qos: .utility).async {
            array.removeAllObjects()
            group.leave()
        }

        group.wait()

        // Have all items been removed
        XCTAssertTrue(array.count == 0)
    }

    func testConcurrentReadsAndRemoveWithIndexes() {
        let inputs: [Any] = ["Test1", "Test2", "Test3", "Test4", "Test5"]
        let array = SFSDKSafeMutableArray(capacity: 6)
        array.insert("Test0", at: 0)
        let group = DispatchGroup()

        let indexSet = IndexSet(integersIn: 1...5)
        array.insert(inputs, at: indexSet)

        XCTAssertEqual(array.count, inputs.count + 1)

        array.enumerateObjects { obj, idx, _ in
            group.enter()
            DispatchQueue.global(qos: .default).async {
                if idx > 0 {
                    XCTAssertEqual(inputs[idx - 1] as? String, obj as? String)
                }
                group.leave()
            }
        }

        for input in inputs {
            group.enter()
            DispatchQueue.global(qos: .default).async {
                array.removeObjectIdentical(to: input)
                group.leave()
            }
        }

        group.wait()

        // Have all items been removed (only "Test0" should remain)
        XCTAssertTrue(array.count == 1)
    }
}
