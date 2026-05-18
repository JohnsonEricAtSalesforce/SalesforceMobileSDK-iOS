/*
 SFSDKAnalyticsManager.swift
 SalesforceAnalytics

 Created by Bharath Hariharan on 6/5/16.

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

/// Manages analytics event storage and device attributes.
@objc(SFSDKAnalyticsManager)
@objcMembers
public class SFSDKAnalyticsManager: NSObject {

    // MARK: - Properties

    public private(set) var storeDirectory: String
    public private(set) var storeManager: SFSDKEventStoreManager
    public private(set) var deviceAttributes: SFSDKDeviceAppAttributes?
    public var globalSequenceId: Int = 0

    // MARK: - Initializers

    /// Parameterized initializer.
    ///
    /// - Parameters:
    ///   - storeDirectory: Store directory that is used to determine where the events are stored.
    ///   - dataEncryptorBlock: Block that performs encryption.
    ///   - dataDecryptorBlock: Block that performs decryption.
    ///   - deviceAttributes: Device app attributes.
    @objc(initWithStoreDirectory:dataEncryptorBlock:dataDecryptorBlock:deviceAttributes:)
    public init(storeDirectory: String, dataEncryptorBlock: DataEncryptorBlock?, dataDecryptorBlock: DataDecryptorBlock?, deviceAttributes: SFSDKDeviceAppAttributes?) {
        self.storeDirectory = storeDirectory
        self.deviceAttributes = deviceAttributes
        self.globalSequenceId = 0
        self.storeManager = SFSDKEventStoreManager(storeDirectory: storeDirectory, dataEncryptorBlock: dataEncryptorBlock, dataDecryptorBlock: dataDecryptorBlock)
        super.init()
    }

    // MARK: - Public Methods

    /// Resets this instance.
    @objc public func reset() {
        storeManager.deleteAllEvents()
    }
}
