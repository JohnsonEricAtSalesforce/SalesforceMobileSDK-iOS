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
public class SFObject: SFMobileSyncPersistableObject, NSCoding {

    /** Object Id */
    @objc public private(set) var objectId: String = ""

    /** Object name */
    @objc public private(set) var name: String = ""

    // MARK: - Init Methods

    public override init(dictionary data: [String: Any]) {
        super.init(dictionary: data)
        configure(withDictionary: data)
    }

    public required init?(coder decoder: NSCoder) {
        super.init(dictionary: [:])
        if let rawData = decoder.decodeObject(forKey: kRawData) as? [String: Any] {
            self.rawData = rawData
            configure(withDictionary: rawData)
        }
    }

    private func configure(withDictionary dataDiction: [String: Any]) {
        if let id = dataDiction[kId] as? String {
            self.objectId = id
            self.name = (dataDiction[kName] as? String) ?? ""

            let typeFieldValue = dataDiction[kObjectTypeField] as? String
            var type = SFMobileSyncObjectUtils.formatValue(typeFieldValue) ?? ""

            if type == kRecentlyViewed {
                type = SFMobileSyncObjectUtils.formatValue(dataDiction[kType] as? String) ?? ""
            }
            self.objectType = type
        } else if let id = dataDiction[kId.lowercased()] as? String {
            self.objectId = id
            self.objectType = (dataDiction[kType] as? String) ?? ""
            self.name = (dataDiction[kName.lowercased()] as? String) ?? ""
        }
    }

    public override var description: String {
        return "name:[\(name)], objectId:[\(objectId)], type:[\(objectType)], rawData:[\(rawData)]"
    }

    // MARK: - Equality

    public override var hash: Int {
        return objectId.hashValue
    }

    public override func isEqual(_ object: Any?) -> Bool {
        guard let otherObj = object as? SFObject else {
            return false
        }

        if objectId != otherObj.objectId {
            return false
        }
        if name != otherObj.name {
            return false
        }
        if rawData as NSDictionary != otherObj.rawData as NSDictionary {
            return false
        }
        return true
    }

    // MARK: - NSCoding Protocol

    public func encode(with encoder: NSCoder) {
        encoder.encode(rawData, forKey: kRawData)
    }
}
