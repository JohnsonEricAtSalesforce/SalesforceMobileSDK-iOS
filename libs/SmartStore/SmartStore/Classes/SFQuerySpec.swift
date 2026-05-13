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
import SalesforceSDKCore

//kQuerySpecSortOrderFoo constants are used when translating to SFSoupQuerySortOrder from JS (dictionary) values
public let kQuerySpecSortOrderAscending = "ascending"
public let kQuerySpecSortOrderDescending = "descending"

//kQuerySpecTypeFoo constants are used when translating to SFSoupQueryType from JS (dictionary) values
public let kQuerySpecTypeExact = "exact"
public let kQuerySpecTypeRange = "range"
public let kQuerySpecTypeLike = "like"
public let kQuerySpecTypeSmart = "smart"
public let kQuerySpecTypeMatch = "match"

//kQuerySpecParamFoo constants are used when build SFQuerySpec from JS (dictionary) values
public let kQuerySpecParamQueryType = "queryType"
public let kQuerySpecParamSelectPaths = "selectPaths"
public let kQuerySpecParamIndexPath = "indexPath"
public let kQuerySpecParamOrder = "order"
public let kQuerySpecParamPageSize = "pageSize"
public let kQuerySpecParamOrderPath = "orderPath"
public let kQuerySpecParamMatchKey = "matchKey"
public let kQuerySpecParamBeginKey = "beginKey"
public let kQuerySpecParamEndKey = "endKey"
public let kQuerySpecParamLikeKey = "likeKey"
public let kQuerySpecParamSmartSql = "smartSql"
public let kQuerySpecDefaultPageSize: UInt = 10

/**
 * Object containing the query specification for queries against a soup.
 */
@objc(SFQuerySpec)
@objcMembers
public class QuerySpec: NSObject {

    @objc(SFSoupQueryType)
    public enum QueryType: Int {
        case exact = 2
        case range = 4
        case like = 8
        case smart = 16
        case match = 32
    }

    @objc(SFSoupQuerySortOrder)
    public enum SortOrder: UInt {
        case ascending
        case descending
    }

    /**
     * The type of query to run (exact, range, like).
     */
    @objc
    public var queryType: QueryType

    /**
     smartSql passed in for smart queries, computed for all others.
     */
    @objc
    public var smartSql: String

    /**
     countSmartSql: query to compute count of results for smartSql
     */
    @objc
    public var countSmartSql: String

    /**
     idsSmartSql: query returning only ids
     */
    @objc
    public var idsSmartSql: String

    /**
     * The number of entries per page to return.
     */
    @objc
    public var pageSize: UInt

    /**
     soupName is used for range, exact, and like queries.
     */
    @objc
    public var soupName: String

    /**
     The paths to return in an array. nil means return the entire soup element.
     */
    @objc
    public var selectPaths: [String]?

    /**
     The indexPath to use for the query. Compound paths must be dot-delimited ie parent.child.grandchild.field .
     */
    @objc
    public var path: String?

    /**
     beginKey is used for range queries.
     */
    @objc
    public var beginKey: String?

    /**
     endKey is used for range queries.
     */
    @objc
    public var endKey: String?

    /**
     likeKey is used for like queries.
     */
    @objc
    public var likeKey: String?

    /**
     matchKey is used for exact and match queries.
     */
    @objc
    public var matchKey: String?

    /**
     The indexPath to use for sorting. Compound paths must be dot-delimited ie parent.child.grandchild.field .
     */
    @objc
    public var orderPath: String?

    /**
     * A sort order for the query (ascending, descending).
     */
    @objc
    public var order: SortOrder

    /**
     ASC or DESC
     */
    @objc
    public var sqlSortOrder: String {
        return order == .descending ? "DESC" : "ASC"
    }

    // MARK: - Factory methods

