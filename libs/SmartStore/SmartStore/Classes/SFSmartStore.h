// SFSmartStore.h - ObjC compatibility shim (implementation moved to SFSmartStore.swift)
@import SalesforceSDKCommon;
#import <SmartStore/SmartStore-Swift.h>

// Extern constants for backward-compatible ObjC access
extern NSString * const kDefaultSmartStoreName;
extern NSString * const kSFSmartStoreErrorDomain;
extern NSString * const kSFSmartStoreJSONParseErrorNotification;
extern NSString * const kSFSmartStoreErrorLoadExternalSoup;
extern NSString * const kSFSmartStoreEncryptionKeyLabel;
extern NSString * const kSFSmartStoreEncryptionSaltLabel;
extern NSString * const ID_COL;
extern NSString * const CREATED_COL;
extern NSString * const LAST_MODIFIED_COL;
extern NSString * const SOUP_COL;
extern NSString * const SOUP_ENTRY_ID;
extern NSString * const SOUP_LAST_MODIFIED_DATE;
extern NSString * const ROWID_COL;

// Backward-compatible enum value aliases
#define SFSmartStoreFTS4  SFSmartStoreFtsExtensionFts4
#define SFSmartStoreFTS5  SFSmartStoreFtsExtensionFts5
