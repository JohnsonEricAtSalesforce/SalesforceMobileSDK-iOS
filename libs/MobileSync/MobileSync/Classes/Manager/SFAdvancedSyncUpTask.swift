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

/**
 * This task class is responsible for running advanced sync up tasks.
 */
@objc(SFAdvancedSyncUpTask)
public class SFAdvancedSyncUpTask: SFSyncUpTask {

    @objc
    public override init(_ syncManager: SFMobileSyncSyncManager, sync: SyncState, updateBlock: SyncUpdateBlock?) {
        super.init(syncManager, sync: sync, updateBlock: updateBlock)
    }

    override func syncUp(_ sync: SyncState, recordIds: [Any]) {
        guard let target = sync.target as? SyncUpTarget else { return }
        let soupName = sync.soupName
        sync.totalSize = recordIds.count

        let recordIdNumbers = recordIds.compactMap { $0 as? NSNumber }
        let records = target.getFromLocalStore(self.syncManager, soupName: soupName, storeIds: recordIdNumbers)

        // Figuring out what records need to be synced up based on merge mode and last mod date on server
        guard let options = sync.options else { return }
        self.shouldSyncUpRecords(self.syncManager, target: target, records: records, options: options) { recordIdToShouldSyncUp in
            self.syncUpMultipleEntries(sync,
                                       records: records,
                                       recordIdToShouldSyncUp: recordIdToShouldSyncUp as [String: Any],
                                       index: 0,
                                       batch: NSMutableArray())
        }
    }

    func shouldSyncUpRecords(_ syncManager: SFMobileSyncSyncManager,
                           target: SyncUpTarget,
                           records: [[String: Any]],
                           options: SFSyncOptions,
                           resultBlock: @escaping RecordsNewerThanServerBlock) {
        if options.mergeMode == .overwrite {
            var result = [String: Any]()

            for record in records {
                if let soupEntryId = record[SOUP_ENTRY_ID] {
                    result["\(soupEntryId)"] = true
                }
            }

            resultBlock(result)
        } else {
            target.areNewerThanServer(syncManager: syncManager, records: records, resultBlock: resultBlock)
        }
    }

    func syncUpMultipleEntries(_ sync: SyncState,
                              records: [[String: Any]],
                              recordIdToShouldSyncUp: [String: Any],
                              index i: Int,
                              batch: NSMutableArray) {
        guard let target = sync.target as? SyncUpTarget & AdvancedSyncUpTarget else { return }
        let maxBatchSize = target.maxBatchSize
        sync.totalSize = records.count
        self.update(sync, countSynched: i)

        if sync.isDone() || self.shouldStop() {
            return
        }

        guard i < records.count else { return }
        var record = records[i]
        SFSDKMobileSyncLogger.d(type(of: self), message: "syncUpMultipleEntries:\(record)")

        if let storeId = record[SOUP_ENTRY_ID] as? NSNumber {
            let shouldSyncUp = (recordIdToShouldSyncUp["\(storeId)"] as? Bool) ?? false
            if shouldSyncUp {
                batch.add(record)
            }
        }

        // Process batch if max batch size reached or at the end of recordIds
        if batch.count == maxBatchSize || i == records.count - 1 {
            self.processSyncUpBatch(sync,
                                   records: records,
                                   recordIdToShouldSyncUp: recordIdToShouldSyncUp,
                                   index: i,
                                   batch: batch)
        } else {
            self.syncUpMultipleEntries(sync,
                                      records: records,
                                      recordIdToShouldSyncUp: recordIdToShouldSyncUp,
                                      index: i + 1,
                                      batch: batch)
        }
    }

    func processSyncUpBatch(_ sync: SyncState,
                          records: [[String: Any]],
                          recordIdToShouldSyncUp: [String: Any],
                          index i: Int,
                          batch: NSMutableArray) {
        guard let advancedTarget = sync.target as? SyncUpTarget & AdvancedSyncUpTarget else { return }

        // Next
        let nextBlock: SyncUpcompletionBlock = { [weak self] syncUpResult in
            guard let self = self else { return }
            batch.removeAllObjects()
            self.syncUpMultipleEntries(sync,
                                      records: records,
                                      recordIdToShouldSyncUp: recordIdToShouldSyncUp,
                                      index: i + 1,
                                      batch: batch)
        }

        let failBlock: SyncUpTargetErrorBlock = { [weak self] err in
            guard let self = self else { return }
            self.fail(sync, failureMessage: "syncUpRecords failed", error: err)
        }

        guard let options = sync.options,
              let fieldlist = options.fieldlist else { return }

        let batchRecords = batch.compactMap { $0 as? [String: Any] }.map { NSMutableDictionary(dictionary: $0) }
        advancedTarget.syncUpRecords(self.syncManager,
                                    records: batchRecords,
                                    fieldlist: fieldlist,
                                    mergeMode: options.mergeMode,
                                    syncSoupName: sync.soupName,
                                    completionBlock: nextBlock,
                                    failBlock: failBlock)
    }
}