    /**
     * Factory method to build an exact query spec
     * Note: caller is responsible for releaseing the query spec
     * @param soupName The target soup name.
     * @param selectPaths The paths to return - if nil the entire soup element is returned.
     * @param path The path to filter on.
     * @param matchKey The exact value to match.
     * @param orderPath The path to sort by.
     * @param order The sort order.
     * @param pageSize The page size.
     * @return A query spec object.
     */
    @objc(newExactQuerySpec:withSelectPaths:withPath:withMatchKey:withOrderPath:withOrder:withPageSize:)
    public class func buildExactQuerySpec(soupName: String, selectPaths: [String]?, path: String, matchKey: String, orderPath: String, order: SortOrder, pageSize: UInt) -> QuerySpec? {
        let querySpec = QuerySpec()
        querySpec.queryType = .exact
        querySpec.path = path
        querySpec.selectPaths = selectPaths
        querySpec.soupName = soupName
        querySpec.matchKey = matchKey
        querySpec.orderPath = orderPath
        querySpec.order = order
        querySpec.pageSize = pageSize
        querySpec.computeSmartAndCountAndIdsSql()
        return querySpec
    }

    @objc(newExactQuerySpec:withPath:withMatchKey:withOrderPath:withOrder:withPageSize:)
    public class func buildExactQuerySpec(soupName: String, path: String, matchKey: String, orderPath: String, order: SortOrder, pageSize: UInt) -> QuerySpec {
        return buildExactQuerySpec(soupName: soupName, selectPaths: nil, path: path, matchKey: matchKey, orderPath: orderPath, order: order, pageSize: pageSize)!
    }

    /**
     * Factory method to build an like query spec
     * Note: caller is responsible for releaseing the query spec
     * @param soupName The target soup name.
     * @param selectPaths The paths to return - if nil the entire soup element is returned.
     * @param path The path to filter on.
     * @param likeKey The value to match on.
     * @param orderPath The path to sort by.
     * @param order The sort order.
     * @param pageSize The page size.
     * @return A query spec object.
     */
    @objc(newLikeQuerySpec:withSelectPaths:withPath:withLikeKey:withOrderPath:withOrder:withPageSize:)
    public class func buildLikeQuerySpec(soupName: String, selectPaths: [String]?, path: String, likeKey: String, orderPath: String, order: SortOrder, pageSize: UInt) -> QuerySpec? {
        let querySpec = QuerySpec()
        querySpec.queryType = .like
        querySpec.soupName = soupName
        querySpec.path = path
        querySpec.selectPaths = selectPaths
        querySpec.likeKey = likeKey
        querySpec.orderPath = orderPath
        querySpec.order = order
        querySpec.pageSize = pageSize
        querySpec.computeSmartAndCountAndIdsSql()
        return querySpec
    }

    @objc(newLikeQuerySpec:withPath:withLikeKey:withOrderPath:withOrder:withPageSize:)
    public class func buildLikeQuerySpec(soupName: String, path: String, likeKey: String, orderPath: String, order: SortOrder, pageSize: UInt) -> QuerySpec {
        return buildLikeQuerySpec(soupName: soupName, selectPaths: nil, path: path, likeKey: likeKey, orderPath: orderPath, order: order, pageSize: pageSize)!
    }

    /**
     * Factory method to build an range query spec
     * Note: caller is responsible for releaseing the query spec
     * @param soupName The target soup name.
     * @param selectPaths The paths to return - if nil the entire soup element is returned.
     * @param path The path to filter on.
     * @param beginKey The start of the range.
     * @param endKey The end of the range.
     * @param orderPath The path to sort by.
     * @param order The sort order.
     * @param pageSize The page size.
     * @return A query spec object.
     */
    @objc(newRangeQuerySpec:withSelectPaths:withPath:withBeginKey:withEndKey:withOrderPath:withOrder:withPageSize:)
    public class func buildRangeQuerySpec(soupName: String, selectPaths: [String]?, path: String?, beginKey: String?, endKey: String?, orderPath: String, order: SortOrder, pageSize: UInt) -> QuerySpec? {
        let querySpec = QuerySpec()
        querySpec.queryType = .range
        querySpec.soupName = soupName
        querySpec.path = path
        querySpec.selectPaths = selectPaths
        querySpec.beginKey = beginKey
        querySpec.endKey = endKey
        querySpec.orderPath = orderPath
        querySpec.order = order
        querySpec.pageSize = pageSize
        querySpec.computeSmartAndCountAndIdsSql()
        return querySpec
    }

