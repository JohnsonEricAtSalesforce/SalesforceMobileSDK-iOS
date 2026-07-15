/*
 Copyright (c) 2019-present, salesforce.com, inc. All rights reserved.

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

import XCTest
import UserNotifications
@testable import SalesforceSDKCore

// Constants matching push notification field keys
private let kRemoteNotificationKeyEncrypted = "encrypted"
private let kRemoteNotificationKeySecret = "secret"
private let kRemoteNotificationKeyAps = "aps"
private let kRemoteNotificationKeyAlert = "alert"
private let kRemoteNotificationKeyTitle = "title"
private let kRemoteNotificationKeyBody = "body"
private let kRemoteNotificationKeyContent = "content"
private let kRemoteNotificationKeyAlertTitle = "alertTitle"
private let kRemoteNotificationKeyAlertBody = "alertBody"

class SFSDKEncryptedPushNotificationTests: XCTestCase {

    private var userInfoDict: [String: Any] = [:]
    private var contentDict: [String: Any] = [:]

    override func setUp() {
        super.setUp()
        contentDict = [
            kRemoteNotificationKeyAlertTitle: "content_alert_title",
            kRemoteNotificationKeyAlertBody: "content_alert_body",
            "ContentKey1": "ContentValue1",
            "ContentKey2": "ContentValue2"
        ]
        let pndp = SFSDKPushNotificationDataProvider(contentObj: contentDict)
        userInfoDict = pndp.userInfoDict
    }

    func testGetRSAKeySameData() {
        let rsaKey = PushNotificationManager.sharedInstance().getRSAPublicKey()
        XCTAssertNotNil(rsaKey)
        let rsaKey2 = PushNotificationManager.sharedInstance().getRSAPublicKey()
        XCTAssertEqual(rsaKey, rsaKey2)
    }

    func testValidateUserInfoNoSecret() {
        var userInfo = userInfoDict
        userInfo[kRemoteNotificationKeySecret] = nil
        let notifContent = notificationContent(withUserInfo: userInfo)
        var noSecretError: NSError?
        let result = SFSDKPushNotificationDecryption.decryptNotificationContent(notifContent, error: &noSecretError)
        XCTAssertFalse(result)
        XCTAssertEqual(noSecretError?.code, SFSDKPushNotificationErrorCode.noEncryptedSecret.rawValue)
    }

    func testValidateUserInfoNoContent() {
        var userInfo = userInfoDict
        userInfo[kRemoteNotificationKeyContent] = nil
        let notifContent = notificationContent(withUserInfo: userInfo)
        var noContentError: NSError?
        let result = SFSDKPushNotificationDecryption.decryptNotificationContent(notifContent, error: &noContentError)
        XCTAssertFalse(result)
        XCTAssertEqual(noContentError?.code, SFSDKPushNotificationErrorCode.noEncryptedContent.rawValue)
    }

    func testValidateUserInfoNoTitle() {
        var userInfo = userInfoDict
        if var apsDict = userInfo[kRemoteNotificationKeyAps] as? [String: Any],
           var alertDict = apsDict[kRemoteNotificationKeyAlert] as? [String: Any] {
            alertDict[kRemoteNotificationKeyTitle] = nil
            apsDict[kRemoteNotificationKeyAlert] = alertDict
            userInfo[kRemoteNotificationKeyAps] = apsDict
        }
        let notifContent = notificationContent(withUserInfo: userInfo)
        var noTitleError: NSError?
        let result = SFSDKPushNotificationDecryption.decryptNotificationContent(notifContent, error: &noTitleError)
        XCTAssertFalse(result)
        XCTAssertEqual(noTitleError?.code, SFSDKPushNotificationErrorCode.noApsAlertTitle.rawValue)
    }

    func testValidateUserInfoNoBody() {
        var userInfo = userInfoDict
        if var apsDict = userInfo[kRemoteNotificationKeyAps] as? [String: Any],
           var alertDict = apsDict[kRemoteNotificationKeyAlert] as? [String: Any] {
            alertDict[kRemoteNotificationKeyBody] = nil
            apsDict[kRemoteNotificationKeyAlert] = alertDict
            userInfo[kRemoteNotificationKeyAps] = apsDict
        }
        let notifContent = notificationContent(withUserInfo: userInfo)
        var noBodyError: NSError?
        let result = SFSDKPushNotificationDecryption.decryptNotificationContent(notifContent, error: &noBodyError)
        XCTAssertFalse(result)
        XCTAssertEqual(noBodyError?.code, SFSDKPushNotificationErrorCode.noApsAlertBody.rawValue)
    }

    func testValidateUserInfoNoApsDict() {
        var userInfo = userInfoDict
        userInfo[kRemoteNotificationKeyAps] = nil
        let notifContent = notificationContent(withUserInfo: userInfo)
        var noApsDictError: NSError?
        let result = SFSDKPushNotificationDecryption.decryptNotificationContent(notifContent, error: &noApsDictError)
        XCTAssertFalse(result)
        XCTAssertEqual(noApsDictError?.code, SFSDKPushNotificationErrorCode.noApsDictionary.rawValue)
    }

    func testValidateUserInfoNoApsAlertDict() {
        var userInfo = userInfoDict
        if var apsDict = userInfo[kRemoteNotificationKeyAps] as? [String: Any] {
            apsDict[kRemoteNotificationKeyAlert] = nil
            userInfo[kRemoteNotificationKeyAps] = apsDict
        }
        let notifContent = notificationContent(withUserInfo: userInfo)
        var noApsAlertDictError: NSError?
        let result = SFSDKPushNotificationDecryption.decryptNotificationContent(notifContent, error: &noApsAlertDictError)
        XCTAssertFalse(result)
        XCTAssertEqual(noApsAlertDictError?.code, SFSDKPushNotificationErrorCode.noApsAlertDictionary.rawValue)
    }

    func testNotificationNotEncrypted() {
        var userInfo = userInfoDict

        // No 'encrypted' value.
        userInfo[kRemoteNotificationKeyEncrypted] = nil
        var notifContent = notificationContent(withUserInfo: userInfo)
        var unexpectedError: NSError?
        var result = SFSDKPushNotificationDecryption.decryptNotificationContent(notifContent, error: &unexpectedError)
        XCTAssertTrue(result)
        XCTAssertNil(unexpectedError)

        // 'encrypted' value is set to NO.
        userInfo[kRemoteNotificationKeyEncrypted] = false
        notifContent = notificationContent(withUserInfo: userInfo)
        unexpectedError = nil
        result = SFSDKPushNotificationDecryption.decryptNotificationContent(notifContent, error: &unexpectedError)
        XCTAssertTrue(result)
        XCTAssertNil(unexpectedError)
    }

    func testNotificationTransform() {
        var unexpectedError: NSError?
        let contentNotif = notificationContent(withUserInfo: userInfoDict)
        let result = SFSDKPushNotificationDecryption.decryptNotificationContent(contentNotif, error: &unexpectedError)
        XCTAssertTrue(result)
        XCTAssertNil(unexpectedError)
        XCTAssertNil(contentNotif.userInfo[kRemoteNotificationKeyContent])
        for contentKey in contentDict.keys {
            XCTAssertEqual(contentDict[contentKey] as? String, contentNotif.userInfo[contentKey] as? String)
        }
        XCTAssertEqual(contentNotif.title, contentDict[kRemoteNotificationKeyAlertTitle] as? String)
        XCTAssertEqual(contentNotif.body, contentDict[kRemoteNotificationKeyAlertBody] as? String)
        XCTAssertEqual(contentNotif.title, contentNotif.userInfo[kRemoteNotificationKeyAlertTitle] as? String)
        XCTAssertEqual(contentNotif.body, contentNotif.userInfo[kRemoteNotificationKeyAlertBody] as? String)
    }

    func testNotificationTransformMalformedSecret() {
        var userInfo = userInfoDict
        userInfo[kRemoteNotificationKeySecret] = "some not base64 string"
        let notifContent = notificationContent(withUserInfo: userInfo)
        var malformedSecretError: NSError?
        let result = SFSDKPushNotificationDecryption.decryptNotificationContent(notifContent, error: &malformedSecretError)
        XCTAssertFalse(result)
        XCTAssertEqual(malformedSecretError?.code, SFSDKPushNotificationErrorCode.malformedSecretData.rawValue)
    }

    func testNotificationTransformNonRSASecret() {
        var userInfo = userInfoDict
        let nonRSASecretBase64 = "some non-encrypted string".data(using: .utf8)?.base64EncodedString() ?? ""
        userInfo[kRemoteNotificationKeySecret] = nonRSASecretBase64
        let notifContent = notificationContent(withUserInfo: userInfo)
        var nonRSASecretError: NSError?
        let result = SFSDKPushNotificationDecryption.decryptNotificationContent(notifContent, error: &nonRSASecretError)
        XCTAssertFalse(result)
        // As of 17.4, decrypting a bad key with PKCS1 returns data instead of nil, so the secret decryption doesn't fail
        // at the same point as before but using it later to decrypt the content still fails
        XCTAssert(nonRSASecretError?.code == SFSDKPushNotificationErrorCode.contentDecryptionFailed.rawValue ||
                  nonRSASecretError?.code == SFSDKPushNotificationErrorCode.secretDecryptionFailed.rawValue)
    }

    func testNotificationTransformMalformedContent() {
        var userInfo = userInfoDict
        userInfo[kRemoteNotificationKeyContent] = "some not base64 string"
        let notifContent = notificationContent(withUserInfo: userInfo)
        var malformedContentError: NSError?
        let result = SFSDKPushNotificationDecryption.decryptNotificationContent(notifContent, error: &malformedContentError)
        XCTAssertFalse(result)
        XCTAssertEqual(malformedContentError?.code, SFSDKPushNotificationErrorCode.malformedContentData.rawValue)
    }

    func testNotificationTransformNonAES128Content() {
        var userInfo = userInfoDict
        let nonAES128ContentBase64 = "some non-encrypted string".data(using: .utf8)?.base64EncodedString() ?? ""
        userInfo[kRemoteNotificationKeyContent] = nonAES128ContentBase64
        let notifContent = notificationContent(withUserInfo: userInfo)
        var nonAES128ContentError: NSError?
        let result = SFSDKPushNotificationDecryption.decryptNotificationContent(notifContent, error: &nonAES128ContentError)
        XCTAssertFalse(result)
        XCTAssertEqual(nonAES128ContentError?.code, SFSDKPushNotificationErrorCode.contentDecryptionFailed.rawValue)
    }

    func testNotificationTransformNonJSONContent() {
        let nonJSONContent = "This is not JSON"
        let pndp = SFSDKPushNotificationDataProvider(contentJSON: nonJSONContent)
        let userInfo = pndp.userInfoDict
        let notifContent = notificationContent(withUserInfo: userInfo)
        var nonJSONContentError: NSError?
        let result = SFSDKPushNotificationDecryption.decryptNotificationContent(notifContent, error: &nonJSONContentError)
        XCTAssertFalse(result)
        XCTAssertEqual(nonJSONContentError?.code, SFSDKPushNotificationErrorCode.invalidContentFormat.rawValue)
    }

    func testNotificationTransformArrayJSONContent() {
        let arrayJSONContent = "[ \"One\", \"Two\", \"Three\" ]"
        let pndp = SFSDKPushNotificationDataProvider(contentJSON: arrayJSONContent)
        let userInfo = pndp.userInfoDict
        let notifContent = notificationContent(withUserInfo: userInfo)
        var arrayJSONContentError: NSError?
        let result = SFSDKPushNotificationDecryption.decryptNotificationContent(notifContent, error: &arrayJSONContentError)
        XCTAssertFalse(result)
        XCTAssertEqual(arrayJSONContentError?.code, SFSDKPushNotificationErrorCode.invalidContentFormat.rawValue)
    }

    // MARK: - Helper methods

    private func notificationContent(withUserInfo userInfo: [AnyHashable: Any]) -> UNMutableNotificationContent {
        let mutContent = UNMutableNotificationContent()
        mutContent.userInfo = userInfo
        return mutContent
    }
}
