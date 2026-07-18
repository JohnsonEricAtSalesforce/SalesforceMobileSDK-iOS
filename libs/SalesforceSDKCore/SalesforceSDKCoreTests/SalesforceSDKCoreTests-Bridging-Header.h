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
#import "SalesforceSDKManager+Internal.h"
// SFOAuthCredentials and SFOAuthKeychainCredentials are now Swift classes.
// Their internal/testing methods are directly accessible from Swift test code.

// Bridge for catching ObjC NSExceptions from Swift test code (Swift cannot catch
// NSException natively). Runs the block and returns the raised NSException, or nil if
// none was raised — the equivalent of ObjC's XCTAssertThrows. Header-only static inline
// so no new compiled source file / project change is required.
static inline NSException * _Nullable SFSDKCatchException(void (^ _Nonnull tryBlock)(void)) {
    @try {
        tryBlock();
    } @catch (NSException *exception) {
        return exception;
    }
    return nil;
}
