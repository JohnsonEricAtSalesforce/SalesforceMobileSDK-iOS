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

// MARK: - Constants

/// Container for SoupIndex string constants, exposed to Objective-C.
@objc(SFSoupIndexConstants)
@objcMembers
public class SoupIndexConstants: NSObject {
    @objc public static let kSoupIndexPath: String = "path"
    @objc public static let kSoupIndexType: String = "type"
    @objc public static let kSoupIndexTypeString: String = "string"
    @objc public static let kSoupIndexTypeInteger: String = "integer"
    @objc public static let kSoupIndexTypeFloating: String = "floating"
    @objc public static let kSoupIndexTypeFullText: String = "full_text"
    @objc public static let kSoupIndexTypeJSON1: String = "json1"

    /// Filter that matches indexes whose values are extracted to a column (non-JSON1).
    @objc public static let kValueExtractedToColumn: @convention(block) (SoupIndex) -> Bool = { idx in
        return idx.indexType != kSoupIndexTypeJSON1
    }

    /// Filter that matches indexes whose values are extracted to a full-text column.
    @objc public static let kValueExtractedToFtsColumn: @convention(block) (SoupIndex) -> Bool = { idx in
        return idx.indexType == kSoupIndexTypeFullText
    }

    /// Filter that matches indexes using JSON extract.
    @objc public static let kValueIndexedWithJSONExtract: @convention(block) (SoupIndex) -> Bool = { idx in
        return idx.indexType == kSoupIndexTypeJSON1
    }
}

// Top-level aliases for Swift callers
public let kSoupIndexPath = SoupIndexConstants.kSoupIndexPath
public let kSoupIndexType = SoupIndexConstants.kSoupIndexType
public let kSoupIndexTypeString = SoupIndexConstants.kSoupIndexTypeString
public let kSoupIndexTypeInteger = SoupIndexConstants.kSoupIndexTypeInteger
public let kSoupIndexTypeFloating = SoupIndexConstants.kSoupIndexTypeFloating
public let kSoupIndexTypeFullText = SoupIndexConstants.kSoupIndexTypeFullText
public let kSoupIndexTypeJSON1 = SoupIndexConstants.kSoupIndexTypeJSON1
public let kValueExtractedToColumn = SoupIndexConstants.kValueExtractedToColumn
public let kValueExtractedToFtsColumn = SoupIndexConstants.kValueExtractedToFtsColumn
public let kValueIndexedWithJSONExtract = SoupIndexConstants.kValueIndexedWithJSONExtract

private let kSoupIndexColumnName: String = "columnName"

// MARK: - Index Spec Type Filter

/// Closure type for filtering index specs by type.
public typealias SFIndexSpecTypeFilterBlock = (SoupIndex) -> Bool

// MARK: - SoupIndex

/// Definition of an index on a given soup.
@objc(SFSoupIndex)
@objcMembers
public class SoupIndex: NSObject {

    /// The simple or compound path to the index value, e.g. "Id" or "Account.Id".
    public var path: String

    /// The type of index this is (string, integer, floating, full_text, or json1).
    public var indexType: String

    /// The name of the column that will store the index.
    public private(set) var columnName: String

    /// The type of data that will be indexed (TEXT, INTEGER, REAL, or nil for JSON1).
    public var columnType: String? {
        switch indexType {
        case kSoupIndexTypeString, kSoupIndexTypeFullText:
            return "TEXT"
        case kSoupIndexTypeInteger:
            return "INTEGER"
        case kSoupIndexTypeFloating:
            return "REAL"
        case kSoupIndexTypeJSON1:
            return nil
        default:
            return "TEXT"
        }
    }

    /// Designated initializer.
    ///
    /// - Parameters:
    ///   - path: The simple or compound path to the index value, e.g. "Id" or "Account.Id".
    ///   - indexType: An index type, e.g. kSoupIndexTypeString.
    ///   - columnName: The SQL column name, or nil.
    @objc
    public init?(path: String, indexType: String, columnName: String?) {
        self.path = path
        self.indexType = indexType
        self.columnName = columnName ?? ""
        super.init()
    }

