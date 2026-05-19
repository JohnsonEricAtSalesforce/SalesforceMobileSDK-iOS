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

private let kUserAccountIdentityUserIdKey = "userIdKey"
private let kUserAccountIdentityOrgIdKey = "orgIdKey"

/// Represents the unique identity of a given user account.
@objc(SFUserAccountIdentity)
@objcMembers public class UserAccountIdentity: NSObject, NSSecureCoding, NSCopying {

    // MARK: - NSSecureCoding

    public static var supportsSecureCoding: Bool { true }

    // MARK: - Properties

    /// The user ID associated with the account.
    @objc public var userId: String

    /// The organization ID associated with the account.
    @objc public var orgId: String

    // MARK: - Initialization

    /// Creates a new account identity object with the given user ID and org ID.
    @objc public init(userId: String, orgId: String) {
        self.userId = userId
        self.orgId = orgId
        super.init()
    }

    /// Convenience method to return a new account identity with the given User ID and Org ID.
    @objc public class func identity(userId: String, orgId: String) -> UserAccountIdentity {
        return UserAccountIdentity(userId: userId, orgId: orgId)
    }

    // MARK: - NSSecureCoding

    public required init?(coder aDecoder: NSCoder) {
        userId = aDecoder.decodeObject(of: NSString.self, forKey: kUserAccountIdentityUserIdKey) as String? ?? ""
        orgId = aDecoder.decodeObject(of: NSString.self, forKey: kUserAccountIdentityOrgIdKey) as String? ?? ""
        super.init()
    }

    public func encode(with aCoder: NSCoder) {
        aCoder.encode(userId, forKey: kUserAccountIdentityUserIdKey)
        aCoder.encode(orgId, forKey: kUserAccountIdentityOrgIdKey)
    }

    // MARK: - NSCopying

    public func copy(with zone: NSZone? = nil) -> Any {
        return UserAccountIdentity(userId: userId, orgId: orgId)
    }

    // MARK: - Equality & Hashing

    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? UserAccountIdentity else { return false }
        if self === other { return true }
        let userIdsEqual = (userId as NSString).sfsdk_isEqual(toEntityId: other.userId)
        let orgIdsEqual = (orgId as NSString).sfsdk_isEqual(toEntityId: other.orgId)
        return userIdsEqual && orgIdsEqual
    }

    public override var hash: Int {
        return "\(userId)_\(orgId)".hash
    }

    // MARK: - Comparison

    /// Compares this identity with another. Useful for sorting.
    @objc public func compare(_ otherIdentity: UserAccountIdentity?) -> ComparisonResult {
        guard let other = otherIdentity else { return .orderedAscending }
        let thisString = "\((orgId as NSString).sfsdk_entityId18() ?? orgId)_\((userId as NSString).sfsdk_entityId18() ?? userId)"
        let otherString = "\((other.orgId as NSString).sfsdk_entityId18() ?? other.orgId)_\((other.userId as NSString).sfsdk_entityId18() ?? other.userId)"
        return thisString.localizedCompare(otherString)
    }

    /// Compares the user identifying information of the account identity with that in the credentials.
    @objc public func matchesCredentials(_ credentials: OAuthCredentials) -> Bool {
        let selfUserId18 = (userId as NSString).sfsdk_entityId18() ?? userId
        let selfOrgId18 = (orgId as NSString).sfsdk_entityId18() ?? orgId
        let credUserId18 = ((credentials.userId ?? "") as NSString).sfsdk_entityId18() ?? (credentials.userId ?? "")
        let credOrgId18 = ((credentials.organizationId ?? "") as NSString).sfsdk_entityId18() ?? (credentials.organizationId ?? "")
        return selfUserId18 == credUserId18 && selfOrgId18 == credOrgId18
    }

    // MARK: - Description

    public override var description: String {
        return "<\(type(of: self)):\(Unmanaged.passUnretained(self).toOpaque()) userId:\(userId) orgId:\(orgId)>"
    }
}
