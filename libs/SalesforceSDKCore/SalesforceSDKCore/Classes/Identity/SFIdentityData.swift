// Copyright (c) 2012-present, salesforce.com, inc. All rights reserved.
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

// JSON keys
private let kSFIdentityIdUrlKey = "id"
private let kSFIdentityAssertedUserKey = "asserted_user"
private let kSFIdentityUserIdKey = "user_id"
private let kSFIdentityOrgIdKey = "organization_id"
private let kSFIdentityUsernameKey = "username"
private let kSFIdentityNicknameKey = "nick_name"
private let kSFIdentityDisplayNameKey = "display_name"
private let kSFIdentityEmailKey = "email"
private let kSFIdentityFirstNameKey = "first_name"
private let kSFIdentityLastNameKey = "last_name"
private let kSFIdentityPhotosKey = "photos"
private let kSFIdentityPictureUrlKey = "picture"
private let kSFIdentityThumbnailUrlKey = "thumbnail"
private let kSFIdentityUrlsKey = "urls"
private let kSFIdentityEnterpriseSoapUrlKey = "enterprise"
private let kSFIdentityMetadataSoapUrlKey = "metadata"
private let kSFIdentityPartnerSoapUrlKey = "partner"
private let kSFIdentityRestUrlKey = "rest"
private let kSFIdentityRestSObjectsUrlKey = "sobjects"
private let kSFIdentityRestSearchUrlKey = "search"
private let kSFIdentityRestQueryUrlKey = "query"
private let kSFIdentityRestRecentUrlKey = "recent"
private let kSFIdentityProfileUrlKey = "profile"
private let kSFIdentityChatterFeedsUrlKey = "feeds"
private let kSFIdentityChatterGroupsUrlKey = "groups"
private let kSFIdentityChatterUsersUrlKey = "users"
private let kSFIdentityChatterFeedItemsUrlKey = "feed_items"
private let kSFIdentityIsActiveKey = "active"
private let kSFIdentityUserTypeKey = "user_type"
private let kSFIdentityLanguageKey = "language"
private let kSFIdentityLocaleKey = "locale"
private let kSFIdentityUtcOffsetKey = "utcOffset"
private let kSFIdentityMobilePolicyKey = "mobile_policy"
private let kSFIdentityMobileAppPinLengthKey = "pin_length"
private let kSFIdentityMobileAppScreenLockTimeoutKey = "screen_lock"
private let kSFIdentityCustomAttributesKey = "custom_attributes"
private let kSFIdentityCustomPermissionsKey = "custom_permissions"
private let kSFIdentityLastModifiedDateKey = "last_modified_date"
private let kSFNativeLoginKey = "native_login"
private let kSFIdentityDateFormatString = "yyyy-MM-dd'T'HH:mm:ssZZZ"
private let kIdJsonDictKey = "dictRepresentation"

/// The data structure for the identity data retrieved from the Salesforce service.
@objc(SFIdentityData)
@objcMembers
public class SFIdentityData: NSObject, NSSecureCoding {

    public static var supportsSecureCoding: Bool { return true }

    /// The NSDictionary representation of this identity data.
    public var dictRepresentation: NSDictionary

    /// The ID URL.
    public var idUrl: URL {
        return URL(string: dictRepresentation[kSFIdentityIdUrlKey] as? String ?? "") ?? URL(string: "https://invalid")!
    }

    public var assertedUser: Bool {
        guard let value = dictRepresentation.sfsdk_nonNullObject(forKey: kSFIdentityAssertedUserKey) else { return false }
        return (value as? NSNumber)?.boolValue ?? false
    }

    public var userId: String { return dictRepresentation[kSFIdentityUserIdKey] as? String ?? "" }
    public var orgId: String { return dictRepresentation[kSFIdentityOrgIdKey] as? String ?? "" }
    public var username: String { return dictRepresentation[kSFIdentityUsernameKey] as? String ?? "" }
    public var nickname: String? { return dictRepresentation.sfsdk_nonNullObject(forKey: kSFIdentityNicknameKey) as? String }
    public var displayName: String? { return dictRepresentation.sfsdk_nonNullObject(forKey: kSFIdentityDisplayNameKey) as? String }
    public var email: String { return dictRepresentation[kSFIdentityEmailKey] as? String ?? "" }
    public var firstName: String? { return dictRepresentation.sfsdk_nonNullObject(forKey: kSFIdentityFirstNameKey) as? String }
    public var lastName: String { return dictRepresentation[kSFIdentityLastNameKey] as? String ?? "" }

