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

// Test subclass to track cache operations
private class TestSFSDKEncryptedURLCache: SFSDKEncryptedURLCache {
    var storedURLs = Set<String>()
    var queriedURLs = Set<String>()
    var storedResponses = [String: CachedURLResponse]()
    var keyGenerationError: Error?

    override init() {
        super.init()
        reset()
    }

    func reset() {
        storedURLs = Set<String>()
        queriedURLs = Set<String>()
        storedResponses = [String: CachedURLResponse]()
    }

    override func cachedResponse(for request: URLRequest) -> CachedURLResponse? {
        if let urlString = request.url?.absoluteString {
            queriedURLs.insert(urlString)
        }
        return super.cachedResponse(for: request)
    }

    override func storeCachedResponse(_ cachedResponse: CachedURLResponse, for request: URLRequest) {
        if let urlString = request.url?.absoluteString {
            storedURLs.insert(urlString)
            storedResponses[urlString] = cachedResponse
        }
        super.storeCachedResponse(cachedResponse, for: request)
    }

    func wasURLStored(_ urlString: String) -> Bool {
        return storedURLs.contains(urlString)
    }

    func wasURLQueried(_ urlString: String) -> Bool {
        return queriedURLs.contains(urlString)
    }

    var storedCount: Int {
        return storedURLs.count
    }

    var queriedCount: Int {
        return queriedURLs.count
    }
}

class SFSDKUrlCacheTests: XCTestCase {

    func testSettingCacheTypes() {
        // Encrypted enabled by default
        _ = SalesforceSDKManager.shared
        XCTAssertTrue(URLCache.shared is SFSDKEncryptedURLCache)

        // Set back to vanilla URL cache
        SalesforceSDKManager.shared.URLCacheType = .standard
        XCTAssertTrue(type(of: URLCache.shared) == URLCache.self)

        // Set to null cache
        SalesforceSDKManager.shared.URLCacheType = .null
        XCTAssertTrue(URLCache.shared is SFSDKNullURLCache)

        // Enable encrypted again
        SalesforceSDKManager.shared.URLCacheType = .encrypted
        XCTAssertTrue(URLCache.shared is SFSDKEncryptedURLCache)
    }

    func testNilURL() {
        // NSURLCache ignores requests with bad/nil URLs, make sure we don't crash
        let encryptedURLCache = SFSDKEncryptedURLCache()
        let contentString = "This is my content"
        guard let contentData = contentString.data(using: .utf8) else {
            XCTFail("Failed to create content data")
            return
        }
        guard let url = URL(string: "bad string -- will create nil URL", encodingInvalidCharacters: false) else {
            // URL is nil, which is the expected case for bad strings
            return
        }
        let request = URLRequest(url: url)
        let response = URLResponse(url: url, mimeType: "text/plain", expectedContentLength: contentData.count, textEncodingName: "NSUTF8StringEncoding")
        let toStore = CachedURLResponse(response: response, data: contentData, userInfo: nil, storagePolicy: .allowed)
        encryptedURLCache.storeCachedResponse(toStore, for: request)
        let cacheResult = encryptedURLCache.cachedResponse(for: request)
        XCTAssertNil(cacheResult)
    }

    func testNullCacheEntry() {
        let nullURLCache = SFSDKNullURLCache()
        let contentString = "This is my content"
        guard let contentData = contentString.data(using: .utf8),
              let url = URL(string: "https://www.salesforce.com") else {
            XCTFail("Failed to create test data")
            return
        }
        let request = URLRequest(url: url)
        let response = URLResponse(url: url, mimeType: "text/plain", expectedContentLength: contentData.count, textEncodingName: "NSUTF8StringEncoding")

        // Should not store
        let toStore = CachedURLResponse(response: response, data: contentData, userInfo: nil, storagePolicy: .allowed)
        nullURLCache.storeCachedResponse(toStore, for: request)
        let cacheResult = nullURLCache.cachedResponse(for: request)
        XCTAssertNil(cacheResult)
    }

    func testEncryptedCacheEntry() {
        _ = SalesforceSDKManager.shared
        XCTAssertTrue(URLCache.shared is SFSDKEncryptedURLCache)

        let contentString = "This is my content"
        guard let contentData = contentString.data(using: .utf8),
              let url = URL(string: "https://www.salesforce.com") else {
            XCTFail("Failed to create test data")
            return
        }
        let request = URLRequest(url: url)
        let response = URLResponse(url: url, mimeType: "text/plain", expectedContentLength: contentData.count, textEncodingName: "NSUTF8StringEncoding")

        let toStore = CachedURLResponse(response: response, data: contentData, userInfo: nil, storagePolicy: .allowed)
        URLCache.shared.storeCachedResponse(toStore, for: request)
        let cacheResult = URLCache.shared.cachedResponse(for: request)
        XCTAssertNotNil(cacheResult)

        if let resultData = cacheResult?.data {
            let cacheString = String(data: resultData, encoding: .utf8)
            XCTAssertEqual(cacheString, contentString)
        }
    }

