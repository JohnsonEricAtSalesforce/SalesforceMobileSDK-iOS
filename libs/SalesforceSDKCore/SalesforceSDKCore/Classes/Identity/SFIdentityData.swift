/*
 Copyright (c) 2012-present, salesforce.com, inc. All rights reserved.

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

// Private constants
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

/**
 * The data structure for the identity data that's retrieved from the Salesforce service.
 * @see SFIdentityCoordinator
 */
@objc(SFIdentityData)
@objcMembers
public class IdentityData: NSObject, NSSecureCoding {

    // MARK: - Properties

    /**
     * The NSDictionary representation of this identity data.
     */
    public private(set) var dictRepresentation: [String: Any]

    /**
     * The ID URL.
     */
    public var idUrl: URL {
        if let urlString = dictRepresentation[kSFIdentityIdUrlKey] as? String {
            return URL(string: urlString) ?? URL(fileURLWithPath: "")
        }
        return URL(fileURLWithPath: "")
    }

    /**
     * Whether or not this is the asserted user for this session.
     */
    public var assertedUser: Bool {
        let value = dictRepresentation.sfsdk_nonNullObject(forKey: kSFIdentityAssertedUserKey)
        return (value as? NSNumber)?.boolValue ?? false
    }

    /**
     * The User ID of the associated user.
     */
    public var userId: String {
        return dictRepresentation[kSFIdentityUserIdKey] as? String ?? ""
    }

    /**
     * The Organization ID of the associated user.
     */
    public var orgId: String {
        return dictRepresentation[kSFIdentityOrgIdKey] as? String ?? ""
    }

    /**
     * The username of the associated user.
     */
    public var username: String {
        return dictRepresentation[kSFIdentityUsernameKey] as? String ?? ""
    }

    /**
     * The nickname of the associated user.
     */
    public var nickname: String? {
        return dictRepresentation.sfsdk_nonNullObject(forKey: kSFIdentityNicknameKey) as? String
    }

    /**
     * The display name of the associated user.
     */
    public var displayName: String? {
        return dictRepresentation.sfsdk_nonNullObject(forKey: kSFIdentityDisplayNameKey) as? String
    }

    /**
     * The email address of the associated user.
     */
    public var email: String {
        return dictRepresentation[kSFIdentityEmailKey] as? String ?? ""
    }

    /**
     * The first name of the user.
     */
    public var firstName: String? {
        return dictRepresentation.sfsdk_nonNullObject(forKey: kSFIdentityFirstNameKey) as? String
    }

    /**
     * The last name of the user.
     */
    public var lastName: String {
        return dictRepresentation[kSFIdentityLastNameKey] as? String ?? ""
    }

    /**
     * The URL to retrieve the user's picture.
     */
    public var pictureUrl: URL? {
        return parentExistsOrNilForUrl(parentKey: kSFIdentityPhotosKey, childKey: kSFIdentityPictureUrlKey)
    }

    /**
     * The URL to retrieve a thumbnail picture for the user.
     */
    public var thumbnailUrl: URL? {
        return parentExistsOrNilForUrl(parentKey: kSFIdentityPhotosKey, childKey: kSFIdentityThumbnailUrlKey)
    }

    /**
     * The enterprise SOAP API URL string for this user.
     * Note: API URLs require replacement of the `version` token with a valid API version string.
     */
    public var enterpriseSoapUrl: String? {
        return parentExistsOrNilForString(parentKey: kSFIdentityUrlsKey, childKey: kSFIdentityEnterpriseSoapUrlKey)
    }

    /**
     * The metadata SOAP API URL string for this user.
     * Note: API URLs require replacement of the `version` token with a valid API version string.
     */
    public var metadataSoapUrl: String? {
        return parentExistsOrNilForString(parentKey: kSFIdentityUrlsKey, childKey: kSFIdentityMetadataSoapUrlKey)
    }

    /**
     * The partner SOAP API URL string for this user.
     * Note: API URLs require replacement of the `version` token with a valid API version string.
     */
    public var partnerSoapUrl: String? {
        return parentExistsOrNilForString(parentKey: kSFIdentityUrlsKey, childKey: kSFIdentityPartnerSoapUrlKey)
    }

    /**
     * The REST API URL string entry point for this user.
     * Note: API URLs require replacement of the `version` token with a valid API version string.
     */
    public var restUrl: String? {
        return parentExistsOrNilForString(parentKey: kSFIdentityUrlsKey, childKey: kSFIdentityRestUrlKey)
    }

