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

import XCTest
@testable import MobileSync

class SFSDKSoqlMutatorTests: XCTestCase {

    func testMutatorNoChange() {
        let soql = "select Id, Name from Account where Id in (select Id from Account) and Name like 'Mad Max' limit 1000"
        XCTAssertEqual(soql, SFSDKSoqlMutator.withSoql(soql).asBuilder().build())
    }

    func testSelectFieldPresenceWhenPresent() {
        let soql = "SELECT Id, Name FROM Account"
        XCTAssertTrue(SFSDKSoqlMutator.withSoql(soql).isSelectingField("Id"))
        XCTAssertTrue(SFSDKSoqlMutator.withSoql(soql).isSelectingField("Name"))
    }

    func testSelectFieldPresenceWhenAbsent() {
        let soql = "SELECT Id, Name FROM Account"
        XCTAssertFalse(SFSDKSoqlMutator.withSoql(soql).isSelectingField("Description"))
    }

    func testSelectFieldPresenceWhenPresentInWhereClause() {
        let soql = "SELECT Id FROM Account WHERE Name like 'James%'"
        XCTAssertFalse(SFSDKSoqlMutator.withSoql(soql).isSelectingField("Name"))
    }

    func testSelectFieldPresenceWhenPresentInSubquery() {
        XCTAssertFalse(SFSDKSoqlMutator.withSoql("SELECT Name, (SELECT LastName FROM Contacts) FROM Account").isSelectingField("LastName"))
    }

    func testSelectFieldPresenceWhenPresentAsSubstring() {
        XCTAssertFalse(SFSDKSoqlMutator.withSoql("SELECT LastName FROM Account").isSelectingField("Name"))
    }

    func testOrderByPresenceWhenPresent() {
        XCTAssertTrue(SFSDKSoqlMutator.withSoql("SELECT LastName FROM Account ORDER BY LastModifiedDate").isOrderingBy("LastModifiedDate"))
    }

    func testOrderByPresenceWhenPresentInSubquery() {
        XCTAssertFalse(SFSDKSoqlMutator.withSoql("SELECT LastName FROM Account WHERE Id IN (SELECT Id FROM Account ORDER BY LastModifiedDate)").isOrderingBy("LastModifiedDate"))
    }

    func testOrderByPresenceWhenAbsent() {
        XCTAssertFalse(SFSDKSoqlMutator.withSoql("SELECT LastName FROM Account").isOrderingBy("LastModifiedDate"))
    }

    func testOrderByPresenceWhenOrderingBySomethingElse() {
        XCTAssertFalse(SFSDKSoqlMutator.withSoql("SELECT LastName FROM Account ORDER BY FirstName").isOrderingBy("LastModifiedDate"))
    }

    func testAddSelectField() {
        let soql = "SELECT Description FROM Account"
        XCTAssertEqual("select Id,Name,Description from Account", SFSDKSoqlMutator.withSoql(soql).addSelectFields("Name").addSelectFields("Id").asBuilder().build())
    }

    func testReplaceSelectField() {
        let soql = "SELECT Description FROM Account"
        XCTAssertEqual("select Id from Account", SFSDKSoqlMutator.withSoql(soql).replaceSelectFields("Id").asBuilder().build())
    }

    func testAddWherePredicateWhenWhereClausePresent() {
        let soql = "SELECT Description FROM Account WHERE FirstName = 'James'"
        XCTAssertEqual("select Description from Account where LastModifiedDate > 123 and FirstName = 'James'", SFSDKSoqlMutator.withSoql(soql).addWherePredicates("LastModifiedDate > 123").asBuilder().build())
    }

    func testAddWherePredicateWhenWhereClauseAbsent() {
        let soql = "SELECT Description FROM Account"
        XCTAssertEqual("select Description from Account where LastModifiedDate > 123", SFSDKSoqlMutator.withSoql(soql).addWherePredicates("LastModifiedDate > 123").asBuilder().build())
    }

    func testReplaceOrderByWhenAbsent() {
        let soql = "SELECT Description FROM Account"
        XCTAssertEqual("select Description from Account order by LastModifiedDate", SFSDKSoqlMutator.withSoql(soql).replaceOrderBy("LastModifiedDate").asBuilder().build())
    }

    func testReplaceOrderByWhenPresent() {
        let soql = "SELECT Description FROM Account ORDER BY Name"
        XCTAssertEqual("select Description from Account order by LastModifiedDate", SFSDKSoqlMutator.withSoql(soql).replaceOrderBy("LastModifiedDate").asBuilder().build())
    }

    func testReplaceOrderByWhenLimit() {
        let soql = "SELECT Description FROM Account LIMIT 1000"
        XCTAssertEqual("select Description from Account order by LastModifiedDate limit 1000", SFSDKSoqlMutator.withSoql(soql).replaceOrderBy("LastModifiedDate").asBuilder().build())
    }

    func testDropOrderBy() {
        let soql = "SELECT Description FROM Account ORDER BY FirstName"
        XCTAssertEqual("select Description from Account", SFSDKSoqlMutator.withSoql(soql).replaceOrderBy("").asBuilder().build())
    }

    func testDropOrderByWhenLimit() {
        let soql = "SELECT Description FROM Account ORDER BY FirstName LIMIT 1000"
        XCTAssertEqual("select Description from Account limit 1000", SFSDKSoqlMutator.withSoql(soql).replaceOrderBy("").asBuilder().build())
    }

    func testHasOrderByWhenPresent() {
        let soql = "SELECT Description FROM Account ORDER BY FirstName LIMIT 1000"
        XCTAssertTrue(SFSDKSoqlMutator.withSoql(soql).hasOrderBy())
    }

