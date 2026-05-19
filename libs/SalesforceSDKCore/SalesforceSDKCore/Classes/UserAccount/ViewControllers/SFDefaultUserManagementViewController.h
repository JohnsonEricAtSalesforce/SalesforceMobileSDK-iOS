// SFDefaultUserManagementViewController.h — tombstoned (class is now in Swift)
// Copyright (c) 2014-present, salesforce.com, inc. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause

#import <UIKit/UIKit.h>

@class SFUserAccount;

// Forward declaration — full type available via -Swift.h in .m files
@class SFDefaultUserManagementViewController;

// Forward-declare the enum type for ObjC headers that reference it by name.
typedef NS_ENUM(NSUInteger, SFUserManagementAction);

typedef void (^SFUserManagementCompletionBlock)(SFUserManagementAction action);
