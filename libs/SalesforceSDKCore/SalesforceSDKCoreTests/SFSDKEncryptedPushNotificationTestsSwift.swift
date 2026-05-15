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

final class SFSDKEncryptedPushNotificationTestsSwift: XCTestCase {

    private var userInfoDict: [AnyHashable: Any]!
    private var contentDict: [String: String]!

    override func setUp() {
        super.setUp()
        contentDict = [
            kRemoteNotificationKeyAlertTitle: "content_alert_title",
            kRemoteNotificationKeyAlertBody: "content_alert_body",
            "ContentKey1": "ContentValue1",
            "ContentKey2": "ContentValue2"
        ]
        let pndp = SFSDKPushNotificationDataProvider(contentObj: contentDict as [AnyHashable: Any])
        userInfoDict = pndp.userInfoDict
    }

    func testGetRSAKeySameData() {
        let rsaKey = PushNotificationManager.sharedInstance().getRSAPublicKey()
        XCTAssertNotNil(rsaKey)
        let rsaKey2 = PushNotificationManager.sharedInstance().getRSAPublicKey()
        XCTAssertEqual(rsaKey, rsaKey2)
    }

    func testValidateUserInfo() {
        // Valid notification content should not throw
        let content = notificationContent(with: userInfoDict)
        XCTAssertNoThrow(try SFSDKPushNotificationDecryption.decryptNotificationContent(content))
    }

    func testValidateUserInfoNoSecret() {
        var userInfo = userInfoDict!
        userInfo[kRemoteNotificationKeySecret] = nil
        let content = notificationContent(with: userInfo)
        assertDecryptionThrows(content: content, expectedCode: SFSDKPushNotificationError.noEncryptedSecret.rawValue)
    }

    func testValidateUserInfoNoContent() {
        var userInfo = userInfoDict!
        userInfo[kRemoteNotificationKeyContent] = nil
        let content = notificationContent(with: userInfo)
        assertDecryptionThrows(content: content, expectedCode: SFSDKPushNotificationError.noEncryptedContent.rawValue)
    }

    func testValidateUserInfoNoTitle() {
        var userInfo = userInfoDict!
        var apsDict = (userInfo[kRemoteNotificationKeyAps] as! [String: Any])
        var alertDict = (apsDict[kRemoteNotificationKeyAlert] as! [String: Any])
        alertDict[kRemoteNotificationKeyTitle] = nil
        apsDict[kRemoteNotificationKeyAlert] = alertDict
        userInfo[kRemoteNotificationKeyAps] = apsDict

        let content = notificationContent(with: userInfo)
        assertDecryptionThrows(content: content, expectedCode: SFSDKPushNotificationError.noApsAlertTitle.rawValue)
    }

    func testValidateUserInfoNoBody() {
        var userInfo = userInfoDict!
        var apsDict = (userInfo[kRemoteNotificationKeyAps] as! [String: Any])
        var alertDict = (apsDict[kRemoteNotificationKeyAlert] as! [String: Any])
        alertDict[kRemoteNotificationKeyBody] = nil
        apsDict[kRemoteNotificationKeyAlert] = alertDict
        userInfo[kRemoteNotificationKeyAps] = apsDict

        let content = notificationContent(with: userInfo)
        assertDecryptionThrows(content: content, expectedCode: SFSDKPushNotificationError.noApsAlertBody.rawValue)
    }

    func testValidateUserInfoNoApsDict() {
        var userInfo = userInfoDict!
        userInfo[kRemoteNotificationKeyAps] = nil
        let content = notificationContent(with: userInfo)
        assertDecryptionThrows(content: content, expectedCode: SFSDKPushNotificationError.noApsDictionary.rawValue)
    }

    func testValidateUserInfoNoApsAlertDict() {
        var userInfo = userInfoDict!
        var apsDict = (userInfo[kRemoteNotificationKeyAps] as! [String: Any])
        apsDict[kRemoteNotificationKeyAlert] = nil
        userInfo[kRemoteNotificationKeyAps] = apsDict
        let content = notificationContent(with: userInfo)
        assertDecryptionThrows(content: content, expectedCode: SFSDKPushNotificationError.noApsAlertDictionary.rawValue)
    }

    func testNotificationNotEncrypted() {
        var userInfo = userInfoDict!

        // No 'encrypted' value.
        userInfo[kRemoteNotificationKeyEncrypted] = nil
        var notifContent = notificationContent(with: userInfo)
        XCTAssertNoThrow(try SFSDKPushNotificationDecryption.decryptNotificationContent(notifContent))

        // 'encrypted' value is set to NO.
        userInfo[kRemoteNotificationKeyEncrypted] = false
        notifContent = notificationContent(with: userInfo)
        XCTAssertNoThrow(try SFSDKPushNotificationDecryption.decryptNotificationContent(notifContent))
    }

