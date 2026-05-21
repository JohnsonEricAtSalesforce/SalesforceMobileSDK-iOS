/*
 SFSDKSafeMutableArray.swift
 SalesforceSDKCommon

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

import Foundation

/// Thread-safe mutable array using concurrent queue with barrier writes.
@objc(SFSDKSafeMutableArray)
@objcMembers
public class SFSDKSafeMutableArray: NSObject, NSMutableCopying {

    private var backingArray: NSMutableArray
    private let queue: DispatchQueue

    // MARK: - Initializers

    public override init() {
        self.backingArray = NSMutableArray()
        self.queue = DispatchQueue(
            label: "com.salesforce.mobilesdk.readWriteArrayQ\(arc4random_uniform(UInt32.max))",
            attributes: .concurrent
        )
        super.init()
    }

    @objc public init(capacity numItems: Int) {
        self.backingArray = NSMutableArray(capacity: numItems)
        self.queue = DispatchQueue(
            label: "com.salesforce.mobilesdk.readWriteArrayQ\(arc4random_uniform(UInt32.max))",
            attributes: .concurrent
        )
        super.init()
    }

    // MARK: - Read Operations

    /// The number of elements in this array.
    @objc public var count: Int {
        var size: Int = 0
        queue.sync {
            size = backingArray.count
        }
        return size
    }

    /// Returns a new instance that is a mutable copy of the receiver.
    public func mutableCopy(with zone: NSZone? = nil) -> Any {
        let mutableCopy = SFSDKSafeMutableArray()
        queue.sync {
            mutableCopy.backingArray = self.backingArray.mutableCopy() as? NSMutableArray ?? NSMutableArray()
        }
        return mutableCopy
    }

    /// Returns true if the object exists in the array.
    @objc public func containsObject(_ anObject: Any) -> Bool {
        var exists = false
        queue.sync {
            exists = backingArray.contains(anObject as AnyObject)
        }
        return exists
    }

    /// Returns the object at the specified index (subscript).
    @objc public func object(atIndexedSubscript idx: Int) -> Any {
        var object: Any = NSNull()
        queue.sync {
            object = backingArray[idx]
        }
        return object
    }

    /// Returns the object at the specified index.
    @objc public func object(atIndexed idx: Int) -> Any {
        var object: Any = NSNull()
        queue.sync {
            object = backingArray.object(at: idx)
        }
        return object
    }

    /// Returns an NSArray snapshot of the mutable array.
    @objc public func asArray() -> NSArray {
        var array: NSArray = NSArray()
        queue.sync {
            array = NSArray(array: backingArray)
        }
        return array
    }

    /// Enumerate objects in the array safely, using a block.
    @objc(enumerateObjectsUsingBlock:)
    public func enumerateObjects(using block: @escaping (Any, Int, UnsafeMutablePointer<ObjCBool>) -> Void) {
        queue.sync {
            backingArray.enumerateObjects { obj, idx, stop in
                block(obj, idx, stop)
            }
        }
    }

    // MARK: - Mutating Methods

    /// Inserts a given object at the end of the array.
    @objc public func addObject(_ obj: Any) {
        queue.async(flags: .barrier) {
            self.backingArray.add(obj)
        }
    }

    /// Adds the objects contained in another given array to the end of the receiving array's content.
    @objc(addObjectsFromArray:)
    public func addObjects(from array: [Any]) {
        queue.async(flags: .barrier) {
            self.backingArray.addObjects(from: array)
        }
    }

    /// Inserts a given object into the array's contents at a given index.
    @objc(insertObject:atIndex:)
    public func insertObject(_ obj: Any, at index: Int) {
        queue.async(flags: .barrier) {
            self.backingArray.insert(obj, at: index)
        }
    }

    /// Inserts the objects in the provided array into the receiving array at the specified indexes.
    @objc(insertObjects:atIndexes:)
    public func insertObjects(_ objects: [Any], at indexes: IndexSet) {
        queue.async(flags: .barrier) {
            self.backingArray.insert(objects, at: indexes)
        }
    }

    /// Removes all objects from the array.
    @objc public func removeAllObjects() {
        queue.async(flags: .barrier) {
            self.backingArray.removeAllObjects()
        }
    }

    /// Removes the object with the highest-valued index in the array.
    @objc public func removeLastObject() {
        queue.async(flags: .barrier) {
            self.backingArray.removeLastObject()
        }
    }

    /// Removes all occurrences in the array of a given object.
    @objc public func removeObject(_ object: Any) {
        queue.async(flags: .barrier) {
            self.backingArray.remove(object)
        }
    }

    /// Removes the object at the given index.
    @objc(removeObjectAtIndex:)
    public func removeObject(at index: Int) {
        queue.async(flags: .barrier) {
            self.backingArray.removeObject(at: index)
        }
    }

    /// Removes the objects at the specified indexes from the array.
    @objc(removeObjectsAtIndexes:)
    public func removeObjects(at indexes: IndexSet) {
        queue.async(flags: .barrier) {
            self.backingArray.removeObjects(at: indexes)
        }
    }

    /// Removes all occurrences of a given object (by identity) in the array.
    @objc(removeObjectIdenticalTo:)
    public func removeObjectIdentical(to object: Any) {
        queue.async(flags: .barrier) {
            self.backingArray.removeObject(identicalTo: object)
        }
    }

    /// Removes all occurrences of a given object (by identity) within the specified range.
    @objc(removeObjectIdenticalTo:inRange:)
    public func removeObjectIdentical(to object: Any, in range: NSRange) {
        queue.async(flags: .barrier) {
            self.backingArray.removeObject(identicalTo: object, in: range)
        }
    }

    /// Removes all occurrences within a specified range in the array of a given object.
    @objc(removeObject:inRange:)
    public func removeObject(_ object: Any, in range: NSRange) {
        queue.async(flags: .barrier) {
            self.backingArray.remove(object, in: range)
        }
    }

    /// Removes from the receiving array the objects in another given array.
    @objc(removeObjectsInArray:)
    public func removeObjects(in otherArray: [Any]) {
        queue.async(flags: .barrier) {
            self.backingArray.removeObjects(in: otherArray)
        }
    }

    /// Removes from the array each of the objects within a given range.
    @objc(removeObjectsInRange:)
    public func removeObjects(in range: NSRange) {
        queue.async(flags: .barrier) {
            self.backingArray.removeObjects(in: range)
        }
    }

    /// Replaces the object at the index with the new object.
    @objc public func setObject(_ object: Any, atIndexedSubscript index: Int) {
        queue.async(flags: .barrier) {
            self.backingArray[index] = object
        }
    }

    /// Empties the array, then adds each object from the other array.
    @objc public func setArray(_ otherArray: [Any]) {
        queue.async(flags: .barrier) {
            self.backingArray.setArray(otherArray)
        }
    }

    /// Filter the array using a predicate.
    @objc(filterUsingPredicate:)
    public func filter(using predicate: NSPredicate) {
        queue.async(flags: .barrier) {
            self.backingArray.filter(using: predicate)
        }
    }

    // MARK: - Class Factory Methods

    /// Allocates and initializes a new SFSDKSafeMutableArray instance.
    @objc public class func array() -> SFSDKSafeMutableArray {
        return SFSDKSafeMutableArray()
    }

    /// Allocates and initializes a new SFSDKSafeMutableArray instance with a capacity hint.
    @objc public class func array(withCapacity numItems: Int) -> SFSDKSafeMutableArray {
        return SFSDKSafeMutableArray(capacity: numItems)
    }
}

/// Typealias preserving the NS_SWIFT_NAME from the original ObjC header.
public typealias SafeMutableArray = SFSDKSafeMutableArray
