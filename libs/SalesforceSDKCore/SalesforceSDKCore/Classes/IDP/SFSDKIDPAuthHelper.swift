// SFSDKIDPAuthHelper.swift
// SalesforceSDKCore
//
// Created by Raj Rao on 10/20/19.
// Converted to Swift
//
// Copyright (c) 2019-present, salesforce.com, inc. All rights reserved.
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

@objc(SFSDKIDPAuthHelper)
@objcMembers
public class SFSDKIDPAuthHelper: NSObject {

    @objc public class func invokeIDPApp(_ session: SFSDKAuthSession, completion completionBlock: @escaping (Bool) -> Void) {
        let randomData = SFSDKCryptoUtils.randomByteData(withLength: SFSDKIDPConstants.kSFVerifierByteLength)
        session.oauthCoordinator.codeVerifier = (randomData as NSData).sfsdk_base64UrlString()

        let verifierData = session.oauthCoordinator.codeVerifier?.data(using: .utf8)
        let codeChallengeString = (verifierData as NSData?)?.sfsdk_sha256Data()?.sfsdk_base64UrlString() ?? ""

        let command = SFSDKSPLoginRequestCommand()
        command.scheme = session.oauthRequest.idpAppURIScheme ?? ""
        command.spClientId = session.oauthCoordinator.credentials?.clientId ?? ""
        command.spCodeChallenge = codeChallengeString
        command.spAppScopes = encodeScopes(session.oauthRequest.scopes)
        command.spUserHint = session.oauthRequest.userHint
        if !session.oauthRequest.idpInitiatedAuth {
            command.spLoginHost = session.oauthCoordinator.credentials?.domain ?? ""
        }
        command.spRedirectURI = session.oauthCoordinator.credentials?.redirectUri ?? ""
        command.spAppName = session.oauthRequest.appDisplayName ?? ""

        let url = command.requestURL()
        DispatchQueue.main.async {
            SFApplicationHelper.openURL(url, options: [:]) { success in
                completionBlock(success)
            }
        }
    }

    @objc public class func encodeScopes(_ requestScopes: Set<String>) -> String {
        var scopes: Set<String> = requestScopes.isEmpty ? Set() : Set(requestScopes)
        scopes.insert(SFSDKIDPConstants.kSFRefreshTokenParam)
        let scopeStr = scopes.joined(separator: ",").sfsdk_stringByURLEncoding() ?? ""
        return scopeStr
    }

    @objc public class func decodeScopes(_ scopeString: String) -> Set<String> {
        let scopeArray = scopeString.components(separatedBy: CharacterSet(charactersIn: ","))
        var scopes = Set<String>()
        for scope in scopeArray where !scope.isEmpty {
            scopes.insert(scope)
        }
        scopes.insert(SFSDKIDPConstants.kSFRefreshTokenParam)
        return scopes
    }

    @objc public class func invokeSPApp(_ url: URL, completion completionBlock: @escaping (Bool) -> Void) {
        DispatchQueue.main.async {
            let authWindow = SFSDKWindowManager.shared.authWindow(nil)
            authWindow.viewController?.presentedViewController?.dismiss(animated: true) {
                authWindow.dismissWindow()
                SFSDKWindowManager.shared.mainWindow(nil).presentWindow()
            }
            SFApplicationHelper.openURL(url, options: [:]) { success in
                completionBlock(success)
            }
        }
    }

    @objc public class func invokeSPAppWithError(_ spAppCredentials: OAuthCredentials, error: Error?, reason: String) {
        let spAppUrlStr = spAppCredentials.redirectUri ?? ""
        let spAppUrl = URL(string: spAppUrlStr)
        let url = appURL(withError: error as NSError?, reason: reason, app: spAppUrl?.scheme ?? "")
        DispatchQueue.main.async {
            let authWindow = SFSDKWindowManager.shared.authWindow(nil)
            authWindow.viewController?.presentedViewController?.dismiss(animated: true) {
                authWindow.dismissWindow()
                SFSDKWindowManager.shared.mainWindow(nil).presentWindow()
            }

            SFApplicationHelper.openURL(url, options: [:]) { success in
                if !success {
                    SFSDKCoreLogger.e(Self.self, format: "Could not launch spAPP to handle error %@", error?.localizedDescription ?? "")
                }

                UserAccountManager.shared.stopCurrentAuthentication { _ in
                    SFSDKCoreLogger.d(Self.self, format: "Completed idp authentication with error, %@", error?.localizedDescription ?? "")
                }
            }
        }
    }

    private class func appURL(withError error: NSError?, reason: String?, app appScheme: String) -> URL {
        let command = SFSDKAuthErrorCommand()
        command.scheme = appScheme

        let errorCode: String
        if let error = error {
            errorCode = String(error.code)
        } else {
            errorCode = "-999"
        }

        var errorDesc = ""
        if let error = error {
            errorDesc = error.localizedDescription.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? ""
        }

        var reasonStr = reason ?? errorDesc
        reasonStr = reasonStr.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? reasonStr

        command.errorCode = errorCode
        command.errorReason = reasonStr
        command.errorDescription = errorDesc

        return command.requestURL()
    }
}
