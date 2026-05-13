/*
 Copyright (c) 2014-present, salesforce.com, inc. All rights reserved.

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

public let kSFSyncOptionsFieldlist = "fieldlist"
public let kSFSyncOptionsMergeMode = "mergeMode"

@objc(SFSyncOptions)
public class SFSyncOptions: NSObject {

    @objc public let fieldlist: [String]?
    @objc public let mergeMode: SyncMergeMode

    private init(fieldlist: [String]?, mergeMode: SyncMergeMode) {
        self.fieldlist = fieldlist
        self.mergeMode = mergeMode
        super.init()
    }

    // MARK: - Factory Methods

    @objc(newSyncOptionsForSyncDown:)
    public static func newSyncOptions(forSyncDown mergeMode: SyncMergeMode) -> SFSyncOptions {
        return SFSyncOptions(fieldlist: nil, mergeMode: mergeMode)
    }

    @objc(newSyncOptionsForSyncUp:)
    public static func newSyncOptions(forSyncUp fieldlist: [String]) -> SFSyncOptions {
        return SFSyncOptions(fieldlist: fieldlist, mergeMode: .overwrite)
    }

    @objc(newSyncOptionsForSyncUp:mergeMode:)
    public static func newSyncOptions(forSyncUp fieldlist: [String], mergeMode: SyncMergeMode) -> SFSyncOptions {
        return SFSyncOptions(fieldlist: fieldlist, mergeMode: mergeMode)
    }

    // MARK: - From/To Dictionary

    @objc(newFromDict:)
    public static func newFromDict(_ dict: [String: Any]?) -> SFSyncOptions? {
        guard let dict = dict, !dict.isEmpty else {
            return nil
        }

        let fieldlist = dict[kSFSyncOptionsFieldlist] as? [String]
        let mergeModeString = dict[kSFSyncOptionsMergeMode] as? String ?? ""
        let mergeMode = SFSyncState.mergeMode(fromString: mergeModeString)

        return SFSyncOptions.newSyncOptions(forSyncUp: fieldlist ?? [], mergeMode: mergeMode)
    }

    @objc
    public func asDict() -> [String: Any] {
        var dict: [String: Any] = [
            kSFSyncOptionsMergeMode: SFSyncState.mergeModeToString(mergeMode)
        ]
        if let fieldlist = fieldlist {
            dict[kSFSyncOptionsFieldlist] = fieldlist
        }
        return dict
    }
}

// Swift naming convention - drop SF prefix
public typealias SyncOptions = SFSyncOptions
