// SFSDKAuthCommand.swift
// SalesforceSDKCore
//
// Created by Raj Rao on 9/28/17.
// Converted to Swift
//
// Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.
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

@objc(SFSDKAuthCommand)
@objcMembers
public class SFSDKAuthCommand: NSObject {

    private var commandParameters: NSMutableDictionary = NSMutableDictionary()

    public var command: String = ""
    public var version: String = SFSDKIDPConstants.kSFSpecVersion
    public var scheme: String = ""
    public var path: String = ""

    public override init() {
        super.init()
    }

    public func requestURL() -> URL {
        assert(!scheme.sfsdk_isEmptyOrWhitespaceAndNewlines(), "Scheme cannot be nil")
        assert(!path.sfsdk_isEmptyOrWhitespaceAndNewlines(), "Path cannot be nil")
        assert(!version.sfsdk_isEmptyOrWhitespaceAndNewlines(), "Version cannot be nil")
        assert(!command.sfsdk_isEmptyOrWhitespaceAndNewlines(), "Command cannot be nil")

        let urlPath = "\(scheme)://\(SFSDKIDPConstants.kSFSpecHost)/\(version)/\(command)"
        var components = URLComponents(string: urlPath)

        var items: [URLQueryItem] = []
        commandParameters.enumerateKeysAndObjects { key, obj, _ in
            guard let keyStr = key as? String, let valueStr = obj as? String else { return }
            let decodedValue = valueStr
                .replacingOccurrences(of: "+", with: " ")
                .removingPercentEncoding ?? valueStr
            items.append(URLQueryItem(name: keyStr, value: decodedValue))
        }
        components?.queryItems = items
        return components?.url ?? URL(string: urlPath) ?? URL(fileURLWithPath: "")
    }

    public func fromRequestURL(_ url: URL) {
        let pathComponents = url.pathComponents
        assert(pathComponents.count > 2, "The path component of the url has to be of the form /v1.0/{COMMAND}")

        // e.g. Path should be of the form /v1.0/{COMMAND}
        version = pathComponents[1]
        command = pathComponents[2]
        scheme = url.scheme ?? ""

        // put all the query params in our backing store
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems {
            for item in queryItems {
                commandParameters[item.name] = item.value ?? ""
            }
        }
    }

    public func isAuthCommand(_ url: URL) -> Bool {
        return url.pathComponents.count > 2 && command.lowercased() == url.pathComponents[2].lowercased()
    }

    public func allParams() -> NSDictionary {
        return NSDictionary(dictionary: commandParameters)
    }

    // MARK: - Internal methods

    public func setParam(_ value: String, forKey key: String) {
        commandParameters.setObject(value, forKey: key as NSCopying)
    }

    public func param(forKey key: String) -> String? {
        return commandParameters.object(forKey: key) as? String
    }

    public func removeParam(_ key: String) {
        commandParameters.removeObject(forKey: key)
    }
}
