/*
 SFSDKSmartStoreLogger.m
 SmartStore
 
 Created by Bharath Hariharan on 6/26/17.
 
 Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.
 
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

#import "SFSDKSmartStoreLogger.h"

NSString * const kSFSDKSmartStoreComponentName = @"SmartStore";

@implementation SFSDKSmartStoreLogger

+ (SFLogger *)_logger {
    return [SFLogger loggerForComponent:kSFSDKSmartStoreComponentName];
}

// Class format: methods
+ (void)e:(Class)cls format:(NSString *)format, ... { va_list a; va_start(a, format); [[self _logger] e:cls message:[[NSString alloc] initWithFormat:format arguments:a]]; va_end(a); }
+ (void)w:(Class)cls format:(NSString *)format, ... { va_list a; va_start(a, format); [[self _logger] w:cls message:[[NSString alloc] initWithFormat:format arguments:a]]; va_end(a); }
+ (void)i:(Class)cls format:(NSString *)format, ... { va_list a; va_start(a, format); [[self _logger] i:cls message:[[NSString alloc] initWithFormat:format arguments:a]]; va_end(a); }
+ (void)d:(Class)cls format:(NSString *)format, ... { va_list a; va_start(a, format); [[self _logger] d:cls message:[[NSString alloc] initWithFormat:format arguments:a]]; va_end(a); }
+ (void)f:(Class)cls format:(NSString *)format, ... { va_list a; va_start(a, format); [[self _logger] f:cls message:[[NSString alloc] initWithFormat:format arguments:a]]; va_end(a); }
+ (void)v:(Class)cls format:(NSString *)format, ... { va_list a; va_start(a, format); [SFLogger v:cls message:[[NSString alloc] initWithFormat:format arguments:a]]; va_end(a); }
+ (void)log:(Class)cls level:(SFLogLevel)level format:(NSString *)format, ... { va_list a; va_start(a, format); [[self _logger] log:cls level:level message:[[NSString alloc] initWithFormat:format arguments:a]]; va_end(a); }

// Class message: methods
+ (void)e:(Class)cls message:(NSString *)message { [[self _logger] e:cls message:message]; }
+ (void)w:(Class)cls message:(NSString *)message { [[self _logger] w:cls message:message]; }
+ (void)i:(Class)cls message:(NSString *)message { [[self _logger] i:cls message:message]; }
+ (void)d:(Class)cls message:(NSString *)message { [[self _logger] d:cls message:message]; }
+ (void)f:(Class)cls message:(NSString *)message { [[self _logger] f:cls message:message]; }
+ (void)v:(Class)cls message:(NSString *)message { [SFLogger v:cls message:message]; }
+ (void)log:(Class)cls level:(SFLogLevel)level message:(NSString *)message { [[self _logger] log:cls level:level message:message]; }

// Instance message: methods (forward to class methods)
- (void)e:(Class)cls message:(NSString *)message { [[self class] e:cls message:message]; }
- (void)w:(Class)cls message:(NSString *)message { [[self class] w:cls message:message]; }
- (void)i:(Class)cls message:(NSString *)message { [[self class] i:cls message:message]; }
- (void)d:(Class)cls message:(NSString *)message { [[self class] d:cls message:message]; }
- (void)f:(Class)cls message:(NSString *)message { [[self class] f:cls message:message]; }
- (void)v:(Class)cls message:(NSString *)message { [[self class] v:cls message:message]; }
- (void)log:(Class)cls level:(SFLogLevel)level message:(NSString *)message { [[self class] log:cls level:level message:message]; }

@end
