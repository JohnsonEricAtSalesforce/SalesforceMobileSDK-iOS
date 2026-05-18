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

@objc(SFSyncUpTask)
@objcMembers
open class SFSyncUpTask: SFSyncTask {

    @objc
    public override init(_ syncManager: SFMobileSyncSyncManager, sync: SFSyncState, updateBlock: SFSyncSyncManagerUpdateBlock?) {
        super.init(syncManager, sync: sync, updateBlock: updateBlock)
    }

    open override func runSync(_ sync: SFSyncState) {
        guard let target = sync.target as? SFSyncUpTarget else { return }
        let dirtyRecordIds = target.getIdsOfRecordsToSyncUp(self.syncManager, soupName: sync.soupName)
        syncUp(sync, recordIds: dirtyRecordIds)
    }

    private func syncUp(_ sync: SFSyncState, recordIds: [Any]) {
        syncUpOneEntry(sync, recordIds: recordIds, index: 0)
    }

    private func syncUpOneEntry(_ sync: SFSyncState, recordIds: [Any], index: UInt) {
        guard let target = sync.target as? SFSyncUpTarget else { return }
        let soupName = sync.soupName
        let mergeMode = sync.mergeMode
        sync.totalSize = Int(recordIds.count)
        updateSync(sync, countSynched: index)

        if sync.isDone() || shouldStop() {
            return
        }

        guard let storeId = recordIds[Int(index)] as? NSNumber else { return }
        let record = NSMutableDictionary(dictionary: target.getFromLocalStore(self.syncManager, soupName: soupName, storeId: storeId))
        SFSDKMobileSyncLogger.d(type(of: self), message: "syncUpOneRecord:\(record)")

        let locallyCreated = target.isLocallyCreated(record)
        let locallyUpdated = target.isLocallyUpdated(record)
        let locallyDeleted = target.isLocallyDeleted(record)

        var action: SFSyncUpTargetAction = .none
        if locallyDeleted { action = .delete }
        else if locallyCreated { action = .create }
        else if locallyUpdated { action = .update }

        if mergeMode == .leaveIfChanged && !locallyCreated {
            target.isNewerThanServer(self.syncManager, record: record) { [weak self] isNewerThanServer in
                guard let self = self else { return }
                if isNewerThanServer {
                    self.resumeSyncUpOneEntry(sync, recordIds: recordIds, index: index, record: record, action: action)
                } else {
                    SFSDKMobileSyncLogger.d(type(of: self), message: "syncUpOneRecord: Record not synced since client does not have the latest from server:\(record)")
                    self.syncUpOneEntry(sync, recordIds: recordIds, index: index + 1)
                }
            }
        } else {
            resumeSyncUpOneEntry(sync, recordIds: recordIds, index: index, record: record, action: action)
        }
    }

    private func resumeSyncUpOneEntry(_ sync: SFSyncState, recordIds: [Any], index: UInt, record: NSMutableDictionary, action: SFSyncUpTargetAction) {
        guard let target = sync.target as? SFSyncUpTarget else { return }
        let mergeMode = sync.mergeMode
        let soupName = sync.soupName

        let nextBlock = { [weak self] in
            self?.syncUpOneEntry(sync, recordIds: recordIds, index: index + 1)
        }

        if action == .none {
            nextBlock()
            return
        }

        // Delete handler
        let completeBlockDelete: SFSyncUpTargetCompleteBlock = { [weak self] _ in
            guard let self = self else { return }
            target.deleteFromLocalStore(syncManager: self.syncManager, soupName: soupName, record: record)
            nextBlock()
        }

        // Update handler
        let completeBlockUpdate: SFSyncUpTargetCompleteBlock = { [weak self] _ in
            guard let self = self else { return }
            target.cleanAndSaveInLocalStore(syncManager: self.syncManager, soupName: soupName, record: record)
            nextBlock()
        }

        // Create handler
        let fieldName = target.idFieldName
        let completeBlockCreate: SFSyncUpTargetCompleteBlock = { d in
            if let d = d {
                record[fieldName] = d[kCreatedId]
            }
            completeBlockUpdate(d)
        }

        // Create failure handler
        let failBlockCreate: SFSyncUpTargetErrorBlock = { [weak self] err in
            guard let self = self else { return }
            if RestRequest.isNetworkError(err) {
                self.failSync(sync, failureMessage: "Create server call failed", error: err)
            } else {
                target.saveRecordToLocalStoreWithLastError(syncManager: self.syncManager, soupName: soupName, record: record)
                nextBlock()
            }
        }

        // Update failure handler
        let failBlockUpdate: SFSyncUpTargetErrorBlock = { [weak self] err in
            guard let self = self else { return }
            if (err as NSError).code == 404 {
                if mergeMode == .overwrite {
                    target.createOnServer(syncManager: self.syncManager, record: record, fieldlist: sync.options?.fieldlist ?? [], completionBlock: completeBlockCreate, failBlock: failBlockCreate)
                } else {
                    nextBlock()
                }
            } else if RestRequest.isNetworkError(err) {
                self.failSync(sync, failureMessage: "Update server call failed", error: err)
            } else {
                target.saveRecordToLocalStoreWithLastError(syncManager: self.syncManager, soupName: soupName, record: record)
                nextBlock()
            }
        }

        // Delete failure handler
        let failBlockDelete: SFSyncUpTargetErrorBlock = { [weak self] err in
            guard let self = self else { return }
            if (err as NSError).code == 404 {
                completeBlockDelete(nil)
            } else if RestRequest.isNetworkError(err) {
                self.failSync(sync, failureMessage: "Delete server call failed", error: err)
            } else {
                target.saveRecordToLocalStoreWithLastError(syncManager: self.syncManager, soupName: soupName, record: record)
                nextBlock()
            }
        }

        switch action {
        case .create:
            target.createOnServer(syncManager: self.syncManager, record: record, fieldlist: sync.options?.fieldlist ?? [], completionBlock: completeBlockCreate, failBlock: failBlockCreate)
        case .update:
            target.updateOnServer(syncManager: self.syncManager, record: record, fieldlist: sync.options?.fieldlist ?? [], completionBlock: completeBlockUpdate, failBlock: failBlockUpdate)
        case .delete:
            if target.isLocallyCreated(record) {
                completeBlockDelete(record as? [String: Any] as NSDictionary?)
            } else {
                target.deleteOnServer(syncManager: self.syncManager, record: record, completionBlock: completeBlockDelete, failBlock: failBlockDelete)
            }
        default:
            SFSDKMobileSyncLogger.i(type(of: self), message: "\(#function) unsupported action with value \(action.rawValue). Moving to the next record.")
            nextBlock()
        }
    }
}
