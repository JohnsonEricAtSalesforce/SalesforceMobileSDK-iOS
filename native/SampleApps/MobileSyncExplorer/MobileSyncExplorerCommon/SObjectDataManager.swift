/*
 Copyright (c) 2014-present, salesforce.com, inc. All rights reserved.

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
import SmartStore
import MobileSync

@objcMembers
class SObjectDataManager: NSObject {

    private static let kMaxQueryPageSize: UInt = 1000
    private static let kSearchFilterQueueName = "com.salesforce.mobileSyncExplorer.searchFilterQueue"
    private static let kSyncDownName = "syncDownContacts"
    private static let kSyncUpName = "syncUpContacts"

    private let syncMgr: SFMobileSyncSyncManager
    private let dataSpec: SObjectDataSpec
    private let searchFilterQueue: DispatchQueue
    private var fullDataRowList: [SObjectData]?

    var store: SFSmartStore {
        return SFSmartStore.sharedStore(withName: kDefaultSmartStoreName) as! SFSmartStore
    }

    var dataRows: [SObjectData]?

    init(dataSpec: SObjectDataSpec) {
        self.syncMgr = SFMobileSyncSyncManager.sharedInstance(for: SFUserAccountManager.sharedInstance().currentUser!)!
        self.dataSpec = dataSpec
        self.searchFilterQueue = DispatchQueue(label: SObjectDataManager.kSearchFilterQueueName)
        super.init()

        // Setup store and syncs if needed
        MobileSyncSDKManager.shared.setupUserStore(fromDefaultConfig: ())
        MobileSyncSDKManager.shared.setupUserSyncs(fromDefaultConfig: ())
    }

    func refreshRemoteData(_ completionBlock: @escaping () -> Void) {
        weak var weakSelf = self
        syncMgr.reSync(byName: SObjectDataManager.kSyncDownName, updateBlock: { sync in
            guard let strongSelf = weakSelf else { return }
            if let sync = sync, sync.isDone() || sync.hasFailed() {
                strongSelf.refreshLocalData(completionBlock)
            }
        }, error: nil)
    }

    func updateRemoteData(_ completionBlock: @escaping (SFSyncState) -> Void) {
        syncMgr.reSync(byName: SObjectDataManager.kSyncUpName, updateBlock: { sync in
            if let sync = sync, sync.isDone() || sync.hasFailed() {
                completionBlock(sync)
            }
        }, error: nil)
    }

    func filterOnSearchTerm(_ searchTerm: String?, completion completionBlock: (() -> Void)?) {
        searchFilterQueue.async { [weak self] in
            guard let self = self else { return }
            self.dataRows = self.fullDataRowList
            guard self.dataRows != nil else { return }

            if let searchTerm = searchTerm, !searchTerm.isEmpty {
                var matchingDataRows: [SObjectData] = []
                if let fullList = self.fullDataRowList {
                    for data in fullList {
                        let dataSpec = type(of: data).dataSpec()
                        for fieldSpec in dataSpec.objectFieldSpecs {
                            if fieldSpec.isSearchable {
                                if let fieldValue = data.fieldValueForFieldName(fieldSpec.fieldName) as? String,
                                   fieldValue.range(of: searchTerm, options: [.caseInsensitive, .diacriticInsensitive]) != nil {
                                    matchingDataRows.append(data)
                                    break
                                }
                            }
                        }
                    }
                }
                self.dataRows = matchingDataRows
            }

            if let completionBlock = completionBlock {
                DispatchQueue.main.async(execute: completionBlock)
            }
        }
    }

    // MARK: - Local data methods

    func refreshLocalData(_ completionBlock: (() -> Void)?) {
        let sobjectsQuerySpec = SFQuerySpec.newAllQuerySpec(dataSpec.soupName, withOrderPath: dataSpec.orderByFieldName, with: .ascending, withPageSize: SObjectDataManager.kMaxQueryPageSize)
        var queryError: NSError?
        let queryResults = store.query(with: sobjectsQuerySpec, pageIndex: 0, error: &queryError)
        SFSDKMobileSyncLogger.log(type(of: self), level: .debug, message: "Got local query results. Populating data rows.")

        if let error = queryError {
            SFSDKMobileSyncLogger.log(type(of: self), level: .error, message: "Error retrieving '\(dataSpec.objectType)' data from SmartStore: \(error.localizedDescription)")
            return
        }

        fullDataRowList = populateDataRows(queryResults as? [[String: Any]] ?? [])
        SFSDKMobileSyncLogger.log(type(of: self), level: .debug, message: "Finished generating data rows. Number of rows: \(fullDataRowList?.count ?? 0). Refreshing view.")
        dataRows = fullDataRowList
        completionBlock?()
    }

    func createLocalData(_ newData: SObjectData) {
        newData.updateSoupForFieldName(kSyncTargetLocal, fieldValue: true)
        newData.updateSoupForFieldName(kSyncTargetLocallyCreated, fieldValue: true)
        store.upsertEntries([newData.soupDict], toSoup: type(of: newData).dataSpec().soupName)
    }

    func updateLocalData(_ updatedData: SObjectData) {
        updatedData.updateSoupForFieldName(kSyncTargetLocal, fieldValue: true)
        updatedData.updateSoupForFieldName(kSyncTargetLocallyUpdated, fieldValue: true)
        store.upsertEntries([updatedData.soupDict], toSoup: type(of: updatedData).dataSpec().soupName)
    }

    func deleteLocalData(_ dataToDelete: SObjectData) {
        dataToDelete.updateSoupForFieldName(kSyncTargetLocal, fieldValue: true)
        dataToDelete.updateSoupForFieldName(kSyncTargetLocallyDeleted, fieldValue: true)
        store.upsertEntries([dataToDelete.soupDict], toSoup: type(of: dataToDelete).dataSpec().soupName)
    }

    func undeleteLocalData(_ dataToUnDelete: SObjectData) {
        dataToUnDelete.updateSoupForFieldName(kSyncTargetLocallyDeleted, fieldValue: false)
        let locallyCreatedOrUpdated = dataLocallyCreated(dataToUnDelete) || dataLocallyUpdated(dataToUnDelete)
        dataToUnDelete.updateSoupForFieldName(kSyncTargetLocal, fieldValue: locallyCreatedOrUpdated)
        store.upsertEntries([dataToUnDelete.soupDict], toSoup: type(of: dataToUnDelete).dataSpec().soupName, withExternalIdPath: kSObjectIdField, error: nil)
    }

    func dataHasLocalChanges(_ data: SObjectData) -> Bool {
        return (data.fieldValueForFieldName(kSyncTargetLocal) as? Bool) ?? false
    }

    func dataLocallyCreated(_ data: SObjectData) -> Bool {
        return (data.fieldValueForFieldName(kSyncTargetLocallyCreated) as? Bool) ?? false
    }

    func dataLocallyUpdated(_ data: SObjectData) -> Bool {
        return (data.fieldValueForFieldName(kSyncTargetLocallyUpdated) as? Bool) ?? false
    }

    func dataLocallyDeleted(_ data: SObjectData) -> Bool {
        return (data.fieldValueForFieldName(kSyncTargetLocallyDeleted) as? Bool) ?? false
    }

    func lastModifiedRecords(_ limit: Int, completion completionBlock: @escaping () -> Void) {
        let sobjectsQuerySpec = SFQuerySpec.newAllQuerySpec(dataSpec.soupName, withOrderPath: "_soupLastModifiedDate", with: .descending, withPageSize: UInt(limit))
        var queryError: NSError?
        let queryResults = store.query(with: sobjectsQuerySpec, pageIndex: 0, error: &queryError)
        SFSDKMobileSyncLogger.log(type(of: self), level: .debug, message: "Got local query results. Populating data rows.")

        if let error = queryError {
            SFSDKMobileSyncLogger.log(type(of: self), level: .error, message: "Error retrieving '\(dataSpec.objectType)' data from SmartStore: \(error.localizedDescription)")
            return
        }

        fullDataRowList = populateDataRows(queryResults as? [[String: Any]] ?? [])
        SFSDKMobileSyncLogger.log(type(of: self), level: .debug, message: "Finished generating data rows. Number of rows: \(fullDataRowList?.count ?? 0). Refreshing view.")
        dataRows = fullDataRowList
        completionBlock()
    }

    // MARK: - Private methods

    private func populateDataRows(_ queryResults: [[String: Any]]) -> [SObjectData] {
        return queryResults.map { type(of: dataSpec).createSObjectData($0) }
    }
}
