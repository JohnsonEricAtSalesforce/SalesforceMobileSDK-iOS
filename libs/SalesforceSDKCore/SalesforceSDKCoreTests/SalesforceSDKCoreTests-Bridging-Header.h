//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "SFSDKLogoutBlocker.h"
#import "SFSDKAuthRequest.h"
#import "SFSDKAuthSession.h"
#import "SFOAuthCoordinator+Internal.h"
#import "SFUserAccountManager+Internal.h"
#import "SFOAuthCredentials+Internal.h"
#import "SFOAuthKeychainCredentials.h"

// Expose internal keychain token methods for testing
@interface SFOAuthKeychainCredentials (Testing)
- (NSString * _Nullable)decryptedTokenForService:(NSString * _Nonnull)service;
- (void)encryptToken:(NSString * _Nonnull)token forService:(NSString * _Nonnull)service;
@end
