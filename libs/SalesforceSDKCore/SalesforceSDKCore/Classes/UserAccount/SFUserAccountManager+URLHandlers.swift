// SFUserAccountManager+URLHandlers.swift
// SalesforceSDKCore
//
// Created by Raj Rao on 9/25/17.
// Converted to Swift
//
// Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.
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
import UIKit

extension UserAccountManager {

    /// Handle an error situation that occurred in the IDP flow.
    /// - Parameter command: The Error URL request from the idp or SP App.
    /// - Returns: YES if this request is handled, NO otherwise.
    @objc public func handleIdpAuthError(_ command: SFSDKAuthErrorCommand) -> Bool {
        let messageObject = AlertMessage.message { builder in
            builder.actionOneTitle = SFSDKResourceUtils.localizedString("authAlertOkButton")
            builder.alertTitle = "Authentication Failed"
            builder.alertMessage = command.errorReason
        }

        DispatchQueue.main.async {
            self.alertDisplayBlock(messageObject, SFSDKWindowManager.shared.authWindow(nil))
            self.stopCurrentAuthentication(nil)
        }
        return true
    }

    /// Handle an IDP initiated auth flow.
    /// - Parameter command: The URL request from the IDP APP.
    /// - Returns: YES if this request is handled, NO otherwise.
    @objc public func handleIdpInitiatedAuth(_ command: SFSDKIDPLoginRequestCommand) -> Bool {
        let userHint = command.userHint
        SFSDKCoreLogger.d(type(of: self), format: "handle handleIdpInitiatedAuth for %@", command.allParams().description)

        if let userHint = userHint {
            let identity = decodeUserIdentity(userHint)
            if let identity = identity {
                let userAccount = self.userAccount(for: identity)
                if let userAccount = userAccount {
                    switchToUserAccount(userAccount)
                    if let startURL = command.startURL {
                        SFSDKCoreLogger.d(type(of: self), format: "Attempting to launch %@", startURL)
                        let handler = SFSDKStartURLHandler()
                        handler.processRequest(URL(string: startURL) ?? URL(fileURLWithPath: ""), options: nil)
                    }
                    return true
                }
            }
        }

        let request = defaultAuthRequest()
        request.userHint = userHint
        request.idpInitiatedAuth = true
        _ = authenticateUsingIDP(request, completion: { _, _ in }, failure: { _, _ in })
        return true
    }

    /// Handle an IDP request initiated from an SP APP.
    /// - Parameter request: The request from the SP APP.
    /// - Returns: YES if this request is handled, NO otherwise.
    @objc public func handleAuthRequestFromSPApp(_ request: SFSDKSPLoginRequestCommand) -> Bool {
        let userHint = request.spUserHint
        SFSDKCoreLogger.d(type(of: self), format: "handleAuthRequestFromSPApp for %@", request.allParams().description)

        let userInfo: [String: Any] = [UserAccountManager.userInfoAdditionalOptionsKey: request.allParams()]
        NotificationCenter.default.post(name: UserAccountManager.didReceiveIDPRequest, object: self, userInfo: userInfo)

        if let userHint = userHint {
            let identity = decodeUserIdentity(userHint)
            if let identity = identity {
                if let userAccount = self.userAccount(for: identity) {
                    if userAccount.credentials.accessToken != nil {
                        SFSDKCoreLogger.d(type(of: self), format: "handleAuthRequestFromSPApp userAccount found for userHint")
                    }
                    selectedUser(userAccount, spAppContext: request.allParams() as? [String: Any] ?? [:])
                    return true
                }
            }
        }

        var showSelection = false
        let allParams = request.allParams() as? [String: Any] ?? [:]
        let domain = (allParams[SFSDKIDPConstants.kSFLoginHostParam] as? String) ?? self.loginHost

        if self.currentUserAccount != nil {
            let domainUsers = userAccounts(forDomain: domain)
            showSelection = domainUsers.count > 0
        }

        if showSelection {
            DispatchQueue.main.async {
                guard let controller = self.idpUserSelectionAction?() else { return }
                controller.spAppOptions = request.allParams() as? [AnyHashable: Any]
                controller.userSelectionDelegate = self
                controller.modalPresentationStyle = .fullScreen
                let authWindow = SFSDKWindowManager.shared.authWindow(nil)
                authWindow.presentWindow(animated: false) {
                    authWindow.viewController?.present(controller, animated: false, completion: nil)
                }
            }
        } else {
            createNewUser(allParams)
        }
        return true
    }

