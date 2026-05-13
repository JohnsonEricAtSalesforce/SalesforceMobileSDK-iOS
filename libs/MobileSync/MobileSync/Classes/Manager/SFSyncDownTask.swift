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

/**
 * Task class responsible for running sync down
 */
@objc(SFSyncDownTask)
public class SFSyncDownTask: SFSyncTask {

    @objc
    public override init(_ syncManager: SFMobileSyncSyncManager, sync: SyncState, updateBlock: SyncUpdateBlock?) {
        super.init(syncManager, sync: sync, updateBlock: updateBlock)
    }

    override func runSync(_ sync: SyncState) {
        let soupName = sync.soupName
        let mergeMode = sync.mergeMode
        guard let target = sync.target as? SyncDownTarget else { return }
        let syncId = NSNumber(value: sync.syncId)

        var countFetched: UInt = 0
        var newMaxTimeStamp: Int64 = sync.maxTimeStamp
        var idsToSkip: NSOrderedSet? = nil
        var continueFetchBlockRecurse: SyncDownTargetFetchCompleteBlock? = nil

        if mergeMode == .leaveIfChanged {
            idsToSkip = target.getIdsToSkip(syncManager: self.syncManager, soupName: soupName)
        }

        let failBlock: SyncDownTargetFetchErrorBlock = { [weak self] error in
            guard let self = self, let error = error else { return }
            self.fail(sync, failureMessage: "Server call for sync down failed", error: error)
            continueFetchBlockRecurse = nil
        }

        let startFetchBlock: SyncDownTargetFetchCompleteBlock = { [weak self] records in
            guard let self = self else { return }
            sync.totalSize = Int(target.totalSize)
            self.update(sync, countSynched: 0)
            if sync.isRunning() {
                continueFetchBlockRecurse?(records)
            } else {
                continueFetchBlockRecurse = nil
            }
        }

        let continueFetchBlock: SyncDownTargetFetchCompleteBlock = { [weak self] records in
            guard let self = self else { return }

            if let records = records {
                if self.shouldStop() {
                    continueFetchBlockRecurse = nil
                    return
                }

                // Figure out records to save
                let recordsToSave: [[String: Any]]
                if let idsToSkip = idsToSkip, idsToSkip.count > 0 {
                    recordsToSave = self.removeWithIds(records as? [[String: Any]] ?? [], idsToSkip: idsToSkip, idField: target.idFieldName)
                } else {
                    recordsToSave = records as? [[String: Any]] ?? []
                }

                // Save to smartstore.
                target.cleanAndSaveRecordsToLocalStore(syncManager: self.syncManager, soupName: soupName, records: recordsToSave, syncId: syncId)
                let maxTimeStampRecords = target.getLatestModificationTimeStamp(records)
                if maxTimeStampRecords >= 0 {
                    newMaxTimeStamp = maxTimeStampRecords > newMaxTimeStamp ? maxTimeStampRecords : newMaxTimeStamp
                }
                countFetched += UInt(records.count)

                // Updating maxTimeStamp if records are ordered by latest modification or if we have seen them all
                if target.isSyncDownSortedByLatestModification() || countFetched == sync.totalSize {
                    sync.maxTimeStamp = newMaxTimeStamp
                }

                // Update sync status
                self.update(sync, countSynched: Int(countFetched))

                if sync.isRunning() {
                    target.continueFetch(syncManager: self.syncManager, onFail: failBlock, onComplete: continueFetchBlockRecurse)
                } else {
                    continueFetchBlockRecurse = nil
                }
            } else {
                // In some cases (e.g. resync for refresh sync down), the totalSize is just an (over)estimation
                // As a result countFetched might never match totalSize
                sync.maxTimeStamp = newMaxTimeStamp
                self.update(sync, countSynched: Int(sync.totalSize))
                continueFetchBlockRecurse = nil
            }
        }

        // initialize the alias
        continueFetchBlockRecurse = continueFetchBlock

        // Start fetch
        target.startFetch(syncManager: self.syncManager, maxTimeStamp: sync.maxTimeStamp, onFail: failBlock, onComplete: startFetchBlock)
    }

    private func removeWithIds(_ records: [[String: Any]], idsToSkip: NSOrderedSet, idField: String) -> [[String: Any]] {
        var arr: [[String: Any]] = []
        for record in records {
            // Keep ?
            if let id = record[idField] as? String {
                if !idsToSkip.contains(id) {
                    arr.append(record)
                }
            } else {
                arr.append(record)
            }
        }
        return arr
    }
}
