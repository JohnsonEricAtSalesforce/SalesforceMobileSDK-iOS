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
import SalesforceSDKCore
import SmartStore

// Block types
public typealias SyncUpdateBlock = (SyncState) -> Void
public typealias SyncCompletionBlock = (SyncStatus, UInt) -> Void
public typealias SFSyncSyncManagerUpdateBlock = SyncUpdateBlock

// Backward compatibility typealiases
public typealias SFSyncState = SyncState
public typealias SFSyncDownTarget = SyncDownTarget
public typealias SFSyncUpTarget = SyncUpTarget

// Possible values for sync manager state
public enum SFSyncManagerState: Int {
    case acceptingSyncs
    case stopRequested
    case stopped
}

public let kSFSyncManagerStateAcceptingSyncs = "accepting_syncs"
public let kSFSyncManagerStateStopRequested = "stop_requested"
public let kSFSyncManagerStateStopped = "stopped"

// Errors
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
private let kSyncManagerQueue = "com.salesforce.mobilesync.manager.syncmanager.QUEUE"

/**
 * This class provides methods for syncing records to/from the server from/to the smartstore.
 */
@objc(SFMobileSyncSyncManager)
public class SFMobileSyncSyncManager: NSObject {

    @objc public private(set) var store: SmartStore
    private var queue: DispatchQueue
    private var activeSyncs: [NSNumber: SFSyncTask] = [:]
    private var _state: SFSyncManagerState = .acceptingSyncs
    private let stateLock = NSLock()

    private static var syncMgrList: [String: SFMobileSyncSyncManager] = [:]
    private static let syncMgrListLock = NSLock()

    // MARK: - Instance Access / Cleanup

    /**
     * Singleton method for accessing the sync manager instance for the given user. This instance uses the
     * default store.
     *
     * @param user User to which this manager instance's data is scoped.
     */
    @objc(sharedInstanceForUserAccount:)
    public static func sharedInstance(forUserAccount user: SFUserAccount) -> SFMobileSyncSyncManager? {
        return sharedInstance(named: nil, forUserAccount: user)
    }

    /**
     * Singleton method for accessing a sync manager based on user and store name. This instance uses the store
     * with the given name for the given user.
     * @param storeName Name of the requested store.
     * @param userAccount User associated with the store.
     */
    @objc(sharedInstanceForStore:userAccount:)
    public static func sharedInstance(named storeName: String?, forUserAccount userAccount: SFUserAccount) -> SFMobileSyncSyncManager? {
        guard userAccount.loginState == .loggedIn else { return nil }

        let actualStoreName = storeName?.isEmpty == false ? storeName! : kDefaultSmartStoreName
        guard let store = SmartStore.shared(withName: actualStoreName, forUserAccount: userAccount) else {
            return nil
        }

        return sharedInstance(store: store)
    }

    /**
     * Singleton method for accessing sync manager instance by SmartStore store.
     *
     * @param store SmartStore instance whose sync manager is being requested.
     */
    @objc(sharedInstanceForStore:)
    public static func sharedInstance(store: SmartStore) -> SFMobileSyncSyncManager? {
        syncMgrListLock.lock()
        defer { syncMgrListLock.unlock() }

        let key = self.key(for: store)
        if let syncMgr = syncMgrList[key] {
            SFSDKAppFeatureMarkers.registerAppFeature(kSFAppFeatureMobileSync)
            return syncMgr
        }

        if let user = store.userAccount, user.loginState != .loggedIn {
            SFSDKMobileSyncLogger.w(SFMobileSyncSyncManager.self, message: "A user account must be in the SFUserAccountLoginStateLoggedIn state in order to create a sync for a user store.")
            return nil
        }

        let syncMgr = SFMobileSyncSyncManager(store: store)
        syncMgrList[key] = syncMgr
        SFSDKAppFeatureMarkers.registerAppFeature(kSFAppFeatureMobileSync)
        return syncMgr
    }

