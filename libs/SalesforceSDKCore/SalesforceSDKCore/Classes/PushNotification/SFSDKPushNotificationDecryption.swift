// Copyright (c) 2019-present, salesforce.com, inc. All rights reserved.
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
import UserNotifications
import SalesforceSDKCommon

// Field constants
private let kRemoteNotificationKeyAlert = "alert"
private let kRemoteNotificationKeyBody = "body"
private let kRemoteNotificationKeyTitle = "title"
private let kRemoteNotificationKeyAlertTitle = "alertTitle"
private let kRemoteNotificationKeyAlertBody = "alertBody"
private let kRemoteNotificationKeyAps = "aps"
private let kRemoteNotificationKeyEncrypted = "encrypted"
private let kRemoteNotificationKeyContent = "content"
private let kRemoteNotificationKeySecret = "secret"

@objc(SFSDKPushNotificationDecryption)
@objcMembers
public class SFSDKPushNotificationDecryption: NSObject {

    /// Decrypts the given notification content. Leaves the content unchanged if it's not encrypted.
    /// - Parameters:
    ///   - notificationContent: Content to decrypt.
    ///   - error: The error associated with decryption, if an error occurs.
    /// - Returns: YES on success, NO otherwise.
    @objc public class func decryptNotificationContent(_ notificationContent: UNMutableNotificationContent, error: NSErrorPointer) -> Bool {
        guard let encrypted = notificationContent.userInfo[kRemoteNotificationKeyEncrypted] as? NSNumber, encrypted.boolValue else {
            // Not encrypted. No action necessary.
            return true
        }

        var dataValidationError: NSError?
        let validData = validateNotificationUserInfo(notificationContent.userInfo, error: &dataValidationError)
        if !validData {
            error?.pointee = dataValidationError
            return false
        }

        guard let secret = notificationContent.userInfo[kRemoteNotificationKeySecret] as? String else { return false }
        var decryptSecretError: NSError?
        guard let encryptionKey = getAESKey(fromSecret: secret, error: &decryptSecretError) else {
            error?.pointee = decryptSecretError
            return false
        }

        guard let encryptedContent = notificationContent.userInfo[kRemoteNotificationKeyContent] as? String else { return false }
        var decryptContentError: NSError?
        guard let contentString = aesDecryptString(encryptedContent, withKey: encryptionKey, error: &decryptContentError) else {
            error?.pointee = decryptContentError
            return false
        }

        guard let contentDict = SFJsonUtils.object(fromJSONString: contentString) as? [String: Any] else {
            error?.pointee = pushError(withCode: SFSDKPushNotificationErrorCode.invalidContentFormat.rawValue, description: "Decrypted content is not a valid JSON dictionary.")
            return false
        }

        // Apply decrypted content.
        var updateUserInfo = notificationContent.userInfo as? [String: Any] ?? [:]
        for (itemKey, value) in contentDict {
            updateUserInfo[itemKey] = value
        }
        updateUserInfo.removeValue(forKey: kRemoteNotificationKeyContent)
        notificationContent.userInfo = updateUserInfo

        // Apply alert.
        notificationContent.title = notificationContent.userInfo[kRemoteNotificationKeyAlertTitle] as? String ?? ""
        notificationContent.body = notificationContent.userInfo[kRemoteNotificationKeyAlertBody] as? String ?? ""

        // Update alert body string.
        if let apsDict = notificationContent.userInfo[kRemoteNotificationKeyAps] as? [String: Any],
           let alertDict = apsDict[kRemoteNotificationKeyAlert] as? [String: Any] {
            var updateAlertDict = alertDict
            if alertDict[kRemoteNotificationKeyBody] != nil {
                updateAlertDict[kRemoteNotificationKeyBody] = notificationContent.body
            }
            if alertDict[kRemoteNotificationKeyTitle] != nil {
                updateAlertDict[kRemoteNotificationKeyTitle] = notificationContent.title
            }
            var updateApsDict = apsDict
            updateApsDict[kRemoteNotificationKeyAlert] = updateAlertDict
            var finalUserInfo = notificationContent.userInfo as? [String: Any] ?? [:]
            finalUserInfo[kRemoteNotificationKeyAps] = updateApsDict
            notificationContent.userInfo = finalUserInfo
        }

        return true
    }

    // MARK: - Private Methods

    private class func validateNotificationUserInfo(_ userInfo: [AnyHashable: Any], error: NSErrorPointer) -> Bool {
        guard let secret = userInfo[kRemoteNotificationKeySecret], secret is String else {
            error?.pointee = pushError(withCode: SFSDKPushNotificationErrorCode.noEncryptedSecret.rawValue, description: "No secret data in the notification content.")
            return false
        }

