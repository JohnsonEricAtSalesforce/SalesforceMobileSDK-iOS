/*
 Copyright (c) 2013-present, salesforce.com, inc. All rights reserved.

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
import FMDB

// MARK: - SmartSqlHelper

/// Utility helper for Smart SQL to SQL conversions.
@objc(SFSmartSqlHelper)
@objcMembers
public class SmartSqlHelper: NSObject {

    // MARK: - Regex Patterns

    private static let noStringsOrFullStrings = "^([^']|'[^']*')*"

    private static let insideQuotedStringRegexp: NSRegularExpression = {
        return try! NSRegularExpression(pattern: noStringsOrFullStrings + "'[^']*", options: [])
    }()

    private static let insideQuotedStringForFTSMatchPredicateRegexp: NSRegularExpression = {
        return try! NSRegularExpression(pattern: noStringsOrFullStrings + "MATCH[ ]+'[^']*", options: [])
    }()

    private static let tableDotJsonExtractRegexp: NSRegularExpression = {
        return try! NSRegularExpression(pattern: "(\\w+)\\.json_extract\\(soup", options: [])
    }()

    private static let soupPathRegexp: NSRegularExpression = {
        return try! NSRegularExpression(pattern: "\\{([^}]+)\\}", options: [])
    }()

    // MARK: - Singleton

    /// Gets the shared instance of the Smart SQL helper.
    @objc(sharedInstance)
    public static let shared: SmartSqlHelper = SmartSqlHelper()

    private override init() {
        super.init()
    }

    // MARK: - Conversion

    /// Converts a Smart SQL query to SQL.
    @objc(convertSmartSql:withStore:withDb:)
    public func convertSmartSql(_ smartSql: String, with store: SmartStore, db: FMDatabase) -> String? {
        // Only SELECTs are supported
        let trimmed = smartSql.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if trimmed.hasPrefix("insert") || trimmed.hasPrefix("update") || trimmed.hasPrefix("delete") {
            SmartStoreLogger.w(SmartSqlHelper.self, message: "convertSmartSql failed: Only SELECT are supported")
            return nil
        }

        // Replacing {soupName} and {soupName:path}
        let sql = NSMutableString()

        let matches = SmartSqlHelper.soupPathRegexp.matches(in: smartSql, options: [], range: NSRange(location: 0, length: smartSql.utf16.count))

        var lastPosition = 0

        for matchResult in matches {
            let matchRange = matchResult.range
            let fullMatch = (smartSql as NSString).substring(with: matchRange)
            let match = (smartSql as NSString).substring(with: matchResult.range(at: 1))
            let position = matchRange.location

            let beforeStr = (smartSql as NSString).substring(to: position)
            let searchedRange = NSRange(location: 0, length: (beforeStr as NSString).length)

            let isInsideQuotedString = NSEqualRanges(searchedRange,
                SmartSqlHelper.insideQuotedStringRegexp.rangeOfFirstMatch(in: beforeStr, options: [], range: searchedRange))
            let isInsideQuotedStringForFTSMatchPredicate = NSEqualRanges(searchedRange,
                SmartSqlHelper.insideQuotedStringForFTSMatchPredicateRegexp.rangeOfFirstMatch(in: beforeStr, options: [], range: searchedRange))

            if isInsideQuotedString && !isInsideQuotedStringForFTSMatchPredicate {
                continue
            }

            let parts = match.components(separatedBy: ":")
            let soupName = parts[0]
            guard let soupTableName = store.tableNameForSoup(soupName, with: db) else {
                SmartStoreLogger.w(SmartSqlHelper.self, message: "convertSmartSql failed: Invalid soup name:\(soupName)")
                return nil
            }

            let tableQualified = position > 0 && (smartSql as NSString).character(at: position - 1) == Character(".").asciiValue.map(UInt16.init) ?? UInt16(46)
            let tableQualifier = tableQualified ? "" : "\(soupTableName)."

            // Appending the part before we have not used
            sql.append((smartSql as NSString).substring(with: NSRange(location: lastPosition, length: position - lastPosition)))
            lastPosition = position + matchRange.length

            // {soupName}
            if parts.count == 1 {
                sql.append(soupTableName)
            } else if parts.count == 2 {
                let path = parts[1]
                // {soupName:_soup}
                if path == "_soup" {
                    sql.append(tableQualifier)
                    sql.append("soup")
                }
                // {soupName:_soupEntryId}
                else if path == "_soupEntryId" {
                    sql.append(tableQualifier)
                    sql.append("id")
                }
                // {soupName:_soupCreatedDate}
                else if path == "_soupCreatedDate" {
                    sql.append(tableQualifier)
                    sql.append("created")
                }
                // {soupName:_soupLastModifiedDate}
                else if path == "_soupLastModifiedDate" {
                    sql.append(tableQualifier)
                    sql.append("lastModified")
                }
                // {soupName:path}
                else {
                    var columnName: String
                    let indexed = (try? store.hasIndex(forPath: path, inSoup: soupName, with: db)) ?? false
                    if !indexed {
                        // Thanks to the json1 extension we can query the data even if it is not indexed
                        columnName = "json_extract(soup, '$.\(path)')"
                    } else {
                        guard let name = try? store.columnName(forPath: path, inSoup: soupName, with: db) else {
                            SmartStoreLogger.w(SmartSqlHelper.self, message: "convertSmartSql failed: Invalid path:\(path)")
                            return nil
                        }
                        columnName = name
                    }
                    sql.append(columnName)
                }
            } else if parts.count > 2 {
                SmartStoreLogger.w(SmartSqlHelper.self, message: "convertSmartSql failed: Invalid soup/path reference: \(fullMatch) at character: \(position)")
                return nil
            }
        }

        // Appending the tail
        sql.append((smartSql as NSString).substring(from: lastPosition))

        // With json1 support, the column name could be an expression of the form json_extract(soup, '$.x.y.z')
        // We can't have TABLE_x.json_extract(soup, ...) or table_alias.json_extract(soup, ...) in the sql query
        // Instead we should have json_extract(TABLE_x.soup, ...)
        SmartSqlHelper.tableDotJsonExtractRegexp.replaceMatches(in: sql, options: [], range: NSRange(location: 0, length: sql.length), withTemplate: "json_extract($1.soup")

        return sql as String
    }
}
