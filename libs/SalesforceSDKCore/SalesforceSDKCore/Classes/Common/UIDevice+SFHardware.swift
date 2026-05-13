/*
 Erica Sadun, http://ericasadun.com
 iPhone Developer's Cookbook, 6.x Edition
 BSD License, Use at your own risk
 */

// Thanks to Emanuele Vulcano, Kevin Ballard/Eridius, Ryandjohnson, Matt Brown, etc.

import Foundation
import UIKit
import Darwin

// MARK: - Constants

private let IFPGA_NAMESTRING = "iFPGA"

// Supported iPhones
private let IPHONE_SE_2G_NAMESTRING = "iPhone SE (2nd generation)"
private let IPHONE_SE_3G_NAMESTRING = "iPhone SE (3rd generation)"
private let IPHONE_XS_NAMESTRING = "iPhone XS"
private let IPHONE_XSMAX_NAMESTRING = "iPhone XS Max"
private let IPHONE_XR_NAMESTRING = "iPhone XR"
private let IPHONE_11_NAMESTRING = "iPhone 11"
private let IPHONE_11_PRO_NAMESTRING = "iPhone 11 Pro"
private let IPHONE_11_PRO_MAX_NAMESTRING = "iPhone 11 Pro Max"
private let IPHONE_12_MINI_NAMESTRING = "iPhone 12 Mini"
private let IPHONE_12_NAMESTRING = "iPhone 12"
private let IPHONE_12_PRO_NAMESTRING = "iPhone 12 Pro"
private let IPHONE_12_PRO_MAX_NAMESTRING = "iPhone 12 Pro Max"
private let IPHONE_13_MINI_NAMESTRING = "iPhone 13 Mini"
private let IPHONE_13_NAMESTRING = "iPhone 13"
private let IPHONE_13_PRO_NAMESTRING = "iPhone 13 Pro"
private let IPHONE_13_PRO_MAX_NAMESTRING = "iPhone 13 Pro Max"
private let IPHONE_14_NAMESTRING = "iPhone 14"
private let IPHONE_14_PLUS_NAMESTRING = "iPhone 14 Plus"
private let IPHONE_14_PRO_NAMESTRING = "iPhone 14 Pro"
private let IPHONE_14_PRO_MAX_NAMESTRING = "iPhone 14 Pro Max"
private let IPHONE_15_NAMESTRING = "iPhone 15"
private let IPHONE_15_PLUS_NAMESTRING = "iPhone 15 Plus"
private let IPHONE_15_PRO_NAMESTRING = "iPhone 15 Pro"
private let IPHONE_15_PRO_MAX_NAMESTRING = "iPhone 15 Pro Max"
private let IPHONE_16_PRO_NAMESTRING = "iPhone 16 Pro"
private let IPHONE_16_PRO_MAX_NAMESTRING = "iPhone 16 Pro Max"
private let IPHONE_16_NAMESTRING = "iPhone 16"
private let IPHONE_16_PLUS_NAMESTRING = "iPhone 16 Plus"
private let IPHONE_UNKNOWN_NAMESTRING = "Unknown iPhone"

