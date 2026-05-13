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
import SmartStore
import SalesforceSDKCore

// Possible values for relationship type
@objc(SFParentChildrenRelationshipType)
public enum RelationshipType: Int {
    case masterDetail
    case lookup
}

public let kSFParentChildrenSyncTargetParent = "parent"

public let kSFParentChildrenSyncTargetChildren = "children"

public let kSFParentChildrenSyncTargetRelationshipType = "relationshipType"

public let kSFParentChildrenSyncTargetParentFieldlist = "parentFieldlist"

public let kSFParentChildrenSyncTargetParentSoqlFilter = "parentSoqlFilter"

public let kSFParentChildrenSyncTargetChildrenFieldlist = "childrenFieldlist"

public let kSFParentChildrenSyncTargetChildrenCreateFieldlist = "childrenCreateFieldlist"

public let kSFParentChildrenSyncTargetChildrenUpdateFieldlist = "childrenUpdateFieldlist"

public let kSFParentChildrenRelationshipMasterDetail = "MASTER_DETAIL"

public let kSFParentChildrenRelationshipLookup = "LOOKUP"

private let kSFAppFeatureRelatedRecords = "RR"

@objc(SFParentChildrenSyncHelper)
public class ParentChildrenSyncHelper: NSObject {

    // MARK: - App feature registration

    @objc(registerAppFeature)
    public static func registerAppFeature() {
        SFSDKAppFeatureMarkers.registerAppFeature(kSFAppFeatureRelatedRecords)
    }

    // MARK: - Enum to/from string helper methods

    /**
     * Enum to/from string helper methods
     */
    @objc(relationshipTypeFromString:)
    public static func relationshipType(fromString relationshipType: String) -> RelationshipType {
        if relationshipType == kSFParentChildrenRelationshipMasterDetail {
            return .masterDetail
        } else {
            return .lookup
        }
    }

    @objc(relationshipTypeToString:)
    public static func relationshipTypeToString(_ relationshipType: RelationshipType) -> String {
        switch relationshipType {
        case .masterDetail: return kSFParentChildrenRelationshipMasterDetail
        case .lookup: return kSFParentChildrenRelationshipLookup
        }
    }

    // MARK: - Other methods

    @objc(getDirtyRecordIdsSql:childrenInfo:parentFieldToSelect:)
    public static func getDirtyRecordIdsSql(_ parentInfo: SFParentInfo, childrenInfo: SFChildrenInfo, parentFieldToSelect: String) -> String {
        return """
        SELECT DISTINCT {\(parentInfo.soupName):\(parentFieldToSelect)} FROM {\(parentInfo.soupName)} WHERE {\(parentInfo.soupName):\(syncTargetLocal)} = 1 OR EXISTS (SELECT {\(childrenInfo.soupName):\(childrenInfo.idFieldName)} FROM {\(childrenInfo.soupName)} WHERE {\(childrenInfo.soupName):\(childrenInfo.parentIdFieldName)} = {\(parentInfo.soupName):\(parentInfo.idFieldName)} AND {\(childrenInfo.soupName):\(syncTargetLocal)} = 1)
        """
    }

    @objc(getNonDirtyRecordIdsSql:childrenInfo:parentFieldToSelect:additionalPredicate:)
    public static func getNonDirtyRecordIdsSql(_ parentInfo: SFParentInfo, childrenInfo: SFChildrenInfo, parentFieldToSelect: String, additionalPredicate: String) -> String {
        return """
        SELECT DISTINCT {\(parentInfo.soupName):\(parentFieldToSelect)} FROM {\(parentInfo.soupName)} WHERE {\(parentInfo.soupName):\(syncTargetLocal)} = 0 \(additionalPredicate) AND NOT EXISTS (SELECT {\(childrenInfo.soupName):\(childrenInfo.idFieldName)} FROM {\(childrenInfo.soupName)} WHERE {\(childrenInfo.soupName):\(childrenInfo.parentIdFieldName)} = {\(parentInfo.soupName):\(parentInfo.idFieldName)} AND {\(childrenInfo.soupName):\(syncTargetLocal)} = 1)
        """
    }

