// UIDevice+SFHardware.swift
//
// Erica Sadun, http://ericasadun.com
// iPhone Developer's Cookbook, 6.x Edition
// BSD License, Use at your own risk
//
// Copyright (c) 2015-present, salesforce.com, inc. All rights reserved.
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

import UIKit
import Darwin

// MARK: - Device Name Strings

// Supported iPhones
public let IPHONE_SE_2G_NAMESTRING = "iPhone SE (2nd generation)"
public let IPHONE_SE_3G_NAMESTRING = "iPhone SE (3rd generation)"
public let IPHONE_XS_NAMESTRING = "iPhone XS"
public let IPHONE_XSMAX_NAMESTRING = "iPhone XS Max"
public let IPHONE_XR_NAMESTRING = "iPhone XR"
public let IPHONE_11_NAMESTRING = "iPhone 11"
public let IPHONE_11_PRO_NAMESTRING = "iPhone 11 Pro"
public let IPHONE_11_PRO_MAX_NAMESTRING = "iPhone 11 Pro Max"
public let IPHONE_12_MINI_NAMESTRING = "iPhone 12 Mini"
public let IPHONE_12_NAMESTRING = "iPhone 12"
public let IPHONE_12_PRO_NAMESTRING = "iPhone 12 Pro"
public let IPHONE_12_PRO_MAX_NAMESTRING = "iPhone 12 Pro Max"
public let IPHONE_13_MINI_NAMESTRING = "iPhone 13 Mini"
public let IPHONE_13_NAMESTRING = "iPhone 13"
public let IPHONE_13_PRO_NAMESTRING = "iPhone 13 Pro"
public let IPHONE_13_PRO_MAX_NAMESTRING = "iPhone 13 Pro Max"
public let IPHONE_14_NAMESTRING = "iPhone 14"
public let IPHONE_14_PLUS_NAMESTRING = "iPhone 14 Plus"
public let IPHONE_14_PRO_NAMESTRING = "iPhone 14 Pro"
public let IPHONE_14_PRO_MAX_NAMESTRING = "iPhone 14 Pro Max"
public let IPHONE_15_NAMESTRING = "iPhone 15"
public let IPHONE_15_PLUS_NAMESTRING = "iPhone 15 Plus"
public let IPHONE_15_PRO_NAMESTRING = "iPhone 15 Pro"
public let IPHONE_15_PRO_MAX_NAMESTRING = "iPhone 15 Pro Max"
public let IPHONE_16_PRO_NAMESTRING = "iPhone 16 Pro"
public let IPHONE_16_PRO_MAX_NAMESTRING = "iPhone 16 Pro Max"
public let IPHONE_16_NAMESTRING = "iPhone 16"
public let IPHONE_16_PLUS_NAMESTRING = "iPhone 16 Plus"
public let IPHONE_UNKNOWN_NAMESTRING = "Unknown iPhone"

// Supported iPads
public let IPAD_MINI_5G_NAMESTRING = "iPad mini (5th generation)"
public let IPAD_MINI_6G_NAMESTRING = "iPad mini (6th generation)"
public let IPAD_MINI_7G_NAMESTRING = "iPad mini 7th Gen"
public let IPAD_AIR_3G_NAMESTRING = "iPad Air (3rd generation)"
public let IPAD_AIR_4G_NAMESTRING = "iPad Air (4th generation)"
public let IPAD_AIR_5G_NAMESTRING = "iPad Air (5th generation)"
public let IPAD_AIR_6G_NAMESTRING = "iPad Air 6th Gen"
public let IPAD_AIR_7G_NAMESTRING = "iPad Air 7th Gen"
public let IPAD_7G_NAMESTRING = "iPad (7th generation)"
public let IPAD_8G_NAMESTRING = "iPad (8th generation)"
public let IPAD_9G_NAMESTRING = "iPad (9th generation)"
public let IPAD_10G_NAMESTRING = "iPad (10th generation)"
public let IPAD_PRO_11_2G_NAMESTRING = "iPad Pro (11-inch, 2nd generation)"
public let IPAD_PRO_11_3G_NAMESTRING = "iPad Pro (11-inch, 3rd generation)"
public let IPAD_PRO_11_4G_NAMESTRING = "iPad Pro (11-inch, 4th generation)"
public let IPAD_PRO_11_5G_NAMESTRING = "iPad Pro 11 inch 5th Gen"
public let IPAD_PRO_12_9_3G_NAMESTRING = "iPad Pro (12.9-inch, 3rd generation)"
public let IPAD_PRO_12_9_4G_NAMESTRING = "iPad Pro (12.9-inch, 4th generation)"
public let IPAD_PRO_12_9_5G_NAMESTRING = "iPad Pro (12.9-inch, 5th generation)"
public let IPAD_PRO_12_9_6G_NAMESTRING = "iPad Pro (12.9-inch, 6th generation)"
public let IPAD_PRO_12_7G_NAMESTRING = "iPad Pro 12.9 inch 7th Gen"
public let IPAD_UNKNOWN_NAMESTRING = "Unknown iPad"

