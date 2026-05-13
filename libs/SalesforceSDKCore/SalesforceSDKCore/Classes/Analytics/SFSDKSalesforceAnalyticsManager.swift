/*
 SFSDKSalesforceAnalyticsManager.swift
 SalesforceSDKCore

 Created by Bharath Hariharan on 6/16/16.

 Copyright (c) 2016-present, salesforce.com, inc. All rights reserved.

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
import SalesforceAnalytics
import SalesforceSDKCommon
import UIKit
import CryptoKit

// MARK: - Constants

// SDK Version - matches SALESFORCE_SDK_VERSION from SalesforceSDKConstants.h
private let SALESFORCE_SDK_VERSION = "14.0.0"

private let kAnalyticsUnauthenticatedManagerKey = "-unauthenticated-"
private let kEventStoresDirectory = "event_stores"
private let kEventStoreEncryptionKeyLabel = "com.salesforce.eventStore.encryptionKey"
private let kAnalyticsOnOffKey = "ailtn_enabled"
private let kEventStoreGCMEncryptedKey = "com.salesforce.eventStore.encryption.GCM"
private let kBatchProcessCount: Int32 = 100

// MARK: - SFSDKAnalyticsTransformPublisherPair

@objc(SFSDKAnalyticsTransformPublisherPair)
public class SFSDKAnalyticsTransformPublisherPair: NSObject {
    @objc public let transform: SFSDKTransform
    @objc public let publisher: SFSDKAnalyticsPublisher

    @objc public init(transform: SFSDKTransform, publisher: SFSDKAnalyticsPublisher) {
        self.transform = transform
        self.publisher = publisher
        super.init()
    }
}

// MARK: - SFSDKSalesforceAnalyticsManager

@objc(SFSDKSalesforceAnalyticsManager)
public class SFSDKSalesforceAnalyticsManager: NSObject {

    // MARK: - Public Properties

    @objc public private(set) var eventStoreManager: SFSDKEventStoreManager
    @objc public private(set) var analyticsManager: SFSDKAnalyticsManager
    @objc public private(set) var userAccount: SFUserAccount?

    /// Disables or enables logging of events.
    ///
    /// If logging is disabled, no events will be stored. However, publishing
    /// of events is still possible.
    @objc public var isLoggingEnabled: Bool {
        get {
            return readAnalyticsPolicy()
        }
        set {
            if newValue {
                SFSDKAppFeatureMarkers.registerAppFeature(kSFAppFeatureAiltnEnabled)
            } else {
                SFSDKAppFeatureMarkers.unregisterAppFeature(kSFAppFeatureAiltnEnabled)
            }
            storeAnalyticsPolicy(newValue)
            // Note: eventStoreManager doesn't have a loggingEnabled property
        }
    }

    /// Disables or enables batch processing of events.
    ///
    /// If batching is enabled, publishing of events will happen in smaller chunks
    @objc public var isBatchingEnabled: Bool = false

    // MARK: - Internal Properties

    private var remotes: NSMutableArray
    private var task: UIBackgroundTaskIdentifier

    // MARK: - Static Properties

    private static var analyticsManagerList: NSMutableDictionary = NSMutableDictionary()

    // MARK: - Initialization

    private override init() {
        // Call designated initializer
        let deviceAttributes = Self.getDeviceAppAttributes()
        let rootStoreDir = SFDirectoryManager.sharedManager().globalDirectory(ofType: FileManager.SearchPathDirectory.documentDirectory, components: [kEventStoresDirectory])

        guard let rootStoreDir = rootStoreDir else {
            SFSDKCoreLogger.e(Self.self, message: "Root directory path is nil")
            fatalError("Root directory path is nil")
        }

        var encryptionKey: SymmetricKey?
        do {
            encryptionKey = try KeyGenerator.encryptionKey(for: kEventStoreEncryptionKeyLabel)
        } catch {
            SFSDKCoreLogger.e(Self.self, message: "Error getting encryption key: \(error.localizedDescription)")
        }

        let dataEncryptorBlock: DataEncryptorBlock = { data in
            guard let key = encryptionKey, let data = data else { return nil }
            do {
                return try Encryptor.encrypt(data: data, using: key)
            } catch {
                SFSDKCoreLogger.e(Self.self, message: "Error encrypting data: \(error.localizedDescription)")
                return nil
            }
        }

        let dataDecryptorBlock: DataDecryptorBlock = { data in
            guard let key = encryptionKey, let data = data else { return nil }
            do {
                return try Encryptor.decrypt(data: data, using: key)
            } catch {
                SFSDKCoreLogger.e(Self.self, message: "Error decrypting data: \(error.localizedDescription)")
                return nil
            }
        }

        self.analyticsManager = SFSDKAnalyticsManager(
            storeDirectory: rootStoreDir,
            dataEncryptorBlock: dataEncryptorBlock,
            dataDecryptorBlock: dataDecryptorBlock,
            deviceAttributes: deviceAttributes
        )
        self.eventStoreManager = analyticsManager.storeManager
        self.remotes = NSMutableArray()
        self.task = UIBackgroundTaskIdentifier.invalid
        self.userAccount = nil

        super.init()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(publishOnAppBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    private init?(user: SFUserAccount?) {
        let deviceAttributes = Self.getDeviceAppAttributes()

        let rootStoreDir: String?
        if let user = user {
            rootStoreDir = SFDirectoryManager.sharedManager().directory(
                forUser: user,
                type: FileManager.SearchPathDirectory.documentDirectory,
                components: [kEventStoresDirectory]
            )
        } else {
            rootStoreDir = SFDirectoryManager.sharedManager().globalDirectory(
                ofType: FileManager.SearchPathDirectory.documentDirectory,
                components: [kEventStoresDirectory]
            )
        }

        guard let rootStoreDir = rootStoreDir else {
            SFSDKCoreLogger.e(Self.self, message: "Root directory path is nil")
            return nil
        }

        var encryptionKey: SymmetricKey?
        do {
            encryptionKey = try KeyGenerator.encryptionKey(for: kEventStoreEncryptionKeyLabel)
        } catch {
            SFSDKCoreLogger.e(Self.self, message: "Error getting encryption key: \(error.localizedDescription)")
        }

        let dataEncryptorBlock: DataEncryptorBlock = { data in
            guard let key = encryptionKey, let data = data else { return nil }
            do {
                return try Encryptor.encrypt(data: data, using: key)
            } catch {
                SFSDKCoreLogger.e(Self.self, message: "Error encrypting data: \(error.localizedDescription)")
                return nil
            }
        }

        let dataDecryptorBlock: DataDecryptorBlock = { data in
            guard let key = encryptionKey, let data = data else { return nil }
            do {
                return try Encryptor.decrypt(data: data, using: key)
            } catch {
                SFSDKCoreLogger.e(Self.self, message: "Error decrypting data: \(error.localizedDescription)")
                return nil
            }
        }

        self.analyticsManager = SFSDKAnalyticsManager(
            storeDirectory: rootStoreDir,
            dataEncryptorBlock: dataEncryptorBlock,
            dataDecryptorBlock: dataDecryptorBlock,
            deviceAttributes: deviceAttributes
        )
        self.eventStoreManager = analyticsManager.storeManager
        self.remotes = NSMutableArray()
        self.task = UIBackgroundTaskIdentifier.invalid
        self.userAccount = user

        super.init()

        // There's no standard for unauthenticated instrumentation publishing, currently. Consumers
        // should explicitly specify their own.
        if user != nil {
            let tpp = SFSDKAnalyticsTransformPublisherPair(
                transform: SFSDKAILTNTransform(),
                publisher: SFSDKAILTNPublisher()
            )
            remotes.add(tpp)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(publishOnAppBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        // Only work with auth-based notifications for an authenticated context.
        if user != nil {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleUserWillLogout(_:)),
                name: .UserAccountManagerWillLogoutUser,
                object: nil
            )
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public Class Methods

    /// Returns an instance of this class associated with the specified user account.
    ///
    /// - Parameter userAccount: User account.
    /// - Returns: Instance of this class.
    @objc public class func sharedInstance(user userAccount: SFUserAccount?) -> SFSDKSalesforceAnalyticsManager? {
        objc_sync_enter(Self.self)
        defer { objc_sync_exit(Self.self) }

        var account = userAccount
        if account == nil {
            account = UserAccountManager.shared.currentUserAccount
        }

        guard let account = account else {
            return nil
        }

        let key = SFKeyForUserAndScope(account, .community)

        if let analyticsMgr = analyticsManagerList[key] as? SFSDKSalesforceAnalyticsManager {
            return analyticsMgr
        }

        if account.loginState != .loggedIn {
            SFSDKCoreLogger.w(Self.self, message: "A user account must be in the SFUserAccountLoginStateLoggedIn state in order to create a SFSDKSalesforceAnalyticsManager instance for a user.")
            return nil
        }

        guard let analyticsMgr = SFSDKSalesforceAnalyticsManager(user: account) else {
            SFSDKCoreLogger.w(Self.self, message: "Unable to create a SFSDKSalesforceAnalyticsManager instance for a user.")
            return nil
        }

        analyticsManagerList[key] = analyticsMgr
        return analyticsMgr
    }

    /// Returns an instance of this class associated with an unauthenticated context (no authenticated user account).
    ///
    /// - Returns: Instance of this class.
    @objc public class func sharedUnauthenticatedInstance() -> SFSDKSalesforceAnalyticsManager {
        objc_sync_enter(Self.self)
        defer { objc_sync_exit(Self.self) }

        if let instance = analyticsManagerList[kAnalyticsUnauthenticatedManagerKey] as? SFSDKSalesforceAnalyticsManager {
            return instance
        }

        let instance = SFSDKSalesforceAnalyticsManager()
        analyticsManagerList[kAnalyticsUnauthenticatedManagerKey] = instance
        return instance
    }

    /// Resets and removes the instance associated with the specified user account.
    ///
    /// - Parameter userAccount: User account.
    @objc public class func removeSharedInstance(user userAccount: SFUserAccount?) {
        objc_sync_enter(Self.self)
        defer { objc_sync_exit(Self.self) }

        var account = userAccount
        if account == nil {
            account = UserAccountManager.shared.currentUserAccount
        }

        guard let account = account else {
            return
        }

        let userKey = SFKeyForUserAndScope(account, .user)

        // Remove all sub-instances (community users) for this user as well
        let keys = analyticsManagerList.allKeys as? [String] ?? []
        for key in keys {
            if key.hasPrefix(userKey) {
                analyticsManagerList.removeObject(forKey: key)
            }
        }
    }

    /// Builds device attributes associated with this device.
    ///
    /// - Returns: Device attributes.
    @objc public class func getDeviceAppAttributes() -> SFSDKDeviceAppAttributes {
        let sdkManager = SalesforceManager.shared
        let prodAppVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let buildNumber = Bundle.main.infoDictionary?[kCFBundleVersionKey as String] as? String ?? ""
        let appVersion = "\(prodAppVersion)(\(buildNumber))"
        let appName = SalesforceManager.analyticsAppName
        let curDevice = UIDevice.current
        let osVersion = curDevice.systemVersion
        let osName = curDevice.systemName
        let appTypeStr = sdkManager.getAppTypeAsString()
        let mobileSdkVersion = SALESFORCE_SDK_VERSION
        let deviceModel = curDevice.platform ?? ""
        let deviceId = sdkManager.deviceId()
        let clientId = sdkManager.appConfig?.remoteAccessConsumerKey ?? ""

        return SFSDKDeviceAppAttributes(
            appVersion: appVersion,
            appName: appName,
            osVersion: osVersion,
            osName: osName,
            nativeAppType: appTypeStr,
            mobileSdkVersion: mobileSdkVersion,
            deviceModel: deviceModel,
            deviceId: deviceId,
            clientId: clientId
        )
    }

    // MARK: - Public Instance Methods

    /// Publishes all stored events to all registered network endpoints after
    /// applying the required event format transforms. Stored events will be
    /// deleted if publishing was successful for all registered endpoints.
    /// This method should NOT be called from the main thread.
    @objc public func publishAllEvents() {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        let publishEventsGroup = DispatchGroup()

        if !isBatchingEnabled {
            if let events = eventStoreManager.fetchAllEvents() {
                publishEvents(events, dispatchGroup: publishEventsGroup)
            }
        } else {
            guard let eventFiles = eventStoreManager.eventFiles() else {
                return
            }
            var i: Int32 = 0
            var remainingEvents = eventFiles.count

            while i < eventFiles.count {
                let subEvents = (eventFiles as NSArray).subarray(
                    with: NSRange(location: Int(i), length: min(Int(kBatchProcessCount), remainingEvents))
                )

                // Batch process and use autorelease pool to best manage memory usage in processing events
                autoreleasepool {
                    let eventsArray = NSMutableArray(capacity: Int(kBatchProcessCount))
                    for subCount in 0..<subEvents.count {
                        if let eventFile = subEvents[subCount] as? String {
                            eventsArray.add(eventStoreManager.fetchEvent(eventFile))
                        }
                    }
                    publishEvents(eventsArray as? [SFSDKInstrumentationEvent] ?? [], dispatchGroup: publishEventsGroup)
                    i += Int32(subEvents.count)
                    remainingEvents = remainingEvents - subEvents.count
                }
            }
        }

        publishEventsGroup.notify(queue: DispatchQueue.global(qos: .default)) {
            self.cleanupBackgroundTask()
        }
    }

    /// Publishes a list of events to all registered network endpoints after
    /// applying the required event format transforms. Stored events will be
    /// deleted if publishing was successful for all registered endpoints.
    /// This method should NOT be called from the main thread.
    ///
    /// - Parameter events: List of events.
    @objc public func publishEvents(_ events: [SFSDKInstrumentationEvent]) {
        publishEvents(events, dispatchGroup: nil)
    }

    /// Publishes an event to all registered network endpoints after
    /// applying the required event format transforms. Stored event will be
    /// deleted if publishing was successful for all registered endpoints.
    /// This method should NOT be called from the main thread.
    ///
    /// - Parameter event: Event.
    @objc public func publishEvent(_ event: SFSDKInstrumentationEvent) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        publishEvents([event])
    }

    /// Adds a remote publisher to publish events to.
    ///
    /// - Parameters:
    ///   - transformer: Transformer class.
    ///   - publisher: Publisher class.
    @objc public func addRemotePublisher(_ transformer: SFSDKTransform, publisher: SFSDKAnalyticsPublisher) {
        let tpp = SFSDKAnalyticsTransformPublisherPair(transform: transformer, publisher: publisher)
        remotes.add(tpp)
    }

    /// Updates the preferences of this library.
    @objc public func updateLoggingPrefs() {
        guard let idData = userAccount?.idData,
              let customAttributes = idData.customAttributes else {
            return
        }

        if let enabled = customAttributes[kAnalyticsOnOffKey] as? String {
            isLoggingEnabled = (enabled as NSString).boolValue
        } else {
            isLoggingEnabled = true
        }
    }

    // MARK: - Private Methods

    private func publishEvents(_ events: [SFSDKInstrumentationEvent], dispatchGroup: DispatchGroup?) {
        if events.isEmpty || remotes.count == 0 {
            return
        }

        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        if let dispatchGroup = dispatchGroup {
            dispatchGroup.enter()
        }

        let eventIds = events.map { $0.eventId }
        var overallSuccess = true
        var overallCompletionStatus = false
        var remoteKeySet = remotes.mutableCopy() as? NSMutableArray

        guard let remoteKeySet = remoteKeySet,
              let currentTpp = remoteKeySet.firstObject as? SFSDKAnalyticsTransformPublisherPair else {
            if let dispatchGroup = dispatchGroup {
                dispatchGroup.leave()
            }
            return
        }

        var publishCompleteBlock: PublishCompleteBlock?
        publishCompleteBlock = { [weak self] success, error in
            guard let self = self else { return }

            // Updates the success flag only if all previous requests have been successful.
            // This ensures that the operation is marked success only if all publishers are successful.
            if overallSuccess {
                overallSuccess = success
            }

            // Removes current transform from the list since it's done.
            remoteKeySet.remove(currentTpp)

            // If there are no transforms left, we're done here.
            if remoteKeySet.count == 0 {
                overallCompletionStatus = true
            }

            if !overallCompletionStatus {
                if let nextTpp = remoteKeySet.firstObject as? SFSDKAnalyticsTransformPublisherPair {
                    self.applyTransformAndPublish(nextTpp, events: events, publishCompleteBlock: publishCompleteBlock)
                }
            } else {
                // Deletes events from the event store if the network publishing was successful.
                if overallSuccess {
                    self.eventStoreManager.deleteEvents(eventIds)
                }
                publishCompleteBlock = nil
            }

            if let dispatchGroup = dispatchGroup {
                dispatchGroup.leave()
            }
        }

        applyTransformAndPublish(currentTpp, events: events, publishCompleteBlock: publishCompleteBlock)
    }

    private func storeAnalyticsPolicy(_ enabled: Bool) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        let defs = UserDefaults.msdkUserDefaults()
        defs.set(enabled, forKey: kAnalyticsOnOffKey)
        defs.synchronize()
    }

    private func readAnalyticsPolicy() -> Bool {
        let analyticsEnabledNum = UserDefaults.msdkUserDefaults().object(forKey: kAnalyticsOnOffKey) as? NSNumber

        if analyticsEnabledNum == nil {
            // Default is Enabled.
            storeAnalyticsPolicy(true)
            return true
        } else {
            return analyticsEnabledNum?.boolValue ?? true
        }
    }

    @objc private func publishOnAppBackground() {
        // Publishing should only happen for the current user, not for all users signed in.
        guard let currentUser = UserAccountManager.shared.currentUserAccount,
              userAccount?.accountIdentity == currentUser.accountIdentity else {
            return
        }

        // Avoid re-entrance if task is active
        if task == UIBackgroundTaskIdentifier.invalid {
            DispatchQueue.global(qos: .default).async { [weak self] in
                guard let self = self,
                      let app = SFApplicationHelper.sharedApplication() else { return }
                self.task = app.beginBackgroundTask(withName: NSStringFromClass(type(of: self))) {
                    self.cleanupBackgroundTask()
                }
                self.publishAllEvents()
            }
        }
    }

    private func applyTransformAndPublish(
        _ tpp: SFSDKAnalyticsTransformPublisherPair,
        events: [SFSDKInstrumentationEvent],
        publishCompleteBlock: PublishCompleteBlock?
    ) {
        let eventsArray = NSMutableArray()
        for event in events {
            autoreleasepool {
                if let transformedEvent = tpp.transform.transform(event) {
                    eventsArray.add(transformedEvent)
                }
            }
        }

        let networkPublisher = tpp.publisher
        if let completeBlock = publishCompleteBlock, let account = userAccount {
            networkPublisher.publish(eventsArray as? [Any] ?? [], user: account, publishComplete: completeBlock)
        }
    }

    // MARK: - User Account Manager Delegate

    @objc private func handleUserWillLogout(_ notification: Notification) {
        if let user = notification.userInfo?[UserAccountManager.userInfoAccountKey] as? SFUserAccount {
            handleLogout(forUser: user)
        }
    }

    private func handleLogout(forUser user: SFUserAccount) {
        analyticsManager.reset()
        let defs = UserDefaults.msdkUserDefaults()
        defs.removeObject(forKey: kAnalyticsOnOffKey)
        Self.removeSharedInstance(user: user)
    }

    private func cleanupBackgroundTask() {
        if let app = SFApplicationHelper.sharedApplication() {
            app.endBackgroundTask(task)
        }
        task = UIBackgroundTaskIdentifier.invalid
    }
}
