/*
 Copyright (c) 2015-present, salesforce.com, inc. All rights reserved.

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
@testable import SalesforceSDKCore

private let kWebNotSupportedExceptionName = "com.salesforce.oauth.tests.WebNotSupported"
private let kWebNotSupportedReasonFormat = "%@ WKWebView transactions not supported in unit test framework."
private let kASWebAuthenticationSessionNotSupportedReasonFormat = "%@ ASWebAuthenticationSession transactions not supported in unit test framework."

final class SFOAuthTestFlowCoordinatorDelegate: NSObject, SFOAuthCoordinatorDelegate {

    var willBeginAuthenticationCalled = false
    var didAuthenticateCalled = false
    var authInfo: SFOAuthInfo?
    var didFailWithErrorCalled = false
    var isNetworkAvailableCalled = false
    var didFailWithError: Error?
    var isNetworkAvailable = true

    // MARK: - SFOAuthCoordinatorDelegate

    func oauthCoordinator(_ coordinator: SFOAuthCoordinator, didBeginAuthenticationWith view: WKWebView) {
        SFSDKCoreLogger.d(type(of: self), message: "\(#function) called.")
        let reason = String(format: kWebNotSupportedReasonFormat, #function)
        NSException(name: NSExceptionName(kWebNotSupportedExceptionName), reason: reason, userInfo: nil).raise()
    }

    func oauthCoordinator(_ coordinator: SFOAuthCoordinator, willBeginAuthenticationWith view: WKWebView) {
        SFSDKCoreLogger.d(type(of: self), message: "\(#function) called.")
        let reason = String(format: kWebNotSupportedReasonFormat, #function)
        NSException(name: NSExceptionName(kWebNotSupportedExceptionName), reason: reason, userInfo: nil).raise()
    }

    func oauthCoordinator(_ coordinator: SFOAuthCoordinator, didStartLoad view: WKWebView) {
        SFSDKCoreLogger.d(type(of: self), message: "\(#function) called.")
        let reason = String(format: kWebNotSupportedReasonFormat, #function)
        NSException(name: NSExceptionName(kWebNotSupportedExceptionName), reason: reason, userInfo: nil).raise()
    }

    func oauthCoordinator(_ coordinator: SFOAuthCoordinator, didFinishLoad view: WKWebView, error: Error?) {
        SFSDKCoreLogger.d(type(of: self), message: "\(#function) called.")
        let reason = String(format: kWebNotSupportedReasonFormat, #function)
        NSException(name: NSExceptionName(kWebNotSupportedExceptionName), reason: reason, userInfo: nil).raise()
    }

    func oauthCoordinatorWillBeginAuthentication(_ coordinator: SFOAuthCoordinator, authInfo info: SFOAuthInfo) {
        SFSDKCoreLogger.d(type(of: self), message: "\(#function) called.")
        willBeginAuthenticationCalled = true
        authInfo = info
    }

    func oauthCoordinatorDidAuthenticate(_ coordinator: SFOAuthCoordinator, authInfo info: SFOAuthInfo) {
        SFSDKCoreLogger.d(type(of: self), message: "\(#function) called.")
        didAuthenticateCalled = true
        authInfo = info
    }

    func oauthCoordinator(_ coordinator: SFOAuthCoordinator, didFailWithError error: Error, authInfo info: SFOAuthInfo?) {
        SFSDKCoreLogger.d(type(of: self), message: "\(#function) called.")
        didFailWithErrorCalled = true
        didFailWithError = error
        authInfo = info
    }

    func oauthCoordinatorIsNetworkAvailable(_ coordinator: SFOAuthCoordinator) -> Bool {
        SFSDKCoreLogger.d(type(of: self), message: "\(#function) called.")
        isNetworkAvailableCalled = true
        return isNetworkAvailable
    }

    func oauthCoordinator(_ coordinator: SFOAuthCoordinator, didBeginAuthenticationWith session: ASWebAuthenticationSession) {
        SFSDKCoreLogger.d(type(of: self), message: "\(#function) called.")
        let reason = String(format: kASWebAuthenticationSessionNotSupportedReasonFormat, #function)
        NSException(name: NSExceptionName(kASWebAuthenticationSessionNotSupportedReasonFormat), reason: reason, userInfo: nil).raise()
    }

    func oauthCoordinatorDidCancelBrowserAuthentication(_ coordinator: SFOAuthCoordinator) {
        SFSDKCoreLogger.d(type(of: self), message: "\(#function) called.")
        let reason = String(format: kASWebAuthenticationSessionNotSupportedReasonFormat, #function)
        NSException(name: NSExceptionName(kASWebAuthenticationSessionNotSupportedReasonFormat), reason: reason, userInfo: nil).raise()
    }

    func oauthCoordinatorDidBeginNativeAuthentication(_ coordinator: SFOAuthCoordinator) {
        SFSDKCoreLogger.d(type(of: self), message: "\(#function) called.")
        let reason = String(format: kASWebAuthenticationSessionNotSupportedReasonFormat, #function)
        NSException(name: NSExceptionName(kASWebAuthenticationSessionNotSupportedReasonFormat), reason: reason, userInfo: nil).raise()
    }
}
