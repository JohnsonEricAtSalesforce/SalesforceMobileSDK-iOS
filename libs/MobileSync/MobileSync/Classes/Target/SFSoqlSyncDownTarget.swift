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

let kSFSoqlSyncTargetQuery = "query"
let kSFSoqlSyncTargetMaxBatchSize = "maxBatchSize"

@objc(SFSoqlSyncDownTarget)
open class SoqlSyncDownTarget: SyncDownTarget {

    @objc public var query: String = ""

    @objc public var maxBatchSize: Int = SFRestSOQLDefaultBatchSize

    var nextRecordsUrl: String?

    // MARK: - Initialization

    public required init(dict: [String: Any]?) {
        super.init(dict: dict)
        self.queryType = .soql
        let dict = dict ?? [:]
        self.query = dict[kSFSoqlSyncTargetQuery] as? String ?? ""
        if let maxBatchSize = dict[kSFSoqlSyncTargetMaxBatchSize] as? NSNumber {
            self.maxBatchSize = maxBatchSize.intValue
        } else {
            self.maxBatchSize = SFRestSOQLDefaultBatchSize
        }
        modifyQueryIfNeeded()
    }

    public override init() {
        super.init()
        self.queryType = .soql
    }

    func modifyQueryIfNeeded() {
        guard !query.isEmpty else { return }

        var mutated = false
        let mutator = SoqlMutator.with(soql: query)

        // Inserts the mandatory 'LastModifiedDate' field if it doesn't exist.
        if !mutator.isSelectingField(modificationDateFieldName) {
            mutated = true
            mutator.addSelectFields(modificationDateFieldName)
        }

        // Inserts the mandatory 'Id' field if it doesn't exist.
        if !mutator.isSelectingField(idFieldName) {
            mutated = true
            mutator.addSelectFields(idFieldName)
        }

        // Order by 'LastModifiedDate' field if no order by specified
        if !mutator.hasOrderBy() {
            mutated = true
            mutator.replaceOrderBy(modificationDateFieldName)
        }

        if mutated {
            self.query = mutator.asBuilder().build()
        }
    }

    // MARK: - Factory methods

    @objc
    open class func newSyncTarget(_ query: String) -> SoqlSyncDownTarget {
        return newSyncTarget(query, maxBatchSize: SFRestSOQLDefaultBatchSize)
    }

    @objc
    open class func newSyncTarget(_ query: String, maxBatchSize: Int) -> SoqlSyncDownTarget {
        let syncTarget = SoqlSyncDownTarget()
        syncTarget.queryType = .soql
        syncTarget.query = query
        syncTarget.maxBatchSize = maxBatchSize
        syncTarget.modifyQueryIfNeeded()
        return syncTarget
    }

    // MARK: - From/to dictionary

    open override func asDict() -> [String: Any] {
        var dict = super.asDict()
        dict[kSFSoqlSyncTargetQuery] = query
        dict[kSFSoqlSyncTargetMaxBatchSize] = NSNumber(value: maxBatchSize)
        return dict
    }

    // MARK: - Data fetching

    open override func startFetch(syncManager: SFMobileSyncSyncManager,
                                  maxTimeStamp: Int64,
                                  onFail errorBlock: @escaping SyncDownErrorBlock,
                                  onComplete completeBlock: @escaping SyncDownCompletionBlock) {
        startFetch(syncManager: syncManager,
                  queryToRun: getQueryToRun(maxTimeStamp),
                  onFail: errorBlock,
                  onComplete: completeBlock)
    }

    @objc
    func startFetch(syncManager: SFMobileSyncSyncManager,
                   queryToRun: String,
                   onFail errorBlock: @escaping SyncDownErrorBlock,
                   onComplete completeBlock: @escaping SyncDownCompletionBlock) {
        let request = buildRequest(queryToRun)

        SFMobileSyncNetworkUtils.sendRequest(
            withMobileSyncUserAgent: request,
            failureBlock: { (response: Any?, error: Error?, rawResponse: URLResponse?) in
                if let error = error {
                    errorBlock(error)
                }
            },
            successBlock: { [weak self] (responseJson: Any?, rawResponse: URLResponse?) in
                guard let self = self,
                      let responseDict = responseJson as? [String: Any] else { return }

                if let totalSize = responseDict[kResponseTotalSize] as? NSNumber {
                    self.totalSize = totalSize.uintValue
                }
                self.nextRecordsUrl = responseDict[kResponseNextRecordsUrl] as? String
                completeBlock(self.getRecordsFromResponse(responseDict))
            }
        )
    }

    @objc
    func buildRequest(_ queryToRun: String) -> SFRestRequest {
        return RestClient.shared.requestForQuery(
            queryToRun,
            apiVersion: nil,
            batchSize: maxBatchSize
        )
    }

