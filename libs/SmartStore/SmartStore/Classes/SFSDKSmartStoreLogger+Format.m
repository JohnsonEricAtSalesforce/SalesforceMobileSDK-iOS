// SFSDKSmartStoreLogger+Format.m - ObjC compatibility bridge
// Provides variadic format: methods (cannot be expressed in Swift) and
// extern constant definitions for backward compatibility with ObjC callers.

#import <SmartStore/SmartStore-Swift.h>
#import "SFSDKSmartStoreLogger.h"

// MARK: - Variadic format methods

@implementation SFSDKSmartStoreLogger (FormatMethods)

+ (void)e:(Class)cls format:(NSString *)format, ... { va_list a; va_start(a, format); [self e:cls message:[[NSString alloc] initWithFormat:format arguments:a]]; va_end(a); }
+ (void)w:(Class)cls format:(NSString *)format, ... { va_list a; va_start(a, format); [self w:cls message:[[NSString alloc] initWithFormat:format arguments:a]]; va_end(a); }
+ (void)i:(Class)cls format:(NSString *)format, ... { va_list a; va_start(a, format); [self i:cls message:[[NSString alloc] initWithFormat:format arguments:a]]; va_end(a); }
+ (void)d:(Class)cls format:(NSString *)format, ... { va_list a; va_start(a, format); [self d:cls message:[[NSString alloc] initWithFormat:format arguments:a]]; va_end(a); }
+ (void)f:(Class)cls format:(NSString *)format, ... { va_list a; va_start(a, format); [self f:cls message:[[NSString alloc] initWithFormat:format arguments:a]]; va_end(a); }
+ (void)v:(Class)cls format:(NSString *)format, ... { va_list a; va_start(a, format); [self v:cls message:[[NSString alloc] initWithFormat:format arguments:a]]; va_end(a); }
+ (void)log:(Class)cls level:(SFLogLevel)level format:(NSString *)format, ... { va_list a; va_start(a, format); [self log:cls level:level message:[[NSString alloc] initWithFormat:format arguments:a]]; va_end(a); }

@end

// MARK: - Extern constant definitions for ObjC backward compatibility

// SoupIndex constants
NSString * const kSoupIndexPath = @"path";
NSString * const kSoupIndexType = @"type";
NSString * const kSoupIndexTypeString = @"string";
NSString * const kSoupIndexTypeInteger = @"integer";
NSString * const kSoupIndexTypeFloating = @"floating";
NSString * const kSoupIndexTypeFullText = @"full_text";
NSString * const kSoupIndexTypeJSON1 = @"json1";

// QuerySpec constants
NSString * const kQuerySpecSortOrderAscending = @"ascending";
NSString * const kQuerySpecSortOrderDescending = @"descending";
NSString * const kQuerySpecTypeExact = @"exact";
NSString * const kQuerySpecTypeRange = @"range";
NSString * const kQuerySpecTypeLike = @"like";
NSString * const kQuerySpecTypeSmart = @"smart";
NSString * const kQuerySpecTypeMatch = @"match";
NSString * const kQuerySpecParamQueryType = @"queryType";
NSString * const kQuerySpecParamSelectPaths = @"selectPaths";
NSString * const kQuerySpecParamIndexPath = @"indexPath";
NSString * const kQuerySpecParamOrderPath = @"orderPath";
NSString * const kQuerySpecParamOrder = @"order";
NSString * const kQuerySpecParamPageSize = @"pageSize";
NSString * const kQuerySpecParamMatchKey = @"matchKey";
NSString * const kQuerySpecParamBeginKey = @"beginKey";
NSString * const kQuerySpecParamEndKey = @"endKey";
NSString * const kQuerySpecParamLikeKey = @"likeKey";
NSString * const kQuerySpecParamSmartSql = @"smartSql";
NSUInteger const kQuerySpecDefaultPageSize = 10;

// SmartStore constants
NSString * const kDefaultSmartStoreName = @"defaultStore";
NSString * const kSFSmartStoreErrorDomain = @"com.salesforce.smartstore.error";
NSString * const kSFSmartStoreJSONParseErrorNotification = @"SFSmartStoreJSONParseErrorNotification";
NSString * const kSFSmartStoreErrorLoadExternalSoup = @"com.salesforce.smartstore.LoadExternalSoupError";
NSString * const kSFSmartStoreEncryptionKeyLabel = @"com.salesforce.smartstore.encryption.keyLabel";
NSString * const kSFSmartStoreEncryptionSaltLabel = @"com.salesforce.smartstore.encryption.saltLabel";

// Column constants
NSString * const ID_COL = @"id";
NSString * const CREATED_COL = @"created";
NSString * const LAST_MODIFIED_COL = @"lastModified";
NSString * const SOUP_COL = @"soup";
NSString * const SOUP_ENTRY_ID = @"_soupEntryId";
NSString * const SOUP_LAST_MODIFIED_DATE = @"_soupLastModifiedDate";
NSString * const ROWID_COL = @"rowid";

// SmartStoreLogger constant
NSString * const kSFSDKSmartStoreComponentName = @"SmartStore";

// Internal constants
NSString * const EXPLAIN_ROWS = @"rows";

// Block-type filter constants
typedef BOOL (^SFIndexSpecTypeFilter)(id);
SFIndexSpecTypeFilter kValueExtractedToColumn = ^BOOL(id idx) {
    return ![[idx indexType] isEqualToString:@"json1"];
};
SFIndexSpecTypeFilter kValueExtractedToFtsColumn = ^BOOL(id idx) {
    return [[idx indexType] isEqualToString:@"full_text"];
};
SFIndexSpecTypeFilter kValueIndexedWithJSONExtract = ^BOOL(id idx) {
    return [[idx indexType] isEqualToString:@"json1"];
};
