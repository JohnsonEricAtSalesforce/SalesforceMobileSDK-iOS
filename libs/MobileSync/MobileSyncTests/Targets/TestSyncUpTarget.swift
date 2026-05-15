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
@testable import MobileSync

enum TestSyncUpTargetModDateCompare: UInt {
    case remoteModDateSameAsLocal = 0
    case remoteModDateGreaterThanLocal = 1
    case remoteModDateLessThanLocal = 2
}

let kCreatedResultIdPrefix = "testSyncUpCreatedId_"

private let kTestSyncUpTargetErrorDomain = "com.mobilesync.test.TestServerTargetErrorDomain"
private let kTestSyncUpDateCompareKey = "dateCompareKey"
private let kTestSyncUpSendRemoteModErrorKey = "sendRemoteModErrorKey"
private let kTestSyncUpSendSyncUpErrorKey = "sendSyncUpErrorKey"

class TestSyncUpTarget: SyncUpTarget {

    private var dateCompare: TestSyncUpTargetModDateCompare = .remoteModDateSameAsLocal
    private var sendRemoteModError: Bool = false
    private var sendSyncUpError: Bool = false

    init(remoteModDateCompare dateCompare: TestSyncUpTargetModDateCompare, sendRemoteModError: Bool, sendSyncUpError: Bool) {
        super.init()
        commonInit(dateCompare: dateCompare, sendRemoteModError: sendRemoteModError, sendSyncUpError: sendSyncUpError)
    }

    required init(dict: [String: Any]?) {
        super.init(dict: dict)
        let dict = dict ?? [:]
        let dateCompare: TestSyncUpTargetModDateCompare = {
            if let value = dict[kTestSyncUpDateCompareKey] as? UInt {
                return TestSyncUpTargetModDateCompare(rawValue: value) ?? .remoteModDateSameAsLocal
            }
            return .remoteModDateSameAsLocal
        }()
        let sendRemoteModError = (dict[kTestSyncUpSendRemoteModErrorKey] as? Bool) ?? false
        let sendSyncUpError = (dict[kTestSyncUpSendSyncUpErrorKey] as? Bool) ?? false
        commonInit(dateCompare: dateCompare, sendRemoteModError: sendRemoteModError, sendSyncUpError: sendSyncUpError)
    }

    override init() {
        super.init()
        commonInit(dateCompare: .remoteModDateSameAsLocal, sendRemoteModError: false, sendSyncUpError: false)
    }

    private func commonInit(dateCompare: TestSyncUpTargetModDateCompare, sendRemoteModError: Bool, sendSyncUpError: Bool) {
        self.dateCompare = dateCompare
        self.sendRemoteModError = sendRemoteModError
        self.sendSyncUpError = sendSyncUpError
    }

    override func asDict() -> [String: Any] {
        var dict = super.asDict()
        dict[kTestSyncUpDateCompareKey] = dateCompare.rawValue
        dict[kTestSyncUpSendRemoteModErrorKey] = sendRemoteModError
        dict[kTestSyncUpSendSyncUpErrorKey] = sendSyncUpError
        return dict
    }

    override func isNewerThanServer(syncManager: MobileSyncSyncManager, record: [String: Any], resultBlock: @escaping RecordNewerThanServerBlock) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if self.sendRemoteModError {
                resultBlock(true)
            } else {
                switch self.dateCompare {
                case .remoteModDateGreaterThanLocal:
                    resultBlock(false)
                case .remoteModDateLessThanLocal:
                    resultBlock(true)
                case .remoteModDateSameAsLocal:
                    resultBlock(true)
                }
            }
        }
    }

    override func createOnServer(syncManager: MobileSyncSyncManager, record: [String: Any], fieldlist: [Any], onComplete completionBlock: @escaping SyncUpcompletionBlock, onFail failBlock: @escaping SyncUpErrorBlock) {
        fakeRemoteCall(isCreate: true, completionBlock: completionBlock, failBlock: failBlock)
    }

    override func updateOnServer(syncManager: MobileSyncSyncManager, record: [String: Any], fieldlist: [Any], onComplete completionBlock: @escaping SyncUpcompletionBlock, onFail failBlock: @escaping SyncUpErrorBlock) {
        fakeRemoteCall(isCreate: false, completionBlock: completionBlock, failBlock: failBlock)
    }

    override func deleteOnServer(syncManager: MobileSyncSyncManager, record: [String: Any], onComplete completionBlock: @escaping SyncUpcompletionBlock, onFail failBlock: @escaping SyncUpErrorBlock) {
        fakeRemoteCall(isCreate: false, completionBlock: completionBlock, failBlock: failBlock)
    }

    private func fakeRemoteCall(isCreate: Bool, completionBlock: @escaping SyncUpcompletionBlock, failBlock: @escaping SyncUpErrorBlock) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if self.sendSyncUpError {
                let syncUpError = NSError(
                    domain: kTestSyncUpTargetErrorDomain,
                    code: Int(CFNetworkErrors.cfurlErrorCannotConnectToHost.rawValue),
                    userInfo: [NSLocalizedDescriptionKey: "RemoteSyncUpError"]
                )
                failBlock(syncUpError)
            } else {
                var result: [String: Any]? = nil
                if isCreate {
                    let randomId = arc4random() % 10000000
                    let resultId = "\(kCreatedResultIdPrefix)\(randomId)"
                    result = ["id": resultId, "errors": [], "success": true]
                }
                completionBlock(result)
            }
        }
    }
}
