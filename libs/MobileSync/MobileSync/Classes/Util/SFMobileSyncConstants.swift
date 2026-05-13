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

public let kId = "Id"
public let kCreatedId = "id" // id in sobject create response
public let kName = "Name"
public let kType = "Type"
public let kAttributes = "attributes"
public let kRecentlyViewed = "RecentlyViewed"
public let kRawData = "rawData"
public let kObjectTypeField = "attributes.type"
public let kLastModifiedDate = "LastModifiedDate"
public let kResponseRecords = "records"
public let kResponseSearchRecords = "searchRecords"
public let kResponseTotalSize = "totalSize"
public let kResponseNextRecordsUrl = "nextRecordsUrl"
public let kRecentItems = "recentItems"

/**
 * Salesforce object types.
 */
public let kAccount = "Account"
public let kTask = "Task"
public let kContact = "Contact"
public let kUser = "User"
public let kGroup = "CollaborationGroup"
public let kContent = "ContentDocument"

/**
 * Sync target constants.
 */
public let kSFSyncTargetTypeKey = "type"
public let kSFSyncTargetiOSImplKey = "iOSImpl"
public let kSFSyncTargetIdFieldNameKey = "idFieldName"
public let kSFSyncTargetModificationDateFieldNameKey = "modificationDateFieldName"

/**
 * Enum for available MobileSync data fetch modes.
 *
 * SFSDKFetchModeCacheOnly - Fetches data from the cache and returns null if no data is available.
 * SFSDKFetchModeCacheFirst - Fetches data from the cache and falls back on the server if no data is available.
 * SFSDKFetchModeServerFirst - Fetches data from the server and falls back on the cache if the server doesn't
 * return data. The data fetched from the server is automatically cached.
 */
@objc public enum SFSDKFetchMode: Int {
    case cacheOnly = 0
    case cacheFirst
    case serverFirst
}
