// SFSDKTestCredentialsData.swift
// SalesforceSDKCore
//
// Copyright (c) 2014-present, salesforce.com, inc. All rights reserved.
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

@objc(SFSDKTestCredentialsData)
@objcMembers
public class SFSDKTestCredentialsData: NSObject {

    private let credentialsDict: [String: Any]

    @objc public init(dict credentialsDict: [String: Any]) {
        self.credentialsDict = credentialsDict
        super.init()
    }

    @objc public var accessToken: String {
        return credentialsDict["access_token"] as? String ?? ""
    }

    @objc public var refreshToken: String {
        return credentialsDict["refresh_token"] as? String ?? ""
    }

    @objc public var identityUrl: String {
        return credentialsDict["identity_url"] as? String ?? ""
    }

    @objc public var instanceUrl: String {
        return credentialsDict["instance_url"] as? String ?? ""
    }

    @objc public var apiInstanceUrl: String {
        return credentialsDict["api_instance_url"] as? String ?? ""
    }

    @objc public var clientId: String {
        return credentialsDict["test_client_id"] as? String ?? ""
    }

    @objc public var redirectUri: String {
        return credentialsDict["test_redirect_uri"] as? String ?? ""
    }

    @objc public var loginHost: String {
        let value = credentialsDict["test_login_domain"] as? String ?? ""
        if value.hasPrefix("https://") { return String(value.dropFirst(8)) }
        if value.hasPrefix("http://") { return String(value.dropFirst(7)) }
        return value
    }

    @objc public var communityUrl: String {
        return credentialsDict["community_url"] as? String ?? ""
    }

    @objc public var username: String {
        return credentialsDict["username"] as? String ?? ""
    }

    @objc public var displayName: String {
        return credentialsDict["display_name"] as? String ?? ""
    }
}
