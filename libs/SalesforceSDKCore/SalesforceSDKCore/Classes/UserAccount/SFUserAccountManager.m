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

// This file retains only the global constant definitions needed by ObjC consumers.
// The class implementation has been migrated to SFUserAccountManager.swift.

#import "SFUserAccountManager.h"

// Notifications
NSNotificationName SFUserAccountManagerDidChangeUserNotification       = @"SFUserAccountManagerDidChangeUserNotification";
NSNotificationName SFUserAccountManagerDidChangeUserDataNotification   = @"SFUserAccountManagerDidChangeUserDataNotification";
NSNotificationName SFUserAccountManagerDidFinishUserInitNotification   = @"SFUserAccountManagerDidFinishUserInitNotification";

//login & logout notifications
NSNotificationName kSFNotificationUserWillLogIn  = @"SFNotificationUserWillLogIn";
NSNotificationName kSFNotificationUserDidLogIn   = @"SFNotificationUserDidLogIn";
NSNotificationName kSFNotificationUserWillLogout = @"SFNotificationUserWillLogout";
NSNotificationName kSFNotificationUserDidLogout  = @"SFNotificationUserDidLogout";
NSNotificationName kSFNotificationOrgDidLogout   = @"SFNotificationOrgDidLogout";
NSNotificationName kSFNotificationUserDidRefreshToken   = @"SFNotificationOAuthUserDidRefreshToken";
NSNotificationName kSFNotificationUserDidMigrateRefreshToken   = @"SFNotificationUserDidMigrateRefreshToken";

NSNotificationName kSFNotificationUserWillSwitch  = @"SFNotificationUserWillSwitch";
NSNotificationName kSFNotificationUserDidSwitch   = @"SFNotificationUserDidSwitch";
NSNotificationName kSFNotificationDidChangeLoginHost = @"SFNotificationDidChangeLoginHost";

//Auth Display Notification
NSNotificationName kSFNotificationUserWillShowAuthView = @"SFNotificationUserWillShowAuthView";
NSNotificationName kSFNotificationUserCancelledAuth = @"SFNotificationUserCanceledAuthentication";
//IDP-SP flow Notifications
NSNotificationName kSFNotificationUserWillSendIDPRequest      = @"SFNotificationUserWillSendIDPRequest";
NSNotificationName kSFNotificationUserWillSendIDPResponse     = @"kSFNotificationUserWillSendIDPResponse";
NSNotificationName kSFNotificationUserDidReceiveIDPRequest    = @"SFNotificationUserDidReceiveIDPRequest";
NSNotificationName kSFNotificationUserDidReceiveIDPResponse   = @"SFNotificationUserDidReceiveIDPResponse";
NSNotificationName kSFNotificationUserIDPInitDidLogIn       = @"SFNotificationUserIDPInitDidLogIn";

//keys used in notifications
NSString * const kSFNotificationUserInfoAccountKey           = @"account";
NSString * const kSFNotificationUserInfoLogoutReasonKey      = @"logoutReason";
NSString * const kSFNotificationUserInfoCredentialsKey       = @"credentials";
NSString * const kSFNotificationUserInfoAuthTypeKey          = @"authType";
NSString * const kSFNotificationPreviousLoginHost            = @"prevLoginHost";
NSString * const kSFNotificationCurrentLoginHost             = @"currentLoginHost";
NSString * const kSFUserInfoAddlOptionsKey                   = @"options";
NSString * const kSFNotificationUserInfoKey                  = @"sfuserInfo";
NSString * const kSFNotificationFromUserKey                  = @"fromUser";
NSString * const kSFNotificationToUserKey                    = @"toUser";
NSString * const SFUserAccountManagerUserChangeKey           = @"change";
NSString * const SFUserAccountManagerUserChangeUserKey       = @"user";

NSString * const kSFSDKUserAccountManagerErrorDomain = @"com.salesforce.mobilesdk.SFUserAccountManager";
NSString * const kSFIDPSceneIdKey = @"sceneIdentifier";
NSString * const kBiometricAuthenticationPolicyKey = @"ENABLE_BIOMETRIC_AUTHENTICATION";

// Constants previously defined in SFIdentityCoordinator.m (now Swift)
NSString * const kHttpHeaderAuthorization = @"Authorization";
NSString * const kHttpAuthHeaderFormatString = @"Bearer %@";
NSString * const kBiometricAuthenticationTimeoutKey = @"BIOMETRIC_AUTHENTICATION_TIMEOUT";
