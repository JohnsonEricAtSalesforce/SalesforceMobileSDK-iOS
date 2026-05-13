/*
 SFLayout.swift
 MobileSync

 Created by Bharath Hariharan on 5/17/18.

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
 * Represents the layout of a Salesforce object.
 *
 * @see https://developer.salesforce.com/docs/atlas.en-us.uiapi.meta/uiapi/ui_api_responses_record_layout.htm
 */
@objc(SFLayout)
public class SFLayout: NSObject {

    @objc public private(set) var id: String?
    @objc public private(set) var layoutType: String = ""
    @objc public private(set) var mode: String?
    @objc public private(set) var sections: [SFLayoutSection]?
    @objc public private(set) var rawData: [String: Any]?

    /**
     * Creates an instance of this class from its JSON representation.
     *
     * @param data JSON data.
     * @return Instance of this class.
     */
    @objc(fromJSON:)
    public static func from(json data: [String: Any]) -> SFLayout {
        let layout = SFLayout()
        layout.rawData = data
        layout.id = data["id"] as? String
        layout.layoutType = (data["layoutType"] as? String) ?? ""
        layout.mode = data["mode"] as? String

        if let sectionsData = data["sections"] as? [[String: Any]] {
            layout.sections = sectionsData.compactMap { SFLayoutSection.from(json: $0) }
        }

        return layout
    }
}

/**
 * Represents a record layout section.
 *
 * @see https://developer.salesforce.com/docs/atlas.en-us.uiapi.meta/uiapi/ui_api_responses_record_layout_section.htm#ui_api_responses_record_layout_section
 */
@objc(SFLayoutSection)
public class SFLayoutSection: NSObject {

    @objc public private(set) var collapsible: Bool = false
    @objc public private(set) var columns: NSNumber?
    @objc public private(set) var heading: String?
    @objc public private(set) var id: String?
    @objc public private(set) var layoutRows: [SFRow]?
    @objc public private(set) var rows: NSNumber?
    @objc public private(set) var userHeading: Bool = false

    /**
     * Creates an instance of this class from its JSON representation.
     *
     * @param data JSON data.
     * @return Instance of this class.
     */
    @objc(fromJSON:)
    public static func from(json data: [String: Any]) -> SFLayoutSection {
        let layoutSection = SFLayoutSection()
        layoutSection.collapsible = (data["collapsible"] as? Bool) ?? false
        layoutSection.columns = data["columns"] as? NSNumber
        layoutSection.heading = data["heading"] as? String
        layoutSection.id = data["id"] as? String

        if let rowsData = data["layoutRows"] as? [[String: Any]] {
            layoutSection.layoutRows = rowsData.compactMap { SFRow.from(json: $0) }
        }

        layoutSection.rows = data["rows"] as? NSNumber
        layoutSection.userHeading = (data["useHeading"] as? Bool) ?? false

        return layoutSection
    }
}

/**
 * Represents a record layout row.
 *
 * @see https://developer.salesforce.com/docs/atlas.en-us.uiapi.meta/uiapi/ui_api_responses_record_layout_row.htm#ui_api_responses_record_layout_row
 */
@objc(SFRow)
public class SFRow: NSObject {

    @objc public private(set) var layoutItems: [SFItem]?

    /**
     * Creates an instance of this class from its JSON representation.
     *
     * @param data JSON data.
     * @return Instance of this class.
     */
    @objc(fromJSON:)
    public static func from(json data: [String: Any]) -> SFRow {
        let row = SFRow()

        if let itemsData = data["layoutItems"] as? [[String: Any]] {
            row.layoutItems = itemsData.compactMap { SFItem.from(json: $0) }
        }

        return row
    }
}

/**
 * Represents a record layout item.
 *
 * @see https://developer.salesforce.com/docs/atlas.en-us.uiapi.meta/uiapi/ui_api_responses_record_layout_item.htm#ui_api_responses_record_layout_item
 */
@objc(SFItem)
public class SFItem: NSObject {

    @objc public private(set) var editableForNew: Bool = false
    @objc public private(set) var editableForUpdate: Bool = false
    @objc public private(set) var label: String?
    @objc public private(set) var layoutComponents: [[String: Any]]?
    @objc public private(set) var lookupIdApiName: String?
    @objc public private(set) var required: Bool = false
    @objc public private(set) var sortable: Bool = false

    /**
     * Creates an instance of this class from its JSON representation.
     *
     * @param data JSON data.
     * @return Instance of this class.
     */
    @objc(fromJSON:)
    public static func from(json data: [String: Any]) -> SFItem {
        let item = SFItem()
        item.editableForNew = (data["editableForNew"] as? Bool) ?? false
        item.editableForUpdate = (data["editableForUpdate"] as? Bool) ?? false
        item.label = data["label"] as? String
        item.layoutComponents = data["layoutComponents"] as? [[String: Any]]
        item.lookupIdApiName = data["lookupIdApiName"] as? String
        item.required = (data["required"] as? Bool) ?? false
        item.sortable = (data["sortable"] as? Bool) ?? false
        return item
    }
}
