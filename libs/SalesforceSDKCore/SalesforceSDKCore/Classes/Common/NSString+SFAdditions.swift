// NSString+SFAdditions.swift
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

/// Entity ID length enum
@objc public enum SFEntityIdLength: UInt {
    case length15 = 15
    case length18 = 18

    public static let min = SFEntityIdLength.length15
    public static let max = SFEntityIdLength.length18
}

// MARK: - Private helper

private func isValidEntityId(_ string: String) -> Bool {
    let length = string.count
    guard length == SFEntityIdLength.length15.rawValue || length == SFEntityIdLength.length18.rawValue else {
        return false
    }
    let regex = try? NSRegularExpression(pattern: "[A-Za-z0-9]{15,18}", options: .caseInsensitive)
    let range = NSRange(location: 0, length: length)
    guard let match = regex?.rangeOfFirstMatch(in: string, options: .anchored, range: range) else {
        return false
    }
    return match.length == length
}

// MARK: - NSString (SFAdditions)

extension NSString {

    /// Returns a hex string representation of the supplied data.
    /// - Parameter data: NSData to be represented as a base 16 string.
    /// - Returns: A hex string representation, or `nil` if data is nil or empty.
    @objc(sfsdk_stringWithHexData:)
    public static func sfsdk_string(withHexData data: NSData?) -> String? {
        guard let data = data, data.length > 0 else { return nil }
        let rawBytes = data.bytes.assumingMemoryBound(to: UInt8.self)
        var stringBuffer = String()
        stringBuffer.reserveCapacity(data.length * 2)
        for i in 0..<data.length {
            stringBuffer += String(format: "%02lx", UInt(rawBytes[i]))
        }
        return stringBuffer
    }

