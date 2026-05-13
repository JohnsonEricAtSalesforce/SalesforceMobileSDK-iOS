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
import SalesforceSDKCore

// Unchanged
public let kSyncManagerUnchanged: Int = -1

/**
 * Abstract super class of task classes responsible for running syncs
 */
@objc(SFSyncTask)
public class SFSyncTask: NSObject {

    @objc public private(set) var syncManager: SFMobileSyncSyncManager
    @objc public private(set) var syncId: NSNumber
    private var sync: SyncState
    private var updateBlock: SyncUpdateBlock?

    @objc
    public init(_ syncManager: SFMobileSyncSyncManager, sync: SyncState, updateBlock: SyncUpdateBlock?) {
        self.syncManager = syncManager
        self.sync = sync
        self.syncId = NSNumber(value: sync.syncId)
        self.updateBlock = updateBlock

        super.init()

        self.syncManager.addToActiveSyncs(self)
        sync.status = .running
        self.update(sync, countSynched: 0)
        // XXX not actually running on worker thread until run() gets invoked
        //     may be we should introduce another state?
    }

    @objc
    public func shouldStop() -> Bool {
        if !self.syncManager.checkAcceptingSyncs(nil) {
            self.sync.status = .stopped
            self.update(self.sync, countSynched: kSyncManagerUnchanged)
            return true
        } else {
            return false
        }
    }

    @objc
    public func run() {
        if !self.shouldStop() {
            self.runSync(self.sync)
        }
    }

    func runSync(_ sync: SyncState) {
        fatalError("Subclass must implement runSync")
    }

    @objc
    public func fail(_ sync: SyncState, failureMessage: String, error: Error) {
        SFSDKMobileSyncLogger.e(type(of: self), message: "runSync failed:\(sync) cause:\(failureMessage) error\(error)")
        sync.error = (error as NSError).userInfo.description
        sync.status = .failed
        self.update(sync, countSynched: kSyncManagerUnchanged)
    }

    @objc
    public func update(_ sync: SyncState, countSynched: Int) {
        // Update progress
        if countSynched != kSyncManagerUnchanged {
            sync.progress = sync.totalSize == 0 ? 100 : (countSynched * 100) / Int(sync.totalSize)
        }

        // Update status
        if sync.status == .running && sync.progress == 100 {
            sync.status = .done
        }

        // Save sync state
        sync.save(self.syncManager.store)
        SFSDKMobileSyncLogger.d(type(of: self), message: "updateSync: syncId:\(sync.syncId) status:\(SyncState.syncStatusToString(sync.status)) progress:\(sync.progress) totalSize:\(sync.totalSize)")

        // Create event and remove from active sync list if stopped/done/failed
        switch self.sync.status {
        case .new, .running:
            break
        case .stopped, .done, .failed:
            self.createAndStoreEvent(sync)
            self.syncManager.removeFromActiveSyncs(self)
        @unknown default:
            break
        }

        // Call updateBlock if any
        self.updateBlock?(sync)
    }

    private func createAndStoreEvent(_ sync: SyncState) {
        var attributes: [String: Any] = [:]
        if sync.totalSize > 0 {
            attributes["numRecords"] = sync.totalSize
        }
        attributes["syncId"] = sync.syncId
        if let target = sync.target {
            attributes["syncTarget"] = NSStringFromClass(type(of: target))
        }
        attributes[SFSDKEventBuilderHelper.startTime] = sync.startTime
        attributes[SFSDKEventBuilderHelper.endTime] = sync.endTime

        SFSDKEventBuilderHelper.createAndStoreEvent(SyncState.syncTypeToString(sync.type),
                                                    userAccount: nil,
                                                    className: NSStringFromClass(type(of: self.syncManager)),
                                                    attributes: attributes)
    }
}
