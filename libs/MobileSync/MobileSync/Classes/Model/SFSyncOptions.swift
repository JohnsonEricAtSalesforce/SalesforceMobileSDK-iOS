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

public let kSFSyncOptionsFieldlist: String = "fieldlist"
public let kSFSyncOptionsMergeMode: String = "mergeMode"

@objc(SFSyncOptions)
@objcMembers
public class SFSyncOptions: NSObject {

    @objc public private(set) var fieldlist: [Any]?
    @objc public private(set) var mergeMode: SFSyncStateMergeMode = .overwrite

    // MARK: - Factory methods

    @objc public class func newSyncOptions(forSyncDown mergeMode: SFSyncStateMergeMode) -> SFSyncOptions {
        let options = SFSyncOptions()
        options.mergeMode = mergeMode
        return options
    }

    @objc public class func newSyncOptions(forSyncUp fieldlist: [Any]) -> SFSyncOptions {
        return newSyncOptions(forSyncUp: fieldlist, mergeMode: .overwrite)
    }

    @objc public class func newSyncOptions(forSyncUp fieldlist: [Any], mergeMode: SFSyncStateMergeMode) -> SFSyncOptions {
        let options = SFSyncOptions()
        options.fieldlist = fieldlist
        options.mergeMode = mergeMode
        return options
    }

    // MARK: - From/to dictionary

    @objc public class func new(fromDict dict: [String: Any]?) -> SFSyncOptions? {
        guard let dict = dict, dict.count > 0 else { return nil }
        return SFSyncOptions.newSyncOptions(
            forSyncUp: dict[kSFSyncOptionsFieldlist] as? [Any] ?? [],
            mergeMode: SFSyncState.mergeMode(fromString: dict[kSFSyncOptionsMergeMode] as? String ?? "")
        )
    }

    @objc public func asDict() -> [String: Any] {
        var dict = [String: Any]()
        if let fieldlist = fieldlist { dict[kSFSyncOptionsFieldlist] = fieldlist }
        dict[kSFSyncOptionsMergeMode] = SFSyncState.mergeModeToString(mergeMode)
        return dict
    }
}
