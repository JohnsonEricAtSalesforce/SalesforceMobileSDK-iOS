/*
 Copyright (c) 2016-present, salesforce.com, inc. All rights reserved.

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

fileprivate let kSFSyncTargetRefreshSoupName = "soupName"
fileprivate let kSFSyncTargetRefreshObjectType = "sobjectType"
fileprivate let kSFSyncTargetRefreshFieldlist = "fieldlist"
fileprivate let kSFSyncTargetRefreshCountIdsPerSoql = "coundIdsPerSoql"
fileprivate let kSFSyncTargetRefreshDefaultCountIdsPerSoql: UInt = 500

@objc(SFRefreshSyncDownTarget)
@objcMembers
public class RefreshSyncDownTarget: SyncDownTarget {

    public private(set) var soupName: String
    public private(set) var objectType: String
    public private(set) var fieldlist: [String]
    public private(set) var countIdsPerSoql: UInt

    // NB: For each sync run - a fresh sync down target is created (by deserializing it from smartstore)
    // The following members are specific to a run
    // page will change during a run as we call start/continueFetch
    private var isResync: Bool = false
    private var page: UInt = 0

    public required init(dict: [String: Any]?) {
        let dict = dict ?? [:]
        self.soupName = dict[kSFSyncTargetRefreshSoupName] as? String ?? ""
        self.objectType = dict[kSFSyncTargetRefreshObjectType] as? String ?? ""
        self.fieldlist = dict[kSFSyncTargetRefreshFieldlist] as? [String] ?? []
        let idsPerSoqlInDict = dict[kSFSyncTargetRefreshCountIdsPerSoql] as? NSNumber
        self.countIdsPerSoql = idsPerSoqlInDict?.uintValue ?? kSFSyncTargetRefreshDefaultCountIdsPerSoql
        super.init(dict: dict)
        self.queryType = .refresh
    }

    public override init() {
        self.soupName = ""
        self.objectType = ""
        self.fieldlist = []
        self.countIdsPerSoql = kSFSyncTargetRefreshDefaultCountIdsPerSoql
        super.init()
        self.queryType = .refresh
    }

    // MARK: - Factory methods

    @objc(newSyncTarget:objectType:fieldlist:)
    public static func newSyncTarget(
        _ soupName: String,
        objectType: String,
        fieldlist: [String]
    ) -> RefreshSyncDownTarget {
        let syncTarget = RefreshSyncDownTarget()
        syncTarget.queryType = .refresh
        syncTarget.soupName = soupName
        syncTarget.objectType = objectType
        syncTarget.fieldlist = fieldlist
        syncTarget.countIdsPerSoql = kSFSyncTargetRefreshDefaultCountIdsPerSoql
        return syncTarget
    }

    // MARK: - To dictionary

    public override func asDict() -> [String: Any] {
        var dict = super.asDict()
        dict[kSFSyncTargetRefreshSoupName] = soupName
        dict[kSFSyncTargetRefreshObjectType] = objectType
        dict[kSFSyncTargetRefreshFieldlist] = fieldlist
        dict[kSFSyncTargetRefreshCountIdsPerSoql] = NSNumber(value: countIdsPerSoql)
        return dict
    }

    // MARK: - Data fetching

    public override func startFetch(
        syncManager: SFMobileSyncSyncManager,
        maxTimeStamp: Int64,
        onFail errorBlock: @escaping SyncDownErrorBlock,
        onComplete completeBlock: SyncDownCompletionBlock?
    ) {
        guard let completeBlock = completeBlock else { return }
        // During reSync, we can't make use of the maxTimeStamp that was captured during last refresh
        // since we expect records to have been fetched from the server and written to the soup directly outside a sync down operation
        // Instead during a reSync, we compute maxTimeStamp from the records in the soup
        isResync = maxTimeStamp > 0
        getIdsFromSmartStoreAndFetchFromServer(
            syncManager,
            onFail: errorBlock,
            onComplete: completeBlock
        )
    }

    public override func continueFetch(
        syncManager: SFMobileSyncSyncManager,
        onFail errorBlock: @escaping SyncDownErrorBlock,
        onComplete completeBlock: SyncDownCompletionBlock?
    ) {
        guard let completeBlock = completeBlock else { return }
        if page > 0 {
            getIdsFromSmartStoreAndFetchFromServer(
                syncManager,
                onFail: errorBlock,
                onComplete: completeBlock
            )
        } else {
            completeBlock(nil)
        }
    }

    public override func getRemoteIds(
        syncManager: SFMobileSyncSyncManager,
        localIds: [Any],
        errorBlock: @escaping SyncDownErrorBlock,
        completeBlock: @escaping SyncDownCompletionBlock
    ) {
        guard let localIds = localIds as? [String], !localIds.isEmpty else {
            completeBlock(nil)
            return
        }

        var remoteIds: [String] = []
        let sliceSize = countIdsPerSoql
        let countSlices = UInt(ceil(Float(localIds.count) / Float(sliceSize)))
        var slice: UInt = 0
        let idFieldName = self.idFieldName
        var fetchBlockRecurse: SyncDownCompletionBlock?

        let fetchErrorBlock: SyncDownErrorBlock = { error in
            fetchBlockRecurse = nil
            errorBlock(error)
        }

        let fetchBlock: SyncDownCompletionBlock = { [weak self] records in
            guard let self = self else { return }

            var error: NSError?
            if !syncManager.checkAcceptingSyncs(&error) {
                if let error = error {
                    errorBlock(error)
                }
                return
            }

            if let records = records as? [[String: Any]] {
                for record in records {
                    if let id = record[idFieldName] as? String {
                        remoteIds.append(id)
                    }
                }
            }

            if slice < countSlices {
                let startIndex = Int(slice * sliceSize)
                let endIndex = min(localIds.count, Int((slice + 1) * sliceSize))
                let idsToFetch = Array(localIds[startIndex..<endIndex])
                slice += 1
                self.fetchFromServer(
                    idsToFetch,
                    fieldlist: [idFieldName],
                    maxTimeStamp: 0,
                    onFail: fetchErrorBlock,
                    onComplete: fetchBlockRecurse!
                )
            } else {
                fetchBlockRecurse = nil
                completeBlock(remoteIds)
            }
        }

        fetchBlockRecurse = fetchBlock
        // Let's get going
        fetchBlock([])
    }

    private func getIdsFromSmartStoreAndFetchFromServer(
        _ syncManager: SFMobileSyncSyncManager,
        onFail errorBlock: @escaping SyncDownErrorBlock,
        onComplete completeBlock: @escaping SyncDownCompletionBlock
    ) {
        // Read from smartstore
        let querySpec: QuerySpec
        var idsInSmartStore: [String] = []
        let maxTimeStamp: Int64

        if isResync {
            // Getting full records from SmartStore to compute maxTimeStamp
            // So doing more db work in the hope of doing less server work
            querySpec = QuerySpec.buildAllQuerySpec(
                soupName: soupName,
                orderPath: idFieldName,
                order: .ascending,
                pageSize: countIdsPerSoql
            )

            guard let recordsFromSmartStore = try? syncManager.store.query(
                using: querySpec,
                startingFromPageIndex: page
            ) as? [[String: Any]] else {
                errorBlock(NSError(domain: "SmartStore", code: -1, userInfo: [NSLocalizedDescriptionKey: "Query failed"]))
                return
            }

            // Compute max time stamp
            maxTimeStamp = getLatestModificationTimeStamp(recordsFromSmartStore ?? [])

            // Get ids
            for record in recordsFromSmartStore ?? [] {
                if let id = record[idFieldName] as? String {
                    idsInSmartStore.append(id)
                }
            }
        } else {
            let smartQuery = "SELECT {\(soupName):\(idFieldName)} FROM {\(soupName)} ORDER BY {\(soupName):\(idFieldName)} ASC"
            querySpec = QuerySpec.buildSmartQuerySpec(smartSql: smartQuery, pageSize: countIdsPerSoql)!

            guard let result = try? syncManager.store.query(
                using: querySpec,
                startingFromPageIndex: page
            ) as? [[Any]] else {
                errorBlock(NSError(domain: "SmartStore", code: -1, userInfo: [NSLocalizedDescriptionKey: "Query failed"]))
                return
            }

            // Not a resync
            maxTimeStamp = 0

            // Get ids
            for row in result ?? [] {
                if let id = row.first as? String {
                    idsInSmartStore.append(id)
                }
            }
        }

        // If fetch is starting, figuring out totalSize
        // NB: it might not be the correct value during resync
        //     since not all records will have changed
        if page == 0 {
            guard let count = try? syncManager.store.count(using: querySpec) else {
                errorBlock(NSError(domain: "SmartStore", code: -1, userInfo: [NSLocalizedDescriptionKey: "Count query failed"]))
                return
            }
            totalSize = count.uintValue
        }

        // Get records from server that have changed after maxTimeStamp
        if !idsInSmartStore.isEmpty {
            fetchFromServer(
                idsInSmartStore,
                fieldlist: fieldlist,
                maxTimeStamp: maxTimeStamp,
                onFail: errorBlock,
                onComplete: { [weak self] records in
                    guard let self = self else { return }
                    // Increment page if there is more to fetch
                    let done = self.countIdsPerSoql * (self.page + 1) >= self.totalSize
                    self.page = done ? 0 : self.page + 1
                    completeBlock(records)
                }
            )
        } else {
            completeBlock(nil)
        }
    }

    private func fetchFromServer(
        _ ids: [String],
        fieldlist: [String],
        maxTimeStamp: Int64,
        onFail errorBlock: @escaping SyncDownErrorBlock,
        onComplete completeBlock: @escaping SyncDownCompletionBlock
    ) {
        let maxTimeStampStr = FormatUtils.getIsoStringFromMillis(maxTimeStamp) ?? ""
        let andClause = maxTimeStamp > 0
            ? " AND \(modificationDateFieldName) > \(maxTimeStampStr)"
            : ""
        let whereClause = "\(idFieldName) IN ('\(ids.joined(separator: "','"))')\(andClause)"
        let soql = SFSDKSoqlBuilder.withFields(array: fieldlist)
            .from(objectType)
            .whereClause(whereClause)
            .build()

        let request = RestClient.shared.requestForQuery(soql ?? "", apiVersion: nil)
        SFMobileSyncNetworkUtils.sendRequest(
            withMobileSyncUserAgent: request,
            failureBlock: { response, error, rawResponse in
                if let error = error {
                    errorBlock(error)
                }
            },
            successBlock: { response, rawResponse in
                if let d = response as? [String: Any],
                   let records = d[kResponseRecords] as? [Any] {
                    completeBlock(records)
                } else {
                    completeBlock(nil)
                }
            }
        )
    }
}
