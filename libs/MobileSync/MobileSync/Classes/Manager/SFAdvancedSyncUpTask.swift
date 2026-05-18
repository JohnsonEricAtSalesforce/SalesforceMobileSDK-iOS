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
import SmartStore

/// This task class is responsible for running advanced sync up tasks.
@objc(SFAdvancedSyncUpTask)
@objcMembers
open class SFAdvancedSyncUpTask: SFSyncUpTask {

    @objc
    public override init(_ syncManager: SFMobileSyncSyncManager, sync: SFSyncState, updateBlock: SFSyncSyncManagerUpdateBlock?) {
        super.init(syncManager, sync: sync, updateBlock: updateBlock)
    }

    open override func runSync(_ sync: SFSyncState) {
        guard let target = sync.target as? SFSyncUpTarget else { return }
        let soupName = sync.soupName
        let dirtyRecordIds = target.getIdsOfRecordsToSyncUp(self.syncManager, soupName: soupName)
        syncUpAdvanced(sync, recordIds: dirtyRecordIds)
    }

    private func syncUpAdvanced(_ sync: SFSyncState, recordIds: [Any]) {
        guard let target = sync.target as? SFSyncUpTarget else { return }
        let soupName = sync.soupName
        sync.totalSize = Int(recordIds.count)

        let records = target.getFromLocalStore(self.syncManager, soupName: soupName, storeIds: recordIds as? [NSNumber] ?? [])

        // Figuring out what records need to be synced up based on merge mode and last mod date on server
        guard let options = sync.options else { return }
        shouldSyncUpRecords(syncManager: self.syncManager, target: target, records: records, options: options) { [weak self] recordIdToShouldSyncUp in
            self?.syncUpMultipleEntries(sync, records: records, recordIdToShouldSyncUp: recordIdToShouldSyncUp, index: 0, batch: NSMutableArray())
        }
    }

    private func shouldSyncUpRecords(syncManager: SFMobileSyncSyncManager, target: SFSyncUpTarget, records: [NSDictionary], options: SFSyncOptions, resultBlock: @escaping SFSyncUpRecordsNewerThanServerBlock) {
        if options.mergeMode == .overwrite {
            var result = [AnyHashable: Any]()
            for record in records {
                if let storeId = record[SmartStoreSoupEntryId] as? NSNumber {
                    result[storeId] = NSNumber(value: true)
                }
            }
            resultBlock(result as NSDictionary)
        } else {
            target.areNewerThanServer(syncManager, records: records, resultBlock: resultBlock)
        }
    }

    private func syncUpMultipleEntries(_ sync: SFSyncState, records: [NSDictionary], recordIdToShouldSyncUp: NSDictionary, index: UInt, batch: NSMutableArray) {
        guard let target = sync.target as? SFSyncUpTarget,
              let advancedTarget = target as? SFSyncUpTarget & SFAdvancedSyncUpTarget else { return }
        let maxBatchSize = advancedTarget.maxBatchSize
        sync.totalSize = Int(records.count)
        updateSync(sync, countSynched: index)

        if sync.isDone() || shouldStop() {
            return
        }

        let record = records[Int(index)].mutableCopy() as? NSMutableDictionary ?? NSMutableDictionary()
        SFSDKMobileSyncLogger.d(type(of: self), message: "syncUpMultipleEntries:\(record)")

        let storeId = record[SmartStoreSoupEntryId] as? NSNumber
        let shouldSyncUp = (recordIdToShouldSyncUp[storeId as Any] as? NSNumber)?.boolValue ?? false
        if shouldSyncUp {
            batch.add(record)
        }

        // Process batch if max batch size reached or at the end of recordIds
        if batch.count == maxBatchSize || index == UInt(records.count) - 1 {
            processSyncUpBatch(sync, records: records, recordIdToShouldSyncUp: recordIdToShouldSyncUp, index: index, batch: batch)
        } else {
            syncUpMultipleEntries(sync, records: records, recordIdToShouldSyncUp: recordIdToShouldSyncUp, index: index + 1, batch: batch)
        }
    }

    private func processSyncUpBatch(_ sync: SFSyncState, records: [NSDictionary], recordIdToShouldSyncUp: NSDictionary, index: UInt, batch: NSMutableArray) {
        guard let advancedTarget = sync.target as? SFSyncUpTarget & SFAdvancedSyncUpTarget else { return }

        // Next
        let nextBlock: SFSyncUpTargetCompleteBlock = { [weak self] _ in
            batch.removeAllObjects()
            self?.syncUpMultipleEntries(sync, records: records, recordIdToShouldSyncUp: recordIdToShouldSyncUp, index: index + 1, batch: batch)
        }

        let failBlock: SFSyncUpTargetErrorBlock = { [weak self] err in
            self?.failSync(sync, failureMessage: "syncUpRecords failed", error: err)
        }

        advancedTarget.syncUpRecords(self.syncManager, records: batch as? [NSMutableDictionary] ?? [], fieldlist: sync.options?.fieldlist ?? [], mergeMode: sync.options?.mergeMode ?? .overwrite, syncSoupName: sync.soupName, completionBlock: nextBlock, failBlock: failBlock)
    }
}
