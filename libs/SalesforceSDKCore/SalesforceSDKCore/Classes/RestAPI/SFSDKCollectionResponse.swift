//
//  SFSDKCollectionResponse.swift
//  SalesforceSDKCore
//
//  Copyright (c) 2022-present, salesforce.com, inc. All rights reserved.
//
//  Redistribution and use of this software in source and binary forms, with or without modification,
//  are permitted provided that the following conditions are met:
//  * Redistributions of source code must retain the above copyright notice, this list of conditions
//    and the following disclaimer.
//  * Redistributions in binary form must reproduce the above copyright notice, this list of
//    conditions and the following disclaimer in the documentation and/or other materials provided
//    with the distribution.
//  * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
//    endorse or promote products derived from this software without specific prior written
//    permission of salesforce.com, inc.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
//  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
//  FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
//  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
//  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
//  WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

import Foundation

// MARK: - CollectionErrorResponse

/// Represents an error in a collection sub-response.
@objc(SFSDKCollectionErrorResponse)
@objcMembers
public class CollectionErrorResponse: NSObject {

    /// The status code string for this error.
    public private(set) var statusCode: String = ""

    /// The error message.
    public private(set) var message: String = ""

    /// The fields related to this error.
    public private(set) var fields: [String] = []

    /// The raw JSON dictionary.
    public private(set) var json: [String: Any] = [:]

    /// Initializes a CollectionErrorResponse from a dictionary.
    @objc public init(dictionary dict: [String: Any]) {
        super.init()
        self.json = dict
        self.statusCode = (dict["statusCode"] as? String) ?? ""
        self.message = (dict["message"] as? String) ?? ""
        self.fields = (dict["fields"] as? [String]) ?? []
    }

    override public var description: String {
        return "\(json)"
    }
}

// MARK: - CollectionSubResponse

/// Represents a single sub-response from a collection request.
@objc(SFSDKCollectionSubResponse)
@objcMembers
public class CollectionSubResponse: NSObject {

    /// The object ID from the response.
    public private(set) var objectId: String = ""

    /// Whether this sub-response was successful.
    public private(set) var success: Bool = false

    /// The array of errors, if any.
    public private(set) var errors: [CollectionErrorResponse] = []

    /// The raw JSON dictionary.
    public private(set) var json: [String: Any] = [:]

    /// Initializes a CollectionSubResponse from a dictionary.
    @objc public init(dictionary dict: [String: Any]) {
        super.init()
        self.json = dict
        self.objectId = (dict["id"] as? String) ?? ""
        self.success = (dict["success"] as? NSNumber)?.boolValue ?? false
        if let rawErrors = dict["errors"] as? [[String: Any]] {
            var parsedErrors: [CollectionErrorResponse] = []
            for errorDict in rawErrors {
                parsedErrors.append(CollectionErrorResponse(dictionary: errorDict))
            }
            self.errors = parsedErrors
        }
    }

    override public var description: String {
        return "\(json)"
    }
}

// MARK: - CollectionResponse

/// Represents the full response from a collection request.
@objc(SFSDKCollectionResponse)
@objcMembers
public class CollectionResponse: NSObject {

    /// The array of sub-responses.
    public private(set) var subResponses: [CollectionSubResponse] = []

    /// Initializes a CollectionResponse from an array of dictionaries.
    @objc public init(array: [[String: Any]]) {
        super.init()
        var responses: [CollectionSubResponse] = []
        for dict in array {
            responses.append(CollectionSubResponse(dictionary: dict))
        }
        subResponses = responses
    }
}
