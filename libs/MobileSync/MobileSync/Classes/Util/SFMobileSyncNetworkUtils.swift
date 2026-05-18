/*
 Copyright (c) 2015-present, salesforce.com, inc. All rights reserved.

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
import SalesforceSDKCore

private let kUserAgent = "User-Agent"
private let kMobileSync = "MobileSync"

/// Class to provide network utilities related to MobileSync actions.
@objc(SFMobileSyncNetworkUtils)
@objcMembers
public class SFMobileSyncNetworkUtils: NSObject {

    /// Sends a REST request, after applying the MobileSync user agent string.
    ///
    /// - Parameters:
    ///   - request: The request to send.
    ///   - failureBlock: The block to call if the request fails.
    ///   - successBlock: The block to call if the request succeeds.
    @objc public class func sendRequest(withMobileSyncUserAgent request: RestRequest, failureBlock: @escaping RestRequestFailBlock, successBlock: @escaping SFRestResponseBlock) {
        SFSDKMobileSyncLogger.d(self, message: "sendRequestWithMobileSyncUserAgent:request:\(request)")
        request.setHeaderValue(RestClient.userAgentString(kMobileSync), forHeaderName: kUserAgent)
        let user = UserAccountManager.shared.currentUserAccount
        let restApiInstance: RestClient = (user == nil) ? RestClient.sharedGlobal : RestClient.shared
        restApiInstance.send(request, failureBlock: { response, error, rawResponse in
            SFSDKMobileSyncLogger.e(self, message: "sendRequestWithMobileSyncUserAgent:error:\((error as NSError?)?.code ?? 0):\((error as NSError?)?.domain ?? "")")
            failureBlock(response, error, rawResponse)
        }, successBlock: { response, rawResponse in
            SFSDKMobileSyncLogger.d(self, message: "sendRequestWithMobileSyncUserAgent:response:\(String(describing: response))")
            successBlock(response, rawResponse)
        })
    }
}