    func testNotificationTransform() {
        let contentNotif = notificationContent(with: userInfoDict)
        XCTAssertNoThrow(try SFSDKPushNotificationDecryption.decryptNotificationContent(contentNotif))
        XCTAssertNil(contentNotif.userInfo[kRemoteNotificationKeyContent])
        for contentKey in contentDict.keys {
            XCTAssertEqual(contentDict[contentKey], contentNotif.userInfo[contentKey] as? String)
        }
        XCTAssertEqual(contentNotif.title, contentDict[kRemoteNotificationKeyAlertTitle])
        XCTAssertEqual(contentNotif.body, contentDict[kRemoteNotificationKeyAlertBody])
        XCTAssertEqual(contentNotif.title, contentNotif.userInfo[kRemoteNotificationKeyAlertTitle] as? String)
        XCTAssertEqual(contentNotif.body, contentNotif.userInfo[kRemoteNotificationKeyAlertBody] as? String)
    }

    func testNotificationTransformMalformedSecret() {
        var userInfo = userInfoDict!
        userInfo[kRemoteNotificationKeySecret] = "some not base64 string"
        let notifContent = notificationContent(with: userInfo)
        assertDecryptionThrows(content: notifContent, expectedCode: SFSDKPushNotificationError.malformedSecretData.rawValue)
    }

    func testNotificationTransformNonRSASecret() {
        var userInfo = userInfoDict!
        let nonRSASecretBase64 = "some non-encrypted string".data(using: .utf8)!.base64EncodedString()
        userInfo[kRemoteNotificationKeySecret] = nonRSASecretBase64
        let notifContent = notificationContent(with: userInfo)
        do {
            try SFSDKPushNotificationDecryption.decryptNotificationContent(notifContent)
            XCTFail("Should have thrown an error")
        } catch let error as NSError {
            XCTAssert(error.code == SFSDKPushNotificationError.contentDecryptionFailed.rawValue || error.code == SFSDKPushNotificationError.secretDecryptionFailed.rawValue)
        }
    }

    func testNotificationTransformMalformedContent() {
        var userInfo = userInfoDict!
        userInfo[kRemoteNotificationKeyContent] = "some not base64 string"
        let notifContent = notificationContent(with: userInfo)
        assertDecryptionThrows(content: notifContent, expectedCode: SFSDKPushNotificationError.malformedContentData.rawValue)
    }

    func testNotificationTransformNonAES128Content() {
        var userInfo = userInfoDict!
        let nonAES128ContentBase64 = "some non-encrypted string".data(using: .utf8)!.base64EncodedString()
        userInfo[kRemoteNotificationKeyContent] = nonAES128ContentBase64
        let notifContent = notificationContent(with: userInfo)
        assertDecryptionThrows(content: notifContent, expectedCode: SFSDKPushNotificationError.contentDecryptionFailed.rawValue)
    }

    func testNotificationTransformNonJSONContent() {
        let nonJSONContent = "This is not JSON"
        let pndp = SFSDKPushNotificationDataProvider(contentJSON: nonJSONContent)
        let userInfo = pndp.userInfoDict
        let notifContent = notificationContent(with: userInfo)
        assertDecryptionThrows(content: notifContent, expectedCode: SFSDKPushNotificationError.invalidContentFormat.rawValue)
    }

    func testNotificationTransformArrayJSONContent() {
        let arrayJSONContent = "[ \"One\", \"Two\", \"Three\" ]"
        let pndp = SFSDKPushNotificationDataProvider(contentJSON: arrayJSONContent)
        let userInfo = pndp.userInfoDict
        let notifContent = notificationContent(with: userInfo)
        assertDecryptionThrows(content: notifContent, expectedCode: SFSDKPushNotificationError.invalidContentFormat.rawValue)
    }

    // MARK: - Helper methods

    private func notificationContent(with userInfo: [AnyHashable: Any]) -> UNMutableNotificationContent {
        let mutContent = UNMutableNotificationContent()
        mutContent.userInfo = userInfo
        return mutContent
    }

    private func assertDecryptionThrows(content: UNMutableNotificationContent, expectedCode: Int, file: StaticString = #file, line: UInt = #line) {
        do {
            try SFSDKPushNotificationDecryption.decryptNotificationContent(content)
            XCTFail("Should have thrown an error", file: file, line: line)
        } catch let error as NSError {
            XCTAssertEqual(error.code, expectedCode, "Error code mismatch", file: file, line: line)
        }
    }
}