// Supported iPads
private let IPAD_MINI_5G_NAMESTRING = "iPad mini (5th generation)"
private let IPAD_MINI_6G_NAMESTRING = "iPad mini (6th generation)"
private let IPAD_MINI_7G_NAMESTRING = "iPad mini 7th Gen"
private let IPAD_AIR_3G_NAMESTRING = "iPad Air (3rd generation)"
private let IPAD_AIR_4G_NAMESTRING = "iPad Air (4th generation)"
private let IPAD_AIR_5G_NAMESTRING = "iPad Air (5th generation)"
private let IPAD_AIR_6G_NAMESTRING = "iPad Air 6th Gen"
private let IPAD_AIR_7G_NAMESTRING = "iPad Air 7th Gen"
private let IPAD_7G_NAMESTRING = "iPad (7th generation)"
private let IPAD_8G_NAMESTRING = "iPad (8th generation)"
private let IPAD_9G_NAMESTRING = "iPad (9th generation)"
private let IPAD_10G_NAMESTRING = "iPad (10th generation)"
private let IPAD_PRO_11_2G_NAMESTRING = "iPad Pro (11-inch, 2nd generation)"
private let IPAD_PRO_11_3G_NAMESTRING = "iPad Pro (11-inch, 3rd generation)"
private let IPAD_PRO_11_4G_NAMESTRING = "iPad Pro (11-inch, 4th generation)"
private let IPAD_PRO_12_9_3G_NAMESTRING = "iPad Pro (12.9-inch, 3rd generation)"
private let IPAD_PRO_12_9_4G_NAMESTRING = "iPad Pro (12.9-inch, 4th generation)"
private let IPAD_PRO_12_9_5G_NAMESTRING = "iPad Pro (12.9-inch, 5th generation)"
private let IPAD_PRO_12_9_6G_NAMESTRING = "iPad Pro (12.9-inch, 6th generation)"
private let IPAD_PRO_11_5G_NAMESTRING = "iPad Pro 11 inch 5th Gen"
private let IPAD_PRO_12_7G_NAMESTRING = "iPad Pro 12.9 inch 7th Gen"
private let IPAD_UNKNOWN_NAMESTRING = "Unknown iPad"

// Supported Apple TVs
private let APPLETV_4G_NAMESTRING = "Apple TV HD"
private let APPLETV_4K_NAMESTRING = "Apple TV 4K (1st generation)"
private let APPLETV_4K_2G_NAMESTRING = "Apple TV 4K (2nd generation)"
private let APPLETV_4K_3G_NAMESTRING = "Apple TV 4K (3rd generation)"
private let APPLETV_UNKNOWN_NAMESTRING = "Unknown Apple TV"

// Simulator
private let SIMULATOR_NAMESTRING = "iPhone Simulator"
private let SIMULATOR_IPHONE_NAMESTRING = "iPhone Simulator"
private let SIMULATOR_IPAD_NAMESTRING = "iPad Simulator"
private let SIMULATOR_APPLETV_NAMESTRING = "Apple TV Simulator"

// Unknown
private let IOS_FAMILY_UNKNOWN_DEVICE = "Unknown iOS device"

// MARK: - Enums

@objc public enum UIDevicePlatform: Int {
    case unknown
    case iFPGA
    case simulator
    case simulatoriPhone
    case simulatoriPad
    case simulatorAppleTV

    // Supported iPhones
    case se2iPhone
    case se3iPhone
    case xriPhone
    case xsiPhone
    case xsMaxiPhone
    case iPhone11
    case iPhone11Pro
    case iPhone11ProMax
    case iPhone12Mini
    case iPhone12
    case iPhone12Pro
    case iPhone12ProMax
    case iPhone13Mini
    case iPhone13
    case iPhone13Pro
    case iPhone13ProMax
    case iPhone14
    case iPhone14Plus
    case iPhone14Pro
    case iPhone14ProMax
    case iPhone15
    case iPhone15Plus
    case iPhone15Pro
    case iPhone15ProMax
    case iPhone16Pro
    case iPhone16ProMax
    case iPhone16
    case iPhone16Plus

    // Supported iPads
    case iPad5GMini
    case iPad6GMini
    case iPad3GAir
    case iPad4GAir
    case iPad5GAir
    case iPad7G
    case iPad8G
    case iPad9G
    case iPad10G
    case iPadProM1_12_9Inch
    case iPadPro3G_12_9Inch
    case iPadPro4G_12_9Inch
    case iPadPro5G_12_9Inch
    case iPadPro6G_12_9Inch
    case iPadPro11Inch
    case iPadPro11Inch2G
    case iPadPro11Inch3G
    case iPadPro11Inch4G
    case iPad6GAir
    case iPad7GAir
    case iPad7GMini
    case iPadPro11Inch5G
    case iPadPro12Inch7G

    // Supported Apple TVs
    case appleTV4
    case appleTV4k
    case appleTV4k2G
    case appleTV4k3G