    /**
     * The REST endpoint string for SObjects.
     * Note: API URLs require replacement of the `version` token with a valid API version string.
     */
    public var restSObjectsUrl: String? {
        return parentExistsOrNilForString(parentKey: kSFIdentityUrlsKey, childKey: kSFIdentityRestSObjectsUrlKey)
    }

    /**
     * The REST endpoint string for search.
     * Note: API URLs require replacement of the `version` token with a valid API version string.
     */
    public var restSearchUrl: String? {
        return parentExistsOrNilForString(parentKey: kSFIdentityUrlsKey, childKey: kSFIdentityRestSearchUrlKey)
    }

    /**
     * The REST endpoint string for queries.
     * Note: API URLs require replacement of the `version` token with a valid API version string.
     */
    public var restQueryUrl: String? {
        return parentExistsOrNilForString(parentKey: kSFIdentityUrlsKey, childKey: kSFIdentityRestQueryUrlKey)
    }

    /**
     * The REST endpoint string for recent activity.
     * Note: API URLs require replacement of the `version` token with a valid API version string.
     */
    public var restRecentUrl: String? {
        return parentExistsOrNilForString(parentKey: kSFIdentityUrlsKey, childKey: kSFIdentityRestRecentUrlKey)
    }

    /**
     * The user profile URL.
     */
    public var profileUrl: URL? {
        return parentExistsOrNilForUrl(parentKey: kSFIdentityUrlsKey, childKey: kSFIdentityProfileUrlKey)
    }

    /**
     * The URL string for Chatter feeds.
     * Note: API URLs require replacement of the `version` token with a valid API version string.
     */
    public var chatterFeedsUrl: String? {
        return parentExistsOrNilForString(parentKey: kSFIdentityUrlsKey, childKey: kSFIdentityChatterFeedsUrlKey)
    }

    /**
     * The URL string for Chatter groups.
     * Note: API URLs require replacement of the `version` token with a valid API version string.
     */
    public var chatterGroupsUrl: String? {
        return parentExistsOrNilForString(parentKey: kSFIdentityUrlsKey, childKey: kSFIdentityChatterGroupsUrlKey)
    }

    /**
     * The URL string for Chatter users.
     * Note: API URLs require replacement of the `version` token with a valid API version string.
     */
    public var chatterUsersUrl: String? {
        return parentExistsOrNilForString(parentKey: kSFIdentityUrlsKey, childKey: kSFIdentityChatterUsersUrlKey)
    }

    /**
     * The URL string for Chatter feed items.
     * Note: API URLs require replacement of the `version` token with a valid API version string.
     */
    public var chatterFeedItemsUrl: String? {
        return parentExistsOrNilForString(parentKey: kSFIdentityUrlsKey, childKey: kSFIdentityChatterFeedItemsUrlKey)
    }

    /**
     * Whether or not this user is active.
     */
    public var isActive: Bool {
        if let value = dictRepresentation[kSFIdentityIsActiveKey] as? NSNumber {
            return value.boolValue
        }
        return false
    }

    /**
     * The user type.
     */
    public var userType: String {
        return dictRepresentation[kSFIdentityUserTypeKey] as? String ?? ""
    }

    /**
     * The user's configured language.
     */
    public var language: String {
        return dictRepresentation[kSFIdentityLanguageKey] as? String ?? ""
    }

    /**
     * The user's configured locale.
     */
    public var locale: String {
        return dictRepresentation[kSFIdentityLocaleKey] as? String ?? ""
    }

    /**
     * The UTC offset for this user.
     */
    public var utcOffset: Int32 {
        let value = dictRepresentation.sfsdk_nonNullObject(forKey: kSFIdentityUtcOffsetKey)
        return (value as? NSNumber)?.int32Value ?? -1
    }

    /**
     * Whether or not any additional mobile security policies have been configured
     * for this application.
     */
    public var mobilePoliciesConfigured: Bool {
        return dictRepresentation.sfsdk_nonNullObject(forKey: kSFIdentityMobilePolicyKey) != nil
    }

    /**
     * The length of the PIN code, if it's required.  Defaults to 0 if not set, but
     * querying mobilePoliciesConfigured is recommended to validate that policies
     * are set.
     */
    public var mobileAppPinLength: Int32 {
        if let mobilePolicy = dictRepresentation.sfsdk_nonNullObject(forKey: kSFIdentityMobilePolicyKey) as? [String: Any],
           let pinLength = mobilePolicy.sfsdk_nonNullObject(forKey: kSFIdentityMobileAppPinLengthKey) as? NSNumber {
            return pinLength.int32Value
        }
        return 0
    }

