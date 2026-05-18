/*
 Copyright (c) 2014-present, salesforce.com, inc. All rights reserved.

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
import SmartStore
import SalesforceSDKCommon

// Soups and soup fields
public let kSFSyncStateSyncsSoupName: String = "syncs_soup"
public let kSFSyncStateSyncsSoupSyncType: String = "type"

// Fields in dict representation
public let kSFSyncStateId: String = "_soupEntryId"
public let kSFSyncStateName: String = "name"
public let kSFSyncStateType: String = "type"
public let kSFSyncStateTarget: String = "target"
public let kSFSyncStateSoupName: String = "soupName"
public let kSFSyncStateOptions: String = "options"
public let kSFSyncStateStatus: String = "status"
public let kSFSyncStateProgress: String = "progress"
public let kSFSyncStateTotalSize: String = "totalSize"
public let kSFSyncStateMaxTimeStamp: String = "maxTimeStamp"
public let kSFSyncStateStartTime: String = "startTime"
public let kSFSyncStateEndTime: String = "endTime"
public let kSFSyncStateError: String = "error"

// Possible values for sync type
public let kSFSyncStateTypeDown: String = "syncDown"
public let kSFSyncStateTypeUp: String = "syncUp"

// Possible values for sync status
public let kSFSyncStateStatusNew: String = "NEW"
public let kSFSyncStateStatusStopped: String = "STOPPED"
public let kSFSyncStateStatusRunning: String = "RUNNING"
public let kSFSyncStateStatusDone: String = "DONE"
public let kSFSyncStateStatusFailed: String = "FAILED"

// Possible values for merge mode
public let kSFSyncStateMergeModeOverwrite: String = "OVERWRITE"
public let kSFSyncStateMergeModeLeaveIfChanged: String = "LEAVE_IF_CHANGED"

/// Possible values for sync type
@objc(SFSyncStateSyncType)
public enum SFSyncStateSyncType: Int {
    case down = 0
    case up
}

/// Possible values for sync status
@objc(SFSyncStateStatus)
public enum SFSyncStateStatus: Int {
    case new = 0
    case stopped
    case running
    case done
    case failed
}

/// Possible values for merge mode
@objc(SFSyncStateMergeMode)
public enum SFSyncStateMergeMode: Int {
    case overwrite = 0
    case leaveIfChanged
}

private let kSFSyncStateSyncsSoupSyncName = "name"

@objc(SFSyncState)
@objcMembers
open class SFSyncState: NSObject, NSCopying {

    @objc public private(set) var syncId: Int = 0
    @objc public private(set) var name: String?
    @objc public private(set) var type: SFSyncStateSyncType = .down
    @objc public private(set) var soupName: String = ""
    @objc public private(set) var target: SFSyncTarget = SFSyncTarget()
    @objc public private(set) var options: SFSyncOptions?
    @objc public private(set) var startTime: Int = 0
    @objc public private(set) var endTime: Int = 0

    private var _status: SFSyncStateStatus = .new
    @objc public var status: SFSyncStateStatus {
        get { return _status }
        set {
            if _status != .running && newValue == .running {
                startTime = Int(Date().timeIntervalSince1970 * 1000)
            }
            if _status == .running && (newValue == .done || newValue == .failed) {
                endTime = Int(Date().timeIntervalSince1970 * 1000)
            }
            _status = newValue
        }
    }

    @objc public var progress: Int = 0
    @objc public var totalSize: Int = 0
    @objc public var maxTimeStamp: Int64 = 0
    @objc public var error: String?

    @objc public var mergeMode: SFSyncStateMergeMode {
        return options?.mergeMode ?? .overwrite
    }

    // MARK: - Setup

    @objc public class func setupSyncsSoupIfNeeded(_ store: SFSmartStore) {
        if store.soupExists(kSFSyncStateSyncsSoupName) && store.indices(forSoupNamed: kSFSyncStateSyncsSoupName).count == 3 {
            return
        }
        let indexSpecs: [SFSoupIndex] = [
            SoupIndex(path: kSFSyncStateSyncsSoupSyncType, indexType: kSoupIndexTypeJSON1, columnName: nil),
            SoupIndex(path: kSFSyncStateSyncsSoupSyncName, indexType: kSoupIndexTypeJSON1, columnName: nil),
            SoupIndex(path: kSFSyncStateStatus, indexType: kSoupIndexTypeJSON1, columnName: nil)
        ].compactMap { $0 }

        if store.soupExists(kSFSyncStateSyncsSoupName) {
            _ = store.alterSoup(named: kSFSyncStateSyncsSoupName, indexSpecs: indexSpecs, reIndexData: true)
        } else {
            try? store.registerSoup(withName: kSFSyncStateSyncsSoupName, withIndices: indexSpecs)
        }
    }

    @objc public class func cleanupSyncsSoupIfNeeded(_ store: SFSmartStore) {
        let syncs = getSyncs(withStatus: store, status: .running)
        for sync in syncs {
            sync.status = .stopped
            sync.save(store)
        }
    }

    @objc public class func getSyncs(withStatus store: SFSmartStore, status: SFSyncStateStatus) -> [SFSyncState] {
        var syncs = [SFSyncState]()
        let smartSql = "select {\(kSFSyncStateSyncsSoupName):_soup} from {\(kSFSyncStateSyncsSoupName)} where {\(kSFSyncStateSyncsSoupName):\(kSFSyncStateStatus)} = '\(SFSyncState.syncStatusToString(status))'"
        guard let query = QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: UInt(INT_MAX)) else { return syncs }
        let rows = try? store.query(using: query, startingFromPageIndex: 0)
        if let rows = rows {
            for row in rows {
                if let rowArray = row as? [Any], let dict = rowArray[0] as? [String: Any],
                   let syncState = SFSyncState.new(fromDict: dict) {
                    syncs.append(syncState)
                }
            }
        }
        return syncs
    }

    // MARK: - Factory methods

    @objc(buildSyncDownWithOptions:target:soupName:name:store:)
    public class func newSyncDown(withOptions options: SFSyncOptions, target: SFSyncDownTarget, soupName: String, name: String?, store: SFSmartStore) -> SFSyncState? {
        var dict: [String: Any] = [
            kSFSyncStateType: kSFSyncStateTypeDown,
            kSFSyncStateTarget: target.asDict(),
            kSFSyncStateSoupName: soupName,
            kSFSyncStateOptions: options.asDict(),
            kSFSyncStateStatus: kSFSyncStateStatusNew,
            kSFSyncStateMaxTimeStamp: NSNumber(value: -1),
            kSFSyncStateProgress: NSNumber(value: 0),
            kSFSyncStateTotalSize: NSNumber(value: -1),
            kSFSyncStateStartTime: NSNumber(value: 0),
            kSFSyncStateEndTime: NSNumber(value: 0),
            kSFSyncStateError: ""
        ]
        if let name = name { dict[kSFSyncStateName] = name }

        if let name = name, SFSyncState.by(name: name, store: store) != nil {
            SFSDKMobileSyncLogger.e(self, message: "Failed to create sync down: there is already a sync with name:\(name)")
            return nil
        }

        let savedDicts = try? store.upsert(entries: [dict], forSoupNamed: kSFSyncStateSyncsSoupName)
        guard let saved = savedDicts, saved.count > 0, let savedDict = saved[0] as? [String: Any] else { return nil }
        return SFSyncState.new(fromDict: savedDict)
    }

    @objc(buildSyncUpWithOptions:target:soupName:name:store:)
    public class func newSyncUp(withOptions options: SFSyncOptions, target: SFSyncUpTarget, soupName: String, name: String?, store: SFSmartStore) -> SFSyncState? {
        var dict: [String: Any] = [
            kSFSyncStateType: kSFSyncStateTypeUp,
            kSFSyncStateTarget: target.asDict(),
            kSFSyncStateSoupName: soupName,
            kSFSyncStateOptions: options.asDict(),
            kSFSyncStateStatus: kSFSyncStateStatusNew,
            kSFSyncStateProgress: NSNumber(value: 0),
            kSFSyncStateTotalSize: NSNumber(value: -1),
            kSFSyncStateStartTime: NSNumber(value: 0),
            kSFSyncStateEndTime: NSNumber(value: 0),
            kSFSyncStateError: ""
        ]
        if let name = name { dict[kSFSyncStateName] = name }

        if let name = name, SFSyncState.by(name: name, store: store) != nil {
            SFSDKMobileSyncLogger.e(self, message: "Failed to create sync up: there is already a sync with name:\(name)")
            return nil
        }

        let savedDicts = try? store.upsert(entries: [dict], forSoupNamed: kSFSyncStateSyncsSoupName)
        guard let saved = savedDicts, saved.count > 0, let savedDict = saved[0] as? [String: Any] else { return nil }
        return SFSyncState.new(fromDict: savedDict)
    }

    @objc(buildSyncUpWithOptions:soupName:store:)
    public class func newSyncUp(withOptions options: SFSyncOptions, soupName: String, store: SFSmartStore) -> SFSyncState? {
        let target: SFSyncUpTarget = SFSyncUpTarget.newFromDict(nil) ?? SFSyncUpTarget()
        return newSyncUp(withOptions: options, target: target, soupName: soupName, name: nil, store: store)
    }

    // MARK: - Save/retrieve/delete

    @objc public class func by(id syncId: NSNumber, store: SFSmartStore) -> SFSyncState? {
        let retrievedDicts = store.retrieve(usingSoupEntryIds: [syncId], fromSoupNamed: kSFSyncStateSyncsSoupName)
        guard retrievedDicts.count > 0 else { return nil }
        let dict = retrievedDicts[0]
        return SFSyncState.new(fromDict: dict)
    }

    @objc public class func by(name: String, store: SFSmartStore) -> SFSyncState? {
        guard let syncId = try? store.lookupSoupEntryId(soupNamed: kSFSyncStateSyncsSoupName, fieldPath: kSFSyncStateSyncsSoupSyncName, fieldValue: name) else {
            return nil
        }
        return by(id: syncId, store: store)
    }

    @objc public func save(_ store: SFSmartStore) {
        try? store.upsert(entries: [asDict()], forSoupNamed: kSFSyncStateSyncsSoupName)
    }

    @objc(deleteSyncId:store:)
    public class func delete(byId syncId: NSNumber, store: SFSmartStore) {
        try? store.removeEntries([syncId], fromSoup: kSFSyncStateSyncsSoupName)
    }

    @objc(deleteSyncName:store:)
    public class func delete(byName name: String, store: SFSmartStore) {
        guard let syncId = try? store.lookupSoupEntryId(soupNamed: kSFSyncStateSyncsSoupName, fieldPath: kSFSyncStateSyncsSoupSyncName, fieldValue: name) else {
            return
        }
        delete(byId: syncId, store: store)
    }

    // MARK: - From/to dictionary

    @objc(buildFromDict:)
    public class func new(fromDict dict: [String: Any]?) -> SFSyncState? {
        guard let dict = dict else { return nil }
        let syncState = SFSyncState()
        syncState.fromDict(dict)
        return syncState
    }

    private func fromDict(_ dict: [String: Any]) {
        syncId = (dict[kSFSyncStateId] as? NSNumber)?.intValue ?? 0
        type = SFSyncState.syncType(fromString: dict[kSFSyncStateType] as? String ?? "")
        name = dict[kSFSyncStateName] as? String
        if type == .down {
            target = SFSyncDownTarget.newFromDict((dict[kSFSyncStateTarget] as? [String: Any] ?? [:]) as NSDictionary) ?? SFSyncDownTarget()
        } else {
            target = SFSyncUpTarget.newFromDict((dict[kSFSyncStateTarget] as? [String: Any] ?? [:]) as NSDictionary) ?? SFSyncUpTarget()
        }
        if let optionsDict = dict[kSFSyncStateOptions] as? [String: Any] {
            options = SFSyncOptions.new(fromDict: optionsDict)
        } else {
            options = nil
        }
        soupName = dict[kSFSyncStateSoupName] as? String ?? ""
        _status = SFSyncState.syncStatus(fromString: dict[kSFSyncStateStatus] as? String)
        progress = (dict[kSFSyncStateProgress] as? NSNumber)?.intValue ?? 0
        totalSize = (dict[kSFSyncStateTotalSize] as? NSNumber)?.intValue ?? 0
        maxTimeStamp = (dict[kSFSyncStateMaxTimeStamp] as? NSNumber)?.int64Value ?? 0
        startTime = (dict[kSFSyncStateStartTime] as? NSNumber)?.intValue ?? 0
        endTime = (dict[kSFSyncStateEndTime] as? NSNumber)?.intValue ?? 0
        error = dict[kSFSyncStateError] as? String
    }

    @objc public func asDict() -> [String: Any] {
        var dict = [String: Any]()
        dict[SmartStoreSoupEntryId] = NSNumber(value: syncId)
        dict[kSFSyncStateType] = SFSyncState.syncTypeToString(type)
        if let name = name { dict[kSFSyncStateName] = name }
        dict[kSFSyncStateTarget] = target.asDict()
        if let options = options { dict[kSFSyncStateOptions] = options.asDict() }
        dict[kSFSyncStateSoupName] = soupName
        dict[kSFSyncStateStatus] = SFSyncState.syncStatusToString(status)
        dict[kSFSyncStateProgress] = NSNumber(value: progress)
        dict[kSFSyncStateTotalSize] = NSNumber(value: totalSize)
        dict[kSFSyncStateMaxTimeStamp] = NSNumber(value: maxTimeStamp)
        dict[kSFSyncStateStartTime] = NSNumber(value: startTime)
        dict[kSFSyncStateEndTime] = NSNumber(value: endTime)
        dict[kSFSyncStateError] = error ?? ""
        return dict
    }

    // MARK: - Easy status check

    @objc public func isDone() -> Bool { return status == .done }
    @objc public func hasFailed() -> Bool { return status == .failed }
    @objc public func isRunning() -> Bool { return status == .running }
    @objc public func isStopped() -> Bool { return status == .stopped }

    // MARK: - Enum to/from string helpers

    @objc public class func syncType(fromString syncType: String) -> SFSyncStateSyncType {
        if syncType == kSFSyncStateTypeDown { return .down }
        return .up
    }

    @objc public class func syncTypeToString(_ syncType: SFSyncStateSyncType) -> String {
        switch syncType {
        case .down: return kSFSyncStateTypeDown
        case .up: return kSFSyncStateTypeUp
        @unknown default: return kSFSyncStateTypeUp
        }
    }

    @objc public class func syncStatus(fromString syncStatus: String?) -> SFSyncStateStatus {
        guard let syncStatus = syncStatus else { return .failed }
        if syncStatus == kSFSyncStateStatusNew { return .new }
        if syncStatus == kSFSyncStateStatusStopped { return .stopped }
        if syncStatus == kSFSyncStateStatusRunning { return .running }
        if syncStatus == kSFSyncStateStatusDone { return .done }
        return .failed
    }

    @objc public class func syncStatusToString(_ syncStatus: SFSyncStateStatus) -> String {
        switch syncStatus {
        case .new: return kSFSyncStateStatusNew
        case .stopped: return kSFSyncStateStatusStopped
        case .running: return kSFSyncStateStatusRunning
        case .done: return kSFSyncStateStatusDone
        case .failed: return kSFSyncStateStatusFailed
        @unknown default: return kSFSyncStateStatusFailed
        }
    }

    @objc public class func mergeMode(fromString mergeMode: String) -> SFSyncStateMergeMode {
        if mergeMode == kSFSyncStateMergeModeLeaveIfChanged { return .leaveIfChanged }
        return .overwrite
    }

    @objc public class func mergeModeToString(_ mergeMode: SFSyncStateMergeMode) -> String {
        switch mergeMode {
        case .leaveIfChanged: return kSFSyncStateMergeModeLeaveIfChanged
        case .overwrite: return kSFSyncStateMergeModeOverwrite
        @unknown default: return kSFSyncStateMergeModeOverwrite
        }
    }

    // MARK: - Description

    open override var description: String {
        return SFJsonUtils.jsonRepresentation(asDict()) ?? ""
    }

    // MARK: - NSCopying

    public func copy(with zone: NSZone? = nil) -> Any {
        let clone = SFSyncState()
        clone.fromDict(asDict())
        return clone
    }
}