    case unknowniPhone
    case unknowniPad
    case unknownAppleTV
}

@objc public enum UIDeviceFamily: Int {
    case iPhone
    case iPod
    case iPad
    case appleTV
    case unknown
}

// MARK: - UIDevice Extension

@objc public extension UIDevice {

    // MARK: - Platform Detection

    @objc(sfsdk_platform)
    var platform: String? {
        return getSysInfoByName("hw.machine")
    }

    @objc(sfsdk_platformType)
    var platformType: UIDevicePlatform {
        guard let platform = platform else { return .unknown }

        if platform == "iFPGA" { return .iFPGA }

        if isSimulator {
            switch userInterfaceIdiom {
            case .phone: return .simulatoriPhone
            case .pad: return .simulatoriPad
            default: return .simulator
            }
        }

        // iPhone identifiers
        let iphoneIdentifiers: [String: UIDevicePlatform] = [
            "iPhone12,8": .se2iPhone,
            "iPhone14,6": .se3iPhone,
            "iPhone11,8": .xriPhone,
            "iPhone11,2": .xsiPhone,
            "iPhone11,4": .xsMaxiPhone,
            "iPhone11,6": .xsMaxiPhone,
            "iPhone12,1": .iPhone11,
            "iPhone12,3": .iPhone11Pro,
            "iPhone12,5": .iPhone11ProMax,
            "iPhone13,1": .iPhone12Mini,
            "iPhone13,2": .iPhone12,
            "iPhone13,3": .iPhone12Pro,
            "iPhone13,4": .iPhone12ProMax,
            "iPhone14,4": .iPhone13Mini,
            "iPhone14,5": .iPhone13,
            "iPhone14,2": .iPhone13Pro,
            "iPhone14,3": .iPhone13ProMax,
            "iPhone14,7": .iPhone14,
            "iPhone14,8": .iPhone14Plus,
            "iPhone15,2": .iPhone14Pro,
            "iPhone15,3": .iPhone14ProMax,
            "iPhone15,4": .iPhone15,
            "iPhone15,5": .iPhone15Plus,
            "iPhone16,1": .iPhone15Pro,
            "iPhone16,2": .iPhone15ProMax,
            "iPhone17,1": .iPhone16Pro,
            "iPhone17,2": .iPhone16ProMax,
            "iPhone17,3": .iPhone16,
            "iPhone17,4": .iPhone16Plus
        ]

        if let iphoneType = iphoneIdentifiers[platform] {
            return iphoneType
        }

        // iPad identifiers
        let ipadIdentifiers: [String: UIDevicePlatform] = [
            "iPad7,11": .iPad7G,
            "iPad7,12": .iPad7G,
            "iPad8,1": .iPadPro11Inch,
            "iPad8,2": .iPadPro11Inch,
            "iPad8,3": .iPadPro11Inch,
            "iPad8,4": .iPadPro11Inch,
            "iPad8,5": .iPadPro3G_12_9Inch,
            "iPad8,6": .iPadPro3G_12_9Inch,
            "iPad8,7": .iPadPro3G_12_9Inch,
            "iPad8,8": .iPadPro3G_12_9Inch,
            "iPad8,9": .iPadPro11Inch2G,
            "iPad8,10": .iPadPro11Inch2G,
            "iPad8,11": .iPadPro4G_12_9Inch,
            "iPad8,12": .iPadPro4G_12_9Inch,
            "iPad11,3": .iPad3GAir,
            "iPad11,4": .iPad3GAir,
            "iPad11,1": .iPad5GMini,
            "iPad11,2": .iPad5GMini,
            "iPad11,6": .iPad8G,
            "iPad11,7": .iPad8G,
            "iPad12,1": .iPad9G,
            "iPad12,2": .iPad9G,
            "iPad13,1": .iPad4GAir,
            "iPad13,2": .iPad4GAir,
            "iPad13,4": .iPadPro11Inch3G,
            "iPad13,5": .iPadPro11Inch3G,
            "iPad13,6": .iPadPro11Inch3G,
            "iPad13,7": .iPadPro11Inch3G,
            "iPad13,8": .iPadPro5G_12_9Inch,
            "iPad13,9": .iPadPro5G_12_9Inch,
            "iPad13,10": .iPadPro5G_12_9Inch,
            "iPad13,11": .iPadPro5G_12_9Inch,
            "iPad13,16": .iPad5GAir,
            "iPad13,17": .iPad5GAir,
            "iPad13,18": .iPad10G,
            "iPad13,19": .iPad10G,
            "iPad14,1": .iPad6GMini,
            "iPad14,2": .iPad6GMini,
            "iPad14,3": .iPadPro6G_12_9Inch,
            "iPad14,4": .iPadPro6G_12_9Inch,
            "iPad14,5": .iPadPro11Inch4G,
            "iPad14,6": .iPadPro11Inch4G,
            "iPad14,8": .iPad6GAir,
            "iPad14,9": .iPad6GAir,
            "iPad14,10": .iPad7GAir,
            "iPad14,11": .iPad7GAir,
            "iPad16,1": .iPad7GMini,
            "iPad16,2": .iPad7GMini,
            "iPad16,3": .iPadPro11Inch5G,
            "iPad16,4": .iPadPro11Inch5G,
            "iPad16,5": .iPadPro12Inch7G,
            "iPad16,6": .iPadPro12Inch7G
        ]

        if let ipadType = ipadIdentifiers[platform] {
            return ipadType
        }

        // Apple TV identifiers
        let appleTVIdentifiers: [String: UIDevicePlatform] = [
            "AppleTV5,3": .appleTV4,
            "AppleTV6,2": .appleTV4k,
            "AppleTV11,1": .appleTV4k2G,
            "AppleTV14,1": .appleTV4k3G
        ]

        if let appleTVType = appleTVIdentifiers[platform] {
            return appleTVType
        }

        // Check for unknown device families
        if platform.hasPrefix("iPhone") { return .unknowniPhone }
        if platform.hasPrefix("iPad") { return .unknowniPad }
        if platform.hasPrefix("AppleTV") { return .unknownAppleTV }

        return .unknown
    }

