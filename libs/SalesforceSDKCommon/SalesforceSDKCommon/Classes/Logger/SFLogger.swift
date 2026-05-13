/*
 SFLogger.swift
 SFLogger

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

@objc
public enum SFLogLevel: UInt, RawRepresentable {
    case `default` = 0x00  // OS_LOG_TYPE_DEFAULT
    case info      = 0x01  // OS_LOG_TYPE_INFO
    case debug     = 0x02  // OS_LOG_TYPE_DEBUG
    case error     = 0x10  // OS_LOG_TYPE_ERROR
    case fault     = 0x11  // OS_LOG_TYPE_FAULT
}

@objc(SFLogging)
public protocol SFLogging: NSObjectProtocol {
    /// Component name associated with this logger.
    var componentName: String { get }

    /// Instance of the underlying logger implementation being used.
    var logger: Any { get }

    /// Used to get and set the current log level associated with this logger.
    var logLevel: SFLogLevel { get set }

    /// Initialize a logger given component Name.
    /// - Returns: Instance of this class.
    init(component componentName: String)

    /// Logs a log line of the specified level.
    /// - Parameters:
    ///   - cls: Class.
    ///   - level: Log level.
    ///   - message: Log message.
    func log(_ cls: AnyClass, level: SFLogLevel, message: String)

    /// Note: The variadic log method with CVaListPointer cannot be part of @objc protocol
    /// Implementations may provide this method separately if needed.

    @objc optional static func sharedInstance(withComponent componentName: String) -> Self
}

private let kDefaultComponentName = "SFSDK"

private var instanceClass: SFLogging.Type = SFDefaultLogger.self
private var logReceiverFactory: SalesforceLogReceiverFactory?
private var loggerList: SFSDKSafeMutableDictionary<NSString, SFLogger>?

@objc(SFLogger)
@objcMembers
open class SFLogger: NSObject {

    private var loggerInstance: SFLogging
    private var logReceiver: SalesforceLogReceiver?

    private static let loggerListLock = NSLock()

    // MARK: - Initialization

    private init(component componentName: String, logReceiver: SalesforceLogReceiver?) {
        // Always use the required initializer from the protocol
        self.loggerInstance = instanceClass.init(component: componentName)
        self.logReceiver = logReceiver
        super.init()
    }

    /// Sets log level to be used by this logger.
    @objc
    public var level: SFLogLevel {
        get {
            return loggerInstance.logLevel
        }
        set {
            loggerInstance.logLevel = newValue
        }
    }

    // MARK: - Instance Methods

    private func submitLogEntry(cls: AnyClass, level: SFLogLevel, message: String) {
        loggerInstance.log(cls, level: level, message: message)
        logReceiver?.receive(level: level, cls: cls, component: loggerInstance.componentName, message: message)
    }

    private func submitLogEntry(cls: AnyClass, level: SFLogLevel, format: String, args: CVaListPointer) {
        // Format the message and use the standard log method
        let formattedMessage = NSString(format: format, arguments: args) as String
        loggerInstance.log(cls, level: level, message: formattedMessage)
        logReceiver?.receive(level: level, cls: cls, component: loggerInstance.componentName, message: formattedMessage)
    }

    @objc
    public func log(_ cls: AnyClass, message: String) {
        submitLogEntry(cls: cls, level: .default, message: message)
    }

    // Not @objc - variadic parameters not supported in Objective-C
    public func log(_ cls: AnyClass, format: String, _ args: CVarArg...) {
        withVaList(args) { argsPointer in
            submitLogEntry(cls: cls, level: .default, format: format, args: argsPointer)
        }
    }

    @objc
    public func log(_ cls: AnyClass, level: SFLogLevel, message: String) {
        submitLogEntry(cls: cls, level: level, message: message)
    }

    // Not @objc - variadic parameters not supported in Objective-C
    public func log(_ cls: AnyClass, level: SFLogLevel, format: String, _ args: CVarArg...) {
        withVaList(args) { argsPointer in
            submitLogEntry(cls: cls, level: level, format: format, args: argsPointer)
        }
    }

    // Not @objc - CVaListPointer not representable in Objective-C
    public func log(_ cls: AnyClass, level: SFLogLevel, format: String, args: CVaListPointer) {
        submitLogEntry(cls: cls, level: level, format: format, args: args)
    }

    @objc
    public func e(_ cls: AnyClass, message: String) {
        submitLogEntry(cls: cls, level: .error, message: message)
    }

    // Not @objc - variadic parameters not supported in Objective-C
    public func e(_ cls: AnyClass, format: String, _ args: CVarArg...) {
        withVaList(args) { argsPointer in
            submitLogEntry(cls: cls, level: .error, format: format, args: argsPointer)
        }
    }

    @objc
    public func f(_ cls: AnyClass, message: String) {
        submitLogEntry(cls: cls, level: .fault, message: message)
    }

    // Not @objc - variadic parameters not supported in Objective-C
    public func f(_ cls: AnyClass, format: String, _ args: CVarArg...) {
        withVaList(args) { argsPointer in
            submitLogEntry(cls: cls, level: .fault, format: format, args: argsPointer)
        }
    }

    @objc
    public func i(_ cls: AnyClass, message: String) {
        submitLogEntry(cls: cls, level: .info, message: message)
    }

    // Not @objc - variadic parameters not supported in Objective-C
    public func i(_ cls: AnyClass, format: String, _ args: CVarArg...) {
        withVaList(args) { argsPointer in
            submitLogEntry(cls: cls, level: .info, format: format, args: argsPointer)
        }
    }

    @objc
    public func d(_ cls: AnyClass, message: String) {
        submitLogEntry(cls: cls, level: .debug, message: message)
    }

    // Not @objc - variadic parameters not supported in Objective-C
    public func d(_ cls: AnyClass, format: String, _ args: CVarArg...) {
        withVaList(args) { argsPointer in
            submitLogEntry(cls: cls, level: .debug, format: format, args: argsPointer)
        }
    }

    @objc
    public func w(_ cls: AnyClass, message: String) {
        submitLogEntry(cls: cls, level: .default, message: message)
    }

    // Not @objc - variadic parameters not supported in Objective-C
    public func w(_ cls: AnyClass, format: String, _ args: CVarArg...) {
        withVaList(args) { argsPointer in
            submitLogEntry(cls: cls, level: .default, format: format, args: argsPointer)
        }
    }

    // MARK: - Class Methods

    @objc
    public static var logLevel: SFLogLevel {
        get {
            return defaultLogger.level
        }
        set {
            defaultLogger.level = newValue
        }
    }

    @objc(setLogLevelWithLevel:)
    public class func setLogLevel(_ logLevel: SFLogLevel) {
        self.logLevel = logLevel
    }

    @objc
    public static var defaultLogger: SFLogger {
        return logger(forComponent: kDefaultComponentName)
    }

    @objc(loggerForComponent:)
    public static func logger(forComponent componentName: String) -> SFLogger {
        loggerListLock.lock()
        defer { loggerListLock.unlock() }

        if loggerList == nil {
            loggerList = SFSDKSafeMutableDictionary<NSString, SFLogger>()
        }

        guard !componentName.isEmpty else {
            return SFLogger(component: kDefaultComponentName, logReceiver: nil)
        }

        if let logger = loggerList?[componentName as NSString] {
            return logger
        }

        var logReceiver: SalesforceLogReceiver?
        if let factory = logReceiverFactory {
            logReceiver = factory.create(componentName: componentName)
        }

        let logger = SFLogger(component: componentName, logReceiver: logReceiver)
        loggerList?[componentName as NSString] = logger

        return logger
    }

    @objc
    public static func setInstanceClass(_ loggerClass: SFLogging.Type) {
        instanceClass = loggerClass
    }

    @objc
    public static func setLogReceiverFactory(_ factory: SalesforceLogReceiverFactory?) {
        logReceiverFactory = factory
    }

    @objc
    internal static func clearAllComponents() {
        loggerList?.removeAllObjects()
    }

    // MARK: - Static Logging Methods

    // Not @objc - variadic parameters not supported in Objective-C
    public static func e(_ cls: AnyClass, format: String, _ args: CVarArg...) {
        withVaList(args) { argsPointer in
            defaultLogger.log(cls, level: .error, format: format, args: argsPointer)
        }
    }

    @objc
    public static func e(_ cls: AnyClass, message: String) {
        defaultLogger.e(cls, message: message)
    }

    // Not @objc - variadic parameters not supported in Objective-C
    public static func d(_ cls: AnyClass, format: String, _ args: CVarArg...) {
        withVaList(args) { argsPointer in
            defaultLogger.log(cls, level: .debug, format: format, args: argsPointer)
        }
    }

    @objc
    public static func d(_ cls: AnyClass, message: String) {
        defaultLogger.d(cls, message: message)
    }

    // Not @objc - variadic parameters not supported in Objective-C
    public static func w(_ cls: AnyClass, format: String, _ args: CVarArg...) {
        withVaList(args) { argsPointer in
            defaultLogger.log(cls, level: .default, format: format, args: argsPointer)
        }
    }

    @objc
    public static func w(_ cls: AnyClass, message: String) {
        defaultLogger.log(cls, message: message)
    }

    // Not @objc - variadic parameters not supported in Objective-C
    public static func i(_ cls: AnyClass, format: String, _ args: CVarArg...) {
        withVaList(args) { argsPointer in
            defaultLogger.log(cls, level: .info, format: format, args: argsPointer)
        }
    }

    @objc
    public static func i(_ cls: AnyClass, message: String) {
        defaultLogger.i(cls, message: message)
    }

    // Not @objc - variadic parameters not supported in Objective-C
    public static func f(_ cls: AnyClass, format: String, _ args: CVarArg...) {
        withVaList(args) { argsPointer in
            defaultLogger.log(cls, level: .fault, format: format, args: argsPointer)
        }
    }

    @objc
    public static func f(_ cls: AnyClass, message: String) {
        defaultLogger.f(cls, message: message)
    }

    // Not @objc - variadic parameters not supported in Objective-C
    public static func v(_ cls: AnyClass, format: String, _ args: CVarArg...) {
        withVaList(args) { argsPointer in
            defaultLogger.log(cls, level: .default, format: format, args: argsPointer)
        }
    }

    @objc
    public static func v(_ cls: AnyClass, message: String) {
        defaultLogger.log(cls, level: .default, message: message)
    }

    @objc
    public static func log(_ cls: AnyClass, message: String) {
        defaultLogger.log(cls, message: message)
    }

    // Not @objc - variadic parameters not supported in Objective-C
    public static func log(_ cls: AnyClass, format: String, _ args: CVarArg...) {
        withVaList(args) { argsPointer in
            defaultLogger.log(cls, level: .default, format: format, args: argsPointer)
        }
    }

    @objc
    public static func log(_ cls: AnyClass, level: SFLogLevel, message: String) {
        defaultLogger.log(cls, level: level, message: message)
    }

    // Not @objc - variadic parameters not supported in Objective-C
    public static func log(_ cls: AnyClass, level: SFLogLevel, format: String, _ args: CVarArg...) {
        withVaList(args) { argsPointer in
            defaultLogger.log(cls, level: .default, format: format, args: argsPointer)
        }
    }
}
