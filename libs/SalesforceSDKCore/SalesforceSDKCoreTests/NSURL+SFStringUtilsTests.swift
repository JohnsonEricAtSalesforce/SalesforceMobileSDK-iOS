/*
 Copyright (c) 2012-present, salesforce.com, inc. All rights reserved.

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

final class NSURL_SFStringUtilsTests: XCTestCase {

    func testNoQueryString() {
        let inUrlString = "https://www.myserver.com/path.html"
        let url = URL(string: inUrlString)!
        let outUrlString = url.sfsdk_redactedAbsoluteString([])
        XCTAssertEqual(inUrlString, outUrlString,
                       "'\(inUrlString)' and '\(outUrlString)' should be the same, with no querystring.")
    }

    func testNoParams() {
        let inUrlString = "https://www.myserver.com/path?param1=val1&param2=val2"
        let url = URL(string: inUrlString)!
        let outUrlString = url.sfsdk_redactedAbsoluteString([])
        XCTAssertEqual(inUrlString, outUrlString,
                       "'\(inUrlString)' and '\(outUrlString)' should be the same, with no arguments.")
    }

    func testNoMatchingParams() {
        let inUrlString = "https://www.myserver.com/path?param1=val1&param2=val2"
        let url = URL(string: inUrlString)!
        let redactParams = ["param3", "param4"]
        let outUrlString = url.sfsdk_redactedAbsoluteString(redactParams)
        XCTAssertEqual(inUrlString, outUrlString,
                       "'\(inUrlString)' and '\(outUrlString)' should be the same, with no matching arguments.")
    }

    func testOneMatchingParam() {
        let inUrlString = "https://www.myserver.com/path?param1=val1&param2=val2"
        let url = URL(string: inUrlString)!
        let redactParams = ["param1"]
        let expectedOutUrlString = "https://www.myserver.com/path?param1=\(kSFRedactedQuerystringValue)&param2=val2"
        let actualOutUrlString = url.sfsdk_redactedAbsoluteString(redactParams)
        XCTAssertEqual(expectedOutUrlString, actualOutUrlString,
                       "'\(inUrlString)' should turn into '\(expectedOutUrlString)'. Got '\(actualOutUrlString)' instead.")
    }

    func testMultipleMatchingParams() {
        let inUrlString = "https://www.myserver.com/path?param1=val1&param2=val2"
        let url = URL(string: inUrlString)!
        let redactParams = ["param1", "param2"]
        let expectedOutUrlString = "https://www.myserver.com/path?param1=\(kSFRedactedQuerystringValue)&param2=\(kSFRedactedQuerystringValue)"
        let actualOutUrlString = url.sfsdk_redactedAbsoluteString(redactParams)
        XCTAssertEqual(expectedOutUrlString, actualOutUrlString,
                       "'\(inUrlString)' should turn into '\(expectedOutUrlString)'. Got '\(actualOutUrlString)' instead.")
    }
}
