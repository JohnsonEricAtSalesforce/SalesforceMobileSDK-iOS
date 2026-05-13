/*
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

/// This class helps decouple framework code from the underlying JSON implementation.
@objc(SFJsonUtils)
@objcMembers
public class SFJsonUtils: NSObject {

    private static var _lastError: NSError?
    private static let lastErrorLock = NSLock()

    /// The last error that was logged during a JSON conversion operation.
    @objc
    public static var lastError: NSError? {
        lastErrorLock.lock()
        defer { lastErrorLock.unlock() }
        return _lastError
    }

    /// Creates the JSON representation of an object.
    /// - Parameter object: The object to JSON-ify
    /// - Returns: a JSON string representation of an Objective-C object
    @objc(JSONRepresentation:)
    public static func jsonRepresentation(_ object: Any) -> String? {
        #if DEBUG
        let options: JSONSerialization.WritingOptions = [.prettyPrinted]
        #else
        let options: JSONSerialization.WritingOptions = []
        #endif
        return jsonRepresentation(object, options: options)
    }

    /// Creates the JSON representation of an object.
    /// - Parameters:
    ///   - object: The object to JSON-ify
    ///   - options: for json-ization
    /// - Returns: a JSON string representation of an Objective-C object
    @objc(JSONRepresentation:options:)
    public static func jsonRepresentation(_ object: Any, options: JSONSerialization.WritingOptions) -> String? {
        guard let jsonData = jsonDataRepresentation(object, options: options) else {
            return nil
        }
        return String(data: jsonData, encoding: .utf8)
    }

    /// Creates the JSON-as-NSData representation of an object.
    /// - Parameter obj: The object to JSON-ify.
    /// - Returns: A JSON string in NSData format, UTF8 encoded.
    @objc(JSONDataRepresentation:)
    public static func jsonDataRepresentation(_ obj: Any) -> Data? {
        #if DEBUG
        let options: JSONSerialization.WritingOptions = [.prettyPrinted]
        #else
        let options: JSONSerialization.WritingOptions = []
        #endif
        return jsonDataRepresentation(obj, options: options)
    }

    /// Creates the JSON-as-NSData representation of an object.
    /// - Parameters:
    ///   - obj: The object to JSON-ify.
    ///   - options: for json-ization
    /// - Returns: A JSON string in NSData format, UTF8 encoded.
    @objc(JSONDataRepresentation:options:)
    public static func jsonDataRepresentation(_ obj: Any, options: JSONSerialization.WritingOptions) -> Data? {
        guard JSONSerialization.isValidJSONObject(obj) else {
            SFLogger.log(SFJsonUtils.self, level: .debug, message: "invalid object passed to JSONDataRepresentation???")
            return nil
        }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: obj, options: options)
            return jsonData
        } catch {
            let nsError = error as NSError
            SFLogger.log(SFJsonUtils.self, level: .debug, message: "WARNING error writing json: \(nsError)")
            lastErrorLock.lock()
            _lastError = nsError
            lastErrorLock.unlock()
            return nil
        }
    }

    /// Creates an object from a string of JSON data.
    /// - Parameter jsonString: A JSON object string.
    /// - Returns: An Objective-C object such as an NSDictionary or NSArray.
    @objc(objectFromJSONString:)
    public static func object(from jsonString: String?) -> Any? {
        guard let jsonString = jsonString,
              let jsonData = jsonString.data(using: .utf8) else {
            return nil
        }
        return object(from: jsonData)
    }

    /// Creates an object from a JSON-as-NSData object.
    /// - Parameter jsonData: JSON data in an NSData wrapper (UTF8 encoding assumed).
    /// - Returns: An Objective-C object such as an NSDictionary or NSArray.
    @objc(objectFromJSONData:)
    public static func object(from jsonData: Data?) -> Any? {
        guard let jsonData = jsonData else {
            return nil
        }

        do {
            let result = try JSONSerialization.jsonObject(with: jsonData, options: [.mutableContainers])
            return result
        } catch {
            let nsError = error as NSError
            SFLogger.log(SFJsonUtils.self, level: .debug, message: "WARNING error parsing json: \(nsError)")
            lastErrorLock.lock()
            _lastError = nsError
            lastErrorLock.unlock()
            return nil
        }
    }

    /// Pull a value from the json-derived object by path ("." delimited).
    ///
    /// Examples (in pseudo code):
    ///
    /// json = {"a": {"b": [{"c":"xx"}, {"c":"xy"}, {"d": [{"e":1}, {"e":2}]}, {"d": [{"e":3}, {"e":4}]}] }}
    /// projectIntoJson(jsonObj, "a") = {"b": [{"c":"xx"}, {"c":"xy"}, {"d": [{"e":1}, {"e":2}]}, {"d": [{"e":3}, {"e":4}]} ]}
    /// projectIntoJson(json, "a.b") = [{c:"xx"}, {c:"xy"}, {"d": [{"e":1}, {"e":2}]}, {"d": [{"e":3}, {"e":4}]}]
    /// projectIntoJson(json, "a.b.c") = ["xx", "xy"]                                     // new in 4.1
    /// projectIntoJson(json, "a.b.d") = [[{"e":1}, {"e":2}], [{"e":3}, {"e":4}]]         // new in 4.1
    /// projectIntoJson(json, "a.b.d.e") = [[1, 2], [3, 4]]                               // new in 4.1
    /// - Parameters:
    ///   - jsonObj: The JSON object that contains the requested JSON path.
    ///   - path: Requested JSON path.
    @objc(projectIntoJson:path:)
    public static func projectIntoJson(_ jsonObj: [String: Any], path: String) -> Any? {
        guard !path.isEmpty else {
            return jsonObj
        }

        let pathElements = path.components(separatedBy: ".")
        return projectIntoJsonHelper(jsonObj, pathElements: pathElements, index: 0)
    }

    private static func projectIntoJsonHelper(_ jsonObj: Any?, pathElements: [String], index: Int) -> Any? {
        guard index < pathElements.count else {
            return jsonObj
        }

        guard let jsonObj = jsonObj else {
            return nil
        }

        let pathElement = pathElements[index]

        if let jsonDict = jsonObj as? [String: Any] {
            let dictVal = jsonDict[pathElement]
            return projectIntoJsonHelper(dictVal, pathElements: pathElements, index: index + 1)
        } else if let jsonArr = jsonObj as? [Any] {
            var result: [Any] = []
            for arrayElt in jsonArr {
                if let resultPart = projectIntoJsonHelper(arrayElt, pathElements: pathElements, index: index) {
                    result.append(resultPart)
                }
            }
            return result.isEmpty ? nil : result
        }

        return nil
    }
}
