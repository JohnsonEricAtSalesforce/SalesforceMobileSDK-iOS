/*
 SFSDKSafeMutableDictionary.swift
 SalesforceSDKCommon

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

/// Thread-safe mutable dictionary using concurrent queue with barrier writes.
/// Note: ObjC lightweight generics erase to `id` at runtime — this class uses untyped
/// parameters for ObjC compatibility. Swift callers can use the generic wrapper below.
@objc(SFSDKSafeMutableDictionary)
@objcMembers
public class SFSDKSafeMutableDictionary: NSObject {

    private var backingDictionary = NSMutableDictionary()
    private let queue: DispatchQueue

    // MARK: - Initializer

    public override init() {
        self.queue = DispatchQueue(
            label: "com.salesforce.mobilesdk.readWriteQueue\(arc4random_uniform(UInt32.max))",
            attributes: .concurrent
        )
        super.init()
    }

    // MARK: - Read Operations

    /// All keys in the dictionary.
    @objc public var allKeys: [Any] {
        var keys: [Any] = []
        queue.sync {
            keys = backingDictionary.allKeys
        }
        return keys
    }

    /// All values in the dictionary.
    @objc public var allValues: [Any] {
        var values: [Any] = []
        queue.sync {
            values = backingDictionary.allValues
        }
        return values
    }

    /// Retrieves object for the key specified (thread safe).
    @objc public func object(forKey aKey: Any) -> Any? {
        var value: Any?
        queue.sync {
            value = backingDictionary[aKey as AnyObject]
        }
        return value
    }


    /// Retrieves all keys for the specified object (thread safe).
    @objc(allKeysForObject:)
    public func allKeys(for anObject: Any) -> [Any] {
        var keys: [Any] = []
        queue.sync {
            keys = backingDictionary.allKeys(for: anObject)
        }
        return keys
    }

    /// Returns an NSDictionary snapshot of the mutable dictionary (thread safe).
    @objc public func dictionary() -> NSDictionary {
        var dict: NSDictionary = NSDictionary()
        queue.sync {
            dict = NSDictionary(dictionary: backingDictionary)
        }
        return dict
    }

    // MARK: - Subscript

    /// Swift subscript for key access.
    public subscript(key: NSCopying) -> Any? {
        get { return object(forKey: key) }
        set {
            if let value = newValue {
                setObject(value, forKey: key)
            } else {
                removeObject(key)
            }
        }
    }

    // MARK: - Mutating Methods

    /// Sets object for key specified (thread safe).
    @objc public func setObject(_ object: Any, forKey aKey: NSCopying) {
        queue.async(flags: .barrier) {
            self.backingDictionary[aKey] = object
        }
    }


    /// Removes object for key specified (thread safe).
    @objc public func removeObject(_ aKey: Any) {
        queue.async(flags: .barrier) {
            self.backingDictionary.removeObject(forKey: aKey)
        }
    }

    /// Removes all objects (thread safe).
    @objc public func removeAllObjects() {
        queue.async(flags: .barrier) {
            self.backingDictionary.removeAllObjects()
        }
    }

    /// Removes objects for keys (thread safe).
    @objc public func removeObjects(_ keys: [Any]) {
        queue.async(flags: .barrier) {
            for key in keys {
                self.backingDictionary.removeObject(forKey: key)
            }
        }
    }

    /// Adds entries from the dictionary passed in (thread safe).
    @objc public func addEntries(_ otherDictionary: NSDictionary) {
        queue.async(flags: .barrier) {
            for (key, value) in otherDictionary {
                self.backingDictionary[key as AnyObject] = value
            }
        }
    }

    /// Sets the dictionary collection to the dictionary passed in (thread safe).
    @objc public func setDictionary(_ dictionary: NSDictionary) {
        queue.async(flags: .barrier) {
            self.backingDictionary.setDictionary(dictionary as? [AnyHashable: Any] ?? [:])
        }
    }
}

// MARK: - Generic Swift Wrapper

/// Type-safe generic wrapper around SFSDKSafeMutableDictionary for use from Swift.
public class SafeMutableDictionary<KeyType: NSCopying, ObjectType: AnyObject> {

    private let backing = SFSDKSafeMutableDictionary()

    public init() {}

    public var allKeys: [Any] { backing.allKeys }
    public var allValues: [Any] { backing.allValues }

    public func object(forKey aKey: KeyType) -> ObjectType? {
        return backing.object(forKey: aKey) as? ObjectType
    }

    public subscript(key: KeyType) -> ObjectType? {
        get { return object(forKey: key) }
        set {
            if let value = newValue {
                setObject(value, forKey: key)
            } else {
                removeObject(key)
            }
        }
    }

    public func setObject(_ object: ObjectType, forKey aKey: KeyType) {
        backing.setObject(object, forKey: aKey)
    }

    public func removeObject(_ aKey: Any) {
        backing.removeObject(aKey)
    }

    public func removeAllObjects() {
        backing.removeAllObjects()
    }

    public func dictionary() -> NSDictionary {
        backing.dictionary()
    }
}
