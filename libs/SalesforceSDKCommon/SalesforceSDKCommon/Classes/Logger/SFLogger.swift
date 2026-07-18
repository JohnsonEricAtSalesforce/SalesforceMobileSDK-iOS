/*
 SFLogger.swift
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

// MARK: - SFLogLevel Enum

/// Log level enum bridged to os_log types.
@objc public enum SFLogLevel: UInt {
    case `default` = 0x00  // OS_LOG_TYPE_DEFAULT
    case info      = 0x01  // OS_LOG_TYPE_INFO
    case debug     = 0x02  // OS_LOG_TYPE_DEBUG
    case error     = 0x10  // OS_LOG_TYPE_ERROR
    case fault     = 0x11  // OS_LOG_TYPE_FAULT
}

// MARK: - SFLogging Protocol

/// Protocol for logger implementations.
@objc(SFLogging)
public protocol SFLogging: NSObjectProtocol {

    /// Component name associated with this logger.
    var componentName: String { get }

    /// Instance of the underlying logger implementation being used.
    var logger: Any { get }

    /// Used to get and set the current log level associated with this logger.
    var logLevel: SFLogLevel { get set }

    /// Initialize a logger given component name.
    init(component componentName: String)

    /// Logs a log line of the specified level.
    func log(_ cls: AnyClass, level: SFLogLevel, message: String)

    /// Returns a shared instance for the given component name.
    @objc optional
    static func sharedInstance(withComponent componentName: String) -> Self
}

// MARK: - SalesforceLogger

/// Primary Salesforce logger facade. Routes log calls to a pluggable SFLogging backend.
@objc(SFLogger)
@objcMembers
open class SalesforceLogger: NSObject {

    // MARK: - Level typealias for Swift callers

    /// Convenience typealias so Swift callers use `SalesforceLogger.Level`.
    public typealias Level = SFLogLevel

    // MARK: - Private Static State

    private static let kDefaultComponentName = "SFSDK"
    private static var instanceClass: SFLogging.Type = SFDefaultLogger.self
    private static var _logReceiverFactory: SalesforceLogReceiverFactory?
    private static var loggerList = SafeMutableDictionary<NSString, SalesforceLogger>()
    private static let syncLock = NSLock()

    // MARK: - Instance Properties

    private var loggingImpl: SFLogging
    private var logReceiver: SalesforceLogReceiver?

    /// The underlying logger implementation backing this facade.
    /// Exposed at internal visibility for test verification (reachable via `@testable import`);
    /// not part of the public API surface.
    internal var underlyingLoggerImpl: SFLogging { loggingImpl }

    /// Sets log level to be used by this logger.
    public var level: SFLogLevel {
        get { loggingImpl.logLevel }
        set { loggingImpl.logLevel = newValue }
    }

    // MARK: - Initializers (internal)

    private init(componentName: String, logReceiver: SalesforceLogReceiver? = nil) {
        let cls = SalesforceLogger.instanceClass
        // Try the optional sharedInstance factory first, fall back to required init
        let sharedSelector = NSSelectorFromString("sharedInstanceWithComponent:")
        if let metaClass = cls as? NSObject.Type,
           metaClass.responds(to: sharedSelector),
           let instance = metaClass.perform(sharedSelector, with: componentName)?.takeUnretainedValue() as? SFLogging {
            self.loggingImpl = instance
        } else {
            self.loggingImpl = cls.init(component: componentName)
        }
        self.logReceiver = logReceiver
        super.init()
    }

    // MARK: - Private Helpers

    private func submitLogEntry(cls: AnyClass, level: SFLogLevel, message: String) {
        loggingImpl.log(cls, level: level, message: message)
        logReceiver?.receive(level: level, cls: cls, component: loggingImpl.componentName, message: message)
    }

    // MARK: - Instance Log Methods

    /// Logs a log line of the default level.
    public func log(_ cls: AnyClass, message: String) {
        submitLogEntry(cls: cls, level: .default, message: message)
    }

    /// Logs a log line of the specified level.
    public func log(_ cls: AnyClass, level: SFLogLevel, message: String) {
        submitLogEntry(cls: cls, level: level, message: message)
    }

    /// Logs an error log line.
    public func e(_ cls: AnyClass, message: String) {
        submitLogEntry(cls: cls, level: .error, message: message)
    }

    /// Logs a fault log line.
    public func f(_ cls: AnyClass, message: String) {
        submitLogEntry(cls: cls, level: .fault, message: message)
    }

    /// Logs an info log line.
    public func i(_ cls: AnyClass, message: String) {
        submitLogEntry(cls: cls, level: .info, message: message)
    }

    /// Logs a debug log line.
    public func d(_ cls: AnyClass, message: String) {
        submitLogEntry(cls: cls, level: .debug, message: message)
    }

    /// Logs a default/warning log line.
    public func w(_ cls: AnyClass, message: String) {
        submitLogEntry(cls: cls, level: .default, message: message)
    }

    // MARK: - Class-Level Log Methods

    /// Returns current log level used by the default logger.
    public class func logLevel() -> SFLogLevel {
        return defaultLogger.level
    }

    /// Sets log level to be used by the default logger.
    public class func setLogLevel(_ logLevel: SFLogLevel) {
        defaultLogger.level = logLevel
    }

    /// Logs an error log line.
    public class func e(_ cls: AnyClass, message: String) {
        defaultLogger.e(cls, message: message)
    }

    /// Logs an info log line.
    public class func i(_ cls: AnyClass, message: String) {
        defaultLogger.i(cls, message: message)
    }

    /// Logs a debug log line.
    public class func d(_ cls: AnyClass, message: String) {
        defaultLogger.d(cls, message: message)
    }

    /// Logs a default/warning log line.
    public class func w(_ cls: AnyClass, message: String) {
        defaultLogger.w(cls, message: message)
    }

    /// Logs a fault log line.
    public class func f(_ cls: AnyClass, message: String) {
        defaultLogger.f(cls, message: message)
    }

    /// Logs a default/verbose log line.
    public class func v(_ cls: AnyClass, message: String) {
        defaultLogger.log(cls, level: .default, message: message)
    }

    /// Logs a log line of the default level.
    public class func log(_ cls: AnyClass, message: String) {
        defaultLogger.log(cls, message: message)
    }

    /// Logs a log line of the specified level.
    public class func log(_ cls: AnyClass, level: SFLogLevel, message: String) {
        defaultLogger.log(cls, level: level, message: message)
    }

    // MARK: - Configuration

    /// Set an instance of the underlying logger class that complies with SFLogging.
    public class func setInstanceClass(_ loggerClass: SFLogging.Type) {
        instanceClass = loggerClass
    }

    /// Sets the log receiver factory which creates log receivers.
    public class func setLogReceiverFactory(_ logReceiverFactory: SalesforceLogReceiverFactory) {
        _logReceiverFactory = logReceiverFactory
    }

    /// Returns the default logger.
    public class var defaultLogger: SalesforceLogger {
        return logger(forComponent: kDefaultComponentName)
    }

    /// Returns a logger for the given component name.
    public class func logger(forComponent component: String) -> SalesforceLogger {
        syncLock.lock()
        defer { syncLock.unlock() }

        let key = component as NSString
        if let existing = loggerList.object(forKey: key) {
            return existing
        }

        var logReceiver: SalesforceLogReceiver?
        if let factory = _logReceiverFactory {
            logReceiver = factory.create(componentName: component)
        }

        let newLogger = SalesforceLogger(componentName: component, logReceiver: logReceiver)
        loggerList.setObject(newLogger, forKey: key)
        return newLogger
    }

    /// Removes all cached loggers. Used for testing.
    internal class func clearAllComponents() {
        loggerList.removeAllObjects()
    }
}
