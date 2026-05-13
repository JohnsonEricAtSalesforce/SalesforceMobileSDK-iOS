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

@objc(SFSDKSoslBuilder)
public class SFSDKSoslBuilder: NSObject {

    private var properties: [String: Any] = [:]
    private var returning: [SFSDKSoslReturningBuilder] = []

    // MARK: - Query Builder

    /// A builder to help create a SOSL statement.
    /// - Parameter searchTerm: text or word phrases to search for
    /// - Returns: the builder
    @objc(withSearchTerm:)
    public static func with(searchTerm: String) -> SFSDKSoslBuilder {
        let builder = SFSDKSoslBuilder()
        builder.setSearchTerm(searchTerm)
        builder.limit(0)
        return builder
    }

    @objc(searchTerm:)
    @discardableResult
    private func setSearchTerm(_ searchTerm: String) -> SFSDKSoslBuilder {
        // Escapes special characters.
        var searchValue = searchTerm
        searchValue = searchValue.replacingOccurrences(of: "\\", with: "\\\\")
        searchValue = searchValue.replacingOccurrences(of: "+", with: "\\+")
        searchValue = searchValue.replacingOccurrences(of: "^", with: "\\^")
        searchValue = searchValue.replacingOccurrences(of: "~", with: "\\~")
        searchValue = searchValue.replacingOccurrences(of: "'", with: "\\'")
        searchValue = searchValue.replacingOccurrences(of: "-", with: "\\-")
        searchValue = searchValue.replacingOccurrences(of: "[", with: "\\[")
        searchValue = searchValue.replacingOccurrences(of: "]", with: "\\]")
        searchValue = searchValue.replacingOccurrences(of: "{", with: "\\{")
        searchValue = searchValue.replacingOccurrences(of: "}", with: "\\}")
        searchValue = searchValue.replacingOccurrences(of: "(", with: "\\(")
        searchValue = searchValue.replacingOccurrences(of: ")", with: "\\)")
        searchValue = searchValue.replacingOccurrences(of: "&", with: "\\&")
        searchValue = searchValue.replacingOccurrences(of: ":", with: "\\:")
        searchValue = searchValue.replacingOccurrences(of: "!", with: "\\!")

        properties["searchTerm"] = searchValue
        return self
    }

    /// A builder to help create a SOSL statement.
    /// - Parameter searchGroup: scope of fields to search. Values may be: ALL FIELDS, NAME FIELDS, EMAIL FIELDS, PHONE FIELDS, SIDEBAR FIELDS
    /// - Returns: the builder
    @objc(searchGroup:)
    @discardableResult
    public func searchGroup(_ searchGroup: String) -> SFSDKSoslBuilder {
        properties["searchGroup"] = searchGroup
        return self
    }

    /// A builder to help create a SOSL statement.
    /// - Parameter returningSpec: information to return in the search result. List of one or more objects and, within each object, list of one or more fields, with optional values to filter against. If unspecified, then the search results contain the IDs of all objects found
    /// - Returns: the builder
    @objc(returning:)
    @discardableResult
    public func returning(_ returningSpec: SFSDKSoslReturningBuilder) -> SFSDKSoslBuilder {
        returning.append(returningSpec)
        return self
    }

    /// A builder to help create a SOSL statement.
    /// - Parameter divisionFilter: if an organization uses divisions, filters all search results based on values for the Division field
    /// - Returns: the builder
    @objc(divisionFilter:)
    @discardableResult
    public func divisionFilter(_ divisionFilter: String) -> SFSDKSoslBuilder {
        properties["divisionFilter"] = divisionFilter
        return self
    }

    /// A builder to help create a SOSL statement.
    /// - Parameter dataCategory: if an organization uses Salesforce Knowledge articles or answers, filters all search results based on one or more data categories
    /// - Returns: the builder
    @objc(dataCategory:)
    @discardableResult
    public func dataCategory(_ dataCategory: String) -> SFSDKSoslBuilder {
        properties["dataCategory"] = dataCategory
        return self
    }

    /// A builder to help create a SOSL statement.
    /// - Parameter limit: the maximum number of rows returned in the text query, up to 200. If unspecified, the default is 200, the largest number of rows that can be returned
    /// - Returns: the builder
    @objc(limit:)
    @discardableResult
    public func limit(_ limit: Int) -> SFSDKSoslBuilder {
        properties["limit"] = limit
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
            return "\(path)search/?q=\(encodedQuery)"
        } else {
            return "\(path)/search/?q=\(encodedQuery)"
        }
    }

    /// Builds a raw (unencoded) query from the builder.
    /// - Parameter path: the path to build the query for
    /// - Returns: the built query
    @objc(buildWithPath:)
    public func build(withPath path: String) -> String? {
        guard let query = build() else { return nil }
        if path.hasSuffix("/") {
            return "\(path)search/?q=\(query)"
        }
        return "\(path)/search/?q=\(query)"
    }

    /// Builds a raw (unencoded) query from the builder.
    /// - Returns: the built query
    @objc public func build() -> String? {
        let query = NSMutableString()

        guard let searchTerm = properties["searchTerm"] as? String, !searchTerm.isEmpty else {
            // invalid search term
            return nil
        }

        query.append("find {\(searchTerm)}")

        if let searchGroup = properties["searchGroup"] as? String, !searchGroup.isEmpty {
            query.append(" in ")
            query.append(searchGroup)
        }

        if !returning.isEmpty {
            query.append(" returning ")
            if let firstReturning = returning.first?.build() {
                query.append(firstReturning)
            }
            for i in 1..<returning.count {
                query.append(", ")
                if let returningBuild = returning[i].build() {
                    query.append(returningBuild)
                }
            }
        }

        if let divisionFilter = properties["divisionFilter"] as? String, !divisionFilter.isEmpty {
            query.append(" with ")
            query.append(divisionFilter)
        }

        if let dataCategory = properties["dataCategory"] as? String, !dataCategory.isEmpty {
            query.append(" with data category ")
            query.append(dataCategory)
        }

        if let limit = properties["limit"] as? Int, limit != 0 {
            query.append(" limit ")
            query.append("\(limit)")
        }

        return query as String
    }
}