    /**
     * The length of time in minutes before the app will be locked, if it's required.
     * Defaults to -1 if not set, but querying mobilePoliciesConfigured is recommended
     * to validate that policies are set.
     */
    public var mobileAppScreenLockTimeout: Int32 {
        if let mobilePolicy = dictRepresentation.sfsdk_nonNullObject(forKey: kSFIdentityMobilePolicyKey) as? [String: Any],
           let screenLockTimeout = mobilePolicy.sfsdk_nonNullObject(forKey: kSFIdentityMobileAppScreenLockTimeoutKey) as? NSNumber {
            return screenLockTimeout.int32Value
        }
        return 0
    }

    /**
     * An optional dictionary of custom attributes defined on the Connected App.
     */
    public var customAttributes: [String: Any]? {
        get {
            let attributes = dictRepresentation.sfsdk_nonNullObject(forKey: kSFIdentityCustomAttributesKey)
            if let dict = attributes as? [String: Any] {
                return dict
            }
            return nil
        }
        set {
            var mutableDict = dictRepresentation
            mutableDict[kSFIdentityCustomAttributesKey] = newValue
            dictRepresentation = mutableDict
        }
    }

    /**
     * An optional dictionary of custom permissions defined on the Connected App.
     */
    public var customPermissions: [String: Any]? {
        get {
            return dictRepresentation.sfsdk_nonNullObject(forKey: kSFIdentityCustomPermissionsKey) as? [String: Any]
        }
        set {
            var mutableDict = dictRepresentation
            mutableDict[kSFIdentityCustomPermissionsKey] = newValue
            dictRepresentation = mutableDict
        }
    }

    /**
     * The date this record was last modified.
     */
    public var lastModifiedDate: Date? {
        if let value = dictRepresentation.sfsdk_nonNullObject(forKey: kSFIdentityLastModifiedDateKey) as? String {
            return Self.date(fromRfc822String: value)
        }
        return nil
    }

    /**
     * Wheher or not the user was added via Native Login.  The profile of this user
     * restricts them from certain flows, such as IDP.
     */
    public var nativeLogin: Bool {
        return (dictRepresentation[kSFNativeLoginKey] as? NSNumber)?.boolValue ?? false
    }

    // MARK: - Initialization

    /**
     * Designated initializer for creating an instance of the SFIdentityData object.
     * @param jsonDict The JSON dictionary containing the user data.
     */
    @objc(initWithJsonDict:)
    public init(jsonDict: [String: Any]) {
        assert(!jsonDict.isEmpty, "Data dictionary must not be nil.")
        self.dictRepresentation = jsonDict
        super.init()
    }

    // MARK: - NSSecureCoding

    public static var supportsSecureCoding: Bool {
        return true
    }

    public required init?(coder aDecoder: NSCoder) {
        let classes = NSSet(array: [NSDictionary.self, NSString.self, NSURL.self, NSNumber.self, NSNull.self, NSArray.self])
        if let dict = aDecoder.decodeObject(of: classes as? Set<AnyHashable> as! [AnyClass], forKey: kIdJsonDictKey) as? [String: Any] {
            self.dictRepresentation = dict
        } else {
            self.dictRepresentation = [:]
        }
        super.init()
    }

    public func encode(with aCoder: NSCoder) {
        aCoder.encode(dictRepresentation, forKey: kIdJsonDictKey)
    }

    // MARK: - Description

    public override var description: String {
        return "\(dictRepresentation)"
    }

    // MARK: - Private Methods

    private func parentExistsOrNilForUrl(parentKey: String, childKey: String) -> URL? {
        if let value = parentExistsOrNilForString(parentKey: parentKey, childKey: childKey) {
            return URL(string: value)
        }
        return nil
    }

    private func parentExistsOrNilForString(parentKey: String, childKey: String) -> String? {
        if let parentDict = dictRepresentation.sfsdk_nonNullObject(forKey: parentKey) as? [String: Any],
           let value = parentDict.sfsdk_nonNullObject(forKey: childKey) as? String {
            return value
        }
        return nil
    }

    private static func date(fromRfc822String dateString: String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = kSFIdentityDateFormatString
        return dateFormatter.date(from: dateString)
    }
}
