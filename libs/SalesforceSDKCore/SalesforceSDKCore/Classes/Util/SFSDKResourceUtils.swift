/*
 Copyright (c) 2012-present, salesforce.com, inc. All rights reserved.
 Author: Kevin Hawkins

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
import SalesforceSDKCommon

/**
 * Class that handles access to Mobile SDK's main bundle.
 */
@objc(SFSDKResourceUtils)
public class SFSDKResourceUtils: NSObject {

    private static var cachedMainSdkBundle: Bundle?

    /**
     * @return Mobile SDK's main bundle.
     */
    @objc
    public static func mainSdkBundle() -> Bundle {
        // One instance. This won't change during the lifetime of the app process.
        if let bundle = cachedMainSdkBundle {
            return bundle
        }

        let sdkBundlePath = Bundle(for: self).path(forResource: "SalesforceSDKResources", ofType: "bundle")
        if let path = sdkBundlePath, let bundle = Bundle(path: path) {
            cachedMainSdkBundle = bundle
            return bundle
        }

        // Fallback to main bundle if resource bundle not found
        cachedMainSdkBundle = Bundle.main
        return Bundle.main
    }

    /**
     * Gets a localized string from the main Mobile SDK bundle.
     * @param localizationKey Localization key used to look up the localized string.
     * @return Localized string associated with the key.
     */
    @objc
    public static func localizedString(_ localizationKey: String) -> String {
        assert(!localizationKey.isEmpty, "localizationKey must contain a value.")

        let value = NSLocalizedString(localizationKey, comment: localizationKey)
        if !value.isEmpty && value != localizationKey {
            // get from main bundle first to allow customer to override
            return value
        }

        let sdkBundle = mainSdkBundle()
        return NSLocalizedString(localizationKey, tableName: "Localizable", bundle: sdkBundle, comment: "")
    }

    /**
     * Retrieves an image from the "Images" asset catalog of the Mobile SDK framework bundle.
     * @param name Name of the image in the asset catalog.
     * @return `UIImage` object containing the named image from the asset catalog.
     */
    @objc
    public static func imageNamed(_ name: String) -> UIImage? {
        assert(!name.isEmpty, "name must contain a value.")

        // Get from main bundle first to allow customer to override
        if let image = UIImage(named: name, in: Bundle.main, compatibleWith: nil) {
            return image
        }

        // Try SDK bundle
        let bundle = Bundle(for: self)
        return UIImage(named: name, in: bundle, compatibleWith: nil)
    }

    /**
     * Read a configuration resource file and parse its contents. The file must be in JSON format.
     * @param configFilePath Path to the configuration resource file.
     * @param error Input-output parameter that sets or returns any error that occurs during file reading.
     * @return `NSDictionary` object built from the file's contents.
     */
    public static func loadConfig(fromFile configFilePath: String) throws -> NSDictionary? {
        guard let resourcePath = Bundle.main.resourcePath else {
            return nil
        }

        let fullPath = (resourcePath as NSString).appendingPathComponent(configFilePath)
        let fileContents = try Data(contentsOf: URL(fileURLWithPath: fullPath), options: .uncached)
        let jsonDict = SFJsonUtils.object(from: fileContents) as? NSDictionary
        return jsonDict
    }
}
