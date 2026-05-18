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

@objc(SFSyncDownTask)
@objcMembers
open class SFSyncDownTask: SFSyncTask {

    @objc
    public override init(_ syncManager: SFMobileSyncSyncManager, sync: SFSyncState, updateBlock: SFSyncSyncManagerUpdateBlock?) {
        super.init(syncManager, sync: sync, updateBlock: updateBlock)
    }

    open override func runSync(_ sync: SFSyncState) {
        let soupName = sync.soupName
        let mergeMode = sync.mergeMode
        guard let target = sync.target as? SFSyncDownTarget else { return }
        let syncId = NSNumber(value: sync.syncId)

        var countFetched: UInt = 0
        var newMaxTimeStamp: Int64 = sync.maxTimeStamp
        var idsToSkip: NSOrderedSet?

        var continueFetchBlockRecurse: SFSyncDownTargetFetchCompleteBlock?

        if mergeMode == .leaveIfChanged {
            idsToSkip = target.getIdsToSkip(self.syncManager, soupName: soupName)
        }

        let failBlock: SFSyncDownTargetFetchErrorBlock = { [weak self] error in
            guard let self = self else { return }
            self.failSync(sync, failureMessage: "Server call for sync down failed", error: error ?? NSError(domain: kSFMobileSyncErrorDomain, code: -1, userInfo: nil))
            continueFetchBlockRecurse = nil
        }

        let startFetchBlock: SFSyncDownTargetFetchCompleteBlock = { [weak self] records in
            guard let self = self else { return }
            sync.totalSize = Int(target.totalSize)
            self.updateSync(sync, countSynched: 0)
            if sync.isRunning() {
                continueFetchBlockRecurse?(records)
            } else {
                continueFetchBlockRecurse = nil
            }
        }

        let continueFetchBlock: SFSyncDownTargetFetchCompleteBlock = { [weak self] records in
            guard let self = self else { return }

            if let records = records {
                if self.shouldStop() {
                    continueFetchBlockRecurse = nil
                    return
                }

                // Figure out records to save
                let recordsToSave: [Any]
                if let idsToSkip = idsToSkip, idsToSkip.count > 0 {
                    recordsToSave = self.removeWithIds(records, idsToSkip: idsToSkip, idField: target.idFieldName)
                } else {
                    recordsToSave = records
                }

                // Save to smartstore
                target.cleanAndSaveRecordsToLocalStore(syncManager: self.syncManager, soupName: soupName, records: recordsToSave, syncId: syncId)
                let maxTimeStampRecords = target.getLatestModificationTimeStamp(records)
                if maxTimeStampRecords >= 0 {
                    newMaxTimeStamp = max(maxTimeStampRecords, newMaxTimeStamp)
                }
                countFetched += UInt(records.count)

                // Update maxTimeStamp if sorted by latest mod or all fetched
                if target.isSyncDownSortedByLatestModification() || countFetched == UInt(sync.totalSize) {
                    sync.maxTimeStamp = newMaxTimeStamp
                }

                // Update sync status
                self.updateSync(sync, countSynched: countFetched)

                if sync.isRunning() {
                    target.continueFetch(self.syncManager, errorBlock: failBlock, completeBlock: continueFetchBlockRecurse ?? { _ in })
                } else {
                    continueFetchBlockRecurse = nil
                }
            } else {
                // Done
                sync.maxTimeStamp = newMaxTimeStamp
                self.updateSync(sync, countSynched: UInt(sync.totalSize))
                continueFetchBlockRecurse = nil
            }
        }

        continueFetchBlockRecurse = continueFetchBlock

        // Start fetch
        target.startFetch(self.syncManager, maxTimeStamp: sync.maxTimeStamp, errorBlock: failBlock, completeBlock: startFetchBlock)
    }

    private func removeWithIds(_ records: [Any], idsToSkip: NSOrderedSet, idField: String) -> [Any] {
        var arr = [Any]()
        for record in records {
            guard let recordDict = record as? [String: Any] else {
                arr.append(record)
                continue
            }
            let id = recordDict[idField] as? String
            if id == nil || !idsToSkip.contains(id as Any) {
                arr.append(record)
            }
        }
        return arr
    }
}
