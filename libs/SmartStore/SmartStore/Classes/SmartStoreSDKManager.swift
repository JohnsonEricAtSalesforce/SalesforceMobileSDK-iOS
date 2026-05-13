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

/**
 * Version of SalesforceSDKManager to be used with all SmartStore-enabled apps.
 * By default, forceios apps use an instance of this class instead of SalesforceSDKManager.
 */
@objc(SmartStoreSDKManager)
@objcMembers
open class SmartStoreSDKManager: SalesforceManager {

    /**
     @return The singleton instance of the SDK Manager.
     */
    // swiftformat:disable:next redundantOverride
    open override class var shared: SmartStoreSDKManager {
        return SalesforceManager.shared as! SmartStoreSDKManager
    }

    public required init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUserWillLogoutForSmartStoreManager(_:)),
            name: .UserAccountManagerWillLogoutUser,
            object: nil
        )
    }

    @objc(initializeSDK)
    // swiftformat:disable:next redundantOverride
    open override class func initializeSDK() {
        SalesforceManager.initializeSDK(manager: self)
    }

    @objc(handleUserWillLogoutForSmartStoreManager:)
    private func handleUserWillLogoutForSmartStoreManager(_ notification: Notification) {
        if let user = notification.userInfo?[kSFNotificationUserInfoAccountKey] as? SFUserAccount {
            SmartStore.removeAll(forUserAccount: user)
        }
    }

    /**
     * Setup global store using config found globalstore.json
     */
    @objc(setupGlobalStoreFromDefaultConfig)
    public func setupGlobalStoreFromDefaultConfig() {
        let configPath = pathForGlobalStoreConfig()
        SmartStoreLogger.d(type(of: self), message: "Setting up global store using config found in \(configPath)")
        if let storeConfig = StoreConfig(resourceAtPath: configPath), storeConfig.hasSoups() {
            if let store = SmartStore.sharedGlobal(withName: kDefaultSmartStoreName) {
                storeConfig.registerSoups(store)
            }
        }
    }

    /**
     * Setup user store using config found in userstore.json
     */
    @objc(setupUserStoreFromDefaultConfig)
    public func setupUserStoreFromDefaultConfig() {
        let configPath = pathForUserStoreConfig()
        SmartStoreLogger.d(type(of: self), message: "Setting up user store using config found in \(configPath)")
        if let storeConfig = StoreConfig(resourceAtPath: configPath), storeConfig.hasSoups() {
            if let store = SmartStore.shared(withName: kDefaultSmartStoreName) {
                storeConfig.registerSoups(store)
            }
        }
    }

    private func pathForGlobalStoreConfig() -> String {
        return "globalstore.json"
    }

    private func pathForUserStoreConfig() -> String {
        return "userstore.json"
    }

    // MARK: - Dev support methods

    public override func devActionsList(presentedViewController: UIViewController) -> [DevAction] {
        var devActions = super.devActionsList(presentedViewController: presentedViewController)
        let action = DevAction(name: "Inspect SmartStore") {
            let devInfo = InspectorViewController()
            presentedViewController.present(devInfo, animated: false, completion: nil)
        }
        devActions.append(action)
        return devActions
    }

    public override func devSupportInfoList() -> [String] {
        guard let store = SmartStore.sharedGlobal(withName: kDefaultSmartStoreName) else {
            return super.devSupportInfoList()
        }
        var devInfos = super.devSupportInfoList()
        devInfos.append("section:SmartStore")
        devInfos.append(contentsOf: [
            "SQLCipher version", store.versionOfSQLCipher(),
            "SQLCipher Compile Options", store.compileOptions().joined(separator: ", "),
            "SQLCipher Runtime Settings", store.runtimeSettings().joined(separator: ", "),
            "User SmartStores", safeJoin(SmartStore.allStoreNames, separator: ", "),
            "Global SmartStores", safeJoin(SmartStore.allGlobalStoreNames, separator: ", ")
        ])
        return devInfos
    }

    private func safeJoin(_ array: [String], separator: String) -> String {
        return array.joined(separator: separator)
    }
}
