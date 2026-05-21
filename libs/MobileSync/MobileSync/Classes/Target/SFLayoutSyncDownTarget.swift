/*
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

private let kSFSyncTargetObjectType_Layout = "sobjectType"
private let kSFSyncTargetFormFactor = "formFactor"
private let kSFSyncTargetLayoutType = "layoutType"
private let kSFSyncTargetMode = "mode"
private let kSFSyncTargetRecordTypeId = "recordTypeId"
private let kIDFieldValue = "%@-%@-%@-%@-%@"

@objc(SFLayoutSyncDownTarget)
@objcMembers
open class SFLayoutSyncDownTarget: SFSyncDownTarget {

    open private(set) var objectAPIName: String = ""
    open private(set) var formFactor: String?
    open private(set) var layoutType: String?
    open private(set) var mode: String?
    open private(set) var recordTypeId: String?

    // MARK: - Initialization

    public override init() {
        super.init()
        self.queryType = .layout
    }

    public required init(dict: NSDictionary) {
        super.init(dict: dict)
        let dictionary = dict as? [String: Any] ?? [:]
        self.queryType = .layout
        self.objectAPIName = dictionary[kSFSyncTargetObjectType_Layout] as? String ?? ""
        self.formFactor = dictionary[kSFSyncTargetFormFactor] as? String
        self.layoutType = dictionary[kSFSyncTargetLayoutType] as? String
        self.mode = dictionary[kSFSyncTargetMode] as? String
        self.recordTypeId = dictionary[kSFSyncTargetRecordTypeId] as? String
    }

    // MARK: - Factory

    @objc
    open class func newSyncTarget(_ objectAPIName: String, formFactor: String?, layoutType: String?, mode: String?, recordTypeId: String?) -> SFLayoutSyncDownTarget {
        let syncTarget = SFLayoutSyncDownTarget()
        syncTarget.queryType = .layout
        syncTarget.objectAPIName = objectAPIName
        syncTarget.formFactor = formFactor
        syncTarget.layoutType = layoutType
        syncTarget.mode = mode
        syncTarget.recordTypeId = recordTypeId
        return syncTarget
    }

    // MARK: - Serialization

    open override func asDict() -> NSMutableDictionary {
        let dict = super.asDict()
        dict[kSFSyncTargetObjectType_Layout] = self.objectAPIName
        dict[kSFSyncTargetFormFactor] = self.formFactor
        dict[kSFSyncTargetLayoutType] = self.layoutType
        dict[kSFSyncTargetMode] = self.mode
        dict[kSFSyncTargetRecordTypeId] = self.recordTypeId
        return dict
    }

    // MARK: - Fetching

    open override func startFetch(_ syncManager: SFMobileSyncSyncManager, maxTimeStamp: Int64, errorBlock: @escaping SFSyncDownTargetFetchErrorBlock, completeBlock: @escaping SFSyncDownTargetFetchCompleteBlock) {
        let request = RestClient.sharedInstance.requestForLayout(withObjectAPIName: self.objectAPIName, formFactor: self.formFactor, layoutType: self.layoutType, mode: self.mode, recordTypeId: self.recordTypeId, apiVersion: nil)
        SFMobileSyncNetworkUtils.sendRequest(withMobileSyncUserAgent: request, failureBlock: { _, error, _ in
            errorBlock(error)
        }, successBlock: { [weak self] responseJson, _ in
            guard let self = self, let d = responseJson as? [String: Any] else { return }
            self.totalSize = 1
            var record = d
            record[kId] = String(format: kIDFieldValue, self.objectAPIName, self.formFactor ?? "", self.layoutType ?? "", self.mode ?? "", self.recordTypeId ?? "")
            completeBlock([record])
        })
    }

    open override func getRemoteIds(_ syncManager: SFMobileSyncSyncManager, localIds: [Any], errorBlock: @escaping SFSyncDownTargetFetchErrorBlock, completeBlock: @escaping SFSyncDownTargetFetchCompleteBlock) {
        completeBlock(nil)
    }

    open override func cleanGhosts(_ syncManager: SFMobileSyncSyncManager, soupName: String, syncId: NSNumber, errorBlock: @escaping SFSyncDownTargetFetchErrorBlock, completeBlock: @escaping SFSyncDownTargetFetchCompleteBlock) {
        completeBlock(nil)
    }
}
