/*
 Copyright (c) 2014-present, salesforce.com, inc. All rights reserved.

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

@objc(SFObject)
@objcMembers
open class SFObject: SFMobileSyncPersistableObject, NSCoding {

    @objc public private(set) var objectId: String = ""
    @objc public private(set) var name: String = ""

    // MARK: - Init

    @objc public override init(dictionary data: [String: Any]) {
        super.init(dictionary: data)
        configureData(with: data)
    }

    @objc public override init(dictionary data: [String: Any], forObjectType objectType: String?) {
        super.init(dictionary: data, forObjectType: objectType)
        configureData(with: data)
    }

    // MARK: - Configure

    private func configureData(with data: [String: Any]) {
        if let oid = data[kId] as? String {
            objectId = oid
            name = data[kName] as? String ?? ""
            var typeValue = SFMobileSyncObjectUtils.formatValue((data as NSDictionary).value(forKeyPath: kObjectTypeField)) ?? ""
            if typeValue == kRecentlyViewed {
                typeValue = SFMobileSyncObjectUtils.formatValue(data[kType]) ?? ""
            }
            updateObjectType(typeValue)
        } else {
            objectId = data[kId.lowercased()] as? String ?? ""
            updateObjectType(data[kType] as? String ?? "")
            name = data[kName.lowercased()] as? String ?? ""
        }
    }

    // MARK: - Description

    open override var description: String {
        return "name:[\(name)], objectId:[\(objectId)], type:[\(objectType ?? "")], rawData:[\(rawData ?? [:])]"
    }

    // MARK: - Equality

    open override var hash: Int {
        var result = objectId.hashValue
        result ^= (rawData as NSDictionary?)?.hash ?? 0 &+ result &* 37
        return result
    }

    open override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? SFObject else { return false }
        if objectId != other.objectId { return false }
        if name != other.name { return false }
        if let lhs = rawData as NSDictionary?, let rhs = other.rawData as NSDictionary? {
            if !lhs.isEqual(rhs) { return false }
        } else if rawData != nil || other.rawData != nil {
            return false
        }
        return true
    }

    // MARK: - NSCoding

    @objc public func encode(with coder: NSCoder) {
        if let rawData = rawData {
            coder.encode(rawData, forKey: kRawData)
        }
    }

    @objc public required init?(coder: NSCoder) {
        super.init(dictionary: [:])
        rawData = coder.decodeObject(forKey: kRawData) as? [String: Any]
        if let rawData = rawData {
            configureData(with: rawData)
        }
    }
}
