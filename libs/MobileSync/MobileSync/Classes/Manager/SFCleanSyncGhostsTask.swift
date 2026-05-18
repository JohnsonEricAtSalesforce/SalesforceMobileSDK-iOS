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

/// This task class is responsible for running "clean resync ghosts" tasks.
@objc(SFCleanSyncGhostsTask)
@objcMembers
open class SFCleanSyncGhostsTask: SFSyncTask {

    private var completionStatusBlock: SFSyncSyncManagerCompletionStatusBlock

    @objc
    public init(_ syncManager: SFMobileSyncSyncManager, sync: SFSyncState, completionStatusBlock: @escaping SFSyncSyncManagerCompletionStatusBlock) {
        self.completionStatusBlock = completionStatusBlock
        super.init(syncManager, sync: sync, updateBlock: nil)
    }

    open override func updateSync(_ sync: SFSyncState, countSynched: UInt) {
        // Not a true sync
        // Leaving sync state alone
    }

    open override func runSync(_ sync: SFSyncState) {
        guard let target = sync.target as? SFSyncDownTarget else { return }
        let soupName = sync.soupName
        let syncId = NSNumber(value: sync.syncId)

        target.cleanGhosts(self.syncManager, soupName: soupName, syncId: syncId, errorBlock: { [weak self] error in
            guard let self = self else { return }
            SFSDKMobileSyncLogger.e(type(of: self), message: "Failed to get list of remote IDs, \(error?.localizedDescription ?? "")")
            self.createAndStoreEvent(sync, numRecords: -1)
            self.syncManager.removeFromActiveSyncs(self)
            self.completionStatusBlock(.failed, 0)
        }, completeBlock: { [weak self] localIds in
            guard let self = self else { return }
            self.createAndStoreEvent(sync, numRecords: Int(localIds?.count ?? 0))
            self.syncManager.removeFromActiveSyncs(self)
            self.completionStatusBlock(.done, UInt(localIds?.count ?? 0))
        })
    }

    private func createAndStoreEvent(_ sync: SFSyncState, numRecords: Int) {
        var eventAttrs = [String: Any]()
        eventAttrs["syncId"] = NSNumber(value: sync.syncId)
        eventAttrs["syncTarget"] = NSStringFromClass(type(of: sync.target))
        if numRecords >= 0 {
            eventAttrs["numRecords"] = NSNumber(value: numRecords)
        }
        SFSDKEventBuilderHelper.createAndStoreEvent("cleanResyncGhosts", userAccount: nil, className: NSStringFromClass(type(of: self)), attributes: eventAttrs)
    }
}
