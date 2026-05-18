//
//  MobileSyncTypeAliases.swift
//  MobileSync
//
//  Swift type aliases preserving NS_SWIFT_NAME compatibility from the original ObjC headers.
//  These allow pre-existing Swift files to continue using the short names.
//
//  Copyright (c) 2024-present, salesforce.com, inc. All rights reserved.
//

import Foundation

// MARK: - Class aliases (NS_SWIFT_NAME from ObjC headers)

public typealias SyncTarget = SFSyncTarget
public typealias SyncDownTarget = SFSyncDownTarget
public typealias SyncUpTarget = SFSyncUpTarget
public typealias SyncManager = SFMobileSyncSyncManager
public typealias SyncState = SFSyncState
public typealias SyncOptions = SFSyncOptions
public typealias BatchSyncUpTarget = SFBatchSyncUpTarget
public typealias RecordModDate = SFRecordModDate
public typealias NetworkUtils = SFMobileSyncNetworkUtils
public typealias MobileSyncLogger = SFSDKMobileSyncLogger
public typealias ObjectUtils = SFMobileSyncObjectUtils
public typealias ChildrenInfo = SFChildrenInfo
public typealias ParentInfo = SFParentInfo
public typealias ParentChildrenSyncHelper = SFParentChildrenSyncHelper
public typealias ParentChildrenSyncDownTarget = SFParentChildrenSyncDownTarget
public typealias ParentChildrenSyncUpTarget = SFParentChildrenSyncUpTarget
public typealias SoslSyncDownTarget = SFSoslSyncDownTarget
public typealias SoqlSyncDownTarget = SFSoqlSyncDownTarget
public typealias RefreshSyncDownTarget = SFRefreshSyncDownTarget
public typealias MruSyncDownTarget = SFMruSyncDownTarget
public typealias MetadataSyncDownTarget = SFMetadataSyncDownTarget
public typealias LayoutSyncDownTarget = SFLayoutSyncDownTarget
public typealias MetadataSyncManager = SFMetadataSyncManager
public typealias LayoutSyncManager = SFLayoutSyncManager
public typealias Layout = SFLayout
public typealias Metadata = SFMetadata
public typealias SObject = SFObject
public typealias PersistableObject = SFMobileSyncPersistableObject
public typealias SyncsConfig = SFSDKSyncsConfig

// MARK: - Typedef aliases (NS_SWIFT_NAME from ObjC headers)

public typealias SyncDownCompletionBlock = SFSyncDownTargetFetchCompleteBlock
public typealias SyncDownErrorBlock = SFSyncDownTargetFetchErrorBlock
public typealias SyncUpdateBlock = SFSyncSyncManagerUpdateBlock
public typealias SyncCompletionBlock = SFSyncSyncManagerCompletionStatusBlock
public typealias RecordNewerThanServerBlock = SFSyncUpRecordNewerThanServerBlock
public typealias SyncUpcompletionBlock = SFSyncUpTargetCompleteBlock
public typealias SyncUpErrorBlock = SFSyncUpTargetErrorBlock

// MARK: - Enum aliases

public typealias SyncType = SFSyncStateSyncType
public typealias SyncStatus = SFSyncStateStatus
public typealias SyncMergeMode = SFSyncStateMergeMode
public typealias FetchMode = SFSDKFetchMode

// MARK: - Reverse aliases (new Swift files use SF-prefixed names for types defined in pre-existing Swift files)

public typealias SFSDKRecordRequest = RecordRequest
public typealias SFSDKRecordResponse = RecordResponse
public typealias SFBriefcaseSyncDownTarget = BriefcaseSyncDownTarget
public typealias SFCollectionSyncUpTarget = CollectionSyncUpTarget

// MARK: - Upstream type aliases (SmartStore/SalesforceSDKCore types referenced by ObjC name in converted code)
// These types were already converted to Swift in their respective libraries with short names.

import SmartStore
import SalesforceSDKCore

public typealias SFSmartStore = SmartStore
public typealias SFSoupIndex = SoupIndex
public typealias SFUserAccount = UserAccount
// Note: SFRestRequest, SFFormatUtils, SFQuerySpec are upstream ObjC classes with NS_SWIFT_NAME
// that makes them available as RestRequest, FormatUtils, QuerySpec in Swift.
// Converted code should use those names directly.
