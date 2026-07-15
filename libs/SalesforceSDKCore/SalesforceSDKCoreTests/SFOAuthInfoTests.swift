/*
 Copyright (c) 2025-present, salesforce.com, inc. All rights reserved.

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

class SFOAuthInfoTests: XCTestCase {

    func testAuthTypeDescription() {
        // Test SFOAuthTypeUnknown
        let unknownInfo = SFOAuthInfo(authType: .unknown)
        XCTAssertEqual(unknownInfo.authTypeDescription, "SFOAuthTypeUnknown", "Unknown auth type should return correct description")
        XCTAssertEqual(unknownInfo.authType, .unknown, "Auth type should be Unknown")

        // Test SFOAuthTypeUserAgent
        let userAgentInfo = SFOAuthInfo(authType: .userAgent)
        XCTAssertEqual(userAgentInfo.authTypeDescription, "SFOAuthTypeUserAgent", "UserAgent auth type should return correct description")
        XCTAssertEqual(userAgentInfo.authType, .userAgent, "Auth type should be UserAgent")

        // Test SFOAuthTypeWebServer
        let webServerInfo = SFOAuthInfo(authType: .webServer)
        XCTAssertEqual(webServerInfo.authTypeDescription, "SFOAuthTypeWebServer", "WebServer auth type should return correct description")
        XCTAssertEqual(webServerInfo.authType, .webServer, "Auth type should be WebServer")

        // Test SFOAuthTypeRefresh
        let refreshInfo = SFOAuthInfo(authType: .refresh)
        XCTAssertEqual(refreshInfo.authTypeDescription, "SFOAuthTypeRefresh", "Refresh auth type should return correct description")
        XCTAssertEqual(refreshInfo.authType, .refresh, "Auth type should be Refresh")

        // Test SFOAuthTypeAdvancedBrowser
        let advancedBrowserInfo = SFOAuthInfo(authType: .advancedBrowser)
        XCTAssertEqual(advancedBrowserInfo.authTypeDescription, "SFOAuthTypeAdvancedBrowser", "AdvancedBrowser auth type should return correct description")
        XCTAssertEqual(advancedBrowserInfo.authType, .advancedBrowser, "Auth type should be AdvancedBrowser")

        // Test SFOAuthTypeJwtTokenExchange
        let jwtInfo = SFOAuthInfo(authType: .jwtTokenExchange)
        XCTAssertEqual(jwtInfo.authTypeDescription, "SFOAuthTypeJwtTokenExchange", "JwtTokenExchange auth type should return correct description")
        XCTAssertEqual(jwtInfo.authType, .jwtTokenExchange, "Auth type should be JwtTokenExchange")

        // Test SFOAuthTypeIDP — production returns "SFOAuthTypeIDP" (all-caps IDP), matching the ObjC
        // original (SFOAuthInfo.m: desc = @"SFOAuthTypeIDP"). This is a public-observable string, so the
        // test expectation is corrected to the canonical casing rather than changing production.
        let idpInfo = SFOAuthInfo(authType: .idp)
        XCTAssertEqual(idpInfo.authTypeDescription, "SFOAuthTypeIDP", "IDP auth type should return correct description")
        XCTAssertEqual(idpInfo.authType, .idp, "Auth type should be IDP")

        // Test SFOAuthTypeNative
        let nativeInfo = SFOAuthInfo(authType: .native)
        XCTAssertEqual(nativeInfo.authTypeDescription, "SFOAuthTypeNative", "Native auth type should return correct description")
        XCTAssertEqual(nativeInfo.authType, .native, "Auth type should be Native")

        // Test SFOAuthTypeRefreshTokenMigration
        let migrationInfo = SFOAuthInfo(authType: .refreshTokenMigration)
        XCTAssertEqual(migrationInfo.authTypeDescription, "SFOAuthTypeRefreshTokenMigration", "RefreshTokenMigration auth type should return correct description")
        XCTAssertEqual(migrationInfo.authType, .refreshTokenMigration, "Auth type should be RefreshTokenMigration")
    }

    func testDescription() {
        // Test that description includes authTypeDescription
        let info = SFOAuthInfo(authType: .refresh)
        let description = info.description

        XCTAssertNotNil(description, "Description should not be nil")
        XCTAssertTrue(description.contains("SFOAuthInfo"), "Description should contain class name")
        XCTAssertTrue(description.contains("authType="), "Description should contain authType label")
        XCTAssertTrue(description.contains("SFOAuthTypeRefresh"), "Description should contain auth type description")
    }
}
