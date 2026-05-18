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

/// Type alias for data encryption block.
public typealias DataEncryptorBlock = (Data?) -> Data?

/// Type alias for data decryption block.
public typealias DataDecryptorBlock = (Data?) -> Data?

/// Manages storage of instrumentation events on the filesystem.
@objc(SFSDKEventStoreManager)
@objcMembers
public class SFSDKEventStoreManager: NSObject {

    // MARK: - Properties

    public private(set) var storeDirectory: String
    public private(set) var dataEncryptorBlock: DataEncryptorBlock?
    public private(set) var dataDecryptorBlock: DataDecryptorBlock?
    public private(set) var numStoredEvents: Int = 0
    public var loggingEnabled: Bool = true
    public var maxEvents: Int = 1000

    private let eventCountMutex = NSLock()

    // MARK: - Initializers

    /// Parameterized initializer.
    ///
    /// - Parameters:
    ///   - storeDirectory: Store directory.
    ///   - dataEncryptorBlock: Block that performs encryption.
    ///   - dataDecryptorBlock: Block that performs decryption.
    @objc(initWithStoreDirectory:dataEncryptorBlock:dataDecryptorBlock:)
    public init(storeDirectory: String, dataEncryptorBlock: DataEncryptorBlock?, dataDecryptorBlock: DataDecryptorBlock?) {
        self.storeDirectory = storeDirectory

        // If a data encryptor block is passed in, uses it. Otherwise, creates a block that returns data as-is.
        if let encryptor = dataEncryptorBlock {
            self.dataEncryptorBlock = encryptor
        } else {
            self.dataEncryptorBlock = { data in return data }
        }

        // If a data decryptor block is passed in, uses it. Otherwise, creates a block that returns data as-is.
        if let decryptor = dataDecryptorBlock {
            self.dataDecryptorBlock = decryptor
        } else {
            self.dataDecryptorBlock = { data in return data }
        }

        super.init()

        // Gets current number of events stored.
        if let files = try? FileManager.default.contentsOfDirectory(atPath: storeDirectory) {
            numStoredEvents = files.count
        }
    }

    // MARK: - Public Methods

    /// Stores an event to the filesystem. A combination of event's unique ID and
    /// filename suffix is used to generate a unique filename per event.
    ///
    /// - Parameter event: Event to be persisted.
    @objc public func storeEvent(_ event: SFSDKInstrumentationEvent?) {
        guard let event = event else { return }

        // Copies event, to isolate data for I/O.
        guard let eventCopy = event.copy() as? SFSDKInstrumentationEvent else { return }
        guard shouldStoreEvent() else { return }

        guard let encryptedData = dataEncryptorBlock?(eventCopy.jsonRepresentation()) else { return }

        let filename = self.filename(forEvent: eventCopy.eventId)
        let parentDir = (filename as NSString).deletingLastPathComponent

        do {
            try FileManager.default.createDirectory(
                atPath: parentDir,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
            )
        } catch {
            SFSDKAnalyticsLogger.w(SFSDKEventStoreManager.self, format: "Error occurred while trying to create directory: %@", error.localizedDescription)
            return
        }

        do {
            try encryptedData.write(to: URL(fileURLWithPath: filename), options: .completeFileProtectionUntilFirstUserAuthentication)
        } catch {
            SFSDKAnalyticsLogger.w(SFSDKEventStoreManager.self, format: "Error occurred while writing to file: %@", error.localizedDescription)
            return
        }

        eventCountMutex.lock()
        numStoredEvents += 1
        eventCountMutex.unlock()
    }

    /// Stores a list of events to the filesystem.
    ///
    /// - Parameter events: List of events.
    @objc public func storeEvents(_ events: [SFSDKInstrumentationEvent]?) {
        guard let events = events, !events.isEmpty else { return }
        guard shouldStoreEvent() else { return }
        for event in events {
            storeEvent(event)
        }
    }

