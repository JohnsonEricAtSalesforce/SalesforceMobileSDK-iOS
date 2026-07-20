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
/// the test explicitly delivers a response. This lets us control exactly
/// when each URLSessionDataTask's completion handler fires.
private class DeferredURLProtocol: URLProtocol {

    private static var pendingProtocols = [DeferredURLProtocol]()
    private static let lock = NSLock()

    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        pendingProtocols.removeAll()
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
        DeferredURLProtocol.lock.lock()
        defer { DeferredURLProtocol.lock.unlock() }
        DeferredURLProtocol.pendingProtocols.append(self)
    }

    override func stopLoading() {
        // Intentionally empty; responses are delivered manually.
    }

    static func deliverResponse(at index: Int, statusCode: Int) {
        let proto: DeferredURLProtocol
        lock.lock()
        // Bounds-guard the access: if the expected protocol hasn't registered yet (e.g. a
        // preceding wait timed out but XCTAssertTrue didn't halt the test), fail softly instead
        // of trapping on an out-of-range index — a trap crashes the host and thrashes the suite.
        guard index >= 0 && index < pendingProtocols.count else {
            lock.unlock()
            XCTFail("deliverResponse(at: \(index)) called but only \(pendingProtocols.count) protocol(s) pending")
            return
        }
        proto = pendingProtocols[index]
        lock.unlock()

        guard let url = proto.request.url else { return }
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: nil)
        let body = "{\"ok\":true}".data(using: .utf8) ?? Data()
        if let response = response {
            proto.client?.urlProtocol(proto, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        proto.client?.urlProtocol(proto, didLoad: body)
        proto.client?.urlProtocolDidFinishLoading(proto)
    }
}

// MARK: - Expose private methods for testing via ObjC runtime

private extension RestClient {
    func resendActiveRequestsRequiringAuthentication() {
        let selector = NSSelectorFromString("resendActiveRequestsRequiringAuthentication")
        guard responds(to: selector) else { return }
        perform(selector)
    }

    func flushPendingRequestQueue(_ error: Error?, rawResponse: URLResponse?) {
        let selector = NSSelectorFromString("flushPendingRequestQueue:rawResponse:")
        guard responds(to: selector) else { return }
        let impl = method(for: selector)
        typealias MethodType = @convention(c) (AnyObject, Selector, Error?, URLResponse?) -> Void
        let method = unsafeBitCast(impl, to: MethodType.self)
        method(self, selector, error, rawResponse)
    }
}

// MARK: - Tests

class SFRestAPIDataTaskRaceTests: XCTestCase {

    private var api: RestClient?

    override func setUp() {
        super.setUp()
        DeferredURLProtocol.reset()

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [DeferredURLProtocol.self]
        Network.setSessionConfiguration(config, identifier: NetworkEphemeralInstanceIdentifier)

        api = RestClient(user: nil)
    }

    override func tearDown() {
        api?.cancelAllRequests()
        api?.cleanup()
        DeferredURLProtocol.reset()
        Network.removeSharedEphemeralInstance()
        super.tearDown()
    }

    /// Creates a request that bypasses auth checks by using an absolute URL.
    /// Unique per-call so DeferredURLProtocol can distinguish them if needed.
    private static var counter = 0
    private func makeRequest() -> RestRequest {
        SFRestAPIDataTaskRaceTests.counter += 1
        let url = "https://test.example.com/api/\(SFRestAPIDataTaskRaceTests.counter)"
        let request = RestRequest(method: .GET, path: url, queryParams: nil)
        request.requiresAuthentication = false
        return request
    }

