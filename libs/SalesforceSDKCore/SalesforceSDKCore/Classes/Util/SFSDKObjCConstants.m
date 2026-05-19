/*
 SFSDKObjCConstants.m
 SalesforceSDKCore

 C-linkage constant definitions for ObjC files that reference extern constants
 whose original definitions were in .m files now replaced by Swift.

 Copyright (c) 2024-present, salesforce.com, inc. All rights reserved.
 SPDX-License-Identifier: BSD-3-Clause
 */

#import <Foundation/Foundation.h>

// From SFSDKAppFeatureMarkers (extern declared in SFSDKAppFeatureMarkers.h)
NSString * const kSFAppFeatureSwiftApp = @"SW";
NSString * const kSFAppFeatureMultiUser = @"MU";
NSString * const kSFAppFeatureMacApp = @"MC";
NSString * const kSFAppFeatureNativeLogin = @"NL";
NSString * const kSFAppFeatureWelcomeDiscovery = @"WD";
NSString * const kSFAppFeatureSafariBrowserForLogin = @"BW";
NSString * const kSFAppFeatureScreenLock = @"SL";
NSString * const kSFAppFeatureBioAuth = @"BA";
NSString * const kSFAppFeatureManagedByMDM = @"MM";
NSString * const kSFAppFeatureOAuth = @"UA";
NSString * const kSFAppFeatureAiltnEnabled = @"AI";
NSString * const kSFSPAppFeatureIDPLogin = @"SP";
NSString * const kSFIDPAppFeatureIDPLogin = @"IP";
NSString * const kSFAppFeatureQrCodeLogin = @"QR";

// From SFSDKIDPConstants (extern declared in SFSDKIDPConstants.h)
NSString * const kSFErrorCodeParam = @"errorCode";
NSString * const kSFErrorReasonParam = @"errorReason";
NSUInteger const kSFVerifierByteLength = 128;
NSString * const kSFVerifierParamName = @"code_verifier";
NSString * const kSFChallengeParamName = @"code_challenge";
NSString * const kSFStateParam = @"state";
NSString * const kSFAppNameParam = @"app_name";
NSString * const kSFUserHintParam = @"user_hint";
NSString * const kSFLoginHostParam = @"login_host";
NSString * const kSFCallingAppUrlParam = @"calling_app_url";
NSString * const kSFErrorDescriptionParam = @"errorDescription";
NSString * const kSFRefreshTokenParam = @"refresh_token";
NSString * const kSFOAuthClientIdParam = @"oauth_client_id";
NSString * const kSFOAuthRedirectUrlParam = @"oauth_redirect_uri";
NSString * const kSFScopesParam = @"scopes";
NSString * const kSFCodeParam = @"code";
NSString * const kSFSpecVersion = @"v1.0";
NSString * const kSFSpecHost = @"oauth2";
NSString * const kSFStartURLParam = @"start_url";
NSString * const kSFKeychainReferenceParam = @"keychain_reference";
NSString * const kSFKeychainGroupParam = @"keychain_group";
NSString * const kSFErrorDescParam = @"errorDesc";

// From SFSDKOAuth2 (extern declared in SFSDKOAuth2.h / SFSDKOAuth2+Internal.h)
NSString * const kSFOAuthErrorDomain = @"com.salesforce.OAuth.ErrorDomain";
