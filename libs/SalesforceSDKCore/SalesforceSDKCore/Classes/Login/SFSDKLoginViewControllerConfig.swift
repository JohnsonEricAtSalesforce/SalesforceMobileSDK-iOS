// SFSDKLoginViewControllerConfig.swift
// SalesforceSDKCore
//
// Created by Raj Rao on 11/15/17.
// Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.
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

/// Block typedef for creating a custom SFLoginViewController.
public typealias LoginViewControllerCreationBlock = () -> SalesforceLoginViewController

@objc(SFSDKLoginViewControllerConfig)
@objcMembers
public class SalesforceLoginViewControllerConfig: SFSDKViewControllerConfig {

    /// Specify visibility of nav bar.
    @objc public var showNavbar: Bool = true

    /// Specify the visibility of the settings icon.
    @objc public var showSettingsIcon: Bool = true

    // Swift-name compatibility: prior SDK releases surfaced these to Swift as `showsNavigationBar`
    // and `showsSettingsIcon` via `NS_SWIFT_NAME` on the Objective-C properties. The ObjC→Swift
    // migration re-declared them under the shorter ObjC identifiers, dropping the historical Swift
    // spellings. These `@nonobjc` computed aliases restore source compatibility for Swift consumers
    // (and the sample apps); they forward to the primary stored properties.

    @nonobjc public var showsNavigationBar: Bool {
        get { showNavbar }
        set { showNavbar = newValue }
    }

    @nonobjc public var showsSettingsIcon: Bool {
        get { showSettingsIcon }
        set { showSettingsIcon = newValue }
    }

    /// Specify the visibility of the server picker option in the settings menu.
    @objc public var showServerPicker: Bool = true

    /// Specify the visibility of the back icon. Value is derived from shouldAuthenticate in bootconfig.
    @objc public var shouldDisplayBackButton: Bool {
        return !(SalesforceSDKManager.shared.bootConfig?.shouldAuthenticate ?? true)
    }

    /// Specify a delegate for LoginViewController.
    @objc public weak var delegate: SalesforceLoginViewControllerDelegate?

    /// Block for creating a custom login view controller.
    @objc public var loginViewControllerCreationBlock: LoginViewControllerCreationBlock?

    public override init() {
        super.init()
        navBarColor = UIColor.salesforceBlueColor
        navBarTitleColor = .white
        navBarTintColor = UIColor.salesforceNavBarTintColor
        navBarFont = nil
    }
}
