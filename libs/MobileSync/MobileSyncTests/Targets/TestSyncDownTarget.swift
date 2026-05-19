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

private let kTestSyncDownTargetPrefix = "prefix"
private let kTestSyncDownTargetNumberOfRecords = "numberOfRecords"
private let kTestSyncDownTargetNumberOfRecordsPerPage = "numberOfRecordsPerPage"
private let kTestSyncDownTargetSleepPerFetch = "sleepPerFetch"

@objc(TestSyncDownTarget)
@objcMembers
class TestSyncDownTarget: SFSyncDownTarget {

    private(set) var prefix: String = ""
    private var numberOfRecords: UInt = 0
    private var numberOfRecordsPerPage: UInt = 0
    private var sleepPerFetch: TimeInterval = 0
    private var records: [[String: Any]] = []
    private var position: UInt = 0

    @objc
    init(prefix: String, numberOfRecords: UInt, numberOfRecordsPerPage: UInt, sleepPerFetch: TimeInterval) {
        super.init()
        self.queryType = .custom
        self.prefix = prefix
        self.numberOfRecords = numberOfRecords
        self.numberOfRecordsPerPage = numberOfRecordsPerPage
        self.sleepPerFetch = sleepPerFetch
        self.records = createRecords(numberOfRecords)
    }

    override init(dict: NSDictionary) {
        super.init(dict: dict)
        let d = dict as? [String: Any] ?? [:]
        self.prefix = d[kTestSyncDownTargetPrefix] as? String ?? ""
        self.numberOfRecords = (d[kTestSyncDownTargetNumberOfRecords] as? NSNumber)?.uintValue ?? 0
        self.numberOfRecordsPerPage = (d[kTestSyncDownTargetNumberOfRecordsPerPage] as? NSNumber)?.uintValue ?? 0
        self.sleepPerFetch = (d[kTestSyncDownTargetSleepPerFetch] as? NSNumber)?.doubleValue ?? 0
        self.queryType = .custom
        self.records = createRecords(numberOfRecords)
    }

    override init() {
        super.init()
    }

    override func asDict() -> NSMutableDictionary {
        let dict = super.asDict()
        dict[kTestSyncDownTargetPrefix] = prefix
        dict[kTestSyncDownTargetNumberOfRecords] = NSNumber(value: numberOfRecords)
        dict[kTestSyncDownTargetNumberOfRecordsPerPage] = NSNumber(value: numberOfRecordsPerPage)
        dict[kTestSyncDownTargetSleepPerFetch] = NSNumber(value: sleepPerFetch)
        return dict
    }

    private func createRecords(_ count: UInt) -> [[String: Any]] {
        var result: [[String: Any]] = []
        for i in 0..<Int(count) {
            var record: [String: Any] = [:]
            record[kId] = idForPosition(UInt(i))
            record[kLastModifiedDate] = SFMobileSyncObjectUtils.getIsoStringFromMillis(dateForPositionAsMillis(UInt(i)))
            result.append(record)
        }
        return result
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

    override func startFetch(_ syncManager: SFMobileSyncSyncManager, maxTimeStamp: Int64, errorBlock: @escaping SFSyncDownTargetFetchErrorBlock, completeBlock: @escaping SFSyncDownTargetFetchCompleteBlock) {
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

    override func continueFetch(_ syncManager: SFMobileSyncSyncManager, errorBlock: @escaping SFSyncDownTargetFetchErrorBlock, completeBlock: @escaping SFSyncDownTargetFetchCompleteBlock) {
        sleepIfNeeded()
        completeBlock(recordsFromPosition())
    }

    override func getRemoteIds(_ syncManager: SFMobileSyncSyncManager, localIds: [Any], errorBlock: @escaping SFSyncDownTargetFetchErrorBlock, completeBlock: @escaping SFSyncDownTargetFetchCompleteBlock) {
        var remoteIds: [Any] = []
        for record in records {
            if let id = record[kId] {
                remoteIds.append(id)
            }
        }
        completeBlock(remoteIds)
    }

    @objc func idForPosition(_ i: UInt) -> String {
        return "\(prefix)_\(1000 + i)"
    }

    @objc func dateForPositionAsMillis(_ i: UInt) -> Int64 {
        var components = DateComponents()
        components.year = 2019
        components.month = 3
        components.day = 1
        components.hour = 12
        components.minute = Int(i) / 60
        components.second = Int(i) % 60
        let calendar = Calendar(identifier: .gregorian)
        let date = calendar.date(from: components) ?? Date()
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
