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
import SalesforceSDKCommon

/// This class provides utilities useful to all unit tests based on the Salesforce SDK.
@objc(TestSetupUtils)
public class TestSetupUtils: NSObject {

    private static var credentials: OAuthCredentials?

    /// Loads a set of auth credentials from the 'ui_test_credentials.json' file located in the bundle
    /// associated with the given class, and returns an array of login info.
    /// - Parameter testClass: The class associated with the bundle where the test credentials file lives.
    /// - Returns: An array of login username, password, url dictionaries.
    @objc public class func populateUILoginInfo(fromConfigFileForClass testClass: AnyClass) -> [Any] {
        guard let tokenPath = Bundle(for: testClass).path(forResource: "ui_test_credentials", ofType: "json") else {
            fatalError("UI test config file not found!")
        }
        let fm = FileManager.default
        guard let jsonData = fm.contents(atPath: tokenPath) else {
            fatalError("Could not read UI test config file!")
        }
        guard let jsonArray = SFJsonUtils.object(from: jsonData) as? [Any] else {
            fatalError("Error parsing JSON from config file: \(String(describing: SFJsonUtils.lastError))")
        }
        return jsonArray
    }

    /// Loads a set of auth credentials from the 'test_credentials.json' file located in the bundle
    /// associated with the given class, and configures UserAccountManager and the current account
    /// with the data from that file.
    /// - Parameter testClass: The class associated with the bundle where the test credentials file lives.
    /// - Returns: The configuration data used to configure UserAccountManager.
    @objc public class func populateAuthCredentials(fromConfigFileForClass testClass: AnyClass) -> SFSDKTestCredentialsData {
        guard let tokenPath = Bundle(for: testClass).path(forResource: "test_credentials", ofType: "json") else {
            fatalError("Test config file not found!")
        }
        let fm = FileManager.default
        guard let tokenJson = fm.contents(atPath: tokenPath) else {
            fatalError("Could not read test config file!")
        }
        guard let jsonResponse = SFJsonUtils.object(from: tokenJson) else {
            fatalError("Error parsing JSON from config file: \(String(describing: SFJsonUtils.lastError))")
        }
        return authCredentials(fromJson: jsonResponse, initializeSdk: true)
    }

    /// Loads a set of auth credentials from the provided JSON string, and configures
    /// UserAccountManager and the current account with the data from that JSON.
    /// Salesforce Mobile SDK will be initialized while populating test credentials.
    /// - Parameter testCredentialsJsonString: The test credentials JSON as a string.
    /// - Returns: The configuration data used to configure UserAccountManager.
    @objc public class func populateAuthCredentials(fromString testCredentialsJsonString: String) -> SFSDKTestCredentialsData {
        return populateAuthCredentials(fromString: testCredentialsJsonString, initializeSdk: true)
    }

    /// Loads a set of auth credentials from the provided JSON string, and configures
    /// UserAccountManager and the current account with the data from that JSON.
    /// - Parameters:
    ///   - testCredentialsJsonString: The test credentials JSON as a string.
    ///   - initializeSdk: Indicates if Salesforce Mobile SDK should be initialized.
    /// - Returns: The configuration data used to configure UserAccountManager.
    @objc public class func populateAuthCredentials(fromString testCredentialsJsonString: String, initializeSdk: Bool) -> SFSDKTestCredentialsData {
        guard let jsonResponse = SFJsonUtils.object(from: testCredentialsJsonString) else {
            fatalError("Error parsing JSON from string: \(String(describing: SFJsonUtils.lastError))")
        }
        return authCredentials(fromJson: jsonResponse, initializeSdk: initializeSdk)
    }

    /// Performs a synchronous refresh of the OAuth credentials, which will stage the
    /// remaining auth data (access token, User ID, Org ID, etc.) in UserAccountManager.
    /// `populateAuthCredentials(fromConfigFileForClass:)` is required to run once before
    /// this method will attempt to refresh authentication.
    /// The "user did log in" notification will not be posted.
    @objc public class func synchronousAuthRefresh() {
        synchronousAuthRefresh(withUserDidLoginNotification: false)
    }

    /// Performs a synchronous refresh of the OAuth credentials, which will stage the
    /// remaining auth data (access token, User ID, Org ID, etc.) in UserAccountManager.
    /// `populateAuthCredentials(fromConfigFileForClass:)` is required to run once before
    /// this method will attempt to refresh authentication.
    /// - Parameter postUserDidLogIn: Indicates if the "user did log in" notification should be posted.
    @objc public class func synchronousAuthRefresh(withUserDidLoginNotification postUserDidLogIn: Bool) {
        guard let creds = credentials else {
            fatalError("You must call populateAuthCredentials(fromConfigFileForClass:) before synchronousAuthRefresh")
        }