    /// Handle an IDP response received from an IDP APP.
    /// - Parameters:
    ///   - response: The URL response from the IDP APP.
    ///   - sceneId: The identifier for the scene that's handling the response.
    /// - Returns: YES if this request is handled, NO otherwise.
    @objc public func handleIdpResponse(_ response: SFSDKSPLoginResponseCommand, sceneId: String?) -> Bool {
        let effectiveSceneId = sceneId ?? SFSDKWindowManager.shared.defaultScene().session.persistentIdentifier

        if let authSession = self.authSessions[effectiveSceneId as NSString] as? SFSDKAuthSession {
            authSession.oauthCoordinator.handleIDPAuthenticationResponse(response.requestURL())
        } else {
            let messageObject = AlertMessage.message { builder in
                builder.actionOneTitle = SFSDKResourceUtils.localizedString("authAlertCancelButton")
                builder.alertTitle = "Authentication Failed"
                builder.alertMessage = "Authentication session for sp app was evicted. Try again."
            }

            DispatchQueue.main.async {
                let authSession = self.authSessions[effectiveSceneId as NSString] as? SFSDKAuthSession
                self.alertDisplayBlock(messageObject, SFSDKWindowManager.shared.authWindow(authSession?.oauthRequest.scene))
            }
        }
        return true
    }

    @objc public func handleIdpRequest(_ response: SFSDKIDPAuthCodeLoginRequestCommand, sceneId: String?, completion completionBlock: AccountManagerSuccessCallbackBlock?, failure failureBlock: AccountManagerFailureCallbackBlock?) -> Bool {
        SFSDKCoreLogger.d(type(of: self), format: "handleIdpRequest for %@", response.allParams().description)

        let effectiveSceneId = sceneId ?? SFSDKWindowManager.shared.defaultScene().session.persistentIdentifier

        if let authSession = self.authSessions[effectiveSceneId as NSString] as? SFSDKAuthSession {
            authSession.oauthCoordinator.handleIDPAuthenticationResponse(response.requestURL())
        } else if response.keychainReference != nil {
            // IDP - SP: Need to create auth session
            let userHint = response.userHint
            if let userHint = userHint {
                let identity = decodeUserIdentity(userHint)
                if let identity = identity {
                    if let userAccount = self.userAccount(for: identity),
                       userAccount.credentials.accessToken != nil {
                        // We already have that user - let's select it and discard the code
                        SFSDKCoreLogger.d(type(of: self), format: "handleIdpRequest userAccount found for userHint")
                        switchToUserAccount(userAccount)
                        let authInfo = SFOAuthInfo(authType: .idp)
                        completionBlock?(authInfo, userAccount)
                        return true
                    }
                }
            }
            // We don't have that user - let's create an auth session to login using the code
            let request = defaultAuthRequest()
            request.idpInitiatedAuth = true
            let authSession = SFSDKAuthSession(with: request, credentials: nil)
            authSession.authFailureCallback = failureBlock
            if let completionBlock = completionBlock {
                authSession.authSuccessCallback = { authInfo, account in
                    if let account = account {
                        completionBlock(authInfo, account)
                    }
                }
            }
            self.authSessions[effectiveSceneId as NSString] = authSession
            (self.authSessions[effectiveSceneId as NSString] as? SFSDKAuthSession)?.oauthCoordinator.handleIDPAuthenticationResponse(response.requestURL())
            authSession.isAuthenticating = true
            authSession.oauthCoordinator.delegate = self
        }
        return true
    }
}