    func testHasOrderByWhenPresentInSubquery() {
        let soql = "SELECT Description FROM Account WHERE Id IN (SELECT Id FROM Account ORDER BY FirstName) LIMIT 1000"
        XCTAssertFalse(SFSDKSoqlMutator.withSoql(soql).hasOrderBy())
    }

    func testHasOrderByWhenPresentInValue() {
        let soql = "SELECT Description FROM Account WHERE Name = ' order by \\' order by \\''"
        XCTAssertFalse(SFSDKSoqlMutator.withSoql(soql).hasOrderBy())
    }

    func testHasOrderByWhenAbsent() {
        let soql = "SELECT Description FROM Account LIMIT 1000"
        XCTAssertFalse(SFSDKSoqlMutator.withSoql(soql).hasOrderBy())
    }

    func testModifyQueryWithInClause() {
        let soql = "select Name from Account where Id IN ('001P000001NQPjJIAX','001P000001NQPkdIAH') order by Name"
        let expectedSoql = "select Id,LastModifiedDate,Name from Account where Id IN ('001P000001NQPjJIAX','001P000001NQPkdIAH') order by LastModifiedDate"
        XCTAssertEqual(expectedSoql, SFSDKSoqlMutator.withSoql(soql).addSelectFields("LastModifiedDate").addSelectFields("Id").replaceOrderBy("LastModifiedDate").asBuilder().build())
    }

    func testModifyQueryWithComplexExpressions() {
        let soql = "select Name from Account where ((Name = 'James Bond') or (Name = 'Batman')) and (Description like '%savior%') order by Name"
        let expectedSoql = "select Id,LastModifiedDate,Name from Account where ((Name = 'James Bond') or (Name = 'Batman')) and (Description like '%savior%') order by LastModifiedDate"
        XCTAssertEqual(expectedSoql, SFSDKSoqlMutator.withSoql(soql).addSelectFields("LastModifiedDate").addSelectFields("Id").replaceOrderBy("LastModifiedDate").asBuilder().build())
    }

    func testModifyOrderByTwiceInComplexQuery() {
        let soql = "select LastModifiedDate,Id, OwnerId, WhatId, Status, Subject, Priority, Description, ActivityDate, WhoId from Task where (OwnerId = '<<<UserIDHERE>>>' OR (What.Type = 'Account' AND (Account.OwnerId = '<<<UserIDHERE>>>' OR Account.Owner.ManagerId = '<<<UserIDHERE>>>'))) AND (LastModifiedDate > 2019-05-15T07:52:27.000Z ) order by Description"
        let expectedSoql = "select LastModifiedDate,Id, OwnerId, WhatId, Status, Subject, Priority, Description, ActivityDate, WhoId from Task where (OwnerId = '<<<UserIDHERE>>>' OR (What.Type = 'Account' AND (Account.OwnerId = '<<<UserIDHERE>>>' OR Account.Owner.ManagerId = '<<<UserIDHERE>>>'))) AND (LastModifiedDate > 2019-05-15T07:52:27.000Z ) order by LastModifiedDate"
        XCTAssertEqual(expectedSoql, SFSDKSoqlMutator.withSoql(soql).replaceOrderBy("LastModifiedDate").replaceOrderBy("LastModifiedDate").asBuilder().build())
    }

    func testTokenizeBasic() {
        tryTokenize("hello world", expectedTokensJoined: "hello# #world")
        tryTokenize("hello world: my name is   James    Bond", expectedTokensJoined: "hello# #world:# #my# #name# #is#   #James#    #Bond")
    }

    func testTokenizeWithOrderGroupBy() {
        tryTokenize("hello order by world", expectedTokensJoined: "hello# #order by# #world")
        tryTokenize("hello group by world", expectedTokensJoined: "hello# #group by# #world")
        tryTokenize("hello something by world", expectedTokensJoined: "hello# #something# #by# #world")
        tryTokenize("hello something  by world order  by abc group    by def order", expectedTokensJoined: "hello# #something#  #by# #world# #order by# #abc# #group by# #def# #order")
    }

    func testTokenizeWithQuotes() {
        tryTokenize("hello 'my world'", expectedTokensJoined: "hello# #'my world'")
        tryTokenize("hello 'my world\\''", expectedTokensJoined: "hello# #'my world\\''")
    }

    func testTokenizeWithParentheses() {
        tryTokenize("hello (this is a group)", expectedTokensJoined: "hello# #(this is a group)")
        tryTokenize("hello (a or (b and c) or d),(e or f)", expectedTokensJoined: "hello# #(a or (b and c) or d)#,#(e or f)")
    }

    func testTokenizeWithQuotesInParentheses() {
        tryTokenize("hello (this is a 'group')", expectedTokensJoined: "hello# #(this is a 'group')")
        tryTokenize("hello (a or (b and 'the name of c') or d)", expectedTokensJoined: "hello# #(a or (b and 'the name of c') or d)")
    }

    func testTokenizeWithParenthesesInQuotes() {
        tryTokenize("hello 'oh oh ( ) ( )))'", expectedTokensJoined: "hello# #'oh oh ( ) ( )))'")
    }

    // MARK: - Helper

    private func tryTokenize(_ soql: String, expectedTokensJoined: String) {
        let tokenizer = SFSDKSoqlTokenizer(soql: soql)
        let tokens = tokenizer.tokenize()
        let actualTokensJoined = tokens.joined(separator: "#")
        XCTAssertEqual(expectedTokensJoined, actualTokensJoined)
    }
}
