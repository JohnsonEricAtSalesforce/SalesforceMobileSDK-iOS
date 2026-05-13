/*
 SFSDKTextFieldTableViewCell.swift
 SalesforceSDKCore

 Created by Kunal Chitalia on 1/22/16.
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

import UIKit

// Insets used to determine the proper size for the editable field presented in the table view cell.
private let SFSDKTextFieldCellInsets = UIEdgeInsets(top: 10.0, left: 10.0, bottom: 10.0, right: 30.0)

/// A custom UITableViewCell which contains a UITextField for inserting and editing text.
@objc(SFSDKTextFieldTableViewCell)
@objcMembers
public class SFSDKTextFieldTableViewCell: UITableViewCell {

    /// Text field for inserting and editing text.
    public private(set) var textField: UITextField

    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        textField = UITextField(frame: .zero)
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        textField.autoresizingMask = .flexibleWidth
        contentView.addSubview(textField)
    }

    required init?(coder: NSCoder) {
        textField = UITextField(frame: .zero)
        super.init(coder: coder)

        textField.autoresizingMask = .flexibleWidth
        contentView.addSubview(textField)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        textField.frame = contentView.frame.inset(by: SFSDKTextFieldCellInsets)
    }
}
