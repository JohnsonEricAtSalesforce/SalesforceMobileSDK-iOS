// SFSDKSmartStoreLogger.h - ObjC compatibility shim (implementation moved to SFSDKSmartStoreLogger.swift)
#import <SmartStore/SmartStore-Swift.h>

// Extern constant
extern NSString * const kSFSDKSmartStoreComponentName;

// Variadic format methods category (cannot be expressed in Swift)
@interface SFSDKSmartStoreLogger (FormatMethods)
+ (void)e:(nonnull Class)cls format:(nonnull NSString *)format, ... NS_FORMAT_FUNCTION(2, 3);
+ (void)w:(nonnull Class)cls format:(nonnull NSString *)format, ... NS_FORMAT_FUNCTION(2, 3);
+ (void)i:(nonnull Class)cls format:(nonnull NSString *)format, ... NS_FORMAT_FUNCTION(2, 3);
+ (void)d:(nonnull Class)cls format:(nonnull NSString *)format, ... NS_FORMAT_FUNCTION(2, 3);
+ (void)f:(nonnull Class)cls format:(nonnull NSString *)format, ... NS_FORMAT_FUNCTION(2, 3);
+ (void)v:(nonnull Class)cls format:(nonnull NSString *)format, ... NS_FORMAT_FUNCTION(2, 3);
+ (void)log:(nonnull Class)cls level:(SFLogLevel)level format:(nonnull NSString *)format, ... NS_FORMAT_FUNCTION(3, 4);
@end
