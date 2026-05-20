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
@testable import SalesforceSDKCore

class SFTestSDKManagerFlow: NSObject, SalesforceSDKManagerFlow {

    private var switchUserCompletionBlock: ((UserAccount?, UserAccount?, Bool) -> Void)?

    // MARK: - Public methods

    func setUpUserSwitchState(from fromUser: UserAccount?, toUser: UserAccount?, completion: @escaping (UserAccount?, UserAccount?, Bool) -> Void) {
        switchUserCompletionBlock = completion
    }

    func clearUserSwitchState() {
        switchUserCompletionBlock = nil
    }

    // MARK: - SalesforceSDKManagerFlow

    func handleAppForeground(_ notification: Notification) {
    }

    func handleAppBackground(_ notification: Notification) {
    }

    func handlePostLogout() {
    }

    func handleAppTerminate(_ notification: Notification) {
    }

    func handleAuthCompleted(_ notification: Notification) {
    }

    func handleUserWillSwitch(_ fromUser: UserAccount?, toUser: UserAccount?) {
        switchUserCompletionBlock?(fromUser, toUser, true)
    }

    func handleUserDidSwitch(_ fromUser: UserAccount?, toUser: UserAccount?) {
        switchUserCompletionBlock?(fromUser, toUser, false)
    }

    func handleIDPInitiatedAuthCompleted(_ notification: Notification) {
    }

    func handleUserDidLogout(_ notification: Notification) {
    }
}
