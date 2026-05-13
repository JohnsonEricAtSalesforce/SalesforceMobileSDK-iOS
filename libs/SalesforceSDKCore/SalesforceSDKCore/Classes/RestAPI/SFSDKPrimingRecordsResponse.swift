/*
Copyright (c) 2022-present, salesforce.com, inc. All rights reserved.

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

@objc(SFSDKPrimingRecord)
@objcMembers
public class PrimingRecord: NSObject {
    public let dict: [String: Any]
    public let objectId: String
    public let systemModstamp: Date

    @objc
    public init(with dict: [String: Any]) {
        self.dict = dict
        self.objectId = dict["id"] as? String ?? ""
        self.systemModstamp = FormatUtils.getDateFromIsoDateString(dict["systemModstamp"] as? String) ?? Date()
        super.init()
    }

    public override var description: String {
        return dict.description
    }
}

@objc(SFSDKPrimingRuleError)
@objcMembers
public class PrimingRuleError: NSObject {
    public let dict: [String: Any]
    public let ruleId: String

    @objc
    public init(with dict: [String: Any]) {
        self.dict = dict
        self.ruleId = dict["ruleId"] as? String ?? ""
        super.init()
    }

    public override var description: String {
        return dict.description
    }
}

@objc(SFSDKPrimingStats)
@objcMembers
public class PrimingStats: NSObject {
    public let dict: [String: Any]
    public let ruleCountTotal: UInt
    public let recordCountTotal: UInt
    public let ruleCountServed: UInt
    public let recordCountServed: UInt

    @objc
    public init(with dict: [String: Any]) {
        self.dict = dict
        self.ruleCountTotal = (dict["ruleCountTotal"] as? NSNumber)?.uintValue ?? 0
        self.recordCountTotal = (dict["recordCountTotal"] as? NSNumber)?.uintValue ?? 0
        self.ruleCountServed = (dict["ruleCountServed"] as? NSNumber)?.uintValue ?? 0
        self.recordCountServed = (dict["recordCountServed"] as? NSNumber)?.uintValue ?? 0
        super.init()
    }

    public override var description: String {
        return dict.description
    }
}

@objc(SFSDKPrimingRecordsResponse)
@objcMembers
public class PrimingRecordsResponse: NSObject {
    public let primingRecords: [String: [String: [PrimingRecord]]]
    public let relayToken: String?
    public let ruleErrors: [PrimingRuleError]
    public let stats: PrimingStats

    @objc
    public init(with dict: [String: Any]) {
        // Priming records
        var apiNameToTypeToPrimingRecords: [String: [String: [PrimingRecord]]] = [:]
        if let apiNameToTypeToPrimingRecordsRaw = dict["primingRecords"] as? [String: Any] {
            for (apiName, value) in apiNameToTypeToPrimingRecordsRaw {
                var typeToPrimingRecords: [String: [PrimingRecord]] = [:]
                if let typeToPrimingRecordsRaw = value as? [String: Any] {
                    for (recordType, recordsValue) in typeToPrimingRecordsRaw {
                        var primingRecords: [PrimingRecord] = []
                        if let primingRecordsRaw = recordsValue as? [[String: Any]] {
                            for primingRecordRaw in primingRecordsRaw {
                                primingRecords.append(PrimingRecord(with: primingRecordRaw))
                            }
                        }
                        typeToPrimingRecords[recordType] = primingRecords
                    }
                }
                apiNameToTypeToPrimingRecords[apiName] = typeToPrimingRecords
            }
        }
        self.primingRecords = apiNameToTypeToPrimingRecords

        // Relay token
        self.relayToken = (dict as NSDictionary).sfsdk_nonNullObject(forKey: "relayToken") as? String

        // Rule errors
        var ruleErrors: [PrimingRuleError] = []
        if let ruleErrorsRaw = dict["ruleErrors"] as? [[String: Any]] {
            for ruleErrorRaw in ruleErrorsRaw {
                ruleErrors.append(PrimingRuleError(with: ruleErrorRaw))
            }
        }
        self.ruleErrors = ruleErrors

        // Stats
        if let statsDict = dict["stats"] as? [String: Any] {
            self.stats = PrimingStats(with: statsDict)
        } else {
            self.stats = PrimingStats(with: [:])
        }

        super.init()
    }
}
