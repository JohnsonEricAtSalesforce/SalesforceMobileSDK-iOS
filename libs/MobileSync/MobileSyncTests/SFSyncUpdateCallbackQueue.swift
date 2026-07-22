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

private let MAX_WAIT_TIME: TimeInterval = 10.0

@objc(SFSyncUpdateCallbackQueue)
@objcMembers
class SFSyncUpdateCallbackQueue: NSObject {

    private var queue: [SFSyncState] = []
    // NB: lock on a stable object, NOT on `queue`. `queue` is a Swift Array (value type); passing it to
    // objc_sync_enter bridges it to a temporary NSArray, and an EMPTY array bridges to a process-global
    // shared-empty singleton. After append(), the array bridges to a different object, so objc_sync_exit
    // would release a different lock than the one entered — orphaning the singleton's lock and deadlocking
    // every thread that later locks an empty array. The original ObjC locked a stable NSMutableArray whose
    // identity was invariant under mutation. This NSLock restores that invariant.
    private let lock = NSLock()

    override init() {
        super.init()
    }

    // MARK: - Public methods

    func runSync(_ sync: SFSyncState, syncManager: SFMobileSyncSyncManager) {
        syncManager.runSync(sync) { [weak self] updatedSync in
            guard let self = self else { return }
            self.lock.lock()
            self.queue.append(updatedSync.copy() as! SFSyncState)
            self.lock.unlock()
        }
    }

    func runReSync(_ syncId: NSNumber, syncManager: SFMobileSyncSyncManager) -> SFSyncState? {
        return try? runReSync(syncId, syncManager: syncManager, error: ())
    }

    func runReSync(_ syncId: NSNumber, syncManager: SFMobileSyncSyncManager, error: ()) throws -> SFSyncState? {
        return try syncManager.reSync(id: syncId) { [weak self] updatedSync in
            guard let self = self else { return }
            self.lock.lock()
            self.queue.append(updatedSync.copy() as! SFSyncState)
            self.lock.unlock()
        }
    }

    func runReSyncByName(_ syncName: String, syncManager: SFMobileSyncSyncManager) throws -> SFSyncState? {
        return try syncManager.reSync(named: syncName) { [weak self] updatedSync in
            guard let self = self else { return }
            self.lock.lock()
            self.queue.append(updatedSync.copy() as! SFSyncState)
            self.lock.unlock()
        }
    }

    func restart(_ syncManager: SFMobileSyncSyncManager, restartStoppedSyncs: Bool) throws -> Bool {
        return try syncManager.restart(restartStoppedSyncs: restartStoppedSyncs) { [weak self] updatedSync in
            guard let self = self else { return }
            self.lock.lock()
            self.queue.append(updatedSync.copy() as! SFSyncState)
            self.lock.unlock()
        }
    }

    func getNextSyncUpdate() -> SFSyncState? {
        return getNextSyncUpdate(MAX_WAIT_TIME)
    }

    func getNextSyncUpdate(_ maxWaitTime: TimeInterval) -> SFSyncState? {
        let startTime = Date()
        while true {
            if let sync = getFirst() {
                SFSDKMobileSyncLogger.d(type(of: self), message: "getNextSyncUpdate: syncId:\(sync.syncId) status:\(SFSyncState.syncStatusToString(sync.status)) progress:\(sync.progress) totalSize:\(sync.totalSize)")
                return sync
            }
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed > maxWaitTime {
                SFSDKMobileSyncLogger.d(type(of: self), message: "getNextSyncUpdate took too long (> \(elapsed) secs) to complete.")
                return nil
            }
            SFSDKMobileSyncLogger.d(type(of: self), message: "## sleeping...")
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        }
    }

    private func getFirst() -> SFSyncState? {
        lock.lock()
        defer { lock.unlock() }
        if !queue.isEmpty {
            return queue.removeFirst()
        }
        return nil
    }
}
