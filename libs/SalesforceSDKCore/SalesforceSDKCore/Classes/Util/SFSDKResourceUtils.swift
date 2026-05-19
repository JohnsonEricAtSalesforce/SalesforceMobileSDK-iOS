// Copyright (c) 2012-present, salesforce.com, inc. All rights reserved.
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
import UIKit
import SalesforceSDKCommon

/// Class that handles access to Mobile SDK's main bundle.
@objc(SFSDKResourceUtils)
@objcMembers public class SFSDKResourceUtils: NSObject {

    private static var sdkBundle: Bundle?

    /// Returns Mobile SDK's main bundle.
    @objc public class func mainSdkBundle() -> Bundle? {
        if sdkBundle == nil {
            if let sdkBundlePath = Bundle(for: SFSDKResourceUtils.self).path(forResource: "SalesforceSDKResources", ofType: "bundle") {
                sdkBundle = Bundle(path: sdkBundlePath)
            }
        }
        return sdkBundle
    }

    /// Gets a localized string from the main Mobile SDK bundle.
    @objc public class func localizedString(_ localizationKey: String) -> String {
        assert(!localizationKey.isEmpty, "localizationKey must contain a value.")

        let value = NSLocalizedString(localizationKey, comment: localizationKey)
        if value != localizationKey {
            return value
        }

        let bundle = mainSdkBundle() ?? Bundle.main
        return NSLocalizedString(localizationKey, tableName: "Localizable", bundle: bundle, value: "", comment: "")
    }

    /// Retrieves an image from the "Images" asset catalog of the Mobile SDK framework bundle.
    @objc public class func imageNamed(_ name: String) -> UIImage? {
        assert(!name.isEmpty, "name must contain a value.")
        let mainBundle = Bundle.main
        if let image = UIImage(named: name, in: mainBundle, compatibleWith: nil) {
            return image
        }
        let frameworkBundle = Bundle(for: SFSDKResourceUtils.self)
        return UIImage(named: name, in: frameworkBundle, compatibleWith: nil)
    }

    /// Reads a configuration resource file and parses its contents. The file must be in JSON format.
    @objc public class func loadConfig(fromFile configFilePath: String, error: NSErrorPointer) -> NSDictionary? {
        guard let resourcePath = Bundle.main.resourcePath else { return nil }
        let fullPath = (resourcePath as NSString).appendingPathComponent(configFilePath)
        let fileContents: Data
        do {
            fileContents = try Data(contentsOf: URL(fileURLWithPath: fullPath), options: .uncached)
        } catch let readError {
            if let errPtr = error {
                errPtr.pointee = readError as NSError
            }
            return nil
        }
        return SFJsonUtils.object(fromJSONData: fileContents) as? NSDictionary
    }
}
