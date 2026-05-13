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

import Foundation

// Note: Generic classes cannot have explicit @objc names or @objcMembers
// Methods using generic type parameters are not exposed to Objective-C
public class SFSDKSafeMutableDictionary<KeyType: NSCopying, ObjectType: AnyObject>: NSObject {

    private var backingDictionary: NSMutableDictionary
    private let queue: DispatchQueue

    public override init() {
        self.backingDictionary = NSMutableDictionary()
        self.queue = DispatchQueue(
            label: "com.salesforce.mobilesdk.readWriteQueue\(arc4random_uniform(UInt32.max))",
            attributes: .concurrent
        )
        super.init()
    }

    public var allKeys: [Any] {
        var keys: [Any] = []
        queue.sync {
            keys = backingDictionary.allKeys
        }
        return keys
    }

    public var allValues: [Any] {
        var values: [Any] = []
        queue.sync {
            values = backingDictionary.allValues
        }
        return values
    }

    /// Retrieves object for the key specified (Thread Safe)
    /// - Returns: object for specified key
    public func object(forKey aKey: KeyType) -> ObjectType? {
        var value: ObjectType?
        queue.sync {
            value = backingDictionary[aKey] as? ObjectType
        }
        return value
    }

    /// Retrieves object for the key specified (Thread Safe)
    /// - Returns: object for specified key
    public subscript(key: KeyType) -> ObjectType? {
        get {
            return object(forKey: key)
        }
        set {
            if let newValue = newValue {
                setObject(newValue, forKey: key)
            } else {
                removeObject(key)
            }
        }
    }

    /// Retreives all keys for object specified (Thread Safe)
    /// - Returns: Array with keys
    public func allKeys(for anObject: ObjectType) -> [KeyType] {
        var keys: [KeyType] = []
        queue.sync {
            if let foundKeys = backingDictionary.allKeys(for: anObject) as? [KeyType] {
                keys = foundKeys
            }
        }
        return keys
    }

    /// Get a NSDictionary from the mutable Dictionary (Thread Safe)
    public func dictionary() -> [AnyHashable: Any] {
        var dict: [AnyHashable: Any] = [:]
        queue.sync {
            dict = backingDictionary as? [AnyHashable: Any] ?? [:]
        }
        return dict
    }

    // MARK: - Mutating Methods

    /// Sets object for key specified (Thread Safe)
    /// - Parameters:
    ///   - object: to add to collection
    ///   - aKey: for to map the object to
    public func setObject(_ object: ObjectType, forKey aKey: KeyType) {
        guard aKey is NSObject else {
            SFLogger.log(type(of: self), level: .default, message: "Attempted to set object with nil key in safe dictionary")
            return
        }

        queue.async(flags: .barrier) {
            self.backingDictionary[aKey] = object
        }
    }

    /// Removes object for key specified (Thread Safe)
    /// - Parameter aKey: to remove from the collection.
    public func removeObject(_ aKey: KeyType) {
        guard aKey is NSObject else {
            SFLogger.log(type(of: self), level: .default, message: "Attempted to remove nil key from safe dictionary")
            return
        }

        queue.async(flags: .barrier) {
            self.backingDictionary.removeObject(forKey: aKey)
        }
    }

    /// removes all objects (Thread Safe)
    public func removeAllObjects() {
        queue.async(flags: .barrier) {
            self.backingDictionary.removeAllObjects()
        }
    }

    /// removes objects for keys (Thread Safe)
    /// - Parameter keys: to remove from the collection.
    public func removeObjects(_ keys: [KeyType]) {
        queue.async(flags: .barrier) {
            self.backingDictionary.removeObjects(forKeys: keys)
        }
    }

    /// Adds entries from the dictionary passed in (Thread Safe)
    /// - Parameter otherDictionary: to add to collection
    public func addEntries(_ otherDictionary: [AnyHashable: Any]) {
        queue.async(flags: .barrier) {
            self.backingDictionary.addEntries(from: otherDictionary)
        }
    }

    /// Sets the dictionary collection to the dictionary passed in(Thread Safe)
    /// - Parameter dictionary: to set
    public func setDictionary(_ dictionary: [AnyHashable: Any]) {
        queue.async(flags: .barrier) {
            self.backingDictionary.setDictionary(dictionary)
        }
    }
}
