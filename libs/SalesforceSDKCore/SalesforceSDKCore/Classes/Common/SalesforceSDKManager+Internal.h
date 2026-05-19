// SalesforceSDKManager+Internal.h — tombstoned (class is now in Swift)
// Copyright (c) 2014-present, salesforce.com, inc. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause

@import SalesforceSDKCommon;
#import "SalesforceSDKManager.h"
#import "SFUserAccountManager.h"

static NSString * _Nonnull const kSFDefaultNativeLoginViewControllerKey = @"defaultKey";

@protocol SalesforceSDKManagerFlow <NSObject>

- (void)handleAppForeground:(nonnull NSNotification *)notification;
- (void)handleAppBackground:(nonnull NSNotification *)notification;
- (void)handleAppTerminate:(nonnull NSNotification *)notification;
- (void)handlePostLogout;
- (void)handleAuthCompleted:(nonnull NSNotification *)notification;
- (void)handleIDPInitiatedAuthCompleted:(nonnull NSNotification *)notification;
- (void)handleUserDidLogout:(nonnull NSNotification *)notification;

@end

