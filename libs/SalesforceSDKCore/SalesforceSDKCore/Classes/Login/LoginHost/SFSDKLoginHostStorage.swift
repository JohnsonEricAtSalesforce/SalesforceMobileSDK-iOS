// SFSDKLoginHostStorage.swift
// SalesforceSDKCore
//
// Created by Kunal Chitalia on 1/22/16.
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
import SalesforceSDKCommon

/// This class manages the list of login hosts as well its persistence.
/// Currently this list is persisted in the user defaults.
@objc(SFSDKLoginHostStorage)
@objcMembers
public class SFSDKLoginHostStorage: NSObject {

    private static let loginHostListKey = "SalesforceLoginHostListPrefs"
    private static let loginHostKey = "SalesforceLoginHostKey"
    private static let loginHostNameKey = "SalesforceLoginHostNameKey"

    @objc public static let sharedInstance = SFSDKLoginHostStorage()

    private var loginHostList: [SalesforceLoginHost] = []

    private override init() {
        super.init()

        let managedPreferences = SFManagedPreferences.sharedPreferences
        let production = SalesforceLoginHost.host(withName: SFSDKResourceUtils.localizedString("LOGIN_SERVER_PRODUCTION"), host: "login.salesforce.com", deletable: false)
        let sandbox = SalesforceLoginHost.host(withName: SFSDKResourceUtils.localizedString("LOGIN_SERVER_SANDBOX"), host: "test.salesforce.com", deletable: false)

        // Add the Production and Sandbox login hosts, unless an MDM policy explicitly forbids this.
        if !(managedPreferences.hasManagedPreferences && managedPreferences.onlyShowAuthorizedHosts) {
            loginHostList.append(production)
            loginHostList.append(sandbox)
        }

        // Load from managed preferences (e.g. MDM).
        if managedPreferences.hasManagedPreferences {
            if loginHostList.count > 0 {
                removeAllLoginHosts()
            }
            let hostLabels = (managedPreferences.loginHostLabels as? [String]) ?? []
            if let loginHosts = managedPreferences.loginHosts as? [String] {
                for (idx, loginHost) in loginHosts.enumerated() {
                    let sanitizedLoginHost = loginHost.trimmingCharacters(in: .whitespaces)
                    let hostLabel = idx < hostLabels.count ? hostLabels[idx] : loginHost
                    loginHostList.append(SalesforceLoginHost.host(withName: hostLabel, host: sanitizedLoginHost, deletable: false))
                }
            }
            if managedPreferences.onlyShowAuthorizedHosts {
                return
            }
        } else if let customHost = Bundle.main.object(forInfoDictionaryKey: "SFDCOAuthLoginHost") as? String {
            if loginHostForHostAddress(customHost) == nil {
                loginHostList.removeAll()
                let config = UserAccountManager.shared.loginViewControllerConfig
                if config.showSettingsIcon && config.showServerPicker {
                    loginHostList.append(production)
                    loginHostList.append(sandbox)
                }
                let sanitizedCustomHost = customHost.trimmingCharacters(in: .whitespaces)
                let customLoginHost = SalesforceLoginHost.host(withName: customHost, host: sanitizedCustomHost, deletable: false)
                loginHostList.append(customLoginHost)
            }
        }

        // Load from the user defaults.
        if let persistedList = UserDefaults.msdkUserDefaults().object(forKey: SFSDKLoginHostStorage.loginHostListKey) as? [[String: String]] {
            for dic in persistedList {
                let name = dic[SFSDKLoginHostStorage.loginHostNameKey] ?? ""
                let host = dic[SFSDKLoginHostStorage.loginHostKey] ?? ""
                loginHostList.append(SalesforceLoginHost.host(withName: name, host: host, deletable: true))
            }
        }
    }

    @objc public func save() {
        var persistedList: [[String: String]] = []
        for host in loginHostList {
            if host.deletable {
                let hostName = host.name
                let hostAddress = host.host.isEmpty ? hostName : host.host
                persistedList.append([
                    SFSDKLoginHostStorage.loginHostNameKey: hostName,
                    SFSDKLoginHostStorage.loginHostKey: hostAddress
                ])
            }
        }
        UserDefaults.msdkUserDefaults().set(persistedList, forKey: SFSDKLoginHostStorage.loginHostListKey)
        UserDefaults.msdkUserDefaults().synchronize()
    }

    @objc public func addLoginHost(_ loginHost: SalesforceLoginHost) {
        loginHostList.append(loginHost)
        save()
    }

    @objc public func removeLoginHost(at index: UInt) {
        loginHostList.remove(at: Int(index))
        save()
    }

    @objc public func indexOfLoginHost(_ host: SalesforceLoginHost) -> UInt {
        if let index = loginHostList.firstIndex(of: host) {
            return UInt(index)
        }
        return UInt(NSNotFound)
    }

    @objc public func loginHost(at index: UInt) -> SalesforceLoginHost {
        return loginHostList[Int(index)]
    }

    @objc public func loginHostForHostAddress(_ hostAddress: String) -> SalesforceLoginHost? {
        return loginHostList.first { $0.host == hostAddress }
    }

    @objc public func removeAllLoginHosts() {
        let managedPreferences = SFManagedPreferences.sharedPreferences
        var startingIndex = 2
        if managedPreferences.hasManagedPreferences && managedPreferences.onlyShowAuthorizedHosts {
            startingIndex = 0
        }
        let removeCount = loginHostList.count - 2
        if removeCount > 0 {
            loginHostList.removeSubrange(startingIndex..<(startingIndex + removeCount))
        }
    }

    @objc public var numberOfLoginHosts: UInt {
        return UInt(loginHostList.count)
    }
}
