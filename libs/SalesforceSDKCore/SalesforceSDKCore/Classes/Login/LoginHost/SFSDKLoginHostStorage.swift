/*
 SFSDKLoginHostStorage.swift
 SalesforceSDKCore

 Created by Kunal Chitalia on 1/22/16.
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
import SalesforceSDKCommon

// Key under which the list of login hosts will be stored in the user defaults.
private let SFSDKLoginHostList = "SalesforceLoginHostListPrefs"

// Key for the host.
private let SFSDKLoginHostKey = "SalesforceLoginHostKey"

// Key for the name.
private let SFSDKLoginHostNameKey = "SalesforceLoginHostNameKey"

/// This class manages the list of login hosts as well its persistence.
/// Currently this list is persisted in the user defaults.
@objc(SFSDKLoginHostStorage)
@objcMembers
public class SFSDKLoginHostStorage: NSObject {

    private var loginHostList: NSMutableArray

    /// Returns the shared instance of this class.
    @objc(sharedInstance)
    public static let shared: SFSDKLoginHostStorage = {
        return SFSDKLoginHostStorage()
    }()

    private override init() {
        loginHostList = NSMutableArray()
        super.init()

        let managedPreferences = SFManagedPreferences.sharedPreferences()
        let production = SalesforceLoginHost.host(
            withName: SFSDKResourceUtils.localizedString("LOGIN_SERVER_PRODUCTION"),
            host: "login.salesforce.com",
            deletable: false
        )
        let sandbox = SalesforceLoginHost.host(
            withName: SFSDKResourceUtils.localizedString("LOGIN_SERVER_SANDBOX"),
            host: "test.salesforce.com",
            deletable: false
        )

        // Add the Production and Sandbox login hosts, unless an MDM policy explicitly forbids this.
        if !(managedPreferences.hasManagedPreferences && managedPreferences.onlyShowAuthorizedHosts) {
            loginHostList.add(production)
            loginHostList.add(sandbox)
        }

        // Load from managed preferences (e.g. MDM).
        if managedPreferences.hasManagedPreferences {
            /*
             * If there are any existing login hosts, remove them as MDM should take
             * highest priority and only the hosts enforced by MDM should be in the list.
             */
            if loginHostList.count > 0 {
                removeAllLoginHosts()
            }
            let hostLabels = managedPreferences.loginHostLabels ?? []
            if let loginHosts = managedPreferences.loginHosts {
                loginHosts.enumerated().forEach { (idx, loginHost) in
                    guard let loginHostStr = loginHost as? String else { return }
                    let sanitizedLoginHost = loginHostStr.trimmingCharacters(in: CharacterSet.whitespaces)
                    let hostLabel = hostLabels.count > idx ? hostLabels[idx] as? String ?? loginHostStr : loginHostStr
                    loginHostList.add(SalesforceLoginHost.host(
                        withName: hostLabel,
                        host: sanitizedLoginHost,
                        deletable: false
                    ))
                }
            }
            if managedPreferences.onlyShowAuthorizedHosts {
                return
            }
        } else if let customHost = Bundle.main.object(forInfoDictionaryKey: "SFDCOAuthLoginHost") as? String {
            // Load from info.plist.

            /*
             * Add the login host from info.plist if it doesn't exist already.
             * This also handles the case where the custom host configured
             * was changed between version updates of the application.
             */
            if loginHost(forHostAddress: customHost) == nil {
                loginHostList.removeAllObjects()
                if SFUserAccountManager.shared.loginViewControllerConfig.showSettingsIcon &&
                   SFUserAccountManager.shared.loginViewControllerConfig.showServerPicker {
                    loginHostList.add(production)
                    loginHostList.add(sandbox)
                }
                let sanitizedCustomHost = customHost.trimmingCharacters(in: .whitespaces)
                let customLoginHost = SalesforceLoginHost.host(
                    withName: customHost,
                    host: sanitizedCustomHost,
                    deletable: false
                )
                loginHostList.add(customLoginHost)
            }
        }

        // Load from the user defaults.
        if let persistedList = UserDefaults.msdkUserDefaults().object(forKey: SFSDKLoginHostList) as? [[String: String]] {
            for dic in persistedList {
                if let name = dic[SFSDKLoginHostNameKey], let host = dic[SFSDKLoginHostKey] {
                    loginHostList.add(SalesforceLoginHost.host(
                        withName: name,
                        host: host,
                        deletable: true
                    ))
                }
            }
        }
    }

    /// Stores all the login host except the non-deletable ones in the user defaults.
    public func save() {
        var persistedList: [[String: String]] = []
        for case let host as SalesforceLoginHost in loginHostList {
            if host.isDeletable {
                let hostName = host.name
                let hostAddress = host.host.isEmpty ? hostName : host.host
                persistedList.append([
                    SFSDKLoginHostNameKey: hostName,
                    SFSDKLoginHostKey: hostAddress
                ])
            }
        }
        UserDefaults.msdkUserDefaults().set(persistedList, forKey: SFSDKLoginHostList)
        UserDefaults.msdkUserDefaults().synchronize()
    }

    /// Adds a new login host.
    /// - Parameter loginHost: Login host to be added
    public func add(_ loginHost: SalesforceLoginHost) {
        loginHostList.add(loginHost)
        save()
    }

    /// Removes the login host at the specified index.
    /// - Parameter index: Index of the login host
    public func removeLoginHost(at index: Int) {
        loginHostList.removeObject(at: index)
        save()
    }

    /// Returns the index of the specified host if exists.
    /// - Parameter host: Requested login host
    /// - Returns: The index of the login host, or NSNotFound if not found
    public func index(of host: SalesforceLoginHost) -> Int {
        if loginHostList.contains(host) {
            return loginHostList.index(of: host)
        }
        return NSNotFound
    }

    /// Returns the login host at the specified index.
    /// - Parameter index: Requested index
    /// - Returns: The login host at the specified index
    public func loginHost(at index: Int) -> SalesforceLoginHost {
        return loginHostList.object(at: index) as! SalesforceLoginHost
    }

    /// Returns the login host with a particular host address, if any.
    /// - Parameter hostAddress: Address to be queried
    /// - Returns: The login host for the specified address, or nil if not found
    public func loginHost(forHostAddress hostAddress: String) -> SalesforceLoginHost? {
        for case let host as SalesforceLoginHost in loginHostList {
            if host.host == hostAddress {
                return host
            }
        }
        return nil
    }

    /// Removes all the login hosts.
    public func removeAllLoginHosts() {
        let managedPreferences = SFManagedPreferences.sharedPreferences()
        var startingIndex = 2

        /*
         * If MDM policy is set to hide hosts, 'Production' and 'Sandbox' won't be on the list.
         */
        if managedPreferences.hasManagedPreferences && managedPreferences.onlyShowAuthorizedHosts {
            startingIndex = 0
        }
        loginHostList.removeObjects(in: NSRange(location: startingIndex, length: loginHostList.count - 2))
    }

    /// Returns the number of login hosts.
    /// - Returns: The number of login hosts
    public func numberOfLoginHosts() -> Int {
        return loginHostList.count
    }
}
