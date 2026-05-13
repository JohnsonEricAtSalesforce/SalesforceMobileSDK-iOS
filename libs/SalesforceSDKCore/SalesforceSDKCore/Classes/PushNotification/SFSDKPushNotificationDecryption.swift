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

import Foundation
import UserNotifications
import SalesforceSDKCommon

@objc(SFSDKPushNotificationDecryption)
@objcMembers
public class SFSDKPushNotificationDecryption: NSObject {

    // MARK: - Public Methods

    /// Decrypts the given notification content. Leaves the content unchanged if it's not encrypted.
    /// - Parameters:
    ///   - notificationContent: Content to decrypt.
    ///   - error: The error associated with decryption, if an error occurs.
    /// - Returns: true on success, false otherwise.
    public static func decryptNotificationContent(_ notificationContent: UNMutableNotificationContent) throws {
        if (notificationContent.userInfo[kRemoteNotificationKeyEncrypted] as? Bool) != true {
            // Not encrypted. No action necessary.
            return
        }

        try validateNotificationUserInfo(notificationContent.userInfo)

        guard let secret = notificationContent.userInfo[kRemoteNotificationKeySecret] as? String else {
            throw pushError(withCode: .noEncryptedSecret, description: "No secret data in the notification content.")
        }

        let encryptionKey = try getAESKey(fromSecret: secret)

        guard let encryptedContent = notificationContent.userInfo[kRemoteNotificationKeyContent] as? String else {
            throw pushError(withCode: .noEncryptedContent, description: "No content data in the notification content.")
        }

        let contentString = try aesDecryptString(encryptedContent, withKey: encryptionKey)

        guard let contentDict = SFJsonUtils.object(from: contentString) as? [String: Any] else {
            throw pushError(withCode: .invalidContentFormat, description: "Decrypted content is not a valid JSON dictionary.")
        }

        // Apply decrypted content.
        var updateUserInfo = notificationContent.userInfo as! [AnyHashable: Any]
        for (itemKey, itemValue) in contentDict {
            updateUserInfo[itemKey] = itemValue
        }
        updateUserInfo.removeValue(forKey: kRemoteNotificationKeyContent)
        notificationContent.userInfo = updateUserInfo

        // Apply alert.
        notificationContent.title = notificationContent.userInfo[kRemoteNotificationKeyAlertTitle] as? String ?? ""
        notificationContent.body = notificationContent.userInfo[kRemoteNotificationKeyAlertBody] as? String ?? ""

        // Update alert body string.
        if var apsDict = notificationContent.userInfo[kRemoteNotificationKeyAps] as? [String: Any],
           var alertDict = apsDict[kRemoteNotificationKeyAlert] as? [String: Any] {

            if alertDict[kRemoteNotificationKeyBody] != nil {
                alertDict[kRemoteNotificationKeyBody] = notificationContent.body
            }
            if alertDict[kRemoteNotificationKeyTitle] != nil {
                alertDict[kRemoteNotificationKeyTitle] = notificationContent.title
            }
            apsDict[kRemoteNotificationKeyAlert] = alertDict
            updateUserInfo[kRemoteNotificationKeyAps] = apsDict
            notificationContent.userInfo = updateUserInfo
        }
    }

    // MARK: - Private methods

    private static func validateNotificationUserInfo(_ userInfo: [AnyHashable: Any]) throws {
        guard let secret = userInfo[kRemoteNotificationKeySecret], secret is String else {
            throw pushError(withCode: .noEncryptedSecret, description: "No secret data in the notification content.")
        }

        guard let encryptedContent = userInfo[kRemoteNotificationKeyContent], encryptedContent is String else {
            throw pushError(withCode: .noEncryptedContent, description: "No content data in the notification content.")
        }

        guard let apsDict = userInfo[kRemoteNotificationKeyAps] as? [String: Any] else {
            throw pushError(withCode: .noApsDictionary, description: "No aps data in the notification content.")
        }

        guard let alertDict = apsDict[kRemoteNotificationKeyAlert] as? [String: Any] else {
            throw pushError(withCode: .noApsAlertDictionary, description: "No alert data in the aps content of the notification.")
        }

        guard let title = alertDict[kRemoteNotificationKeyTitle], title is String else {
            throw pushError(withCode: .noApsAlertTitle, description: "No alert title in the notification content.")
        }

        guard let body = alertDict[kRemoteNotificationKeyBody], body is String else {
            throw pushError(withCode: .noApsAlertBody, description: "No alert body in the notification content.")
        }
    }

    private static func pushError(withCode code: SFSDKPushNotificationError, description: String) -> NSError {
        let userInfo = [NSLocalizedDescriptionKey: description]
        return NSError(domain: SFSDKPushNotificationErrorDomain, code: code.rawValue, userInfo: userInfo)
    }

    private static func getAESKey(fromSecret secret: String) throws -> EncryptionKey {
        guard let secretData = Data(base64Encoded: secret) else {
            throw pushError(withCode: .malformedSecretData, description: "Encrypted secret is an invalid Base64 string.")
        }

        guard let privateKeyRef = CryptoUtils.getRSAPrivateKeyRef(withName: PushNotificationManagerConstants.kPNEncryptionKeyName, keyLength: PushNotificationManagerConstants.kPNEncryptionKeyLength) else {
            throw pushError(withCode: .privateRSAKeyNotFound, description: "Could not retrieve private RSA key for encrypted notification.")
        }

        var decryptedData: Data?
        do {
            decryptedData = try CryptoUtils.decrypt(data: secretData, key: privateKeyRef, algorithm: .rsaEncryptionOAEPSHA256)
        } catch {
            SFSDKCoreLogger.w(SFSDKPushNotificationDecryption.self, message: "Decrypting secret with RSA OAEP failed, falling back to PKCS1: \(error.localizedDescription)")

            do {
                decryptedData = try CryptoUtils.decrypt(data: secretData, key: privateKeyRef, algorithm: .rsaEncryptionPKCS1)
            } catch {
                SFSDKCoreLogger.e(SFSDKPushNotificationDecryption.self, message: "Decrypting secret with RSA PKCS1 failed: \(error.localizedDescription)")
            }
        }

        // ARC automatically manages Core Foundation objects in Swift
        // CFRelease is not needed and causes a compiler error

        guard let decryptedData = decryptedData, decryptedData.count == 32 else {
            throw pushError(withCode: .secretDecryptionFailed, description: "Failed to decrypt secret with RSA private key.")
        }

        let keyData = decryptedData.subdata(in: 0..<16)
        let ivData = decryptedData.subdata(in: 16..<32)
        return EncryptionKey(data: keyData, initializationVector: ivData)
    }

    private static func aesDecryptString(_ encryptedString: String, withKey key: EncryptionKey) throws -> String {
        guard let encryptedData = Data(base64Encoded: encryptedString) else {
            throw pushError(withCode: .malformedContentData, description: "Encrypted content is an invalid Base64 string.")
        }

        guard let keyData = key.key else {
            throw pushError(withCode: .secretDecryptionFailed, description: "Encryption key data is nil.")
        }

        guard let decryptedData = CryptoUtils.aes128DecryptData(encryptedData, withKey: keyData, iv: key.initializationVector) else {
            throw pushError(withCode: .contentDecryptionFailed, description: "Failed to decrypt content with symmetric secret key.")
        }

        guard let decryptedString = String(data: decryptedData, encoding: .utf8) else {
            throw pushError(withCode: .contentDecryptionFailed, description: "Failed to decrypt content with symmetric secret key.")
        }

        return decryptedString
    }
}
