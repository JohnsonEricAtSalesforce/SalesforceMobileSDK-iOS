/*
 UIColor+SFColors.swift
 SalesforceSDKCore

 Created by Kunal Chitalia on 3/28/16.
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
import UIKit

@objc public extension UIColor {

    // MARK: - Salesforce Brand Colors

    /// Salesforce blue color
    @objc static var salesforceBlueColor: UIColor {
        return UIColor(red: 0.0 / 255.0, green: 112.0 / 255.0, blue: 210.0 / 255.0, alpha: 1.0)
    }

    @objc static var salesforceSystemBackgroundColor: UIColor {
        return UIColor.systemBackground
    }

    @objc static var salesforceLabelColor: UIColor {
        return UIColor.label
    }

    @objc static var salesforceBackgroundRowSelectedColor: UIColor {
        return UIColor(red: 240.0 / 255.0, green: 248.0 / 255.0, blue: 252.0 / 255.0, alpha: 1.0)
    }

    @objc static var salesforceBorderColor: UIColor {
        return UIColor(red: 216.0 / 255.0, green: 221.0 / 255.0, blue: 230.0 / 255.0, alpha: 1.0)
    }

    @objc static var salesforceWeakTextColor: UIColor {
        return UIColor(red: 84.0 / 255.0, green: 105.0 / 255.0, blue: 141.0 / 255.0, alpha: 1.0)
    }

    @objc static var salesforceDefaultTextColor: UIColor {
        return UIColor(red: 22.0 / 255.0, green: 50.0 / 255.0, blue: 92.0 / 255.0, alpha: 1.0)
    }

    @objc static var salesforceAltTextColor: UIColor {
        return UIColor(red: 24.0 / 255.0, green: 52.0 / 255.0, blue: 95.0 / 255.0, alpha: 1.0)
    }

    @objc static var salesforceAlt2BackgroundColor: UIColor {
        return UIColor(red: 224.0 / 255.0, green: 229.0 / 255.0, blue: 238.0 / 255.0, alpha: 1.0)
    }

    @objc static var salesforceAltBackgroundColor: UIColor {
        return UIColor.white
    }

    @objc static var salesforceTableCellBackgroundColor: UIColor {
        return UIColor(red: 245.0 / 255.0, green: 246.0 / 255.0, blue: 250.0 / 255.0, alpha: 1.0)
    }

    @objc static var salesforceNavBarTintColor: UIColor {
        return UIColor.white
    }

    // MARK: - Color Utilities

    /// Construct a color given hex color, like "#00FF00" (#RRGGBB).
    /// - Parameter hexString: The hex color string
    /// - Returns: The UIColor or nil if invalid
    @objc(sfsdk_colorFromHexValue:)
    static func sfsdk_color(fromHexValue hexString: String) -> UIColor? {
        guard let sixDigitHex = sfsdk_sixDigitHex(from: hexString), !sixDigitHex.isEmpty else {
            return nil
        }

        var rgbValue: UInt32 = 0
        let scanner = Scanner(string: sixDigitHex)
        scanner.scanHexInt32(&rgbValue)

        let red = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((rgbValue & 0xFF00) >> 8) / 255.0
        let blue = CGFloat(rgbValue & 0xFF) / 255.0

        return UIColor(red: red, green: green, blue: blue, alpha: 1.0)
    }

    private static func sfsdk_sixDigitHex(from hexString: String) -> String? {
        if hexString.isEmpty {
            return nil
        }

        var hex = hexString
        if hex.hasPrefix("#") {
            hex = String(hex.dropFirst())
        }

        if hex.count == 6 {
            return hex
        }

        // invalid shorthand representation
        if hex.count != 3 {
            return nil
        }

        var sixDigitHex = ""
        for char in hex {
            sixDigitHex.append(char)
            sixDigitHex.append(char)
        }

        return sixDigitHex
    }

    /// Returns a color that adapts to light and dark modes
    /// - Parameters:
    ///   - lightStyleColor: Color for light mode
    ///   - darkStyleColor: Color for dark mode
    /// - Returns: Dynamic color
    @objc(sfsdk_colorForLightStyle:darkStyle:)
    static func sfsdk_color(forLightStyle lightStyleColor: UIColor, darkStyle darkStyleColor: UIColor) -> UIColor {
        return UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return darkStyleColor
            } else {
                return lightStyleColor
            }
        }
    }

    /// Returns a CSS hex color representation of this color
    /// - Returns: Hex string representation like "#RRGGBB"
    @objc func sfsdk_hexStringFromColor() -> String {
        assert(canProvideRGBComponents, "Must be a RGB color to use hexStringFromColor")

        var r = red
        var g = green
        var b = blue

        // Fix range if needed
        if r < 0.0 { r = 0.0 }
        if g < 0.0 { g = 0.0 }
        if b < 0.0 { b = 0.0 }

        if r > 1.0 { r = 1.0 }
        if g > 1.0 { g = 1.0 }
        if b > 1.0 { b = 1.0 }

        // Convert to hex string between 0x00 and 0xFF
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }

    // MARK: - Color Space Helpers

    private var colorSpaceModel: CGColorSpaceModel {
        guard let colorSpace = cgColor.colorSpace else {
            return .unknown
        }
        return colorSpace.model
    }

    private var colorSpaceString: String {
        switch colorSpaceModel {
        case .unknown:
            return "kCGColorSpaceModelUnknown"
        case .monochrome:
            return "kCGColorSpaceModelMonochrome"
        case .rgb:
            return "kCGColorSpaceModelRGB"
        case .cmyk:
            return "kCGColorSpaceModelCMYK"
        case .lab:
            return "kCGColorSpaceModelLab"
        case .deviceN:
            return "kCGColorSpaceModelDeviceN"
        case .indexed:
            return "kCGColorSpaceModelIndexed"
        case .pattern:
            return "kCGColorSpaceModelPattern"
        @unknown default:
            return "Not a valid color space"
        }
    }

    private var canProvideRGBComponents: Bool {
        return colorSpaceModel == .rgb || colorSpaceModel == .monochrome
    }

    private var red: CGFloat {
        assert(canProvideRGBComponents, "Must be a RGB color to use -red, -green, -blue")
        guard let components = cgColor.components else { return 0.0 }
        return components[0]
    }

    private var green: CGFloat {
        assert(canProvideRGBComponents, "Must be a RGB color to use -red, -green, -blue")
        guard let components = cgColor.components else { return 0.0 }
        if colorSpaceModel == .monochrome { return components[0] }
        return components[1]
    }

    private var blue: CGFloat {
        assert(canProvideRGBComponents, "Must be a RGB color to use -red, -green, -blue")
        guard let components = cgColor.components else { return 0.0 }
        if colorSpaceModel == .monochrome { return components[0] }
        return components[2]
    }

    private var alpha: CGFloat {
        guard let components = cgColor.components else { return 1.0 }
        return components[cgColor.numberOfComponents - 1]
    }
}
