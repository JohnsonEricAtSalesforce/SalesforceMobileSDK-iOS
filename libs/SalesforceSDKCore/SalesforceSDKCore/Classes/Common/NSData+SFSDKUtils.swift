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

@objc public extension NSData {

    /// Creates a base64url string based on the data.  See RFC 4648.
    /// - Returns: The base64url string based on the data.
    @objc var sfsdk_base64UrlString: String {
        let base64String = self.base64EncodedString(options: [])
        return NSData.sfsdk_replaceBase64CharsForBase64UrlString(base64String)
    }

    /// Creates an SHA256 hash of the given data.
    /// - Returns: The SHA256 hash of the given data.
    @objc var sfsdk_sha256Data: Data? {
        var sha256Data = Data(count: Int(CC_SHA256_DIGEST_LENGTH))
        sha256Data.withUnsafeMutableBytes { bytes in
            _ = CC_SHA256(self.bytes, CC_LONG(self.length), bytes.baseAddress?.assumingMemoryBound(to: UInt8.self))
        }
        return sha256Data
    }

    // MARK: - Internal methods

    /// Replace the base64 characters that are invalid in a base64url string.
    /// - Parameter base64String: The input string with characters to replace.
    /// - Returns: The base64 string with the URL chars replaced (i.e. the base64url string).
    @objc static func sfsdk_replaceBase64CharsForBase64UrlString(_ base64String: String?) -> String {
        guard let base64String = base64String else { return "" }

        var base64UrlString = base64String
        base64UrlString = base64UrlString.replacingOccurrences(of: "/", with: "_")
        base64UrlString = base64UrlString.replacingOccurrences(of: "+", with: "-")

        // Remove trailing equals
        var lastEqualsIndex = base64UrlString.count
        while lastEqualsIndex > 0 && base64UrlString[base64UrlString.index(base64UrlString.startIndex, offsetBy: lastEqualsIndex - 1)] == "=" {
            lastEqualsIndex -= 1
        }
        if lastEqualsIndex < base64UrlString.count {
            base64UrlString = String(base64UrlString.prefix(lastEqualsIndex))
        }
        return base64UrlString
    }
}
