// SFSDKOAuth2.h — tombstoned (class is now in Swift)
// Copyright (c) 2019-present, salesforce.com, inc. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause

#import <Foundation/Foundation.h>
#import <SalesforceSDKCore/SalesforceSDKConstants.h>

// Forward declarations — full types available via -Swift.h in .m files
@class SFOAuthCredentials;
@class SFSDKOAuth2;
@class SFSDKOAuthTokenEndpointRequest;
@class SFSDKOAuthTokenEndpointResponse;
@class SFSDKOAuthTokenEndpointErrorResponse;
@protocol SFSDKOAuthProtocol;

extern const NSTimeInterval kSFOAuthDefaultTimeout;
extern NSString * _Nonnull const kSFOAuthErrorDomain;

enum {
    kSFOAuthErrorUnknown = 666,
    kSFOAuthErrorTimeout,
    kSFOAuthErrorMalformed,
    kSFOAuthErrorAccessDenied,
    kSFOAuthErrorInvalidClientId,
    kSFOAuthErrorInvalidClientCredentials,
    kSFOAuthErrorInvalidGrant,
    kSFOAuthErrorInvalidRequest,
    kSFOAuthErrorInactiveUser,
    kSFOAuthErrorInactiveOrg,
    kSFOAuthErrorRateLimitExceeded,
    kSFOAuthErrorUnsupportedResponseType,
    kSFOAuthErrorWrongVersion,
    kSFOAuthErrorBrowserLaunchFailed,
    kSFOAuthErrorUnknownAdvancedAuthConfig,
    kSFOAuthErrorInvalidMDMConfiguration,
    kSFOAuthErrorJWTInvalidGrant,
    kSFOAuthErrorRequestCancelled,
    kSFOAuthErrorRefreshFailed,
    kSFOAuthErrorInvalidURL
};

typedef NS_ENUM(NSInteger, SFLogoutReason) {
    SFLogoutReasonCorruptState,
    SFLogoutReasonCorruptStateAppConfigurationSettings,
    SFLogoutReasonCorruptStateAppProviderErrorInvalidUser,
    SFLogoutReasonCorruptStateAppInvalidRestClient,
    SFLogoutReasonCorruptStateAppOther,
    SFLogoutReasonCorruptStateMSDK,
    SFLogoutReasonTokenExpired,
    SFLogoutReasonSSDKPolicy,
    SFLogoutReasonTimeout,
    SFLogoutReasonUnexpected,
    SFLogoutReasonUnexpectedResponse,
    SFLogoutReasonUnknown,
    SFLogoutReasonUserInitiated,
    SFLogoutReasonRefreshTokenRotated,              // Refresh token rotated
    SFLogoutReasonAppAttestationFailed              // App attestation permanently blocked this client
};
