/*
 * Copyright (c) 2012-present, salesforce.com, inc.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification, are permitted provided
 * that the following conditions are met:
 *
 *    Redistributions of source code must retain the above copyright notice, this list of conditions and the
 *    following disclaimer.
 *
 *    Redistributions in binary form must reproduce the above copyright notice, this list of conditions and
 *    the following disclaimer in the documentation and/or other materials provided with the distribution.
 *
 *    Neither the name of salesforce.com, inc. nor the names of its contributors may be used to endorse or
 *    promote products derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 * PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 * TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

/**
 * This category assists with creating SOQL and SOSL queries.
 *
 * Example SOQL usage:
 *
 * let soqlQuery = RestClient.soqlQuery(
 *     withFields: ["Id", "Name", "Company", "Status"],
 *     sObject: "Lead",
 *     whereClause: nil,
 *     limit: 10
 * )
 *
 * Example SOSL usage:
 *
 * let soslQuery = RestClient.soslSearch(
 *     withSearchTerm: "all of these will be escaped:~{]",
 *     objectScope: ["User": "WHERE isactive=true ORDER BY lastname asc limit 5"]
 * )
 */

import Foundation

// Reserved characters that must be escaped in SOSL search terms
public let kSOSLReservedCharacters = "\\?&|!{}[]()^~*:\"'+-"
public let kSOSLEscapeCharacter = "\\"

// Maximum number of records returned via SOSL search
public let kMaxSOSLSearchLimit = 200

@objc
extension RestClient {

    /**
     * @param searchTerm The search term to be sanitized.
     * @return SOSL-safe version of search term
     */
    @objc
    public static func sanitizeSOSLSearchTerm(_ searchTerm: String) -> String {
        var sanitized = searchTerm

        // Escape every reserved character in this term
        for i in 0..<kSOSLReservedCharacters.count {
            let startIndex = kSOSLReservedCharacters.index(kSOSLReservedCharacters.startIndex, offsetBy: i)
            let endIndex = kSOSLReservedCharacters.index(startIndex, offsetBy: 1)
            let ch = String(kSOSLReservedCharacters[startIndex..<endIndex])
            sanitized = sanitized.replacingOccurrences(of: ch, with: kSOSLEscapeCharacter + ch)
        }

        return sanitized
    }

    // MARK: - Generating Searches

    /**
     * Generate a SOSL search.
     * @param term - the search term. This is sanitized for proper characters
     * @param objectScope - nil to search all searchable objects, or a dictionary where each key is an sObject name
     * and each value is a string with the fieldlist and (optional) where, order by, and limit clause for that object.
     * or NSNull to not specify any fields/clauses for that object
     * @returns query or nil if a query could not be generated
     */
    @objc
    public static func soslSearch(withSearchTerm term: String, objectScope: [String: String]?) -> String? {
        return soslSearch(withSearchTerm: term, fieldScope: nil, objectScope: objectScope, limit: 0)
    }

    /**
     * Generate a SOSL search.
     * @param term - the search term. This is sanitized for proper characters
     * @param fieldScope - nil OR the SOSL scope, e.g. "IN ALL FIELDS". if nil, defaults to "IN NAME FIELDS"
     * @param objectScope - nil to search all searchable objects, or a dictionary where each key is an sObject name
     * and each value is a string with the fieldlist and (optional) where, order by, and limit clause for that object.
     * or NSNull to not specify any fields/clauses for that object
     * @param limit - overall search limit (max 200)
     * @returns query or nil if a query could not be generated
     */
    @objc
    public static func soslSearch(withSearchTerm term: String, fieldScope: String?, objectScope: [String: String]?, limit: Int) -> String? {
        guard !term.isEmpty else {
            return nil
        }

        let actualFieldScope = fieldScope?.isEmpty == false ? fieldScope! : "IN NAME FIELDS"
        var query = "FIND {\(sanitizeSOSLSearchTerm(term))} \(actualFieldScope)"

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
            let actualLimit = min(limit, kMaxSOSLSearchLimit)
            query += " LIMIT \(actualLimit)"
        }

        return query
    }

    /**
     * Generate a SOQL query.
     * @param fields - NSArray of fields to select
     * @param sObject - object to query
     * @param whereClause - nil OR where clause
     * @param limit - limit count, or 0 for no limit (for use with query locators)
     * @returns query or nil if a query could not be generated
     */
    @objc
    public static func soqlQuery(withFields fields: [String], sObject: String, whereClause: String?, limit: Int) -> String? {
        return soqlQuery(withFields: fields, sObject: sObject, whereClause: whereClause, groupBy: nil, having: nil, orderBy: nil, limit: limit)
    }

    /**
     * Generate a SOQL query.
     * @param fields - NSArray of fields to select
     * @param sObject - object to query
     * @param whereClause - nil OR where clause
     * @param groupBy - nil OR NSArray of strings, each string is an individual group by clause
     * @param having - nil OR having clause
     * @param orderBy - nil OR NSArray of strings, each string is an individual order by clause
     * @param limit - limit count, or 0 for no limit (for use with query locators)
     * @returns query or nil if a query could not be generated
     */
    @objc
    public static func soqlQuery(withFields fields: [String], sObject: String, whereClause: String?, groupBy: [String]?, having: String?, orderBy: [String]?, limit: Int) -> String? {
        guard !fields.isEmpty else {
            return nil
        }

        guard !sObject.isEmpty else {
            return nil
        }

        // Use Set to remove duplicates, then convert back to array for joining
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
