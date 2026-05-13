/*
 Copyright (c) 2011-present, salesforce.com, inc. All rights reserved.

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
import SalesforceSDKCommon
import SalesforceSDKCore

/**
 * Defines a cursor into data stored in a soup.
 */
@objc(SFStoreCursor)
@objcMembers
public class StoreCursor: NSObject {

    /**
     * A unique ID for this cursor.
     */
    @objc
    public private(set) var cursorId: String?

    /**
     * The query spec that generated this cursor.
     */
    @objc
    public private(set) var querySpec: QuerySpec?

    /**
     * The list of current page entries, ordered as requested in the querySpec.
     */
    @objc
    public var currentPageOrderedEntries: [Any]? {
        return nil // This is computed dynamically when needed
    }

    /**
     * The maximum number of entries returned per page.
     */
    @objc
    public private(set) var pageSize: NSNumber?

    /**
     * The total number of pages of results available.
     */
    @objc
    public private(set) var totalPages: NSNumber?

    /**
     * The total number of entries.
     */
    @objc
    public private(set) var totalEntries: NSNumber?

    /**
     * The current page index among totalPages available: writing this value
     * causes currentPageOrderedEntries to be refetched.
     */
    @objc
    public var currentPageIndex: NSNumber?

    /**
     * Initializes a new instance of a soup cursor.
     * @param store The store where the soup is contained.
     * @param querySpec The query used to retrieve the data.
     */
    @objc(initWithStore:querySpec:)
    public init(store: SmartStore, querySpec: QuerySpec) {
        self.querySpec = querySpec
        self.pageSize = NSNumber(value: querySpec.pageSize)

        let totalEntriesValue = (try? store.count(using: querySpec))?.uintValue ?? 0
        let totalPagesFloat = Float(totalEntriesValue) / Float(querySpec.pageSize)
        var totalPagesValue = UInt(ceilf(totalPagesFloat))
        if totalEntriesValue == 0 {
            totalPagesValue = 0
        }

        self.totalPages = NSNumber(value: totalPagesValue)
        self.totalEntries = NSNumber(value: totalEntriesValue)
        self.currentPageIndex = NSNumber(value: 0)
        super.init()
        self.cursorId = String(format: "0x%lx", UInt(bitPattern: ObjectIdentifier(self)))
    }

    deinit {
        if cursorId != nil { // otherwise close has already been called
            close()
        }
    }

    /**
     Close this cursor when finished operating on it.
     */
    @objc(close)
    public func close() {
        SmartStoreLogger.v(type(of: self), message: "closing cursor id: \(cursorId ?? "")")
        cursorId = nil
        querySpec = nil
        currentPageIndex = nil
        pageSize = nil
        totalPages = nil
    }

    /**
     * Run query and resturn JSON serialized representation of the cursor.
     * @return JSON serialized representation of this object.
     */
    public func getDataSerialized(_ store: SmartStore) throws -> String? {
        let resultBuilder = NSMutableString()
        resultBuilder.append("{")
        resultBuilder.append("\"\("cursorId")\":\"\(cursorId ?? "")\", ")
        resultBuilder.append("\"\("currentPageIndex")\":\(currentPageIndex ?? 0), ")
        resultBuilder.append("\"\("pageSize")\":\(pageSize ?? 0), ")
        resultBuilder.append("\"\("totalPages")\":\(totalPages ?? 0), ")
        resultBuilder.append("\"\("totalEntries")\":\(totalEntries ?? 0), ")
        resultBuilder.append("\"\("currentPageOrderedEntries")\":")

        guard let querySpec = querySpec else {
            throw NSError(domain: "SmartStore", code: -1, userInfo: [NSLocalizedDescriptionKey: "Query spec is nil"])
        }

        try store.query(result: resultBuilder, querySpec: querySpec, pageIndex: UInt(currentPageIndex?.intValue ?? 0))
        resultBuilder.append("}")

        if store.checkRawJson(resultBuilder as String, fromMethod: #function) {
            // NB: checkRawJson is only called if query succeeded
            return resultBuilder as String
        } else {
            return nil
        }
    }

    /**
    * Run query and resturn NSDictionary (deserialized) representation of the cursor.
    * @return NSDictionary representation of this object.
    */
    public func getDataDeserialized(_ store: SmartStore) throws -> [String: Any]? {
        var result: [String: Any] = [:]
        result["cursorId"] = cursorId ?? ""
        result["currentPageIndex"] = currentPageIndex ?? 0
        result["pageSize"] = pageSize ?? 0
        result["totalPages"] = totalPages ?? 0
        result["totalEntries"] = totalEntries ?? 0

        guard let querySpec = querySpec else {
            throw NSError(domain: "SmartStore", code: -1, userInfo: [NSLocalizedDescriptionKey: "Query spec is nil"])
        }

        let entries = try store.query(using: querySpec, startingFromPageIndex: UInt(currentPageIndex?.intValue ?? 0))
        result["currentPageOrderedEntries"] = entries
        return result
    }
}
