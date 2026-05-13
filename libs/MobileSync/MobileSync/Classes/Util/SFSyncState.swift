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

// soups and soup fields
// @objc(SFSyncStateSyncsSoupName)
public let kSFSyncStateSyncsSoupName = "syncs_soup"

// @objc(SFSyncStateSyncsSoupSyncType)
public let kSFSyncStateSyncsSoupSyncType = "type"

// Fields in dict representation
// @objc(SFSyncStateId)
public let kSFSyncStateId = "_soupEntryId"

// @objc(SFSyncStateName)
public let kSFSyncStateName = "name"

// @objc(SFSyncStateType)
public let kSFSyncStateType = "type"

// @objc(SFSyncStateTarget)
public let kSFSyncStateTarget = "target"

// @objc(SFSyncStateSoupName)
public let kSFSyncStateSoupName = "soupName"

// @objc(SFSyncStateOptions)
public let kSFSyncStateOptions = "options"

// @objc(SFSyncStateStatus)
public let kSFSyncStateStatus = "status"

// @objc(SFSyncStateProgress)
public let kSFSyncStateProgress = "progress"

// @objc(SFSyncStateTotalSize)
public let kSFSyncStateTotalSize = "totalSize"

// @objc(SFSyncStateMaxTimeStamp)
public let kSFSyncStateMaxTimeStamp = "maxTimeStamp"

// @objc(SFSyncStateStartTime)
public let kSFSyncStateStartTime = "startTime"

// @objc(SFSyncStateEndTime)
public let kSFSyncStateEndTime = "endTime"

// @objc(SFSyncStateError)
public let kSFSyncStateError = "error"

// Possible values for sync type
@objc(SFSyncStateSyncType)
public enum SyncType: Int {
    case down
    case up
}

// @objc(SFSyncStateTypeDown)
public let kSFSyncStateTypeDown = "syncDown"

// @objc(SFSyncStateTypeUp)
public let kSFSyncStateTypeUp = "syncUp"

// Possible value for sync status
@objc(SFSyncStateStatus)
public enum SyncStatus: Int {
    case new
    case stopped
    case running
    case done
    case failed
}

// @objc(SFSyncStateStatusNew)
public let kSFSyncStateStatusNew = "NEW"

// @objc(SFSyncStateStatusStopped)
public let kSFSyncStateStatusStopped = "STOPPED"

// @objc(SFSyncStateStatusRunning)
public let kSFSyncStateStatusRunning = "RUNNING"

// @objc(SFSyncStateStatusDone)
public let kSFSyncStateStatusDone = "DONE"

// @objc(SFSyncStateStatusFailed)
public let kSFSyncStateStatusFailed = "FAILED"

// Possible value for merge mode
@objc(SFSyncStateMergeMode)
public enum SyncMergeMode: Int {
    case overwrite
    case leaveIfChanged
}

// Type alias for backward compatibility
public typealias SyncStateMergeMode = SyncMergeMode

public let kSFSyncStateMergeModeOverwrite = "OVERWRITE"
public let kSFSyncStateMergeModeLeaveIfChanged = "LEAVE_IF_CHANGED"

@objc(SFSyncState)
public class SyncState: NSObject, NSCopying {

    @objc public private(set) var syncId: Int = 0
    @objc public private(set) var name: String?
    @objc public private(set) var type: SyncType = .down
    @objc public private(set) var soupName: String = ""
    @objc public private(set) var target: SyncTarget?
    @objc public private(set) var options: SyncOptions?
    @objc public var status: SyncStatus = .new {
        didSet {
            if oldValue != .running && status == .running {
                startTime = Int(Date().timeIntervalSince1970 * 1000) // milliseconds expected
            }
            if oldValue == .running && (status == .done || status == .failed) {
                endTime = Int(Date().timeIntervalSince1970 * 1000) // milliseconds expected
            }
        }
    }
    @objc public var progress: Int = 0
    @objc public var totalSize: Int = 0
    @objc public var mergeMode: SyncMergeMode {
        get {
            return options?.mergeMode ?? .overwrite
        }
    }
    @objc public var maxTimeStamp: Int64 = 0

    // Start and end time in milliseconds since 1970
    @objc public private(set) var startTime: Int = 0
    @objc public private(set) var endTime: Int = 0

    // Error JSON string
    @objc public var error: String?

    // MARK: - Setup

