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

// App Feature Marker Constants
public let kSFAppFeatureSwiftApp = "SW"
public let kSFAppFeatureMultiUser = "MU"
public let kSFAppFeatureMacApp = "MC"
public let kSFAppFeatureNativeLogin = "NL"
public let kSFAppFeatureWelcomeDiscovery = "WD"
public let kSFAppFeatureSafariBrowserForLogin = "BW"
public let kSFAppFeatureScreenLock = "SL"
public let kSFAppFeatureBioAuth = "BA"
public let kSFAppFeatureManagedByMDM = "MM"
public let kSFAppFeatureOAuth = "UA"
public let kSFAppFeatureAiltnEnabled = "AI"
public let kSFSPAppFeatureIDPLogin = "SP"
public let kSFIDPAppFeatureIDPLogin = "IP"
public let kSFAppFeatureQrCodeLogin = "QR"

/// Class to register and unregister feature markers associated with SDK facilities being used in an app.
@objc(SFSDKAppFeatureMarkers)
@objcMembers
public class SFSDKAppFeatureMarkers: NSObject {

    private static var appFeatureMarkersSet: NSMutableSet = NSMutableSet()
    private static let dispatchQueue = DispatchQueue(label: "com.salesforce.mobilesdk.appFeaturesQueue")

    /// Register a particular app feature.
    /// - Parameter appFeature: The string representation of the feature to register.
    @objc(registerAppFeature:)
    public static func registerAppFeature(_ appFeature: String) {
        dispatchQueue.sync {
            appFeatureMarkersSet.add(appFeature)
        }
    }

    /// Unregister a particular app feature.
    /// - Parameter appFeature: The string representation of the feature to unregister.
    @objc(unregisterAppFeature:)
    public static func unregisterAppFeature(_ appFeature: String) {
        dispatchQueue.sync {
            appFeatureMarkersSet.remove(appFeature)
        }
    }

    /// Returns the current set of registered features.
    @objc(appFeatures)
    public static func appFeatures() -> Set<String> {
        var markersSet: Set<String>!
        dispatchQueue.sync {
            markersSet = appFeatureMarkersSet.copy() as? Set<String> ?? Set<String>()
        }
        return markersSet
    }
}
