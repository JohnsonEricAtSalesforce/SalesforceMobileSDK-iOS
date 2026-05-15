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
@testable import MobileSync

private let kMaxWaitTime: TimeInterval = 10.0

class SFSyncUpdateCallbackQueue {

    private var queue: [SyncState] = []
    private let lock = NSObject()

    // MARK: - Public methods

    func runSync(_ sync: SyncState, syncManager: SFMobileSyncSyncManager) {
        // Use reSync which internally calls the private runSync
        // This works because the sync has already been persisted to the soup
        let _ = try? syncManager.reSync(id: NSNumber(value: sync.syncId)) { [weak self] syncState in
            guard let self = self else { return }
            objc_sync_enter(self.lock)
            self.queue.append(syncState.copy() as! SyncState)
            objc_sync_exit(self.lock)
        }
    }

    func runReSync(_ syncId: NSNumber, syncManager: SFMobileSyncSyncManager) -> SyncState? {
        return try? syncManager.reSync(id: syncId) { [weak self] syncState in
            guard let self = self else { return }
            objc_sync_enter(self.lock)
            self.queue.append(syncState.copy() as! SyncState)
            objc_sync_exit(self.lock)
        }
    }

    func runReSyncByName(_ syncName: String, syncManager: SFMobileSyncSyncManager) throws -> SyncState? {
        return try syncManager.reSync(named: syncName) { [weak self] syncState in
            guard let self = self else { return }
            objc_sync_enter(self.lock)
            self.queue.append(syncState.copy() as! SyncState)
            objc_sync_exit(self.lock)
        }
    }

    func restart(_ syncManager: SFMobileSyncSyncManager, restartStoppedSyncs: Bool) throws -> Bool {
        return try syncManager.restart(restartStoppedSyncs: restartStoppedSyncs) { [weak self] syncState in
            guard let self = self else { return }
            objc_sync_enter(self.lock)
            self.queue.append(syncState.copy() as! SyncState)
            objc_sync_exit(self.lock)
        }
    }

    func getNextSyncUpdate() -> SyncState? {
        return getNextSyncUpdate(maxWaitTime: kMaxWaitTime)
    }

    func getNextSyncUpdate(maxWaitTime: TimeInterval) -> SyncState? {
        let startTime = Date()
        while true {
            if let sync = getFirst() {
                SFSDKMobileSyncLogger.d(SFSyncUpdateCallbackQueue.self, message: "getNextSyncUpdate: syncId:\(sync.syncId) status:\(SyncState.syncStatusToString(sync.status)) progress:\(sync.progress) totalSize:\(sync.totalSize)")
                return sync
            }
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed > maxWaitTime {
                SFSDKMobileSyncLogger.d(SFSyncUpdateCallbackQueue.self, message: "getNextSyncUpdate took too long (> \(elapsed) secs) to complete.")
                return nil
            }
            SFSDKMobileSyncLogger.d(SFSyncUpdateCallbackQueue.self, message: "## sleeping...")
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        }
    }

    // MARK: - Private methods

    private func getFirst() -> SyncState? {
        objc_sync_enter(lock)
        defer { objc_sync_exit(lock) }
        if !queue.isEmpty {
            return queue.removeFirst()
        }
        return nil
    }
}
