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
import SalesforceSDKCore

private let kStoreConfigSoups = "soups"
private let kStoreConfigSoupName = "soupName"
private let kStoreConfigIndexes = "indexes"

/// Class encapsulating a SmartStore schema (soups).
///
/// Config expected JSON in a resource file with the following format:
/// ```
/// {
///     "soups": [
///         {
///             "soupName": "xxx",
///             "indexes": [
///                 { "path": "xxx", "type": "xxx" }
///             ]
///         }
///     ]
/// }
/// ```
@objc(SFSDKStoreConfig)
@objcMembers
public class StoreConfig: NSObject {

    private var soupsConfig: [[String: Any]]?

    /// Initializes a store config from a resource file at the given path.
    ///
    /// - Parameter path: Path to the config file.
    @objc
    public init?(resourceAtPath path: String) {
        super.init()
        let config = SFSDKResourceUtils.loadConfig(fromFile: path, error: nil)
        if let config = config {
            self.soupsConfig = config[kStoreConfigSoups] as? [[String: Any]]
        } else {
            self.soupsConfig = nil
        }
    }

    /// Register the soups from the config in the given store.
    ///
    /// NB: only feedback is through the logs - the config is static so getting it right
    /// is something the developer should do while writing the app.
    ///
    /// - Parameter store: The store to register soups in.
    @objc
    public func registerSoups(_ store: SmartStore) {
        guard let soupsConfig = soupsConfig else {
            SmartStoreLogger.d(StoreConfig.self, message: "No store config available")
            return
        }

        for soupConfig in soupsConfig {
            guard let soupName = soupConfig[kStoreConfigSoupName] as? String else {
                continue
            }

            // Leaving soup alone if it already exists
            if store.soupExists(soupName) {
                SmartStoreLogger.d(StoreConfig.self, message: "Soup already exists:\(soupName) - skipping")
                continue
            }

            guard let indexDicts = soupConfig[kStoreConfigIndexes] as? [Any] else {
                continue
            }

            let indexSpecs = SoupIndex.asArraySoupIndexes(indexDicts)
            do {
                try store.registerSoup(withName: soupName, withIndices: indexSpecs)
            } catch {
                SmartStoreLogger.e(StoreConfig.self, message: "Error registering soup: \(soupName) - \(error)")
            }
        }
    }

    /// Check for soups in store config.
    ///
    /// - Returns: true if soups are defined in config.
    @objc
    public func hasSoups() -> Bool {
        guard let soupsConfig = soupsConfig else { return false }
        return !soupsConfig.isEmpty
    }
}
