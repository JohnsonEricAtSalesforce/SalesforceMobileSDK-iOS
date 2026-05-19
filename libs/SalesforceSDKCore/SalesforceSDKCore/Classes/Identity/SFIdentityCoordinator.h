// SFIdentityCoordinator.h — tombstoned (class is now in Swift)
// Copyright (c) 2012-present, salesforce.com, inc. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause

#import <Foundation/Foundation.h>

// Forward declarations — full types available via -Swift.h in .m files
@class SFIdentityCoordinator;
@class SFOAuthCredentials;
@class SFIdentityData;
@protocol SFIdentityCoordinatorDelegate;

extern const NSTimeInterval kSFIdentityRequestDefaultTimeoutSeconds;
extern NSString * const kSFIdentityErrorDomain;
extern NSString * const kHttpHeaderAuthorization;
extern NSString * const kHttpAuthHeaderFormatString;

enum {
    kSFIdentityErrorUnknown = 766,
    kSFIdentityErrorNoData,
    kSFIdentityErrorDataMalformed,
    kSFIdentityErrorBadHttpResponse,
    kSFIdentityErrorMissingParameters,
    kSFIdentityErrorAlreadyRetrieving,
};
