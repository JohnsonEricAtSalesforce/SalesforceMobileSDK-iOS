/*
 SFUserAccountManager+URLHandlers.swift
 SalesforceSDKCore

 Created by Raj Rao on 9/25/17.

 Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.

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

// MARK: - Internal Helper Methods for IDP

extension UserAccountManager {

    /// Encodes a user identity into a string format "userid:orgid"
    @objc internal func encodeUserIdentity(_ userIdentity: SFUserAccountIdentity) -> String {
        return "\(userIdentity.userId):\(userIdentity.orgId)"
    }

    /// Decodes a user identity from string format "userid:orgid"
    @objc internal func decodeUserIdentity(_ userIdentityEncoded: String?) -> SFUserAccountIdentity? {
        guard let encoded = userIdentityEncoded else { return nil }

        let components = encoded.components(separatedBy: ":")
        guard components.count == 2 else { return nil }

        let userId = components[0]
        let orgId = components[1]

        return SFUserAccountIdentity(userId: userId, orgId: orgId)
    }

    /// Creates a default authentication request with current configuration
    @objc internal func defaultAuthRequest() -> AuthRequest {
        let request = AuthRequest()
        request.loginHost = self.loginHost ?? ""
        request.scene = SFSDKWindowManager.shared.defaultScene()
        return request
    }

    /// Authenticates using IDP flow
    @objc internal func authenticateUsingIDP(
        _ request: AuthRequest,
        completion completionBlock: @escaping AccountManagerSuccessCallbackBlock,
        failure failureBlock: @escaping AccountManagerFailureCallbackBlock
    ) -> Bool {
        // For now, use the basic login flow with Result-based completion
        // TODO: This is a simplified implementation - full IDP login flow needs to be implemented
        return self.login { result in
            switch result {
            case .success(let (userAccount, authInfo)):
                completionBlock(authInfo, userAccount)
            case .failure(let error):
                // Create a minimal SFOAuthInfo for the failure case
                let authInfo = SFOAuthInfo(authType: .refresh)
                failureBlock(authInfo, error)
            }
        }
    }
}

// MARK: - SFSDKUserSelectionViewDelegate

extension UserAccountManager: SFSDKUserSelectionViewDelegate {

    @objc public func createNewUser(_ spAppOptions: [AnyHashable: Any]) {
        // Start authentication flow for new user with SP app options
        let request = self.defaultAuthRequest()

        // Apply SP app options to request
        if let loginHost = spAppOptions[kSFLoginHostParam] as? String {
            request.loginHost = loginHost
        }

        // Initiate IDP authentication
        _ = self.authenticateUsingIDP(request, completion: { [weak self] (authInfo: SFOAuthInfo?, user: UserAccount?) in
            // Success - user created and authenticated
            SFSDKCoreLogger.d(UserAccountManager.self, message: "Successfully created new user via IDP")
        }, failure: { (authInfo: SFOAuthInfo?, error: Error?) in
            // Failure
            SFSDKCoreLogger.e(UserAccountManager.self, message: "Failed to create new user via IDP: \(String(describing: error))")
        })
    }

    @objc public func selectedUser(_ user: UserAccount, spAppContext spAppOptions: [AnyHashable: Any]) {
        // Switch to the selected user and continue IDP flow
        self.switchToUserAccount(user)

        // Trigger IDP response with selected user
        let userIdentity = self.encodeUserIdentity(user.accountIdentity)
        var responseOptions = spAppOptions
        responseOptions["user_hint"] = userIdentity

        // Post notification that user was selected for IDP
        NotificationCenter.default.post(
            name: .UserAccountManagerDidReceiveIDPRequest,
            object: self,
            userInfo: [UserAccountManager.userInfoAccountKey: user,
                      UserAccountManager.userInfoAdditionalOptionsKey: spAppOptions]
        )
    }

    @objc public func cancel(_ spAppOptions: [AnyHashable: Any]) {
        // User cancelled the selection - stop authentication
        self.stopCurrentAuthentication(nil)
    }
}

extension UserAccountManager {

    /// Handle an error situation that occurred in the IDP flow.
    /// - Parameter command: The Error URL request from the idp or SP App.
    /// - Returns: YES if this request is handled, NO otherwise.
    @objc public func handleIdpAuthError(_ command: SFSDKAuthErrorCommand) -> Bool {
        let messageObject = SFSDKAlertMessage.message { builder in
            builder.actionOneTitle = SFSDKResourceUtils.localizedString("authAlertOkButton")
            builder.alertTitle = "Authentication Failed"
            builder.alertMessage = command.errorReason ?? "Unknown error"
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
        SFSDKCoreLogger.d(type(of: self), message: "handle handleIdpInitiatedAuth for \(command.allParams())")

        if let userHint = userHint {
            let identity = self.decodeUserIdentity(userHint)
            if let identity = identity, let userAccount = self.userAccount(for: identity) {
                self.switchToUserAccount(userAccount)
                if let startURL = command.startURL, let url = URL(string: startURL) {
                    SFSDKCoreLogger.d(type(of: self), message: "Attempting to launch \(startURL)")
                    let handler = SFSDKStartURLHandler()
                    handler.processRequest(url, options: nil)
                }
                return true
            }
        }

        let request = self.defaultAuthRequest()
        request.userHint = userHint
        request.idpInitiatedAuth = true
        self.authenticateUsingIDP(request, completion: { authInfo, user in
            // Success
        }, failure: { authInfo, error in
            // Failure
        })
        return true
    }

    /// Handle an IDP request initiated from an SP APP.
    /// - Parameter request: The request from the SP APP.
    /// - Returns: YES if this request is handled, NO otherwise.
    @objc public func handleAuthRequestFromSPApp(_ request: SFSDKSPLoginRequestCommand) -> Bool {
        let userHint = request.spUserHint
        SFSDKCoreLogger.d(type(of: self), message: "handleAuthRequestFromSPApp for \(request.allParams())")

        let userInfo: [AnyHashable: Any] = [UserAccountManager.userInfoAdditionalOptionsKey: request.allParams()]
        NotificationCenter.default.post(name: .UserAccountManagerDidReceiveIDPRequest, object: self, userInfo: userInfo)

        if let userHint = userHint {
            let identity = self.decodeUserIdentity(userHint)
            if let identity = identity, let userAccount = self.userAccount(for: identity) {
                if userAccount.credentials.accessToken != nil {
                    SFSDKCoreLogger.d(type(of: self), message: "handleAuthRequestFromSPApp userAccount found for userHint")
                }
                self.selectedUser(userAccount, spAppContext: request.allParams())
                return true
            }
        }

        var showSelection = false
        let domain = request.allParams()[kSFLoginHostParam] as? String ?? self.loginHost ?? ""

        if self.currentUserAccount != nil {
            let domainUsers = self.userAccounts(forDomain: domain)
            showSelection = domainUsers.count > 0
        }

        if showSelection {
            DispatchQueue.main.async {
                guard let controller = self.idpUserSelectionAction?() else { return }
                controller.spAppOptions = request.allParams() as? [AnyHashable: Any]
                controller.userSelectionDelegate = self
                controller.modalPresentationStyle = .fullScreen
                let authWindow = SFSDKWindowManager.shared.authWindow(nil)
                authWindow.presentWindowAnimated(false, withCompletion: {
                    if let viewController = authWindow.viewController {
                        viewController.present(controller as! UIViewController, animated: false, completion: nil)
                    }
                })
            }
        } else {
            self.createNewUser(request.allParams() as? [AnyHashable: Any] ?? [:])
        }
        return true
    }

    /// Handle an IDP response received from an IDP APP.
    /// - Parameters:
    ///   - response: The URL response from the IDP APP.
    ///   - sceneId: The identifier for the scene that's handling the response.
    /// - Returns: YES if this request is handled, NO otherwise.
    @objc public func handleIdpResponse(_ response: SFSDKSPLoginResponseCommand, sceneId: String?) -> Bool {
        var actualSceneId = sceneId
        if actualSceneId == nil {
            actualSceneId = SFSDKWindowManager.shared.defaultScene().session.persistentIdentifier
        }

        if let sceneId = actualSceneId, let authSession = authSessions[sceneId as NSString] as? AuthSession {
            if let responseURL = response.requestURL() {
                authSession.oauthCoordinator.handleIDPAuthenticationResponse(responseURL)
            }
        } else {
            let messageObject = SFSDKAlertMessage.message { builder in
                builder.actionOneTitle = SFSDKResourceUtils.localizedString("authAlertCancelButton")
                builder.alertTitle = "Authentication Failed"
                builder.alertMessage = "Authentication session for sp app was evicted. Try again."
            }

            DispatchQueue.main.async {
                if let sceneId = actualSceneId, let authSession = self.authSessions[sceneId as NSString] as? AuthSession {
                    self.alertDisplayBlock(messageObject, SFSDKWindowManager.shared.authWindow(authSession.oauthRequest.scene))
                } else {
                    self.alertDisplayBlock(messageObject, SFSDKWindowManager.shared.authWindow(nil))
                }
            }
        }
        return true
    }

    @objc public func handleIdpRequest(_ response: SFSDKIDPAuthCodeLoginRequestCommand,
                                       sceneId: String?,
                                       completion completionBlock: AccountManagerSuccessCallbackBlock?,
                                       failure failureBlock: AccountManagerFailureCallbackBlock?) -> Bool {
        SFSDKCoreLogger.d(type(of: self), message: "handleIdpRequest for \(response.allParams())")

        var actualSceneId = sceneId
        if actualSceneId == nil {
            actualSceneId = SFSDKWindowManager.shared.defaultScene().session.persistentIdentifier
        }

        if let sceneId = actualSceneId, let authSession = authSessions[sceneId as NSString] as? AuthSession {
            if let responseURL = response.requestURL() {
                authSession.oauthCoordinator.handleIDPAuthenticationResponse(responseURL)
            }
        } else if let keychainReference = response.keychainReference {
            // IDP - SP: Need to create auth session
            let userHint = response.userHint
            if let userHint = userHint {
                let identity = self.decodeUserIdentity(userHint)
                if let identity = identity, let userAccount = self.userAccount(for: identity) {
                    if userAccount.credentials.accessToken != nil {
                        // We already have that user - let's select it and discard the code
                        SFSDKCoreLogger.d(type(of: self), message: "handleIdpRequest userAccount found for userHint")
                        self.switchToUserAccount(userAccount)
                        let authInfo = SFOAuthInfo(authType: .idp)
                        completionBlock?(authInfo, userAccount)
                        return true
                    }
                }
            }
            // We don't have that user - let's create an auth session to login using the code
            let request = self.defaultAuthRequest()
            request.idpInitiatedAuth = true
            let authSession = AuthSession(with: request, credentials: nil)
            authSession.authFailureCallback = failureBlock
            authSession.authSuccessCallback = completionBlock
            if let sceneId = actualSceneId, let responseURL = response.requestURL() {
                authSessions[sceneId as NSString] = authSession
                authSession.oauthCoordinator.handleIDPAuthenticationResponse(responseURL)
                authSession.isAuthenticating = true
                // Note: OAuth coordinator delegate handling is managed by UserAccountManager's main implementation
            }
        }
        return true
    }
}

// MARK: - SFSDKLoginFlowSelectionViewDelegate

extension UserAccountManager: SFSDKLoginFlowSelectionViewDelegate {

    public func loginFlowSelectionIDPSelected(_ controller: UIViewController, options appOptions: [AnyHashable: Any]) {
        // Start IDP authentication flow
        let request = self.defaultAuthRequest()
        _ = self.authenticateUsingIDP(request, completion: { [weak self] (authInfo: SFOAuthInfo?, user: UserAccount?) in
            SFSDKCoreLogger.d(UserAccountManager.self, message: "IDP login flow selected and completed successfully")
            controller.dismiss(animated: true, completion: nil)
        }, failure: { (authInfo: SFOAuthInfo?, error: Error?) in
            SFSDKCoreLogger.e(UserAccountManager.self, message: "IDP login flow failed: \(String(describing: error))")
            controller.dismiss(animated: true, completion: nil)
        })
    }

    public func loginFlowSelectionLocalLoginSelected(_ controller: UIViewController, options appOptions: [AnyHashable: Any]) {
        // Start local/standard authentication flow
        controller.dismiss(animated: true) { [weak self] in
            _ = self?.login { result in
                switch result {
                case .success:
                    SFSDKCoreLogger.d(UserAccountManager.self, message: "Local login flow completed successfully")
                case .failure(let error):
                    SFSDKCoreLogger.e(UserAccountManager.self, message: "Local login flow failed: \(error)")
                }
            }
        }
    }
}
