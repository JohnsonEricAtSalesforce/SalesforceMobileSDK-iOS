// SFRestAPI.h — tombstoned (class is now in Swift)
// Copyright (c) 2011-present, salesforce.com, inc. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause

#import <Foundation/Foundation.h>
#import <SalesforceSDKCore/SalesforceSDKConstants.h>

// Forward declarations — full types available via -Swift.h in .m files
@class SFRestAPI;
@class SFRestRequest;
@class SFUserAccount;

typedef void (^SFRestRequestFailBlock) (id _Nullable response, NSError * _Nullable e, NSURLResponse * _Nullable rawResponse) NS_SWIFT_NAME(RestRequestFailBlock);
typedef void (^SFRestResponseBlock) (id _Nullable response, NSURLResponse * _Nullable rawResponse) NS_SWIFT_NAME(RestResponseBlock);

/*
 * Domain used for errors reported by the rest API (non HTTP errors)
 */
extern NSString* _Nonnull const kSFRestErrorDomain NS_SWIFT_NAME(SFRestErrorDomain);
/*
 * Error code used for all rest API errors (non HTTP errors)
 */
extern NSInteger const kSFRestErrorCode NS_SWIFT_NAME(SFRestErrorCode);

/*
 * Default API version (currently "v66.0")
 */
extern NSString* _Nonnull const kSFRestDefaultAPIVersion NS_SWIFT_NAME(SFRestDefaultAPIVersion);

/*
 * Misc keys appearing in requests
 */
extern NSString* _Nonnull const kSFRestIfUnmodifiedSince NS_SWIFT_NAME(SFRestIfUnmodifiedSince);

/**
 * SOQL batch related constants
 */
extern NSInteger const kSFRestSOQLMinBatchSize NS_SWIFT_NAME(SFRestSOQLMinBatchSize);
extern NSInteger const kSFRestSOQLMaxBatchSize NS_SWIFT_NAME(SFRestSOQLMaxBatchSize);
extern NSInteger const kSFRestSOQLDefaultBatchSize NS_SWIFT_NAME(SFRestSOQLDefaultBatchSize);
extern NSString* _Nonnull const kSFRestQueryOptions NS_SWIFT_NAME(SFRestQueryOptions);

/**
 Other constants
 */
extern NSInteger const kSFRestCollectionRetrieveMaxSize NS_SWIFT_NAME(SFRestCollectionRetrieveMaxSize);