    @objc(newRangeQuerySpec:withPath:withBeginKey:withEndKey:withOrderPath:withOrder:withPageSize:)
    public class func buildRangeQuerySpec(soupName: String, path: String, beginKey: String, endKey: String, orderPath: String, order: SortOrder, pageSize: UInt) -> QuerySpec {
        return buildRangeQuerySpec(soupName: soupName, selectPaths: nil, path: path, beginKey: beginKey, endKey: endKey, orderPath: orderPath, order: order, pageSize: pageSize)!
    }

    /**
     * Factory method to build a query spec to return all data from a soup.
     * @param soupName The target soup name.
     * @param selectPaths The paths to return - if nil the entire soup element is returned.
     * @param orderPath The path to sort by.
     * @param order The sort order.
     * @param pageSize The page size.
     */
    @objc(newAllQuerySpec:withSelectPaths:withOrderPath:withOrder:withPageSize:)
    public class func buildAllQuerySpec(soupName: String, selectPaths: [String]?, orderPath: String, order: SortOrder, pageSize: UInt) -> QuerySpec {
        return buildRangeQuerySpec(soupName: soupName, selectPaths: selectPaths, path: nil, beginKey: nil, endKey: nil, orderPath: orderPath, order: order, pageSize: pageSize)!
    }

    @objc(newAllQuerySpec:withOrderPath:withOrder:withPageSize:)
    public class func buildAllQuerySpec(soupName: String, orderPath: String, order: SortOrder, pageSize: UInt) -> QuerySpec {
        return buildAllQuerySpec(soupName: soupName, selectPaths: nil, orderPath: orderPath, order: order, pageSize: pageSize)
    }

    /**
     * Factory method to build a match query spec (full-text search)
     * Note: caller is responsible for releaseing the query spec
     * @param soupName The target soup name.
     * @param selectPaths The paths to return - if nil the entire soup element is returned.
     * @param path The path to filter on - can be nil to match against any full-text indexed paths.
     * @param matchKey The match query string.
     * @param orderPath The path to sort by.
     * @param order The sort order.
     * @param pageSize The page size.
     * @return A query spec object.
     */
    @objc(newMatchQuerySpec:withSelectPaths:withPath:withMatchKey:withOrderPath:withOrder:withPageSize:)
    public class func buildMatchQuerySpec(soupName: String, selectPaths: [String]?, path: String, matchKey: String, orderPath: String, order: SortOrder, pageSize: UInt) -> QuerySpec? {
        let querySpec = QuerySpec()
        querySpec.queryType = .match
        querySpec.path = path
        querySpec.soupName = soupName
        querySpec.selectPaths = selectPaths
        querySpec.matchKey = matchKey
        querySpec.orderPath = orderPath
        querySpec.order = order
        querySpec.pageSize = pageSize
        querySpec.computeSmartAndCountAndIdsSql()
        return querySpec
    }

    @objc(newMatchQuerySpec:withPath:withMatchKey:withOrderPath:withOrder:withPageSize:)
    public class func buildMatchQuerySpec(soupName: String, path: String, matchKey: String, orderPath: String, order: SortOrder, pageSize: UInt) -> QuerySpec {
        return buildMatchQuerySpec(soupName: soupName, selectPaths: nil, path: path, matchKey: matchKey, orderPath: orderPath, order: order, pageSize: pageSize)!
    }

    /**
     * Factory method to build a smart query spec
     * Note: caller is responsible for releaseing the query spec
     * @param smartSql The smart sql query.
     * @param pageSize The page size.
     * @return A query spec object.
     */
    @objc(newSmartQuerySpec:withPageSize:)
    public class func buildSmartQuerySpec(smartSql: String, pageSize: UInt) -> QuerySpec? {
        let querySpec = QuerySpec()
        querySpec.queryType = .smart
        querySpec.smartSql = smartSql
        querySpec.pageSize = pageSize
        querySpec.countSmartSql = querySpec.computeCountSql(smartSql)
        querySpec.idsSmartSql = querySpec.computeIdsSql(smartSql)
        return querySpec
    }

    // MARK: - Initializers

