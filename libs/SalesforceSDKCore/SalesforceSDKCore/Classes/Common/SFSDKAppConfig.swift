// SFSDKAppConfig.swift
//
// Copyright (c) 2014-present, salesforce.com, inc. All rights reserved.
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

/// Error codes for app config validation.
@objc(SFSDKAppConfigErrorCode)
public enum BootConfigErrorCode: Int {
    case noConsumerKey = 966
    case noRedirectURI = 967
}

/// Error domain for app config errors.
public let SFSDKAppConfigErrorDomain: String = "com.salesforce.mobilesdk.AppConfigErrorDomain"

/// Default native app config file path.
public let SFSDKDefaultNativeAppConfigFilePath: String = "/bootconfig.plist"

// MARK: - Private constants

private let kRemoteAccessConsumerKey = "remoteAccessConsumerKey"
private let kOauthRedirectURI = "oauthRedirectURI"
private let kOauthScopes = "oauthScopes"
private let kShouldAuthenticate = "shouldAuthenticate"
private let kDefaultShouldAuthenticate = true

/// Contains this app's OAuth configuration as defined in the developer's Salesforce connected app.
@objc(SFSDKAppConfig)
@objcMembers
public class BootConfig: NSObject {

    /// The Connected App key associated with this application.
    public var remoteAccessConsumerKey: String {
        get { return configDict[kRemoteAccessConsumerKey] as? String ?? "" }
        set { configDict[kRemoteAccessConsumerKey] = newValue }
    }

    /// The OAuth Redirect URI associated with the configured Connected Application.
    public var oauthRedirectURI: String {
        get { return configDict[kOauthRedirectURI] as? String ?? "" }
        set { configDict[kOauthRedirectURI] = newValue }
    }

    /// The OAuth Scopes being requested for this app.
    public var oauthScopes: Set<String> {
        get {
            if let arr = configDict[kOauthScopes] as? [String] {
                return Set(arr)
            }
            return Set()
        }
        set { configDict[kOauthScopes] = Array(newValue) }
    }

    /// Whether or not this app should authenticate when it first starts.
    @objc(shouldAuthenticateOnFirstLaunch)
    public var shouldAuthenticate: Bool {
        get { return (configDict[kShouldAuthenticate] as? NSNumber)?.boolValue ?? kDefaultShouldAuthenticate }
        set { configDict[kShouldAuthenticate] = NSNumber(value: newValue) }
    }

    /// The config as a dictionary.
    public var configDict: NSMutableDictionary

    /// Initializer with a given JSON-based configuration dictionary.
    /// - Parameter configDict: The dictionary containing the configuration.
    @objc(init:)
    public init?(dict configDict: NSDictionary?) {
        if let dict = configDict {
            self.configDict = NSMutableDictionary(dictionary: dict)
        } else {
            self.configDict = NSMutableDictionary()
        }
        super.init()

        if self.configDict[kShouldAuthenticate] == nil {
            self.shouldAuthenticate = kDefaultShouldAuthenticate
        }

        let whitespaceSet = CharacterSet.whitespacesAndNewlines
        if let key = self.configDict[kRemoteAccessConsumerKey] as? String {
            self.configDict[kRemoteAccessConsumerKey] = key.trimmingCharacters(in: whitespaceSet)
        }
        if let uri = self.configDict[kOauthRedirectURI] as? String {
            self.configDict[kOauthRedirectURI] = uri.trimmingCharacters(in: whitespaceSet)
        }
    }

    /// Initializer with a given config file.
    /// - Parameter configFile: The path to config file.
    @objc(initWithConfigFile:)
    public convenience init?(configFile: String) {
        guard let resourcePath = Bundle.main.resourcePath else {
            return nil
        }
        let fullPath = (resourcePath as NSString).appendingPathComponent(configFile)
        guard FileManager.default.fileExists(atPath: fullPath) else {
            SFSDKCoreLogger.i(BootConfig.self, message: "\(#function) Config file does not exist at path '\(fullPath)'")
            return nil
        }
        guard let dict = NSDictionary(contentsOfFile: fullPath) else {
            SFSDKCoreLogger.i(BootConfig.self, message: "\(#function) Could not parse the config file at path '\(fullPath)'. Config file is not in a valid plist format.")
            return nil
        }
        self.init(dict: dict)
    }

