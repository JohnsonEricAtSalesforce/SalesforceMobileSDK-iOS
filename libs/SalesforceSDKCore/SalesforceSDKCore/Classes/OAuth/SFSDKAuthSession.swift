/*
Copyright (c) 2019-present, salesforce.com, inc. All rights reserved.

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

@objc(SFSDKAuthSession)
public class AuthSession: NSObject {

    @objc public var isAuthenticating: Bool = false
    @objc public var credentials: OAuthCredentials
    @objc public var oauthCoordinator: SFOAuthCoordinator!
    @objc public var oauthRequest: AuthRequest
    @objc public private(set) var sceneId: String
    @objc public var authSuccessCallback: ((SFOAuthInfo, UserAccount) -> Void)?
    @objc public var authFailureCallback: ((SFOAuthInfo, NSError) -> Void)?
    @objc public var identityCoordinator: IdentityCoordinator?
    @objc public var notifiesDelegatesOfFailure: Bool = false
    @objc public var authError: NSError?
    @objc public var authCoordinatorBrowserBlock: ((Bool) -> Void)?
    @objc public var nativeLogin: Bool = false
    // idp related
    @objc public var spAppCredentials: OAuthCredentials?

    @objc public convenience init(with request: AuthRequest) {
        self.init(with: request, credentials: nil)
    }

    @objc public convenience init(with request: AuthRequest, credentials creds: OAuthCredentials?) {
        self.init(with: request, credentials: creds, spAppCredentials: nil)
    }

    @objc public init(with request: AuthRequest, credentials creds: OAuthCredentials?, spAppCredentials: OAuthCredentials?) {
        self.oauthRequest = request
        self.credentials = creds ?? AuthSession.newClientCredentials(for: request)
        self.credentials.jwt = request.jwtToken
        self.spAppCredentials = spAppCredentials
        self.sceneId = request.scene?.session.persistentIdentifier ?? "" // Pass through for convenience
        super.init()
        self.initCoordinator()
    }

    private func initCoordinator() {
        self.oauthCoordinator = SFOAuthCoordinator(authSession: self)
        self.oauthCoordinator.spAppCredentials = self.spAppCredentials
        self.oauthCoordinator.additionalOAuthParameterKeys = self.oauthRequest.additionalOAuthParameterKeys
        self.oauthCoordinator.additionalTokenRefreshParams = self.oauthRequest.additionalTokenRefreshParams
        self.oauthCoordinator.scopes = self.oauthRequest.scopes
        self.oauthCoordinator.brandLoginPath = self.oauthRequest.brandLoginPath
        self.oauthCoordinator.useBrowserAuth = self.oauthRequest.useBrowserAuth || self.oauthRequest.loginAsAdmin

        // TODO: Remove in Mobile SDK 14.0
        if let userAgent = self.oauthRequest.userAgentForAuth {
            self.oauthCoordinator.userAgentForAuth = userAgent
        }

        if let spAppCredentials = self.spAppCredentials,
           let oldCreds = self.oauthCoordinator.credentials {
            // domain is private(set), so we update via instance_url
            self.oauthCoordinator.credentials = OAuthCredentials(identifier: oldCreds.identifier, clientId: oldCreds.clientId, encrypted: oldCreds.isEncrypted)
            self.oauthCoordinator.credentials?.updateCredentials(["instance_url": "https://\(spAppCredentials.domain ?? "")"])
        }
    }

    private static func newClientCredentials(for request: AuthRequest) -> OAuthCredentials {
        // Generate a unique identifier for the credentials
        let identifier = UUID().uuidString
        let creds = OAuthCredentials(identifier: identifier, clientId: request.oauthClientId, encrypted: true)
        // clientId is already set in the initializer
        creds.redirectUri = request.oauthCompletionUrl
        creds.updateCredentials(["instance_url": "https://\(request.loginHost)"])
        creds.scopes = Array(request.scopes)
        creds.accessToken = nil
        return creds
    }
}
