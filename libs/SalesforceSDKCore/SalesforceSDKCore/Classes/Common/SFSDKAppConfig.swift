/*
 Copyright (c) 2014-present, salesforce.com, inc. All rights reserved.

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

public let SFSDKDefaultNativeAppConfigFilePath = "/bootconfig.plist"
public let SFSDKAppConfigErrorDomain = "com.salesforce.mobilesdk.AppConfigErrorDomain"

private let kRemoteAccessConsumerKey = "remoteAccessConsumerKey"
private let kOauthRedirectURI = "oauthRedirectURI"
private let kOauthScopes = "oauthScopes"
private let kShouldAuthenticate = "shouldAuthenticate"
private let kDefaultShouldAuthenticate = true

/// Contains this app's OAuth configuration as defined in the developer's Salesforce connected app.
@objc(SFSDKAppConfig)
@objcMembers
public class BootConfig: NSObject {

    @objc public enum ErrorCode: Int {
        case noConsumerKey = 966
        case noRedirectURI
    }

    /// The Connected App key associated with this application.
    @objc public var remoteAccessConsumerKey: String? {
        get {
            return configDict[kRemoteAccessConsumerKey] as? String
        }
        set {
            configDict[kRemoteAccessConsumerKey] = newValue
        }
    }

    /// The OAuth Redirect URI associated with the configured Connected Application.
    @objc public var oauthRedirectURI: String? {
        get {
            return configDict[kOauthRedirectURI] as? String
        }
        set {
            configDict[kOauthRedirectURI] = newValue
        }
    }

    /// The OAuth Scopes being requested for this app.
    @objc public var oauthScopes: Set<String> {
        get {
            if let scopes = configDict[kOauthScopes] as? [String] {
                return Set(scopes)
            }
            return Set()
        }
        set {
            configDict[kOauthScopes] = Array(newValue)
        }
    }

    /// Whether or not this app should authenticate when it first starts.
    @objc public var shouldAuthenticate: Bool {
        get {
            return (configDict[kShouldAuthenticate] as? NSNumber)?.boolValue ?? kDefaultShouldAuthenticate
        }
        set {
            configDict[kShouldAuthenticate] = NSNumber(value: newValue)
        }
    }

    /// The config as a dictionary
    @objc public var configDict: NSMutableDictionary

    public override init() {
        self.configDict = NSMutableDictionary()
        super.init()
        self.shouldAuthenticate = kDefaultShouldAuthenticate
    }

    /// Initializer with a given JSON-based configuration dictionary.
    /// - Parameter configDict: The dictionary containing the configuration.
    @objc(initWithDict:)
    public init?(_ configDict: NSDictionary?) {
        if let configDict = configDict {
            self.configDict = NSMutableDictionary(dictionary: configDict)
        } else {
            self.configDict = NSMutableDictionary()
        }
        super.init()

        if self.configDict[kShouldAuthenticate] == nil {
            self.shouldAuthenticate = kDefaultShouldAuthenticate
        }

        let whitespaceSet = CharacterSet.whitespacesAndNewlines
        if let consumerKey = self.configDict[kRemoteAccessConsumerKey] as? String {
            self.configDict[kRemoteAccessConsumerKey] = consumerKey.trimmingCharacters(in: whitespaceSet)
        }
        if let redirectURI = self.configDict[kOauthRedirectURI] as? String {
            self.configDict[kOauthRedirectURI] = redirectURI.trimmingCharacters(in: whitespaceSet)
        }
    }

    /// Initializer with a given a config file.
    /// - Parameter configFile: The path to config file
    @objc(initWithConfigFile:)
    public convenience init?(_ configFile: String) {
        let fullPath = (Bundle.main.resourcePath! as NSString).appendingPathComponent(configFile)
        if !FileManager.default.fileExists(atPath: fullPath) {
            SFSDKCoreLogger.i(BootConfig.self, message: "Config file does not exist at path '\(fullPath)'")
            return nil
        }
        guard let configDict = NSDictionary(contentsOfFile: fullPath) else {
            SFSDKCoreLogger.i(BootConfig.self, message: "Could not parse the config file at path '\(fullPath)'. Config file is not in a valid plist format.")
            return nil
        }

        self.init(configDict)
    }

    public override var description: String {
        return "<\(type(of: self)):\(Unmanaged.passUnretained(self).toOpaque()) data: \(configDict.description)>"
    }

    /// Validate the app config inputs.
    /// - Parameter error: The error associated with validation, if an error occurs.
    /// - Returns: true if validation was successful, false otherwise.
    @objc(validate:)
    public func validate(_ error: NSErrorPointer) -> Bool {
        if remoteAccessConsumerKey?.isEmpty ?? true {
            BootConfig.createError(error, withCode: ErrorCode.noConsumerKey.rawValue, message: SFSDKResourceUtils.localizedString("appConfigValidationErrorNoConsumerKey"))
            return false
        }
        if oauthRedirectURI?.isEmpty ?? true {
            BootConfig.createError(error, withCode: ErrorCode.noRedirectURI.rawValue, message: SFSDKResourceUtils.localizedString("appConfigValidationErrorNoRedirectURI"))
            return false
        }

        return true
    }

    // MARK: - Load config methods

    /// Returns the app config from the default configuration file location.
    @objc(fromDefaultConfigFile)
    public static func fromDefaultConfigFile() -> BootConfig? {
        return fromConfigFile(SFSDKDefaultNativeAppConfigFilePath)
    }

    /// Create an app config from the config file at the specified file path.
    /// - Parameter configFilePath: The file path to the configuration file, relative to the resources root path.
    /// - Returns: The app config from the given file path.
    @objc(fromConfigFile:)
    public static func fromConfigFile(_ configFilePath: String) -> BootConfig? {
        assert(!configFilePath.isEmpty, "Must specify a config file path.")
        return BootConfig(configFilePath)
    }

    // MARK: - Helper Methods

    private static func createError(_ error: NSErrorPointer, withCode errorCode: Int, message: String) {
        if let error = error {
            let userInfo = [NSLocalizedDescriptionKey: message]
            error.pointee = NSError(domain: SFSDKAppConfigErrorDomain, code: errorCode, userInfo: userInfo)
        }
    }
}
