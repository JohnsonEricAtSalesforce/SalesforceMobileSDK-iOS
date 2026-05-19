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
import SmartStore
import MobileSync

let kSObjectIdField = "Id"

@objcMembers
class SObjectDataSpec: NSObject {
    var objectType: String
    var objectFieldSpecs: [SObjectDataFieldSpec]
    var soupName: String
    var orderByFieldName: String

    var fieldNames: [String] {
        return objectFieldSpecs.map { $0.fieldName }
    }

    var soupFieldNames: [String] {
        return objectFieldSpecs.map { "{\(soupName):\($0.fieldName)}" }
    }

    init(objectType: String, objectFieldSpecs: [SObjectDataFieldSpec], soupName: String, orderByFieldName: String) {
        self.objectType = objectType
        self.objectFieldSpecs = SObjectDataSpec.buildObjectFieldSpecs(objectFieldSpecs)
        self.soupName = soupName
        self.orderByFieldName = orderByFieldName
        super.init()
    }

    class func createSObjectData(_ soupDict: [String: Any]) -> SObjectData {
        fatalError("You must override createSObjectData(_:) in a subclass")
    }

    // MARK: - Private methods

    private static func buildObjectFieldSpecs(_ origObjectFieldSpecs: [SObjectDataFieldSpec]) -> [SObjectDataFieldSpec] {
        let foundIdFieldSpec = origObjectFieldSpecs.contains { $0.fieldName == kSObjectIdField }

        if !foundIdFieldSpec {
            var objectFieldSpecsWithId = origObjectFieldSpecs
            let idSpec = SObjectDataFieldSpec(fieldName: kSObjectIdField, searchable: false)
            objectFieldSpecsWithId.insert(idSpec, at: 0)
            return objectFieldSpecsWithId
        } else {
            return origObjectFieldSpecs
        }
    }
}