    /// Returns an SHA 256 hash of the current string.
    @objc public func sfsdk_sha256() -> NSData {
        let str = self as String
        let data = str.data(using: .utf8) ?? Data()
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(buffer.count), &digest)
        }
        return NSData(bytes: digest, length: Int(CC_SHA256_DIGEST_LENGTH))
    }

    /// Escape XML entities.
    /// - Parameter value: String value to escape. If nil is passed, this method will return nil.
    /// - Returns: The escaped string, or empty string if input is empty.
    @objc(sfsdk_escapeXMLCharacter:)
    public static func sfsdk_escapeXMLCharacter(_ value: String?) -> String? {
        guard let value = value, !NSString.sfsdk_isEmpty(value) else { return "" }
        var returnValue = value
        returnValue = returnValue.replacingOccurrences(of: "'", with: "&#39;")
        returnValue = returnValue.replacingOccurrences(of: "&", with: "&#38;")
        returnValue = returnValue.replacingOccurrences(of: "\"", with: "&#34;")
        returnValue = returnValue.replacingOccurrences(of: "<", with: "&#60;")
        returnValue = returnValue.replacingOccurrences(of: ">", with: "&#62;")
        returnValue = returnValue.replacingOccurrences(of: "&", with: "&amp;")
        returnValue = returnValue.replacingOccurrences(of: "\u{00A9}", with: "&#169;")
        returnValue = returnValue.replacingOccurrences(of: "\"", with: "&quot;")
        return returnValue
    }

    /// Unescape XML entities.
    /// - Parameter value: String value to unescape. If nil is passed, this method will return nil.
    /// - Returns: The unescaped string, or empty string if input is empty.
    @objc(sfsdk_unescapeXMLCharacter:)
    public static func sfsdk_unescapeXMLCharacter(_ value: String?) -> String? {
        guard let value = value, !NSString.sfsdk_isEmpty(value) else { return "" }
        var returnValue = value
        returnValue = returnValue.replacingOccurrences(of: "&#39;", with: "'")
        returnValue = returnValue.replacingOccurrences(of: "&#38;", with: "&")
        returnValue = returnValue.replacingOccurrences(of: "&#34;", with: "\"")
        returnValue = returnValue.replacingOccurrences(of: "&#60;", with: "<")
        returnValue = returnValue.replacingOccurrences(of: "&lt;", with: "<")
        returnValue = returnValue.replacingOccurrences(of: "&#62;", with: ">")
        returnValue = returnValue.replacingOccurrences(of: "&gt;", with: ">")
        returnValue = returnValue.replacingOccurrences(of: "&amp;", with: "&")
        returnValue = returnValue.replacingOccurrences(of: "&#169;", with: "\u{00A9}")
        returnValue = returnValue.replacingOccurrences(of: "&quot;", with: "\"")
        return returnValue
    }

    /// Trim string by taking out beginning and ending space.
    @objc public func sfsdk_trim() -> String {
        return trimmingCharacters(in: .whitespaces)
    }

    /// Returns the string in debug build or a redacted version for production build.
    @objc public func sfsdk_redacted() -> String {
        return sfsdk_redacted(withPrefix: 0)
    }

    /// Returns the string in debug build or a redacted version for production build.
    /// - Parameter prefixLength: The number of characters to preserve at the beginning of the string.
    @objc(sfsdk_redactedWithPrefix:)
    public func sfsdk_redacted(withPrefix prefixLength: UInt) -> String {
        #if DEBUG
        return self as String
        #else
        let str = self as String
        let prefixCount = min(str.count, Int(prefixLength))
        let prefix = String(str.prefix(prefixCount))
        let redacted = String(repeating: "-", count: str.count - prefixCount)
        return prefix + redacted
        #endif
    }

    /// Return YES if string is nil or length is 0 or with white space only.
    /// - Parameter string: String to check.
    @objc(sfsdk_isEmpty:)
    public static func sfsdk_isEmpty(_ string: String?) -> Bool {
        guard let string = string else { return true }
        if (string as NSObject) is NSNull { return true }
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty
    }

    /// Returns a string with all non-legal URL characters (per RFC 3986) escaped.
    @objc public func sfsdk_stringByURLEncoding() -> String {
        let disallowed = CharacterSet(charactersIn: "\n\r \"#%/:<>?@[\\]^`{|}&:/=+")
        let allowed = disallowed.inverted
        return (self as String).addingPercentEncoding(withAllowedCharacters: allowed) ?? (self as String)
    }

    /// Strips any HTML markup from the source string.
    @objc public func sfsdk_stringByStrippingHTML() -> String {
        var str = self as String
        while let range = str.range(of: "<[^>]+>", options: .regularExpression) {
            str = str.replacingCharacters(in: range, with: "")
        }
        return str
    }

    /// Returns YES if the string is empty or contains only whitespace or newline characters.
    @objc public func sfsdk_isEmptyOrWhitespaceAndNewlines() -> Bool {
        let str = self as String
        return str.isEmpty || str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The 18 character case-insensitive entity ID representing the receiver.
    /// Returns `nil` if the receiver is not a valid Salesforce entity ID.
    @objc public func sfsdk_entityId18() -> String? {
        let kChunkTable: [Character] = [
            "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P",
            "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "0", "1", "2", "3", "4", "5"
        ]

        let str = self as String
        guard isValidEntityId(str) else { return nil }
        if str.count == Int(SFEntityIdLength.length18.rawValue) { return str }

        let capsCharSet = CharacterSet.uppercaseLetters
        var suffix = ""
        let characters = Array(str.unicodeScalars)

        for chunk in 0..<3 {
            var chunkMap: UInt8 = 0
            for i in 0..<5 {
                let c = characters[(chunk * 5) + i]
                if capsCharSet.contains(c) {
                    chunkMap |= 0x1F & (0x1 << i)
                }
            }
            suffix.append(kChunkTable[Int(chunkMap)])
        }
        return str + suffix
    }

    /// Returns a Boolean value that indicates if the given entity ID is equal to the receiver.
    /// The comparison properly handles comparing 15 character case-sensitive ID's against
    /// 18 character case-insensitive ID's.
    /// - Parameter entityId: The entity ID to compare with the receiver.
    /// - Returns: `true` if the given entityId is semantically equal to the receiver.
    @objc(sfsdk_isEqualToEntityId:)
    public func sfsdk_isEqual(toEntityId entityId: String) -> Bool {
        let selfStr = self as String
        if !isValidEntityId(selfStr) || !isValidEntityId(entityId) {
            return selfStr.caseInsensitiveCompare(entityId) == .orderedSame
        }

        let id18self = selfStr.count == Int(SFEntityIdLength.length18.rawValue) ? selfStr : (self.sfsdk_entityId18() ?? selfStr)
        let id18other: String
        if entityId.count == Int(SFEntityIdLength.length18.rawValue) {
            id18other = entityId
        } else {
            guard let computed = (entityId as NSString).sfsdk_entityId18() else { return false }
            id18other = computed
        }
        return id18self.caseInsensitiveCompare(id18other) == .orderedSame
    }
}
