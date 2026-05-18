/*
 SFSDKAnalyticsLogger.swift
 SalesforceAnalytics

 Created by Bharath Hariharan on 6/28/17.

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

/// Component name for the SalesforceAnalytics component.
public let kSFSDKAnalyticsComponentName: String = "SalesforceAnalytics"

/// Component-specific logger. Forwards to SalesforceLogger for this component.
@objc(SFSDKAnalyticsLogger)
@objcMembers
public class SFSDKAnalyticsLogger: NSObject {

    // MARK: - Private

    private class var logger: SalesforceLogger {
        return SalesforceLogger.logger(forComponent: kSFSDKAnalyticsComponentName)
    }

    // MARK: - Class Methods (format variants for Swift callers)

    public class func e(_ cls: AnyClass, format: String, _ args: CVarArg...) {
        let message = String(format: format, arguments: args)
        logger.e(cls, message: message)
    }

    public class func w(_ cls: AnyClass, format: String, _ args: CVarArg...) {
        let message = String(format: format, arguments: args)
        logger.w(cls, message: message)
    }

    public class func i(_ cls: AnyClass, format: String, _ args: CVarArg...) {
        let message = String(format: format, arguments: args)
        logger.i(cls, message: message)
    }

    public class func d(_ cls: AnyClass, format: String, _ args: CVarArg...) {
        let message = String(format: format, arguments: args)
        logger.d(cls, message: message)
    }

    public class func f(_ cls: AnyClass, format: String, _ args: CVarArg...) {
        let message = String(format: format, arguments: args)
        logger.f(cls, message: message)
    }

    public class func v(_ cls: AnyClass, format: String, _ args: CVarArg...) {
        let message = String(format: format, arguments: args)
        SalesforceLogger.v(cls, message: message)
    }

    public class func log(_ cls: AnyClass, level: SFLogLevel, format: String, _ args: CVarArg...) {
        let message = String(format: format, arguments: args)
        logger.log(cls, level: level, message: message)
    }

    // MARK: - Class Methods (message variants)

    @objc public class func e(_ cls: AnyClass, message: String) {
        logger.e(cls, message: message)
    }

    @objc public class func w(_ cls: AnyClass, message: String) {
        logger.w(cls, message: message)
    }

    @objc public class func i(_ cls: AnyClass, message: String) {
        logger.i(cls, message: message)
    }

    @objc public class func d(_ cls: AnyClass, message: String) {
        logger.d(cls, message: message)
    }

    @objc public class func f(_ cls: AnyClass, message: String) {
        logger.f(cls, message: message)
    }

    @objc public class func v(_ cls: AnyClass, message: String) {
        SalesforceLogger.v(cls, message: message)
    }

    @objc public class func log(_ cls: AnyClass, level: SFLogLevel, message: String) {
        logger.log(cls, level: level, message: message)
    }

    // MARK: - Instance Methods (for Swift callers using SFSDKAnalyticsLogger().e(cls, message:) pattern)

    @objc public func e(_ cls: AnyClass, message: String) {
        SFSDKAnalyticsLogger.e(cls, message: message)
    }

    @objc public func w(_ cls: AnyClass, message: String) {
        SFSDKAnalyticsLogger.w(cls, message: message)
    }

    @objc public func i(_ cls: AnyClass, message: String) {
        SFSDKAnalyticsLogger.i(cls, message: message)
    }

    @objc public func d(_ cls: AnyClass, message: String) {
        SFSDKAnalyticsLogger.d(cls, message: message)
    }

    @objc public func f(_ cls: AnyClass, message: String) {
        SFSDKAnalyticsLogger.f(cls, message: message)
    }

    @objc public func v(_ cls: AnyClass, message: String) {
        SFSDKAnalyticsLogger.v(cls, message: message)
    }

    @objc public func log(_ cls: AnyClass, level: SFLogLevel, message: String) {
        SFSDKAnalyticsLogger.log(cls, level: level, message: message)
    }
}
