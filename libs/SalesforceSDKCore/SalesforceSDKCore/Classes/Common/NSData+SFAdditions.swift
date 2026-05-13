/*
 Copyright (c) 2015-present, salesforce.com, inc. All rights reserved.

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
import zlib

/// Extension to NSData class to provide common functions. Added functionality includes:
/// --base64 encoding of an NSData object
/// --MD5 version of an NSData object
/// --Gzip deflated representation of a gzip-compressed NSData object
/// --Hex version of an NSData object
@objc public extension NSData {

    /// Returns a specified number of random bytes.
    /// - Parameter length: The number of bytes of random data to return.
    /// - Returns: The specified quantity of random bytes or `nil` if an error occurs.
    @objc(sfsdk_randomDataOfLength:)
    func sfsdk_randomData(ofLength length: Int) -> Data? {
        var data = Data(count: length)
        let result = data.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, length, bytes.baseAddress!)
        }
        if result != 0 {
            SFSDKCoreLogger.w(type(of: self), message: "Failed to generate random bytes (errno = \(errno))")
            return nil
        }
        return data
    }

    /// Derives a sha256 hex encoded string.
    /// - Returns: sha256 version of data.
    @objc var sfsdk_sha256: String {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        (self as Data).withUnsafeBytes { bytes in
            _ = CC_SHA256(bytes.baseAddress, CC_LONG(self.length), &digest)
        }
        var ms = ""
        for i in 0..<Int(CC_SHA256_DIGEST_LENGTH) {
            ms += String(format: "%02x", digest[i])
        }
        return ms
    }

    /// Converts this data to gzip uncompressed format.
    /// - Returns: This data in gzip uncompressed format.
    @objc var sfsdk_gzipInflate: Data? {
        if self.length == 0 {
            return self as Data
        }

        let fullLength = UInt(self.length)
        let halfLength = UInt(self.length) / 2

        var decompressed = Data(count: Int(fullLength + halfLength))
        var done = false
        var status: Int32

        var strm = z_stream()
        strm.next_in = UnsafeMutablePointer<Bytef>(mutating: (self.bytes.assumingMemoryBound(to: Bytef.self)))
        strm.avail_in = UInt32(self.length)
        strm.total_out = 0
        strm.zalloc = nil
        strm.zfree = nil

        if inflateInit2_(&strm, 15 + 32, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) != Z_OK {
            return nil
        }

        while !done {
            if strm.total_out >= decompressed.count {
                decompressed.count += Int(halfLength)
            }
            let currentOffset = Int(strm.total_out)
            let availableSpace = decompressed.count - currentOffset
            decompressed.withUnsafeMutableBytes { bytes in
                strm.next_out = bytes.baseAddress!.advanced(by: currentOffset).assumingMemoryBound(to: Bytef.self)
                strm.avail_out = UInt32(availableSpace)
            }

            status = inflate(&strm, Z_SYNC_FLUSH)
            if status == Z_STREAM_END {
                done = true
            } else if status != Z_OK {
                break
            }
        }

        if inflateEnd(&strm) != Z_OK {
            return nil
        }

        if done {
            decompressed.count = Int(strm.total_out)
            return decompressed
        } else {
            return nil
        }
    }

    /// Converts this data to gzip compressed format.
    /// - Returns: This data in gzip compressed format.
    @objc var sfsdk_gzipDeflate: Data? {
        var stream = z_stream()
        stream.zalloc = nil
        stream.zfree = nil
        stream.opaque = nil
        stream.total_out = 0
        stream.next_in = UnsafeMutablePointer<Bytef>(mutating: (self.bytes.assumingMemoryBound(to: Bytef.self)))
        stream.avail_in = UInt32(self.length)

        let deflateStatus = deflateInit2_(&stream, Z_DEFAULT_COMPRESSION, Z_DEFLATED, 15 + 16, 8, Z_DEFAULT_STRATEGY, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
        if deflateStatus != Z_OK {
            SFSDKCoreLogger.e(type(of: self), message: "cannot initialize zlib deflate: \(deflateStatus)")
            return nil
        }

        var compressedData = Data(count: 16384)

        repeat {
            if stream.total_out >= compressedData.count {
                compressedData.count += 16384
            }
            let currentOffset = Int(stream.total_out)
            let availableSpace = compressedData.count - currentOffset
            compressedData.withUnsafeMutableBytes { bytes in
                stream.next_out = bytes.baseAddress!.advanced(by: currentOffset).assumingMemoryBound(to: Bytef.self)
                stream.avail_out = UInt32(availableSpace)
            }

            deflate(&stream, Z_FINISH)
        } while stream.avail_out == 0

        if stream.msg != nil {
            let msg = String(cString: stream.msg!)
            SFSDKCoreLogger.e(type(of: self), message: "couldn't compress input: zlib error \(deflateStatus): \(msg)")
            deflateEnd(&stream)
            return nil
        }

        deflateEnd(&stream)
        compressedData.count = Int(stream.total_out)
        SFSDKCoreLogger.d(type(of: self), message: "Compressed file from \(self.length/1024) KB to \(compressedData.count/1024) KB")
        return compressedData
    }

    /// Creates a hex string representation of this object's data.
    /// - Returns: Hex string representation of this object's data.
    @objc var sfsdk_newHexStringFromBytes: String {
        let dataLen = self.length
        var sb = ""
        sb.reserveCapacity(2 * dataLen)
        let rawBytes = self.bytes.assumingMemoryBound(to: UInt8.self)
        for i in 0..<dataLen {
            sb += String(format: "%02lx", UInt(rawBytes[i]))
        }
        return sb
    }
}