        let authListener = SFSDKTestRequestListener()
        var user: UserAccount?

        _ = UserAccountManager.shared.refresh(credentials: creds) { result in
            switch result {
            case .success(let (userAccount, authInfo)):
                authListener.returnStatus = kTestRequestStatusDidLoad
                user = userAccount
                // Ensure tests don't change/corrupt the current user credentials.
                if userAccount.credentials.refreshToken == nil {
                    userAccount.credentials = creds
                }
                if postUserDidLogIn {
                    let userInfo: [String: Any] = [
                        UserAccountManager.userInfoAccountKey: userAccount,
                        UserAccountManager.userInfoAuthenticationTypeKey: authInfo
                    ]
                    NotificationCenter.default.post(
                        name: .UserAccountManagerDidLogInUser,
                        object: UserAccountManager.shared,
                        userInfo: userInfo
                    )
                    UserAccountManager.shared.stopCurrentAuthentication { _ in }
                }
            case .failure(let error):
                authListener.lastError = error
                authListener.returnStatus = kTestRequestStatusDidFail
            }
        }

        _ = authListener.waitForCompletion()
        UserAccountManager.shared.currentUserAccount = user

        assert(authListener.returnStatus == kTestRequestStatusDidLoad,
               "After auth attempt, expected status '\(kTestRequestStatusDidLoad)', got '\(authListener.returnStatus ?? "nil")'")
    }

    /// Creates new client credentials using the current OAuth settings.
    @objc public class func newClientCredentials() -> OAuthCredentials {
        let clientId = UserAccountManager.shared.oauthClientID ?? ""
        let identifier = UUID().uuidString
        let creds = OAuthCredentials(identifier: identifier, clientId: clientId, encrypted: true)
        creds.redirectUri = UserAccountManager.shared.oauthCompletionURL
        creds.setValue(UserAccountManager.shared.loginHost, forKey: "domain")
        creds.accessToken = nil
        return creds
    }

    // MARK: - Private

    private class func authCredentials(fromJson jsonResponse: Any, initializeSdk: Bool) -> SFSDKTestCredentialsData {
        guard let dictResponse = jsonResponse as? [String: Any] else {
            fatalError("Error parsing JSON from config file: \(String(describing: SFJsonUtils.lastError))")
        }

        let credsData = SFSDKTestCredentialsData(dict: dictResponse)
        assert(!credsData.refreshToken.isEmpty &&
               !credsData.clientId.isEmpty &&
               !credsData.redirectUri.isEmpty &&
               !credsData.loginHost.isEmpty &&
               !credsData.identityUrl.isEmpty &&
               !credsData.instanceUrl.isEmpty,
               "config credentials are missing! \(dictResponse)")

        // Check whether the test config file has never been edited
        assert(credsData.refreshToken != "__INSERT_TOKEN_HERE__",
               "You need to obtain credentials for your test org and replace test_credentials.json")

        if initializeSdk {
            SalesforceManager.initializeSDK()
        }

        let appconfig = BootConfig()
        appconfig.oauthRedirectURI = credsData.redirectUri
        appconfig.remoteAccessConsumerKey = credsData.clientId
        appconfig.oauthScopes = Set(["web", "api", "openid"])
        SalesforceManager.shared.appConfig = appconfig
        UserAccountManager.shared.oauthClientID = credsData.clientId
        UserAccountManager.shared.oauthCompletionURL = credsData.redirectUri
        UserAccountManager.shared.scopes = Set(["web", "api"])
        UserAccountManager.shared.loginHost = credsData.loginHost

        let newCreds = newClientCredentials()
        newCreds.instanceUrl = URL(string: credsData.instanceUrl)
        if !credsData.apiInstanceUrl.isEmpty {
            newCreds.apiInstanceUrl = URL(string: credsData.apiInstanceUrl)
        }
        newCreds.identityUrl = URL(string: credsData.identityUrl)
        let communityUrlString = credsData.communityUrl
        if !communityUrlString.isEmpty {
            newCreds.communityUrl = URL(string: communityUrlString)
        }
        newCreds.accessToken = credsData.accessToken
        newCreds.refreshToken = credsData.refreshToken
        UserAccountManager.shared.currentUserAccount?.credentials = newCreds
        credentials = newCreds
        return credsData
    }
}
