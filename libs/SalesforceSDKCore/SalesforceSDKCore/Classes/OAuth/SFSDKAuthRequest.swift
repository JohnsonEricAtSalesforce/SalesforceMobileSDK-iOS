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
import UIKit

@objc(SFSDKAuthRequest)
@objcMembers
public class SFSDKAuthRequest: NSObject {

    public var useBrowserAuth: Bool = false

    /// Indicates that browser auth was initiated by the "Login for Admin" action.
    public var loginAsAdmin: Bool = false

    public var additionalOAuthParameterKeys: [String] = []
    public var additionalTokenRefreshParams: [String: Any] = [:]
    public var loginHost: String = ""
    public var retryLoginAfterFailure: Bool = false
    public var oauthClientId: String = ""
    public var oauthCompletionUrl: String = ""
    public var brandLoginPath: String?
    public var scopes: Set<String> = []
    public var loginViewControllerConfig: SalesforceLoginViewControllerConfig = SalesforceLoginViewControllerConfig()
    public var scene: UIScene?
    public var jwtToken: String = ""

    // IDP flow related properties (SPApp related properties)
    public var idpEnabled: Bool {
        return (idpAppURIScheme?.count ?? 0) > 0
    }
    public var idpAppURIScheme: String?
    public var userHint: String?
    public var spAppLoginFlowSelectionAction: (() -> (UIViewController & SFSDKLoginFlowSelectionView)?)?
    public var appDisplayName: String = ""
    public var idpInitiatedAuth: Bool = false
    public var keychainGroup: String?
    public var keychainReference: String?

    // IDP flow related properties (IDP App related properties)
    public var idpAppUserSelectionAction: (() -> (UIViewController & SFSDKUserSelectionView)?)?
    public var authenticateRequestFromSPApp: Bool = false
}
