/*
 SFDefaultLogger.swift
 SalesforceSDKCommon

 Created by Raj Rao on 10/4/18.

 Copyright (c) 2018-present, salesforce.com, inc. All rights reserved.

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
import os.log

/// Default logger implementation using Apple's os_log system.
@objc(SFDefaultLogger)
@objcMembers
public class SFDefaultLogger: NSObject, SFLogging {

    // MARK: - Constants

    private static let kLogIdentifierFormat = "CLASS: %@"

    // MARK: - SFLogging Properties

    public private(set) var componentName: String
    public var logLevel: SFLogLevel = .default
    public private(set) var logger: Any

    /// The underlying os_log_t instance.
    private var osLogger: OSLog

    // MARK: - Initializer

    public required init(component componentName: String) {
        self.componentName = componentName
        let appName = Bundle.main.bundleIdentifier ?? "com.salesforce.sdkcommon"
        self.osLogger = OSLog(subsystem: appName, category: componentName)
        self.logger = osLogger
        super.init()
    }

    // MARK: - SFLogging Methods

    /// Logs a log line of the specified level.
    public func log(_ cls: AnyClass, level: SFLogLevel, message: String) {
        let tag = String(format: SFDefaultLogger.kLogIdentifierFormat, NSStringFromClass(cls))
        os_log("%{public}s %{public}s", log: osLogger, type: OSLogType(rawValue: UInt8(level.rawValue)), tag, message)
    }

    /// Logs a log line of the specified level with format and variadic arguments.
    public func log(_ cls: AnyClass, level: SFLogLevel, format: String, args: CVaListPointer) {
        let formattedMessage = NSString(format: format, arguments: args) as String
        log(cls, level: level, message: formattedMessage)
    }
}
