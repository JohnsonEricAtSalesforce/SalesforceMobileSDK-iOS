// SFSDKCoreLogger.h
// SalesforceSDKCore
//
// Created by Bharath Hariharan on 6/27/17.
// Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause

// SFSDKCoreLogger — class is defined in Swift (SFSDKCoreLogger.swift).
// This header declares the variadic format: category for ObjC callers.

@import SalesforceSDKCommon;

// Forward-declare the class (defined in Swift via -Swift.h)
@class SFSDKCoreLogger;

// This category cannot be used until after -Swift.h is imported in the .m file.
// The .m files that use these must import -Swift.h before this header.
@interface SFSDKCoreLogger (VariadicFormat)
+ (void)e:(nonnull Class)cls format:(nonnull NSString *)format, ... NS_FORMAT_FUNCTION(2, 3);
+ (void)w:(nonnull Class)cls format:(nonnull NSString *)format, ... NS_FORMAT_FUNCTION(2, 3);
+ (void)i:(nonnull Class)cls format:(nonnull NSString *)format, ... NS_FORMAT_FUNCTION(2, 3);
+ (void)d:(nonnull Class)cls format:(nonnull NSString *)format, ... NS_FORMAT_FUNCTION(2, 3);
+ (void)f:(nonnull Class)cls format:(nonnull NSString *)format, ... NS_FORMAT_FUNCTION(2, 3);
+ (void)v:(nonnull Class)cls format:(nonnull NSString *)format, ... NS_FORMAT_FUNCTION(2, 3);
+ (void)log:(nonnull Class)cls level:(enum SFLogLevel)level format:(nonnull NSString *)format, ... NS_FORMAT_FUNCTION(3, 4);
@end
