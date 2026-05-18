/*
 SFSDKDeviceAppAttributes.swift
 SalesforceAnalytics

 Created by Bharath Hariharan on 5/24/16.

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

/// Represents device and app attributes for analytics events.
@objc(SFSDKDeviceAppAttributes)
@objcMembers
public class SFSDKDeviceAppAttributes: NSObject {

    // MARK: - JSON Keys

    private static let kAppVersionKey = "appVersion"
    private static let kAppNameKey = "appName"
    private static let kOsVersionKey = "osVersion"
    private static let kOsNameKey = "osName"
    private static let kNativeAppTypeKey = "nativeAppType"
    private static let kMobileSdkVersionKey = "mobileSdkVersion"
    private static let kDeviceModelKey = "deviceModel"
    private static let kDeviceIdKey = "deviceId"
    private static let kClientIdKey = "clientId"

    // MARK: - Properties

    public private(set) var appVersion: String
    public private(set) var appName: String
    public private(set) var osVersion: String
    public private(set) var osName: String
    public private(set) var nativeAppType: String
    public private(set) var mobileSdkVersion: String
    public private(set) var deviceModel: String
    public private(set) var deviceId: String
    public private(set) var clientId: String

    // MARK: - Initializers

    /// Parameterized initializer.
    ///
    /// - Parameters:
    ///   - appVersion: App version.
    ///   - appName: App name.
    ///   - osVersion: OS version.
    ///   - osName: OS name.
    ///   - nativeAppType: Native app type.
    ///   - mobileSdkVersion: Mobile SDK version.
    ///   - deviceModel: Device model.
    ///   - deviceId: Device ID.
    ///   - clientId: Client ID.
    @objc(initWithAppVersion:appName:osVersion:osName:nativeAppType:mobileSdkVersion:deviceModel:deviceId:clientId:)
    public init(appVersion: String, appName: String, osVersion: String, osName: String, nativeAppType: String, mobileSdkVersion: String, deviceModel: String, deviceId: String, clientId: String) {
        self.appVersion = appVersion
        self.appName = appName
        self.osVersion = osVersion
        self.osName = osName
        self.nativeAppType = nativeAppType
        self.mobileSdkVersion = mobileSdkVersion
        self.deviceModel = deviceModel
        self.deviceId = deviceId
        self.clientId = clientId
        super.init()
    }

    /// Parameterized initializer from JSON dictionary.
    ///
    /// - Parameter jsonRepresentation: JSON dictionary representation.
    @objc(initWithJson:)
    public init(json jsonRepresentation: NSDictionary) {
        self.appVersion = jsonRepresentation[SFSDKDeviceAppAttributes.kAppVersionKey] as? String ?? ""
        self.appName = jsonRepresentation[SFSDKDeviceAppAttributes.kAppNameKey] as? String ?? ""
        self.osVersion = jsonRepresentation[SFSDKDeviceAppAttributes.kOsVersionKey] as? String ?? ""
        self.osName = jsonRepresentation[SFSDKDeviceAppAttributes.kOsNameKey] as? String ?? ""
        self.nativeAppType = jsonRepresentation[SFSDKDeviceAppAttributes.kNativeAppTypeKey] as? String ?? ""
        self.mobileSdkVersion = jsonRepresentation[SFSDKDeviceAppAttributes.kMobileSdkVersionKey] as? String ?? ""
        self.deviceModel = jsonRepresentation[SFSDKDeviceAppAttributes.kDeviceModelKey] as? String ?? ""
        self.deviceId = jsonRepresentation[SFSDKDeviceAppAttributes.kDeviceIdKey] as? String ?? ""
        self.clientId = jsonRepresentation[SFSDKDeviceAppAttributes.kClientIdKey] as? String ?? ""
        super.init()
    }

    // MARK: - Public Methods

    /// Returns a JSON dictionary representation of device app attributes.
    ///
    /// - Returns: JSON dictionary representation.
    @objc public func jsonRepresentation() -> NSDictionary {
        let dict = NSMutableDictionary()
        dict[SFSDKDeviceAppAttributes.kAppVersionKey] = appVersion
        dict[SFSDKDeviceAppAttributes.kAppNameKey] = appName
        dict[SFSDKDeviceAppAttributes.kOsVersionKey] = osVersion
        dict[SFSDKDeviceAppAttributes.kOsNameKey] = osName
        dict[SFSDKDeviceAppAttributes.kNativeAppTypeKey] = nativeAppType
        dict[SFSDKDeviceAppAttributes.kMobileSdkVersionKey] = mobileSdkVersion
        dict[SFSDKDeviceAppAttributes.kDeviceModelKey] = deviceModel
        dict[SFSDKDeviceAppAttributes.kDeviceIdKey] = deviceId
        dict[SFSDKDeviceAppAttributes.kClientIdKey] = clientId
        return dict
    }
}
