/*
 Copyright (c) 2015-present, salesforce.com, inc. All rights reserved.

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

private let kSFSoqlSyncTargetQuery = "query"
private let kSFSoqlSyncTargetMaxBatchSize = "maxBatchSize"

@objc(SFSoqlSyncDownTarget)
@objcMembers
open class SFSoqlSyncDownTarget: SFSyncDownTarget {

    open var query: String = ""
    open var maxBatchSize: Int = Int(SFRestSOQLDefaultBatchSize)

    private var nextRecordsUrl: String?

    // MARK: - Initialization

    public override init() {
        super.init()
        self.queryType = .soql
    }

    public required init(dict: NSDictionary) {
        super.init(dict: dict)
        let dictionary = dict as? [String: Any] ?? [:]
        self.queryType = .soql
        self.query = dictionary[kSFSoqlSyncTargetQuery] as? String ?? ""
        if let maxBatchSizeNum = dictionary[kSFSoqlSyncTargetMaxBatchSize] as? NSNumber {
            self.maxBatchSize = maxBatchSizeNum.intValue
        } else {
            self.maxBatchSize = Int(SFRestSOQLDefaultBatchSize)
        }
        modifyQueryIfNeeded()
    }

    // MARK: - Factory methods

    @objc
    open class func newSyncTarget(_ query: String) -> SFSoqlSyncDownTarget {
        return newSyncTarget(query, maxBatchSize: Int(SFRestSOQLDefaultBatchSize))
    }

    @objc
    open class func newSyncTarget(_ query: String, maxBatchSize: Int) -> SFSoqlSyncDownTarget {
        let syncTarget = SFSoqlSyncDownTarget()
        syncTarget.queryType = .soql
        syncTarget.query = query
        syncTarget.maxBatchSize = maxBatchSize
        syncTarget.modifyQueryIfNeeded()
        return syncTarget
    }

    // MARK: - Serialization

    open override func asDict() -> NSMutableDictionary {
        let dict = super.asDict()
        dict[kSFSoqlSyncTargetQuery] = self.query
        dict[kSFSoqlSyncTargetMaxBatchSize] = NSNumber(value: self.maxBatchSize)
        return dict
    }

    // MARK: - Data fetching

    open override func startFetch(_ syncManager: SFMobileSyncSyncManager, maxTimeStamp: Int64, errorBlock: @escaping SFSyncDownTargetFetchErrorBlock, completeBlock: @escaping SFSyncDownTargetFetchCompleteBlock) {
        startFetch(syncManager, queryToRun: getQueryToRun(maxTimeStamp), errorBlock: errorBlock, completeBlock: completeBlock)
    }

    @objc
    open func startFetch(_ syncManager: SFMobileSyncSyncManager, queryToRun: String, errorBlock: @escaping SFSyncDownTargetFetchErrorBlock, completeBlock: @escaping SFSyncDownTargetFetchCompleteBlock) {
        let request = buildRequest(queryToRun)
        SFMobileSyncNetworkUtils.sendRequest(withMobileSyncUserAgent: request, failureBlock: { _, error, _ in
            errorBlock(error)
        }, successBlock: { [weak self] responseJson, _ in
            guard let self = self, let responseDict = responseJson as? [String: Any] else { return }
            self.totalSize = (responseDict[kResponseTotalSize] as? NSNumber)?.uintValue ?? 0
            self.nextRecordsUrl = responseDict[kResponseNextRecordsUrl] as? String
            completeBlock(self.getRecordsFromResponse(responseDict as NSDictionary))
        })
    }

    @objc
    open func buildRequest(_ queryToRun: String) -> RestRequest {
        return RestClient.sharedInstance.requestForQuery(queryToRun, apiVersion: nil, batchSize: maxBatchSize)
    }

    open override func continueFetch(_ syncManager: SFMobileSyncSyncManager, errorBlock: @escaping SFSyncDownTargetFetchErrorBlock, completeBlock: @escaping SFSyncDownTargetFetchCompleteBlock) {
        if let nextUrl = self.nextRecordsUrl {
            let request = RestRequest(method: .GET, path: nextUrl, queryParams: nil)
            SFMobileSyncNetworkUtils.sendRequest(withMobileSyncUserAgent: request, failureBlock: { _, error, _ in
                errorBlock(error)
            }, successBlock: { [weak self] responseJson, _ in
                guard let self = self, let responseDict = responseJson as? [String: Any] else { return }
                self.nextRecordsUrl = responseDict[kResponseNextRecordsUrl] as? String
                completeBlock(self.getRecordsFromResponse(responseDict as NSDictionary))
            })
        } else {
            completeBlock(nil)
        }
    }

    @objc
    open func getRecordsFromResponse(_ responseJson: NSDictionary) -> [Any]? {
        return (responseJson as? [String: Any])?[kResponseRecords] as? [Any]
    }

    open override func getRemoteIds(_ syncManager: SFMobileSyncSyncManager, localIds: [Any], errorBlock: @escaping SFSyncDownTargetFetchErrorBlock, completeBlock: @escaping SFSyncDownTargetFetchCompleteBlock) {
        if localIds.isEmpty {
            completeBlock(nil)
            return
        }
        let soql = getSoqlForRemoteIds()
        var remoteIds = Set<String>()
        let idFieldName = self.idFieldName

        var fetchBlockRecurse: SFSyncDownTargetFetchCompleteBlock?

        let fetchErrorBlock: SFSyncDownTargetFetchErrorBlock = { error in
            fetchBlockRecurse = nil
            errorBlock(error)
        }

        let fetchBlock: SFSyncDownTargetFetchCompleteBlock = { [weak self] records in
            guard let self = self else { return }
            guard let records = records else {
                completeBlock(Array(remoteIds))
                fetchBlockRecurse = nil
                return
            }

            var error: NSError?
            if !syncManager.checkAcceptingSyncs(&error) {
                errorBlock(error)
                return
            }

            for record in records {
                if let recordDict = record as? [String: Any], let id = recordDict[idFieldName] as? String {
                    remoteIds.insert(id)
                }
            }

            self.continueFetch(syncManager, errorBlock: fetchErrorBlock, completeBlock: fetchBlockRecurse ?? { _ in })
        }
        fetchBlockRecurse = fetchBlock
        startFetch(syncManager, queryToRun: soql, errorBlock: errorBlock, completeBlock: fetchBlock)
    }

    open override func isSyncDownSortedByLatestModification() -> Bool {
        return SFSDKSoqlMutator.withSoql(self.query).isOrderingBy(self.modificationDateFieldName)
    }

    // MARK: - Utility methods

    @objc
    open func parseIdsFromResponse(_ records: [Any]) -> Set<String> {
        var remoteIds = Set<String>()
        for record in records {
            if let recordDict = record as? [String: Any], let id = recordDict[self.idFieldName] as? String {
                remoteIds.insert(id)
            }
        }
        return remoteIds
    }

    @objc
    open func getSoqlForRemoteIds() -> String {
        return SFSDKSoqlMutator.withSoql(self.query)
            .replaceSelectFields(self.idFieldName)
            .replaceOrderBy("")
            .asBuilder()
            .build() ?? ""
    }

    @objc
    open func getQueryToRun() -> String {
        return getQueryToRun(0)
    }

    @objc
    open func getQueryToRun(_ maxTimeStamp: Int64) -> String {
        var queryToRun = self.query
        if maxTimeStamp > 0 {
            queryToRun = SFSoqlSyncDownTarget.addFilterForReSync(self.query, modDateFieldName: self.modificationDateFieldName, maxTimeStamp: maxTimeStamp)
        }
        return queryToRun
    }

    @objc
    open class func addFilterForReSync(_ query: String, modDateFieldName: String, maxTimeStamp: Int64) -> String {
        var queryToRun = query
        if maxTimeStamp > 0 {
            let maxTimeStampStr = SFMobileSyncObjectUtils.getIsoString(fromMillis: maxTimeStamp)
            let extraPredicate = "\(modDateFieldName) > \(maxTimeStampStr)"
            queryToRun = SFSDKSoqlMutator.withSoql(query)
                .addWherePredicates(extraPredicate)
                .asBuilder()
                .build() ?? query
        }
        return queryToRun
    }

    @objc
    open class func appendToFirstOccurence(_ str: String, pattern: String, stringToAppend: String) -> String {
        guard let regexp = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return str }
        let range = regexp.rangeOfFirstMatch(in: str, options: [], range: NSRange(location: 0, length: str.count))
        guard range.location != NSNotFound else { return str }
        let firstMatch = (str as NSString).substring(with: range)
        return (str as NSString).replacingCharacters(in: range, with: firstMatch + stringToAppend)
    }

    // MARK: - Private

    private func modifyQueryIfNeeded() {
        guard !self.query.isEmpty else { return }
        let mutator = SFSDKSoqlMutator.withSoql(self.query)
        var mutated = false

        if !mutator.isSelectingField(self.modificationDateFieldName) {
            mutated = true
            mutator.addSelectFields(self.modificationDateFieldName)
        }
        if !mutator.isSelectingField(self.idFieldName) {
            mutated = true
            mutator.addSelectFields(self.idFieldName)
        }
        if !mutator.hasOrderBy() {
            mutated = true
            mutator.replaceOrderBy(self.modificationDateFieldName)
        }
        if mutated {
            self.query = mutator.asBuilder().build() ?? self.query
        }
    }
}