    public var pictureUrl: URL? { return parentExistsOrNilForUrl(kSFIdentityPhotosKey, childKey: kSFIdentityPictureUrlKey) }
    public var thumbnailUrl: URL? { return parentExistsOrNilForUrl(kSFIdentityPhotosKey, childKey: kSFIdentityThumbnailUrlKey) }

    public var enterpriseSoapUrl: String? { return parentExistsOrNilForString(kSFIdentityUrlsKey, childKey: kSFIdentityEnterpriseSoapUrlKey) }
    public var metadataSoapUrl: String? { return parentExistsOrNilForString(kSFIdentityUrlsKey, childKey: kSFIdentityMetadataSoapUrlKey) }
    public var partnerSoapUrl: String? { return parentExistsOrNilForString(kSFIdentityUrlsKey, childKey: kSFIdentityPartnerSoapUrlKey) }
    public var restUrl: String? { return parentExistsOrNilForString(kSFIdentityUrlsKey, childKey: kSFIdentityRestUrlKey) }
    public var restSObjectsUrl: String? { return parentExistsOrNilForString(kSFIdentityUrlsKey, childKey: kSFIdentityRestSObjectsUrlKey) }
    public var restSearchUrl: String? { return parentExistsOrNilForString(kSFIdentityUrlsKey, childKey: kSFIdentityRestSearchUrlKey) }
    public var restQueryUrl: String? { return parentExistsOrNilForString(kSFIdentityUrlsKey, childKey: kSFIdentityRestQueryUrlKey) }
    public var restRecentUrl: String? { return parentExistsOrNilForString(kSFIdentityUrlsKey, childKey: kSFIdentityRestRecentUrlKey) }
    public var profileUrl: URL? { return parentExistsOrNilForUrl(kSFIdentityUrlsKey, childKey: kSFIdentityProfileUrlKey) }
    public var chatterFeedsUrl: String? { return parentExistsOrNilForString(kSFIdentityUrlsKey, childKey: kSFIdentityChatterFeedsUrlKey) }
    public var chatterGroupsUrl: String? { return parentExistsOrNilForString(kSFIdentityUrlsKey, childKey: kSFIdentityChatterGroupsUrlKey) }
    public var chatterUsersUrl: String? { return parentExistsOrNilForString(kSFIdentityUrlsKey, childKey: kSFIdentityChatterUsersUrlKey) }
    public var chatterFeedItemsUrl: String? { return parentExistsOrNilForString(kSFIdentityUrlsKey, childKey: kSFIdentityChatterFeedItemsUrlKey) }

    public var isActive: Bool {
        return (dictRepresentation[kSFIdentityIsActiveKey] as? NSNumber)?.boolValue ?? false
    }

    public var userType: String { return dictRepresentation[kSFIdentityUserTypeKey] as? String ?? "" }
    public var language: String { return dictRepresentation[kSFIdentityLanguageKey] as? String ?? "" }
    public var locale: String { return dictRepresentation[kSFIdentityLocaleKey] as? String ?? "" }

    public var utcOffset: Int32 {
        guard let value = dictRepresentation.sfsdk_nonNullObject(forKey: kSFIdentityUtcOffsetKey) else { return -1 }
        return (value as? NSNumber)?.int32Value ?? -1
    }

    public var mobilePoliciesConfigured: Bool {
        return dictRepresentation.sfsdk_nonNullObject(forKey: kSFIdentityMobilePolicyKey) != nil
    }

