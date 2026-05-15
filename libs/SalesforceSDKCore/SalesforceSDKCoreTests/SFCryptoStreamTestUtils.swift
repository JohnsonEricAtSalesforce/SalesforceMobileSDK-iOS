/*
 Copyright (c) 2016-present, salesforce.com, inc. All rights reserved.

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

/// Utilities for crypto stream testing.
final class SFCryptoStreamTestUtils {

    /// The default test key bounded by a size.
    /// - Parameter keySize: The key size.
    /// - Returns: The default test key data.
    static func defaultKey(withSize keySize: Int) -> Data {
        let key = "defaultKey"
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        let keyData = key.data(using: .utf8)!
        keyData.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(buffer.count), &digest)
        }
        return Data(digest.prefix(keySize))
    }

    /// The default initialization vector bounded by a size.
    /// - Parameter blockSize: The IV size.
    /// - Returns: The default test IV data.
    static func defaultInitializationVector(withBlockSize blockSize: Int) -> Data {
        let storageKey = "iv_\(blockSize)"
        if let iv = UserDefaults.standard.data(forKey: storageKey) {
            return iv
        }
        var data = Data(count: blockSize)
        let result = data.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, blockSize, buffer.baseAddress!)
        }
        assert(result == errSecSuccess, "Failed to generate random bytes.")
        UserDefaults.standard.set(data, forKey: storageKey)
        UserDefaults.standard.synchronize()
        return data
    }

    /// The default test data bounded by a size.
    /// - Parameter testDataSize: The test data size.
    /// - Returns: The default test data.
    static func defaultTestData(withSize testDataSize: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: testDataSize)
        for i in 0..<testDataSize {
            bytes[i] = UInt8(truncatingIfNeeded: i)
        }
        return Data(bytes)
    }

    /// Encrypt or decrypt in one-shot, based on the operation type of the crypto reference.
    /// - Parameters:
    ///   - data: The data to be encrypted/decrypted.
    ///   - crypto: A crypto reference to be used in the operation.
    ///   - iv: The initialization vector to use.
    /// - Returns: The encrypted/decrypted result.
    static func encryptDecryptData(_ data: Data, usingCrypto crypto: CCCryptorRef, withInitializationVector iv: Data) -> Data {
        let baseResetStatus = iv.withUnsafeBytes { ivBuffer in
            CCCryptorReset(crypto, ivBuffer.baseAddress)
        }
        assert(baseResetStatus == kCCSuccess, "SFCryptoStreamTestUtils: Failed to reset crypto.")

        let baseDataTotalSize = CCCryptorGetOutputLength(crypto, data.count, true)
        var baseData = Data(count: baseDataTotalSize)
        var baseBytesMoved: size_t = 0

        let baseUpdateStatus = data.withUnsafeBytes { dataBuffer in
            baseData.withUnsafeMutableBytes { outputBuffer in
                CCCryptorUpdate(
                    crypto,
                    dataBuffer.baseAddress,
                    data.count,
                    outputBuffer.baseAddress,
                    baseDataTotalSize,
                    &baseBytesMoved
                )
            }
        }
        assert(baseUpdateStatus == kCCSuccess, "SFCryptoStreamTestUtils: failed to crypt data.")
        baseData.count = baseBytesMoved

        let finalDataSize = baseDataTotalSize - baseBytesMoved
        var finalData = Data(count: finalDataSize)
        var finalBytesMoved: size_t = 0

        let baseFinalStatus = finalData.withUnsafeMutableBytes { finalBuffer in
            CCCryptorFinal(
                crypto,
                finalBuffer.baseAddress,
                finalDataSize,
                &finalBytesMoved
            )
        }
        assert(baseFinalStatus == kCCSuccess, "SFCryptoStreamTestUtils: failed to finalize crypt.")
        finalData.count = finalBytesMoved

        baseData.append(finalData)
        return baseData
    }

    /// A file path where test files are stored.
    /// - Parameter fileName: The file name.
    /// - Returns: The complete path to reach the test file name passed.
    static func filePath(forFileName fileName: String) -> String {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        let documentsDirectory = paths[0]
        return (documentsDirectory as NSString).appendingPathComponent(fileName)
    }
}
