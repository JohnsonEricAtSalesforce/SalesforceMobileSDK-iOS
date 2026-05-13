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

public let kCompositeResponse = "compositeResponse"
public let kHttpStatusCode = "httpStatusCode"
public let kHttpHeaders = "httpHeaders"
public let kReferenceId = "referenceId"
public let kBody = "body"

@objc(SFSDKCompositeSubResponse)
@objcMembers
public class CompositeSubResponse: NSObject {
    public let dict: Any
    public let body: Any
    public let httpHeaders: [String: String]
    public let httpStatusCode: Int
    public let referenceId: String

    @objc
    public init(with dict: [String: Any]) {
        self.dict = dict
        self.body = dict[kBody] ?? NSNull()
        self.httpHeaders = dict[kHttpHeaders] as? [String: String] ?? [:]
        self.httpStatusCode = (dict[kHttpStatusCode] as? NSNumber)?.intValue ?? 0
        self.referenceId = dict[kReferenceId] as? String ?? ""
        super.init()
    }

    public override var description: String {
        if let dict = dict as? [String: Any] {
            return dict.description
        }
        return String(describing: dict)
    }
}

@objc(SFSDKCompositeResponse)
@objcMembers
public class CompositeResponse: NSObject {
    public let subResponses: [CompositeSubResponse]

    @objc
    public init(with dict: [String: Any]) {
        var subResponsesArray = [CompositeSubResponse]()
        if let results = dict[kCompositeResponse] as? [[String: Any]] {
            for result in results {
                subResponsesArray.append(CompositeSubResponse(with: result))
            }
        }
        self.subResponses = subResponsesArray
        super.init()
    }
}
