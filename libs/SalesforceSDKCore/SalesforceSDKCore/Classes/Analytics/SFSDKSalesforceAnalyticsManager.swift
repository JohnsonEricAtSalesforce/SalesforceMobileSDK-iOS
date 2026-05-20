// SFSDKSalesforceAnalyticsManager.swift
// SalesforceSDKCore
//
// Created by Bharath Hariharan on 6/16/16.
// Copyright (c) 2016-present, salesforce.com, inc. All rights reserved.
//
// Redistribution and use of this software in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
// * Redistributions of source code must retain the above copyright notice, this list of conditions
// and the following disclaimer.
// * Redistributions in binary form must reproduce the above copyright notice, this list of
// conditions and the following disclaimer in the documentation and/or other materials provided
// with the distribution.
// * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
// endorse or promote products derived from this software without specific prior written
// permission of salesforce.com, inc.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
// IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
// FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
// CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
// WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
// WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import Foundation
import UIKit
import CryptoKit
import SalesforceAnalytics
import SalesforceSDKCommon

private let kAnalyticsUnauthenticatedManagerKey = "-unauthenticated-"
private let kEventStoresDirectory = "event_stores"
private let kEventStoreEncryptionKeyLabel = "com.salesforce.eventStore.encryptionKey"
private let kAnalyticsOnOffKey = "ailtn_enabled"
private let kBatchProcessCount: Int = 100

@objc(SFSDKSalesforceAnalyticsManager)
@objcMembers
public class SFSDKSalesforceAnalyticsManager: NSObject {

    private static let lock = NSRecursiveLock()
    private static var analyticsManagerList: [String: SFSDKSalesforceAnalyticsManager] = [:]

    @objc public private(set) var eventStoreManager: SFSDKEventStoreManager
    @objc public private(set) var analyticsManager: SFSDKAnalyticsManager
    @objc public private(set) var userAccount: UserAccount?

    var remotes: [SFSDKAnalyticsTransformPublisherPair] = []
    private var task: UIBackgroundTaskIdentifier = .invalid

    @objc public var loggingEnabled: Bool {
        get { return readAnalyticsPolicy() }
        set {
            if newValue {
                SFSDKAppFeatureMarkers.registerAppFeature(kSFAppFeatureAiltnEnabled)
            } else {
                SFSDKAppFeatureMarkers.unregisterAppFeature(kSFAppFeatureAiltnEnabled)
            }
            storeAnalyticsPolicy(newValue)
            eventStoreManager.loggingEnabled = newValue
        }
    }

    @objc public var batchingEnabled: Bool = false

    // MARK: - Shared instances

    @objc public class func sharedInstance(with userAccount: UserAccount?) -> SFSDKSalesforceAnalyticsManager? {
        lock.lock()
        defer { lock.unlock() }

        var account = userAccount
        if account == nil {
            account = UserAccountManager.shared.currentUserAccount
        }
        guard let account = account else { return nil }

        guard let key = SFKeyForUserAndScope(account, .community) else { return nil }

        if let existing = analyticsManagerList[key] {
            return existing
        }

        guard account.loginState == .loggedIn else {
            SFSDKCoreLogger.w(SFSDKSalesforceAnalyticsManager.self, message: "A user account must be in the logged in state to create a SFSDKSalesforceAnalyticsManager instance.")
            return nil
        }

        guard let newInstance = SFSDKSalesforceAnalyticsManager(user: account) else {
            SFSDKCoreLogger.w(SFSDKSalesforceAnalyticsManager.self, message: "Unable to create a SFSDKSalesforceAnalyticsManager instance for a user.")
            return nil
        }
        analyticsManagerList[key] = newInstance
        return newInstance
    }

    @objc public class func sharedUnauthenticatedInstance() -> SFSDKSalesforceAnalyticsManager {
        lock.lock()
        defer { lock.unlock() }
        if let existing = analyticsManagerList[kAnalyticsUnauthenticatedManagerKey] {
            return existing
        }
        let instance = SFSDKSalesforceAnalyticsManager(user: nil)!
        analyticsManagerList[kAnalyticsUnauthenticatedManagerKey] = instance
        return instance
    }

    @objc public class func removeSharedInstance(with userAccount: UserAccount?) {
        lock.lock()
        defer { lock.unlock() }

        var account = userAccount
        if account == nil {
            account = UserAccountManager.shared.currentUserAccount
        }
        guard let account = account else { return }

        guard let userKey = SFKeyForUserAndScope(account, .user) else { return }
        let keysToRemove = analyticsManagerList.keys.filter { $0.hasPrefix(userKey) }
        for key in keysToRemove {
            analyticsManagerList.removeValue(forKey: key)
        }
    }

    // MARK: - Initialization

