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
@testable import SalesforceSDKCore

/// Test helper that swizzles logout methods on UserAccountManager to prevent actual logout during tests.
final class SFSDKLogoutBlocker: NSObject {

    private static let shared = SFSDKLogoutBlocker()

    @objc static func block() -> SFSDKLogoutBlocker {
        return shared
    }

    override init() {
        super.init()
        // Swizzle on first access
        SFSDKLogoutBlocker.swizzleLogoutMethods()
    }

    static func swizzleLogoutMethods() {
        SFSDKCoreLogger.d(SFSDKLogoutBlocker.self, message: "Swizzled logout methods for Logout protection.")

        swizzleMethod(
            originalSelector: #selector(UserAccountManager.logout as (UserAccountManager) -> () -> Void),
            swizzledSelector: #selector(SFSDKLogoutBlocker.dummy_logout),
            forClass: UserAccountManager.self,
            isInstanceMethod: true
        )

        swizzleMethod(
            originalSelector: #selector(UserAccountManager.logout(_:) as (UserAccountManager) -> (SFLogoutReason) -> Void),
            swizzledSelector: #selector(SFSDKLogoutBlocker.dummy_logoutWithReason(_:)),
            forClass: UserAccountManager.self,
            isInstanceMethod: true
        )

        swizzleMethod(
            originalSelector: #selector(UserAccountManager.logoutAllUsers),
            swizzledSelector: #selector(SFSDKLogoutBlocker.dummy_logoutAllUsers),
            forClass: UserAccountManager.self,
            isInstanceMethod: true
        )

        swizzleMethod(
            originalSelector: #selector(UserAccountManager.logout(_:reason:)),
            swizzledSelector: #selector(SFSDKLogoutBlocker.dummy_logoutUser(_:reason:)),
            forClass: UserAccountManager.self,
            isInstanceMethod: true
        )
    }

    // MARK: - Dummy methods

    @objc func dummy_logout() {}
    @objc func dummy_logoutWithReason(_ reason: SFLogoutReason) {}
    @objc func dummy_logoutUser(_ user: UserAccount?) {}
    @objc func dummy_logoutUser(_ user: UserAccount?, reason: SFLogoutReason) {}
    @objc func dummy_logoutAllUsers() {}
    @objc func dummy_revoke() {}
    @objc func dummy_revokeAccessToken() {}
    @objc func dummy_revokeRefreshToken() {}

    // MARK: - Swizzle Utility

    private static func swizzleMethod(originalSelector: Selector, swizzledSelector: Selector, forClass clazz: AnyClass, isInstanceMethod: Bool) {
        let originalMethod: ObjectiveC.Method?
        let swizzledMethod: ObjectiveC.Method?

        if isInstanceMethod {
            originalMethod = class_getInstanceMethod(clazz, originalSelector)
            swizzledMethod = class_getInstanceMethod(SFSDKLogoutBlocker.self, swizzledSelector)
        } else {
            originalMethod = class_getClassMethod(clazz, originalSelector)
            swizzledMethod = class_getClassMethod(SFSDKLogoutBlocker.self, swizzledSelector)
        }

        guard let origMethod = originalMethod, let swizMethod = swizzledMethod else { return }

        let didAddMethod = class_addMethod(
            clazz,
            originalSelector,
            method_getImplementation(swizMethod),
            method_getTypeEncoding(swizMethod)
        )

        if didAddMethod {
            class_replaceMethod(
                clazz,
                swizzledSelector,
                method_getImplementation(origMethod),
                method_getTypeEncoding(origMethod)
            )
        } else {
            method_exchangeImplementations(origMethod, swizMethod)
        }
    }
}
