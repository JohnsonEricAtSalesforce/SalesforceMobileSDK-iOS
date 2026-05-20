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
import SalesforceSDKCommon
@testable import SalesforceSDKCore

private let kEncryptionKeyLengthBytes: UInt = 16
private let kEncryptionIVLengthBytes: UInt = 16

// Local constants matching PushNotification field keys
private let kRemoteNotificationKeyEncrypted = "encrypted"
private let kRemoteNotificationKeySecret = "secret"
private let kRemoteNotificationKeyAps = "aps"
private let kRemoteNotificationKeyAlert = "alert"
private let kRemoteNotificationKeyTitle = "title"
private let kRemoteNotificationKeyBody = "body"
private let kRemoteNotificationKeyContent = "content"

class SFSDKPushNotificationDataProvider {

    let contentJSONData: Data?

    var userInfoDict: [String: Any] {
        let key = createEncryptionKey()
        var userInfo: [String: Any] = [
            kRemoteNotificationKeyEncrypted: true,
            kRemoteNotificationKeySecret: encryptKey(usingRSAPublicKey: key),
            kRemoteNotificationKeyAps: [
                kRemoteNotificationKeyAlert: [
                    kRemoteNotificationKeyTitle: "Title",
                    kRemoteNotificationKeyBody: "Body",
                    "key1": "value1"
                ]
            ]
        ]
        if let contentData = contentJSONData {
            userInfo[kRemoteNotificationKeyContent] = encryptContent(usingKey: key, data: contentData)
        }
        return userInfo
    }

    init(contentJSON: String?) {
        if let json = contentJSON {
            contentJSONData = json.data(using: .utf8)
        } else {
            contentJSONData = nil
        }
    }

    init(contentObj: Any?) {
        if let obj = contentObj {
            contentJSONData = SFJsonUtils.jsonDataRepresentation(obj)
        } else {
            contentJSONData = nil
        }
    }

    private func createEncryptionKey() -> SFEncryptionKey {
        let keyBytes = SFSDKCryptoUtils.randomByteData(withLength: kEncryptionKeyLengthBytes)
        let ivBytes = SFSDKCryptoUtils.randomByteData(withLength: kEncryptionIVLengthBytes)
        return SFEncryptionKey(data: keyBytes, initializationVector: ivBytes)
    }

    private func encryptKey(usingRSAPublicKey key: SFEncryptionKey) -> String {
        guard let keyData = key.key, let ivData = key.initializationVector else {
            fatalError("Key or IV is nil")
        }
        var fullKeyData = keyData
        fullKeyData.append(ivData)

        let publicKeyRef = getPublicKeyRef()
        guard let encryptedKeyData = try? SFSDKCryptoUtils.encrypt(data: fullKeyData, key: publicKeyRef, algorithm: .rsaEncryptionOAEPSHA256) else {
            fatalError("Failed to encrypt key data")
        }
        return encryptedKeyData.base64EncodedString()
    }

    private func encryptContent(usingKey key: SFEncryptionKey, data: Data) -> String {
        guard let keyData = key.key, let ivData = key.initializationVector,
              let encryptedContentData = SFSDKCryptoUtils.aes128EncryptData(data, withKey: keyData, iv: ivData) else {
            fatalError("Failed to encrypt content data")
        }
        return encryptedContentData.base64EncodedString()
    }

    private func getPublicKeyRef() -> SecKey {
        let keyName = PushNotificationManagerConstants.kPNEncryptionKeyName
        let keyLength = UInt(PushNotificationManagerConstants.kPNEncryptionKeyLength)
        if let publicKeyRef = SFSDKCryptoUtils.getRSAPublicKeyRef(withName: keyName, keyLength: keyLength) {
            return publicKeyRef
        }
        SFSDKCryptoUtils.createRSAKeyPair(withName: keyName, keyLength: keyLength, accessibleAttribute: kSecAttrAccessibleAfterFirstUnlock)
        guard let publicKeyRef = SFSDKCryptoUtils.getRSAPublicKeyRef(withName: keyName, keyLength: keyLength) else {
            fatalError("Could not get RSA public key.")
        }
        return publicKeyRef
    }
}
