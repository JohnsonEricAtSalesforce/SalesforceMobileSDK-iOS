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

class SFNetworkTests: XCTestCase {

    func testSessionSharing() {
        // Default ephemeral instance
        do {
            let network = Network.sharedEphemeralInstance()
            XCTAssertNotNil(network.activeSession)
            let identifiers = Network.sharedInstanceIdentifiers() ?? []
            XCTAssertEqual(identifiers.count, 1)
            XCTAssertTrue(identifiers.contains(NetworkEphemeralInstanceIdentifier))
        }

        // Add default background instance
        do {
            let network = Network.sharedBackgroundInstance()
            XCTAssertNotNil(network.activeSession)
            XCTAssertEqual(network.activeSession.configuration.identifier, NetworkBackgroundInstanceIdentifier)
            let identifiers = Network.sharedInstanceIdentifiers() ?? []
            XCTAssertEqual(identifiers.count, 2)
            XCTAssertTrue(identifiers.contains(NetworkEphemeralInstanceIdentifier))
            XCTAssertTrue(identifiers.contains(NetworkBackgroundInstanceIdentifier))
        }

        // Another ephemeral instance, should be reused from the first one
        do {
            let network = Network.sharedEphemeralInstance()
            XCTAssertNotNil(network.activeSession)
            let identifiers = Network.sharedInstanceIdentifiers() ?? []
            XCTAssertEqual(identifiers.count, 2)
            XCTAssertTrue(identifiers.contains(NetworkEphemeralInstanceIdentifier))
        }

        // Remove ephemeral instance with convenience wrapper
        do {
            Network.removeSharedEphemeralInstance()
            let identifiers = Network.sharedInstanceIdentifiers() ?? []
            XCTAssertEqual(identifiers.count, 1)
            XCTAssertFalse(identifiers.contains(NetworkEphemeralInstanceIdentifier))
        }

        // New custom instance
        do {
            let customConfig = URLSessionConfiguration.default
            customConfig.allowsCellularAccess = false
            let network = Network.sharedInstance(withIdentifier: "sessionWithCustomConfig", sessionConfiguration: customConfig)
            XCTAssertNotNil(network.activeSession)
            let instances = Network.allSharedInstances()
            XCTAssertEqual(instances.count, 2)

            let sharedInstance = instances["sessionWithCustomConfig"]
            XCTAssertNotNil(sharedInstance)
            XCTAssertFalse(sharedInstance?.activeSession.configuration.allowsCellularAccess ?? true)
        }

        // Clear all
        do {
            Network.removeAllSharedInstances()
            let identifiers = Network.sharedInstanceIdentifiers() ?? []
            XCTAssertEqual(identifiers.count, 0)
        }

        // New custom session with default config, then remove it
        do {
            let identifier = "sessionWithDefaultConfig"

            let network = Network.sharedEphemeralInstance(withIdentifier: identifier)
            XCTAssertNotNil(network.activeSession)
            var identifiers = Network.sharedInstanceIdentifiers() ?? []
            XCTAssertEqual(identifiers.count, 1)
            XCTAssertTrue(identifiers.contains(identifier))

            Network.removeSharedInstance(forIdentifier: identifier)
            identifiers = Network.sharedInstanceIdentifiers() ?? []
            XCTAssertEqual(identifiers.count, 0)
            XCTAssertFalse(identifiers.contains(identifier))
        }
    }

    func testMetricsAction() {
        addTeardownBlock {
            Network.metricsCollectedAction = nil
        }

        let getExpectation = expectation(description: "Get")
        let testBaseURL = "https://mobilesdk.my.salesforce.com"
        let testPathURL = "/.well-known/auth-configuration"
        let request = RestRequest.customUrlRequest(withMethod: .GET, baseURL: testBaseURL, path: testPathURL, queryParams: nil)

        RestClient.sharedGlobalInstance.send(request, failureBlock: { _, _, _ in
            XCTFail("Request failed")
        }, successBlock: { _, _ in
            getExpectation.fulfill()
        })

        let metricsExpectation = expectation(description: "metricsExpectation")
        Network.metricsCollectedAction = { session, task, metrics in
            XCTAssertNotNil(session)
            XCTAssertNotNil(task)
            XCTAssertNotNil(metrics)
            metricsExpectation.fulfill()
        }

        wait(for: [getExpectation, metricsExpectation], timeout: 30)
    }

    func testRequestUserAgent() {
        let network = Network.sharedEphemeralInstance()
        let request = URLRequest(url: URL(string: "https://www.salesforce.com")!)
        // sendRequest takes URLRequest by value (Swift value semantics) and applies the default
        // User-Agent to the copy it actually sends — unlike the ObjC original, which took an
        // NSMutableURLRequest and mutated the caller's instance in place. Observe the header on the
        // request the SDK actually dispatched via the returned task's originalRequest.
        let task = network.sendRequest(request, dataResponseBlock: nil)

        let userAgent = task.originalRequest?.allHTTPHeaderFields?["User-Agent"]
        let expectedUserAgent = SalesforceSDKManager.shared.userAgentString?("") ?? ""
        XCTAssertEqual(userAgent, expectedUserAgent, "User-Agent header should match SDK manager's user agent")
    }
}
