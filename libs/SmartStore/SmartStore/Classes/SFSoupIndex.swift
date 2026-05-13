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

public let kSoupIndexPath = "path"
public let kSoupIndexType = "type"
public let kSoupIndexTypeString = "string"
public let kSoupIndexTypeInteger = "integer"
public let kSoupIndexTypeFloating = "floating"
public let kSoupIndexTypeFullText = "full_text"
public let kSoupIndexTypeJSON1 = "json1"

private let kSoupIndexColumnName = "columnName"

/**
 * Index types filter
 */
public typealias IndexSpecTypeFilterBlock = (SoupIndex) -> Bool

public let kValueExtractedToColumn: IndexSpecTypeFilterBlock = { idx in
    return idx.indexType != kSoupIndexTypeJSON1
}

public let kValueExtractedToFtsColumn: IndexSpecTypeFilterBlock = { idx in
    return idx.indexType == kSoupIndexTypeFullText
}

public let kValueIndexedWithJSONExtract: IndexSpecTypeFilterBlock = { idx in
    return idx.indexType == kSoupIndexTypeJSON1
}

/**
 * Definition of an index on a given soup.
 */
@objc(SFSoupIndex)
@objcMembers
public class SoupIndex: NSObject {

    /**
     * The simple or compound path to the index value, e.g. "Id" or "Account.Id".
     */
    @objc
    public var path: String

    /**
     * The type of index this is (string or date).
     */
    @objc
    public var indexType: String

    /**
     * The name of the column that will store the index.
     */
    @objc
    public private(set) var columnName: String?

    /**
     * The type of data that will be indexed (string or integer).
     */
    @objc
    public var columnType: String? {
        var result = "TEXT"
        if indexType == kSoupIndexTypeString {
            result = "TEXT"
        } else if indexType == kSoupIndexTypeFullText {
            result = "TEXT"
        } else if indexType == kSoupIndexTypeInteger {
            result = "INTEGER"
        } else if indexType == kSoupIndexTypeFloating {
            result = "REAL"
        } else if indexType == kSoupIndexTypeJSON1 {
            return nil
        }
        return result
    }

    /**
     * Designated initializer.
     *
     * @param path The simple or compound path to the index value, e.g. "Id" or "Account.Id".
     * @param type An index type, e.g. kSoupIndexTypeString.
     * @param columnName The SQL column name, or nil.
     */
    @objc(initWithPath:indexType:columnName:)
    public init?(path: String, indexType type: String, columnName: String?) {
        self.path = path
        self.indexType = type
        self.columnName = columnName
        super.init()
    }

    /**
     * Creates an SFSoupIndex based on the given NSDictionary index spec.
     * @param dict the dictionary to use
     * @return Initialized SFSoupIndex object.
     */
    @objc(initWithDictionary:)
    public convenience init?(dictionary dict: [String: Any]) {
        self.init(
            path: dict[kSoupIndexPath] as? String ?? "",
            indexType: dict[kSoupIndexType] as? String ?? "",
            columnName: dict[kSoupIndexColumnName] as? String
        )
    }

    /**
      * Return dictionary for this SFSoupIndex object without column name
      */
    @objc(asDictionary)
    public func asDictionary() -> [String: Any] {
        return asDictionary(withColumnName: false)
    }

    /**
      * Returns a dictionary For this SFSoupIndex object with or without column name
      * @param withColumnName If YES, column name is included in returned dictionary
      */
    @objc(asDictionary:)
    public func asDictionary(withColumnName: Bool) -> [String: Any] {
        var result: [String: Any] = [:]
        result[kSoupIndexPath] = path
        result[kSoupIndexType] = indexType
        if withColumnName, let columnName = columnName {
            result[kSoupIndexColumnName] = columnName
        }
        return result
    }

    /**
      * Returns an array of NSDictionary objects for a given array of soup indexes, using the given column name as the index.
      * @param arrayOfSoupIndexes Array of soup indexes
      * @param withColumnName If YES, column name is included in returned dictionary
      * @return Array of NSDictionary objects
      */
    @objc(asArrayOfDictionaries:withColumnName:)
    public class func asArrayOfDictionaries(_ arrayOfSoupIndexes: [Any], withColumnName: Bool) -> [[String: Any]] {
        var result: [[String: Any]] = []
        for soupIndex in arrayOfSoupIndexes {
            let dict: [String: Any]
            if let index = soupIndex as? SoupIndex {
                dict = index.asDictionary(withColumnName: withColumnName)
            } else if let dictIndex = soupIndex as? [String: Any] {
                dict = dictIndex
            } else {
                continue
            }
            result.append(dict)
        }
        return result
    }

    /**
     * Returns an array of SFSoupIndex objects for a given array of soup indexes.
     * @param arrayOfDictionaries Array of dictionaries
     * @return Array of SFSoupIndex objects
     */
    @objc(asArraySoupIndexes:)
    public class func asArray(_ arrayOfDictionaries: [Any]) -> [SoupIndex] {
        var result: [SoupIndex] = []
        for dict in arrayOfDictionaries {
            if let index = dict as? SoupIndex {
                result.append(index)
            } else if let dictIndex = dict as? [String: Any],
                      let soupIndex = SoupIndex(dictionary: dictIndex) {
                result.append(soupIndex)
            }
        }
        return result
    }

    /**
     Returns a map path to SFSoupIndex
     * @param soupIndexes array of SFSoupIndex objects
     * @return Dictionary that maps paths to soup indexes
     */
    @objc(mapForSoupIndexes:)
    public class func map(forSoupIndexes soupIndexes: [SoupIndex]) -> [String: SoupIndex] {
        var map: [String: SoupIndex] = [:]
        for soupIndex in soupIndexes {
            map[soupIndex.path] = soupIndex
        }
        return map
    }

    /**
     Returns YES if any of the indexes are full text
     * @param soupIndexes array of SFSoupIndex objects
     * @return YES if any of the indexes are full text
     */
    @objc(hasFts:)
    public class func hasFts(_ soupIndexes: [SoupIndex]) -> Bool {
        for soupIndex in soupIndexes {
            if soupIndex.indexType == kSoupIndexTypeFullText {
                return true
            }
        }
        return false
    }

    /**
     Returns YES if any of the indexes are JSON1
     * @param soupIndexes array of SFSoupIndex objects
     * @return YES if any of the indexes are JSON1
     */
    @objc(hasJSON1:)
    public class func hasJSON1(_ soupIndexes: [SoupIndex]) -> Bool {
        for soupIndex in soupIndexes {
            if soupIndex.indexType == kSoupIndexTypeJSON1 {
                return true
            }
        }
        return false
    }

    /**
     Using the path and indexType property values, constructs a string in the format "path--indexType".
     @return String containing the path and indext type, separated by "--".
     */
    @objc(getPathType)
    public func getPathType() -> String {
        return "\(path)--\(indexType)"
    }
}
