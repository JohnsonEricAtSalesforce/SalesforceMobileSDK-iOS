/*
 Copyright (c) 2012-present, salesforce.com, inc. All rights reserved.

 Redistribution and use of this software in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright notice, this list of conditions
 and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of
 conditions and the following disclaimer in the documentation and/or other materials provided
 with the distribution.
 * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
 endorse or promote products derived from this software without specific prior written
 permission of salesforce.com, inc.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
 FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
 WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

// NOTE: The class implementation has been migrated to SFUserAccountManager.swift.
// This header retains only the global constant declarations needed by ObjC consumers.
// The class interface, delegate protocol, enums, and SFNotificationUserInfo are now
// provided by the Swift-generated header (SalesforceSDKCore-Swift.h).

#import <Foundation/Foundation.h>
#import <SalesforceSDKCore/SFOAuthCoordinator.h>

@class SFUserAccountManager;
@class SFUserAccount;

NS_ASSUME_NONNULL_BEGIN

/**
 Callback block definition for auth client factory.
 */
typedef id<SFSDKOAuthProtocol> __nonnull (^SFAuthClientFactoryBlock)(void);

/**
 Callback block definition for OAuth completion callback.
 */
typedef void (^SFUserAccountManagerSuccessCallbackBlock)(SFOAuthInfo *, SFUserAccount *);

/**
 Callback block definition for OAuth failure callback.
 */
typedef void (^SFUserAccountManagerFailureCallbackBlock)(SFOAuthInfo *, NSError *);

// Notification names
FOUNDATION_EXTERN NSNotificationName SFUserAccountManagerDidChangeUserNotification;
FOUNDATION_EXTERN NSNotificationName SFUserAccountManagerDidChangeUserDataNotification;
FOUNDATION_EXTERN NSNotificationName SFUserAccountManagerDidFinishUserInitNotification;
FOUNDATION_EXTERN NSNotificationName kSFNotificationUserWillLogIn;
FOUNDATION_EXTERN NSNotificationName kSFNotificationUserDidLogIn;
FOUNDATION_EXTERN NSNotificationName kSFNotificationUserWillLogout;
FOUNDATION_EXTERN NSNotificationName kSFNotificationUserDidLogout;
FOUNDATION_EXTERN NSNotificationName kSFNotificationOrgDidLogout;
FOUNDATION_EXTERN NSNotificationName kSFNotificationUserDidRefreshToken;
FOUNDATION_EXTERN NSNotificationName kSFNotificationUserDidMigrateRefreshToken;
FOUNDATION_EXTERN NSNotificationName kSFNotificationUserWillSwitch;
FOUNDATION_EXTERN NSNotificationName kSFNotificationUserDidSwitch;
FOUNDATION_EXTERN NSNotificationName kSFNotificationDidChangeLoginHost;
FOUNDATION_EXTERN NSNotificationName kSFNotificationUserWillShowAuthView;
FOUNDATION_EXTERN NSNotificationName kSFNotificationUserCancelledAuth;
FOUNDATION_EXTERN NSNotificationName kSFNotificationUserWillSendIDPRequest;
FOUNDATION_EXTERN NSNotificationName kSFNotificationUserWillSendIDPResponse;
FOUNDATION_EXTERN NSNotificationName kSFNotificationUserDidReceiveIDPRequest;
FOUNDATION_EXTERN NSNotificationName kSFNotificationUserDidReceiveIDPResponse;
FOUNDATION_EXTERN NSNotificationName kSFNotificationUserIDPInitDidLogIn;

// Keys used in notification userInfo dictionaries
FOUNDATION_EXTERN NSString * const SFUserAccountManagerUserChangeKey;
FOUNDATION_EXTERN NSString * const SFUserAccountManagerUserChangeUserKey;
FOUNDATION_EXTERN NSString * const kSFNotificationUserInfoAccountKey;
FOUNDATION_EXTERN NSString * const kSFNotificationUserInfoLogoutReasonKey;
FOUNDATION_EXTERN NSString * const kSFNotificationUserInfoCredentialsKey;
FOUNDATION_EXTERN NSString * const kSFNotificationUserInfoAuthTypeKey;
FOUNDATION_EXTERN NSString * const kSFUserInfoAddlOptionsKey;
FOUNDATION_EXTERN NSString * const kSFNotificationUserInfoKey;
FOUNDATION_EXTERN NSString * const kSFNotificationFromUserKey;
FOUNDATION_EXTERN NSString * const kSFNotificationToUserKey;
FOUNDATION_EXTERN NSString * const kSFIDPSceneIdKey;

// Error domain
FOUNDATION_EXTERN NSString * const kSFSDKUserAccountManagerErrorDomain;

// Biometric/Identity constants
FOUNDATION_EXTERN NSString * const kBiometricAuthenticationPolicyKey;
FOUNDATION_EXTERN NSString * const kHttpHeaderAuthorization;
FOUNDATION_EXTERN NSString * const kHttpAuthHeaderFormatString;
FOUNDATION_EXTERN NSString * const kBiometricAuthenticationTimeoutKey;

NS_ASSUME_NONNULL_END