    private init?(user userAccount: UserAccount?) {
        self.userAccount = userAccount
        let deviceAttributes = SFSDKSalesforceAnalyticsManager.getDeviceAppAttributes()

        let rootStoreDir: String?
        if let userAccount = userAccount {
            rootStoreDir = SFDirectoryManager.sharedManager.directory(forUser: userAccount, type: .documentDirectory, components: [kEventStoresDirectory])
        } else {
            rootStoreDir = SFDirectoryManager.sharedManager.globalDirectory(ofType: .documentDirectory, components: [kEventStoresDirectory])
        }

        guard let rootStoreDir = rootStoreDir else {
            SFSDKCoreLogger.e(SFSDKSalesforceAnalyticsManager.self, message: "Root directory path is nil")
            return nil
        }

        let encryptionKey: SymmetricKey
        do {
            encryptionKey = try KeyGenerator.encryptionKey(for: kEventStoreEncryptionKeyLabel)
        } catch {
            SFSDKCoreLogger.e(SFSDKSalesforceAnalyticsManager.self, message: "Error getting encryption key: \(error.localizedDescription)")
            return nil
        }

        let dataEncryptorBlock: DataEncryptorBlock = { data in
            guard let data = data else { return nil }
            do {
                return try Encryptor.encrypt(data: data, using: encryptionKey)
            } catch {
                SFSDKCoreLogger.e(SFSDKSalesforceAnalyticsManager.self, message: "Error encrypting data: \(error.localizedDescription)")
                return nil
            }
        }
        let dataDecryptorBlock: DataDecryptorBlock = { data in
            guard let data = data else { return nil }
            do {
                return try Encryptor.decrypt(data: data, using: encryptionKey)
            } catch {
                SFSDKCoreLogger.e(SFSDKSalesforceAnalyticsManager.self, message: "Error decrypting data: \(error.localizedDescription)")
                return nil
            }
        }

        analyticsManager = SFSDKAnalyticsManager(storeDirectory: rootStoreDir, dataEncryptorBlock: dataEncryptorBlock, dataDecryptorBlock: dataDecryptorBlock, deviceAttributes: deviceAttributes)
        eventStoreManager = analyticsManager.storeManager

        super.init()

        if userAccount != nil {
            let tpp = SFSDKAnalyticsTransformPublisherPair(transform: SFSDKAILTNTransform(), publisher: SFSDKAILTNPublisher())
            remotes.append(tpp)
        }

        NotificationCenter.default.addObserver(self, selector: #selector(publishOnAppBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        if userAccount != nil {
            NotificationCenter.default.addObserver(self, selector: #selector(handleUserWillLogout(_:)), name: UserAccountManager.willLogoutUser, object: nil)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public methods

    @objc public func updateLoggingPrefs() {
        guard let customAttributes = userAccount?.idData?.customAttributes else { return }
        if let enabled = customAttributes[kAnalyticsOnOffKey] as? String {
            loggingEnabled = (enabled as NSString).boolValue
        } else {
            loggingEnabled = true
        }
    }

    @objc public func publishAllEvents() {
        Self.lock.lock()
        defer { Self.lock.unlock() }

        let publishEventsGroup = DispatchGroup()

        if !batchingEnabled {
            let events = eventStoreManager.fetchAllEvents() ?? []
            publishEvents(events, dispatchGroup: publishEventsGroup)
        } else {
            let eventFiles = eventStoreManager.eventFiles() ?? []
            var i = 0
            var remainingEvents = eventFiles.count

            while i < eventFiles.count {
                let count = min(kBatchProcessCount, remainingEvents)
                let subEvents = Array(eventFiles[i..<(i + count)])

                autoreleasepool {
                    var eventsArray: [SFSDKInstrumentationEvent] = []
                    for eventFile in subEvents {
                        if let event = eventStoreManager.fetchEvent(eventFile) {
                            eventsArray.append(event)
                        }
                    }
                    publishEvents(eventsArray, dispatchGroup: publishEventsGroup)
                    i += subEvents.count
                    remainingEvents -= subEvents.count
                }
            }
        }

        publishEventsGroup.notify(queue: .global()) { [weak self] in
            self?.cleanupBackgroundTask()
        }
    }

    @objc public func publishEvents(_ events: [SFSDKInstrumentationEvent]) {
        publishEvents(events, dispatchGroup: nil)
    }

    private func publishEvents(_ events: [SFSDKInstrumentationEvent], dispatchGroup: DispatchGroup?) {
        guard events.count > 0, remotes.count > 0 else { return }

        Self.lock.lock()
        defer { Self.lock.unlock() }

        dispatchGroup?.enter()

        let eventIds = events.map { $0.eventId }
        var overallSuccess = true
        var overallCompletionStatus = false
        var remoteKeySet = remotes
        var currentTppIndex = 0

        var publishCompleteBlock: PublishCompleteBlock?
        publishCompleteBlock = { [weak self] success, error in
            guard let self = self else { return }
            if overallSuccess {
                overallSuccess = success
            }

            remoteKeySet.remove(at: currentTppIndex)
            if remoteKeySet.isEmpty {
                overallCompletionStatus = true
            }

            if !overallCompletionStatus {
                currentTppIndex = 0
                self.applyTransformAndPublish(remoteKeySet[currentTppIndex], events: events, publishCompleteBlock: publishCompleteBlock!)
            } else {
                if overallSuccess {
                    self.eventStoreManager.deleteEvents(eventIds)
                }
                publishCompleteBlock = nil
            }

            dispatchGroup?.leave()
        }

        applyTransformAndPublish(remoteKeySet[currentTppIndex], events: events, publishCompleteBlock: publishCompleteBlock!)
    }

    @objc public func publishEvent(_ event: SFSDKInstrumentationEvent) {
        Self.lock.lock()
        defer { Self.lock.unlock() }
        publishEvents([event])
    }

    @objc public func addRemotePublisher(_ transformer: SFSDKTransform, publisher: SFSDKAnalyticsPublisher) {
        let tpp = SFSDKAnalyticsTransformPublisherPair(transform: transformer, publisher: publisher)
        remotes.append(tpp)
    }

    @objc public class func getDeviceAppAttributes() -> SFSDKDeviceAppAttributes {
        let sdkManager = SalesforceSDKManager.shared
        let prodAppVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let buildNumber = Bundle.main.infoDictionary?[kCFBundleVersionKey as String] as? String ?? ""
        let appVersion = "\(prodAppVersion)(\(buildNumber))"
        let appName = SalesforceSDKManager.ailtnAppName ?? ""
        let curDevice = UIDevice.current
        let osVersion = curDevice.systemVersion
        let osName = curDevice.systemName
        let appTypeStr = sdkManager.getAppTypeAsString()
        let mobileSdkVersion = SALESFORCE_SDK_VERSION
        let deviceModel = curDevice.sfsdk_platform() ?? ""
        let deviceId = sdkManager.deviceId()
        let clientId = sdkManager.bootConfig?.remoteAccessConsumerKey ?? ""
        return SFSDKDeviceAppAttributes(appVersion: appVersion, appName: appName, osVersion: osVersion, osName: osName, nativeAppType: appTypeStr, mobileSdkVersion: mobileSdkVersion, deviceModel: deviceModel, deviceId: deviceId, clientId: clientId)
    }

    // MARK: - Private methods

    private func storeAnalyticsPolicy(_ enabled: Bool) {
        let defs = UserDefaults.msdkUserDefaults()
        defs.set(enabled, forKey: kAnalyticsOnOffKey)
        defs.synchronize()
    }

    private func readAnalyticsPolicy() -> Bool {
        guard let analyticsEnabledNum = UserDefaults.msdkUserDefaults().object(forKey: kAnalyticsOnOffKey) as? NSNumber else {
            storeAnalyticsPolicy(true)
            return true
        }
        return analyticsEnabledNum.boolValue
    }

    @objc private func publishOnAppBackground() {
        guard userAccount?.accountIdentity == UserAccountManager.shared.currentUserAccount?.accountIdentity else {
            return
        }
        guard task == .invalid else { return }

        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }
            self.task = SFApplicationHelper.sharedApplication()?.beginBackgroundTask(withName: String(describing: type(of: self))) {
                self.cleanupBackgroundTask()
            } ?? .invalid
            self.publishAllEvents()
        }
    }

    private func applyTransformAndPublish(_ tpp: SFSDKAnalyticsTransformPublisherPair, events: [SFSDKInstrumentationEvent], publishCompleteBlock: @escaping PublishCompleteBlock) {
        var eventsArray: [Any] = []
        for event in events {
            autoreleasepool {
                if let transformedEvent = tpp.transform.transform(event) {
                    eventsArray.append(transformedEvent)
                }
            }
        }
        if let userAccount = userAccount {
            tpp.publisher.publish(eventsArray, user: userAccount, publishComplete: publishCompleteBlock)
        }
    }

    @objc private func handleUserWillLogout(_ notification: Notification) {
        guard let user = notification.userInfo?[UserAccountManager.userInfoAccountKey] as? UserAccount else { return }
        handleLogout(for: user)
    }

    private func handleLogout(for user: UserAccount) {
        analyticsManager.reset()
        let defs = UserDefaults.msdkUserDefaults()
        defs.removeObject(forKey: kAnalyticsOnOffKey)
        SFSDKSalesforceAnalyticsManager.removeSharedInstance(with: user)
    }

    private func cleanupBackgroundTask() {
        SFApplicationHelper.sharedApplication()?.endBackgroundTask(task)
        task = .invalid
    }
}

// MARK: - SFSDKAnalyticsTransformPublisherPair

@objc(SFSDKAnalyticsTransformPublisherPair)
@objcMembers
public class SFSDKAnalyticsTransformPublisherPair: NSObject {
    @objc public let transform: SFSDKTransform
    @objc public let publisher: SFSDKAnalyticsPublisher

    @objc public init(transform: SFSDKTransform, publisher: SFSDKAnalyticsPublisher) {
        self.transform = transform
        self.publisher = publisher
        super.init()
    }
}
