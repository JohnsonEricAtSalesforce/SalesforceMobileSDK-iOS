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
import MobileSync

let kLastModifiedDate = "LastModifiedDate"

@objcMembers
class ContactSObjectData: SObjectData {

    private static var sDataSpec: ContactSObjectDataSpec?

    override class func dataSpec() -> SObjectDataSpec {
        if sDataSpec == nil {
            sDataSpec = ContactSObjectDataSpec()
        }
        return sDataSpec!
    }

    // MARK: - Property getters / setters

    var firstName: String? {
        get { return nonNullFieldValue(kContactFirstNameField) as? String }
        set { updateSoupForFieldName(kContactFirstNameField, fieldValue: newValue) }
    }

    var lastName: String? {
        get { return nonNullFieldValue(kContactLastNameField) as? String }
        set { updateSoupForFieldName(kContactLastNameField, fieldValue: newValue) }
    }

    var title: String? {
        get { return nonNullFieldValue(kContactTitleField) as? String }
        set { updateSoupForFieldName(kContactTitleField, fieldValue: newValue) }
    }

    var mobilePhone: String? {
        get { return nonNullFieldValue(kContactMobilePhoneField) as? String }
        set { updateSoupForFieldName(kContactMobilePhoneField, fieldValue: newValue) }
    }

    var email: String? {
        get { return nonNullFieldValue(kContactEmailField) as? String }
        set { updateSoupForFieldName(kContactEmailField, fieldValue: newValue) }
    }

    var department: String? {
        get { return nonNullFieldValue(kContactDepartmentField) as? String }
        set { updateSoupForFieldName(kContactDepartmentField, fieldValue: newValue) }
    }

    var homePhone: String? {
        get { return nonNullFieldValue(kContactHomePhoneField) as? String }
        set { updateSoupForFieldName(kContactHomePhoneField, fieldValue: newValue) }
    }

    var lastModifiedDate: String? {
        get { return nonNullFieldValue(kLastModifiedDate) as? String }
    }
}
