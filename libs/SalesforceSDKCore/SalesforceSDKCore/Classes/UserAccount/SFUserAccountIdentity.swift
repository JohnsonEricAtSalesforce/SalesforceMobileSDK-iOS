/*
 Copyright (c) 2014-present, salesforce.com, inc. All rights reserved.

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

private let kUserAccountIdentityUserIdKey = "userIdKey"
private let kUserAccountIdentityOrgIdKey = "orgIdKey"

/**
 Represents the unique identity of a given user account.
 */
@objc(SFUserAccountIdentity)
public class UserAccountIdentity: NSObject, NSSecureCoding, NSCopying {

    /**
     The user ID associated with the account.
     */
    @objc public internal(set) var userId: String

    /**
     The organization ID associated with the account.
     */
    @objc public internal(set) var orgId: String

    // MARK: - NSSecureCoding

    @objc public static var supportsSecureCoding: Bool {
        return true
    }

    // MARK: - Initialization

    /**
     Convenience method to return a new account identity with the given User ID and Org ID.
     - Parameter userId: The user ID associated with the identity.
     - Parameter orgId: The org ID associated with the identity.
     - Returns: An account identity representing the given User ID and Org ID.
     */
    @objc(identityWithUserId:orgId:)
    public static func identity(userId: String, orgId: String) -> UserAccountIdentity {
        return UserAccountIdentity(userId: userId, orgId: orgId)
    }

    /**
     Creates a new account identity object with the given user ID and org ID.
     - Parameter userId: The user ID associated with the identity.
     - Parameter orgId: The org ID associated with the identity.
     */
    @objc(initWithUserId:orgId:)
    public init(userId: String, orgId: String) {
        self.userId = userId
        self.orgId = orgId
        super.init()
    }

    // MARK: - NSCoding

    @objc public required init?(coder aDecoder: NSCoder) {
        guard let userId = aDecoder.decodeObject(of: NSString.self, forKey: kUserAccountIdentityUserIdKey) as String?,
              let orgId = aDecoder.decodeObject(of: NSString.self, forKey: kUserAccountIdentityOrgIdKey) as String? else {
            return nil
        }

        self.userId = userId
        self.orgId = orgId
        super.init()
    }

    @objc public func encode(with aCoder: NSCoder) {
        aCoder.encode(self.userId, forKey: kUserAccountIdentityUserIdKey)
        aCoder.encode(self.orgId, forKey: kUserAccountIdentityOrgIdKey)
    }

    // MARK: - NSCopying

    @objc public func copy(with zone: NSZone? = nil) -> Any {
        return UserAccountIdentity(userId: self.userId, orgId: self.orgId)
    }

    // MARK: - Equality

    public override func isEqual(_ object: Any?) -> Bool {
        guard let object = object else {
            return false
        }

        if self === object as AnyObject {
            return true
        }

        guard let otherIdentity = object as? UserAccountIdentity else {
            return false
        }

        let userIdsEqual = otherIdentity.userId.sfsdk_isEqual(toEntityId: self.userId)
        let orgIdsEqual = otherIdentity.orgId.sfsdk_isEqual(toEntityId: self.orgId)
        return userIdsEqual && orgIdsEqual
    }

    public override var hash: Int {
        return "\(self.userId)_\(self.orgId)".hash
    }

    // MARK: - Comparison

    /**
     Compares this identity with another.  Useful for [NSArray sortedArrayUsingSelector:].
     - Parameter otherIdentity: The other identity to compare to this one.
     - Returns: NSOrderedAscending if other is greater, NSOrderedDescending if other is less,
     NSOrderedSame if they're equal.
     */
    @objc(compare:)
    public func compare(_ otherIdentity: UserAccountIdentity) -> ComparisonResult {
        let thisStringToCompare = "\(self.orgId.sfsdk_entityId18 ?? self.orgId)_\(self.userId.sfsdk_entityId18 ?? self.userId)"
        let otherStringToCompare = "\(otherIdentity.orgId.sfsdk_entityId18 ?? otherIdentity.orgId)_\(otherIdentity.userId.sfsdk_entityId18 ?? otherIdentity.userId)"
        return thisStringToCompare.localizedCompare(otherStringToCompare)
    }

    /**
     Compares the user identifying information of the account identity with that in the credentials.
     - Parameter credentials: The OAuthCredentials to compare against
     - Returns: Whether or not the user contained is the same
     */
    @objc(matchesCredentials:)
    public func matches(credentials: SFOAuthCredentials) -> Bool {
        let thisUserId18 = self.userId.sfsdk_entityId18 ?? ""
        let thisOrgId18 = self.orgId.sfsdk_entityId18 ?? ""
        let credUserId18 = credentials.userId?.sfsdk_entityId18 ?? ""
        let credOrgId18 = credentials.organizationId?.sfsdk_entityId18 ?? ""

        return thisUserId18 == credUserId18 && thisOrgId18 == credOrgId18
    }

    // MARK: - Description

    public override var description: String {
        return "<\(type(of: self)):\(Unmanaged.passUnretained(self).toOpaque()) userId:\(self.userId) orgId:\(self.orgId)>"
    }
}