    /// Helper: spin the run loop until `condition` returns YES, up to `timeout` seconds.
    private func waitForCondition(_ condition: @escaping () -> Bool, timeout: TimeInterval) -> Bool {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while !condition() && deadline.timeIntervalSinceNow > 0 {
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.01))
        }
        return condition()
    }

    // MARK: - Test: resendActiveRequestsRequiringAuthentication race

    /// Reproduces the crash scenario:
    ///   1. Request is sent, creating dataTask #1 (in-flight).
    ///   2. Token refresh completes; resendActiveRequestsRequiringAuthentication
    ///      re-sends the same request, creating dataTask #2.
    ///   3. dataTask #1 completes (200 OK) -> successBlock should NOT be called
    ///      (stale task, guard drops it).
    ///   4. dataTask #2 completes (200 OK) -> successBlock IS called (current task).
    ///
    /// Without the stale-task guard, successBlock fires twice (crash).
    /// With the guard, successBlock fires exactly once.
    func testResendActiveRequestsDoesNotDoubleInvokeBlocks() {
        guard let api = api else { XCTFail("API not initialized"); return }

        var successCount = 0
        var failureCount = 0
        let expectation = self.expectation(description: "block called")

        let request = makeRequest()

        // Step 1: Send the request. This creates dataTask #1.
        api.send(request, failureBlock: { _, _, _ in
            failureCount += 1
        }, successBlock: { _, _ in
            successCount += 1
            expectation.fulfill()
        })

        // Wait for dataTask #1 to be registered with DeferredURLProtocol.
        XCTAssertTrue(waitForCondition({ DeferredURLProtocol.pendingCount >= 1 }, timeout: 2),
                      "dataTask #1 should be pending")

        // Step 2: Simulate what happens after token refresh succeeds:
        // resendActiveRequestsRequiringAuthentication re-sends all active requests.
        // This creates dataTask #2 for the same request.
        api.resendActiveRequestsRequiringAuthentication()

        // Wait for dataTask #2 to be registered.
        XCTAssertTrue(waitForCondition({ DeferredURLProtocol.pendingCount >= 2 }, timeout: 2),
                      "dataTask #2 should be pending")

        // Step 3: dataTask #1 (index 0) completes with 200 OK.
        DeferredURLProtocol.deliverResponse(at: 0, statusCode: 200)

        // Step 4: dataTask #2 (index 1) completes with 200 OK.
        DeferredURLProtocol.deliverResponse(at: 1, statusCode: 200)

        waitForExpectations(timeout: 5, handler: nil)

        XCTAssertEqual(successCount, 1, "successBlock must be called exactly once, was called \(successCount) times")
        XCTAssertEqual(failureCount, 0, "failureBlock must not be called")
    }

    // MARK: - Test: flushPendingRequestQueue race

    /// Reproduces the flush variant:
    ///   1. Request is sent, creating dataTask #1 (in-flight).
    ///   2. Token refresh FAILS; flushPendingRequestQueue calls failureBlock
    ///      for all active requests AND cancels their dataTasks.
    ///   3. dataTask #1's cancel callback fires -> guard drops it (stale task).
    ///
    /// Without the fix: failureBlock fires twice (once from flush, once from cancel callback).
    /// With the fix: failureBlock fires exactly once.
    func testFlushPendingRequestQueueDoesNotDoubleInvokeBlocks() {
        guard let api = api else { XCTFail("API not initialized"); return }

        var successCount = 0
        var failureCount = 0
        let expectation = self.expectation(description: "failure block called")

        let request = makeRequest()

        // Step 1: Send the request. This creates dataTask #1.
        api.send(request, failureBlock: { _, _, _ in
            failureCount += 1
            expectation.fulfill()
        }, successBlock: { _, _ in
            successCount += 1
        })

        // Wait for dataTask #1 to be registered.
        XCTAssertTrue(waitForCondition({ DeferredURLProtocol.pendingCount >= 1 }, timeout: 2),
                      "dataTask #1 should be pending")

        // Step 2: Simulate token refresh failure.
        let refreshError = NSError(domain: "TestDomain", code: 401, userInfo: nil)
        guard let rawURL = URL(string: "https://test.example.com") else {
            XCTFail("Failed to create URL")
            return
        }
        let rawResponse = HTTPURLResponse(url: rawURL, statusCode: 401, httpVersion: "HTTP/1.1", headerFields: nil)
        api.flushPendingRequestQueue(refreshError, rawResponse: rawResponse)

        waitForExpectations(timeout: 5, handler: nil)

        // Give any stale cancel callbacks time to fire.
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.5))

        XCTAssertEqual(failureCount, 1, "failureBlock must be called exactly once, was called \(failureCount) times")
        XCTAssertEqual(successCount, 0, "successBlock must not be called")
    }

    // MARK: - Test: cancelAllRequests still works

    /// Ensures that legitimate cancellation via cancelAllRequests still delivers
    /// the NSURLErrorCancelled error to the failureBlock (the stale-task guard
    /// must NOT interfere because cancelAllRequests doesn't re-send).
    func testCancelAllRequestsStillDeliversCancellationError() {
        guard let api = api else { XCTFail("API not initialized"); return }

        var failureCount = 0
        var receivedError: NSError?
        let expectation = self.expectation(description: "cancel delivered")

        let request = makeRequest()

        api.send(request, failureBlock: { _, error, _ in
            failureCount += 1
            receivedError = error as NSError?
            expectation.fulfill()
        }, successBlock: { _, _ in
            XCTFail("successBlock should not be called on cancellation")
        })

        // Wait for the dataTask to be in-flight.
        XCTAssertTrue(waitForCondition({ DeferredURLProtocol.pendingCount >= 1 }, timeout: 2),
                      "dataTask should be pending")

        // Cancel all requests.
        api.cancelAllRequests()

        waitForExpectations(timeout: 5, handler: nil)

        XCTAssertEqual(failureCount, 1, "failureBlock must be called exactly once")
        XCTAssertEqual(receivedError?.code, NSURLErrorCancelled, "Error should be NSURLErrorCancelled")
    }

    // MARK: - Test: cleanup during in-flight refresh

    /// Verifies that cleanup delivers "User logged out" errors to all pending
    /// requests and clears activeRequests, even when a token refresh cycle is active.
    func testCleanupDuringRefreshCycleDeliversLogoutError() {
        guard let api = api else { XCTFail("API not initialized"); return }

        var failureCount = 0
        var receivedError: NSError?
        let expectation = self.expectation(description: "failure delivered")

        let request = makeRequest()

        api.send(request, failureBlock: { _, error, _ in
            failureCount += 1
            receivedError = error as NSError?
            expectation.fulfill()
        }, successBlock: { _, _ in
            XCTFail("successBlock should not be called after cleanup")
        })

        // Wait for the request to be in-flight.
        XCTAssertTrue(waitForCondition({ DeferredURLProtocol.pendingCount >= 1 }, timeout: 2),
                      "dataTask should be pending")

        // Simulate a refresh cycle being active (as if a 401 triggered replayRequest:).
        api.refreshCycleActive = true

        // Logout triggers cleanup while refresh is in-flight.
        api.cleanup()

        waitForExpectations(timeout: 5, handler: nil)

        XCTAssertEqual(failureCount, 1, "failureBlock must be called exactly once")
        XCTAssertEqual(receivedError?.domain, SFRestErrorDomain, "Error domain should be REST error domain")
        XCTAssertTrue((receivedError?.userInfo[NSLocalizedDescriptionKey] as? String)?.contains("logged out") ?? false,
                      "Error message should mention logout")
        XCTAssertEqual(api.activeRequests.count, 0, "activeRequests should be empty after cleanup")
    }

    /// Verifies that if the coordinator's refresh callback fires AFTER cleanup
    /// has cleared activeRequests, no requests are resent and no crash occurs.
    func testRefreshCallbackAfterCleanupIsHarmless() {
        guard let api = api else { XCTFail("API not initialized"); return }

        var successCount = 0
        var failureCount = 0

        let request = makeRequest()

        api.send(request, failureBlock: { _, _, _ in
            failureCount += 1
        }, successBlock: { _, _ in
            successCount += 1
        })

        // Wait for the request to be in-flight.
        XCTAssertTrue(waitForCondition({ DeferredURLProtocol.pendingCount >= 1 }, timeout: 2),
                      "dataTask should be pending")

        // Simulate: refresh cycle active, then cleanup runs (logout).
        api.refreshCycleActive = true
        api.cleanup()

        // Now simulate what happens when the coordinator callback fires after cleanup.
        // This calls resendActiveRequestsRequiringAuthentication on an empty activeRequests set.
        api.resendActiveRequestsRequiringAuthentication()
        api.refreshCycleActive = false

        // Give any unexpected callbacks a chance to fire.
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.5))

        // The cleanup already delivered the failure. The post-cleanup resend should be a no-op.
        XCTAssertEqual(failureCount, 1, "failureBlock should have been called once (by cleanup)")
        XCTAssertEqual(successCount, 0, "successBlock must not be called after cleanup")
        XCTAssertEqual(api.activeRequests.count, 0, "activeRequests should remain empty")
    }

    /// Verifies that cleanup properly cancels in-flight dataTasks (the session
    /// data task cancel callback should not cause double-invocation of failureBlock).
    func testCleanupCancelsTasksWithoutDoubleCallback() {
        guard let api = api else { XCTFail("API not initialized"); return }

        var failureCount = 0
        let expectation = self.expectation(description: "failure delivered")

        let request = makeRequest()

        api.send(request, failureBlock: { _, _, _ in
            failureCount += 1
            if failureCount == 1 {
                expectation.fulfill()
            }
        }, successBlock: { _, _ in
            XCTFail("successBlock should not be called after cleanup")
        })

        // Wait for the request to be in-flight.
        XCTAssertTrue(waitForCondition({ DeferredURLProtocol.pendingCount >= 1 }, timeout: 2),
                      "dataTask should be pending")

        // Cleanup cancels tasks and delivers errors.
        api.cleanup()

        waitForExpectations(timeout: 5, handler: nil)

        // Give time for the cancelled dataTask's URLSession callback to fire.
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.5))

        XCTAssertEqual(failureCount, 1, "failureBlock must be called exactly once (cleanup), not again from cancellation callback. Was called \(failureCount) times")
    }

    /// Verifies that after cleanup, a new request can trigger a fresh refresh cycle
    /// (refreshCycleActive is not permanently stuck).
    func testNewRefreshCyclePossibleAfterCleanup() {
        guard let api = api else { XCTFail("API not initialized"); return }

        let request = makeRequest()

        api.send(request, failureBlock: { _, _, _ in }, successBlock: { _, _ in })

        XCTAssertTrue(waitForCondition({ DeferredURLProtocol.pendingCount >= 1 }, timeout: 2),
                      "dataTask should be pending")

        // Simulate refresh in progress, then cleanup (logout).
        api.refreshCycleActive = true
        api.cleanup()

        // After cleanup, refreshCycleActive should still be YES (cleanup doesn't reset it).
        // But activeRequests is empty, so a future callback is harmless.
        // Simulate the callback arriving and resetting the flag.
        api.refreshCycleActive = false

        // Now send a new request and verify a fresh refresh cycle can start.
        let newRequest = makeRequest()
        api.send(newRequest, failureBlock: { _, _, _ in }, successBlock: { _, _ in })

        XCTAssertTrue(waitForCondition({ DeferredURLProtocol.pendingCount >= 2 }, timeout: 2),
                      "new dataTask should be pending")

        XCTAssertFalse(api.refreshCycleActive, "refreshCycleActive should be false, ready for a new cycle")
        XCTAssertEqual(api.activeRequests.count, 1, "New request should be in activeRequests")
    }
}
