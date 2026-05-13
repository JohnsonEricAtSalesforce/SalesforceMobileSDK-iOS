/*
 Copyright (c) 2012-present, salesforce.com, inc. All rights reserved.
 Author: Kevin Hawkins

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

/// The value that will be used to replace the redacted querystring value.
public let kSFRedactedQuerystringValue = "[redacted]"

public extension URL {

    /// Will return the absolute string of a URL, with potentially sensitive querystring
    /// parameter values redacted.  Useful for logging URL values without sensitive data
    /// included.
    /// - Parameter queryStringParamsToRedact: An array of querystring parameter names whose values should be redacted.
    /// - Returns: The redacted version of the absolute string value.
    func sfsdk_redactedAbsoluteString(_ queryStringParamsToRedact: [String]) -> String {
        if queryStringParamsToRedact.isEmpty || query == nil || query?.isEmpty == true {
            return absoluteString
        }

        // Initialize the new URL.
        var redactedUrl = ""
        if let scheme = scheme {
            redactedUrl += "\(scheme)://"
        }
        if let host = host {
            redactedUrl += host
        }
        if let port = port {
            redactedUrl += ":\(port)"
        }
        if !path.isEmpty {
            redactedUrl += path
        }
        redactedUrl += "?"

        // Loop through the querystring to evaluate the parameters.
        guard let queryString = query else {
            return absoluteString
        }

        let queryNameValPairs = queryString.components(separatedBy: "&")
        for (i, nameValPairString) in queryNameValPairs.enumerated() {
            let nameValPair = nameValPairString.components(separatedBy: "=")

            if nameValPair.count != 2 {
                // If it's just a "hanging" parameter (e.g. &fromEmail as opposed to &fromEmail=1),
                // just take it as-is.
                redactedUrl += nameValPairString
                continue
            }

            // Got a good name/value pair. See if any of the parameters to redact match this pair.
            let name = nameValPair[0]
            var redactedNameValuePairString: String?

            for paramToRedact in queryStringParamsToRedact {
                if paramToRedact.lowercased() == name.lowercased() {
                    // Got one! Redact it.
                    redactedNameValuePairString = "\(name)=\(kSFRedactedQuerystringValue)"
                    break
                }
            }

            // Did we get one? If so, add it. If not, add back the original.
            if i > 0 {
                redactedUrl += "&"
            }
            if let redactedPair = redactedNameValuePairString {
                redactedUrl += redactedPair
            } else {
                redactedUrl += nameValPairString
            }
        }

        return redactedUrl
    }

    /// Appends path components to a mutable URL string
    /// - Parameters:
    ///   - pathComponents: Array of path components to append
    ///   - urlString: The mutable string to append to
    static func appendPathComponents(_ pathComponents: [String], toMutableUrlString urlString: NSMutableString) {
        for component in pathComponents {
            if component == "/" {
                continue
            }

            if !component.hasPrefix("/") && !(urlString as String).hasSuffix("/") {
                urlString.append("/")
                urlString.append(component)
            } else if component.hasPrefix("/") && (urlString as String).hasSuffix("/") {
                urlString.append(String(component.dropFirst()))
            } else {
                urlString.append(component)
            }
        }
    }

    /// Returns the value for a given query parameter name
    /// - Parameter paramName: The name of the parameter to retrieve
    /// - Returns: The value of the parameter, or nil if not found
    func sfsdk_valueForParameterName(_ paramName: String) -> String? {
        guard let urlComponents = URLComponents(url: self, resolvingAgainstBaseURL: true),
              let queryItems = urlComponents.queryItems else {
            return nil
        }

        return queryItems.first { $0.name == paramName }?.value
    }
}
