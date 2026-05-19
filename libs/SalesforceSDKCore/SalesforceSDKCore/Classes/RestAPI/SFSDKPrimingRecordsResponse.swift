//
//  SFSDKPrimingRecordsResponse.swift
//  SalesforceSDKCore
//
//  Copyright (c) 2022-present, salesforce.com, inc. All rights reserved.
//
//  Redistribution and use of this software in source and binary forms, with or without modification,
//  are permitted provided that the following conditions are met:
//  * Redistributions of source code must retain the above copyright notice, this list of conditions
//    and the following disclaimer.
//  * Redistributions in binary form must reproduce the above copyright notice, this list of
//    conditions and the following disclaimer in the documentation and/or other materials provided
//    with the distribution.
//  * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
//    endorse or promote products derived from this software without specific prior written
//    permission of salesforce.com, inc.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
//  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
//  FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
//  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
//  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
//  WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

import Foundation

/// Represents a single priming record from the priming records response.
@objc(SFSDKPrimingRecord)
@objcMembers
public class PrimingRecord: NSObject {

    public let dict: NSDictionary
    public let objectId: String
    public let systemModstamp: Date

    @objc public init(dict: NSDictionary) {
        self.dict = dict
        self.objectId = dict["id"] as? String ?? ""
        self.systemModstamp = FormatUtils.getDate(fromIsoDateString: dict["systemModstamp"] as? String) ?? Date()
        super.init()
    }

    public override var description: String {
        return dict.description
    }
}

/// Represents a rule error in the priming records response.
@objc(SFSDKPrimingRuleError)
@objcMembers
public class PrimingRuleError: NSObject {

    public let dict: NSDictionary
    public let ruleId: String

    @objc public init(dict: NSDictionary) {
        self.dict = dict
        self.ruleId = dict["ruleId"] as? String ?? ""
        super.init()
    }

    public override var description: String {
        return dict.description
    }
}

/// Statistics about the priming records response.
@objc(SFSDKPrimingStats)
@objcMembers
public class PrimingStats: NSObject {

    public let dict: NSDictionary
    public let ruleCountTotal: UInt
    public let recordCountTotal: UInt
    public let ruleCountServed: UInt
    public let recordCountServed: UInt

    @objc public init(dict: NSDictionary) {
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

/// Represents the full response from a priming records request.
@objc(SFSDKPrimingRecordsResponse)
@objcMembers
public class PrimingRecordsResponse: NSObject {

    public let primingRecords: [String: [String: [PrimingRecord]]]
    public let relayToken: String?
    public let ruleErrors: [PrimingRuleError]
    public let stats: PrimingStats

    @objc public init(dict: NSDictionary) {
        // Priming records
        var apiNameToTypeToPrimingRecords: [String: [String: [PrimingRecord]]] = [:]
        if let apiNameToTypeToPrimingRecordsRaw = dict["primingRecords"] as? [String: Any] {
            for (apiName, typeToPrimingRecordsRawValue) in apiNameToTypeToPrimingRecordsRaw {
                guard let typeToPrimingRecordsRaw = typeToPrimingRecordsRawValue as? [String: Any] else { continue }
                var typeToPrimingRecords: [String: [PrimingRecord]] = [:]
                for (recordType, primingRecordsRawValue) in typeToPrimingRecordsRaw {
                    guard let primingRecordsRaw = primingRecordsRawValue as? [[String: Any]] else { continue }
                    let records = primingRecordsRaw.map { PrimingRecord(dict: $0 as NSDictionary) }
                    typeToPrimingRecords[recordType] = records
                }
                apiNameToTypeToPrimingRecords[apiName] = typeToPrimingRecords
            }
        }
        self.primingRecords = apiNameToTypeToPrimingRecords

        // Relay token
        self.relayToken = dict.sfsdk_nonNullObject(forKey: "relayToken") as? String

        // Rule errors
        var errors: [PrimingRuleError] = []
        if let ruleErrorsRaw = dict["ruleErrors"] as? [[String: Any]] {
            errors = ruleErrorsRaw.map { PrimingRuleError(dict: $0 as NSDictionary) }
        }
        self.ruleErrors = errors

        // Stats
        self.stats = PrimingStats(dict: (dict["stats"] as? NSDictionary) ?? NSDictionary())

        super.init()
    }
}