    open override func continueFetch(syncManager: SFMobileSyncSyncManager,
                                    onFail errorBlock: @escaping SyncDownErrorBlock,
                                    onComplete completeBlock: SyncDownCompletionBlock?) {
        guard let nextRecordsUrl = nextRecordsUrl else {
            completeBlock?(nil)
            return
        }

        let request = RestRequest.request(withMethod: .GET, path: nextRecordsUrl, queryParams: nil)

        SFMobileSyncNetworkUtils.sendRequest(
            withMobileSyncUserAgent: request,
            failureBlock: { (response: Any?, error: Error?, rawResponse: URLResponse?) in
                if let error = error {
                    errorBlock(error)
                }
            },
            successBlock: { [weak self] (responseJson: Any?, rawResponse: URLResponse?) in
                guard let self = self,
                      let responseDict = responseJson as? [String: Any] else { return }

                self.nextRecordsUrl = responseDict[kResponseNextRecordsUrl] as? String
                completeBlock?(self.getRecordsFromResponse(responseDict))
            }
        )
    }

    @objc
    func getRecordsFromResponse(_ responseJson: [String: Any]) -> [Any] {
        return responseJson[kResponseRecords] as? [Any] ?? []
    }

    open override func getRemoteIds(syncManager: SFMobileSyncSyncManager,
                                   localIds: [Any],
                                   errorBlock: @escaping SyncDownErrorBlock,
                                   completeBlock: @escaping SyncDownCompletionBlock) {
        let soql = getSoqlForRemoteIds()
        let remoteIds = NSMutableSet()
        let idFieldName = self.idFieldName

        var fetchBlockRecurse: SyncDownCompletionBlock?

        let fetchErrorBlock: SyncDownErrorBlock = { error in
            fetchBlockRecurse = nil
            errorBlock(error)
        }

        let fetchBlock: SyncDownCompletionBlock = { [weak self] records in
            guard let self = self else { return }

            if records == nil {
                completeBlock(remoteIds.allObjects)
                fetchBlockRecurse = nil
                return
            }

            var error: NSError?
            if !syncManager.checkAcceptingSyncs(&error) {
                if let error = error {
                    errorBlock(error)
                }
                return
            }

            if let records = records as? [[String: Any]] {
                for record in records {
                    if let id = record[idFieldName] {
                        remoteIds.add(id)
                    }
                }
            }

            self.continueFetch(syncManager: syncManager,
                             onFail: fetchErrorBlock,
                             onComplete: fetchBlockRecurse)
        }

        fetchBlockRecurse = fetchBlock
        startFetch(syncManager: syncManager,
                  queryToRun: soql,
                  onFail: errorBlock,
                  onComplete: fetchBlock)
    }

    open override func isSyncDownSortedByLatestModification() -> Bool {
        let mutator = SoqlMutator.with(soql: query)
        return mutator.isOrderingBy(modificationDateFieldName)
    }

    // MARK: - Utility methods

    @objc
    func parseIdsFromResponse(_ records: [Any]) -> Set<String> {
        var remoteIds = Set<String>()
        for record in records {
            if let recordDict = record as? [String: Any],
               let id = recordDict[idFieldName] as? String {
                remoteIds.insert(id)
            }
        }
        return remoteIds
    }

    @objc
    func getSoqlForRemoteIds() -> String {
        guard let mutator = SoqlMutator.with(soql: query) as? SoqlMutator else { return "" }
        return mutator.replaceSelectFields(idFieldName)
            .replaceOrderBy("")
            .asBuilder()
            .build()
    }

    @objc
    open func getQueryToRun() -> String {
        return getQueryToRun(0)
    }

    @objc
    open func getQueryToRun(_ maxTimeStamp: Int64) -> String {
        var queryToRun = query
        if maxTimeStamp > 0 {
            queryToRun = Self.addFilterForReSync(query,
                                                 modDateFieldName: modificationDateFieldName,
                                                 maxTimeStamp: maxTimeStamp)
        }
        return queryToRun
    }

    @objc
    open class func addFilterForReSync(_ query: String,
                                      modDateFieldName: String,
                                      maxTimeStamp: Int64) -> String {
        var queryToRun = query
        if maxTimeStamp > 0 {
            let maxTimeStampStr = FormatUtils.getIsoStringFromMillis(maxTimeStamp) ?? ""
            let extraPredicate = "\(modDateFieldName) > \(maxTimeStampStr)"
            let mutator = SoqlMutator.with(soql: query)
            queryToRun = mutator.addWherePredicates(extraPredicate).asBuilder().build()
        }
        return queryToRun
    }

    @objc
    open class func appendToFirstOccurence(_ str: String,
                                          pattern: String,
                                          stringToAppend: String) -> String {
        guard let regexp = try? NSRegularExpression(pattern: pattern,
                                                    options: .caseInsensitive) else {
            return str
        }

        let range = NSRange(location: 0, length: str.count)
        let rangeFirst = regexp.rangeOfFirstMatch(in: str, options: [], range: range)
        guard rangeFirst.location != NSNotFound else { return str }

        let nsStr = str as NSString
        let firstMatch = nsStr.substring(with: rangeFirst)
        return nsStr.replacingCharacters(in: rangeFirst, with: firstMatch + stringToAppend)
    }
}
