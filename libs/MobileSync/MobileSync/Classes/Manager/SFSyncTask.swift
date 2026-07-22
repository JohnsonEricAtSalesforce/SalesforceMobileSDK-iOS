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

public let kSyncManagerUnchanged: Int = -1

@objc(SFSyncTask)
@objcMembers
open class SFSyncTask: NSObject {

    // The -1 sentinel as an unsigned value. Swift's UInt(Int) initializer traps on negatives, whereas the
    // original ObjC implicitly reinterpreted NSInteger(-1) as NSUIntegerMax when passed to an NSUInteger
    // parameter. Reproduce that wrap with UInt(bitPattern:) so the sentinel comparison stays value-faithful.
    private static let unchangedSentinel = UInt(bitPattern: kSyncManagerUnchanged)

    open private(set) var syncManager: SFMobileSyncSyncManager
    open private(set) var syncId: NSNumber
    private var sync: SFSyncState
    private var updateBlock: SFSyncSyncManagerUpdateBlock?

    // MARK: - Initialization

    @objc
    public init(_ syncManager: SFMobileSyncSyncManager, sync: SFSyncState, updateBlock: SFSyncSyncManagerUpdateBlock?) {
        self.syncManager = syncManager
        self.sync = sync
        self.syncId = NSNumber(value: sync.syncId)
        self.updateBlock = updateBlock
        super.init()

        syncManager.addToActiveSyncs(self)
        sync.status = .running
        updateSync(sync, countSynched: 0)
    }

    // MARK: - Public methods

    @objc
    open func run() {
        if !shouldStop() {
            runSync(sync)
        }
    }

    @objc
    open func shouldStop() -> Bool {
        if !syncManager.checkAcceptingSyncs(nil) {
            sync.status = .stopped
            updateSync(sync, countSynched: Self.unchangedSentinel)
            return true
        }
        return false
    }

    @objc
    open func runSync(_ sync: SFSyncState) {
        // Abstract - subclasses must override
        NSException(name: .internalInconsistencyException, reason: "Subclasses must override runSync", userInfo: nil).raise()
    }

    @objc
    open func failSync(_ sync: SFSyncState, failureMessage: String, error: Error) {
        SFSDKMobileSyncLogger.e(type(of: self), message: "runSync failed:\(sync) cause:\(failureMessage) error:\(error)")
        sync.error = (error as NSError).userInfo.description
        sync.status = .failed
        updateSync(sync, countSynched: Self.unchangedSentinel)
    }

    @objc
    open func updateSync(_ sync: SFSyncState, countSynched: UInt) {
        // Update progress
        if countSynched != Self.unchangedSentinel {
            // The original ObjC evaluated countSynched*100/totalSize entirely in NSUInteger arithmetic, so a
            // negative totalSize (e.g. the -1 "unknown size" sentinel) wrapped to NSUIntegerMax and yielded a
            // progress of 0 rather than trapping. Reproduce that with bit-pattern reinterpretation and wrapping
            // multiply; Swift's plain UInt(Int) initializer would trap on the negative sentinel.
            sync.progress = sync.totalSize == 0 ? 100 : Int(bitPattern: countSynched &* 100 / UInt(bitPattern: sync.totalSize))
        }

        // Update status
        if sync.status == .running && sync.progress == 100 {
            sync.status = .done
        }

        // Save sync state
        sync.save(self.syncManager.store)
        SFSDKMobileSyncLogger.d(type(of: self), message: "updateSync: syncId:\(sync.syncId) status:\(SFSyncState.syncStatusToString(sync.status)) progress:\(sync.progress) totalSize:\(sync.totalSize)")

        // Create event and remove from active sync list if stopped/done/failed
        switch sync.status {
        case .new, .running:
            break
        case .stopped, .done, .failed:
            createAndStoreEvent(sync)
            syncManager.removeFromActiveSyncs(self)
        @unknown default:
            break
        }

        // Call updateBlock if any
        updateBlock?(sync)
    }

    // MARK: - Private

    private func createAndStoreEvent(_ sync: SFSyncState) {
        var attributes = [String: Any]()
        if sync.totalSize > 0 {
            attributes["numRecords"] = NSNumber(value: sync.totalSize)
        }
        attributes["syncId"] = NSNumber(value: sync.syncId)
        attributes["syncTarget"] = NSStringFromClass(type(of: sync.target))
        attributes[SFSDKEventBuilderHelper.startTimeKey] = NSNumber(value: sync.startTime)
        attributes[SFSDKEventBuilderHelper.endTimeKey] = NSNumber(value: sync.endTime)
        SFSDKEventBuilderHelper.createAndStoreEvent(SFSyncState.syncTypeToString(sync.type), userAccount: nil, className: NSStringFromClass(type(of: self.syncManager)), attributes: attributes)
    }
}