    /**
     * Remove the shared instance associated with the given user.
     *
     * @param user User associated with the store.
     */
    @objc(removeSharedInstance:)
    public static func removeSharedInstance(_ user: SFUserAccount) {
        syncMgrListLock.lock()
        defer { syncMgrListLock.unlock() }

        let keysToRemove = syncMgrList.keys.filter { key in
            return isUserRelatedSync(key, user: user)
        }

        for key in keysToRemove {
            syncMgrList.removeValue(forKey: key)
        }
    }

    /**
     * Remove the shared instance associated with the given store name and user.
     * @param storeName Name of the requested store.
     * @param userAccount User associated with the store.
     */
    @objc(removeSharedInstanceForStore:userAccount:)
    public static func removeSharedInstance(named storeName: String?, forUserAccount userAccount: SFUserAccount) {
        let actualStoreName = storeName?.isEmpty == false ? storeName! : kDefaultSmartStoreName
        let key = self.key(forUser: userAccount, storeName: actualStoreName)
        removeSharedInstance(forKey: key)
    }

    /**
     * Remove the shared instance associated with the specified store.
     *
     * @param store SmartStore instance whose sync manager is to be removed.
     */
    @objc(removeSharedInstanceForStore:)
    public static func removeSharedInstance(store: SmartStore) {
        let key = self.key(for: store)
        removeSharedInstance(forKey: key)
    }

    /**
     * Remove all shared instances.
     */
    @objc
    public static func removeSharedInstances() {
        syncMgrListLock.lock()
        defer { syncMgrListLock.unlock() }
        syncMgrList.removeAll()
    }

    private static func removeSharedInstance(forKey key: String) {
        syncMgrListLock.lock()
        defer { syncMgrListLock.unlock() }
        syncMgrList.removeValue(forKey: key)
    }

    private static func key(for store: SmartStore) -> String {
        return key(forUser: store.userAccount, storeName: store.name)
    }

    private static func key(forUser user: SFUserAccount?, storeName: String) -> String {
        let keyPrefix: String
        if let user = user {
            keyPrefix = SFKeyForUserAndScope(user, .community)
        } else {
            keyPrefix = SFKeyForUserAndScope(nil, .global)
        }
        return "\(keyPrefix)-\(storeName)"
    }

    private static func isUserRelatedSync(_ key: String, user: SFUserAccount) -> Bool {
        let userPrefix = SFKeyForUserAndScope(user, .community)
        return key.contains(userPrefix)
    }

    // MARK: - Init / Dealloc

