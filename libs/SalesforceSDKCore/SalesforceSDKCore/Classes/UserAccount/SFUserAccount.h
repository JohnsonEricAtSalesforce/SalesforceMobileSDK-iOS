// SFUserAccount.h — tombstoned (class is now in Swift)
// Copyright (c) 2012-present, salesforce.com, inc. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
// For full license text, see the LICENSE file in the repo root or https://opensource.org/licenses/BSD-3-Clause

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <SalesforceSDKCore/SalesforceSDKConstants.h>
#import <SalesforceSDKCore/SFUserAccountConstants.h>

// Forward declarations — full type available via -Swift.h in .m files
@class SFUserAccount;
@class SFUserAccountIdentity;
@class SFOAuthCredentials;
@class NotificationType;
@class SFIdentityData;

// C functions still needed by ObjC callers
NS_ASSUME_NONNULL_BEGIN

@class SFUserAccount;

NSString *_Nullable SFKeyForUserAndScope(SFUserAccount * _Nullable user, SFUserAccountScope scope);
NSString *_Nullable SFKeyForUserIdAndScope(NSString *_Nullable userId, NSString *_Nullable orgId, NSString *_Nullable communityId, SFUserAccountScope scope);
NSString *SFKeyForGlobalScope(void);

NS_ASSUME_NONNULL_END