    @objc(sfsdk_systemVersionNumber)
    var systemVersionNumber: Double {
        return (systemVersion as NSString).doubleValue
    }

    @objc(sfsdk_platformString)
    var platformString: String {
        switch platformType {
        case .se2iPhone: return IPHONE_SE_2G_NAMESTRING
        case .se3iPhone: return IPHONE_SE_3G_NAMESTRING
        case .xsiPhone: return IPHONE_XS_NAMESTRING
        case .xsMaxiPhone: return IPHONE_XSMAX_NAMESTRING
        case .xriPhone: return IPHONE_XR_NAMESTRING
        case .iPhone11: return IPHONE_11_NAMESTRING
        case .iPhone11Pro: return IPHONE_11_PRO_NAMESTRING
        case .iPhone11ProMax: return IPHONE_11_PRO_MAX_NAMESTRING
        case .iPhone12Mini: return IPHONE_12_MINI_NAMESTRING
        case .iPhone12: return IPHONE_12_NAMESTRING
        case .iPhone12Pro: return IPHONE_12_PRO_NAMESTRING
        case .iPhone12ProMax: return IPHONE_12_PRO_MAX_NAMESTRING
        case .iPhone13Mini: return IPHONE_13_MINI_NAMESTRING
        case .iPhone13: return IPHONE_13_NAMESTRING
        case .iPhone13Pro: return IPHONE_13_PRO_NAMESTRING
        case .iPhone13ProMax: return IPHONE_13_PRO_MAX_NAMESTRING
        case .iPhone14: return IPHONE_14_NAMESTRING
        case .iPhone14Plus: return IPHONE_14_PLUS_NAMESTRING
        case .iPhone14Pro: return IPHONE_14_PRO_NAMESTRING
        case .iPhone14ProMax: return IPHONE_14_PRO_MAX_NAMESTRING
        case .iPhone15: return IPHONE_15_NAMESTRING
        case .iPhone15Plus: return IPHONE_15_PLUS_NAMESTRING
        case .iPhone15Pro: return IPHONE_15_PRO_NAMESTRING
        case .iPhone15ProMax: return IPHONE_15_PRO_MAX_NAMESTRING
        case .iPhone16Pro: return IPHONE_16_PRO_NAMESTRING
        case .iPhone16ProMax: return IPHONE_16_PRO_MAX_NAMESTRING
        case .iPhone16: return IPHONE_16_NAMESTRING
        case .iPhone16Plus: return IPHONE_16_PLUS_NAMESTRING
        case .unknowniPhone: return IPHONE_UNKNOWN_NAMESTRING
        case .iPad5GMini: return IPAD_MINI_5G_NAMESTRING
        case .iPad6GMini: return IPAD_MINI_6G_NAMESTRING
        case .iPad3GAir: return IPAD_AIR_3G_NAMESTRING
        case .iPad4GAir: return IPAD_AIR_4G_NAMESTRING
        case .iPad5GAir: return IPAD_AIR_5G_NAMESTRING
        case .iPad7G: return IPAD_7G_NAMESTRING
        case .iPad8G: return IPAD_8G_NAMESTRING
        case .iPad9G: return IPAD_9G_NAMESTRING
        case .iPad10G: return IPAD_10G_NAMESTRING
        case .iPadPro3G_12_9Inch: return IPAD_PRO_12_9_3G_NAMESTRING
        case .iPadPro4G_12_9Inch: return IPAD_PRO_12_9_4G_NAMESTRING
        case .iPadPro5G_12_9Inch: return IPAD_PRO_12_9_5G_NAMESTRING
        case .iPadPro6G_12_9Inch: return IPAD_PRO_12_9_6G_NAMESTRING
        case .iPadPro11Inch2G: return IPAD_PRO_11_2G_NAMESTRING
        case .iPadPro11Inch3G: return IPAD_PRO_11_3G_NAMESTRING
        case .iPadPro11Inch4G: return IPAD_PRO_11_4G_NAMESTRING
        case .iPad6GAir: return IPAD_AIR_6G_NAMESTRING
        case .iPad7GAir: return IPAD_AIR_7G_NAMESTRING
        case .iPad7GMini: return IPAD_MINI_7G_NAMESTRING
        case .iPadPro11Inch5G: return IPAD_PRO_11_5G_NAMESTRING
        case .iPadPro12Inch7G: return IPAD_PRO_12_7G_NAMESTRING
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

    // MARK: - Memory

    @objc(sfsdk_totalMemory)
    var totalMemory: UInt {
        return getSysInfo(HW_PHYSMEM)
    }

    @objc(sfsdk_userMemory)
    var userMemory: UInt {
        return getSysInfo(HW_USERMEM)
    }

    @objc(sfsdk_applicationMemory)
    var applicationMemory: UInt {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        return kerr == KERN_SUCCESS ? UInt(info.resident_size) : 0
    }

    @objc(sfsdk_freeMemory)
    var freeMemory: UInt {
        let hostPort = mach_host_self()
        var hostSize = mach_msg_type_number_t(MemoryLayout<vm_statistics_data_t>.stride / MemoryLayout<integer_t>.stride)
        var pagesize: vm_size_t = 0
        var vmStat = vm_statistics_data_t()

        host_page_size(hostPort, &pagesize)

        let result = withUnsafeMutablePointer(to: &vmStat) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(hostSize)) {
                host_statistics(hostPort, HOST_VM_INFO, $0, &hostSize)
            }
        }

        guard result == KERN_SUCCESS else { return 0 }

        return UInt(vmStat.free_count) * UInt(pagesize)
    }