    private init(store: SmartStore) {
        self.store = store
        self.queue = DispatchQueue(label: kSyncManagerQueue)
        self._state = .acceptingSyncs

        super.init()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUserWillLogout(_:)),
            name: .UserAccountManagerWillLogoutUser,
            object: nil
        )

        SyncState.setupSyncsSoupIfNeeded(store: store)
        SyncState.cleanupSyncsSoupIfNeeded(store: store)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - State Management

    private var state: SFSyncManagerState {
        get {
            stateLock.lock()
            defer { stateLock.unlock() }
            return _state
        }
        set {
            stateLock.lock()
            defer { stateLock.unlock() }
            if _state != newValue {
                SFSDKMobileSyncLogger.d(type(of: self), message: "state changing from \(Self.stateToString(_state)) to \(Self.stateToString(newValue))")
                _state = newValue
            }
        }
    }

    /**
     * Stop the sync manager.
     * It can take a while for active syncs to actually stop.
     * Call `isStopped()` to see if the sync manager is fully paused.
     */
    @objc
    public func stop() {
        stateLock.lock()
        defer { stateLock.unlock() }

        if activeSyncs.isEmpty {
            _state = .stopped
        } else {
            _state = .stopRequested
        }
    }

    /**
     * @return YES if a stop was requested but some syncs are still active.
     */
    @objc
    public func isStopping() -> Bool {
        return state == .stopRequested
    }

    /**
     * @return YES if a stop was requested and no syncs are still active.
     */
    @objc
    public func isStopped() -> Bool {
        return state == .stopped
    }

    /**
     * Restart this sync manager.
     *
     * @param restartStoppedSyncs Pass YES to restart all stopped syncs.
     * @param updateBlock Block to be called with updates.
     * @return YES if restarted successfully.
     */
    @discardableResult
    public func restart(restartStoppedSyncs: Bool, onUpdate updateBlock: @escaping SyncUpdateBlock) throws -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }

        if _state == .stopped || _state == .stopRequested {
            _state = .acceptingSyncs

            if restartStoppedSyncs {
                let stoppedSyncs = SyncState.getSyncs(with: store, status: .stopped)
                for sync in stoppedSyncs {
                    SFSDKMobileSyncLogger.d(type(of: self), message: "restarting \(sync.syncId)")
                    try? reSync(id: NSNumber(value: sync.syncId), onUpdate: updateBlock)
                }
            }
            return true
        } else {
            let description = "restart() called on a sync manager that has state: \(Self.stateToString(_state))"
            throw createError(type: kSFSyncManagerCannotRestartError, code: kSFSyncManagerCannotRestartErrorCode, description: description)
        }
    }

    // MARK: - Active Syncs Management

    @objc
    internal func addToActiveSyncs(_ syncTask: SFSyncTask) {
        stateLock.lock()
        defer { stateLock.unlock() }
        activeSyncs[syncTask.syncId] = syncTask
    }

    @objc
    internal func removeFromActiveSyncs(_ syncTask: SFSyncTask) {
        stateLock.lock()
        defer { stateLock.unlock() }

        activeSyncs.removeValue(forKey: syncTask.syncId)
        if _state == .stopRequested && activeSyncs.isEmpty {
            _state = .stopped
        }
    }

    // MARK: - Check Methods

    /**
     * Check whether a sync manager is running.
     *
     * @return YES if the sync manager is running, or NO if it's stopping or stopped.
     */
    @discardableResult
    public func checkAcceptingSyncs(_ error: NSErrorPointer?) -> Bool {
        if state != .acceptingSyncs {
            let message = "sync manager has state \(Self.stateToString(state))"
            if let error = error {
                setError(error, type: kSFSyncManagerStoppedError, code: kSFSyncManagerStoppedErrorCode, description: message)
            }
            return false
        }
        return true
    }

    @discardableResult
    private func checkNotRunning(_ syncId: NSNumber, error: NSErrorPointer?) -> Bool {
        if activeSyncs[syncId] != nil {
            let message = "sync \(syncId) is still running"
            if let error = error {
                setError(error, type: kSFSyncAlreadyRunningError, code: kSFSyncAlreadyRunningErrorCode, description: message)
            }
            return false
        }
        return true
    }

    private func checkExists(byId syncId: NSNumber, error: NSErrorPointer?) -> SyncState? {
        guard let sync = syncStatus(forId: syncId) else {
            let message = "Sync \(syncId) does not exist"
            if let error = error {
                setError(error, type: kSFSyncNotExistError, code: kSFSyncNotExistErrorCode, description: message)
            }
            return nil
        }
        return sync
    }

    private func checkExists(byName syncName: String, error: NSErrorPointer?) -> SyncState? {
        guard let sync = syncStatus(forName: syncName) else {
            let message = "Sync \(syncName) does not exist"
            if let error = error {
                setError(error, type: kSFSyncNotExistError, code: kSFSyncNotExistErrorCode, description: message)
            }
            return nil
        }
        return sync
    }

    private func setError(_ error: NSErrorPointer, type: String, code: Int, description: String) {
        // TODO: Fix NSErrorPointer Swift interop bug
        // Swift compiler cannot properly unwrap NSErrorPointer even in non-optional context
        // error.pointee = createError(type: type, code: code, description: description)
        _ = createError(type: type, code: code, description: description)
    }

    private func createError(type: String, code: Int, description: String) -> NSError {
        SFSDKMobileSyncLogger.e(Swift.type(of: self), message: "\(type): \(description)")
        return NSError(
            domain: kSFMobileSyncErrorDomain,
            code: code,
            userInfo: [
                "error": type,
                "description": description
            ]
        )
    }

    // MARK: - Get / Has Sync Methods

    /**
     * Return status of the sync with the given sync ID.
     *
     * @param syncId Sync ID.
     */
    @objc(syncStatusForId:)
    public func syncStatus(forId syncId: NSNumber) -> SyncState? {
        let sync = SyncState.byId(syncId: syncId, store: store)
        if sync == nil {
            SFSDKMobileSyncLogger.d(type(of: self), message: "Sync \(syncId) not found")
        }
        return sync
    }

    /**
     * Return status of the sync with the given name.
     *
     * @param syncName Sync name.
     */
    @objc(syncStatusForName:)
    public func syncStatus(forName syncName: String) -> SyncState? {
        let sync = SyncState.byName(syncName: syncName, store: store)
        if sync == nil {
            SFSDKMobileSyncLogger.d(type(of: self), message: "Sync \(syncName) not found")
        }
        return sync
    }

    /**
     * Return YES if a sync with the given name exists.
     * @param syncName Sync name.
     * @return YES if a sync with the given name exists.
     */
    @objc(hasSyncForName:)
    public func hasSync(forName syncName: String) -> Bool {
        return SyncState.byName(syncName: syncName, store: store) != nil
    }

    // MARK: - Delete Sync Methods

    /**
     * Delete the sync with the given ID.
     *
     * @param syncId Sync ID.
     */
    @objc(deleteSyncForId:)
    public func deleteSync(forId syncId: NSNumber) {
        SyncState.deleteSync(syncId: syncId, store: store)
    }

    /**
     * Delete the sync with the given name.
     *
     * @param syncName Sync name.
     */
    @objc(deleteSyncForName:)
    public func deleteSync(forName syncName: String) {
        SyncState.deleteSync(syncName: syncName, store: store)
    }

    // MARK: - Run Sync Methods

    /** Run a previously created sync */
    private func runSync(_ sync: SyncState, updateBlock: @escaping SyncUpdateBlock) {
        let task: SFSyncTask

        switch sync.type {
        case .down:
            task = SFSyncDownTask(self, sync: sync, updateBlock: updateBlock)
        case .up:
            if sync.target is AdvancedSyncUpTarget {
                task = SFAdvancedSyncUpTask(self, sync: sync, updateBlock: updateBlock)
            } else {
                task = SFSyncUpTask(self, sync: sync, updateBlock: updateBlock)
            }
        @unknown default:
            task = SFSyncDownTask(self, sync: sync, updateBlock: updateBlock)
        }

        // Run on background thread
        queue.async {
            task.run()
        }
    }

    // MARK: - Sync Down and Supporting Methods

    /**
     * Create a sync down without running it.
     * @param target Sync down target that will manage the sync down process.
     * @param options Options associated with this sync down.
     * @param soupName Soup name where the local entries are stored.
     * @param syncName Name for this sync (optional).
     * @return Sync state associated with this sync down.
     */
    @objc(createSyncDown:options:soupName:syncName:)
    public func createSyncDown(_ target: SFSyncDownTarget, options: SFSyncOptions, soupName: String, syncName: String?) -> SyncState {
        guard let sync = SyncState.buildSyncDown(options: options, target: target, soupName: soupName, name: syncName, store: store) else {
            fatalError("Failed to create sync down")
        }
        SFSDKMobileSyncLogger.d(type(of: self), message: "Created syncDown:\(sync)")
        return sync
    }

    /**
     * Create and run a sync down that overwrites modified records.
     * @param target Sync down target that will manage the sync down process.
     * @param soupName Soup name where the local entries are stored.
     * @param updateBlock Block to be called with updates.
     * @return Sync state associated with this sync, or nil if it could not be created.
     */
    @objc(syncDownWithTarget:soupName:onUpdate:)
    public func syncDown(target: SFSyncDownTarget, soupName: String, onUpdate updateBlock: @escaping SyncUpdateBlock) -> SyncState? {
        let options = SFSyncOptions.newSyncOptions(forSyncDown: .overwrite)
        return syncDown(target: target, options: options, soupName: soupName, onUpdate: updateBlock)
    }

    /**
     * Create and run a sync down.
     * @param target Sync down target that manages the sync down process.
     * @param options Options associated with this sync down. Use this parameter to specify how the sync
     * should handle modified records in the store.
     * @param soupName Soup name where the local entries are stored.
     * @param updateBlock Block to be called with updates.
     * @return Sync state associated with this sync, or nil if it could not be created.
     */
    @objc(syncDownWithTarget:options:soupName:onUpdate:)
    public func syncDown(target: SFSyncDownTarget, options: SFSyncOptions, soupName: String, onUpdate updateBlock: @escaping SyncUpdateBlock) -> SyncState? {
        return try? syncDown(target: target, options: options, soupName: soupName, syncName: nil, onUpdate: updateBlock)
    }

    /**
     * Create and run a named sync down.
     * @param target Sync down target that will manage the sync down process.
     * @param options Options associated with this sync down. Use this parameter to specify how the sync
     * should handle modified records in the store.
     * @param soupName Soup name where the local entries are stored.
     * @param syncName Name for this sync.
     * @param updateBlock Block to be called with updates.
     * @return Sync state associated with this sync, or nil if it could not be created.
     */
    public func syncDown(target: SFSyncDownTarget, options: SFSyncOptions, soupName: String, syncName: String?, onUpdate updateBlock: @escaping SyncUpdateBlock) throws -> SyncState? {
        guard checkAcceptingSyncs(nil) else {
            throw createError(type: kSFSyncManagerStoppedError, code: kSFSyncManagerStoppedErrorCode, description: "sync manager has state \(Self.stateToString(state))")
        }

        let sync = createSyncDown(target, options: options, soupName: soupName, syncName: syncName)
        runSync(sync, updateBlock: updateBlock)
        return sync.copy() as? SyncState
    }

    // MARK: - ReSync Methods

    /**
     * Perform a resync.
     * @param syncId Sync ID.
     * @param updateBlock Block to be called with updates.
     * @return Sync state associated with this sync, or nil if it could not be started.
     */
    public func reSync(id syncId: NSNumber, onUpdate updateBlock: @escaping SyncUpdateBlock) throws -> SyncState? {
        var error: NSError?
        guard let sync = checkExists(byId: syncId, error: &error) else {
            if let error = error {
                throw error
            }
            return nil
        }
        return try reSync(withSync: sync, updateBlock: updateBlock)
    }

    /**
     * Perform a resync by name.
     * @param syncName Sync name.
     * @param updateBlock Block to be called with updates.
     * @return Sync state associated with this sync, or nil if it could not be started.
     */
    public func reSync(named syncName: String, onUpdate updateBlock: @escaping SyncUpdateBlock) throws -> SyncState? {
        var error: NSError?
        guard let sync = checkExists(byName: syncName, error: &error) else {
            if let error = error {
                throw error
            }
            return nil
        }
        return try reSync(withSync: sync, updateBlock: updateBlock)
    }

    @objc(reSyncByName:onUpdate:error:)
    public func reSyncByName(_ syncName: String, onUpdate updateBlock: @escaping SyncUpdateBlock) throws -> SyncState {
        guard let result = try reSync(named: syncName, onUpdate: updateBlock) else {
            throw createError(type: kSFSyncNotExistError, code: kSFSyncNotExistErrorCode, description: "Sync \(syncName) does not exist")
        }
        return result
    }

    @objc(reSyncById:onUpdate:error:)
    public func reSyncById(_ syncId: NSNumber, onUpdate updateBlock: @escaping SyncUpdateBlock) throws -> SyncState {
        guard let result = try reSync(id: syncId, onUpdate: updateBlock) else {
            throw createError(type: kSFSyncNotExistError, code: kSFSyncNotExistErrorCode, description: "Sync \(syncId) does not exist")
        }
        return result
    }

    private func reSync(withSync sync: SyncState, updateBlock: @escaping SyncUpdateBlock) throws -> SyncState? {
        var error: NSError?
        guard checkAcceptingSyncs(&error), checkNotRunning(NSNumber(value: sync.syncId), error: &error) else {
            if let error = error {
                throw error
            }
            return nil
        }

        // Reset total size
        sync.totalSize = -1

        // Adjust maxTimeStamp if sync was stopped
        if sync.isStopped() {
            sync.maxTimeStamp = sync.maxTimeStamp == -1 ? -1 : sync.maxTimeStamp - 1
        }

        SFSDKMobileSyncLogger.d(type(of: self), message: "reSync:\(sync)")
        runSync(sync, updateBlock: updateBlock)
        return sync.copy() as? SyncState
    }

    // MARK: - Sync Up and Supporting Methods

    /**
     * Create a sync up without running it.
     * @param target Sync up target that will manage the sync up process.
     * @param options Options associated with this sync up. Use this parameter to specify how the sync
     * should handle modified records on the server.
     * @param soupName Soup name where the local entries are stored.
     * @param syncName Name for this sync.
     * @return Sync state associated with this sync up.
     */
    @objc(createSyncUp:options:soupName:syncName:)
    public func createSyncUp(_ target: SFSyncUpTarget, options: SFSyncOptions, soupName: String, syncName: String?) -> SyncState {
        guard let sync = SyncState.buildSyncUp(options: options, target: target, soupName: soupName, name: syncName, store: store) else {
            fatalError("Failed to create sync up")
        }
        SFSDKMobileSyncLogger.d(SFMobileSyncSyncManager.self, message: "Created syncUp:\(sync)")
        return sync
    }

    /**
     * Create and run a sync up with the default SFSyncUpTarget.
     *
     * @param options Options associated with this sync up. Use this parameter to specify how the sync
     * should handle modified records on the server.
     * @param soupName Soup name where the local entries are stored.
     * @param updateBlock Block to be called with updates.
     * @return Sync state associated with this sync, or nil if it could not be created.
     */
    @objc(syncUpWithOptions:soupName:onUpdate:)
    public func syncUp(options: SFSyncOptions, soupName: String, onUpdate updateBlock: @escaping SyncUpdateBlock) -> SyncState? {
        guard let target = SFSyncUpTarget.newFromDict(nil) else {
            return nil
        }
        return syncUp(target: target, options: options, soupName: soupName, onUpdate: updateBlock)
    }

    /**
     * Create and run a sync up with the configured SFSyncUpTarget.
     *
     * @param target Sync up target that will manage the sync up process.
     * @param options Options associated with this sync up. Use this parameter to specify how the sync
     * should handle modified records on the server.
     * @param soupName Soup name where the local entries are stored.
     * @param updateBlock Block to be called with updates.
     * @return Sync state associated with this sync, or nil if it could not be created.
     */
    @objc(syncUpWithTarget:options:soupName:onUpdate:)
    public func syncUp(target: SFSyncUpTarget, options: SFSyncOptions, soupName: String, onUpdate updateBlock: @escaping SyncUpdateBlock) -> SyncState? {
        return try? syncUp(target: target, options: options, soupName: soupName, syncName: nil, onUpdate: updateBlock)
    }

    /**
     * Create and run a named sync up.
     *
     * @param target Sync up target that will manage the sync up process.
     * @param options Options associated with this sync up. Use this parameter to specify how the sync
     * should handle modified records on the server.
     * @param soupName Soup name where the local entries are stored.
     * @param syncName Name for this sync.
     * @param updateBlock Block to be called with updates.
     * @return Sync state associated with this sync, or nil if it could not be created.
     */
    public func syncUp(target: SFSyncUpTarget, options: SFSyncOptions, soupName: String, syncName: String?, onUpdate updateBlock: @escaping SyncUpdateBlock) throws -> SyncState? {
        guard checkAcceptingSyncs(nil) else {
            throw createError(type: kSFSyncManagerStoppedError, code: kSFSyncManagerStoppedErrorCode, description: "sync manager has state \(Self.stateToString(state))")
        }

        let sync = createSyncUp(target, options: options, soupName: soupName, syncName: syncName)
        runSync(sync, updateBlock: updateBlock)
        return sync.copy() as? SyncState
    }

    // MARK: - Clean Resync Ghosts Methods

    /**
     * Remove local copies of records that have been deleted on the server
     * or do not match the query results on the server anymore.
     *
     * @param syncId Sync ID.
     * @param completionStatusBlock Completion status block.
     * @return YES if cleanResyncGhosts started successfully.
     */
    @discardableResult
    public func cleanResyncGhosts(forId syncId: NSNumber, onComplete completionStatusBlock: @escaping SyncCompletionBlock) throws -> Bool {
        var error: NSError?
        guard let sync = checkExists(byId: syncId, error: &error) else {
            if let error = error {
                throw error
            }
            return false
        }
        return try cleanResyncGhosts(withSync: sync, completionStatusBlock: completionStatusBlock)
    }

    /**
     * Remove local copies of records that have been deleted on the server
     * or do not match the query results on the server anymore.
     *
     * @param syncName Sync Name.
     * @param completionStatusBlock Completion status block.
     * @return YES if cleanResyncGhosts started successfully.
     */
    @discardableResult
    public func cleanResyncGhosts(forName syncName: String, onComplete completionStatusBlock: @escaping SyncCompletionBlock) throws -> Bool {
        var error: NSError?
        guard let sync = checkExists(byName: syncName, error: &error) else {
            if let error = error {
                throw error
            }
            return false
        }
        return try cleanResyncGhosts(withSync: sync, completionStatusBlock: completionStatusBlock)
    }

    private func cleanResyncGhosts(withSync sync: SyncState, completionStatusBlock: @escaping SyncCompletionBlock) throws -> Bool {
        var error: NSError?
        guard checkAcceptingSyncs(&error), checkNotRunning(NSNumber(value: sync.syncId), error: &error) else {
            if let error = error {
                throw error
            }
            return false
        }

        guard sync.type == .down else {
            let description = "Cannot run cleanResyncGhosts:\(sync.syncId):wrong type:\(SyncState.syncTypeToString(sync.type))"
            throw createError(type: kSFSyncManagerCanOnlyRunCleanGhostsForSyncDown, code: kSFSyncManagerCanOnlyRunCleanGhostsForSyncDownCode, description: description)
        }

        SFSDKMobileSyncLogger.d(type(of: self), message: "cleanResyncGhosts:\(sync)")

        // Run on background thread
        let task = SFCleanSyncGhostsTask(self, sync: sync, completionStatusBlock: completionStatusBlock)
        queue.async {
            task.run()
        }

        return true
    }

    // MARK: - Logout Handling

    @objc
    private func handleUserWillLogout(_ notification: Notification) {
        guard let user = notification.userInfo?[kSFNotificationUserInfoAccountKey] as? SFUserAccount else {
            return
        }
        Self.removeSharedInstance(user)
    }

    // MARK: - State String Conversion

    public static func state(fromString state: String) -> SFSyncManagerState {
        switch state {
        case kSFSyncManagerStateAcceptingSyncs:
            return .acceptingSyncs
        case kSFSyncManagerStateStopRequested:
            return .stopRequested
        default:
            return .stopped
        }
    }

    public static func stateToString(_ state: SFSyncManagerState) -> String {
        switch state {
        case .acceptingSyncs:
            return kSFSyncManagerStateAcceptingSyncs
        case .stopRequested:
            return kSFSyncManagerStateStopRequested
        case .stopped:
            return kSFSyncManagerStateStopped
        }
    }
}

// Swift naming convention - drop SF prefix
public typealias MobileSyncSyncManager = SFMobileSyncSyncManager
public typealias SyncManager = SFMobileSyncSyncManager