// Supported Apple TVs
public let APPLETV_4G_NAMESTRING = "Apple TV HD"
public let APPLETV_4K_NAMESTRING = "Apple TV 4K (1st generation)"
public let APPLETV_4K_2G_NAMESTRING = "Apple TV 4K (2nd generation)"
public let APPLETV_4K_3G_NAMESTRING = "Apple TV 4K (3rd generation)"
public let APPLETV_UNKNOWN_NAMESTRING = "Unknown Apple TV"

// Simulator
public let SIMULATOR_NAMESTRING = "iPhone Simulator"
public let SIMULATOR_IPHONE_NAMESTRING = "iPhone Simulator"
public let SIMULATOR_IPAD_NAMESTRING = "iPad Simulator"
public let SIMULATOR_APPLETV_NAMESTRING = "Apple TV Simulator"

// Unknown
public let IOS_FAMILY_UNKNOWN_DEVICE = "Unknown iOS device"
public let IFPGA_NAMESTRING = "iFPGA"

// MARK: - UIDevicePlatform

@objc public enum UIDevicePlatform: UInt {
    case unknown = 0
    case iFPGA
    case simulator
    case simulatoriPhone
    case simulatoriPad
    case simulatorAppleTV

    // Supported iPhones (A12 Bionic and newer)
    case SE2iPhone
    case SE3iPhone
    case XRiPhone
    case XsiPhone
    case XsMaxiPhone
    case _11iPhone
    case _11ProiPhone
    case _11ProMaxiPhone
    case _12MiniiPhone
    case _12iPhone
    case _12ProiPhone
    case _12ProMaxiPhone
    case _13MiniiPhone
    case _13iPhone
    case _13ProiPhone
    case _13ProMaxiPhone
    case _14iPhone
    case _14PlusiPhone
    case _14ProiPhone
    case _14ProMaxiPhone
    case _15iPhone
    case _15PlusiPhone
    case _15ProiPhone
    case _15ProMaxiPhone
    case _16ProiPhone
    case _16ProMaxiPhone
    case _16iPhone
    case _16PlusiPhone

    // Supported iPads (A12 Bionic and newer)
    case _5GiPadMini
    case _6GiPadMini
    case _3GiPadAir
    case _4GiPadAir
    case _5GiPadAir
    case _7GiPad
    case _8GiPad
    case _9GiPad
    case _10GiPad
    case m1iPadPro129Inch
    case _3G129InchiPadPro
    case _4G129InchiPadPro
    case _5G129InchiPadPro
    case _6G129InchiPadPro
    case _11InchiPadPro
    case _11Inch2GiPadPro
    case _11Inch3GiPadPro
    case _11Inch4GiPadPro
    case _6GiPadAir
    case _7GiPadAir
    case _7GiPadMini
    case _11Inch5GiPadPro
    case _12Inch7GiPadPro

    // Supported Apple TVs
    case appleTV4
    case appleTV4k
    case appleTV4k2G
    case appleTV4k3G

    case unknowniPhone
    case unknowniPad
    case unknownAppleTV
}

// MARK: - UIDeviceFamily

@objc public enum UIDeviceFamily: UInt {
    case iPhone = 0
    case iPod
    case iPad
    case appleTV
    case unknown
}

// MARK: - UIDevice (SFHardware)

extension UIDevice {

    // MARK: Private helpers

