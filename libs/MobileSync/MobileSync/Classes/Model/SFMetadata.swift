/*
 SFMetadata.swift
 MobileSync

 Created by Bharath Hariharan on 5/24/18.

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

private let kSFActivateable = "activateable"
private let kSFCompactLayoutable = "compactLayoutable"
private let kSFCreateable = "createable"
private let kSFCustom = "custom"
private let kSFCustomSetting = "customSetting"
private let kSFDeletable = "deletable"
private let kSFDeprecatedAndHidden = "deprecatedAndHidden"
private let kSFFeedEnabled = "feedEnabled"
private let kSFChildRelationships = "childRelationships"
private let kSFHasSubtypes = "hasSubtypes"
private let kSFIsSubtype = "isSubtype"
private let kSFKeyPrefix = "keyPrefix"
private let kSFMetaLabel = "label"
private let kSFLabelPlural = "labelPlural"
private let kSFLayoutable = "layoutable"
private let kSFMergeable = "mergeable"
private let kSFMruEnabled = "mruEnabled"
private let kSFMetaName = "name"
private let kSFFields = "fields"
private let kSFNetworkScopeFieldName = "networkScopeFieldName"
private let kSFQueryable = "queryable"
private let kSFReplicateable = "replicateable"
private let kSFRetrieveable = "retrieveable"
private let kSFSearchLayoutable = "searchLayoutable"
private let kSFSearchable = "searchable"
private let kSFTriggerable = "triggerable"
private let kSFUndeletable = "undeletable"
private let kSFUpdateable = "updateable"
private let kSFUrls = "urls"

/// Represents the metadata of a Salesforce object.
@objc(SFMetadata)
@objcMembers
public class SFMetadata: NSObject {

    @objc public private(set) var activateable: Bool = false
    @objc public private(set) var compactLayoutable: Bool = false
    @objc public private(set) var createable: Bool = false
    @objc public private(set) var custom: Bool = false
    @objc public private(set) var customSetting: Bool = false
    @objc public private(set) var deletable: Bool = false
    @objc public private(set) var deprecatedAndHidden: Bool = false
    @objc public private(set) var feedEnabled: Bool = false
    @objc public private(set) var childRelationships: [[String: Any]]?
    @objc public private(set) var hasSubtypes: Bool = false
    @objc public private(set) var isSubtype: Bool = false
    @objc public private(set) var keyPrefix: String = ""
    @objc public private(set) var label: String?
    @objc public private(set) var labelPlural: String?
    @objc public private(set) var layoutable: Bool = false
    @objc public private(set) var mergeable: Bool = false
    @objc public private(set) var mruEnabled: Bool = false
    @objc public private(set) var name: String = ""
    @objc public private(set) var fields: [[String: Any]]?
    @objc public private(set) var networkScopeFieldName: String?
    @objc public private(set) var queryable: Bool = false
    @objc public private(set) var replicateable: Bool = false
    @objc public private(set) var retrieveable: Bool = false
    @objc public private(set) var searchLayoutable: Bool = false
    @objc public private(set) var searchable: Bool = false
    @objc public private(set) var triggerable: Bool = false
    @objc public private(set) var undeletable: Bool = false
    @objc public private(set) var updateable: Bool = false
    @objc public private(set) var urls: [String: Any] = [:]
    @objc public private(set) var rawData: [String: Any] = [:]

    /// Creates an instance of this class from its JSON representation.
    @objc public class func from(_ data: [AnyHashable: Any]) -> SFMetadata? {
        guard !data.isEmpty else { return nil }
        let metadata = SFMetadata()
        let dict = data as? [String: Any] ?? [:]
        metadata.rawData = dict
        metadata.activateable = (dict[kSFActivateable] as? NSNumber)?.boolValue ?? false
        metadata.compactLayoutable = (dict[kSFCompactLayoutable] as? NSNumber)?.boolValue ?? false
        metadata.createable = (dict[kSFCreateable] as? NSNumber)?.boolValue ?? false
        metadata.custom = (dict[kSFCustom] as? NSNumber)?.boolValue ?? false
        metadata.customSetting = (dict[kSFCustomSetting] as? NSNumber)?.boolValue ?? false
        metadata.deletable = (dict[kSFDeletable] as? NSNumber)?.boolValue ?? false
        metadata.deprecatedAndHidden = (dict[kSFDeprecatedAndHidden] as? NSNumber)?.boolValue ?? false
        metadata.feedEnabled = (dict[kSFFeedEnabled] as? NSNumber)?.boolValue ?? false
        metadata.childRelationships = dict[kSFChildRelationships] as? [[String: Any]]
        metadata.hasSubtypes = (dict[kSFHasSubtypes] as? NSNumber)?.boolValue ?? false
        metadata.isSubtype = (dict[kSFIsSubtype] as? NSNumber)?.boolValue ?? false
        metadata.keyPrefix = dict[kSFKeyPrefix] as? String ?? ""
        metadata.label = dict[kSFMetaLabel] as? String
        metadata.labelPlural = dict[kSFLabelPlural] as? String
        metadata.layoutable = (dict[kSFLayoutable] as? NSNumber)?.boolValue ?? false
        metadata.mergeable = (dict[kSFMergeable] as? NSNumber)?.boolValue ?? false
        metadata.mruEnabled = (dict[kSFMruEnabled] as? NSNumber)?.boolValue ?? false
        metadata.name = dict[kSFMetaName] as? String ?? ""
        metadata.fields = dict[kSFFields] as? [[String: Any]]
        metadata.networkScopeFieldName = dict[kSFNetworkScopeFieldName] as? String
        metadata.queryable = (dict[kSFQueryable] as? NSNumber)?.boolValue ?? false
        metadata.replicateable = (dict[kSFReplicateable] as? NSNumber)?.boolValue ?? false
        metadata.retrieveable = (dict[kSFRetrieveable] as? NSNumber)?.boolValue ?? false
        metadata.searchLayoutable = (dict[kSFSearchLayoutable] as? NSNumber)?.boolValue ?? false
        metadata.searchable = (dict[kSFSearchable] as? NSNumber)?.boolValue ?? false
        metadata.triggerable = (dict[kSFTriggerable] as? NSNumber)?.boolValue ?? false
        metadata.undeletable = (dict[kSFUndeletable] as? NSNumber)?.boolValue ?? false
        metadata.updateable = (dict[kSFUpdateable] as? NSNumber)?.boolValue ?? false
        metadata.urls = dict[kSFUrls] as? [String: Any] ?? [:]
        return metadata
    }
}
