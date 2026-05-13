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

@objc(SFSDKSoqlBuilder)
public class SFSDKSoqlBuilder: NSObject {

    private var properties: [String: Any] = [:]

    // MARK: - Query Builder

    /// A builder to help create a SOQL statement.
    /// - Parameter fields: a list of one or more fields, separated by commas, that are to be retrieved from the specified object
    /// - Returns: the builder
    @objc(withFields:)
    public static func with(fields: String) -> SFSDKSoqlBuilder {
        let builder = SFSDKSoqlBuilder()
        builder.fields(fields)
        builder.limit(0)
        builder.offset(0)
        return builder
    }

    /// A builder to help create a SOQL statement.
    /// - Parameter fields: an array of one or more fields, that are to be retrieved from the specified object
    /// - Returns: the builder
    @objc(withFieldsArray:)
    public static func withFields(array fields: [String]) -> SFSDKSoqlBuilder {
        return SFSDKSoqlBuilder.with(fields: fields.joined(separator: ", "))
    }

    @objc(fields:)
    @discardableResult
    private func fields(_ fields: String) -> SFSDKSoqlBuilder {
        properties["fields"] = fields
        return self
    }

    /// A builder to help create a SOQL statement.
    /// - Parameter from: the object to be queried
    /// - Returns: the builder
    @objc(from:)
    @discardableResult
    public func from(_ from: String) -> SFSDKSoqlBuilder {
        properties["from"] = from
        return self
    }

    /// A builder to help create a SOQL statement.
    /// - Parameter whereClause: a conditional statement
    /// - Returns: the builder
    @objc(whereClause:)
    @discardableResult
    public func whereClause(_ whereClause: String) -> SFSDKSoqlBuilder {
        properties["whereClause"] = whereClause
        return self
    }

    /// A builder to help create a SOQL statement.
    /// - Parameter with: used to filter records based on field values.
    /// - Returns: the builder
    @objc(with:)
    @discardableResult
    public func with(_ with: String) -> SFSDKSoqlBuilder {
        properties["with"] = with
        return self
    }

    /// A builder to help create a SOQL statement.
    /// - Parameter groupBy: a list of one or more fields, separated by commas, the resutls are to be grouped by
    /// - Returns: the builder
    @objc(groupBy:)
    @discardableResult
    public func groupBy(_ groupBy: String) -> SFSDKSoqlBuilder {
        properties["groupBy"] = groupBy
        return self
    }

    /// A builder to help create a SOQL statement.
    /// - Parameter having: specifies one or more conditional expressions using aggregate functions to filter the query results
    /// - Returns: the builder
    @objc(having:)
    @discardableResult
    public func having(_ having: String) -> SFSDKSoqlBuilder {
        properties["having"] = having
        return self
    }

    /// A builder to help create a SOQL statement.
    /// - Parameter orderBy: controls the order of the query results
    /// - Returns: the builder
    @objc(orderBy:)
    @discardableResult
    public func orderBy(_ orderBy: String) -> SFSDKSoqlBuilder {
        properties["orderBy"] = orderBy
        return self
    }

    /// A builder to help create a SOQL statement.
    /// - Parameter limit: specifies the maximum number of rows to return
    /// - Returns: the builder
    @objc(limit:)
    @discardableResult
    public func limit(_ limit: Int) -> SFSDKSoqlBuilder {
        properties["limit"] = limit
        return self
    }

    /// A builder to help create a SOQL statement.
    /// - Parameter offset: specifies the starting row offset into the result set returned by the query
    /// - Returns: the builder
    @objc(offset:)
    @discardableResult
    public func offset(_ offset: Int) -> SFSDKSoqlBuilder {
        properties["offset"] = offset
        return self
    }

    // MARK: - Query String Generation

    /// Builds an encoded query from the builder.
    /// - Returns: the built query
    @objc public func encodeAndBuild() -> String? {
        guard let rawQuery = build() else { return nil }
        return rawQuery.sfsdk_stringByURLEncoding
    }

    /// Builds an enoded query from the builder.
    /// - Parameter path: the path to build the query for
    /// - Returns: the built query
    @objc(encodeAndBuildWithPath:)
    public func encodeAndBuild(withPath path: String) -> String? {
        guard let encodedQuery = encodeAndBuild() else { return nil }
        if path.hasSuffix("/") {
            return "\(path)query/?q=\(encodedQuery)"
        }
        return "\(path)/query/?q=\(encodedQuery)"
    }

    /// Builds a raw (unencoded) query from the builder.
    /// - Parameter path: the path to build the query for
    /// - Returns: the built query
    @objc(buildWithPath:)
    public func build(withPath path: String) -> String? {
        guard let query = build() else { return nil }
        if path.hasSuffix("/") {
            return "\(path)query/?q=\(query)"
        }
        return "\(path)/query/?q=\(query)"
    }

    /// Builds a raw (unencoded) query from the builder.
    /// - Returns: the built query
    @objc public func build() -> String? {
        let query = NSMutableString()

        guard let fieldList = properties["fields"] as? String, !fieldList.isEmpty else {
            // invalid field list
            return nil
        }

        query.append("select ")
        query.append(fieldList)

        guard let from = properties["from"] as? String, !from.isEmpty else {
            // from field not specified
            return nil
        }

        query.append(" from ")
        query.append(from)

        if let whereClause = properties["whereClause"] as? String, !whereClause.isEmpty {
            query.append(" where ")
            query.append(whereClause)
        }

        if let groupBy = properties["groupBy"] as? String, !groupBy.isEmpty {
            query.append(" group by ")
            query.append(groupBy)
        }

        if let having = properties["having"] as? String, !having.isEmpty {
            query.append(" having ")
            query.append(having)
        }

        if let orderBy = properties["orderBy"] as? String, !orderBy.isEmpty {
            query.append(" order by ")
            query.append(orderBy)
        }

        if let limit = properties["limit"] as? Int, limit != 0 {
            query.append(" limit ")
            query.append("\(limit)")
        }

        if let offset = properties["offset"] as? Int, offset != 0 {
            query.append(" offset ")
            query.append("\(offset)")
        }

        return query as String
    }
}
