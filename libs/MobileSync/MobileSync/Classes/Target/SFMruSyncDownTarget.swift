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

private let kSFSyncTargetObjectType = "sobjectType"
private let kSFSyncTargetFieldlist = "fieldlist"

@objc(SFMruSyncDownTarget)
@objcMembers
open class SFMruSyncDownTarget: SFSyncDownTarget {

    open private(set) var objectType: String = ""
    open private(set) var fieldlist: [String] = []

    // MARK: - Initialization

    public override init() {
        super.init()
        self.queryType = .mru
    }

    public required init(dict: NSDictionary) {
        super.init(dict: dict)
        let dictionary = dict as? [String: Any] ?? [:]
        self.queryType = .mru
        self.objectType = dictionary[kSFSyncTargetObjectType] as? String ?? ""
        self.fieldlist = dictionary[kSFSyncTargetFieldlist] as? [String] ?? []
    }

    // MARK: - Factory

    @objc
    open class func newSyncTarget(_ objectType: String, fieldlist: [Any]) -> SFMruSyncDownTarget {
        let syncTarget = SFMruSyncDownTarget()
        syncTarget.queryType = .mru
        syncTarget.objectType = objectType
        syncTarget.fieldlist = fieldlist as? [String] ?? []
        return syncTarget
    }

    // MARK: - Serialization

    open override func asDict() -> NSMutableDictionary {
        let dict = super.asDict()
        dict[kSFSyncTargetObjectType] = self.objectType
        dict[kSFSyncTargetFieldlist] = self.fieldlist
        return dict
    }

    // MARK: - Fetching

    open override func startFetch(_ syncManager: SFMobileSyncSyncManager, maxTimeStamp: Int64, errorBlock: @escaping SFSyncDownTargetFetchErrorBlock, completeBlock: @escaping SFSyncDownTargetFetchCompleteBlock) {
        let request = RestClient.shared.requestForMetadata(withObjectType: self.objectType, apiVersion: nil)
        SFMobileSyncNetworkUtils.sendRequest(withMobileSyncUserAgent: request, failureBlock: { _, error, _ in
            errorBlock(error)
        }, successBlock: { [weak self] responseJson, _ in
            guard let self = self, let d = responseJson as? [String: Any] else { return }
            let recentItems = self.pluck(d[kRecentItems] as? [[String: Any]] ?? [], key: self.idFieldName)
            let inPredicate = "\(self.idFieldName) IN ('\(recentItems.joined(separator: "', '"))')"
            let soql = SFSDKSoqlBuilder.withFieldsArray(self.fieldlist)
                .from(self.objectType)
                .whereClause(inPredicate)
                .build() ?? ""
            self.startFetch(syncManager, maxTimeStamp: maxTimeStamp, queryRun: soql, errorBlock: errorBlock, completeBlock: completeBlock)
        })
    }

    @objc
    open func startFetch(_ syncManager: SFMobileSyncSyncManager, maxTimeStamp: Int64, queryRun: String, errorBlock: @escaping SFSyncDownTargetFetchErrorBlock, completeBlock: @escaping SFSyncDownTargetFetchCompleteBlock) {
        let soqlRequest = RestClient.shared.request(forQuery: queryRun, apiVersion: nil)
        SFMobileSyncNetworkUtils.sendRequest(withMobileSyncUserAgent: soqlRequest, failureBlock: { _, error, _ in
            errorBlock(error)
        }, successBlock: { [weak self] responseJson, _ in
            guard let self = self, let d = responseJson as? [String: Any] else { return }
            self.totalSize = (d[kResponseTotalSize] as? NSNumber)?.uintValue ?? 0
            completeBlock(d[kResponseRecords] as? [Any])
        })
    }

    open override func getRemoteIds(_ syncManager: SFMobileSyncSyncManager, localIds: [Any], errorBlock: @escaping SFSyncDownTargetFetchErrorBlock, completeBlock: @escaping SFSyncDownTargetFetchCompleteBlock) {
        if localIds.isEmpty {
            completeBlock(nil)
            return
        }
        let idFieldName = self.idFieldName
        let localIdsStrings = localIds.map { "\($0)" }
        let inPredicate = "\(idFieldName) IN ('\(localIdsStrings.joined(separator: "', '"))')"
        let soql = SFSDKSoqlBuilder.withFields(idFieldName)
            .from(self.objectType)
            .whereClause(inPredicate)
            .build() ?? ""

        let fetchBlock: SFSyncDownTargetFetchCompleteBlock = { records in
            var remoteIds = [Any]()
            for record in records ?? [] {
                if let recordDict = record as? [String: Any], let id = recordDict[idFieldName] {
                    remoteIds.append(id)
                }
            }
            completeBlock(remoteIds)
        }
        startFetch(syncManager, maxTimeStamp: 0, queryRun: soql, errorBlock: errorBlock, completeBlock: fetchBlock)
    }

    // MARK: - Private

    private func pluck(_ arrayOfDictionaries: [[String: Any]], key: String) -> [String] {
        var result = [String]()
        for d in arrayOfDictionaries {
            if let value = d[key] as? String {
                result.append(value)
            }
        }
        return result
    }
}
