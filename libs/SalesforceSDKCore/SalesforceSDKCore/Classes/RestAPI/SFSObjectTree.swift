//
//  SFSObjectTree.swift
//  SalesforceSDKCore
//
//  Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.
//
//  Redistribution and use of this software in source and binary forms, with or without modification,
//  are permitted provided that the following conditions are met:
//  * Redistributions of source code must retain the above copyright notice, this list of conditions
//    and the following disclaimer.
//  * Redistributions in binary form must reproduce the above copyright notice, this list of
//    conditions and the following disclaimer in the documentation and/or other materials provided
//    with the distribution.
//  * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
//    endorse or promote products derived from this software without specific prior written
//    permission of salesforce.com, inc.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
//  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
//  FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
//  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
//  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
//  WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

import Foundation

/// Helper class for SObject tree requests.
@objc(SFSObjectTree)
@objcMembers
public class SObjectTree: NSObject {

    private let objectType: String
    private let objectTypePlural: String?
    private let referenceId: String
    private let fields: [String: Any]
    private let childrenTrees: [SObjectTree]?

    /// Constructor for an SObject tree node.
    /// - Parameters:
    ///   - objectType: Object type (e.g. "Contact")
    ///   - objectTypePlural: Plural object type (e.g. "Contacts") - can be nil for the root SObject
    ///   - referenceId: Reference id for the root record
    ///   - fields: Fields for the root SObject
    ///   - childrenTrees: Array of SObjectTree for the children SObjects
    @objc public init?(objectType: String,
                        objectTypePlural: String?,
                        referenceId: String,
                        fields: [String: Any],
                        childrenTrees: [SObjectTree]?) {
        self.objectType = objectType
        self.objectTypePlural = objectTypePlural
        self.referenceId = referenceId
        self.fields = fields
        self.childrenTrees = childrenTrees
        super.init()
    }

    /// Returns a dictionary representing the SObject tree as JSON.
    @objc public func asJSON() -> [String: Any] {
        var parentJson = buildJsonForRecord(
            objectType: objectType,
            referenceId: referenceId,
            fields: fields
        )

        if let childrenTrees = childrenTrees {
            // Grouping children trees by type and figuring out object type to object type plural mapping
            var objectTypeToObjectTypePlural: [String: String] = [:]
            var objectTypeToChildrenTrees: [String: [SObjectTree]] = [:]

            for childTree in childrenTrees {
                let childObjectType = childTree.objectType
                if objectTypeToObjectTypePlural[childObjectType] == nil {
                    objectTypeToObjectTypePlural[childObjectType] = childTree.objectTypePlural
                }

                if objectTypeToChildrenTrees[childObjectType] == nil {
                    objectTypeToChildrenTrees[childObjectType] = []
                }
                objectTypeToChildrenTrees[childObjectType]?.append(childTree)
            }

            // Iterating through children
            for (childrenObjectType, childrenTreesForType) in objectTypeToChildrenTrees {
                var childrenJsonArray: [[String: Any]] = []
                for childTree in childrenTreesForType {
                    childrenJsonArray.append(
                        buildJsonForRecord(
                            objectType: childrenObjectType,
                            referenceId: childTree.referenceId,
                            fields: childTree.fields
                        )
                    )
                }
                if let pluralName = objectTypeToObjectTypePlural[childrenObjectType] {
                    parentJson[pluralName] = ["records": childrenJsonArray]
                }
            }
        }

        return parentJson
    }

    // MARK: - Private

    private func buildJsonForRecord(objectType: String, referenceId: String, fields: [String: Any]) -> [String: Any] {
        var jsonForRecord = fields
        jsonForRecord["attributes"] = ["referenceId": referenceId, "type": objectType]
        return jsonForRecord
    }
}
