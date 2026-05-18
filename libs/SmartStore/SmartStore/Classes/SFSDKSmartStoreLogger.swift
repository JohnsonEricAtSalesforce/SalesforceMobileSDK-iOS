/*
 SFSDKSmartStoreLogger.swift
 SmartStore

 Created by Bharath Hariharan on 6/26/17.

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

import Foundation
import SalesforceSDKCommon

// Top-level alias for backward compatibility
public let kSFSDKSmartStoreComponentName = SmartStoreLogger.kSFSDKSmartStoreComponentName

/// Component-specific logger. Forwards to SalesforceLogger for this component.
@objc(SFSDKSmartStoreLogger)
@objcMembers
public class SmartStoreLogger: NSObject {

    @objc public static let kSFSDKSmartStoreComponentName: String = "SmartStore"

    private static var logger: SalesforceLogger {
        return SalesforceLogger.logger(forComponent: kSFSDKSmartStoreComponentName)
    }

    // MARK: - Class Methods (message variants)

    /// Logs an error message.
    @objc(e:message:)
    public class func e(_ cls: AnyClass, message: String) {
        logger.e(cls, message: message)
    }

    /// Logs a warning message.
    @objc(w:message:)
    public class func w(_ cls: AnyClass, message: String) {
        logger.w(cls, message: message)
    }

    /// Logs an info message.
    @objc(i:message:)
    public class func i(_ cls: AnyClass, message: String) {
        logger.i(cls, message: message)
    }

    /// Logs a debug message.
    @objc(d:message:)
    public class func d(_ cls: AnyClass, message: String) {
        logger.d(cls, message: message)
    }

    /// Logs a fault message.
    @objc(f:message:)
    public class func f(_ cls: AnyClass, message: String) {
        logger.f(cls, message: message)
    }

    /// Logs a verbose/default message.
    @objc(v:message:)
    public class func v(_ cls: AnyClass, message: String) {
        SalesforceLogger.v(cls, message: message)
    }

    /// Logs a message at the specified level.
    @objc(log:level:message:)
    public class func log(_ cls: AnyClass, level: SFLogLevel, message: String) {
        logger.log(cls, level: level, message: message)
    }

    /// Sets the log level for the SmartStore component logger.
    @objc(setLogLevel:)
    public class func setLogLevel(_ level: SFLogLevel) {
        SalesforceLogger.setLogLevel(level)
    }

    /// Gets the current log level for the SmartStore component logger.
    @objc
    public class func logLevel() -> SFLogLevel {
        return SalesforceLogger.logLevel()
    }

    // MARK: - Instance Methods (for Swift callers using SmartStoreLogger().e(cls, message:) pattern)

    /// Logs an error message.
    @objc
    public func e(_ cls: AnyClass, message: String) {
        SmartStoreLogger.e(cls, message: message)
    }

    /// Logs a warning message.
    @objc
    public func w(_ cls: AnyClass, message: String) {
        SmartStoreLogger.w(cls, message: message)
    }

    /// Logs an info message.
    @objc
    public func i(_ cls: AnyClass, message: String) {
        SmartStoreLogger.i(cls, message: message)
    }

    /// Logs a debug message.
    @objc
    public func d(_ cls: AnyClass, message: String) {
        SmartStoreLogger.d(cls, message: message)
    }

    /// Logs a fault message.
    @objc
    public func f(_ cls: AnyClass, message: String) {
        SmartStoreLogger.f(cls, message: message)
    }

    /// Logs a verbose/default message.
    @objc
    public func v(_ cls: AnyClass, message: String) {
        SmartStoreLogger.v(cls, message: message)
    }

    /// Logs a message at the specified level.
    @objc
    public func log(_ cls: AnyClass, level: SFLogLevel, message: String) {
        SmartStoreLogger.log(cls, level: level, message: message)
    }
}
