// TestSetupUtils.swift
// SalesforceSDKCore
//
// Copyright (c) 2012-present, salesforce.com, inc. All rights reserved.
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

/// This class provides utilities useful to all unit tests based on the Salesforce SDK.
@objc(TestSetupUtils)
@objcMembers
public class TestSetupUtils: NSObject {

    private static var credentials: OAuthCredentials?

    @objc public class func populateUILoginInfo(fromConfigFileFor testClass: AnyClass) -> [Any] {
        guard let tokenPath = Bundle(for: testClass).path(forResource: "ui_test_credentials", ofType: "json") else {
            preconditionFailure("UI test config file not found!")
        }
        let fm = FileManager.default
        guard let jsonData = fm.contents(atPath: tokenPath),
              let jsonArray = SFJsonUtils.object(fromJSONData: jsonData) as? [Any] else {
            preconditionFailure("Error parsing JSON from config file: \(SFJsonUtils.lastError()?.localizedDescription ?? "")")
        }
        return jsonArray
    }

    @objc public class func populateAuthCredentials(fromConfigFileFor testClass: AnyClass) -> SFSDKTestCredentialsData {
        guard let tokenPath = Bundle(for: testClass).path(forResource: "test_credentials", ofType: "json") else {
            preconditionFailure("Test config file not found!")
        }
        let fm = FileManager.default
        guard let tokenJson = fm.contents(atPath: tokenPath),
              let jsonResponse = SFJsonUtils.object(fromJSONData: tokenJson) else {
            preconditionFailure("Error parsing JSON from config file: \(SFJsonUtils.lastError()?.localizedDescription ?? "")")
        }
        return authCredentials(fromJson: jsonResponse, initializeSdk: true)
    }

    @objc public class func populateAuthCredentials(fromString testCredentialsJsonString: String) -> SFSDKTestCredentialsData {
        return populateAuthCredentials(fromString: testCredentialsJsonString, initializeSdk: true)
    }

    @objc public class func populateAuthCredentials(fromString testCredentialsJsonString: String, initializeSdk: Bool) -> SFSDKTestCredentialsData {
        guard let jsonResponse = SFJsonUtils.object(fromJSONString: testCredentialsJsonString) else {
            preconditionFailure("Error parsing JSON from string: \(SFJsonUtils.lastError()?.localizedDescription ?? "")")
        }
        return authCredentials(fromJson: jsonResponse, initializeSdk: initializeSdk)
    }

    @objc public class func synchronousAuthRefresh() {
        synchronousAuthRefresh(withUserDidLoginNotification: false)
    }

    @objc public class func synchronousAuthRefresh(withUserDidLoginNotification postUserDidLogIn: Bool) {
        guard let creds = credentials else {
            preconditionFailure("You must call populateAuthCredentialsFromConfigFileForClass before synchronousAuthRefresh")
        }

        let authListener = SFSDKTestRequestListener()
        var user: UserAccount?

        _ = UserAccountManager.shared.refreshCredentials(creds, completion: { authInfo, userAccount in
            authListener.returnStatus = kTestRequestStatusDidLoad
            user = userAccount
            if userAccount?.credentials.refreshToken == nil {
                userAccount?.credentials = creds
            }
            if postUserDidLogIn {
                let userInfo: [String: Any] = [
                    UserAccountManager.userInfoAccountKey: userAccount,
                    UserAccountManager.userInfoAuthenticationTypeKey: authInfo
                ]
                NotificationCenter.default.post(name: UserAccountManager.didLogInUser, object: UserAccountManager.shared, userInfo: userInfo)
                UserAccountManager.shared.stopCurrentAuthentication { _ in }
            }
        }, failure: { authInfo, error in
            authListener.lastError = error as NSError
            authListener.returnStatus = kTestRequestStatusDidFail
        })

        _ = authListener.waitForCompletion()
        UserAccountManager.shared.perform(NSSelectorFromString("setCurrentUserInternal:"), with: user)
        assert(authListener.returnStatus == kTestRequestStatusDidLoad, "After auth attempt, expected status '\(kTestRequestStatusDidLoad)', got '\(authListener.returnStatus ?? "nil")'")
    }

    @objc public class func newClientCredentials() -> OAuthCredentials {
        let userAccountManager = UserAccountManager.shared
        let identifier = userAccountManager.perform(NSSelectorFromString("uniqueUserAccountIdentifier:"), with: userAccountManager.oauthClientID ?? "")?.takeUnretainedValue() as? String ?? UUID().uuidString
        guard let creds = OAuthCredentials.credentials(identifier: identifier, clientId: userAccountManager.oauthClientID ?? "", encrypted: true, storageType: .keychain) else {
            preconditionFailure("Failed to create OAuthCredentials")
        }
        creds.setValue(userAccountManager.oauthClientID, forKey: "clientId")
        creds.setValue(userAccountManager.oauthCompletionURL, forKey: "redirectUri")
        creds.setValue(userAccountManager.loginHost, forKey: "domain")
        creds.setValue(nil, forKey: "accessToken")
        return creds
    }

    private class func authCredentials(fromJson jsonResponse: Any, initializeSdk: Bool) -> SFSDKTestCredentialsData {
        guard let dictResponse = jsonResponse as? [String: Any] else {
            preconditionFailure("Error parsing JSON from config file: \(SFJsonUtils.lastError()?.localizedDescription ?? "")")
        }
        let credsData = SFSDKTestCredentialsData(dict: dictResponse)

        assert(!credsData.refreshToken.isEmpty && !credsData.clientId.isEmpty && !credsData.redirectUri.isEmpty && !credsData.loginHost.isEmpty && !credsData.identityUrl.isEmpty && !credsData.instanceUrl.isEmpty, "Config credentials are missing!")

        assert(credsData.refreshToken != "__INSERT_TOKEN_HERE__", "You need to obtain credentials for your test org and replace test_credentials.json")

        if initializeSdk {
            SalesforceSDKManager.initializeSDK()
        }

        let configDict: NSDictionary = [
            "remoteAccessConsumerKey": credsData.clientId,
            "oauthRedirectURI": credsData.redirectUri,
            "oauthScopes": ["web", "api", "openid"]
        ]
        if let appconfig = BootConfig(dict: configDict) {
            SalesforceSDKManager.shared.appConfig = appconfig
        }
        UserAccountManager.shared.oauthClientID = credsData.clientId
        UserAccountManager.shared.oauthCompletionURL = credsData.redirectUri
        UserAccountManager.shared.scopes = Set(["web", "api"])
        UserAccountManager.shared.loginHost = credsData.loginHost

        let newCreds = newClientCredentials()
        newCreds.setValue(URL(string: credsData.instanceUrl), forKey: "instanceUrl")
        if !credsData.apiInstanceUrl.isEmpty {
            newCreds.setValue(URL(string: credsData.apiInstanceUrl), forKey: "apiInstanceUrl")
        }
        newCreds.setValue(URL(string: credsData.identityUrl), forKey: "identityUrl")
        if !credsData.communityUrl.isEmpty {
            newCreds.setValue(URL(string: credsData.communityUrl), forKey: "communityUrl")
        }
        newCreds.setValue(credsData.accessToken, forKey: "accessToken")
        newCreds.setValue(credsData.refreshToken, forKey: "refreshToken")
        UserAccountManager.shared.currentUserAccount?.credentials = newCreds
        credentials = newCreds
        return credsData
    }
}
