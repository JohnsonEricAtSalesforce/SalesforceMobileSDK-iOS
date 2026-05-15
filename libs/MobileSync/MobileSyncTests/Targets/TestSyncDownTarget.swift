/*
 Copyright (c) 2019-present, salesforce.com, inc. All rights reserved.

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
import SalesforceSDKCore

private let kTestSyncDownTargetPrefix = "prefix"
private let kTestSyncDownTargetNumberOfRecords = "numberOfRecords"
private let kTestSyncDownTargetNumberOfRecordsPerPage = "numberOfRecordsPerPage"
private let kTestSyncDownTargetSleepPerFetch = "sleepPerFetch"

class TestSyncDownTarget: SyncDownTarget {

    private(set) var prefix: String = ""
    private var numberOfRecords: UInt = 0
    private var numberOfRecordsPerPage: UInt = 0
    private var sleepPerFetch: TimeInterval = 0
    private var records: [[String: Any]] = []
    private var position: UInt = 0

    required init(dict: [String: Any]?) {
        super.init(dict: dict)
        let dict = dict ?? [:]
        let prefix = dict[kTestSyncDownTargetPrefix] as? String ?? ""
        let numberOfRecords = (dict[kTestSyncDownTargetNumberOfRecords] as? NSNumber)?.uintValue ?? 0
        let numberOfRecordsPerPage = (dict[kTestSyncDownTargetNumberOfRecordsPerPage] as? NSNumber)?.uintValue ?? 0
        let sleepPerFetch = (dict[kTestSyncDownTargetSleepPerFetch] as? NSNumber)?.doubleValue ?? 0
        commonInit(prefix: prefix, numberOfRecords: numberOfRecords, numberOfRecordsPerPage: numberOfRecordsPerPage, sleepPerFetch: sleepPerFetch)
    }

    init(prefix: String, numberOfRecords: UInt, numberOfRecordsPerPage: UInt, sleepPerFetch: TimeInterval) {
        super.init()
        commonInit(prefix: prefix, numberOfRecords: numberOfRecords, numberOfRecordsPerPage: numberOfRecordsPerPage, sleepPerFetch: sleepPerFetch)
    }

    private func commonInit(prefix: String, numberOfRecords: UInt, numberOfRecordsPerPage: UInt, sleepPerFetch: TimeInterval) {
        self.queryType = .custom
        self.prefix = prefix
        self.numberOfRecords = numberOfRecords
        self.numberOfRecordsPerPage = numberOfRecordsPerPage
        self.sleepPerFetch = sleepPerFetch
        self.records = createRecords(numberOfRecords)
    }

    override func asDict() -> [String: Any] {
        var dict = super.asDict()
        dict[kTestSyncDownTargetPrefix] = prefix
        dict[kTestSyncDownTargetNumberOfRecords] = numberOfRecords
        dict[kTestSyncDownTargetNumberOfRecordsPerPage] = numberOfRecordsPerPage
        dict[kTestSyncDownTargetSleepPerFetch] = sleepPerFetch
        return dict
    }

    private func createRecords(_ numberOfRecords: UInt) -> [[String: Any]] {
        var records: [[String: Any]] = []
        for i in 0..<Int(numberOfRecords) {
            var record: [String: Any] = [:]
            record[kId] = idForPosition(UInt(i))
            record[kLastModifiedDate] = FormatUtils.getIsoStringFromMillis(dateForPositionAsMillis(UInt(i)))
            records.append(record)
        }
        return records
    }

    private func recordsFromPosition() -> [Any]? {
        if position >= numberOfRecords {
            return nil
        }

        var arrayForPage: [Any] = []
        var i = position
        var limit = position + numberOfRecordsPerPage
        if limit > numberOfRecords { limit = numberOfRecords }

        repeat {
            arrayForPage.append(records[Int(i)])
            i += 1
        } while i < limit
        position = i
        return arrayForPage
    }

    override func isSyncDownSortedByLatestModification() -> Bool {
        return true
    }

    override func startFetch(syncManager: SFMobileSyncSyncManager, maxTimeStamp: Int64, onFail errorBlock: @escaping SyncDownErrorBlock, onComplete completeBlock: @escaping SyncDownCompletionBlock) {
        position = positionForDate(maxTimeStamp)
        totalSize = numberOfRecords - position
        sleepIfNeeded()
        completeBlock(recordsFromPosition())
    }

    private func sleepIfNeeded() {
        if sleepPerFetch > 0 {
            Thread.sleep(forTimeInterval: sleepPerFetch)
        }
    }

    override func continueFetch(syncManager: SFMobileSyncSyncManager, onFail errorBlock: @escaping SyncDownErrorBlock, onComplete completeBlock: SyncDownCompletionBlock?) {
        sleepIfNeeded()
        completeBlock?(recordsFromPosition())
    }

    override func getRemoteIds(syncManager: SFMobileSyncSyncManager, localIds: [Any], errorBlock: @escaping SyncDownErrorBlock, completeBlock: @escaping SyncDownCompletionBlock) {
        var remoteIds: [Any] = []
        for record in records {
            if let id = record[kId] {
                remoteIds.append(id)
            }
        }
        completeBlock(remoteIds)
    }

    func idForPosition(_ i: UInt) -> String {
        return "\(prefix)_\(1000 + i)"
    }

    func dateForPositionAsMillis(_ i: UInt) -> Int64 {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        var comps = DateComponents()
        comps.year = 2019
        comps.month = 3
        comps.day = 1
        comps.hour = 12
        comps.minute = Int(i) / 60
        comps.second = Int(i) % 60
        guard let date = calendar.date(from: comps) else { return 0 }
        return Int64(date.timeIntervalSince1970 * 1000)
    }

    private func positionForDate(_ millis: Int64) -> UInt {
        for i in 0..<UInt(records.count) {
            if dateForPositionAsMillis(i) > millis {
                return i
            }
        }
        return UInt(records.count)
    }
}
