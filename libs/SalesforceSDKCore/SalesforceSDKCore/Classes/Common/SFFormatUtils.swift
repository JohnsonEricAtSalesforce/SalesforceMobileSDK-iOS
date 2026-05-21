// SFFormatUtils.swift
//
// Copyright (c) 2020-present, salesforce.com, inc. All rights reserved.
//
// Redistribution and use of this software in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
// * Redistributions of source code must retain the above copyright notice, this list of conditions
// and the following disclaimer.
// * Redistributions in binary form must reproduce the above copyright notice, this list of
// conditions and the following disclaimer in the documentation and/or other materials provided
// with the distribution.
// * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
// endorse or promote products derived from this software without specific prior written
// permission of salesforce.com, inc.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
// IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
// FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
// CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
// WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
// WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import Foundation

/// Date formatting utilities for Salesforce SDK.
@objc(SFFormatUtils)
@objcMembers
open class FormatUtils: NSObject {

    private static let utcDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        return formatter
    }()

    private static let isoDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        // See https://developer.apple.com/documentation/foundation/nsdateformatter
        // and https://developer.apple.com/library/archive/qa/qa1480/_index.html
        let enUSPOSIXLocale = Locale(identifier: "en_US_POSIX")
        formatter.locale = enUSPOSIXLocale
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        return formatter
    }()

    @objc public static func formatLocalDate(toGMTString localDate: Date) -> String? {
        return utcDateFormatter.string(from: localDate)
    }

    @objc public static func getMillis(fromIsoString dateStr: String) -> Int64 {
        guard (dateStr as NSObject) is NSString else { return -1 }
        guard let date = isoDateFormatter.date(from: dateStr) else { return -1 }
        return Int64(date.timeIntervalSince1970 * 1000.0)
    }

    @objc public static func getIsoString(fromMillis millis: Int64) -> String? {
        guard millis >= 0 else { return nil }
        let date = Date(timeIntervalSince1970: Double(millis) / 1000.0)
        return isoDateFormatter.string(from: date)
    }

    @objc public static func getDate(fromIsoDateString isoDateString: String?) -> Date? {
        guard let isoDateString = isoDateString, !isoDateString.isEmpty else { return nil }
        return isoDateFormatter.date(from: isoDateString)
    }

    @objc public static func getIsoString(from date: Date) -> String? {
        return isoDateFormatter.string(from: date)
    }
}
