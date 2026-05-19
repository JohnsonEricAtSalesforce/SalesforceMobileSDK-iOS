/*
 Copyright (c) 2026-present, salesforce.com, inc. All rights reserved.

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

import UIKit
import SalesforceSDKCommon
import SalesforceSDKCore
import MobileSync

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        self.window = SFSDKUIWindow(windowScene: windowScene)

        // App Setup for any changes to the current authenticated user
        SFSDKAuthHelper.registerBlock(forCurrentUserChangeNotifications: scene) { [weak self] in
            self?.resetUserLoginStatus()
            self?.resetViewState {
                self?.setupRootViewController()
            }
        }

        initializeAppViewState()

        SFSDKAuthHelper.loginIfRequired(scene) { [weak self] in
            self?.resetUserLoginStatus()
            self?.setupRootViewController()
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
    }

    func sceneWillResignActive(_ scene: UIScene) {
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        // Uncomment following block to enable IDP Login flow
        // if let urlContext = URLContexts.first {
        //     SFUserAccountManager.sharedInstance().handleIdentityProviderResponse(
        //         urlContext.url,
        //         withOptions: [kSFUserAccountManagerSceneKey: scene.session.persistentIdentifier])
        // }
    }

    // MARK: - Private methods

    private func resetUserLoginStatus() {
        let loggedIn = SFUserAccountManager.sharedInstance().currentUser != nil
        UserDefaults.msdkUserDefaults().set(loggedIn, forKey: "userLoggedIn")
        UserDefaults.msdkUserDefaults().synchronize()
        let isLoggedIn = UserDefaults.msdkUserDefaults().bool(forKey: "userLoggedIn")
        SFSDKMobileSyncLogger.log(type(of: self), level: .debug, message: "\(isLoggedIn) userLoggedIn")
    }

    private func initializeAppViewState() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.initializeAppViewState()
            }
            return
        }

        window?.rootViewController = InitialViewController(nibName: nil, bundle: nil)
        window?.makeKeyAndVisible()
    }

    private func setupRootViewController() {
        let rootVC = ContactListViewController(style: .plain)
        let navVC = SFSDKNavigationController(rootViewController: rootVC)
        window?.rootViewController = navVC
    }

    private func resetViewState(_ postResetBlock: @escaping () -> Void) {
        if window?.rootViewController?.presentedViewController != nil {
            window?.rootViewController?.dismiss(animated: false) {
                postResetBlock()
            }
        } else {
            postResetBlock()
        }
    }
}
