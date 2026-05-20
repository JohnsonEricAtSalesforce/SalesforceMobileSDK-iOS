//
//  SFSDKLogoutBlocker.swift
//  SalesforceSDKCoreTests
//
//  Copyright (c) 2019-present, salesforce.com, inc. All rights reserved.
//
//  Redistribution and use of this software in source and binary forms, with or without modification,
//  are permitted provided that the following conditions are met:
//  * Redistributions of source code must retain the above copyright notice, this list of conditions
//  and the following disclaimer.
//  * Redistributions in binary form must reproduce the above copyright notice, this list of
//  conditions and the following disclaimer in the documentation and/or other materials provided
//  with the distribution.
//  * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
//  endorse or promote products derived from this software without specific prior written
//  permission of salesforce.com, inc.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
//  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
//  FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
//  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
//  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
//  WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import Foundation
import ObjectiveC
@testable import SalesforceSDKCore

@objc class SFSDKLogoutBlocker: NSObject {

    private static var swizzled: SFSDKLogoutBlocker?
    private static let onceToken: Void = {
        let instance = SFSDKLogoutBlocker()
        swizzled = instance

        SFSDKCoreLogger.d(SFSDKLogoutBlocker.self, message: "Swizzled logout methods for Logout protection.")

        // logout()
        swizzleMethod(
            original: #selector(UserAccountManager.logout as (UserAccountManager) -> () -> Void),
            swizzled: #selector(SFSDKLogoutBlocker.dummy_logout),
            forClass: UserAccountManager.self,
            isInstanceMethod: true
        )

        // logout(_ reason:)
        swizzleMethod(
            original: #selector(UserAccountManager.logout(_:) as (UserAccountManager) -> (SFLogoutReason) -> Void),
            swizzled: #selector(SFSDKLogoutBlocker.dummy_logoutWithReason(_:)),
            forClass: UserAccountManager.self,
            isInstanceMethod: true
        )

        // logoutAllUsers()
        swizzleMethod(
            original: #selector(UserAccountManager.logoutAllUsers),
            swizzled: #selector(SFSDKLogoutBlocker.dummy_logoutAllUsers),
            forClass: UserAccountManager.self,
            isInstanceMethod: true
        )

        // logout(_ user:) - ObjC name logoutUser:
        swizzleMethod(
            original: Selector(("logoutUser:")),
            swizzled: #selector(SFSDKLogoutBlocker.dummy_logoutUser(_:)),
            forClass: UserAccountManager.self,
            isInstanceMethod: true
        )

        // logout(_ user: reason:) - ObjC name logoutUser:reason:
        swizzleMethod(
            original: Selector(("logoutUser:reason:")),
            swizzled: #selector(SFSDKLogoutBlocker.dummy_logoutUserWithReason(_:reason:)),
            forClass: UserAccountManager.self,
            isInstanceMethod: true
        )
    }()

    @objc static func block() -> SFSDKLogoutBlocker {
        _ = onceToken
        return swizzled ?? SFSDKLogoutBlocker()
    }

    // MARK: - Dummy methods

    @objc func dummy_logout() {}

    @objc func dummy_logoutWithReason(_ reason: SFLogoutReason) {}

    @objc func dummy_logoutUser(_ user: UserAccount) {}

    @objc func dummy_logoutUserWithReason(_ user: UserAccount, reason: SFLogoutReason) {}

    @objc func dummy_logoutAllUsers() {}

    @objc func dummy_revoke() {}

    @objc func dummy_revokeAccessToken() {}

    @objc func dummy_revokeRefreshToken() {}

    // MARK: - Swizzle Helper

    private static func swizzleMethod(original originalSelector: Selector, swizzled swizzledSelector: Selector, forClass clazz: AnyClass, isInstanceMethod: Bool) {
        let originalMethod: Method?
        let swizzledMethod: Method?

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
