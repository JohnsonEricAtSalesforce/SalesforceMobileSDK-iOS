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

private let kSFSyncTargetRefreshSoupName = "soupName"
private let kSFSyncTargetRefreshObjectType = "sobjectType"
private let kSFSyncTargetRefreshFieldlist = "fieldlist"
private let kSFSyncTargetRefreshCountIdsPerSoql = "coundIdsPerSoql"
private let kSFSyncTargetRefreshDefaultCountIdsPerSoql: UInt = 500

@objc(SFRefreshSyncDownTarget)
@objcMembers
open class SFRefreshSyncDownTarget: SFSyncDownTarget {

    open private(set) var soupName: String = ""
    open private(set) var objectType: String = ""
    open private(set) var fieldlist: [String] = []
    // internal (not private) so `@testable import MobileSync` tests can force multiple SOQL round trips,
    // matching the ObjC tests that re-declared it via a class-extension. Not exposed in the public header,
    // so this is not a public-API change.
    internal var countIdsPerSoql: UInt = kSFSyncTargetRefreshDefaultCountIdsPerSoql
    private var isResync: Bool = false
    private var page: UInt = 0

    // MARK: - Initialization

    public override init() {
        super.init()
        self.queryType = .refresh
    }

    public required init(dict: NSDictionary) {
        super.init(dict: dict)
        let dictionary = dict as? [String: Any] ?? [:]
        self.queryType = .refresh
        self.soupName = dictionary[kSFSyncTargetRefreshSoupName] as? String ?? ""
        self.objectType = dictionary[kSFSyncTargetRefreshObjectType] as? String ?? ""
        self.fieldlist = dictionary[kSFSyncTargetRefreshFieldlist] as? [String] ?? []
        if let idsPerSoql = dictionary[kSFSyncTargetRefreshCountIdsPerSoql] as? NSNumber {
            self.countIdsPerSoql = idsPerSoql.uintValue
        } else {
            self.countIdsPerSoql = kSFSyncTargetRefreshDefaultCountIdsPerSoql
        }
    }

    // MARK: - Factory

    @objc
    open class func newSyncTarget(_ soupName: String, objectType: String, fieldlist: [Any]) -> SFRefreshSyncDownTarget {
        let syncTarget = SFRefreshSyncDownTarget()
        syncTarget.queryType = .refresh
        syncTarget.soupName = soupName
        syncTarget.objectType = objectType
        syncTarget.fieldlist = fieldlist as? [String] ?? []
        syncTarget.countIdsPerSoql = kSFSyncTargetRefreshDefaultCountIdsPerSoql
        return syncTarget
    }

    // MARK: - Serialization

    open override func asDict() -> NSMutableDictionary {
        let dict = super.asDict()
        dict[kSFSyncTargetRefreshSoupName] = self.soupName
        dict[kSFSyncTargetRefreshObjectType] = self.objectType
        dict[kSFSyncTargetRefreshFieldlist] = self.fieldlist
        dict[kSFSyncTargetRefreshCountIdsPerSoql] = NSNumber(value: self.countIdsPerSoql)
        return dict
    }

    // MARK: - Data fetching

    open override func startFetch(_ syncManager: SFMobileSyncSyncManager, maxTimeStamp: Int64, errorBlock: @escaping SFSyncDownTargetFetchErrorBlock, completeBlock: @escaping SFSyncDownTargetFetchCompleteBlock) {
        self.isResync = maxTimeStamp > 0
        getIdsFromSmartStoreAndFetchFromServer(syncManager, errorBlock: errorBlock, completeBlock: completeBlock)
    }

    open override func continueFetch(_ syncManager: SFMobileSyncSyncManager, errorBlock: @escaping SFSyncDownTargetFetchErrorBlock, completeBlock: @escaping SFSyncDownTargetFetchCompleteBlock) {
        if self.page > 0 {
            getIdsFromSmartStoreAndFetchFromServer(syncManager, errorBlock: errorBlock, completeBlock: completeBlock)
        } else {
            completeBlock(nil)
        }
    }

    open override func getRemoteIds(_ syncManager: SFMobileSyncSyncManager, localIds: [Any], errorBlock: @escaping SFSyncDownTargetFetchErrorBlock, completeBlock: @escaping SFSyncDownTargetFetchCompleteBlock) {
        if localIds.isEmpty {
            completeBlock(nil)
            return
        }

        var remoteIds = [Any]()
        let sliceSize = Int(self.countIdsPerSoql)
        let countSlices = Int(ceil(Float(localIds.count) / Float(sliceSize)))
        var slice = 0
        let idFieldName = self.idFieldName

        var fetchBlockRecurse: SFSyncDownTargetFetchCompleteBlock?

        let fetchErrorBlock: SFSyncDownTargetFetchErrorBlock = { error in
            fetchBlockRecurse = nil
            errorBlock(error)
        }

        let fetchBlock: SFSyncDownTargetFetchCompleteBlock = { [weak self] records in
            guard let self = self else { return }
            var error: NSError?
            if !syncManager.checkAcceptingSyncs(&error) {
                errorBlock(error)
                return
            }

            for record in records ?? [] {
                if let recordDict = record as? [String: Any], let id = recordDict[idFieldName] {
                    remoteIds.append(id)
                }
            }

            if slice < countSlices {
                let startIndex = slice * sliceSize
                let endIndex = min(localIds.count, (slice + 1) * sliceSize)
                let idsToFetch = Array(localIds[startIndex..<endIndex])
                slice += 1
                self.fetchFromServer(idsToFetch, fieldlist: [idFieldName], maxTimeStamp: 0, errorBlock: fetchErrorBlock, completeBlock: fetchBlockRecurse ?? { _ in })
            } else {
                fetchBlockRecurse = nil
                completeBlock(remoteIds)
            }
        }
        fetchBlockRecurse = fetchBlock
        fetchBlock([])
    }