    private override init() {
        self.queryType = .exact
        self.smartSql = ""
        self.countSmartSql = ""
        self.idsSmartSql = ""
        self.pageSize = kQuerySpecDefaultPageSize
        self.soupName = ""
        self.order = .ascending
        super.init()
    }

    /**
     * Initializes the object with the given query spec.
     * @param querySpec the name/value pairs defining the query spec.
     * @param targetSoupName the soup name targeted (not nil for exact/like/range queries)
     * @return A new instance of the object.
     */
    @objc(initWithDictionary:withSoupName:)
    public init?(querySpec: [String: Any], targetSoupName: String) {
        let rawQueryType = querySpec.sfsdk_nonNullObject(forKey: kQuerySpecParamQueryType) as? String
        let path = querySpec.sfsdk_nonNullObject(forKey: kQuerySpecParamIndexPath) as? String
        let selectPaths = querySpec.sfsdk_nonNullObject(forKey: kQuerySpecParamSelectPaths) as? [String]
        let beginKey = querySpec.sfsdk_nonNullObject(forKey: kQuerySpecParamBeginKey) as? String
        let endKey = querySpec.sfsdk_nonNullObject(forKey: kQuerySpecParamEndKey) as? String
        let matchKey = querySpec.sfsdk_nonNullObject(forKey: kQuerySpecParamMatchKey) as? String
        let likeKey = querySpec.sfsdk_nonNullObject(forKey: kQuerySpecParamLikeKey) as? String
        let smartSql = querySpec.sfsdk_nonNullObject(forKey: kQuerySpecParamSmartSql) as? String
        let orderPath = querySpec.sfsdk_nonNullObject(forKey: kQuerySpecParamOrderPath) as? String
        let rawOrder = querySpec.sfsdk_nonNullObject(forKey: kQuerySpecParamOrder) as? String
        let rawPageSize = querySpec.sfsdk_nonNullObject(forKey: kQuerySpecParamPageSize) as? NSNumber

        let order = QuerySpec.sortOrder(from: rawOrder)
        let pageSize = (rawPageSize?.uintValue ?? 0) > 0 ? rawPageSize!.uintValue : kQuerySpecDefaultPageSize
        let queryType = QuerySpec.queryType(from: rawQueryType)

        self.queryType = .exact
        self.smartSql = ""
        self.countSmartSql = ""
        self.idsSmartSql = ""
        self.pageSize = kQuerySpecDefaultPageSize
        self.soupName = ""
        self.order = .ascending
        super.init()

        // queryTypeFromString returns .smart for anything that isn't exact/like/range/match
        if queryType == .smart && rawQueryType != kQuerySpecTypeSmart {
            SmartStoreLogger.v(type(of: self), message: "Invalid queryType: '\(rawQueryType ?? "")'")
            return nil
        }

        let spec: QuerySpec?
        switch queryType {
        case .exact:
            spec = QuerySpec.buildExactQuerySpec(soupName: targetSoupName, selectPaths: selectPaths, path: path ?? "", matchKey: matchKey ?? "", orderPath: orderPath ?? "", order: order, pageSize: pageSize)
        case .range:
            spec = QuerySpec.buildRangeQuerySpec(soupName: targetSoupName, selectPaths: selectPaths, path: path, beginKey: beginKey, endKey: endKey, orderPath: orderPath ?? "", order: order, pageSize: pageSize)
        case .like:
            spec = QuerySpec.buildLikeQuerySpec(soupName: targetSoupName, selectPaths: selectPaths, path: path ?? "", likeKey: likeKey ?? "", orderPath: orderPath ?? "", order: order, pageSize: pageSize)
        case .smart:
            spec = QuerySpec.buildSmartQuerySpec(smartSql: smartSql ?? "", pageSize: pageSize)
        case .match:
            spec = QuerySpec.buildMatchQuerySpec(soupName: targetSoupName, selectPaths: selectPaths, path: path ?? "", matchKey: matchKey ?? "", orderPath: orderPath ?? "", order: order, pageSize: pageSize)
        }

        guard let spec = spec else {
            return nil
        }

        self.queryType = spec.queryType
        self.smartSql = spec.smartSql
        self.countSmartSql = spec.countSmartSql
        self.idsSmartSql = spec.idsSmartSql
        self.pageSize = spec.pageSize
        self.soupName = spec.soupName
        self.selectPaths = spec.selectPaths
        self.path = spec.path
        self.beginKey = spec.beginKey
        self.endKey = spec.endKey
        self.likeKey = spec.likeKey
        self.matchKey = spec.matchKey
        self.orderPath = spec.orderPath
        self.order = spec.order
    }

