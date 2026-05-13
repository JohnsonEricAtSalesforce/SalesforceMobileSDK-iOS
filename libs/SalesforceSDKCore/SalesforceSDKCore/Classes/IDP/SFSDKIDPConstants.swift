/*
 SFSDKIDPConstants.swift
 SalesforceSDKCore

 Created by Raj Rao on 9/28/17.

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

public let kSFErrorCodeParam = "errorCode"
public let kSFErrorReasonParam = "errorReason"
public let kSFVerifierByteLength: UInt = 128
public let kSFVerifierParamName = "code_verifier"
public let kSFChallengeParamName = "code_challenge"
public let kSFStateParam = "state"
public let kSFAppNameParam = "app_name"
public let kSFUserHintParam = "user_hint"
public let kSFLoginHostParam = "login_host"
public let kSFCallingAppUrlParam = "calling_app_url"
public let kSFErrorDescriptionParam = "errorDescription"
public let kSFRefreshTokenParam = "refresh_token"
public let kSFOAuthClientIdParam = "oauth_client_id"
public let kSFOAuthRedirectUrlParam = "oauth_redirect_uri"
public let kSFScopesParam = "scopes"
public let kSFCodeParam = "code"
public let kSFSpecVersion = "v1.0"
public let kSFSpecHost = "oauth2"
public let kSFStartURLParam = "start_url"
public let kSFKeychainReferenceParam = "keychain_reference"
public let kSFKeychainGroupParam = "keychain_group"

@objc(SFSDKIDPConstants)
public class SFSDKIDPConstants: NSObject {
}
