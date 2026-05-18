/*
 Copyright (c) 2012-present, salesforce.com, inc. All rights reserved.

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
import SalesforceSDKCommon

// MARK: - Constants

/// Container for QuerySpec string constants, exposed to Objective-C.
@objc(SFQuerySpecConstants)
@objcMembers
public class QuerySpecConstants: NSObject {
    @objc public static let kQuerySpecSortOrderAscending: String = "ascending"
    @objc public static let kQuerySpecSortOrderDescending: String = "descending"

    @objc public static let kQuerySpecTypeExact: String = "exact"
    @objc public static let kQuerySpecTypeRange: String = "range"
    @objc public static let kQuerySpecTypeLike: String = "like"
    @objc public static let kQuerySpecTypeSmart: String = "smart"
    @objc public static let kQuerySpecTypeMatch: String = "match"

    @objc public static let kQuerySpecParamQueryType: String = "queryType"
    @objc public static let kQuerySpecParamSelectPaths: String = "selectPaths"
    @objc public static let kQuerySpecParamIndexPath: String = "indexPath"
    @objc public static let kQuerySpecParamOrderPath: String = "orderPath"
    @objc public static let kQuerySpecParamOrder: String = "order"
    @objc public static let kQuerySpecParamPageSize: String = "pageSize"
    @objc public static let kQuerySpecParamMatchKey: String = "matchKey"
    @objc public static let kQuerySpecParamBeginKey: String = "beginKey"
    @objc public static let kQuerySpecParamEndKey: String = "endKey"
    @objc public static let kQuerySpecParamLikeKey: String = "likeKey"
    @objc public static let kQuerySpecParamSmartSql: String = "smartSql"

    @objc public static let kQuerySpecDefaultPageSize: UInt = 10
}

// Top-level aliases for Swift callers
public let kQuerySpecSortOrderAscending = QuerySpecConstants.kQuerySpecSortOrderAscending
public let kQuerySpecSortOrderDescending = QuerySpecConstants.kQuerySpecSortOrderDescending
public let kQuerySpecTypeExact = QuerySpecConstants.kQuerySpecTypeExact
public let kQuerySpecTypeRange = QuerySpecConstants.kQuerySpecTypeRange
public let kQuerySpecTypeLike = QuerySpecConstants.kQuerySpecTypeLike
public let kQuerySpecTypeSmart = QuerySpecConstants.kQuerySpecTypeSmart
public let kQuerySpecTypeMatch = QuerySpecConstants.kQuerySpecTypeMatch
public let kQuerySpecParamQueryType = QuerySpecConstants.kQuerySpecParamQueryType
public let kQuerySpecParamSelectPaths = QuerySpecConstants.kQuerySpecParamSelectPaths
public let kQuerySpecParamIndexPath = QuerySpecConstants.kQuerySpecParamIndexPath
public let kQuerySpecParamOrderPath = QuerySpecConstants.kQuerySpecParamOrderPath
public let kQuerySpecParamOrder = QuerySpecConstants.kQuerySpecParamOrder
public let kQuerySpecParamPageSize = QuerySpecConstants.kQuerySpecParamPageSize
public let kQuerySpecParamMatchKey = QuerySpecConstants.kQuerySpecParamMatchKey
public let kQuerySpecParamBeginKey = QuerySpecConstants.kQuerySpecParamBeginKey
public let kQuerySpecParamEndKey = QuerySpecConstants.kQuerySpecParamEndKey
public let kQuerySpecParamLikeKey = QuerySpecConstants.kQuerySpecParamLikeKey
public let kQuerySpecParamSmartSql = QuerySpecConstants.kQuerySpecParamSmartSql
public let kQuerySpecDefaultPageSize = QuerySpecConstants.kQuerySpecDefaultPageSize

// MARK: - Enums

@objc(SFSoupQueryType)
public enum SoupQueryType: Int {
    @objc(kSFSoupQueryTypeExact) case exact = 2
    @objc(kSFSoupQueryTypeRange) case range = 4
    @objc(kSFSoupQueryTypeLike) case like = 8
    @objc(kSFSoupQueryTypeSmart) case smart = 16
    @objc(kSFSoupQueryTypeMatch) case match = 32
}

@objc(SFSoupQuerySortOrder)
public enum SoupQuerySortOrder: UInt {
    @objc(kSFSoupQuerySortOrderAscending) case ascending = 0
    @objc(kSFSoupQuerySortOrderDescending) case descending = 1
}

// MARK: - QuerySpec

/// Object containing the query specification for queries against a soup.
@objc(SFQuerySpec)
@objcMembers
public class QuerySpec: NSObject {

    /// The type of query to run (exact, range, like, smart, match).
    public var queryType: SoupQueryType = .smart

    /// smartSql passed in for smart queries, computed for all others.
    public var smartSql: String = ""

    /// countSmartSql: query to compute count of results for smartSql.
    public var countSmartSql: String = ""

    /// idsSmartSql: query returning only ids.
    public var idsSmartSql: String = ""

    /// The number of entries per page to return.
    public var pageSize: UInt = 10

    /// soupName is used for range, exact, and like queries.
    public var soupName: String = ""

    /// The paths to return in an array. nil means return the entire soup element.
    public var selectPaths: [String]?

    /// The indexPath to use for the query.
    public var path: String = ""

    /// beginKey is used for range queries.
    public var beginKey: String = ""

    /// endKey is used for range queries.
    public var endKey: String = ""

    /// likeKey is used for like queries.
    public var likeKey: String = ""

    /// matchKey is used for exact and match queries.
    public var matchKey: String = ""

    /// The indexPath to use for sorting.
    public var orderPath: String = ""

    /// A sort order for the query (ascending, descending).
    public var order: SoupQuerySortOrder = .ascending

    /// ASC or DESC
    public var sqlSortOrder: String {
        return order == .descending ? "DESC" : "ASC"
    }

    // MARK: - Factory Methods

    /// Builds an exact query spec.
    @objc(newExactQuerySpec:withSelectPaths:withPath:withMatchKey:withOrderPath:withOrder:withPageSize:)
    public class func buildExactQuerySpec(soupName: String, selectPaths: [String]?, path: String, matchKey: String, orderPath: String, order: SoupQuerySortOrder, pageSize: UInt) -> QuerySpec? {
        let spec = QuerySpec()
        spec.queryType = .exact
        spec.soupName = soupName
        spec.path = path
        spec.selectPaths = selectPaths
        spec.matchKey = matchKey
        spec.orderPath = orderPath
        spec.order = order
        spec.pageSize = pageSize
        spec.computeSmartAndCountAndIdsSql()
        return spec
    }

    @objc(newExactQuerySpec:withPath:withMatchKey:withOrderPath:withOrder:withPageSize:)
    public class func buildExactQuerySpec(soupName: String, path: String, matchKey: String, orderPath: String, order: SoupQuerySortOrder, pageSize: UInt) -> QuerySpec {
        return buildExactQuerySpec(soupName: soupName, selectPaths: nil, path: path, matchKey: matchKey, orderPath: orderPath, order: order, pageSize: pageSize) ?? QuerySpec()
    }

    /// Builds a like query spec.
    @objc(newLikeQuerySpec:withSelectPaths:withPath:withLikeKey:withOrderPath:withOrder:withPageSize:)
    public class func buildLikeQuerySpec(soupName: String, selectPaths: [String]?, path: String, likeKey: String, orderPath: String, order: SoupQuerySortOrder, pageSize: UInt) -> QuerySpec? {
        let spec = QuerySpec()
        spec.queryType = .like
        spec.soupName = soupName
        spec.path = path
        spec.selectPaths = selectPaths
        spec.likeKey = likeKey
        spec.orderPath = orderPath
        spec.order = order
        spec.pageSize = pageSize
        spec.computeSmartAndCountAndIdsSql()
        return spec
    }

    @objc(newLikeQuerySpec:withPath:withLikeKey:withOrderPath:withOrder:withPageSize:)
    public class func buildLikeQuerySpec(soupName: String, path: String, likeKey: String, orderPath: String, order: SoupQuerySortOrder, pageSize: UInt) -> QuerySpec {
        return buildLikeQuerySpec(soupName: soupName, selectPaths: nil, path: path, likeKey: likeKey, orderPath: orderPath, order: order, pageSize: pageSize) ?? QuerySpec()
    }

    /// Builds a range query spec.
    @objc(newRangeQuerySpec:withSelectPaths:withPath:withBeginKey:withEndKey:withOrderPath:withOrder:withPageSize:)
    public class func buildRangeQuerySpec(soupName: String, selectPaths: [String]?, path: String?, beginKey: String?, endKey: String?, orderPath: String, order: SoupQuerySortOrder, pageSize: UInt) -> QuerySpec? {
        let spec = QuerySpec()
        spec.queryType = .range
        spec.soupName = soupName
        spec.path = path ?? ""
        spec.selectPaths = selectPaths
        spec.beginKey = beginKey ?? ""
        spec.endKey = endKey ?? ""
        spec.orderPath = orderPath
        spec.order = order
        spec.pageSize = pageSize
        spec.computeSmartAndCountAndIdsSql()
        return spec
    }

    @objc(newRangeQuerySpec:withPath:withBeginKey:withEndKey:withOrderPath:withOrder:withPageSize:)
    public class func buildRangeQuerySpec(soupName: String, path: String, beginKey: String, endKey: String, orderPath: String, order: SoupQuerySortOrder, pageSize: UInt) -> QuerySpec {
        return buildRangeQuerySpec(soupName: soupName, selectPaths: nil, path: path, beginKey: beginKey, endKey: endKey, orderPath: orderPath, order: order, pageSize: pageSize) ?? QuerySpec()
    }

    /// Builds an all query spec.
    @objc(newAllQuerySpec:withSelectPaths:withOrderPath:withOrder:withPageSize:)
    public class func buildAllQuerySpec(soupName: String, selectPaths: [String]?, orderPath: String, order: SoupQuerySortOrder, pageSize: UInt) -> QuerySpec {
        return buildRangeQuerySpec(soupName: soupName, selectPaths: selectPaths, path: nil, beginKey: nil, endKey: nil, orderPath: orderPath, order: order, pageSize: pageSize) ?? QuerySpec()
    }

    @objc(newAllQuerySpec:withOrderPath:withOrder:withPageSize:)
    public class func buildAllQuerySpec(soupName: String, orderPath: String, order: SoupQuerySortOrder, pageSize: UInt) -> QuerySpec {
        return buildAllQuerySpec(soupName: soupName, selectPaths: nil, orderPath: orderPath, order: order, pageSize: pageSize)
    }

    /// Builds a match query spec (full-text search).
    @objc(newMatchQuerySpec:withSelectPaths:withPath:withMatchKey:withOrderPath:withOrder:withPageSize:)
    public class func buildMatchQuerySpec(soupName: String, selectPaths: [String]?, path: String, matchKey: String, orderPath: String, order: SoupQuerySortOrder, pageSize: UInt) -> QuerySpec? {
        let spec = QuerySpec()
        spec.queryType = .match
        spec.soupName = soupName
        spec.path = path
        spec.selectPaths = selectPaths
        spec.matchKey = matchKey
        spec.orderPath = orderPath
        spec.order = order
        spec.pageSize = pageSize
        spec.computeSmartAndCountAndIdsSql()
        return spec
    }

    @objc(newMatchQuerySpec:withPath:withMatchKey:withOrderPath:withOrder:withPageSize:)
    public class func buildMatchQuerySpec(soupName: String, path: String, matchKey: String, orderPath: String, order: SoupQuerySortOrder, pageSize: UInt) -> QuerySpec {
        return buildMatchQuerySpec(soupName: soupName, selectPaths: nil, path: path, matchKey: matchKey, orderPath: orderPath, order: order, pageSize: pageSize) ?? QuerySpec()
    }

    /// Builds a smart query spec.
    @objc(newSmartQuerySpec:withPageSize:)
    public class func buildSmartQuerySpec(smartSql: String, pageSize: UInt) -> QuerySpec? {
        let spec = QuerySpec()
        spec.queryType = .smart
        spec.smartSql = smartSql
        spec.pageSize = pageSize
        spec.countSmartSql = spec.computeCountSql(smartSql)
        spec.idsSmartSql = spec.computeIdsSql(smartSql)
        return spec
    }

    // MARK: - Dictionary Init

    /// Initializes the object with the given query spec dictionary.
    @objc(initWithDictionary:withSoupName:)
    public convenience init?(querySpec dict: [String: Any], targetSoupName: String) {
        self.init()

        let rawQueryType = dict[kQuerySpecParamQueryType] as? String ?? ""
        let path = dict[kQuerySpecParamIndexPath] as? String ?? ""
        let selectPaths = dict[kQuerySpecParamSelectPaths] as? [String]
        let beginKey = dict[kQuerySpecParamBeginKey] as? String
        let endKey = dict[kQuerySpecParamEndKey] as? String
        let matchKey = dict[kQuerySpecParamMatchKey] as? String ?? ""
        let likeKey = dict[kQuerySpecParamLikeKey] as? String ?? ""
        let smartSql = dict[kQuerySpecParamSmartSql] as? String ?? ""
        let orderPath = dict[kQuerySpecParamOrderPath] as? String ?? ""
        let rawOrder = dict[kQuerySpecParamOrder] as? String ?? ""
        let rawPageSize = dict[kQuerySpecParamPageSize] as? NSNumber

        let order = QuerySpec.sortOrder(from: rawOrder)
        let pageSize: UInt = rawPageSize != nil && rawPageSize?.uintValue ?? 0 > 0 ? rawPageSize?.uintValue ?? kQuerySpecDefaultPageSize : kQuerySpecDefaultPageSize
        let queryType = QuerySpec.queryType(from: rawQueryType)

        // queryTypeFromString returns .smart for anything that isn't exact/like/range/match
        if queryType == .smart && rawQueryType != kQuerySpecTypeSmart {
            SmartStoreLogger.v(QuerySpec.self, message: "Invalid queryType: '\(rawQueryType)'")
            return nil
        }

        switch queryType {
        case .exact:
            guard let spec = QuerySpec.buildExactQuerySpec(soupName: targetSoupName, selectPaths: selectPaths, path: path, matchKey: matchKey, orderPath: orderPath, order: order, pageSize: pageSize) else { return nil }
            copyFrom(spec)
        case .range:
            guard let spec = QuerySpec.buildRangeQuerySpec(soupName: targetSoupName, selectPaths: selectPaths, path: path.isEmpty ? nil : path, beginKey: beginKey, endKey: endKey, orderPath: orderPath, order: order, pageSize: pageSize) else { return nil }
            copyFrom(spec)
        case .like:
            guard let spec = QuerySpec.buildLikeQuerySpec(soupName: targetSoupName, selectPaths: selectPaths, path: path, likeKey: likeKey, orderPath: orderPath, order: order, pageSize: pageSize) else { return nil }
            copyFrom(spec)
        case .smart:
            guard let spec = QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: pageSize) else { return nil }
            copyFrom(spec)
        case .match:
            guard let spec = QuerySpec.buildMatchQuerySpec(soupName: targetSoupName, selectPaths: selectPaths, path: path, matchKey: matchKey, orderPath: orderPath, order: order, pageSize: pageSize) else { return nil }
            copyFrom(spec)
        @unknown default:
            return nil
        }
    }

    private func copyFrom(_ other: QuerySpec) {
        self.queryType = other.queryType
        self.smartSql = other.smartSql
        self.countSmartSql = other.countSmartSql
        self.idsSmartSql = other.idsSmartSql
        self.pageSize = other.pageSize
        self.soupName = other.soupName
        self.selectPaths = other.selectPaths
        self.path = other.path
        self.beginKey = other.beginKey
        self.endKey = other.endKey
        self.likeKey = other.likeKey
        self.matchKey = other.matchKey
        self.orderPath = other.orderPath
        self.order = other.order
    }

    // MARK: - Binds

    /// Return bind arguments for query.
    @objc
    public func bindsForQuerySpec() -> [Any]? {
        switch queryType {
        case .range:
            if !beginKey.isEmpty && !endKey.isEmpty {
                return [beginKey, endKey]
            } else if !beginKey.isEmpty {
                return [beginKey]
            } else if !endKey.isEmpty {
                return [endKey]
            }
            return nil
        case .like:
            return !likeKey.isEmpty ? [likeKey] : nil
        case .exact:
            return !matchKey.isEmpty ? [matchKey] : nil
        case .match, .smart:
            return nil
        @unknown default:
            return nil
        }
    }

    // MARK: - Smart SQL Computation

    private func computeSmartAndCountAndIdsSql() {
        let selectClause = computeSelectClause()
        let fromClause = computeFromClause()
        let whereClause = computeWhereClause()
        let orderClause = computeOrderClause()

        smartSql = selectClause + fromClause + whereClause + orderClause
        countSmartSql = "SELECT count(*) " + fromClause + whereClause
        idsSmartSql = "SELECT \(SmartStoreIdColumn) " + fromClause + whereClause + orderClause
    }

    private func computeCountSql(_ sql: String) -> String {
        return "SELECT count(*) FROM (\(sql))"
    }

    private func computeIdsSql(_ sql: String) -> String {
        return "SELECT \(SmartStoreIdColumn) FROM (\(sql))"
    }

    private func computeSelectClause() -> String {
        let paths = selectPaths ?? ["_soup"]
        let fieldReferences = paths.map { computeFieldReference($0) }
        return "SELECT \(fieldReferences.joined(separator: ", ")) "
    }

    private func computeFromClause() -> String {
        return "FROM \(computeSoupReference()) "
    }

    private func computeWhereClause() -> String {
        if path.isEmpty && queryType != .match {
            return ""
        }

        var field = ""
        if !path.isEmpty {
            field = computeFieldReference(path)
        }

        switch queryType {
        case .exact:
            return "WHERE \(field) = ? "
        case .like:
            return "WHERE \(field) LIKE ? "
        case .range:
            if beginKey.isEmpty && endKey.isEmpty { return "" }
            else if endKey.isEmpty { return "WHERE \(field) >= ? " }
            else if beginKey.isEmpty { return "WHERE \(field) <= ? " }
            else { return "WHERE \(field) >= ? AND \(field) <= ? " }
        case .match:
            let entryIdRef = computeFieldReference(SmartStoreSoupEntryId)
            let ftsRef = computeSoupFtsReference()
            let qualifiedMatch = QuerySpec.qualifyMatchKey(matchKey, field: field.isEmpty ? nil : field)
            return "WHERE \(entryIdRef) IN (SELECT \(ROWID_COL) FROM \(ftsRef) WHERE \(ftsRef) MATCH '\(qualifiedMatch)') "
        default:
            return ""
        }
    }

    /// FTS5 qualification of match key.
    @objc
    public class func qualifyMatchKey(_ matchKey: String, field: String?) -> String {
        guard let field = field, !field.isEmpty else { return matchKey }

        var qualifiedMatchKey = ""
        guard let regex = try? NSRegularExpression(pattern: "[^\\(\\) ]+", options: .caseInsensitive) else {
            return matchKey
        }

        let matches = regex.matches(in: matchKey, options: [], range: NSRange(location: 0, length: matchKey.count))
        var locationAlreadyCopied = 0

        for match in matches {
            let matchRange = match.range
            let nsMatchKey = matchKey as NSString
            let part = nsMatchKey.substring(with: matchRange)
            let lowerCasePart = part.lowercased()

            let beforeRange = NSRange(location: locationAlreadyCopied, length: matchRange.location - locationAlreadyCopied)
            qualifiedMatchKey += nsMatchKey.substring(with: beforeRange)
            locationAlreadyCopied = matchRange.location + matchRange.length

            if lowerCasePart == "and" || lowerCasePart == "or" || lowerCasePart == "not" || lowerCasePart.hasPrefix("{") {
                qualifiedMatchKey += part
            } else {
                qualifiedMatchKey += "\(field):\(part)"
            }
        }

        // tail
        let tailRange = NSRange(location: locationAlreadyCopied, length: matchKey.count - locationAlreadyCopied)
        qualifiedMatchKey += (matchKey as NSString).substring(with: tailRange)

        return qualifiedMatchKey
    }

    private func computeOrderClause() -> String {
        if orderPath.isEmpty { return "" }
        return "ORDER BY \(computeFieldReference(orderPath)) \(sqlSortOrder) "
    }

    private func computeFieldReference(_ field: String) -> String {
        return "{\(soupName):\(field)}"
    }

    private func computeSoupReference() -> String {
        return "{\(soupName)}"
    }

    private func computeSoupFtsReference() -> String {
        return "{\(soupName)}_fts"
    }

    // MARK: - Dictionary Representation

    /// The NSDictionary representation of the query spec.
    @objc
    public func asDictionary() -> [String: Any] {
        var result: [String: Any] = [kQuerySpecParamPageSize: NSNumber(value: pageSize)]

        if !path.isEmpty { result[kQuerySpecParamIndexPath] = path }
        if !orderPath.isEmpty { result[kQuerySpecParamOrderPath] = orderPath }

        result[kQuerySpecParamOrder] = QuerySpec.sortOrder(from: order)
        result[kQuerySpecParamQueryType] = QuerySpec.queryType(from: queryType)

        switch queryType {
        case .range:
            if !beginKey.isEmpty { result[kQuerySpecParamBeginKey] = beginKey }
            if !endKey.isEmpty { result[kQuerySpecParamEndKey] = endKey }
        case .like:
            result[kQuerySpecParamLikeKey] = likeKey
        case .exact:
            result[kQuerySpecParamMatchKey] = matchKey
        case .smart:
            result[kQuerySpecParamSmartSql] = smartSql
        case .match:
            result[kQuerySpecParamMatchKey] = matchKey
        @unknown default:
            break
        }

        return result
    }

    public override var description: String {
        return SFJsonUtils.jsonRepresentation(asDictionary()) ?? ""
    }

    // MARK: - Enum Conversion

    /// Convert query type string to enum.
    @objc(queryTypeFromString:)
    public class func queryType(from string: String) -> SoupQueryType {
        switch string {
        case kQuerySpecTypeExact: return .exact
        case kQuerySpecTypeRange: return .range
        case kQuerySpecTypeLike: return .like
        case kQuerySpecTypeMatch: return .match
        default: return .smart
        }
    }

    /// Convert query type enum to string.
    @objc(queryTypeFromEnum:)
    public class func queryType(from queryType: SoupQueryType) -> String {
        switch queryType {
        case .exact: return kQuerySpecTypeExact
        case .range: return kQuerySpecTypeRange
        case .like: return kQuerySpecTypeLike
        case .smart: return kQuerySpecTypeSmart
        case .match: return kQuerySpecTypeMatch
        @unknown default: return kQuerySpecTypeSmart
        }
    }

    /// Convert sort order string to enum.
    @objc(sortOrderFromString:)
    public class func sortOrder(from string: String) -> SoupQuerySortOrder {
        if string == kQuerySpecSortOrderDescending { return .descending }
        return .ascending
    }

    /// Convert sort order enum to string.
    @objc(sortOrderFromEnum:)
    public class func sortOrder(from order: SoupQuerySortOrder) -> String {
        switch order {
        case .descending: return kQuerySpecSortOrderDescending
        case .ascending: return kQuerySpecSortOrderAscending
        @unknown default: return kQuerySpecSortOrderAscending
        }
    }
}
