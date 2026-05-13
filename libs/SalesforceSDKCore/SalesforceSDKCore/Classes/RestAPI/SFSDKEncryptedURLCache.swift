/*
 Copyright (c) 2019-present, salesforce.com, inc. All rights reserved.

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
import CryptoKit

private let kURLSchemePrefix = "sfsdkURLCache://"
private let kURLCacheEncryptionKeyLabel = "com.salesforce.URLCache.encryptionKey"

@objc(SFSDKEncryptedURLCache)
@objcMembers
public class EncryptedURLCache: URLCache {

    private var encryptionKey: SymmetricKey?

    public override init() {
        super.init()
        self.encryptionKey = try? KeyGenerator.encryptionKey(for: kURLCacheEncryptionKeyLabel)
    }

    @objc
    public override init(memoryCapacity: Int, diskCapacity: Int, diskPath path: String?) {
        super.init(memoryCapacity: memoryCapacity, diskCapacity: diskCapacity, diskPath: path)
        self.encryptionKey = try? KeyGenerator.encryptionKey(for: kURLCacheEncryptionKeyLabel)
    }

    public override func cachedResponse(for request: URLRequest) -> CachedURLResponse? {
        // For request.URL
        guard let requestWithSecureURL = requestWithSecureURL(for: request) else {
            SFSDKCoreLogger.e(EncryptedURLCache.self, message: "RequestWithSecureURL is nil, unable to fetch cached response")
            return nil
        }

        // For response.data
        guard let cachedResponse = super.cachedResponse(for: requestWithSecureURL) else {
            return nil
        }

        guard let encryptionKey = encryptionKey else {
            SFSDKCoreLogger.e(EncryptedURLCache.self, message: "Encryption key is nil")
            return nil
        }

        do {
            let decryptedResponseData = try Encryptor.decrypt(data: cachedResponse.data, using: encryptionKey)
            let decryptedURLResponse = CachedURLResponse(
                response: cachedResponse.response,
                data: decryptedResponseData,
                userInfo: cachedResponse.userInfo,
                storagePolicy: cachedResponse.storagePolicy
            )
            return decryptedURLResponse
        } catch {
            SFSDKCoreLogger.e(EncryptedURLCache.self, message: "Unable to decrypt cached response: \(error.localizedDescription)")
            return nil
        }
    }

    public override func storeCachedResponse(_ cachedResponse: CachedURLResponse, for request: URLRequest) {
        // For request.URL
        guard let requestWithSecureURL = requestWithSecureURL(for: request) else {
            SFSDKCoreLogger.e(EncryptedURLCache.self, message: "RequestWithSecureURL is nil, unable to store response")
            return
        }

        // For cachedResponse.data
        guard let encryptionKey = encryptionKey else {
            SFSDKCoreLogger.e(EncryptedURLCache.self, message: "Encryption key is nil")
            return
        }

        do {
            let encryptedResponseData = try Encryptor.encrypt(data: cachedResponse.data, using: encryptionKey)
            let encryptedURLResponse = CachedURLResponse(
                response: cachedResponse.response,
                data: encryptedResponseData,
                userInfo: cachedResponse.userInfo,
                storagePolicy: cachedResponse.storagePolicy
            )
            super.storeCachedResponse(encryptedURLResponse, for: requestWithSecureURL)
        } catch {
            SFSDKCoreLogger.e(EncryptedURLCache.self, message: "Unable to encrypt response to store: \(error.localizedDescription)")
        }
    }

    public override func removeCachedResponse(for request: URLRequest) {
        guard let requestWithSecureURL = requestWithSecureURL(for: request) else {
            SFSDKCoreLogger.e(EncryptedURLCache.self, message: "RequestWithSecureURL is nil, unable to remove cached response")
            return
        }
        super.removeCachedResponse(for: requestWithSecureURL)
    }

    private func requestWithSecureURL(for request: URLRequest) -> URLRequest? {
        guard let url = request.url else {
            SFSDKCoreLogger.e(EncryptedURLCache.self, message: "Request URL is nil")
            return nil
        }

        let urlHash = EncryptedURLCache.computeHash(request)
        let prefixedURL = "\(kURLSchemePrefix)\(urlHash)"
        guard let secureURL = URL(string: prefixedURL) else {
            return nil
        }

        var newRequest = URLRequest(url: secureURL, cachePolicy: request.cachePolicy, timeoutInterval: request.timeoutInterval)
        return newRequest
    }

    @objc
    public static func computeHash(_ request: URLRequest) -> String {
        guard let url = request.url else { return "" }
        let urlWithoutSubdomain = EncryptedURLCache.urlWithoutSubdomain(url)
        guard let data = urlWithoutSubdomain.data(using: .utf8) else { return "" }
        return (data as NSData).sfsdk_sha256
    }

    @objc
    public static func urlWithoutSubdomain(_ url: URL) -> String {
        let host = url.host ?? ""
        let path = url.path
        let query = url.query

        let hostParts = host.components(separatedBy: ".")
        let endRange = hostParts.count >= 2 ? (hostParts.count - 2)..<hostParts.count : 0..<min(hostParts.count, 2)
        let hostWithoutSubdomain = Array(hostParts[endRange]).joined(separator: ".")

        let queryString = query != nil ? "?\(query!)" : ""
        return "https://\(hostWithoutSubdomain)\(path)\(queryString)"
    }
}
