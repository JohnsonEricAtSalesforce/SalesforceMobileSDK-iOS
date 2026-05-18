/*
 SFSDKReachability.swift
 SalesforceSDKCommon

 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample's licensing information

 Abstract:
 Basic demonstration of how to use the SystemConfiguration Reachability APIs.
 */

import Foundation
import SystemConfiguration

// MARK: - Network Status Enum

/// Network reachability status values.
@objc public enum SFSDKReachabilityNetworkStatus: Int {
    case notReachable = 0
    case reachableViaWiFi
    case reachableViaWWAN
}

// MARK: - SFSDKReachability

/// Wrapper around SCNetworkReachability for monitoring network status.
@available(visionOS, unavailable)
@objc(SFSDKReachability)
@objcMembers
public class SFSDKReachability: NSObject {

    /// Notification posted when network reachability changes.
    @objc public static let kSFSDKReachabilityChangedNotification = "kSFSDKNetworkReachabilityChangedNotification"

    private var reachabilityRef: SCNetworkReachability?

    // MARK: - Factory Methods

    /// Creates a reachability instance to check the reachability of a given host name.
    @objc public class func reachability(withHostName hostName: String) -> SFSDKReachability? {
        guard let ref = SCNetworkReachabilityCreateWithName(nil, hostName) else {
            return nil
        }
        let instance = SFSDKReachability()
        instance.reachabilityRef = ref
        return instance
    }

    /// Creates a reachability instance to check the reachability of a given IP address.
    @objc public class func reachability(withAddress hostAddress: UnsafePointer<sockaddr>) -> SFSDKReachability? {
        guard let ref = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, hostAddress) else {
            return nil
        }
        let instance = SFSDKReachability()
        instance.reachabilityRef = ref
        return instance
    }

    /// Checks whether the default route is available.
    @objc public class func reachabilityForInternetConnection() -> SFSDKReachability? {
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        zeroAddress.sin_family = sa_family_t(AF_INET)

        return withUnsafePointer(to: &zeroAddress) { zeroPtr in
            zeroPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                reachability(withAddress: sockaddrPtr)
            }
        }
    }

    // MARK: - Notifier

    /// Start listening for reachability notifications on the current run loop.
    @objc public func startNotifier() -> Bool {
        guard let ref = reachabilityRef else { return false }

        var context = SCNetworkReachabilityContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let callback: SCNetworkReachabilityCallBack = { _, _, info in
            guard let info = info else { return }
            let reachability = Unmanaged<SFSDKReachability>.fromOpaque(info).takeUnretainedValue()
            NotificationCenter.default.post(
                name: Notification.Name(SFSDKReachability.kSFSDKReachabilityChangedNotification),
                object: reachability
            )
        }

        if SCNetworkReachabilitySetCallback(ref, callback, &context) {
            if SCNetworkReachabilityScheduleWithRunLoop(ref, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue) {
                return true
            }
        }

        return false
    }

    /// Stop listening for reachability notifications.
    @objc public func stopNotifier() {
        guard let ref = reachabilityRef else { return }
        SCNetworkReachabilityUnscheduleFromRunLoop(ref, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
    }

    deinit {
        stopNotifier()
    }

    // MARK: - Status

    /// Returns the current reachability status.
    @objc public func currentReachabilityStatus() -> SFSDKReachabilityNetworkStatus {
        guard let ref = reachabilityRef else { return .notReachable }
        var flags = SCNetworkReachabilityFlags()
        guard SCNetworkReachabilityGetFlags(ref, &flags) else { return .notReachable }
        return networkStatus(for: flags)
    }

    /// Returns whether a connection is required to reach the target.
    @objc public func connectionRequired() -> Bool {
        guard let ref = reachabilityRef else { return false }
        var flags = SCNetworkReachabilityFlags()
        guard SCNetworkReachabilityGetFlags(ref, &flags) else { return false }
        return flags.contains(.connectionRequired)
    }

    // MARK: - Private

    private func networkStatus(for flags: SCNetworkReachabilityFlags) -> SFSDKReachabilityNetworkStatus {
        guard flags.contains(.reachable) else {
            return .notReachable
        }

        var returnValue: SFSDKReachabilityNetworkStatus = .notReachable

        if !flags.contains(.connectionRequired) {
            returnValue = .reachableViaWiFi
        }

        if flags.contains(.connectionOnDemand) || flags.contains(.connectionOnTraffic) {
            if !flags.contains(.interventionRequired) {
                returnValue = .reachableViaWiFi
            }
        }

        if flags.contains(.isWWAN) {
            returnValue = .reachableViaWWAN
        }

        return returnValue
    }
}