    /// Tests that SFSDKEncryptedURLCache properly stores and retrieves cached responses from actual network requests.
    func testRestCalls() {
        // Create test cache to track operations
        let testCache = TestSFSDKEncryptedURLCache()

        do {
            // Set our test cache as the shared cache
            URLCache.shared = testCache

            // Configure SFNetwork to use our test cache
            let testSessionConfig = URLSessionConfiguration.default
            testSessionConfig.urlCache = testCache
            Network.setSessionConfiguration(testSessionConfig, identifier: "com.salesforce.network.ephemeralSession")

            // Don't need to login but want the instance URL from the config
            let credsData = TestSetupUtils.populateAuthCredentials(fromConfigFileFor: type(of: self))
            let baseURL = credsData.instanceUrl

            // Phase 1: Make network requests and verify cache gets populated
            makeRequests(withBaseURL: baseURL)

            // Verify cache got populated during Phase 1
            XCTAssertGreaterThan(testCache.storedCount, 0, "Cache should have been populated after first set of requests")
            let expectedRequestCount = 4
            XCTAssertEqual(testCache.storedCount, expectedRequestCount, "Cache should contain \(expectedRequestCount) stored responses")

            // Phase 2: Reset counters but keep cached data, then make the same requests again
            testCache.reset()

            makeRequests(withBaseURL: baseURL)

            // Verify cache was queried during Phase 2 (indicating cache hits)
            XCTAssertGreaterThan(testCache.queriedCount, 0, "Cache should have been queried during second set of requests")
            XCTAssertEqual(testCache.queriedCount, expectedRequestCount, "Cache should have been queried \(expectedRequestCount) times")
        }

        // Restore original cache configuration
        SalesforceSDKManager.shared.URLCacheType = .standard
        SalesforceSDKManager.shared.URLCacheType = .encrypted

        // Clean up SFNetwork instances to prevent affecting other tests
        Network.removeSharedInstance(forIdentifier: "com.salesforce.network.ephemeralSession")
    }

    func testUrlWithoutSubdomain() {
        // Weird host
        XCTAssertEqual("https://salesforce", SFSDKEncryptedURLCache.urlWithoutSubdomain(URL(string: "https://salesforce")))
        XCTAssertEqual("https://salesforce/abc", SFSDKEncryptedURLCache.urlWithoutSubdomain(URL(string: "https://salesforce/abc")))
        XCTAssertEqual("https://salesforce/abc?d=e", SFSDKEncryptedURLCache.urlWithoutSubdomain(URL(string: "https://salesforce/abc?d=e")))

        // Path and host with and without subdomains
        XCTAssertEqual("https://salesforce.com/abc", SFSDKEncryptedURLCache.urlWithoutSubdomain(URL(string: "https://salesforce.com/abc")))
        XCTAssertEqual("https://salesforce.com/abc", SFSDKEncryptedURLCache.urlWithoutSubdomain(URL(string: "https://cs1.salesforce.com/abc")))
        XCTAssertEqual("https://salesforce.com/abc", SFSDKEncryptedURLCache.urlWithoutSubdomain(URL(string: "https://cs1.content.salesforce.com/abc")))

        // Path and query and host with and without subdomains
        XCTAssertEqual("https://salesforce.com/abc?d=e", SFSDKEncryptedURLCache.urlWithoutSubdomain(URL(string: "https://salesforce.com/abc?d=e")))
        XCTAssertEqual("https://salesforce.com/abc?d=e", SFSDKEncryptedURLCache.urlWithoutSubdomain(URL(string: "https://cs1.salesforce.com/abc?d=e")))
        XCTAssertEqual("https://salesforce.com/abc?d=e", SFSDKEncryptedURLCache.urlWithoutSubdomain(URL(string: "https://cs1.content.salesforce.com/abc?d=e")))
    }

    // MARK: - Helpers

    private func makeRequests(withBaseURL baseURL: String) {
        let testImages: [[String: String]] = [
            ["path": "/img/icon/t4v35/standard/today_60.png"],
            ["path": "/img/icon/t4v35/standard/task_60.png"],
            ["path": "/img/icon/t4v35/custom/custom62_60.png"],
            ["path": "/img/icon/t4v35/action/share_post_120.png"]
        ]

        for imageInfo in testImages {
            guard let path = imageInfo["path"] else { continue }
            let request = RestRequest.request(withMethod: .GET, baseURL: baseURL, path: path, queryParams: nil)
            request.requiresAuthentication = false
            request.endpoint = ""
            sendRequest(request)
        }
    }

    private func sendRequest(_ request: RestRequest) {
        var status = kTestRequestStatusWaiting

        let expectation = self.expectation(description: "REST request completed")

        let failBlock: SFRestRequestFailBlock = { _, _, _ in
            status = kTestRequestStatusDidFail
            expectation.fulfill()
        }

        let completeBlock: SFRestResponseBlock = { _, _ in
            status = kTestRequestStatusDidLoad
            expectation.fulfill()
        }

        RestClient.sharedGlobalInstance.sendRequest(request, failureBlock: failBlock, successBlock: completeBlock)

        wait(for: [expectation], timeout: 30.0)
        XCTAssertEqual(status, kTestRequestStatusDidLoad, "request failed")
    }
}
