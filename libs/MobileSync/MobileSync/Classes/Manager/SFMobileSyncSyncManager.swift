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
import SalesforceSDKCore

// Block types
public typealias SFSyncSyncManagerUpdateBlock = (SFSyncState) -> Void
public typealias SFSyncSyncManagerCompletionStatusBlock = (SFSyncStateStatus, UInt) -> Void

// Sync manager state
@objc
public enum SFSyncManagerState: Int {
    case acceptingSyncs = 0
    case stopRequested
    case stopped
}

// State string constants
public let kSFSyncManagerStateAcceptingSyncs = "accepting_syncs"
public let kSFSyncManagerStateStopRequested = "stop_requested"
public let kSFSyncManagerStateStopped = "stopped"

// Error constants
public let kSFMobileSyncErrorDomain = "com.salesforce.MobileSync.ErrorDomain"
public let kSFSyncManagerStoppedError = "SyncManagerStoppedError"
public let kSFSyncManagerCannotRestartError = "SyncManagerCannotRestartError"
public let kSFSyncAlreadyRunningError = "SyncAlreadyRunningError"
public let kSFSyncNotExistError = "SyncNotExistError"
public let kSFSyncManagerCanOnlyRunCleanGhostsForSyncDown = "SyncManagerCanOnlyRunCleanGhostsForSyncDown"

public let kSFSyncManagerStoppedErrorCode: Int = 900
public let kSFSyncManagerCannotRestartErrorCode: Int = 901
public let kSFSyncAlreadyRunningErrorCode: Int = 902
public let kSFSyncNotExistErrorCode: Int = 903
public let kSFSyncManagerCanOnlyRunCleanGhostsForSyncDownCode: Int = 904

private let kSFAppFeatureMobileSync = "SY"
private let kSyncManagerQueueLabel = "com.salesforce.mobilesync.manager.syncmanager.QUEUE"

@objc(SFMobileSyncSyncManager)
@objcMembers
open class SFMobileSyncSyncManager: NSObject {

    open private(set) var store: SFSmartStore
    private var queue: DispatchQueue
    private var activeSyncs = [NSNumber: SFSyncTask]()
    private var state: SFSyncManagerState = .acceptingSyncs {
        didSet {
            if oldValue != state {
                SFSDKMobileSyncLogger.d(type(of: self), message: "state changing from \(SFMobileSyncSyncManager.stateToString(oldValue)) to \(SFMobileSyncSyncManager.stateToString(state))")
            }
        }
    }

    private static var syncMgrList = NSMutableDictionary()
    private static let lock = NSRecursiveLock()

    // MARK: - Instance access / cleanup

    @objc(sharedInstance:)
    open class func sharedInstance(forUserAccount user: SFUserAccount) -> SFMobileSyncSyncManager? {
        return sharedInstanceForUser(user, storeName: nil)
    }

    @objc
    open class func sharedInstanceForUser(_ user: SFUserAccount, storeName: String?) -> SFMobileSyncSyncManager? {
        return sharedInstance(named: storeName, forUserAccount: user)
    }

    @objc(sharedInstance:forUserAccount:)
    open class func sharedInstance(named storeName: String?, forUserAccount userAccount: SFUserAccount) -> SFMobileSyncSyncManager? {
        guard userAccount != nil else { return nil }
        let effectiveStoreName = (storeName?.isEmpty == false) ? storeName ?? SmartStoreConstants.defaultStoreName : SmartStoreConstants.defaultStoreName
        guard let store = SmartStore.shared(withName: effectiveStoreName, forUserAccount: userAccount) else { return nil }
        return sharedInstance(store: store)
    }

    @objc(sharedInstanceForStore:)
    open class func sharedInstance(store: SFSmartStore) -> SFMobileSyncSyncManager? {
        lock.lock()
        defer { lock.unlock() }

        guard store.path != nil else { return nil }
        let key = keyForStore(store)
        if let existing = syncMgrList[key] as? SFMobileSyncSyncManager {
            SFSDKAppFeatureMarkers.registerAppFeature(kSFAppFeatureMobileSync)
            return existing
        }
        if let user = store.userAccount, user.loginState != .loggedIn {
            SFSDKMobileSyncLogger.w(self, message: "\(#function) A user account must be in the SFUserAccountLoginStateLoggedIn state in order to create a sync for a user store.")
            return nil
        }
        let syncMgr = self.init(store: store)
        syncMgrList[key] = syncMgr
        SFSDKAppFeatureMarkers.registerAppFeature(kSFAppFeatureMobileSync)
        return syncMgr
    }

