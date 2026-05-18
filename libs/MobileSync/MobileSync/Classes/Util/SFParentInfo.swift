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

public let kSFParentInfoSObjectType: String = "sobjectType"
public let kSFParentInfoSoupName: String = "soupName"
public let kSFParentInfoIdFieldName: String = "idFieldName"
public let kSFParentInfoModificationDateFieldName: String = "modificationDateFieldName"
public let kSFParentInfoExternalIdFieldName: String = "externalIdFieldName"

// Keep the original constant name for ObjC compatibility (note the typo "Modifification" in the original)
public let kSFParentInfoModifificationDateFieldName: String = "modificationDateFieldName"

/// Simple object to capture details of parent in parent-child relationship
@objc(SFParentInfo)
@objcMembers
open class SFParentInfo: NSObject {

    @objc public private(set) var sobjectType: String = ""
    @objc public private(set) var idFieldName: String = ""
    @objc public private(set) var modificationDateFieldName: String = ""
    @objc public private(set) var soupName: String = ""
    @objc public private(set) var externalIdFieldName: String?

    // MARK: - Init

    public override init() {
        self.sobjectType = ""
        self.soupName = ""
        self.idFieldName = ""
        self.modificationDateFieldName = ""
        self.externalIdFieldName = nil
        super.init()
    }

    @objc public init(sobjectType: String, soupName: String, idFieldName: String, modificationDateFieldName: String, externalIdFieldName: String?) {
        self.sobjectType = sobjectType
        self.soupName = soupName
        self.idFieldName = idFieldName
        self.modificationDateFieldName = modificationDateFieldName
        self.externalIdFieldName = externalIdFieldName
        super.init()
    }

    // MARK: - Factory methods

    @objc public class func new(withSObjectType sobjectType: String, soupName: String) -> SFParentInfo {
        return SFParentInfo(sobjectType: sobjectType, soupName: soupName, idFieldName: kId, modificationDateFieldName: kLastModifiedDate, externalIdFieldName: nil)
    }

    @objc public class func new(withSObjectType sobjectType: String, soupName: String, idFieldName: String, modificationDateFieldName: String) -> SFParentInfo {
        return SFParentInfo(sobjectType: sobjectType, soupName: soupName, idFieldName: idFieldName, modificationDateFieldName: modificationDateFieldName, externalIdFieldName: nil)
    }

    @objc public class func new(withSObjectType sobjectType: String, soupName: String, idFieldName: String, modificationDateFieldName: String, externalIdFieldName: String?) -> SFParentInfo {
        return SFParentInfo(sobjectType: sobjectType, soupName: soupName, idFieldName: idFieldName, modificationDateFieldName: modificationDateFieldName, externalIdFieldName: externalIdFieldName)
    }

    @objc public class func new(fromDict dict: [String: Any]) -> SFParentInfo {
        return SFParentInfo(
            sobjectType: dict[kSFParentInfoSObjectType] as? String ?? "",
            soupName: dict[kSFParentInfoSoupName] as? String ?? "",
            idFieldName: dict[kSFParentInfoIdFieldName] as? String ?? kId,
            modificationDateFieldName: dict[kSFParentInfoModificationDateFieldName] as? String ?? kLastModifiedDate,
            externalIdFieldName: dict[kSFParentInfoExternalIdFieldName] as? String
        )
    }

    // MARK: - To dictionary

    @objc public func asDict() -> [String: Any] {
        var dict = [String: Any]()
        dict[kSFParentInfoSObjectType] = sobjectType
        dict[kSFParentInfoIdFieldName] = idFieldName
        dict[kSFParentInfoModificationDateFieldName] = modificationDateFieldName
        dict[kSFParentInfoSoupName] = soupName
        if let externalIdFieldName = externalIdFieldName {
            dict[kSFParentInfoExternalIdFieldName] = externalIdFieldName
        }
        return dict
    }
}
