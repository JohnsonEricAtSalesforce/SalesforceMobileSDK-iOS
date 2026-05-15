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

private let kDefaultWaitTimeout: TimeInterval = 5.0

/// Listens for an asynchronous process to complete by polling a status block
/// until the actual status matches the expected status or a timeout is reached.
@available(*, deprecated, message: "No longer used, will be removed")
@objc(SFSDKAsyncProcessListener)
public class SFSDKAsyncProcessListener: NSObject {

    private let expectedStatus: AnyObject
    private let actualStatusBlock: () -> AnyObject
    private let timeout: TimeInterval

    /// Designated initializer.
    /// - Parameters:
    ///   - expectedStatus: The expected return status upon completion.
    ///   - actualStatusBlock: A block that returns the actual status when called.
    ///   - timeout: The amount of time before the asynchronous process is considered to time out.
    @objc public init(expectedStatus: AnyObject, actualStatusBlock: @escaping () -> AnyObject, timeout: TimeInterval) {
        // actualStatusBlock is non-optional, so it's guaranteed to be non-nil
        self.expectedStatus = expectedStatus
        self.actualStatusBlock = actualStatusBlock
        self.timeout = timeout > 0 ? timeout : kDefaultWaitTimeout
        super.init()
    }

    /// Waits for the asynchronous process to complete.
    /// - Returns: The actual status at the time the process completes or times out.
    @objc public func waitForCompletion() -> AnyObject {
        let startTime = Date()
        var actualStatus = actualStatusBlock()
        while !expectedStatus.isEqual(actualStatus) {
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed > timeout {
                SFSDKCoreLogger.d(type(of: self), message: "\(type(of: self))|\(#function): Async process took too long (> \(elapsed) secs) to complete.")
                return actualStatus
            }
            SFSDKCoreLogger.d(type(of: self), message: "\(type(of: self))|\(#function): Expected \(expectedStatus), got \(actualStatus). ## sleeping...")
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
            actualStatus = actualStatusBlock()
        }
        return actualStatus
    }
}
