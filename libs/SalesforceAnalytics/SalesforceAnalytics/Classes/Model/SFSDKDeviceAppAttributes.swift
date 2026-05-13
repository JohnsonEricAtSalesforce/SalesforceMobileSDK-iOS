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

private let kSFAppVersionKey = "appVersion"
private let kSFAppNameKey = "appName"
private let kSFOsVersionKey = "osVersion"
private let kSFOsNameKey = "osName"
private let kSFNativeAppTypeKey = "nativeAppType"
private let kSFMobileSdkVersionKey = "mobileSdkVersion"
private let kSFDeviceModelKey = "deviceModel"
private let kSFDeviceIdKey = "deviceId"
private let kSFClientIdKey = "clientId"

@objc(SFSDKDeviceAppAttributes)
public class SFSDKDeviceAppAttributes: NSObject {

    @objc public let appVersion: String
    @objc public let appName: String
    @objc public let osVersion: String
    @objc public let osName: String
    @objc public let nativeAppType: String
    @objc public let mobileSdkVersion: String
    @objc public let deviceModel: String
    @objc public let deviceId: String
    @objc public let clientId: String

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
    @objc
    public init(
        appVersion: String,
        appName: String,
        osVersion: String,
        osName: String,
        nativeAppType: String,
        mobileSdkVersion: String,
        deviceModel: String,
        deviceId: String,
        clientId: String
    ) {
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

    /// Parameterized initializer.
    ///
    /// - Parameter jsonRepresentation: JSON representation.
    @objc
    public init(json jsonRepresentation: [String: Any]) {
        self.appVersion = jsonRepresentation[kSFAppVersionKey] as? String ?? ""
        self.appName = jsonRepresentation[kSFAppNameKey] as? String ?? ""
        self.osVersion = jsonRepresentation[kSFOsVersionKey] as? String ?? ""
        self.osName = jsonRepresentation[kSFOsNameKey] as? String ?? ""
        self.nativeAppType = jsonRepresentation[kSFNativeAppTypeKey] as? String ?? ""
        self.mobileSdkVersion = jsonRepresentation[kSFMobileSdkVersionKey] as? String ?? ""
        self.deviceModel = jsonRepresentation[kSFDeviceModelKey] as? String ?? ""
        self.deviceId = jsonRepresentation[kSFDeviceIdKey] as? String ?? ""
        self.clientId = jsonRepresentation[kSFClientIdKey] as? String ?? ""
        super.init()
    }

    /// Returns a JSON representation of device app attributes.
    ///
    /// - Returns: JSON representation.
    @objc
    public func jsonRepresentation() -> [String: Any] {
        return [
            kSFAppVersionKey: appVersion,
            kSFAppNameKey: appName,
            kSFOsVersionKey: osVersion,
            kSFOsNameKey: osName,
            kSFNativeAppTypeKey: nativeAppType,
            kSFMobileSdkVersionKey: mobileSdkVersion,
            kSFDeviceModelKey: deviceModel,
            kSFDeviceIdKey: deviceId,
            kSFClientIdKey: clientId
        ]
    }
}
