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

private let kSFSoslSyncTargetQuery = "query"

@objc(SFSoslSyncDownTarget)
@objcMembers
open class SFSoslSyncDownTarget: SFSyncDownTarget {

    open private(set) var query: String = ""

    // MARK: - Initialization

    public override init() {
        super.init()
        self.queryType = .sosl
    }

    public required init(dict: NSDictionary) {
        super.init(dict: dict)
        let dictionary = dict as? [String: Any] ?? [:]
        self.queryType = .sosl
        self.query = dictionary[kSFSoslSyncTargetQuery] as? String ?? ""
    }

    // MARK: - Factory

    @objc
    open class func newSyncTarget(_ query: String) -> SFSoslSyncDownTarget {
        let syncTarget = SFSoslSyncDownTarget()
        syncTarget.queryType = .sosl
        syncTarget.query = query
        return syncTarget
    }

    // MARK: - Serialization

    open override func asDict() -> NSMutableDictionary {
        let dict = super.asDict()
        dict[kSFSoslSyncTargetQuery] = self.query
        return dict
    }

    // MARK: - Fetching

    open override func startFetch(_ syncManager: SFMobileSyncSyncManager, maxTimeStamp: Int64, errorBlock: @escaping SFSyncDownTargetFetchErrorBlock, completeBlock: @escaping SFSyncDownTargetFetchCompleteBlock) {
        startFetch(syncManager, maxTimeStamp: maxTimeStamp, queryRun: self.query, errorBlock: errorBlock, completeBlock: completeBlock)
    }

    @objc
    open func startFetch(_ syncManager: SFMobileSyncSyncManager, maxTimeStamp: Int64, queryRun: String, errorBlock: @escaping SFSyncDownTargetFetchErrorBlock, completeBlock: @escaping SFSyncDownTargetFetchCompleteBlock) {
        let request = RestClient.sharedInstance.requestForSearch(queryRun, apiVersion: nil)
        SFMobileSyncNetworkUtils.sendRequest(withMobileSyncUserAgent: request, failureBlock: { _, error, _ in
            errorBlock(error)
        }, successBlock: { [weak self] responseJson, _ in
            guard let self = self, let d = responseJson as? [String: Any] else { return }
            let searchRecords = d[kResponseSearchRecords] as? [Any] ?? []
            self.totalSize = UInt(searchRecords.count)
            completeBlock(searchRecords)
        })
    }

    open override func getRemoteIds(_ syncManager: SFMobileSyncSyncManager, localIds: [Any], errorBlock: @escaping SFSyncDownTargetFetchErrorBlock, completeBlock: @escaping SFSyncDownTargetFetchCompleteBlock) {
        let idFieldName = self.idFieldName
        let fetchBlock: SFSyncDownTargetFetchCompleteBlock = { records in
            var remoteIds = [Any]()
            for record in records ?? [] {
                if let recordDict = record as? [String: Any], let id = recordDict[idFieldName] {
                    remoteIds.append(id)
                }
            }
            completeBlock(remoteIds)
        }
        startFetch(syncManager, maxTimeStamp: 0, queryRun: self.query, errorBlock: errorBlock, completeBlock: fetchBlock)
    }
}
