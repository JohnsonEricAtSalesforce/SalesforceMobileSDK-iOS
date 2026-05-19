// SFSDKTestRequestListener.h — tombstoned (class is now in Swift)
// Copyright (c) 2012-present, salesforce.com, inc. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause

#import <Foundation/Foundation.h>

// Forward declaration — full type available via -Swift.h in .m files
@class SFSDKTestRequestListener;

extern NSString* _Nonnull const kTestRequestStatusWaiting;
extern NSString* _Nonnull const kTestRequestStatusDidLoad;
extern NSString* _Nonnull const kTestRequestStatusDidFail;

// Forward-declare enum — values defined in Swift
typedef NS_ENUM(NSUInteger, SFAccountManagerServiceType);