    // MARK: - Public methods

    /**
     * Return bind arguments for query.
     * @return bind arguments.
     */
    @objc(bindsForQuerySpec)
    public func binds() -> [String]? {
        var result: [String]?

        switch queryType {
        case .range:
            if let beginKey = beginKey, let endKey = endKey {
                result = [beginKey, endKey]
            } else if let beginKey = beginKey {
                result = [beginKey]
            } else if let endKey = endKey {
                result = [endKey]
            }

        case .like:
            if let likeKey = likeKey {
                result = [likeKey]
            }

        case .exact:
            if let matchKey = matchKey {
                result = [matchKey]
            }

        case .match:
            // baking matchKey into query
            break

        case .smart:
            break
        }

        return result
    }

    /**
     * The NSDictionary representation of the query spec.
     */
    @objc(asDictionary)
    public func asDictionary() -> [String: Any] {
        var result: [String: Any] = [
            kQuerySpecParamPageSize: NSNumber(value: pageSize)
        ]

        if let path = path {
            result[kQuerySpecParamIndexPath] = path
        }

        if let orderPath = orderPath {
            result[kQuerySpecParamOrderPath] = orderPath
        }

        result[kQuerySpecParamOrder] = QuerySpec.sortOrder(from: order)
        result[kQuerySpecParamQueryType] = QuerySpec.queryType(from: queryType)

        switch queryType {
        case .range:
            if let beginKey = beginKey {
                result[kQuerySpecParamBeginKey] = beginKey
            }
            if let endKey = endKey {
                result[kQuerySpecParamEndKey] = endKey
            }

        case .like:
            result[kQuerySpecParamLikeKey] = likeKey

        case .exact:
            result[kQuerySpecParamMatchKey] = matchKey

        case .smart:
            result[kQuerySpecParamSmartSql] = smartSql

        case .match:
            result[kQuerySpecParamMatchKey] = matchKey
        }

        return result
    }

    public override var description: String {
        return SFJsonUtils.jsonRepresentation(asDictionary()) ?? ""
    }

    // MARK: - Smart sql computation

    private func computeSmartAndCountAndIdsSql() {
        let selectClause = computeSelectClause()
        let fromClause = computeFromClause()
        let whereClause = computeWhereClause()
        let orderClause = computeOrderClause()

        let computedSmartSql = selectClause + fromClause + whereClause + orderClause
        self.smartSql = computedSmartSql

        let countSmartSql = "SELECT count(*) " + fromClause + whereClause
        self.countSmartSql = countSmartSql

        let idsSmartSql = "SELECT \(ID_COL) " + fromClause + whereClause + orderClause
        self.idsSmartSql = idsSmartSql
    }

    private func computeCountSql(_ smartSql: String) -> String {
        return "SELECT count(*) FROM (\(smartSql))"
    }

    private func computeIdsSql(_ smartSql: String) -> String {
        return "SELECT \(ID_COL) FROM (\(smartSql))"
        // NB: that query won't successfully run if smartSql doesn't select the id col
    }

    private func computeSelectClause() -> String {
        var fieldReferences: [String] = []
        for selectPath in (selectPaths ?? ["_soup"]) {
            fieldReferences.append(computeFieldReference(selectPath))
        }

        return "SELECT " + fieldReferences.joined(separator: ", ") + " "
    }

    private func computeFromClause() -> String {
        return "FROM " + computeSoupReference() + " "
    }

