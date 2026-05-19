// SFSDKIDPAuthCodeLoginRequestCommand.swift
// SalesforceSDKCore
//
// Created by Brianna Birman on 4/18/23.
// Converted to Swift
//
// Copyright (c) 2023-present, salesforce.com, inc. All rights reserved.
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

/// Sent by IDP to SP for IDP initiated login flow using the keychain to store the code verifier
@objc(SFSDKIDPAuthCodeLoginRequestCommand)
@objcMembers
public class SFSDKIDPAuthCodeLoginRequestCommand: SFSDKAuthCommand {

    public override var command: String {
        get { return "idpauthcodeinit" }
        set { }
    }

    public var userHint: String? {
        get { return param(forKey: SFSDKIDPConstants.kSFUserHintParam) }
        set { if let val = newValue { setParam(val, forKey: SFSDKIDPConstants.kSFUserHintParam) } }
    }

    public var keychainReference: String? {
        get { return param(forKey: SFSDKIDPConstants.kSFKeychainReferenceParam) }
        set { if let val = newValue { setParam(val, forKey: SFSDKIDPConstants.kSFKeychainReferenceParam) } }
    }

    public var keychainGroup: String? {
        get { return param(forKey: SFSDKIDPConstants.kSFKeychainGroupParam) }
        set { if let val = newValue { setParam(val, forKey: SFSDKIDPConstants.kSFKeychainGroupParam) } }
    }

    public var authCode: String? {
        get { return param(forKey: SFSDKIDPConstants.kSFCodeParam) }
        set { if let val = newValue { setParam(val, forKey: SFSDKIDPConstants.kSFCodeParam) } }
    }
}
