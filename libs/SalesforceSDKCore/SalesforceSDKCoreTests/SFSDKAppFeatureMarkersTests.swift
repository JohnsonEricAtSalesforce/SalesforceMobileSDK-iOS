/*
 Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.

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

class SFSDKAppFeatureMarkersTests: XCTestCase {

    private var existingMarkers = Set<String>()
    private var userA: UserAccount!
    private var userB: UserAccount!

    override func setUp() {
        super.setUp()
        existingMarkers = Set<String>()
        persistExistingMarkers()
        clearExistingMarkers()
        userA = fakeUser(orgId: "org1", userId: "user1", credentialsIdentifier: "test-creds-A")
        userB = fakeUser(orgId: "org2", userId: "user2", credentialsIdentifier: "test-creds-B")
    }

    override func tearDown() {
        SFSDKAppFeatureMarkers.unregisterAppFeature("XY", forUser: userA)
        SFSDKAppFeatureMarkers.unregisterAppFeature("XY", forUser: userB)
        SFSDKAppFeatureMarkers.unregisterAppFeature("GL", forUser: nil)
        SFSDKAppFeatureMarkers.unregisterAppFeature("PU", forUser: userA)
        SFSDKAppFeatureMarkers.unregisterAppFeature("NL", forUser: nil)
        SFSDKAppFeatureMarkers.unregisterAppFeature("RM", forUser: userA)
        SFSDKAppFeatureMarkers.unregisterAppFeature("HY", forUser: userA)
        SFSDKAppFeatureMarkers.unregisterAppFeature("PS", forUser: userA)
        SFSDKAppFeatureMarkers.unregisterAppFeature(kSFAppFeatureSafariBrowserForLogin, forUser: userA)
        SFSDKAppFeatureMarkers.unregisterAppFeature(kSFAppFeatureWelcomeDiscovery, forUser: userA)
        SFSDKAppFeatureMarkers.unregisterAppFeature(kSFAppFeatureQrCodeLogin, forUser: userA)
        userA = nil
        userB = nil
        clearExistingMarkers()
        resetPreviousMarkers()
        existingMarkers = Set<String>()
        super.tearDown()
    }

    func testNoDuplicates() {
        let someFeature = "BlahNoDuplicates"
        SFSDKAppFeatureMarkers.registerAppFeature(someFeature)
        XCTAssertEqual(SFSDKAppFeatureMarkers.appFeatures().count, 1, "Failed to add feature '\(someFeature)'")
        SFSDKAppFeatureMarkers.registerAppFeature(someFeature)
        XCTAssertEqual(SFSDKAppFeatureMarkers.appFeatures().count, 1, "Feature '\(someFeature)' should only exist once.")
    }

    func testAddAndRemove() {
        let someFeature = "BlahAddAndRemove"
        SFSDKAppFeatureMarkers.registerAppFeature(someFeature)
        XCTAssertEqual(SFSDKAppFeatureMarkers.appFeatures().count, 1, "Failed to add feature '\(someFeature)'")
        SFSDKAppFeatureMarkers.unregisterAppFeature(someFeature)
        XCTAssertEqual(SFSDKAppFeatureMarkers.appFeatures().count, 0, "Failed to unregister feature '\(someFeature)'")
    }

    func testUnregisterNonExistingNoError() {
        let someFeature = "BlahUnregisterNonExistingNoError"
        SFSDKAppFeatureMarkers.unregisterAppFeature(someFeature)
    }

    // MARK: - Per-user feature flag tests

    func test_givenTwoUsers_whenRegisterFeatureForUserA_thenOnlyUserAHasFlag() {
        SFSDKAppFeatureMarkers.registerAppFeature("XY", forUser: userA)

        XCTAssertTrue(SFSDKAppFeatureMarkers.appFeatures(forUser: userA).contains("XY"), "userA should have feature XY")
        XCTAssertFalse(SFSDKAppFeatureMarkers.appFeatures(forUser: userB).contains("XY"), "userB should NOT have feature XY")
        XCTAssertFalse(SFSDKAppFeatureMarkers.appFeatures().contains("XY"), "Global set should NOT contain per-user feature XY")
    }

    func test_givenGlobalAndPerUserFlags_whenAppFeaturesForUser_thenUnionReturned() {
        SFSDKAppFeatureMarkers.registerAppFeature("GL")
        SFSDKAppFeatureMarkers.registerAppFeature("PU", forUser: userA)

        let featuresForA = SFSDKAppFeatureMarkers.appFeatures(forUser: userA)
        XCTAssertTrue(featuresForA.contains("GL"), "appFeatures(forUser: userA) should include global feature GL")
        XCTAssertTrue(featuresForA.contains("PU"), "appFeatures(forUser: userA) should include per-user feature PU")

        let featuresForB = SFSDKAppFeatureMarkers.appFeatures(forUser: userB)
        XCTAssertTrue(featuresForB.contains("GL"), "appFeatures(forUser: userB) should include global feature GL")
        XCTAssertFalse(featuresForB.contains("PU"), "appFeatures(forUser: userB) should NOT include userA's per-user feature PU")
    }

    func test_givenNilUser_whenRegisterForUser_thenFlagGoesToGlobalSet() {
        SFSDKAppFeatureMarkers.registerAppFeature("NL", forUser: nil)

        XCTAssertTrue(SFSDKAppFeatureMarkers.appFeatures().contains("NL"), "Registering with nil user should fall back to global set")
    }

    func test_givenUserWithFlag_whenUnregisterForUser_thenFlagRemovedFromUser() {
        // Register RM only per-user for userA; do not add to global set
        SFSDKAppFeatureMarkers.registerAppFeature("RM", forUser: userA)
        XCTAssertTrue(SFSDKAppFeatureMarkers.appFeatures(forUser: userA).contains("RM"), "Feature RM should be present for userA before unregister")

        SFSDKAppFeatureMarkers.unregisterAppFeature("RM", forUser: userA)

        XCTAssertFalse(SFSDKAppFeatureMarkers.appFeatures(forUser: userA).contains("RM"), "Feature RM should be removed from userA after per-user unregister")
        XCTAssertFalse(SFSDKAppFeatureMarkers.appFeatures().contains("RM"), "Global set should not contain RM (it was never registered globally)")
    }

    func test_givenLoadPersistedFeatures_whenAppFeaturesForUser_thenFlagsPresent() {
        SFSDKAppFeatureMarkers.loadPersistedFeatures(["HY"], forUser: userA)

        XCTAssertTrue(SFSDKAppFeatureMarkers.appFeatures(forUser: userA).contains("HY"), "Hydrated feature HY should be visible via appFeatures(forUser:)")
        XCTAssertFalse(userA.persistedFeatureFlags?.contains("HY") ?? false, "loadPersistedFeatures should NOT write back to persistedFeatureFlags")
    }

    func test_givenPersistedFlagsOnUser_whenRegisterForUser_thenPersistedFlagsUpdated() {
        SFSDKAppFeatureMarkers.registerAppFeature("PS", forUser: userA)

        XCTAssertTrue(userA.persistedFeatureFlags?.contains("PS") ?? false, "registerAppFeature(_:forUser:) should save PS to user.persistedFeatureFlags")
    }

    func test_givenNilUser_whenAppFeaturesForUser_thenReturnsGlobalSet() {
        SFSDKAppFeatureMarkers.registerAppFeature("GL")
        SFSDKAppFeatureMarkers.registerAppFeature("PU", forUser: userA)

        let forNil = SFSDKAppFeatureMarkers.appFeatures(forUser: nil)
        let global = SFSDKAppFeatureMarkers.appFeatures()

        XCTAssertEqual(forNil, global, "appFeatures(forUser: nil) should be identical to appFeatures()")
        XCTAssertFalse(forNil.contains("PU"), "appFeatures(forUser: nil) should not include per-user features")
    }

    func test_givenPersistedFlagsOnUser_whenUnregisterForUser_thenPersistedFlagsUpdated() {
        SFSDKAppFeatureMarkers.registerAppFeature("RM", forUser: userA)
        XCTAssertTrue(userA.persistedFeatureFlags?.contains("RM") ?? false, "Precondition: RM should be in persistedFeatureFlags after register")

        SFSDKAppFeatureMarkers.unregisterAppFeature("RM", forUser: userA)

        XCTAssertFalse(userA.persistedFeatureFlags?.contains("RM") ?? false, "unregisterAppFeature(_:forUser:) should remove RM from user.persistedFeatureFlags")
    }

    // MARK: - Auth-completion promotion pattern tests

    func test_givenAdvancedBrowserAuth_whenPromoteBW_thenUserHasBWAndGlobalCleared() {
        // Simulates: authType == advancedBrowser path in auth completion
        SFSDKAppFeatureMarkers.registerAppFeature(kSFAppFeatureSafariBrowserForLogin)

        // Promotion sequence from auth completion
        SFSDKAppFeatureMarkers.registerAppFeature(kSFAppFeatureSafariBrowserForLogin, forUser: userA)
        SFSDKAppFeatureMarkers.unregisterAppFeature(kSFAppFeatureSafariBrowserForLogin)

        XCTAssertTrue(SFSDKAppFeatureMarkers.appFeatures(forUser: userA).contains(kSFAppFeatureSafariBrowserForLogin), "BW should be registered per-user after advanced browser auth")
        XCTAssertFalse(SFSDKAppFeatureMarkers.appFeatures().contains(kSFAppFeatureSafariBrowserForLogin), "BW should be cleared from global set after promotion")
    }

    func test_givenNonAdvancedBrowserAuth_whenPromoteBW_thenUserLacksBWAndGlobalCleared() {
        // Simulates: authType != advancedBrowser path in auth completion
        SFSDKAppFeatureMarkers.registerAppFeature(kSFAppFeatureSafariBrowserForLogin)

        // Promotion sequence from auth completion (non-advanced path)
        SFSDKAppFeatureMarkers.unregisterAppFeature(kSFAppFeatureSafariBrowserForLogin, forUser: userA)
        SFSDKAppFeatureMarkers.unregisterAppFeature(kSFAppFeatureSafariBrowserForLogin)

        XCTAssertFalse(SFSDKAppFeatureMarkers.appFeatures(forUser: userA).contains(kSFAppFeatureSafariBrowserForLogin), "BW should NOT be registered per-user after non-advanced auth")
        XCTAssertFalse(SFSDKAppFeatureMarkers.appFeatures().contains(kSFAppFeatureSafariBrowserForLogin), "BW should be cleared from global set regardless of auth type")
    }

    func test_givenGlobalWDSet_whenPromoteWD_thenUserHasWDAndGlobalCleared() {
        // Simulates: WelcomeDiscovery was used globally, authType != refresh
        SFSDKAppFeatureMarkers.registerAppFeature(kSFAppFeatureWelcomeDiscovery)

        // Promotion sequence from auth completion
        let usedWelcomeDiscovery = SFSDKAppFeatureMarkers.appFeatures().contains(kSFAppFeatureWelcomeDiscovery)
        XCTAssertTrue(usedWelcomeDiscovery, "Precondition: global WD should be set")

        SFSDKAppFeatureMarkers.registerAppFeature(kSFAppFeatureWelcomeDiscovery, forUser: userA)
        SFSDKAppFeatureMarkers.unregisterAppFeature(kSFAppFeatureWelcomeDiscovery)

        XCTAssertTrue(SFSDKAppFeatureMarkers.appFeatures(forUser: userA).contains(kSFAppFeatureWelcomeDiscovery), "WD should be promoted to per-user when global WD was set")
        XCTAssertFalse(SFSDKAppFeatureMarkers.appFeatures().contains(kSFAppFeatureWelcomeDiscovery), "WD should be cleared from global set after promotion")
    }

    func test_givenGlobalWDNotSet_whenPromoteWD_thenUserLacksWDAndGlobalCleared() {
        // Simulates: WelcomeDiscovery was NOT used globally, authType != refresh
        // Do NOT register WD globally

        // Promotion sequence from auth completion
        let usedWelcomeDiscovery = SFSDKAppFeatureMarkers.appFeatures().contains(kSFAppFeatureWelcomeDiscovery)
        XCTAssertFalse(usedWelcomeDiscovery, "Precondition: global WD should NOT be set")

        SFSDKAppFeatureMarkers.unregisterAppFeature(kSFAppFeatureWelcomeDiscovery, forUser: userA)
        SFSDKAppFeatureMarkers.unregisterAppFeature(kSFAppFeatureWelcomeDiscovery)

        XCTAssertFalse(SFSDKAppFeatureMarkers.appFeatures(forUser: userA).contains(kSFAppFeatureWelcomeDiscovery), "WD should NOT be per-user when global WD was not set")
        XCTAssertFalse(SFSDKAppFeatureMarkers.appFeatures().contains(kSFAppFeatureWelcomeDiscovery), "Global WD should remain absent")
    }

    func test_givenGlobalQRSet_whenPromoteQR_thenUserHasQRAndGlobalCleared() {
        // Simulates: QR login was used globally, authType != refresh
        SFSDKAppFeatureMarkers.registerAppFeature(kSFAppFeatureQrCodeLogin)

        // Promotion sequence from auth completion
        let usedQrLogin = SFSDKAppFeatureMarkers.appFeatures().contains(kSFAppFeatureQrCodeLogin)
        XCTAssertTrue(usedQrLogin, "Precondition: global QR should be set")

        SFSDKAppFeatureMarkers.registerAppFeature(kSFAppFeatureQrCodeLogin, forUser: userA)
        SFSDKAppFeatureMarkers.unregisterAppFeature(kSFAppFeatureQrCodeLogin)

        XCTAssertTrue(SFSDKAppFeatureMarkers.appFeatures(forUser: userA).contains(kSFAppFeatureQrCodeLogin), "QR should be promoted to per-user when global QR was set")
        XCTAssertFalse(SFSDKAppFeatureMarkers.appFeatures().contains(kSFAppFeatureQrCodeLogin), "QR should be cleared from global set after promotion")
    }

    func test_givenGlobalQRNotSet_whenPromoteQR_thenUserLacksQR() {
        // Simulates: QR login was NOT used globally, authType != refresh
        // Do NOT register QR globally

        // Promotion sequence from auth completion
        let usedQrLogin = SFSDKAppFeatureMarkers.appFeatures().contains(kSFAppFeatureQrCodeLogin)
        XCTAssertFalse(usedQrLogin, "Precondition: global QR should NOT be set")

        SFSDKAppFeatureMarkers.unregisterAppFeature(kSFAppFeatureQrCodeLogin, forUser: userA)

        XCTAssertFalse(SFSDKAppFeatureMarkers.appFeatures(forUser: userA).contains(kSFAppFeatureQrCodeLogin), "QR should NOT be per-user when global QR was not set")
    }

    // MARK: - Private helpers

    private func fakeUser(orgId: String, userId: String, credentialsIdentifier identifier: String) -> UserAccount {
        let credentials = OAuthCredentials.credentials(identifier: identifier, clientId: "fakeClientIdForTesting", encrypted: false)!
        credentials.organizationId = orgId
        credentials.userId = userId
        return UserAccount(credentials: credentials)
    }

    private func persistExistingMarkers() {
        for marker in SFSDKAppFeatureMarkers.appFeatures() {
            existingMarkers.insert(marker)
        }
    }

    private func resetPreviousMarkers() {
        for marker in existingMarkers {
            SFSDKAppFeatureMarkers.registerAppFeature(marker)
        }
        XCTAssertEqual(SFSDKAppFeatureMarkers.appFeatures().count, existingMarkers.count, "Failed to re-register previous markers.")
    }

    private func clearExistingMarkers() {
        for marker in SFSDKAppFeatureMarkers.appFeatures() {
            SFSDKAppFeatureMarkers.unregisterAppFeature(marker)
        }
        XCTAssertEqual(SFSDKAppFeatureMarkers.appFeatures().count, 0, "Failed to clear app feature markers.")
    }
}