    private func getSysInfoByName(_ typeSpecifier: String) -> String? {
        var size: Int = 0
        sysctlbyname(typeSpecifier, nil, &size, nil, 0)
        guard size > 0 else { return nil }
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname(typeSpecifier, &machine, &size, nil, 0)
        return String(cString: machine)
    }

    private func getSysInfo(_ typeSpecifier: Int32) -> UInt {
        var size = MemoryLayout<Int32>.size
        var results: Int32 = 0
        var mib: [Int32] = [CTL_HW, typeSpecifier]
        sysctl(&mib, 2, &results, &size, nil, 0)
        return UInt(results)
    }

    // MARK: Public API

    /// Platform for the device.
    @objc public func sfsdk_platform() -> String? {
        return getSysInfoByName("hw.machine")
    }

    /// Platform type. See `UIDevicePlatform`.
    @objc public func sfsdk_platformType() -> UIDevicePlatform {
        guard let platform = sfsdk_platform() else { return .unknown }

        if platform == "iFPGA" { return .iFPGA }

        // Simulators
        if sfsdk_isSimulator() {
            switch userInterfaceIdiom {
            case .phone: return .simulatoriPhone
            case .pad: return .simulatoriPad
            default: return .simulator
            }
        }

        // iPhones
        let iphoneIdentifiers: [String: UIDevicePlatform] = [
            "iPhone12,8": .SE2iPhone,
            "iPhone14,6": .SE3iPhone,
            "iPhone11,8": .XRiPhone,
            "iPhone11,2": .XsiPhone,
            "iPhone11,4": .XsMaxiPhone,
            "iPhone11,6": .XsMaxiPhone,
            "iPhone12,1": ._11iPhone,
            "iPhone12,3": ._11ProiPhone,
            "iPhone12,5": ._11ProMaxiPhone,
            "iPhone13,1": ._12MiniiPhone,
            "iPhone13,2": ._12iPhone,
            "iPhone13,3": ._12ProiPhone,
            "iPhone13,4": ._12ProMaxiPhone,
            "iPhone14,4": ._13MiniiPhone,
            "iPhone14,5": ._13iPhone,
            "iPhone14,2": ._13ProiPhone,
            "iPhone14,3": ._13ProMaxiPhone,
            "iPhone14,7": ._14iPhone,
            "iPhone14,8": ._14PlusiPhone,
            "iPhone15,2": ._14ProiPhone,
            "iPhone15,3": ._14ProMaxiPhone,
            "iPhone15,4": ._15iPhone,
            "iPhone15,5": ._15PlusiPhone,
            "iPhone16,1": ._15ProiPhone,
            "iPhone16,2": ._15ProMaxiPhone,
            "iPhone17,1": ._16ProiPhone,
            "iPhone17,2": ._16ProMaxiPhone,
            "iPhone17,3": ._16iPhone,
            "iPhone17,4": ._16PlusiPhone,
        ]
        if let iphoneType = iphoneIdentifiers[platform] { return iphoneType }

        // iPads
        let ipadIdentifiers: [String: UIDevicePlatform] = [
            "iPad7,11": ._7GiPad, "iPad7,12": ._7GiPad,
            "iPad8,1": ._11InchiPadPro, "iPad8,2": ._11InchiPadPro,
            "iPad8,3": ._11InchiPadPro, "iPad8,4": ._11InchiPadPro,
            "iPad8,5": ._3G129InchiPadPro, "iPad8,6": ._3G129InchiPadPro,
            "iPad8,7": ._3G129InchiPadPro, "iPad8,8": ._3G129InchiPadPro,
            "iPad8,9": ._11Inch2GiPadPro, "iPad8,10": ._11Inch2GiPadPro,
            "iPad8,11": ._4G129InchiPadPro, "iPad8,12": ._4G129InchiPadPro,
            "iPad11,3": ._3GiPadAir, "iPad11,4": ._3GiPadAir,
            "iPad11,1": ._5GiPadMini, "iPad11,2": ._5GiPadMini,
            "iPad11,6": ._8GiPad, "iPad11,7": ._8GiPad,
            "iPad12,1": ._9GiPad, "iPad12,2": ._9GiPad,
            "iPad13,1": ._4GiPadAir, "iPad13,2": ._4GiPadAir,
            "iPad13,4": ._11Inch3GiPadPro, "iPad13,5": ._11Inch3GiPadPro,
            "iPad13,6": ._11Inch3GiPadPro, "iPad13,7": ._11Inch3GiPadPro,
            "iPad13,8": ._5G129InchiPadPro, "iPad13,9": ._5G129InchiPadPro,
            "iPad13,10": ._5G129InchiPadPro, "iPad13,11": ._5G129InchiPadPro,
            "iPad13,16": ._5GiPadAir, "iPad13,17": ._5GiPadAir,
            "iPad13,18": ._10GiPad, "iPad13,19": ._10GiPad,
            "iPad14,1": ._6GiPadMini, "iPad14,2": ._6GiPadMini,
            "iPad14,3": ._6G129InchiPadPro, "iPad14,4": ._6G129InchiPadPro,
            "iPad14,5": ._11Inch4GiPadPro, "iPad14,6": ._11Inch4GiPadPro,
            "iPad14,8": ._6GiPadAir, "iPad14,9": ._6GiPadAir,
            "iPad14,10": ._7GiPadAir, "iPad14,11": ._7GiPadAir,
            "iPad16,1": ._7GiPadMini, "iPad16,2": ._7GiPadMini,
            "iPad16,3": ._11Inch5GiPadPro, "iPad16,4": ._11Inch5GiPadPro,
            "iPad16,5": ._12Inch7GiPadPro, "iPad16,6": ._12Inch7GiPadPro,
        ]
        if let ipadType = ipadIdentifiers[platform] { return ipadType }

        // Apple TVs
        let appleTVIdentifiers: [String: UIDevicePlatform] = [
            "AppleTV5,3": .appleTV4,
            "AppleTV6,2": .appleTV4k,
            "AppleTV11,1": .appleTV4k2G,
            "AppleTV14,1": .appleTV4k3G,
        ]
        if let appleTVType = appleTVIdentifiers[platform] { return appleTVType }

        // Fallback checks
        if platform.hasPrefix("iPhone") { return .unknowniPhone }
        if platform.hasPrefix("iPad") { return .unknowniPad }
        if platform.hasPrefix("AppleTV") { return .unknownAppleTV }

        return .unknown
    }

