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

/**
 * Simple SOQL tokenizer
 * Tokens returned are either:
 *  - SOQL keywords (select, from, where, having, group by, order by, limit, offset)
 *  - top level parenthesized expression
 *  - top level single quoted expression
 *  - strings without white spaces
 *  - white spaces
 */
@objc(SFSDKSoqlTokenizer)
public class SoqlTokenizer: NSObject {

    private let soql: String

    // Used during tokenization
    private var tokens: [String] = []
    private var inWhiteSpace: Bool = false
    private var inQuotes: Bool = false
    private var depth: UInt = 0
    private var lastCh: unichar = 0
    private var currentToken: String = ""

    @objc
    public init(soql: String) {
        self.soql = soql
        super.init()
    }

    private func pushToken() {
        tokens.append(currentToken)
        currentToken = ""
    }

    private func beginWhiteSpace() {
        if depth == 0 {
            pushToken()
        }
        inWhiteSpace = true
        currentToken += " "
    }

    private func beginWord(_ ch: unichar) {
        if depth == 0 {
            pushToken()
        }
        inWhiteSpace = false
        currentToken += String(Character(UnicodeScalar(ch)!))
    }

    private func beginParenthesized() {
        if depth == 0 {
            pushToken()
        }
        inWhiteSpace = false
        depth += 1
        currentToken += "("
    }

    private func endParenthesized() {
        currentToken += ")"
        depth -= 1
        if depth == 0 {
            pushToken()
        }
    }

    private func beginQuoted() {
        if depth == 0 {
            pushToken()
        }
        inQuotes = true
        inWhiteSpace = false
        currentToken += "'"
    }

    private func endQuoted() {
        currentToken += "'"
        if depth == 0 {
            pushToken()
        }
        inQuotes = false
    }

    // Combining order by, group by into single token
    private func processTokens() -> [String] {
        var processedTokens: [String] = []
        var i = 0
        while i < tokens.count {
            let token = tokens[i]
            if i + 2 < tokens.count {
                let nextToken = tokens[i + 1]
                let afterNextToken = tokens[i + 2]
                if nextToken.replacingOccurrences(of: " ", with: "").isEmpty &&
                   afterNextToken.caseInsensitiveCompare("by") == .orderedSame &&
                   (token.caseInsensitiveCompare("order") == .orderedSame || token.caseInsensitiveCompare("group") == .orderedSame) {
                    processedTokens.append("\(token) \(afterNextToken)")
                    i += 3
                    continue
                }
            }
            processedTokens.append(token)
            i += 1
        }

        return processedTokens
    }

    @objc
    public func tokenize() -> [String] {
        let nsString = soql as NSString
        for i in 0..<nsString.length {
            let ch = nsString.character(at: i)
            switch ch {
            case 0x0027: // Single quote '
                if !inQuotes { // starting '' expression
                    beginQuoted()
                } else if lastCh != 0x005C { // ending '' expression (not escaped with \)
                    endQuoted()
                } else { // within '' expression but escaped
                    currentToken += String(Character(UnicodeScalar(ch)!))
                }

            case 0x0028: // Left parenthesis (
                if !inQuotes { // starting () expressions
                    beginParenthesized()
                } else { // within '' expression
                    currentToken += String(Character(UnicodeScalar(ch)!))
                }

            case 0x0029: // Right parenthesis )
                if !inQuotes { // ending () expressions
                    endParenthesized()
                } else { // within '' expression
                    currentToken += String(Character(UnicodeScalar(ch)!))
                }

            case 0x0020: // Space
                if !inWhiteSpace && !inQuotes && depth == 0 { // starting top level white space
                    beginWhiteSpace()
                } else {
                    currentToken += String(Character(UnicodeScalar(ch)!))
                }

            default:
                if inWhiteSpace {
                    beginWord(ch)
                } else {
                    currentToken += String(Character(UnicodeScalar(ch)!))
                }
            }
            lastCh = ch
        }

        // Don't forget last token
        if !currentToken.isEmpty {
            tokens.append(currentToken)
        }

        // Process tokens
        return processTokens()
    }
}
