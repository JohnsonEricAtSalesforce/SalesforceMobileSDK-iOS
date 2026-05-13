/*
 SFSDKAuthCommand.swift
 SalesforceSDKCore

 Created by Raj Rao on 9/28/17.

 Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.

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

@objc(SFSDKAuthCommand)
public class SFSDKAuthCommand: NSObject {

    private var commandParameters: NSMutableDictionary = NSMutableDictionary()

    @objc public var command: String = ""
    @objc public var version: String = kSFSpecVersion
    @objc public var scheme: String = ""
    @objc public var path: String = ""

    public override init() {
        super.init()
    }

    @objc public func requestURL() -> URL? {
        assert(!scheme.sfsdk_isEmptyOrWhitespaceAndNewlines, "Scheme cannot be nil")
        assert(!path.sfsdk_isEmptyOrWhitespaceAndNewlines, "Path cannot be nil")
        assert(!version.sfsdk_isEmptyOrWhitespaceAndNewlines, "Version cannot be nil")
        assert(!command.sfsdk_isEmptyOrWhitespaceAndNewlines, "Command cannot be nil")

        let urlPath = "\(scheme)://\(kSFSpecHost)/\(version)/\(command)"

        guard var components = URLComponents(string: urlPath) else {
            return nil
        }

        var items: [URLQueryItem] = []
        commandParameters.forEach { key, obj in
            if let key = key as? String, var value = obj as? String {
                value = value.replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? value
                items.append(URLQueryItem(name: key, value: value))
            }
        }
        components.queryItems = items
        return components.url
    }

    @objc public func from(requestURL url: URL) {
        let pathComponents = url.pathComponents
        assert(pathComponents.count > 2, "The path component of the url has to be of the form /v1.0/{COMMAND}")

        // e.g. Path should be of the form /v1.0/{COMMAND}
        version = pathComponents[1]
        command = pathComponents[2]

        scheme = url.scheme ?? ""

        // put all the query params in our backing store
        if let dictionary = (url as NSURL).sfsdk_dictionaryFromQuery {
            commandParameters.addEntries(from: dictionary)
        }
    }

    @objc public func isAuthCommand(_ url: URL) -> Bool {
        return url.pathComponents.count > 2 && command.lowercased() == url.pathComponents[2].lowercased()
    }

    @objc public func allParams() -> [String: Any] {
        return commandParameters as! [String: Any]
    }

    // Internal methods
    @objc public func setParam(_ value: String, forKey key: String) {
        commandParameters[key] = value
    }

    @objc public func param(forKey key: String) -> String? {
        return commandParameters[key] as? String
    }

    @objc public func removeParam(_ key: String) {
        commandParameters.removeObject(forKey: key)
    }
}
