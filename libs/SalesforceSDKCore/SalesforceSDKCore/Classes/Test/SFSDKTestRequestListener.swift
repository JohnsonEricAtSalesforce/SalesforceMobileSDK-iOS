// SFSDKTestRequestListener.swift
// SalesforceSDKCore
//
// Copyright (c) 2012-present, salesforce.com, inc. All rights reserved.
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
import WebKit
import AuthenticationServices

public let kTestRequestStatusWaiting = "waiting"
public let kTestRequestStatusDidLoad = "didLoad"
public let kTestRequestStatusDidFail = "didFail"

@objc public enum SFAccountManagerServiceType: UInt {
    case none = 0
    case oAuth
    case identity
}

@objc(SFSDKTestRequestListener)
@objcMembers
public class SFSDKTestRequestListener: NSObject, SFIdentityCoordinatorDelegate, SFOAuthCoordinatorDelegate {

    @objc public var dataResponse: Any?
    @objc public var lastError: NSError?
    @objc public var returnStatus: String?
    @objc public var maxWaitTime: TimeInterval = 30.0

    private let completionSemaphore = DispatchSemaphore(value: 0)

    public override init() {
        super.init()
        returnStatus = kTestRequestStatusWaiting
    }

    /// Wait for the request to complete (success or fail).
    /// Waits for up to maxWaitTime.
    @objc public func waitForCompletion() -> String {
        // Wait for completion signal with timeout
        let result = completionSemaphore.wait(timeout: .now() + maxWaitTime)
        if result == .timedOut {
            SFSDKCoreLogger.d(SFSDKTestRequestListener.self, message: "Request took too long (> \(maxWaitTime) secs) to complete.")
            return kTestRequestStatusDidFail
        }
        return returnStatus ?? kTestRequestStatusDidFail
    }

    // MARK: - SFIdentityCoordinatorDelegate

    public func identityCoordinatorRetrievedData(_ coordinator: SFIdentityCoordinator) {
        SFSDKCoreLogger.i(SFSDKTestRequestListener.self, message: #function)
        returnStatus = kTestRequestStatusDidLoad
        completionSemaphore.signal()
    }

    public func identityCoordinator(_ coordinator: SFIdentityCoordinator, didFailWithError error: Error) {
        SFSDKCoreLogger.i(SFSDKTestRequestListener.self, message: "\(#function) with error: \(error)")
        lastError = error as NSError
        returnStatus = kTestRequestStatusDidFail
        completionSemaphore.signal()
    }

    // MARK: - SFOAuthCoordinatorDelegate

    public func oauthCoordinator(_ coordinator: SFOAuthCoordinator, willBeginAuthenticationWith view: WKWebView) {
        assertionFailure("User Agent flow not supported in this class.")
    }

    public func oauthCoordinator(_ coordinator: SFOAuthCoordinator, didStartLoad view: WKWebView) {
        assertionFailure("User Agent flow not supported in this class.")
    }

    public func oauthCoordinator(_ coordinator: SFOAuthCoordinator, didFinishLoad view: WKWebView, error: Error?) {
        assertionFailure("User Agent flow not supported in this class.")
    }

    public func oauthCoordinator(_ coordinator: SFOAuthCoordinator, didBeginAuthenticationWithView view: WKWebView) {
        assertionFailure("User Agent flow not supported in this class.")
    }

    public func oauthCoordinator(_ coordinator: SFOAuthCoordinator, didBeginAuthenticationWithSession session: ASWebAuthenticationSession) {
        assertionFailure("Web Server flow not supported in this class.")
    }

    public func oauthCoordinatorDidCancelBrowserAuthentication(_ coordinator: SFOAuthCoordinator) {
        assertionFailure("Web Server flow not supported in this class.")
    }

    public func oauthCoordinatorDidBeginNativeAuthentication(_ coordinator: SFOAuthCoordinator) {
        assertionFailure("Web Server flow not supported in this class.")
    }

    public func oauthCoordinatorDidAuthenticate(_ coordinator: SFOAuthCoordinator, authInfo info: SFOAuthInfo) {
        SFSDKCoreLogger.i(SFSDKTestRequestListener.self, message: "\(#function) with authInfo: \(info)")
        returnStatus = kTestRequestStatusDidLoad
        completionSemaphore.signal()
    }

    public func oauthCoordinator(_ coordinator: SFOAuthCoordinator, didFailWithError error: Error, authInfo info: SFOAuthInfo?) {
        SFSDKCoreLogger.i(SFSDKTestRequestListener.self, message: "\(#function) with authInfo: \(String(describing: info)), error: \(error)")
        lastError = error as NSError
        returnStatus = kTestRequestStatusDidFail
        completionSemaphore.signal()
    }
}
