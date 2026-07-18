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

class SFSDKSafeMutableArrayTests: XCTestCase {

    func testReadWrites() {
        let array = SFSDKSafeMutableArray.array()
        let obj1 = "Test1"
        let obj2 = "Test2"

        array.addObject(obj1)
        array.addObject(obj2)
        array.addObject(NSNumber(value: 10))

        XCTAssertTrue(array.containsObject(obj1))
        XCTAssertTrue(array.containsObject(obj2))
        XCTAssertEqual((array.object(atIndexedSubscript: 0) as AnyObject).description, obj1)
        XCTAssertEqual((array.object(atIndexedSubscript: 1) as AnyObject).description, obj2)
        XCTAssertEqual((array.object(atIndexedSubscript: 2) as? NSNumber)?.intValue, 10)
    }

    func testReadWriteDelete() {
        let array = SFSDKSafeMutableArray.array(withCapacity: 3)
        array.insertObject("Test2", at: 0)
        array.insertObject("Test1", at: 1)

        XCTAssertEqual((array.object(atIndexedSubscript: 0) as AnyObject).description, "Test2")
        XCTAssertEqual((array.object(atIndexedSubscript: 1) as AnyObject).description, "Test1")
        array.removeObject("Test2")
        XCTAssertEqual((array.object(atIndexedSubscript: 0) as AnyObject).description, "Test1")
        array.removeAllObjects()
        XCTAssertTrue(array.count == 0)
    }

    func testConcurrentWrites() {
        let inputs: [Any] = ["Test1", "Test2", "Test3", "Test4", "Test5"]

        let array = SFSDKSafeMutableArray.array()
        let group = DispatchGroup()

        group.enter()
        DispatchQueue.global().async {
            array.addObjects(from: inputs)
            group.leave()
        }

        group.wait()

        // Does the array have the right number of items?
        XCTAssertTrue(array.count == inputs.count)
        // Does the array have each of our items?
        array.enumerateObjects { obj, idx, stop in
            XCTAssertTrue((inputs as NSArray).contains(obj))
            XCTAssertTrue((inputs[idx] as AnyObject).isEqual(obj))
        }
    }

    func testConcurrentReadWrites() {
        let inputs: [Any] = ["Test1", "Test2", "Test3", "Test4", "Test5"]

        let array = SFSDKSafeMutableArray.array()
        let group = DispatchGroup()

        for i in 0..<inputs.count {
            array.addObject(inputs[i])
        }

        array.enumerateObjects { obj, idx, stop in
            group.enter()
            DispatchQueue.global().async {
                XCTAssertNotNil(array.object(atIndexedSubscript: idx))
                group.leave()
            }
        }

        group.wait()
        // Does the array have the right number of items?
        XCTAssertTrue(array.count == inputs.count)
        // Does the array have each of our items?
        array.enumerateObjects { obj, idx, stop in
            XCTAssertTrue((inputs as NSArray).contains(obj))
            XCTAssertTrue((inputs[idx] as AnyObject).isEqual(obj))
        }
    }

    func testConcurrentReadsAndRemove() {
        let inputs: [Any] = ["Test1", "Test2", "Test3", "Test4", "Test5"]

        let array = SFSDKSafeMutableArray.array()
        let group = DispatchGroup()

        for i in 0..<inputs.count {
            array.addObject(inputs[i])
        }

        XCTAssertEqual(array.count, inputs.count)
        array.enumerateObjects { obj, idx, stop in
            group.enter()
            DispatchQueue.global().async {
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

        for i in 0..<inputs.count {
            array.addObject(inputs[i])
        }

        array.enumerateObjects { obj, idx, stop in
            group.enter()
            DispatchQueue.global().async {
                if idx < array.count {
                    // Faithful to the oracle's XCTAssertNotNil(array[idx]): the migrated
                    // API returns a non-optional Any (NSNull() sentinel for a missing slot),
                    // so verify a real object came back rather than the empty sentinel.
                    XCTAssertFalse(array.object(atIndexedSubscript: idx) is NSNull)
                }
                group.leave()
            }
        }

        group.enter()
        DispatchQueue.global(qos: .background).async {
            array.removeAllObjects()
            group.leave()
        }

        group.wait()
        // Have all items been removed
        XCTAssertTrue(array.count == 0)
    }

    func testConcurrentReadsAndRemoveWithIndexes() {
        let inputs: [Any] = ["Test1", "Test2", "Test3", "Test4", "Test5"]

        let array = SFSDKSafeMutableArray.array(withCapacity: 6)
        array.insertObject("Test0", at: 0)
        let group = DispatchGroup()

        let indexSet = IndexSet(integersIn: 1...5)
        array.insertObjects(inputs, at: indexSet)

        XCTAssertEqual(array.count, inputs.count + 1)
        array.enumerateObjects { obj, idx, stop in
            group.enter()
            DispatchQueue.global().async {
                if idx > 0 {
                    XCTAssertTrue((inputs[idx - 1] as AnyObject).isEqual(obj))
                }
                group.leave()
            }
        }

        for i in 0..<inputs.count {
            group.enter()
            let item = inputs[i]
            DispatchQueue.global().async {
                array.removeObjectIdentical(to: item)
                group.leave()
            }
        }

        group.wait()
        // Have all items been removed
        XCTAssertTrue(array.count == 1)
    }
}