    @objc
    open class func removeSharedInstance(_ user: SFUserAccount) {
        for key in syncMgrList.allKeys {
            if let keyStr = key as? String, isUserRelatedSync(keyStr, user: user) {
                removeSharedInstance(forKey: keyStr)
            }
        }
    }

    @objc
    open class func removeSharedInstanceForUser(_ user: SFUserAccount, storeName: String?) {
        removeSharedInstance(named: storeName, forUserAccount: user)
    }

    @objc(removeSharedInstance:forUserAccount:)
    open class func removeSharedInstance(named storeName: String?, forUserAccount userAccount: SFUserAccount) {
        guard userAccount != nil else { return }
        let effectiveStoreName = (storeName?.isEmpty == false) ? storeName ?? SmartStoreConstants.defaultStoreName : SmartStoreConstants.defaultStoreName
        let key = keyForUser(userAccount, storeName: effectiveStoreName)
        removeSharedInstance(forKey: key)
    }

    @objc(removeSharedInstanceForStore:)
    open class func removeSharedInstance(store: SFSmartStore) {
        let key = keyForStore(store)
        removeSharedInstance(forKey: key)
    }

    private class func removeSharedInstance(forKey key: String) {
        lock.lock()
        defer { lock.unlock() }
        syncMgrList.removeObject(forKey: key)
    }

    @objc
    open class func removeSharedInstances() {
        lock.lock()
        defer { lock.unlock() }
        syncMgrList.removeAllObjects()
    }

    // MARK: - Key helpers

    private class func keyForStore(_ store: SFSmartStore) -> String {
        return keyForUser(store.userAccount, storeName: store.name)
    }

    private class func keyForUser(_ user: SFUserAccount?, storeName: String) -> String {
        let keyPrefix: String
        if let user = user {
            keyPrefix = SFKeyForUserAndScope(user, .community) ?? ""
        } else {
            keyPrefix = SFKeyForUserAndScope(nil, .global) ?? ""
        }
        return "\(keyPrefix)-\(storeName)"
    }

    private class func isUserRelatedSync(_ key: String, user: SFUserAccount) -> Bool {
        let userPrefix = SFKeyForUserAndScope(user, .community) ?? ""
        return key.contains(userPrefix)
    }

    // MARK: - init

