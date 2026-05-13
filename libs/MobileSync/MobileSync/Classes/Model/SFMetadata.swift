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

/**
 * Represents the metadata of a Salesforce object.
 *
 * @see https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/dome_sobject_describe.htm
 */
@objc(SFMetadata)
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

    /**
     * Creates an instance of this class from its JSON representation.
     *
     * @param data JSON data.
     * @return Instance of this class.
     */
    @objc(fromJSON:)
    public static func from(json data: [String: Any]) -> SFMetadata {
        let metadata = SFMetadata()
        metadata.rawData = data
        metadata.activateable = (data["activateable"] as? Bool) ?? false
        metadata.compactLayoutable = (data["compactLayoutable"] as? Bool) ?? false
        metadata.createable = (data["createable"] as? Bool) ?? false
        metadata.custom = (data["custom"] as? Bool) ?? false
        metadata.customSetting = (data["customSetting"] as? Bool) ?? false
        metadata.deletable = (data["deletable"] as? Bool) ?? false
        metadata.deprecatedAndHidden = (data["deprecatedAndHidden"] as? Bool) ?? false
        metadata.feedEnabled = (data["feedEnabled"] as? Bool) ?? false
        metadata.childRelationships = data["childRelationships"] as? [[String: Any]]
        metadata.hasSubtypes = (data["hasSubtypes"] as? Bool) ?? false
        metadata.isSubtype = (data["isSubtype"] as? Bool) ?? false
        metadata.keyPrefix = (data["keyPrefix"] as? String) ?? ""
        metadata.label = data["label"] as? String
        metadata.labelPlural = data["labelPlural"] as? String
        metadata.layoutable = (data["layoutable"] as? Bool) ?? false
        metadata.mergeable = (data["mergeable"] as? Bool) ?? false
        metadata.mruEnabled = (data["mruEnabled"] as? Bool) ?? false
        metadata.name = (data["name"] as? String) ?? ""
        metadata.fields = data["fields"] as? [[String: Any]]
        metadata.networkScopeFieldName = data["networkScopeFieldName"] as? String
        metadata.queryable = (data["queryable"] as? Bool) ?? false
        metadata.replicateable = (data["replicateable"] as? Bool) ?? false
        metadata.retrieveable = (data["retrieveable"] as? Bool) ?? false
        metadata.searchLayoutable = (data["searchLayoutable"] as? Bool) ?? false
        metadata.searchable = (data["searchable"] as? Bool) ?? false
        metadata.triggerable = (data["triggerable"] as? Bool) ?? false
        metadata.undeletable = (data["undeletable"] as? Bool) ?? false
        metadata.updateable = (data["updateable"] as? Bool) ?? false
        metadata.urls = (data["urls"] as? [String: Any]) ?? [:]
        return metadata
    }
}
