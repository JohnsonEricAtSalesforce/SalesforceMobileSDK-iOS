//
//  SFSDKCompositeResponse.swift
//  SalesforceSDKCore
//
//  Copyright (c) 2019-present, salesforce.com, inc. All rights reserved.
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

// MARK: - Constants

/// Key for the composite response array.
public let kCompositeResponse: String = "compositeResponse"

/// Key for the HTTP status code.
public let kHttpStatusCode: String = "httpStatusCode"

/// Key for the HTTP headers.
public let kHttpHeaders: String = "httpHeaders"

/// Key for the reference ID.
public let kReferenceId: String = "referenceId"

/// Key for the body.
public let kBody: String = "body"

// MARK: - CompositeSubResponse

/// Represents a single sub-response from a composite request.
@objc(SFSDKCompositeSubResponse)
@objcMembers
public class CompositeSubResponse: NSObject {

    /// The raw dictionary for this sub-response.
    public private(set) var dict: Any

    /// The body of the response.
    public private(set) var body: Any?

    /// The HTTP headers from the response.
    public private(set) var httpHeaders: [String: String] = [:]

    /// The HTTP status code from the response.
    public private(set) var httpStatusCode: Int = 0

    /// The reference ID associated with this sub-response.
    public private(set) var referenceId: String = ""

    /// Initializes a CompositeSubResponse from a dictionary.
    @objc public init(dictionary dict: [String: Any]) {
        self.dict = dict
        super.init()
        self.body = dict[kBody]
        self.httpHeaders = (dict[kHttpHeaders] as? [String: String]) ?? [:]
        self.httpStatusCode = (dict[kHttpStatusCode] as? NSNumber)?.intValue ?? 0
        self.referenceId = (dict[kReferenceId] as? String) ?? ""
    }

    override public var description: String {
        return "\(dict)"
    }
}

// MARK: - CompositeResponse

/// Represents the full response from a composite request.
@objc(SFSDKCompositeResponse)
@objcMembers
public class CompositeResponse: NSObject {

    /// The array of sub-responses.
    public private(set) var subResponses: [CompositeSubResponse] = []

    /// Initializes a CompositeResponse from a dictionary.
    @objc public init(dictionary dict: [String: Any]) {
        super.init()
        if let results = dict[kCompositeResponse] as? [[String: Any]] {
            var responses: [CompositeSubResponse] = []
            for resultDict in results {
                responses.append(CompositeSubResponse(dictionary: resultDict))
            }
            subResponses = responses
        }
    }
}
