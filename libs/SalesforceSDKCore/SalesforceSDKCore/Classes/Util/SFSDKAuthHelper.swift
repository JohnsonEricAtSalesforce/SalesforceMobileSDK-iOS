/*
 SFSDKAuthHelper.swift
 SalesforceSDKCore

 Created by Raj Rao on 07/19/18.
 Copyright (c) 2018-present, salesforce.com, inc. All rights reserved.

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
import UIKit

@objc(SFSDKAuthHelper)
public class SFSDKAuthHelper: NSObject {

    /**
     Initiate a login flow if the user is not already logged in to Salesforce and if the app config's `shouldAuthenticate` flag is set to false.

     @param completionBlock Block that executes immediately if the user is already logged in, or if the app config's `shouldAuthenticate` is set to false.
                            Otherwise, this block executes after the user logs in successfully, if login is required.
     */
    @objc
    public static func loginIfRequired(_ completionBlock: (() -> Void)?) {
        loginIfRequired(SFSDKWindowManager.shared.defaultScene(), completion: completionBlock)
    }

    /**
     Initiate a login flow if the user is not already logged in to Salesforce and if the app config's `shouldAuthenticate` flag is set to false.

     @param scene Scene that login is initiated for.
     @param completionBlock Block that executes immediately if the user is already logged in, or if the app config's `shouldAuthenticate` is set to false.
                            Otherwise, this block executes after the user logs in successfully, if login is required.
     */
    @objc
    public static func loginIfRequired(_ scene: UIScene?, completion completionBlock: (() -> Void)?) {
        loginIfRequired(scene, frontDoorBridgeUrl: nil, codeVerifier: nil, completion: completionBlock)
    }

    /**
     Initiate a login flow if the user is not already logged in to Salesforce and if the app config's
     `shouldAuthenticate` flag is set to false.

     Parameters here include support for an optional overriding Salesforce Identity UI Bridge API front door bridge
     URL with an optional overriding code verifier.  These override the default login URL to load and the default
     code verifier that would be generated for it when web server authentication is enabled.  One use case for this
     is automatic login from a front door bridge URL provided as part of a QR code log in set up.

     @param scene Scene that login is initiated for.
     @param completionBlock Block that executes immediately if the user is already logged in or if the app
     config's `shouldAuthenticate` is set to false. Otherwise, this block executes after the user logs in successfully
     if login is required.
     @param frontDoorBridgeUrl Optionally, a Salesforce Identity API front door bridge URL to use in place
     of the default log in URL
     @param codeVerifier Optionally and only with the front door bridge URL parameter, a code verifier to use
     when the front door bridge URL is using web server authentication
     */
    @objc
    public static func loginIfRequired(_ scene: UIScene?, frontDoorBridgeUrl: URL?, codeVerifier: String?, completion completionBlock: (() -> Void)?) {
        loginIfRequired(scene, loginHint: nil, loginHost: nil, frontDoorBridgeUrl: frontDoorBridgeUrl, codeVerifier: codeVerifier, completion: completionBlock)
    }

    /**
     Initiate a login flow if the user is not already logged in to Salesforce and if the app config's
     `shouldAuthenticate` flag is set to false.

     @param scene Scene that login is initiated for.
     @param loginHint Optional login hint to pre-fill the username field.
     @param loginHost Optional login host URL to use for authentication.
     @param completionBlock Block that executes immediately if the user is already logged in or if the app
     config's `shouldAuthenticate` is set to false. Otherwise, this block executes successfully after if login is
     required.
     */
    @objc
    public static func loginIfRequired(_ scene: UIScene?, loginHint: String?, loginHost: String?, completion completionBlock: (() -> Void)?) {
        loginIfRequired(scene, loginHint: loginHint, loginHost: loginHost, frontDoorBridgeUrl: nil, codeVerifier: nil, completion: completionBlock)
    }

    @objc
    public static func loginIfRequired(_ scene: UIScene?, loginHint: String?, loginHost: String?, frontDoorBridgeUrl: URL?, codeVerifier: String?, completion completionBlock: (() -> Void)?) {
        var targetScene = scene
        if targetScene == nil {
            targetScene = SFSDKWindowManager.shared.defaultScene()
        }

        registerBlockForLoginNotification {
            completionBlock?()
        }

        if frontDoorBridgeUrl != nil || isDeepLink(loginHost) || shouldAuthenticateNewUser() {
            let failureBlock: SFUserAccountManagerFailureCallbackBlock = { authInfo, authError in
                SFSDKCoreLogger.e(Self.self, message: "Authentication failed: \(authError?.localizedDescription ?? "unknown error").")
            }

            let result = UserAccountManager.shared.login(
                completion: nil as AccountManagerSuccessCallbackBlock?,
                failure: failureBlock,
                scene: targetScene,
                loginHint: loginHint,
                loginHost: loginHost,
                frontDoorBridgeUrl: frontDoorBridgeUrl,
                codeVerifier: codeVerifier
            )

            if !result {
                UserAccountManager.shared.stopCurrentAuthentication { _ in
                    UserAccountManager.shared.login(
                        completion: nil as AccountManagerSuccessCallbackBlock?,
                        failure: failureBlock,
                        scene: targetScene,
                        loginHint: loginHint,
                        loginHost: loginHost,
                        frontDoorBridgeUrl: frontDoorBridgeUrl,
                        codeVerifier: codeVerifier
                    )
                }
            }
        } else {
            screenLockValidation(completionBlock)
        }
    }

    @objc
    public static func handleLogout(_ completionBlock: (() -> Void)?) {
        let scene = SFSDKWindowManager.shared.defaultScene()
        handleLogout(scene, completion: completionBlock)
    }

    @objc
    public static func handleLogout(_ scene: UIScene?, completion completionBlock: (() -> Void)?) {
        // Multi-user pattern:
        // - If there are two or more existing accounts after logout, let the user choose the account
        //   to switch to.
        // - If there is one existing account, automatically switch to that account.
        // - If there are no further authenticated accounts, present the login screen.
        //
        // Alternatively, you could just go straight to re-initializing your app state, if you know
        // your app does not support multiple accounts.  The logic below will work either way.
        let allAccounts = UserAccountManager.shared.userAccounts() ?? []

        if allAccounts.count > 1 {
            let userSwitchVc = SalesforceUserManagementViewController { _ in
                SFSDKWindowManager.shared.mainWindow(scene).window?.rootViewController?.dismiss(animated: true, completion: nil as (() -> Void)?)
            }
            SFSDKWindowManager.shared.mainWindow(scene).window?.rootViewController?.present(userSwitchVc, animated: true, completion: nil as (() -> Void)?)
        } else {
            if allAccounts.count == 1, let firstAccount = allAccounts.first {
                UserAccountManager.shared.switchToUserAccount(firstAccount)
                completionBlock?()
            } else {
                loginIfRequired(scene, completion: completionBlock)
            }
        }
    }

    @objc
    public static func registerBlockForCurrentUserChangeNotifications(_ completionBlock: @escaping () -> Void) {
        let scene = SFSDKWindowManager.shared.defaultScene()
        registerBlockForCurrentUserChangeNotifications(scene, completion: completionBlock)
    }

    @objc
    public static func registerBlockForCurrentUserChangeNotifications(_ scene: UIScene?, completion completionBlock: @escaping () -> Void) {
        registerBlockForLogoutNotifications(scene, completion: completionBlock)
        registerBlockForSwitchUserNotifications(completionBlock)
    }

    @objc
    public static func registerBlockForLogoutNotifications(_ completionBlock: @escaping () -> Void) {
        let scene = SFSDKWindowManager.shared.defaultScene()
        registerBlockForLogoutNotifications(scene, completion: completionBlock)
    }

    @objc
    public static func registerBlockForLogoutNotifications(_ scene: UIScene?, completion completionBlock: @escaping () -> Void) {
        NotificationCenter.default.addObserver(forName: .UserAccountManagerDidLogoutUser, object: nil, queue: .main) { [weak scene] _ in
            handleLogout(scene, completion: completionBlock)
        }
    }

    @objc
    public static func registerBlockForSwitchUserNotifications(_ completionBlock: @escaping () -> Void) {
        NotificationCenter.default.addObserver(forName: .UserAccountManagerDidSwitchUser, object: nil, queue: .main) { _ in
            completionBlock()
        }
    }

    // MARK: - Private Methods

    private static func isDeepLink(_ host: String?) -> Bool {
        return (host?.count ?? 0) > 0
    }

    private static func shouldAuthenticateNewUser() -> Bool {
        return UserAccountManager.shared.currentUserAccount == nil && (SalesforceManager.shared.appConfig?.shouldAuthenticate ?? false)
    }

    private static func registerBlockForLoginNotification(_ completionBlock: @escaping () -> Void) {
        NotificationCenter.default.addObserver(forName: .UserAccountManagerDidLogInUser, object: nil, queue: .main) { _ in
            completionBlock()
        }
    }

    private static func screenLockValidation(_ completionBlock: (() -> Void)?) {
        SFScreenLockManagerInternal.shared.setCallbackBlock {
            SFSDKCoreLogger.i(Self.self, message: "Screen unlocked or not configured.  Proceeding with authentication validation.")
            completionBlock?()
        }
        SFScreenLockManagerInternal.shared.handleAppForeground()
        SFBiometricAuthenticationManagerInternal.shared.handleAppForeground()
    }
}
