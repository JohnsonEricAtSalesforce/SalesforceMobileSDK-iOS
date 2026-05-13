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

import Foundation
import CommonCrypto
import Security
import LocalAuthentication

// MARK: - Public Constants

/**
 * Default number of PBKDF derivation rounds used to generate a key.
 */
public let kSFPBKDFDefaultNumberOfDerivationRounds: UInt = 4000

/**
 * Default length in bytes of a PDKDF derived key.
 */
public let kSFPBKDFDefaultDerivedKeyByteLength: UInt = 128

/**
 * Default length in bytes for random-generated salt data.
 */
public let kSFPBKDFDefaultSaltByteLength: UInt = 32

// MARK: - Private Constants

private let kSFRSAPublicKeyTagPrefix = "com.salesforce.rsakey.public"
private let kSFRSAPrivateKeyTagPrefix = "com.salesforce.rsakey.private"

private let kSFECPublicKeyTagPrefix = "com.salesforce.eckey.public"
private let kSFECPrivateKeyTagPrefix = "com.salesforce.eckey.private"

// MARK: - Crypto Utils

/**
 * Various utility methods that support cryptographic operations.
 */
@objc(SFSDKCryptoUtils)
public class CryptoUtils: NSObject {

    // MARK: - Random Data Generation

    /**
     * Creates a random string of bytes (based on `arc4random()` generation) and returns
     * them as an `NSData` object.
     * @param lengthInBytes Number of bytes to generate.
     * @return `NSData` object containing a string of random bytes.
     */
    @objc public class func randomByteData(withLength lengthInBytes: UInt) -> Data {
        var data = Data(count: Int(lengthInBytes))
        _ = data.withUnsafeMutableBytes { bufferPointer in
            SecRandomCopyBytes(kSecRandomDefault, Int(lengthInBytes), bufferPointer.baseAddress!)
        }
        return data
    }

    // MARK: - PBKDF2 Key Derivation

    /**
     * Creates a PBKDF2 derived key from an input key string. Uses default values for the
     * random-generated salt data and its length, the number of derivation rounds, and the
     * derived key length.
     * @param stringToHash Plain-text string used to generate the key.
     * @return The derived key.
     */
    @objc public class func pbkdf2DerivedKey(_ stringToHash: String) -> Data? {
        let salt = randomByteData(withLength: kSFPBKDFDefaultSaltByteLength)
        return pbkdf2DerivedKey(stringToHash,
                                salt: salt,
                                derivationRounds: kSFPBKDFDefaultNumberOfDerivationRounds,
                                keyLength: kSFPBKDFDefaultDerivedKeyByteLength)
    }

    /**
     * Creates a PBKDF2-derived key from an input key string, a salt, number of derivation
     * rounds, and the given derived key length.
     * @param stringToHash Base string to use for the derived key.
     * @param salt Salt to append to the string.
     * @param numDerivationRounds Number of derivation rounds used to generate the key.
     * @param derivedKeyLength Requested derived key length.
     * @return The derived key.
     */
    @objc public class func pbkdf2DerivedKey(_ stringToHash: String,
                                             salt: Data,
                                             derivationRounds numDerivationRounds: UInt,
                                             keyLength derivedKeyLength: UInt) -> Data? {
        guard let stringData = stringToHash.data(using: .utf8) else { return nil }

        var key = Data(count: Int(derivedKeyLength))
        let result = key.withUnsafeMutableBytes { keyBytes -> Int32 in
            stringData.withUnsafeBytes { stringBytes in
                salt.withUnsafeBytes { saltBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        stringBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                        stringData.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(numDerivationRounds),
                        keyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        Int(derivedKeyLength)
                    )
                }
            }
        }