        guard let content = userInfo[kRemoteNotificationKeyContent], content is String else {
            error?.pointee = pushError(withCode: SFSDKPushNotificationErrorCode.noEncryptedContent.rawValue, description: "No content data in the notification content.")
            return false
        }

        guard let apsDict = userInfo[kRemoteNotificationKeyAps] as? [String: Any] else {
            error?.pointee = pushError(withCode: SFSDKPushNotificationErrorCode.noApsDictionary.rawValue, description: "No aps data in the notification content.")
            return false
        }

        guard let alertDict = apsDict[kRemoteNotificationKeyAlert] as? [String: Any] else {
            error?.pointee = pushError(withCode: SFSDKPushNotificationErrorCode.noApsAlertDictionary.rawValue, description: "No alert data in the aps content of the notification.")
            return false
        }

        guard alertDict[kRemoteNotificationKeyTitle] is String else {
            error?.pointee = pushError(withCode: SFSDKPushNotificationErrorCode.noApsAlertTitle.rawValue, description: "No alert title in the notification content.")
            return false
        }

        guard alertDict[kRemoteNotificationKeyBody] is String else {
            error?.pointee = pushError(withCode: SFSDKPushNotificationErrorCode.noApsAlertBody.rawValue, description: "No alert body in the notification content.")
            return false
        }

        return true
    }

    private class func pushError(withCode code: Int, description: String) -> NSError {
        return NSError(domain: SFSDKPushNotificationErrorDomain, code: code, userInfo: [NSLocalizedDescriptionKey: description])
    }

    private class func getAESKey(fromSecret secret: String, error: NSErrorPointer) -> SFEncryptionKey? {
        guard let secretData = Data(base64Encoded: secret, options: []) else {
            error?.pointee = pushError(withCode: SFSDKPushNotificationErrorCode.malformedSecretData.rawValue, description: "Encrypted secret is an invalid Base64 string.")
            return nil
        }

        guard let privateKeyRef = SFSDKCryptoUtils.getRSAPrivateKeyRef(withName: PushNotificationManagerConstants.kPNEncryptionKeyName, keyLength: UInt(PushNotificationManagerConstants.kPNEncryptionKeyLength)) else {
            error?.pointee = pushError(withCode: SFSDKPushNotificationErrorCode.privateRSAKeyNotFound.rawValue, description: "Could not retrieve private RSA key for encrypted notification.")
            return nil
        }

        var decryptedData: Data?
        do {
            decryptedData = try SFSDKCryptoUtils.decrypt(data: secretData, key: privateKeyRef, algorithm: .rsaEncryptionOAEPSHA256)
        } catch {
            SFSDKCoreLogger.w(Self.self, format: "Decrypting secret with RSA OAEP failed, falling back to PKCS1: %@", error.localizedDescription)
            do {
                decryptedData = try SFSDKCryptoUtils.decrypt(data: secretData, key: privateKeyRef, algorithm: .rsaEncryptionPKCS1)
            } catch {
                SFSDKCoreLogger.e(Self.self, format: "Decrypting secret with RSA PKCS1 failed: %@", error.localizedDescription)
            }
        }

        guard let data = decryptedData, data.count == 32 else {
            error?.pointee = pushError(withCode: SFSDKPushNotificationErrorCode.secretDecryptionFailed.rawValue, description: "Failed to decrypt secret with RSA private key.")
            return nil
        }

        let keyData = data.subdata(in: 0..<16)
        let ivData = data.subdata(in: 16..<32)
        return SFEncryptionKey(data: keyData, initializationVector: ivData)
    }

    private class func aesDecryptString(_ encryptedString: String, withKey key: SFEncryptionKey, error: NSErrorPointer) -> String? {
        guard let encryptedData = Data(base64Encoded: encryptedString, options: []) else {
            error?.pointee = pushError(withCode: SFSDKPushNotificationErrorCode.malformedContentData.rawValue, description: "Encrypted content is an invalid Base64 string.")
            return nil
        }

        guard let keyData = key.key, let ivData = key.initializationVector else {
            error?.pointee = pushError(withCode: SFSDKPushNotificationErrorCode.contentDecryptionFailed.rawValue, description: "Failed to decrypt content with symmetric secret key.")
            return nil
        }

        guard let decryptedData = SFSDKCryptoUtils.aes128DecryptData(encryptedData, withKey: keyData, iv: ivData) else {
            error?.pointee = pushError(withCode: SFSDKPushNotificationErrorCode.contentDecryptionFailed.rawValue, description: "Failed to decrypt content with symmetric secret key.")
            return nil
        }

        guard let decryptedString = String(data: decryptedData, encoding: .utf8) else {
            error?.pointee = pushError(withCode: SFSDKPushNotificationErrorCode.contentDecryptionFailed.rawValue, description: "Failed to decrypt content with symmetric secret key.")
            return nil
        }

        return decryptedString
    }
}