    /** Setup soup that keeps track of sync operations */
    // @objc(setupSyncsSoupIfNeeded:)
    public static func setupSyncsSoupIfNeeded(_ store: SmartStore) {
        if store.soupExists(forName: kSFSyncStateSyncsSoupName) && store.indices(forSoupNamed: kSFSyncStateSyncsSoupName).count == 3 {
            return
        }

        let indexSpecs = [
            SoupIndex(path: kSFSyncStateSyncsSoupSyncType, indexType: kSoupIndexTypeJSON1, columnName: nil),
            SoupIndex(path: "name", indexType: kSoupIndexTypeJSON1, columnName: nil),
            SoupIndex(path: kSFSyncStateStatus, indexType: kSoupIndexTypeJSON1, columnName: nil)
        ]

        // Syncs soup exists but doesn't have all the required indexes
        if store.soupExists(forName: kSFSyncStateSyncsSoupName) {
            try? store.alterSoup(named: kSFSyncStateSyncsSoupName, indexSpecs: indexSpecs.compactMap { $0 }, reIndexData: true) // reindexing to json1 is quick
        }
        // Syncs soup does not exist
        else {
            try? store.registerSoup(withName: kSFSyncStateSyncsSoupName, withIndices: indexSpecs.compactMap { $0 })
        }
    }

    /**
     * Cleanup syncs soup if needed
     * At startup, no sync could be running already
     * If a sync is in the running state, we change it to stopped
     */
    // @objc(cleanupSyncsSoupIfNeeded:)
    public static func cleanupSyncsSoupIfNeeded(_ store: SmartStore) {
        let syncs = getSyncs(with: store, status: .running)
        for sync in syncs {
            sync.status = .stopped
            sync.save(store)
        }
    }

    // @objc(getSyncsWithStatus:status:)
    public static func getSyncs(with store: SmartStore, status: SyncStatus) -> [SyncState] {
        var syncs: [SyncState] = []
        let smartSql = "select {\(kSFSyncStateSyncsSoupName):_soup} from {\(kSFSyncStateSyncsSoupName)} where {\(kSFSyncStateSyncsSoupName):\(kSFSyncStateStatus)} = '\(syncStatusToString(status))'"
        guard let query = QuerySpec.buildSmartQuerySpec(smartSql: smartSql, pageSize: UInt(INT_MAX)) else {
            return syncs
        }

        do {
            let rows = try store.query(using: query, startingFromPageIndex: 0)
            for row in rows {
                if let rowArray = row as? [Any], let dict = rowArray.first as? [String: Any],
                   let sync = SyncState.build(dict: dict) {
                    syncs.append(sync)
                }
            }
        } catch {
            // Ignore error
        }

        return syncs
    }

    // MARK: - Factory methods

    /** Factory methods */
    // @objc(newSyncDownWithOptions:target:soupName:name:store:)
    public static func buildSyncDown(options: SyncOptions, target: SyncDownTarget, soupName: String, name: String?, store: SmartStore) -> SyncState? {
        var dict: [String: Any] = [
            kSFSyncStateType: kSFSyncStateTypeDown,
            kSFSyncStateTarget: target.asDict(),
            kSFSyncStateSoupName: soupName,
            kSFSyncStateOptions: options.asDict(),
            kSFSyncStateStatus: kSFSyncStateStatusNew,
            kSFSyncStateMaxTimeStamp: -1,
            kSFSyncStateProgress: 0,
            kSFSyncStateTotalSize: -1,
            kSFSyncStateStartTime: 0,
            kSFSyncStateEndTime: 0,
            kSFSyncStateError: ""
        ]
        if let name = name {
            dict[kSFSyncStateName] = name
        }

        if let name = name, byName(name, store: store) != nil {
            SFSDKMobileSyncLogger.e(SyncState.self, message: "Failed to create sync down: there is already a sync with name:\(name)")
            return nil
        }

        do {
            let savedDicts = try store.upsert(entries: [dict as NSDictionary], forSoupNamed: kSFSyncStateSyncsSoupName)
            if let firstDict = savedDicts.first as? [String: Any] {
                return SyncState.build(dict: firstDict)
            }
        } catch {
            // Ignore error
        }

        return nil
    }

    // @objc(newSyncUpWithOptions:soupName:store:)
    public static func buildSyncUp(options: SyncOptions, soupName: String, store: SmartStore) -> SyncState? {
        let target = SyncUpTarget.newFromDict(nil)
        return buildSyncUp(options: options, target: target, soupName: soupName, name: nil, store: store)
    }