    /// Returns the system-dependent version number.
    @objc public func sfsdk_systemVersionNumber() -> Double {
        return Double(systemVersion) ?? 0
    }

    /// Platform string.
    @objc public func sfsdk_platformString() -> String {
        switch sfsdk_platformType() {
        case .SE2iPhone: return IPHONE_SE_2G_NAMESTRING
        case .SE3iPhone: return IPHONE_SE_3G_NAMESTRING
        case .XsiPhone: return IPHONE_XS_NAMESTRING
        case .XsMaxiPhone: return IPHONE_XSMAX_NAMESTRING
        case .XRiPhone: return IPHONE_XR_NAMESTRING
        case ._11iPhone: return IPHONE_11_NAMESTRING
        case ._11ProiPhone: return IPHONE_11_PRO_NAMESTRING
        case ._11ProMaxiPhone: return IPHONE_11_PRO_MAX_NAMESTRING
        case ._12MiniiPhone: return IPHONE_12_MINI_NAMESTRING
        case ._12iPhone: return IPHONE_12_NAMESTRING
        case ._12ProiPhone: return IPHONE_12_PRO_NAMESTRING
        case ._12ProMaxiPhone: return IPHONE_12_PRO_MAX_NAMESTRING
        case ._13MiniiPhone: return IPHONE_13_MINI_NAMESTRING
        case ._13iPhone: return IPHONE_13_NAMESTRING
        case ._13ProiPhone: return IPHONE_13_PRO_NAMESTRING
        case ._13ProMaxiPhone: return IPHONE_13_PRO_MAX_NAMESTRING
        case ._14iPhone: return IPHONE_14_NAMESTRING
        case ._14PlusiPhone: return IPHONE_14_PLUS_NAMESTRING
        case ._14ProiPhone: return IPHONE_14_PRO_NAMESTRING
        case ._14ProMaxiPhone: return IPHONE_14_PRO_MAX_NAMESTRING
        case ._15iPhone: return IPHONE_15_NAMESTRING
        case ._15PlusiPhone: return IPHONE_15_PLUS_NAMESTRING
        case ._15ProiPhone: return IPHONE_15_PRO_NAMESTRING
        case ._15ProMaxiPhone: return IPHONE_15_PRO_MAX_NAMESTRING
        case ._16ProiPhone: return IPHONE_16_PRO_NAMESTRING
        case ._16ProMaxiPhone: return IPHONE_16_PRO_MAX_NAMESTRING
        case ._16iPhone: return IPHONE_16_NAMESTRING
        case ._16PlusiPhone: return IPHONE_16_PLUS_NAMESTRING
        case .unknowniPhone: return IPHONE_UNKNOWN_NAMESTRING

        case ._5GiPadMini: return IPAD_MINI_5G_NAMESTRING
        case ._6GiPadMini: return IPAD_MINI_6G_NAMESTRING
        case ._3GiPadAir: return IPAD_AIR_3G_NAMESTRING
        case ._4GiPadAir: return IPAD_AIR_4G_NAMESTRING
        case ._5GiPadAir: return IPAD_AIR_5G_NAMESTRING
        case ._7GiPad: return IPAD_7G_NAMESTRING
        case ._8GiPad: return IPAD_8G_NAMESTRING
        case ._9GiPad: return IPAD_9G_NAMESTRING
        case ._10GiPad: return IPAD_10G_NAMESTRING
        case ._3G129InchiPadPro: return IPAD_PRO_12_9_3G_NAMESTRING
        case ._4G129InchiPadPro: return IPAD_PRO_12_9_4G_NAMESTRING
        case ._5G129InchiPadPro: return IPAD_PRO_12_9_5G_NAMESTRING
        case ._6G129InchiPadPro: return IPAD_PRO_12_9_6G_NAMESTRING
        case ._11Inch2GiPadPro: return IPAD_PRO_11_2G_NAMESTRING
        case ._11Inch3GiPadPro: return IPAD_PRO_11_3G_NAMESTRING
        case ._11Inch4GiPadPro: return IPAD_PRO_11_4G_NAMESTRING
        case ._6GiPadAir: return IPAD_AIR_6G_NAMESTRING
        case ._7GiPadAir: return IPAD_AIR_7G_NAMESTRING
        case ._7GiPadMini: return IPAD_MINI_7G_NAMESTRING
        case ._11Inch5GiPadPro: return IPAD_PRO_11_5G_NAMESTRING
        case ._12Inch7GiPadPro: return IPAD_PRO_12_7G_NAMESTRING
        case .unknowniPad: return IPAD_UNKNOWN_NAMESTRING

        case .appleTV4: return APPLETV_4G_NAMESTRING
        case .appleTV4k: return APPLETV_4K_NAMESTRING
        case .appleTV4k2G: return APPLETV_4K_2G_NAMESTRING
        case .appleTV4k3G: return APPLETV_4K_3G_NAMESTRING
        case .unknownAppleTV: return APPLETV_UNKNOWN_NAMESTRING

        case .simulator: return SIMULATOR_NAMESTRING
        case .simulatoriPhone: return SIMULATOR_IPHONE_NAMESTRING
        case .simulatoriPad: return SIMULATOR_IPAD_NAMESTRING
        case .simulatorAppleTV: return SIMULATOR_APPLETV_NAMESTRING

        case .iFPGA: return IFPGA_NAMESTRING

        default: return IOS_FAMILY_UNKNOWN_DEVICE
        }
    }

