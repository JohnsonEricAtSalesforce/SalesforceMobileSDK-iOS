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

#import "SFSDKTestRequestListener.h"
#import "TestSetupUtils.h"
#import "SFUserAccountManager.h"

NSString* const kTestRequestStatusWaiting = @"waiting";
NSString* const kTestRequestStatusDidLoad = @"didLoad";
NSString* const kTestRequestStatusDidFail = @"didFail";

@interface SFSDKTestRequestListener ()
@end

@implementation SFSDKTestRequestListener

@synthesize dataResponse = _dataResponse;
@synthesize lastError = _lastError;
@synthesize returnStatus = _returnStatus;
@synthesize maxWaitTime = _maxWaitTime;

- (id)init
{
    self = [super init];
    if (nil != self) {
        self.maxWaitTime = 30.0;
        self.returnStatus = kTestRequestStatusWaiting;
    }
    return self;
}

- (void)dealloc {
    self.dataResponse = nil;
    self.lastError = nil;
    self.returnStatus = nil;
}

- (NSString *)waitForCompletion {
    NSDate *startTime = [NSDate date] ;
    while ([self.returnStatus isEqualToString:kTestRequestStatusWaiting]) {
        NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:startTime];
        if (elapsed > self.maxWaitTime) {
            [SFSDKCoreLogger d:[self class] format:@"Request took too long (> %f secs) to complete.", elapsed];
            return kTestRequestStatusDidFail;
        }
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }
    return self.returnStatus;
}

#pragma mark - SFIdentityCoordinatorDelegate

- (void)identityCoordinatorRetrievedData:(SFIdentityCoordinator *)coordinator
{
    [SFSDKCoreLogger i:[self class] format:@"%@", NSStringFromSelector(_cmd)];
    self.returnStatus = kTestRequestStatusDidLoad;
}

- (void)identityCoordinator:(SFIdentityCoordinator *)coordinator didFailWithError:(NSError *)error
{
    [SFSDKCoreLogger i:[self class] format:@"%@ with error: %@", NSStringFromSelector(_cmd), error];
    self.lastError = error;
    self.returnStatus = kTestRequestStatusDidFail;
}

#pragma mark - SFOAuthCoordinatorDelegate

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator willBeginAuthenticationWithView:(WKWebView *)view
{
    NSAssert(NO, @"User Agent flow not supported in this class.");
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didStartLoad:(WKWebView *)view
{
    NSAssert(NO, @"User Agent flow not supported in this class.");
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didFinishLoad:(WKWebView *)view error:(NSError*)errorOrNil
{
    NSAssert(NO, @"User Agent flow not supported in this class.");
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didBeginAuthenticationWithView:(WKWebView *)view
{
    NSAssert(NO, @"User Agent flow not supported in this class.");
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didBeginAuthenticationWithSession:(ASWebAuthenticationSession *)session
{
    NSAssert(NO, @"Web Server flow not supported in this class.");
}
- (void)oauthCoordinatorDidCancelBrowserAuthentication:(SFOAuthCoordinator *)coordinator
{
    NSAssert(NO, @"Web Server flow not supported in this class.");
}

- (void)oauthCoordinatorDidBeginNativeAuthentication:(nonnull SFOAuthCoordinator *)coordinator {
    NSAssert(NO, @"Web Server flow not supported in this class.");
}

- (void)oauthCoordinatorDidAuthenticate:(SFOAuthCoordinator *)coordinator authInfo:(SFOAuthInfo *)info
{
    [SFSDKCoreLogger i:[self class] format:@"%@ with authInfo: %@", NSStringFromSelector(_cmd), info];
    self.returnStatus = kTestRequestStatusDidLoad;
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didFailWithError:(NSError *)error authInfo:(SFOAuthInfo *)info
{
    [SFSDKCoreLogger i:[self class] format:@"%@ with authInfo: %@, error: %@", NSStringFromSelector(_cmd), info, error];
    self.lastError = error;
    self.returnStatus = kTestRequestStatusDidFail;
}

@end