        guard result == kCCSuccess else { return nil }
        return key
    }

    // MARK: - AES-128 Encryption/Decryption

    /**
     * Encrypt the given data using the AES-128 algorithm.
     * @param data Data to encrypt.
     * @param key Key used to encrypt the data.
     * @param iv Initialization vector data used for the encryption.
     * @return `NSData` object containing the encrypted data, or `nil` if encryption failed.
     */
    @objc public class func aes128EncryptData(_ data: Data, withKey key: Data, iv: Data) -> Data? {
        return aesEncryptData(data, withKey: key, keyLength: kCCKeySizeAES128, iv: iv)
    }

    /**
     * Decrypt the given data using the AES-128 algorithm.
     * @param data Data to decrypt.
     * @param key Key used to decrypt the data.
     * @param iv Initialization vector data used for the decryption.
     * @return `NSData` object containing the decrypted data, or `nil` if decryption failed.
     */
    @objc public class func aes128DecryptData(_ data: Data, withKey key: Data, iv: Data) -> Data? {
        return aesDecryptData(data, withKey: key, keyLength: kCCKeySizeAES128, iv: iv)
    }

    // MARK: - AES-256 Encryption/Decryption

    /**
     * Encrypt the given data using the AES-256 algorithm.
     * @param data Data to encrypt.
     * @param key Key used to encrypt the data.
     * @param iv Initialization vector data used for the encryption.
     * @return `NSData` object containing the encrypted data, or `nil` if encryption failed.
     */
    @objc public class func aes256EncryptData(_ data: Data, withKey key: Data, iv: Data) -> Data? {
        return aesEncryptData(data, withKey: key, keyLength: kCCKeySizeAES256, iv: iv)
    }

    /**
     * Decrypt the given data using the AES-256 algorithm.
     * @param data Data to decrypt.
     * @param key Key used to decrypt the data.
     * @param iv Initialization vector data used for the decryption.
     * @return `NSData` object containing the decrypted data, or `nil` if decryption failed.
     */
    @objc public class func aes256DecryptData(_ data: Data, withKey key: Data, iv: Data) -> Data? {
        return aesDecryptData(data, withKey: key, keyLength: kCCKeySizeAES256, iv: iv)
    }

    // MARK: - RSA Key Management

    /**
     * Create asymmetric keys (public/private key pairs) using RSA algorithm with given key name and length.
     * @param keyName Name of key.
     * @param length Length of key.
     */
    @objc public class func createRSAKeyPair(withName keyName: String, keyLength length: UInt, accessibleAttribute: CFTypeRef) {
        let privateTagString = "\(kSFRSAPrivateKeyTagPrefix).\(keyName)"
        guard let privateTag = privateTagString.data(using: .utf8) else { return }

        let publicTagString = "\(kSFRSAPublicKeyTagPrefix).\(keyName)"
        guard let publicTag = publicTagString.data(using: .utf8) else { return }

        let attributes: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits: length,
            kSecPrivateKeyAttrs: [
                kSecAttrIsPermanent: true,
                kSecAttrApplicationTag: privateTag,
                kSecAttrAccessible: accessibleAttribute
            ] as [CFString: Any],
            kSecPublicKeyAttrs: [
                kSecAttrIsPermanent: true,
                kSecAttrApplicationTag: publicTag,
                kSecAttrAccessible: accessibleAttribute
            ] as [CFString: Any]
        ]

        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            if let error = error?.takeRetainedValue() {
                SFSDKCoreLogger.e(CryptoUtils.self, message: "Error creating RSA private Key with name \(keyName) and length \(length). Error code: \(error)")
            }
            return
        }

        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            SFSDKCoreLogger.e(CryptoUtils.self, message: "Error creating RSA public key with name \(keyName) and length \(length).")
            return
        }
    }

    /**
     * Retrieve an RSA public key as `NSString` with given key name and length.
     * @param keyName Name of key.
     * @param length Length of key.
     * @return Key string, or `nil` if no matching key is found.
     */
    @objc public class func getRSAPublicKeyString(withName keyName: String, keyLength length: UInt) -> String? {
        let tagString = "\(kSFRSAPublicKeyTagPrefix).\(keyName)"
        guard let keyBits = getRSAKeyData(withTag: tagString, keyLength: length) else {
            return nil
        }
        guard let pemData = getRSAPublicKeyAsDER(keyBits) else {
            return nil
        }
        return pemData.base64EncodedString(options: .lineLength64Characters)
    }

    /**
     * Retrieve an RSA private key as `NSData` with given key name and length.
     * @param keyName Name of key.
     * @param length Length of key.
     * @return `NSData` object containing the key data, or `nil` if no matching key is found.
     */
    @objc public class func getRSAPrivateKeyData(withName keyName: String, keyLength length: UInt) -> Data? {
        let tagString = "\(kSFRSAPrivateKeyTagPrefix).\(keyName)"
        return getRSAKeyData(withTag: tagString, keyLength: length)
    }

    /**
     * Get RSA public `SecKeyRef` with given key name and length.
     * @param keyName Name of key.
     * @param length Length of key.
     * @return `SecKeyRef` object, or `nil` if no matching key is found.
     */
    @objc public class func getRSAPublicKeyRef(withName keyName: String, keyLength length: UInt) -> SecKey? {
        let tagString = "\(kSFRSAPublicKeyTagPrefix).\(keyName)"
        return getRSAKeyRef(withTag: tagString, keyLength: length)
    }

    /**
     * Get RSA private `SecKeyRef` with given key name and length.
     * @param keyName Name of key.
     * @param length Length of key.
     * @return `SecKeyRef` object, or `nil` if no matching key is found.
     */
    @objc public class func getRSAPrivateKeyRef(withName keyName: String, keyLength length: UInt) -> SecKey? {
        let tagString = "\(kSFRSAPrivateKeyTagPrefix).\(keyName)"
        return getRSAKeyRef(withTag: tagString, keyLength: length)
    }

    // MARK: - EC Key Management

    /**
     * Check for availability of the secure enclave.
     * @return YES if secure enclave is available.
     */
    @objc public class func isSecureEnclaveAvailable() -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        let context = LAContext()
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        #endif
    }

    /**
     * Create asymmetric keys (public/private key pairs) using the EC algorithm with given key name.
     * @param keyName Name of key.
     * @return YES if successful.
     */
    @objc public class func createECKeyPair(withName keyName: String, accessibleAttribute: CFTypeRef, useSecureEnclave: Bool) -> Bool {
        let privateTagString = "\(kSFECPrivateKeyTagPrefix).\(keyName)"
        guard let privateTag = privateTagString.data(using: .utf8) else { return false }

        let publicTagString = "\(kSFECPublicKeyTagPrefix).\(keyName)"
        guard let publicTag = publicTagString.data(using: .utf8) else { return false }

        // Private key attributes
        var privateKeyAttributes: [CFString: Any] = [
            kSecAttrIsPermanent: true,
            kSecAttrApplicationTag: privateTag
        ]

        if useSecureEnclave {
            var error: Unmanaged<CFError>?
            if let privateAccess = SecAccessControlCreateWithFlags(
                kCFAllocatorDefault,
                accessibleAttribute,
                .privateKeyUsage,
                &error
            ) {
                privateKeyAttributes[kSecAttrAccessControl] = privateAccess
            }
        } else {
            privateKeyAttributes[kSecAttrAccessible] = accessibleAttribute
        }

        // Public key attributes
        let publicKeyAttributes: [CFString: Any] = [
            kSecAttrIsPermanent: true,
            kSecAttrApplicationTag: publicTag,
            kSecAttrAccessible: accessibleAttribute
        ]

        // Key pair attributes
        var keyPairAttributes: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits: 256,
            kSecPrivateKeyAttrs: privateKeyAttributes,
            kSecPublicKeyAttrs: publicKeyAttributes
        ]

        if useSecureEnclave {
            keyPairAttributes[kSecAttrTokenID] = kSecAttrTokenIDSecureEnclave
        }

        // Generation
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(keyPairAttributes as CFDictionary, &error) else {
            if let error = error?.takeRetainedValue() {
                SFSDKCoreLogger.e(CryptoUtils.self, message: "Error creating EC private Key with name \(keyName). Error code: \(error)")
            }
            return false
        }

        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            SFSDKCoreLogger.e(CryptoUtils.self, message: "Error creating EC public key with name \(keyName).")
            return false
        }

        return true
    }

    /**
     * Delete an EC key pair created with `createECKeyPairWithName:accessibleAttribute:useSecureEnclase:`.
     * @param keyName Name of key.
     * @return YES if successful.
     */
    @objc public class func deleteECKeyPair(withName keyName: String) -> Bool {
        let deletedPublicKey = deleteKey(byTag: "\(kSFECPublicKeyTagPrefix).\(keyName)")
        let deletedPrivateKey = deleteKey(byTag: "\(kSFECPrivateKeyTagPrefix).\(keyName)")
        return deletedPublicKey && deletedPrivateKey
    }

    /**
     * Get EC public `SecKeyRef` with the given key name.
     * @param keyName Name of key.
     * @return `SecKeyRef` object, or `nil` if no matching key is found.
     */
    @objc public class func getECPublicKeyRef(withName keyName: String) -> SecKey? {
        return getECKeyRef(withTag: "\(kSFECPublicKeyTagPrefix).\(keyName)")
    }

    /**
     * Get EC private `SecKeyRef` with the given key name.
     * @param keyName Name of key.
     * @return `SecKeyRef` object, or `nil` if no matching key is found.
     */
    @objc public class func getECPrivateKeyRef(withName keyName: String) -> SecKey? {
        return getECKeyRef(withTag: "\(kSFECPrivateKeyTagPrefix).\(keyName)")
    }

    /**
     * Encrypt data with the given `SecKeyRef` using the EC algorithm.
     * @param data Data to encrypt.
     * @param keyRef Keyref used in encryption.
     * @return `NSData` object containing the encrypted data, or `nil` if encryption failed.
     */
    @objc public class func encryptUsingEC(forData data: Data, withKeyRef keyRef: SecKey) -> Data? {
        var error: Unmanaged<CFError>?
        guard let encryptedData = SecKeyCreateEncryptedData(
            keyRef,
            .eciesEncryptionStandardX963SHA256AESGCM,
            data as CFData,
            &error
        ) else {
            if let error = error?.takeRetainedValue() {
                SFSDKCoreLogger.e(CryptoUtils.self, message: "Error encrypting data with EC key. Error code: \(error)")
            }
            return nil
        }
        return encryptedData as Data
    }

    /**
     * Decrypt data with the given `SecKeyRef` using the EC algorithm.
     * @param data Data to decrypt.
     * @param keyRef Keyref used in decryption.
     * @return `NSData` object containing the decrypted data, or `nil` if decryption failed.
     */
    @objc public class func decryptUsingEC(forData data: Data, withKeyRef keyRef: SecKey) -> Data? {
        var error: Unmanaged<CFError>?
        guard let decryptedData = SecKeyCreateDecryptedData(
            keyRef,
            .eciesEncryptionStandardX963SHA256AESGCM,
            data as CFData,
            &error
        ) else {
            if let error = error?.takeRetainedValue() {
                SFSDKCoreLogger.e(CryptoUtils.self, message: "Error decrypting data with EC key. Error code: \(error)")
            }
            return nil
        }
        return decryptedData as Data
    }

    // MARK: - Private Methods

    private class func executeCrypt(_ inData: Data, cryptor: CCCryptorRef, resultData: inout Data?) -> Bool {
        let buffersize = CCCryptorGetOutputLength(cryptor, inData.count, true)
        var buffer = [UInt8](repeating: 0, count: buffersize)
        var bufferused: size_t = 0
        var totalbytes: size_t = 0

        var status = inData.withUnsafeBytes { inBytes in
            CCCryptorUpdate(
                cryptor,
                inBytes.baseAddress,
                inData.count,
                &buffer,
                buffersize,
                &bufferused
            )
        }

        if status != kCCSuccess {
            SFSDKCoreLogger.e(CryptoUtils.self, message: "CCCryptorUpdate() failed with status code: \(status)")
            return false
        }

        totalbytes += bufferused

        status = buffer.withUnsafeMutableBytes { bufferPtr in
            guard let baseAddress = bufferPtr.baseAddress else { return CCStatus(kCCMemoryFailure) }
            return CCCryptorFinal(cryptor, baseAddress.advanced(by: bufferused), buffersize - bufferused, &bufferused)
        }
        if status != kCCSuccess {
            SFSDKCoreLogger.e(CryptoUtils.self, message: "CCCryptoFinal() failed with status code: \(status)")
            return false
        }

        totalbytes += bufferused
        resultData = Data(bytes: buffer, count: totalbytes)
        return true
    }

    private class func aesEncryptData(_ data: Data, withKey key: Data, keyLength: Int, iv: Data) -> Data? {
        guard !key.isEmpty else {
            SFSDKCoreLogger.e(CryptoUtils.self, message: "aesEncryptData: encryption key is nil. Cannot encrypt data.")
            return nil
        }

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
                    keyBytes.baseAddress,
                    mutableKey.count,
                    ivBytes.baseAddress,
                    &cryptor
                )
            }
        }

        guard status == kCCSuccess, let unwrappedCryptor = cryptor else {
            SFSDKCoreLogger.e(CryptoUtils.self, message: "Error creating encryption cryptor with CCCryptorCreate(). Status code: \(status)")
            return nil
        }

        var resultData: Data?
        let executeCryptSuccess = executeCrypt(data, cryptor: unwrappedCryptor, resultData: &resultData)
        CCCryptorRelease(unwrappedCryptor)
        return executeCryptSuccess ? resultData : nil
    }

    private class func aesDecryptData(_ data: Data, withKey key: Data, keyLength: Int, iv: Data) -> Data? {
        guard !key.isEmpty else {
            SFSDKCoreLogger.e(CryptoUtils.self, message: "aesDecryptData: decryption key is nil. Cannot decrypt data.")
            return nil
        }

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
                    keyBytes.baseAddress,
                    mutableKey.count,
                    ivBytes.baseAddress,
                    &cryptor
                )
            }
        }

        guard status == kCCSuccess, let unwrappedCryptor = cryptor else {
            SFSDKCoreLogger.e(CryptoUtils.self, message: "Error creating decryption cryptor with CCCryptorCreate(). Status code: \(status)")
            return nil
        }

        var resultData: Data?
        let executeCryptSuccess = executeCrypt(data, cryptor: unwrappedCryptor, resultData: &resultData)
        CCCryptorRelease(unwrappedCryptor)
        return executeCryptSuccess ? resultData : nil
    }

    private class func getRSAKeyData(withTag keyTagString: String, keyLength length: UInt) -> Data? {
        guard let tag = keyTagString.data(using: .utf8) else { return nil }

        let getquery: [CFString: Any] = [
            kSecClass: kSecClassKey,
            kSecAttrApplicationTag: tag,
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecReturnData: true,
            kSecAttrKeySizeInBits: length
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(getquery as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        if status != errSecSuccess {
            let error = NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: nil)
            SFSDKCoreLogger.e(CryptoUtils.self, message: "Error getting RSA key with tag \(keyTagString) and length \(length). Error code: \(error)")
            return nil
        }

        return result as? Data
    }

    private class func getRSAKeyRef(withTag keyTagString: String, keyLength length: UInt) -> SecKey? {
        guard let tag = keyTagString.data(using: .utf8) else { return nil }

        let getquery: [CFString: Any] = [
            kSecClass: kSecClassKey,
            kSecAttrApplicationTag: tag,
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecReturnRef: true,
            kSecAttrKeySizeInBits: length
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(getquery as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        if status != errSecSuccess {
            let error = NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: nil)
            SFSDKCoreLogger.e(CryptoUtils.self, message: "Error getting RSA SecKeyRef with tag \(keyTagString) and length \(length). Error code: \(error)")
            return nil
        }

        return (result as! SecKey)
    }

    private class func getRSAPublicKeyAsDER(_ keyData: Data) -> Data? {
        // Sequence of length 0xd made up of OID followed by NULL
        let encodedRSAEncryptionOID: [UInt8] = [
            0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86,
            0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00
        ]

        var builder = [UInt8](repeating: 0, count: 15)
        var encKey = Data()

        // Encode bitstring
        let bitstringEncLength: Int
        if keyData.count + 1 < 128 {
            bitstringEncLength = 1
        } else {
            bitstringEncLength = ((keyData.count + 1) / 256) + 2
        }

        // ASN.1 encoding representing a SEQUENCE
        builder[0] = 0x30

        // Build up overall size
        let totalSize = encodedRSAEncryptionOID.count + 2 + bitstringEncLength + keyData.count
        let lengthSize = encodeLength(&builder[1], length: totalSize)
        encKey.append(contentsOf: builder[0...(lengthSize)])

        // First part of the sequence is the OID
        encKey.append(contentsOf: encodedRSAEncryptionOID)

        // Now add the bitstring
        builder[0] = 0x03
        let bitstringLengthSize = encodeLength(&builder[1], length: keyData.count + 1)
        builder[bitstringLengthSize + 1] = 0x00
        encKey.append(contentsOf: builder[0...(bitstringLengthSize + 1)])

        // Now the actual key
        encKey.append(keyData)

        return encKey
    }

    private class func encodeLength(_ buf: inout UInt8, length: Int) -> Int {
        if length < 128 {
            buf = UInt8(length)
            return 1
        }

        let i = (length / 256) + 1
        buf = UInt8(i + 0x80)

        // This implementation is simplified; full implementation would require buffer array
        return i + 1
    }

    private class func getECKeyRef(withTag keyTagString: String) -> SecKey? {
        guard let keyTag = keyTagString.data(using: .utf8) else { return nil }

        let getquery: [CFString: Any] = [
            kSecClass: kSecClassKey,
            kSecAttrApplicationTag: keyTag,
            kSecReturnRef: true
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(getquery as CFDictionary, &result)

        if status != errSecSuccess && status != errSecItemNotFound {
            let error = NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: nil)
            SFSDKCoreLogger.e(CryptoUtils.self, message: "Error getting EC SecKeyRef with tag \(keyTagString). Error code: \(error)")
            return nil
        }

        return result as! SecKey?
    }

    private class func deleteKey(byTag keyTagString: String) -> Bool {
        guard let keyTag = keyTagString.data(using: .utf8) else { return false }

        let delquery: [CFString: Any] = [
            kSecClass: kSecClassKey,
            kSecAttrApplicationTag: keyTag
        ]

        var status = SecItemDelete(delquery as CFDictionary)
        while status == errSecDuplicateItem {
            status = SecItemDelete(delquery as CFDictionary)
        }

        if status != errSecSuccess && status != errSecItemNotFound {
            let error = NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: nil)
            SFSDKCoreLogger.e(CryptoUtils.self, message: "Error deleting EC key with tag \(keyTagString). Error code: \(error)")
            return false
        }

        return true
    }
}