    // MARK: - Swift-name compatibility
    //
    // Prior SDK releases annotated both Objective-C initializers with `NS_SWIFT_NAME(init(_:))`,
    // so Swift consumers called them unlabeled — `BootConfig(configDict)` and `BootConfig("/path")`
    // — with overload resolution by argument type. The ObjC→Swift migration re-declared them with
    // explicit Swift labels (`init(dict:)` / `init(configFile:)`), dropping the unlabeled spelling.
    // These `@nonobjc` unlabeled overloads restore source compatibility for Swift consumers (and the
    // sample apps); they forward to the labeled initializers.

    @nonobjc public convenience init?(_ configDict: [AnyHashable: Any]?) {
        self.init(dict: configDict as NSDictionary?)
    }

    @nonobjc public convenience init?(_ configFile: String) {
        self.init(configFile: configFile)
    }

    public override var description: String {
        return "<\(type(of: self)):\(Unmanaged.passUnretained(self).toOpaque()) data: \(configDict)>"
    }

    /// Validate the app config inputs.
    /// - Parameter error: The error associated with validation, if an error occurs.
    /// - Returns: `true` if validation was successful, `false` otherwise.
    @objc public func validate() throws {
        if remoteAccessConsumerKey.isEmpty {
            throw NSError(
                domain: SFSDKAppConfigErrorDomain,
                code: BootConfigErrorCode.noConsumerKey.rawValue,
                userInfo: [NSLocalizedDescriptionKey: SFSDKResourceUtils.localizedString("appConfigValidationErrorNoConsumerKey")]
            )
        }
        if oauthRedirectURI.isEmpty {
            throw NSError(
                domain: SFSDKAppConfigErrorDomain,
                code: BootConfigErrorCode.noRedirectURI.rawValue,
                userInfo: [NSLocalizedDescriptionKey: SFSDKResourceUtils.localizedString("appConfigValidationErrorNoRedirectURI")]
            )
        }
    }

    /// Validate the app config inputs (ObjC-compatible).
    /// - Parameter error: The error associated with validation, if an error occurs.
    /// - Returns: `YES` if validation was successful, `NO` otherwise.
    @objc(validate:)
    public func validateObjC(_ error: NSErrorPointer) -> Bool {
        if remoteAccessConsumerKey.isEmpty {
            if let error = error {
                error.pointee = NSError(
                    domain: SFSDKAppConfigErrorDomain,
                    code: BootConfigErrorCode.noConsumerKey.rawValue,
                    userInfo: [NSLocalizedDescriptionKey: SFSDKResourceUtils.localizedString("appConfigValidationErrorNoConsumerKey")]
                )
            }
            return false
        }
        if oauthRedirectURI.isEmpty {
            if let error = error {
                error.pointee = NSError(
                    domain: SFSDKAppConfigErrorDomain,
                    code: BootConfigErrorCode.noRedirectURI.rawValue,
                    userInfo: [NSLocalizedDescriptionKey: SFSDKResourceUtils.localizedString("appConfigValidationErrorNoRedirectURI")]
                )
            }
            return false
        }
        return true
    }

    /// The app config from the default configuration file location.
    @objc public static func fromDefaultConfigFile() -> BootConfig? {
        return fromConfigFile(SFSDKDefaultNativeAppConfigFilePath)
    }

    /// Create an app config from the config file at the specified file path.
    /// - Parameter configFilePath: The file path to the configuration file, relative to the resources root path.
    /// - Returns: The app config from the given file path.
    @objc public static func fromConfigFile(_ configFilePath: String) -> BootConfig? {
        assert(!configFilePath.isEmpty, "Must specify a config file path.")
        return BootConfig(configFile: configFilePath)
    }
}
