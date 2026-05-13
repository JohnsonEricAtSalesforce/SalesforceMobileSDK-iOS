/*
 Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.

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
import SmartStore
import SalesforceSDKCore

/**
 * Version of SalesforceSDKManager to be used with all MobileSync-enabled apps.
 */
@objc(MobileSyncSDKManager)
public class MobileSyncSDKManager: SmartStoreSDKManager {

    @objc
    public override class func initializeSDK() {
        SalesforceManager.initializeSDK(manager: self)
    }

    /**
     * Setup global syncs using config found globalsyncs.json
     */
    @objc
    public func setupGlobalSyncsFromDefaultConfig() {
        let configPath = pathForGlobalSyncsConfig()
        SFSDKMobileSyncLogger.d(type(of: self), message: "Setting up global syncs using config found in \(configPath)")
        if let syncsConfig = SFSDKSyncsConfig(resourceAtPath: configPath), syncsConfig.hasSyncs(),
           let store = SmartStore.sharedGlobal(withName: kDefaultSmartStoreName) {
            syncsConfig.createSyncs(store)
        }
    }

    /**
     * Setup user syncs using config found in usersyncs.json
     */
    @objc
    public func setupUserSyncsFromDefaultConfig() {
        let configPath = pathForUserSyncsConfig()
        SFSDKMobileSyncLogger.d(type(of: self), message: "Setting up user syncs using config found in \(configPath)")
        if let syncsConfig = SFSDKSyncsConfig(resourceAtPath: configPath), syncsConfig.hasSyncs(),
           let store = SmartStore.shared(withName: kDefaultSmartStoreName) {
            syncsConfig.createSyncs(store)
        }
    }

    func pathForGlobalSyncsConfig() -> String {
        return "globalsyncs.json"
    }

    func pathForUserSyncsConfig() -> String {
        return "usersyncs.json"
    }

    /**
     @return The singleton instance of the SDK Manager.
     */
    @objc
    public override class var shared: MobileSyncSDKManager {
        return SalesforceManager.shared as! MobileSyncSDKManager
    }
}
