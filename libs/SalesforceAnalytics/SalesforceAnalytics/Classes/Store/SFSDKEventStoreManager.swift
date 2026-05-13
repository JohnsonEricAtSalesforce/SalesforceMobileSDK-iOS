/*
 SFSDKEventStoreManager.swift
 SalesforceAnalytics

 Created by Bharath Hariharan on 6/4/16.

 Copyright (c) 2016-present, salesforce.com, inc. All rights reserved.

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

// Note: These typealiases cannot be marked @objc because closures with optional types
// are not representable in Objective-C
public typealias DataEncryptorBlock = (Data?) -> Data?
public typealias DataDecryptorBlock = (Data?) -> Data?

@objc(SFSDKEventStoreManager)
public class SFSDKEventStoreManager: NSObject {

    @objc public let storeDirectory: String
    @objc public let dataEncryptorBlock: DataEncryptorBlock
    @objc public let dataDecryptorBlock: DataDecryptorBlock
    @objc public private(set) var numStoredEvents: Int
    @objc public var isLoggingEnabled: Bool {
        get {
            if let globalAnalyticsDisabled = Bundle.main.object(forInfoDictionaryKey: "SFDCAnalyticsDisabled") as? Bool,
               globalAnalyticsDisabled {
                return false
            }
            return _loggingEnabled
        }
        set {
            _loggingEnabled = newValue
        }
    }

    private var _loggingEnabled: Bool
    @objc public var maxEvents: Int

    private let eventCountMutex = NSObject()

    /// Parameterized initializer.
    ///
    /// - Parameters:
    ///   - storeDirectory: Store directory.
    ///   - dataEncryptorBlock: Block that performs encryption.
    ///   - dataDecryptorBlock: Block that performs decryption.
    @objc
    public init(
        storeDirectory: String,
        dataEncryptorBlock: DataEncryptorBlock?,
        dataDecryptorBlock: DataDecryptorBlock?
    ) {
        self.storeDirectory = storeDirectory
        self._loggingEnabled = true
        self.maxEvents = 1000

        // If a data encryptor block is passed in, uses it. Otherwise, creates a block that returns data as-is.
        if let encryptorBlock = dataEncryptorBlock {
            self.dataEncryptorBlock = encryptorBlock
        } else {
            self.dataEncryptorBlock = { data in
                return data
            }
        }

        // If a data decryptor block is passed in, uses it. Otherwise, creates a block that returns data as-is.
        if let decryptorBlock = dataDecryptorBlock {
            self.dataDecryptorBlock = decryptorBlock
        } else {
            self.dataDecryptorBlock = { data in
                return data
            }
        }

        // Gets current number of events stored.
        self.numStoredEvents = 0
        if let files = try? FileManager.default.contentsOfDirectory(atPath: storeDirectory) {
            self.numStoredEvents = files.count
        }

        super.init()
    }

    /// Stores an event to the filesystem. A combination of event's unique ID and
    /// filename suffix is used to generate a unique filename per event.
    ///
    /// - Parameter event: Event to be persisted.
    @objc
    public func storeEvent(_ event: SFSDKInstrumentationEvent?) {
        guard let event = event else {
            return
        }

        // Copies event, to isolate data for I/O.
        guard let eventCopy = event.copy() as? SFSDKInstrumentationEvent else {
            return
        }

        if !shouldStoreEvent() {
            return
        }

        guard let encryptedData = dataEncryptorBlock(eventCopy.jsonRepresentation()) else {
            return
        }

        let filename = filenameForEvent(eventCopy.eventId)
        let parentDir = (filename as NSString).deletingLastPathComponent

        do {
            try FileManager.default.createDirectory(
                atPath: parentDir,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
            )
        } catch {
            SFSDKAnalyticsLogger.w(type(of: self), message: "Error occurred while trying to create directory: \(error.localizedDescription)")
            return
        }

        do {
            try encryptedData.write(to: URL(fileURLWithPath: filename), options: .completeFileProtectionUntilFirstUserAuthentication)
            objc_sync_enter(eventCountMutex)
            numStoredEvents += 1
            objc_sync_exit(eventCountMutex)
        } catch {
            SFSDKAnalyticsLogger.w(type(of: self), message: "Error occurred while writing to file: \(error.localizedDescription)")
        }
    }

    /// Stores a list of events to the filesystem.
    ///
    /// - Parameter events: List of events.
    @objc
    public func storeEvents(_ events: [SFSDKInstrumentationEvent]?) {
        guard let events = events, !events.isEmpty else {
            return
        }

        if !shouldStoreEvent() {
            return
        }

        for event in events {
            storeEvent(event)
        }
    }

    /// Returns all the event files stored on the filesystem for that unique identifier.
    ///
    /// - Returns: List of event files.
    @objc
    public func eventFiles() -> [String]? {
        return try? FileManager.default.contentsOfDirectory(atPath: storeDirectory)
    }

    /// Returns a specific event stored on the filesystem.
    ///
    /// - Parameter eventId: Unique identifier for the event.
    /// - Returns: Event.
    @objc
    public func fetchEvent(_ eventId: String?) -> SFSDKInstrumentationEvent? {
        guard let eventId = eventId else {
            return nil
        }

        let filePath = filenameForEvent(eventId)
        return fetchEventFromFile(filePath)
    }

    /// Returns all the events stored on the filesystem for that unique identifier.
    ///
    /// - Returns: List of events.
    @objc
    public func fetchAllEvents() -> [SFSDKInstrumentationEvent]? {
        guard let files = eventFiles() else {
            return nil
        }

        var events: [SFSDKInstrumentationEvent] = []
        for file in files {
            if let event = fetchEventFromFile(filenameForEvent(file)) {
                events.append(event)
            }
        }
        return events
    }

    /// Deletes a specific event stored on the filesystem.
    ///
    /// - Parameter eventId: Unique identifier for the event.
    /// - Returns: True - if successful, False - otherwise.
    @objc
    public func deleteEvent(_ eventId: String?) -> Bool {
        guard let eventId = eventId else {
            return false
        }

        let fileManager = FileManager.default
        let filePath = filenameForEvent(eventId)

        if fileManager.fileExists(atPath: filePath) {
            do {
                try fileManager.removeItem(atPath: filePath)
                objc_sync_enter(eventCountMutex)
                numStoredEvents -= 1
                objc_sync_exit(eventCountMutex)
                return true
            } catch {
                return false
            }
        }
        return false
    }

    /// Deletes the events stored on the filesystem for that unique identifier.
    ///
    /// - Parameter eventIds: List of event IDs.
    @objc
    public func deleteEvents(_ eventIds: [String]?) {
        guard let eventIds = eventIds, !eventIds.isEmpty else {
            return
        }

        for eventId in eventIds {
            _ = deleteEvent(eventId)
        }
    }

    /// Deletes all the events stored on the filesystem for that unique identifier.
    @objc
    public func deleteAllEvents() {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(atPath: storeDirectory) else {
            return
        }

        for file in files {
            let filePath = filenameForEvent(file)
            if fileManager.fileExists(atPath: filePath) {
                try? fileManager.removeItem(atPath: filePath)
            }
        }

        objc_sync_enter(eventCountMutex)
        numStoredEvents = 0
        objc_sync_exit(eventCountMutex)
    }

    /// Lets callers know if they can store an event (optimization, so they wouldn't have to build and call -store: unnecessarily).
    ///
    /// - Returns: True if event can be stored, false otherwise.
    @objc
    public func shouldStoreEvent() -> Bool {
        return isLoggingEnabled && (numStoredEvents < maxEvents)
    }

    // MARK: - Private methods

    private func fetchEventFromFile(_ file: String) -> SFSDKInstrumentationEvent? {
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: file) else {
            return nil
        }

        guard let fileData = try? Data(contentsOf: URL(fileURLWithPath: file)),
              let decryptedData = dataDecryptorBlock(fileData) else {
            return nil
        }

        let event = SFSDKInstrumentationEvent(json: decryptedData)
        if !event.eventId.isEmpty {
            return event.copy() as? SFSDKInstrumentationEvent
        }
        return nil
    }

    private func filenameForEvent(_ eventId: String) -> String {
        return (storeDirectory as NSString).appendingPathComponent(eventId)
    }
}
