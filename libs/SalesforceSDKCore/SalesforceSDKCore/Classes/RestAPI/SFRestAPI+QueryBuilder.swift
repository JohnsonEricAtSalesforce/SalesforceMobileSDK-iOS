//
//  SFRestAPI+QueryBuilder.swift
//  SalesforceSDKCore
//
//  Copyright (c) 2012-present, salesforce.com, inc. All rights reserved.
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

/// Reserved characters that must be escaped in SOSL search terms.
public let kSOSLReservedCharacters: String = "\\?&|!{}[]()^~*:\"'+-"

/// Escape character for SOSL.
public let kSOSLEscapeCharacter: String = "\\"

/// Maximum number of records returned via SOSL search.
public let kMaxSOSLSearchLimit: Int = 200

// MARK: - RestClient QueryBuilder Extension

extension RestClient {

    /// Returns a SOSL-safe version of the given search term.
    @objc public static func sanitizeSOSLSearchTerm(_ searchTerm: String) -> String {
        var result = searchTerm
        for i in 0..<kSOSLReservedCharacters.count {
            let index = kSOSLReservedCharacters.index(kSOSLReservedCharacters.startIndex, offsetBy: i)
            let ch = String(kSOSLReservedCharacters[index])
            result = result.replacingOccurrences(of: ch, with: kSOSLEscapeCharacter + ch)
        }
        return result
    }

    /// Generate a SOSL search with a search term and object scope.
    @objc public static func soslSearch(withSearchTerm term: String, objectScope: [String: String]?) -> String? {
        return soslSearch(withSearchTerm: term, fieldScope: nil, objectScope: objectScope, limit: 0)
    }

    /// Generate a SOSL search with all parameters.
    @objc public static func soslSearch(withSearchTerm term: String, fieldScope: String?, objectScope: [String: String]?, limit: Int) -> String? {
        guard !term.isEmpty else { return nil }

        let resolvedFieldScope = (fieldScope?.isEmpty ?? true) ? "IN NAME FIELDS" : fieldScope ?? "IN NAME FIELDS"

        var query = "FIND {\(sanitizeSOSLSearchTerm(term))} \(resolvedFieldScope)"

        if let objectScope = objectScope, !objectScope.isEmpty {
            var scopes: [String] = []
            for (sObject, value) in objectScope {
                var scope = sObject
                if !value.isEmpty {
                    scope += " (\(value))"
                }
                scopes.append(scope)
            }
            query += " RETURNING \(scopes.joined(separator: ","))"
        }

        if limit > 0 {
            let effectiveLimit = limit > kMaxSOSLSearchLimit ? kMaxSOSLSearchLimit : limit
            query += " LIMIT \(effectiveLimit)"
        }

        return query
    }

    /// Generate a SOQL query with basic parameters.
    @objc public static func soqlQuery(withFields fields: [String], sObject: String, whereClause: String?, limit: Int) -> String? {
        return soqlQuery(withFields: fields, sObject: sObject, whereClause: whereClause, groupBy: nil, having: nil, orderBy: nil, limit: limit)
    }

    /// Generate a SOQL query with all parameters.
    @objc public static func soqlQuery(withFields fields: [String], sObject: String, whereClause: String?, groupBy: [String]?, having: String?, orderBy: [String]?, limit: Int) -> String? {
        guard !fields.isEmpty else { return nil }
        guard !sObject.isEmpty else { return nil }

        let uniqueFields = Array(Set(fields))
        var query = "select \(uniqueFields.joined(separator: ",")) from \(sObject)"

        if let whereClause = whereClause, !whereClause.isEmpty {
            query += " where \(whereClause)"
        }

        if let groupBy = groupBy, !groupBy.isEmpty {
            query += " group by \(groupBy.joined(separator: ","))"

            if let having = having, !having.isEmpty {
                query += " having \(having)"
            }
        }

        if let orderBy = orderBy, !orderBy.isEmpty {
            query += " order by \(orderBy.joined(separator: ","))"
        }

        if limit > 0 {
            query += " limit \(limit)"
        }

        return query
    }
}
