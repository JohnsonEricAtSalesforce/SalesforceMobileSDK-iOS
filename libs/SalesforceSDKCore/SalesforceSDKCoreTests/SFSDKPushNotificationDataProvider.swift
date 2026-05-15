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
@testable import SalesforceSDKCore
import SalesforceSDKCommon

/// Test helper that provides encrypted push notification data for testing decryption logic.
final class SFSDKPushNotificationDataProvider: NSObject {

    private static let encryptionKeyLengthBytes: UInt = 16
    private static let encryptionIVLengthBytes: UInt = 16

    let contentJSONData: Data?

    var userInfoDict: [String: Any] {
        let key = createEncryptionKey()
        var userInfo: [String: Any] = [
            kRemoteNotificationKeyEncrypted: true,
            kRemoteNotificationKeySecret: encryptKeyUsingRSAPublicKey(key),
            kRemoteNotificationKeyAps: [
                kRemoteNotificationKeyAlert: [
                    kRemoteNotificationKeyTitle: "Title",
                    kRemoteNotificationKeyBody: "Body",
                    "key1": "value1"
                ]
            ]
        ]

        if let contentData = contentJSONData {
            userInfo[kRemoteNotificationKeyContent] = encryptContent(contentData, usingKey: key)
        }
        return userInfo
    }

    init(contentObj: Any?) {
        if let obj = contentObj {
            self.contentJSONData = SFJsonUtils.jsonDataRepresentation(obj)
        } else {
            self.contentJSONData = nil
        }
        super.init()
    }

    init(contentJSON: String?) {
        if let json = contentJSON {
            self.contentJSONData = json.data(using: .utf8)
        } else {
            self.contentJSONData = nil
        }
        super.init()
    }

    // MARK: - Private

    private func createEncryptionKey() -> EncryptionKey {
        let keyBytes = CryptoUtils.randomByteData(withLength: Self.encryptionKeyLengthBytes)
        let ivBytes = CryptoUtils.randomByteData(withLength: Self.encryptionIVLengthBytes)
        return EncryptionKey(data: keyBytes, initializationVector: ivBytes)
    }

    private func encryptKeyUsingRSAPublicKey(_ key: EncryptionKey) -> String {
        var fullKeyData = Data()
        if let keyData = key.key {
            fullKeyData.append(keyData)
        }
        fullKeyData.append(key.initializationVector)

        let publicKeyRef = getPublicKeyRef()
        var error: Unmanaged<CFError>?
        let encryptedKeyData = SecKeyCreateEncryptedData(publicKeyRef, .rsaEncryptionOAEPSHA256, fullKeyData as CFData, &error) as Data?
        return encryptedKeyData?.base64EncodedString() ?? ""
    }

    private func encryptContent(_ contentData: Data, usingKey key: EncryptionKey) -> String {
        guard let keyData = key.key else { return "" }
        let encryptedData = CryptoUtils.aes128EncryptData(contentData, withKey: keyData, iv: key.initializationVector)
        return encryptedData?.base64EncodedString() ?? ""
    }

    private func getPublicKeyRef() -> SecKey {
        let name = PushNotificationManagerConstants.kPNEncryptionKeyName
        let length = PushNotificationManagerConstants.kPNEncryptionKeyLength

        if let publicKeyRef = CryptoUtils.getRSAPublicKeyRef(withName: name, keyLength: length) {
            return publicKeyRef
        }

        CryptoUtils.createRSAKeyPair(withName: name, keyLength: length, accessibleAttribute: kSecAttrAccessibleAfterFirstUnlock)
        guard let publicKeyRef = CryptoUtils.getRSAPublicKeyRef(withName: name, keyLength: length) else {
            fatalError("Could not get RSA public key.")
        }
        return publicKeyRef
    }
}
