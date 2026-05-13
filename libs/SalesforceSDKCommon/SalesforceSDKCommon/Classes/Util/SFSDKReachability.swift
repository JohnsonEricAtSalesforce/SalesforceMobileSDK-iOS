/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample's licensing information

 Abstract:
 Basic demonstration of how to use the SystemConfiguration Reachablity APIs.
 */

import Foundation
import SystemConfiguration

@objc
public enum SFSDKReachabilityNetworkStatus: Int {
    case notReachable = 0
    case reachableViaWiFi
    case reachableViaWWAN
}

public let kSFSDKReachabilityChangedNotification = "kSFSDKNetworkReachabilityChangedNotification"

@available(visionOS, unavailable)
@objc(SFSDKReachability)
@objcMembers
public class SFSDKReachability: NSObject {

    private var reachabilityRef: SCNetworkReachability?

    deinit {
        stopNotifier()
        // Core Foundation objects are automatically memory managed in Swift
        // No need to call CFRelease
    }

    // MARK: - Factory Methods

    /// Use to check the reachability of a given host name.
    @objc(reachabilityWithHostName:)
    public static func reachability(withHostName hostName: String) -> SFSDKReachability? {
        guard let reachability = SCNetworkReachabilityCreateWithName(nil, (hostName as NSString).utf8String!) else {
            return nil
        }

        let returnValue = SFSDKReachability()
        returnValue.reachabilityRef = reachability
        return returnValue
    }

    /// Use to check the reachability of a given IP address.
    @objc(reachabilityWithAddress:)
    public static func reachability(withAddress hostAddress: UnsafePointer<sockaddr>) -> SFSDKReachability? {
        guard let reachability = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, hostAddress) else {
            return nil
        }

        let returnValue = SFSDKReachability()
        returnValue.reachabilityRef = reachability
        return returnValue
    }

    /// Checks whether the default route is available. Should be used by applications that do not connect to a particular host.
    @objc
    public static func reachabilityForInternetConnection() -> SFSDKReachability? {
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        zeroAddress.sin_family = sa_family_t(AF_INET)

        return withUnsafePointer(to: &zeroAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                reachability(withAddress: $0)
            }
        }
    }

    // MARK: - Start and stop notifier

    /// Start listening for reachability notifications on the current run loop.
    @objc
    public func startNotifier() -> Bool {
        guard let reachabilityRef = reachabilityRef else {
            return false
        }

        var context = SCNetworkReachabilityContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        guard SCNetworkReachabilitySetCallback(reachabilityRef, reachabilityCallback, &context) else {
            return false
        }

        guard SCNetworkReachabilityScheduleWithRunLoop(reachabilityRef, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue) else {
            return false
        }

        return true
    }

    @objc
    public func stopNotifier() {
        guard let reachabilityRef = reachabilityRef else {
            return
        }
        SCNetworkReachabilityUnscheduleFromRunLoop(reachabilityRef, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
    }

    // MARK: - Network Flag Handling

    @objc
    public func currentReachabilityStatus() -> SFSDKReachabilityNetworkStatus {
        guard let reachabilityRef = reachabilityRef else {
            return .notReachable
        }

        var flags = SCNetworkReachabilityFlags()
        guard SCNetworkReachabilityGetFlags(reachabilityRef, &flags) else {
            return .notReachable
        }

        return networkStatus(for: flags)
    }

    /// WWAN may be available, but not active until a connection has been established. WiFi may require a connection for VPN on Demand.
    @objc
    public func connectionRequired() -> Bool {
        guard let reachabilityRef = reachabilityRef else {
            return false
        }

        var flags = SCNetworkReachabilityFlags()
        guard SCNetworkReachabilityGetFlags(reachabilityRef, &flags) else {
            return false
        }

        return flags.contains(.connectionRequired)
    }

    private func networkStatus(for flags: SCNetworkReachabilityFlags) -> SFSDKReachabilityNetworkStatus {
        if !flags.contains(.reachable) {
            // The target host is not reachable.
            return .notReachable
        }

        var returnValue: SFSDKReachabilityNetworkStatus = .notReachable

        if !flags.contains(.connectionRequired) {
            // If the target host is reachable and no connection is required then we'll assume (for now) that you're on Wi-Fi...
            returnValue = .reachableViaWiFi
        }

        if flags.contains(.connectionOnDemand) || flags.contains(.connectionOnTraffic) {
            // ... and the connection is on-demand (or on-traffic) if the calling application is using the CFSocketStream or higher APIs...
            if !flags.contains(.interventionRequired) {
                // ... and no [user] intervention is needed...
                returnValue = .reachableViaWiFi
            }
        }

        if flags.contains(.isWWAN) {
            // ... but WWAN connections are OK if the calling application is using the CFNetwork APIs.
            returnValue = .reachableViaWWAN
        }

        return returnValue
    }
}

// MARK: - Reachability Callback

private func reachabilityCallback(
    target: SCNetworkReachability,
    flags: SCNetworkReachabilityFlags,
    info: UnsafeMutableRawPointer?
) {
    guard let info = info else {
        return
    }

    let reachability = Unmanaged<SFSDKReachability>.fromOpaque(info).takeUnretainedValue()

    // Post a notification to notify the client that the network reachability changed.
    NotificationCenter.default.post(
        name: NSNotification.Name(rawValue: kSFSDKReachabilityChangedNotification),
        object: reachability
    )
}