    // MARK: - Disk Space

    @objc(sfsdk_totalDiskSpace)
    var totalDiskSpace: NSNumber {
        let fileManager = FileManager.default
        let attributes = try? fileManager.attributesOfFileSystem(forPath: NSHomeDirectory())
        return (attributes?[.systemSize] as? NSNumber) ?? 0
    }

    @objc(sfsdk_freeDiskSpace)
    var freeDiskSpace: NSNumber {
        let fileManager = FileManager.default
        let attributes = try? fileManager.attributesOfFileSystem(forPath: NSHomeDirectory())
        return (attributes?[.systemFreeSize] as? NSNumber) ?? 0
    }

    // MARK: - Neural Engine

    @objc(sfsdk_hasNeuralEngine)
    var hasNeuralEngine: Bool {
        guard UIDevice.currentDeviceIsIPad || UIDevice.currentDeviceIsIPhone else {
            return false
        }

        switch platformType {
        // Devices without Neural Engine
        case .se2iPhone, .xriPhone, .se3iPhone, .xsiPhone, .xsMaxiPhone,
             .iPhone11, .iPhone11Pro, .iPhone11ProMax,
             .iPad5GMini, .iPad3GAir, .iPad7G, .iPad8G,
             .iPadPro3G_12_9Inch, .iPadPro11Inch2G:
            return false

        // Devices with Neural Engine
        case .iPhone12Mini, .iPhone12, .iPhone12Pro, .iPhone12ProMax,
             .iPhone13Mini, .iPhone13, .iPhone13Pro, .iPhone13ProMax,
             .iPhone14, .iPhone14Plus, .iPhone14Pro, .iPhone14ProMax,
             .iPhone15, .iPhone15Plus, .iPhone15Pro, .iPhone15ProMax,
             .iPhone16Pro, .iPhone16ProMax, .iPhone16, .iPhone16Plus,
             .iPad6GMini, .iPad4GAir, .iPad5GAir, .iPad9G, .iPad10G,
             .iPadPro4G_12_9Inch, .iPadPro5G_12_9Inch, .iPadPro6G_12_9Inch,
             .iPadPro11Inch3G, .iPadPro11Inch4G:
            return true

        default:
            return false
        }
    }

