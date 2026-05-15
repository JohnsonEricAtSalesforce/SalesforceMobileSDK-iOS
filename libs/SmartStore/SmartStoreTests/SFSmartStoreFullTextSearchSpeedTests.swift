/*
 Copyright (c) 2015-present, salesforce.com, inc. All rights reserved.

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
import FMDB
@testable import SmartStore
import SalesforceSDKCore
import SalesforceSDKCommon

private let kTestStore = "testSmartStore"
private let kAnimalsSoup = "animals"
private let kText = "text"

class SFSmartStoreFullTextSearchSpeedTests: SFSmartStoreTestCase {

    private var store: SmartStore!
    private var animals: [String]!

    override func setUp() {
        super.setUp()
        store = SmartStore.sharedGlobal(withName: kTestStore)
        animals = ["alligator", "ant", "bear", "bee", "bird", "camel", "cat",
                   "cheetah", "chicken", "chimpanzee", "cow", "crocodile", "deer", "dog", "dolphin",
                   "duck", "eagle", "elephant", "fish", "fly", "fox", "frog", "giraffe", "goat",
                   "goldfish", "hamster", "hippopotamus", "horse", "iguana", "impala", "jaguar", "jellyfish", "kangaroo", "kitten", "lion",
                   "lobster", "monkey", "nightingale", "octopus", "owl", "panda", "pig", "puppy", "quail", "rabbit", "rat",
                   "scorpion", "seal", "shark", "sheep", "snail", "snake", "spider", "squirrel",
                   "tiger", "turtle", "umbrellabird", "vulture", "wolf", "xantus", "xerus", "yak"]
    }

    override func tearDown() {
        store.removeAllSoups()
        SmartStore.removeSharedGlobal(withName: kTestStore)
        super.tearDown()
        store = nil
        animals = nil
    }

    // MARK: - Tests

    func testSearch1000RowsOneMatch() {
        trySearch(rowsPerAnimal: 40, matchingRowsPerAnimal: 1)
    }

    func testSearch1000RowsManyMatches() {
        trySearch(rowsPerAnimal: 40, matchingRowsPerAnimal: 40)
    }

    // MARK: - Helper methods

    private func trySearch(rowsPerAnimal: Int, matchingRowsPerAnimal: Int) {
        let totalInsertTimeString = setupData(textFieldType: kSoupIndexTypeString, rowsPerAnimal: rowsPerAnimal, matchingRowsPerAnimal: matchingRowsPerAnimal)
        let avgQueryTimeString = queryData(textFieldType: kSoupIndexTypeString, rowsPerAnimal: rowsPerAnimal, matchingRowsPerAnimal: matchingRowsPerAnimal)
        store.removeAllSoups()
        let totalInsertTimeFullText = setupData(textFieldType: kSoupIndexTypeFullText, rowsPerAnimal: rowsPerAnimal, matchingRowsPerAnimal: matchingRowsPerAnimal)
        let avgQueryTimeFullText = queryData(textFieldType: kSoupIndexTypeFullText, rowsPerAnimal: rowsPerAnimal, matchingRowsPerAnimal: matchingRowsPerAnimal)
        store.removeAllSoups()

        NSLog("Search rows=%d matchingRows=%d avgQueryTimeString=%.4fs avgQueryTimeFullText=%.4fs (%.2f%%) totalInsertTimeString=%.3fs totalInsertTimeFullText=%.3fs (%.2f%%)",
              rowsPerAnimal * 25,
              matchingRowsPerAnimal,
              avgQueryTimeString,
              avgQueryTimeFullText,
              100 * avgQueryTimeFullText / avgQueryTimeString,
              totalInsertTimeString,
              totalInsertTimeFullText,
              100 * totalInsertTimeFullText / totalInsertTimeString)
    }

    private func setupData(textFieldType: String, rowsPerAnimal: Int, matchingRowsPerAnimal: Int) -> Double {
        let soupIndices = SoupIndex.asArray([[kSoupIndexPath: kText, kSoupIndexType: textFieldType]])
        try! store.registerSoup(withName: kAnimalsSoup, withIndices: soupIndices)

        var rowCount = 0
        var totalInsertTime = 0.0
        for i in 0..<25 {
            let charToMatch = Character(UnicodeScalar(i + Int(("a" as UnicodeScalar).value))!)
            store.storeQueue.inDatabase { db in
                for j in 0..<rowsPerAnimal {
                    let prefix = String(format: "%07d", j % (rowsPerAnimal / matchingRowsPerAnimal))
                    var text = ""
                    for animal in self.animals {
                        if animal.first == charToMatch {
                            text += "\(prefix)\(animal) "
                        }
                    }
                    let start = Date()
                    var error: NSError?
                    _ = self.store.upsertEntries([NSDictionary(dictionary: [kText: text])], toSoup: kAnimalsSoup, withExternalIdPath: nil, error: &error, with: db)
                    rowCount += 1
                    if rowCount % 100 == 0 { NSLog("Rows inserted %d", rowCount) }
                    totalInsertTime += Date().timeIntervalSince(start)
                }
            }
        }

        return totalInsertTime
    }

    private func queryData(textFieldType: String, rowsPerAnimal: Int, matchingRowsPerAnimal: Int) -> Double {
        var totalQueryTime = 0.0
        for animal in animals {
            let prefix = String(format: "%07d", Int(arc4random_uniform(UInt32(rowsPerAnimal / matchingRowsPerAnimal))))
            let matchKey = "\(prefix)\(animal)"
            let likeKey = "%\(matchKey)%"
            let querySpec: QuerySpec
            if textFieldType == kSoupIndexTypeFullText {
                querySpec = QuerySpec.buildMatchQuerySpec(soupName: kAnimalsSoup, path: kText, matchKey: matchKey, orderPath: "", order: .ascending, pageSize: UInt(rowsPerAnimal))
            } else {
                querySpec = QuerySpec.buildLikeQuerySpec(soupName: kAnimalsSoup, path: kText, likeKey: likeKey, orderPath: "", order: .ascending, pageSize: UInt(rowsPerAnimal))
            }

            let start = Date()
            let results = try! store.query(using: querySpec, startingFromPageIndex: 0)
            totalQueryTime += Date().timeIntervalSince(start)
            validateResults(expectedRows: matchingRowsPerAnimal, stringToMatch: matchKey, results: results as! [[String: Any]])
        }

        return totalQueryTime / Double(animals.count)
    }

    private func validateResults(expectedRows: Int, stringToMatch: String, results: [[String: Any]]) {
        XCTAssertEqual(results.count, expectedRows, "Wrong number of results")
        for result in results {
            let text = result[kText] as? String ?? ""
            XCTAssertTrue(text.contains(stringToMatch), "Invalid result")
        }
    }
}
