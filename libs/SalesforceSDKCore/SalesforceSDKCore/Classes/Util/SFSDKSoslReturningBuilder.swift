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

@objc(SFSDKSoslReturningBuilder)
public class SFSDKSoslReturningBuilder: NSObject {

    private var properties: [String: Any] = [:]

    /// Returns the object name for this builder
    @objc public var objectName: String {
        return properties["objectName"] as? String ?? ""
    }

    // MARK: - Builder Methods

    /// A builder to help create a returning statement.
    /// - Parameter name: the object to return.
    /// - Returns: the builder
    @objc(withObjectName:)
    public static func with(objectName name: String) -> SFSDKSoslReturningBuilder {
        let builder = SFSDKSoslReturningBuilder()
        builder.setObjectName(name)
        builder.limit(0)
        return builder
    }

    @objc(objectName:)
    @discardableResult
    private func setObjectName(_ name: String) -> SFSDKSoslReturningBuilder {
        properties["objectName"] = name
        return self
    }

    /// A builder to help create a returning statement.
    /// - Parameter fields: a list of one or more fields to return for a given object, comma separated
    /// - Returns: the builder
    @objc(fields:)
    @discardableResult
    public func fields(_ fields: String) -> SFSDKSoslReturningBuilder {
        properties["fields"] = fields
        return self
    }

    /// A builder to help create a returning statement.
    /// - Parameter whereClause: a description of how search results for the given object should be filtered, based on individual field values. If unspecified, the search retrieves all the rows in the object that are visible to the user
    /// - Returns: the builder
    @objc(whereClause:)
    @discardableResult
    public func whereClause(_ whereClause: String) -> SFSDKSoslReturningBuilder {
        properties["whereClause"] = whereClause
        return self
    }

    /// A builder to help create a returning statement.
    /// - Parameter networkId: The network id to scope this returning statement with, if necessary
    /// - Returns: the builder
    @objc(withNetwork:)
    @discardableResult
    public func withNetwork(_ networkId: String) -> SFSDKSoslReturningBuilder {
        properties["withNetwork"] = networkId
        return self
    }

    /// A builder to help create a returning statement.
    /// - Parameter orderBy: a description of how to order the returned result, including ascending and descending order, and how nulls are ordered
    /// - Returns: the builder
    @objc(orderBy:)
    @discardableResult
    public func orderBy(_ orderBy: String) -> SFSDKSoslReturningBuilder {
        properties["orderBy"] = orderBy
        return self
    }

    /// A builder to help create a returning statement.
    /// - Parameter limit: the maximum number of records returned for the given object. If unspecified, all matching records are returned, up to the limit set for the query as a whole
    /// - Returns: the builder
    @objc(limit:)
    @discardableResult
    public func limit(_ limit: Int) -> SFSDKSoslReturningBuilder {
        properties["limit"] = limit
        return self
    }

    // MARK: - Query String Generation

    /// Builds a returning statement from the builder.
    /// - Returns: the built returning statement
    @objc public func build() -> String? {
        let query = NSMutableString()
        guard let objectName = properties["objectName"] as? String, !objectName.isEmpty else {
            // missing object name
            return nil
        }

        query.append(" ")
        query.append(objectName)

        if let fields = properties["fields"] as? String, !fields.isEmpty {
            query.append("(\(fields)")

            if let whereClause = properties["whereClause"] as? String, !whereClause.isEmpty {
                query.append(" where ")
                query.append(whereClause)
            }

            if let orderBy = properties["orderBy"] as? String, !orderBy.isEmpty {
                query.append(" order by ")
                query.append(orderBy)
            }

            if let withNetwork = properties["withNetwork"] as? String, !withNetwork.isEmpty {
                query.append(" with network = ")
                query.append(withNetwork)
            }

            if let limit = properties["limit"] as? Int, limit != 0 {
                query.append(" limit ")
                query.append("\(limit)")
            }

            query.append(")")
        }

        return query as String
    }
}
