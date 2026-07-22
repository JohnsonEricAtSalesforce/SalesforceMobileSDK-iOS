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
import SalesforceSDKCore
import SmartStore

// Possible values for relationship type
@objc(SFParentChildrenRelationshipType)
public enum SFParentChildrenRelationshipType: Int {
    case masterDetail = 0
    case lookup
}

public let kSFParentChildrenSyncTargetParent: String = "parent"
public let kSFParentChildrenSyncTargetChildren: String = "children"
public let kSFParentChildrenSyncTargetRelationshipType: String = "relationshipType"
public let kSFParentChildrenSyncTargetParentFieldlist: String = "parentFieldlist"
public let kSFParentChildrenSyncTargetParentSoqlFilter: String = "parentSoqlFilter"
public let kSFParentChildrenSyncTargetChildrenFieldlist: String = "childrenFieldlist"
public let kSFParentChildrenSyncTargetChildrenCreateFieldlist: String = "childrenCreateFieldlist"
public let kSFParentChildrenSyncTargetChildrenUpdateFieldlist: String = "childrenUpdateFieldlist"
public let kSFParentChildrenRelationshipMasterDetail: String = "MASTER_DETAIL"
public let kSFParentChildrenRelationshipLookup: String = "LOOKUP"

private let kSFAppFeatureRelatedRecords = "RR"

@objc(SFParentChildrenSyncHelper)
@objcMembers
public class SFParentChildrenSyncHelper: NSObject {

    // MARK: - App feature registration

    @objc public class func registerAppFeature() {
        SFSDKAppFeatureMarkers.registerAppFeature(kSFAppFeatureRelatedRecords)
    }

    // MARK: - String to/from enum

    @objc public class func relationshipType(fromString relationshipType: String) -> SFParentChildrenRelationshipType {
        if relationshipType == kSFParentChildrenRelationshipMasterDetail {
            return .masterDetail
        }
        return .lookup
    }

    @objc public class func relationshipTypeToString(_ relationshipType: SFParentChildrenRelationshipType) -> String {
        switch relationshipType {
        case .masterDetail: return kSFParentChildrenRelationshipMasterDetail
        case .lookup: return kSFParentChildrenRelationshipLookup
        @unknown default: return kSFParentChildrenRelationshipLookup
        }
    }

    // MARK: - SQL helpers

    @objc public class func getDirtyRecordIdsSql(_ parentInfo: SFParentInfo, childrenInfo: SFChildrenInfo, parentFieldToSelect: String) -> String {
        return "SELECT DISTINCT {\(parentInfo.soupName):\(parentFieldToSelect)} FROM {\(parentInfo.soupName)} WHERE {\(parentInfo.soupName):\(kSyncTargetLocal)} = 1 OR EXISTS (SELECT {\(childrenInfo.soupName):\(childrenInfo.idFieldName)} FROM {\(childrenInfo.soupName)} WHERE {\(childrenInfo.soupName):\(childrenInfo.parentIdFieldName)} = {\(parentInfo.soupName):\(parentInfo.idFieldName)} AND {\(childrenInfo.soupName):\(kSyncTargetLocal)} = 1)"
    }

    @objc public class func getNonDirtyRecordIdsSql(_ parentInfo: SFParentInfo, childrenInfo: SFChildrenInfo, parentFieldToSelect: String, additionalPredicate: String) -> String {
        return "SELECT DISTINCT {\(parentInfo.soupName):\(parentFieldToSelect)} FROM {\(parentInfo.soupName)} WHERE {\(parentInfo.soupName):\(kSyncTargetLocal)} = 0 \(additionalPredicate) AND NOT EXISTS (SELECT {\(childrenInfo.soupName):\(childrenInfo.idFieldName)} FROM {\(childrenInfo.soupName)} WHERE {\(childrenInfo.soupName):\(childrenInfo.parentIdFieldName)} = {\(parentInfo.soupName):\(parentInfo.idFieldName)} AND {\(childrenInfo.soupName):\(kSyncTargetLocal)} = 1)"
    }

