// Copyright (c) 2019-present, salesforce.com, inc. All rights reserved.
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

@objc(SFSDKAuthSession)
@objcMembers
public class SFSDKAuthSession: NSObject {

    // Prefix for the synthesized scene id used when a login starts before any UIScene has connected.
    static let unscopedSceneIdPrefix = "com.salesforce.mobilesdk.unscopedAuthSession-"

    public var isAuthenticating: Bool = false
    public var credentials: OAuthCredentials
    public var oauthCoordinator: SFOAuthCoordinator
    public var oauthRequest: SFSDKAuthRequest
    public private(set) var sceneId: String
    public var authSuccessCallback: ((SFOAuthInfo, UserAccount?) -> Void)?
    public var authFailureCallback: ((SFOAuthInfo, Error) -> Void)?
    public var identityCoordinator: SFIdentityCoordinator?
    public var notifiesDelegatesOfFailure: Bool = false
    public var authError: Error?
    public var authCoordinatorBrowserBlock: ((Bool) -> Void)?
    public var nativeLogin: Bool = false
    // IDP related
    public var spAppCredentials: OAuthCredentials?

    @objc public convenience init(with request: SFSDKAuthRequest, credentials creds: OAuthCredentials?) {
        self.init(with: request, credentials: creds, spAppCredentials: nil)
    }

    @objc public init(with request: SFSDKAuthRequest, credentials creds: OAuthCredentials?, spAppCredentials: OAuthCredentials?) {
        self.oauthRequest = request
        guard let resolvedCredentials = creds ?? SFSDKAuthSession.newClientCredentials(request: request) else {
            fatalError("SFSDKAuthSession: Failed to create OAuthCredentials.")
        }
        resolvedCredentials.setValue(request.jwtToken, forKey: "jwt")
        self.credentials = resolvedCredentials
        self.spAppCredentials = spAppCredentials
        // When no scene is connected yet, persistentIdentifier is nil; synthesize a unique per-session id
        // so this session gets its own authSessions[] key and the browser callback can key back to it.
        self.sceneId = request.scene?.session.persistentIdentifier ?? "\(SFSDKAuthSession.unscopedSceneIdPrefix)\(UUID().uuidString)"

        // Temp init — coordinator requires self
        self.oauthCoordinator = SFOAuthCoordinator(credentials: resolvedCredentials)
        super.init()
        initCoordinator()
    }

    private func initCoordinator() {
        oauthCoordinator = SFOAuthCoordinator(authSession: self)
        oauthCoordinator.spAppCredentials = spAppCredentials
        oauthCoordinator.additionalOAuthParameterKeys = oauthRequest.additionalOAuthParameterKeys
        oauthCoordinator.additionalTokenRefreshParams = oauthRequest.additionalTokenRefreshParams
        oauthCoordinator.scopes = NSSet(set: oauthRequest.scopes)
        oauthCoordinator.brandLoginPath = oauthRequest.brandLoginPath ?? ""
        oauthCoordinator.useBrowserAuth = oauthRequest.useBrowserAuth || oauthRequest.loginAsAdmin
        if let spDomain = spAppCredentials?.domain, spDomain.count > 0 {
            oauthCoordinator.credentials?.setValue(spDomain, forKey: "domain")
        }
    }

    private static func newClientCredentials(request: SFSDKAuthRequest) -> OAuthCredentials? {
        let identifier = UserAccountManager.shared.perform(NSSelectorFromString("uniqueUserAccountIdentifier:"), with: request.oauthClientId)?.takeUnretainedValue() as? String ?? UUID().uuidString
        guard let creds = OAuthCredentials.credentials(identifier: identifier, clientId: request.oauthClientId, encrypted: true, storageType: .keychain) else { return nil }
        creds.setValue(request.oauthClientId, forKey: "clientId")
        creds.setValue(request.oauthCompletionUrl, forKey: "redirectUri")
        creds.setValue(request.loginHost, forKey: "domain")
        creds.setValue(Array(request.scopes) as NSArray, forKey: "scopes")
        creds.setValue(nil, forKey: "accessToken")
        return creds
    }
}
