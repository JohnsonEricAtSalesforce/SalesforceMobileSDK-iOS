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

    override func setUp() {
        super.setUp()
        existingMarkers = Set<String>()
        persistExistingMarkers()
        clearExistingMarkers()
    }

    override func tearDown() {
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

    // MARK: - Private helpers

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