    // MARK: - Store operations

    @objc public class func saveRecordTrees(toLocalStore syncManager: SFMobileSyncSyncManager, target: SFSyncTarget, parentInfo: SFParentInfo, childrenInfo: SFChildrenInfo, recordTrees: [Any], syncId: NSNumber) {
        var parentRecords = [[String: Any]]()
        var childrenRecords = [[String: Any]]()

        for recordTree in recordTrees {
            guard let tree = recordTree as? [String: Any] else { continue }
            var parent = tree
            let children = parent[childrenInfo.sobjectTypePlural] as? [[String: Any]]
            parent.removeValue(forKey: childrenInfo.sobjectTypePlural)
            parentRecords.append(parent)

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

    @objc public class func getMutableChildren(fromLocalStore store: SFSmartStore, parentInfo: SFParentInfo, childrenInfo: SFChildrenInfo, parent: [String: Any]) -> [NSMutableDictionary] {
        // Unwrap the parent id before boxing into [Any] — `parent[key] as Any` boxes a Swift Optional,
        // which interpolates as the literal `Optional("…")` in getQueryForChildren's SmartSQL predicate,
        // matching zero children (oracle passes the raw id via ObjC `parent[key]`). See SFRefreshSyncDownTarget (Fix E).
        guard let parentId = parent[parentInfo.idFieldName] else { return [] }
        guard let querySpec = getQueryForChildren(parentInfo, childrenInfo: childrenInfo, childFieldToSelect: "_soup", parentIds: [parentId]) else { return [] }
        guard let rows = try? store.query(using: querySpec, startingFromPageIndex: 0) else { return [] }
        var children = [NSMutableDictionary]()
        for row in rows {
            if let rowArray = row as? [Any], let dict = rowArray[0] as? NSDictionary {
                children.append(dict.mutableCopy() as? NSMutableDictionary ?? NSMutableDictionary())
            }
        }
        return children
    }

    @objc public class func deleteChildren(fromLocalStore store: SFSmartStore, parentInfo: SFParentInfo, childrenInfo: SFChildrenInfo, parentIds: [Any]) {
        guard let querySpec = getQueryForChildren(parentInfo, childrenInfo: childrenInfo, childFieldToSelect: SmartStoreSoupEntryId, parentIds: parentIds) else { return }
        try? store.removeEntries(usingQuerySpec: querySpec, forSoupNamed: childrenInfo.soupName)
    }

    // MARK: - Private

    private class func getQueryForChildren(_ parentInfo: SFParentInfo, childrenInfo: SFChildrenInfo, childFieldToSelect: String, parentIds: [Any]) -> QuerySpec? {
        // Unwrap any boxed Optional before interpolating — a boxed Optional renders as `Optional("…")` in the
        // predicate and matches nothing. Callers should pass unwrapped ids; this is a defensive backstop.
        let parentIdList = parentIds.map { id -> String in
            "'\(unwrapForSql(id))'"
        }.joined(separator: ", ")
        let smartSql = "SELECT {\(childrenInfo.soupName):\(childFieldToSelect)} FROM {\(childrenInfo.soupName)},{\(parentInfo.soupName)} WHERE {\(childrenInfo.soupName):\(childrenInfo.parentIdFieldName)} = {\(parentInfo.soupName):\(parentInfo.idFieldName)} AND {\(parentInfo.soupName):\(parentInfo.idFieldName)} IN (\(parentIdList))"
        return QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: UInt(INT_MAX))
    }

    /// Renders a value for SQL interpolation, stripping a boxed Optional wrapper if present so that a
    /// value that arrived as `Optional("x")` (e.g. via `dict[key] as Any`) interpolates as `x`, not `Optional("x")`.
    private class func unwrapForSql(_ value: Any) -> String {
        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle == .optional {
            if let first = mirror.children.first {
                return "\(first.value)"
            }
            return ""
        }
        return "\(value)"
    }
}
