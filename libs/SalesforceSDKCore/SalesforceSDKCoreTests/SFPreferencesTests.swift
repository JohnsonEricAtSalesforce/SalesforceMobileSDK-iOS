//
//  SFPreferencesTests.swift
//  SalesforceSDKCoreTests
//
//  Copyright (c) 2012-present, salesforce.com, inc. All rights reserved.
//
//  Redistribution and use of this software in source and binary forms, with or without modification,
//  are permitted provided that the following conditions are met:
//  * Redistributions of source code must retain the above copyright notice, this list of conditions
//  and the following disclaimer.
//  * Redistributions in binary form must reproduce the above copyright notice, this list of
//  conditions and the following disclaimer in the documentation and/or other materials provided
//  with the distribution.
//  * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
//  endorse or promote products derived from this software without specific prior written
//  permission of salesforce.com, inc.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
//  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
//  FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
//  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
//  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
//  WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import XCTest
@testable import SalesforceSDKCore

/// Class that tests the various scoped preferences
class SFPreferencesTests: XCTestCase {

    func testGlobalPreference() {
        let prefs = SFPreferences.globalPreferences()
        XCTAssertNotNil(prefs, "Preferences must exist")

        guard let basePath = SFDirectoryManager.shared.directory(forOrg: nil, user: nil, community: nil, type: .libraryDirectory, components: nil) else {
            XCTFail("Failed to get directory path")
            return
        }
        let expectedPath = (basePath as NSString).appendingPathComponent("Preferences.plist")
        XCTAssertEqual(prefs?.path, expectedPath, "Preferences path mismatch")

        // Make sure the same instance is returned each time
        XCTAssertTrue(prefs === SFPreferences.globalPreferences(), "Shared instance mismatch")
    }

    func testOrgLevelPreferences() {
        guard let credentials = OAuthCredentials.credentials(identifier: "happy-user", clientId: UserAccountManager.shared.oauthClientID, encrypted: true) else {
            XCTFail("Failed to create credentials")
            return
        }
        let user = UserAccount(credentials: credentials)

        XCTAssertTrue(UserAccountManager.shared.upsert(user), "Should be able to create user account")

        user.credentials.identityUrl = URL(string: "https://login.salesforce.com/id/00D000000000062EA0/005R0000000Dsl0")
        XCTAssertTrue(UserAccountManager.shared.upsert(user), "Should be able to update user account")
        UserAccountManager.shared.setCurrentUserInternal(user)

        let prefs = SFPreferences.currentOrgLevelPreferences()
        XCTAssertNotNil(prefs, "Preferences must exist")

        guard let basePath = SFDirectoryManager.shared.directory(forOrg: "00D000000000062EA0", user: nil, community: nil, type: .libraryDirectory, components: nil) else {
            XCTFail("Failed to get directory path")
            return
        }
        let expectedPath = (basePath as NSString).appendingPathComponent("Preferences.plist")
        XCTAssertEqual(prefs?.path, expectedPath, "Preferences path mismatch")

        // Make sure the same instance is returned each time
        XCTAssertTrue(prefs === SFPreferences.currentOrgLevelPreferences(), "Shared instance mismatch")

        // Check that the other scoped instances don't match
        XCTAssertFalse(prefs === SFPreferences.globalPreferences(), "Preferences instance should be different")
        _ = UserAccountManager.shared.delete(user)
    }

    func testUserLevelPreferences() {
        guard let credentials = OAuthCredentials.credentials(identifier: "happy-user", clientId: UserAccountManager.shared.oauthClientID, encrypted: true) else {
            XCTFail("Failed to create credentials")
            return
        }
        let user = UserAccount(credentials: credentials)
        user.credentials.identityUrl = URL(string: "https://login.salesforce.com/id/00D000000000062EA0/005R0000000Dsl0")

        XCTAssertTrue(UserAccountManager.shared.upsert(user), "Should be able to create user account")
        UserAccountManager.shared.setCurrentUserInternal(user)

        let prefs = SFPreferences.currentUserLevelPreferences()
        XCTAssertNotNil(prefs, "Preferences must exist")

        guard let basePath = SFDirectoryManager.shared.directory(forOrg: "00D000000000062EA0", user: "005R0000000Dsl0", community: nil, type: .libraryDirectory, components: nil) else {
            XCTFail("Failed to get directory path")
            return
        }
        let expectedPath = (basePath as NSString).appendingPathComponent("Preferences.plist")
        XCTAssertEqual(prefs?.path, expectedPath, "Preferences path mismatch")

        // Make sure the same instance is returned each time
        XCTAssertTrue(prefs === SFPreferences.currentUserLevelPreferences(), "Shared instance mismatch")

        // Check that the other scoped instances don't match
        XCTAssertFalse(prefs === SFPreferences.currentOrgLevelPreferences(), "Preferences instance should be different")
        XCTAssertFalse(prefs === SFPreferences.globalPreferences(), "Preferences instance should be different")
        _ = UserAccountManager.shared.delete(user)
    }

    func testCommunityLevelPreferences() {
        guard let credentials = OAuthCredentials.credentials(identifier: "happy-user", clientId: UserAccountManager.shared.oauthClientID, encrypted: true) else {
            XCTFail("Failed to create credentials")
            return
        }
        let user = UserAccount(credentials: credentials)
        user.credentials.identityUrl = URL(string: "https://login.salesforce.com/id/00D000000000062EA0/005R0000000Dsl0")

        XCTAssertTrue(UserAccountManager.shared.upsert(user), "Should be able to create user account")
        UserAccountManager.shared.setCurrentUserInternal(user)

        let prefs = SFPreferences.currentCommunityLevelPreferences()
        XCTAssertNotNil(prefs, "Preferences must exist")

        guard let basePath = SFDirectoryManager.shared.directory(forOrg: "00D000000000062EA0", user: "005R0000000Dsl0", community: nil, type: .libraryDirectory, components: nil) else {
            XCTFail("Failed to get directory path")
            return
        }
        var expectedPath = (basePath as NSString).appendingPathComponent("internal")
        expectedPath = (expectedPath as NSString).appendingPathComponent("Preferences.plist")
        XCTAssertEqual(prefs?.path, expectedPath, "Preferences path mismatch")

        // Make sure the same instance is returned each time
        XCTAssertTrue(prefs === SFPreferences.currentCommunityLevelPreferences(), "Shared instance mismatch")

        // Check that the other scoped instances don't match
        XCTAssertFalse(prefs === SFPreferences.currentUserLevelPreferences(), "Preferences instance should be different")
        XCTAssertFalse(prefs === SFPreferences.currentOrgLevelPreferences(), "Preferences instance should be different")
        XCTAssertFalse(prefs === SFPreferences.globalPreferences(), "Preferences instance should be different")
        _ = UserAccountManager.shared.delete(user)
    }
}
