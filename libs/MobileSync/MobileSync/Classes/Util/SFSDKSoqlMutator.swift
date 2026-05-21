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

private let kSelect = "select"
private let kFrom = "from"
private let kWhere = "where"
private let kHaving = "having"
private let kOrderBy = "order by"
private let kGroupBy = "group by"
private let kLimit = "limit"
private let kOffset = "offset"

@objc(SFSDKSoqlMutator)
@objcMembers
public class SFSDKSoqlMutator: NSObject {

    private var originalSoql: String
    private var clauses = [String: String]()
    private var clausesWithoutSubqueries = [String: String]()

    // MARK: - Factory

    @objc public class func withSoql(_ soql: String) -> SFSDKSoqlMutator {
        return SFSDKSoqlMutator(soql: soql)
    }

    private init(soql: String) {
        self.originalSoql = soql
        super.init()
        parseQuery()
    }

    // MARK: - Mutations

    @objc @discardableResult
    public func replaceSelectFields(_ commaSeparatedFields: String) -> SFSDKSoqlMutator {
        clauses[kSelect] = commaSeparatedFields
        return self
    }

    @objc @discardableResult
    public func addSelectFields(_ commaSeparatedFields: String) -> SFSDKSoqlMutator {
        clauses[kSelect] = "\(commaSeparatedFields),\(trimmedClause(kSelect))"
        return self
    }

    @objc @discardableResult
    public func addWherePredicates(_ commaSeparatedPredicates: String) -> SFSDKSoqlMutator {
        if clauses[kWhere] != nil {
            clauses[kWhere] = "\(commaSeparatedPredicates) and \(trimmedClause(kWhere))"
        } else {
            clauses[kWhere] = commaSeparatedPredicates
        }
        return self
    }

    @objc @discardableResult
    public func replaceOrderBy(_ commaSeparatedFields: String) -> SFSDKSoqlMutator {
        clauses[kOrderBy] = commaSeparatedFields
        return self
    }

    // MARK: - Query inspection

    @objc public func isOrderingBy(_ commaSeparatedFields: String) -> Bool {
        guard let orderByClause = clauses[kOrderBy] else { return false }
        return equalsIgnoringWhiteSpaces(orderByClause, s2: commaSeparatedFields)
    }

    @objc public func hasOrderBy() -> Bool {
        return clauses[kOrderBy] != nil
    }

    @objc public func isSelectingField(_ field: String) -> Bool {
        let selectClause = clausesWithoutSubqueries[kSelect] ?? ""
        let selectedFields = removeWhiteSpaces(selectClause).components(separatedBy: ",")
        return selectedFields.contains(field)
    }

    // MARK: - Builder

    @objc public func asBuilder() -> SFSDKSoqlBuilder {
        let builder = SFSDKSoqlBuilder.withFields(trimmedClause(kSelect))
            .from(trimmedClause(kFrom))
            .whereClause(trimmedClause(kWhere))
            .having(trimmedClause(kHaving))
            .groupBy(trimmedClause(kGroupBy))
            .orderBy(trimmedClause(kOrderBy))

        let limitValue = clauseAsInteger(kLimit)
        if limitValue > 0 {
            builder.limit(limitValue)
        }
        let offsetValue = clauseAsInteger(kOffset)
        if offsetValue > 0 {
            builder.offset(offsetValue)
        }
        return builder
    }

    // MARK: - Private helpers

    private func parseQuery() {
        let clauseTypeKeywords = [kSelect, kFrom, kWhere, kHaving, kOrderBy, kGroupBy, kLimit, kOffset]

        var matchingClauseType: String?
        var currentClauseType: String?
        let tokenizer = SFSDKSoqlTokenizer(soql: originalSoql)

        for token in tokenizer.tokenize() {
            matchingClauseType = nil
            for clauseType in clauseTypeKeywords {
                if token.caseInsensitiveCompare(clauseType) == .orderedSame {
                    matchingClauseType = clauseType
                    break
                }
            }

            if let matched = matchingClauseType {
                currentClauseType = matched
                clauses[matched] = ""
                clausesWithoutSubqueries[matched] = ""
            } else if let current = currentClauseType {
                clauses[current] = (clauses[current] ?? "") + token
                if !token.hasPrefix("(") {
                    clausesWithoutSubqueries[current] = (clausesWithoutSubqueries[current] ?? "") + token
                }
            }
        }
    }

    private func clauseAsInteger(_ clauseType: String) -> Int {
        return Int(trimmedClause(clauseType)) ?? 0
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
