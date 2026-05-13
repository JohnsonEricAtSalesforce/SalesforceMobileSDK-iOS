/*
 SFLayoutSyncDownTarget.swift
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

fileprivate let kSFSyncTargetFormFactor = "formFactor"
fileprivate let kSFSyncTargetLayoutType = "layoutType"
fileprivate let kSFSyncTargetMode = "mode"
fileprivate let kSFSyncTargetRecordTypeId = "recordTypeId"
fileprivate let kIDFieldValue = "%@-%@-%@-%@-%@"

/**
 * Sync down target for object layouts. This uses the '/ui-api/layout' API to fetch object layouts.
 * The easiest way to use this sync target is through SFLayoutSyncManager.
 */
@objc(SFLayoutSyncDownTarget)
@objcMembers
public class LayoutSyncDownTarget: SyncDownTarget {

    public private(set) var objectAPIName: String
    public private(set) var formFactor: String?
    public private(set) var layoutType: String?
    public private(set) var mode: String?
    public private(set) var recordTypeId: String?

    required public init(dict: [String: Any]?) {
        self.objectAPIName = (dict?[kSFSyncTargetObjectType] as? String) ?? ""
        self.formFactor = dict?[kSFSyncTargetFormFactor] as? String
        self.layoutType = dict?[kSFSyncTargetLayoutType] as? String
        self.mode = dict?[kSFSyncTargetMode] as? String
        self.recordTypeId = dict?[kSFSyncTargetRecordTypeId] as? String
        super.init(dict: dict)
        self.queryType = .layout
    }

    public override init() {
        self.objectAPIName = ""
        self.formFactor = nil
        self.layoutType = nil
        self.mode = nil
        self.recordTypeId = nil
        super.init()
        self.queryType = .layout
    }

    /**
     * Factory method.
     */
    @objc(newSyncTarget:formFactor:layoutType:mode:recordTypeId:)
    public static func newSyncTarget(
        _ objectAPIName: String,
        formFactor: String?,
        layoutType: String?,
        mode: String?,
        recordTypeId: String?
    ) -> LayoutSyncDownTarget {
        let syncTarget = LayoutSyncDownTarget()
        syncTarget.queryType = .layout
        syncTarget.objectAPIName = objectAPIName
        syncTarget.formFactor = formFactor
        syncTarget.layoutType = layoutType
        syncTarget.mode = mode
        syncTarget.recordTypeId = recordTypeId
        return syncTarget
    }

    public override func asDict() -> [String: Any] {
        var dict = super.asDict()
        dict[kSFSyncTargetObjectType] = objectAPIName
        dict[kSFSyncTargetFormFactor] = formFactor
        dict[kSFSyncTargetLayoutType] = layoutType
        dict[kSFSyncTargetMode] = mode
        dict[kSFSyncTargetRecordTypeId] = recordTypeId
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
            objectAPIName: objectAPIName,
            formFactor: formFactor,
            layoutType: layoutType,
            mode: mode,
            recordTypeId: recordTypeId,
            errorBlock: errorBlock,
            completeBlock: completeBlock
        )
    }

    public func startFetch(
        _ syncManager: MobileSyncSyncManager,
        maxTimeStamp: Int64,
        objectAPIName: String,
        formFactor: String?,
        layoutType: String?,
        mode: String?,
        recordTypeId: String?,
        errorBlock: @escaping SyncDownTargetFetchErrorBlock,
        completeBlock: @escaping SyncDownTargetFetchCompleteBlock
    ) {
        let request = RestClient.shared.requestForLayout(
            withObjectAPIName: objectAPIName,
            formFactor: formFactor,
            layoutType: layoutType,
            mode: mode,
            recordTypeId: recordTypeId,
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
                record[kId] = String(format: kIDFieldValue,
                                   self.objectAPIName,
                                   self.formFactor ?? "",
                                   self.layoutType ?? "",
                                   self.mode ?? "",
                                   self.recordTypeId ?? "")
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
