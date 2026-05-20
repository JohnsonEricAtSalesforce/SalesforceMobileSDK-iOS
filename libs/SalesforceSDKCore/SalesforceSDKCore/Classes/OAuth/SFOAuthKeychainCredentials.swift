// Copyright (c) 2015-present, salesforce.com, inc. All rights reserved.
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
import CryptoKit
import SalesforceSDKCommon

@objc(SFOAuthKeychainCredentials)
public class OAuthKeychainCredentials: OAuthCredentials {

    // MARK: - NSSecureCoding
    // Must explicitly override because we override init(coder:)
    @objc override public class var supportsSecureCoding: Bool { true }

    // MARK: - Initialization

    /// Convenience init defaulting to keychain storage type.
    @objc public convenience init?(identifier theIdentifier: String, clientId theClientId: String?, encrypted: Bool) {
        self.init(identifier: theIdentifier, clientId: theClientId, encrypted: encrypted, storageType: .keychain)
    }

    @objc public init?(identifier theIdentifier: String, clientId theClientId: String?, encrypted: Bool, storageType type: OAuthCredentialsStorageType) {
        super.init(internalIdentifier: theIdentifier, clientId: theClientId, encrypted: encrypted)
    }

    override init(internalIdentifier theIdentifier: String, clientId theClientId: String?, encrypted: Bool) {
        super.init(internalIdentifier: theIdentifier, clientId: theClientId, encrypted: encrypted)
    }

    @objc public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    // MARK: - Token Storage (Keychain-backed)

    public override var accessToken: String? {
        get { return decryptedToken(forService: kSFOAuthServiceAccess) }
        set { encryptToken(newValue, forService: kSFOAuthServiceAccess) }
    }

    public override var refreshToken: String? {
        get { return decryptedToken(forService: kSFOAuthServiceRefresh) }
        set { encryptToken(newValue, forService: kSFOAuthServiceRefresh) }
    }

    public override var lightningSid: String? {
        get { return decryptedToken(forService: kSFOAuthServiceLightningSid) }
        set { encryptToken(newValue, forService: kSFOAuthServiceLightningSid) }
    }

    public override var vfSid: String? {
        get { return decryptedToken(forService: kSFOAuthServiceVfSid) }
        set { encryptToken(newValue, forService: kSFOAuthServiceVfSid) }
    }

    public override var contentSid: String? {
        get { return decryptedToken(forService: kSFOAuthServiceContentSid) }
        set { encryptToken(newValue, forService: kSFOAuthServiceContentSid) }
    }

    public override var csrfToken: String? {
        get { return decryptedToken(forService: kSFOAuthServiceCsrf) }
        set { encryptToken(newValue, forService: kSFOAuthServiceCsrf) }
    }

    public override var parentSid: String? {
        get { return decryptedToken(forService: kSFOAuthServiceParentSid) }
        set { encryptToken(newValue, forService: kSFOAuthServiceParentSid) }
    }

    public override var beaconChildConsumerKey: String? {
        get { return decryptedToken(forService: kSFOAuthServiceBeaconChildConsumerKey) }
        set { encryptToken(newValue, forService: kSFOAuthServiceBeaconChildConsumerKey) }
    }

    public override var beaconChildConsumerSecret: String? {
        get { return decryptedToken(forService: kSFOAuthServiceBeaconChildConsumerSecret) }
        set { encryptToken(newValue, forService: kSFOAuthServiceBeaconChildConsumerSecret) }
    }

    // MARK: - Private Keychain Methods

    private func tokenData(forService service: String) -> Data? {
        guard !identifier.isEmpty else {
            NSException(name: .internalInconsistencyException, reason: "identifier cannot be nil or empty", userInfo: nil).raise()
            return nil
        }
        let result = KeychainHelper.createIfNotPresent(service: service, account: identifier)
        if let error = result.error {
            SFSDKCoreLogger.e(type(of: self), message: "Could not read \(service) from keychain, \(error)")
        }
        return result.data
    }

    @objc public func decryptedToken(forService service: String) -> String? {
        guard let symmetricKey = symmetricKey(forService: service) else { return nil }
        guard let data = tokenData(forService: service) else { return nil }

        if isEncrypted {
            guard let decryptedData = try? Encryptor.decrypt(data: data, using: symmetricKey) else { return nil }
            return String(data: decryptedData, encoding: .utf8)
        } else {
            return String(data: data, encoding: .utf8)
        }
    }

    @objc public func encryptToken(_ token: String?, forService service: String) {
        guard let symmetricKey = symmetricKey(forService: service) else { return }
        var tokenData: Data?
        if let token = token, !token.isEmpty {
            tokenData = token.data(using: .utf8)
            if isEncrypted, let data = tokenData {
                tokenData = try? Encryptor.encrypt(data: data, using: symmetricKey)
            }
        }

        let success = updateKeychain(withTokenData: tokenData, forService: service)
        if !success {
            SFSDKCoreLogger.w(type(of: self), message: "\(type(of: self)):encryptToken - Failed to update \(service).")
        }
    }

    private func updateKeychain(withTokenData tokenData: Data?, forService service: String) -> Bool {
        guard !identifier.isEmpty else {
            NSException(name: .internalInconsistencyException, reason: "identifier cannot be nil or empty", userInfo: nil).raise()
            return false
        }

        let _ = KeychainHelper.createIfNotPresent(service: service, account: identifier)
        let result: KeychainResult
        if let tokenData = tokenData {
            result = KeychainHelper.write(service: service, data: tokenData, account: identifier)
            if !result.success {
                SFSDKCoreLogger.w(type(of: self), message: "\(type(of: self)):updateKeychain - Error saving token data to keychain: \(String(describing: result.error))")
            }
        } else {
            result = KeychainHelper.reset(service: service, account: identifier)
            if !result.success {
                SFSDKCoreLogger.w(type(of: self), message: "\(type(of: self)):updateKeychain - Error resetting tokenData in keychain: \(String(describing: result.error))")
            }
        }
        return result.success
    }

    private func symmetricKey(forService service: String) -> SymmetricKey? {
        return try? KeyGenerator.encryptionKey(for: service)
    }
}