    // @objc(newSyncUpWithOptions:target:soupName:name:store:)
    public static func buildSyncUp(options: SyncOptions, target: SyncUpTarget?, soupName: String, name: String?, store: SmartStore) -> SyncState? {
        guard let target = target else { return nil }
        var dict: [String: Any] = [
            kSFSyncStateType: kSFSyncStateTypeUp,
            kSFSyncStateTarget: target.asDict(),
            kSFSyncStateSoupName: soupName,
            kSFSyncStateOptions: options.asDict(),
            kSFSyncStateStatus: kSFSyncStateStatusNew,
            kSFSyncStateProgress: 0,
            kSFSyncStateTotalSize: -1,
            kSFSyncStateStartTime: 0,
            kSFSyncStateEndTime: 0,
            kSFSyncStateError: ""
        ]
        if let name = name {
            dict[kSFSyncStateName] = name
        }

        if let name = name, byName(name, store: store) != nil {
            SFSDKMobileSyncLogger.e(SyncState.self, message: "Failed to create sync up: there is already a sync with name:\(name)")
            return nil
        }

        do {
            let savedDicts = try store.upsert(entries: [dict as NSDictionary], forSoupNamed: kSFSyncStateSyncsSoupName)
            if savedDicts.isEmpty {
                return nil
            }
            if let firstDict = savedDicts.first as? [String: Any] {
                return SyncState.build(dict: firstDict)
            }
        } catch {
            // Ignore error
        }

        return nil
    }

    // MARK: - Save/retrieve/delete to/from smartstore

    /** Methods to save/retrieve/delete from smartstore */
    // @objc(byId:store:)
    public static func byId(_ syncId: NSNumber, store: SmartStore) -> SyncState? {
        do {
            let retrievedDicts = try store.retrieve(usingSoupEntryIds: [syncId], fromSoupNamed: kSFSyncStateSyncsSoupName)
            if retrievedDicts.isEmpty {
                return nil
            }
            if let firstDict = retrievedDicts.first as? [String: Any] {
                return SyncState.build(dict: firstDict)
            }
        } catch {
            // Ignore error
        }
        return nil
    }

    // @objc(byName:store:)
    public static func byName(_ name: String, store: SmartStore) -> SyncState? {
        do {
            let syncId = try store.lookupSoupEntryId(soupNamed: kSFSyncStateSyncsSoupName, fieldPath: "name", fieldValue: name)
            if let syncId = syncId {
                return byId(syncId, store: store)
            }
        } catch {
            // Ignore error
        }
        return nil
    }

    // @objc(save:)
    public func save(_ store: SmartStore) {
        do {
            _ = try store.upsert(entries: [asDict() as NSDictionary], forSoupNamed: kSFSyncStateSyncsSoupName)
        } catch {
            // Ignore error
        }
    }

    // @objc(deleteById:store:)
    public static func delete(syncId: NSNumber, store: SmartStore) {
        do {
            try store.remove(entryIds: [syncId], forSoupNamed: kSFSyncStateSyncsSoupName)
        } catch {
            // Ignore error
        }
    }

    // @objc(deleteByName:store:)
    public static func delete(syncName: String, store: SmartStore) {
        do {
            let syncId = try store.lookupSoupEntryId(soupNamed: kSFSyncStateSyncsSoupName, fieldPath: "name", fieldValue: syncName)
            if let syncId = syncId {
                delete(syncId: syncId, store: store)
            }
        } catch {
            // Ignore error
        }
    }

    // MARK: - From/to dictionary

    /** Methods to translate to/from dictionary */
    // @objc(newFromDict:)
    public static func build(dict: [String: Any]) -> SyncState? {
        let syncState = SyncState()
        syncState.fromDict(dict)
        return syncState
    }

    private func fromDict(_ dict: [String: Any]) {
        if let id = dict[kSFSyncStateId] as? NSNumber {
            self.syncId = id.intValue
        }
        if let typeString = dict[kSFSyncStateType] as? String {
            self.type = SyncState.syncType(fromString: typeString)
        }
        self.name = dict[kSFSyncStateName] as? String

        if let targetDict = dict[kSFSyncStateTarget] as? [String: Any] {
            self.target = (self.type == .down
                          ? SyncDownTarget.newFromDict(targetDict)
                          : SyncUpTarget(dict: targetDict))
        }

        if let optionsDict = dict[kSFSyncStateOptions] as? [String: Any] {
            self.options = SyncOptions.newFromDict(optionsDict)
        }

        self.soupName = dict[kSFSyncStateSoupName] as? String ?? ""

        if let statusString = dict[kSFSyncStateStatus] as? String {
            self.status = SyncState.syncStatus(fromString: statusString)
        }

        if let progress = dict[kSFSyncStateProgress] as? NSNumber {
            self.progress = progress.intValue
        }
        if let totalSize = dict[kSFSyncStateTotalSize] as? NSNumber {
            self.totalSize = totalSize.intValue
        }
        if let maxTimeStamp = dict[kSFSyncStateMaxTimeStamp] as? NSNumber {
            self.maxTimeStamp = maxTimeStamp.int64Value
        }
        if let startTime = dict[kSFSyncStateStartTime] as? NSNumber {
            self.startTime = startTime.intValue
        }
        if let endTime = dict[kSFSyncStateEndTime] as? NSNumber {
            self.endTime = endTime.intValue
        }
        self.error = dict[kSFSyncStateError] as? String
    }

