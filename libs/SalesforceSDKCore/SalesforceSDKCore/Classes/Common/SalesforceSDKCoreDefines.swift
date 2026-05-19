// SalesforceSDKCoreDefines.swift
//
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

// MARK: - Error Constants

/// Error domain for SalesforceSDKManager errors.
public let kSalesforceSDKManagerErrorDomain: String = "com.salesforce.sdkmanager.error"

/// Error details key for SalesforceSDKManager errors.
public let kSalesforceSDKManagerErrorDetailsKey: String = "SalesforceSDKManagerErrorDetails"

/// Unknown error code.
public let kSalesforceSDKManagerErrorUnknown: Int = 766

/// Invalid launch parameters error code.
public let kSalesforceSDKManagerErrorInvalidLaunchParameters: Int = 767

// MARK: - Block Type Definitions

/// Block to return a user agent string, with an optional qualifier.
public typealias UserAgentGeneratorBlock = (_ qualifier: String) -> String

/// Block typedef for creating a custom login flow selection dialog.
public typealias IDPLoginFlowSelectionBlock = () -> UIViewController & SFSDKLoginFlowSelectionView

/// Block typedef for creating a custom user selection flow for IDP provider app.
public typealias IDPUserSelectionBlock = () -> UIViewController & SFSDKUserSelectionView

/// Block to select an app config at runtime based on the login host.
/// The block takes a login host and a callback. The callback should be invoked with the selected app config.
public typealias BootConfigRuntimeSelector = (_ loginHost: String, _ callback: @escaping (BootConfig?) -> Void) -> Void
