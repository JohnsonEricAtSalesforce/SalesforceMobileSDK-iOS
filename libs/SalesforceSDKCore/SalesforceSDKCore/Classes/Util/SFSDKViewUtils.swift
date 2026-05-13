/*
 SFSDKViewUtils.swift
 SalesforceSDKCore

 Created by Raj Rao on 2/5/19.
 Copyright (c) 2019-present, salesforce.com, inc. All rights reserved.

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

@objc(SFSDKViewUtils)
public class SFSDKViewUtils: NSObject {

    @objc
    public static func styleNavigationBar(_ navigationBar: UINavigationBar?, config: SFSDKViewControllerConfig?, classes: [AnyClass]) {
        guard let navigationBar = navigationBar, let config = config else {
            return
        }

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()

        if let navBarColor = config.navigationBarColor {
            appearance.backgroundColor = navBarColor
            navigationBar.backgroundColor = navBarColor
        }

        var textAttributes: [NSAttributedString.Key: Any] = [:]

        if let navBarTintColor = config.navigationBarTintColor {
            navigationBar.tintColor = navBarTintColor
            textAttributes[.foregroundColor] = navBarTintColor
        } else {
            // default color
            navigationBar.tintColor = UIColor.salesforceNavBarTintColor
        }

        if let navBarTitleColor = config.navigationTitleColor {
            textAttributes[.foregroundColor] = navBarTitleColor
        }

        if let navBarFont = config.navigationBarFont {
            textAttributes[.font] = navBarFont
        }

        if !textAttributes.isEmpty {
            appearance.titleTextAttributes = textAttributes
            navigationBar.titleTextAttributes = textAttributes
        }

        let appearanceClasses = classes.compactMap { $0 as? any UIAppearanceContainer.Type }
        UINavigationBar.appearance(whenContainedInInstancesOf: appearanceClasses).standardAppearance = appearance
        UINavigationBar.appearance(whenContainedInInstancesOf: appearanceClasses).compactAppearance = appearance
        UINavigationBar.appearance(whenContainedInInstancesOf: appearanceClasses).scrollEdgeAppearance = appearance
        UINavigationBar.appearance(whenContainedInInstancesOf: appearanceClasses).compactScrollEdgeAppearance = appearance
    }

    @objc
    public static func headerBackgroundImage(_ color: UIColor) -> UIImage {
        return imageFromColor(color)
    }

    @objc
    public static func imageFromColor(_ color: UIColor) -> UIImage {
        let rect = CGRect(x: 0, y: 0, width: 1, height: 1)
        UIGraphicsBeginImageContext(rect.size)

        if let context = UIGraphicsGetCurrentContext() {
            context.setFillColor(color.cgColor)
            context.fill(rect)
        }

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return image ?? UIImage()
    }
}