    /// Returns all the event files stored on the filesystem for that unique identifier.
    ///
    /// - Returns: List of event files.
    @objc public func eventFiles() -> [String]? {
        return try? FileManager.default.contentsOfDirectory(atPath: storeDirectory)
    }

    /// Returns a specific event stored on the filesystem.
    ///
    /// - Parameter eventId: Unique identifier for the event.
    /// - Returns: Event.
    @objc public func fetchEvent(_ eventId: String?) -> SFSDKInstrumentationEvent? {
        guard let eventId = eventId else { return nil }
        let filePath = filename(forEvent: eventId)
        return fetchEvent(fromFile: filePath)
    }

    /// Returns all the events stored on the filesystem for that unique identifier.
    ///
    /// - Returns: List of events.
    @objc public func fetchAllEvents() -> [SFSDKInstrumentationEvent]? {
        guard let files = eventFiles() else { return nil }
        var events = [SFSDKInstrumentationEvent]()
        for file in files {
            if let event = fetchEvent(fromFile: filename(forEvent: file)) {
                events.append(event)
            }
        }
        return events
    }

    /// Deletes a specific event stored on the filesystem.
    ///
    /// - Parameter eventId: Unique identifier for the event.
    /// - Returns: True if successful, False otherwise.
    @objc(deleteEvent:)
    @discardableResult
    public func deleteEvent(_ eventId: String?) -> Bool {
        guard let eventId = eventId else { return false }
        let fileManager = FileManager.default
        let filePath = filename(forEvent: eventId)
        guard fileManager.fileExists(atPath: filePath) else { return false }
        do {
            try fileManager.removeItem(atPath: filePath)
            eventCountMutex.lock()
            numStoredEvents -= 1
            eventCountMutex.unlock()
            return true
        } catch {
            return false
        }
    }

    /// Deletes the events stored on the filesystem for the given event IDs.
    ///
    /// - Parameter eventIds: Event IDs to delete.
    @objc public func deleteEvents(_ eventIds: [String]?) {
        guard let eventIds = eventIds, !eventIds.isEmpty else { return }
        for eventId in eventIds {
            deleteEvent(eventId)
        }
    }

    /// Deletes all the events stored on the filesystem for that unique identifier.
    @objc public func deleteAllEvents() {
        let fileManager = FileManager.default
        let files = try? fileManager.contentsOfDirectory(atPath: storeDirectory)
        if let files = files {
            for file in files {
                let filePath = filename(forEvent: file)
                if fileManager.fileExists(atPath: filePath) {
                    try? fileManager.removeItem(atPath: filePath)
                }
            }
        }
        eventCountMutex.lock()
        numStoredEvents = 0
        eventCountMutex.unlock()
    }

    /// Lets callers know if they can store an event (optimization, so they wouldn't have to build and call storeEvent unnecessarily).
    ///
    /// - Returns: True if an event can be stored.
    @objc public func shouldStoreEvent() -> Bool {
        return effectiveLoggingEnabled && (numStoredEvents < maxEvents)
    }

    // MARK: - Private Properties (for custom getter)

    private var effectiveLoggingEnabled: Bool {
        let globalAnalyticsDisabled = (Bundle.main.object(forInfoDictionaryKey: "SFDCAnalyticsDisabled") as? NSNumber)?.boolValue ?? false
        if globalAnalyticsDisabled {
            return false
        }
        return loggingEnabled
    }

    // MARK: - Private Methods

    private func fetchEvent(fromFile file: String?) -> SFSDKInstrumentationEvent? {
        guard let file = file else { return nil }
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: file) else { return nil }
        guard let fileData = try? Data(contentsOf: URL(fileURLWithPath: file)),
              let data = dataDecryptorBlock?(fileData) else { return nil }
        let event = SFSDKInstrumentationEvent(json: data)
        if !event.eventId.isEmpty {
            return event.copy() as? SFSDKInstrumentationEvent
        }
        return nil
    }

    private func filename(forEvent eventId: String) -> String {
        return (storeDirectory as NSString).appendingPathComponent(eventId)
    }
}
