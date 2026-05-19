// SFSDKAuthConfigUtil.h — tombstoned (class is now in Swift)
// Copyright (c) 2018-present, salesforce.com, inc. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause

#import <Foundation/Foundation.h>

@class SFOAuthOrgAuthConfiguration;

// Forward declaration — full type available via -Swift.h in .m files
@class SFSDKAuthConfigUtil;

typedef void (^ _Nonnull MyDomainAuthConfigBlock)(SFOAuthOrgAuthConfiguration * _Nullable authConfig, NSError * _Nullable error);
