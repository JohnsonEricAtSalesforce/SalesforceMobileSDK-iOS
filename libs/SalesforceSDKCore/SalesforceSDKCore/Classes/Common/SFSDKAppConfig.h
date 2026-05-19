// SFSDKAppConfig.h — tombstoned (class is now in Swift)
// Copyright (c) 2014-present, salesforce.com, inc. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause

#import <Foundation/Foundation.h>

// Forward declaration — full type available via -Swift.h in .m files
@class SFSDKAppConfig;

// Forward-declare enum — values defined in Swift
typedef NS_ENUM(NSInteger, SFSDKAppConfigErrorCode);

extern NSString * _Nonnull const SFSDKAppConfigErrorDomain NS_SWIFT_NAME(BootConfig.errorDomain);
extern NSString * _Nonnull const SFSDKDefaultNativeAppConfigFilePath NS_SWIFT_NAME(BootConfig.defaultFilePath);