    /// Total memory.
    @objc public func sfsdk_totalMemory() -> UInt {
        return getSysInfo(HW_PHYSMEM)
    }

    /// User memory.
    @objc public func sfsdk_userMemory() -> UInt {
        return getSysInfo(HW_USERMEM)
    }

    /// Memory used by application (in bytes).
    @objc public func sfsdk_applicationMemory() -> UInt {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let kerr = withUnsafeMutablePointer(to: &info) { infoPtr in
            infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), intPtr, &count)
            }
        }
        return kerr == KERN_SUCCESS ? UInt(info.resident_size) : 0
    }

    /// Free VM page space available to application (in bytes).
    @objc public func sfsdk_freeMemory() -> UInt {
        let hostPort = mach_host_self()
        var hostSize = mach_msg_type_number_t(MemoryLayout<vm_statistics_data_t>.size / MemoryLayout<integer_t>.size)
        var pageSize: vm_size_t = 0
        var vmStat = vm_statistics_data_t()

        host_page_size(hostPort, &pageSize)

        let result = withUnsafeMutablePointer(to: &vmStat) { vmStatPtr in
            vmStatPtr.withMemoryRebound(to: integer_t.self, capacity: Int(hostSize)) { intPtr in
                host_statistics(hostPort, HOST_VM_INFO, intPtr, &hostSize)
            }
        }

        guard result == KERN_SUCCESS else { return 0 }
        return UInt(vmStat.free_count) * UInt(pageSize)
    }

    /// Total disk space.
    @objc public func sfsdk_totalDiskSpace() -> NSNumber? {
        let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
        return attrs?[.systemSize] as? NSNumber
    }

    /// Total free space.
    @objc public func sfsdk_freeDiskSpace() -> NSNumber? {
        let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
        return attrs?[.systemFreeSize] as? NSNumber
    }

    /// Returns whether the device's SOC has a neural engine for core ML tasks.
    @objc public func sfsdk_hasNeuralEngine() -> Bool {
        guard UIDevice.sfsdk_currentDeviceIsIPad() || UIDevice.sfsdk_currentDeviceIsIPhone() else {
            return false
        }

        let platform = sfsdk_platformType()
        switch platform {
        // Devices without a Neural Engine
        case .SE2iPhone, .XRiPhone, .SE3iPhone, .XsiPhone, .XsMaxiPhone,
             ._11iPhone, ._11ProiPhone, ._11ProMaxiPhone,
             ._5GiPadMini, ._3GiPadAir, ._7GiPad, ._8GiPad,
             ._3G129InchiPadPro, ._11Inch2GiPadPro:
            return false

        // Devices with a Neural Engine
        case ._12MiniiPhone, ._12iPhone, ._12ProiPhone, ._12ProMaxiPhone,
             ._13MiniiPhone, ._13iPhone, ._13ProiPhone, ._13ProMaxiPhone,
             ._14iPhone, ._14PlusiPhone, ._14ProiPhone, ._14ProMaxiPhone,
             ._15iPhone, ._15PlusiPhone, ._15ProiPhone, ._15ProMaxiPhone,
             ._16ProiPhone, ._16ProMaxiPhone, ._16iPhone, ._16PlusiPhone,
             ._6GiPadMini, ._4GiPadAir, ._5GiPadAir,
             ._9GiPad, ._10GiPad,
             ._4G129InchiPadPro, ._5G129InchiPadPro, ._6G129InchiPadPro,
             ._11Inch3GiPadPro, ._11Inch4GiPadPro:
            return true

        default:
            return false
        }
    }

    /// Device Family.
    @objc public func sfsdk_deviceFamily() -> UIDeviceFamily {
        guard let platform = sfsdk_platform() else { return .unknown }
        if platform.hasPrefix("iPhone") { return .iPhone }
        if platform.hasPrefix("iPod") { return .iPod }
        if platform.hasPrefix("iPad") { return .iPad }
        if platform.hasPrefix("AppleTV") { return .appleTV }
        return .unknown
    }

    /// Device's current orientation.
    /// This method will first try to retrieve orientation using UIDevice currentOrientation,
    /// if return value is an invalid orientation, it will try to use the orientation of the first window scene.
    @available(visionOS, unavailable)
    @objc public func sfsdk_interfaceOrientation() -> UIInterfaceOrientation {
        let deviceOrientation = UIDevice.current.orientation
        var orientation = UIInterfaceOrientation(rawValue: deviceOrientation.rawValue) ?? .unknown
        if !deviceOrientation.isValidInterfaceOrientation {
            if let windowScene = SFApplicationHelper.sharedApplication()?.connectedScenes.first(where: { $0 is UIWindowScene }) as? UIWindowScene {
                orientation = windowScene.interfaceOrientation
            } else {
                orientation = .unknown
            }
        }
        return orientation
    }

    /// Determine if current device is simulator or not.
    @objc public func sfsdk_isSimulator() -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    /// Return YES if device is iPad.
    @objc public static func sfsdk_currentDeviceIsIPad() -> Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }

    /// Return YES if device is iPhone.
    @objc public static func sfsdk_currentDeviceIsIPhone() -> Bool {
        return UIDevice.current.userInterfaceIdiom == .phone
    }
}
