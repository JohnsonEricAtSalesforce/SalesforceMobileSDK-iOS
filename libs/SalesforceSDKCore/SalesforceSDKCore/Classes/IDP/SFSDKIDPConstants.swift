// SFSDKIDPConstants.swift
// SalesforceSDKCore
//
// Created by Raj Rao on 9/28/17.
// Converted to Swift
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

@objc(SFSDKIDPConstants)
@objcMembers
public class SFSDKIDPConstants: NSObject {

    @objc public static let kSFErrorCodeParam = "errorCode"
    @objc public static let kSFErrorReasonParam = "errorReason"
    @objc public static let kSFVerifierByteLength: UInt = 128
    @objc public static let kSFVerifierParamName = "code_verifier"
    @objc public static let kSFChallengeParamName = "code_challenge"
    @objc public static let kSFStateParam = "state"
    @objc public static let kSFAppNameParam = "app_name"
    @objc public static let kSFUserHintParam = "user_hint"
    @objc public static let kSFLoginHostParam = "login_host"
    @objc public static let kSFCallingAppUrlParam = "calling_app_url"
    @objc public static let kSFErrorDescriptionParam = "errorDescription"
    @objc public static let kSFRefreshTokenParam = "refresh_token"
    @objc public static let kSFOAuthClientIdParam = "oauth_client_id"
    @objc public static let kSFOAuthRedirectUrlParam = "oauth_redirect_uri"
    @objc public static let kSFScopesParam = "scopes"
    @objc public static let kSFCodeParam = "code"
    @objc public static let kSFSpecVersion = "v1.0"
    @objc public static let kSFSpecHost = "oauth2"
    @objc public static let kSFStartURLParam = "start_url"
    @objc public static let kSFKeychainReferenceParam = "keychain_reference"
    @objc public static let kSFKeychainGroupParam = "keychain_group"
}
