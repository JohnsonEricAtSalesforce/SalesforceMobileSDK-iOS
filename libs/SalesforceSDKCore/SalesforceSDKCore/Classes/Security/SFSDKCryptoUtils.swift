// Copyright (c) 2013-present, salesforce.com, inc. All rights reserved.
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
import CommonCrypto
import Security
import LocalAuthentication

/// Default number of PBKDF derivation rounds used to generate a key.
public let kSFPBKDFDefaultNumberOfDerivationRounds: UInt = 4000

/// Default length in bytes of a PDKDF derived key.
public let kSFPBKDFDefaultDerivedKeyByteLength: UInt = 128

/// Default length in bytes for random-generated salt data.
public let kSFPBKDFDefaultSaltByteLength: UInt = 32

// RSA key constants
private let kSFRSAPublicKeyTagPrefix = "com.salesforce.rsakey.public"
private let kSFRSAPrivateKeyTagPrefix = "com.salesforce.rsakey.private"

// EC key constants
private let kSFECPublicKeyTagPrefix = "com.salesforce.eckey.public"
private let kSFECPrivateKeyTagPrefix = "com.salesforce.eckey.private"

/// Various utility methods that support cryptographic operations.
@objc(SFSDKCryptoUtils)
@objcMembers
public class SFSDKCryptoUtils: NSObject {

    // MARK: - Public Methods

    /// Creates a random string of bytes and returns them as Data.
    /// - Parameter lengthInBytes: Number of bytes to generate.
    /// - Returns: Data containing random bytes.
    @objc public class func randomByteData(withLength lengthInBytes: UInt) -> Data {
        var bytes = [UInt8](repeating: 0, count: Int(lengthInBytes))
        let status = SecRandomCopyBytes(kSecRandomDefault, Int(lengthInBytes), &bytes)
        if status == errSecSuccess {
            return Data(bytes)
        }
        return Data(repeating: 0, count: Int(lengthInBytes))
    }

    /// Creates a PBKDF2 derived key from an input key string using default parameters.
    /// - Parameter stringToHash: Plain-text string used to generate the key.
    /// - Returns: The derived key, or nil on failure.
    @objc public class func pbkdf2DerivedKey(_ stringToHash: String) -> Data? {
        let salt = randomByteData(withLength: UInt(kSFPBKDFDefaultSaltByteLength))
        return pbkdf2DerivedKey(stringToHash, salt: salt, derivationRounds: UInt(kSFPBKDFDefaultNumberOfDerivationRounds), keyLength: UInt(kSFPBKDFDefaultDerivedKeyByteLength))
    }

