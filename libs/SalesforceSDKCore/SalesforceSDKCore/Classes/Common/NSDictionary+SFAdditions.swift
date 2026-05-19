// NSDictionary+SFAdditions.swift
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

// MARK: - NSDictionary (SFAdditions)

extension NSDictionary {

    /// Get object from NSDictionary with "/" separated path.
    ///
    /// This method is similar to the built-in valueForKeyPath function except it handles special
    /// values like NSNull and "<nil>" in the NSDictionary element value.
    ///
    /// - Parameter path: Path for the object to retrieve. Use "/" to separate between levels.
    /// - Returns: The object at the given path, or `nil` if not found or path is nil.
    @objc(sfsdk_objectAtPath:)
    public func sfsdk_object(atPath path: String?) -> Any? {
        guard let path = path else { return nil }

        var obj: Any? = self
        let elements = path.components(separatedBy: "/")
        for element in elements {
            guard let dict = obj as? NSDictionary else { return nil }
            obj = dict.sfsdk_nonNullObject(forKey: element)
            if obj == nil {
                return nil
            }
        }

        if let stringObj = obj as? String {
            return NSString.sfsdk_unescapeXMLCharacter(stringObj)
        }
        return obj
    }

    /// Returns an object whose ID is key, or nil.
    /// - Parameter key: The ID of an object, or a null value.
    /// - Returns: An object whose ID is key, or else nil if the key has a value of NSNull
    ///   or an NSString value of "<nil>" or "<null>".
    @objc(sfsdk_nonNullObjectForKey:)
    public func sfsdk_nonNullObject(forKey key: Any?) -> Any? {
        guard let key = key else { return nil }
        let result = object(forKey: key)
        if result is NSNull {
            return nil
        }
        if let stringResult = result as? String,
           (stringResult == "<nil>" || stringResult == "<null>") {
            return nil
        }
        return result
    }

    /// Returns the dictionary's contents reformatted as a JSON string.
    @objc public func sfsdk_jsonString() -> String? {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: self, options: [])
            return String(data: jsonData, encoding: .utf8)
        } catch {
            SFSDKCoreLogger.w(type(of: self), message: "Unable to serialize to JSON string. NSDictionary:\(self). Error:\(error)")
            return "{}"
        }
    }
}
