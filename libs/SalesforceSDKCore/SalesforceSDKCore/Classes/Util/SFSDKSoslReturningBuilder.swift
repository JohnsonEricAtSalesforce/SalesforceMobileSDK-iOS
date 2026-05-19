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

/// A builder to help create a SOSL returning statement.
@objc(SFSDKSoslReturningBuilder)
@objcMembers public class SFSDKSoslReturningBuilder: NSObject {

    private var properties = NSMutableDictionary()

    /// Returns the object name for this builder.
    @objc public var objectName: String {
        return properties["objectName"] as? String ?? ""
    }

    // MARK: - Factory Methods

    /// Creates a new returning builder with the given object name.
    @objc public class func withObjectName(_ name: String) -> SFSDKSoslReturningBuilder {
        let builder = SFSDKSoslReturningBuilder()
        builder.setObjectName(name)
        builder.limit(0)
        return builder
    }

    // MARK: - Builder Methods

    @discardableResult
    private func setObjectName(_ name: String) -> SFSDKSoslReturningBuilder {
        properties["objectName"] = name
        return self
    }

    @discardableResult
    @objc public func fields(_ fields: String) -> SFSDKSoslReturningBuilder {
        properties["fields"] = fields
        return self
    }

    @discardableResult
    @objc public func whereClause(_ whereClause: String) -> SFSDKSoslReturningBuilder {
        properties["whereClause"] = whereClause
        return self
    }

    @discardableResult
    @objc public func withNetwork(_ networkId: String) -> SFSDKSoslReturningBuilder {
        properties["withNetwork"] = networkId
        return self
    }

    @discardableResult
    @objc public func orderBy(_ orderBy: String) -> SFSDKSoslReturningBuilder {
        properties["orderBy"] = orderBy
        return self
    }

    @discardableResult
    @objc public func limit(_ limit: Int) -> SFSDKSoslReturningBuilder {
        properties["limit"] = NSNumber(value: limit)
        return self
    }

    // MARK: - Build

    @objc public func build() -> String? {
        guard let objName = properties["objectName"] as? String, !objName.isEmpty else {
            return nil
        }
        var query = " "
        query += objName
        if let fields = properties["fields"] as? String, !fields.isEmpty {
            query += "(\(fields)"
            if let whereClause = properties["whereClause"] as? String, !whereClause.isEmpty {
                query += " where "
                query += whereClause
            }
            if let orderBy = properties["orderBy"] as? String, !orderBy.isEmpty {
                query += " order by "
                query += orderBy
            }
            if let withNetwork = properties["withNetwork"] as? String, !withNetwork.isEmpty {
                query += " with network = "
                query += withNetwork
            }
            if let limit = properties["limit"] as? NSNumber, limit.intValue != 0 {
                query += " limit "
                query += "\(limit.intValue)"
            }
            query += ")"
        }
        return query
    }
}
