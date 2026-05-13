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

@objc public enum SFEntityIdLength: UInt {
    case length15 = 15
    case length18 = 18

    public static var min: SFEntityIdLength { return .length15 }
    public static var max: SFEntityIdLength { return .length18 }
}

private func isValidEntityId(_ string: String) -> Bool {
    let regex = try! NSRegularExpression(
        pattern: "[A-Za-z0-9]{15,18}",
        options: .caseInsensitive
    )
    let range = NSRange(location: 0, length: string.count)
    return (string.count == 15 || string.count == 18) &&
           regex.rangeOfFirstMatch(in: string, options: .anchored, range: range).length == string.count
}

@objc public extension NSString {

    /// A hex string representation of the supplied data; or `nil` if `data` is `nil` or empty.
    /// - Parameter data: NSData to be represented as a base 16 string.
    /// - Returns: A hex string representation of the supplied data
    @objc(sfsdk_stringWithHexData:)
    static func sfsdk_string(withHexData data: Data?) -> String? {
        guard let data = data, !data.isEmpty else { return nil }
        var stringBuffer = ""
        stringBuffer.reserveCapacity(data.count * 2)
        data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            for byte in bytes {
                stringBuffer.append(String(format: "%02lx", UInt(byte)))
            }
        }
        return stringBuffer
    }

    /// Returns an SHA 256 hash of the current string
    @objc var sfsdk_sha256: Data {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        let data = (self as String).data(using: .utf8)!
        data.withUnsafeBytes { bytes in
            _ = CC_SHA256(bytes.baseAddress, CC_LONG(data.count), &digest)
        }
        return Data(digest)
    }

    /// Escape XML entities
    /// - Parameter value: String value to escape. If nil is passed, this method will return nil.
    @objc(sfsdk_escapeXMLCharacter:)
    static func sfsdk_escapeXMLCharacter(_ value: String?) -> String? {
        guard let value = value, !sfsdk_isEmpty(value) else { return "" }
        var returnValue = value.replacingOccurrences(of: "'", with: "&#39;")
        returnValue = returnValue.replacingOccurrences(of: "&", with: "&#38;")
        returnValue = returnValue.replacingOccurrences(of: "\"", with: "&#34;")
        returnValue = returnValue.replacingOccurrences(of: "<", with: "&#60;")
        returnValue = returnValue.replacingOccurrences(of: ">", with: "&#62;")
        returnValue = returnValue.replacingOccurrences(of: "&", with: "&amp;")
        returnValue = returnValue.replacingOccurrences(of: "©", with: "&#169;")
        returnValue = returnValue.replacingOccurrences(of: "\"", with: "&quot;")
        return returnValue
    }

    /// Unescape XML entities
    /// - Parameter value: String value to unescape. If nil is passed, this method will return nil.
    @objc(sfsdk_unescapeXMLCharacter:)
    static func sfsdk_unescapeXMLCharacter(_ value: String?) -> String? {
        guard let value = value, !sfsdk_isEmpty(value) else { return "" }
        var returnValue = value.replacingOccurrences(of: "&#39;", with: "'")
        returnValue = returnValue.replacingOccurrences(of: "&#38;", with: "&")
        returnValue = returnValue.replacingOccurrences(of: "&#34;", with: "\"")
        returnValue = returnValue.replacingOccurrences(of: "&#60;", with: "<")
        returnValue = returnValue.replacingOccurrences(of: "&lt;", with: "<")
        returnValue = returnValue.replacingOccurrences(of: "&#62;", with: ">")
        returnValue = returnValue.replacingOccurrences(of: "&gt;", with: ">")
        returnValue = returnValue.replacingOccurrences(of: "&amp;", with: "&")
        returnValue = returnValue.replacingOccurrences(of: "&#169;", with: "©")
        returnValue = returnValue.replacingOccurrences(of: "&quot;", with: "\"")
        return returnValue
    }

    /// Trim string by taking out beginning and ending space.
    @objc var sfsdk_trim: String {
        return (self as String).trimmingCharacters(in: .whitespaces)
    }

    /// Returns the string in debug build or a redacted version of it for production build
    @objc var sfsdk_redacted: String {
        return sfsdk_redacted(withPrefix: 0)
    }

    /// Returns the string in debug build or a redacted version of it for production build.
    /// The prefix length is the number of characters that won't be redacted from the beginning of the string.
    /// - Parameter prefixLength: The number of characters to preserve at the beginning of the string.
    @objc(sfsdk_redactedWithPrefix:)
    func sfsdk_redacted(withPrefix prefixLength: UInt) -> String {
        #if DEBUG
        return self as String
        #else
        let prefixLen = min(Int(prefixLength), self.length)
        var ms = String(self.substring(to: prefixLen))
        for _ in prefixLen..<self.length {
            ms.append("-")
        }
        return ms
        #endif
    }

    /// Return YES if string is nil or length is 0 or with white space only
    /// - Parameter string: String to check
    @objc(sfsdk_isEmpty:)
    static func sfsdk_isEmpty(_ string: String?) -> Bool {
        guard let string = string as NSString?, !(string is NSNull) else { return true }
        let trimmed = string.sfsdk_trim
        return trimmed.isEmpty
    }

    /// A string with all non-legal URL characters (per RFC 3986) escaped.
    @objc var sfsdk_stringByURLEncoding: String {
        let urlAllowedCharacterSet = CharacterSet(charactersIn: "\n\r \"#%/:<>?@[\\]^`{|}&:/=+").inverted
        return (self as String).addingPercentEncoding(withAllowedCharacters: urlAllowedCharacterSet) ?? (self as String)
    }

    /// Strips any HTML markup from the source string.
    @objc var sfsdk_stringByStrippingHTML: String {
        var str = self as String
        while let range = str.range(of: "<[^>]+>", options: .regularExpression) {
            str = str.replacingCharacters(in: range, with: "")
        }
        return str
    }

    /// Returns YES if the string is empty of contains only whitespance or newline characters.
    @objc var sfsdk_isEmptyOrWhitespaceAndNewlines: Bool {
        return self.length == 0 ||
               (self as String).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The 18 character case-insensitive entity ID representing the receiver.
    /// Returns `nil` if the receiver is not a valid Salesforce entity ID.
    @objc var sfsdk_entityId18: String? {
        // Look up table of characters which correspond to the bitmap value of uppercase characters for a
        // 5 character chunk of the entity ID (the 15 character entity ID is divided into 3 x 5 char chunks).
        let kChunkTable: [Character] = [
            "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P",
            "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "0", "1", "2", "3", "4", "5"
        ]

        let selfString = self as String
        guard isValidEntityId(selfString) else { return nil }
        if selfString.count == 18 { return selfString }

        let capsCharSet = CharacterSet.uppercaseLetters
        var suffix = ""
        suffix.reserveCapacity(3)

        // Iterate the 15 char entity ID in 3 x 5 char chunks building a bitmap with on bits
        // representing upper case characters. Finally represent each chunk with a character
        // from the look up table corresponding to the map value.
        for chunk in 0..<3 {
            var chunkMap: UInt8 = 0
            for i in 0..<5 {
                let index = selfString.index(selfString.startIndex, offsetBy: (chunk * 5) + i)
                let c = selfString[index]
                if let scalar = c.unicodeScalars.first, capsCharSet.contains(scalar) {
                    chunkMap |= UInt8(0x1F & (0x1 << i))
                }
            }
            suffix.append(kChunkTable[Int(chunkMap)])
        }
        return selfString + suffix
    }

    /// Returns a Boolean value that indicates if the given entity ID is equal to the receiver.
    /// The comparison properly handles comparing 15 character case-sensitive ID's against 18 character case-insensitive ID's.
    /// - Parameter entityId: The entity ID to compare with the receiver.
    /// - Returns: `YES` if the given entityId is semantically equal to the receiver, otherwise `NO`.
    /// Returns `NO` if either the given ID or receiver are not valid Salesforce entity ID's.
    @objc(sfsdk_isEqualToEntityId:)
    func sfsdk_isEqual(toEntityId entityId: String) -> Bool {
        let selfString = self as String
        if !isValidEntityId(selfString) || !isValidEntityId(entityId) {
            // for entityId like `me`
            return selfString.caseInsensitiveCompare(entityId) == .orderedSame
        }

        let id18self = (selfString.count == 18) ? selfString : sfsdk_entityId18
        let id18other = (entityId.count == 18) ? entityId : (entityId as NSString).sfsdk_entityId18
        guard let id18self = id18self, let id18other = id18other else { return false }
        return id18self.caseInsensitiveCompare(id18other) == .orderedSame
    }
}
