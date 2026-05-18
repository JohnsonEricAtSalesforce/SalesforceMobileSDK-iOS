/*
 SFJsonUtils.swift
 SalesforceSDKCommon

 Copyright (c) 2011-present, salesforce.com, inc. All rights reserved.

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

/// Utility class that decouples framework code from the underlying JSON implementation.
@objc(SFJsonUtils)
@objcMembers
public class SFJsonUtils: NSObject {

    // MARK: - Error Tracking

    private static let errorLock = NSLock()
    private static var _lastError: NSError?

    /// Returns the last error that was logged during a JSON conversion operation.
    @objc public class func lastError() -> NSError? {
        errorLock.lock()
        defer { errorLock.unlock() }
        return _lastError
    }

    private class func setLastError(_ error: NSError?) {
        errorLock.lock()
        defer { errorLock.unlock() }
        _lastError = error
    }

    // MARK: - Serialization

    /// Creates the JSON string representation of an object using default options.
    @objc(JSONRepresentation:)
    public class func jsonRepresentation(_ object: Any) -> String? {
        #if DEBUG
        let options: JSONSerialization.WritingOptions = .prettyPrinted
        #else
        let options: JSONSerialization.WritingOptions = []
        #endif
        return jsonRepresentation(object, options: options)
    }

    /// Creates the JSON string representation of an object with the specified options.
    @objc(JSONRepresentation:options:)
    public class func jsonRepresentation(_ object: Any, options: JSONSerialization.WritingOptions) -> String? {
        guard let jsonData = jsonDataRepresentation(object, options: options) else {
            return nil
        }
        return String(data: jsonData, encoding: .utf8)
    }

    /// Creates the JSON Data representation of an object using default options.
    @objc(JSONDataRepresentation:)
    public class func jsonDataRepresentation(_ obj: Any) -> Data? {
        #if DEBUG
        let options: JSONSerialization.WritingOptions = .prettyPrinted
        #else
        let options: JSONSerialization.WritingOptions = []
        #endif
        return jsonDataRepresentation(obj, options: options)
    }

    /// Creates the JSON Data representation of an object with the specified options.
    @objc(JSONDataRepresentation:options:)
    public class func jsonDataRepresentation(_ obj: Any, options: JSONSerialization.WritingOptions) -> Data? {
        guard JSONSerialization.isValidJSONObject(obj) else {
            SalesforceLogger.log(SFJsonUtils.self, level: .debug, message: "invalid object passed to JSONDataRepresentation")
            return nil
        }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: obj, options: options)
            return jsonData
        } catch {
            SalesforceLogger.log(SFJsonUtils.self, level: .debug, message: "WARNING error writing json: \(error)")
            setLastError(error as NSError)
            return nil
        }
    }

    // MARK: - Deserialization

    /// Creates an object from a JSON string.
    @objc public class func object(fromJSONString jsonString: String) -> Any? {
        guard let jsonData = jsonString.data(using: .utf8) else {
            return nil
        }
        return object(fromJSONData: jsonData)
    }

    /// Creates an object from JSON data.
    @objc public class func object(fromJSONData jsonData: Data) -> Any? {
        do {
            let result = try JSONSerialization.jsonObject(with: jsonData, options: .mutableContainers)
            return result
        } catch {
            SalesforceLogger.log(SFJsonUtils.self, level: .debug, message: "WARNING error parsing json: \(error)")
            setLastError(error as NSError)
            return nil
        }
    }

    // MARK: - JSON Path Projection

    /// Pull a value from the json-derived object by path ("." delimited).
    ///
    /// Examples (in pseudo code):
    /// ```
    /// json = {"a": {"b": [{"c":"xx"}, {"c":"xy"}]}}
    /// projectIntoJson(json, "a.b.c") = ["xx", "xy"]
    /// ```
    @objc(projectIntoJson:path:)
    public class func project(intoJson jsonObj: Any, path: String) -> Any? {
        guard !path.isEmpty else {
            return jsonObj
        }
        guard let dict = jsonObj as? NSDictionary else {
            return nil
        }

        let pathElements = path.components(separatedBy: ".")
        return projectIntoJsonHelper(dict, pathElements: pathElements, index: 0)
    }

    // MARK: - Private Helpers

    private class func projectIntoJsonHelper(_ jsonObj: Any?, pathElements: [String], index: Int) -> Any? {
        guard index < pathElements.count else {
            return jsonObj
        }

        guard let jsonObj = jsonObj else {
            return nil
        }

        let pathElement = pathElements[index]

        if let jsonDict = jsonObj as? NSDictionary {
            let dictVal = jsonDict[pathElement]
            return projectIntoJsonHelper(dictVal, pathElements: pathElements, index: index + 1)
        } else if let jsonArr = jsonObj as? NSArray {
            let result = NSMutableArray()
            for arrayElt in jsonArr {
                if let resultPart = projectIntoJsonHelper(arrayElt, pathElements: pathElements, index: index) {
                    result.add(resultPart)
                }
            }
            return result.count == 0 ? nil : result
        }

        return nil
    }
}