    private func computeWhereClause() -> String {
        if path == nil && queryType != .match /* null path allowed for fts match query */ {
            return ""
        }

        var field = ""

        if let path = path {
            field = computeFieldReference(path)
        }

        switch queryType {
        case .exact:
            return "WHERE " + field + " = ? "

        case .like:
            return "WHERE " + field + " LIKE ? "

        case .range:
            if beginKey == nil && endKey == nil {
                return ""
            } else if endKey == nil {
                return "WHERE " + field + " >= ? "
            } else if beginKey == nil {
                return "WHERE " + field + " <= ? "
            } else {
                return "WHERE " + field + " >= ? AND " + field + " <= ? "
            }

        case .match:
            return "WHERE " +
                computeFieldReference(SOUP_ENTRY_ID) +
                " IN " +
                "(SELECT " +
                ROWID_COL +
                " FROM " +
                computeSoupFtsReference() +
                " WHERE " +
                computeSoupFtsReference() +
                " MATCH '" +
                QuerySpec.qualifyMatchKey(matchKey ?? "", field: field) + // match clause -- statement arg binding doesn't seem to work so inlining matchKey
                "') "

        default:
            break
        }

        return "" // we should never get here
    }

    /**
     * fts5 doesn't allow WHERE column MATCH 'value' - only allows WHERE table MATCH 'column:value'
     * This method changes the matchKey to add field: in the right places
     */
    @objc(qualifyMatchKey:field:)
    public class func qualifyMatchKey(_ matchKey: String, field: String) -> String {
        if field.isEmpty {
            return matchKey
        } else {
            let qualifiedMatchKey = NSMutableString()
            let regex = try! NSRegularExpression(pattern: "[^\\(\\) ]+", options: .caseInsensitive)

            let matches = regex.matches(in: matchKey, options: [], range: NSRange(location: 0, length: matchKey.count))

            var locationAlreadyCopied = 0
            for match in matches {
                let matchRange = match.range
                let part = (matchKey as NSString).substring(with: matchRange)
                let lowerCasePart = part.lowercased()

                let beforeMatchRange = NSRange(location: locationAlreadyCopied, length: matchRange.location - locationAlreadyCopied)
                qualifiedMatchKey.append((matchKey as NSString).substring(with: beforeMatchRange))
                locationAlreadyCopied = matchRange.location + matchRange.length

                if lowerCasePart == "and" || lowerCasePart == "or" || lowerCasePart == "not" || lowerCasePart.hasPrefix("{") {
                    qualifiedMatchKey.append(part)
                } else {
                    qualifiedMatchKey.append("\(field):\(part)")
                }
            }
            // tail
            let tailRange = NSRange(location: locationAlreadyCopied, length: matchKey.count - locationAlreadyCopied)
            qualifiedMatchKey.append((matchKey as NSString).substring(with: tailRange))

            return qualifiedMatchKey as String
        }
    }

    private func computeOrderClause() -> String {
        guard let orderPath = orderPath else {
            return ""
        }

        return "ORDER BY " + computeFieldReference(orderPath) + " " + sqlSortOrder + " "
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

    // MARK: - Enum to/from string helper methods

    @objc(queryTypeFromString:)
    public class func queryType(from queryType: String?) -> QueryType {
        guard let queryType = queryType else {
            return .smart
        }

        if queryType == kQuerySpecTypeExact {
            return .exact
        } else if queryType == kQuerySpecTypeRange {
            return .range
        } else if queryType == kQuerySpecTypeLike {
            return .like
        } else if queryType == kQuerySpecTypeMatch {
            return .match
        } else {
            return .smart
        }
    }

    @objc(queryTypeFromEnum:)
    public class func queryType(from queryType: QueryType) -> String {
        switch queryType {
        case .exact:
            return kQuerySpecTypeExact
        case .range:
            return kQuerySpecTypeRange
        case .like:
            return kQuerySpecTypeLike
        case .smart:
            return kQuerySpecTypeSmart
        case .match:
            return kQuerySpecTypeMatch
        }
    }

    @objc(sortOrderFromString:)
    public class func sortOrder(from sortOrder: String?) -> SortOrder {
        if sortOrder == kQuerySpecSortOrderDescending {
            return .descending
        } else {
            return .ascending
        }
    }

    @objc(sortOrderFromEnum:)
    public class func sortOrder(from sortOrder: SortOrder) -> String {
        switch sortOrder {
        case .descending:
            return kQuerySpecSortOrderDescending
        case .ascending:
            return kQuerySpecSortOrderAscending
        }
    }
}
