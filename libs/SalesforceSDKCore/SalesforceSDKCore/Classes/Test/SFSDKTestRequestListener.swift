/*
 Copyright (c) 2012-present, salesforce.com, inc. All rights reserved.

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

public let kTestRequestStatusWaiting = "waiting"
public let kTestRequestStatusDidLoad = "didLoad"
public let kTestRequestStatusDidFail = "didFail"

@objc public enum SFAccountManagerServiceType: UInt {
    case none = 0
    case oAuth
    case identity
}

@objc(SFSDKTestRequestListener)
public class SFSDKTestRequestListener: NSObject, IdentityCoordinatorDelegate, SFOAuthCoordinatorDelegate {

    @objc public var dataResponse: Any?
    @objc public var lastError: Error?
    @objc public var returnStatus: String?

    /// Max time to wait for request completion
    @objc public var maxWaitTime: TimeInterval = 30.0

    public override init() {
        super.init()
        self.returnStatus = kTestRequestStatusWaiting
    }

    /// Wait for the request to complete (success or fail).
    /// Waits for up to maxWaitTime.
    /// - Returns: returnStatus; kTestRequestStatusDidFail if maxWaitTime was exceeded
    @objc public func waitForCompletion() -> String {
        let startTime = Date()
        while returnStatus == kTestRequestStatusWaiting {
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed > maxWaitTime {
                SFSDKCoreLogger.d(type(of: self), message: "Request took too long (> \(elapsed) secs) to complete.")
                return kTestRequestStatusDidFail
            }
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        }
        return returnStatus ?? kTestRequestStatusDidFail
    }

    // MARK: - IdentityCoordinatorDelegate

    public func identityCoordinatorRetrievedData(_ coordinator: IdentityCoordinator) {
        SFSDKCoreLogger.i(type(of: self), message: #function)
        returnStatus = kTestRequestStatusDidLoad
    }

    public func identityCoordinator(_ coordinator: IdentityCoordinator, didFailWith error: Error) {
        SFSDKCoreLogger.i(type(of: self), message: "\(#function) with error: \(error)")
        lastError = error
        returnStatus = kTestRequestStatusDidFail
    }

    // MARK: - SFOAuthCoordinatorDelegate

    public func oauthCoordinator(_ coordinator: SFOAuthCoordinator, didBeginAuthenticationWith view: WKWebView) {
        assertionFailure("User Agent flow not supported in this class.")
    }

    public func oauthCoordinator(_ coordinator: SFOAuthCoordinator, didBeginAuthenticationWith session: ASWebAuthenticationSession) {
        assertionFailure("Web Server flow not supported in this class.")
    }

    public func oauthCoordinatorDidBeginNativeAuthentication(_ coordinator: SFOAuthCoordinator) {
        assertionFailure("Web Server flow not supported in this class.")
    }

    public func oauthCoordinatorDidCancelBrowserAuthentication(_ coordinator: SFOAuthCoordinator) {
        assertionFailure("Web Server flow not supported in this class.")
    }

    public func oauthCoordinatorDidAuthenticate(_ coordinator: SFOAuthCoordinator, authInfo info: SFOAuthInfo) {
        SFSDKCoreLogger.i(type(of: self), message: "\(#function) with authInfo: \(info)")
        returnStatus = kTestRequestStatusDidLoad
    }

    public func oauthCoordinator(_ coordinator: SFOAuthCoordinator, didFailWithError error: Error, authInfo info: SFOAuthInfo?) {
        SFSDKCoreLogger.i(type(of: self), message: "\(#function) with authInfo: \(String(describing: info)), error: \(error)")
        lastError = error
        returnStatus = kTestRequestStatusDidFail
    }
}