    public required init(store: SFSmartStore) {
        self.store = store
        self.queue = DispatchQueue(label: kSyncManagerQueueLabel)
        self.state = .acceptingSyncs
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(handleUserWillLogout(_:)), name: UserAccountManager.willLogoutUser, object: nil)
        SFSyncState.setupSyncsSoupIfNeeded(self.store)
        SFSyncState.cleanupSyncsSoupIfNeeded(self.store)
    }

    // MARK: - Stop / restart

    @objc
    open func stop() {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        if activeSyncs.isEmpty {
            self.state = .stopped
        } else {
            self.state = .stopRequested
        }
    }

    @objc
    open func isStopping() -> Bool {
        return self.state == .stopRequested
    }

    @objc
    open func isStopped() -> Bool {
        return self.state == .stopped
    }


    open func restart(restartStoppedSyncs: Bool, updateBlock: @escaping SFSyncSyncManagerUpdateBlock) throws -> Bool {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        if isStopped() || isStopping() {
            self.state = .acceptingSyncs
            if restartStoppedSyncs {
                let stoppedSyncs = SFSyncState.getSyncs(withStatus: self.store, status: .stopped)
                for sync in stoppedSyncs {
                    SFSDKMobileSyncLogger.d(type(of: self), message: "restarting \(sync.syncId)")
                    try reSync(id: NSNumber(value: sync.syncId), onUpdate: updateBlock)
                }
            }
            return true
        } else {
            let description = "restart() called on a sync manager that has state: \(SFMobileSyncSyncManager.stateToString(self.state))"
            throw makeError(type: kSFSyncManagerCannotRestartError, code: kSFSyncManagerCannotRestartErrorCode, description: description)
        }
    }

    @objc
    open func addToActiveSyncs(_ syncTask: SFSyncTask) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        activeSyncs[syncTask.syncId] = syncTask
    }

    @objc
    open func removeFromActiveSyncs(_ syncTask: SFSyncTask) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        activeSyncs.removeValue(forKey: syncTask.syncId)
        if self.state == .stopRequested && activeSyncs.isEmpty {
            self.state = .stopped
        }
    }

    // MARK: - Check methods

    @objc
    open func checkAcceptingSyncs(_ error: NSErrorPointer) -> Bool {
        if self.state != .acceptingSyncs {
            let message = "sync manager has state \(SFMobileSyncSyncManager.stateToString(self.state))"
            if let error = error {
                error.pointee = makeError(type: kSFSyncManagerStoppedError, code: kSFSyncManagerStoppedErrorCode, description: message)
            }
            return false
        }
        return true
    }

    private func checkNotRunning(_ syncId: NSNumber, error: NSErrorPointer) -> Bool {
        if activeSyncs[syncId] != nil {
            let message = "sync \(syncId) is still running"
            if let error = error {
                error.pointee = makeError(type: kSFSyncAlreadyRunningError, code: kSFSyncAlreadyRunningErrorCode, description: message)
            }
            return false
        }
        return true
    }

    private func checkExistsById(_ syncId: NSNumber, error: NSErrorPointer) -> SFSyncState? {
        let sync = getSyncStatus(syncId)
        if sync == nil {
            let message = "Sync \(syncId) does not exist"
            if let error = error {
                error.pointee = makeError(type: kSFSyncNotExistError, code: kSFSyncNotExistErrorCode, description: message)
            }
        }
        return sync
    }

    private func checkExistsByName(_ syncName: String, error: NSErrorPointer) -> SFSyncState? {
        let sync = getSyncStatusByName(syncName)
        if sync == nil {
            let message = "Sync \(syncName) does not exist"
            if let error = error {
                error.pointee = makeError(type: kSFSyncNotExistError, code: kSFSyncNotExistErrorCode, description: message)
            }
        }
        return sync
    }

    private func makeError(type: String, code: Int, description: String) -> NSError {
        SFSDKMobileSyncLogger.e(Swift.type(of: self), message: "\(type): \(description)")
        return NSError(domain: kSFMobileSyncErrorDomain, code: code, userInfo: ["error": type, "description": description])
    }

    // MARK: - Get / has / delete sync

    @objc(syncStatus:)
    open func getSyncStatus(_ syncId: NSNumber) -> SFSyncState? {
        let sync = SFSyncState.by(id: syncId, store: self.store)
        if sync == nil {
            SFSDKMobileSyncLogger.d(type(of: self), message: "Sync \(syncId) not found")
        }
        return sync
    }

    @objc(syncStatusForName:)
    open func getSyncStatusByName(_ syncName: String) -> SFSyncState? {
        let sync = SFSyncState.by(name:syncName, store: self.store)
        if sync == nil {
            SFSDKMobileSyncLogger.d(type(of: self), message: "Sync \(syncName) not found")
        }
        return sync
    }

    @objc(hasSync:)
    open func hasSyncWithName(_ syncName: String) -> Bool {
        return SFSyncState.by(name:syncName, store: self.store) != nil
    }

    @objc(deleteSync:)
    open func deleteSyncById(_ syncId: NSNumber) {
        SFSyncState.delete(byId: syncId, store: self.store)
    }

    @objc(deleteSyncByName:)
    open func deleteSyncByName(_ syncName: String) {
        SFSyncState.delete(byName: syncName, store: self.store)
    }

    // MARK: - Run sync

    private func runSync(_ sync: SFSyncState, updateBlock: @escaping SFSyncSyncManagerUpdateBlock) {
        var task: SFSyncTask
        switch sync.type {
        case .down:
            task = SFSyncDownTask(self, sync: sync, updateBlock: updateBlock)
        case .up:
            if sync.target.conforms(to: SFAdvancedSyncUpTarget.self) {
                task = SFAdvancedSyncUpTask(self, sync: sync, updateBlock: updateBlock)
            } else {
                task = SFSyncUpTask(self, sync: sync, updateBlock: updateBlock)
            }
        @unknown default:
            return
        }
        queue.async {
            task.run()
        }
    }

    // MARK: - Sync down

    @objc(syncDown:soupName:onUpdate:)
    open func syncDownWithTarget(_ target: SFSyncDownTarget, soupName: String, updateBlock: @escaping SFSyncSyncManagerUpdateBlock) -> SFSyncState? {
        let options = SFSyncOptions.newSyncOptions(forSyncDown: .overwrite)
        return syncDownWithTarget(target, options: options, soupName: soupName, updateBlock: updateBlock)
    }

    @objc(syncDown:options:soupName:onUpdate:)
    open func syncDownWithTarget(_ target: SFSyncDownTarget, options: SFSyncOptions, soupName: String, updateBlock: @escaping SFSyncSyncManagerUpdateBlock) -> SFSyncState? {
        return try? syncDownWithTarget(target, options: options, soupName: soupName, syncName: nil, updateBlock: updateBlock)
    }


    open func syncDownWithTarget(_ target: SFSyncDownTarget, options: SFSyncOptions, soupName: String, syncName: String?, updateBlock: @escaping SFSyncSyncManagerUpdateBlock) throws -> SFSyncState? {
        var err: NSError?
        guard checkAcceptingSyncs(&err) else {
            if let err = err { throw err }
            return nil
        }
        let sync = createSyncDown(target, options: options, soupName: soupName, syncName: syncName)
        runSync(sync, updateBlock: updateBlock)
        return sync.copy() as? SFSyncState
    }

    @objc
    @discardableResult
    open func createSyncDown(_ target: SFSyncDownTarget, options: SFSyncOptions, soupName: String, syncName: String?) -> SFSyncState {
        let sync = SFSyncState.newSyncDown(withOptions: options, target: target, soupName: soupName, name: syncName, store: self.store)!
        SFSDKMobileSyncLogger.d(type(of: self), message: "Created syncDown:\(sync)")
        return sync
    }

    // MARK: - ReSync


    open func reSync(id syncId: NSNumber, onUpdate updateBlock: @escaping SFSyncSyncManagerUpdateBlock) throws -> SFSyncState? {
        var err: NSError?
        guard let sync = checkExistsById(syncId, error: &err) else {
            if let err = err { throw err }
            return nil
        }
        return try reSyncWithSync(sync, updateBlock: updateBlock)
    }


    open func reSync(named syncName: String, onUpdate updateBlock: @escaping SFSyncSyncManagerUpdateBlock) throws -> SFSyncState? {
        var err: NSError?
        guard let sync = checkExistsByName(syncName, error: &err) else {
            if let err = err { throw err }
            return nil
        }
        return try reSyncWithSync(sync, updateBlock: updateBlock)
    }

    private func reSyncWithSync(_ sync: SFSyncState, updateBlock: @escaping SFSyncSyncManagerUpdateBlock) throws -> SFSyncState? {
        var err: NSError?
        guard checkAcceptingSyncs(&err), checkNotRunning(NSNumber(value: sync.syncId), error: &err) else {
            if let err = err { throw err }
            return nil
        }
        sync.totalSize = -1
        if sync.isStopped() {
            sync.maxTimeStamp = sync.maxTimeStamp == -1 ? -1 : sync.maxTimeStamp - 1
        }
        SFSDKMobileSyncLogger.d(type(of: self), message: "reSync:\(sync)")
        runSync(sync, updateBlock: updateBlock)
        return sync.copy() as? SFSyncState
    }

    // MARK: - Sync up

    @objc(syncUp:soupName:onUpdate:)
    open func syncUpWithOptions(_ options: SFSyncOptions, soupName: String, updateBlock: @escaping SFSyncSyncManagerUpdateBlock) -> SFSyncState? {
        return syncUpWithTarget(SFSyncUpTarget.newFromDict(nil), options: options, soupName: soupName, updateBlock: updateBlock)
    }

    @objc(syncUp:options:soupName:onUpdate:)
    open func syncUpWithTarget(_ target: SFSyncUpTarget?, options: SFSyncOptions, soupName: String, updateBlock: @escaping SFSyncSyncManagerUpdateBlock) -> SFSyncState? {
        guard let target = target else { return nil }
        return try? syncUpWithTarget(target, options: options, soupName: soupName, syncName: nil, updateBlock: updateBlock)
    }


    open func syncUpWithTarget(_ target: SFSyncUpTarget, options: SFSyncOptions, soupName: String, syncName: String?, updateBlock: @escaping SFSyncSyncManagerUpdateBlock) throws -> SFSyncState? {
        var err: NSError?
        guard checkAcceptingSyncs(&err) else {
            if let err = err { throw err }
            return nil
        }
        let sync = createSyncUp(target, options: options, soupName: soupName, syncName: syncName)
        runSync(sync, updateBlock: updateBlock)
        return sync.copy() as? SFSyncState
    }

    @objc
    @discardableResult
    open func createSyncUp(_ target: SFSyncUpTarget, options: SFSyncOptions, soupName: String, syncName: String?) -> SFSyncState {
        let sync = SFSyncState.newSyncUp(withOptions: options, target: target, soupName: soupName, name: syncName, store: self.store)!
        SFSDKMobileSyncLogger.d(type(of: self), message: "Created syncUp:\(sync)")
        return sync
    }

    // MARK: - Clean resync ghosts


    open func cleanResyncGhosts(forId syncId: NSNumber, onComplete completionStatusBlock: @escaping SFSyncSyncManagerCompletionStatusBlock) throws -> Bool {
        var err: NSError?
        guard let sync = checkExistsById(syncId, error: &err) else {
            if let err = err { throw err }
            return false
        }
        return try cleanResyncGhostsWithSync(sync, completionStatusBlock: completionStatusBlock)
    }


    open func cleanResyncGhosts(forName syncName: String, onComplete completionStatusBlock: @escaping SFSyncSyncManagerCompletionStatusBlock) throws -> Bool {
        var err: NSError?
        guard let sync = checkExistsByName(syncName, error: &err) else {
            if let err = err { throw err }
            return false
        }
        return try cleanResyncGhostsWithSync(sync, completionStatusBlock: completionStatusBlock)
    }

    private func cleanResyncGhostsWithSync(_ sync: SFSyncState, completionStatusBlock: @escaping SFSyncSyncManagerCompletionStatusBlock) throws -> Bool {
        var err: NSError?
        guard checkAcceptingSyncs(&err), checkNotRunning(NSNumber(value: sync.syncId), error: &err) else {
            if let err = err { throw err }
            return false
        }
        if sync.type != .down {
            let description = "Cannot run cleanResyncGhosts:\(sync.syncId):wrong type:\(SFSyncState.syncTypeToString(sync.type))"
            throw makeError(type: kSFSyncManagerCanOnlyRunCleanGhostsForSyncDown, code: kSFSyncManagerCanOnlyRunCleanGhostsForSyncDownCode, description: description)
        }

        SFSDKMobileSyncLogger.d(type(of: self), message: "cleanResyncGhosts:\(sync)")
        let task = SFCleanSyncGhostsTask(self, sync: sync, completionStatusBlock: completionStatusBlock)
        queue.async {
            task.run()
        }
        return true
    }

    // MARK: - Logout handling

    @objc
    private func handleUserWillLogout(_ notification: Notification) {
        if let user = notification.userInfo?[UserAccountManager.userInfoAccountKey] as? SFUserAccount {
            type(of: self).removeSharedInstance(user)
        }
    }

    // MARK: - State string helpers

    @objc
    open class func stateFromString(_ state: String) -> SFSyncManagerState {
        if state == kSFSyncManagerStateAcceptingSyncs { return .acceptingSyncs }
        if state == kSFSyncManagerStateStopRequested { return .stopRequested }
        return .stopped
    }

    @objc
    open class func stateToString(_ state: SFSyncManagerState) -> String {
        switch state {
        case .acceptingSyncs: return kSFSyncManagerStateAcceptingSyncs
        case .stopRequested: return kSFSyncManagerStateStopRequested
        case .stopped: return kSFSyncManagerStateStopped
        @unknown default: return kSFSyncManagerStateStopped
        }
    }
}
