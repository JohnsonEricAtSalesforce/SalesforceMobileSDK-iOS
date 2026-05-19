// SFSDKAppFeatureMarkers.swift
//
// Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.
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

// MARK: - App Feature Marker Constants

public let kSFAppFeatureSwiftApp: String = "SW"
public let kSFAppFeatureMultiUser: String = "MU"
public let kSFAppFeatureMacApp: String = "MC"
public let kSFAppFeatureNativeLogin: String = "NL"
public let kSFAppFeatureWelcomeDiscovery: String = "WD"
public let kSFAppFeatureSafariBrowserForLogin: String = "BW"
public let kSFAppFeatureScreenLock: String = "SL"
public let kSFAppFeatureBioAuth: String = "BA"
public let kSFAppFeatureManagedByMDM: String = "MM"
public let kSFAppFeatureOAuth: String = "UA"
public let kSFAppFeatureAiltnEnabled: String = "AI"
public let kSFSPAppFeatureIDPLogin: String = "SP"
public let kSFIDPAppFeatureIDPLogin: String = "IP"
public let kSFAppFeatureQrCodeLogin: String = "QR"

// MARK: - SFSDKAppFeatureMarkers

/// Class to register and unregister feature markers associated with SDK facilities being used in an app.
@objc(SFSDKAppFeatureMarkers)
@objcMembers
public class SFSDKAppFeatureMarkers: NSObject {

    private static let queue = DispatchQueue(label: "com.salesforce.mobilesdk.appFeaturesQueue")
    private static var markersSet = Set<String>()

    /// Register a particular app feature.
    /// - Parameter appFeature: The string representation of the feature to register.
    @objc public static func registerAppFeature(_ appFeature: String) {
        queue.sync {
            markersSet.insert(appFeature)
        }
    }

    /// Unregister a particular app feature.
    /// - Parameter appFeature: The string representation of the feature to unregister.
    @objc public static func unregisterAppFeature(_ appFeature: String) {
        queue.sync {
            markersSet.remove(appFeature)
        }
    }

    /// The current set of registered features.
    @objc public static func appFeatures() -> Set<String> {
        var result = Set<String>()
        queue.sync {
            result = markersSet
        }
        return result
    }
}
