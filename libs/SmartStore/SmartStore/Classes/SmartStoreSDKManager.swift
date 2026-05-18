/*
 Copyright (c) 2015-present, salesforce.com, inc. All rights reserved.

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
import SalesforceSDKCore

/// Version of SalesforceSDKManager to be used with all SmartStore-enabled apps.
/// By default, forceios apps use an instance of this class instead of SalesforceSDKManager.
@objc(SmartStoreSDKManager)
@objcMembers
open class SmartStoreSDKManager: SalesforceManager {

    // MARK: - Initialization

    public override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUserWillLogout(_:)),
            name: UserAccountManager.willLogoutUser,
            object: nil
        )
    }

    /// Initialize the SDK with SmartStoreSDKManager.
    @objc
    open override class func initializeSDK() {
        super.initializeSDK(manager: self)
    }

    // MARK: - User Logout

    @objc private func handleUserWillLogout(_ notification: Notification) {
        guard let user = notification.userInfo?[UserAccountManager.userInfoAccountKey] as? UserAccount else { return }
        SmartStore.removeAll(forUserAccount: user)
    }

    // MARK: - Store Config

    /// Setup global store using config found in globalstore.json.
    @objc
    public func setupGlobalStoreFromDefaultConfig() {
        let configPath = pathForGlobalStoreConfig()
        SmartStoreLogger.d(SmartStoreSDKManager.self, message: "Setting up global store using config found in \(configPath)")
        if let storeConfig = StoreConfig(resourceAtPath: configPath) {
            if storeConfig.hasSoups() {
                storeConfig.registerSoups(SmartStore.sharedGlobal(withName: SmartStoreDefaultStoreName))
            }
        }
    }

    /// Setup user store using config found in userstore.json.
    @objc
    public func setupUserStoreFromDefaultConfig() {
        let configPath = pathForUserStoreConfig()
        SmartStoreLogger.d(SmartStoreSDKManager.self, message: "Setting up user store using config found in \(configPath)")
        if let storeConfig = StoreConfig(resourceAtPath: configPath) {
            if storeConfig.hasSoups() {
                if let userStore = SmartStore.shared(withName: SmartStoreDefaultStoreName) {
                    storeConfig.registerSoups(userStore)
                }
            }
        }
    }

    private func pathForGlobalStoreConfig() -> String {
        return "globalstore.json"
    }

    private func pathForUserStoreConfig() -> String {
        return "userstore.json"
    }

    // MARK: - Dev Support

    open override func devActionsList(presentedViewController: UIViewController) -> [DevAction] {
        var devActions = super.devActionsList(presentedViewController: presentedViewController)
        let action = DevAction("Inspect SmartStore") {
            let devInfo = InspectorViewController()
            presentedViewController.present(devInfo, animated: false, completion: nil)
        }
        devActions.append(action)
        return devActions
    }

    open override func devSupportInfoList() -> [String] {
        let globalStore = SmartStore.sharedGlobal(withName: SmartStoreDefaultStoreName)
        var devInfos = super.devSupportInfoList()
        devInfos.append("section:SmartStore")
        devInfos.append(contentsOf: [
            "SQLCipher version", globalStore.versionOfSQLCipher(),
            "SQLCipher Compile Options", (globalStore.compileOptions() as? [String])?.joined(separator: ", ") ?? "",
            "SQLCipher Runtime Settings", globalStore.runtimeSettings().map { "\($0)" }.joined(separator: ", "),
            "User SmartStores", safeJoin(SmartStore.allStoreNames, separator: ", "),
            "Global SmartStores", safeJoin(SmartStore.allGlobalStoreNames, separator: ", ")
        ])
        return devInfos
    }

    private func safeJoin(_ array: [String]?, separator: String) -> String {
        return array?.joined(separator: separator) ?? ""
    }
}