    /// Creates a SoupIndex based on the given dictionary index spec.
    ///
    /// - Parameter dict: The dictionary to use.
    @objc
    public init(dictionary dict: [String: Any]) {
        self.path = dict[kSoupIndexPath] as? String ?? ""
        self.indexType = dict[kSoupIndexType] as? String ?? ""
        self.columnName = dict[kSoupIndexColumnName] as? String ?? ""
        super.init()
    }

    // MARK: - Converting to Dictionary

    /// Returns dictionary for this SoupIndex object without column name.
    @objc
    public func asDictionary() -> [String: Any] {
        return asDictionary(withColumnName: false)
    }

    /// Returns a dictionary for this SoupIndex object with or without column name.
    ///
    /// - Parameter withColumnName: If true, column name is included in returned dictionary.
    @objc(asDictionary:)
    public func asDictionary(withColumnName: Bool) -> [String: Any] {
        var result: [String: Any] = [
            kSoupIndexPath: path,
            kSoupIndexType: indexType
        ]
        if withColumnName && !columnName.isEmpty {
            result[kSoupIndexColumnName] = columnName
        }
        return result
    }

    /// Returns an array of dictionaries for a given array of soup indexes.
    ///
    /// - Parameters:
    ///   - arrayOfSoupIndexes: Array of soup indexes.
    ///   - withColumnName: If true, column name is included in returned dictionaries.
    /// - Returns: Array of dictionary objects.
    @objc
    public class func asArrayOfDictionaries(_ arrayOfSoupIndexes: [Any], withColumnName: Bool) -> [[String: Any]] {
        var result: [[String: Any]] = []
        for item in arrayOfSoupIndexes {
            if let soupIndex = item as? SoupIndex {
                result.append(soupIndex.asDictionary(withColumnName: withColumnName))
            } else if let dict = item as? [String: Any] {
                result.append(dict)
            }
        }
        return result
    }

    /// Returns an array of SoupIndex objects for a given array of dictionaries.
    ///
    /// - Parameter arrayOfDictionaries: Array of dictionaries.
    /// - Returns: Array of SoupIndex objects.
    @objc
    public class func asArraySoupIndexes(_ arrayOfDictionaries: [Any]) -> [SoupIndex] {
        var result: [SoupIndex] = []
        for item in arrayOfDictionaries {
            if let soupIndex = item as? SoupIndex {
                result.append(soupIndex)
            } else if let dict = item as? [String: Any] {
                result.append(SoupIndex(dictionary: dict))
            }
        }
        return result
    }

    /// Returns a map from path to SoupIndex.
    ///
    /// - Parameter soupIndexes: Array of SoupIndex objects.
    /// - Returns: Dictionary that maps paths to soup indexes.
    @objc
    public class func map(forSoupIndexes soupIndexes: [SoupIndex]) -> [String: SoupIndex] {
        var map: [String: SoupIndex] = [:]
        for soupIndex in soupIndexes {
            map[soupIndex.path] = soupIndex
        }
        return map
    }

    /// Returns true if any of the indexes are full text.
    ///
    /// - Parameter soupIndexes: Array of SoupIndex objects.
    /// - Returns: true if any of the indexes are full text.
    @objc
    public class func hasFts(_ soupIndexes: [SoupIndex]) -> Bool {
        return soupIndexes.contains { $0.indexType == kSoupIndexTypeFullText }
    }

    /// Returns true if any of the indexes are JSON1.
    ///
    /// - Parameter soupIndexes: Array of SoupIndex objects.
    /// - Returns: true if any of the indexes are JSON1.
    @objc
    public class func hasJSON1(_ soupIndexes: [SoupIndex]) -> Bool {
        return soupIndexes.contains { $0.indexType == kSoupIndexTypeJSON1 }
    }

    /// Constructs a string in the format "path--indexType".
    @objc
    public func getPathType() -> String {
        return "\(path)--\(indexType)"
    }
}
