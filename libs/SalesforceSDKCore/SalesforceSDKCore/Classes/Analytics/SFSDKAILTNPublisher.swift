// SFSDKAILTNPublisher.swift
// SalesforceSDKCore
//
// Created by Bharath Hariharan on 6/19/16.
// Copyright (c) 2016-present, salesforce.com, inc. All rights reserved.
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

private let kSchemaTypeKey = "schemaType"
private let kCode = "code"
private let kAiltn = "ailtn"
private let kData = "data"
private let kLogLines = "logLines"
private let kPayload = "payload"
private let kRestApiSuffix = "connect/proxy/app-analytics-logging"

@objc(SFSDKAILTNPublisher)
@objcMembers
public class SFSDKAILTNPublisher: NSObject, SFSDKAnalyticsPublisher {

    public func publish(_ events: [Any], user: UserAccount, publishComplete publishCompleteBlock: @escaping PublishCompleteBlock) {
        guard events.count > 0 else {
            publishCompleteBlock(false, nil)
            return
        }

        let bodyDictionary = SFSDKAILTNPublisher.buildRequestBody(events)
        SFSDKAILTNPublisher.publishLogLines(bodyDictionary, user: user, publishCompleteBlock: publishCompleteBlock)
    }

    private class func publishLogLines(_ bodyDictionary: [String: Any], user: UserAccount, publishCompleteBlock: @escaping PublishCompleteBlock) {
        guard let restAPI = RestClient.restClient(for: user) else {
            publishCompleteBlock(false, nil)
            return
        }
        let path = "/\(SFRestDefaultAPIVersion)/\(kRestApiSuffix)"
        let request = RestRequest(method: .POST, path: path, queryParams: nil)

        // Adds GZIP compression.
        if let bodyString = dictionaryAsJSONString(bodyDictionary),
           let bodyData = bodyString.data(using: .utf8) {
            let nsData: NSData = bodyData as NSData
            if let gzipped = nsData.perform(NSSelectorFromString("sfsdk_gzipDeflate"))?.takeUnretainedValue() as? Data {
                request.setCustomRequestBodyData(gzipped, contentType: "application/json")
                request.setHeaderValue("gzip", forHeaderName: "Content-Encoding")
                request.setHeaderValue("\(gzipped.count)", forHeaderName: "Content-Length")
            } else {
                request.setCustomRequestBodyData(bodyData, contentType: "application/json")
                request.setHeaderValue("\(bodyData.count)", forHeaderName: "Content-Length")
            }
        }

        restAPI.send(request, failureBlock: { response, error, rawResponse in
            if let error = error {
                let nsError = error as NSError
                SFSDKCoreLogger.e(SFSDKAILTNPublisher.self, message: "Upload failed \(nsError.code) \(error.localizedDescription)")
            }
            publishCompleteBlock(false, error)
        }, successBlock: { response, rawResponse in
            publishCompleteBlock(true, nil)
        })
    }

    private class func buildRequestBody(_ events: [Any]) -> [String: Any] {
        var logLines: [[String: Any]] = []
        for item in events {
            guard var event = item as? NSMutableDictionary else { continue }
            var trackingInfo: [String: Any] = [:]
            trackingInfo[kCode] = kAiltn
            var data: [String: Any] = [:]
            data[kSchemaTypeKey] = event[kSchemaTypeKey]
            event.removeObject(forKey: kSchemaTypeKey)
            data[kPayload] = dictionaryAsJSONString(event as? [String: Any] ?? [:])
            trackingInfo[kData] = data
            logLines.append(trackingInfo)
        }
        return [kLogLines: logLines]
    }

    private class func dictionaryAsJSONString(_ dict: [String: Any]?) -> String? {
        guard let dict = dict, JSONSerialization.isValidJSONObject(dict) else {
            SFSDKCoreLogger.e(SFSDKAILTNPublisher.self, message: "Invalid object passed to JSONDataRepresentation")
            return nil
        }
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: dict, options: [])
            var jsonString = String(data: jsonData, encoding: .utf8)
            jsonString = jsonString?.replacingOccurrences(of: "\\/", with: "/")
            return jsonString
        } catch {
            return nil
        }
    }
}
