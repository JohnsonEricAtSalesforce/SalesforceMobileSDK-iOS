/*
 Copyright (c) 2019-present, salesforce.com, inc. All rights reserved.

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

private let kSFSDKSoqlMutatorSelect = "select"
private let kSFSDKSoqlMutatorFrom = "from"
private let kSFSDKSoqlMutatorWhere = "where"
private let kSFSDKSoqlMutatorHaving = "having"
private let kSFSDKSoqlMutatorOrderBy = "order by"
private let kSFSDKSoqlMutatorGroupBy = "group by"
private let kSFSDKSoqlMutatorLimit = "limit"
private let kSFSDKSoqlMutatorOffset = "offset"

@objc(SFSDKSoqlMutator)
public class SoqlMutator: NSObject {

    private let originalSoql: String
    private var clauses: [String: String] = [:]
    private var clausesWithoutSubqueries: [String: String] = [:]

    /**
     * Initialize this SOQLMutator with the soql query to manipulate
     * @param soql Original soql query.
     */
    @objc(withSoql:)
    public static func with(soql: String) -> SoqlMutator {
        return SoqlMutator(soql: soql)
    }

    private init(soql: String) {
        self.originalSoql = soql
        super.init()
        parseQuery()
    }

    private func parseQuery() {
        let clauseTypeKeywords = [
            kSFSDKSoqlMutatorSelect, kSFSDKSoqlMutatorFrom,
            kSFSDKSoqlMutatorWhere, kSFSDKSoqlMutatorHaving,
            kSFSDKSoqlMutatorOrderBy, kSFSDKSoqlMutatorGroupBy,
            kSFSDKSoqlMutatorLimit, kSFSDKSoqlMutatorOffset
        ]

        var matchingClauseType: String?
        var currentClauseType: String? // one of the clause types of interest
        let tokenizer = SoqlTokenizer(soql: originalSoql)

        for token in tokenizer.tokenize() {
            for clauseType in clauseTypeKeywords {
                if token.caseInsensitiveCompare(clauseType) == .orderedSame {
                    matchingClauseType = clauseType
                    break
                }
            }

            if let matchedType = matchingClauseType {
                // We just matched one of the clauseTypeKeywords in the top level query
                currentClauseType = matchedType
                clauses[matchedType] = ""
                clausesWithoutSubqueries[matchedType] = ""
                matchingClauseType = nil
            } else {
                // We are inside a clause
                if let clauseType = currentClauseType {
                    clauses[clauseType] = (clauses[clauseType] ?? "") + token
                    // We are inside a clause and not in a subquery
                    if !token.hasPrefix("(") {
                        clausesWithoutSubqueries[clauseType] = (clausesWithoutSubqueries[clauseType] ?? "") + token
                    }
                }
            }
        }
    }

    /**
     * Replace select fields
     * @param commaSeparatedFields Comma separated fields to use in top level query's select.
     */
    @objc(replaceSelectFields:)
    @discardableResult
    public func replaceSelectFields(_ commaSeparatedFields: String) -> SoqlMutator {
        clauses[kSFSDKSoqlMutatorSelect] = commaSeparatedFields
        return self
    }

    /**
     * Add fields to select
     * @param commaSeparatedFields Comma separated fields to add to top level query's select.
     */
    @objc(addSelectFields:)
    @discardableResult
    public func addSelectFields(_ commaSeparatedFields: String) -> SoqlMutator {
        clauses[kSFSDKSoqlMutatorSelect] = "\(commaSeparatedFields),\(trimmedClause(kSFSDKSoqlMutatorSelect))"
        return self
    }

    /**
     * Add predicates to where clause
     * @param commaSeparatedPredicates Comma separated predicates to add to top level query's where.
     */
    @objc(addWherePredicates:)
    @discardableResult
    public func addWherePredicates(_ commaSeparatedPredicates: String) -> SoqlMutator {
        if clauses[kSFSDKSoqlMutatorWhere] != nil {
            clauses[kSFSDKSoqlMutatorWhere] = "\(commaSeparatedPredicates) and \(trimmedClause(kSFSDKSoqlMutatorWhere))"
        } else {
            clauses[kSFSDKSoqlMutatorWhere] = commaSeparatedPredicates
        }
        return self
    }

    /**
     * Replace order by clause (or add one if none)
     * @param commaSeparatedFields Comma separated fields to add to top level query's select.
     */
    @objc(replaceOrderBy:)
    @discardableResult
    public func replaceOrderBy(_ commaSeparatedFields: String) -> SoqlMutator {
        clauses[kSFSDKSoqlMutatorOrderBy] = commaSeparatedFields
        return self
    }

    /**
     * Check if query is ordering by given fields
     * @param commaSeparatedFields Comma separated fields to look for.
     * @return YES if it is the case.
     */
    @objc(isOrderingBy:)
    public func isOrderingBy(_ commaSeparatedFields: String) -> Bool {
        guard let orderByClause = clauses[kSFSDKSoqlMutatorOrderBy] else { return false }
        return equalsIgnoringWhiteSpaces(orderByClause, s2: commaSeparatedFields)
    }

    /**
     * Check if query has order by clause
     * @return YES if it is the case.
     */
    @objc
    public func hasOrderBy() -> Bool {
        return clauses[kSFSDKSoqlMutatorOrderBy] != nil
    }

    /**
     * Check if query is selecting by given field
     * @param field Field to look for.
     * @return YES if it is the case.
     */
    @objc(isSelectingField:)
    public func isSelectingField(_ field: String) -> Bool {
        guard let selectClause = clausesWithoutSubqueries[kSFSDKSoqlMutatorSelect] else { return false }
        let selectedFields = removeWhiteSpaces(selectClause).components(separatedBy: ",")
        return selectedFields.contains(field)
    }

    /**
     * @return a SOQL builder with mutations applied
     */
    @objc
    public func asBuilder() -> SoqlMutator {
        // Return self as the mutator acts as a builder
        return self
    }

    /**
     * @return the mutated SOQL query as a string
     */
    @objc
    public func build() -> String {
        let builder = SFSDKSoqlBuilder.with(fields: trimmedClause(kSFSDKSoqlMutatorSelect))
            .from(trimmedClause(kSFSDKSoqlMutatorFrom))

        let whereClause = trimmedClause(kSFSDKSoqlMutatorWhere)
        if !whereClause.isEmpty {
            builder.whereClause(whereClause)
        }

        let having = trimmedClause(kSFSDKSoqlMutatorHaving)
        if !having.isEmpty {
            builder.having(having)
        }

        let groupBy = trimmedClause(kSFSDKSoqlMutatorGroupBy)
        if !groupBy.isEmpty {
            builder.groupBy(groupBy)
        }

        let orderBy = trimmedClause(kSFSDKSoqlMutatorOrderBy)
        if !orderBy.isEmpty {
            builder.orderBy(orderBy)
        }

        if let limit = clauseAsInteger(kSFSDKSoqlMutatorLimit) {
            builder.limit(limit.intValue)
        }
        if let offset = clauseAsInteger(kSFSDKSoqlMutatorOffset) {
            builder.offset(offset.intValue)
        }

        return builder.build() ?? ""
    }

    // MARK: - Helper methods

    private func clauseAsInteger(_ clauseType: String) -> NSNumber? {
        let trimmed = trimmedClause(clauseType)
        if trimmed.isEmpty {
            return nil
        }
        return NSNumber(value: Int(trimmed) ?? 0)
    }

    private func trimmedClause(_ clauseType: String) -> String {
        return clauses[clauseType]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func equalsIgnoringWhiteSpaces(_ s1: String, s2: String) -> Bool {
        return removeWhiteSpaces(s1) == removeWhiteSpaces(s2)
    }

    private func removeWhiteSpaces(_ s: String) -> String {
        return s.replacingOccurrences(of: " ", with: "")
    }
}
