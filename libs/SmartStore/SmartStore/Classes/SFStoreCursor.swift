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

/// Defines a cursor into data stored in a soup.
@objc(SFStoreCursor)
@objcMembers
public class StoreCursor: NSObject {

    /// A unique ID for this cursor.
    public private(set) var cursorId: String?

    /// The query spec that generated this cursor.
    public private(set) var querySpec: QuerySpec?

    /// The list of current page entries, ordered as requested in the querySpec.
    public private(set) var currentPageOrderedEntries: [Any]?

    /// The maximum number of entries returned per page.
    public private(set) var pageSize: NSNumber?

    /// The total number of pages of results available.
    public private(set) var totalPages: NSNumber?

    /// The total number of entries.
    public private(set) var totalEntries: NSNumber?

    /// The current page index among totalPages available.
    public var currentPageIndex: NSNumber?

    /// Initializes a new instance of a soup cursor.
    ///
    /// - Parameters:
    ///   - store: The store where the soup is contained.
    ///   - querySpec: The query used to retrieve the data.
    @objc
    public init(store: SmartStore, querySpec: QuerySpec) {
        super.init()
        self.querySpec = querySpec
        self.cursorId = String(format: "0x%lx", UInt(bitPattern: ObjectIdentifier(self).hashValue))
        self.pageSize = NSNumber(value: querySpec.pageSize)

        let totalEntriesCount: UInt = (try? store.count(using: querySpec))?.uintValue ?? 0
        let totalPagesFloat = Float(totalEntriesCount) / Float(querySpec.pageSize)
        var totalPagesCount = UInt(ceilf(totalPagesFloat))
        if totalEntriesCount == 0 {
            totalPagesCount = 0
        }

        self.totalPages = NSNumber(value: totalPagesCount)
        self.totalEntries = NSNumber(value: totalEntriesCount)
        self.currentPageIndex = NSNumber(value: 0)
    }

    deinit {
        if cursorId != nil {
            close()
        }
    }

    /// Close this cursor when finished operating on it.
    @objc
    public func close() {
        SmartStoreLogger.v(StoreCursor.self, message: "closing cursor id: \(cursorId ?? "nil")")
        cursorId = nil
        querySpec = nil
        currentPageIndex = nil
        pageSize = nil
        totalPages = nil
    }

    /// Run query and return JSON serialized representation of the cursor.
    ///
    /// - Parameter store: The store to query against.
    /// - Throws: An error if the query fails.
    /// - Returns: JSON serialized representation of this cursor, or nil on failure.
    @objc
    public func getDataSerialized(_ store: SmartStore) throws -> String {
        var resultBuilder = "{"
        resultBuilder += "\"cursorId\":\"\(cursorId ?? "")\", "
        resultBuilder += "\"currentPageIndex\":\(currentPageIndex ?? 0), "
        resultBuilder += "\"pageSize\":\(pageSize ?? 0), "
        resultBuilder += "\"totalPages\":\(totalPages ?? 0), "
        resultBuilder += "\"totalEntries\":\(totalEntries ?? 0), "
        resultBuilder += "\"currentPageOrderedEntries\":"

        guard let spec = querySpec else {
            return ""
        }

        var mutableResult = NSMutableString(string: resultBuilder)
        try store.queryAsString(mutableResult, querySpec: spec, pageIndex: UInt(truncating: currentPageIndex ?? 0))
        mutableResult.append("}")

        let finalString = mutableResult as String
        if store.checkRawJson(finalString, fromMethod: #function) {
            return finalString
        } else {
            throw NSError(domain: SmartStoreConstants.errorDomain, code: 999, userInfo: [NSLocalizedDescriptionKey: "Failed to serialize cursor data"])
        }
    }

    /// Run query and return NSDictionary (deserialized) representation of the cursor.
    ///
    /// - Parameter store: The store to query against.
    /// - Throws: An error if the query fails.
    /// - Returns: Dictionary representation of this cursor, or nil on failure.
    @objc
    public func getDataDeserialized(_ store: SmartStore) throws -> [String: Any] {
        var result: [String: Any] = [:]
        result["cursorId"] = cursorId ?? ""
        result["currentPageIndex"] = currentPageIndex ?? 0
        result["pageSize"] = pageSize ?? 0
        result["totalPages"] = totalPages ?? 0
        result["totalEntries"] = totalEntries ?? 0

        guard let spec = querySpec else {
            return result
        }

        let entries = try store.query(using: spec, startingFromPageIndex: UInt(truncating: currentPageIndex ?? 0))
        result["currentPageOrderedEntries"] = entries
        return result
    }
}
