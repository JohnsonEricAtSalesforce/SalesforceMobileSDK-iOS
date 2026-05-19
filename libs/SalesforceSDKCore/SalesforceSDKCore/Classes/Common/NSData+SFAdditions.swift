// NSData+SFAdditions.swift
//
// Copyright (c) 2015-present, salesforce.com, inc. All rights reserved.
//
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
import zlib

// MARK: - NSData (SFBase64)

extension NSData {

    /// Returns a specified number of random bytes.
    /// - Parameter length: The number of bytes of random data to return.
    /// - Returns: The specified quantity of random bytes or `nil` if an error occurs.
    @objc(sfsdk_randomDataOfLength:)
    public func sfsdk_randomData(ofLength length: Int) -> NSData? {
        let mutableData = NSMutableData(data: self as Data)
        let result = SecRandomCopyBytes(kSecRandomDefault, length, mutableData.mutableBytes)
        if result != errSecSuccess {
            SFSDKCoreLogger.w(type(of: self), message: "Failed to generate random bytes (errno = \(errno))")
            return nil
        }
        return mutableData
    }
}

// MARK: - NSData (SFSHA)

extension NSData {

    /// Derives a SHA256 hex encoded string.
    /// - Returns: SHA256 hex string of data.
    @objc public func sfsdk_sha256() -> String {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        CC_SHA256(bytes, CC_LONG(length), &digest)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - NSData (SFzlib)

extension NSData {

    /// Converts this data to gzip uncompressed format.
    /// - Returns: This data in gzip uncompressed format, or `nil` on failure.
    @objc public func sfsdk_gzipInflate() -> NSData? {
        guard length > 0 else { return self }

        let fullLength = UInt(length)
        let halfLength = UInt(length) / 2

        let decompressed = NSMutableData(length: Int(fullLength + halfLength))
        guard let decompressed = decompressed else { return nil }

        var strm = z_stream()
        strm.next_in = UnsafeMutablePointer<Bytef>(mutating: bytes.assumingMemoryBound(to: Bytef.self))
        strm.avail_in = uInt(length)
        strm.total_out = 0
        strm.zalloc = nil
        strm.zfree = nil

        guard inflateInit2_(&strm, 15 + 32, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else {
            return nil
        }

        var done = false
        while !done {
            if strm.total_out >= decompressed.length {
                decompressed.increaseLength(by: Int(halfLength))
            }
            strm.next_out = decompressed.mutableBytes.advanced(by: Int(strm.total_out)).assumingMemoryBound(to: Bytef.self)
            strm.avail_out = uInt(UInt(decompressed.length) - UInt(strm.total_out))

            let status = inflate(&strm, Z_SYNC_FLUSH)
            if status == Z_STREAM_END {
                done = true
            } else if status != Z_OK {
                break
            }
        }

        guard inflateEnd(&strm) == Z_OK else { return nil }

        if done {
            decompressed.length = Int(strm.total_out)
            return NSData(data: decompressed as Data)
        }
        return nil
    }

    /// Converts this data to gzip compressed format.
    /// - Returns: This data in gzip compressed format, or `nil` on failure.
    @objc public func sfsdk_gzipDeflate() -> NSData? {
        var stream = z_stream()
        stream.zalloc = nil
        stream.zfree = nil
        stream.opaque = nil
        stream.total_out = 0
        stream.next_in = UnsafeMutablePointer<Bytef>(mutating: bytes.assumingMemoryBound(to: Bytef.self))
        stream.avail_in = uInt(length)

        var deflateStatus = deflateInit2_(&stream, Z_DEFAULT_COMPRESSION, Z_DEFLATED, 15 + 16, 8, Z_DEFAULT_STRATEGY, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
        guard deflateStatus == Z_OK else {
            SFSDKCoreLogger.e(type(of: self), message: "cannot initialize zlib deflate: \(deflateStatus)")
            return nil
        }

        let compressedData = NSMutableData(length: 16384)
        guard let compressedData = compressedData else {
            deflateEnd(&stream)
            return nil
        }

        repeat {
            if stream.total_out >= compressedData.length {
                compressedData.increaseLength(by: 16384)
            }
            stream.next_out = compressedData.mutableBytes.advanced(by: Int(stream.total_out)).assumingMemoryBound(to: Bytef.self)
            stream.avail_out = uInt(UInt(compressedData.length) - UInt(stream.total_out))

            deflateStatus = zlib.deflate(&stream, Z_FINISH)
        } while deflateStatus == Z_OK

        guard deflateStatus == Z_STREAM_END else {
            SFSDKCoreLogger.e(type(of: self), message: "couldn't compress input: zlib error \(deflateStatus)")
            deflateEnd(&stream)
            return nil
        }

        deflateEnd(&stream)
        compressedData.length = Int(stream.total_out)
        SFSDKCoreLogger.d(type(of: self), message: "Compressed file from \(length / 1024) KB to \(compressedData.length / 1024) KB")
        return compressedData
    }
}

// MARK: - NSData (SFHexSupport)

extension NSData {

    /// Creates a hex string representation of this object's data.
    /// - Returns: Hex string representation of this object's data.
    @objc public func sfsdk_newHexStringFromBytes() -> String {
        let dataLen = length
        let rawBytes = bytes.assumingMemoryBound(to: UInt8.self)
        var sb = String()
        sb.reserveCapacity(2 * dataLen)
        for i in 0..<dataLen {
            sb += String(format: "%02lx", UInt(rawBytes[i]))
        }
        return sb
    }
}
