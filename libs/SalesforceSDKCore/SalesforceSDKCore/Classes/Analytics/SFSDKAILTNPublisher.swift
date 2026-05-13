/*
 AILTNPublisher.swift
 SalesforceSDKCore

 Created by Bharath Hariharan on 6/19/16.

 Copyright (c) 2016-present, salesforce.com, inc. All rights reserved.

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
import SalesforceAnalytics

@objc(SFSDKAILTNPublisher)
public class SFSDKAILTNPublisher: NSObject, SFSDKAnalyticsPublisher {

    private static let kCode = "code"
    private static let kAiltn = "ailtn"
    private static let kData = "data"
    private static let kLogLines = "logLines"
    private static let kPayload = "payload"
    private static let kRestApiSuffix = "connect/proxy/app-analytics-logging"

    @objc(publish:user:publishCompleteBlock:)
    public func publish(
        _ events: [Any],
        user: SFUserAccount?,
        publishCompleteBlock: @escaping PublishCompleteBlock
    ) {
        guard let events = events as? [[String: Any]], !events.isEmpty else {
            publishCompleteBlock(false, nil)
            return
        }

        let bodyDictionary = Self.buildRequestBody(events)
        Self.publishLogLines(bodyDictionary, user: user, publishCompleteBlock: publishCompleteBlock)
    }

    private static func publishLogLines(
        _ bodyDictionary: [String: Any],
        user: SFUserAccount?,
        publishCompleteBlock: @escaping PublishCompleteBlock
    ) {
        guard let user = user else {
            publishCompleteBlock(false, nil)
            return
        }

        guard let restAPI = SFRestAPI.restClient(for: user) else {
            publishCompleteBlock(false, nil)
            return
        }
        let path = "/\(SFRestDefaultAPIVersion)/\(kRestApiSuffix)"
        let request = RestRequest.request(withMethod: .POST, path: path, queryParams: nil)

        let bodyString = dictionaryAsJSONString(bodyDictionary)
        if let bodyData = bodyString?.data(using: .utf8),
           let postData = (bodyData as NSData).sfsdk_gzipDeflate {
            request.setCustomRequestBodyData(postData, contentType: "application/json")
            request.setHeaderValue("gzip", forHeaderName: "Content-Encoding")
            request.setHeaderValue("\(postData.count)", forHeaderName: "Content-Length")
        }

        restAPI.send(request, failureBlock: { response, error, rawResponse in
            if let error = error {
                let nsError = error as NSError
                SFSDKCoreLogger.e(Self.self, message: "Upload failed \(nsError.code) \(error.localizedDescription)")
            }
            publishCompleteBlock(false, error)
        }, successBlock: { response, rawResponse in
            publishCompleteBlock(true, nil)
        })
    }

    private static func buildRequestBody(_ events: [[String: Any]]) -> [String: Any] {
        var body: [String: Any] = [:]
        var logLines: [[String: Any]] = []

        for var event in events {
            var trackingInfo: [String: Any] = [:]
            trackingInfo[kCode] = kAiltn

            var data: [String: Any] = [:]
            if let schemaType = event[kSchemaTypeKey] {
                data[kSchemaTypeKey] = schemaType
                event.removeValue(forKey: kSchemaTypeKey)
            }
            data[kPayload] = dictionaryAsJSONString(event)
            trackingInfo[kData] = data
            logLines.append(trackingInfo)
        }

        body[kLogLines] = logLines
        return body
    }

    private static func dictionaryAsJSONString(_ dict: [String: Any]) -> String? {
        guard JSONSerialization.isValidJSONObject(dict) else {
            SFSDKCoreLogger.e(Self.self, message: "\(Self.self) - invalid object passed to JSONDataRepresentation")
            return nil
        }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: dict, options: [])
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                return jsonString.replacingOccurrences(of: "\\/", with: "/")
            }
        } catch {
            return nil
        }

        return nil
    }
}
