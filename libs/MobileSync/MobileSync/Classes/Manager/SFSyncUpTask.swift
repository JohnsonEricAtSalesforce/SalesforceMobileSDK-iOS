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

/**
 * Task class responsible for running sync up
 */
@objc(SFSyncUpTask)
public class SFSyncUpTask: SFSyncTask {

    @objc
    public override init(_ syncManager: SFMobileSyncSyncManager, sync: SyncState, updateBlock: SyncUpdateBlock?) {
        super.init(syncManager, sync: sync, updateBlock: updateBlock)
    }

    override func runSync(_ sync: SyncState) {
        guard let target = sync.target as? SyncUpTarget else { return }
        let dirtyRecordIds = target.getIdsOfRecordsToSyncUp(syncManager: self.syncManager, soupName: sync.soupName)
        self.syncUp(sync, recordIds: dirtyRecordIds)
    }

    func syncUp(_ sync: SyncState, recordIds: [Any]) {
        self.syncUpOneEntry(sync, recordIds: recordIds, index: 0)
    }

    func syncUpOneEntry(_ sync: SyncState, recordIds: [Any], index i: Int) {
        guard let target = sync.target as? SyncUpTarget else { return }
        let soupName = sync.soupName
        let mergeMode = sync.mergeMode
        sync.totalSize = recordIds.count
        self.update(sync, countSynched: i)

        if sync.isDone() || self.shouldStop() {
            return
        }

        guard i < recordIds.count else { return }
        guard let recordIdNumber = recordIds[i] as? NSNumber else {
            self.syncUpOneEntry(sync, recordIds: recordIds, index: i + 1)
            return
        }
        let record = target.getFromLocalStore(self.syncManager, soupName: soupName, storeId: recordIdNumber)
        SFSDKMobileSyncLogger.d(SFSyncUpTask.self, message: "syncUpOneRecord:\(record)")

        // Do we need to do a create, update or delete
        let locallyCreated = target.isLocallyCreated(record)
        let locallyUpdated = target.isLocallyUpdated(record)
        let locallyDeleted = target.isLocallyDeleted(record)

        var action: SyncUpTargetAction = .none
        if locallyDeleted {
            action = .delete
        } else if locallyCreated {
            action = .create
        } else if locallyUpdated {
            action = .update
        }

        /*
         * Checks if we are attempting to update a record that has been updated
         * on the server AFTER the client's last sync down. If the merge mode
         * passed in tells us to leave the record alone under these
         * circumstances, we will do nothing.
         */
        if mergeMode == .leaveIfChanged && !locallyCreated {
            // Need to check the modification date on the server, against the local date.
            target.isNewerThanServer(syncManager: self.syncManager, record: record) { [weak self] isNewerThanServer in
                guard let self = self else { return }
                if isNewerThanServer {
                    self.resumeSyncUpOneEntry(sync,
                                            recordIds: recordIds,
                                            index: i,
                                            record: record,
                                            action: action)
                } else {
                    // Server date is newer than the local date.  Skip this update.
                    SFSDKMobileSyncLogger.d(type(of: self), message: "syncUpOneRecord: Record not synced since client does not have the latest from server:\(record)")
                    self.syncUpOneEntry(sync, recordIds: recordIds, index: i + 1)
                }
            }
        } else {
            // State is such that we can simply update the record directly.
            self.resumeSyncUpOneEntry(sync, recordIds: recordIds, index: i, record: record, action: action)
        }
    }

