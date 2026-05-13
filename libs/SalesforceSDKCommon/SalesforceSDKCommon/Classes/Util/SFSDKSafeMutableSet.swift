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

import Foundation

@objc(SFSDKSafeMutableSet)
@objcMembers
public class SFSDKSafeMutableSet: NSObject {

    private var backingSet: NSMutableSet
    private let queue: DispatchQueue

    public override init() {
        self.backingSet = NSMutableSet()
        self.queue = DispatchQueue(
            label: "com.salesforce.mobilesdk.readWriteSetQ\(arc4random_uniform(UInt32.max))",
            attributes: .concurrent
        )
        super.init()
    }

    @objc
    public init(capacity numItems: Int) {
        self.backingSet = NSMutableSet(capacity: numItems)
        self.queue = DispatchQueue(
            label: "com.salesforce.mobilesdk.readWriteSetQ\(arc4random_uniform(UInt32.max))",
            attributes: .concurrent
        )
        super.init()
    }

    /// The number of elements in this set.
    @objc
    public var count: Int {
        var size = 0
        queue.sync {
            size = backingSet.count
        }
        return size
    }

    /// Adds a given object to the set, if it is not already a member.
    @objc
    public func anyObject() -> Any? {
        var object: Any?
        queue.sync {
            object = backingSet.anyObject()
        }
        return object
    }

    /// Returns true if the object exists in the set.
    @objc(containsObject:)
    public func contains(_ anObject: Any) -> Bool {
        var exists = false
        queue.sync {
            exists = backingSet.contains(anObject)
        }
        return exists
    }

    /// Return an Array of all Objects
    @objc
    public func allObjects() -> [Any] {
        var array: [Any] = []
        queue.sync {
            array = backingSet.allObjects
        }
        return array
    }

    /// Get a NSSet from the mutable set
    @objc
    public func asSet() -> Set<AnyHashable> {
        var set = Set<AnyHashable>()
        queue.sync {
            set = backingSet as! Set<AnyHashable>
        }
        return set
    }

    /// Returns true if the sets are equal.
    @objc(isEqualToSet:)
    public func isEqual(to otherSet: SFSDKSafeMutableSet) -> Bool {
        guard self != otherSet else {
            return true
        }
        let thisSet = self.asSet()
        let thatSet = otherSet.asSet()
        return thisSet == thatSet
    }

    /// Enumerate objects in the set safely, using a block.
    @objc(enumerateObjectsUsingBlock:)
    public func enumerateObjects(using block: @escaping (Any, UnsafeMutablePointer<ObjCBool>) -> Void) {
        let array = allObjects()
        queue.sync(flags: .barrier) {
            for obj in array {
                var stop: ObjCBool = false
                block(obj, &stop)
                if stop.boolValue {
                    break
                }
            }
        }
    }

    // MARK: - Mutating Methods

    /// Adds a given object to the set, if it is not already a member.
    @objc(addObject:)
    public func add(_ obj: Any) {
        queue.async(flags: .barrier) {
            self.backingSet.add(obj)
        }
    }

    /// Adds to the set each object contained in a given array that is not already a member.
    @objc(addObjectsFromArray:)
    public func addObjects(from array: [Any]) {
        queue.async(flags: .barrier) {
            self.backingSet.addObjects(from: array)
        }
    }

    /// Removes all objects from the set.
    @objc
    public func removeAllObjects() {
        queue.async(flags: .barrier) {
            self.backingSet.removeAllObjects()
        }
    }

    /// Removes a given object from the set.
    @objc(removeObject:)
    public func remove(_ object: Any) {
        queue.async(flags: .barrier) {
            self.backingSet.remove(object)
        }
    }

    /// Removes each object in another given set from the receiving set, if present.
    @objc(unionSet:)
    public func union(_ otherSet: Set<AnyHashable>) {
        queue.async(flags: .barrier) {
            self.backingSet.union(otherSet)
        }
    }

    /// Empties the receiving set, then adds each object contained in another given set.
    @objc(minusSet:)
    public func minus(_ set: Set<AnyHashable>) {
        queue.async(flags: .barrier) {
            self.backingSet.minus(set)
        }
    }

    /// Empties the receiving set, then adds each object contained in another given set.
    @objc(intersectSet:)
    public func intersect(_ otherSet: Set<AnyHashable>) {
        queue.async(flags: .barrier) {
            self.backingSet.intersect(otherSet)
        }
    }

    /// Empties the receiving set, then adds each object contained in another given set.
    @objc(setSet:)
    public func setSet(_ otherSet: Set<AnyHashable>) {
        queue.async(flags: .barrier) {
            self.backingSet.setSet(otherSet)
        }
    }

    /// Filter the set using a predicate.
    @objc(filterUsingPredicate:)
    public func filter(using predicate: NSPredicate) {
        queue.async(flags: .barrier) {
            self.backingSet.filter(using: predicate)
        }
    }

    // MARK: - Class Level

    /// A convenience method to allocate and initialize a new instance of a SFSDKSafeMutableSet.
    /// - Returns: A new SFSDKSafeMutableSet instance.
    @objc
    public static func set() -> SFSDKSafeMutableSet {
        return SFSDKSafeMutableSet()
    }

    /// A convenience method to allocate and initialize a new instance of a SFSDKSafeMutableSetWithCapacity.
    /// - Returns: A new SFSDKSafeMutableSet instance.
    @objc(setWithCapacity:)
    public static func set(withCapacity numItems: Int) -> SFSDKSafeMutableSet {
        return SFSDKSafeMutableSet(capacity: numItems)
    }
}
