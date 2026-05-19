// Copyright (c) 2012-present, salesforce.com, inc. All rights reserved.
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

/// The type of authentication being attempted, in a given OAuth coordinator cycle.
@objc(SFOAuthType)
public enum SFOAuthType: UInt {
    case unknown = 0
    case userAgent
    case refresh
    case advancedBrowser
    case jwtTokenExchange
    case idp
    case webServer
    case native
    case refreshTokenMigration
}

/// Data class containing members denoting state information for an OAuth coordinator authentication cycle.
@objc(SFOAuthInfo)
@objcMembers
public class SFOAuthInfo: NSObject {

    /// The type of authentication being performed.
    public private(set) var authType: SFOAuthType

    /// The string description of the auth type.
    public var authTypeDescription: String {
        switch authType {
        case .userAgent:
            return "SFOAuthTypeUserAgent"
        case .webServer:
            return "SFOAuthTypeWebServer"
        case .refresh:
            return "SFOAuthTypeRefresh"
        case .advancedBrowser:
            return "SFOAuthTypeAdvancedBrowser"
        case .jwtTokenExchange:
            return "SFOAuthTypeJwtTokenExchange"
        case .idp:
            return "SFOAuthTypeIDP"
        case .native:
            return "SFOAuthTypeNative"
        case .refreshTokenMigration:
            return "SFOAuthTypeRefreshTokenMigration"
        case .unknown:
            return "SFOAuthTypeUnknown"
        @unknown default:
            return "SFOAuthTypeUnknown"
        }
    }

    /// Creates a new instance with the given auth type.
    /// - Parameter authType: The type of authentication being performed.
    @objc public init(authType: SFOAuthType) {
        self.authType = authType
        super.init()
    }

    public override var description: String {
        return "<SFOAuthInfo: \(Unmanaged.passUnretained(self).toOpaque()), authType=\(authTypeDescription)>"
    }
}
