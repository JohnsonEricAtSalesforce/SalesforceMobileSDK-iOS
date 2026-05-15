/*
 Copyright (c) 2016-present, salesforce.com, inc. All rights reserved.

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

final class SFSDKLoginHostTestsSwift: XCTestCase {

    private let productionUrl = "login.salesforce.com"
    private let sandboxUrl = "test.salesforce.com"
    private let doesNotExistUrl = "doesnotexist.salesforce.com"
    private let customName = "New"
    private let customUrl = "https://new.com"
    private let customName2 = "New2"
    private let customUrl2 = "https://new2.com"

    override func tearDown() {
        let loginHostStorage = SFSDKLoginHostStorage.shared
        loginHostStorage.removeAllLoginHosts()
        super.tearDown()
    }

    func testLoginHost() {
        let name = "dummyname"
        let host = "dummyhost"
        let deletable = true

        var loginHost = SFSDKLoginHost.host(withName: name, host: host, deletable: deletable)
        XCTAssertEqual(host, loginHost.host, "\(host) Should be equal to \(loginHost.host)")
        XCTAssertEqual(name, loginHost.name, "\(name) Should be equal to \(loginHost.name)")
        XCTAssertEqual(deletable, loginHost.isDeletable, "deletable values should match")

        // Only testing name to be nil as host can never be nil and deletable will always have a YES or NO value
        loginHost = SFSDKLoginHost.host(withName: nil, host: host, deletable: deletable)
        XCTAssertNotNil(loginHost.name, "Name should not be nil")
    }

    func testSetupNavigationBar() {
        let loginViewController = SFLoginViewController()
        // Test default values
        XCTAssertNotNil(loginViewController.navigationBarColor, "Nav bar color should not be nil")
        XCTAssertNotNil(loginViewController.navigationBarTintColor, "Nav bar tint color should not be nil")
        XCTAssertNil(loginViewController.navigationBarFont, "Nav bar font should be nil")
        XCTAssertTrue(loginViewController.showsNavigationBar, "Show Nav bar should be set to yes by default")
        XCTAssertTrue(loginViewController.showsSettingsIcon, "Show Settings Icon should be set to yes by default")
    }

    func testGetLoginHosts() {
        let loginHostStorage = SFSDKLoginHostStorage.shared

        var loginHost = loginHostStorage.loginHost(forHostAddress: productionUrl)
        XCTAssertEqual("Production", loginHost?.name)
        XCTAssertEqual(productionUrl, loginHost?.host)

        loginHost = loginHostStorage.loginHost(forHostAddress: sandboxUrl)
        XCTAssertEqual("Sandbox", loginHost?.name)
        XCTAssertEqual(sandboxUrl, loginHost?.host)

        loginHost = loginHostStorage.loginHost(forHostAddress: doesNotExistUrl)
        XCTAssertNil(loginHost, "Login host should be nil")
    }

    func testAddCustomServer() {
        let loginHostStorage = SFSDKLoginHostStorage.shared
        var loginHost = loginHostStorage.loginHost(forHostAddress: productionUrl)

        XCTAssertEqual("Production", loginHost?.name)
        XCTAssertEqual(productionUrl, loginHost?.host)

        loginHostStorage.add(SFSDKLoginHost.host(withName: customName, host: customUrl, deletable: true))
        loginHost = loginHostStorage.loginHost(forHostAddress: customUrl)

        XCTAssertEqual(customName, loginHost?.name)
        XCTAssertEqual(customUrl, loginHost?.host)
    }

    func testAddMultipleCustomServers() {
        let loginHostStorage = SFSDKLoginHostStorage.shared
        XCTAssertEqual(2, loginHostStorage.numberOfLoginHosts(), "Number of login hosts should be equal to 2")

        loginHostStorage.add(SFSDKLoginHost.host(withName: customName, host: customUrl, deletable: true))
        var loginHost = loginHostStorage.loginHost(forHostAddress: customUrl)
        XCTAssertEqual(3, loginHostStorage.numberOfLoginHosts(), "Number of login hosts should be equal to 3")
        XCTAssertEqual(customName, loginHost?.name)
        XCTAssertEqual(customUrl, loginHost?.host)

        loginHostStorage.add(SFSDKLoginHost.host(withName: customName2, host: customUrl2, deletable: true))
        loginHost = loginHostStorage.loginHost(forHostAddress: customUrl2)
        XCTAssertEqual(4, loginHostStorage.numberOfLoginHosts(), "Number of login hosts should be equal to 4")
        XCTAssertEqual(customName2, loginHost?.name)
        XCTAssertEqual(customUrl2, loginHost?.host)
    }

    func testLoginHostListViewControllerCreatesUniqueInstances() {
        let loginViewController = SFLoginViewController()

        let instance1 = loginViewController.createLoginHostListViewController()
        let instance2 = loginViewController.createLoginHostListViewController()
        let instance3 = loginViewController.createLoginHostListViewController()

        XCTAssertNotNil(instance1, "First instance should not be nil")
        XCTAssertNotNil(instance2, "Second instance should not be nil")
        XCTAssertNotNil(instance3, "Third instance should not be nil")

        XCTAssertFalse(instance1 === instance2, "First and second instances should be different objects")
        XCTAssertFalse(instance2 === instance3, "Second and third instances should be different objects")
        XCTAssertFalse(instance1 === instance3, "First and third instances should be different objects")

        XCTAssertNotNil(instance1.config, "First instance should have config")
        XCTAssertNotNil(instance2.config, "Second instance should have config")
        XCTAssertNotNil(instance3.config, "Third instance should have config")

        XCTAssertTrue(instance1.delegate === loginViewController, "First instance delegate should be set to loginViewController")
        XCTAssertTrue(instance2.delegate === loginViewController, "Second instance delegate should be set to loginViewController")
        XCTAssertTrue(instance3.delegate === loginViewController, "Third instance delegate should be set to loginViewController")
    }
}