    func resumeSyncUpOneEntry(_ sync: SyncState,
                            recordIds: [Any],
                            index i: Int,
                            record: [String: Any],
                            action: SyncUpTargetAction) {
        let mergeMode = sync.mergeMode
        guard let target = sync.target as? SyncUpTarget else { return }
        let soupName = sync.soupName

        // Next
        let nextBlock: () -> Void = { [weak self] in
            self?.syncUpOneEntry(sync, recordIds: recordIds, index: i + 1)
        }

        // If it is not a advanced sync up target and there is no changes on the record, go to next
        if action == .none {
            // Next
            nextBlock()
            return
        }

        // Delete handler
        let completeBlockDelete: SyncUpTargetCompleteBlock = { [weak self] d in
            guard let self = self else { return }
            // Remove entry on delete
            target.deleteFromLocalStore(syncManager: self.syncManager, soupName: soupName, record: record)

            // Next
            nextBlock()
        }

        // Update handler
        let completeBlockUpdate: SyncUpTargetCompleteBlock = { [weak self] d in
            guard let self = self else { return }
            target.cleanAndSaveInLocalStore(syncManager: self.syncManager, soupName: soupName, record: record)

            // Next
            nextBlock()
        }

        // Create handler
        let fieldName = target.idFieldName
        let completeBlockCreate: SyncUpTargetCompleteBlock = { [weak self] d in
            guard let self = self else { return }
            // Replace id with server id during create
            var mutableRecord = record
            if let d = d, let createdId = d[kCreatedId] {
                mutableRecord[fieldName] = createdId
            }
            target.cleanAndSaveInLocalStore(syncManager: self.syncManager, soupName: soupName, record: mutableRecord)
            nextBlock()
        }

        // Create failure handler
        let failBlockCreate: SyncUpTargetErrorBlock = { [weak self] err in
            guard let self = self else { return }
            if SFRestRequest.isNetworkError(err) {
                self.fail(sync, failureMessage: "Create server call failed", error: err)
            } else {
                target.saveRecordToLocalStoreWithLastError(syncManager: self.syncManager, soupName: soupName, record: record)

                // Next
                nextBlock()
            }
        }

        // Update failure handler
        let failBlockUpdate: SyncUpTargetErrorBlock = { [weak self] err in
            guard let self = self else { return }
            // Handling remotely deleted records
            if (err as NSError).code == 404 {
                if mergeMode == .overwrite {
                    target.createOnServer(syncManager: self.syncManager, record: record, fieldlist: sync.options?.fieldlist ?? [], onComplete: completeBlockCreate, onFail: failBlockCreate)
                } else {
                    // Next
                    nextBlock()
                }
            } else if SFRestRequest.isNetworkError(err) {
                self.fail(sync, failureMessage: "Update server call failed", error: err)
            } else {
                target.saveRecordToLocalStoreWithLastError(syncManager: self.syncManager, soupName: soupName, record: record)

                // Next
                nextBlock()
            }
        }

        // Delete failure handler
        let failBlockDelete: SyncUpTargetErrorBlock = { [weak self] err in
            guard let self = self else { return }
            // Handling remotely deleted records
            if (err as NSError).code == 404 {
                completeBlockDelete([:])
            } else if SFRestRequest.isNetworkError(err) {
                self.fail(sync, failureMessage: "Delete server call failed", error: err)
            } else {
                target.saveRecordToLocalStoreWithLastError(syncManager: self.syncManager, soupName: soupName, record: record)

                // Next
                nextBlock()
            }
        }

        switch action {
        case .create:
            target.createOnServer(syncManager: self.syncManager, record: record, fieldlist: sync.options?.fieldlist ?? [], onComplete: completeBlockCreate, onFail: failBlockCreate)
        case .update:
            target.updateOnServer(syncManager: self.syncManager, record: record, fieldlist: sync.options?.fieldlist ?? [], onComplete: completeBlockUpdate, onFail: failBlockUpdate)
        case .delete:
            // if locally created it can't exist on the server - we don't need to actually do the deleteOnServer call
            if target.isLocallyCreated(record) {
                completeBlockDelete(record)
            } else {
                target.deleteOnServer(syncManager: self.syncManager, record: record, onComplete: completeBlockDelete, onFail: failBlockDelete)
            }
        default:
            // Action is unsupported here.  Move on.
            SFSDKMobileSyncLogger.i(SFSyncUpTask.self, message: "\(#function) unsupported action with value \(action.rawValue).  Moving to the next record.")
            nextBlock()
            return
        }
    }
}
