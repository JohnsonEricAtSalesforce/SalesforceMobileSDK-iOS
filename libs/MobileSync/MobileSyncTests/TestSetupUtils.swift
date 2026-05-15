/*
 Copyright (c) 2012-present, salesforce.com, inc. All rights reserved.

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
import SalesforceSDKCommon

let kTestRequestStatusWaiting = "waiting"
let kTestRequestStatusDidLoad = "didLoad"
let kTestRequestStatusDidFail = "didFail"

class SFSDKTestRequestListener: NSObject {
    var dataResponse: Any?
    var lastError: NSError?
    var returnStatus: String?
    var maxWaitTime: TimeInterval = 30.0

    override init() {
        super.init()
        self.returnStatus = kTestRequestStatusWaiting
    }

    @discardableResult
    func waitForCompletion() -> String {
        let startTime = Date()
        while returnStatus == kTestRequestStatusWaiting {
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed > maxWaitTime {
                SFSDKCoreLogger.d(type(of: self), message: "Request took too long (> \(elapsed) secs) to complete.")
                return kTestRequestStatusDidFail
            }
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        }
        return returnStatus ?? kTestRequestStatusDidFail
    }
}

class TestSetupUtils: NSObject {

    private static var credentials: OAuthCredentials?

    @discardableResult
    static func populateAuthCredentialsFromConfigFile(for testClass: AnyClass) -> Any? {
        guard let tokenPath = Bundle(for: testClass).path(forResource: "test_credentials", ofType: "json") else {
            fatalError("Test config file not found!")
        }
        let fm = FileManager.default
        guard let tokenJson = fm.contents(atPath: tokenPath),
              let jsonResponse = SFJsonUtils.object(from: tokenJson) as? [String: Any] else {
            fatalError("Error parsing JSON from config file")
        }
        return authCredentials(from: jsonResponse, initializeSdk: true)
    }

    static func synchronousAuthRefresh() {
        guard let creds = credentials else {
            fatalError("You must call populateAuthCredentialsFromConfigFile before synchronousAuthRefresh")
        }
        let listener = SFSDKTestRequestListener()

        _ = UserAccountManager.shared.refresh(credentials: creds) { result in
            switch result {
            case .success(let (userAccount, _)):
                listener.returnStatus = kTestRequestStatusDidLoad
                if userAccount.credentials.refreshToken == nil {
                    userAccount.credentials = creds
                }
                UserAccountManager.shared.currentUserAccount = userAccount
            case .failure(let error):
                listener.lastError = error as NSError
                listener.returnStatus = kTestRequestStatusDidFail
            }
        }
        listener.waitForCompletion()
        assert(listener.returnStatus == kTestRequestStatusDidLoad,
               "After auth attempt, expected status '\(kTestRequestStatusDidLoad)', got '\(listener.returnStatus ?? "nil")'")
    }

    @discardableResult
    private static func authCredentials(from jsonResponse: [String: Any], initializeSdk: Bool) -> Any? {
        let refreshToken = jsonResponse["refresh_token"] as? String ?? ""
        let clientId = jsonResponse["test_client_id"] as? String ?? ""
        let redirectUri = jsonResponse["test_redirect_uri"] as? String ?? ""
        let loginHost = jsonResponse["test_login_domain"] as? String ?? ""
        let identityUrl = jsonResponse["identity_url"] as? String ?? ""
        let instanceUrl = jsonResponse["instance_url"] as? String ?? ""
        let accessToken = jsonResponse["access_token"] as? String ?? ""
        let apiInstanceUrl = jsonResponse["api_instance_url"] as? String ?? ""
        let communityUrl = jsonResponse["community_url"] as? String ?? ""

        assert(!refreshToken.isEmpty && !clientId.isEmpty && !redirectUri.isEmpty &&
               !loginHost.isEmpty && !identityUrl.isEmpty && !instanceUrl.isEmpty,
               "config credentials are missing!")
        assert(refreshToken != "__INSERT_TOKEN_HERE__",
               "You need to obtain credentials for your test org and replace test_credentials.json")

        if initializeSdk {
            SalesforceManager.initializeSDK()
        }

        let appconfig = BootConfig()
        appconfig.oauthRedirectURI = redirectUri
        appconfig.remoteAccessConsumerKey = clientId
        appconfig.oauthScopes = Set(["web", "api", "openid"])
        SalesforceManager.shared.appConfig = appconfig
        UserAccountManager.shared.oauthClientID = clientId
        UserAccountManager.shared.oauthCompletionURL = redirectUri
        UserAccountManager.shared.scopes = Set(["web", "api"])
        UserAccountManager.shared.loginHost = loginHost

        let identifier = "\(clientId)_\(UUID().uuidString)"
        let creds = OAuthCredentials(identifier: identifier, clientId: clientId, encrypted: true)
        creds.redirectUri = redirectUri
        creds.accessToken = nil
        creds.instanceUrl = URL(string: instanceUrl)
        if !apiInstanceUrl.isEmpty {
            creds.apiInstanceUrl = URL(string: apiInstanceUrl)
        }
        creds.identityUrl = URL(string: identityUrl)
        if !communityUrl.isEmpty {
            creds.communityUrl = URL(string: communityUrl)
        }
        creds.accessToken = accessToken
        creds.refreshToken = refreshToken
        UserAccountManager.shared.currentUserAccount?.credentials = creds
        credentials = creds
        return jsonResponse
    }
}
