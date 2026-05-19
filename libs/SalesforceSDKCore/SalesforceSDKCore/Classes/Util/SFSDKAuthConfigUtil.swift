// Copyright (c) 2018-present, salesforce.com, inc. All rights reserved.
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
import SalesforceSDKCommon

@objc(SFSDKAuthConfigUtil)
@objcMembers public class SFSDKAuthConfigUtil: NSObject {

    public typealias MyDomainAuthConfigBlock = (SFOAuthOrgAuthConfiguration?, Error?) -> Void

    private static let kSFOAuthEndPointAuthConfiguration = "/.well-known/auth-configuration"
    private static let kSandboxLoginURL = "test.salesforce.com"
    private static let kProductionLoginURL = "login.salesforce.com"
    private static let kWelcomeLoginURL = "welcome.salesforce.com/discovery"

    @objc public class func getMyDomainAuthConfig(_ authConfigBlock: @escaping MyDomainAuthConfigBlock, loginDomain: String) {
        let orgConfigUrl = "https://\(loginDomain)\(kSFOAuthEndPointAuthConfiguration)"

        if loginDomain == kSandboxLoginURL || loginDomain == kProductionLoginURL || loginDomain == kWelcomeLoginURL {
            SFSDKCoreLogger.d(SFSDKAuthConfigUtil.self, message: "\(#function) Skipping auth config retrieval for login pool URL")
            authConfigBlock(nil, nil)
            return
        }

        SFSDKCoreLogger.i(SFSDKAuthConfigUtil.self, message: "\(#function) Checking if advanced authentication configured. Retrieving auth configuration from \(orgConfigUrl)")

        guard let url = URL(string: orgConfigUrl) else {
            authConfigBlock(nil, nil)
            return
        }

        let orgConfigRequest = NSMutableURLRequest(url: url)
        let network = Network.sharedEphemeralInstance()

        network.sendRequest(orgConfigRequest as URLRequest) { data, response, error in
            if let error = error {
                SFSDKCoreLogger.w(SFSDKAuthConfigUtil.self, message: "Org config request failed with error: Error Code: \(error._code), Description: \(error.localizedDescription)")
                authConfigBlock(nil, error)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                authConfigBlock(nil, nil)
                return
            }

            let statusCode = httpResponse.statusCode
            if statusCode >= 200 && statusCode <= 299 {
                guard let data = data else {
                    SFSDKCoreLogger.w(SFSDKAuthConfigUtil.self, message: "No org auth config data returned from \(orgConfigUrl)")
                    authConfigBlock(nil, nil)
                    return
                }

                guard let configDict = SFJsonUtils.object(fromJSONData: data) as? [String: Any] else {
                    let jsonParseError = SFJsonUtils.lastError()
                    SFSDKCoreLogger.e(SFSDKAuthConfigUtil.self, message: "Could not parse org auth config response from \(orgConfigUrl): \(jsonParseError?.localizedDescription ?? "unknown error")")
                    authConfigBlock(nil, jsonParseError)
                    return
                }

                SFSDKCoreLogger.i(SFSDKAuthConfigUtil.self, message: "Successfully retrieved org auth config data from \(orgConfigUrl)")
                let orgAuthConfig = SFOAuthOrgAuthConfiguration(configDict: configDict as NSDictionary)
                authConfigBlock(orgAuthConfig, nil)
            } else {
                SFSDKCoreLogger.w(SFSDKAuthConfigUtil.self, message: "Org config request failed with error: Status Code: \(statusCode)")
                authConfigBlock(nil, nil)
            }
        }
    }
}
