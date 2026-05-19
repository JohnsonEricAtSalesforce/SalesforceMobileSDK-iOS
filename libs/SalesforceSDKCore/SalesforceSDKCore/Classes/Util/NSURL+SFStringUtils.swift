// NSURL+SFStringUtils.swift
//
// Copyright (c) 2012-present, salesforce.com, inc. All rights reserved.
// Author: Kevin Hawkins
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

/// The value that will be used to replace the redacted querystring value.
public let kSFRedactedQuerystringValue: String = "[redacted]"

// MARK: - NSURL (SFStringUtils)

extension NSURL {

    /// Will return the absolute string of a URL, with potentially sensitive querystring
    /// parameter values redacted. Useful for logging URL values without sensitive data included.
    /// - Parameter queryStringParamsToRedact: An array of querystring parameter names whose values should be redacted.
    /// - Returns: The redacted version of the absolute string value.
    @objc(sfsdk_redactedAbsoluteString:)
    public func sfsdk_redactedAbsoluteString(_ queryStringParamsToRedact: [String]) -> String {
        guard !queryStringParamsToRedact.isEmpty,
              let queryStr = query, !queryStr.isEmpty else {
            return absoluteString ?? ""
        }

        // Initialize the new URL.
        var redactedUrl = "\(scheme ?? "")://\(host ?? "")"
        if let port = port {
            redactedUrl += ":\(port)"
        }
        redactedUrl += "\(path ?? "")?"

        // Loop through the querystring to evaluate the parameters.
        let queryNameValPairs = queryStr.components(separatedBy: "&")
        for i in 0..<queryNameValPairs.count {
            let nameValPairString = queryNameValPairs[i]
            let nameValPair = nameValPairString.components(separatedBy: "=")
            if nameValPair.count != 2 {
                // Hanging parameter (e.g. &fromEmail as opposed to &fromEmail=1)
                if i > 0 { redactedUrl += "&" }
                redactedUrl += nameValPairString
                continue
            }

            // Got a good name/value pair. See if any of the parameters to redact match this pair.
            let name = nameValPair[0]
            var redactedNameValuePairString: String?
            for paramToRedact in queryStringParamsToRedact {
                if paramToRedact.lowercased() == name.lowercased() {
                    redactedNameValuePairString = "\(name)=\(kSFRedactedQuerystringValue)"
                    break
                }
            }

            if i > 0 {
                redactedUrl += "&"
            }
            redactedUrl += redactedNameValuePairString ?? nameValPairString
        }

        return redactedUrl
    }

    /// Appends path components to a mutable URL string.
    /// - Parameters:
    ///   - pathComponents: Array of path components to append.
    ///   - urlString: The mutable string to append to.
    @objc(appendPathComponents:toMutableUrlString:)
    public static func appendPathComponents(_ pathComponents: [String], toMutableUrlString urlString: NSMutableString) {
        for c in pathComponents {
            if c == "/" {
                continue
            }

            if !c.hasPrefix("/") && !urlString.hasSuffix("/") {
                urlString.append("/")
                urlString.append(c)
            } else if c.hasPrefix("/") && urlString.hasSuffix("/") {
                urlString.append(String(c.dropFirst()))
            } else {
                urlString.append(c)
            }
        }
    }
}
