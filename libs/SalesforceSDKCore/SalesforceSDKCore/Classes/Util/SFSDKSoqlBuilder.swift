// Copyright (c) 2014-present, salesforce.com, inc. All rights reserved.
//
// Redistribution and use of this software in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
// * Redistributions of source code must retain the above copyright notice, this list of conditions
// and the following disclaimer.
// * Redistributions in binary form must reproduce the above copyright notice, this list of
// conditions and the following disclaimer in the documentation and/or other materials provided
// with the distribution.
// * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
// endorse or promote products derived from this software without specific prior written
// permission of salesforce.com, inc.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
// IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
// FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
// CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
// WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
// WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import Foundation

/// A builder to help create a SOQL statement.
@objc(SFSDKSoqlBuilder)
@objcMembers public class SFSDKSoqlBuilder: NSObject {

    private var properties = NSMutableDictionary()

    // MARK: - Factory Methods

    /// Creates a new builder with the given comma-separated field list.
    @objc public class func withFields(_ fields: String) -> SFSDKSoqlBuilder {
        let builder = SFSDKSoqlBuilder()
        builder.fields(fields)
        builder.limit(0)
        builder.offset(0)
        return builder
    }

    /// Creates a new builder with the given array of fields.
    @objc public class func withFieldsArray(_ fields: [String]) -> SFSDKSoqlBuilder {
        return SFSDKSoqlBuilder.withFields(fields.joined(separator: ", "))
    }

    // MARK: - Builder Methods

    @discardableResult
    @objc public func fields(_ fields: String) -> SFSDKSoqlBuilder {
        properties["fields"] = fields
        return self
    }

    @discardableResult
    @objc public func from(_ from: String) -> SFSDKSoqlBuilder {
        properties["from"] = from
        return self
    }

    @discardableResult
    @objc public func whereClause(_ whereClause: String) -> SFSDKSoqlBuilder {
        properties["whereClause"] = whereClause
        return self
    }

    @discardableResult
    @objc public func with(_ with: String) -> SFSDKSoqlBuilder {
        properties["with"] = with
        return self
    }

    @discardableResult
    @objc public func groupBy(_ groupBy: String) -> SFSDKSoqlBuilder {
        properties["groupBy"] = groupBy
        return self
    }

    @discardableResult
    @objc public func having(_ having: String) -> SFSDKSoqlBuilder {
        properties["having"] = having
        return self
    }

    @discardableResult
    @objc public func orderBy(_ orderBy: String) -> SFSDKSoqlBuilder {
        properties["orderBy"] = orderBy
        return self
    }

    @discardableResult
    @objc public func limit(_ limit: Int) -> SFSDKSoqlBuilder {
        properties["limit"] = NSNumber(value: limit)
        return self
    }

    @discardableResult
    @objc public func offset(_ offset: Int) -> SFSDKSoqlBuilder {
        properties["offset"] = NSNumber(value: offset)
        return self
    }

    // MARK: - Encoded Queries

    @objc public func encodeAndBuild() -> String? {
        return build()?.sfsdk_stringByURLEncoding()
    }

    @objc public func encodeAndBuild(withPath path: String) -> String? {
        guard let encoded = encodeAndBuild() else { return nil }
        if path.hasSuffix("/") {
            return "\(path)query/?q=\(encoded)"
        }
        return "\(path)/query/?q=\(encoded)"
    }

    // MARK: - Raw Queries

    @objc public func build(withPath path: String) -> String? {
        guard let built = build() else { return nil }
        if path.hasSuffix("/") {
            return "\(path)query/?q=\(built)"
        }
        return "\(path)/query/?q=\(built)"
    }

    @objc public func build() -> String? {
        var query = ""
        guard let fieldList = properties["fields"] as? String, !fieldList.isEmpty else {
            return nil
        }
        query += "select "
        query += fieldList
        guard let from = properties["from"] as? String, !from.isEmpty else {
            return nil
        }
        query += " from "
        query += from
        if let whereClause = properties["whereClause"] as? String, !whereClause.isEmpty {
            query += " where "
            query += whereClause
        }
        if let groupBy = properties["groupBy"] as? String, !groupBy.isEmpty {
            query += " group by "
            query += groupBy
        }
        if let having = properties["having"] as? String, !having.isEmpty {
            query += " having "
            query += having
        }
        if let orderBy = properties["orderBy"] as? String, !orderBy.isEmpty {
            query += " order by "
            query += orderBy
        }
        if let limit = properties["limit"] as? NSNumber, limit.intValue != 0 {
            query += " limit "
            query += "\(limit.intValue)"
        }
        if let offset = properties["offset"] as? NSNumber, offset.intValue != 0 {
            query += " offset "
            query += "\(offset.intValue)"
        }
        return query
    }
}
