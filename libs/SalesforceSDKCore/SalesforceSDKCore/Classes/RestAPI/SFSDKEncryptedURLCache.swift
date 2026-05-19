//
//  SFSDKEncryptedURLCache.swift
//  SalesforceSDKCore
//
//  Copyright (c) 2019-present, salesforce.com, inc. All rights reserved.
//
//  Redistribution and use of this software in source and binary forms, with or without modification,
//  are permitted provided that the following conditions are met:
//  * Redistributions of source code must retain the above copyright notice, this list of conditions
//    and the following disclaimer.
//  * Redistributions in binary form must reproduce the above copyright notice, this list of
//    conditions and the following disclaimer in the documentation and/or other materials provided
//    with the distribution.
//  * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
//    endorse or promote products derived from this software without specific prior written
//    permission of salesforce.com, inc.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
//  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
//  FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
//  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
//  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
//  WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

import Foundation
import CryptoKit

private let kURLSchemePrefix = "sfsdkURLCache://"
private let kURLCacheEncryptionKeyLabel = "com.salesforce.URLCache.encryptionKey"

/// An encrypted URL cache that encrypts both the request URL (as a hash) and the response data.
@objc(SFSDKEncryptedURLCache)
@objcMembers
public class SFSDKEncryptedURLCache: URLCache {

    private var encryptionKey: SymmetricKey?

    @objc(initWithMemoryCapacity:diskCapacity:cacheDirectory:)
    public convenience init(memoryCapacity: Int, diskCapacity: Int, cacheDirectory directoryURL: URL?) {
        self.init()
    }

    public override init() {
        super.init()
        encryptionKey = try? KeyGenerator.encryptionKey(for: kURLCacheEncryptionKeyLabel)
    }

    public override func cachedResponse(for request: URLRequest) -> CachedURLResponse? {
        guard let requestWithSecureURL = self.requestWithSecureURL(for: request) else {
            SFSDKCoreLogger.e(type(of: self), message: "RequestWithSecureURL is nil, unable to fetch cached response")
            return nil
        }

        guard let cachedResponse = super.cachedResponse(for: requestWithSecureURL),
              let key = encryptionKey else {
            return nil
        }

        do {
            let decryptedData = try Encryptor.decrypt(data: cachedResponse.data, using: key)
            return CachedURLResponse(
                response: cachedResponse.response,
                data: decryptedData,
                userInfo: cachedResponse.userInfo,
                storagePolicy: cachedResponse.storagePolicy
            )
        } catch {
            SFSDKCoreLogger.e(type(of: self), message: "Unable to decrypt cached response: \(error.localizedDescription)")
            return nil
        }
    }

    public override func storeCachedResponse(_ cachedResponse: CachedURLResponse, for request: URLRequest) {
        guard let requestWithSecureURL = self.requestWithSecureURL(for: request) else {
            SFSDKCoreLogger.e(type(of: self), message: "RequestWithSecureURL is nil, unable to store response")
            return
        }

        guard let key = encryptionKey else {
            SFSDKCoreLogger.e(type(of: self), message: "Encryption key is nil, unable to store response")
            return
        }

        do {
            let encryptedData = try Encryptor.encrypt(data: cachedResponse.data, using: key)
            let encryptedResponse = CachedURLResponse(
                response: cachedResponse.response,
                data: encryptedData,
                userInfo: cachedResponse.userInfo,
                storagePolicy: cachedResponse.storagePolicy
            )
            super.storeCachedResponse(encryptedResponse, for: requestWithSecureURL)
        } catch {
            SFSDKCoreLogger.e(type(of: self), message: "Unable to encrypt response to store \(error.localizedDescription)")
        }
    }

    public override func removeCachedResponse(for request: URLRequest) {
        guard let requestWithSecureURL = self.requestWithSecureURL(for: request) else {
            SFSDKCoreLogger.e(type(of: self), message: "RequestWithSecureURL is nil, unable to remove cached response")
            return
        }
        super.removeCachedResponse(for: requestWithSecureURL)
    }

    // MARK: - Private

    private func requestWithSecureURL(for request: URLRequest) -> URLRequest? {
        guard request.url != nil else {
            SFSDKCoreLogger.e(type(of: self), message: "Request URL is nil")
            return nil
        }

        let urlHash = SFSDKEncryptedURLCache.computeHash(request)
        let prefixedURL = "\(kURLSchemePrefix)\(urlHash)"
        guard let secureURL = URL(string: prefixedURL) else {
            return nil
        }
        return URLRequest(url: secureURL, cachePolicy: request.cachePolicy, timeoutInterval: request.timeoutInterval)
    }

    @objc public static func computeHash(_ request: URLRequest) -> String {
        let urlString = urlWithoutSubdomain(request.url)
        return (urlString.data(using: .utf8) as NSData?)?.sfsdk_sha256() ?? ""
    }

    @objc public static func urlWithoutSubdomain(_ url: URL?) -> String {
        guard let url = url else { return "" }
        let host = url.host ?? ""
        let path = url.path
        let query = url.query

        let hostParts = host.components(separatedBy: ".")
        let startIndex = hostParts.count >= 2 ? hostParts.count - 2 : 0
        let hostWithoutSubdomain = hostParts[startIndex...].joined(separator: ".")

        let queryPart = query != nil ? "?\(query ?? "")" : ""
        return "https://\(hostWithoutSubdomain)\(path)\(queryPart)"
    }
}
