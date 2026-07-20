// Copyright (c) 2025-present, salesforce.com, inc. All rights reserved.
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

/// Private container for an in-flight refresh operation, holding the refresher
/// instance and all waiting callbacks.
private class SFSDKTokenRefreshEntry {
    var refresher: SFOAuthSessionRefresher?
    var completionBlocks: [(OAuthCredentials) -> Void] = []
    var errorBlocks: [(Error) -> Void] = []
    var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid
}

/// Centralized coordinator that ensures at most one token refresh request is in-flight
/// per credential at any given time. Concurrent callers for the same credential are
/// coalesced: the first triggers the refresh, and subsequent callers wait for the same result.
///
/// This prevents the "double-spend" race condition when using single-use (rotating) refresh tokens,
/// where concurrent refresh attempts would invalidate each other's tokens.
@objc(SFSDKTokenRefreshCoordinator)
@objcMembers
public class SFSDKTokenRefreshCoordinator: NSObject {

    /// Shared singleton instance.
    @objc(sharedInstance)
    public static let shared = SFSDKTokenRefreshCoordinator()

    /// Testing hook: inject a factory block to create mock SFOAuthSessionRefresher instances.
    /// When nil (default), the coordinator creates a standard SFOAuthSessionRefresher.
    @objc public var refresherFactory: ((OAuthCredentials) -> SFOAuthSessionRefresher)?

    private var activeRefreshes: [String: SFSDKTokenRefreshEntry] = [:]
    private let serialQueue = DispatchQueue(label: "com.salesforce.mobilesdk.tokenRefreshCoordinator")

    override init() {
        super.init()
    }

    // MARK: - Public API

    /// Request a token refresh for the given credentials.
    ///
    /// If a refresh is already in-flight for these credentials (keyed by `credentials.identifier`),
    /// the callbacks are appended to the waiting list and no new network request is made.
    /// When the single in-flight refresh completes, all registered callbacks receive the same result.
    ///
    /// Completion and error callbacks are dispatched on the main queue.
    ///
    /// - Parameters:
    ///   - credentials: The OAuth credentials to refresh.
    ///   - completionBlock: Called with the updated credentials on successful refresh.
    ///   - errorBlock: Called with the error if the refresh fails.
    @objc(refreshSessionForCredentials:completion:error:)
    public func refreshSession(forCredentials credentials: OAuthCredentials,
                               completion completionBlock: ((OAuthCredentials) -> Void)?,
                               error errorBlock: ((Error) -> Void)?) {
        let key = credentials.identifier
        guard !key.isEmpty else {
            SFSDKCoreLogger.e(Self.self, message: "Cannot refresh credentials with nil identifier.")
            if let errorBlock = errorBlock {
                let err = NSError(domain: "SFSDKTokenRefreshCoordinator",
                                  code: -1,
                                  userInfo: [NSLocalizedDescriptionKey: "Credentials identifier is nil"])
                errorBlock(err)
            }
            return
        }

        serialQueue.async { [self] in
            let existingEntry = activeRefreshes[key]
            let alreadyInFlight = (existingEntry != nil)
            let entry = existingEntry ?? SFSDKTokenRefreshEntry()

            // Append callbacks — same path whether coalescing or starting fresh
            if let completionBlock = completionBlock {
                entry.completionBlocks.append(completionBlock)
            }
            if let errorBlock = errorBlock {
                entry.errorBlocks.append(errorBlock)
            }

            if alreadyInFlight {
                SFSDKCoreLogger.d(Self.self, message: "Refresh already in-flight for credential \(key). Coalescing request.")
                return
            }

            // Background task protection
            if let app = SFApplicationHelper.sharedApplication() {
                entry.backgroundTaskId = app.beginBackgroundTask(withName: "SFSDKTokenRefresh") { [weak self] in
                    self?.handleBackgroundExpiration(forKey: key)
                }
            }

            // Create refresher (via factory for testability, or standard instance). Use the
            // non-deprecated internal initializer so the centralized path stays warning-free.
            entry.refresher = refresherFactory?(credentials) ?? SFOAuthSessionRefresher(internalCredentials: credentials)

            activeRefreshes[key] = entry

            SFSDKCoreLogger.i(Self.self, message: "Starting token refresh for credential \(key).")

            entry.refresher?.refreshSessionInternal(withCompletion: { [weak self] updatedCredentials in
                self?.serialQueue.async {
                    self?.completeRefresh(forKey: key, credentials: updatedCredentials, error: nil)
                }
            }, error: { [weak self] refreshError in
                self?.serialQueue.async {
                    self?.completeRefresh(forKey: key, credentials: nil, error: refreshError)
                }
            })
        }
    }

    // MARK: - Private

    private func completeRefresh(forKey key: String, credentials: OAuthCredentials?, error: Error?) {
        guard let entry = activeRefreshes[key] else { return } // Already handled (e.g., by background expiration)

        activeRefreshes.removeValue(forKey: key)

        // End background task
        if entry.backgroundTaskId != .invalid {
            if let app = SFApplicationHelper.sharedApplication() {
                app.endBackgroundTask(entry.backgroundTaskId)
            }
            entry.backgroundTaskId = .invalid
        }

        // Dispatch callbacks on the main queue as documented in the header.
        DispatchQueue.main.async {
            if let error = error {
                SFSDKCoreLogger.e(Self.self, message: "Token refresh failed for credential \(key). Notifying \(entry.errorBlocks.count) waiter(s). Error: \(error)")
                for errorBlock in entry.errorBlocks {
                    errorBlock(error)
                }
            } else if let credentials = credentials {
                SFSDKCoreLogger.i(Self.self, message: "Token refresh succeeded for credential \(key). Notifying \(entry.completionBlocks.count) waiter(s).")
                for completionBlock in entry.completionBlocks {
                    completionBlock(credentials)
                }
            }
        }
    }

    private func handleBackgroundExpiration(forKey key: String) {
        serialQueue.async { [self] in
            guard activeRefreshes[key] != nil else { return }

            SFSDKCoreLogger.w(Self.self, message: "Background task expired during token refresh for credential \(key). Delivering cancellation error.")

            let bgError = NSError(domain: "SFSDKTokenRefreshCoordinator",
                                  code: -2,
                                  userInfo: [NSLocalizedDescriptionKey: "Token refresh interrupted: app background time expired"])
            completeRefresh(forKey: key, credentials: nil, error: bgError)
        }
    }
}
