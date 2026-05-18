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

public let kId: String = "Id"
public let kCreatedId: String = "id" // id in sobject create response
public let kName: String = "Name"
public let kType: String = "Type"
public let kAttributes: String = "attributes"
public let kRecentlyViewed: String = "RecentlyViewed"
public let kRawData: String = "rawData"
public let kObjectTypeField: String = "attributes.type"
public let kLastModifiedDate: String = "LastModifiedDate"
public let kResponseRecords: String = "records"
public let kResponseSearchRecords: String = "searchRecords"
public let kResponseTotalSize: String = "totalSize"
public let kResponseNextRecordsUrl: String = "nextRecordsUrl"
public let kRecentItems: String = "recentItems"

// Salesforce object types
public let kAccount: String = "Account"
public let kTask: String = "Task"
public let kContact: String = "Contact"
public let kUser: String = "User"
public let kGroup: String = "CollaborationGroup"
public let kContent: String = "ContentDocument"

// Sync target constants
public let kSFSyncTargetTypeKey: String = "type"
public let kSFSyncTargetiOSImplKey: String = "iOSImpl"
public let kSFSyncTargetIdFieldNameKey: String = "idFieldName"
public let kSFSyncTargetModificationDateFieldNameKey: String = "modificationDateFieldName"

/// Enum for available MobileSync data fetch modes.
///
/// - cacheOnly: Fetches data from the cache and returns null if no data is available.
/// - cacheFirst: Fetches data from the cache and falls back on the server if no data is available.
/// - serverFirst: Fetches data from the server and falls back on the cache if the server doesn't
///   return data. The data fetched from the server is automatically cached.
@objc(SFSDKFetchMode)
public enum SFSDKFetchMode: Int {
    case cacheOnly = 0
    case cacheFirst
    case serverFirst
}