    // MARK: - Device Family

    @objc(sfsdk_deviceFamily)
    var deviceFamily: UIDeviceFamily {
        guard let platform = platform else { return .unknown }

        if platform.hasPrefix("iPhone") { return .iPhone }
        if platform.hasPrefix("iPod") { return .iPod }
        if platform.hasPrefix("iPad") { return .iPad }
        if platform.hasPrefix("AppleTV") { return .appleTV }

        return .unknown
    }

    #if !os(visionOS)
    @objc(sfsdk_interfaceOrientation)
    var interfaceOrientation: UIInterfaceOrientation {
        let deviceOrientation = UIDevice.current.orientation
        var orientation = UIInterfaceOrientation(rawValue: deviceOrientation.rawValue) ?? .unknown

        if !deviceOrientation.isValidInterfaceOrientation {
            if let app = SFApplicationHelper.sharedApplication(), let windowScene = app.connectedScenes.first as? UIWindowScene {
                orientation = windowScene.interfaceOrientation
            } else {
                orientation = .unknown
            }
        }

        return orientation
    }
    #endif

    // MARK: - Device Type Checks

    @objc(sfsdk_currentDeviceIsIPad)
    static var currentDeviceIsIPad: Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }

    @objc(sfsdk_currentDeviceIsIPhone)
    static var currentDeviceIsIPhone: Bool {
        return UIDevice.current.userInterfaceIdiom == .phone
    }

    @objc(sfsdk_isSimulator)
    var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    // MARK: - Private Helpers

    private func getSysInfoByName(_ typeSpecifier: String) -> String? {
        var size: Int = 0
        sysctlbyname(typeSpecifier, nil, &size, nil, 0)

        var result = [CChar](repeating: 0, count: size)
        sysctlbyname(typeSpecifier, &result, &size, nil, 0)

        return String(cString: result)
    }

    private func getSysInfo(_ typeSpecifier: Int32) -> UInt {
        var size = MemoryLayout<Int>.size
        var results: Int = 0
        var mib: [Int32] = [CTL_HW, typeSpecifier]

        sysctl(&mib, 2, &results, &size, nil, 0)
        return UInt(results)
    }
}