    /// Creates a PBKDF2-derived key from an input key string.
    /// - Parameters:
    ///   - stringToHash: Base string to use for the derived key.
    ///   - salt: Salt to append to the string.
    ///   - numDerivationRounds: Number of derivation rounds.
    ///   - derivedKeyLength: Requested derived key length.
    /// - Returns: The derived key, or nil on failure.
    @objc public class func pbkdf2DerivedKey(_ stringToHash: String, salt: Data, derivationRounds numDerivationRounds: UInt, keyLength derivedKeyLength: UInt) -> Data? {
        guard let stringData = stringToHash.data(using: .utf8) else { return nil }
        var key = [UInt8](repeating: 0, count: Int(derivedKeyLength))
        let result = stringData.withUnsafeBytes { stringBytes in
            salt.withUnsafeBytes { saltBytes in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    stringBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                    stringData.count,
                    saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    UInt32(numDerivationRounds),
                    &key,
                    Int(derivedKeyLength)
                )
            }
        }
        if result != 0 {
            return nil
        }
        return Data(key)
    }

    /// Encrypt data using AES-128.
    @objc public class func aes128EncryptData(_ data: Data, withKey key: Data, iv: Data) -> Data? {
        return aesEncryptData(data, withKey: key, keyLength: kCCKeySizeAES128, iv: iv)
    }

    /// Decrypt data using AES-128.
    @objc public class func aes128DecryptData(_ data: Data, withKey key: Data, iv: Data) -> Data? {
        return aesDecryptData(data, withKey: key, keyLength: kCCKeySizeAES128, iv: iv)
    }

    /// Encrypt data using AES-256.
    @objc public class func aes256EncryptData(_ data: Data, withKey key: Data, iv: Data) -> Data? {
        return aesEncryptData(data, withKey: key, keyLength: kCCKeySizeAES256, iv: iv)
    }

    /// Decrypt data using AES-256.
    @objc public class func aes256DecryptData(_ data: Data, withKey key: Data, iv: Data) -> Data? {
        return aesDecryptData(data, withKey: key, keyLength: kCCKeySizeAES256, iv: iv)
    }

    /// Create RSA key pair with given key name and length.
    @objc public class func createRSAKeyPair(withName keyName: String, keyLength length: UInt, accessibleAttribute: CFTypeRef) {
        let privateTagString = "\(kSFRSAPrivateKeyTagPrefix).\(keyName)"
        guard let privateTag = privateTagString.data(using: .utf8) else { return }
        let publicTagString = "\(kSFRSAPublicKeyTagPrefix).\(keyName)"
        guard let publicTag = publicTagString.data(using: .utf8) else { return }

        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: NSNumber(value: length),
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: privateTag,
                kSecAttrAccessible as String: accessibleAttribute
            ],
            kSecPublicKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: publicTag,
                kSecAttrAccessible as String: accessibleAttribute
            ]
        ]

        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            let err = error?.takeRetainedValue()
            SFSDKCoreLogger.e(Self.self, format: "Error creating RSA private Key with name %@ and length %lu. Error code: %@", keyName, length, err?.localizedDescription ?? "unknown")
            return
        }

        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            SFSDKCoreLogger.e(Self.self, format: "Error creating RSA public key with name %@ and length %lu.", keyName, length)
            return
        }
        _ = publicKey // Release handled by ARC
    }

    /// Retrieve an RSA public key as String.
    @objc public class func getRSAPublicKeyString(withName keyName: String, keyLength length: UInt) -> String? {
        let tagString = "\(kSFRSAPublicKeyTagPrefix).\(keyName)"
        guard let keyBits = getRSAKeyData(withTag: tagString, keyLength: length) else { return nil }
        guard let pemData = getRSAPublicKeyAsDER(keyBits) else { return nil }
        return pemData.base64EncodedString(options: .lineLength64Characters)
    }

    /// Retrieve an RSA private key as Data.
    @objc public class func getRSAPrivateKeyData(withName keyName: String, keyLength length: UInt) -> Data? {
        let tagString = "\(kSFRSAPrivateKeyTagPrefix).\(keyName)"
        return getRSAKeyData(withTag: tagString, keyLength: length)
    }

    /// Get RSA public SecKeyRef.
    @objc public class func getRSAPublicKeyRef(withName keyName: String, keyLength length: UInt) -> SecKey? {
        let tagString = "\(kSFRSAPublicKeyTagPrefix).\(keyName)"
        return getRSAKeyRef(withTag: tagString, keyLength: length)
    }

    /// Get RSA private SecKeyRef.
    @objc public class func getRSAPrivateKeyRef(withName keyName: String, keyLength length: UInt) -> SecKey? {
        let tagString = "\(kSFRSAPrivateKeyTagPrefix).\(keyName)"
        return getRSAKeyRef(withTag: tagString, keyLength: length)
    }

    /// Check for availability of the secure enclave.
    @objc public class func isSecureEnclaveAvailable() -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        let context = LAContext()
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        #endif
    }

    /// Create EC key pair.
    @objc @discardableResult
    public class func createECKeyPair(withName keyName: String, accessibleAttribute: CFTypeRef, useSecureEnclave: Bool) -> Bool {
        let privateTagString = "\(kSFECPrivateKeyTagPrefix).\(keyName)"
        guard let privateTag = privateTagString.data(using: .utf8) else { return false }
        let publicTagString = "\(kSFECPublicKeyTagPrefix).\(keyName)"
        guard let publicTag = publicTagString.data(using: .utf8) else { return false }

        var privateKeyAttributes: [String: Any] = [
            kSecAttrIsPermanent as String: true,
            kSecAttrApplicationTag as String: privateTag
        ]

        if useSecureEnclave {
            var errorRef: Unmanaged<CFError>?
            let privateAccess = SecAccessControlCreateWithFlags(
                kCFAllocatorDefault,
                accessibleAttribute,
                .privateKeyUsage,
                &errorRef
            )
            if errorRef == nil, let access = privateAccess {
                privateKeyAttributes[kSecAttrAccessControl as String] = access
            }
        } else {
            privateKeyAttributes[kSecAttrAccessible as String] = accessibleAttribute
        }

        let publicKeyAttributes: [String: Any] = [
            kSecAttrIsPermanent as String: true,
            kSecAttrApplicationTag as String: publicTag,
            kSecAttrAccessible as String: accessibleAttribute
        ]

        var keyPairAttributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256
        ]
        if useSecureEnclave {
            keyPairAttributes[kSecAttrTokenID as String] = kSecAttrTokenIDSecureEnclave
        }
        keyPairAttributes[kSecPrivateKeyAttrs as String] = privateKeyAttributes
        keyPairAttributes[kSecPublicKeyAttrs as String] = publicKeyAttributes

        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(keyPairAttributes as CFDictionary, &error) else {
            let err = error?.takeRetainedValue()
            SFSDKCoreLogger.e(Self.self, format: "Error creating EC private Key with name %@. Error code: %@", keyName, err?.localizedDescription ?? "unknown")
            return false
        }

        guard SecKeyCopyPublicKey(privateKey) != nil else {
            SFSDKCoreLogger.e(Self.self, format: "Error creating EC public key with name %@.", keyName)
            return false
        }

        return true
    }

    /// Delete an EC key pair.
    @objc @discardableResult
    public class func deleteECKeyPair(withName keyName: String) -> Bool {
        let deletedPublic = deleteKey(byTag: "\(kSFECPublicKeyTagPrefix).\(keyName)")
        let deletedPrivate = deleteKey(byTag: "\(kSFECPrivateKeyTagPrefix).\(keyName)")
        return deletedPublic && deletedPrivate
    }

    /// Get EC public SecKeyRef.
    @objc public class func getECPublicKeyRef(withName keyName: String) -> SecKey? {
        return getECKeyRef(withTag: "\(kSFECPublicKeyTagPrefix).\(keyName)")
    }

    /// Get EC private SecKeyRef.
    @objc public class func getECPrivateKeyRef(withName keyName: String) -> SecKey? {
        return getECKeyRef(withTag: "\(kSFECPrivateKeyTagPrefix).\(keyName)")
    }

    /// Encrypt data using EC algorithm.
    @objc public class func encryptUsingEC(forData data: Data, withKeyRef keyRef: SecKey) -> Data? {
        var error: Unmanaged<CFError>?
        let encryptedData = SecKeyCreateEncryptedData(keyRef, .eciesEncryptionStandardX963SHA256AESGCM, data as CFData, &error)
        if let err = error?.takeRetainedValue() {
            SFSDKCoreLogger.e(Self.self, format: "Error encrypting data with EC key. Error code: %@", (err as Error).localizedDescription)
        }
        return encryptedData as Data?
    }

    /// Decrypt data using EC algorithm.
    @objc public class func decryptUsingEC(forData data: Data, withKeyRef keyRef: SecKey) -> Data? {
        var error: Unmanaged<CFError>?
        let decryptedData = SecKeyCreateDecryptedData(keyRef, .eciesEncryptionStandardX963SHA256AESGCM, data as CFData, &error)
        if let err = error?.takeRetainedValue() {
            SFSDKCoreLogger.e(Self.self, format: "Error decrypting data with EC key. Error code: %@", (err as Error).localizedDescription)
        }
        return decryptedData as Data?
    }

    // MARK: - Private Methods

    private class func executeCrypt(_ inData: Data, cryptor: CCCryptorRef, resultData: inout Data?) -> Bool {
        let bufferSize = CCCryptorGetOutputLength(cryptor, inData.count, true)
        let buffer = UnsafeMutableRawPointer.allocate(byteCount: bufferSize, alignment: 1)
        var bufferUsed: size_t = 0
        var totalBytes: size_t = 0

        let status = inData.withUnsafeBytes { inBytes -> CCCryptorStatus in
            CCCryptorUpdate(cryptor, inBytes.baseAddress, inData.count, buffer, bufferSize, &bufferUsed)
        }
        if status != CCCryptorStatus(kCCSuccess) {
            SFSDKCoreLogger.e(Self.self, format: "CCCryptorUpdate() failed with status code: %d", status)
            buffer.deallocate()
            return false
        }
        totalBytes += bufferUsed

        let finalStatus = CCCryptorFinal(cryptor, buffer.advanced(by: bufferUsed), bufferSize - bufferUsed, &bufferUsed)
        if finalStatus != CCCryptorStatus(kCCSuccess) {
            SFSDKCoreLogger.e(Self.self, format: "CCCryptoFinal() failed with status code: %d", finalStatus)
            buffer.deallocate()
            return false
        }
        totalBytes += bufferUsed

        resultData = Data(bytesNoCopy: buffer, count: totalBytes, deallocator: .custom({ ptr, _ in ptr.deallocate() }))
        return true
    }

    private class func aesEncryptData(_ data: Data, withKey key: Data, keyLength: Int, iv: Data) -> Data? {
        var mutableKey = key
        mutableKey.count = keyLength
        var mutableIv = iv
        mutableIv.count = kCCBlockSizeAES128

        var cryptor: CCCryptorRef?
        let status = mutableKey.withUnsafeBytes { keyBytes in
            mutableIv.withUnsafeBytes { ivBytes in
                CCCryptorCreate(
                    CCOperation(kCCEncrypt),
                    CCAlgorithm(kCCAlgorithmAES),
                    CCOptions(kCCOptionPKCS7Padding),
                    keyBytes.baseAddress, mutableKey.count,
                    ivBytes.baseAddress,
                    &cryptor
                )
            }
        }
        guard status == CCCryptorStatus(kCCSuccess), let theCryptor = cryptor else {
            SFSDKCoreLogger.e(Self.self, format: "Error creating encryption cryptor with CCCryptorCreate(). Status code: %d", status)
            return nil
        }

        var resultData: Data?
        let success = executeCrypt(data, cryptor: theCryptor, resultData: &resultData)
        CCCryptorRelease(theCryptor)
        return success ? resultData : nil
    }

    private class func aesDecryptData(_ data: Data, withKey key: Data, keyLength: Int, iv: Data) -> Data? {
        var mutableKey = key
        mutableKey.count = keyLength
        var mutableIv = iv
        mutableIv.count = kCCBlockSizeAES128

        var cryptor: CCCryptorRef?
        let status = mutableKey.withUnsafeBytes { keyBytes in
            mutableIv.withUnsafeBytes { ivBytes in
                CCCryptorCreate(
                    CCOperation(kCCDecrypt),
                    CCAlgorithm(kCCAlgorithmAES),
                    CCOptions(kCCOptionPKCS7Padding),
                    keyBytes.baseAddress, mutableKey.count,
                    ivBytes.baseAddress,
                    &cryptor
                )
            }
        }
        guard status == CCCryptorStatus(kCCSuccess), let theCryptor = cryptor else {
            SFSDKCoreLogger.e(Self.self, format: "Error creating decryption cryptor with CCCryptorCreate(). Status code: %d", status)
            return nil
        }

        var resultData: Data?
        let success = executeCrypt(data, cryptor: theCryptor, resultData: &resultData)
        CCCryptorRelease(theCryptor)
        return success ? resultData : nil
    }

    private class func getRSAKeyData(withTag keyTagString: String, keyLength length: UInt) -> Data? {
        guard let tag = keyTagString.data(using: .utf8) else { return nil }
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecReturnData as String: true,
            kSecAttrKeySizeInBits as String: NSNumber(value: length)
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        if status != errSecSuccess {
            let error = NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: nil)
            SFSDKCoreLogger.e(Self.self, format: "Error getting RSA key with tag %@ and length %lu. Error code: %@", keyTagString, length, error.localizedDescription)
            return nil
        }
        return result as? Data
    }

    private class func getRSAKeyRef(withTag keyTagString: String, keyLength length: UInt) -> SecKey? {
        guard let tag = keyTagString.data(using: .utf8) else { return nil }
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecReturnRef as String: true,
            kSecAttrKeySizeInBits as String: NSNumber(value: length)
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        if status != errSecSuccess {
            let error = NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: nil)
            SFSDKCoreLogger.e(Self.self, format: "Error getting RSA SecKeyRef with tag %@ and length %lu. Error code: %@", keyTagString, length, error.localizedDescription)
            return nil
        }
        // swiftlint:disable:next force_cast
        return (result as! SecKey)
    }

    private class func getRSAPublicKeyAsDER(_ keyData: Data) -> Data? {
        let encodedRSAEncryptionOID: [UInt8] = [
            0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86,
            0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00
        ]

        let bitstringEncLength: Int
        if keyData.count + 1 < 128 {
            bitstringEncLength = 1
        } else {
            bitstringEncLength = ((keyData.count + 1) / 256) + 2
        }

        var encKey = Data()
        var builder = [UInt8](repeating: 0, count: 15)

        // SEQUENCE
        builder[0] = 0x30
        let totalSize = encodedRSAEncryptionOID.count + 2 + bitstringEncLength + keyData.count
        let j = encodeLength(&builder[1...], length: totalSize)
        encKey.append(contentsOf: builder[0..<(j + 1)])

        // OID
        encKey.append(contentsOf: encodedRSAEncryptionOID)

        // BIT STRING
        builder[0] = 0x03
        let j2 = encodeLength(&builder[1...], length: keyData.count + 1)
        builder[Int(j2) + 1] = 0x00
        encKey.append(contentsOf: builder[0..<(Int(j2) + 2)])

        // Actual key data
        encKey.append(keyData)

        return encKey
    }

    private class func encodeLength(_ buf: inout ArraySlice<UInt8>, length: Int) -> Int {
        if length < 128 {
            buf[buf.startIndex] = UInt8(length)
            return 1
        }
        let i = (length / 256) + 1
        buf[buf.startIndex] = UInt8(i + 0x80)
        var len = length
        for idx in 0..<i {
            buf[buf.startIndex + i - idx] = UInt8(len & 0xFF)
            len = len >> 8
        }
        return i + 1
    }

    private class func getECKeyRef(withTag keyTagString: String) -> SecKey? {
        guard let keyTag = keyTagString.data(using: .utf8) else { return nil }
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: keyTag,
            kSecReturnRef as String: true
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status != errSecSuccess && status != errSecItemNotFound {
            let error = NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: nil)
            SFSDKCoreLogger.e(Self.self, format: "Error getting EC SecKeyRef with tag %@. Error code: %@", keyTagString, error.localizedDescription)
            return nil
        }
        return result as! SecKey?
    }

    private class func deleteKey(byTag keyTagString: String) -> Bool {
        guard let keyTag = keyTagString.data(using: .utf8) else { return false }
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: keyTag
        ]

        var status = SecItemDelete(query as CFDictionary)
        while status == errSecDuplicateItem {
            status = SecItemDelete(query as CFDictionary)
        }
        if status != errSecSuccess && status != errSecItemNotFound {
            let error = NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: nil)
            SFSDKCoreLogger.e(Self.self, format: "Error deleting EC key with tag %@. Error code: %@", keyTagString, error.localizedDescription)
            return false
        }
        return true
    }
}
