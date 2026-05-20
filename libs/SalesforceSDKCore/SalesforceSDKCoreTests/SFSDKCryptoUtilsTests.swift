/*
 Copyright (c) 2013-present, salesforce.com, inc. All rights reserved.

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
@testable import SalesforceSDKCore

class SFSDKCryptoUtilsTests: XCTestCase {

    func testRandomDataGenerator() {
        let randomStringByteLength: UInt = 32
        let numDataStrings: Int = 5000

        var dataStringArray = [Data]()
        for _ in 0..<numDataStrings {
            dataStringArray.append(SFSDKCryptoUtils.randomByteData(withLength: randomStringByteLength))
        }

        for i in 0..<numDataStrings {
            for j in (i + 1)..<numDataStrings {
                XCTAssertNotEqual(dataStringArray[i], dataStringArray[j], "Random data strings at index \(i) and \(j) are equal. Not enough entropy!")
            }
        }
    }

    func testSamePBKDFKeysWithSameInputs() {
        let initialPasscode = "Hello123"
        let verifyPasscode = "Hello123"
        let salt = SFSDKCryptoUtils.randomByteData(withLength: 32)
        let numDerivationRounds: UInt = 100
        let derivedKeyLength: UInt = 128

        let initialDerivedKey = SFSDKCryptoUtils.pbkdf2DerivedKey(initialPasscode, salt: salt, derivationRounds: numDerivationRounds, keyLength: derivedKeyLength)
        let verifyDerivedKey = SFSDKCryptoUtils.pbkdf2DerivedKey(verifyPasscode, salt: salt, derivationRounds: numDerivationRounds, keyLength: derivedKeyLength)
        XCTAssertEqual(initialDerivedKey, verifyDerivedKey, "Generated keys with same input parameters should be equal.")
    }

    func testDifferentPBKDFKeyWithDifferentSalt() {
        let passcode = "Hello123"
        let saltByteLength: UInt = 32
        let numDerivationRounds: UInt = 100
        let derivedKeyLength: UInt = 128

        let initialSalt = SFSDKCryptoUtils.randomByteData(withLength: saltByteLength)
        let newSalt = SFSDKCryptoUtils.randomByteData(withLength: saltByteLength)
        let initialDerivedKey = SFSDKCryptoUtils.pbkdf2DerivedKey(passcode, salt: initialSalt, derivationRounds: numDerivationRounds, keyLength: derivedKeyLength)
        let verifyDerivedKey = SFSDKCryptoUtils.pbkdf2DerivedKey(passcode, salt: newSalt, derivationRounds: numDerivationRounds, keyLength: derivedKeyLength)
        XCTAssertNotEqual(initialDerivedKey, verifyDerivedKey, "Generated keys with different salts should not be equal.")
    }

    func testDifferentPBKDFKeyWithDifferentDerivationRounds() {
        let passcode = "Hello123"
        let salt = SFSDKCryptoUtils.randomByteData(withLength: 32)
        let derivedKeyLength: UInt = 128

        let initialNumDerivationRounds: UInt = 100
        let initialDerivedKey = SFSDKCryptoUtils.pbkdf2DerivedKey(passcode, salt: salt, derivationRounds: initialNumDerivationRounds, keyLength: derivedKeyLength)

        let newNumDerivationRounds: UInt = initialNumDerivationRounds + 1
        let verifyDerivedKey = SFSDKCryptoUtils.pbkdf2DerivedKey(passcode, salt: salt, derivationRounds: newNumDerivationRounds, keyLength: derivedKeyLength)

        XCTAssertNotEqual(initialDerivedKey, verifyDerivedKey, "Generated keys with different derivation rounds should not be equal.")
    }

    func testDifferentPBKDFKeyWithDifferentDerivedKeyLength() {
        let passcode = "Hello123"
        let salt = SFSDKCryptoUtils.randomByteData(withLength: 32)
        let numDerivationRounds: UInt = 100

        let initialDerivedKeyLength: UInt = 128
        let initialDerivedKey = SFSDKCryptoUtils.pbkdf2DerivedKey(passcode, salt: salt, derivationRounds: numDerivationRounds, keyLength: initialDerivedKeyLength)

        let newDerivedKeyLength: UInt = initialDerivedKeyLength + 1
        let verifyDerivedKey = SFSDKCryptoUtils.pbkdf2DerivedKey(passcode, salt: salt, derivationRounds: numDerivationRounds, keyLength: newDerivedKeyLength)
        XCTAssertNotEqual(initialDerivedKey, verifyDerivedKey, "Generated keys with different derived key lengths should not be equal.")
    }

    func testAes256EncryptionDecryption() {
        guard let origData = "The quick brown fox...".data(using: .utf8),
              let keyData = "My encryption key".data(using: .utf8),
              let ivData = "Here's an iv staging string".data(using: .utf8) else {
            XCTFail("Failed to create test data")
            return
        }

        guard let encryptedData = SFSDKCryptoUtils.aes256EncryptData(origData, withKey: keyData, iv: ivData) else {
            XCTFail("Encryption returned nil")
            return
        }
        XCTAssertNotEqual(encryptedData, origData, "Encrypted data should not be the same as original data.")

        // Clean decryption should pass.
        let decryptedData = SFSDKCryptoUtils.aes256DecryptData(encryptedData, withKey: keyData, iv: ivData)
        XCTAssertEqual(decryptedData, origData, "Decrypted data should match original data.")

        // Bad decryption key data should return different data.
        guard let badKey = "The wrong key".data(using: .utf8),
              let badIv = "The wrong iv".data(using: .utf8) else {
            XCTFail("Failed to create bad key data")
            return
        }
        let badDecryptData1 = SFSDKCryptoUtils.aes256DecryptData(encryptedData, withKey: badKey, iv: ivData)
        XCTAssertNotEqual(badDecryptData1, origData, "Wrong encryption key should return different data on decrypt.")
        let badDecryptData2 = SFSDKCryptoUtils.aes256DecryptData(encryptedData, withKey: keyData, iv: badIv)
        XCTAssertNotEqual(badDecryptData2, origData, "Wrong initialization vector should return different data on decrypt.")
        let badDecryptData3 = SFSDKCryptoUtils.aes256DecryptData(encryptedData, withKey: badKey, iv: badIv)
        XCTAssertNotEqual(badDecryptData3, origData, "Wrong key and initialization vector should return different data on decrypt.")
    }

    func testAes128EncryptionDecryption() {
        guard let origData = "The quick brown fox...".data(using: .utf8),
              let keyData = "My encryption key".data(using: .utf8),
              let ivData = "Here's an iv staging string".data(using: .utf8) else {
            XCTFail("Failed to create test data")
            return
        }

        guard let encryptedData = SFSDKCryptoUtils.aes128EncryptData(origData, withKey: keyData, iv: ivData) else {
            XCTFail("Encryption returned nil")
            return
        }
        XCTAssertNotEqual(encryptedData, origData, "Encrypted data should not be the same as original data.")

        // Clean decryption should pass.
        let decryptedData = SFSDKCryptoUtils.aes128DecryptData(encryptedData, withKey: keyData, iv: ivData)
        XCTAssertEqual(decryptedData, origData, "Decrypted data should match original data.")

        // Bad decryption key data should return different data.
        guard let badKey = "The wrong key".data(using: .utf8),
              let badIv = "The wrong iv".data(using: .utf8) else {
            XCTFail("Failed to create bad key data")
            return
        }
        let badDecryptData1 = SFSDKCryptoUtils.aes128DecryptData(encryptedData, withKey: badKey, iv: ivData)
        XCTAssertNotEqual(badDecryptData1, origData, "Wrong encryption key should return different data on decrypt.")
        let badDecryptData2 = SFSDKCryptoUtils.aes128DecryptData(encryptedData, withKey: keyData, iv: badIv)
        XCTAssertNotEqual(badDecryptData2, origData, "Wrong initialization vector should return different data on decrypt.")
        let badDecryptData3 = SFSDKCryptoUtils.aes128DecryptData(encryptedData, withKey: badKey, iv: badIv)
        XCTAssertNotEqual(badDecryptData3, origData, "Wrong key and initialization vector should return different data on decrypt.")
    }

    func testRSAKeyGeneration() {
        SFSDKCryptoUtils.createRSAKeyPair(withName: "test", keyLength: 2048, accessibleAttribute: kSecAttrAccessibleAfterFirstUnlock)
        let privateKeyData = SFSDKCryptoUtils.getRSAPrivateKeyData(withName: "test", keyLength: 2048)
        XCTAssertNotNil(privateKeyData)
        let publicKeyString = SFSDKCryptoUtils.getRSAPublicKeyString(withName: "test", keyLength: 2048)
        XCTAssertNotNil(publicKeyString)
    }

    func testRSAKeyGenerationDifferentKey() {
        SFSDKCryptoUtils.createRSAKeyPair(withName: "test1", keyLength: 2048, accessibleAttribute: kSecAttrAccessibleAfterFirstUnlock)
        SFSDKCryptoUtils.createRSAKeyPair(withName: "test2", keyLength: 2048, accessibleAttribute: kSecAttrAccessibleAfterFirstUnlock)

        let privateKeyData1 = SFSDKCryptoUtils.getRSAPrivateKeyData(withName: "test1", keyLength: 2048)
        XCTAssertNotNil(privateKeyData1)

        let privateKeyData2 = SFSDKCryptoUtils.getRSAPrivateKeyData(withName: "test2", keyLength: 2048)
        XCTAssertNotNil(privateKeyData2)

        XCTAssertNotEqual(privateKeyData1, privateKeyData2, "should get different private key data with different keynames")

        let public1KeyString = SFSDKCryptoUtils.getRSAPublicKeyString(withName: "test1", keyLength: 2048)
        XCTAssertNotNil(public1KeyString)
        XCTAssertFalse(public1KeyString?.isEmpty ?? true)

        let public2KeyString = SFSDKCryptoUtils.getRSAPublicKeyString(withName: "test2", keyLength: 2048)
        XCTAssertNotNil(public2KeyString)
        XCTAssertFalse(public2KeyString?.isEmpty ?? true)

        XCTAssertNotEqual(public1KeyString, public2KeyString, "should get different public key strings with different keynames")

        SFSDKCryptoUtils.createRSAKeyPair(withName: "test1", keyLength: 1024, accessibleAttribute: kSecAttrAccessibleAfterFirstUnlock)

        let privateKeyData3 = SFSDKCryptoUtils.getRSAPrivateKeyData(withName: "test1", keyLength: 1024)
        XCTAssertNotNil(privateKeyData3)

        let public3KeyString = SFSDKCryptoUtils.getRSAPublicKeyString(withName: "test1", keyLength: 1024)
        XCTAssertNotNil(public3KeyString)
        XCTAssertFalse(public3KeyString?.isEmpty ?? true)

        XCTAssertNotEqual(public3KeyString, public1KeyString, "should get different public key strings with different sizes")
        XCTAssertNotEqual(privateKeyData3, privateKeyData1, "should get different private key strings with different sizes")
    }

    func testRSAEncryptionAndDecryptionWrongKeys() {
        let keySize: UInt = 2048

        SFSDKCryptoUtils.createRSAKeyPair(withName: "test1", keyLength: keySize, accessibleAttribute: kSecAttrAccessibleAfterFirstUnlock)
        SFSDKCryptoUtils.createRSAKeyPair(withName: "test", keyLength: keySize, accessibleAttribute: kSecAttrAccessibleAfterFirstUnlock)

        guard let publicKeyRef = SFSDKCryptoUtils.getRSAPublicKeyRef(withName: "test1", keyLength: keySize),
              let privateKeyRef = SFSDKCryptoUtils.getRSAPrivateKeyRef(withName: "test", keyLength: keySize) else {
            XCTFail("Failed to get key refs")
            return
        }

        // Encrypt data
        let testString = "This is a test"
        guard let testData = testString.data(using: .utf8) else {
            XCTFail("Failed to create test data")
            return
        }
        let encryptedData: Data
        do {
            encryptedData = try SFSDKCryptoUtils.encrypt(data: testData, key: publicKeyRef, algorithm: .rsaEncryptionOAEPSHA256)
        } catch {
            XCTFail("Encryption failed: \(error)")
            return
        }

        // Decrypt data
        let decryptedData = try? SFSDKCryptoUtils.decrypt(data: encryptedData, key: privateKeyRef, algorithm: .rsaEncryptionOAEPSHA256)
        let result = decryptedData.flatMap { String(data: $0, encoding: .utf8) }
        XCTAssertNotEqual(testString, result)
    }

    func testECKeyGenerationDeletion() {
        // Keys should not exist already
        let privateKeyRef = SFSDKCryptoUtils.getECPrivateKeyRef(withName: "test")
        let publicKeyRef = SFSDKCryptoUtils.getECPublicKeyRef(withName: "test")
        XCTAssertNil(privateKeyRef, "Private key should not have been found")
        XCTAssertNil(publicKeyRef, "Public key should not have been found")

        // Create keys
        SFSDKCryptoUtils.createECKeyPair(withName: "test", accessibleAttribute: kSecAttrAccessibleAfterFirstUnlock, useSecureEnclave: SFSDKCryptoUtils.isSecureEnclaveAvailable())

        // Keys should exist
        let foundPrivateKeyRef = SFSDKCryptoUtils.getECPrivateKeyRef(withName: "test")
        let foundPublicKeyRef = SFSDKCryptoUtils.getECPublicKeyRef(withName: "test")
        XCTAssertNotNil(foundPrivateKeyRef, "Private key should have been found")
        XCTAssertNotNil(foundPublicKeyRef, "Public key should have been found")

        // Delete keys
        SFSDKCryptoUtils.deleteECKeyPair(withName: "test")
        let deletedPrivateKeyRef = SFSDKCryptoUtils.getECPrivateKeyRef(withName: "test")
        let deletedPublicKeyRef = SFSDKCryptoUtils.getECPublicKeyRef(withName: "test")
        XCTAssertNil(deletedPrivateKeyRef, "Private key should no longer exist")
        XCTAssertNil(deletedPublicKeyRef, "Public key should no longer exist")
    }

    func testECEncryptionAndDecryptionForData() {
        // Create keys
        SFSDKCryptoUtils.createECKeyPair(withName: "test", accessibleAttribute: kSecAttrAccessibleAfterFirstUnlock, useSecureEnclave: SFSDKCryptoUtils.isSecureEnclaveAvailable())
        guard let privateKeyRef = SFSDKCryptoUtils.getECPrivateKeyRef(withName: "test"),
              let publicKeyRef = SFSDKCryptoUtils.getECPublicKeyRef(withName: "test") else {
            XCTFail("Failed to get EC key refs")
            return
        }

        guard let testData = "test data".data(using: .utf8) else {
            XCTFail("Failed to create test data")
            return
        }
        guard let encryptedData = SFSDKCryptoUtils.encryptUsingEC(forData: testData, withKeyRef: publicKeyRef) else {
            XCTFail("EC encryption failed")
            return
        }
        let decryptedData = SFSDKCryptoUtils.decryptUsingEC(forData: encryptedData, withKeyRef: privateKeyRef)
        XCTAssertNotEqual(testData, encryptedData, "Encrypted data should be different from data")
        XCTAssertEqual(testData, decryptedData, "Decrypted data should be identical to data")

        // Delete keys
        SFSDKCryptoUtils.deleteECKeyPair(withName: "test")
    }
}