    public var mobileAppPinLength: Int32 {
        guard let mobilePolicy = dictRepresentation.sfsdk_nonNullObject(forKey: kSFIdentityMobilePolicyKey) as? NSDictionary else { return 0 }
        guard let pinLength = mobilePolicy.sfsdk_nonNullObject(forKey: kSFIdentityMobileAppPinLengthKey) else { return 0 }
        return (pinLength as? NSNumber)?.int32Value ?? 0
    }

    public var mobileAppScreenLockTimeout: Int32 {
        guard let mobilePolicy = dictRepresentation.sfsdk_nonNullObject(forKey: kSFIdentityMobilePolicyKey) as? NSDictionary else { return 0 }
        guard let timeout = mobilePolicy.sfsdk_nonNullObject(forKey: kSFIdentityMobileAppScreenLockTimeoutKey) else { return 0 }
        return (timeout as? NSNumber)?.int32Value ?? 0
    }

    public var customAttributes: NSDictionary? {
        get {
            let attrs = dictRepresentation.sfsdk_nonNullObject(forKey: kSFIdentityCustomAttributesKey)
            return attrs as? NSDictionary
        }
        set {
            let mutable = (dictRepresentation as? [String: Any] ?? [:]).merging([kSFIdentityCustomAttributesKey: newValue ?? NSNull()]) { _, new in new }
            dictRepresentation = mutable as NSDictionary
        }
    }

    public var customPermissions: NSDictionary? {
        get {
            return dictRepresentation.sfsdk_nonNullObject(forKey: kSFIdentityCustomPermissionsKey) as? NSDictionary
        }
        set {
            let mutable = (dictRepresentation as? [String: Any] ?? [:]).merging([kSFIdentityCustomPermissionsKey: newValue ?? NSNull()]) { _, new in new }
            dictRepresentation = mutable as NSDictionary
        }
    }

    public var lastModifiedDate: Date? {
        guard let value = dictRepresentation.sfsdk_nonNullObject(forKey: kSFIdentityLastModifiedDateKey) as? String else { return nil }
        return SFIdentityData.date(fromRfc822String: value)
    }

    public var nativeLogin: Bool {
        return (dictRepresentation[kSFNativeLoginKey] as? NSNumber)?.boolValue ?? false
    }

    /// Designated initializer.
    @objc public init(jsonDict: NSDictionary) {
        assert(jsonDict.count > 0, "Data dictionary must not be nil.")
        self.dictRepresentation = jsonDict
        super.init()
    }

    // Convenience for [String: Any]
    @objc(initWithDictionary:)
    public convenience init(jsonDict dict: [String: Any]) {
        self.init(jsonDict: dict as NSDictionary)
    }

    public override var description: String {
        return dictRepresentation.description
    }

    // MARK: - NSSecureCoding

    public required init?(coder aDecoder: NSCoder) {
        let allowedClasses: [AnyClass] = [NSDictionary.self, NSString.self, NSURL.self, NSNumber.self, NSNull.self, NSArray.self]
        guard let dict = aDecoder.decodeObject(of: allowedClasses, forKey: kIdJsonDictKey) as? NSDictionary else {
            self.dictRepresentation = [:]
            super.init()
            return nil
        }
        self.dictRepresentation = dict
        super.init()
    }

    public func encode(with aCoder: NSCoder) {
        aCoder.encode(dictRepresentation, forKey: kIdJsonDictKey)
    }

    // MARK: - Private Helpers

    private func parentExistsOrNilForUrl(_ parentKey: String, childKey: String) -> URL? {
        guard let value = parentExistsOrNilForString(parentKey, childKey: childKey) else { return nil }
        return URL(string: value)
    }

    private func parentExistsOrNilForString(_ parentKey: String, childKey: String) -> String? {
        guard let parentDict = dictRepresentation.sfsdk_nonNullObject(forKey: parentKey) as? NSDictionary else { return nil }
        guard let value = parentDict.sfsdk_nonNullObject(forKey: childKey) else { return nil }
        return value as? String
    }

    private static func date(fromRfc822String dateString: String) -> Date? {
        let df = DateFormatter()
        df.dateFormat = kSFIdentityDateFormatString
        return df.date(from: dateString)
    }
}
