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

@objc(SFMobileSyncObjectUtils)
public class SFMobileSyncObjectUtils: FormatUtils {

    @objc
    public static func formatValue(_ value: Any?) -> String? {
        var processedValue: Any? = value

        if let value = value {
            if (value as? NSNull) != nil {
                processedValue = nil
            } else if let stringValue = value as? String, stringValue == "<null>" {
                processedValue = nil
            }
        }

        guard let finalValue = processedValue else {
            return ""
        }

        if let numberValue = finalValue as? NSNumber {
            return numberValue.stringValue
        } else if let stringValue = finalValue as? String {
            return stringValue
        } else if let obj = finalValue as? NSObject, obj.responds(to: #selector(getter: NSNumber.stringValue)) {
            return obj.perform(#selector(getter: NSNumber.stringValue))?.takeUnretainedValue() as? String
        }

        return nil
    }

    @objc
    public static func isEmpty(_ value: String?) -> Bool {
        guard let value = value else {
            return true
        }
        return value.trimmingCharacters(in: .whitespaces).isEmpty
    }
}
