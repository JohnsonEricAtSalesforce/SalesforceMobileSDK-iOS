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

private let kSFId = "id"
private let kSFLayoutType = "layoutType"
private let kSFMode = "mode"
private let kSFSections = "sections"
private let kSFCollapsible = "collapsible"
private let kSFColumns = "columns"
private let kSFHeading = "heading"
private let kSFLayoutRows = "layoutRows"
private let kSFRows = "rows"
private let kSFUseHeading = "useHeading"
private let kSFLayoutItems = "layoutItems"
private let kSFEditableForNew = "editableForNew"
private let kSFEditableForUpdate = "editableForUpdate"
private let kSFLabel = "label"
private let kSFLayoutComponents = "layoutComponents"
private let kSFLookupIdApiName = "lookupIdApiName"
private let kSFRequired = "required"
private let kSFSortable = "sortable"

/// Represents the layout of a Salesforce object.
@objc(SFLayout)
@objcMembers
public class SFLayout: NSObject {

    @objc public private(set) var id: String?
    @objc public private(set) var layoutType: String = ""
    @objc public private(set) var mode: String?
    @objc public private(set) var sections: [SFLayoutSection]?
    @objc public private(set) var rawData: NSDictionary?

    /// Creates an instance of this class from its JSON representation.
    @objc public class func from(_ data: [AnyHashable: Any]) -> SFLayout? {
        guard !data.isEmpty else { return nil }
        let layout = SFLayout()
        layout.rawData = data as NSDictionary
        layout.id = data[kSFId] as? String
        layout.layoutType = data[kSFLayoutType] as? String ?? ""
        layout.mode = data[kSFMode] as? String
        if let sectionsArray = data[kSFSections] as? [[String: Any]] {
            var extractedSections = [SFLayoutSection]()
            for sectionData in sectionsArray {
                if let section = SFLayoutSection.from(sectionData) {
                    extractedSections.append(section)
                }
            }
            layout.sections = extractedSections
        }
        return layout
    }
}

/// Represents a record layout section.
@objc(SFLayoutSection)
@objcMembers
public class SFLayoutSection: NSObject {

    @objc public private(set) var collapsible: Bool = false
    @objc public private(set) var columns: NSNumber?
    @objc public private(set) var heading: String?
    @objc public private(set) var id: String?
    @objc public private(set) var layoutRows: [SFRow]?
    @objc public private(set) var rows: NSNumber?
    @objc public private(set) var userHeading: Bool = false

    /// Creates an instance of this class from its JSON representation.
    @objc public class func from(_ data: [String: Any]) -> SFLayoutSection? {
        guard !data.isEmpty else { return nil }
        let section = SFLayoutSection()
        section.collapsible = (data[kSFCollapsible] as? NSNumber)?.boolValue ?? false
        section.columns = data[kSFColumns] as? NSNumber
        section.heading = data[kSFHeading] as? String
        section.id = data[kSFId] as? String
        if let rowsArray = data[kSFLayoutRows] as? [[String: Any]] {
            var extractedRows = [SFRow]()
            for rowData in rowsArray {
                if let row = SFRow.from(rowData) {
                    extractedRows.append(row)
                }
            }
            section.layoutRows = extractedRows
        }
        section.rows = data[kSFRows] as? NSNumber
        section.userHeading = (data[kSFUseHeading] as? NSNumber)?.boolValue ?? false
        return section
    }
}

/// Represents a record layout row.
@objc(SFRow)
@objcMembers
public class SFRow: NSObject {

    @objc public private(set) var layoutItems: [SFItem]?

    /// Creates an instance of this class from its JSON representation.
    @objc public class func from(_ data: [String: Any]) -> SFRow? {
        guard !data.isEmpty else { return nil }
        let row = SFRow()
        if let itemsArray = data[kSFLayoutItems] as? [[String: Any]] {
            var extractedItems = [SFItem]()
            for itemData in itemsArray {
                if let item = SFItem.from(itemData) {
                    extractedItems.append(item)
                }
            }
            row.layoutItems = extractedItems
        }
        return row
    }
}

/// Represents a record layout item.
@objc(SFItem)
@objcMembers
public class SFItem: NSObject {

    @objc public private(set) var editableForNew: Bool = false
    @objc public private(set) var editableForUpdate: Bool = false
    @objc public private(set) var label: String?
    @objc public private(set) var layoutComponents: [[String: Any]]?
    @objc public private(set) var lookupIdApiName: String?
    @objc public private(set) var required: Bool = false
    @objc public private(set) var sortable: Bool = false

    /// Creates an instance of this class from its JSON representation.
    @objc public class func from(_ data: [String: Any]) -> SFItem? {
        guard !data.isEmpty else { return nil }
        let item = SFItem()
        item.editableForNew = (data[kSFEditableForNew] as? NSNumber)?.boolValue ?? false
        item.editableForUpdate = (data[kSFEditableForUpdate] as? NSNumber)?.boolValue ?? false
        item.label = data[kSFLabel] as? String
        item.layoutComponents = data[kSFLayoutComponents] as? [[String: Any]]
        item.lookupIdApiName = data[kSFLookupIdApiName] as? String
        item.required = (data[kSFRequired] as? NSNumber)?.boolValue ?? false
        item.sortable = (data[kSFSortable] as? NSNumber)?.boolValue ?? false
        return item
    }
}
