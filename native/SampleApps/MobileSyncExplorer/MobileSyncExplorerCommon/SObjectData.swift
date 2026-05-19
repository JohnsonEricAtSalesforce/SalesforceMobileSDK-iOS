/*
 Copyright (c) 2014-present, salesforce.com, inc. All rights reserved.

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

import Foundation
import SalesforceSDKCore

@objcMembers
class SObjectData: NSObject {
    var soupDict: [String: Any]

    override init() {
        self.soupDict = [:]
        super.init()
        initSoupValues(type(of: self).dataSpec().fieldNames)
        updateSoupForFieldName("attributes", fieldValue: ["type": type(of: self).dataSpec().objectType])
    }

    init(soupDict: [String: Any]) {
        self.soupDict = [:]
        super.init()
        initSoupValues(type(of: self).dataSpec().fieldNames)
        updateSoupForFieldName("attributes", fieldValue: ["type": type(of: self).dataSpec().objectType])
        if !soupDict.isEmpty {
            updateSoup(soupDict)
        }
    }

    func fieldValueForFieldName(_ fieldName: String) -> Any? {
        return nonNullFieldValue(fieldName)
    }

    func updateSoupForFieldName(_ fieldName: String, fieldValue: Any?) {
        var mutableSoup = soupDict
        mutableSoup[fieldName] = fieldValue ?? NSNull()
        soupDict = mutableSoup
    }

    class func dataSpec() -> SObjectDataSpec {
        fatalError("You must override dataSpec() in a subclass")
    }

    // MARK: - Internal

    func nonNullFieldValue(_ fieldName: String) -> Any? {
        let value = soupDict[fieldName]
        if value is NSNull {
            return nil
        }
        return value
    }

    override var description: String {
        return "<\(type(of: self)):\(Unmanaged.passUnretained(self).toOpaque())> \(soupDict)"
    }

    // MARK: - Private

    private func initSoupValues(_ fieldNames: [String]) {
        var mutableSoup = soupDict
        for fieldName in fieldNames {
            mutableSoup[fieldName] = NSNull()
        }
        soupDict = mutableSoup
    }

    private func updateSoup(_ soupDict: [String: Any]) {
        var mutableSoup = self.soupDict
        for (fieldName, fieldValue) in soupDict {
            mutableSoup[fieldName] = fieldValue
        }
        self.soupDict = mutableSoup
    }
}
