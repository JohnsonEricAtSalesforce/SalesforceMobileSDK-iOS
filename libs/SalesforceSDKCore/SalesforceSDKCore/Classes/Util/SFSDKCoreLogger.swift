// Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.
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
import SalesforceSDKCommon

public let kSFSDKCoreComponentName: String = "SalesforceSDKCore"

/// Component-specific logger. Forwards to SalesforceLogger for this component.
@objc(SFSDKCoreLogger)
@objcMembers public class SFSDKCoreLogger: NSObject {

    private class func logger() -> SalesforceLogger {
        return SalesforceLogger.logger(forComponent: kSFSDKCoreComponentName)
    }

    // MARK: - Swift-only variadic format: methods (not exported to ObjC)

    public class func e(_ cls: AnyClass, format: String, _ args: CVarArg...) {
        e(cls, message: String(format: format, arguments: args))
    }

    public class func w(_ cls: AnyClass, format: String, _ args: CVarArg...) {
        w(cls, message: String(format: format, arguments: args))
    }

    public class func i(_ cls: AnyClass, format: String, _ args: CVarArg...) {
        i(cls, message: String(format: format, arguments: args))
    }

    public class func d(_ cls: AnyClass, format: String, _ args: CVarArg...) {
        d(cls, message: String(format: format, arguments: args))
    }

    public class func f(_ cls: AnyClass, format: String, _ args: CVarArg...) {
        f(cls, message: String(format: format, arguments: args))
    }

    public class func v(_ cls: AnyClass, format: String, _ args: CVarArg...) {
        v(cls, message: String(format: format, arguments: args))
    }

    public class func log(_ cls: AnyClass, level: SFLogLevel, format: String, _ args: CVarArg...) {
        log(cls, level: level, message: String(format: format, arguments: args))
    }

    // MARK: - Class message: methods

    @objc public class func e(_ cls: AnyClass, message: String) {
        logger().e(cls, message: message)
    }

    @objc public class func w(_ cls: AnyClass, message: String) {
        logger().w(cls, message: message)
    }

    @objc public class func i(_ cls: AnyClass, message: String) {
        logger().i(cls, message: message)
    }

    @objc public class func d(_ cls: AnyClass, message: String) {
        logger().d(cls, message: message)
    }

    @objc public class func f(_ cls: AnyClass, message: String) {
        logger().f(cls, message: message)
    }

    @objc public class func v(_ cls: AnyClass, message: String) {
        SalesforceLogger.v(cls, message: message)
    }

    @objc public class func log(_ cls: AnyClass, level: SFLogLevel, message: String) {
        logger().log(cls, level: level, message: message)
    }

    // MARK: - Instance message: methods

    @objc public func e(_ cls: AnyClass, message: String) {
        SFSDKCoreLogger.e(cls, message: message)
    }

    @objc public func w(_ cls: AnyClass, message: String) {
        SFSDKCoreLogger.w(cls, message: message)
    }

    @objc public func i(_ cls: AnyClass, message: String) {
        SFSDKCoreLogger.i(cls, message: message)
    }

    @objc public func d(_ cls: AnyClass, message: String) {
        SFSDKCoreLogger.d(cls, message: message)
    }

    @objc public func f(_ cls: AnyClass, message: String) {
        SFSDKCoreLogger.f(cls, message: message)
    }

    @objc public func v(_ cls: AnyClass, message: String) {
        SFSDKCoreLogger.v(cls, message: message)
    }

    @objc public func log(_ cls: AnyClass, level: SFLogLevel, message: String) {
        SFSDKCoreLogger.log(cls, level: level, message: message)
    }
}
