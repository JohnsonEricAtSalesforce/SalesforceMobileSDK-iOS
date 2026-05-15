/*
 Copyright (c) 2026-present, salesforce.com, inc. All rights reserved.

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

// MARK: - DeferredURLProtocol

/// URLProtocol subclass that intercepts all requests and holds them until
/// the test explicitly delivers a response.
private class DeferredURLProtocolSwift: URLProtocol {
    private static var pendingProtocols: [DeferredURLProtocolSwift] = []
    private static let lock = NSLock()

    static func reset() {
        lock.lock()
        pendingProtocols.removeAll()
        lock.unlock()
    }

    static var pendingCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return pendingProtocols.count
    }

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        DeferredURLProtocolSwift.lock.lock()
        DeferredURLProtocolSwift.pendingProtocols.append(self)
        DeferredURLProtocolSwift.lock.unlock()
    }

    override func stopLoading() {
        // Intentionally empty; responses are delivered manually.
    }

    static func deliverResponse(at index: Int, statusCode: Int) {
        lock.lock()
        let proto = pendingProtocols[index]
        lock.unlock()

        let response = HTTPURLResponse(url: proto.request.url!, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: nil)!
        let body = "{\"ok\":true}".data(using: .utf8)!
        proto.client?.urlProtocol(proto, didReceive: response, cacheStoragePolicy: .notAllowed)
        proto.client?.urlProtocol(proto, didLoad: body)
        proto.client?.urlProtocolDidFinishLoading(proto)
    }
}

// MARK: - Tests

/// Swift conversion of the data task race tests.
/// Note: Tests that exercise private methods (resendActiveRequestsRequiringAuthentication,
/// flushPendingRequestQueue) remain in the ObjC .m file since they require category-based
/// access to private methods which is not possible with @testable import in Swift.
/// This Swift file tests the publicly accessible cancelAllRequests behavior.
final class SFRestAPIDataTaskRaceTestsSwift: XCTestCase {

    private var api: RestClient!

    override func setUp() {
        super.setUp()
        DeferredURLProtocolSwift.reset()

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [DeferredURLProtocolSwift.self]
        Network.setSessionConfiguration(config, identifier: NetworkEphemeralInstanceIdentifier)

        api = RestClient(user: nil)
    }

    override func tearDown() {
        api.cancelAllRequests()
        api.cleanup()
        DeferredURLProtocolSwift.reset()
        Network.removeSharedEphemeralInstance()
        super.tearDown()
    }

    /// Creates a request that bypasses auth checks by using an absolute URL.
    private var requestCounter = 0
    private func makeRequest() -> RestRequest {
        requestCounter += 1
        let url = "https://test.example.com/api/\(requestCounter)"
        let request = RestRequest.request(withMethod: .GET, path: url, queryParams: nil)
        request.requiresAuthentication = false
        return request
    }

    /// Helper: spin the run loop until `condition` returns true, up to `timeout` seconds.
    private func waitForCondition(_ condition: @escaping () -> Bool, timeout: TimeInterval) -> Bool {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while !condition() && deadline.timeIntervalSinceNow > 0 {
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.01))
        }
        return condition()
    }

    // MARK: - Test: cancelAllRequests still works

    /// Ensures that legitimate cancellation via cancelAllRequests delivers
    /// the NSURLErrorCancelled error to the failureBlock.
    func testCancelAllRequestsStillDeliversCancellationError() {
        var failureCount = 0
        var receivedError: NSError?
        let completionExpectation = expectation(description: "cancel delivered")

        let request = makeRequest()

        api.send(request, failureBlock: { _, error, _ in
            failureCount += 1
            receivedError = error as NSError?
            completionExpectation.fulfill()
        }, successBlock: { _, _ in
            XCTFail("successBlock should not be called on cancellation")
        })

        // Wait for the dataTask to be in-flight.
        XCTAssertTrue(waitForCondition({ DeferredURLProtocolSwift.pendingCount >= 1 }, timeout: 2),
                      "dataTask should be pending")

        // Cancel all requests.
        api.cancelAllRequests()

        wait(for: [completionExpectation], timeout: 5)

        XCTAssertEqual(failureCount, 1, "failureBlock must be called exactly once")
        XCTAssertEqual(receivedError?.code, NSURLErrorCancelled, "Error should be NSURLErrorCancelled")
    }

    // MARK: - Test: basic send and receive

    /// Tests that a successful request properly invokes the successBlock.
    func testBasicSendAndReceive() {
        let completionExpectation = expectation(description: "success block called")

        let request = makeRequest()

        api.send(request, failureBlock: { _, _, _ in
            XCTFail("failureBlock should not be called")
        }, successBlock: { response, _ in
            XCTAssertNotNil(response)
            completionExpectation.fulfill()
        })

        // Wait for the dataTask to be registered.
        XCTAssertTrue(waitForCondition({ DeferredURLProtocolSwift.pendingCount >= 1 }, timeout: 2),
                      "dataTask should be pending")

        // Deliver a successful response.
        DeferredURLProtocolSwift.deliverResponse(at: 0, statusCode: 200)

        wait(for: [completionExpectation], timeout: 5)
    }
}
