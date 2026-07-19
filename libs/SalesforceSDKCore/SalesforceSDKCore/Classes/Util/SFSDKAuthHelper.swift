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

import UIKit

/// Provides helper methods for initiating login flows and handling logout/user-switching.
@objc(SFSDKAuthHelper)
@objcMembers public class AuthHelper: NSObject {

    @objc public class func loginIfRequired(_ completionBlock: (() -> Void)?) {
        loginIfRequired(SFSDKWindowManager.shared.defaultScene(), completion: completionBlock)
    }

    @objc public class func loginIfRequired(_ scene: UIScene?, completion completionBlock: (() -> Void)?) {
        loginIfRequired(scene, frontDoorBridgeUrl: nil, codeVerifier: nil, completion: completionBlock ?? {})
    }

    @objc public class func loginIfRequired(_ scene: UIScene?, loginHint: String?, loginHost: String?, completion completionBlock: @escaping (() -> Void)) {
        loginIfRequired(scene, loginHint: loginHint, loginHost: loginHost, frontDoorBridgeUrl: nil, codeVerifier: nil, completion: completionBlock)
    }

    @objc public class func loginIfRequired(_ scene: UIScene?, loginHint: String?, loginHost: String?, frontDoorBridgeUrl: URL?, codeVerifier: String?, completion completionBlock: @escaping (() -> Void)) {
        let resolvedScene = scene ?? SFSDKWindowManager.shared.defaultScene()

        registerBlockForLoginNotification {
            completionBlock()
        }

        if frontDoorBridgeUrl != nil || isDeepLink(loginHost) || shouldAuthenticateNewUser() {
            let result = UserAccountManager.shared.login { result in
                if case .failure(let error) = result {
                    SFSDKCoreLogger.e(AuthHelper.self, message: "Authentication failed: \(error.localizedDescription).")
                }
            }
            if !result {
                UserAccountManager.shared.stopCurrentAuthentication { _ in
                    _ = UserAccountManager.shared.login { result in
                        if case .failure(let error) = result {
                            SFSDKCoreLogger.e(AuthHelper.self, message: "Authentication failed: \(error.localizedDescription).")
                        }
                    }
                }
            }
        } else {
            screenLockValidation(completionBlock)
        }
    }

    @objc public class func loginIfRequired(_ scene: UIScene?, frontDoorBridgeUrl: URL?, codeVerifier: String?, completion completionBlock: @escaping (() -> Void)) {
        loginIfRequired(scene, loginHint: nil, loginHost: nil, frontDoorBridgeUrl: frontDoorBridgeUrl, codeVerifier: codeVerifier, completion: completionBlock)
    }

    @objc public class func handleLogout(_ completionBlock: (() -> Void)?) {
        let scene = SFSDKWindowManager.shared.defaultScene()
        handleLogout(scene, completion: completionBlock)
    }

    @objc public class func handleLogout(_ scene: UIScene?, completion completionBlock: (() -> Void)?) {
        let allAccounts = UserAccountManager.shared.userAccounts() ?? []
        if allAccounts.count > 1 {
            let userSwitchVc = SalesforceUserManagementViewController { action in
                SFSDKWindowManager.shared.mainWindow(scene).window?.rootViewController?.dismiss(animated: true, completion: nil)
            }
            SFSDKWindowManager.shared.mainWindow(scene).window?.rootViewController?.present(userSwitchVc, animated: true, completion: nil)
        } else if allAccounts.count == 1 {
            UserAccountManager.shared.switchToUserAccount(allAccounts[0])
            completionBlock?()
        } else {
            loginIfRequired(scene, completion: completionBlock)
        }
    }

    @objc public class func registerBlockForCurrentUserChangeNotifications(_ completionBlock: @escaping (() -> Void)) {
        let scene = SFSDKWindowManager.shared.defaultScene()
        registerBlockForCurrentUserChangeNotifications(scene, completion: completionBlock)
    }

    @objc public class func registerBlockForCurrentUserChangeNotifications(_ scene: UIScene?, completion completionBlock: @escaping (() -> Void)) {
        registerBlockForLogoutNotifications(scene, completion: completionBlock)
        registerBlockForSwitchUserNotifications(completionBlock)
    }

    /// Swift-facing aliases for ``registerBlockForCurrentUserChangeNotifications(_:)`` and its
    /// scene overload. Prior SDK releases exposed this Objective-C method to Swift with the split
    /// argument label `registerBlock(forCurrentUserChangeNotifications:...)` (Swift's automatic
    /// method-name import). The ObjC→Swift migration collapsed it to the single-identifier Swift
    /// name; these aliases preserve source compatibility for Swift consumers (and the sample apps).
    /// `@nonobjc` because the primary methods already own the Objective-C selectors.
    @nonobjc public class func registerBlock(forCurrentUserChangeNotifications completionBlock: @escaping (() -> Void)) {
        registerBlockForCurrentUserChangeNotifications(completionBlock)
    }

    @nonobjc public class func registerBlock(forCurrentUserChangeNotifications scene: UIScene?, completion completionBlock: @escaping (() -> Void)) {
        registerBlockForCurrentUserChangeNotifications(scene, completion: completionBlock)
    }

    @objc public class func registerBlockForLogoutNotifications(_ completionBlock: @escaping (() -> Void)) {
        let scene = SFSDKWindowManager.shared.defaultScene()
        registerBlockForLogoutNotifications(scene, completion: completionBlock)
    }

    @objc public class func registerBlockForLogoutNotifications(_ scene: UIScene?, completion completionBlock: @escaping (() -> Void)) {
        NotificationCenter.default.addObserver(forName: UserAccountManager.didLogoutUser, object: nil, queue: .main) { _ in
            handleLogout(scene, completion: completionBlock)
        }
    }

    @objc public class func registerBlockForSwitchUserNotifications(_ completionBlock: @escaping (() -> Void)) {
        NotificationCenter.default.addObserver(forName: UserAccountManager.didSwitchUser, object: nil, queue: .main) { _ in
            completionBlock()
        }
    }

    // MARK: - Private Methods

    private class func isDeepLink(_ host: String?) -> Bool {
        guard let host = host else { return false }
        return !host.isEmpty
    }

    private class func shouldAuthenticateNewUser() -> Bool {
        return UserAccountManager.shared.currentUserAccount == nil && SalesforceSDKManager.shared.appConfig?.shouldAuthenticate == true
    }

    private class func registerBlockForLoginNotification(_ completionBlock: @escaping (() -> Void)) {
        NotificationCenter.default.addObserver(forName: UserAccountManager.didLogInUser, object: nil, queue: .main) { _ in
            completionBlock()
        }
    }

    private class func screenLockValidation(_ completionBlock: (() -> Void)?) {
        ScreenLockManagerInternal.shared.setCallbackBlock {
            SFSDKCoreLogger.i(AuthHelper.self, message: "Screen unlocked or not configured. Proceeding with authentication validation.")
            completionBlock?()
        }
        ScreenLockManagerInternal.shared.handleAppForeground()
        BiometricAuthenticationManagerInternal.shared.handleAppForeground()
    }
}
