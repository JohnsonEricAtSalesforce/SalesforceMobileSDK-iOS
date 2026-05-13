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

let kSFSoslSyncTargetQuery = "query"

@objc(SFSoslSyncDownTarget)
open class SoslSyncDownTarget: SyncDownTarget {

    @objc public var query: String = ""

    // MARK: - Initialization

    required public init(dict: [String: Any]?) {
        super.init(dict: dict)
        self.queryType = .sosl
        self.query = (dict?[kSFSoslSyncTargetQuery] as? String) ?? ""
    }

    public override init() {
        super.init()
        self.queryType = .sosl
    }

    // MARK: - Factory methods

    @objc
    open class func newSyncTarget(_ query: String) -> SoslSyncDownTarget {
        let syncTarget = SoslSyncDownTarget()
        syncTarget.queryType = .sosl
        syncTarget.query = query
        return syncTarget
    }

    // MARK: - To dictionary

    open override func asDict() -> [String: Any] {
        var dict = super.asDict()
        dict[kSFSoslSyncTargetQuery] = query
        return dict
    }

    // MARK: - Data fetching

    open override func startFetch(syncManager: SFMobileSyncSyncManager,
                                  maxTimeStamp: Int64,
                                  onFail errorBlock: @escaping SyncDownErrorBlock,
                                  onComplete completeBlock: @escaping SyncDownCompletionBlock) {
        startFetch(syncManager: syncManager,
                  maxTimeStamp: maxTimeStamp,
                  queryRun: query,
                  errorBlock: errorBlock,
                  completeBlock: completeBlock)
    }

    @objc
    func startFetch(syncManager: SFMobileSyncSyncManager,
                   maxTimeStamp: Int64,
                   queryRun: String,
                   errorBlock: @escaping SyncDownErrorBlock,
                   completeBlock: @escaping SyncDownCompletionBlock) {
        let request = RestClient.shared.requestForSearch(queryRun, apiVersion: nil)

        SFMobileSyncNetworkUtils.sendRequest(
            withMobileSyncUserAgent: request,
            failureBlock: { [weak self] (response: Any?, error: (any Error)?, rawResponse: URLResponse?) in
                errorBlock(error)
            },
            successBlock: { [weak self] (response: Any?, rawResponse: URLResponse?) in
                guard let self = self,
                      let responseDict = response as? [String: Any],
                      let searchRecords = responseDict[kResponseSearchRecords] as? [Any] else { return }

                self.totalSize = UInt(searchRecords.count)
                completeBlock(searchRecords)
            }
        )
    }

    open override func getRemoteIds(syncManager: SFMobileSyncSyncManager,
                                   localIds: [Any],
                                   errorBlock: @escaping SyncDownErrorBlock,
                                   completeBlock: @escaping SyncDownCompletionBlock) {
        let idFieldName = self.idFieldName

        let fetchBlock: SyncDownCompletionBlock = { records in
            guard let records = records as? [[String: Any]] else {
                completeBlock([])
                return
            }

            var remoteIds: [Any] = []
            for record in records {
                if let id = record[idFieldName] {
                    remoteIds.append(id)
                }
            }
            completeBlock(remoteIds)
        }

        startFetch(syncManager: syncManager,
                  maxTimeStamp: 0,
                  queryRun: query,
                  errorBlock: errorBlock,
                  completeBlock: fetchBlock)
    }
}
