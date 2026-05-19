// SFAuthErrorHandler.h — tombstoned (class is now in Swift)
// Copyright (c) 2013-present, salesforce.com, inc. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause

#import <Foundation/Foundation.h>

@class SFOAuthInfo;
@class SFSDKAuthSession;

// Forward declaration — full type available via -Swift.h in .m files
@class SFAuthErrorHandler;

/**
 Block definition for auth error handling evaluation block with Options.
 */
typedef BOOL (^SFAuthErrorHandlerContextEvalBlock)(NSError * _Nonnull, SFSDKAuthSession * _Nonnull, NSDictionary * _Nonnull);
