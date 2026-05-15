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

import XCTest
@testable import SalesforceSDKCore

final class SFSDKURLCacheTestsSwift: XCTestCase {

    override func setUp() {
        super.setUp()
        // Ensure SalesforceManager is initialized and cache is set to encrypted
        _ = SalesforceManager.shared
    }

    func testSettingCacheTypes() {
        // Encrypted enabled by default
        _ = SalesforceManager.shared
        XCTAssertTrue(URLCache.shared is SFSDKEncryptedURLCache)

        // Set back to vanilla URL cache
        SalesforceManager.shared.URLCacheType = .standard
        XCTAssertTrue(type(of: URLCache.shared) == URLCache.self)

        // Set to null cache
        SalesforceManager.shared.URLCacheType = .null
        XCTAssertTrue(URLCache.shared is SFSDKNullURLCache)

        // Enable encrypted again
        SalesforceManager.shared.URLCacheType = .encrypted
        XCTAssertTrue(URLCache.shared is SFSDKEncryptedURLCache)
    }

    func testNilURL() {
        // In ObjC, NSURLRequest can have a nil URL and NSURLCache ignores it.
        // In Swift, URLRequest requires a non-nil URL, so we verify that
        // URL(string:encodingInvalidCharacters:) returns nil for invalid strings.
        let url = URL(string: "bad string -- will create nil URL", encodingInvalidCharacters: false)
        XCTAssertNil(url, "URL with invalid characters and encodingInvalidCharacters:false should be nil")
    }

    func testNullCacheEntry() {
        let nullURLCache = SFSDKNullURLCache()
        let contentString = "This is my content"
        let contentData = contentString.data(using: .utf8)!
        let url = URL(string: "https://www.salesforce.com")!
        let request = URLRequest(url: url)
        let response = URLResponse(url: url, mimeType: "text/plain", expectedContentLength: contentData.count, textEncodingName: "NSUTF8StringEncoding")

        // Should not store
        let toStore = CachedURLResponse(response: response, data: contentData, userInfo: nil, storagePolicy: .allowed)
        nullURLCache.storeCachedResponse(toStore, for: request)
        let cacheResult = nullURLCache.cachedResponse(for: request)
        XCTAssertNil(cacheResult)
    }

    func testEncryptedCacheEntry() {
        _ = SalesforceManager.shared
        XCTAssertTrue(URLCache.shared is SFSDKEncryptedURLCache)

        let contentString = "This is my content"
        let contentData = contentString.data(using: .utf8)!
        let url = URL(string: "https://www.salesforce.com")!
        let request = URLRequest(url: url)
        let response = URLResponse(url: url, mimeType: "text/plain", expectedContentLength: contentData.count, textEncodingName: "NSUTF8StringEncoding")

        let toStore = CachedURLResponse(response: response, data: contentData, userInfo: nil, storagePolicy: .allowed)
        URLCache.shared.storeCachedResponse(toStore, for: request)
        let cacheResult = URLCache.shared.cachedResponse(for: request)
        XCTAssertNotNil(cacheResult)

        let cacheString = String(data: cacheResult!.data, encoding: .utf8)
        XCTAssertEqual(cacheString, contentString)
    }

    func testUrlWithoutSubdomain() {
        // Weird host
        XCTAssertEqual("https://salesforce", SFSDKEncryptedURLCache.urlWithoutSubdomain(URL(string: "https://salesforce")!))
        XCTAssertEqual("https://salesforce/abc", SFSDKEncryptedURLCache.urlWithoutSubdomain(URL(string: "https://salesforce/abc")!))
        XCTAssertEqual("https://salesforce/abc?d=e", SFSDKEncryptedURLCache.urlWithoutSubdomain(URL(string: "https://salesforce/abc?d=e")!))

        // Path and host with and without subdomains
        XCTAssertEqual("https://salesforce.com/abc", SFSDKEncryptedURLCache.urlWithoutSubdomain(URL(string: "https://salesforce.com/abc")!))
        XCTAssertEqual("https://salesforce.com/abc", SFSDKEncryptedURLCache.urlWithoutSubdomain(URL(string: "https://cs1.salesforce.com/abc")!))
        XCTAssertEqual("https://salesforce.com/abc", SFSDKEncryptedURLCache.urlWithoutSubdomain(URL(string: "https://cs1.content.salesforce.com/abc")!))

        // Path and query and host with and without subdomains
        XCTAssertEqual("https://salesforce.com/abc?d=e", SFSDKEncryptedURLCache.urlWithoutSubdomain(URL(string: "https://salesforce.com/abc?d=e")!))
        XCTAssertEqual("https://salesforce.com/abc?d=e", SFSDKEncryptedURLCache.urlWithoutSubdomain(URL(string: "https://cs1.salesforce.com/abc?d=e")!))
        XCTAssertEqual("https://salesforce.com/abc?d=e", SFSDKEncryptedURLCache.urlWithoutSubdomain(URL(string: "https://cs1.content.salesforce.com/abc?d=e")!))
    }
}
