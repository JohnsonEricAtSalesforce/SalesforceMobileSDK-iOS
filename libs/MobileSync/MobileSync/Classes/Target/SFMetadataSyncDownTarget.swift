/*
 SFMetadataSyncDownTarget.swift
 MobileSync

 Created by Bharath Hariharan on 5/6/18.

 Copyright (c) 2018-present, salesforce.com, inc. All rights reserved.

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

@objc(SFMetadataSyncDownTarget)
@objcMembers
public class MetadataSyncDownTarget: SyncDownTarget {

    public private(set) var objectType: String

    required public init(dict: [String: Any]?) {
        self.objectType = (dict?[kSFSyncTargetObjectType] as? String) ?? ""
        super.init(dict: dict)
        self.queryType = .metadata
    }

    public override init() {
        self.objectType = ""
        super.init()
        self.queryType = .metadata
    }

    /**
     * Factory method.
     */
    @objc(newSyncTarget:)
    public static func newSyncTarget(_ objectType: String) -> MetadataSyncDownTarget {
        let syncTarget = MetadataSyncDownTarget()
        syncTarget.queryType = .metadata
        syncTarget.objectType = objectType
        return syncTarget
    }

    public override func asDict() -> [String: Any] {
        var dict = super.asDict()
        dict[kSFSyncTargetObjectType] = objectType
        return dict
    }

    public override func startFetch(
        syncManager: SFMobileSyncSyncManager,
        maxTimeStamp: Int64,
        onFail errorBlock: @escaping SyncDownTargetFetchErrorBlock,
        onComplete completeBlock: @escaping SyncDownTargetFetchCompleteBlock
    ) {
        startFetch(
            syncManager,
            maxTimeStamp: maxTimeStamp,
            objectType: objectType,
            errorBlock: errorBlock,
            completeBlock: completeBlock
        )
    }

    public func startFetch(
        _ syncManager: MobileSyncSyncManager,
        maxTimeStamp: Int64,
        objectType: String,
        errorBlock: @escaping SyncDownTargetFetchErrorBlock,
        completeBlock: @escaping SyncDownTargetFetchCompleteBlock
    ) {
        let request = RestClient.shared.requestForDescribe(
            withObjectType: objectType,
            apiVersion: nil
        )

        SFMobileSyncNetworkUtils.sendRequest(
            withMobileSyncUserAgent: request,
            failureBlock: { [weak self] (response: Any?, error: (any Error)?, rawResponse: URLResponse?) in
                errorBlock(error)
            },
            successBlock: { [weak self] (response: Any?, rawResponse: URLResponse?) in
                guard let self = self,
                      let d = response as? [String: Any] else {
                    completeBlock(nil)
                    return
                }

                self.totalSize = 1
                var record = d
                record[kId] = self.objectType
                let records = [record]
                completeBlock(records)
            }
        )
    }

    public override func getRemoteIds(
        syncManager: SFMobileSyncSyncManager,
        localIds: [Any],
        errorBlock: @escaping SyncDownTargetFetchErrorBlock,
        completeBlock: @escaping SyncDownTargetFetchCompleteBlock
    ) {
        completeBlock(nil)
    }

    public override func cleanGhosts(
        syncManager: SFMobileSyncSyncManager,
        soupName: String,
        syncId: NSNumber,
        onFail errorBlock: @escaping SyncDownTargetFetchErrorBlock,
        onComplete completeBlock: @escaping SyncDownTargetFetchCompleteBlock
    ) {
        completeBlock(nil)
    }
}
