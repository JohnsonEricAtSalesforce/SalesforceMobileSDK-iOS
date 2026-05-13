/*
 SFSDKAuthViewHandler.swift
 SalesforceSDKCore

 Created by Raj Rao on 7/25/17.

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
import WebKit
import AuthenticationServices
import UIKit

/**
 Block definition for displaying the auth view.
 */
public typealias AuthViewDisplayBlock = (AuthViewHolder) -> Void

/**
 Block definition for dismissing the auth view.
 */
public typealias AuthViewDismissBlock = () -> Void

@objc(SFSDKAuthViewHolder)
public class AuthViewHolder: NSObject {

    @objc public weak var wkWebView: WKWebView? {
        get {
            return loginController?.oauthView as? WKWebView
        }
        set {
            loginController?.oauthView = newValue
        }
    }

    @objc public var loginController: LoginViewController?

    @objc public weak var session: ASWebAuthenticationSession?

    @objc public var isAdvancedAuthFlow: Bool = false

    @objc public var scene: UIScene?
}

@objc(SFSDKAuthViewHandler)
public class AuthViewHandler: NSObject {

    /**
     The block used to display the auth view.
     */
    @objc public var authViewDisplayBlock: AuthViewDisplayBlock?

    /**
     The block used to dismiss the auth view.
     */
    @objc public var authViewDismissBlock: AuthViewDismissBlock?

    /**
     Designated initializer for the class.
     @param displayBlock The block used to display the auth view.
     @param dismissBlock The block used to dismiss the auth view.
     */
    @objc(initWithDisplayBlock:dismissBlock:)
    public init(displayBlock: @escaping AuthViewDisplayBlock, dismissBlock: AuthViewDismissBlock?) {
        super.init()
        self.authViewDisplayBlock = displayBlock
        self.authViewDismissBlock = dismissBlock
    }
}
