// Copyright (c) 2014-present, salesforce.com, inc. All rights reserved.
//
// Redistribution and use of this software in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
// * Redistributions of source code must retain the above copyright notice, this list of conditions
// and the following disclaimer.
// * Redistributions in binary form must reproduce the above copyright notice, this list of
// conditions and the following disclaimer in the documentation and/or other materials provided
// with the distribution.
// * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
// endorse or promote products derived from this software without specific prior written
// permission of salesforce.com, inc.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
// IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
// FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
// CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
// WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
// WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import Foundation

/// A builder to help create a SOSL statement.
@objc(SFSDKSoslBuilder)
@objcMembers public class SFSDKSoslBuilder: NSObject {

    private var properties = NSMutableDictionary()
    private var returningSpecs = NSMutableArray()

    // MARK: - Factory Methods

    /// Creates a new builder with the given search term.
    @objc public class func withSearchTerm(_ searchTerm: String) -> SFSDKSoslBuilder {
        let builder = SFSDKSoslBuilder()
        builder.setSearchTerm(searchTerm)
        builder.limit(0)
        return builder
    }

    // MARK: - Builder Methods

    @discardableResult
    private func setSearchTerm(_ searchTerm: String?) -> SFSDKSoslBuilder {
        var searchValue = searchTerm ?? ""
        if !searchValue.isEmpty {
            searchValue = searchValue.replacingOccurrences(of: "\\", with: "\\\\")
            searchValue = searchValue.replacingOccurrences(of: "+", with: "\\+")
            searchValue = searchValue.replacingOccurrences(of: "^", with: "\\^")
            searchValue = searchValue.replacingOccurrences(of: "~", with: "\\~")
            searchValue = searchValue.replacingOccurrences(of: "'", with: "\\'")
            searchValue = searchValue.replacingOccurrences(of: "-", with: "\\-")
            searchValue = searchValue.replacingOccurrences(of: "[", with: "\\[")
            searchValue = searchValue.replacingOccurrences(of: "]", with: "\\]")
            searchValue = searchValue.replacingOccurrences(of: "{", with: "\\{")
            searchValue = searchValue.replacingOccurrences(of: "}", with: "\\}")
            searchValue = searchValue.replacingOccurrences(of: "(", with: "\\(")
            searchValue = searchValue.replacingOccurrences(of: ")", with: "\\)")
            searchValue = searchValue.replacingOccurrences(of: "&", with: "\\&")
            searchValue = searchValue.replacingOccurrences(of: ":", with: "\\:")
            searchValue = searchValue.replacingOccurrences(of: "!", with: "\\!")
        }
        properties["searchTerm"] = searchValue
        return self
    }

    @discardableResult
    @objc public func searchGroup(_ searchGroup: String) -> SFSDKSoslBuilder {
        properties["searchGroup"] = searchGroup
        return self
    }

    @discardableResult
    @objc public func returning(_ returningSpec: SFSDKSoslReturningBuilder) -> SFSDKSoslBuilder {
        returningSpecs.add(returningSpec)
        return self
    }

    @discardableResult
    @objc public func divisionFilter(_ divisionFilter: String) -> SFSDKSoslBuilder {
        properties["divisionFilter"] = divisionFilter
        return self
    }

    @discardableResult
    @objc public func dataCategory(_ dataCategory: String) -> SFSDKSoslBuilder {
        properties["dataCategory"] = dataCategory
        return self
    }

    @discardableResult
    @objc public func limit(_ limit: Int) -> SFSDKSoslBuilder {
        properties["limit"] = NSNumber(value: limit)
        return self
    }

    // MARK: - Encoded Queries

    @objc public func encodeAndBuild() -> String? {
        return build()?.sfsdk_stringByURLEncoding()
    }

    @objc public func encodeAndBuild(withPath path: String) -> String? {
        guard let encoded = encodeAndBuild() else { return nil }
        if path.hasSuffix("/") {
            return "\(path)search/?q=\(encoded)"
        }
        return "\(path)/search/?q=\(encoded)"
    }

    // MARK: - Raw Queries

    @objc public func build(withPath path: String) -> String? {
        guard let built = build() else { return nil }
        if path.hasSuffix("/") {
            return "\(path)search/?q=\(built)"
        }
        return "\(path)/search/?q=\(built)"
    }

    @objc public func build() -> String? {
        guard let searchTerm = properties["searchTerm"] as? String, !searchTerm.isEmpty else {
            return nil
        }
        var query = "find {\(searchTerm)}"
        if let searchGroup = properties["searchGroup"] as? String, !searchGroup.isEmpty {
            query += " in "
            query += searchGroup
        }
        if returningSpecs.count > 0 {
            query += " returning "
            if let first = returningSpecs[0] as? SFSDKSoslReturningBuilder, let built = first.build() {
                query += built
            }
            for i in 1..<returningSpecs.count {
                if let spec = returningSpecs[i] as? SFSDKSoslReturningBuilder, let built = spec.build() {
                    query += ", "
                    query += built
                }
            }
        }
        if let divisionFilter = properties["divisionFilter"] as? String, !divisionFilter.isEmpty {
            query += " with "
            query += divisionFilter
        }
        if let dataCategory = properties["dataCategory"] as? String, !dataCategory.isEmpty {
            query += " with data category "
            query += dataCategory
        }
        if let limit = properties["limit"] as? NSNumber, limit.intValue != 0 {
            query += " limit "
            query += "\(limit.intValue)"
        }
        return query
    }
}
