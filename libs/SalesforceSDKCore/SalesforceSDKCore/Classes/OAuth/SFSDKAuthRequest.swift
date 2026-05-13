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
import UIKit

@objc(SFSDKAuthRequest)
public class AuthRequest: NSObject {

    @objc public var useBrowserAuth: Bool = false

    /// Indicates that browser auth was initiated by the "Login for Admin" action.
    /// When YES, cancelling the browser session returns to the WebView login instead of showing the server picker.
    @objc public var loginAsAdmin: Bool = false

    @objc public var additionalOAuthParameterKeys: [String] = []
    @objc public var additionalTokenRefreshParams: [String: Any] = [:]
    @objc public var loginHost: String = ""
    @objc public var retryLoginAfterFailure: Bool = false
    @objc public var oauthClientId: String = ""
    @objc public var oauthCompletionUrl: String = ""
    @objc public var brandLoginPath: String?
    @objc public var scopes: Set<String> = []
    @objc public var loginViewControllerConfig: LoginViewControllerConfig!
    @objc public var scene: UIScene?
    @objc public var jwtToken: String = ""
    @objc public var userAgentForAuth: String?

    // QR Code login properties
    @objc public var loginHint: String?
    @objc public var frontDoorBridgeUrl: URL?
    @objc public var codeVerifier: String?

    // IDP flow related properties (SPApp related properties)
    @objc public var idpEnabled: Bool {
        return idpAppURIScheme.count > 0
    }
    @objc public var idpAppURIScheme: String = ""
    @objc public var userHint: String?
    @objc public var spAppLoginFlowSelectionAction: (() -> UIViewController & LoginFlowSelectionView)?
    @objc public var appDisplayName: String = ""
    @objc public var idpInitiatedAuth: Bool = false
    @objc public var keychainGroup: String?
    @objc public var keychainReference: String?

    // IDP flow related properties (IDP App related properties)
    @objc public var idpAppUserSelectionAction: (() -> UIViewController & UserSelectionView)?
    @objc public var authenticateRequestFromSPApp: Bool = false
}