    @objc(saveRecordTreesToLocalStore:target:parentInfo:childrenInfo:recordTrees:syncId:)
    public static func saveRecordTreesToLocalStore(_ syncManager: MobileSyncSyncManager, target: SyncTarget, parentInfo: SFParentInfo, childrenInfo: SFChildrenInfo, recordTrees: [Any], syncId: NSNumber) {
        var parentRecords: [[String: Any]] = []
        var childrenRecords: [[String: Any]] = []

        for recordTree in recordTrees {
            guard var parent = recordTree as? [String: Any] else { continue }

            // Separating parent from children
            let children = parent[childrenInfo.sobjectTypePlural] as? [[String: Any]]
            parent.removeValue(forKey: childrenInfo.sobjectTypePlural)
            parentRecords.append(parent)

            // Put server id of parent in children
            if let children = children {
                for child in children {
                    var updatedChild = child
                    updatedChild[childrenInfo.parentIdFieldName] = parent[parentInfo.idFieldName]
                    childrenRecords.append(updatedChild)
                }
            }
        }

        // Saving parents
        target.saveInLocalStore(syncManager, soupName: parentInfo.soupName, records: parentRecords, idFieldName: parentInfo.idFieldName, syncId: syncId, lastError: nil, cleanFirst: true)

        // Saving children
        target.saveInLocalStore(syncManager, soupName: childrenInfo.soupName, records: childrenRecords, idFieldName: childrenInfo.idFieldName, syncId: syncId, lastError: nil, cleanFirst: true)
    }

    @objc(getMutableChildrenFromLocalStore:parentInfo:childrenInfo:parent:)
    public static func getMutableChildrenFromLocalStore(_ store: SmartStore, parentInfo: SFParentInfo, childrenInfo: SFChildrenInfo, parent: [String: Any]) -> [[String: Any]] {
        guard let parentId = parent[parentInfo.idFieldName] else { return [] }

        let querySpec = getQueryForChildren(parentInfo, childrenInfo: childrenInfo, childFieldToSelect: "_soup", parentIds: [parentId])

        do {
            let rows = try store.query(using: querySpec, startingFromPageIndex: 0)
            var children: [[String: Any]] = []
            for row in rows {
                if let rowArray = row as? [Any], let dict = rowArray.first as? [String: Any] {
                    children.append(dict)
                }
            }
            return children
        } catch {
            return []
        }
    }

    @objc(deleteChildrenFromLocalStore:parentInfo:childrenInfo:parentIds:)
    public static func deleteChildrenFromLocalStore(_ store: SmartStore, parentInfo: SFParentInfo, childrenInfo: SFChildrenInfo, parentIds: [Any]) {
        let querySpec = getQueryForChildren(parentInfo, childrenInfo: childrenInfo, childFieldToSelect: SOUP_ENTRY_ID, parentIds: parentIds)
        try? store.removeEntries(usingQuerySpec: querySpec, forSoupNamed: childrenInfo.soupName)
    }

    private static func getQueryForChildren(_ parentInfo: SFParentInfo, childrenInfo: SFChildrenInfo, childFieldToSelect: String, parentIds: [Any]) -> QuerySpec {
        let parentIdsString = parentIds.map { "'\($0)'" }.joined(separator: ", ")

        let smartSql = """
        SELECT {\(childrenInfo.soupName):\(childFieldToSelect)} FROM {\(childrenInfo.soupName)},{\(parentInfo.soupName)} WHERE {\(childrenInfo.soupName):\(childrenInfo.parentIdFieldName)} = {\(parentInfo.soupName):\(parentInfo.idFieldName)} AND {\(parentInfo.soupName):\(parentInfo.idFieldName)} IN (\(parentIdsString))
        """

        return QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: UInt(INT_MAX))!
    }
}

// Swift-friendly typealias
public typealias ParentChildrenRelationshipType = RelationshipType