    @objc
    public func asDict() -> [String: Any] {
        var dict: [String: Any] = [:]
        dict[SOUP_ENTRY_ID] = NSNumber(value: syncId)
        dict[kSFSyncStateType] = SyncState.syncTypeToString(type)
        if let name = name {
            dict[kSFSyncStateName] = name
        }
        if let target = target {
            dict[kSFSyncStateTarget] = target.asDict()
        }
        if let options = options {
            dict[kSFSyncStateOptions] = options.asDict()
        }
        dict[kSFSyncStateSoupName] = soupName
        dict[kSFSyncStateStatus] = SyncState.syncStatusToString(status)
        dict[kSFSyncStateProgress] = NSNumber(value: progress)
        dict[kSFSyncStateTotalSize] = NSNumber(value: totalSize)
        dict[kSFSyncStateMaxTimeStamp] = NSNumber(value: maxTimeStamp)
        dict[kSFSyncStateStartTime] = NSNumber(value: startTime)
        dict[kSFSyncStateEndTime] = NSNumber(value: endTime)
        dict[kSFSyncStateError] = error ?? ""
        return dict
    }

    // MARK: - Easy status check

    /** Method for easy status check */
    @objc
    public func isDone() -> Bool {
        return status == .done
    }

    @objc
    public func hasFailed() -> Bool {
        return status == .failed
    }

    @objc
    public func isRunning() -> Bool {
        return status == .running
    }

    @objc
    public func isStopped() -> Bool {
        return status == .stopped
    }

    // MARK: - Enum to/from string helper methods

    /** Enum to/from string helper methods */
    // @objc(syncTypeFromString:)
    public static func syncType(fromString syncType: String) -> SyncType {
        if syncType == kSFSyncStateTypeDown {
            return .down
        }
        // Must be up
        return .up
    }

    // @objc(syncTypeToString:)
    public static func syncTypeToString(_ syncType: SyncType) -> String {
        switch syncType {
        case .down: return kSFSyncStateTypeDown
        case .up: return kSFSyncStateTypeUp
        }
    }

    // @objc(syncStatusFromString:)
    public static func syncStatus(fromString syncStatus: String?) -> SyncStatus {
        guard let syncStatus = syncStatus else { return .failed }

        if syncStatus == kSFSyncStateStatusNew {
            return .new
        }
        if syncStatus == kSFSyncStateStatusStopped {
            return .stopped
        }
        if syncStatus == kSFSyncStateStatusRunning {
            return .running
        }
        if syncStatus == kSFSyncStateStatusDone {
            return .done
        }
        return .failed
    }

    // @objc(syncStatusToString:)
    public static func syncStatusToString(_ syncStatus: SyncStatus) -> String {
        switch syncStatus {
        case .new: return kSFSyncStateStatusNew
        case .stopped: return kSFSyncStateStatusStopped
        case .running: return kSFSyncStateStatusRunning
        case .done: return kSFSyncStateStatusDone
        case .failed: return kSFSyncStateStatusFailed
        }
    }

    // @objc(mergeModeFromString:)
    public static func mergeMode(fromString mergeMode: String) -> SyncMergeMode {
        if mergeMode == kSFSyncStateMergeModeLeaveIfChanged {
            return .leaveIfChanged
        }
        return .overwrite
    }

    // @objc(mergeModeToString:)
    public static func mergeModeToString(_ mergeMode: SyncMergeMode) -> String {
        switch mergeMode {
        case .leaveIfChanged: return kSFSyncStateMergeModeLeaveIfChanged
        case .overwrite: return kSFSyncStateMergeModeOverwrite
        }
    }

    // MARK: - NSObject

    public override var description: String {
        return SFJsonUtils.jsonRepresentation(asDict()) ?? ""
    }

    // MARK: - NSCopying

    public func copy(with zone: NSZone? = nil) -> Any {
        let clone = SyncState()
        clone.fromDict(asDict())
        return clone
    }

    // MARK: - Convenience Wrappers for Manager

    public static func setupSyncsSoupIfNeeded(store: SmartStore) {
        setupSyncsSoupIfNeeded(store)
    }

    public static func cleanupSyncsSoupIfNeeded(store: SmartStore) {
        cleanupSyncsSoupIfNeeded(store)
    }

    public static func byId(syncId: NSNumber, store: SmartStore) -> SyncState? {
        return byId(syncId, store: store)
    }

    public static func byName(syncName: String, store: SmartStore) -> SyncState? {
        return byName(syncName, store: store)
    }

    public static func deleteSync(syncId: NSNumber, store: SmartStore) {
        delete(syncId: syncId, store: store)
    }

    public static func deleteSync(syncName: String, store: SmartStore) {
        delete(syncName: syncName, store: store)
    }
}