    // MARK: - Private

    private func getIdsFromSmartStoreAndFetchFromServer(_ syncManager: SFMobileSyncSyncManager, errorBlock: @escaping SFSyncDownTargetFetchErrorBlock, completeBlock: @escaping SFSyncDownTargetFetchCompleteBlock) {

        var idsInSmartStore = [String]()
        var maxTimeStamp: Int64

        if self.isResync {
            let querySpec = QuerySpec.buildAllQuerySpec(soupName: self.soupName, orderPath: self.idFieldName, order: .ascending, pageSize: self.countIdsPerSoql)
            do {
                let recordsFromSmartStore = try syncManager.store.query(using: querySpec, startingFromPageIndex: self.page)
                let records = recordsFromSmartStore as? [[String: Any]] ?? []
                maxTimeStamp = getLatestModificationTimeStamp(records)
                for record in records {
                    if let id = record[self.idFieldName] as? String {
                        idsInSmartStore.append(id)
                    }
                }
            } catch {
                errorBlock(error)
                return
            }
        } else {
            let smartSql = "SELECT {\(self.soupName):\(self.idFieldName)} FROM {\(self.soupName)} ORDER BY {\(self.soupName):\(self.idFieldName)} ASC"
            guard let querySpec = QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: self.countIdsPerSoql) else {
                completeBlock(nil)
                return
            }
            do {
                let result = try syncManager.store.query(using: querySpec, startingFromPageIndex: self.page)
                let rows = result as? [[Any]] ?? []
                maxTimeStamp = 0
                for row in rows {
                    if let id = row.first as? String {
                        idsInSmartStore.append(id)
                    }
                }
            } catch {
                errorBlock(error)
                return
            }
        }

        // Figuring out totalSize on first page
        if self.page == 0 {
            do {
                let querySpec: QuerySpec
                if self.isResync {
                    querySpec = QuerySpec.buildAllQuerySpec(soupName: self.soupName, orderPath: self.idFieldName, order: .ascending, pageSize: self.countIdsPerSoql)
                } else {
                    let smartSql = "SELECT {\(self.soupName):\(self.idFieldName)} FROM {\(self.soupName)} ORDER BY {\(self.soupName):\(self.idFieldName)} ASC"
                    guard let qs = QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: self.countIdsPerSoql) else {
                        completeBlock(nil)
                        return
                    }
                    querySpec = qs
                }
                let count = try syncManager.store.count(using: querySpec)
                self.totalSize = count.uintValue
            } catch {
                errorBlock(error)
                return
            }
        }

        if !idsInSmartStore.isEmpty {
            fetchFromServer(idsInSmartStore, fieldlist: self.fieldlist, maxTimeStamp: maxTimeStamp, errorBlock: errorBlock) { [weak self] records in
                guard let self = self else { return }
                let done = self.countIdsPerSoql * (self.page + 1) >= self.totalSize
                self.page = done ? 0 : self.page + 1
                completeBlock(records)
            }
        } else {
            completeBlock(nil)
        }
    }

    private func fetchFromServer(_ ids: [Any], fieldlist: [String], maxTimeStamp: Int64, errorBlock: @escaping SFSyncDownTargetFetchErrorBlock, completeBlock: @escaping SFSyncDownTargetFetchCompleteBlock) {
        let idsStrings = ids.map { "\($0)" }
        // getIsoString returns String? (nil only for negative millis); guarded by maxTimeStamp > 0 here, so
        // unwrap with "" — interpolating the Optional directly injects the literal `Optional("…")` into the
        // SOQL and the server rejects it as MALFORMED_QUERY. The ObjC original used a non-nil NSString.
        let maxTimeStampStr = SFMobileSyncObjectUtils.getIsoString(fromMillis: maxTimeStamp) ?? ""
        let andClause = maxTimeStamp > 0 ? " AND \(self.modificationDateFieldName) > \(maxTimeStampStr)" : ""
        let whereClause = "\(self.idFieldName) IN ('\(idsStrings.joined(separator: "','"))')\(andClause)"
        let soql = SFSDKSoqlBuilder.withFieldsArray(fieldlist)
            .from(self.objectType)
            .whereClause(whereClause)
            .build() ?? ""
        let request = RestClient.sharedInstance.requestForQuery(soql, apiVersion: nil)
        SFMobileSyncNetworkUtils.sendRequest(withMobileSyncUserAgent: request, failureBlock: { _, error, _ in
            errorBlock(error)
        }, successBlock: { responseJson, _ in
            let d = responseJson as? [String: Any] ?? [:]
            completeBlock(d[kResponseRecords] as? [Any])
        })
    }
}
