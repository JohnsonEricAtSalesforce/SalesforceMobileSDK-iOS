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

public let kSFChildrenInfoSObjectTypePlural: String = "sobjectTypePlural"
public let kSFChildrenInfoParentIdFieldName: String = "parentIdFieldName"

/// Simple object to capture details of children in parent-child relationship
@objc(SFChildrenInfo)
@objcMembers
public class SFChildrenInfo: SFParentInfo {

    @objc public private(set) var sobjectTypePlural: String = ""
    @objc public private(set) var parentIdFieldName: String = ""

    // MARK: - Init

    public override init() {
        self.sobjectTypePlural = ""
        self.parentIdFieldName = ""
        super.init()
    }

    @objc public init(sobjectType: String, sobjectTypePlural: String, soupName: String, parentIdFieldName: String, idFieldName: String, modificationDateFieldName: String, externalIdFieldName: String?) {
        self.sobjectTypePlural = sobjectTypePlural
        self.parentIdFieldName = parentIdFieldName
        super.init(sobjectType: sobjectType, soupName: soupName, idFieldName: idFieldName, modificationDateFieldName: modificationDateFieldName, externalIdFieldName: externalIdFieldName)
    }

    // MARK: - Factory methods

    @objc public class func new(withSObjectType sobjectType: String, sobjectTypePlural: String, soupName: String, parentIdFieldName: String) -> SFChildrenInfo {
        return SFChildrenInfo(sobjectType: sobjectType, sobjectTypePlural: sobjectTypePlural, soupName: soupName, parentIdFieldName: parentIdFieldName, idFieldName: kId, modificationDateFieldName: kLastModifiedDate, externalIdFieldName: nil)
    }

    @objc public class func new(withSObjectType sobjectType: String, sobjectTypePlural: String, soupName: String, parentIdFieldName: String, idFieldName: String, modificationDateFieldName: String) -> SFChildrenInfo {
        return SFChildrenInfo(sobjectType: sobjectType, sobjectTypePlural: sobjectTypePlural, soupName: soupName, parentIdFieldName: parentIdFieldName, idFieldName: idFieldName, modificationDateFieldName: modificationDateFieldName, externalIdFieldName: nil)
    }

    @objc public class func new(withSObjectType sobjectType: String, sobjectTypePlural: String, soupName: String, parentIdFieldName: String, idFieldName: String, modificationDateFieldName: String, externalIdFieldName: String?) -> SFChildrenInfo {
        return SFChildrenInfo(sobjectType: sobjectType, sobjectTypePlural: sobjectTypePlural, soupName: soupName, parentIdFieldName: parentIdFieldName, idFieldName: idFieldName, modificationDateFieldName: modificationDateFieldName, externalIdFieldName: externalIdFieldName)
    }

    @objc public override class func new(fromDict dict: [String: Any]) -> SFChildrenInfo {
        return SFChildrenInfo(
            sobjectType: dict[kSFParentInfoSObjectType] as? String ?? "",
            sobjectTypePlural: dict[kSFChildrenInfoSObjectTypePlural] as? String ?? "",
            soupName: dict[kSFParentInfoSoupName] as? String ?? "",
            parentIdFieldName: dict[kSFChildrenInfoParentIdFieldName] as? String ?? "",
            idFieldName: dict[kSFParentInfoIdFieldName] as? String ?? kId,
            modificationDateFieldName: dict[kSFParentInfoModificationDateFieldName] as? String ?? kLastModifiedDate,
            externalIdFieldName: dict[kSFParentInfoExternalIdFieldName] as? String
        )
    }

    // MARK: - To dictionary

    @objc public override func asDict() -> [String: Any] {
        var dict = super.asDict()
        dict[kSFChildrenInfoSObjectTypePlural] = sobjectTypePlural
        dict[kSFChildrenInfoParentIdFieldName] = parentIdFieldName
        return dict
    }
}
